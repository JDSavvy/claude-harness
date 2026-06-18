#!/usr/bin/env bash
# Behavior tests for plugins/harness/hooks/lib/common.sh — json_str, emit_context, run_with_timeout.
# Pure: no network, no git. Exits non-zero on any failed assertion.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/plugins/harness/hooks/lib/common.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/common-test.XXXXXX")"
fails=0

eq() { [ "$1" = "$2" ] || {
  echo "FAIL [$3]: got '$1' want '$2'"
  fails=$((fails + 1))
}; }
contains() { case "$2" in *"$1"*) ;; *)
  echo "FAIL [$3]: expected '$1' in: $2"
  fails=$((fails + 1)) ;; esac; }

# json_str: quotes a plain string, and escapes embedded " and \ (JSON-safe).
eq "$(json_str 'plain')" '"plain"' "json_str plain"
eq "$(json_str 'a"b')" '"a\"b"' "json_str escapes quote"
eq "$(json_str 'a\b')" '"a\\b"' "json_str escapes backslash"

# emit_context: emits the documented SessionStart shape as VALID JSON, message preserved (incl. quotes).
out="$(emit_context 'hello "world"')"
contains '"hookEventName":"SessionStart"' "$out" "emit_context event name"
if ! python3 - "$out" <<'PY'; then
import json, sys
d = json.loads(sys.argv[1])
assert d["hookSpecificOutput"]["hookEventName"] == "SessionStart", "wrong event name"
assert d["hookSpecificOutput"]["additionalContext"] == 'hello "world"', "message not preserved"
PY
  echo "FAIL [emit_context valid JSON / payload]: $out"
  fails=$((fails + 1))
fi

# run_with_timeout: a fast command returns rc 0 and its stdout is captured to the file.
run_with_timeout 5 "$T/out" printf 'hi'
rc=$?
eq "$rc" "0" "run_with_timeout fast rc"
eq "$(cat "$T/out")" "hi" "run_with_timeout fast stdout"

# run_with_timeout: a command exceeding the budget is hard-killed (non-zero rc) and never hangs.
run_with_timeout 1 "$T/out2" sleep 10
rc=$?
[ "$rc" -ne 0 ] || {
  echo "FAIL [run_with_timeout kill]: expected non-zero rc, got 0"
  fails=$((fails + 1))
}

if [ "$fails" -eq 0 ]; then
  echo "common.test.sh: PASS"
else
  echo "common.test.sh: $fails assertion(s) FAILED"
  exit 1
fi
