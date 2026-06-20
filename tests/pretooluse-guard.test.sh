#!/usr/bin/env bash
# Behavior tests for the copyable PreToolUse guard template
# (plugins/harness/hooks/templates/pretooluse-guard.sh.template).
# Pure: feeds JSON payloads on stdin and checks the block decision / exit. No git, no network.
# Exits non-zero on any failed assertion.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
GUARD="$ROOT/plugins/harness/hooks/templates/pretooluse-guard.sh.template"
T="$(mktemp -d "${TMPDIR:-/tmp}/guard-test.XXXXXX")"
fails=0

contains() { case "$2" in *"$1"*) ;; *)
  echo "FAIL [$3]: expected '$1' in: $2"
  fails=$((fails + 1)) ;; esac; }
empty() { [ -z "$1" ] || {
  echo "FAIL [$2]: expected empty (no decision), got: $1"
  fails=$((fails + 1))
}; }
eq() { [ "$1" = "$2" ] || {
  echo "FAIL [$3]: got '$1' want '$2'"
  fails=$((fails + 1))
}; }

run() { printf '%s' "$2" | bash "$1"; } # run <guard> <payload> -> stdout
# blocks <payload> <label>: asserts the guard emits a deny decision and exits 0.
blocks() {
  out="$(run "$GUARD" "$1")"
  rc=$?
  contains '"permissionDecision":"deny"' "$out" "$2 denies"
  eq "$rc" "0" "$2 exits 0 (decision via JSON, not exit code)"
}
# allows <payload> <label>: asserts the guard makes NO decision (empty stdout) and exits 0.
allows() {
  out="$(run "$GUARD" "$1")"
  rc=$?
  empty "$out" "$2 no decision"
  eq "$rc" "0" "$2 exits 0"
}

# --- (1) dangerous Bash is blocked ---
blocks '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/build"}}' "rm -rf"
blocks '{"tool_name":"Bash","tool_input":{"command":"git push origin main --force"}}' "git push --force"
blocks '{"tool_name":"Bash","tool_input":{"command":"git push --force-with-lease"}}' "git push --force-with-lease"
blocks '{"tool_name":"Bash","tool_input":{"command":"git reset --hard origin/main"}}' "git reset --hard"

# --- regression: a JSON-escaped quote BEFORE the dangerous token must NOT slip past the guard.
#     A naive field extractor truncates the command at the first \" and misses the danger; the
#     raw-payload scan catches it. (These payloads carry an escaped \" earlier in the command.) ---
blocks '{"tool_name":"Bash","tool_input":{"command":"cd \"/my project\" && rm -rf node_modules"}}' "rm -rf after a quoted arg"
blocks '{"tool_name":"Bash","tool_input":{"command":"git add -A && git commit -m \"wip\" && git push --force-with-lease"}}' "force-push after a quoted -m"
blocks '{"tool_name":"Bash","tool_input":{"command":"echo \"go\"; git reset --hard HEAD~5"}}' "reset --hard after a quoted echo"

# --- widened destructive forms: short/refspec force-push and rm permutations ---
blocks '{"tool_name":"Bash","tool_input":{"command":"git push -f origin main"}}' "force-push via -f"
blocks '{"tool_name":"Bash","tool_input":{"command":"git push origin +HEAD:main"}}' "force-push via +refspec"
blocks '{"tool_name":"Bash","tool_input":{"command":"rm -r -f /tmp/x"}}' "rm -r -f (split flags)"
blocks '{"tool_name":"Bash","tool_input":{"command":"rm --recursive /tmp/x"}}' "rm --recursive"
blocks '{"tool_name":"Bash","tool_input":{"command":"rm -Rf build"}}' "rm -Rf"
allows '{"tool_name":"Bash","tool_input":{"command":"git push origin my-feature"}}' "normal push not over-blocked"

# --- (2) secret-path writes are blocked ---
blocks '{"tool_name":"Edit","tool_input":{"file_path":"/repo/.env"}}' "edit .env"
blocks '{"tool_name":"Write","tool_input":{"file_path":"config/.env.production"}}' "write .env.production"
blocks '{"tool_name":"Bash","tool_input":{"command":"echo SECRET=1 > .env"}}' "shell redirect into .env"

# --- safe calls make NO decision (normal permission flow still applies) ---
allows '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' "ls"
allows '{"tool_name":"Bash","tool_input":{"command":"git status"}}' "git status"
allows '{"tool_name":"Edit","tool_input":{"file_path":"src/main.py","old_string":"a","new_string":"b"}}' "edit normal file"

# --- the deny payload is valid JSON, and its reason is the VISIBLE audit (shown to Claude) ---
out="$(run "$GUARD" '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/x"}}')"
if printf '%s' "$out" | python3 -c "import json,sys;d=json.load(sys.stdin);h=d['hookSpecificOutput'];assert h['permissionDecision']=='deny';assert h['permissionDecisionReason'].strip()" 2>/dev/null; then :; else
  echo "FAIL [valid JSON]: deny payload is not valid JSON / missing reason: $out"
  fails=$((fails + 1))
fi
contains "blocked by guard" "$out" "deny reason is a visible audit (permissionDecisionReason)"

# --- a visible audit line is also emitted to stderr on a block (lightweight audit trail, no log file) ---
err="$(run "$GUARD" '{"tool_name":"Bash","tool_input":{"command":"rm -rf /x"}}' 2>&1 1>/dev/null)"
contains "harness guard: blocked" "$err" "audit line on block"

# --- opt-out: HARNESS_GUARD=off makes NO decision even for a destructive command ---
out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | HARNESS_GUARD=off bash "$GUARD")"
empty "$out" "HARNESS_GUARD=off suppresses the guard"

# --- off-limits placeholder: inert by default, blocks once filled in ---
allows '{"tool_name":"mcp__prod_db__query","tool_input":{"q":"x"}}' "placeholder inert by default"
FILLED="$T/guard-filled.sh"
sed -e 's/__REPLACE_ME_mcp_prefix__/mcp__prod_db__/' \
  -e 's/__REPLACE_ME_service_ref__/prod-cluster/' "$GUARD" >"$FILLED"
out="$(run "$FILLED" '{"tool_name":"mcp__prod_db__query","tool_input":{"q":"x"}}')"
contains '"permissionDecision":"deny"' "$out" "filled placeholder blocks off-limits MCP tool"
out="$(run "$FILLED" '{"tool_name":"Bash","tool_input":{"command":"kubectl --context prod-cluster delete ns x"}}')"
contains '"permissionDecision":"deny"' "$out" "filled placeholder blocks off-limits ref in bash"
out="$(run "$FILLED" '{"tool_name":"Bash","tool_input":{"command":"echo \"go\"; kubectl --context prod-cluster delete ns x"}}')"
contains '"permissionDecision":"deny"' "$out" "filled placeholder blocks off-limits ref after a quoted arg"

# --- a control byte in the (interpolated) tool_name must not break the deny JSON (stripped, stays valid) ---
out="$(printf '{"tool_name":"mcp__prod_db__q\tX","tool_input":{"q":"x"}}' | bash "$FILLED" 2>/dev/null)"
if printf '%s' "$out" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then :; else
  echo "FAIL [control-char deny JSON]: a tab in tool_name produced invalid deny JSON: $out"
  fails=$((fails + 1))
fi

if [ "$fails" -eq 0 ]; then
  echo "pretooluse-guard.test.sh: PASS"
else
  echo "pretooluse-guard.test.sh: $fails assertion(s) FAILED"
  exit 1
fi
