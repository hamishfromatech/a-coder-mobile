/**
 * Token generation, persistence, QR payload structure, and manual code chunks.
 */

import { randomBytes, createHash } from 'node:crypto'
import { readFileSync, writeFileSync, existsSync, mkdirSync, chmodSync } from 'node:fs'
import { dirname } from 'node:path'

// 256-bit token as base64url (43-44 chars)
export function generateToken(): string {
  return randomBytes(32).toString('base64url')
}

/** A token is 32+ chars of base64url. */
export function isValidToken(token: string): boolean {
  return token.length >= 32 && /^[A-Za-z0-9_-]+$/.test(token)
}

/** Load a persisted token, or create + persist one. Corrupt files are regenerated. */
export function loadOrPersistToken(tokenFile: string): string {
  if (existsSync(tokenFile)) {
    const raw = readFileSync(tokenFile, 'utf8').trim()
    if (isValidToken(raw)) {
      // Self-heal permissions if the file was created without 0600.
      try { chmodSync(tokenFile, 0o600) } catch {}
      return raw
    }
    // Corrupt — regenerate below
    console.error(`[pairing] token file corrupt, regenerating: ${tokenFile}`)
  }

  const token = generateToken()
  const dir = dirname(tokenFile)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  writeFileSync(tokenFile, token, { mode: 0o600 })
  chmodSync(tokenFile, 0o600)
  return token
}

/** Overwrite the persisted token (serve --rotate). */
export function rotateToken(tokenFile: string): string {
  const token = generateToken()
  const dir = dirname(tokenFile)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  writeFileSync(tokenFile, token, { mode: 0o600 })
  chmodSync(tokenFile, 0o600)
  return token
}

/** QR payload — compact, versioned JSON (doc 04 §5.2). */
export interface QrPayload {
  v: number
  kind: 'acoder'
  host: string          // IP or hostname
  port: number
  tls: boolean
  token: string         // the full bearer token (43-char base64url, no padding)
  name: string          // friendly machine name
  id: string            // first 8 hex chars of SHA-256(token), for dedupe
}

/** Machine id derived from the token — dedupes without leaking it. */
export function machineIdFor(token: string): string {
  return createHash('sha256').update(token).digest('hex').slice(0, 8)
}

export function buildQrPayload(
  host: string, port: number, tls: boolean,
  token: string, name: string
): QrPayload {
  return { v: 1, kind: 'acoder', host, port, tls, token, name, id: machineIdFor(token) }
}

export function parseQrPayload(raw: string): QrPayload | null {
  try {
    const obj = JSON.parse(raw) as Record<string, unknown>
    if (obj?.v !== 1 || obj?.kind !== 'acoder') return null
    const host = String(obj.host ?? '')
    const port = Number(obj.port ?? 0)
    const token = String(obj.token ?? '')
    if (!host || !Number.isFinite(port) || port <= 0 || !isValidToken(token)) return null
    return {
      v: 1,
      kind: 'acoder',
      host,
      port,
      tls: Boolean(obj.tls),
      token,
      name: String(obj.name ?? ''),
      id: String(obj.id ?? machineIdFor(token)),
    }
  } catch {
    return null
  }
}

/**
 * Split a token into groups of 8 chars for manual entry. The final group
 * carries the remainder (a 44-char token → 5×8 + 4). Every character of the
 * token is preserved so manual entry can reassemble the exact token.
 */
export function chunkToken(token: string): string[] {
  const chunks: string[] = []
  for (let i = 0; i < token.length; i += 8) {
    chunks.push(token.slice(i, i + 8))
  }
  return chunks
}

/** Reassemble from manual entry (groups of 8). Returns null if incomplete. */
export function reassembleToken(chunks: string[]): string | null {
  const joined = chunks.join('').trim()
  if (!isValidToken(joined)) return null
  return joined
}