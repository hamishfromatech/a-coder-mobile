# A-Coder Mobile v1 — release plan and checklist

**Target:** release candidate built and verified **Thu 2026-12-10**; ship
**Sat 2026-12-12**.

**Snapshot:** 2026-11-17 23:00 NZDT. `feat/on-device-lfm3` @ `cded22e`
(docs commit; feature head `2920258`), `main` @ `74a0bc1`. App version
`1.0.0+1`.

Owner: Maya. Go/no-go reviewer: Dash. Board owns push, merge, tag, store
submission and release-notes publication.

Task structure (board plan, 2026-11-17): **THE-107** release build (Maya,
blocked by THE-106, THE-42, THE-48) → **THE-108** go/no-go (Dash). Delegated
slices: **THE-109** store metadata drafts (Dash), **THE-110** iOS on-device
gate (Maya, blocked by THE-106).

---

## Definition of done — current state

| # | Gate | State | Owner | Evidence |
|---|---|---|---|---|
| 1 | `flutter analyze` + `flutter test` green on the release commit | **Open** | Maya (THE-106) | Last recorded green: 267 tests @ `361f747`, 2026-11-03 — **before** the LFM3 branch. No gate result recorded yet for `2920258`. |
| 2 | THE-48 device QA on a physical device, with evidence | **Blocked** | Maya | Blocked on THE-38 (Xcode) for the iOS half and on hardware. Emulator matrix from 2026-11-03 has 2 open failures (below). |
| 3 | Android AAB + iOS archive, release version/signing, installable by QA | **Open** | Maya | Android signing material is present and valid (see below); no AAB built yet. iOS needs Xcode + an Apple team (none set in the Xcode project). |
| 4 | Store metadata + release notes ready (submission board-gated) | **In progress** | Dash (THE-109), reviewed by Maya | No store metadata, screenshots or release notes existed at kickoff; THE-109 is drafting them under `docs/store/v1/`. |
| 5 | Dash go/no-go review PASS on every line | **Not started** | Dash | Rubric to be issued with the RC. |

## Critical path

```
Xcode install (THE-38, board)
  └─> iOS simulator build + physical-device QA (THE-48)
        └─> signed iOS archive (DoD 3)
Android AAB (independent) ──┘
LFM3 branch lands (THE-106) ─> release commit ─> artifacts rebuilt on it
Store metadata (Dash, independent)
```

- **Xcode install latest dates.** For RC on 12-10: install by **Thu 2026-11-26**
  (two-week buffer for device QA, defect fixes, signing). Hard latest
  **Thu 2026-12-03** (one week; no slack for a defect that needs a rebuild).
  Past 12-03, the 12-12 ship date should be treated as at risk and the board
  asked to re-plan.
- Every artifact must be rebuilt from the **same release commit** after the
  LFM3 branch lands. Do not ship an AAB built from a dirty or pre-merge tree.

## Workstreams

| Workstream | Issue | Owner | State | Next action |
|---|---|---|---|---|
| Land `feat/on-device-lfm3` | THE-106 | Maya | in progress | analyze + test on `2920258`, docs, then board push approval, PR → `main` |
| iOS toolchain | THE-38 | Board installs, Maya verifies | in progress | install full Xcode; verify `xcodebuild -version` and `flutter build ios --simulator` |
| Physical-device QA (`wss://`, pinned cert, one turn) | THE-48 | Maya | blocked | runs after THE-38; needs a real Android phone on the same LAN as the bridge |
| Release artifacts | THE-107 | Maya | blocked | Android AAB as soon as THE-106 lands; iOS archive after THE-38 |
| Store metadata + release notes | THE-109 | Dash | in progress | drafts only; nothing published |
| Desktop "Mobile access" card | THE-42 | Dash | in review | confirm it ships in the desktop build used for QA |
| iOS on-device gate | THE-110 | Maya | blocked (THE-106) | hide/disable on-device on iOS for v1, with a widget test |
| Go/no-go review | THE-108 | Dash | blocked (THE-107) | rubric at RC; verdict PASS/FAIL per line |
| Push relay | THE-40 | — | out of scope | design spike only; not part of v1 |

## Release contents (and what is verified)

- **On-device LFM3** — voice chat, Omni multimodal, model hub/streaming, image
  composer, speech languages, persistent transcripts. Android arm64 only; see
  the iOS gap below.
- **Desktop "Mobile access" card** (THE-42) — in review.
- **`wss://` + certificate pinning** — bridge side merged (THE-41); app side is
  `app/lib/core/connection/cert_pinning.dart`. Device verification is THE-48.

## Gaps found in this audit

