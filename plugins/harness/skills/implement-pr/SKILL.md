---
name: implement-pr
description: >-
  Take a pull request that's mentioned with this skill and drive it to a merge-ready, done state —
  implement and fix whatever it needs. Use when you want Claude to actually BUILD/COMPLETE a PR, not just
  inspect it — e.g. "implement this PR", "/implement-pr", "finish this PR", "take this PR and make it done",
  "address & fix this PR", "@claude implement this PR", "nimm dir diesen PR vor und setze ihn um", "PR fertig
  implementieren", "PR umsetzen/beheben". As a built-in PRE-STEP it first reconciles the PR against drift
  (base-branch drift/conflicts, a changed linked issue/spec, changed related APIs/code outside the PR,
  failing CI + open review threads) by MERGING base into the PR branch (never rebasing a published PR) — so
  the work is built on current ground — and only THEN implements the PR's intent to completion, re-verifies
  against the repo's quality gate, and pushes ONCE. Autonomous (no confirm gate) with hard stop-and-flag
  guardrails. Stack-agnostic: reads the repo's CLAUDE.md. NEVER pushes to the default branch.
---

# implement-pr — bring a mentioned PR to done (reconcile first, then implement)

**Primary job:** given one PR (named with this skill), **implement and fix it until it fully delivers its
intent and is merge-ready**. Re-aligning the PR against drift is the necessary **pre-step (preflight)**, not
the goal — you do it first so you build on the current state of the world, then you do the real work: finish
the implementation, make CI green, resolve review threads.

Runs identically **locally** (`/harness:implement-pr <PR#>`) and **via the `@claude` GitHub Action** (comment
naming this skill), so the sequence below is the one canonical order on both surfaces.

Owner chose **implement-directly (no confirm gate)** — reconcile and implement without asking, BUT the
**Stop-and-flag** rules are hard guardrails. Autonomous ≠ reckless.

## Invariants (never violate)
- Never push to the default branch (`main`/`master`); operate only on the PR's own head branch.
- Never rebase a published PR; never `git push --force` a shared branch (use `--force-with-lease` only if a
  rewrite is unavoidable). **Merge, don't rebase**, to integrate base — preserves reviewer commits/anchors
  and makes re-runs idempotent.
- Always fast-forward the local copy from the remote head first (preserve others' commits).
- **Never weaken, skip, or delete tests** to go green — fix the cause.

## Procedure

### 1. Understand what "done" means for this PR
Resolve the target PR (argument / the `@claude` PR context / ask if ambiguous). Read its title + body, the
linked issue/spec, and the repo's `CLAUDE.md`:
```
gh pr view <PR#> --json number,headRefName,baseRefName,headRefOid,mergeable,mergeStateStatus,\
reviewDecision,statusCheckRollup,closingIssuesReferences,createdAt,isDraft
gh issue view <linked-id> --json title,body,updatedAt
```
From these derive the PR's **intent + acceptance criteria** — the done state you're driving toward.
`git config rerere.enabled true`.

### 2. Preflight: reconcile against drift (the pre-step, so you build on current ground)
- **Refresh** — `git fetch origin`; check out the PR head; `git merge --ff-only origin/<head>` to keep any
  reviewer/co-author/bot commits. Record `headRefOid` (if it moves under you later → stop-and-flag).
- **Base drift/conflicts** — `mergeStateStatus` ∈ {`BEHIND`,`DIRTY`} or `git merge-base --is-ancestor
  origin/<base> HEAD` false; probe non-destructively with `git merge-tree --write-tree origin/<base> HEAD`.
  Resolve by **merging** base into the head (`git merge origin/<base>`, rerere on), conflicts only in the
  PR's own files.
- **Spec drift** — linked issue `updatedAt` newer than the PR's `createdAt` ⇒ fold the new requirements
  into the target.
- **External-API drift** — for symbols the PR calls but doesn't define (signatures, models/DTOs, shared
  helpers), note the current contracts in main to build against (the build/typecheck is the backstop).
- **CI + reviews** — `gh pr checks <PR#> --json bucket,state` (any `bucket==fail`; exit 8 ⇒ pending, wait)
  and open `reviewThreads(isResolved:false)` ⇒ collect what must be fixed.

### 3. Implement the PR to done (the main job)
Build out everything the PR's intent + acceptance criteria require that isn't finished yet; fix the cause of
every failing check; implement what each open review thread asks. Follow the repo's `CLAUDE.md` conventions
and add/update tests per them. **This is the deliverable — a complete, correct, merge-ready PR**, not just a
re-aligned one.

### 4. Verify
Run the repo's real quality gate from `CLAUDE.md` (lint + typecheck/build + tests; mirror CI, e.g. strict
linters). **iOS/Xcode caveat:** a Linux runner cannot build the app — defer real build/test to the repo's
**macOS CI** (push-then-watch-CI). Web/TS stacks: verify locally / in Linux CI.

### 5. Push once & report
Push the head branch **once** (plain push; `--force-with-lease` only if unavoidable; **never** bare
`--force`, **never** the default branch). Post **one** concise PR comment: what was reconciled, what was
implemented, CI/verify status, and anything still open.

## Stop-and-flag (post a comment, do NOT proceed) when
- The PR's **intent is unclear/underspecified** and neither the linked issue nor `CLAUDE.md` resolves it.
- A merge conflict reaches into code **outside the PR's own files**.
- The linked **spec changed in a way that alters intent or acceptance criteria** (not just typos).
- A **human or other bot committed onto the PR head** you would overwrite (`headRefOid` moved).
- A **CI failure looks environmental/flaky** rather than caused by the diff.
- `mergeStateStatus`/`mergeable` is `UNKNOWN`/`null` (GitHub still computing) — **re-poll**, don't guess.
- Required context (the linked issue, a CI log) **can't be read**.

## Run it on both surfaces
- **Locally (macOS):** `/harness:implement-pr <PR#>`.
- **Via `@claude` (phone/web ok):** comment on the PR, naming the skill, e.g.
  `@claude run the harness:implement-pr skill on this PR`. The action loads the plugin, so this is the same
  skill and the same sequence — only the trigger surface differs.

## Guardrails
- Stack-agnostic: do detection with shell `git`/`gh`; defer verification to the repo's `CLAUDE.md` gate.
- The `@claude` action can push commits and reply to reviews but has **no built-in rebase/conflict engine** —
  drive every git/gh step explicitly here.
- Requires `gh` (authenticated) and a checkout of the repo with `origin` set.
