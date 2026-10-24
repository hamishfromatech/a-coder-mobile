/**
 * Bridge-owned control frames — the ONLY non-engine envelopes on the wire.
 * Every frame is a JSON object with `type: "bridge"` and an `event` field.
 */

export type BridgeEvent =
  | { event: 'connected'; clients: number }
  | { event: 'engine_exited'; code: number }
  | { event: 'engine_failed'; attempts: number }
  | { event: 'shutting_down' }
  | { event: 'server_version'; v: string }
  | { event: 'slow_client'; ip: string }

/** Serialize a bridge control frame to one JSON line. */
export function serializeBridgeFrame(frame: BridgeEvent): string {
  return JSON.stringify({ type: 'bridge', ...frame }) + '\n'
}

/** Parse a potential bridge frame from a raw JSON object (after `JSON.parse`).
 * Returns null if it's not a bridge frame. */
export function parseBridgeFrame(obj: unknown): BridgeEvent | null {
  if (obj === null || typeof obj !== 'object') return null
  const o = obj as Record<string, unknown>
  if (o.type !== 'bridge' || o.event === undefined) return null
  const event = o.event as string
  switch (event) {
    case 'connected':
      return { event: 'connected', clients: (o.clients as number) ?? 0 }
    case 'engine_exited':
      return { event: 'engine_exited', code: (o.code as number) ?? 0 }
    case 'engine_failed':
      return { event: 'engine_failed', attempts: (o.attempts as number) ?? 0 }
    case 'shutting_down':
      return { event: 'shutting_down' }
    case 'server_version':
      return { event: 'server_version', v: String(o.v ?? '') }
    case 'slow_client':
      return { event: 'slow_client', ip: String(o.ip ?? '') }
    default:
      // Unknown bridge events — log and drop (forward-compat)
      console.error(`[bridge] unknown control frame event: ${event}`)
      return null
  }
}
