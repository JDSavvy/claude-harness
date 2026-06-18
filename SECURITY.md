# Security Policy

`claude-harness` is a public Claude Code plugin marketplace holding one plugin, `harness` —
a dependency-free set of shell hooks, skills, and subagents. There is no server, no build
artifact, and no data we hold. The relevant attack surface is the **code you run locally**.

## Scope & threat model

The plugin's SessionStart hooks (`session-git-sync.sh`, `harness-update-check.sh`,
`anti-hallucination-reminder.sh`) and its skills run **with your local user privileges**, in
your shell, against your repos. They are intentionally lean and auditable: the hooks are
offline/worktree-safe, always `exit 0`, and the only state they mutate is a `git merge --ff-only`
on a clean, strictly-behind branch. Read them before you trust them — they're plain shell.

### autoUpdate is a trust decision

Consumers integrate by enabling the marketplace with `autoUpdate`. With **`autoUpdate: true`**,
each session start pulls and runs **whatever `main` is at that moment** — you are trusting the
current state of this repo to execute on your machine. That is fine for an interactive developer
laptop where you accept rolling updates.

It is **not** appropriate where the session holds credentials or runs unattended. **Token-holding
or CI consumers should pin `autoUpdate: false`** and update deliberately (review the diff, then
`/plugin marketplace update claude-harness`). Treat a compromised or unexpected `main` the same
way you'd treat any third-party code with shell access.

## Reporting a vulnerability

Report privately — **do not** open a public issue for anything exploitable.

- **GitHub:** open a private report via *Security → Report a vulnerability* (GitHub Security
  Advisories) on https://github.com/JDSavvy/claude-harness — preferred, keeps the thread on the repo.
- **Email:** jdsavvy@proton.me

Useful in a report: the affected file/hook/skill, the conditions to trigger it, and the impact
(what an attacker gains). A minimal repro helps most.

## What to expect

- This is a single-maintainer project: response is **best-effort**, typically within a few days.
- There is **no bug bounty** and no monetary reward.
- Confirmed issues are fixed on `main` and, when warranted, called out in `CHANGELOG.md` and a
  GitHub Security Advisory. Credit is given if you want it.

Only the current `main` / latest release is supported — there are no maintained older branches.
