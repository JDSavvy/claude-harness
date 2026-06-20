---
name: plan-change
description: >-
  Produce a structured, in-session implementation PLAN for a change before you build it — orientation →
  what to check first → technical & design changes → validation strategy → risk/approval class → whether
  a branch/issue/PR is needed. Use when the user wants a plan, approach, or strategy BEFORE implementing —
  e.g. "plan how to change X", "how should I approach X", "map out the steps to do X", "give me a plan for
  X before coding", "orient me on X", "plane die Umsetzung von X", "wie gehe ich X an". Output is a Markdown
  plan artifact in the conversation only: it writes NO code, opens NO branch/PR, and creates NO GitHub
  issue. Distinct from /create-issue (which persists a formal GitHub issue spec for later/handoff) and
  /finish-pr (which completes an existing PR) — this skill just plans the work you then implement yourself.
  Stack-agnostic: it grounds the plan in the repo's CLAUDE.md, existing skills/hooks/agents, and the
  harness Risk & Approval classes.
argument-hint: "<change to plan>"
---

# plan-change — orient and plan a change (no code, no git)

Turn a natural request like **"change the app's font to `examplefont`"** into a concrete, reviewable
**plan** for *this* repo: where to look, what to touch, how to prove it works, what risk class it carries,
and how it reaches a PR. **The plan is the only artifact.** Implementing it is a separate step the owner
runs afterwards — this skill never edits code, never opens a branch/PR, never files an issue.

It is project-neutral: it reads the current repo's `CLAUDE.md` and conventions and adapts to whatever the
stack is (Swift, Next.js, Python, Go, …) instead of assuming one.

## Boundaries — when this is NOT the right skill

- **`/create-issue`** persists a formal, research-backed **GitHub issue** (a spec for later or for handoff).
  `plan-change` produces a lightweight **in-session** plan you act on immediately — no issue is created.
- **`/finish-pr`** drives an **existing PR** to merge-ready. `plan-change` runs *before* any branch exists.
- This skill makes **no mutation of any kind** (no files, no `git`/`gh`). If the user wants the change
  *done*, plan it here, then implement it as a separate step.

## Procedure

### 1. Orient — map the change onto this repo
Read the relevant `CLAUDE.md` sections, then inventory what already exists so the plan reuses it rather
than reinventing it:
- The repo's **conventions / hard rules / architecture** that bear on this change.
- Existing **skills, hooks, subagents** that already cover part of the work.
- The **stack** (detect via `package.json` / `*.xcodeproj` / `Cargo.toml` / `go.mod` / `pyproject.toml`).
- The **files/modules** the change most likely touches.

### 2. Check first — verify the ground before planning edits
List what must be confirmed *in the project* before changing anything: where the thing actually lives,
the current pattern for it, prior art, and any convention the change must respect. **Verify empirically**
(read the files, run `--version`, grep for the symbol) — never assert structure or absence from memory.

### 3. Technical + design changes
Spell out the concrete work in two lanes:
- **Technical:** the specific edits/additions (files, config, dependencies, interfaces) the change needs.
- **Design / UX:** the gestalt decisions (tokens, theming, layout, copy, accessibility) — even a "small"
  change like a font swap usually has a design side (fallback stack, weights, licensing, asset loading).

### 4. Validation strategy
State exactly how the change will be **proven** — defer to the repo's own gate (the lint/build/test
commands in `CLAUDE.md` / package scripts / CI), name which **tests** must exist or change, and how to
**observe the behaviour** (run the app / a visual check) so the result is verified, not assumed.

### 5. Risk & approval class
Classify the change — **autonomous when safe + reversible**, **stop-and-flag** when it touches: **(a)**
secrets/credentials (never commit, log, or client-expose them), **(b)** irreversible git ops (force-push,
history rewrite on a published branch, branch deletion), **(c)** irreversible DB/infra (drops, mass
deletes, resource deletion), **(d)** externally-visible/production actions (deploys, releases, publish).
Also fold in any **project-specific** risk rules from the repo's `CLAUDE.md`. If intent is ambiguous or
context is missing, say so and **stop-and-flag** rather than plan on a guess.

### 6. Delivery path
Say whether/when a **branch, commit, issue, PR, or review** is needed for this change, and point at the
**universal Definition of Done** the implementation must satisfy and verify: repo gate green, tests that
bite, conventional commit, docs updated where needed, no secret leak, acceptance criteria met **and
checked** (plus any stricter per-repo criteria in the repo's `CLAUDE.md`).

## Output — the plan artifact

Emit one Markdown plan with these sections (drop a section only if it genuinely doesn't apply, and say so):

```
## Plan: <change>

### Orientation
- Relevant CLAUDE.md / conventions: <…>
- Existing skills/hooks/agents to reuse: <…>
- Stack: <detected> · Likely files/modules: <…>

### Check first
- <what to confirm in the repo before editing — verified, not assumed>

### Changes
- Technical: <concrete edits/additions>
- Design / UX: <gestalt decisions>

### Validation
- Gate: <the repo's real lint/build/test commands>
- Tests: <which to add/update> · Observe: <how to see it work>

### Risk & approval
- Class: <safe-autonomous | stop-and-flag (a/b/c/d)> — <why>

### Delivery
- Branch/commit/issue/PR/review: <what's needed, in order> · DoD: <the done bar>
```

## Guardrails
- **Plan only** — zero file edits, zero `git`/`gh` mutations. The deliverable is the plan, nothing else.
- **Verify before asserting**, including negative claims ("there's no such file/config") — check the live
  source of truth, never memory.
- **Stack-agnostic** — read the repo's `CLAUDE.md`; never hardcode a package manager, framework, or runner.
- **Stop-and-flag, don't guess** — if the request is unclear, contradictory, or under-specified, ask
  instead of planning on assumptions.
