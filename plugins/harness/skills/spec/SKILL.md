---
name: spec
description: >-
  Turn a declared goal into a research-backed, current-best-practice GitHub issue spec that is ready
  for @claude to implement autonomously. Use when the user wants to declare/plan a task, feature, fix,
  or change and have a clean spec/issue prepared (NOT implemented yet) — e.g. "spec out X", "/spec",
  "/spec-it", "create a task/issue/PR for X", "plan X for @claude", "draft an implementation brief",
  "erstelle eine Spec", "Task/Implementierungs-Spec vorbereiten", "ich will X umsetzen". Fetches today's
  date, researches the latest best practices for the requirement (pins versions empirically), asks ONLY
  the questions that genuinely need the owner (the rest is decided from research + the codebase), then
  writes a complete GitHub issue. Makes NO code changes — never touches the working tree, branches, or
  opens a PR. Stack-agnostic: it reads the repo's CLAUDE.md to ground itself in that project.
---

# spec — Goal → researched, BP-current GitHub issue (ready for @claude)

Turn the user's declared goal into one complete, detailed **GitHub issue** that `@claude` can later
implement autonomously. **This skill never edits code, never opens a branch, never implements** — its
only artifact is the issue. It is project-neutral: it grounds itself in the current repo's `CLAUDE.md`
and conventions, whatever the stack.

Why an issue (not a PR): an issue declares *what* to build. After it exists, the user comments
**`@claude`** on it; the Claude GitHub Action reads the issue **and `CLAUDE.md`**, then opens an
implementation PR.

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

---
Ready for autonomous implementation — the owner starts it with the hand-off comment printed after creation.
```

### 6. Hand off
Print the created issue URL and the exact comment to paste (`@claude implement this per the spec and
CLAUDE.md; open a PR with tests`). The issue **body** itself stays `@claude`-free (see Guardrails) — the
manual comment is the trigger, so the owner reviews the spec first. Do not implement.

## Guardrails
- **Never put the literal `@claude` in the issue BODY.** Repos commonly fire the action on `@claude` in
  `issues.opened`, so a body mention auto-starts implementation *before* the owner reviews the spec —
  defeating the spec-first intent. The trigger is the manual hand-off COMMENT (step 6), posted after review.
- **Spec only** — zero code/file edits beyond creating the issue.
- **Lean & honest** — concise spec; cite sources; mark unverified claims; don't pad.
- Requires `gh` (authenticated) and network for research.
