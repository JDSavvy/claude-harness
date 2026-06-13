# claude-harness — shared Claude Code harness (BP June 2026)

A **plugin marketplace** holding one project-neutral plugin (`harness`) that every repo of mine reuses
— so the *handling* (skill names, functions, workflow pattern) is identical everywhere, while each
project tailors only its stack-specific bits locally. Repos never mix.

## Layout
```
claude-harness/
├── .claude-plugin/marketplace.json     # this repo IS the marketplace
└── plugins/harness/                    # the shared plugin
    ├── .claude-plugin/plugin.json
    ├── skills/spec/SKILL.md             # /spec — goal → researched GitHub issue (no code)
    └── agents/                          # generic, stack-agnostic subagents
        ├── code-reviewer.md
        └── test-runner.md
```

## What is SHARED (here) vs PER-REPO (committed in each project)
| Shared (this plugin) | Per-repo (`<project>/.claude/`, `.github/`) |
|---|---|
| `/spec` skill | `.github/workflows/claude.yml` + `claude-code-review.yml` (must live in the repo) |
| generic `code-reviewer`, `test-runner` | `settings.json` permissions + plugin enablement |
| (future generic skills/agents) | **anti-mixing guard hook** (the forbidden ref is project-specific) |
| | `format-edited` hook (stack-specific linter), stack-specific subagents |
| | `CLAUDE.md` (build/test commands, conventions), app-specific skills |

## Integrate into a project

**1) Interactive (Claude Code CLI / web), one-time per machine:**
```
/plugin marketplace add https://github.com/JDSavvy/claude-harness.git
/plugin install harness@claude-harness
```
Then `/spec` (namespaced `/harness:spec`) and the agents are available.

**2) Autonomous @claude GitHub Action** — add to the repo's `claude.yml` / `claude-code-review.yml`
(verified inputs of `anthropics/claude-code-action`):
```yaml
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          plugin_marketplaces: https://github.com/JDSavvy/claude-harness.git
          plugins: harness@claude-harness
```
> If this marketplace repo is **private**, the Action needs read access to clone it: either make this
> repo public, or pass a PAT secret with `repo` read scope to the checkout/action. With the repo's
> default `GITHUB_TOKEN` (scoped to the project repo only) a private cross-repo clone will fail.

## Versioning / updates
Bump `version` in `plugin.json` + `marketplace.json`; pin consumers to a `ref`/`sha` in their
`plugin_marketplaces`/marketplace entry for stability, or track `main` for always-latest. One change
here propagates to every project on next install/run.
