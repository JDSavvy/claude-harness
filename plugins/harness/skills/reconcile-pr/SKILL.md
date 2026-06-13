---
name: reconcile-pr
description: >-
  Bring an existing pull request back in sync with reality, then implement the update autonomously.
  Use when a PR has gone stale or the world moved under it — e.g. "reconcile this PR", "/reconcile-pr",
  "update/refresh the PR", "bring the PR up to date with main", "sync this PR with main", "resolve the
  PR's conflicts", "the linked issue changed, update the PR", "fix the PR's failing CI / review threads",
  "PR aktualisieren", "PR ist veraltet — neu ausrichten", "PR mit main abgleichen". Detects four drift
  triggers — base-branch drift/conflicts, a changed linked issue/spec, changed related APIs/code outside
  the PR, and failing CI + open review threads — resolves them by MERGING base into the PR branch (never
  rebasing a published PR), implements the needed changes, re-verifies against the repo's quality gate,
  and pushes ONCE. Autonomous (no confirm gate) but stops and flags on the defined unsafe conditions.
  Stack-agnostic: reads the repo's CLAUDE.md for the real build/test/lint commands. NEVER pushes to the
  default branch.
---

# reconcile-pr — detect drift, re-align a PR, implement, verify, push

Take one open pull request and make it current again: detect what changed under it, reconcile the PR
branch, implement the required updates, re-verify, and push a single time. Project-neutral — it grounds
itself in the current repo's `CLAUDE.md` and stack. It runs identically **locally** (`/harness:reconcile-pr <PR#>`)
and **via the `@claude` GitHub Action** (comment naming this skill), so the sequence below is the one
canonical order on both surfaces.

The owner chose **implement-directly (no confirm gate)** — so you reconcile and push without asking, BUT
the **Stop-and-flag** rules below are hard guardrails: when one trips, you post a comment and stop instead
of guessing. Autonomous ≠ reckless.

## Invariants (never violate)
- **Never push to the default branch** (`main`/`master`); operate only on the PR's own head branch.
- **Never rebase a published PR** and **never `git push --force`** a shared branch. Use a plain push, or
  `--force-with-lease` only if a rewrite is truly unavoidable (a concurrent push must abort you, not be
  overwritten).
- **Merge, don't rebase**, to integrate the base — this keeps reviewer commits and review-comment anchors
  intact and makes re-runs idempotent (already-merged base commits are no-ops).
- **Preserve others' work**: always fast-forward the local copy from the remote head first.

## Procedure

### 1. Anchor on the PR & the repo
Resolve the target PR (from the argument, the `@claude` PR context, or ask if ambiguous). Pull its state:
```
gh pr view <PR#> --json number,headRefName,baseRefName,headRefOid,mergeable,mergeStateStatus,\
reviewDecision,statusCheckRollup,closingIssuesReferences,createdAt,isDraft,author
```
Read the repo's `CLAUDE.md` (build/test/lint commands, conventions, scope rules). `git config rerere.enabled true`.

### 2. Refresh remote state (don't clobber)
`git fetch origin`, check out the PR head, then `git merge --ff-only origin/<headRefName>` (or `gh pr checkout <PR#>`
followed by an ff-only pull) so any reviewer/co-author/other-bot commits are preserved. Record `headRefOid` —
if it changes under you later, a concurrent push happened → **stop-and-flag**.

### 3. Detect the four drift triggers
- **(a) Base drift / conflicts** — `mergeStateStatus` ∈ {`BEHIND`,`DIRTY`}, or `git merge-base --is-ancestor
  origin/<base> HEAD` is false. Probe conflicts **without mutating** the tree: `git merge-tree --write-tree
  origin/<base> HEAD` (non-zero + lists conflicted paths on conflict). `git rev-list --left-right --count
  origin/<base>...HEAD` quantifies ahead/behind.
- **(b) Spec drift** — from `closingIssuesReferences` get the linked issue; `gh issue view <id> --json
  updatedAt,title,body`. If `updatedAt` is newer than the PR's `createdAt` (or your last reconcile marker),
  diff the spec for substantive changes (acceptance criteria, scope).
- **(c) External-code drift** — `git diff origin/<base>...HEAD --name-only` = files the PR owns; for symbols
  the PR *calls but doesn't define* (imports, signatures, models/DTOs, shared helpers), compare their current
  signature in the post-merge tree to what the PR was written against. On compiled stacks the build (trigger d)
  is the real backstop.
- **(d) CI + reviews** — `gh pr checks <PR#> --json bucket,state,name,link` (any `bucket==fail`; exit code 8
  ⇒ checks still pending → wait, don't act). Open threads: `gh pr view --json reviewDecision,latestReviews`
  plus unresolved review-comment threads (GraphQL `reviewThreads(isResolved:false)` or REST
  `GET .../pulls/<PR#>/comments`).

### 4. Resolve — in this exact order
1. **Integrate base via merge** (not rebase): `git merge origin/<base>`; with `rerere` on, resolve conflicts
   **only inside the PR's own files**; commit the merge.
2. **Re-align to the changed spec** (b): implement substantive deltas.
3. **Repair external-API drift** (c): update call sites to the new signatures/contracts.
4. **Fix CI** (d): `gh run view --log-failed` on the failing job, fix the cause — **never weaken, skip, or
   delete a test to go green**.
5. **Address open review threads** (d): push a fix; reply to / resolve only threads the change truly fixes.

### 5. Verify
Run the repo's real quality gate from `CLAUDE.md` (lint + typecheck/build + tests; mirror CI, e.g. strict
linters). **iOS/Xcode caveat:** a Linux runner cannot build the app — defer real build/test to the repo's
**macOS CI** (push-then-watch-CI), not a local green-before-push. For web/TS stacks verify locally/in Linux CI.

### 6. Push once & report
Push the head branch **once** (plain push, or `--force-with-lease` only if unavoidable; **never** bare
`--force`, **never** to the default branch). Post **one** concise PR comment summarizing what was reconciled
(which triggers fired, what changed, CI/verification status). Idempotent: a re-run with nothing new is a no-op.

## Stop-and-flag (post a comment, do NOT proceed) when
- A merge conflict reaches into code **outside the PR's own files**.
- The linked **spec/issue changed in a way that alters intent or acceptance criteria** (not just typos).
- A **human or other bot committed onto the PR head** you would otherwise overwrite (`headRefOid` moved).
- A **CI failure looks environmental/flaky** rather than caused by the diff.
- `mergeStateStatus`/`mergeable` is `UNKNOWN`/`null` (GitHub still computing) — **re-poll**, don't guess.
- Required context (the linked issue, a CI log) **can't be read**.

## Run it on both surfaces
- **Locally (macOS):** `/harness:reconcile-pr <PR#>`.
- **Via `@claude` (phone/web ok):** comment on the PR, naming the skill, e.g.
  `@claude run the harness:reconcile-pr skill on this PR`. The action loads the plugin, so this is the same
  skill and the same sequence — only the trigger surface differs.

## Guardrails
- Stack-agnostic: do detection with shell `git`/`gh`; defer verification to the repo's `CLAUDE.md` gate.
- The `@claude` action can push commits and reply to reviews but has **no built-in rebase/conflict engine** —
  drive every git/gh step explicitly here.
- Requires `gh` (authenticated) and a checkout of the repo with `origin` set.
