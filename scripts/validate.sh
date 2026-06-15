#!/usr/bin/env bash
# Self-validation gate for claude-harness (Node-free, no GitHub compute).
# Run manually or via the pre-commit hook in .githooks/. Exits non-zero on any failure.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
cd "$ROOT" || exit 1
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

# 7) Skill + agent frontmatter (name + NON-EMPTY description). Runs without the `claude` CLI — which
#    only WARNS on a missing description (exit 0) and never checks it when absent. A skill/agent with a
#    blank description degrades triggering in EVERY consumer, so we hard-fail here. (python3 = already
#    a gate dependency, used above for JSON.)
fm_reason() { # $1=file -> prints "" on ok, or a reason; exit 1 on fail
  python3 - "$1" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
if not t.startswith("---"):
    print("no frontmatter"); sys.exit(1)
end = t.find("\n---", 3)
if end < 0:
    print("unterminated frontmatter"); sys.exit(1)
lines = t[3:end].splitlines()
def has(key):
    for i, l in enumerate(lines):
        m = re.match(r"^" + key + r":\s*(.*)$", l)
        if not m:
            continue
        val = m.group(1).strip()
        if val and val not in (">", ">-", ">+", "|", "|-", "|+"):
            return True  # inline value
        for nl in lines[i + 1:]:        # block scalar / empty inline -> need an indented continuation
            if nl.strip() == "":
                continue
            return bool(nl[:1] in (" ", "\t"))
        return False
    return False
missing = [k for k in ("name", "description") if not has(k)]
if missing:
    print("missing/empty: " + ", ".join(missing)); sys.exit(1)
sys.exit(0)
PY
}
while IFS= read -r f; do
  r="$(fm_reason "$f" 2>&1)" && ok "frontmatter — ${f#plugins/harness/}" || no "frontmatter — ${f#plugins/harness/} ($r)"
done < <({ find plugins/harness/skills -name 'SKILL.md'; find plugins/harness/agents -name '*.md'; } | sort)

# 8) hooks.json referential integrity: every ${CLAUDE_PLUGIN_ROOT}/… script it points to must exist.
#    A typo'd path silently no-ops in every consumer's session, and `claude plugin validate` does not
#    flag it. (Empirically verified 2026-06-15.)
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ -f "plugins/harness/$rel" ]; then ok "hook ref exists — $rel"; else
    no "hooks.json references MISSING script — plugins/harness/$rel"
  fi
done < <(python3 - <<'PY'
import json, re
d = json.load(open("plugins/harness/hooks/hooks.json"))
seen = []
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "command" and isinstance(v, str):
                for m in re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\s\"']+)", v):
                    if m not in seen:
                        seen.append(m)
            else:
                walk(v)
    elif isinstance(o, list):
        for x in o:
            walk(x)
walk(d)
print("\n".join(seen))
PY
)

if [ "$fail" -eq 0 ]; then
  printf '\033[32mvalidate: ALL GREEN\033[0m\n'
else
  printf '\033[31mvalidate: FAILED\033[0m\n'
fi
exit "$fail"
