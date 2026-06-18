## Summary

<!-- What does this change and why? One or two sentences. Link the issue if there is one. -->

## Checklist

- [ ] `bash scripts/validate.sh` is green locally.
- [ ] Conventional Commit PR title (drives release-please, e.g. `feat:`, `fix:`, `docs:`, `chore:`).
- [ ] CLAUDE.md hard rules respected: stack-agnostic (no pnpm/Next/Swift/pip/etc.), version single-sourced in `plugin.json`, hooks `exit 0` + carry an opt-out env var.
- [ ] Docs / README / CLAUDE.md updated if behaviour changed.
- [ ] No project-specific names leaked into the plugin.

## Notes for reviewers

<!-- Anything worth flagging: trade-offs, follow-ups, why an alternative was rejected, blast-radius callouts. -->
