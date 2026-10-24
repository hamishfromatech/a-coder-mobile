/**
 * WebSocket server with Bearer token auth, rate limiting, and client registry.
 * Binds an HTTP server used for both the WS upgrade at /rpc and /health + /info.
 */

import { timingSafeEqual } from 'node:crypto'
import http, { IncomingMessage, ServerResponse } from 'node:http'
import type { AddressInfo } from 'node:net'
import { WebSocketServer, WebSocket } from 'ws'
import { LineAccumulator } from './wire.js'

// ─── Rate limiter (10 failures / 15 min per IP → 15 min lockout) ──

interface RateLimitEntry {
  failures: number
  windowStart: number
  lockedUntil: number | null // ms epoch when lockout expires (null = not locked)
}

const RATE_LIMIT_MAX_FAILURES = 10
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000   // 15 minutes
const RATE_LIMIT_LOCKOUT_MS = 15 * 60 * 1000  // 403 for 15 min

export class RateLimiter {
  private entries = new Map<string, RateLimitEntry>()

  /** Returns null if allowed; returns remaining lockout seconds if blocked. */
  check(ip: string): number | null {
    const entry = this.entries.get(ip)
    if (!entry) return null
    const now = Date.now()
    if (entry.lockedUntil && now < entry.lockedUntil) {
      return Math.ceil((entry.lockedUntil - now) / 1000)
    }
    return null // allowed
  }

  recordFailure(ip: string): void {
    const now = Date.now()
    let entry = this.entries.get(ip)
    if (!entry) {
      entry = { failures: 0, windowStart: now, lockedUntil: null }
      this.entries.set(ip, entry)
    }

    // Reset the failure window once it has elapsed.
    if (now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
      entry.failures = 0
      entry.windowStart = now
    }

    if (entry.lockedUntil && now >= entry.lockedUntil) {
      // Lockout expired — start a fresh window.
      entry.lockedUntil = null
      entry.failures = 0
      entry.windowStart = now
    }

    entry.failures++
    if (entry.failures >= RATE_LIMIT_MAX_FAILURES && !entry.lockedUntil) {
      entry.lockedUntil = now + RATE_LIMIT_LOCKOUT_MS
      console.error(`[auth] rate limit: ${ip} locked for ${RATE_LIMIT_LOCKOUT_MS / 60000} min`)
    }
  }

  recordSuccess(ip: string): void {
    this.entries.delete(ip)
  }

  /** Clean up stale entries (lockout expired long ago). */
  cleanup(): void {
    const now = Date.now()
    for (const [ip, entry] of this.entries) {
      if (!entry.lockedUntil && now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
        this.entries.delete(ip)
      } else if (entry.lockedUntil && now > entry.lockedUntil) {
        this.entries.delete(ip)
      }
    }
  }
}

// ─── Client registry ───────────────────────────────────────────

export interface AuthenticatedClient {
  ws: WebSocket
  ip: string
}

export type MessageHandler = (line: string, clientIp: string) => void
export type CloseHandler = (clientIp: string) => void

// ─── HTTP handlers for /health and /info ───────────────────────

function getClientIp(req: IncomingMessage): string {
  return req.socket.remoteAddress ?? 'unknown'
}

/** Compare two strings in constant time (length check up front is unavoidable). */
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  try {
    return timingSafeEqual(Buffer.from(a, 'utf8'), Buffer.from(b, 'utf8'))
  } catch {
    let result = 0
    for (let i = 0; i < a.length; i++) {
      result |= a.charCodeAt(i) ^ b.charCodeAt(i)
    }
    return result === 0
  }
}

// ─── WebSocket server ──────────────────────────────────────────

export interface WsServerOptions {
  token: string          // '' = no-auth mode (local only)
  maxClients: number
  onMessage: MessageHandler
  onClose: CloseHandler
  onClientConnect?: () => void
  onClientDisconnect?: () => void
  onError?: (msg: string) => void
}

