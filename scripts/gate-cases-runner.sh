#!/usr/bin/env bash
# Gate-case catalog + live probes. Replaces adversarial-rot-wave2 inline fixtures.
#
# The catalog (gate-cases.tsv) is the frozen audit record: 91 cases, 40 problems.
# Every problem row must name either a probe that runs here or an open reason,
# so "the 40 are fixed" is a number this script computes, not a claim.
#
# Usage: bash scripts/gate-cases-runner.sh [--baseline-only]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TSV="$ROOT/scripts/fixtures/gate-cases.tsv"
[[ -f "$TSV" ]] || { echo "missing $TSV" >&2; exit 2; }

problems=$(awk -F'\t' 'NR>1 && $8=="1"{c++} END{print c+0}' "$TSV")
total=$(awk -F'\t' 'NR>1{c++} END{print c+0}' "$TSV")
echo "== gate-cases catalog total=$total problems=$problems =="
# Append-only register: the 91/40 audit is the floor. Rows are never deleted,
# only resolved (RESOLUTION=probe). Newly measured holes are appended.
[[ "$problems" -ge 40 && "$total" -ge 91 ]] || {
  echo "FAIL catalog shrank below the 91/40 audit record" >&2
  exit 1
}
[[ "${1:-}" == "--baseline-only" ]] && exit 0

python3 - "$ROOT" <<'PY'
import contextlib, csv, importlib.util, io, sys, tempfile
from pathlib import Path

root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("cs", root / "skills/spec/scripts/check_spec.py")
cs = importlib.util.module_from_spec(spec); spec.loader.exec_module(cs)

# Open problems may only shrink on a fix. Raise this only when a newly measured
# hole is appended to the catalog, and say so in the commit — never to let a
# regression through.
OPEN_CEILING = 7

def quiet(fn, *a, **kw):
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        return fn(*a, **kw)

def honesty(run, closing=False, spec_dir=Path("atk")):
    r = cs.Report()
    quiet(cs.check_run_honesty, spec_dir, run, r, structure_only=False, closing=closing)
    return r.errors

def tests_report(tests):
    r = cs.Report()
    quiet(cs.check_tests, Path("atk"), tests, [], r, structure_only=False)
    return r

hole = 0
passed = set()
def note(good, id_, detail):
    global hole
    if good:
        passed.add(id_); print(f"OK    {id_} — {detail}")
    else:
        hole += 1; print(f"HOLE  {id_} — {detail}", file=sys.stderr)

# --- deleted mechanisms must stay deleted (U3 hooks, U6 ALLOW_PARTIAL) ---
note(not (root / "scripts/hooks").exists()
     and not (root / "templates/.cursor/hooks.json").exists()
     and not (root / "templates/.claude/hooks").exists(),
     "hooks-gone", "no hooks subsystem to self-authorize")
note("ALLOW_PARTIAL" not in (root / "scripts/scaffold.sh").read_text(encoding="utf-8"),
     "allow-partial-gone", "scaffold cannot half-write a host")

# --- prose claims no longer buy anything: the close action is the gate ---
run_claim = "- 状态: `acceptance-passed`\n- 是否可以交付: `可交付`\n"
note(honesty(run_claim) == 0, "D01-nonclosing", f"err={honesty(run_claim)}")
note(honesty(run_claim, closing=True) >= 1, "claim-drift-neutralized",
     "ASCII-colon claim still cannot close without evidence")

head = "证伪: done\noverride: 用户要求自写\n### 追踪矩阵\n"
head += "| Requirement | Test | Implementation | Evidence | Result |\n|---|---|---|---|---|\n"

