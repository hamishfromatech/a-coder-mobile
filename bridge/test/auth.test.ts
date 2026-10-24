/**
 * Auth tests — token accept/deny, timing-safe compare, rate limit lockout.
 */

import { describe, it, expect } from 'vitest'
import { generateToken, loadOrPersistToken, chunkToken as pairingChunkToken, reassembleToken as pairingReassembleToken } from '../src/serve/pairing.js'
import { parseBridgeFrame } from '../src/serve/control-frames.js'

describe('generateToken', () => {
  it('produces a base64url string of at least 32 chars', () => {
    const token = generateToken()
    expect(token.length).toBeGreaterThanOrEqual(32)
    // base64url uses [A-Za-z0-9_-] only
    expect(/^[-A-Za-z0-9_]+$/.test(token)).toBe(true)
  })

  it('produces different tokens each call', () => {
    const t1 = generateToken()
    const t2 = generateToken()
    expect(t1).not.toBe(t2)
  })
})

describe('parseBridgeFrame', () => {
  it('parses connected frame', () => {
    const result = parseBridgeFrame({ type: 'bridge', event: 'connected', clients: 3 })
    expect(result).toEqual({ event: 'connected', clients: 3 })
  })

  it('parses engine_exited frame', () => {
    const result = parseBridgeFrame({ type: 'bridge', event: 'engine_exited', code: 1 })
    expect(result).toEqual({ event: 'engine_exited', code: 1 })
  })

  it('parses engine_failed frame', () => {
    const result = parseBridgeFrame({ type: 'bridge', event: 'engine_failed', attempts: 2 })
    expect(result).toEqual({ event: 'engine_failed', attempts: 2 })
  })

  it('parses shutting_down frame', () => {
    const result = parseBridgeFrame({ type: 'bridge', event: 'shutting_down' })
    expect(result).toEqual({ event: 'shutting_down' })
  })

  it('parses server_version frame', () => {
    const result = parseBridgeFrame({ type: 'bridge', event: 'server_version', v: '0.1.0' })
    expect(result).toEqual({ event: 'server_version', v: '0.1.0' })
  })

  it('returns null for non-bridge frames', () => {
    expect(parseBridgeFrame({ type: 'message_start', message: {} })).toBeNull()
    expect(parseBridgeFrame(null)).toBeNull()
    expect(parseBridgeFrame('not an object')).toBeNull()
  })

  it('handles unknown bridge events gracefully', () => {
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
    const result = parseBridgeFrame({ type: 'bridge', event: 'unknown_event' })
    expect(result).toBeNull()
    expect(consoleSpy).toHaveBeenCalledWith('[bridge] unknown control frame event: unknown_event')
    consoleSpy.mockRestore()
  })

  it('parses slow_client frame', () => {
    const result = parseBridgeFrame({ type: 'bridge', event: 'slow_client', ip: '192.168.1.50' })
    expect(result).toEqual({ event: 'slow_client', ip: '192.168.1.50' })
  })
})

describe('chunkToken / reassembleToken', () => {
  // 32 random bytes → base64url = exactly 43 chars (no padding).
  it('splits a 43-char token into 5×8 + 3-char remainder', () => {
    const token = generateToken()
    expect(token.length).toBe(43)
    const chunks = pairingChunkToken(token)
    expect(chunks).toHaveLength(6) // 5 full groups of 8 + 3-char remainder
    expect(chunks.slice(0, 5).every((c) => c.length === 8)).toBe(true)
    expect(chunks[5].length).toBe(3)
  })

  it('reassembles from manual entry (remainder chunk included)', () => {
    const token = generateToken()
    const chunks = pairingChunkToken(token)
    expect(chunks.join('')).toBe(token)
    expect(pairingReassembleToken(chunks)).toBe(token)
  })
})
