# Repo hosting proposal — `mobile-app`

**Status:** executed 2026-11-03 (THE-43); branch protection enabled 2026-11-03
**Date:** 2026-11-03
**Owner:** Flutter Expert

**Execution state:** the remote exists and is **public**; `main` is pushed, CI is
green, and classic branch protection is **enforced** on `main` (§13). The board
chose public visibility on 2026-11-02T14:17:49Z, which unblocked protection.
One prepared commit (`b37bc3a`: Android compile job + iOS PR guard) is still
local only, and the `LICENSE` choice is still open (§12.2, §13.5).

---

## 1. Decision requested

| # | Decision | Recommendation |
|---|---|---|
| D1 | Where the repo lives | `github.com/hamishfromatech/a-coder-mobile` (private) |
| D2 | Visibility | **Private** until a release is cut and a `LICENSE` is chosen |
| D3 | Default branch | **`main`** (rename local `master` before the first push) |
| D4 | History migration | Preserve all 33 commits; drop the one tracked build artifact by rewriting history while the repo is still local |
| D5 | Required checks | `mobile / flutter` only, at first. Add `iOS build / unsigned-ipa` after it runs on PRs |
| D6 | Signing secrets | **None now.** Future credentials go in a protected `release` environment, never repo-wide |

If the board prefers zero CI spend, the only change is D2 → public (free standard
runners, including macOS). That is a real trade-off, quantified in §6.

> **D2 was superseded** on 2026-11-02: the board chose public visibility to
> unblock branch protection. See §13.1. Rows D1–D6 are otherwise as approved.

---

## 2. Current state (verified locally, 2026-11-03)

```
$ git remote -v          # (empty)
$ git branch -a          # master only
$ git rev-list --count HEAD  → 33
$ git tag -l             # (empty)
$ du -sh .git            # 8.2 MB
$ git ls-files | wc -l   → 299
```

- Single branch `master`, 33 commits, single committer (`Hamish <hamish@atech.industries>`).
- `.git` is 8.2 MB of loose objects (never packed); largest tracked file is the
  912 KB app icon. Repo size is not a hosting concern.
- **Neither workflow has ever run.** There is no remote, so `.github/workflows/*`
  is unexecuted code. The first push is also the first CI run — that is why
  branch protection is enabled *after* the first green run (§8).
- Two hygiene defects to fix before the first push:
  1. `app/android/build/reports/problems/problems-report.html` (132 KB Gradle
     report) is tracked. `app/.gitignore` has `/build/`, which anchors to
     `app/build/` and does not cover `app/android/build/`.
  2. `.gitignore` has no rule for `app/android/build/`; the same mistake will
     recur on the next Gradle run.
- Working tree currently carries one uncommitted formatting change in
  `app/test/fixtures/fixture_runner.dart` from a concurrent run (THE-38). It is
  not ours to commit; the push must happen from a clean tree after that run lands.
- No `LICENSE` file. Public + unlicensed = "all rights reserved" by default,
  which is a poor first impression for a public repo.
- No tracked secrets or keystores (`app/android/.gitignore` already covers
  `key.properties`, `**/*.jks`, `**/*.keystore`).

**Local verification for this proposal:**

```
cd app && flutter analyze   → No issues found! (ran in 1.7s)
cd app && flutter test      → 267 tests, All tests passed! (~7 s)
```

---

## 3. Remote location, visibility, default branch

### 3.1 Location — `hamishfromatech/a-coder-mobile`

| Option | Verdict |
|---|---|
| **`hamishfromatech/a-coder-mobile`** | **Recommended.** Matches the existing sibling `hamishfromatech/a-coder-cli`; one owner, one billing identity, one place to grant access. |
| New org (`a-coder-dev/mobile-app`) | Better long-term if more than one maintainer or outside contributors are planned. Costs an org, separate access/billing setup, and a migration later. Revisit at the first external contributor. |
| Monorepo into `a-coder-cli` | Rejected: different release cadence (npm CLI vs mobile binaries), different toolchains, and the CLI repo's CI is npm/desktop-focused. A path filter would keep it honest but couples two release trains for no benefit. |
| Git submodule of the CLI repo | Rejected: makes mobile checkout depend on CLI commits and complicates CI caching. |

The local directory stays `mobile-app`; only the remote name changes.

