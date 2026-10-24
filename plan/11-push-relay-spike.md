# 11 — Push Relay Spike (design only, M6.4)

Status: **spike / not implemented.** This document is the design hook the plan
calls for; nothing here ships in v1.

## Problem

The phone only knows about an approval request or a finished turn while the app
is connected. iOS/Android suspend LAN sockets in the background, so a user who
walks away misses the one event that needs them: *the agent is blocked waiting
for permission*. Push is the only reliable way to surface that.

## Non-goals

- No cloud execution, no remote control over the relay.
- No message content, prompts, code, file paths, or tokens leave the LAN.
- No always-on relay requirement: the bridge keeps working exactly as today
  when push is disabled.

## Architecture

```
a-coder-cli serve ──(outbound HTTPS)──► relay (small stateless service) ──► APNs / FCM ──► phone
        │                                     ▲
        └── pairing already shares the token ─┘  (device registration is a separate, revocable id)
```

- The bridge opens an **outbound** connection to the relay (never inbound), so
  no port forwarding or NAT traversal is needed.
- The relay is a dumb fan-out: it maps `device_push_id → platform token` and
  forwards an opaque notification. It stores no transcripts.
- The relay is optional: self-hosters can run it, or use the hosted one.

## Event triggers (v1)

| Event | Notification |
|---|---|
| `extension_ui_request` (`kind: permission`) | "Approval needed — {tool}" |
| `agent_end` after a turn the user didn't watch | "Turn finished" |
| `cron_update` job `lastStatus: error` | "Scheduled task failed" |

Rate limits: at most one notification per session per 60 s, coalesced; approvals
always win over completion notices. Quiet hours and per-session mute are client
settings.

## Payload

```json
{
  "v": 1,
  "kind": "approval_waiting",
  "hostId": "deadbeef",
  "sessionId": "…",
  "tool": "bash",
  "requestId": "…",
  "sentAt": 1760000000000
}
```

No prompt text, no command, no output, no token. The phone wakes, reconnects
over the LAN/VPN, and fetches the real state. If it cannot connect, the
notification still tells the user *that* something needs them.

## Registration & auth

1. The phone generates a random `device_push_id` (stored in secure storage).
2. It registers `{device_push_id, apns/fcm token, platform}` with the relay and
   receives a short-lived **registration secret**.
3. The bridge is given `{relayUrl, device_push_id, registration secret}` during
   pairing (a new QR field), or via `serve --push <config>`.
4. The bridge signs each notification with the registration secret
   (HMAC-SHA256); the relay rejects unsigned/invalid sends and rate-limits per
   device.
5. Removing the device in Settings revokes the secret at the relay and wipes the
   local push id.

## Privacy

- Payloads are metadata only (event kind, host id, session id, tool name).
- The relay sees device ids and timing, not conversations.
- Toggle: "Notifications" is off by default; enabling shows exactly what will be
  sent.
- Retention: relay stores no payloads, only device registrations; logs are
  counts, not contents.

## Delivery & dedupe

- The bridge includes a monotonically increasing `seq` per host; the phone
  ignores duplicates and stale (`seq < lastSeen`) notifications.
- APNs/FCM collapse keys are set per session so a burst becomes one banner.
- Deep link: notification → `acoder://chat/{hostId}/{sessionPath}` (the app
  already resolves hosts by id; add a route handler).

## Phasing

1. **Spike (this doc):** validate that a backgrounded phone reconnects < 3 s
   after a push and that approvals are answerable from the notification.
2. **Relay MVP:** single region, APNs + FCM, HMAC auth, no persistence beyond
   registration.
3. **Bridge integration:** `--push` flag, QR field, settings toggle, quiet hours.
4. **Hardening:** per-device revocation, metrics, abuse limits, self-host docs.

## Risks / open questions

- **Store review:** notification permission flows and the "no content" promise
  must be visible in the UI copy.
- **Multi-host:** one phone can pair with several desktops; notifications carry
  `hostId` and must not leak across profiles.
- **Relay trust:** a compromised relay can suppress or replay notifications, but
  cannot read content or issue commands (the WS token never leaves the LAN).
- **Cost:** negligible at single-user scale; budget for FCM/APNs free tiers.
- **Alternative considered:** local notifications while the app is foregrounded
  (already possible) and short-lived background sockets (unreliable on iOS).
