---
name: create-issue
description: >-
  Turn a declared goal into a research-backed, current-best-practice GitHub issue — a clean, complete
  spec ready to implement however you later choose to pick it up. Use when the user wants a task,
  feature, fix, or change written up as a persisted GitHub issue/spec (NOT implemented yet) — e.g.
  "create an issue for X", "/create-issue", "draft an implementation brief / spec", "spec out X",
  "erstelle ein Issue / eine Spec für X", "Task/Implementierungs-Spec vorbereiten". Fetches today's date,
  researches the latest best practices for the requirement (pins versions empirically), asks ONLY the
  questions that genuinely need the owner (the rest is decided from research + the codebase), then writes
  a complete GitHub issue. Makes NO code changes — never touches the working tree, branches, or opens a
  PR. Distinct from /plan-change, which produces an in-session plan artifact and creates NO GitHub issue;
  use this only when the deliverable is a persisted issue. Stack-agnostic: reads the repo's CLAUDE.md.
argument-hint: "<goal>"
---

# create-issue — Goal → researched, BP-current GitHub issue

Turn the user's declared goal into one complete, detailed **GitHub issue**. **This skill never edits
code, never opens a branch, never implements** — its only artifact is the issue. It is project-neutral:
it grounds itself in the current repo's `CLAUDE.md` and conventions, whatever the stack.

An issue declares *what* to build and *why*. **How** it gets implemented afterwards is entirely the
owner's choice — implement it yourself, run `/harness:finish-pr` on a PR, mention an automation bot on
the issue, or anything else. That decision is out of scope here, so this skill makes no assumption about
it: it produces a reviewable spec and stops.

## Procedure

### 1. Anchor on today
Run `date +%Y-%m-%d` and use that date for (a) judging best-practice currency and (b) stamping the
issue. Never assume the date from memory.

### 2. Understand the goal & the codebase
Read the declared goal and any notes. Skim the relevant code/docs (`CLAUDE.md`, the touched area) so
the spec is grounded in *this* repo's architecture and conventions — not generic advice. Detect the
stack (e.g. `package.json` / `*.xcodeproj` / `Cargo.toml` / `go.mod`) and use its real build/test
commands in the verification section.

### 3. Research current best practices (empirical, no hallucination)
Use WebSearch/WebFetch to find the **latest** best practices for the requirement as of today. Prefer
**primary/official sources** (vendor docs, framework guides, standards). Cross-check claims and cite
source URLs in the issue. If something can't be verified, say so explicitly rather than inventing it.
Resolve every decision you *can* from research + the codebase here — so the user is only asked what
truly needs them.

### 4. Ask ONLY owner-must-answer questions
Use `AskUserQuestion` for the few decisions research and the code genuinely cannot settle:
product/scope tradeoffs, priorities, preferences, credentials, irreversible or cost/risk choices,
anything contradicting an existing convention. Batch them; offer a recommended option first. **Do not
ask anything the research or the repo already answers.** If nothing genuinely needs the user, skip this
step and say why.

### 5. Write the issue (no code)
Compose a complete spec and create it with `gh issue create` (use `--label` if sensible). Body:

```
## Goal
<what & why, 2–4 sentences, grounded in this repo>

## Acceptance criteria
- [ ] <verifiable outcome>
- [ ] <…>
- [ ] Tests added/updated per CLAUDE.md conventions
- [ ] All the repo's quality gates pass (lint, typecheck, format, unit/e2e — whatever CLAUDE.md / the package scripts define)

## Scope
- In: <areas/files>
- Out: <explicitly excluded — separate issues>

## Best-practice notes (as of <today>)
- <decision> — rationale + source URL
- <flagged uncertainty, if any>

## Decisions (resolved with the owner)
- <question> → <chosen answer>

## Verification
- <how to prove it works: the repo's real build/test/lint commands, manual steps>

## Engineering rules
- General solution — implement for all valid inputs; do not hard-code to the tests.
- **Never weaken, skip, or delete tests** to go green — fix the cause.
- No over-engineering — build exactly this scope; no speculative abstractions.
- Read the referenced files before asserting anything about them.
```

### 6. Hand off
Print the created issue URL and a one-line summary of what it covers. **Do not implement** — the spec is
the deliverable; picking it up is the owner's call.

## Guardrails
- **Spec only** — zero code/file edits beyond creating the issue.
- **Keep the issue review-first** — don't embed an auto-trigger mention (e.g. an automation bot's
  keyword) in the issue *body*; many repos fire an action on such mentions in `issues.opened`, which
  would start implementation before the spec is reviewed. If the owner wants automation, they add the
  trigger themselves after review.
- **Lean & honest** — concise spec; cite sources; mark unverified claims; don't pad.
- Requires `gh` (authenticated) and network for research.
