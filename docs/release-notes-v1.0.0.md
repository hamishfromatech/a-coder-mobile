# A-Coder Mobile v1.0.0 — release notes (draft)

> **Draft.** This text is prepared for a GitHub Release body. Nothing here is
> published; creating the Release needs an explicit board approval.

A-Coder Mobile is the phone client for the A-Coder bridge: pair with the machine
running `a-coder-cli serve`, then read sessions, send prompts, watch responses
stream in, and answer approval requests from the phone. Version **1.0.0**
(build 1).

## Downloads

| Platform | File | Notes |
|---|---|---|
| Android | `acoder-mobile-1.0.0.apk` | Universal APK (arm64-v8a, armeabi-v7a, x86_64). Android 7.0 (API 24) or newer. |
| iOS | `acoder-mobile-1.0.0-unsigned.ipa` | **Unsigned.** iOS 15.0 or newer. Needs sideloading — see below. |
| Both | `SHA256SUMS` | Verify before installing. |

```
3c32595161dc5148ad8f644765b37aada63095f44eea3c43fa2718ca893456e5  acoder-mobile-1.0.0.apk
16d123bf20db1492ca7e48668714108fa26d5a9bcce32e530690ad7a03f466e5  acoder-mobile-1.0.0-unsigned.ipa
```

## What's in v1

- **Pairing over the local network** with `wss://` and certificate pinning, via
  QR capture or a pasted host/pin.
- **Sessions and streaming chat** — browse the bridge's sessions, send a prompt,
  watch the reply stream token by token, stop a turn.
- **Approvals** — surface pending approval requests and answer them from the
  phone.
- **On-device models (Android only in v1)** — the LFM3 features: text chat,
  voice chat, Omni multimodal input, model hub and downloads, an image composer,
  speech languages and persistent transcripts. No desktop bridge needed.
- **Settings** — host management, pairing controls, appearance.

## Installing on Android

1. Download `acoder-mobile-1.0.0.apk` and `SHA256SUMS`.
2. Optionally verify: `shasum -a 256 -c SHA256SUMS` (macOS/Linux) or
   `certutil -hashfile acoder-mobile-1.0.0.apk SHA256` (Windows).
3. Open the file on the phone. Android will ask you to allow installing from
   this source (browser or file manager) — allow it for this install only.
4. Play Protect may show a "scan" prompt for an app installed outside Play;
   choose to install anyway.

The APK is signed with the A-Coder Mobile upload key
(`CN=A-Coder Mobile, OU=Mobile, O=A-Coder, C=NZ`). A later APK signed with the
same key installs over this one; an APK signed with a different key will not, and
requires uninstalling the old app first.

## Installing on iOS

There is **no signed iOS build** in this release: an Apple Developer Program
account is not enrolled, so no distribution certificate or provisioning profile
exists. The `.ipa` is unsigned and cannot be installed as downloaded. Two
supported paths:

- **Sideload with your own Apple ID.** Use a sideloading tool such as Sideloadly
  or AltStore with the unsigned IPA. The tool re-signs it for your device using a
  free Apple ID. Free-account signatures expire after 7 days and must be renewed;
  a paid developer account gives a year.
- **Build from source.** `flutter build ios --release` from the matching tag,
  with Xcode and your own signing team, then run on your device.

If neither is acceptable, use the Android client or the desktop app.

## Requirements

- The Mac (or Linux host) running **`a-coder-cli serve`**, reachable on the same
  network. TLS is required for `wss://`; the app pins the bridge certificate.
  For live tool cards, the bridge must be a build that includes the THE-125
  fix (released `0.80.202` predates it).
- Android 7.0+ / iOS 15.0+.

## Known limitations in 1.0.0

- **On-device models are Android-only.** Every iOS on-device entry point is
  gated and shows an explanatory screen (scope decision, THE-110).
- **Live-turn tool cards need a newer bridge.** The app renders tool activity
  from the bridge's `tool_execution_start` / `tool_execution_end` frames. Bridge
  builds up to `0.80.202` do not send those frames to phone clients, so a turn
  shows its reply but no tool cards (THE-125). The fix is committed to the CLI
  source but is not in a released bridge yet; once your bridge includes it, the
  cards appear with no app update.
- **The offline home screen's Retry does nothing**, and returning to the app from
  the background can land on the Pairing screen (known, pre-existing).
- **No auto-update.** Check this repository for a newer Release.
- **QR pairing needs a camera.** On a simulator, pair by pasting the host and pin.

## Verify a download

```
shasum -a 256 acoder-mobile-1.0.0.apk
shasum -a 256 acoder-mobile-1.0.0-unsigned.ipa
```

Compare with `SHA256SUMS` above. A mismatch means a corrupted or substituted
file — do not install it.
