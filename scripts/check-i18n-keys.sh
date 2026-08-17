#!/usr/bin/env bash
# i18n key existence — the cheapest reality anchor there is.
#
# Measured hole: an implementation passed a real 368-line acceptance suite while
# rendering hardcoded English to Chinese users. It referenced two translation keys
# that existed in no locale file and papered over it with i18n's own `defaultValue`
# option. `defaultValue` is a legitimate API, so lint, tsc and vitest were all silent.
#
# Usage: bash scripts/check-i18n-keys.sh [--cwd DIR] [--strict]
# Exit 0 ok / no locales found · 1 finding · 2 usage
set -uo pipefail
CWD="."; STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "check-i18n-keys: unknown option $1" >&2; exit 2 ;;
  esac
done
[[ -d "$CWD" ]] || { echo "check-i18n-keys: not a directory: $CWD" >&2; exit 2; }

python3 - "$CWD" "$STRICT" <<'PY'
import json, re, sys
from pathlib import Path

root, strict = Path(sys.argv[1]).resolve(), sys.argv[2] == "1"
SKIP = re.compile(r"/(node_modules|\.git|dist|build|coverage|\.next|vendor)/")

locale_dirs = sorted(
    {p.parent for p in root.rglob("*.json")
     if "/i18n/locales/" in str(p).replace("\\", "/") and not SKIP.search(str(p) + "/")}
)
if not locale_dirs:
    print("SKIP: no **/i18n/locales/*/ JSON found — nothing to anchor")
    sys.exit(0)

def flatten(obj, prefix=""):
    out = set()
    if isinstance(obj, dict):
        for k, v in obj.items():
            out |= flatten(v, f"{prefix}{k}.")
    else:
        out.add(prefix[:-1])
    return out

# Per namespace, not just per locale: a JSON file name IS the i18next namespace, and
# `t('settings:connections.openTerminal')` must resolve inside settings.json specifically.
# agentdeck uses that colon form in 24 live call sites — one of them with defaultValue,
# the exact shape this script exists to catch — and merging namespaces made it invisible.
per_ns: dict[str, dict[str, set[str]]] = {}
per_locale: dict[str, set[str]] = {}
for d in locale_dirs:
    keys: set[str] = set()
    ns_map: dict[str, set[str]] = {}
    for f in sorted(d.glob("*.json")):
        try:
            ks = flatten(json.loads(f.read_text(encoding="utf-8")))
        except Exception as e:
            print(f"WARN: cannot parse {f.relative_to(root)}: {e}", file=sys.stderr)
            continue
        ns_map[f.stem] = ks
        keys |= ks
    per_ns[d.name] = ns_map
    per_locale[d.name] = keys
known = set().union(*per_locale.values()) if per_locale else set()


def resolves(raw: str) -> bool:
    """A call-site key, with or without an `ns:` prefix, exists in at least one locale."""
    if ":" in raw:
        ns, _, key = raw.partition(":")
        return any(key in nsmap.get(ns, ()) for nsmap in per_ns.values())
    return raw in known

# t('a.b') / t("a.b") / i18n.t(`a.b`) — dotted keys only; bare words are too noisy.
KEY = r"""(?:[A-Za-z_][\w-]*:)?[A-Za-z_][\w-]*(?:\.[\w-]+)+"""
CALL = re.compile(r"""\bt\(\s*['"`](""" + KEY + r""")['"`]""")
DEFAULTED = re.compile(r"""\bt\(\s*['"`](""" + KEY + r""")['"`][^)]{0,400}?defaultValue""", re.S)

# Call shapes this script still cannot resolve. Found by attacking it: `t('ns:key')` was
# missed too, but that one is real — 24 live call sites on agentdeck, one carrying a
# defaultValue — so it got a parser above instead of a warning. These two remain unused
# by every host here, so they get no parser, but they must not be skipped in silence:
# a gate whose quiet means "did not look" is the thing this file exists to prevent.
UNANALYZED = re.compile(r"""<Trans[\s/>]|i18nKey\s*=|useTranslation\([^)]*keyPrefix""")

missing_defaulted: dict[str, str] = {}
missing_plain: dict[str, str] = {}
unanalyzed: dict[str, int] = {}
defaulted_keys: dict[str, str] = {}
for src in root.rglob("*"):
    if src.suffix not in {".ts", ".tsx", ".js", ".jsx", ".vue", ".svelte"}:
        continue
    s = str(src).replace("\\", "/")
    if SKIP.search(s + "/"):
        continue
    try:
        text = src.read_text(encoding="utf-8", errors="replace")
    except Exception:
        continue
    # Count call sites, not pattern hits: `<Trans i18nKey=…>` matches twice on one line.
    n_un = sum(1 for line in text.splitlines() if UNANALYZED.search(line))
    if n_un:
        unanalyzed[str(src.relative_to(root))] = n_un
    defaulted = set(DEFAULTED.findall(text))
    for key in defaulted:
        defaulted_keys.setdefault(key, str(src.relative_to(root)))
    for key in set(CALL.findall(text)):
        if resolves(key):
            continue
        rel = str(src.relative_to(root))
        (missing_defaulted if key in defaulted else missing_plain)[key] = rel

fail = 0
for key, where in sorted(missing_defaulted.items()):
    # The exact shape that shipped English to Chinese users while every check passed.
    print(f"FAIL: {where}: t('{key}') exists in no locale and is masked by defaultValue "
          "— users of every other language see the hardcoded fallback", file=sys.stderr)
    fail = 1

# Masked *and* partially translated is worse than a plain missing translation: the user
# sees the wrong language instead of a visible gap a translator would notice. Measured on
# agentdeck: 592 of 666 defaultValue-carrying keys. That is a translation backlog, not a
# defect this change introduced, so it is counted and not failed — `--strict` is the switch
# for a team that wants to enforce it.
masked_partial = 0
if len(per_locale) > 1:
    for key, where in sorted(defaulted_keys.items()):
        ns, _, k = key.partition(":") if ":" in key else ("", None, key)
        present = [loc for loc, nm in per_ns.items()
                   if (k in nm.get(ns, ()) if ns else any(k in ks for ks in nm.values()))]
        if present and len(present) < len(per_ns):
            masked_partial += 1

incomplete = 0
if len(per_locale) > 1:
    for key in sorted(known):
        absent = [name for name, keys in per_locale.items() if key not in keys]
        if absent and len(absent) < len(per_locale):
            incomplete += 1
            if incomplete <= 10:
                print(f"{'FAIL' if strict else 'WARN'}: key '{key}' missing from "
                      f"{', '.join(absent)}", file=sys.stderr)
    if incomplete and strict:
        fail = 1

for key, where in sorted(missing_plain.items())[:10]:
    print(f"WARN: {where}: t('{key}') not found in any locale "
          "(may be namespaced at the call site)", file=sys.stderr)

for where, n in sorted(unanalyzed.items())[:5]:
    print(f"WARN: {where}: {n} i18n call(s) this script cannot resolve "
          "(<Trans i18nKey> / useTranslation keyPrefix) — not checked, not proof of absence",
          file=sys.stderr)

print(f"--- check-i18n-keys: locales={','.join(sorted(per_locale))} keys={len(known)} "
      f"defaultValue-masked={len(missing_defaulted)} unresolved={len(missing_plain)} "
      f"incomplete={incomplete} masked-partial={masked_partial} unanalyzed={sum(unanalyzed.values())} fail={fail} ---")
sys.exit(fail)
PY
