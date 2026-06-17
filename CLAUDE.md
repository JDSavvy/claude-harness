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
   zero stack assumptions: `session-git-sync`, `harness-update-check`, `anti-hallucination-reminder`,
   `/spec`, `/implement-pr`, `/release-harness`, and the generic `code-reviewer` + `test-runner` (which
   read each repo's CLAUDE.md).
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
  package manager, like this one): a committed `.githooks/` dir + `git config core.hooksPath .githooks`.
  Wire that fallback either **manually, once per clone** (`scripts/setup.sh` — sets `core.hooksPath`
  **unconditionally**) or have it **self-activate** via a per-repo SessionStart hook that sets
  `core.hooksPath` **only when unset** (the canonical auto pattern — see **Reviewed** below). Either way
  the gate runs on **pre-push**, is `--no-verify`-bypassable, and never runs in CI.
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

### Reviewed (bring your perspective — these were re-confirmed by a second session)

- **Plugin-provided generic pre-push hook? → No. The quality gate stays per-repo.**
  _Resolved 2026-06-15 (four-eyes)._ Empirically, a Claude-Code plugin ships skills/agents/Claude-Code
  hooks but **cannot install a _git_ hook**; the only way it could enforce a pre-push gate is a
  SessionStart hook that mutates each consumer's `core.hooksPath` — intrusive, and it would fight any
  repo that already runs Lefthook or sets its own hooksPath. So the gate stays per-repo (**Lefthook**,
  or the zero-dependency **`.githooks` fallback**). **Canonical per-repo pattern** (copy it): a committed
  `.githooks/<gate>` (e.g. `pre-push`) that mirrors the repo's own CI lint, enabled one of two ways —
  **(1) auto, recommended:** a per-repo SessionStart hook that sets `core.hooksPath` **only when unset**
  (idempotent; never clobbers a repo that already runs Lefthook or set its own hooksPath), so it
  self-activates every session with no manual step — reference impl: GameStats
  `.claude/hooks/session-setup.sh` (Swift); **(2) manual:** a one-shot `scripts/setup.sh` that sets
  `core.hooksPath` **unconditionally**, run once per clone — this repo's variant. The only-when-unset
  guard is exactly what makes (1) safe to run on every session start; do **not** port the manual
  one-shot's unconditional `config` into a SessionStart hook.
- **Further universal skills/agents to promote from a consumer? → None this round.**
  _Evaluated 2026-06-15._ The project **anti-mixing guards** (`guard-<other-project>.sh`) hard-code a
  specific project's Supabase ref, so they **fail the framework-independence test** and correctly stay
  per-repo. Re-open this when a genuinely stack-neutral candidate appears.

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

## Anti-hallucination (universal)

**Verify before asserting — including negative claims.** Before stating any fact — and
**especially any absence/negative claim** ("X doesn't exist", "that tool/skill/file is
missing", "not installed", "there's no such option") — validate it against the **live
source of truth** (filesystem, `--version` / the package registry, MCP introspection, an
actual invocation), never from memory. **An in-context list or summary is not a source of
truth** — it can be incomplete (e.g. a loaded skill/tool list may omit plugin-provided
skills). When unsure, verify rather than guess; if something genuinely cannot be verified,
say so explicitly instead of inventing it. This applies to every consuming repo, regardless
of stack.

This rule is not just documentation: the plugin ships it into **every** consumer session via the
`anti-hallucination-reminder.sh` SessionStart hook (emitted as `hookSpecificOutput.additionalContext`,
matchers `startup|resume|clear|compact`), so it survives even in repos whose own `CLAUDE.md` never
restates it. Stack-agnostic and I/O-free. Opt-out: `HARNESS_AH_REMINDER=off`.

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
