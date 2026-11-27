# A-Coder Mobile v1.0.0-rc2 — release notes

A-Coder Mobile is the phone client for the A-Coder bridge: pair with the machine
running `a-coder-cli serve`, then read sessions, send prompts, watch responses
stream in, and answer approval requests from the phone.

This is the **second release candidate** for v1.0.0. It supersedes `v1.0.0-rc1`
(build 1). Install it if you already have rc1 — rc1 has a defect that stops the
phone ever appearing in the desktop's **Mobile access** list.

## What changed since rc1

| Fix | Effect |
|---|---|
| **Device identity is now sent on connect** (`#8`) | The bridge records the phone, so it appears in the desktop's Settings → **Mobile access** card and can be removed/revoked there. In rc1 the phone connected but never entered the registry, leaving the card empty. |
| **Offline Retry now reconnects** (`#7`) | The home screen's offline pane had a Retry button wired to nothing. It now requests a reconnect. |
| Release notes and the release runbook are in the repository (`#6`) | The published rc1 notes previously existed only outside the repo, so the download could not be audited against its source. |

Both app changes are small and covered by tests (see **Verification**).

## Downloads

| Platform | File | Notes |
|---|---|---|
| Android | `acoder-mobile-1.0.0-rc2.apk` | Universal APK (arm64-v8a, armeabi-v7a, x86_64). `versionCode` **2**, `versionName` 1.0.0. Android 7.0 (API 24) or newer. |
| iOS | `acoder-mobile-1.0.0-rc2-unsigned.ipa` | **Unsigned.** iOS 15.0 or newer. Needs sideloading — see below. |
| Both | `SHA256SUMS` | Verify before installing. |

```
ef40ac58e19d795cb07bf74716d1e13218eabcda37f9aed63ed6e2effc64405d  acoder-mobile-1.0.0-rc2.apk
d00c19ef98c7597a4c0d9fb7df959cbedceb6fc6ca85af9f102a83d527841da5  acoder-mobile-1.0.0-rc2-unsigned.ipa
```

Both files are built from commit
`3758525` on `main`. The APK was built locally with the release upload key; the
IPA is the CI `unsigned-ipa` artifact from the same commit.

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

1. Download `acoder-mobile-1.0.0-rc2.apk` and `SHA256SUMS`.
2. Optionally verify: `shasum -a 256 -c SHA256SUMS` (macOS/Linux) or
   `certutil -hashfile acoder-mobile-1.0.0-rc2.apk SHA256` (Windows).
3. Open the file on the phone. Android will ask you to allow installing from
   this source (browser or file manager) — allow it for this install only.
4. Play Protect may show a "scan" prompt for an app installed outside Play;
   choose to install anyway.

The APK is signed with the A-Coder Mobile upload key
(`CN=A-Coder Mobile, OU=Mobile, O=A-Coder, C=NZ`, certificate SHA-256
`de28f41d…83b4`). Because `versionCode` is **2**, it installs straight over rc1:
no uninstall is needed and the pairing/settings you already have are kept. An APK
signed with a different key will not install over it.

After installing, reconnect to your bridge and open the desktop's Settings →
**Mobile access**: the phone should now appear within a few seconds, and
**Remove** on its row is a real revocation (the bridge rejects that device's token
with `401` from then on).

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
- **The device name is generic.** The Mobile access row reads
  `Android phone (xxxx)`; the app does not read the hardware model, so a Nothing
  Phone 2a is not named as one. The four-character suffix is what distinguishes
  two phones.
- **Returning to the app from the background can land on the Pairing screen.**
  Observed once before the LFM3 work, not reproduced since.
- **No auto-update.** Check this repository for a newer Release.
- **QR pairing needs a camera.** On a simulator, pair by pasting the host and pin.

## Verification

On commit `3758525`, `main`, with GitHub Actions enabled again:

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test --concurrency=2` | **309 tests passed**, 0 failures |
| CI `flutter` job | success |
| CI `android` job | success |
| CI `unsigned-ipa` job | success |
| APK `apksigner verify` | verifies; signed by the upload key (not the debug key) |
| APK identity | `dev.acoder.mobile`, `versionCode 2`, `versionName 1.0.0`, `minSdk 24`, `targetSdk 36` |
| IPA identity | `dev.acoder.mobile.acoderMobile`, 1.0.0 (build 1), **unsigned** |

Note that the Android and iOS build numbers differ — Android `versionCode` 2 is
set by the build flag, while CI builds iOS from `pubspec.yaml` (`1.0.0+1`). Same
source commit; iOS build numbers are only meaningful for App Store uploads,
which are not part of this channel.

## Verify a download

```
shasum -a 256 acoder-mobile-1.0.0-rc2.apk
shasum -a 256 acoder-mobile-1.0.0-rc2-unsigned.ipa
```

Compare with `SHA256SUMS` above. A mismatch means a corrupted or substituted
file — do not install it.
