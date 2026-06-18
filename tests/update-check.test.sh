#!/usr/bin/env bash
# Behavior tests for plugins/harness/hooks/harness-update-check.sh.
# Hermetic: a temp $HOME holding a "marketplace clone" of a LOCAL bare remote — no real network.
# Exits non-zero on any failed assertion.
set -u

# Drop the repo-local git env vars a pre-commit hook leaks (GIT_DIR, GIT_INDEX_FILE, …) so every git
# call below resolves only its own temp fixtures and can never touch the real repo. (Same guard as
# git-sync.test.sh.)
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars 2>/dev/null)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
HOOK="$ROOT/plugins/harness/hooks/harness-update-check.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/update-check-test.XXXXXX")"
fails=0

contains() { case "$2" in *"$1"*) ;; *)
  echo "FAIL [$3]: expected '$1' in: $2"
  fails=$((fails + 1)) ;; esac; }
empty() { [ -z "$1" ] || {
  echo "FAIL [$2]: expected empty, got: $1"
  fails=$((fails + 1))
}; }

# Bare remote with one commit on main.
git init -q --bare "$T/remote.git"
git -C "$T/remote.git" symbolic-ref HEAD refs/heads/main
git clone -q "$T/remote.git" "$T/work" 2>/dev/null
git -C "$T/work" config user.email t@t
git -C "$T/work" config user.name t
printf 'c1\n' >"$T/work/f"
git -C "$T/work" add f
git -C "$T/work" commit -qm c1
git -C "$T/work" branch -M main
git -C "$T/work" push -qu origin main

# The hook looks for the marketplace clone under $HOME; clone it there (origin = the bare remote).
HOME_DIR="$T/home"
MKT="$HOME_DIR/.claude/plugins/marketplaces/claude-harness"
mkdir -p "$(dirname "$MKT")"
git clone -q "$T/remote.git" "$MKT" 2>/dev/null

DATA="$T/data"
run() { HOME="$HOME_DIR" CLAUDE_PLUGIN_DATA="$DATA" bash "$HOOK"; }
fresh() { rm -rf "$DATA"; } # clear the throttle stamp so the next run actually probes

# opt-out -> silent
empty "$(HARNESS_UPDATE_CHECK=off HOME="$HOME_DIR" CLAUDE_PLUGIN_DATA="$DATA" bash "$HOOK")" "opt-out silent"

# not installed (no marketplace clone under HOME) -> silent
empty "$(HOME="$T/empty-home" CLAUDE_PLUGIN_DATA="$T/data2" bash "$HOOK")" "not-installed silent"

# up to date (clone HEAD == remote tip) -> silent
fresh
empty "$(run)" "up-to-date silent"

# remote advances beyond the clone -> behind -> notify "update available"
printf 'c2\n' >>"$T/work/f"
git -C "$T/work" commit -qam c2
git -C "$T/work" push -q origin main
fresh
contains "update available" "$(run)" "behind notifies"

# throttle: the previous run stamped DATA; a re-run (still behind, fresh stamp) is skipped -> silent
empty "$(run)" "throttled silent"

if [ "$fails" -eq 0 ]; then
  echo "update-check.test.sh: PASS"
else
  echo "update-check.test.sh: $fails assertion(s) FAILED"
  exit 1
fi
