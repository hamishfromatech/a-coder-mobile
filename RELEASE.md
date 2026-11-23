# A-Coder Mobile v1 — release plan and checklist

**Target:** release candidate built and verified **Thu 2026-12-10**; ship
**Sat 2026-12-12**.

**Snapshot:** 2026-11-23 14:2x NZDT (plan rev 11). **PR #4 is merged into
`main`** at 2026-11-23 01:24:24Z, squash commit **`361bc63`**, under board
approval `9520dd25` (one-time bypass). `git diff 5544b23 361bc63` is empty, so
the merged tree is exactly the PR head that CI verified: `flutter` ->
`No issues found!` + **297 tests passed**, plus `android`, `unsigned-ipa` and
`changes` all green. That makes **`361bc63` the release commit candidate**, and
its own push CI run confirms it: [mobile 45094390320](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/45094390320)
-> `Analyze: No issues found! (ran in 15.6s)`, **`🎉 297 tests passed`**, android
success; [iOS build 45094390363](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/45094390363)
-> success. App version `1.0.0+1`. The six release
questions were answered 2026-11-19 12:47Z — see *Board decisions applied* below.
PR #3 (`9de316d`, 2026-11-19) carried the LFM3 feature with 289 tests; PR #4
carried the follow-up commits plus the THE-110 iOS on-device gate (see Gap 6).
Merging PR #4 exposed a defect in `main`'s branch protection — see **Gap 9**: the
required status contexts do not match any check the workflows publish, so no PR
can ever satisfy them.

