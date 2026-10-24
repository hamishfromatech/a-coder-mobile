/**
 * Engine pump — spawns `a-coder-cli --mode rpc` and pumps NDJSON lines
 * between the engine's stdin/stdout and WebSocket clients.
 * Transport is transparent: engine lines pass through verbatim (doc 04 §3).
 */

import { spawn, type ChildProcess } from 'node:child_process'
import { serializeBridgeFrame } from './control-frames.js'
import { LineAccumulator } from './wire.js'

export interface EnginePumpOptions {
  cwd?: string
  provider?: string
  model?: string
  continue?: boolean
  /** Engine binary; defaults to `a-coder-cli` on PATH. Tests inject a fake engine. */
  engineCommand?: string
  /** Extra engine args before the fixed `--mode rpc` set. */
  engineArgs?: string[]
  maxRestartAttempts?: number // default 2
  restartDelayMs?: number     // default 30_000 (tests inject small values)
  idleExitMs?: number         // ms with no clients before engine shutdown (0 = never)
  /** Raw engine stdout line (LF already stripped) — broadcast verbatim. */
  onEngineLine: (line: string) => void
  /** Bridge control event to fan out to clients (serialized by the caller). */
  onControlFrame: (event: Record<string, unknown>) => void
}

export class EnginePump {
  private child: ChildProcess | null = null
  private stdinQueue: string[] = []
  private isWritingStdin = false
  private restartAttempts = 0
  private restartTimer: ReturnType<typeof setTimeout> | null = null
  private idleTimer: ReturnType<typeof setTimeout> | null = null
  private killTimer: ReturnType<typeof setTimeout> | null = null
  private hasClients = false
  private intentionalShutdown = false
  private readonly maxRestarts: number
  private readonly restartDelayMs: number
  private readonly idleExitMs: number
  private readonly opts: EnginePumpOptions

  constructor(opts: EnginePumpOptions) {
    this.opts = opts
    this.maxRestarts = opts.maxRestartAttempts ?? 2
    this.restartDelayMs = opts.restartDelayMs ?? 30_000
    this.idleExitMs = opts.idleExitMs ?? 0
  }

  /** Signal that a client connected — spawn the engine if needed. */
  onClientConnect(): void {
    this.hasClients = true
    this.intentionalShutdown = false
    this._clearIdleTimer()
    if (!this.child && !this.restartTimer) {
      this.restartAttempts = 0 // fresh connection → fresh restart budget
      this._spawnEngine()
    }
  }

  /** Signal that the last client disconnected — start the idle timer. */
  onClientDisconnect(): void {
    this.hasClients = false
    if (this.idleExitMs > 0 && this.child) {
      this._clearIdleTimer()
      this.idleTimer = setTimeout(() => {
        console.log(`[engine] idle exit: ${Math.round(this.idleExitMs / 60000)} min with no clients`)
        this._stopEngine('idle-exit')
      }, this.idleExitMs)
      if (typeof this.idleTimer.unref === 'function') this.idleTimer.unref()
    }
  }

  /** Queue a command line for the engine's stdin (single-writer queue). */
  sendCommand(line: string): void {
    this.stdinQueue.push(line.endsWith('\n') ? line : line + '\n')
    this._flushStdin()
  }

  /** Engine process is running. */
  get running(): boolean {
    return this.child !== null
  }

  /** Graceful shutdown: notify clients, then stop the engine (SIGTERM → 10s → SIGKILL). */
  shutdown(): void {
    this.intentionalShutdown = true
    this.hasClients = false
    this._clearIdleTimer()
    this._clearRestartTimer()
    this.opts.onControlFrame({ event: 'shutting_down' })
    this._stopEngine('shutdown')
  }

  // ── internals ──────────────────────────────────────────────

