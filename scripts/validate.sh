#!/usr/bin/env bash
# Self-validation gate for claude-harness (Node-free, no GitHub compute).
# Run manually or via the pre-commit hook in .githooks/. Exits non-zero on any failure.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
cd "$ROOT" || exit 1

# Invoked from .githooks/pre-commit, git exports the repo-local env vars (GIT_DIR, GIT_INDEX_FILE,
# GIT_WORK_TREE, GIT_COMMON_DIR, GIT_OBJECT_DIRECTORY, …). Clear the complete, git-defined set so
# the git-based behavior tests below run against their own temp fixtures, never the real repo.
# shellcheck disable=SC2046  # intentional word-split: each name becomes its own unset arg
unset $(git rev-parse --local-env-vars 2>/dev/null)

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
  plugins/harness/hooks/hooks.json release-please-config.json .release-please-manifest.json; do
  if python3 -c "import json;json.load(open('$f'))" 2>/dev/null; then ok "json parses — $f"; else no "json INVALID — $f"; fi
done

# 2) Version is single-sourced (must NOT exist in the marketplace plugin entry).
if python3 -c "import json,sys;d=json.load(open('.claude-plugin/marketplace.json'));sys.exit('version' in d['plugins'][0])" 2>/dev/null; then
  ok "version single-sourced (plugin.json only)"
else
  no "version duplicated in marketplace.json — remove it (plugin.json wins)"
fi

# 3) bash syntax for every hook + lib script + copyable *.sh.template (templates aren't *.sh, so
#    they'd otherwise dodge the gate; a syntax-broken template would mislead every consumer).
while IFS= read -r s; do
  if bash -n "$s" 2>/dev/null; then ok "bash -n — ${s#plugins/harness/}"; else no "bash syntax — $s"; fi
done < <(find plugins/harness/hooks \( -name '*.sh' -o -name '*.sh.template' \) | sort)

# 4) shellcheck (if installed) — hooks, lib, and the templates.
if command -v shellcheck >/dev/null 2>&1; then
  sc_files="$(find plugins/harness/hooks \( -name '*.sh' -o -name '*.sh.template' \) | sort)"
  if [ -z "$sc_files" ]; then
    skip "shellcheck — no hook scripts found" # guard: never run bare `shellcheck` (would read stdin)
  # shellcheck disable=SC2086  # intentional word-split: repo-controlled paths, no spaces
  elif shellcheck -S warning -x $sc_files 2>/dev/null; then
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

# 6) Hook behavior tests — every tests/*.test.sh (auto-discovered, so new hooks stay regression-protected).
while IFS= read -r t; do
  [ -n "$t" ] || continue
  if bash "$t" >/dev/null 2>&1; then ok "hook tests — $t"; else no "hook tests FAILED (run: bash $t)"; fi
done < <(find tests -name '*.test.sh' 2>/dev/null | sort)

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
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
            val = val[1:-1].strip()  # a quoted inline value: "" / "   " is semantically empty
        if val and val not in (">", ">-", ">+", "|", "|-", "|+"):
            return True  # non-empty inline value
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

# 9) Consumption wiring (no CLI needed): the static proxy for "does a consumer actually load this
#    plugin?" — the marketplace entry must point at a real plugin dir whose plugin.json `name` matches
#    and that ships a hooks.json. The live `claude plugin validate` above is the full check when the CLI
#    is present; this runs everywhere (CI has no CLI), so a broken marketplace→plugin wiring can't slip by.
wiring="$(python3 - <<'PY' 2>&1
import json, os
try:
    m = json.load(open(".claude-plugin/marketplace.json"))
    p = m["plugins"][0]
    name, path = p.get("name"), p["source"]["path"]
    errs = []
    pj = os.path.join(path, ".claude-plugin", "plugin.json")
    if not os.path.isfile(pj):
        errs.append("marketplace source.path '%s' has no .claude-plugin/plugin.json" % path)
    else:
        d = json.load(open(pj))
        if d.get("name") != name:
            errs.append("name mismatch: marketplace '%s' vs plugin.json '%s'" % (name, d.get("name")))
    if not os.path.isfile(os.path.join(path, "hooks", "hooks.json")):
        errs.append("plugin '%s' ships no hooks/hooks.json" % path)
    print("; ".join(errs))
except Exception as e:
    print("marketplace.json wrong shape: %s" % e)
PY
)"
if [ -z "$wiring" ]; then ok "consumption wiring (marketplace → plugin name + path + hooks.json)"; else no "consumption wiring — $wiring"; fi

# 10) bash-3.2 multibyte-safe interpolation: a bare `$VAR` immediately followed by a multibyte (non-ASCII)
#     byte — e.g. `$OLD→` — makes bash 3.2 in a UTF-8 locale absorb the char's lead byte into the variable
#     name and abort under `set -u`. Brace-delimit it (`${OLD}→`). This caught a real git-sync regression;
#     enforce it deterministically (locale-independent, every platform) so no future hook reintroduces it.
mb="$(python3 - <<'PY' 2>&1
import re, glob
pat = re.compile(r"\$[A-Za-z_][A-Za-z0-9_]*")  # a BARE var ref (no braces)
hits = []
for f in sorted(glob.glob("plugins/harness/hooks/**/*.sh", recursive=True) +
                glob.glob("plugins/harness/hooks/**/*.sh.template", recursive=True)):
    for ln, line in enumerate(open(f, encoding="utf-8"), 1):
        for m in pat.finditer(line):
            nxt = line[m.end():m.end() + 1]
            if nxt and ord(nxt) > 127:
                hits.append("%s:%d  %s%s" % (f, ln, m.group(0), nxt))
print("\n".join(hits))
PY
)"
if [ -z "$mb" ]; then ok "bash-3.2 multibyte-safe interpolation (no bare \$VAR before a non-ASCII byte)"; else
  no "unbraced \$VAR before a multibyte char (brace-delimit it):"
  printf '%s\n' "$mb" | while IFS= read -r h; do [ -n "$h" ] && printf '      %s\n' "$h"; done
fi

if [ "$fail" -eq 0 ]; then
  printf '\033[32mvalidate: ALL GREEN\033[0m\n'
else
  printf '\033[31mvalidate: FAILED\033[0m\n'
fi
exit "$fail"