# a close must rest on one artifact; typing a Pass row is not enough
with tempfile.TemporaryDirectory() as td:
    h = Path(td); sd = h / "docs/specs/s1"; sd.mkdir(parents=True)
    typed = head + "| R-001 | T-001 | a.ts | kind=unit · 3 assertions | Pass |\n"
    note(honesty(typed, closing=True, spec_dir=sd) >= 1, "typed-close-rejected",
         "no artifact on disk")
    (h / "artifacts").mkdir(); (h / "artifacts/t001.log").write_text("ok\n", encoding="utf-8")
    real = head + "| R-001 | T-001 | a.ts | kind=unit · log=artifacts/t001.log | Pass |\n"
    note(honesty(real, closing=True, spec_dir=sd) == 0, "closing-evidence",
         "filled Pass row + real artifact closes")
    note(honesty(real, closing=True, spec_dir=sd) == 0, "real-pass-row-closes",
         "no new false alarm")

ovr = "- 当前模式：`build`\n- 结论：实现完成\noverride: 用户要求自写\noracle-freeze: intact\n红绿证据: N/A · 无自动化\n"
note(honesty(ovr) == 0, "override-1line", f"err={honesty(ovr)}")

eng = "- 当前模式：`build`\n- 结论：implementation complete\n"
note(honesty(eng) >= 1, "E08-english-claim", f"err={honesty(eng)}")

ph = head + "| R-001 | T-001 | | kind=… · | Pass / Fail / Blocked |\n"
note(honesty(ph, closing=True) >= 1, "placeholder-evidence", "template menus are not evidence")

mp = head + "| R-001 | T-001 | a.ts | kind=unit · log=nope/missing.log | Pass |\n"
note(honesty(mp, closing=True) >= 1, "missing-artifact", "cited path must exist")

# --- wordlists advise, they do not reject (U2 F08, U4 antipatterns) ---
def one_test(then_body):
    return (
        "## 测试索引\n\n| ID | Type | 标题 |\n|---|---|---|\n| T-001 | success | t |\n\n"
        f"## T-001\n\n### Given\n\n- env: local\n\n### When\n\n1. call it\n\n### Then\n\n{then_body}\n"
    )

weak = tests_report(one_test("- 用户可见：能打开"))
note(weak.errors == 0 and weak.warnings >= 1, "weak-oracle-warns",
     f"err={weak.errors} warn={weak.warnings}")
anti = tests_report(one_test("- 用户可见：引导走完，勾完清单"))
note(anti.errors == 0, "antipattern-warns", f"err={anti.errors}")

tpl_smoke = "- 产品冒烟（目标环境 · P6）：通过 | 未过 | Blocked+原因\n"
note(honesty(tpl_smoke) == 0, "template-smoke-not-a-claim", "menu row is not a prod claim")

# --- valid Markdown must not be rejected on formatting (U1 D13 / D14) ---
spaced = one_test("- 返回 200 且 total==3").replace("### ", "###  ")
note(tests_report(spaced).errors == 0, "atx-spacing-accepted", "###  Heading parses")
pipeless = (
    "## 测试索引\n\nID | Type | 标题\n--- | --- | ---\nT-001 | success | t\n\n"
    "## T-001\n\n### Given\n\n- local env\n\n### When\n\n1. call it\n\n"
    "### Then\n\n- 返回 200 且 total==3\n"
)
note(tests_report(pipeless).errors == 0, "pipeless-table-parsed", "outer pipes are optional")

# --- evidence binding (U5 E13 / E14) ---
with tempfile.TemporaryDirectory() as td:
    host = Path(td)
    logs = host / ".codex-dispatch-logs"; logs.mkdir()
    body = '{"type":"turn.completed","spec":"good-spec-v2","note":"' + "x" * 80 + '"}\n'
    (logs / "run-a.jsonl").write_text(body, encoding="utf-8")
    sd = host / "docs/specs/good-spec"; sd.mkdir(parents=True)
    ok, _ = cs.dispatch_evidence_valid("dispatch-run-id: run-a\n", sd)
    note(not ok, "spec-token-boundary", "good-spec-v2 log does not close good-spec")

    good_body = '{"type":"turn.completed","spec":"good-spec","note":"' + "x" * 80 + '"}\n'
    (logs / "run-b.jsonl").write_text(good_body, encoding="utf-8")
    ok2, _ = cs.dispatch_evidence_valid(
        "dispatch-run-id: run-b\ndispatch-run-id: run-missing\n", sd)
    note(not ok2, "all-run-ids-checked", "a second cited run-id is validated too")