### 3.2 Visibility — private

- Pre-release product with an unreleased security model (`plan/02-architecture.md §6`)
  and no license.
- Private keeps the App Store / Play submission and the signing story closed
  until there is something to announce.
- Cost is the counter-argument (§6): macOS minutes are charged at **10×** against
  the included quota on private repos, and are free on public repos.
- Suggested revisit point: immediately before the first public TestFlight/Play
  build, when a `LICENSE` and a security policy also need to exist.

### 3.3 Default branch — `main`

- Only **one** place in the repo hardcodes `master`:
  `.github/workflows/mobile.yml:5` (`branches: [master]`).
  `ios.yml` already targets `main` (which is currently a latent bug — it can
  never fire, since the only branch is `master`).
- Renaming before the first push costs one `git branch -m`, one workflow edit,
  and no broken clones — there is no remote, no fork, no PR history.
- Keeping `master` would instead require fixing `ios.yml` to `master` and leaves
  the repo on a non-default branch name forever.

`git branch -m master main` happens locally, pre-push, only after board approval.

---

## 4. History migration

**Recommendation: preserve the 33 commits, rewrite once to drop the tracked
Gradle report, then push `main`.**

Why rewrite rather than "remove it in a follow-up commit":

- The artifact has no value in history and is the only such file.
- There is no remote, no fork, no clone anywhere — rewriting now has **zero blast
  radius**. After the first push it becomes a force-push against protected
  `main`, which we would not do.
- 33 commits is small; the rewrite is fast and verifiable.

Procedure (executed only after approval, §8):

```bash
# from a scratch clone of the local repo, never in the shared workspace
git branch -m master main
git filter-repo --path app/android/build --invert-paths
# verify: same 33 commits, same tree as HEAD except the removed path
git ls-tree -r --name-only HEAD | grep -c '^app/android/build'   # → 0
git gc --aggressive --prune=now                                   # 8.2 MB → ~2 MB
```

If the board prefers not to rewrite, the fallback is a normal commit that
`git rm --cached`s the file plus the `.gitignore` fix. It costs 132 KB of dead
history and keeps every SHA stable. Either is acceptable; rewriting is cleaner
while the cost is zero.

---

## 5. Branch protection

Applied to `main` **after** the first green CI run is observed.

**Require a pull request before merging**

- 1 approving review; dismiss stale approvals on new pushes.
- Require approval of the most recent reviewable push.
- Require conversation resolution.

**Require status checks**

- `mobile / flutter` — required, must be up to date with `main`.
- `iOS build / unsigned-ipa` — **not required at first.** See §6.4; it only runs
  on `main` + `workflow_dispatch` today, so requiring it would block every PR
  on a check that never reports for that SHA.

**Merge policy**

- Squash merge only; require linear history.
- Delete head branches on merge.

**Protect from destruction**

- Block force pushes and branch deletion.
- No bypass allowlist for now (single maintainer with admin rights can still
  change settings deliberately; we do not bake in a silent bypass).
- Signed commits: **not required** initially — it would block the current
  committer identity and add a local signing setup with no threat model behind it.

Merge queue: skip. It matters with concurrent PRs and a slow required build; we
have neither yet. Revisit when two or more PRs are routinely open.

---

## 6. CI

### 6.1 What exists

| Workflow | Trigger | Runner | Steps |
|---|---|---|---|
| `.github/workflows/mobile.yml` | push → `master`; every PR | `macos-latest` | `pub get` → `flutter analyze` → `flutter test --coverage` → upload `lcov.info`; upload golden diffs on failure |
| `.github/workflows/ios.yml` | `workflow_dispatch`; push → **`main`** on `app/**` | `macos-15` | `pod install` → `flutter build ios --release --no-codesign` → package unsigned IPA → upload artifact |

Both are reusable as-is. Tests + goldens run on macOS deliberately: the golden
baselines are rasteriser/font sensitive, and Ubuntu reproduces them unreliably.

### 6.2 Required edits (small, reviewed separately)

