/**
 * `a-coder-cli serve` — CLI entry point.
 * Parses flags, loads/generates token, starts WS server + mDNS announce,
 * spawns engine on first client, handles lifecycle (SIGTERM/SIGINT).
 */

import { resolve } from 'node:path'
import { homedir, hostname, networkInterfaces } from 'node:os'
import { isEADDRINUSE } from './net-utils.js'
import { WsServer } from './ws-server.js'
import { EnginePump } from './engine-pump.js'
import {
  loadOrPersistToken, rotateToken, chunkToken, buildQrPayload, machineIdFor, isValidToken,
} from './pairing.js'
import { createAnnounce, type AnnounceHandle } from './announce.js'
import { serializeBridgeFrame } from './control-frames.js'
import QRCode from 'qrcode'

// ─── Argument parser ───────────────────────────────────────────

export interface CliFlags {
  cwd: string
  port: number
  bind: string
  provider?: string
  model?: string
  continue: boolean
  tokenFile: string
  tokenOverride?: string
  rotate: boolean
  maxClients: number
  idleExitMin: number
  noAuth: boolean
  announce: boolean
  engine?: string
}

export const DEFAULT_TOKEN_FILE = resolve(homedir(), '.a-coder-cli/agent/serve/token')

export function parseArgs(argv: string[]): CliFlags {
  const flags: CliFlags = {
    cwd: process.cwd(),
    port: 8787,
    bind: '0.0.0.0',
    continue: false,
    tokenFile: DEFAULT_TOKEN_FILE,
    rotate: false,
    maxClients: 1,
    idleExitMin: 30,
    noAuth: false,
    announce: true,
  }

  const needValue = (name: string, i: number): string => {
    const v = argv[i + 1]
    if (v === undefined) {
      console.error(`Missing value for ${name}`)
      process.exit(1)
    }
    return v
  }

  let i = 2 // skip node + script path
  while (i < argv.length) {
    const arg = argv[i]
    switch (arg) {
      case '--cwd': flags.cwd = resolve(needValue(arg, i)); i += 2; break
      case '--port': flags.port = parseInt(needValue(arg, i), 10) || 8787; i += 2; break
      case '--bind': flags.bind = needValue(arg, i); i += 2; break
      case '--provider': flags.provider = needValue(arg, i); i += 2; break
      case '--model': flags.model = needValue(arg, i); i += 2; break
      case '--continue': flags.continue = true; i += 1; break
      case '--token': flags.tokenOverride = needValue(arg, i); i += 2; break
      case '--token-file': flags.tokenFile = resolve(needValue(arg, i)); i += 2; break
      case '--rotate': flags.rotate = true; i += 1; break
      case '--max-clients': flags.maxClients = parseInt(needValue(arg, i), 10) || 1; i += 2; break
      case '--idle-exit': flags.idleExitMin = parseInt(needValue(arg, i), 10) || 30; i += 2; break
      case '--no-auth': flags.noAuth = true; i += 1; break
      case '--announce': flags.announce = true; i += 1; break
      case '--no-announce': flags.announce = false; i += 1; break
      case '--engine': flags.engine = needValue(arg, i); i += 2; break
      case '--tls-cert':
      case '--tls-key':
        console.error(`${arg} is reserved for wss:// support — not implemented in v0.1`)
        process.exit(1)
        break
      default:
        console.error(`Unknown option: ${arg}`)
        process.exit(1)
    }
  }

  if (flags.idleExitMin < 0) flags.idleExitMin = 0
  return flags
}

// ─── Helpers ───────────────────────────────────────────────────

/** Best-effort primary LAN IPv4 for the QR payload (bind 0.0.0.0 needs a real host). */
function primaryLanIp(): string | null {
  const nets = networkInterfaces()
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] ?? []) {
      if (net.family === 'IPv4' && !net.internal) return net.address
    }
  }
  return null
}

async function printQr(payload: string): Promise<void> {
  try {
    const text = await QRCode.toString(payload, {
      type: 'terminal',
      small: true,
      errorCorrectionLevel: 'M',
    })
    console.error(text)
  } catch (err) {
    console.error(`[serve] QR render failed: ${(err as Error).message}`)
  }
}

function printBanner(
  host: string, port: number, token: string, noAuth: boolean, announceOn: boolean, friendlyName: string
): void {
  // Startup banner to stderr (stdout is reserved for the protocol).
  console.error(`\nA-Coder serve listening on ws://${host}:${port}`)
  if (!noAuth) {
    console.error(`Pairing token: ${chunkToken(token).join(' ')}`)
    console.error(`mDNS: _a-coder._tcp announced as "${friendlyName}"`)
  } else {
    console.error(`WARNING: Running without auth on ${host}:${port}!`)
  }
  console.error()
}

// ─── Main serve logic ──────────────────────────────────────────

export interface ServeHandle {
  wsServer: WsServer
  enginePump: EnginePump
  actualPort: number
  stop: () => Promise<void>
  republishAnnounce: () => void
}