export class WsServer {
  private readonly httpServer: http.Server
  private readonly wss: WebSocketServer
  private readonly rateLimiter = new RateLimiter()
  private readonly clients = new Map<WebSocket, AuthenticatedClient>()
  private readonly perClientAcc: Map<WebSocket, LineAccumulator> = new Map()
  private readonly backpressureTimers = new Set<ReturnType<typeof setTimeout>>()
  private cleanupInterval: ReturnType<typeof setInterval> | null = null
  private token: string
  private maxClients: number
  private readonly opts: WsServerOptions
  private address: AddressInfo | null = null

  constructor(opts: WsServerOptions) {
    this.opts = opts
    this.token = opts.token
    this.maxClients = opts.maxClients

    this.httpServer = http.createServer((req, res) => { this.handleHttp(req, res) })

    this.wss = new WebSocketServer({ noServer: true, maxPayload: 16 * 1024 * 1024 })

    // The http 'upgrade' event types `socket` as Duplex; WebSocketServer's
    // handleUpgrade expects a net.Socket — the actual object is a Socket.
    this.httpServer.on('upgrade', (req, socket, head) => {
      this.handleUpgrade(req, socket as import('node:net').Socket, head)
    })

    this.wss.on('connection', (ws, req) => { this.handleConnection(ws, req) })
  }

  /** Bind and start listening. Resolves with the actual port once listening. */
  listen(port: number, bind: string): Promise<number> {
    return new Promise((resolve, reject) => {
      this.httpServer.once('error', reject)
      this.httpServer.listen(port, bind, () => {
        this.httpServer.off('error', reject)
        this.httpServer.on('error', (err) => console.error(`[http] ${err.message}`))
        this.address = this.httpServer.address() as AddressInfo
        // Periodic rate-limiter cleanup
        this.cleanupInterval = setInterval(() => this.rateLimiter.cleanup(), 60 * 1000)
        resolve(this.address.port)
      })
    })
  }

  /** Accept a new token (--rotate) — takes effect for future connections. */
  updateToken(token: string): void {
    this.token = token
  }

  get clientCount(): number {
    return this.clients.size
  }

  get listenAddress(): AddressInfo | null {
    return this.address
  }

  /** Send one LF-terminated line to every connected client. */
  broadcast(line: string): void {
    const data = line.endsWith('\n') ? line : line + '\n'
    for (const [, client] of this.clients) {
      if (client.ws.readyState === WebSocket.OPEN) {
        client.ws.send(data)
      }
    }
  }

  stop(): void {
    if (this.cleanupInterval) { clearInterval(this.cleanupInterval); this.cleanupInterval = null }
    for (const timer of this.backpressureTimers) clearTimeout(timer)
    this.backpressureTimers.clear()
    for (const [, client] of this.clients) {
      try { client.ws.close(1001, 'Server shutting down') } catch {}
    }
    this.wss.close()
    this.httpServer.close()
  }

  // ── internals ──────────────────────────────────────────────

  private handleUpgrade(req: IncomingMessage, socket: import('node:net').Socket, head: Buffer): void {
    const url = new URL(req.url ?? '/', 'http://localhost')
    if (url.pathname !== '/rpc') {
      socket.destroy()
      return
    }

    const ip = getClientIp(req)

    // Rate-limit lockout check (only meaningful in auth mode)
    if (this.token) {
      const blocked = this.rateLimiter.check(ip)
      if (blocked !== null) {
        console.error(`[auth] ${ip} rate-limited: ${blocked}s remaining`)
        socket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n')
        socket.destroy()
        return
      }
    }

    // Token check — Bearer header preferred, ?token= query tolerated.
    if (this.token) {
      let providedToken: string | null = null
      const authHeader = req.headers.authorization
      if (authHeader?.startsWith('Bearer ')) {
        providedToken = authHeader.slice(7)
      } else if (url.searchParams.has('token')) {
        console.warn('[ws] ?token= query param used — discouraged')
        providedToken = url.searchParams.get('token')
      }

      if (!providedToken || !safeEqual(providedToken, this.token)) {
        this.rateLimiter.recordFailure(ip)
        socket.write('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n')
        socket.destroy()
        return
      }
    }

    // Capacity check — full bridge rejects new clients with 503.
    if (this.clients.size >= this.maxClients) {
      socket.write('HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n\r\n')
      socket.destroy()
      return
    }

    this.wss.handleUpgrade(req, socket, head, (ws) => {
      this.wss.emit('connection', ws, req)
    })
  }

