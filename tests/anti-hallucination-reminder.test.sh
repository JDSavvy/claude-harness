#!/usr/bin/env bash
# Behavior tests for plugins/harness/hooks/anti-hallucination-reminder.sh.
# Pure stdout/exit-code checks — no git, no network, no state. Exits non-zero on any failed assertion.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
HOOK="$ROOT/plugins/harness/hooks/anti-hallucination-reminder.sh"
fails=0

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

# default: the reminder is emitted as SessionStart context, exit 0.
out="$(bash "$HOOK")"
rc=$?
eq "$rc" "0" "default exits 0"
contains "additionalContext" "$out" "default emits SessionStart additionalContext"
contains "Verify before asserting" "$out" "default carries the rule"
contains "is NOT a source of truth" "$out" "default carries the in-context-list caveat"

# the emitted payload must be valid JSON (guards against escaping regressions in the rule text).
if printf '%s' "$out" | python3 -c "import json,sys;json.load(sys.stdin)" 2>/dev/null; then
  :
else
  echo "FAIL [valid JSON]: emitted output is not valid JSON: $out"
  fails=$((fails + 1))
fi

# opt-out: HARNESS_AH_REMINDER=off -> silent, still exit 0.
out="$(HARNESS_AH_REMINDER=off bash "$HOOK")"
rc=$?
eq "$rc" "0" "opt-out exits 0"
empty "$out" "opt-out suppresses the reminder"

if [ "$fails" -eq 0 ]; then
  echo "anti-hallucination-reminder.test.sh: PASS"
else
  echo "anti-hallucination-reminder.test.sh: $fails assertion(s) FAILED"
  exit 1
fi