| Change | Why |
|---|---|
| `mobile.yml`: `branches: [master]` → `[main]` | Matches the renamed default branch |
| Both: add `permissions: contents: read` | Workflows currently inherit the repo-default token scope. Nothing needs write. |
| Both: pin `flutter-version: 3.47.5` instead of `channel: stable` | Local toolchain is Flutter 3.47.5 / Dart 3.13.4 (revision `6a19cca564`). An SDK bump silently changes text layout and breaks goldens. Pin, then bump deliberately with regenerated goldens. |
| Both: pin `runs-on: macos-15` | `macos-latest` can be re-pointed at a new image; golden rendering must not drift under us. |
| Both: add `concurrency: {group: <workflow>-${{ github.ref}}, cancel-in-progress: true}` | Cancels superseded PR runs; directly reduces macOS minutes. |
| Artifact uploads: add `retention-days: 14` | Default retention is 90 days. A ~30 MB unsigned IPA × every `main` push exceeds the 500 MB private-repo storage allowance within weeks. |
| `ios.yml`: keep `macos-15`, no change to branches | It already expects `main`, which becomes correct after the rename |

### 6.3 New job — Android (recommended, cheap)

> **Implemented in THE-44** — see §12.3. It is not required yet; that needs
> branch protection, which the Free private plan still blocks.

There is currently **no CI proof that the Android app compiles**; release APKs
are only ever built by hand. Add a third job to `mobile.yml`:

```yaml
android:
  runs-on: ubuntu-latest          # 1× minutes, not 10×
  steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
      with: {flutter-version: 3.47.5, cache: true}
    - run: cd app && flutter pub get && flutter build apk --debug
```

`--debug` avoids signing entirely (release falls back to debug signing when
`key.properties` is absent, but debug is the honest compile check). ~4-6 min on
Linux. Make it required once it has passed on `main`.

### 6.4 Making the iOS job PR-visible (optional, later)

> **Implemented in THE-44** — see §12.4. It cannot be marked required until
> branch protection is available (§12.1).

To make `iOS build / unsigned-ipa` required on PRs, add a `pull_request` trigger
and a **guard step** that always reports success when no iOS-relevant path
changed. Do **not** rely on `paths:` filtering for a *required* check: a
path-filtered workflow that never starts leaves the required check pending and
blocks the merge. The guard-step pattern reports a real conclusion either way.

Recommended trigger set if adopted: `app/ios/**`, `app/pubspec.yaml`,
`app/pubspec.lock`, `app/lib/**` (plugin/native surface), `.github/workflows/ios.yml`.

### 6.5 Runner availability and cost

All GitHub-hosted; no self-hosted runner needed. Estimated **per run** (Flutter
SDK cached, `cache: true`):

| Job | Estimate |
|---|---|
| `mobile / flutter` (macOS) | 5-8 min |
| `iOS build / unsigned-ipa` (macOS) | 8-12 min |
| `android` (Linux, if added) | 4-6 min |

Illustrative month — 10 PRs and 10 pushes to `main`:

- mobile on PRs 10 × 6.5 ≈ 65 min
- mobile on `main` 10 × 6.5 ≈ 65 min
- iOS on `main` 10 × 10 ≈ 100 min
- **≈ 230 macOS minutes/month**

On a **private** repo, macOS minutes count **10×** against the plan quota
(≈ 2,300 billed minutes — over the 2,000-minute Free allowance) and cost
≈ **$0.08/min** at published list rates, i.e. **≈ $18-20/month** if fully billed.
On a **public** repo, standard runners — including macOS — are **free**, so the
same schedule costs **$0**.

Caveats the board should weigh: these are estimates from workflow step counts,
not measurements, because the workflows have never run; and GitHub pricing and
image mappings change. Confirm against the org's billing page before treating
the figure as a commitment. The first `mobile` run after the first push will
give the real duration.

Cost controls already included above: `concurrency` cancel-in-progress, Flutter
SDK cache, 14-day artifact retention, and (if adopted) a guard step so the
expensive iOS build only runs when iOS actually changed.

---

## 7. Secrets

### 7.1 Today: none

The proposed CI needs **zero secrets**. `ios.yml` builds with `--no-codesign`
and ships an unsigned IPA. The Android job uses debug signing. Nothing to
provision, nothing to leak.

### 7.2 When signing is added (TestFlight / Play)

| Platform | Credentials | Scope |
|---|---|---|
| iOS | Distribution certificate `.p12` (base64), provisioning profile (base64), or an App Store Connect API key (`issuer id`, `key id`, `.p8`) | `release` environment |
| Android | Upload keystore `.jks` (base64), `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` → materialised into `app/android/key.properties` at build time | `release` environment |

