# A-Coder Mobile v1 — release plan and checklist

**Target:** release candidate built and verified **Thu 2026-12-10**; ship
**Sat 2026-12-12**.

**Snapshot:** 2026-11-17 23:55 NZDT. `feat/on-device-lfm3` @ `6b02bd2`
(not pushed), `main` @ `74a0bc1`. App version `1.0.0+1`. Xcode **27.2
(27B52)** installed and selected. Working tree clean.

Owner: Maya. Go/no-go reviewer: Dash. Board owns push, merge, tag, store
submission and release-notes publication.

## Task structure (board plan, comment `653ee48a`, 2026-11-17)

| Issue | Task | Owner | Blocked by |
|---|---|---|---|
| THE-106 | Land `feat/on-device-lfm3` (analyze/test, push approval, PR) | Maya | — |
| THE-42 | Desktop "Mobile access" card (in review) | Dash | — |
| THE-38 | Install full Xcode (board action, critical) | board | — |
| THE-48 | Device QA over `wss://` on hardware | Maya | THE-38 |
| THE-107 | v1 release build: AAB + iOS archive, signing, store metadata | Maya | THE-106, THE-42, THE-48 |
| THE-108 | Go/no-go review with evidence | Dash | THE-107 |

Deferred past v1: **THE-40** push relay, **THE-47** scanner polish.
Delegated slices under THE-107: **THE-109** store metadata/screenshots/release
notes drafts (Dash, drafts only), **THE-110** iOS on-device gate (Maya).

Board decisions still needed before THE-107 can build: bundle identity, iOS
on-device scope, Apple team, Play Console status, physical QA devices, and
upload-keystore backup. They are in the saved question card on THE-105.

**Critical path changed on 2026-11-17:** Xcode is installed, so the gate is no
longer the toolchain. It is now the **THE-106 push approval** (pending board
approval `7989c5af`) and the **THE-42 review**, then THE-107.

---

## Definition of done — current state

| # | Gate | State | Owner | Evidence |
|---|---|---|---|---|
| 1 | `flutter analyze` + `flutter test` green on the release commit | **Open — conditional** | Maya (THE-106) | On `6b02bd2`: `flutter analyze` clean; non-golden suite **198/198**; **9 golden cases drift on macOS 27.2** with 142–242 px text-antialiasing diffs and fail identically on `main` (`74a0bc1`). Baselines were generated on macOS 26 and CI is macos-26. DoD 1 needs either the CI run on the PR or an explicit accept of the golden drift (THE-111). |
| 2 | THE-48 device QA on a physical device, with evidence | **In progress** | Maya | Xcode 27.2 installed, so THE-48 is unblocked and running. iOS **simulator runtimes are not installed yet** (`simctl list runtimes` empty; `flutter doctor` cannot list simulator runtimes) — device builds work, simulator/UI tests wait for the runtime download. Emulator matrix from 2026-11-03 has 2 open failures (below). |
| 3 | Android AAB + iOS archive, release version/signing, installable by QA | **Open** | Maya | Android signing material is present and valid (see below); no AAB built yet. iOS needs Xcode + an Apple team (none set in the Xcode project). |
| 4 | Store metadata + release notes ready (submission board-gated) | **In progress** | Dash (THE-109), reviewed by Maya | No store metadata, screenshots or release notes existed at kickoff; THE-109 is drafting them. No draft files in this workspace yet (checked 2026-11-17). |
| 5 | Dash go/no-go review PASS on every line | **Not started** | Dash | Rubric to be issued with the RC. |

## Critical path

```
THE-106 push approval (board, pending 7989c5af) ─> PR ─> CI (macos-26)
  └─> release commit ─> AAB + iOS archive rebuilt on it
The-42 review ─────────────────────────────────┘
Xcode 27.2 (done 2026-11-17) ─> THE-48 device QA ─> signed iOS archive
Store metadata (Dash, independent)
```

- **Xcode install is no longer at risk.** Verified 2026-11-17: `/Applications/Xcode.app`
  selected, `Xcode 27.2` build `27B52`, iOS SDK 27.2, iOS Simulator SDK 27.2,
  `xcodebuild -checkFirstLaunchStatus` exit 0 (license accepted). The only
  missing piece is the simulator **runtime**, which is downloading.
- **Xcode install dates are moot.** For RC on 12-10 the old guidance was install
  by 2026-11-26; it landed on 11-17. The date-based risk now belongs to the
  THE-106 push approval and the THE-42 review.
- Every artifact must be rebuilt from the **same release commit** after the
  LFM3 branch lands. Do not ship an AAB built from a dirty or pre-merge tree.

## Workstreams

| Workstream | Issue | Owner | State | Next action |
|---|---|---|---|---|
| Land `feat/on-device-lfm3` | THE-106 | Maya | in review | board approval `7989c5af` pending: push `6b02bd2` + open PR (merge separately gated) |
| iOS toolchain | THE-38 | Board installs, Maya verifies | **done** | verified Xcode 27.2 / iOS SDK 27.2 / license accepted on 2026-11-17; simulator runtime still downloading |
| Physical-device QA (`wss://`, pinned cert, one turn) | THE-48 | Maya | in progress | running against the installed toolchain; needs a real Android phone on the same LAN as the bridge |
| Release artifacts | THE-107 | Maya | blocked | Android AAB once THE-106 lands; iOS archive needs device QA + signing identity |
| Store metadata + release notes | THE-109 | Dash | in progress | drafts only; nothing published |
| Desktop "Mobile access" card | THE-42 | Dash | in review | Maya code review then board acceptance; ships in the desktop build used for QA |
| iOS on-device gate | THE-110 | Maya | blocked (THE-106) | hide/disable on-device on iOS for v1, with a widget test |
| Go/no-go review | THE-108 | Dash | blocked (THE-107) | rubric at RC; verdict PASS/FAIL per line |
| Push relay | THE-40 | — | out of scope | design spike only; not part of v1 |
| Scanner polish | THE-47 | Dash | deferred | backlog; not part of v1 |

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
   LFM3 commits; the first PR run is a real gate, not a formality. Approval
   `7989c5af` requests push + PR only; merge stays separately gated.
7. **Golden baselines drift on macOS 27.2.** 9 golden cases fail locally with
   identical text-antialiasing diffs on `main`, so they are host-related, not a
   branch regression. The non-golden suite is 198/198 green. Fixing or
   re-baselining is THE-111; until then DoD 1 rests on the macos-26 CI run.

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
| 1 | 11-17 → 11-23 | LFM3 branch green (analyze + tests) and docs current; **Xcode installed (done 11-17)**; Android AAB built and installed; store drafts started; iOS on-device decision made |
| 2 | 11-24 → 11-30 | iOS simulator runtime installed + simulator build; physical-device QA (THE-48) with transcript + screenshots; defects triaged |
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
6. Upload-keystore backup confirmation (`upload-keystore.jks` + `key.properties`).

All six are in the saved question card `30ec2894` on THE-105 (still pending).

## Governance

Nothing is pushed, tagged, submitted or published without explicit board
approval. Release notes and store metadata are drafts until approved. The
upload keystore password is never written to the repo, a comment or a document.
