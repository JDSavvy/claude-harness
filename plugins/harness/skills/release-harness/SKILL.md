---
name: release-harness
description: >-
  Cut a versioned release of the shared `harness` plugin (this claude-harness repo). Use when asked to
  "release the harness", "bump the harness version", "cut a harness release", "tag the plugin", or after
  merging changes to the plugin that consumers should pick up. Validates the plugin, single-sources the
  version bump in plugin.json, updates CHANGELOG.md, makes a Conventional Commit, and tags it. Only for
  THIS repo (the marketplace/plugin). Makes no changes to consumer repos.
---

# /release-harness — cut a release of the `harness` plugin

The plugin has a high blast radius: one change here propagates to every consuming repo on the next
refresh. This skill makes releases deliberate, validated, and traceable. **Claude Code only.**

## Hard rules
- **Version lives ONLY in `plugins/harness/.claude-plugin/plugin.json`.** Never add a `version` to
  `.claude-plugin/marketplace.json` — Claude Code lets `plugin.json` win and the two silently drift.
- **Don't fake validation.** If `claude plugin validate` fails, fix the cause; never skip it.
- **Conventional Commits**, one clean release commit. Tag matches the new version (`vX.Y.Z`).
- Work on a branch + PR if the repo protects `main`; otherwise a direct release commit on `main` is fine
  for a solo maintainer. Never force-push.

## Steps

1. **Pre-flight.** Confirm a clean tree (`git status`), you're on the intended base, and summarise the
   unreleased changes since the last tag:
   ```
   git fetch --tags --quiet
   git describe --tags --abbrev=0 2>/dev/null || echo "(no tags yet)"
   git log --oneline "$(git describe --tags --abbrev=0 2>/dev/null)"..HEAD 2>/dev/null || git log --oneline -10
   ```

2. **Validate the plugin** (empirical — do not skip):
   ```
   claude plugin validate ./plugins/harness 2>/dev/null || claude plugin validate . 
   ```
   If the CLI lacks the command, at minimum verify every JSON file parses
   (`marketplace.json`, `plugin.json`, `hooks/hooks.json`) and `bash -n` every hook script.

3. **Pick the SemVer bump** from the change set: `patch` (fixes/docs), `minor` (new skill/agent/hook,
   backward-compatible), `major` (breaking change to a skill/agent contract). State your reasoning.

4. **Bump the version** in `plugins/harness/.claude-plugin/plugin.json` only. Sanity-check no stray
   `version` exists in `marketplace.json`.

5. **Update `CHANGELOG.md`** — add a new dated section for the version with Added / Changed / Fixed /
   Removed as needed, derived from the commits in step 1. Keep entries concrete.

6. **Commit + tag** (Conventional Commit):
   ```
   git add plugins/harness/.claude-plugin/plugin.json CHANGELOG.md
   git commit -m "chore(release): harness vX.Y.Z"
   git tag -a vX.Y.Z -m "harness vX.Y.Z"
   ```

7. **Publish.** Push the branch/commit and the tag (`git push && git push --tags`), open a PR if
   required. Tell the owner consumers will pick it up via `autoUpdate` at startup or
   `/plugin marketplace update claude-harness`.

## Backfill
If tags are missing for already-released versions, create annotated tags on the corresponding commits
(`git tag -a vX.Y.Z <sha> -m …`) so `git describe` and the changelog stay aligned.