Storage and least privilege:

- **GitHub Actions *environment* secrets** on an environment named `release`,
  not repository secrets. Restrict deployment branches to `main` and require
  reviewers on the environment, so a compromised or mistaken workflow cannot
  read them.
- Job-scoped `env:` only for the steps that need them; `permissions: contents: read`
  everywhere else.
- Decode to `$RUNNER_TEMP`, import the `.p12` into a temporary keychain, and
  delete the keychain and files in an `if: always()` step.
- Fork PRs never receive secrets (GitHub withholds them), and the `release`
  environment gate means no PR job can reach them at all.
- Rotate on a calendar and on personnel change. Apple certificates expire; put
  the expiry date in `BUILD.md` when the credentials are created.
- Do **not** add long-lived cloud keys for a relay/backend later — use OIDC
  workload identity federation if that work lands (`plan/11-push-relay-spike.md`
  is design-only today).
- Secrets never go in `key.properties` in the tree, in issue comments, or in
  workflow files. `.gitignore` already covers `app/android/key.properties`,
  `**/*.jks`, `**/*.keystore`.

---

## 8. Rollout steps after approval

Every step below is gated on D1-D6 being decided. Steps 1-4 are local and
reversible; step 5 is the first irreversible external action.

1. **Hygiene commit** (local, reviewed):
   - add `android/build/` to `app/.gitignore`
   - `git rm --cached app/android/build/reports/problems/problems-report.html`
   - confirm `git status` is clean of build artifacts
2. **Branch rename** (local): `git branch -m master main`.
3. **Workflow edits** (§6.2), reviewed as a normal commit — branch name, pins,
   permissions, concurrency, artifact retention.
4. **Re-verify locally**: `cd app && flutter analyze && flutter test`
   (expect `No issues found!` and 267 passing).
5. **History rewrite** (§4) in a scratch clone; verify tree and commit count.
6. **Wait for the shared workspace to be clean.** THE-38's uncommitted
   `fixture_runner.dart` edit must be committed or discarded by its owner first;
   the initial push is done from a clean tree.
7. **Create the empty private repo** `hamishfromatech/a-coder-mobile` — no
   README, no `.gitignore`, no license from the template.
8. **Push**: `git remote add origin git@github.com:hamishfromatech/a-coder-mobile.git`
   then `git push -u origin main`.
9. **Watch the first `mobile` run.** This is its first execution ever. If
   goldens fail on the runner, fix forward with a normal commit (do not mark the
   check required while it is red).
10. **Enable branch protection** per §5, with `mobile / flutter` as the required
    check. Confirm the settings take effect (`GET .../branches/main/protection`).
11. **Prove the iOS job** with a `workflow_dispatch` run; confirm the
    `A-Coder-unsigned-ipa` artifact downloads and is non-empty.
12. **Record the outcome on THE-43** and open a follow-up issue **only if
    approved** — scope: D2 revisit at release time, `LICENSE`, and enabling the
    iOS/Android checks as required.

Explicitly **not** in scope: tags, releases, TestFlight/Play uploads, npm/pub
publication, any push to `wici-ai/inferssd`, and any change inside the
`a-coder-cli` repository.

---

## 9. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| First CI run fails on the runner because the workflows have never executed | Medium | Push, observe, fix forward **before** enabling branch protection; goldens are the likeliest failure and the workflow already uploads diff images on failure |
| `flutter-version` pin drifts from local 3.47.5 and goldens mismatch | Low once pinned | Pin exactly; bump only with regenerated goldens in the same PR |
| macOS minutes exceed the private-repo quota | Medium | `concurrency` cancel, cached SDK, guard-step iOS job, revisit public visibility at release |
| Artifact storage blows the 500 MB private allowance | Medium | `retention-days: 14` on the IPA and lcov uploads |
| Rewriting history after a push | Low if done now | Rewrite pre-push only; after that, never force-push protected `main` |
| Repo becomes a second source of truth for the bridge | Low | `bridge/` stays a pointer; the bridge remains in the CLI repo, unchanged |

---

## 10. Acceptance mapping

