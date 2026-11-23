#!/usr/bin/env python3
"""Where a Spec lives — the one place that knows.

A Spec is the work-context package one version (iteration) is cut into, so it lives inside it:

    <docs>/iterations/<yyyy-mm>/<w>/<version>/README.md       the version (front matter `type: iteration`)
    <docs>/iterations/<yyyy-mm>/<w>/<version>/<spec-id>/      a Spec (has VERSION.md)
    <docs>/specs/_template/                                   the Spec template
    <docs>/specs/<spec-id>/ · specs/<archive>/<spec-id>/      legacy: written before the version layer

The time buckets are a convention (month of the version's start, then week-of-month `w1`…`w5`);
nothing here depends on their spelling. A version is any directory under `iterations/` whose
README.md front matter says `type: iteration`; its Specs are its direct child dirs holding a
VERSION.md. Nothing moves when a Spec or a version closes — the status word says it.

Ids are unique: a Spec id across every version and the legacy tree, a version id across
`iterations/`. `find_spec_dir` reports a duplicate instead of guessing.

CLI (used by the shell tools):
    spec_paths.py find <host> <spec-id>          print the Spec dir; exit 1 if none, 3 if ambiguous
    spec_paths.py find-iteration <host> <id>     print the version dir; exit 1 if none, 3 if ambiguous
    spec_paths.py iteration <spec-dir>           print the version id a Spec dir belongs to (or nothing)
    spec_paths.py list <host>                    print every Spec dir (versions first, then legacy)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

SPECIAL = {"_template", "archive"}
_TYPE = re.compile(r"^type:\s*iteration\s*$", re.M)


def docs_root(host: Path) -> Path:
    agents = host / "AGENTS.md"
    if agents.is_file():
        for line in agents.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"^\s*-\s*SDD docs root:\s*`?([^`\s]+)`?\s*$", line)
            if m:
                return (host / m.group(1).strip().rstrip("/")).resolve()
    return (host / "docs").resolve()


def archive_names(host: Path) -> frozenset[str]:
    names = {"archive"}
    agents = host / "AGENTS.md"
    if agents.is_file():
        for line in agents.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"^\s*-\s*SDD archive dir:\s*`?([^`\s]+)`?\s*$", line)
            if m:
                names.add(m.group(1).strip().strip("/"))
    return frozenset(names)


def _plain(name: str, arch: frozenset[str]) -> bool:
    return not (name in SPECIAL or name in arch or name.startswith(("_", ".")))


def is_iteration_dir(d: Path) -> bool:
    readme = d / "README.md"
    if not readme.is_file():
        return False
    head = readme.read_text(encoding="utf-8", errors="replace")[:600]
    m = re.match(r"^---\n(.*?)\n---\n", head, re.S)
    return bool(m and _TYPE.search(m.group(1)))


def iteration_dirs(docs: Path, arch: frozenset[str] = frozenset()) -> list[Path]:
    """Every version dir under <docs>/iterations/, at any depth (open and closed alike)."""
    base = docs / "iterations"
    out: list[Path] = []
    if not base.is_dir():
        return out
    stack = [base]
    while stack:
        cur = stack.pop()
        for p in sorted(cur.iterdir(), reverse=True):
            if not p.is_dir() or not _plain(p.name, arch):
                continue
            if is_iteration_dir(p):
                out.append(p)          # a version does not contain versions
            else:
                stack.append(p)
    return sorted(out)


def specs_of(iteration: Path, arch: frozenset[str] = frozenset()) -> list[Path]:
    return sorted(p for p in iteration.iterdir()
                  if p.is_dir() and _plain(p.name, arch) and (p / "VERSION.md").is_file())


def iteration_spec_dirs(docs: Path, arch: frozenset[str] = frozenset()) -> list[Path]:
    return [s for it in iteration_dirs(docs, arch) for s in specs_of(it, arch)]


def legacy_spec_dirs(docs: Path, arch: frozenset[str] = frozenset()) -> list[Path]:
    d = docs / "specs"
    return sorted(p for p in d.iterdir() if p.is_dir() and _plain(p.name, arch)) if d.is_dir() else []


def active_spec_dirs(docs: Path, arch: frozenset[str] = frozenset()) -> list[Path]:
    """Every Spec that is not in a legacy archive: in versions, then legacy `specs/<id>`.
    (Whether it is still in flight is the status word's business, not the path's.)"""
    return iteration_spec_dirs(docs, arch) + legacy_spec_dirs(docs, arch)


class AmbiguousSpec(Exception):
    pass


def _one(cands: list[Path], what: str) -> Path | None:
    if len(cands) > 1:
        raise AmbiguousSpec(f"{what} exists in more than one place: " + ", ".join(map(str, cands)))
    return cands[0].resolve() if cands else None


def find_spec_dir(docs: Path, spec_id: str, arch: frozenset[str]) -> Path | None:
    name = Path(spec_id).name
    hit = _one([d for d in active_spec_dirs(docs, arch) if d.name == name], f"Spec id {name}")
    if hit:
        return hit
    # legacy archive: specs/<archive>/<id>, or (hosts that retired docs/specs/) <archive>/specs/<id>
    cands = [docs / "specs" / a / name for a in sorted(arch)] + [docs / a / "specs" / name for a in sorted(arch)]
    return _one([c for c in cands if c.is_dir()], f"Spec id {name}")


def find_iteration_dir(docs: Path, it_id: str, arch: frozenset[str] = frozenset()) -> Path | None:
    return _one([d for d in iteration_dirs(docs, arch) if d.name == it_id], f"version id {it_id}")


def iteration_of(spec_dir: Path) -> str | None:
    """The version a Spec dir sits in; None for a legacy `specs/<id>`."""
    parent = spec_dir.resolve().parent
    return parent.name if is_iteration_dir(parent) else None


def docs_root_of(spec_dir: Path) -> Path | None:
    """The SDD docs root a Spec dir belongs to, from its location alone."""
    p = spec_dir.resolve()
    if is_iteration_dir(p.parent):
        for anc in p.parents:
            if anc.name == "iterations":
                return anc.parent
        return None
    if p.parent.name == "specs":
        return p.parent.parent  # legacy specs/<id> -> docs
    return None


def main(argv: list[str]) -> int:
    cmds = {"find", "find-iteration", "iteration", "list"}
    if len(argv) < 3 or argv[1] not in cmds:
        print(__doc__.split("CLI (used by the shell tools):")[1], file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "iteration":
        it = iteration_of(Path(argv[2]))
        if it:
            print(it)
        return 0
    host = Path(argv[2]).resolve()
    docs, arch = docs_root(host), archive_names(host)
    if cmd == "list":
        for d in active_spec_dirs(docs, arch):
            print(d)
        return 0
    if len(argv) < 4:
        return 2
    try:
        d = (find_spec_dir(docs, argv[3], arch) if cmd == "find"
             else find_iteration_dir(docs, argv[3], arch))
    except AmbiguousSpec as e:
        print(f"spec_paths: {e}", file=sys.stderr)
        return 3
    if d is None:
        return 1
    print(d)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
