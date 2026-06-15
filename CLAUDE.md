# CLAUDE.md — claude-harness

The shared, **stack-agnostic, Claude-Code-only** harness reused by every JDSavvy repo. This file grounds
any work done **on this repo**. The plugin here propagates to **every** consuming project, so changes are
**high blast radius** — treat them with care and validate before committing.

## What this repo is

A plugin **marketplace** (`.claude-plugin/marketplace.json`) holding one plugin, `harness`
(`plugins/harness/`): shared **skills**, generic **subagents**, and generic **SessionStart hooks**.
See `README.md` for the layout and `docs/HARNESS-SETUP.html` for how it's installed and used
(GitHub = source of truth → one local clone in `~/.claude/plugins/` → every project uses that copy).

## Hard rules (non-negotiable)

1. **Stay stack-agnostic.** No project/language/framework assumptions (no pnpm/Next/Supabase/etc.) in any
   skill, agent, or hook. Project-specific logic lives in each consumer's `.claude/` — never here.
2. **Version is single-sourced** in `plugins/harness/.claude-plugin/plugin.json`. **Never** add `version`
   to the marketplace entry — Claude Code lets `plugin.json` win and the two silently drift.
3. **Hooks must be safe in every repo:** offline-safe, worktree-safe, fast, **always `exit 0`**, never
   mutate state except the documented `merge --ff-only` path, and offer an opt-out env var. Portable to
   macOS **bash 3.2** (no `timeout`/`gtimeout`, no `jq`).
4. **Validate before commit.** Run `bash scripts/validate.sh` (wired as a pre-commit hook — see below).
   Never commit a hook that fails the gate; it breaks every repo.
5. **Lean / scope-fence.** Add only what genuinely serves every repo. **No GitHub CI compute** (cost) —
   quality runs locally. No deps, no build step; keep the repo a thin, auditable set of text files.

## How to extend

- **New skill:** `plugins/harness/skills/<name>/SKILL.md` (frontmatter `name` + `description`). Keep it generic.
- **New subagent:** `plugins/harness/agents/<name>.md`.
- **New hook:** add a script under `plugins/harness/hooks/`, register it in `hooks/hooks.json`, give it an
  opt-out env var + a watchdog if it does I/O, and add a behavior test under `tests/`.
- After any meaningful change, cut a release with **`/release-harness`** (validate → bump `plugin.json` →
  update `CHANGELOG.md` → Conventional Commit + tag). Consumers pick it up via `autoUpdate` or
  `/plugin marketplace update claude-harness`.

## Quality gate (local, zero GitHub cost)

`bash scripts/validate.sh` checks: JSON manifests parse · version is single-sourced · `bash -n` on every
hook · `shellcheck` (if installed) · `claude plugin validate` (if installed) · the hook behavior tests in
`tests/`. It is wired as a git **pre-commit** via `.githooks/`. **Enable once per clone:**

```
bash scripts/setup.sh            # or: git config core.hooksPath .githooks
```

Bypass a single commit in an emergency with `git commit --no-verify`.
