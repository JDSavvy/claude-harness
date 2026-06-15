#!/usr/bin/env bash
# Generic SessionStart git-sync for ANY repo (framework-agnostic, part of harness@claude-harness).
#
# Behaviour (owner decision, BP 2026-06):
#   - Clean tree AND strictly behind (ahead=0, behind>0) on a tracking branch -> safe `merge --ff-only`.
#   - Anything else (dirty / ahead / diverged / detached / no upstream) -> NOTIFY only, never mutate.
#   - Up to date -> silent.
# Safety: offline-safe (bounded fetch, never hangs), worktree-safe (git plumbing), always exits 0.
# Opt-out:  HARNESS_GIT_SYNC=off  (disable entirely)  |  HARNESS_GIT_SYNC_AUTOFF=off  (notify, no auto-FF)
set -u

case "${HARNESS_GIT_SYNC:-on}" in off | 0 | false) exit 0 ;; esac

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$SELF_DIR/lib/common.sh" || exit 0

# Resolve the consuming repo: prefer CLAUDE_PROJECT_DIR, fall back to CWD. Bail if not a git work tree.
PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$PROJ" 2>/dev/null || exit 0
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" 2>/dev/null || exit 0

# Need an 'origin' remote, a real branch (not detached), and an upstream.
git remote get-url origin >/dev/null 2>&1 || exit 0
BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" || exit 0
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || {
  emit_context "ℹ harness git-sync: branch '$BRANCH' has no upstream — skipped."
  exit 0
}

# Bounded fetch of just the upstream branch (no tags). Never prompt, never hang.
export GIT_TERMINAL_PROMPT=0
REMOTE="${UPSTREAM%%/*}"
RBRANCH="${UPSTREAM#*/}"
run_with_timeout 8 /dev/null git fetch --quiet --no-tags "$REMOTE" "$RBRANCH" || exit 0

# Recompute divergence after the fetch:  rev-list --left-right --count <upstream>...HEAD  => "<behind>\t<ahead>".
# Word-split (whitespace-agnostic: tab or space) instead of relying on a literal tab.
COUNTS="$(git rev-list --left-right --count "${UPSTREAM}...HEAD" 2>/dev/null)" || exit 0
# shellcheck disable=SC2086
set -- $COUNTS
BEHIND="${1:-0}"
AHEAD="${2:-0}"

# Up to date -> silent.
[ "$BEHIND" = "0" ] && [ "$AHEAD" = "0" ] && exit 0

DIRTY=""
[ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY=1

# Auto fast-forward: clean + strictly behind + not ahead.
if [ -z "$DIRTY" ] && [ "$AHEAD" = "0" ] && [ "$BEHIND" -gt 0 ] && [ "${HARNESS_GIT_SYNC_AUTOFF:-on}" != "off" ]; then
  if git merge --ff-only --quiet "$UPSTREAM" 2>/dev/null; then
    emit_context "✅ harness git-sync: fast-forwarded $BRANCH by +$BEHIND from $UPSTREAM (tree was clean & behind). HEAD moved — re-read files if cached."
    exit 0
  fi
fi

# Advisory only.
MSG="⚠ harness git-sync: $BRANCH vs $UPSTREAM —"
[ "$BEHIND" -gt 0 ] && MSG="$MSG ${BEHIND} behind"
[ "$AHEAD" -gt 0 ] && MSG="$MSG ${AHEAD} ahead"
[ -n "$DIRTY" ] && MSG="$MSG (working tree dirty)"
MSG="$MSG. Reconcile before pushing to avoid merge/commit failures."
emit_context "$MSG"
exit 0
