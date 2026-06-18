# claude-harness

> A lean, stack-agnostic, Claude-Code-only agent harness shared across your repos.

[![CI](https://github.com/JDSavvy/claude-harness/actions/workflows/ci.yml/badge.svg)](https://github.com/JDSavvy/claude-harness/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/JDSavvy/claude-harness?sort=semver)](https://github.com/JDSavvy/claude-harness/releases)
[![License: MIT](https://img.shields.io/github/license/JDSavvy/claude-harness)](LICENSE)
![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-de7356)

## What is this

A Claude Code plugin **marketplace** holding a single plugin, `harness`. An _agent harness_ is the set of
skills, hooks, and subagents that shape **how the agent works** — the workflow, not the code it writes.
The design is a two-layer model: this plugin is the **universal core** (pure git/workflow logic, zero
stack assumptions), and each consumer repo's own committed `.claude/` is the **stack adapter** (formatter,
linter, build/test commands, project skills).

## Install

**Interactive (one-time per machine):**

```
/plugin marketplace add https://github.com/JDSavvy/claude-harness.git
/plugin install harness@claude-harness
```

**Repo-committed bootstrap** — add to the project's `.claude/settings.json` so clones are prompted to
install on folder-trust:

```json
{
  "extraKnownMarketplaces": {
    "claude-harness": {
      "source": {
        "source": "git",
        "url": "https://github.com/JDSavvy/claude-harness.git"
      },
      "autoUpdate": true
    }
  },
  "enabledPlugins": { "harness@claude-harness": true }
}
```

> `autoUpdate: true` refreshes the marketplace and plugin from the mutable `main` branch at every session
> start — each start runs whatever `main` currently is (including its SessionStart hooks) before you can
> review it. For higher-privileged consumers, especially CI runners holding tokens, prefer
> `autoUpdate: false` and update deliberately via `/plugin marketplace update claude-harness`.

**`@claude` GitHub Action** — add to the workflow's `with:` block:

```yaml
with:
  plugin_marketplaces: https://github.com/JDSavvy/claude-harness.git
  plugins: harness@claude-harness
```

## What's inside

| Element                        | What it does                                                                                              | Opt-out                  |
| ------------------------------ | --------------------------------------------------------------------------------------------------------- | ------------------------ |
| `/create-issue`                | Turn a goal into a researched, best-practice GitHub issue — no code; ends at the issue                    | —                        |
| `/finish-pr`                   | Drive a PR to merge-ready: reconcile against drift (merge base, never rebase), implement, verify, push once | —                        |
| `code-reviewer`                | Opus subagent — reviews correctness, security, performance, reuse                                          | —                        |
| `test-runner`                  | Sonnet subagent — runs the repo's lint + build + test gate                                                 | —                        |
| `session-git-sync`             | Bounded fetch + ahead/behind/dirty notify; safe `git merge --ff-only` only when clean & strictly behind   | `HARNESS_GIT_SYNC=off`   |
| `harness-update-check`         | Throttled (~daily) `ls-remote` check; notifies (never auto-updates) when the plugin is behind             | `HARNESS_UPDATE_CHECK=off` |
| `anti-hallucination-reminder`  | Injects the universal "verify before asserting, incl. negative claims" rule into every session            | `HARNESS_AH_REMINDER=off`  |

## Shared vs per-repo

| Shared — this plugin                                                | Per-repo — each project's `.claude/`                                  |
| ------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `/create-issue`, `/finish-pr` skills                                | Formatter, linter, dependency install                                 |
| Generic `code-reviewer`, `test-runner` subagents                    | The quality-gate commands (lint / build / test)                       |
| Generic `SessionStart` hooks (git-sync, update-check, AH reminder)  | Project-specific skills and specialized subagents                     |
| Pure git/workflow logic, zero stack assumptions                     | The project `CLAUDE.md` and `.claude/settings.json` bootstrap         |

Decider: _would this break on a Swift / Python / Go repo?_ If yes, it is per-repo and never lives in the plugin.

## Quality & releases

After `bash scripts/setup.sh` (once per clone), a local quality gate runs on every commit (pre-commit
via `.githooks/`). The **same** `scripts/validate.sh` runs locally and in this repo's free
read-only CI: it parses the JSON manifests, checks the version is single-sourced, runs `bash -n` and
`shellcheck` on the hooks, `claude plugin validate`, skill/agent frontmatter and `hooks.json` reference
integrity, and every `tests/*.test.sh`. It is Node-free and bypassable with `git commit --no-verify`.

Releases are automated via **release-please** (Conventional Commits → release PR → on merge, tag +
GitHub Release). The version is single-sourced in `plugins/harness/.claude-plugin/plugin.json` — never in
`marketplace.json`. No GitHub CI compute is imposed on consumer repos; this public repo's own CI and
release-please are the deliberate exception.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, and [CLAUDE.md](CLAUDE.md) for the hard rules and the harness contract.

## License

[MIT](LICENSE) © 2026 JDSavvy