# --- P0 Oracle must be executable, and must be able to fail ------------------
# Measured holes: check_spec accepted a P0 test with no command at all and one whose
# command was `true`; and referential oracles ("同 T-001", "S0 确定的 tests") appear at a
# rate escalating effort does not fix, which no runner can replay.
def oracle_errs(cmd_line, req_extra="", closing=False, rows=None, given="- x"):
    tests = (
        "## 索引\n\n| ID | R |\n|---|---|\n| T-001 | R-001 |\n\n"
        f"## T-001 · probe\n\n### Given\n\n{given}\n\n### When\n\n1. y\n\n"
        "### Then（Oracle）\n\n- offset=0 与 offset=1000 首行 id 不同\n\n"
        "### 自动化\n\n" + cmd_line + "\n"
    )
    if rows is None:
        rows = [{"ID": "R-001", "优先级": "P0", "证据级": "Verified",
                 "需求": "签名 token 校验" + req_extra, "Tests": "T-001"}]
    r = cs.Report()
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        cs.check_p0_oracle_commands(Path("atk"), tests, rows, r, closing=closing)
    # The text matters, not just the count: "errors >= 1" is also satisfied by the
    # unreadable-column report, so a counting probe cannot tell which gate fired.
    return r.errors, r.warnings, buf.getvalue()

note(oracle_errs("- 预期 Evidence Kind：`unit`")[0] >= 1, "oracle-no-command",
     "a P0 test with no 命令 line is rejected")
note(oracle_errs("- 命令：`true`")[0] >= 1, "oracle-noop-command",
     "命令 `true` stays green with the feature deleted, so it is rejected")
note(oracle_errs("- 命令：`PYTHONPATH=. python3 -m pytest tests -q`")[0] == 0,
     "oracle-real-command-passes", "a real command with leading env vars is accepted")
_mo = "- 命令：`manual-only` + 原因：需要真人看排版"
note(oracle_errs(_mo)[1] >= 1 and oracle_errs(_mo, closing=True)[0] >= 1,
     "oracle-manual-only-with-prose-rejected",
     "manual-only buried in prose warns at Build and blocks close (32 live oracles do this)")
note(oracle_errs("- 命令或测试路径：`manual-only`", closing=True)[0] == 0,
     "oracle-manual-only-accepted",
     "the template's own human marker must not be refused by this gate")
note(oracle_errs("- 命令：`tests/backend/x.test.ts`", closing=True)[0] >= 1,
     "oracle-bare-test-path-rejected",
     "a test path is not a command — the runner cannot exec it (write npx vitest run …)")
note(oracle_errs("- 命令：同 T-002。")[0] == 0
     and oracle_errs("- 命令：同 T-002。")[1] >= 1,
     "oracle-referential-warns", "referential oracle warns during Build")
note(oracle_errs("- 命令：同 T-002。", closing=True)[0] >= 1,
     "oracle-referential-blocks-close", "referential oracle cannot close a Spec")
note(oracle_errs("- 命令：`npx vitest run a.test.ts`", req_extra="；文案与移动端可读",
                 closing=True)[0] >= 1,
     "oracle-visible-needs-nonunit",
     "a user-visible requirement gated only by unit tests cannot close")
note(oracle_errs("- 命令：`npx playwright test a.spec.ts`", req_extra="；文案与移动端可读",
                 closing=True)[0] == 0,
     "oracle-visible-browser-passes", "a browser oracle satisfies the user-visible bar")

