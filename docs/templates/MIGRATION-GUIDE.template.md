<!--
  TEMPLATE — major-release migration guide for claude-harness.
  Copy to docs/migrations/v<MAJOR>.md when cutting a `feat!` / major release, fill in every <…>, and
  delete this comment and any rows/sections that don't apply. Link it from the release notes + CHANGELOG.
  See docs/VERSIONING.md for when this is required.
-->

# Migrating to harness v<MAJOR>.0.0

**Released:** <YYYY-MM-DD> · **From:** v<PREV>.x · **Effort:** <a few minutes | review each consumer>

## Summary

<1–3 sentences: what changed at a high level and why a consumer should care.>

## Breaking changes

| What changed | Why | What you must do |
| --- | --- | --- |
| <removed/renamed skill `/harness:<old>` → `/harness:<new>`> | <rationale> | <update any docs/scripts that referenced the old command> |
| <removed hook / renamed opt-out env var `<OLD>` → `<NEW>`> | <rationale> | <update `.claude/settings.json` / env> |
| <changed contract ruling in CLAUDE.md> | <rationale> | <action> |

## Removed (previously deprecated)

- <element> — deprecated in v<PREV>.<minor>, removed here. Replacement: <what to use instead>.

## Step-by-step

1. Review this guide and the release notes for v<MAJOR>.0.0.
2. Update the harness: `/plugin marketplace update claude-harness` (then confirm the new version).
3. Apply each row in **Breaking changes** above to your repo.
4. Re-run your repo's quality gate to confirm nothing regressed.

## Rollback

If you need to revert: pin back to the previous version (set `autoUpdate: false` and update deliberately, or
reinstall the prior release), then re-open an issue describing what blocked the upgrade.
