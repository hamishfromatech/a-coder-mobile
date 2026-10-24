/**
 * Wire codec tests — LF-only framing, U+2028/2029 safety, \r\n tolerance, multi-MB lines.
 */

import { describe, it, expect } from 'vitest'
import { splitLines, parseLine, serializeLine, LineAccumulator } from '../src/serve/wire.js'

describe('splitLines', () => {
  it('splits on LF only', () => {
    const input = '{"type":"a"}\n{"type":"b"}\n{"type":"c"}\n'
    expect(splitLines(input)).toEqual(['{"type":"a"}', '{"type":"b"}', '{"type":"c"}'])
  })

  it('handles \r\n by stripping trailing \\r', () => {
    const input = '{"type":"a"}\r\n{"type":"b"}\r\n'
    expect(splitLines(input)).toEqual(['{"type":"a"}', '{"type":"b"}'])
  })

  it('skips empty lines', () => {
    const input = '{"type":"a"}\n\n{"type":"b"}\n'
    expect(splitLines(input)).toEqual(['{"type":"a"}', '{"type":"b"}'])
  })

  it('does NOT split on U+2028 or U+2029 inside strings', () => {
    // These are legal JSON string characters — must stay in one line
    const input = `{"text":"hello\u2028world"}\n{"type":"next"}\n`
    expect(splitLines(input)).toEqual(['{"text":"hello\u2028world"}', '{"type":"next"}'])
  })

  it('handles single line without trailing newline', () => {
    const input = '{"type":"no-newline"}'
    expect(splitLines(input)).toEqual(['{"type":"no-newline"}'])
  })

  it('returns empty array for empty string', () => {
    expect(splitLines('')).toEqual([])
  })
})

describe('parseLine', () => {
  it('parses valid JSON', () => {
    const result = parseLine('{"type":"message_start","message":{}}')
    expect(result).toEqual({ type: 'message_start', message: {} })
  })

  it('returns null for empty string', () => {
    expect(parseLine('')).toBeNull()
  })

  it('returns null for malformed JSON', () => {
    const result = parseLine('{invalid json}')
    expect(result).toBeNull()
  })

  it('parses large tool results (multi-MB simulation)', () => {
    const text = 'x'.repeat(1_000_000) // 1MB string
    const line = `{"result":"${text}"}`
    const result = parseLine(line) as Record<string, unknown>
    expect((result.result as string).length).toBe(1_000_000)
  })
})

describe('serializeLine', () => {
  it('adds trailing newline', () => {
    expect(serializeLine({ type: 'test' })).toBe('{"type":"test"}\n')
  })

  it('serializes nested objects', () => {
    const obj = { id: 'abc', data: { foo: 'bar' } }
    const result = serializeLine(obj)
    expect(result).toContain('"id":"abc"')
    expect(result).toContain('"foo":"bar"')
  })
})

describe('LineAccumulator', () => {
  it('yields complete lines on feed', () => {
    const lines: string[] = []
    const acc = new LineAccumulator((line) => lines.push(line))

    acc.feed('{"a":1}\n{"b":2}\n')
    expect(lines).toEqual(['{"a":1}', '{"b":2}'])
  })

  it('buffers partial data until newline', () => {
    const lines: string[] = []
    const acc = new LineAccumulator((line) => lines.push(line))

    acc.feed('{"partial')
    expect(lines).toEqual([]) // no complete line yet

    acc.feed(':1}\n')
    expect(lines).toEqual(['{"partial:1}']) // partial chunks join into one line
  })

  it('flushes remaining buffer', () => {
    const lines: string[] = []
    const acc = new LineAccumulator((line) => lines.push(line))

    acc.feed('{"not": "finished"}')
    expect(lines).toEqual([])

    acc.flush()
    expect(lines).toEqual(['{"not": "finished"}'])
  })

  it('handles mixed \\n and \\r\\n', () => {
    const lines: string[] = []
    const acc = new LineAccumulator((line) => lines.push(line))

    acc.feed('{"a":1}\r\n{"b":2}\n')
    expect(lines).toEqual(['{"a":1}', '{"b":2}'])
  })
})
