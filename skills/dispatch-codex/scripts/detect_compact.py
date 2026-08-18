#!/usr/bin/env python3
"""Inspect a Codex `exec --json` jsonl log for real terminal events.

Codex stdout events (observed):
  thread.started, turn.started, item.started, item.completed, turn.completed

`turn.completed` is the real end of the turn. `usage.input_tokens` is
*cumulative billed tokens* (often millions, includes cache) — NOT window size.
Do not trip on that number.

Compact: only explicit event/item types, never a regex over file dumps.

Usage:
  python3 detect_compact.py <log.jsonl>
  python3 detect_compact.py --require-turn <log.jsonl>

Exit: 0 clean, 1 compact or (with --require-turn) missing turn.completed, 2 usage.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

COMPACT_TYPES = frozenset(
    {
        "compaction",
        "compact",
        "auto_compact",
        "auto-compact",
        "context_compact",
        "context-compact",
    }
)


def _type_names(obj: dict) -> list[str]:
    names: list[str] = []
    t = obj.get("type")
    if isinstance(t, str) and t:
        names.append(t)
    for key in ("item", "msg", "payload", "message"):
        inner = obj.get(key)
        if isinstance(inner, dict):
            it = inner.get("type")
            if isinstance(it, str) and it:
                names.append(it)
    return names


def scan(path: Path) -> dict:
    if not path.is_file():
        return {"ok": False, "error": f"missing {path}"}
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        return {"ok": False, "error": str(e)}

    turn_started = False
    turn_completed = False
    actions = 0
    usage = None
    compact_events: list[str] = []
    last_agent = ""

    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(obj, dict):
            continue
        names = _type_names(obj)
        if "turn.started" in names:
            turn_started = True
        if "turn.completed" in names:
            turn_completed = True
            if isinstance(obj.get("usage"), dict):
                usage = obj["usage"]
        for n in names:
            leaf = n.split(".")[-1].lower().replace("_", "-")
            raw = n.lower()
            if raw in COMPACT_TYPES or leaf in COMPACT_TYPES:
                compact_events.append(n)
        item = obj.get("item") if isinstance(obj.get("item"), dict) else {}
        # Budget by what can be counted, not by a predicted token peak. Measured across 720
        # real sessions: at <=50 agent actions 3% were compacted, at 51-200 it was 64%, and
        # past 200 it was 100%. The estimator that this replaces predicted a peak nobody was
        # observed crossing — 342 codex_exec sessions, zero over the cliff.
        if obj.get("type") == "item.completed":
            actions += 1
        if (
            obj.get("type") == "item.completed"
            and item.get("type") == "agent_message"
        ):
            text_val = item.get("text") or item.get("content") or ""
            if isinstance(text_val, list):
                text_val = " ".join(str(x) for x in text_val)
            if isinstance(text_val, str) and text_val.strip():
                last_agent = text_val.strip()

    return {
        "ok": not compact_events,
        "turn_started": turn_started,
        "turn_completed": turn_completed,
        "compact_events": compact_events,
        "usage": usage,
        "actions": actions,
        "action_zone": ("safe" if actions <= 50 else "risky" if actions <= 200 else "past-cliff"),
        "last_agent_chars": len(last_agent),
        "log": str(path),
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("log")
    ap.add_argument(
        "--max-actions",
        type=int,
        default=0,
        help="exit 3 when the run exceeded this many agent actions (0 = report only)",
    )
    ap.add_argument(
        "--require-turn",
        action="store_true",
        help="fail if jsonl has no turn.completed (Codex did not finish the turn)",
    )
    args = ap.parse_args()
    path = Path(args.log)
    result = scan(path)
    print(json.dumps(result, ensure_ascii=False))
    if result.get("error"):
        raise SystemExit(2)
    if result.get("compact_events"):
        raise SystemExit(1)
    if args.require_turn and not result.get("turn_completed"):
        raise SystemExit(1)
    if args.max_actions and result.get("actions", 0) > args.max_actions:
        # A distinct code: the turn finished, so this is not a failed dispatch — it is a unit
        # that should have been split, and the next one must be smaller.
        raise SystemExit(3)
    raise SystemExit(0)


if __name__ == "__main__":
    main()
