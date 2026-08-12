#!/usr/bin/env bash
# Thin wrapper: wave-2 probes now live in gate-cases.tsv + gate-cases-runner.sh.
# Kept for Makefile / habit compatibility.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$ROOT/scripts/gate-cases-runner.sh" "$@"
