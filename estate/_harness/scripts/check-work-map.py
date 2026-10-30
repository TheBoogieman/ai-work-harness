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

Earlier estate audit reports are frozen (never edited), so a dead link inside one
is counted as history_links rather than raised as a finding; the newest report
is checked like any other note.

Frontmatter: a leading YAML block (Obsidian properties) is read in the plain
subset Obsidian writes, block or flow lists. repos (repo card file names) is
expected on ticket primaries, walkthroughs, repo cards, pipeline pages and Repo
Workflows runbooks; pipelines (pipeline page slugs) is optional except on a
pipeline page, which lists its own slug. Every value must name an existing Work
Map page; a ticket's repos equals the GitHub/<repo> entries of its header Repos
list; a walkthrough includes its ticket's repos; a repo card lists itself. A
missing property is a NOTE like every finding here, so legacy records stay
grandfathered until a backfill. YAML comments are refused because other scripts
read a "#" line as a Markdown heading.
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
AUDIT_RE = re.compile(r"^\d{8}-estate-audit.*\.md$")
# The two frontmatter list properties this helper reads, and the plain page name a value must be:
# a repo card's or pipeline page's file name without .md, so never a path, a wiki-link or a dotfile.
FRONTMATTER_KEYS = ("repos", "pipelines")
PLAIN_NAME_RE = re.compile(r"^(?!\.)[^/\\\[\]|#^<>:\x00]+$")
FRONTMATTER_MESSAGES = {
    "FRONTMATTER_COMMENT": "YAML comment in frontmatter; other scripts read a # line as a Markdown heading.",
    "FRONTMATTER_MALFORMED": "Frontmatter is not the plain block Obsidian writes; its properties were not read.",
    "FRONTMATTER_MISSING": "No repos property in frontmatter; an empty list is allowed when unknown.",
    "UNKNOWN_REPO": "A repos value names no repo card.",
    "UNKNOWN_REPO_NAME": "A repos value is not a repo card file name (no path or wiki-link).",
    "UNKNOWN_PIPELINE": "A pipelines value names no pipeline page.",
    "UNKNOWN_PIPELINE_NAME": "A pipelines value is not a pipeline page file name (no path or wiki-link).",
}


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


def plain_item(text: str) -> str:
    """One list item as written, with one pair of surrounding quotes removed."""
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        text = text[1:-1]
    return text


def frontmatter(raw: str) -> tuple[dict | None, list[tuple[str, int]]]:
    """Read a leading frontmatter block (Obsidian properties) in the plain subset Obsidian writes.

    Returns (properties, problems). properties is None when line 1 is not "---" or the block is
    malformed, so no value check ever runs on a guess. repos and pipelines are read as lists of
    strings in either form Obsidian may write: a block list ("key:" then "  - item" lines) or a
    flow list ("key: [a, b]"); one pair of quotes around an item is removed. Any other key is
    recorded as present but not read, together with its indented or "- " continuation lines.
    problems holds (code, line) pairs: FRONTMATTER_COMMENT for a "#" comment line, and
    FRONTMATTER_MALFORMED for an unclosed block, a repeated key, a repos or pipelines value that
    is not a list, an unquoted value holding ": ", or any other line.
    """
    lines = raw.lstrip("﻿").split("\n")
    if lines[0].rstrip("\r") != "---":
        return None, []
    end = next((index for index in range(1, len(lines)) if lines[index].rstrip("\r") == "---"), None)
    if end is None:
        return None, [("FRONTMATTER_MALFORMED", 1)]
    properties: dict[str, list[str] | None] = {}
    problems: list[tuple[str, int]] = []
    current, block = None, False
    for index in range(1, end):
        line, number = lines[index].rstrip("\r"), index + 1
        if not line.strip():
            continue
        if line.strip().startswith("#"):
            problems.append(("FRONTMATTER_COMMENT", number))
            continue
        # A key starts in column 0 and is not a list item; its value is the rest of the line.
        key = re.match(r"([^\s#:-][^:]*?):(?:[ \t]+(.*?))?[ \t]*$", line)
        if key:
            name, value = key.group(1), key.group(2) or ""
            if name in properties:
                return None, problems + [("FRONTMATTER_MALFORMED", number)]
            current, block = name, False
            # An unquoted value holding ": " is not a plain scalar in YAML, and Obsidian then drops
            # the whole block (checked in Obsidian 1.14.5), so every property here would silently
            # vanish from search, graph groups and Bases. A quoted value is fine (#331).
            if value[:1] not in ("\"", "'") and ": " in value:
                return None, problems + [("FRONTMATTER_MALFORMED", number)]
            if name not in FRONTMATTER_KEYS:
                properties[name] = None
            elif not value:
                properties[name], block = [], True
            elif value.startswith("[") and value.endswith("]"):
                inner = value[1:-1].strip()
                properties[name] = [plain_item(item) for item in inner.split(",")] if inner else []
            else:
                return None, problems + [("FRONTMATTER_MALFORMED", number)]
            continue
        item = re.match(r"[ \t]*-(?:[ \t]+(.*))?$", line)
        if item and block:
            properties[current].append(plain_item(item.group(1) or ""))
            continue
        if current is not None and current not in FRONTMATTER_KEYS and (item or line[0] in " \t"):
            continue
        return None, problems + [("FRONTMATTER_MALFORMED", number)]
    return properties, problems


