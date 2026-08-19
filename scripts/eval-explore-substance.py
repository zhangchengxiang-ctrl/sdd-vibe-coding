#!/usr/bin/env python3
"""Grade Explore/Deliver agent behavior by output substance, not Read obedience only.

Requires `cursor-agent` on PATH (maintainer local check).

Usage:
  python3 scripts/eval-explore-substance.py
  python3 scripts/eval-explore-substance.py --case ES-INFRA-KILL-LIVE-RELAY
  make eval-explore-substance
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CASES = ROOT / "scripts" / "fixtures" / "explore-substance" / "cases.json"
DEFAULT_AGENT = "cursor-agent"


def extract_read_paths(stream_lines: list[str]) -> list[str]:
    paths: list[str] = []
    for line in stream_lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") != "tool_call":
            continue
        tc = obj.get("tool_call") or {}
        read = tc.get("readToolCall") or {}
        args = read.get("args") or {}
        path = args.get("path")
        if isinstance(path, str) and path:
            if not paths or paths[-1] != path:
                paths.append(path)
    return paths


def extract_result_text(stream_lines: list[str]) -> str:
    for line in reversed(stream_lines):
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") == "result" and isinstance(obj.get("result"), str):
            return obj["result"]
        if obj.get("type") == "assistant":
            msg = obj.get("message") or {}
            content = msg.get("content") or []
            texts = [
                p.get("text", "")
                for p in content
                if isinstance(p, dict) and p.get("type") == "text"
            ]
            if texts:
                return "\n".join(texts)
    return ""


def grade_substance(case: dict, read_paths: list[str], result_text: str) -> list[str]:
    fails: list[str] = []
    blob_reads = "\n".join(read_paths)
    for sub in case.get("must_read_substrings") or []:
        if sub not in blob_reads and sub not in result_text:
            fails.append(f"missing-read-or-mention: {sub}")

    for needle in case.get("must_not_contain") or []:
        if needle in result_text:
            fails.append(f"performance-marker: {needle!r}")

    patterns = case.get("substance_any") or []
    min_hits = int(case.get("substance_min_hits") or 1)
    hits = sum(1 for p in patterns if re.search(re.escape(p), result_text, re.I))
    if hits < min_hits:
        fails.append(
            f"substance: need>={min_hits} of {patterns!r}, got {hits}"
        )

    for needle in case.get("result_must_contain") or []:
        if needle not in result_text:
            fails.append(f"missing-result: {needle!r}")

    return fails


def run_case(
    case: dict,
    *,
    agent: str,
    plugin_dir: Path,
    model: str | None,
) -> tuple[bool, str]:
    fixture_rel = case.get("host_fixture") or ""
    host_src = plugin_dir / fixture_rel
    if not host_src.is_dir():
        return False, f"{case['id']}: missing host_fixture {host_src}"

    with tempfile.TemporaryDirectory(prefix="explore-substance-") as tmp:
        host = Path(tmp) / "host"
        shutil.copytree(host_src, host)
        prompt = (
            f"Plugin directory: {plugin_dir}\n"
            f"Workspace (fixture host): {host}\n\n"
            + case["prompt"]
        )
        cmd = [
            agent,
            "--print",
            "--output-format",
            "stream-json",
            "--trust",
            "--force",
            "--sandbox",
            "enabled",
            "--workspace",
            str(host),
            "--plugin-dir",
            str(plugin_dir),
            prompt,
        ]
        if model:
            cmd.insert(1, model)
            cmd.insert(1, "--model")

        timeout = int(case.get("timeout_sec") or 240)
        try:
            proc = subprocess.run(
                cmd,
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            return False, f"{case['id']}: timeout after {timeout}s"

        lines = [ln for ln in (proc.stdout or "").splitlines() if ln.strip()]
        reads = extract_read_paths(lines)
        result = extract_result_text(lines)
        fails = grade_substance(case, reads, result)
        detail = (
            f"reads({len(reads)})={json.dumps(reads[:12], ensure_ascii=False)} "
            f"result_head={result[:240]!r}"
        )
        if proc.returncode != 0 and not lines:
            return False, (
                f"{case['id']}: agent exit={proc.returncode} "
                f"stderr={proc.stderr[:200]!r}"
            )
        if fails:
            return False, f"{case['id']}: {'; '.join(fails)} | {detail}"
        return True, f"{case['id']}: OK | {detail}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--agent", default=DEFAULT_AGENT)
    parser.add_argument("--plugin-dir", type=Path, default=ROOT)
    parser.add_argument("--model", default=None)
    args = parser.parse_args()

    if shutil.which(args.agent) is None:
        print(f"ERROR: `{args.agent}` not on PATH", file=sys.stderr)
        return 2

    data = json.loads(CASES.read_text(encoding="utf-8"))
    cases = data["cases"]
    if args.case:
        cases = [c for c in cases if c["id"] in args.case]

    ok_n = 0
    failures: list[str] = []
    print(f"Running {len(cases)} explore-substance cases (plugin={args.plugin_dir})")
    for case in cases:
        print(f"== {case['id']} ==")
        passed, msg = run_case(
            case,
            agent=args.agent,
            plugin_dir=args.plugin_dir.resolve(),
            model=args.model,
        )
        print(msg, flush=True)
        if passed:
            ok_n += 1
        else:
            failures.append(msg)

    print("--------")
    print(f"PASS={ok_n} FAIL={len(failures)} TOTAL={len(cases)}")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