  private handleConnection(ws: WebSocket, req: IncomingMessage): void {
    const ip = getClientIp(req)
    if (this.token) this.rateLimiter.recordSuccess(ip)

    const client: AuthenticatedClient = { ws, ip }
    this.clients.set(ws, client)
    console.log(`[ws] client connected from ${ip} (total: ${this.clients.size})`)

    // Bridge control frames on connect — clients count includes this one.
    this.sendBridgeFrame(ws, { event: 'connected', clients: this.clients.size })
    this.sendBridgeFrame(ws, { event: 'server_version', v: '0.1.0' })
    this.opts.onClientConnect?.()

    // Buffer partial frames into complete NDJSON lines before forwarding.
    const acc = new LineAccumulator((line) => this.opts.onMessage(line, ip))
    this.perClientAcc.set(ws, acc)

    ws.on('message', (data: Buffer | string) => {
      acc.feed(typeof data === 'string' ? data : data.toString('utf8'))
    })

    ws.on('close', () => {
      this.clients.delete(ws)
      this.perClientAcc.delete(ws)
      console.log(`[ws] client disconnected from ${ip} (total: ${this.clients.size})`)
      this.opts.onClose(ip)
      this.opts.onClientDisconnect?.()
    })

    ws.on('error', (err) => {
      this.opts.onError?.(`[ws] error for ${ip}: ${err.message}`)
    })

    // Backpressure guard — warn once via slow_client frame, then drop the client.
    // Each check reschedules itself; fired timers are removed from the set so it
    // doesn't grow unboundedly over a long-lived connection.
    const checkBackpressure = () => {
      if (!this.clients.has(ws) || ws.readyState !== WebSocket.OPEN) return
      if (ws.bufferedAmount > 8 * 1024 * 1024) {
        console.error(`[ws] slow client ${ip}: ${ws.bufferedAmount} bytes buffered`)
        this.sendBridgeFrame(ws, { event: 'slow_client', ip })
        ws.close(1008, 'Client falling behind')
        return
      }
      const t = setTimeout(() => {
        this.backpressureTimers.delete(t)
        checkBackpressure()
      }, 5000)
      this.backpressureTimers.add(t)
    }
    checkBackpressure()
  }

  private sendBridgeFrame(ws: WebSocket, event: Record<string, unknown>): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'bridge', ...event }) + '\n')
    }
  }

  private handleHttp(req: IncomingMessage, res: ServerResponse): void {
    const url = new URL(req.url ?? '/', 'http://localhost')

    if (req.method !== 'GET') {
      res.writeHead(405).end()
      return
    }

    switch (url.pathname) {
      case '/health': {
        res.writeHead(200, { 'Content-Type': 'application/json' })
        res.end(JSON.stringify({ ok: true, version: '0.1.0' }))
        return
      }
      case '/info': {
        // Pre-auth shape always available; full shape behind the token.
        let authorized = false
        if (!this.token) {
          authorized = true
        } else {
          let providedToken: string | null = null
          if (req.headers.authorization?.startsWith('Bearer ')) {
            providedToken = req.headers.authorization.slice(7)
          } else if (url.searchParams.has('token')) {
            console.warn('[http] ?token= query param used — discouraged, may be logged')
            providedToken = url.searchParams.get('token')
          }
          if (providedToken && safeEqual(providedToken, this.token)) {
            if (this.token) this.rateLimiter.recordSuccess(getClientIp(req))
            authorized = true
          }
        }

        if (authorized) {
          res.writeHead(200, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({
            name: 'A-Coder Bridge',
            version: '0.1.0',
            protocol: 'acoder-rpc-v1',
            requiresAuth: this.token.length > 0,
            activeClients: this.clients.size,
            maxClients: this.maxClients,
          }))
        } else {
          res.writeHead(200, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({ requiresAuth: true }))
        }
        return
      }
      default:
        res.writeHead(404).end('Not found')
        return
    }
  }
}