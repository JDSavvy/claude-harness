#!/usr/bin/env bash
# Behavior tests for plugins/harness/hooks/session-git-sync.sh. Exits non-zero on any failed assertion.
# Builds throwaway git repos under a temp dir (left in /tmp; harmless). No network, no external services.
set -u

# Hermetic: a git hook (e.g. .githooks/pre-commit) exports the repo-local env vars (GIT_DIR,
# GIT_INDEX_FILE, GIT_WORK_TREE, GIT_COMMON_DIR, GIT_OBJECT_DIRECTORY, …) into its children.
# `git -C <dir>` does NOT override those, so they would redirect this test's git commands onto
# the REAL repo and corrupt it (stray branches, reset HEAD, polluted config). Drop the complete,
# git-defined set up front so every git call below resolves only its own temp fixtures.
# shellcheck disable=SC2046  # intentional word-split: each name becomes its own unset arg
unset $(git rev-parse --local-env-vars 2>/dev/null)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
HOOK="$ROOT/plugins/harness/hooks/session-git-sync.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/git-sync-test.XXXXXX")"
fails=0

git init -q --bare "$T/remote.git"
git -C "$T/remote.git" symbolic-ref HEAD refs/heads/main
git clone -q "$T/remote.git" "$T/local" 2>/dev/null
git -C "$T/local" config user.email t@t
git -C "$T/local" config user.name t
printf 'c1\n' >"$T/local/f"
git -C "$T/local" add f
git -C "$T/local" commit -qm c1
git -C "$T/local" branch -M main
git -C "$T/local" push -qu origin main

git clone -q "$T/remote.git" "$T/up" 2>/dev/null
git -C "$T/up" config user.email t@t
git -C "$T/up" config user.name t
adv() {
  printf '%s\n' "$1" >>"$T/up/f"
  git -C "$T/up" commit -qam "$1"
  git -C "$T/up" push -q origin main
}
run() { CLAUDE_PROJECT_DIR="$T/local" bash "$HOOK"; }
head_msg() { git -C "$T/local" log --oneline -1 --format='%s'; }

contains() { case "$2" in *"$1"*) ;; *)
  echo "FAIL [$3]: expected '$1' in: $2"
  fails=$((fails + 1)) ;; esac; }
empty() { [ -z "$1" ] || {
  echo "FAIL [$2]: expected empty, got: $1"
  fails=$((fails + 1))
}; }
eq() { [ "$1" = "$2" ] || {
  echo "FAIL [$3]: got '$1' want '$2'"
  fails=$((fails + 1))
}; }

# up-to-date -> silent
empty "$(run)" "up-to-date silent"

# clean + behind -> auto fast-forward, HEAD moves
adv c2
contains "fast-forwarded" "$(run)" "clean+behind notifies FF"
eq "$(head_msg)" "c2" "auto-FF moved HEAD"

# dirty + behind -> notify, NO fast-forward
adv c3
printf 'wip\n' >"$T/local/dirty"
out="$(run)"
contains "behind" "$out" "dirty+behind notifies behind"
contains "dirty" "$out" "dirty+behind notes dirty"
eq "$(head_msg)" "c2" "dirty: HEAD unchanged (no FF)"
rm -f "$T/local/dirty"

# ahead -> notify ahead
git -C "$T/local" pull -q --ff-only
printf 'local\n' >>"$T/local/f"
git -C "$T/local" commit -qam local-ahead
contains "ahead" "$(run)" "ahead notifies"

# no upstream -> notify
git -C "$T/local" checkout -q -b feature-x
contains "no upstream" "$(run)" "no-upstream notifies"

# opt-outs on a clean+behind state
git -C "$T/local" checkout -q main
git -C "$T/local" reset -q --hard origin/main
adv c4
empty "$(HARNESS_GIT_SYNC=off run)" "HARNESS_GIT_SYNC=off silent"
eq "$(head_msg)" "c3" "kill-switch: HEAD unchanged"
out="$(HARNESS_GIT_SYNC_AUTOFF=off run)"
contains "behind" "$out" "AUTOFF=off still notifies"
eq "$(head_msg)" "c3" "AUTOFF=off: HEAD unchanged (no FF)"

if [ "$fails" -eq 0 ]; then
  echo "git-sync.test.sh: PASS"
else
  echo "git-sync.test.sh: $fails assertion(s) FAILED"
  exit 1
fi
