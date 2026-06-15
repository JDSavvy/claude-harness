# Changelog — harness plugin

All notable changes to the `harness` plugin. Versions track
`plugins/harness/.claude-plugin/plugin.json` (the single source of truth). Loosely follows
[Keep a Changelog]; the repo uses Conventional Commits.

## 1.2.0 — 2026-06-15

### Added

- **Generic `SessionStart` hooks** shipped by the plugin (`plugins/harness/hooks/`), active in every
  enabled repo (verified: plugin hooks merge with user/project hooks):
  - `session-git-sync.sh` — bounded `fetch` + ahead/behind/dirty notify; safe `git merge --ff-only`
    **only** when the tree is clean and strictly behind. Offline-/worktree-safe, always exits 0.
    Opt-outs: `HARNESS_GIT_SYNC=off`, `HARNESS_GIT_SYNC_AUTOFF=off`.
  - `harness-update-check.sh` — throttled (≈ once/day) live `ls-remote` check that notifies (never
    auto-updates) when the plugin is behind its remote. Opt-out: `HARNESS_UPDATE_CHECK=off`.
  - `lib/common.sh` — portable bash-3.2 watchdog (no `timeout`/`jq` dependency) + JSON context emit.
- `/release-harness` skill — validate → bump `plugin.json` → update this changelog → Conventional
  Commit + tag.
- This `CHANGELOG.md`.

### Changed

- **Version is now single-sourced** in `plugin.json`; removed the duplicate `version` from
  `marketplace.json` (Claude Code lets `plugin.json` win, so the two silently drifted — the old README
  even institutionalised the drift by telling you to bump both).
- README rewritten: documents the hooks + opt-outs, the repo-committed bootstrap
  (`extraKnownMarketplaces` + `enabledPlugins`, prompt-on-trust), `autoUpdate`, honest update
  semantics, and corrects the marketplace to **public** (no PAT needed for the @claude Action).

### Repo tooling (not plugin-versioned)

- `CLAUDE.md` — grounds work on this repo (hard rules, scope-fence, how to extend, release flow).
- `scripts/validate.sh` — Node-free self-validation gate (JSON parse · version single-source · `bash -n`
  · `shellcheck` · `claude plugin validate` · hook tests), wired as a git pre-commit via `.githooks/`
  (`scripts/setup.sh` to enable). No GitHub compute — the high-blast-radius plugin now validates itself.
- `tests/git-sync.test.sh` — behavior regression tests for the state-mutating git-sync hook.
- `.claude/settings.json` — dogfoods the harness bootstrap in its own repo.

## 1.1.0 — 2026-06-13

### Added

- `/implement-pr` skill — drive a mentioned PR to done (reconcile against drift as a pre-step, then
  implement & fix it merge-ready).

## 1.0.0 — 2026-06-13

### Added

- Initial shared marketplace + `harness` plugin: `/spec` skill (goal → researched GitHub issue) and
  generic `code-reviewer` + `test-runner` subagents.

[Keep a Changelog]: https://keepachangelog.com/en/1.1.0/
