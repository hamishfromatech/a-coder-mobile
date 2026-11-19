# A-Coder Mobile v1 — release plan and checklist

**Target:** release candidate built and verified **Thu 2026-12-10**; ship
**Sat 2026-12-12**.

**Snapshot:** 2026-11-19 05:45 NZDT (plan rev 5). `feat/on-device-lfm3` local
head `c3b2481` (**4 commits ahead of the pushed head**); `origin` at `ef2aaff`,
PR #3, all four CI checks green. `main` @ `74a0bc1`. App version `1.0.0+1`.
Xcode **27.2 (27B52)** installed and selected, with **iOS 27.2 simulator
runtimes installed on 2026-11-19**.

**Resource gate (2026-11-19):** swap **11.80 GB of 12.29 GB (96%)** on a 32 GB
Mac, so no build, test suite or simulator boot is started this heartbeat. Free
memory 32%, load 4.5/12. Every number below comes from an existing artifact, an
API read or a light discovery command, not from a fresh build.

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

**Critical path changed twice.** On 2026-11-17 Xcode installed, so the toolchain
stopped being the gate. On 2026-11-19 the push approval was granted and PR #3
went green, so the gate is now the **THE-106 merge** (blocked by the review gate
on THE-114: the PR author is the repo's only collaborator), the **THE-42 copy
fix**, the **physical-device pass** (THE-48) and the **six decisions in card
`30ec2894`** that THE-107 needs before it can build.

---

## Definition of done — current state

| # | Gate | State | Owner | Evidence |
|---|---|---|---|---|
| 1 | `flutter analyze` + `flutter test` green on the release commit | **Met on the PR head; must be re-run on the merge commit** | Maya (THE-106) | PR #3 @ `ef2aaff` on macos-26: `flutter` job -> `Analyze: No issues found!` and **`289 tests passed`**; `android`, `changes` and `unsigned-ipa` also **pass**. That is the authoritative golden gate, because baselines are owned by macos-26 CI (THE-111). Local macOS 27.2 still drifts on 9 golden cases exactly as `main` does. Re-run required on the final release commit after merge. |
| 2 | THE-48 device QA on a physical device, with evidence | **Interim simulator pass now runnable; physical device still missing** | Maya | 2026-11-19 evidence: `simctl list runtimes` -> **two iOS 27.2 runtimes**; `simctl list devices available` -> iPhone 18 Pro / 18 Pro Max / 17 / 17e / Air, iPad mini (all shutdown); `flutter emulators` -> **`apple_ios_simulator`** and **`acoder_pixel_api35`**; `xcodebuild -list` resolves the workspace and the `Runner` scheme. `devicectl list devices` -> **0**. So the `wss://` pairing pass can now run in a simulator as clearly-labelled interim evidence; physical-device evidence for DoD 2 cannot. Bridge evidence unchanged: v0.80.202 wss banner, served-cert pin match, `/health` 200, 12/12 cert-pinning tests. Two QA traps to carry in: the fixture cert is `CN=localhost` with no LAN IP in its SAN, and the wrong-pin case needs an untrusted chain or the pin is never consulted. |
| 3 | Android AAB + iOS archive, release version/signing, installable by QA | **Open** | Maya | Android signing material is present and valid (see below); no AAB built yet. iOS needs Xcode + an Apple team (none set in the Xcode project). |
| 4 | Store metadata + release notes ready (submission board-gated) | **Drafts complete — review open** | Dash (THE-109), reviewed by Maya | Drafts committed on branch `the-109-store-docs` @ `94f19d7` (separate worktree): app-store, play-store, privacy policy, screenshot shot-list, README with 12 board decisions. Remaining: privacy-policy legal review + hosted URL, four screenshots (blocked by swap and, for iOS, the toolchain), and the board decisions. Nothing published. |
| 5 | Dash go/no-go review PASS on every line | **Not started** | Dash | Rubric to be issued with the RC. |

## Critical path

```
THE-106 push (done 11-17) ─> PR #3 CI green (done 11-17, 289 tests)
  └─> merge, gated by review gate THE-114 ─> release commit
        └─> DoD 1 re-run ─> AAB + iOS archive rebuilt on it
THE-42 copy fix (Dash) ────────────────────┘
Xcode 27.2 + simulator runtime (done 11-19) ─> THE-48 wss:// pass
  ├─ simulator interim evidence (runnable now, resource-gated)
  └─ physical device (missing) ─> signed iOS archive / DoD 2
Six decisions, card 30ec2894 ─> THE-107 build inputs
Store metadata (Dash, drafts done) ─> DoD 4
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
| Land `feat/on-device-lfm3` | THE-106 | Maya | in review — merge blocked by review gate | pushed; PR #3 green; merge blocked by THE-114 (`REVIEW_REQUIRED`, author is the only collaborator); 4 local commits beyond the PR head need a board-approved push |
| iOS toolchain | THE-38 | Board installs, Maya verifies | **done** | Xcode 27.2 / iOS SDK 27.2 / license accepted 2026-11-17; **iOS 27.2 simulator runtimes installed 2026-11-19** |
| Device QA (`wss://`, pinned cert, one turn) | THE-48 | Maya | in review — hardware outstanding | simulator pass unblocked 2026-11-19 (runtime + `apple_ios_simulator` emulator present); physical device still absent, `devicectl` 0; card `159bffa1` still pending on the hardware half |
| Release artifacts | THE-107 | Maya | blocked | Android AAB once THE-106 lands; iOS archive needs device QA + signing identity |
| Store metadata + release notes | THE-109 | Dash | drafts done | branch `the-109-store-docs` @ `94f19d7`; needs privacy URL/legal sign-off, screenshots and the board decisions |
| Desktop "Mobile access" card | THE-42 | Dash | in review | Maya code review then board acceptance; ships in the desktop build used for QA |
| iOS on-device gate | THE-110 | Maya | blocked (THE-106) | hide/disable on-device on iOS for v1, with a widget test |
| Go/no-go review | THE-108 | Dash | blocked (THE-107) | rubric at RC; verdict PASS/FAIL per line |
| Push relay | THE-40 | — | out of scope | design spike only; not part of v1 |
| Scanner polish | THE-47 | Dash | deferred | backlog; not part of v1 |

## Release contents (and what is verified)

- **On-device LFM3** — voice chat, Omni multimodal, model hub/streaming, image
  composer, speech languages, persistent transcripts. Android arm64 only; see
  the iOS gap below.
- **Desktop "Mobile access" card** (THE-42) — changes requested on the Remove-device copy (it revokes, it is not cosmetic); back with Dash.
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
6. **Local branch is 4 commits ahead of the CI-verified head.** The pushed head
   is `ef2aaff`; `454082f`/`c3b2481` (THE-45/46 tests) and `5d4b64f`/`4b5ddbd`
   (release docs), plus this tracker update, exist only on this machine.
   Pushing them needs board approval, and the release commit must be the merged
   `main` commit with DoD 1 re-run on it. Do not build artifacts from the local
   head as if they were the verified one.
7. **Golden baselines drift on macOS 27.2.** 9 golden cases fail locally with
   identical text-antialiasing diffs on `main`, so they are host-related, not a
   branch regression. THE-111 settled the policy (`ef2aaff`): baselines stay
   owned by macos-26 CI and the tolerance now classifies the drift instead of
   only counting pixels; no baseline PNG was regenerated. No post-change suite
   run is recorded yet, so DoD 1 still rests on the macos-26 CI run.
8. **No physical device** (simulator gap closed 2026-11-19). Xcode 27.2 has two
   iOS 27.2 runtimes and a bootable device set, and `flutter emulators` lists
   `apple_ios_simulator` and `acoder_pixel_api35`, so an interim simulator
   `wss://` pass is possible. `devicectl` still sees 0 devices, so DoD 2's
   physical-device evidence is the one thing a simulator cannot supply
   (THE-48).

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
| 2 | 11-24 → 11-30 | iOS simulator runtime installed (**done 11-19**) + simulator build; physical-device QA (THE-48) with transcript + screenshots; defects triaged |
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

All six are in the saved question card `30ec2894` on THE-105 (still pending as of
2026-11-19). One more decision sits outside that card: the **THE-106 merge gate
on THE-114** is blocked because the PR author is the repo's only collaborator,
so it clears only by temporarily lowering `required_approving_review_count` for
that merge or by adding a second reviewer. That is a yes/no, not a review.

## Governance

Nothing is pushed, tagged, submitted or published without explicit board
approval. Release notes and store metadata are drafts until approved. The
upload keystore password is never written to the repo, a comment or a document.