1. **iOS and on-device models.** `docs/on-device.md` says "iOS on-device
   support is not wired in this pass", but the app exposes the `/local` routes
   on every platform (`app/lib/app.dart`) and `app/pubspec.yaml` configures
   `llamadart` native backends only for `android-arm64` and `android-x64`.
   For v1 the safe choice is to hide/disable on-device entry points on iOS so
   the iOS archive cannot present a feature that cannot load a native runtime.
   Needs a board scope decision and a small, tested gate.
2. **Store prerequisites are missing.** No store metadata, screenshots or
   privacy-policy document/URL; no `DEVELOPMENT_TEAM` in
   `app/ios/Runner.xcodeproj`; Play Console account status unverified. These
   block DoD 3 (signed archive) and DoD 4, not the Dart work.
3. **Android upload key is local-only.** `app/android/app/upload-keystore.jks`
   (alias `upload`, created 2026-09-25) and `app/android/key.properties` are
   correctly git-ignored but exist on this machine only. The board/operator
   must back both up: losing the key blocks every future update to the same
   listing. Never commit or paste the passwords.
4. **Emulator matrix has two open failures** (2026-11-03, pre-LFM3):
   the offline home's Retry button is a no-op
   (`lib/features/sessions/screens/home_screen.dart`, `onRetry: _noop`), and
   background → foreground lands on the Pairing screen. Both need a decision:
   fix before RC or explicitly accept for v1 with the physical-device pass as
   cover. The physical-device matrix is required either way.
5. **Version freeze.** `1.0.0+1` is the RC version. After any store upload the
   build number must increase (`+2`, `+3`); never upload a lower build number.
   THE-107's brief says bundle ids are `com.atech.*`; the app actually ships as
   `dev.acoder.mobile` (Android) and `dev.acoder.mobile.acoderMobile` (iOS).
   Renaming the Android `applicationId` now would create a new Play listing and
   detach the existing upload key, so the recommendation is to keep the current
   ids unless the board explicitly chooses a new identity.
6. **Branch is local-only.** Push and the PR are board-gated (THE-106). CI
   (analyze/test/Android compile/unsigned IPA) has therefore never run on the
   LFM3 commits; the first PR run is a real gate, not a formality.

## Artifact runbook

Run from `app/` after `flutter pub get` on the release commit. Keep every
artifact under `app/build/releases/v1.0.0+1/` with a SHA-256 file.

```bash
# Android App Bundle (uses the upload keystore when key.properties is present)
flutter build appbundle --release
cp build/app/outputs/bundle/release/app-release.aab \
   build/releases/v1.0.0+1/acoder-mobile-1.0.0+1.aab

# Android arm64 APK for QA sideload (on-device models need arm64)
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
   build/releases/v1.0.0+1/acoder-mobile-1.0.0+1-arm64.apk

# Confirm the AAB is signed with the upload key, not the debug key
keytool -printcert -jarfile build/releases/v1.0.0+1/acoder-mobile-1.0.0+1.aab | head -20

# iOS (needs full Xcode; THE-38)
flutter build ipa --release            # signed archive, requires a team
./scripts/build_ios.sh unsigned        # CI/sideload fallback

shasum -a 256 build/releases/v1.0.0+1/* > build/releases/v1.0.0+1/SHA256SUMS
```

Signing checks that must be recorded with the artifact:

- Android: certificate CN/fingerprint matches the `upload` keystore, not
  `CN=Android Debug`.
- iOS: archive built with the release configuration and the A-Tech team, and
  `Info.plist` carries `CFBundleShortVersionString 1.0.0`, `CFBundleVersion 1`.

## Timeline

| Week | Dates | Exit criteria |
|---|---|---|
| 1 | 11-17 → 11-23 | LFM3 branch green (analyze + tests) and docs current; Android AAB built and installed; store drafts started; iOS on-device decision made |
| 2 | 11-24 → 11-30 | Xcode installed **by 11-26**; iOS simulator build; physical-device QA (THE-48) with transcript + screenshots; defects triaged |
| 3 | 12-01 → 12-09 | Release commit frozen; AAB + signed iOS archive rebuilt on it; QA installs both; store metadata + screenshots final; Dash go/no-go PASS by 12-09 |
| RC | 12-10 | Board approves tag/RC |
| Ship | 12-12 | Board submits to both stores |

## Board inputs needed

1. Apple Developer Program team and status (Team ID) — required for the signed
   iOS archive and any TestFlight/App Store upload.
2. Google Play Console account status and upload path — required for
   submission (not for the RC build).
3. iOS v1 scope for on-device models: gate them to Android for v1
   (recommended) or wire an iOS native runtime before RC.
4. Bundle identity: keep `dev.acoder.mobile` / `dev.acoder.mobile.acoderMobile`
   (recommended) or switch to `com.atech.*` before v1.
5. Physical devices available for QA (Android model, iPhone model).

## Governance

Nothing is pushed, tagged, submitted or published without explicit board
approval. Release notes and store metadata are drafts until approved. The
upload keystore password is never written to the repo, a comment or a document.
