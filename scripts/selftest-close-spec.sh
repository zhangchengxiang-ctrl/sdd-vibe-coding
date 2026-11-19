#!/usr/bin/env bash
# Offline self-test for close-spec.sh + check_spec.py host compatibility.
#
# Covers what an existing host (one that predates this plugin's conventions) actually trips on:
#   1. `SDD archive dir:` is honoured; no second `archive/` appears
#   2. an annotated status cell closes, and the original text lands in the change log
#   3. `- Status:` bullet style closes
#   4. links INTO the moved Spec and the moved files' OWN relative links are rewritten
#   5. check_spec --all does not treat the archive dir as a Spec
#   6. check_spec warns (never fails) on a status that does not start with a vocabulary word
#   7. with no declaration the default dir is still `archive`
# Skips verify-deliver (needs a Docker-capable host); that gate has its own selftests.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/skills/spec/scripts/check_spec.py"
pass=0; fail=0
ok()  { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }
expect() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mk_host() {  # $1 = dir, $2 = archive declaration line (may be empty)
  local h="$1"; mkdir -p "$h/docs/specs/v1-annotated" "$h/docs/specs/v2-bullet" "$h/docs/product"
  git -C "$h" init -q
  printf '# Agents\n%s\n' "${2:-}" > "$h/AGENTS.md"
  echo "# product" > "$h/docs/product/x.md"
  cat > "$h/docs/specs/v1-annotated/VERSION.md" <<'V'
# Version · v1-annotated

| 字段 | 值 |
|---|---|
| **状态** | `verifying`（已上线 main=abc，待复测） |

## 变更记录

| 日期 | 变更 | 依据 |
|---|---|---|
| 2026-01-01 | 初版 | t |
V
  printf '# c\n\nSee [product](../../product/x.md).\n' > "$h/docs/specs/v1-annotated/contract.md"
  printf '# Version\n\n- Version: v2-bullet\n- Status: draft\n' > "$h/docs/specs/v2-bullet/VERSION.md"
  printf '# notes\n\n[v1](specs/v1-annotated/VERSION.md) and [c](specs/v1-annotated/contract.md#x)\n' > "$h/docs/notes.md"
  git -C "$h" add -A && git -C "$h" -c user.email=t@t -c user.name=t commit -qm init
}

# ---- host A: declared archive dir `_archive` -------------------------------------------------
A="$TMP/a"; mkdir -p "$A"; mk_host "$A" '- SDD archive dir: _archive'
bash "$ROOT/scripts/close-spec.sh" "$A" v1-annotated --skip-verify-deliver >"$TMP/a1.log" 2>&1
expect "annotated status closes (exit 0)"        grep -q 'close-spec: DONE' "$TMP/a1.log"
expect "moved into declared _archive/"           test -d "$A/docs/specs/_archive/v1-annotated"
expect "no stray archive/ created"               test ! -e "$A/docs/specs/archive"
expect "status cell replaced"                    grep -q '^| \*\*状态\*\* | `archived` |' "$A/docs/specs/_archive/v1-annotated/VERSION.md"
expect "original annotation kept in change log"  grep -q '已上线 main=abc' "$A/docs/specs/_archive/v1-annotated/VERSION.md"
expect "inbound link rewritten"                  grep -q '(specs/_archive/v1-annotated/VERSION.md)' "$A/docs/notes.md"
expect "inbound link keeps its #anchor"          grep -q '(specs/_archive/v1-annotated/contract.md#x)' "$A/docs/notes.md"
expect "moved file's own relative link fixed"    grep -q '(../../../product/x.md)' "$A/docs/specs/_archive/v1-annotated/contract.md"
bash "$ROOT/scripts/close-spec.sh" "$A" v2-bullet --skip-verify-deliver >"$TMP/a2.log" 2>&1
expect "'- Status:' bullet style closes"         grep -q 'close-spec: DONE' "$TMP/a2.log"
expect "bullet status replaced"                  grep -q '^- Status: `archived`' "$A/docs/specs/_archive/v2-bullet/VERSION.md"

# ---- host B: no declaration -> default `archive` --------------------------------------------
B="$TMP/b"; mkdir -p "$B"; mk_host "$B" ''
bash "$ROOT/scripts/close-spec.sh" "$B" v1-annotated --skip-verify-deliver >"$TMP/b1.log" 2>&1
expect "default archive dir is archive/"         test -d "$B/docs/specs/archive/v1-annotated"

# ---- status vocabulary: warns, never fails ----------------------------------------------------
C="$TMP/c"; mkdir -p "$C"; mk_host "$C" ''
sed -i 's/`verifying`（已上线 main=abc，待复测）/✅ 已完成并已发版/' "$C/docs/specs/v1-annotated/VERSION.md"
# Independent of close-spec: a pre-existing `_archive/` full of archived Specs must not be scanned as a Spec.
mkdir -p "$C/docs/specs/_archive/old-spec" && echo "# old" > "$C/docs/specs/_archive/old-spec/VERSION.md"
python3 "$CHECK" "$C" --all --skip-agents >"$TMP/c0.log" 2>&1
expect "check_spec --all does not scan _archive as a Spec" bash -c "! grep -q '== Spec _archive' '$TMP/c0.log'"
python3 "$CHECK" "$C" v1-annotated --skip-agents >"$TMP/c1.log" 2>&1
expect "non-vocabulary status produces a WARN"   grep -q 'VERSION.md: 状态' "$TMP/c1.log"
expect "...and not an ERROR on that account"     bash -c "! grep -E '^ERROR.*VERSION.md: 状态' '$TMP/c1.log'"

echo "--- selftest-close-spec: pass=$pass fail=$fail ---"
[[ $fail -eq 0 ]]