  private _spawnEngine(): void {
    if (this.child) return
    console.log('[engine] spawning a-coder-cli --mode rpc')

    const args = [...(this.opts.engineArgs ?? []), '--mode', 'rpc']
    if (this.opts.continue) args.push('--continue')
    if (this.opts.provider) args.push('--provider', this.opts.provider)
    if (this.opts.model) args.push('--model', this.opts.model)

    // Mirror desktop client.rs::spawn semantics: inherit the parent env (PATH
    // included) so the engine resolves providers and tools identically.
    const env = { ...process.env }

    let child: ChildProcess
    try {
      child = spawn(this.opts.engineCommand ?? 'a-coder-cli', args, {
        cwd: this.opts.cwd ?? process.cwd(),
        env,
        stdio: ['pipe', 'pipe', 'pipe'],
      })
    } catch (err) {
      console.error(`[engine] spawn failed: ${(err as Error).message}`)
      this.opts.onControlFrame({ event: 'engine_failed', attempts: this.maxRestarts })
      return
    }
    this.child = child
    this.intentionalShutdown = false

    // stdout → accumulate partial chunks into complete lines → broadcast.
    const acc = new LineAccumulator((line) => this.opts.onEngineLine(line))
    child.stdout?.on('data', (data: Buffer) => acc.feed(data))
    child.stdout?.on('end', () => acc.flush())

    // stderr → bridge stderr with [engine] prefix.
    child.stderr?.on('data', (data: Buffer) => {
      const text = data.toString('utf8').trim()
      if (text) console.error(`[engine] ${text}`)
    })

    // Spawn/kill failures (ENOENT etc.) — the process never started.
    child.on('error', (err) => {
      console.error(`[engine] process error: ${err.message}`)
      this.child = null
      this._drainStdinQueue()
      if (this.hasClients && !this.intentionalShutdown) {
        this._handleUnexpectedExit(-1)
      }
    })

    child.on('exit', (code, signal) => {
      console.log(`[engine] exited: code=${code} signal=${signal}`)
      this.child = null
      this._drainStdinQueue()
      this._clearKillTimer()

      if (this.intentionalShutdown || !this.hasClients) {
        // Intentional stop (idle exit, explicit shutdown) — no restart.
        return
      }
      this._handleUnexpectedExit(code ?? -1)
    })

    child.stdin?.on('error', (err) => {
      console.error(`[engine] stdin error: ${err.message}`)
    })
  }

  /** Unexpected engine exit while clients are connected: notify + restart (≤ maxRestarts). */
  private _handleUnexpectedExit(code: number): void {
    this.restartAttempts++
    if (this.restartAttempts <= this.maxRestarts) {
      console.log(`[engine] restart attempt ${this.restartAttempts}/${this.maxRestarts}`)
      this.opts.onControlFrame({ event: 'engine_exited', code })
      this.restartTimer = setTimeout(() => {
        this.restartTimer = null
        if (this.hasClients && !this.child) {
          this._spawnEngine()
        }
      }, this.restartDelayMs)
      if (typeof this.restartTimer.unref === 'function') this.restartTimer.unref()
    } else {
      console.error(`[engine] max restart attempts (${this.maxRestarts}) reached`)
      this.opts.onControlFrame({ event: 'engine_failed', attempts: this.maxRestarts })
    }
  }

  private _flushStdin(): void {
    if (this.isWritingStdin || !this.child?.stdin || this.stdinQueue.length === 0) return
    this.isWritingStdin = true

    const line = this.stdinQueue.shift()!
    const stdin = this.child.stdin
    const wrote = stdin.write(line, () => {
      this.isWritingStdin = false
      this._flushStdin()
    })

    if (!wrote) {
      // Backpressure — wait for drain before the next line.
      stdin.once('drain', () => {
        this.isWritingStdin = false
        this._flushStdin()
      })
    }
  }

  private _drainStdinQueue(): void {
    // Engine is gone; drop queued commands (they cannot survive a restart —
    // sessions are re-established by the client resync on reconnect).
    this.stdinQueue = []
    this.isWritingStdin = false
  }

  private _stopEngine(_reason: string): void {
    const child = this.child
    if (!child) return
    try {
      child.kill('SIGTERM')
      // 10s grace → SIGKILL. `killed` only reflects the kill call, so track
      // liveness via exitCode: null means the process is still running.
      this.killTimer = setTimeout(() => {
        if (this.child && this.child.exitCode === null && this.child.pid) {
          console.log('[engine] force kill after 10s grace')
          try { this.child.kill('SIGKILL') } catch {}
        }
        this.killTimer = null
      }, 10_000)
      if (typeof this.killTimer.unref === 'function') this.killTimer.unref()
    } catch {}
  }

  private _clearIdleTimer(): void {
    if (this.idleTimer) { clearTimeout(this.idleTimer); this.idleTimer = null }
  }

  private _clearRestartTimer(): void {
    if (this.restartTimer) { clearTimeout(this.restartTimer); this.restartTimer = null }
  }

  private _clearKillTimer(): void {
    if (this.killTimer) { clearTimeout(this.killTimer); this.killTimer = null }
  }
}

// Re-export so callers can serialize control frames without another import.
export { serializeBridgeFrame }