- [x] Remote location, visibility, default branch, history migration — §3, §4
- [x] Branch protection + required checks — §5
- [x] CI reuse of `mobile.yml` and `ios.yml`, runner availability and cost — §6
- [x] Secrets for signing, where they live, least-privilege scope — §7
- [x] Rollout steps after approval — §8
- [x] No remote created, no push, no tag — verified: `git remote -v` empty,
      `git tag -l` empty

---

## 11. Execution log (2026-11-03)

Executed after the board accepted the decision card on 2026-11-02T13:44:30Z.

### 11.1 Local migration

- Hygiene commit `2ae69ad`: added `/android/build/` to `app/.gitignore` and
  `git rm --cached` the 132 KB Gradle report.
- Branch renamed `master` → `main`.
- History rewritten with `git filter-branch --index-filter` over `--all`
  (`git-filter-repo` is not installed on this machine). Pre-rewrite bundle kept
  at `../mobile-app-pre-rewrite-20261103T024515.bundle`. Verified: the report
  appears in **0** commits, all 37 commits preserved, `.git` 8.2 MB → 3.8 MB.
- Workflow commit `efc7cec`: `main` trigger, `contents: read`, Flutter pinned
  `3.47.5`, `macos-26`, `concurrency` cancel-in-progress, 14-day artifact
  retention.

### 11.2 First CI run — both jobs failed (expected risk, `efc7cec`)

| Run | Result | Cause |
|---|---|---|
| [41455822486](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/41455822486) mobile | 202 passed, 65 failed | All failures 1–7 px antialiasing diffs: baselines were made on macOS 26.5.1, `macos-15` rasterises differently |
| [41455822498](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/41455822498) iOS | build failed | `connectivity_plus 7.3.1` uses `NWPath.isUltraConstrained`, an Xcode 26 SDK API; `macos-15` ships Xcode 16.4 |

### 11.3 Fix forward (`21ebbae`)

- Both jobs moved to `macos-26` (Xcode 26.6 default).
- Added `app/test/flutter_test_config.dart`: a `LocalFileComparator` subclass
  allowing ≤0.05% differing pixels (≈165 px on 390x844). Measured jitter was
  1–7 px (≤0.002%); real regressions are orders of magnitude larger.
- Local verification after the change: `flutter analyze` clean, 267/267 tests
  pass.

Green runs:

| Run | Result | Wall time |
|---|---|---|
| [41456404544](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/41456404544) mobile | analyze + 267 tests + coverage | 3m7s |
| [41456404535](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/41456404535) iOS (push) | unsigned IPA, 11.5 MB | 3m10s |
| [41456941456](https://github.com/hamishfromatech/a-coder-mobile/actions/runs/41456941456) iOS (`workflow_dispatch`) | artifact downloaded and unzipped: `Payload/Runner.app` | 2m3s |

Measured cost is below the §6.5 estimate (3 min vs 5–8 for mobile, 3 vs 8–12
for iOS).

### 11.4 Blocked: branch protection

```
$ gh api -X PUT repos/.../branches/main/protection …
403 Upgrade to GitHub Pro or make this repository public to enable this feature.
$ gh api -X POST repos/.../rulesets …
403 Upgrade to GitHub Pro or make this repository public to enable this feature.
```

GitHub does not offer branch protection or rulesets for private repositories on
the Free plan. The repo-level merge policy **was** applied: squash-only, merge
and rebase commits disabled, delete branch on merge. Required checks, review
requirements, linear history and force-push/deletion blocks remain unenforced.

Options (board decision):

1. **GitHub Pro** (~$4/month) — keeps the repo private and enables protection.
2. **Make the repo public** — enables protection for free, but D2 deferred that
   until a release and a `LICENSE`. Public + unlicensed means all rights
   reserved.

Do not treat the current `main` as protected: a direct push is possible today.

### 11.5 Not done

- `LICENSE` — deferred to the visibility decision above.
- Android compile job (§6.3) — recommended, not part of D1–D6.
- Making `unsigned-ipa` required (§6.4) — needs the guard-step pattern first.
- No tags, no releases, no signing secrets, no changes to `a-coder-cli`.

---

## 12. Follow-up execution (THE-44, 2026-11-03)

### 12.1 Branch protection — still blocked by the plan

Re-verified on 2026-11-03:

```
$ gh api repos/hamishfromatech/a-coder-mobile/branches/main/protection
403 Upgrade to GitHub Pro or make this repository public to enable this feature.
$ gh api repos/hamishfromatech/a-coder-mobile/rulesets
403 Upgrade to GitHub Pro or make this repository public to enable this feature.
```

Nothing changed: the owner is still on GitHub Free and the repo is private, so
neither branch protection nor rulesets can be enabled. No protection settings
were applied; `main` remains directly pushable. The repo-level merge policy is
still squash-only, merge/rebase disabled, delete-branch-on-merge. Enabling the
§5 settings needs a board decision (§12.5).

### 12.2 LICENSE — pending board decision

`LICENSE` is still absent. Private + unlicensed is all-rights-reserved, which is
the correct default while the product is unreleased, but it must be resolved
before any public switch or binary distribution. The sibling `a-coder-cli` repo
uses MIT plus A-Tech dual-license distribution terms; mirroring that is the
consistent option. The choice is a board decision (§12.5) and was deliberately
not made unilaterally.

### 12.3 Android compile job — added

Implemented locally (THE-44 commit, pending push approval, §12.5).
`.github/workflows/mobile.yml` now has an `android` job:

- `runs-on: ubuntu-latest` — Linux minutes bill 1× (macOS bills 10× on a
  private repo).
- Flutter pinned `3.47.5`, `cache: true`.
- `cd app && flutter pub get && flutter build apk --debug`.

`--debug` needs no signing material, so this is a real compile check without
touching the release-signing gate. Local proof: `flutter build apk --debug`
succeeded on 2026-11-03 (§12.6); the CI run supplies the runner proof once the
commit is pushed.

Do not require it until it has passed on `main`. With protection unavailable
(§12.1), the "required" half cannot be configured yet.

### 12.4 iOS required check — guard added

Implemented locally (THE-44 commit, pending push approval, §12.5).
`.github/workflows/ios.yml` now:

- triggers on `pull_request` to `main` **without** a `paths:` filter, so the
  check can never stay pending;
- runs a cheap `changes` gate on `ubuntu-latest` that diffs the PR base/head for
  `app/ios`, `app/pubspec.yaml`, `app/pubspec.lock`, `app/lib`, and the workflow
  file, and always concludes;
- runs `unsigned-ipa` only when the gate reports `ios=true`. A job skipped by an
  `if` reports "Success" to GitHub, so the required check is satisfied without
  spending macOS minutes on Dart-only PRs.

The `push` trigger keeps its `paths:` filter and `workflow_dispatch` always
builds. Once branch protection is available, `iOS build / unsigned-ipa` can be
added as required.

### 12.5 Decisions requested from the board

1. **Branch protection path** — **resolved 2026-11-02T14:17:49Z: make the repo
   public.** Executed 2026-11-03; see §13. The LICENSE caution attached to this
   option was overridden, so §12.2 remains open.
2. **LICENSE** — mirror the `a-coder-cli` MIT + A-Tech dual license vs. MIT
   only vs. proprietary/all-rights-reserved vs. defer.
3. **Push approval** — approve pushing the THE-44 CI/doc commits to
   `origin/main` (ordinary push; no tag, release, signing secret, or
   force-push).

### 12.6 Measured timings and revised cost

Real GitHub-hosted job durations (not estimates):

| Job | Run | Duration |
|---|---|---|
| `mobile / flutter` | 41456404544 | 3 m 03 s |
| `mobile / flutter` | 41457354803 | 1 m 21 s |
| `iOS build / unsigned-ipa` | 41456404535 | 3 m 03 s |
| `iOS build / unsigned-ipa` (dispatch) | 41456941456 | 1 m 58 s |

§6.5 assumed 5–8 min (mobile) and 8–12 min (iOS). Measured is ~2–3 min each, so
the illustrative 10-PR + 10-push month is far cheaper than the earlier
$18–20/month figure:

- macOS: 10 PRs × 3 min + 10 pushes × (3 min flutter + 3 min iOS) = 90 raw
  minutes → **900 billed minutes** at the 10× multiplier.
- Linux (`android`): ~20 × 4 min ≈ **80 billed minutes** at 1×.

≈ 980 billed minutes/month — inside the 2,000-minute Free allowance, i.e. ≈ $0
at this schedule. The billing page remains authoritative. The Actions billing
API needs the `user` OAuth scope, which the current CLI token does not have:

```
gh auth refresh -h github.com -s user   # human, interactive
gh api /users/hamishfromatech/settings/billing/actions
```

The first green `android` run replaces the ~4 min estimate with a measurement.

---

## 13. Execution: public visibility and branch protection (2026-11-03)

### 13.1 Decision

The board answered the §11.4 / §12.5 protection question with **"Make the repo
public now"** (`protection_path = public`, 2026-11-02T14:17:49Z). That overrides
D2 (private) for now. The repo is therefore public and still unlicensed, which
under default copyright is all-rights-reserved — see §13.5.

### 13.2 Pre-flight

Before the visibility switch the tracked tree and full history were scanned for
credentials:

```
$ git ls-files | grep -Ei '\.env|secret|credential|key\.properties|\.jks$|\.keystore$|\.pem$|\.p12$|token'
(no matches)
$ git log --all -p | grep -Eni '(gho_|ghp_|sk-|AKIA|BEGIN .*PRIVATE KEY)'
(no matches)
```

No secrets, keystores, or environment files are tracked in any commit.

### 13.3 Actions

```
$ gh repo edit hamishfromatech/a-coder-mobile \
    --visibility public --accept-visibility-change-consequences
$ gh api -X PUT repos/hamishfromatech/a-coder-mobile/branches/main/protection \
    --input protection.json
```

Protection applied to `main`:

| Setting | Value |
|---|---|
| Required status checks | `mobile / flutter` |
| Require branch up to date (`strict`) | yes |
| Required approving reviews | 1 |
| Dismiss stale approvals | yes |
| Require approval of most recent push | yes |
| Require conversation resolution | yes |
| Require linear history | yes |
| Enforce for administrators | yes |
| Allow force pushes | no |
| Allow branch deletion | no |
| Signed commits | not required |

`dismissal_restrictions` must be **omitted** for a user-owned repository;
sending it returns `422 Only organization repositories can have users and team
restrictions`. The rest of the payload is unchanged from §5.

### 13.4 Verification (read back after the write)

```
$ gh repo view hamishfromatech/a-coder-mobile --json visibility,isPrivate
{ "visibility": "PUBLIC", "isPrivate": false }
$ gh api repos/hamishfromatech/a-coder-mobile/branches/main --jq .protected
true
$ gh api repos/hamishfromatech/a-coder-mobile/branches/main/protection --jq '{...}'
checks: ["mobile / flutter"]  strict: true
reviews: 1  stale: true  last_push: true
enforce_admins: true  linear: true
force_push: false  deletions: false  conversations: true
```

Local suite is unaffected by a metadata-only change:

```
cd app && flutter analyze  → No issues found! (1.5s)
cd app && flutter test     → 267 tests, All tests passed! (7s)
```

### 13.5 Consequences and remaining work

- **Public Actions minutes are free** on standard runners, so the §12.6 cost
  question disappears for `ubuntu-latest` and `macos-26`. The 10× macOS
  multiplier no longer applies.
- **`main` is no longer directly pushable, including for the owner**
  (`enforce_admins: true`). Every change now needs a branch, a PR, one human
  approval, and a green `mobile / flutter`. That is the intended model but it
  is a real workflow change for a single-maintainer repo.
- **Only `mobile / flutter` is required** because it is the only check that
  exists on `origin/main` today. `mobile / android` and
  `iOS build / unsigned-ipa` stay advisory until `b37bc3a` lands and both pass
  on `main`; only then should they be appended to `required_status_checks`.
  Requiring them now would leave PRs waiting on checks that never start.
- **`b37bc3a` (`ci: prove Android compiles and gate the iOS PR check`) is
  still local only.** It needs board approval to push a branch and open a PR.
  After it merges and both new jobs pass, add them as required with
  `gh api -X PUT .../protection/required_status_checks` or the
  `branches/main/protection` payload above.
- **`LICENSE` is still absent** (§12.2). Public + unlicensed is legally
  all-rights-reserved, which is workable but inconsistent with an open
  repository. The sibling `a-coder-cli` uses MIT plus A-Tech dual-license
  distribution terms; choosing it remains a board decision. Do this before any
  binary distribution or outside contribution is solicited.
- No tags, no releases, no signing secrets, and no changes in `a-coder-cli`.