/**
 * Build and start the full serve stack (WS + pump + announce).
 * Exported for tests; the CLI wrapper below handles process-level concerns.
 */
export async function startServe(flags: CliFlags): Promise<ServeHandle> {
  if (flags.noAuth && flags.bind !== '127.0.0.1') {
    throw new Error('--no-auth requires --bind 127.0.0.1 for local dev only')
  }

  // Token: --token overrides the file; otherwise load-or-create.
  let token: string
  if (flags.tokenOverride) {
    if (!isValidToken(flags.tokenOverride)) {
      throw new Error('Invalid --token: expected 32+ chars of base64url')
    }
    token = flags.tokenOverride
  } else if (flags.rotate) {
    token = rotateToken(flags.tokenFile)
  } else {
    token = loadOrPersistToken(flags.tokenFile)
  }
  if (!flags.noAuth && !isValidToken(token)) {
    throw new Error('Invalid token — regenerate with `serve --rotate`')
  }

  const effectiveToken = flags.noAuth ? '' : token

  // Both are wired to each other's callbacks; declare first so neither
  // callback can hit the temporal dead zone if a client connects during
  // the `listen` await below.
  let wsServer!: WsServer
  let enginePump!: EnginePump

  wsServer = new WsServer({
    token: effectiveToken,
    maxClients: flags.maxClients,
    onMessage: (line) => {
      enginePump.sendCommand(line)
    },
    onClose: () => {
      if (wsServer.clientCount <= 0) enginePump.onClientDisconnect()
    },
    onClientConnect: () => {
      enginePump.onClientConnect()
    },
    onClientDisconnect: () => {
      if (wsServer.clientCount <= 0) enginePump.onClientDisconnect()
    },
    onError: (msg) => console.error(msg),
  })

  enginePump = new EnginePump({
    cwd: flags.cwd,
    provider: flags.provider,
    model: flags.model,
    continue: flags.continue,
    engineCommand: flags.engine,
    maxRestartAttempts: 2,
    idleExitMs: flags.idleExitMin * 60 * 1000,
    onEngineLine: (line) => {
      // Transparent transport — engine line passes through verbatim.
      wsServer.broadcast(line)
    },
    onControlFrame: (event) => {
      wsServer.broadcast(serializeBridgeFrame(event as never))
    },
  })

  // Bind with auto-port fallback: try port..port+9 on EADDRINUSE.
  let lastError: unknown
  let actualPort = flags.port
  for (let p = flags.port; p < flags.port + 10; p++) {
    try {
      actualPort = await wsServer.listen(p, flags.bind)
      lastError = null
      break
    } catch (err) {
      if (isEADDRINUSE(err)) {
        lastError = err
        continue
      }
      throw err
    }
  }
  if (lastError) {
    throw new Error(`No free port in range ${flags.port}–${flags.port + 9}`)
  }

  // mDNS announce (skipped in no-auth mode: loopback-only serving).
  const friendlyName = `A-Coder on ${hostname().replace(/[^a-zA-Z0-9\-]/g, '_') || 'host'}`
  let announce: AnnounceHandle | null = null
  if (flags.announce && !flags.noAuth) {
    announce = createAnnounce({ serviceName: friendlyName, port: actualPort, token })
  }

  const qrHost = primaryLanIp() ?? (flags.bind === '0.0.0.0' ? '127.0.0.1' : flags.bind)
  printBanner(qrHost, actualPort, token, flags.noAuth, flags.announce, friendlyName)
  if (!flags.noAuth) {
    await printQr(JSON.stringify(buildQrPayload(qrHost, actualPort, false, token, friendlyName)))
  }

  const stop = async (): Promise<void> => {
    announce?.stop()
    enginePump.shutdown()
    wsServer.stop()
  }

  return {
    wsServer,
    enginePump,
    actualPort,
    stop,
    republishAnnounce: () => announce?.republish(),
  }
}

/** CLI wrapper: parse argv, start, wire process signals, stay alive. */
export async function runServe(argv: string[] = process.argv): Promise<void> {
  const flags = parseArgs(argv)
  const handle = await startServe(flags)

  const gracefulShutdown = () => {
    console.error('\n[serve] shutting down...')
    handle.stop().finally(() => process.exit(0))
    // Hard exit if teardown hangs (e.g. engine ignoring SIGKILL).
    setTimeout(() => process.exit(0), 12_000).unref()
  }
  process.on('SIGTERM', gracefulShutdown)
  process.on('SIGINT', gracefulShutdown)

  // Re-announce on SIGHUP (documented for users; also fires on network changes).
  process.on('SIGHUP', () => {
    console.error('[serve] SIGHUP — re-announcing mDNS')
    handle.republishAnnounce()
  })

  console.error(`[serve] ready — project: ${flags.cwd}`)
}

// CLI entry point when run directly.
const isMain = process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href
if (isMain) {
  runServe().catch((err) => {
    console.error(`Failed to start serve: ${err instanceof Error ? err.message : err}`)
    process.exit(1)
  })
}