def without_frontmatter(text: str) -> str:
    """Blank a closed leading frontmatter block, keeping its line count, so no YAML line reads as Markdown."""
    match = re.match(r"﻿?---\r?\n(?:[^\n]*\n)*?---\r?(?:\n|\Z)", text)
    return blank(text[:match.end()]) + text[match.end():] if match else text


def header_repos(raw: str) -> set[str]:
    """Repo names a ticket header's "Repos:" list gives as GitHub/<repo>, from the raw text so a
    backticked entry counts. An entry without GitHub/ (the estate itself, say) is prose."""
    lines = raw.split("\n")
    for index, line in enumerate(lines):
        # Hand-written headers also bold the label or annotate it ("**Repos:**", "Repos (confirmed
        # by discovery):"); reading only the bare form saw no repos there and passed a wrong [] (#331).
        if re.fullmatch(r"(?:\*\*)?Repos(?:[ \t]*\([^)\n]*\))?(?:\*\*)?:(?:\*\*)?[ \t]*\r?", line):
            names: set[str] = set()
            for entry in lines[index + 1:]:
                if not entry.startswith("- "):
                    break
                names.update(name.rstrip(".") for name in
                             re.findall(r"(?<![A-Za-z0-9])GitHub/([A-Za-z0-9._-]+)", entry))
            return names
    return set()


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
        self.history_links = 0
        # Raw file text, for the checks that must see what prose() blanks (frontmatter, header lists).
        self.raw: dict[Path, str] = {}
        self.frontmatter_expected = 0
        self.frontmatter_present = 0
        self.map_dir = root / GAK / "Work Map"
        audits = sorted(path for path in (root / GHK / "Audits").glob("*.md") if AUDIT_RE.match(path.name))
        self.frozen_audits = set(audits[:-1])

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
            raw = path.read_text(encoding="utf-8")
            self.raw[path] = raw
            return prose(raw)
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
            # The title is the first heading after any frontmatter, so a YAML line is never read as it.
            heading = re.search(r"^#\s+(.+)$", without_frontmatter(text), re.M)
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

    def kind(self, path: Path) -> str | None:
        """The document kind that must carry repos, from its path alone (why there is no type property)."""
        if path.name == "_index.md":
            return None
        if path in self.tickets:
            return "ticket"
        if path.name.endswith("-walkthrough.md") and path.parent / (path.parent.name + ".md") in self.tickets:
            return "walkthrough"
        for folder, name in ((self.map_dir / "Repos", "repo"), (self.map_dir / "Pipelines", "pipeline"),
                             (self.root / GHK / "Repo Workflows", "runbook")):
            if path.parent == folder:
                return name
        return None

    def check_frontmatter(self):
        """Check repos and pipelines frontmatter on every scanned document; NOTE findings only."""
        found: dict[Path, dict | None] = {}
        for path in sorted(self.documents):
            properties, problems = frontmatter(self.raw.get(path, ""))
            found[path] = properties
            for code, line in problems:
                self.note(code, path, FRONTMATTER_MESSAGES[code], line)
            kind = self.kind(path)
            if kind is not None:
                self.frontmatter_expected += 1
                if properties is not None and "repos" in properties:
                    self.frontmatter_present += 1
                elif properties is not None or not problems:
                    # A malformed block already has its own finding; only an absent property is missing.
                    self.note("FRONTMATTER_MISSING", path, FRONTMATTER_MESSAGES["FRONTMATTER_MISSING"], 1)
            if properties is None:
                continue
            for key, folder, code in (("repos", "Repos", "UNKNOWN_REPO"),
                                      ("pipelines", "Pipelines", "UNKNOWN_PIPELINE")):
                for value in properties.get(key) or []:
                    if not PLAIN_NAME_RE.match(value):
                        self.note(code, path, FRONTMATTER_MESSAGES[code + "_NAME"], 1)
                        continue
                    page = self.map_dir / folder / (value + ".md")
                    if not page.is_file():
                        self.note(code, path, FRONTMATTER_MESSAGES[code], 1, page)
            repos = set(properties.get("repos") or [])
            if kind == "ticket" and "repos" in properties and repos != header_repos(self.raw[path]):
                self.note("FRONTMATTER_MISMATCH", path,
                          "repos differs from the GitHub/<repo> entries of the header Repos list.", 1)
            elif kind == "repo" and "repos" in properties and path.stem not in repos:
                self.note("FRONTMATTER_MISMATCH", path, "repos does not list this repo card's own name.", 1)
            elif kind == "pipeline" and path.stem not in (properties.get("pipelines") or []):
                self.note("FRONTMATTER_MISMATCH", path, "pipelines does not list this pipeline page's own slug.", 1)
        # A walkthrough is compared with its ticket's frontmatter, so it runs once every file is read.
        for path in sorted(self.documents):
            mine = found.get(path)
            if self.kind(path) != "walkthrough" or not mine or "repos" not in mine:
                continue
            ticket = found.get(path.parent / (path.parent.name + ".md"))
            if ticket and "repos" in ticket and not set(ticket["repos"]) <= set(mine["repos"]):
                self.note("FRONTMATTER_MISMATCH", path, "repos lacks a repo that its ticket's repos lists.", 1)

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
                if source in self.frozen_audits:
                    self.history_links += 1
                    return None
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
        self.check_frontmatter()
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
                "history_links": self.history_links,
                "findings": self.findings,
                "coverage": {"tickets": len(self.tickets), "mapped": len(mapped),
                             "uninitialized": self.uninitialized, "templates_skipped": self.templates_skipped,
                             "notes": len(notes), "reachable_notes": len(notes & reachable),
                             "map_available": map_available,
                             "frontmatter_expected": self.frontmatter_expected,
                             "frontmatter_present": self.frontmatter_present,
                             "complete": not self.findings}}


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
        history = f"; {report['history_links']} dead links in earlier audits counted as history" if report["history_links"] else ""
        print(f"NOTE [work-map] {report['files_scanned']} Markdown files, {report['links_checked']} local links; "
              f"{coverage['mapped']}/{coverage['tickets']} initialized tickets mapped; "
              f"{coverage['frontmatter_present']}/{coverage['frontmatter_expected']} documents carry repos frontmatter; "
              f"{len(report['findings'])} findings{history}.")
    return int(arguments.strict and bool(report["findings"]))


if __name__ == "__main__":
    raise SystemExit(main())