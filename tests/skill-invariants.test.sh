#!/usr/bin/env bash
# Behavior tests for the security-critical SKILL invariants the harness must never silently lose.
# Skills are prompt-driven (not state machines), so we test two real, deterministic things:
#   1. STATIC PRESENCE of each guardrail in the skill file — this build breaks the moment an
#      invariant line is deleted or reworded away, which is exactly the regression we want to catch.
#   2. RUNTIME behavior of the referenced PreToolUse guard template (A3) — the no-force-push and
#      no-destructive-reset invariants are turned into actual hard blocks there.
# No git, no network. Exits non-zero on any failed assertion.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
S="$ROOT/plugins/harness/skills"
GUARD="$ROOT/plugins/harness/hooks/templates/pretooluse-guard.sh.template"
fails=0

# must_match <file> <extended-regex> <label>: the file must contain a line matching (case-insensitive).
must_match() {
  if grep -iqE -- "$2" "$1" 2>/dev/null; then :; else
    echo "FAIL [$3]: invariant missing from ${1##*/plugins/harness/}  (/$2/ not found)"
    fails=$((fails + 1))
  fi
}
# guard_denies <payload> <label>: the A3 guard must emit a deny decision for this tool call.
guard_denies() {
  out="$(printf '%s' "$1" | bash "$GUARD" 2>/dev/null)"
  case "$out" in *'"permissionDecision":"deny"'*) ;; *)
    echo "FAIL [$2]: guard did not deny: $1"
    fails=$((fails + 1)) ;; esac
}

# --- finish-pr: the git-mutating skill must carry every critical guardrail ---
FP="$S/finish-pr/SKILL.md"
must_match "$FP" 'never push to the default branch' "finish-pr: no push to the default branch"
must_match "$FP" 'never rebase a published' "finish-pr: no rebase of a published PR"
must_match "$FP" 'never[^.]*--force' "finish-pr: no force-push"
must_match "$FP" 'never weaken, skip, or delete tests' "finish-pr: never weaken/skip/delete tests"

# --- plan-change: plan-only, zero git/gh mutation ---
must_match "$S/plan-change/SKILL.md" 'zero file edits' "plan-change: plan-only, no git/gh mutation"

# --- create-issue: produces only the issue, no code changes ---
must_match "$S/create-issue/SKILL.md" 'makes no code changes' "create-issue: no code changes"

# --- the no-force / no-destructive invariants are enforceable by the A3 PreToolUse guard ---
guard_denies '{"tool_name":"Bash","tool_input":{"command":"git push --force"}}' "guard denies force-push"
guard_denies '{"tool_name":"Bash","tool_input":{"command":"git push --force-with-lease"}}' "guard denies force-with-lease"
guard_denies '{"tool_name":"Bash","tool_input":{"command":"git reset --hard HEAD~1"}}' "guard denies reset --hard"

if [ "$fails" -eq 0 ]; then
  echo "skill-invariants.test.sh: PASS"
else
  echo "skill-invariants.test.sh: $fails assertion(s) FAILED"
  exit 1
fi
