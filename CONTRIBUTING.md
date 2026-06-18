# Contributing to claude-harness

**Philosophy:** keep the harness lean, auditable, and truly stack-agnostic — every line here propagates to
every consuming repo, so the bar is high. [`CLAUDE.md`](CLAUDE.md) is the binding contract; read it before
you change anything. The deciding rule lives there: **the framework-independence test** — _"Would this break
on a Swift / Python / Go repo?"_ If yes, it belongs in a consumer repo's own `.claude/`, **not** in this
plugin.

## Local setup

```sh
git clone https://github.com/JDSavvy/claude-harness.git
cd claude-harness
bash scripts/setup.sh            # wires the pre-commit gate (git config core.hooksPath .githooks)
```

`setup.sh` is a one-shot per clone. It points git at the committed `.githooks/`, so `scripts/validate.sh`
runs automatically before every commit.

## The change loop

1. **Branch.** Never commit on `main`; never push to `main`.
2. **Edit.** Keep it generic — no `pnpm`/Next/`tsc`/`swift`/`pip` or any stack name in a skill, agent, or hook.
3. **Validate.** `bash scripts/validate.sh` must be green. The pre-commit hook runs it for you; don't bypass it
   without reason (`git commit --no-verify` is for emergencies only).
4. **Commit** with a [Conventional Commit](#conventional-commits) message — these drive releases.
5. **Open a PR.** CI runs the same gate on this public repo. Get it green, then merge. One small PR at a time —
   never two open harness PRs in flight (see the four-eyes protocol in `CLAUDE.md`).

## Adding things

| Adding a… | Where | Requirements |
| --- | --- | --- |
| **Skill** | `plugins/harness/skills/<name>/SKILL.md` | Frontmatter `name` + `description`. Keep it generic. |
| **Subagent** | `plugins/harness/agents/<name>.md` | Stack-agnostic; reads the consumer's `CLAUDE.md`. |
| **Hook** | script under `plugins/harness/hooks/` | Register it in `hooks/hooks.json`, give it an opt-out env var, and add a behavior test under `tests/`. |

Hooks must be portable to macOS **bash 3.2** (no `timeout`, no `jq`), offline-safe, worktree-safe, fast, and
**always `exit 0`**. The validator checks frontmatter, `hooks.json` reference integrity, `bash -n` on every
hook, and runs each `tests/*.test.sh`.

## Conventional Commits

`<type>(<scope>): <summary>` — release-please parses these to bump the version and write the changelog.

| Type | Use for | Version effect |
| --- | --- | --- |
| `feat` | a new skill, agent, hook, or capability | minor |
| `fix` | a bug fix | patch |
| `docs` | docs only (README, this file, `CLAUDE.md`) | none |
| `chore` | tooling, meta, housekeeping | none |
| `refactor` | internal change, no behavior shift | none |
| `test` | tests only | none |
| `feat!` / `BREAKING CHANGE:` | a breaking change (footer or `!`) | major |

## Releasing (maintainers)

Releases are **automated** — there are no manual version bumps. Merge Conventional Commits to `main` and
[release-please](https://github.com/googleapis/release-please) opens a **release PR** that bumps the single
source of truth, `plugins/harness/.claude-plugin/plugin.json`, and updates `CHANGELOG.md`. Merging that
release PR tags the commit and cuts a GitHub Release. Consumers pick it up via `autoUpdate` on their next
session start.

Never set `version` in `marketplace.json` — `plugin.json` wins and the two would silently drift.

---

Questions or contract disagreements: resolve them by editing the relevant section of `CLAUDE.md` in a PR
(with rationale), not by diverging silently. Maintainer: <jdsavvy@proton.me>.
