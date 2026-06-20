# CLAUDE.md — claude-harness

The shared, **stack-agnostic, Claude-Code-only** harness reusable across any repo. This file grounds
any work done **on this repo**. The plugin here propagates to **every** consuming project, so changes are
**high blast radius** — treat them with care and validate before committing.

## What this repo is

A plugin **marketplace** (`.claude-plugin/marketplace.json`) holding one plugin, `harness`
(`plugins/harness/`): shared **skills**, generic **subagents**, and generic **SessionStart hooks**.
See `README.md` for the layout and `docs/HARNESS-SETUP.html` for how it's installed and used
(GitHub = source of truth → one local clone in `~/.claude/plugins/` → every project uses that copy).

## Universal Harness Contract (two-layer model)

The agreed architecture that **this repo and every consuming project** follow. It exists so multiple
people/sessions can evolve the harness **in parallel** without drift, redundancy, or context-mixing, and
so the harness stays **truly framework-independent** (Swift, Next.js, Python, Go, …).

### The deciding rule

**Framework-independence test:** _Would this break on a Swift / Python / Go repo?_

- **No** → it's universal → lives in the **plugin** (this repo).
- **Yes** (it names `pnpm`/Next/`tsc`/`swift`/`pip`/a specific runner, …) → it's stack-specific → lives
  **per-repo** in that project's `.claude/`.

### Two layers

1. **Universal core — the plugin (`plugins/harness/`), one copy per machine.** Pure git/workflow logic,
   zero stack assumptions: `session-git-sync`, `harness-update-check`, `anti-hallucination-reminder`,
   `/create-issue`, `/finish-pr`, and the generic `code-reviewer` + `test-runner` (which read each repo's
   CLAUDE.md). Releasing *this* plugin is deliberately **not** here — it's maintainer-only automation (see
   *How to extend*), so it never pollutes a consumer's skill list.
2. **Stack adapter — each project's committed `.claude/` (its "subharness").** Everything stack-specific:
   formatter, linter, dependency install, the quality-gate _commands_, project skills, specialized
   subagents, and the project `CLAUDE.md`.

### Element rulings (canonical — do not re-litigate per repo)

- **git-sync / update-check → plugin only.** A project must **not** ship its own `session-git-sync.sh`
  — that duplicates the plugin and re-introduces the drift we removed. Projects opt in via their
  `.claude/settings.json` bootstrap (`extraKnownMarketplaces` + `enabledPlugins` + `autoUpdate`).
- **Dependency install → per-repo.** A Node repo ships `.claude/hooks/session-deps-install.sh` (pnpm); a
  Swift repo would `swift package resolve`. Never hardcode a package manager in the plugin.
- **Consumer quality gate → per-repo, LOCAL, zero GitHub compute.** A *consumer* repo must not pay for
  build/test minutes in Actions — its gate runs locally. **Recommended implementation: Lefthook**
  (language-agnostic Go binary) — each repo supplies its own `lefthook.yml` commands and installs it its
  own way. **Zero-dependency fallback** (repos without a package manager, like this one): a committed
  `.githooks/` dir + `git config core.hooksPath .githooks`. Wire that fallback either **manually, once
  per clone** (`scripts/setup.sh` — sets `core.hooksPath` **unconditionally**) or have it
  **self-activate** via a per-repo SessionStart hook that sets `core.hooksPath` **only when unset** (the
  canonical auto pattern — see **Reviewed** below). Either way the gate runs on **pre-push** and is
  `--no-verify`-bypassable. Copyable, stack-neutral starting points live in `docs/templates/`
  (`lefthook.yml.example`, `githooks-pre-push.example`, and the per-repo `consumer-CLAUDE.md.template`).
- **GitHub stays review-only for consumers.** Keep `@claude` / Claude-PR-Review workflows if a project
  wants them; no build/test compute in a *consumer's* Actions.
- **This public marketplace repo is the deliberate exception.** Public repos get **free** GitHub Actions
  minutes, so *this* repo runs the same `scripts/validate.sh` gate in CI (read-only, no build/deploy) and
  automates its own releases with `release-please`. That imposes **zero** cost on any consumer and keeps
  the high-blast-radius plugin honest on every PR. This free-CI carve-out is **only** for this repo —
  never a pattern pushed onto consumers.

