# shellcheck shell=bash
# Shared helpers for the harness SessionStart hooks.
# Portable to macOS bash 3.2 (no `timeout`/`gtimeout`, no `jq`). Source me; do not execute.

# run_with_timeout <seconds> <stdout-file> <command...>
# Runs <command...> with stdout redirected to <stdout-file> (use /dev/null to discard).
# Hard-kills it after <seconds> via a background watchdog (since macOS has no `timeout`).
# Returns the command's exit code, or non-zero (>=128) if it was killed. Never hangs a session.
run_with_timeout() {
  local secs="$1" out="$2"; shift 2
  "$@" >"$out" 2>/dev/null &
  local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local killer=$!
  local rc=0
  wait "$pid" 2>/dev/null; rc=$?
  kill -TERM "$killer" 2>/dev/null
  wait "$killer" 2>/dev/null
  return "$rc"
}

# json_str <text> -> a JSON-quoted, escaped string literal (handles \ and ").
json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

# emit_context <message>
# Emits the documented SessionStart hook output so the message becomes session context
# (hookSpecificOutput.additionalContext). Single-line messages only.
emit_context() {
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$(json_str "$1")"
}