# --- a gate that applies to zero rows is not a passing gate ------------------
# The P0 set is keyed on two column names. Measured before fixing: `Priority`, traditional
# `優先級`, a `P0（必须）` cell, or a `测试` column each made this gate — and three others —
# return with no output at all, so you could not tell 14 ids checked from none.
REF = "- 命令：同 T-002。"
def r1(**kw):
    base = {"ID": "R-001", "证据级": "Verified", "需求": "签名 token 校验", "Tests": "T-001"}
    base.update(kw)
    return [base]

note("P0-mapped T-001" in oracle_errs(REF, closing=True, rows=r1(**{"Priority": "P0"}))[2],
     "oracle-header-priority-english", "a `Priority` column still reaches the P0 gate")
note("P0-mapped T-001" in oracle_errs(REF, closing=True, rows=r1(**{"優先級": "P0"}))[2],
     "oracle-header-priority-traditional", "a traditional 優先級 column still reaches it")
note("P0-mapped T-001" in oracle_errs(REF, closing=True, rows=r1(**{"优先级": "P0（必须）"}))[2],
     "oracle-priority-value-suffixed", "`P0（必须）` reads as P0")
rows_cn_tests = [{"ID": "R-001", "优先级": "P0", "证据级": "Verified",
                  "需求": "签名 token 校验", "测试": "T-001"}]
note("P0-mapped T-001" in oracle_errs(REF, closing=True, rows=rows_cn_tests)[2],
     "oracle-header-tests-chinese", "a `测试` column still maps the T-id")
unknown = oracle_errs(REF, closing=True, rows=r1(**{"Prio": "P0"}))
note(unknown[0] >= 1 and "no priority column" in unknown[2],
     "oracle-unknown-priority-column-fails",
     "an unreadable priority column is reported, not silently skipped")
none_p0 = oracle_errs(REF, closing=True, rows=r1(**{"优先级": "P1"}))
note(none_p0[0] == 0 and none_p0[1] == 0 and "0 P0→T-xxx" in none_p0[2],
     "oracle-no-p0-is-not-an-error",
     "a Spec with no P0 rows passes — and says so, rather than saying nothing")

# --- the browser bar wants a browser, and only the Oracle's own fields count ---
VIS = "；文案与移动端可读"
note(oracle_errs("- 命令：`npx playwright --version`", req_extra=VIS, closing=True)[0] >= 1,
     "oracle-playwright-version-is-not-a-browser-run",
     "naming the binary without running it does not satisfy the user-visible bar")
note(oracle_errs("- 命令：`npx playwright test a.spec.ts`", req_extra=VIS, closing=True)[0] == 0,
     "oracle-playwright-test-still-passes", "an actual browser run does")
# Attack: the word lands in ### Given, which the close gate used to pool while the dispatch
# throat never looked there — so the same Spec passed one gate and was refused by the other.
note(oracle_errs("- 命令：`npx vitest run a.test.ts`", req_extra=VIS, closing=True,
                 given="- a human operator watches the screen")[0] >= 1,
     "oracle-given-mention-does-not-gate",
     "a non-unit word in Given is not an Oracle; close and throat read the same fields")
# Measured on 332 real requirement rows: bare case-insensitive `UI` matched inside UID,
# setuid, build and required_for_new — 8 backend requirements with nothing to look at —
# while a real confirmation modal was not flagged at all.
note(oracle_errs("- 命令：`npx vitest run a.test.ts`", req_extra="；以目标 UID 执行探针",
                 closing=True)[0] == 0,
     "oracle-uid-is-not-user-visible",
     "UID / setuid / build must not trip the user-visible gate")
note(oracle_errs("- 命令：`npx vitest run a.test.ts`", req_extra="；上传确认弹窗展示文件数与总大小",
                 closing=True)[0] >= 1,
     "oracle-modal-is-user-visible",
     "a confirmation modal needs a non-unit oracle (the old regex missed it entirely)")
note(oracle_errs("- 命令：`manual-only`", req_extra="；上传确认弹窗展示文件数",
                 closing=True)[0] == 0,
     "oracle-modal-closed-by-human",
     "manual-only is the one-line escape hatch for a visible requirement")
