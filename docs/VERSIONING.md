# Versioning, deprecation & autoUpdate

How `claude-harness` versions itself, what counts as a breaking change, how consumers adopt updates safely,
and the policy every **major** release must follow. This complements [`CONTRIBUTING.md`](../CONTRIBUTING.md)
(the commit/release flow) and [`CLAUDE.md`](../CLAUDE.md) (the contract). The plugin propagates to **every**
consuming repo, so version discipline is a safety property, not bookkeeping.

## Semantic versioning, single-sourced & automated

- The version lives in **one** place: `plugins/harness/.claude-plugin/plugin.json`. It is **never** set in
  `marketplace.json` (Claude Code lets `plugin.json` win, and the two would silently drift).
- Releases are automated by **release-please** from [Conventional Commits](../CONTRIBUTING.md#conventional-commits):

  | Commit | Bump | Example |
  | --- | --- | --- |
  | `fix:` | **patch** | a hook edge case |
  | `feat:` | **minor** | a new skill / agent / hook / capability |
  | `feat!:` or a `BREAKING CHANGE:` footer | **major** | see below |

  On merge to `main`, release-please opens/updates a release PR (it computes the bump, updates
  `CHANGELOG.md`, and bumps `plugin.json`). Merging that PR tags the commit and cuts a GitHub Release.
  **Never hand-bump the version or hand-edit `CHANGELOG.md`.**

## What counts as a breaking change (→ `feat!` / major)

This plugin's "public API" is the set of names and contracts consumers depend on. Treat any of these as
**breaking**:

- **Removing or renaming a skill** — the command name is the skill's directory name, so renaming
  `skills/<dir>/` changes the `/harness:<dir>` a consumer types.
- **Removing or renaming a subagent** (`agents/<name>.md`) consumers invoke by name.
- **Removing a hook, changing its registration in `hooks.json`, or removing/renaming its opt-out env var**
  (`HARNESS_GIT_SYNC`, `HARNESS_UPDATE_CHECK`, `HARNESS_AH_REMINDER`, `HARNESS_GUARD`, …).
- **Changing a hook's externally-observable contract** — e.g. the auto-`merge --ff-only` behaviour of
  `session-git-sync`, or the SessionStart `additionalContext` shape — in a way that alters consumer sessions.
- **Renaming the plugin or the marketplace**, or moving the plugin's source path/`ref`.
- **A backward-incompatible change to the Universal Harness Contract** in `CLAUDE.md` (a ruling consumers
  were told to rely on).

Non-breaking (no major): adding a new skill/agent/hook, tightening an internal pattern, docs, or any change
that leaves every existing name + opt-out + contract working as before.

## Deprecate before you remove

Removal is a two-step, never a surprise:

1. **Deprecate first.** Mark the element deprecated for **at least one minor release** — note it in
   `CHANGELOG.md`, in the element's own description/comment, and (if it changes behaviour) emit a one-line
   deprecation notice. Keep it working during this window.
2. **Remove in the next major**, with a migration guide (below). The deprecation window is the consumer's
   heads-up; the major is where the removal lands.

## Every major ships a migration guide

A `feat!` / major release **must** include a migration guide so consumers can move deliberately:

- Write it from [`docs/templates/MIGRATION-GUIDE.template.md`](templates/MIGRATION-GUIDE.template.md) and
  commit it as `docs/migrations/v<MAJOR>.md`.
- Link it from the release notes and from the `CHANGELOG.md` entry.
- It states **what** changed, **why**, the **per-change migration steps**, what was **removed** (and its
  prior deprecation), and how to **roll back** (pin to the previous version).

## autoUpdate heuristic (consumers)

A consumer opts into the harness in its `.claude/settings.json` (`extraKnownMarketplaces` + `enabledPlugins`).
The `autoUpdate` flag decides whether each session start pulls and runs the latest plugin **before** you can
review it — including its SessionStart hooks, unsandboxed, with your user rights. Choose by **privilege**:

| Set `autoUpdate` | When the repo/session … | Why |
| --- | --- | --- |
| **`false`** _(recommended default)_ | holds **secrets/tokens**, has **MCP servers** with credentials, runs in **CI** or any **privileged** context | auto-pulling+running new plugin code at session start is a supply-chain exposure; review first |
| **`true`** | is **purely local, low-privilege**, throwaway/experimental, with nothing sensitive reachable | convenience outweighs the (low) risk there |

**Pinning & deliberate updates.** With `autoUpdate: false`, the installed plugin stays put until you update
**after review** with `/plugin marketplace update claude-harness` (each release is the single-sourced
`plugin.json` version). Read the migration guide before adopting a new **major**. This is the same tradeoff
the [README](../README.md#install) states at the install step — this table is the canonical version of it.

> **What pinning does and doesn't do.** `autoUpdate: false` pins *when* you take an update (you choose the
> moment), not *which commit* — the marketplace source tracks the mutable `main` branch (`ref: main` in
> `marketplace.json`), so a manual `update` still pulls whatever `main` is at that instant. Tags/releases
> exist for humans to read the changelog and diff; the harness does **not** currently offer git-tag pinning
> in the consumer bootstrap. Update right after reviewing the release notes so the gap stays small.

## How consumers pick up a release

- **`autoUpdate: true`** → next session start.
- **`autoUpdate: false`** → `/plugin marketplace update claude-harness` when you choose to, after reviewing the
  diff/release notes (and the migration guide for a major).
