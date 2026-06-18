#!/usr/bin/env bash
# SessionStart reminder: inject the universal anti-hallucination rule into EVERY consumer session as
# context (hookSpecificOutput.additionalContext). Stack-agnostic — names no project, language, or tool.
# Pure stdout: no I/O, no network, no throttle/stamp (the reminder is cheap and we want it every
# session). Portable to macOS bash 3.2. Always exits 0.
# Opt-out: HARNESS_AH_REMINDER=off
set -u

case "${HARNESS_AH_REMINDER:-on}" in off | 0 | false) exit 0 ;; esac

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$SELF_DIR/lib/common.sh" || exit 0

emit_context "🧭 Anti-hallucination (harness, universal): Verify before asserting — especially negative/absence claims (\"X doesn't exist\", \"not installed\", \"no such option\", \"that flag/tool/file is missing\"). Validate against the live source of truth (filesystem, --version, the package registry, MCP introspection, an actual invocation), never from memory. An in-context list or summary is NOT a source of truth — it can be incomplete (e.g. a loaded tool/skill list may omit plugin-provided ones). When unsure, verify rather than guess; if something genuinely cannot be verified, say so explicitly instead of inventing it."
exit 0