# Attacked: a unit test whose FILENAME contains browser/e2e/i18n/mobile used to satisfy
# the non-unit bar. All 7 real requirements this tightening flips had no 命令 line at all
# and passed on requirement prose leaking into the test body.
note(oracle_errs("- 命令：`npx vitest run tests/browser-utils.test.ts`",
                 req_extra="；文案与移动端可读", closing=True)[0] >= 1,
     "oracle-vitest-cannot-fake-browser",
     "a unit test named browser-* does not satisfy a user-visible requirement")
note(oracle_errs("- 命令：`npx vitest run a.test.ts`\n- 预期 Evidence Kind：`browser-job`",
                 req_extra="；文案与移动端可读", closing=True)[0] == 0,
     "oracle-declared-browser-kind-passes",
     "a declared browser-job Evidence Kind satisfies the bar")

# --- catalog accounting: every problem row names a probe or an open reason ---
rows = list(csv.DictReader((root / "scripts/fixtures/gate-cases.tsv").open(encoding="utf-8"),
                           delimiter="\t"))
open_rows, unbound = [], []
for r in rows:
    if r.get("PROBLEM") != "1":
        continue
    res, ref = (r.get("RESOLUTION") or "").strip(), (r.get("REF") or "").strip()
    if res == "open":
        open_rows.append(f"{r['CASE_ID']}:{ref or '?'}")
    elif res == "probe":
        if ref not in passed:
            unbound.append(f"{r['CASE_ID']}->{ref or '?'}")
    else:
        unbound.append(f"{r['CASE_ID']}:no-resolution")

for u in unbound:
    hole += 1
    print(f"HOLE  catalog-binding — {u}", file=sys.stderr)

total_problems = sum(1 for r in rows if r.get("PROBLEM") == "1")
print(f"== catalog problems={total_problems} "
      f"covered={total_problems - len(open_rows) - len(unbound)} "
      f"open={len(open_rows)} ({', '.join(sorted(open_rows)) or 'none'}) ==")
if len(open_rows) > OPEN_CEILING:
    hole += 1
    print(f"HOLE  open-ratchet — open={len(open_rows)} > ceiling {OPEN_CEILING}",
          file=sys.stderr)

print(f"== live probes HOLE={hole} OK={len(passed)} ==")
sys.exit(1 if hole else 0)
PY

# An unwired script looks like coverage and is not: orphan-refs must catch one.
# The name must be random — a literal here would appear in the corpus we scan.
probe="$(mktemp "$ROOT/skills/dispatch-codex/scripts/XXXXXXXX.sh")"
printf '#!/usr/bin/env bash\necho probe\n' >"$probe"
if bash "$ROOT/scripts/orphan-refs.sh" --strict >/dev/null 2>&1; then
  rm -f "$probe"
  echo "HOLE  unwired-script-detected — orphan-refs passed with an unreferenced script" >&2
  exit 1
fi
rm -f "$probe"
echo "OK    unwired-script-detected — an unreferenced script fails orphan-refs --strict"

# Top-level scripts/ used to be outside the unwired scan entirely. Extending the scan
# is not enough on its own: the corpus contains top-level scripts, and a script names
# itself in its own usage text, so counting its own body as a reference would leave the
# check vacuous (measured: 0 hits vs 2 with self-exclusion).
probe="$(mktemp "$ROOT/scripts/XXXXXXXX.sh")"
stem="$(basename "$probe" .sh)"
printf '#!/usr/bin/env bash\n# usage: bash scripts/%s.sh\necho "%s: hi"\n' "$stem" "$stem" >"$probe"
if bash "$ROOT/scripts/orphan-refs.sh" --strict >/dev/null 2>&1; then
  rm -f "$probe"
  echo "HOLE  unwired-selfnaming-toplevel — a self-naming unwired script in scripts/ passed" >&2
  exit 1
