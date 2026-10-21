#!/usr/bin/env python3
"""anchor-style.py — rewrite section links (`file.md#fragment`) between GitHub and Obsidian styles.

GitHub and VS Code resolve a fragment only as a GitHub slug (`#42-durable-evidence-gate`);
Obsidian resolves it only as the heading text (`#4.2%20Durable%20Evidence%20Gate`). An estate
read mostly in Obsidian can convert its living documents with --to obsidian; a public copy is
converted back with --to github. Optional: nothing in the harness requires either style.

Usage:
  anchor-style.py --to obsidian|github [--check] PATH...

PATH is a Markdown file or a directory (searched recursively for *.md). Each relative link
with a fragment is matched to a heading of its target file by heading text, then GitHub slug,
then — for renumbered sections — the slug without its leading section number, if that is
unique. Matched fragments are rewritten in the requested style; unmatched ones are left as
they are and listed. --check writes nothing. Exit 0 when every fragment resolved, 1 when any
did not, 2 on bad arguments.

Never pass dated or append-only records (ticket Session Logs, audits, retrospectives): the
script edits what it is given.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import quote, unquote

LINK_RE = re.compile(r"(?<!!)(\[[^\]]*\]\()(<?)([^)\s>#]*)#([^)\s>]+)(>?\))")
FENCE_RE = re.compile(r"^\s*(```|~~~)")
HEADING_RE = re.compile(r"^#{1,6}\s+(.*?)\s*#*\s*$")
SKIP_DIRS = {".git", "Logs", "Dump", "_retired", ".ipynb_checkpoints", "node_modules"}


def github_slug(text: str) -> str:
    # Same rule as audit-inventory.py: inline-code text is kept, other punctuation dropped.
    return re.sub(r"[^a-z0-9 _-]", "", text.replace("`", "").strip().lower()).replace(" ", "-")


def obsidian_fragment(text: str) -> str:
    return quote(text, safe="-._~")


def headings_of(path: Path, cache: dict[Path, list[str]]) -> list[str]:
    if path not in cache:
        found, fenced = [], False
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if FENCE_RE.match(line):
                fenced = not fenced
            elif not fenced and (m := HEADING_RE.match(line)):
                found.append(m.group(1))
        cache[path] = found
    return cache[path]


def resolve(fragment: str, headings: list[str]) -> str | None:
    """Return the heading a fragment points at, or None when it is absent or ambiguous."""
    wanted = unquote(fragment)
    for h in headings:
        if h.strip().lower() == wanted.strip().lower():
            return h
    for h in headings:
        if github_slug(h) == wanted.lower():
            return h
    # A renumbered section: compare slugs with the leading section number removed.
    bare = re.sub(r"^\d+-", "", github_slug(wanted))
    hits = [h for h in headings if re.sub(r"^\d+-", "", github_slug(h)) == bare]
    return hits[0] if len(hits) == 1 else None


def convert(path: Path, style: str, cache: dict, write: bool) -> tuple[int, list[str]]:
    changed, unresolved, fenced, out = 0, [], False, []
    # newline="" on both the read and the write keeps each line's own ending byte for byte. The
    # default translation read CRLF as LF and, on Windows, wrote every LF back as CRLF, so a single
    # conversion rewrote the line endings of the whole document.
    with path.open(encoding="utf-8", newline="") as handle:
        text = handle.read()
    for number, line in enumerate(text.splitlines(keepends=True), start=1):
        if FENCE_RE.match(line):
            fenced = not fenced
        if fenced or FENCE_RE.match(line):
            out.append(line)
            continue
        # Inline code spans are copied untouched; only the text between them is rewritten.
        parts = re.split(r"(`[^`]*`)", line)
        for i, part in enumerate(parts):
            if part.startswith("`"):
                continue

            def rewrite(m: re.Match) -> str:
                nonlocal changed
                head, lt, target, fragment, tail = m.groups()
                if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or fragment.startswith("^") \
                        or re.fullmatch(r"L\d+(-L\d+)?", fragment):
                    return m.group(0)
                dest = path if not target else (path.parent / unquote(target)).resolve()
                if dest.suffix.lower() != ".md" or not dest.is_file():
                    return m.group(0)
                heading = resolve(fragment, headings_of(dest, cache))
                if heading is None:
                    unresolved.append(f"{path}:{number}: #{fragment}")
                    return m.group(0)
                new = obsidian_fragment(heading) if style == "obsidian" else github_slug(heading)
                if new != fragment:
                    changed += 1
                return f"{head}{lt}{target}#{new}{tail}"

            parts[i] = LINK_RE.sub(rewrite, part)
        out.append("".join(parts))
    if write and changed:
        path.write_text("".join(out), encoding="utf-8", newline="")
    return changed, unresolved


def markdown_files(paths: list[str]) -> list[Path]:
    files = []
    for p in map(Path, paths):
        if p.is_dir():
            files += [f for f in sorted(p.rglob("*.md")) if not SKIP_DIRS & set(f.parts)]
        elif p.suffix.lower() == ".md" and p.is_file():
            files.append(p)
        else:
            print(f"anchor-style: not a Markdown file or directory: {p}", file=sys.stderr)
            sys.exit(2)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description="Rewrite section links between GitHub and Obsidian styles.")
    parser.add_argument("--to", choices=["obsidian", "github"], required=True)
    parser.add_argument("--check", action="store_true", help="report only; write nothing")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    cache: dict[Path, list[str]] = {}
    total, files_changed, unresolved = 0, 0, []
    for f in markdown_files(args.paths):
        n, bad = convert(f.resolve(), args.to, cache, write=not args.check)
        total += n
        files_changed += bool(n)
        unresolved += bad
    verb = "would convert" if args.check else "converted"
    print(f"anchor-style: {verb} {total} link(s) in {files_changed} file(s) to {args.to} style.")
    for item in unresolved:
        print(f"UNRESOLVED {item}")
    return 1 if unresolved else 0


if __name__ == "__main__":
    sys.exit(main())