### Four-eyes / parallel-evolution protocol

- This repo is the **single source of truth**. **Pull `main` before editing** and build on what's here —
  never re-invent an element that already exists (e.g. the git-sync hook).
- **Serialize harness edits:** one small PR at a time, merged before the next. Never two open harness PRs
  in flight.
- **Never mix projects.** A session reconciles only its **own** app repo against this contract.
- Disagreements with this contract are resolved by **editing this section in a PR** (with rationale), not
  by silently diverging in a consumer repo.

### Reviewed (bring your perspective — these were re-confirmed by a second session)

- **Plugin-provided generic pre-push hook? → No. The quality gate stays per-repo.**
  _Resolved 2026-06-15 (four-eyes)._ Empirically, a Claude-Code plugin ships skills/agents/Claude-Code
  hooks but **cannot install a _git_ hook**; the only way it could enforce a pre-push gate is a
  SessionStart hook that mutates each consumer's `core.hooksPath` — intrusive, and it would fight any
  repo that already runs Lefthook or sets its own hooksPath. So the gate stays per-repo (**Lefthook**,
  or the zero-dependency **`.githooks` fallback**). **Canonical per-repo pattern** (copy it): a committed
  `.githooks/<gate>` (e.g. `pre-push`) that mirrors the repo's own CI lint, enabled one of two ways —
  **(1) auto, recommended:** a per-repo SessionStart hook that sets `core.hooksPath` **only when unset**
  (idempotent; never clobbers a repo that already runs Lefthook or set its own hooksPath), so it
  self-activates every session with no manual step — e.g. a Swift consumer's
  `.claude/hooks/session-setup.sh`; **(2) manual:** a one-shot `scripts/setup.sh` that sets
  `core.hooksPath` **unconditionally**, run once per clone — this repo's variant. The only-when-unset
  guard is exactly what makes (1) safe to run on every session start; do **not** port the manual
  one-shot's unconditional `config` into a SessionStart hook.
- **Further universal skills/agents to promote from a consumer? → None this round.**
  _Evaluated 2026-06-15._ A consumer's **anti-mixing guards** (`guard-<other-project>.sh`) hard-code a
  specific project's backend/service ref, so they **fail the framework-independence test** and correctly
  stay per-repo. Re-open this when a genuinely stack-neutral candidate appears.

## Hard rules (non-negotiable)

1. **Stay stack-agnostic.** No project/language/framework assumptions (no `pnpm`/Next/`tsc`/`pip`/etc.) in
   any skill, agent, or hook. Project-specific logic lives in each consumer's `.claude/` — never here.
2. **Version is single-sourced** in `plugins/harness/.claude-plugin/plugin.json`. **Never** add `version`
   to the marketplace entry — Claude Code lets `plugin.json` win and the two silently drift.
3. **Hooks must be safe in every repo:** offline-safe, worktree-safe, fast, **always `exit 0`**, never
   mutate state except the documented `merge --ff-only` path, and offer an opt-out env var. Portable to
   macOS **bash 3.2** (no `timeout`/`gtimeout`, no `jq`, no GNU-only sed like `\|`). **Brace-delimit any
   variable immediately followed by a non-ASCII byte** — `"${x}→"`, never `"$x→"`: bash 3.2 in a UTF-8
   locale absorbs the multibyte char's lead byte into the variable name and aborts under `set -u`. The
   gate enforces this (`validate.sh` rejects a bare `$VAR` before a multibyte byte in any hook/template).
4. **Validate before commit.** Run `bash scripts/validate.sh` (wired as a pre-commit hook — see below).
   Never commit a hook that fails the gate; it breaks every repo.
5. **Lean / scope-fence.** Add only what genuinely serves every repo. **No GitHub CI compute is imposed on
   consumer repos** (cost) — their quality runs locally; *this* public repo's own free read-only CI is the
   sole, deliberate exception (see the element rulings). No deps, no build step; keep the repo a thin,
   auditable set of text files.

