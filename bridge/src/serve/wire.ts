/**
 * NDJSON wire codec — LF-only framing, U+2028/2029 safe, multi-MB line support.
 * Mirrors the engine's jsonl.ts rules exactly (doc 03 §1).
 */

/**
 * Split raw data into complete JSON lines on LF boundaries only.
 * Handles \r\n by stripping trailing \r. Skips empty lines.
 * U+2028/U+2029 inside strings are legal JSON and must NOT split records.
 */
export function splitLines(data: string): string[] {
  // Split on LF only (\n), not \r\n or other sequences
  const parts = data.split('\n')
  const lines: string[] = []

  for (const part of parts) {
    // Strip trailing \r before \n (engine does this too)
    const cleaned = part.replace(/\r$/, '')
    if (cleaned.length > 0) {
      lines.push(cleaned)
    }
  }

  return lines
}

/**
 * Parse a single JSON line. Returns null for empty or malformed input.
 */
export function parseLine(line: string): unknown | null {
  const trimmed = line.trim()
  if (trimmed.length === 0) return null
  try {
    return JSON.parse(trimmed)
  } catch {
    // Malformed JSON — log and drop (per protocol rules)
    console.error(`[wire] malformed JSON: ${trimmed.slice(0, 100)}`)
    return null
  }
}

/**
 * Serialize a value to one JSON line terminated with LF.
 */
export function serializeLine(value: unknown): string {
  return JSON.stringify(value) + '\n'
}

/**
 * Line-based stream accumulator.
 * Buffers partial data and emits complete lines via its per-instance callback.
 * Handles multi-MB lines without dropping the connection, and never discards
 * completed lines when an oversized tail arrives (doc 03 §1: max line 16 MiB).
 */
export class LineAccumulator {
  private buffer = ''
  private readonly maxLineBytes = 16 * 1024 * 1024 // 16 MiB
  private readonly onLine: (line: string) => void

  constructor(onLine: (line: string) => void) {
    this.onLine = onLine
  }

  /** Feed raw data into the accumulator; complete lines are emitted via the callback. */
  feed(data: Buffer | string): void {
    const str = typeof data === 'string' ? data : data.toString('utf8')
    this.buffer += str

    // Extract complete lines first — never drop valid completed data.
    let idx: number
    while ((idx = this.buffer.indexOf('\n')) >= 0) {
      const line = this.buffer.slice(0, idx).replace(/\r$/, '')
      this.buffer = this.buffer.slice(idx + 1)
      if (line.length > 0) {
        this.onLine(line)
      }
    }

    // Only the incomplete remainder is left. If it exceeds the cap, drop it:
    // a single line this large is protocol garbage (max payload is 16 MiB).
    if (this.buffer.length > this.maxLineBytes) {
      console.error(`[wire] incomplete line exceeded ${this.maxLineBytes} bytes — dropping`)
      this.buffer = ''
    }
  }

  /** Call when the stream ends — emits any remaining buffer as a final line. */
  flush(): void {
    const trimmed = this.buffer.replace(/\r$/, '')
    this.buffer = ''
    if (trimmed.length > 0) {
      this.onLine(trimmed)
    }
  }
}