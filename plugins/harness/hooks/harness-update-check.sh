#!/usr/bin/env bash
# SessionStart probe: is the installed harness plugin behind its remote? NOTIFY only — never auto-updates
# (auto-updating a globally-shared plugin mid-session is riskier than letting the user run one command).
# Compares the local marketplace clone's HEAD against the true remote tip via a LIVE `ls-remote`
# (the clone's cached origin/main was proven stale in testing, so we never trust it).
# Throttled to once per ~24h via a stamp in CLAUDE_PLUGIN_DATA. Bounded + always exits 0.
# Opt-out: HARNESS_UPDATE_CHECK=off
set -u

case "${HARNESS_UPDATE_CHECK:-on}" in off | 0 | false) exit 0 ;; esac

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$SELF_DIR/lib/common.sh" || exit 0

MKT="$HOME/.claude/plugins/marketplaces/claude-harness"
[ -d "$MKT/.git" ] || exit 0 # harness not installed via marketplace -> nothing to check

# Throttle: skip if we checked within the last day.
DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/claude-harness}"
STAMP="$DATA_DIR/.update-check.stamp"
mkdir -p "$DATA_DIR" 2>/dev/null
if [ -e "$STAMP" ] && find "$STAMP" -mtime -1 2>/dev/null | grep -q .; then exit 0; fi

LOCAL="$(git -C "$MKT" rev-parse HEAD 2>/dev/null)" || exit 0

TMP="$(mktemp 2>/dev/null || echo "/tmp/.harness_lsremote.$$")"
export GIT_TERMINAL_PROMPT=0
run_with_timeout 8 "$TMP" git -C "$MKT" ls-remote origin -h refs/heads/main
REMOTE="$(awk 'NR==1{print $1}' "$TMP" 2>/dev/null)"
rm -f "$TMP"

touch "$STAMP" 2>/dev/null # stamp regardless, so a flaky network doesn't probe every session

[ -n "$REMOTE" ] || exit 0
if [ "$LOCAL" != "$REMOTE" ]; then
  emit_context "🔄 harness plugin update available (local ${LOCAL:0:7} → remote ${REMOTE:0:7}). To update: /plugin marketplace update claude-harness"
fi
exit 0
