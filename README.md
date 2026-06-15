# claude-harness — shared Claude Code harness (BP June 2026)

A **plugin marketplace** holding one project-neutral plugin (`harness`) that every repo of mine reuses
— so the *handling* (skill names, session behaviour, workflow pattern) is identical everywhere, while
each project tailors only its stack-specific bits locally. Repos never mix. **Claude Code only.**

## Layout
```
claude-harness/
├── .claude-plugin/marketplace.json     # this repo IS the marketplace (NO version here — see plugin.json)
└── plugins/harness/                    # the shared plugin
    ├── .claude-plugin/plugin.json      # single source of truth for the version
    ├── skills/
    │   ├── spec/SKILL.md               # /spec — goal → researched GitHub issue (no code)
    │   ├── implement-pr/SKILL.md       # /implement-pr — drive a mentioned PR to done
    │   └── release-harness/SKILL.md    # /release-harness — cut a versioned release of this plugin
    ├── agents/                         # generic, stack-agnostic subagents
    │   ├── code-reviewer.md
    │   └── test-runner.md
    └── hooks/                          # generic SessionStart automation (runs in EVERY enabled repo)
        ├── hooks.json
        ├── session-git-sync.sh         # fetch + ahead/behind/dirty notify; safe FF-only when clean & behind
        ├── harness-update-check.sh     # notify when this plugin is behind its remote (throttled; never auto-updates)
        └── lib/common.sh               # shared bash helpers (portable watchdog, JSON context emit)
```

## Session-start automation (shipped by the plugin)
Once `harness@claude-harness` is enabled, its `SessionStart` hooks run automatically in **every** project
(verified: plugin hooks merge with your user/project hooks). All are non-destructive, offline-safe,
worktree-safe, and always exit 0 — they never hang or block a session.

- **git-sync** (`session-git-sync.sh`) — fetches the upstream branch (bounded; offline = no-op), then:
  - clean tree **and** strictly behind → safe `git merge --ff-only` (stay current, avoid stale-base merge/commit failures);
  - dirty / ahead / diverged / detached / no-upstream → **notify only**, never mutate;
  - up to date → silent.
  - Opt-out: `HARNESS_GIT_SYNC=off` (disable) · `HARNESS_GIT_SYNC_AUTOFF=off` (notify, no auto-FF).
- **update-check** (`harness-update-check.sh`) — compares the installed plugin against its remote via a
  live `ls-remote` (throttled ≈ once/day) and tells you to run `/plugin marketplace update claude-harness`
  when behind. Deliberately does **not** auto-update a globally-shared plugin mid-session. Opt-out: `HARNESS_UPDATE_CHECK=off`.

## What is SHARED (here) vs PER-REPO (committed in each project)
| Shared (this plugin) | Per-repo (`<project>/.claude/`, `.github/`) |
|---|---|
| `/spec`, `/implement-pr`, `/release-harness` skills | `.github/workflows/claude*.yml` (must live in the repo) |
| generic `code-reviewer`, `test-runner` subagents | repo `settings.json` (permissions, plugin bootstrap, project hooks) |
| generic `SessionStart` **hooks** (git-sync, update-check) | **stack-specific hooks** (formatter, i18n, anti-mixing guard …) |
| | `CLAUDE.md` (build/test commands, conventions), app-specific skills/subagents |

## Integrate into a project

**Interactive (one-time per machine):**
```
/plugin marketplace add https://github.com/JDSavvy/claude-harness.git
/plugin install harness@claude-harness
```

**Repo-committed bootstrap (recommended)** — add to the project's `.claude/settings.json` so new clones
are *prompted* to install on folder-trust:
```json
{
  "extraKnownMarketplaces": {
    "claude-harness": {
      "source": { "source": "git", "url": "https://github.com/JDSavvy/claude-harness.git" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": { "harness@claude-harness": true }
}
```
> This **prompts** on folder-trust — it is not a silent auto-install (Claude Code security design).
> `autoUpdate: true` lets Claude Code refresh the marketplace + plugin at startup; the update-check hook
> is the belt-and-suspenders signal regardless.

**Autonomous @claude GitHub Action** — add to the repo's `claude.yml` / `claude-code-review.yml`
(verified inputs of `anthropics/claude-code-action`, as of 2026-06-15):
```yaml
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          plugin_marketplaces: https://github.com/JDSavvy/claude-harness.git
          plugins: harness@claude-harness
```
> This marketplace repo is **public**, so the Action clones it with the default `GITHUB_TOKEN` — no PAT
> needed. ⚠️ If it is ever flipped **private**, both workflows silently fail to load the plugin unless a
> PAT with `repo` read scope is wired into the checkout/action.

## Versioning / updates
- **Single source of truth:** the version lives **only** in `plugins/harness/.claude-plugin/plugin.json`.
  Do **not** add a `version` to the marketplace entry — Claude Code lets `plugin.json` win and the two
  silently drift.
- Cut releases with **`/release-harness`**: it validates the plugin, bumps `plugin.json`, updates
  `CHANGELOG.md`, makes a Conventional Commit and tags it.
- Consumers either enable `autoUpdate` (refresh at startup) or run `/plugin marketplace update
  claude-harness`; the update-check hook surfaces when they're behind. One change here propagates to
  every project on the next refresh.
```