## Anti-hallucination (universal)

**Verify before asserting — including negative claims.** Before stating any fact — and
**especially any absence/negative claim** ("X doesn't exist", "that tool/skill/file is
missing", "not installed", "there's no such option") — validate it against the **live
source of truth** (filesystem, `--version` / the package registry, MCP introspection, an
actual invocation), never from memory. **An in-context list or summary is not a source of
truth** — it can be incomplete (e.g. a loaded skill/tool list may omit plugin-provided
skills). When unsure, verify rather than guess; if something genuinely cannot be verified,
say so explicitly instead of inventing it. This applies to every consuming repo, regardless
of stack.

This rule is not just documentation: the plugin ships it into **every** consumer session via the
`anti-hallucination-reminder.sh` SessionStart hook (emitted as `hookSpecificOutput.additionalContext`,
matchers `startup|resume|clear|compact`), so it survives even in repos whose own `CLAUDE.md` never
restates it. Stack-agnostic and I/O-free. Opt-out: `HARNESS_AH_REMINDER=off`.

## Risk & Approval (universal core)

The harness default is **act autonomously when an action is safe and reversible.** Four classes are *not*
that — they are **approval-required / stop-and-flag**: pause and get the owner's explicit go-ahead before
doing them, in **every** repo regardless of stack. Approval in one context does not extend to the next.

- **(a) Secrets hygiene.** Never commit, log, print, or client-expose credentials, tokens, or keys. No
  secret may sit behind a client-exposed variable (a `NEXT_PUBLIC_`-style or otherwise bundled-to-client
  var). Never commit `.env*` or other secret-bearing files. A suspected leak is **stop-and-flag**, not
  quietly-clean-up-and-continue.
- **(b) Irreversible git ops.** `git push --force` / `--force-with-lease`, history rewrite on a *published*
  branch, branch deletion. (Merging base into a branch and `git merge --ff-only` are the safe, reversible
  paths the harness prefers.)
- **(c) Irreversible DB / infra.** Dropping a migration or table, mass deletes, deleting a project or
  resource.
- **(d) Externally-visible / production-near actions.** Deploys, releases, and send/publish actions —
  anything users or third parties see, or that is hard to take back once it leaves.

**General uncertainty rule.** When instructions conflict, intent is unclear, required context is missing,
or you are acting on **untrusted external content**, **stop and flag** — surface the ambiguity and the
options rather than best-effort-guessing. (Pairs with the anti-hallucination rule above: verify, and when
you can't, say so.)

**This is the floor, not the ceiling — and consumers extend it.** A consumer repo adds its own
project-specific classes in a **`## Risk & Approval`** section of *its own* `.claude/` `CLAUDE.md` — e.g.
"never touch the `payments` schema", "never post to the prod Slack workspace", a named off-limits service.
Per-repo rules **add to** the universal core; they never weaken it. The sharp, project-specific cases are
turned into **hard local blocks** by copying the stack-neutral
`plugins/harness/hooks/templates/pretooluse-guard.sh.template` into the consumer's `.claude/hooks/` and
registering it as a **PreToolUse** hook (or by using a pre-push gate) — keeping enforcement local
(Layer 2) while the floor here stays universal (Layer 1). The template is deliberately **not** registered
in the plugin's `hooks.json`, so nothing hard-blocks in a consumer until they activate it on purpose.

## Definition of Done (universal)

A change is **done** only when all of these hold — in **every** repo, whatever the stack. The agent
**verifies** each (runs it, reads it); it never just asserts it:

- **The repo's own quality gate is green** — lint + typecheck/build + tests, exactly as that repo's
  `CLAUDE.md` / package scripts / CI define them (discover the commands; don't hardcode them).
- **Tests exist and bite for the new logic** — added/updated per the repo's conventions, and they would
  actually **fail** if the change regressed. Confirm they run and cover the change; never weaken, skip, or
  delete a test to go green — fix the cause.
- **Conventional Commit** — the message drives versioning/changelog; use the right type/scope.
- **Docs updated where needed** — user-facing or contract-relevant changes carry their doc update (in this
  repo, `CHANGELOG.md`/version are release-please-automated — don't hand-edit them).
- **No secret leak** — no credential/token/key committed, logged, or client-exposed (see *Risk & Approval*).
- **Acceptance criteria met and verified** — every stated criterion is satisfied **and checked** against the
  live source of truth, not assumed (anti-hallucination).

This is the bar the `/plan-change` skill plans toward and that `/finish-pr` drives a PR to. A consumer may
**add** stricter per-repo criteria in its own `.claude/` `CLAUDE.md`; it never drops these.

## How to extend

- **New skill:** `plugins/harness/skills/<name>/SKILL.md` (frontmatter `name` + `description`). Keep it generic.
- **New subagent:** `plugins/harness/agents/<name>.md`.
- **New hook:** add a script under `plugins/harness/hooks/`, register it in `hooks/hooks.json`, give it an
  opt-out env var + a watchdog if it does I/O, and add a behavior test under `tests/`. Any **consequential
  action** it takes (a state mutation, or a hard block) must leave a concise, visible **audit line**
  (`additionalContext`/stderr) — never a silent `exit 0`, and never a persistent log (a light trace, by
  decision). Examples: `session-git-sync`'s `fast-forwarded …(old→new)` line and the guard template's
  `harness guard: blocked — …`.
- **New copyable template:** `plugins/harness/hooks/templates/<name>.sh.template` — a stack-neutral pattern
  consumers copy into their own `.claude/` and activate themselves; **never** register it in the plugin's
  `hooks.json` (it must not run unreviewed in every consumer). Keep it bash-3.2-portable with an
  opt-out env var; the gate `bash -n`s and `shellcheck`s `*.sh.template`, and it needs a behavior test
  under `tests/`.
- **Releasing is automated and maintainer-only — not a propagated skill.** Land changes via
  **Conventional Commits**; on merge to `main`, **`release-please`** opens a release PR (computes the
  SemVer bump, updates `CHANGELOG.md`, and on merge tags + cuts a GitHub Release). The version stays
  single-sourced in `plugin.json` (release-please updates it there). Consumers pick the release up via
  `autoUpdate` or `/plugin marketplace update claude-harness`. See `CONTRIBUTING.md` for the flow, and
  `docs/VERSIONING.md` for what counts as **breaking**, the **deprecate-before-remove** rule, the
  **per-major migration-guide** requirement, and the consumer **`autoUpdate` heuristic**.

## Quality gate

`bash scripts/validate.sh` checks: JSON manifests parse · version is single-sourced · `bash -n` on every
hook + `*.sh.template` · `shellcheck` (if installed) · `claude plugin validate` (if installed) ·
skill/agent frontmatter (rejecting an empty/quoted-empty `description`) · `hooks.json` referential
integrity · **consumption wiring** (the marketplace entry resolves to a real plugin dir whose
`plugin.json` name matches and that ships a `hooks.json` — the no-CLI static proxy for "a consumer can
load this plugin") · **bash-3.2 multibyte-safe interpolation** (no bare `$VAR` before a non-ASCII byte) ·
every `tests/*.test.sh`. It runs in **three
places, identically**: as a local git **pre-commit** (via `.githooks/`) and in **CI on every push/PR on
both Linux and macOS** — the macOS job runs the gate under the system **bash 3.2.57** (`/bin/bash`), the
floor the hooks must stay portable to, so a bash-4-ism can't reach consumers. All free for this public
repo, so a contributor who skips the local hook still can't merge a red gate. **Enable the local hook once
per clone:**

```
bash scripts/setup.sh            # or: git config core.hooksPath .githooks
```

Bypass a single local commit in an emergency with `git commit --no-verify` (CI still runs).

`main` is branch-protected: the `validate` check is **required** and force-push/deletion are blocked.
`enforce_admins` is intentionally **off** so the solo maintainer is never locked out — a deliberate
trade-off (an admin *can* merge without a second reviewer; the four-eyes protocol above stays the norm).
Actions are SHA-pinned (with version comments) and kept current by Dependabot.