**Resource gate (2026-11-23 14:22 NZDT):** free memory 74%, swap **3536 MB of
5120 MB (69%)**, load 5.65/12 (limit 24). Swap is over the 25% hard-stop line, so
this heartbeat ran **no build, no `flutter test` and no simulator boot**; every
number in this revision comes from `gh`, `git`, `security`, `devicectl` or a
GitHub-hosted CI run. The 2026-11-20 suite run recorded in earlier revisions was
the last local heavy job (297/297 under `nice -n 15`, 33 s).

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
| 1 | `flutter analyze` + `flutter test` green on the release commit | **Met on `361bc63` (PR #4 merge)** — re-confirmed by the push CI run at that commit | Maya | PR #4 head `5544b23`: `flutter` -> `No issues found!` + **297 tests passed**; `changes`, `android`, `unsigned-ipa` all pass ([run 44534309166](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/44534309166) / [44534309291](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/44534309291)). Squash-merged as `361bc63`; `git diff 5544b23 361bc63` is **empty**, so the merged tree is byte-identical to the verified head. DoD 1 is confirmed by the push CI run at `361bc63` (2026-11-23 01:26-01:30Z): `Analyze: No issues found! (ran in 15.6s)` and **`297 tests passed`** ([run 45094390320](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/45094390320), job `137430850317`), iOS `unsigned-ipa`/`changes` success ([run 45094390363](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/45094390363)), android success. PR #3's `9de316d` run (289 tests) remains recorded for history. |
| 2 | THE-48 device QA on a physical device, with evidence | **Interim simulator pass executed 2026-11-20; physical device still missing** | Maya | iPhone 18 Pro / iOS 27.2 simulator against `a-coder-cli serve` 0.80.202 with the fixture cert: pinned `wss://` connect **PASS** (`[conn] ready`, 501 sessions, Home rendered), wrong pin **PASS** (all-zero pin -> `CERTIFICATE_VERIFY_FAILED`, self-signed chain so the pin really was consulted). **One turn is PARTIAL:** streaming works (`agent_start -> message_update xN -> turn_end -> agent_end`) and the engine executed bash, but **no `tool_execution_start`/`tool_execution_end` frames reached the client**, so tool cards had nothing to render — a real defect, filed as a THE-48 follow-up. QR capture not run (simulator has no camera; pairing was seeded via debug `SEED_HOST_TLS`/`SEED_HOST_PIN`, same `PairedHost -> HostRegistry.wsUrl -> RpcClient` path). `devicectl` still **0 devices**, so DoD 2's hardware row is open. This evidence is committed locally on `feat/on-device-lfm3` (`3d0d925`, QA.md + integration test + debug seed) and is **not yet on `main`** — it needs a push approval when the physical run happens. |
| 3 | Android AAB + iOS archive, release version/signing, installable by QA | **Open** | Maya | Android signing material is present and valid (see below); no AAB built yet. Bundle identity is now fixed by the 2026-11-19 decision, so the first AAB will not need an identity rebuild. iOS still needs an Apple team (none set in the Xcode project). |
| 4 | Store metadata + release notes ready (submission board-gated) | **Drafts complete — review open** | Dash (THE-109), reviewed by Maya | Drafts committed on branch `the-109-store-docs` @ `94f19d7` (separate worktree): app-store, play-store, privacy policy, screenshot shot-list, README with 12 board decisions. Remaining: privacy-policy legal review + hosted URL, four screenshots (blocked by swap and, for iOS, the toolchain), and Dash's own 12 doc decisions. Identity and iOS scope are now settled for it by the 2026-11-19 answers. Nothing published. |
| 5 | Dash go/no-go review PASS on every line | **Not started** | Dash | Rubric to be issued with the RC. |

## Critical path

```
PR #3 merged 11-19 (9de316d) ─> PR #4 merged 11-23 (361bc63, 297 tests) = release commit candidate
  └─> DoD 1 re-read from push CI at 361bc63 ─> AAB + iOS archive rebuilt on it
THE-42 copy fix (Dash, still outstanding) ──┘
THE-48: simulator interim pass DONE 11-20 (connect PASS, wrong pin PASS, turn PARTIAL)
  ├─ tool_execution_* frames missing client-side ─> follow-up defect
  └─ physical device (missing) ─> DoD 2 + signed iOS archive
Apple team / Play Console (operator) ─> signed archive + submission
Gap 9 protection-context fix (board) ─> any future PR merge, incl. THE-107
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
| Land `feat/on-device-lfm3` | THE-106 | Maya | **done — merged twice** | PR #3 squash-merged as `9de316d` (2026-11-19, 289 tests). Follow-ups + THE-110 merged as **PR #4 -> `361bc63`** (2026-11-23, 297 tests), so nothing is left unpushed on this path |
| iOS toolchain | THE-38 | Board installs, Maya verifies | **done** | Xcode 27.2 / iOS SDK 27.2 / license accepted 2026-11-17; **iOS 27.2 simulator runtimes installed 2026-11-19** |
| Device QA (`wss://`, pinned cert, one turn) | THE-48 | Maya | **blocked — physical hardware outstanding** | interim iOS simulator pass executed 2026-11-20: connect PASS, wrong pin PASS, turn PARTIAL (no `tool_execution_*` frames to the client). Evidence is local (`3d0d925`) and unpushed. `devicectl` 0 devices; hardware is still question 5 of `30ec2894` |
| Release artifacts | THE-107 | Maya | blocked | Android AAB can start on `361bc63`; the signed iOS archive needs an Apple team (none on this Mac) and DoD 2 |
| Store metadata + release notes | THE-109 | Dash | drafts done | branch `the-109-store-docs` @ `94f19d7`; needs privacy URL/legal sign-off, screenshots and the board decisions |
| Desktop "Mobile access" card | THE-42 | Dash | in review | Maya code review then board acceptance; ships in the desktop build used for QA |
| iOS on-device gate | THE-110 | Maya | **done — merged** | Shipped in [PR #4](https://github.com/hamishfromatech/a-coder-mobile/pull/4) -> `361bc63` (2026-11-23). `/local*`, pairing link, home icon and Settings row Android-gated; iOS routes render the gate; widget tests on both platforms; analyze clean, 297/297 tests |
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
6. **The follow-up commits and THE-110 are merged — [PR #4](https://github.com/hamishfromatech/a-coder-mobile/pull/4) -> `361bc63` (closed 2026-11-23).**
   The PR #3 squash landed the contents of `ef2aaff` only. The board approved
   the push on 2026-11-19 (`f3b168c2`), the branch was rebased onto
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
8. **No physical device, and the interim pass found a turn defect.** The
   simulator `wss://` pass ran on 2026-11-20 (iPhone 18 Pro / iOS 27.2): connect
   PASS, wrong pin PASS, **turn PARTIAL** — streaming completes, the engine
   executes the tool, but no `tool_execution_start`/`tool_execution_end` frames
   reach the client, so tool cards cannot render. That is a product defect now
   attached to THE-48, not a test gap. `devicectl` still sees 0 devices, so
   DoD 2's physical-device evidence remains open; the simulator cannot supply
   it, and neither can it exercise QR capture (no camera). The evidence lives
   in local commit `3d0d925` and needs a board-approved push to reach `main`.

9. **`main`'s branch protection cannot be satisfied by any workflow.** Found while
   merging PR #4 (2026-11-23). Protection requires three **legacy status
   contexts**: `mobile / flutter`, `mobile / android`, `iOS build / unsigned-ipa`.
   The workflows publish **check runs** named `flutter`, `android`,
   `unsigned-ipa`, `changes`. The names never match, so GitHub reports the
   required checks as permanently *expected* and every PR on `main` returns
   `405 — 3 of 3 required status checks are expected`, regardless of green CI.
   Verified:

   ```
   required contexts : mobile / flutter | mobile / android | iOS build / unsigned-ipa  (app_id null → legacy statuses)
   check runs @5544b23: flutter | android | unsigned-ipa | changes  (all success, github-actions)
   ```

   This is config, not a code defect: `enforce_admins: true` means even an admin
   cannot bypass it (`gh pr merge --admin` and the REST merge endpoint both
   returned 405), which is why PR #4 needed a temporary removal of
   `required_status_checks` to merge at all — see *Merge mechanics* below.
   **Fix needs board approval:** change the required contexts to the names the
   workflows actually publish (`flutter`, `android`, `unsigned-ipa`), or switch
   the requirement to the three check-run apps. Until then, every future PR
   needs the same manual bypass, including THE-107's release commits.

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
| 1 | 11-17 → 11-23 | LFM3 branch green and **merged (11-19 `9de316d`; 11-23 `361bc63`)**; **Xcode installed (11-17)**; **iOS on-device decision (gate to Android)** and **THE-110 merged**; store drafts done. **Not met:** Android AAB built/installed (no build — swap over the hard stop across this window) |
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

### Merge mechanics (both merges, for the record)

| Merge | Approval | Mechanism | Result |
|---|---|---|---|
| PR #3 | board bypass on THE-114 | one-time admin bypass | `9de316d`, 2026-11-19 12:47:58Z |
| PR #4 | `9520dd25` (approved 2026-11-23 01:22Z) | one-time bypass: `required_status_checks` and the PR-review requirement removed, merge executed pinned to `5544b23`, both restored from a captured backup seconds later | `361bc63`, 2026-11-23 01:24:24Z |

PR #4 needed one field more than PR #3: because of **Gap 9**, the required
status contexts can never be satisfied, so the merge was blocked on checks as
well as on review. The temporary window is disclosed here rather than left
implicit. Restoration was verified against the pre-merge capture
`protection-main-backup.json` and the live protection is **identical** to it:
`required_status_checks` (strict `true`, same three contexts), review
requirement (1 approval, `require_last_push_approval: true`,
`dismiss_stale_reviews: true`), `enforce_admins: true`, linear history on,
force-push and deletion off, conversation resolution on, `lock_branch` off. No
other setting changed, and nothing was force-pushed.

**Still needs a board decision:** Gap 9's context mismatch, so the next merge
(THE-107) does not need the same manual intervention.

## Governance

Nothing is pushed, tagged, submitted or published without explicit board
approval. Release notes and store metadata are drafts until approved. The
upload keystore password is never written to the repo, a comment or a document.
