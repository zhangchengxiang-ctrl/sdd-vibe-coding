#!/usr/bin/env bash
# Install this repository as a local Codex plugin.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKETPLACE="sdd-vibe-coding-local"
PLUGIN="sdd-vibe-coding@${MARKETPLACE}"

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: Codex CLI is required." >&2
  exit 1
fi

version="$(
  python3 - "$PLUGIN_ROOT/.codex-plugin/plugin.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)["version"])
PY
)"

codex plugin marketplace remove "$MARKETPLACE" >/dev/null 2>&1 || true
codex plugin marketplace add "$PLUGIN_ROOT"
codex plugin add "$PLUGIN"

echo "Installed $PLUGIN v$version from $PLUGIN_ROOT"
echo "Restart Codex or start a new task before validating skill discovery."
