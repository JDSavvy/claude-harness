# Changelog — harness plugin

All notable changes to the `harness` plugin. Versions track
`plugins/harness/.claude-plugin/plugin.json` (the single source of truth). Loosely follows
[Keep a Changelog]; the repo uses Conventional Commits.

## [2.1.1](https://github.com/JDSavvy/claude-harness/compare/harness-v2.1.0...harness-v2.1.1) (2026-06-20)


### Bug Fixes

* **gate:** enforce bash-3.2 multibyte-safe interpolation; reject empty descriptions ([#29](https://github.com/JDSavvy/claude-harness/issues/29)) ([473f72c](https://github.com/JDSavvy/claude-harness/commit/473f72c7af69e1fe27c87d8304a1384474a69302))
* **hooks:** harden guard template — short/refspec force-push, rm variants, control-char-safe deny ([#30](https://github.com/JDSavvy/claude-harness/issues/30)) ([ef82359](https://github.com/JDSavvy/claude-harness/commit/ef82359fc084f4ea3bf687c149d9761c82db4d46))
* **skills:** sharpen create-issue↔plan-change boundary; finish-pr reaches the universal DoD ([#27](https://github.com/JDSavvy/claude-harness/issues/27)) ([459e9e6](https://github.com/JDSavvy/claude-harness/commit/459e9e6c5bebb64afee6143f5429942ab6222b56))


### Documentation

* **readme:** award-winning visual redesign with branded SVGs ([#33](https://github.com/JDSavvy/claude-harness/issues/33)) ([3b7d941](https://github.com/JDSavvy/claude-harness/commit/3b7d9419d1585f8b35499e236e8f4599dee65d3b))
* secure-by-default autoUpdate, command namespacing, /plan-change inventory, pinning honesty ([#31](https://github.com/JDSavvy/claude-harness/issues/31)) ([415b112](https://github.com/JDSavvy/claude-harness/commit/415b11277f9d722c1e477b7214de0dca705f176e))

## [2.1.0](https://github.com/JDSavvy/claude-harness/compare/harness-v2.0.0...harness-v2.1.0) (2026-06-20)


### Features

* **hooks:** add copyable PreToolUse guard template + gate it ([#20](https://github.com/JDSavvy/claude-harness/issues/20)) ([fc0adad](https://github.com/JDSavvy/claude-harness/commit/fc0adadd534584de444713c0ae47bcae8938d263))
* **hooks:** enrich git-sync fast-forward audit line + document the audit-trail norm ([#25](https://github.com/JDSavvy/claude-harness/issues/25)) ([9233884](https://github.com/JDSavvy/claude-harness/commit/9233884a801490407166d4e28e70cda47f45c97f))
* **skills:** add /plan-change skill (plan-only artifact) ([#17](https://github.com/JDSavvy/claude-harness/issues/17)) ([d99544e](https://github.com/JDSavvy/claude-harness/commit/d99544ec652785c7805ccdf4e07e58c7abefb769))

## [2.0.0](https://github.com/JDSavvy/claude-harness/compare/harness-v1.2.0...harness-v2.0.0) (2026-06-18)

A universal-harness overhaul — project-neutral, senior-BP, with free CI and automated releases.

### ⚠ BREAKING CHANGES

- **Skills renamed:** `/spec` → `/create-issue` and `/implement-pr` → `/finish-pr` (both decoupled from
  any specific implementation surface — no `@claude` assumptions). Consumers referencing the old names
  must update them.
- **`/release-harness` removed** from the plugin — releasing is now automated via `release-please`, so it
  no longer clutters every consumer's skill list.

### Added

- **`anti-hallucination-reminder.sh`** SessionStart hook — injects the universal "verify before
  asserting, including negative/absence claims; an in-context list is not a source of truth" rule into
  every consumer session (`hookSpecificOutput.additionalContext`). Opt-out: `HARNESS_AH_REMINDER=off`.
- **Free CI** (`.github/workflows/ci.yml`) running the same `scripts/validate.sh` gate on every push/PR,
  and **automated releases** via `release-please` — the version stays single-sourced in `plugin.json`.
- Repo hygiene: `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md`, `.editorconfig`, issue/PR templates,
  `CODEOWNERS`, Dependabot, and a rewritten `README.md` with badges + an inventory table.
- `scripts/validate.sh` now auto-discovers every `tests/*.test.sh` and parses the release-please JSON.
- Hermetic behavior tests now cover **all four** plugin shell files (added `harness-update-check.sh` and
  `lib/common.sh` coverage).

### Changed

- Genericized the harness to be fully project-neutral (removed all project-specific examples) and refined
  the contract: the "no GitHub CI compute" rule applies to *consumer* repos, while this public marketplace
  repo uses its own free read-only CI as the documented exception. ([f7a9122](https://github.com/JDSavvy/claude-harness/commit/f7a9122cc1c4988a19c45e3cd2530b64a94f1cea))

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
