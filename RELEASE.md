# A-Coder Mobile v1 — release plan and checklist

**Target:** release candidate built and verified **Thu 2026-12-10**; ship
**Sat 2026-12-12**.

**Snapshot:** 2026-11-20 02:25 NZDT (plan rev 8). **PR #3 is merged into
`main`** at 2026-11-19 12:47:58Z via the board-authorised one-time admin bypass;
merge commit **`9de316d`**, whose tree is identical to the CI-verified head
`ef2aaff` (`git diff ef2aaff 9de316d` is empty). CI on `main` @ `9de316d`:
`flutter` -> `No issues found!` + **289 tests passed**; `android`,
`unsigned-ipa` and `changes` all pass. App version `1.0.0+1`. The six release
questions were answered 2026-11-19 12:47Z — see *Board decisions applied* below.
Local `feat/on-device-lfm3` is now divergent and carried the follow-up commits
(settings test/seam + release docs); they were rebased onto `main` and pushed as
[PR #4](https://github.com/hamishfromatech/a-coder-mobile/pull/4) — see Gap 6.
**THE-110 (iOS on-device gate) is implemented, green and pushed**: `flutter
analyze` clean and `flutter test` **297/297 passed**; merge is a separate board
action.

**Resource gate (2026-11-20 02:20–02:25 NZDT):** before the suite, free memory
64%, swap **1467 MB of 2048 MB (72%)**, load 8.0/12 (limit 24). Swap had been
flat at 1467 MB with 885 total pageouts across 4h52m uptime, i.e. stale swapped
pages rather than live thrash, so the suite ran as the single heavy job under
`nice -n 15 flutter test --concurrency=1`. It finished in 33 s with no pressure
delta. No build, simulator boot or render was started.

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

**Critical path moved past the merge.** Xcode installed 11-17, PR #3 went green
11-17, the six answers landed 11-19 12:47Z and **PR #3 merged at 12:47:58Z**
(board-authorised one-time admin bypass; branch protection was not changed).
THE-106 is landed, so the gate is now the **follow-up PR**, the
**THE-42 copy fix** (checked 2026-11-20: not yet in the desktop branch), the
**physical-device pass** (THE-48) and the **three operator lookups** that only
signing and submission need.

## Board decisions applied (card `30ec2894`, answered 2026-11-19 12:47Z)

| # | Question | Answer | Effect |
|---|---|---|---|
| 1 | Bundle identity | **Keep `dev.acoder.mobile` / `dev.acoder.mobile.acoderMobile`** | No rename, no new Play listing, no upload-key detachment. THE-107 builds on the shipping ids; its brief's `com.atech.*` is superseded. |
| 2 | iOS on-device scope | **Gate on-device models to Android for v1** | Approved scope for **THE-110**. iOS v1 ships pairing + chat. THE-106 has merged, so the gate can be implemented on `main` and only needs a verified analyze/test run. |
| 3 | Apple Developer Program team/status | **Not recorded** — operator must supply Team ID, account-holder status and whether an App Store Connect record exists | Blocks the *signed* iOS archive and any upload only; an unsigned archive stays buildable. |
| 4 | Google Play Console | **Unknown** — board to confirm | Blocks submission only, but approval can take days, so confirm before RC week. |
| 5 | Physical QA devices | **Not recorded** — Android phone + iPhone models, and whether the Android phone can join the bridge LAN | Blocks DoD 2 on hardware; simulator interim evidence does not substitute. |
| 6 | Upload-keystore backup | **Unsure** — paths and steps requested | Paths and a secret-free backup procedure are in Gap 3 below. Losing the key blocks every future update to the same listing. |

---

## Definition of done — current state

| # | Gate | State | Owner | Evidence |
|---|---|---|---|---|
| 1 | `flutter analyze` + `flutter test` green on the release commit | **Met on the merge commit `9de316d`** | Maya (THE-106) | `main` push CI run [44527248735](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/44527248735): `flutter` job (macos-26) -> `Analyze: No issues found! (ran in 14.9s)` and **`289 tests passed`**; `android` pass. [iOS run 44527249107](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/44527249107): `unsigned-ipa` and `changes` pass. `git diff ef2aaff 9de316d` is empty, so the merged tree is exactly the head verified before the merge. **Still to do:** the follow-up PR contains a settings-provider change and a widget test, so DoD 1 must be re-run on that merge commit before it is the release commit. |
| 2 | THE-48 device QA on a physical device, with evidence | **Interim simulator pass now runnable; physical device still missing** | Maya | 2026-11-19 evidence: `simctl list runtimes` -> **two iOS 27.2 runtimes**; `simctl list devices available` -> iPhone 18 Pro / 18 Pro Max / 17 / 17e / Air, iPad mini (all shutdown); `flutter emulators` -> **`apple_ios_simulator`** and **`acoder_pixel_api35`**; `xcodebuild -list` resolves the workspace and the `Runner` scheme. `devicectl list devices` -> **0**. So the `wss://` pairing pass can now run in a simulator as clearly-labelled interim evidence; physical-device evidence for DoD 2 cannot. Bridge evidence unchanged: v0.80.202 wss banner, served-cert pin match, `/health` 200, 12/12 cert-pinning tests. Two QA traps to carry in: the fixture cert is `CN=localhost` with no LAN IP in its SAN, and the wrong-pin case needs an untrusted chain or the pin is never consulted. |
| 3 | Android AAB + iOS archive, release version/signing, installable by QA | **Open** | Maya | Android signing material is present and valid (see below); no AAB built yet. Bundle identity is now fixed by the 2026-11-19 decision, so the first AAB will not need an identity rebuild. iOS still needs an Apple team (none set in the Xcode project). |
| 4 | Store metadata + release notes ready (submission board-gated) | **Drafts complete — review open** | Dash (THE-109), reviewed by Maya | Drafts committed on branch `the-109-store-docs` @ `94f19d7` (separate worktree): app-store, play-store, privacy policy, screenshot shot-list, README with 12 board decisions. Remaining: privacy-policy legal review + hosted URL, four screenshots (blocked by swap and, for iOS, the toolchain), and Dash's own 12 doc decisions. Identity and iOS scope are now settled for it by the 2026-11-19 answers. Nothing published. |
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
| Land `feat/on-device-lfm3` | THE-106 | Maya | **done — merged** | PR #3 squash-merged as `9de316d` at 12:47:58Z via the board-authorised one-time admin bypass; `main` CI green (`289 tests passed`); 6 local commits still need a follow-up PR |
| iOS toolchain | THE-38 | Board installs, Maya verifies | **done** | Xcode 27.2 / iOS SDK 27.2 / license accepted 2026-11-17; **iOS 27.2 simulator runtimes installed 2026-11-19** |
| Device QA (`wss://`, pinned cert, one turn) | THE-48 | Maya | in review — hardware outstanding | simulator pass unblocked 2026-11-19 (runtime + `apple_ios_simulator` emulator present); physical device still absent, `devicectl` 0; old card `159bffa1` withdrawn — the hardware question is answered "not recorded" in card `30ec2894` |
| Release artifacts | THE-107 | Maya | blocked | Android AAB once THE-106 lands; iOS archive needs device QA + signing identity |
| Store metadata + release notes | THE-109 | Dash | drafts done | branch `the-109-store-docs` @ `94f19d7`; needs privacy URL/legal sign-off, screenshots and the board decisions |
| Desktop "Mobile access" card | THE-42 | Dash | in review | Maya code review then board acceptance; ships in the desktop build used for QA |
| iOS on-device gate | THE-110 | Maya | **done** — pushed as [PR #4](https://github.com/hamishfromatech/a-coder-mobile/pull/4); merge is a separate board action | `/local*`, pairing link, home icon and Settings row Android-gated; iOS routes render the gate; widget tests on both platforms; analyze clean, 297/297 tests |
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

1. **iOS on-device gate — implemented (THE-110).** Board answer (2026-11-19):
   gate on-device to Android for v1. Implemented on
   `the-110-ios-on-device-gate`: the four `/local*` routes, the pairing-screen
   link, the home memory icon and the Settings row all check
   `onDeviceModelsAvailable()`; on iOS the routes stay registered but render an
   "On-device models are Android-only in v1" screen, and neither
   `LocalModelsScreen`/`LocalChatScreen` nor a `LlamaEngine.load` is
   constructed. Coverage: `test/features/local/on_device_gate_test.dart`
   (platform mapping, all four routes on iOS and Android, home icon both ways)
   plus a Settings test in `test/features/settings/settings_widget_test.dart`.
   **The audit premise was partly wrong.** `flutter build ios --release
   --no-codesign` succeeds (CI run `44527249107`, main, 2026-11-19; PR run
   `44068833043`), and the unsigned IPA **does** ship
   `Frameworks/llamadart.framework` — a 15.8 MB iOS-arm64 llama.cpp/ggml/Metal
   runtime with the `mtmd` audio and `llama_dart_tts_*` LFM3 speech symbols.
   The gate therefore enforces v1 **scope**, not a missing binary. iOS LFM3 is
   still unvalidated (load, RAM, thermals, speech) and there is no iPhone in the
   QA set. No load attempt was run on iOS; if one throws,
   `LocalChatController.loadModel` catches it into `state.error`.
2. **Store prerequisites are missing.** No store metadata, screenshots or
   privacy-policy document/URL; no `DEVELOPMENT_TEAM` in
   `app/ios/Runner.xcodeproj`; Play Console account status unverified. These
   block DoD 3 (signed archive) and DoD 4, not the Dart work.
3. **Android upload key is local-only — paths and backup steps supplied.** Both
   files exist on this Mac only:
   - `app/android/app/upload-keystore.jks` (2,664 bytes, alias `upload`, created
     2026-09-25)
   - `app/android/key.properties` (137 bytes; keys `storePassword`,
     `keyPassword`, `keyAlias`, `storeFile`)

   Both are correctly git-ignored (`app/android/.gitignore` lines 12 and 14).
   Losing the key blocks every future update to the same listing, so the
   operator should:
   1. Copy both files, unmodified, into the A-Tech password manager / encrypted
      vault as one encrypted archive entry (7-Zip or `zip -e`) — not a plain
      cloud folder, not chat.
   2. Record **in the vault entry**, never in this repo: the `keyAlias` value,
      the two passwords from `key.properties`, and the certificate SHA-256
      fingerprint from
      `keytool -list -v -keystore app/android/app/upload-keystore.jks -alias upload`
      (run interactively; do not redirect output into the repo).
   3. Restore it once on a second machine or a second path before the first
      upload, so the backup is known-good rather than merely present.
   4. Name the vault entry after the Play listing (`dev.acoder.mobile`), which
      the 2026-11-19 decision keeps.

   No agent can perform this step: it needs the operator's vault. Nothing here
   requires printing, copying or committing a secret.
4. **Emulator matrix has two open failures** (2026-11-03, pre-LFM3):
   the offline home's Retry button is a no-op
   (`lib/features/sessions/screens/home_screen.dart`, `onRetry: _noop`), and
   background → foreground lands on the Pairing screen. Both need a decision:
   fix before RC or explicitly accept for v1 with the physical-device pass as
   cover. The physical-device matrix is required either way.
5. **Version freeze — identity settled.** `1.0.0+1` is the RC version. After any
   store upload the build number must increase (`+2`, `+3`); never upload a
   lower build number. Board answer 2026-11-19: **keep `dev.acoder.mobile`
   (Android) and `dev.acoder.mobile.acoderMobile` (iOS)**. THE-107's brief said
   `com.atech.*`; the decision supersedes it, so there is no rename, no new Play
   listing and no upload-key detachment.
6. **The follow-up commits are not on `main` — they are [PR #4](https://github.com/hamishfromatech/a-coder-mobile/pull/4).**
   The squash merge landed the contents of `ef2aaff` only. The board approved
   the push on 2026-11-19 (`f3b168c2`), so the branch was rebased onto
   `origin/main` (`9de316d`) and pushed as `the-110-ios-on-device-gate`:
   - `454082f`, `c3b2481` — THE-45/46 settings test + injectable prefs seam
   - `5d4b64f`, `4b5ddbd`, `4abaed1`, `7e4a6bd`, `3d793a6`, `f6aee6f` — release
     tracker and QA docs
   - `c2d50a4` — THE-110 iOS on-device gate (rebased from local `d9f0c0e`)

   Rebasing onto `origin/main` dropped the commits already squashed into
   `9de316d`; the rebased gate commit is tree-identical to the locally verified
   `d9f0c0e` (`git diff d9f0c0e c2d50a4` is empty), so the 297/297 run still
   describes the PR head. `git diff --stat origin/main...HEAD` is 13 files, **+730/−190** —
   the follow-ups plus THE-110, with none of the already-merged LFM3 feature.
   DoD 1 must be re-run on the PR's merge commit, because the delta changes a
   settings provider and adds a widget test. Merge is a separate board action.
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
| 1 | 11-17 → 11-23 | LFM3 branch green (analyze + tests) and **merged (done 11-19, `9de316d`)**; **Xcode installed (done 11-17)**; **iOS on-device decision made (11-19: gate to Android)**; Android AAB built and installed; store drafts started |
| 2 | 11-24 → 11-30 | iOS simulator runtime installed (**done 11-19**) + simulator build; physical-device QA (THE-48) with transcript + screenshots; defects triaged |
| 3 | 12-01 → 12-09 | Release commit frozen; AAB + signed iOS archive rebuilt on it; QA installs both; store metadata + screenshots final; Dash go/no-go PASS by 12-09 |
| RC | 12-10 | Board approves tag/RC |
| Ship | 12-12 | Board submits to both stores |

## Board inputs still outstanding

Card `30ec2894` was answered on 2026-11-19; both policy picks are settled above.
Three operator lookups still stand, and all three gate **signing or submission**,
never the Dart work:

1. **Apple Developer Program** — Team ID, account-holder status, and whether an
   App Store Connect record already exists for `dev.acoder.mobile.acoderMobile`
   (required for the signed archive / TestFlight).
2. **Google Play Console** — is the developer account approved, and does an app
   record / listing already exist for `dev.acoder.mobile`? (Submission only, but
   approval can take days.)
3. **Physical QA devices** — Android phone and iPhone models, and whether the
   Android phone can join the bridge machine's LAN (DoD 2).

The upload-keystore question is answered procedurally in Gap 3: the operator
performs and confirms the vault backup; no agent needs the secret.

The merge gate that sat beside this list is settled: the board chose a
**one-time admin bypass** for PR #3 over changing branch protection, THE-114 was
closed as a duplicate, and the merge landed as `9de316d`. Protection on `main`
is unchanged (`required_approving_review_count: 1`,
`require_last_push_approval: true`, `enforce_admins: true`), so the follow-up
PR needs its own board decision on how it merges — another one-time
bypass, a temporary reviewer, or a second collaborator.

## Governance

Nothing is pushed, tagged, submitted or published without explicit board
approval. Release notes and store metadata are drafts until approved. The
upload keystore password is never written to the repo, a comment or a document.
