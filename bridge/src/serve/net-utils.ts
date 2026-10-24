/** Helpers for interpreting Node network errors. */

/** True when the error is an EADDRINUSE bind failure (port already taken). */
export function isEADDRINUSE(err: unknown): boolean {
  const e = err as { code?: string; message?: string }
  if (!e) return false
  return e.code === 'EADDRINUSE' || e.message?.includes('EADDRINUSE') === true
}