fi
rm -f "$probe"
echo "OK    unwired-selfnaming-toplevel — a self-naming script in scripts/ cannot fake wiring"

# Attacked and confirmed: matching the STEM let a script whose stem is a substring of
# other text pass — any short stem is. The check matches the file name with its
# extension, which is what a real invocation writes.
# The fixture name must be random and must not appear literally in this file, or this
# probe would wire its own fixture through the corpus it is testing.
sub_probe="$(mktemp "$ROOT/scripts/XXXXXXXX.sh")"
sub_stem="$(basename "$sub_probe" .sh)"
printf '#!/usr/bin/env bash\necho hi\n' >"$sub_probe"
# The decoy mentions the stem only inside a longer token. It must be a .md, not a .sh:
# a second unwired script would fail --strict on its own and make this probe trivially
# true no matter what the matching rule is.
sub_decoy="$ROOT/scripts/${sub_stem}-notes.md"
printf 'see %s-meter.sh for the wave-2 probes\n' "$sub_stem" >"$sub_decoy"
if bash "$ROOT/scripts/orphan-refs.sh" --strict >/dev/null 2>&1; then
  rm -f "$sub_probe" "$sub_decoy"
  echo "HOLE  unwired-substring-stem — a stem embedded in a longer token faked wiring" >&2
  exit 1
fi
rm -f "$sub_probe" "$sub_decoy"
echo "OK    unwired-substring-stem — a stem that is a substring of other text cannot fake wiring"

# i18n key existence. The plugin repo has no locales, so `make i18n-keys HOST=.` only
# ever prints SKIP — a reachable script with nothing to assert is still not a gate.
# These fixtures carry the assertion: the exact shape that shipped hardcoded English
# to Chinese users while a real 368-line acceptance suite passed.
i18n_fx="$(mktemp -d)"
trap 'rm -rf "$i18n_fx"' EXIT
mkdir -p "$i18n_fx/src/i18n/locales/en" "$i18n_fx/src/i18n/locales/zh-CN" "$i18n_fx/src/ui"
printf '{"panel":{"title":"Title"}}\n' >"$i18n_fx/src/i18n/locales/en/common.json"
printf '{"panel":{"title":"标题"}}\n'   >"$i18n_fx/src/i18n/locales/zh-CN/common.json"
i18n_src="$i18n_fx/src/ui/Panel.tsx"
i18n_run() { bash "$ROOT/scripts/check-i18n-keys.sh" --cwd "$i18n_fx" "$@" >/dev/null 2>&1; }
i18n_note() {  # 1=condition already evaluated by caller via $? style; use explicit args
  if [[ "$1" != "0" ]]; then
    echo "HOLE  $2 — $3" >&2
    exit 1
  fi
  echo "OK    $2 — $3"
}

printf "const a = t('panel.title');\n" >"$i18n_src"
i18n_run && rc=0 || rc=1
i18n_note "$((rc == 0 ? 0 : 1))" "i18n-complete-locales-green" \
  "a key present in every locale is accepted"

printf "const a = t('panel.subtitle', { defaultValue: 'Untitled' });\n" >"$i18n_src"
i18n_run && rc=0 || rc=1
i18n_note "$((rc == 1 ? 0 : 1))" "i18n-masked-defaultvalue-red" \
  "a key in no locale masked by defaultValue is rejected"

printf "const a = t('panel.subtitle');\n" >"$i18n_src"
i18n_run && rc=0 || rc=1
i18n_note "$((rc == 0 ? 0 : 1))" "i18n-unmasked-missing-warns" \
  "an unmasked unknown key only warns (call-site namespacing is legal)"

printf '{"panel":{"title":"Title","only":"EN"}}\n' >"$i18n_fx/src/i18n/locales/en/common.json"
printf "const a = t('panel.title');\n" >"$i18n_src"
i18n_run && rc=0 || rc=1
i18n_note "$((rc == 0 ? 0 : 1))" "i18n-partial-locale-warns-by-default" \
  "a key missing from one locale does not block Build"
