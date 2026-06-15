#!/usr/bin/env bash
# One-time per-clone setup: route git hooks to the committed .githooks/ dir so the local quality gate
# (scripts/validate.sh) runs on commit. No GitHub compute; no dependencies.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
git -C "$ROOT" config core.hooksPath .githooks
echo "✓ core.hooksPath → .githooks (pre-commit runs scripts/validate.sh). Bypass: git commit --no-verify"
