# Repo hosting proposal — `mobile-app`

**Status:** proposal, awaiting board decision (THE-43)
**Date:** 2026-11-03
**Owner:** Flutter Expert
**Nothing in this document has been executed.** No remote was created, nothing was
pushed, no tags exist.

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
