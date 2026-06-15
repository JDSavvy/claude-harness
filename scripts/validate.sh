#!/usr/bin/env bash
# Self-validation gate for claude-harness (Node-free, no GitHub compute).
# Run manually or via the pre-commit hook in .githooks/. Exits non-zero on any failure.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
cd "$ROOT"
fail=0
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
no() {
  printf '  \033[31m✗\033[0m %s\n' "$1"
  fail=1
}
skip() { printf '  \033[33m•\033[0m %s\n' "$1"; }

echo "claude-harness · validate"

# 1) JSON manifests parse.
for f in .claude-plugin/marketplace.json plugins/harness/.claude-plugin/plugin.json \
  plugins/harness/hooks/hooks.json; do
  if python3 -c "import json;json.load(open('$f'))" 2>/dev/null; then ok "json parses — $f"; else no "json INVALID — $f"; fi
done

# 2) Version is single-sourced (must NOT exist in the marketplace plugin entry).
if python3 -c "import json,sys;d=json.load(open('.claude-plugin/marketplace.json'));sys.exit('version' in d['plugins'][0])" 2>/dev/null; then
  ok "version single-sourced (plugin.json only)"
else
  no "version duplicated in marketplace.json — remove it (plugin.json wins)"
fi

# 3) bash syntax for every hook + lib script.
while IFS= read -r s; do
  if bash -n "$s" 2>/dev/null; then ok "bash -n — ${s#plugins/harness/}"; else no "bash syntax — $s"; fi
done < <(find plugins/harness/hooks -name '*.sh' | sort)

# 4) shellcheck (if installed).
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning -x plugins/harness/hooks/*.sh plugins/harness/hooks/lib/*.sh 2>/dev/null; then
    ok "shellcheck"
  else
    no "shellcheck reported issues"
  fi
else
  skip "shellcheck not installed — skipped"
fi

# 5) claude plugin validate (if the CLI is installed).
if command -v claude >/dev/null 2>&1; then
  if claude plugin validate ./plugins/harness >/dev/null 2>&1; then ok "claude plugin validate"; else no "claude plugin validate failed"; fi
else
  skip "claude CLI not installed — skipped"
fi

# 6) Hook behavior tests (the git-sync hook mutates state → regression-protected).
if bash tests/git-sync.test.sh >/dev/null 2>&1; then ok "hook tests — tests/git-sync.test.sh"; else no "hook tests FAILED (run: bash tests/git-sync.test.sh)"; fi

if [ "$fail" -eq 0 ]; then
  printf '\033[32mvalidate: ALL GREEN\033[0m\n'
else
  printf '\033[31mvalidate: FAILED\033[0m\n'
fi
exit "$fail"
