/**
 * mDNS announcement via bonjour-service.
 * Service type: _a-coder._tcp with TXT records per doc 04 §5.1:
 * `v=1`, `path=/`, `tokenReq=1`, `name=<friendly>`, `engine=a-coder-cli`,
 * `id=<machine-id>` (8 hex chars of SHA-256(token) — dedupes without leaking it).
 */

import { Bonjour, type Service } from 'bonjour-service'
import { machineIdFor } from './pairing.js'

export interface AnnounceOptions {
  serviceName: string    // "A-Coder on <hostname>" (sanitized)
  port: number
  token: string          // used to derive the machine id in the TXT record
}

export interface AnnounceHandle {
  /** Unpublish and destroy the Bonjour instance. */
  stop: () => void
  /** Re-publish (SIGHUP / network change). */
  republish: () => void
}

/** Create and start an mDNS announce. */
export function createAnnounce(opts: AnnounceOptions): AnnounceHandle {
  const publish = (): Service => {
    const b = new Bonjour()
    const service = b.publish({
      // Service name is published verbatim — do NOT double-prefix.
      name: opts.serviceName,
      type: '_a-coder._tcp',
      port: opts.port,
      txt: {
        v: '1',
        path: '/',
        tokenReq: '1',
        name: opts.serviceName.replace(/[^a-zA-Z0-9\-]/g, '_'),
        engine: 'a-coder-cli',
        id: machineIdFor(opts.token),
      },
    })
    service.on('error', (err: Error) => {
      console.error(`[mDNS] announce error: ${err.message}`)
    })
    // Keep a reference so cleanup can destroy the owning Bonjour instance.
    ;(service as Service & { _bonjour?: Bonjour })._bonjour = b
    return service
  }

  let service = publish()

  const stop = (): void => {
    try {
      const b = (service as Service & { _bonjour?: Bonjour })._bonjour
      service.stop(() => {
        try { b?.destroy() } catch {}
      })
    } catch {}
  }

  const republish = (): void => {
    try {
      const b = (service as Service & { _bonjour?: Bonjour })._bonjour
      service.stop(() => {
        try { b?.destroy() } catch {}
        service = publish()
      })
    } catch (err) {
      console.error(`[mDNS] re-announce failed: ${(err as Error).message}`)
    }
  }

  return { stop, republish }
}

/** A service discovered on the LAN. */
export interface DiscoveredService {
  name: string
  host: string
  port: number
  txt: Record<string, string>
}

export interface DiscoveryHandle {
  results: DiscoveredService[]
  /** Stop browsing and destroy the Bonjour instance. */
  unsubscribe: () => void
}

/** Browse for _a-coder._tcp services (used by the CLI pairing helper). */
export function createDiscovery(): DiscoveryHandle {
  const bonjour = new Bonjour()
  const results: DiscoveredService[] = []

  const upsert = (service: Service): void => {
    const entry: DiscoveredService = {
      name: service.name ?? '',
      host: service.host ?? '',
      port: service.port ?? 0,
      txt: (service.txt as Record<string, string>) ?? {},
    }
    const idx = results.findIndex((r) => r.name === entry.name)
    if (idx >= 0) {
      results[idx] = entry
    } else {
      results.push(entry)
    }
  }

  const browser = bonjour.find({ type: '_a-coder._tcp' }, (service) => upsert(service))

  return {
    get results() { return [...results] },
    unsubscribe: () => {
      try {
        browser.stop()
        bonjour.destroy()
      } catch {}
    },
  }
}