i18n_run --strict && rc=0 || rc=1
i18n_note "$((rc == 1 ? 0 : 1))" "i18n-partial-locale-strict-red" \
  "the same partial locale is rejected under --strict"

# Found by attacking this script: the `ns:key` colon form was skipped entirely, and
# agentdeck uses it in 24 live call sites — one of them with a defaultValue, the exact
# shape this check exists to catch. A JSON file name IS the namespace.
printf '{"panel":{"title":"Title"}}\n' >"$i18n_fx/src/i18n/locales/en/common.json"
printf '{"panel":{"title":"标题"}}\n'   >"$i18n_fx/src/i18n/locales/zh-CN/common.json"
printf "const a = t('common:panel.gone', { defaultValue: 'X' });\n" >"$i18n_src"
i18n_run && rc=0 || rc=1
i18n_note "$((rc == 1 ? 0 : 1))" "i18n-ns-key-masked-red" \
  "t('ns:key') masked by defaultValue is caught, not skipped for having a namespace"

# A computed key cannot be enumerated, so this must not read as coverage. Measured: 70 live
# call sites on agentdeck use t(`…${…}`), while the <Trans>/keyPrefix shapes the script
# already warned about occur 0 times there — the loud one was the shape nobody used.
i18n_out() { bash "$ROOT/scripts/check-i18n-keys.sh" --cwd "$i18n_fx" 2>&1; }
printf 'const a = t(`panel.${state}`, { defaultValue: "Pay now" });\n' >"$i18n_src"
i18n_out | grep -q 'dynamic-template=1' && rc=0 || rc=1
i18n_note "$((rc == 0 ? 0 : 1))" "i18n-computed-key-counted" \
  "t(\`a.\${x}\`) is reported as unanalyzed instead of silently skipped"
i18n_out | grep -q 'computed key' && rc=0 || rc=1
i18n_note "$((rc == 0 ? 0 : 1))" "i18n-computed-key-named" \
  "the report names the file, so the number is actionable"
printf "const a = t('panel.title');\n" >"$i18n_src"
i18n_out | grep -q 'dynamic-template=0' && rc=0 || rc=1
i18n_note "$((rc == 0 ? 0 : 1))" "i18n-static-key-not-counted-dynamic" \
  "a static key is not miscounted as computed"

printf "const a = t('common:panel.title');\n" >"$i18n_src"
i18n_run && rc=0 || rc=1
i18n_note "$((rc == 0 ? 0 : 1))" "i18n-ns-key-resolves" \
  "t('ns:key') resolves inside that namespace's own JSON file"

printf "const a = t('settings:panel.title');\n" >"$i18n_src"
i18n_run && rc=0 || rc=1
i18n_note "$((rc == 0 ? 0 : 1))" "i18n-wrong-ns-warns-not-fails" \
  "right key in the wrong namespace warns; only defaultValue masking fails"

printf 'const a = <Trans i18nKey="panel.gone" defaults="X" />;\nconst b = <TranscriptX />;\n' >"$i18n_src"
i18n_out="$(bash "$ROOT/scripts/check-i18n-keys.sh" --cwd "$i18n_fx" 2>&1)"
i18n_note "$(grep -q 'unanalyzed=1' <<<"$i18n_out" && echo 0 || echo 1)" \
  "i18n-unanalyzed-is-reported" \
  "a call shape this script cannot parse is counted, not silently skipped (<TranscriptX is not one)"
rm -rf "$i18n_fx"; trap - EXIT

# The discipline gate must fail closed when it cannot find a base to diff.
if env CI=1 GATE_DISCIPLINE_BASE=refs/__none__ \
    bash "$ROOT/scripts/check-gate-discipline.sh" >/dev/null 2>&1; then
  echo "HOLE  gate-discipline-fail-closed — passed with no base ref under CI" >&2
  exit 1
fi
echo "OK    gate-discipline-fail-closed — no base ref under CI exits 1"
