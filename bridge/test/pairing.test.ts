/**
 * Pairing tests — token generation, persistence, QR payload round-trip.
 */

import { describe, it, expect, beforeEach } from 'vitest'
import { writeFileSync, unlinkSync, existsSync, readFileSync, rmSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'
import * as pairing from '../src/serve/pairing.js'

describe('token generation and persistence', () => {
  const tmpDir = '/tmp/acoder-test-token-' + Date.now()
  const tokenFile = join(tmpDir, 'token')

  beforeEach(() => {
    // Clean slate — the directory must exist for tests that write directly.
    try { unlinkSync(tokenFile) } catch {}
    try { rmSync(tmpDir, { recursive: true }) } catch {}
    mkdirSync(tmpDir, { recursive: true })
  })

  it('generates a new token and persists it', () => {
    const token = pairing.loadOrPersistToken(tokenFile)
    expect(token.length).toBeGreaterThanOrEqual(32)
    expect(existsSync(tokenFile)).toBe(true)
    // Clean up
    try { rmSync(tmpDir, { recursive: true }) } catch {}
  })

  it('reuses existing token', () => {
    const first = pairing.loadOrPersistToken(tokenFile)
    const second = pairing.loadOrPersistToken(tokenFile)
    expect(first).toBe(second)
    // Clean up
    try { rmSync(tmpDir, { recursive: true }) } catch {}
  })

  it('regenerates on corrupt file', () => {
    writeFileSync(tokenFile, 'short')
    const token = pairing.loadOrPersistToken(tokenFile)
    expect(token.length).toBeGreaterThanOrEqual(32)
    // Clean up
    try { rmSync(tmpDir, { recursive: true }) } catch {}
  })
})

describe('QR payload', () => {
  it('builds a valid QR payload', () => {
    const token = pairing.generateToken()
    const payload = pairing.buildQrPayload('192.168.1.20', 8787, false, token, "Hamish's MacBook")
    expect(payload.v).toBe(1)
    expect(payload.kind).toBe('acoder')
    expect(payload.host).toBe('192.168.1.20')
    expect(payload.port).toBe(8787)
    expect(payload.tls).toBe(false)
    expect(payload.token).toBe(token)
    expect(payload.name).toContain("Hamish's")
    expect(payload.id).toHaveLength(8) // 8 hex chars of SHA-256
  })

  it('round-trips through JSON serialization', () => {
    const token = pairing.generateToken()
    const payload = pairing.buildQrPayload('10.0.0.5', 9000, true, token, 'Test Machine')
    const json = JSON.stringify(payload)
    const parsed = pairing.parseQrPayload(json)
    expect(parsed).not.toBeNull()
    expect(parsed?.host).toBe('10.0.0.5')
    expect(parsed?.port).toBe(9000)
    expect(parsed?.tls).toBe(true)
    expect(parsed?.token).toBe(token)
  })

  it('rejects invalid payloads', () => {
    expect(pairing.parseQrPayload('')).toBeNull()
    expect(pairing.parseQrPayload('not json')).toBeNull()
    expect(pairing.parseQrPayload(JSON.stringify({ v: 2, kind: 'acoder' }))).toBeNull()
    expect(pairing.parseQrPayload(JSON.stringify({ v: 1, kind: 'wrong' }))).toBeNull()
  })

  it('derives consistent machine id from token', () => {
    const token = 'same-token-for-testing'
    const p1 = pairing.buildQrPayload('x', 8080, false, token, 'M1')
    const p2 = pairing.buildQrPayload('y', 9090, true, token, 'M2')
    expect(p1.id).toBe(p2.id) // same token → same id
    expect(p1.id).toHaveLength(8)
  })
})

describe('chunkToken / reassembleToken', () => {
  it('splits and reassembles a full token', () => {
    const token = pairing.generateToken()
    const chunks = pairing.chunkToken(token)
    expect(chunks.length).toBeGreaterThanOrEqual(4)
    const joined = pairing.reassembleToken(chunks)
    expect(joined).toBe(token)
  })

  it('returns null for incomplete manual entry', () => {
    // Only 3 chunks of 8 chars = 24 chars, less than 32 minimum
    const result = pairing.reassembleToken(['aaaaaaaa', 'aaaaaaaa', 'aaaaaaaa'])
    expect(result).toBeNull()
  })

  it('handles empty token gracefully', () => {
    const chunks = pairing.chunkToken('')
    expect(chunks).toEqual([])
    expect(pairing.reassembleToken([])).toBeNull()
  })
})
