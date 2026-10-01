#!/usr/bin/env python3
"""Observe local navigation without writing records or enforcing ticket grammar.

Scans direct ticket Markdown and AI-Knowledge only after <folder>/<folder>.md
has a Current State heading, plus both general knowledge trees. Skips year-9999
templates, Logs, Dump, .git, _retired, notebooks and all source symlinks. Links
may reference other files, but those files are never opened by following links.

Supported Markdown: inline links (balanced/escaped parentheses, angle-delimited
destinations and optional titles), reference definitions, fenced code, inline
backtick spans and HTML comments. Reference definitions are routes even when
unused; undefined reference labels, inline images, raw HTML links, indented code,
nested link labels, multiline definitions, blockquote fences and Obsidian
wikilinks are not validated. This is not a CommonMark implementation or an
anchor/URL checker. Symbolic <file>, <Topic>, <path/...> placeholders are inert.

Only canonical filename-first index entries and promotion destinations supply
additional routes; the existing validator still owns index grammar validation.
Directory routes resolve to _index.md or the same-named topic Markdown, never
to every descendant. Coverage means reachability in this supported local graph,
not verified facts, lineage, aliases, or complete Markdown interpretation.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import stat
from urllib.parse import unquote, urlsplit


GAK = "General AI-Knowledge"
GHK = "General Human Knowledge"
EXCLUDED = {"Logs", "Dump", ".git", "_retired"}


def blank(text: str) -> str:
    """Keep offsets and line numbers while removing non-prose from parsing."""
    return "".join("\n" if character == "\n" else " " for character in text)


def prose(text: str) -> str:
    """Consume comments/code together so fences inside examples cannot leak links."""
    token = re.compile(r"<!--|^ {0,3}(?P<fence>`{3,}|~{3,})[^\n]*|(?P<ticks>`+)", re.M)
    pieces = []
    offset = 0
    while match := token.search(text, offset):
        start = match.start()
        if match.group() == "<!--":
            closing = text.find("-->", match.end())
            end = len(text) if closing < 0 else closing + 3
        elif fence := match.group("fence"):
            closing = re.compile(r"^ {0,3}" + re.escape(fence[0]) +
                                 "{" + str(len(fence)) + r",}[ \t]*$", re.M).search(text, match.end())
            end = len(text) if closing is None else closing.end()
        else:
            closing = re.compile(r"(?<!`)" + match.group("ticks") + r"(?!`)").search(text, match.end())
            if closing is None:
                pieces.append(text[offset:match.end()])
                offset = match.end()
                continue
            end = closing.end()
        pieces.extend((text[offset:start], blank(text[start:end])))
        offset = end
    pieces.append(text[offset:])
    return "".join(pieces)


def destination(text: str, offset: int) -> tuple[str, int]:
    """Read one destination; nesting matters for ordinary filenames like note(1).md."""
    while offset < len(text) and text[offset].isspace():
        offset += 1
    if offset < len(text) and text[offset] == "<":
        end = text.find(">", offset + 1)
        if end < 0:
            return "", offset
        value = text[offset + 1:end]
        if re.fullmatch(r"(?i)(?:file|topic|repo|board|num|path)(?:[/ ].*)?", value):
            return "", end + 1
        return value, end + 1
    result = []
    depth = 0
    while offset < len(text):
        character = text[offset]
        if character == "\\" and offset + 1 < len(text):
            result.append(text[offset + 1])
            offset += 2
            continue
        if character.isspace() or (character == ")" and depth == 0):
            break
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
        result.append(character)
        offset += 1
    return "".join(result), offset


def routes(text: str, index: bool) -> list[tuple[int, str, bool]]:
    """Extract destinations, never descriptions; promotion routes are estate-relative."""
    found = []
    definitions = re.compile(r"^ {0,3}\[[^\]\n]+\]:[ \t]*", re.M)
    masked = list(text)
    for match in definitions.finditer(text):
        target, end = destination(text, match.end())
        found.append((text.count("\n", 0, match.start()) + 1, target, False))
        masked[match.start():end] = blank(text[match.start():end])
    inline_text = "".join(masked)
    for match in re.finditer(r"(?<!!)(?<!\\)\[(?:\\.|[^\]\\\n])*\]\(", inline_text):
        target, end = destination(inline_text, match.end())
        # A destination must close as a link; trailing prose is not a filesystem route.
        if re.match(r'''\s*(?:"[^"\n]*"|'[^'\n]*'|\([^\n]*?\))?\s*\)''', inline_text[end:]):
            found.append((text.count("\n", 0, match.start()) + 1, target, False))
    if index:
        for line, value in enumerate(text.splitlines(), 1):
            entry = re.match(r"^- ([^\s<>\[\]`]+\.md)(?=\s|$)(.*)$", value)
            if not entry:
                continue
            remainder = entry.group(2)
            if "(promoted" in remainder:
                promoted = re.fullmatch(r"\s+\(promoted\s*->\s*(General AI-Knowledge/[^<>]+)\)\s*", remainder)
                if promoted:
                    found.append((line, promoted.group(1).strip(), True))
            else:
                found.append((line, entry.group(1), False))
    return sorted(set(found))


class Observer:
    """Build a temporary graph of scoped files, with no persistent cache or repairs."""

    def __init__(self, root: Path):
        self.root = root
        self.documents: dict[Path, str] = {}
        self.edges: dict[Path, set[Path]] = {}
        self.tickets: set[Path] = set()
        self.findings: list[dict] = []
        self.links_checked = 0
        self.uninitialized = 0
        self.templates_skipped = 0
        self.map_dir = root / GAK / "Work Map"

    def label(self, path: Path) -> str:
        return path.relative_to(self.root).as_posix() if path.is_relative_to(self.root) else path.as_posix()

    def note(self, code: str, path: Path, message: str, line: int = 0, target: Path | None = None):
        # Fixed messages and paths only: never echo record text, exception payloads or URL queries.
        finding = {"code": code, "path": self.label(path), "line": line, "message": message}
        if target is not None:
            finding["target"] = self.label(target)
        self.findings.append(finding)

    def entries(self, directory: Path) -> list[Path]:
        try:
            if directory.is_symlink():
                self.skip_symlink(directory)
                return []
            return sorted(directory.iterdir())
        except OSError:
            self.note("UNAVAILABLE", directory, "Directory unavailable; coverage is incomplete.")
            return []

    def skip_symlink(self, path: Path):
        try:
            escaped = not path.resolve().is_relative_to(self.root)
        except (OSError, RuntimeError):
            escaped = True
        self.note("OUTSIDE_ESTATE" if escaped else "SYMLINK_SKIPPED", path,
                  "Source symlink not read; coverage is incomplete.")

    def markdown(self, directory: Path, recursive: bool = True):
        # Do not descend into arbitrary ticket assets or follow source symlinks into code/data.
        for path in self.entries(directory):
            if path.name in EXCLUDED:
                continue
            if path.is_symlink():
                self.skip_symlink(path)
                continue
            try:
                kind = path.stat().st_mode
                if stat.S_ISDIR(kind) and recursive:
                    yield from self.markdown(path)
                elif stat.S_ISREG(kind) and path.suffix.lower() == ".md":
                    yield path
            except OSError:
                self.note("UNAVAILABLE", path, "Path unavailable; coverage is incomplete.")

    def read(self, path: Path) -> str | None:
        try:
            if path.is_symlink():
                self.skip_symlink(path)
                return None
            if not stat.S_ISREG(path.stat().st_mode):
                self.note("UNAVAILABLE", path, "Not a regular Markdown file; not read.")
                return None
            return prose(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError):
            self.note("UNAVAILABLE", path, "Markdown unavailable or not UTF-8; coverage is incomplete.")
            return None

    def collect(self):
        for name in (GAK, GHK):
            for path in self.markdown(self.root / name):
                if (text := self.read(path)) is not None:
                    self.documents[path] = text
        for folder in self.entries(self.root / "Tickets"):
            if folder.name in EXCLUDED:
                continue
            if folder.name.startswith("9999"):
                self.templates_skipped += 1
                continue
            if folder.is_symlink():
                self.skip_symlink(folder)
                continue
            if not folder.is_dir() or ((folder / ".not-a-ticket").exists() and
                                       not (folder / ".ticket-pending").exists()):
                continue
            primary = folder / (folder.name + ".md")
            if not primary.exists() and not primary.is_symlink():
                continue
            text = self.read(primary)
            if text is None or not re.search(r"^##[ \t]*Current[ \t]*State[ \t]*#*[ \t]*$", text, re.M):
                continue
            heading = re.search(r"^#\s+(.+)$", text, re.M)
            if (heading is None or re.search(r"<[^>]+>|\bTODO\b|\b[A-Z]+-XXXXX\b", heading.group(1)) or
                    (folder / ".ticket-pending").exists() or "Now: template only" in text):
                self.uninitialized += 1
                self.note("UNINITIALIZED_TICKET", primary,
                          "Placeholder or pending primary; omitted from mapped-ticket totals.")
                continue
            self.tickets.add(primary)
            self.documents[primary] = text
            for path in self.markdown(folder, recursive=False):
                if path != primary and (support := self.read(path)) is not None:
                    self.documents[path] = support
            knowledge = folder / "AI-Knowledge"
            if knowledge.exists() or knowledge.is_symlink():
                for path in self.markdown(knowledge):
                    if (knowledge_text := self.read(path)) is not None:
                        self.documents[path] = knowledge_text

    def entity(self, path: Path) -> bool:
        return any(path.is_relative_to(self.map_dir / kind) for kind in ("Repos", "Pipelines"))

    def resolve(self, source: Path, line: int, raw: str, estate_relative: bool) -> Path | None:
        if not raw or raw.startswith("#") or re.search(r"<[^>]+>", raw):
            return None
        try:
            parsed = urlsplit(raw)
            # URI schemes are opaque, including file:, vscode:, obsidian: and mailto:.
            windows_absolute = Path(raw).is_absolute() and bool(Path(raw).drive)
            if (parsed.scheme and not windows_absolute) or parsed.netloc:
                return None
            local_path = raw.split("#", 1)[0].split("?", 1)[0] if windows_absolute else parsed.path
            decoded = unquote(local_path, encoding="utf-8", errors="strict")
            if not decoded or re.search(r"<[^>]+>", decoded):
                return None
            self.links_checked += 1
            if "\x00" in decoded:
                raise ValueError("invalid path")
            raw_path = Path(decoded)
            base = self.root if estate_relative else source.parent
            candidate = Path(os.path.abspath(base / raw_path))
            target = candidate.resolve()
            # Absolute aliases of the estate (such as macOS /var) still identify its loaded pages.
            if raw_path.is_absolute() and target.is_relative_to(self.root) and not candidate.is_relative_to(self.root):
                candidate = target
            if not candidate.is_relative_to(self.root):
                # Absolute legacy code references may be checked for existence but never traversed.
                if raw_path.is_absolute():
                    if not candidate.exists():
                        self.note("MISSING_LINK", source, "Absolute local target does not exist.", line, candidate)
                    return None
                self.note("OUTSIDE_ESTATE", source, "Decoded relative target escapes the estate; not followed.", line, candidate)
                return None
            if not target.is_relative_to(self.root):
                self.note("OUTSIDE_ESTATE", source, "Symlink target escapes the estate; not followed.", line, candidate)
                return None
            if not target.exists():
                self.note("MISSING_ENTITY" if self.entity(candidate) else "MISSING_LINK", source,
                          "Local target does not exist.", line, candidate)
                return None
            if target.is_dir():
                # A folder is a route to its authored landing page, not blanket coverage of its files.
                for landing in (target / "_index.md", target / (target.name + ".md")):
                    if landing in self.documents:
                        return landing
                return None
            return target if target in self.documents else None
        except (OSError, RuntimeError, ValueError, UnicodeError):
            self.note("UNAVAILABLE", source, "Local target cannot be resolved; not followed.", line)
            return None

    def report(self) -> dict:
        self.collect()
        for path, text in sorted(self.documents.items()):
            self.edges[path] = set()
            for line, target, estate_relative in routes(text, path.name == "_index.md"):
                resolved = self.resolve(path, line, target, estate_relative)
                if resolved is not None:
                    self.edges[path].add(resolved)
        roots = {self.root / name / "_index.md" for name in (GAK, GHK)}
        for index in sorted(roots - self.documents.keys()):
            self.note("MISSING_INDEX", index, "General root index unavailable; coverage is incomplete.")
        reachable: set[Path] = set()
        pending = list(roots & self.documents.keys())
        while pending:
            path = pending.pop()
            if path not in reachable:
                reachable.add(path)
                pending.extend(self.edges.get(path, set()) - reachable)
        notes = {path for path in self.documents if any(path.is_relative_to(self.root / name) for name in (GAK, GHK))}
        for path in sorted(notes - reachable):
            self.note("ORPHAN_NOTE", path, "No supported link path from either general root index.")
        map_index = self.map_dir / "_index.md"
        map_available = map_index in self.documents
        mapped = set()
        if map_available:
            # Only pages discoverable from the map can provide ticket coverage;
            # an orphan entity linking a ticket must not inflate the mapped total.
            map_reachable: set[Path] = set()
            pending = [map_index]
            while pending:
                path = pending.pop()
                if path not in map_reachable:
                    map_reachable.add(path)
                    pending.extend(target for target in self.edges.get(path, set())
                                   if target.is_relative_to(self.map_dir) and target not in map_reachable)
            for path in map_reachable:
                targets = self.edges.get(path, set())
                if self.entity(path):
                    mapped.update(targets & self.tickets)
            for path in sorted(self.tickets - mapped):
                self.note("UNMAPPED_TICKET", path, "No incoming primary-record link from a map entity page.")
        else:
            self.note("MAP_UNAVAILABLE", map_index, "Map index unavailable; ticket mapping checks skipped.")
        self.findings.sort(key=lambda finding: (finding["path"], finding["line"], finding["code"], finding.get("target", "")))
        return {"files_scanned": len(self.documents), "links_checked": self.links_checked,
                "findings": self.findings,
                "coverage": {"tickets": len(self.tickets), "mapped": len(mapped),
                             "uninitialized": self.uninitialized, "templates_skipped": self.templates_skipped,
                             "notes": len(notes), "reachable_notes": len(notes & reachable),
                             "map_available": map_available, "complete": not self.findings}}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2],
                        help="estate root (defaults to this script's estate)")
    parser.add_argument("--json", action="store_true", help="deterministic paths/counts/findings, no source contents")
    parser.add_argument("--strict", action="store_true", help="exit 1 on findings; opt-in for tests or manual use only")
    arguments = parser.parse_args()
    # Bad/unavailable roots still produce the same report contract, never a validator-style red.
    try:
        root = arguments.root.expanduser().resolve()
    except (OSError, RuntimeError):
        root = Path(os.path.abspath(arguments.root))
    report = Observer(root).report()
    if arguments.json:
        print(json.dumps(report, sort_keys=True, ensure_ascii=True))
    else:
        for finding in report["findings"]:
            location = json.dumps(finding["path"], ensure_ascii=True)
            target = " -> " + json.dumps(finding["target"], ensure_ascii=True) if "target" in finding else ""
            print(f"NOTE [work-map:{finding['code']}] {location}:{finding['line']}: {finding['message']}{target}")
        coverage = report["coverage"]
        print(f"NOTE [work-map] {report['files_scanned']} Markdown files, {report['links_checked']} local links; "
              f"{coverage['mapped']}/{coverage['tickets']} initialized tickets mapped; "
              f"{len(report['findings'])} findings.")
    return int(arguments.strict and bool(report["findings"]))


if __name__ == "__main__":
    raise SystemExit(main())