# CLAUDE.md — claude-harness

The shared, **stack-agnostic, Claude-Code-only** harness reused by every JDSavvy repo. This file grounds
any work done **on this repo**. The plugin here propagates to **every** consuming project, so changes are
**high blast radius** — treat them with care and validate before committing.

## What this repo is

A plugin **marketplace** (`.claude-plugin/marketplace.json`) holding one plugin, `harness`
(`plugins/harness/`): shared **skills**, generic **subagents**, and generic **SessionStart hooks**.
See `README.md` for the layout and `docs/HARNESS-SETUP.html` for how it's installed and used
(GitHub = source of truth → one local clone in `~/.claude/plugins/` → every project uses that copy).

## Universal Harness Contract (two-layer model)

The agreed architecture that **this repo and every consuming project** follow. It exists so multiple
people/sessions can evolve the harness **in parallel** without drift, redundancy, or context-mixing, and
so the harness stays **truly framework-independent** (Swift, Next.js, Python, Go, …).

### The deciding rule

**Framework-independence test:** _Would this break on a Swift / Python / Go repo?_

- **No** → it's universal → lives in the **plugin** (this repo).
- **Yes** (it names `pnpm`/Next/`tsc`/`swift`/`pip`/a specific runner, …) → it's stack-specific → lives
  **per-repo** in that project's `.claude/`.

### Two layers

1. **Universal core — the plugin (`plugins/harness/`), one copy per machine.** Pure git/workflow logic,
   zero stack assumptions: `session-git-sync`, `harness-update-check`, `/spec`, `/implement-pr`,
   `/release-harness`, and the generic `code-reviewer` + `test-runner` (which read each repo's CLAUDE.md).
2. **Stack adapter — each project's committed `.claude/` (its "subharness").** Everything stack-specific:
   formatter, linter, dependency install, the quality-gate _commands_, project skills, specialized
   subagents, and the project `CLAUDE.md`.

### Element rulings (canonical — do not re-litigate per repo)

- **git-sync / update-check → plugin only.** A project must **not** ship its own `session-git-sync.sh`
  — that duplicates the plugin and re-introduces the drift we removed. Projects opt in via their
  `.claude/settings.json` bootstrap (`extraKnownMarketplaces` + `enabledPlugins` + `autoUpdate`).
- **Dependency install → per-repo.** A Node repo ships `.claude/hooks/session-deps-install.sh` (pnpm); a
  Swift repo would `swift package resolve`. Never hardcode a package manager in the plugin.
- **Quality gate → per-repo, LOCAL, zero GitHub compute.** No CI/build/test workflows in Actions.
  **Recommended implementation: Lefthook** (language-agnostic Go binary) — each repo supplies its own
  `lefthook.yml` commands and installs it its own way. **Zero-dependency fallback** (repos without a
  package manager, like this one): a committed `.githooks/` dir + `git config core.hooksPath .githooks`
  (see `scripts/setup.sh`). Either way the gate runs on **pre-push**, is `--no-verify`-bypassable, and
  never runs in CI.
- **GitHub stays review-only.** Keep `@claude` / Claude-PR-Review workflows if a project wants them; no
  build/test compute in Actions.

### Four-eyes / parallel-evolution protocol

- This repo is the **single source of truth**. **Pull `main` before editing** and build on what's here —
  never re-invent an element that already exists (e.g. the git-sync hook).
- **Serialize harness edits:** one small PR at a time, merged before the next. Never two open harness PRs
  in flight.
- **Never mix projects.** A session reconciles only its **own** app repo against this contract.
- Disagreements with this contract are resolved by **editing this section in a PR** (with rationale), not
  by silently diverging in a consumer repo.

### Open for review (bring your perspective)

- Whether to additionally offer a _plugin-provided_ generic pre-push hook (delegating to a project
  `.claude/quality-gate.sh`) instead of per-repo Lefthook wiring. Current decision: **Lefthook +
  `.githooks` fallback** — stable, proven, nothing custom to maintain. (A Claude-Code plugin can't
  install a _git_ hook directly; it would need a SessionStart hook that mutates each repo's git config,
  which is more intrusive — hence the per-repo decision for now.)
- Any further genuinely-universal skills/agents worth promoting from a consumer repo.

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
