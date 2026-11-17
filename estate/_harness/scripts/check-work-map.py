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

Only actual links are routes (#397). An index file is read like any other Markdown: a
bare filename-first entry or a promotion declaration names a file without linking it,
so it supplies no route; the index grammar gives every entry and tombstone a real link,
and the validator still owns that grammar. Directory routes resolve to _index.md or the
same-named topic Markdown, never to every descendant. Coverage means reachability in
this supported local graph, not verified facts, lineage, aliases, or complete Markdown
interpretation.

Earlier estate audit reports are frozen (never edited), so a dead link inside one
is counted as history_links rather than raised as a finding; the newest report
is checked like any other note.

Frontmatter: a leading YAML block (Obsidian properties) is read in the plain
subset Obsidian writes, block or flow lists. repos (repo card file names) is
expected on ticket primaries, walkthroughs, repo cards, pipeline pages and Repo
Workflows runbooks; pipelines (pipeline page slugs) is optional except on a
pipeline page, which lists its own slug. workbooks (file names in Mappings/) is
optional and read on pipeline pages only (#385): a value that names no file there
is MISSING_WORKBOOK, and the workbooks no page names are one UNLINKED_WORKBOOK
note with a count. Nothing in Mappings/ is ever opened. Every value must name an existing Work
Map page; a ticket's repos equals the GitHub/<repo> entries of its header Repos
list; a walkthrough includes its ticket's repos; a repo card lists itself. A
missing property is a NOTE like every finding here, so legacy records stay
grandfathered until a backfill. YAML comments are refused because other scripts
read a "#" line as a Markdown heading.

External links (#368): a web address left in prose (BARE_URL) and a pull request
named by number without a link (UNLINKED_PR) are each one NOTE per file with a
count, at the first occurrence. Link labels and destinations, code, comments,
frontmatter, frozen earlier audits and every Session Log entry but the newest
are ignored. An autolink (<https://...>) still counts as bare: the rule asks for
a label. Nothing else external is matched; that is the writing agents' job.

Estate files (#384): a ticket file that names an existing file by its path without
linking it (UNLINKED_FILE) is one NOTE per ticket with a count. A path is a token
with a folder and a file extension, such as Agent-Output/03-load.md, that exists
under the ticket folder, or under Tickets/ or Mappings/ from the estate root
(scripts, contracts and config files are things a ticket changes, not records). Inline code is read, because that is
how a path is usually written; fenced blocks, comments, frontmatter, links and
every Session Log entry but the newest are ignored.

Ticket files (#397): every retained file in an initialized ticket's folder must be
reachable through actual links from its ticket file, either directly or through the
AI-Knowledge/_index.md the ticket file links. The files that are not are one
UNLINKED_TICKET_FILE note per ticket with a count; the entry helper's Ticket files
section links them. The inventory, its housekeeping exclusions and its refusal to follow
symlinks or enter another checkout are ticket-files.py's, imported from beside this
script; a file it skips is a TICKET_FILE_SKIPPED note. Only file names are listed: no
ticket file other than the ticket file and its knowledge index is opened. Without
ticket-files.py the check is not run, and coverage says so. A ticket whose header does not link
AGENTS.md and CONSTITUTION.md (the template's agent pointer line) is an UNLINKED_RULES note; the
next entry adds the line. A non-Markdown file in either knowledge tree (an image, a script, a
licence) that no note the root indexes reach links is an ORPHAN_FILE note, as an unreached note is
an ORPHAN_NOTE; only its name is read.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import sys
from urllib.parse import unquote, urlsplit


GAK = "General AI-Knowledge"
GHK = "General Human Knowledge"
EXCLUDED = {"Logs", "Dump", ".git", "_retired"}
AUDIT_RE = re.compile(r"^\d{8}-estate-audit.*\.md$")
# The two frontmatter list properties this helper reads, and the plain page name a value must be:
# a repo card's or pipeline page's file name without .md, so never a path, a wiki-link or a dotfile.
FRONTMATTER_KEYS = ("repos", "pipelines", "workbooks")
PLAIN_NAME_RE = re.compile(r"^(?!\.)[^/\\\[\]|#^<>:\x00]+$")
FRONTMATTER_MESSAGES = {
    "FRONTMATTER_COMMENT": "YAML comment in frontmatter; other scripts read a # line as a Markdown heading.",
    "FRONTMATTER_MALFORMED": "Frontmatter is not the plain block Obsidian writes; its properties were not read.",
    "FRONTMATTER_MISSING": "No repos property in frontmatter; an empty list is allowed when unknown.",
    "UNKNOWN_REPO": "A repos value names no repo card.",
    "UNKNOWN_REPO_NAME": "A repos value is not a repo card file name (no path or wiki-link).",
    "UNKNOWN_PIPELINE": "A pipelines value names no pipeline page.",
    "UNKNOWN_PIPELINE_NAME": "A pipelines value is not a pipeline page file name (no path or wiki-link).",
    "MISSING_WORKBOOK": "A workbooks value names no file in Mappings/.",
    "UNLINKED_WORKBOOK": "{n} workbook(s) in Mappings/ that no pipeline page names in its workbooks list; "
                         "mappings-index.py lists them.",
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


def routes(text: str) -> list[tuple[int, str, bool]]:
    """Extract destinations, never descriptions. Only an actual link is a route (#397): a bare
    filename-first index entry or a promotion declaration names a file but links nothing, so it
    no longer counts; the index grammar puts a real link on every entry and tombstone instead.
    The third field is always False (no route is estate-relative any more); it keeps the shape
    ticket-files.py, which reads links through this function, already unpacks."""
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
    return sorted(set(found))


# External-link patterns (#368). Deliberately dumb: a web address left in prose, and a pull request
# named by number but not linked. Everything else external (tracker keys, comments, wiki pages,
# scheduler runs) is left to the writing agents, because no cheap pattern tells a linkable tracker
# key from a ticket folder name or a heading.
BARE_URL_RE = re.compile(r"(?i)\bhttps?://[^\s<>)\]]+")
UNLINKED_PR_RE = re.compile(r"(?i)\b(?:PR|pull request)\s?#\d+\b")
LINK_MESSAGES = {
    "BARE_URL": "{n} bare web address(es); write each as a masked link, [what it is](<address>) (CONSTITUTION §6.1).",
    "UNLINKED_PR": "{n} pull request(s) named by number but not linked; write [PR #N](<address>) (CONSTITUTION §6.1).",
}


# A path as a ticket file writes one: at least one folder, then a file name with an extension, no
# spaces. The lookbehind keeps a match from starting in the middle of a longer path or address.
FILE_MENTION_RE = re.compile(r"(?<![\w/.%:~-])((?:[\w.-]+/)+[\w.-]+\.[A-Za-z0-9]{1,6})(?![\w/-])")
# Estate-rooted paths count only under these folders: they hold records a reader follows. A
# script, an agent contract or a config file named as the thing a ticket changed is not a record
# to navigate to, and a repo checkout is not part of the estate.
RECORD_ROOTS = ("Tickets", "Mappings")
FILE_MESSAGE = ("{n} estate file(s) named by path but not linked; write [what it is](relative/path) "
                "(CONSTITUTION §6.1).")
RULES_MESSAGE = ("The header does not link AGENTS.md and CONSTITUTION.md; the next Session Log entry adds "
                 "the template's agent pointer line (CONSTITUTION §4.3).")
TICKET_FILES_MESSAGE = ("{n} retained ticket file(s) not reachable through links from the ticket file; "
                        "the next Session Log entry links them under Ticket files (CONSTITUTION §6.1).")


def ticket_files_module():
    """ticket-files.py from beside this script, or None when it is absent or cannot load. It is
    handed THIS module as its link reader, so both scripts parse links with the same code."""
    path = Path(__file__).with_name("ticket-files.py")
    if not path.is_file():
        return None
    try:
        spec = importlib.util.spec_from_file_location("ticket_files", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except Exception:  # an unloadable helper must not stop the rest of the observation
        return None
    module._PARSER = sys.modules[__name__]
    return module


def fences_blanked(text: str) -> str:
    """Blank comments and fenced code but keep inline code, keeping offsets. prose() blanks inline
    code too, and a file path in a ticket is nearly always written in backticks."""
    token = re.compile(r"<!--|^ {0,3}(?P<fence>`{3,}|~{3,})[^\n]*", re.M)
    pieces = []
    offset = 0
    while match := token.search(text, offset):
        if fence := match.group("fence"):
            closing = re.compile(r"^ {0,3}" + re.escape(fence[0]) +
                                 "{" + str(len(fence)) + r",}[ \t]*$", re.M).search(text, match.end())
            end = len(text) if closing is None else closing.end()
        else:
            closing_at = text.find("-->", match.end())
            end = len(text) if closing_at < 0 else closing_at + 3
        pieces.extend((text[offset:match.start()], blank(text[match.start():end])))
        offset = end
    pieces.append(text[offset:])
    return "".join(pieces)


def without_links(text: str) -> str:
    """Blank every link span (label and destination) and every autolink, keeping offsets, so what
    is left is the prose a reader sees unlinked. Reuses destination() so a destination with
    parentheses is spanned the same way the route reader spans it."""
    masked = list(text)
    for match in re.finditer(r"^ {0,3}\[[^\]\n]+\]:[ \t]*", text, re.M):
        _, end = destination(text, match.end())
        line_end = text.find("\n", end)
        end = len(text) if line_end < 0 else line_end
        masked[match.start():end] = blank(text[match.start():end])
    # Inline links: [label](destination "title"); the label is blanked too, so "[PR #9](url)" is
    # linked and never counted. Reference-style uses, [label][ref], are blanked the same way.
    for match in re.finditer(r"(?<!\\)\[(?:\\.|[^\]\\\n])*\]\(", text):
        _, end = destination(text, match.end())
        close = re.match(r'''\s*(?:"[^"\n]*"|'[^'\n]*'|\([^\n]*?\))?\s*\)''', text[end:])
        if close:
            stop = end + close.end()
            masked[match.start():stop] = blank(text[match.start():stop])
    for match in re.finditer(r"(?<!\\)\[(?:\\.|[^\]\\\n])*\]\[[^\]\n]*\]", text):
        masked[match.start():match.end()] = blank(text[match.start():match.end()])
    # An autolink <https://...> is clickable but shows the raw address, so it is NOT blanked: the
    # rule asks for a masked label.
    return "".join(masked)


def history_blanked(text: str) -> str:
    """Blank every Session Log entry except the newest. Older entries are history that is never
    rewritten (CONSTITUTION §6), so a note about them could never be fixed; the newest entry is
    still checked because it was just written."""
    log = re.search(r"^##[ \t]*Session[ \t]*Log[ \t]*#*[ \t]*$", text, re.M)
    if not log:
        return text
    entries = list(re.finditer(r"^## \d{14} - ", text[log.end():], re.M))
    if len(entries) < 2:
        return text
    start, stop = log.end(), log.end() + entries[-1].start()
    return text[:start] + blank(text[start:stop]) + text[stop:]


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
        # Each document's frontmatter as read, kept for the checks that run after check_frontmatter.
        self.properties: dict[Path, dict | None] = {}
        self.frontmatter_expected = 0
        self.frontmatter_present = 0
        # Ticket-file coverage (#397): retained files counted, how many are reachable by links, and
        # whether ticket-files.py was there to count them at all.
        self.ticket_files = 0
        self.ticket_files_linked = 0
        self.ticket_files_checked = False
        # Every existing local target each document links, files and folders alike (#397): a
        # non-Markdown file in a knowledge tree counts as linked only through these.
        self.targets: dict[Path, set[Path]] = {}
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
            self.properties[path] = properties
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
            self.targets.setdefault(source, set()).add(target)
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

    def check_external_links(self):
        """Note bare web addresses and unlinked PR numbers (#368): one NOTE per file and pattern,
        at the first occurrence's line, with a count. Frozen earlier audits are history and skipped."""
        for path in sorted(self.documents):
            if path in self.frozen_audits:
                continue
            # documents[] already has code and comments blanked; frontmatter and older Session Log
            # entries are blanked here, then links, so only unlinked prose remains.
            text = without_links(history_blanked(without_frontmatter(self.documents[path])))
            for code, pattern in (("BARE_URL", BARE_URL_RE), ("UNLINKED_PR", UNLINKED_PR_RE)):
                hits = list(pattern.finditer(text))
                if hits:
                    self.note(code, path, LINK_MESSAGES[code].format(n=len(hits)),
                              text.count("\n", 0, hits[0].start()) + 1)

    def check_workbooks(self):
        """Note the two gaps between Mappings/ and the pipeline pages (#385). A pipeline page names
        its design workbooks in its frontmatter workbooks list, by file name. A name with no file
        in Mappings/ is one NOTE on that page. The workbooks no page names are ONE note with a
        count, however many there are, because this runs at every session start and an estate may
        hold a hundred workbooks. Only file names are read; no workbook is opened."""
        folder = self.root / "Mappings"
        try:
            books = {p.name for p in folder.iterdir()
                     if p.is_file() and p.suffix.lower() in (".xlsx", ".xlsm") and not p.name.startswith("~$")}
        except OSError:
            books = set()
        named: set[str] = set()
        for path in sorted(self.documents):
            if self.kind(path) != "pipeline":
                continue
            for value in (self.properties.get(path) or {}).get("workbooks") or []:
                named.add(value)
                if value not in books:
                    self.note("MISSING_WORKBOOK", path, FRONTMATTER_MESSAGES["MISSING_WORKBOOK"], 1,
                              folder / value)
        unnamed = books - named
        if unnamed:
            self.note("UNLINKED_WORKBOOK", folder,
                      FRONTMATTER_MESSAGES["UNLINKED_WORKBOOK"].format(n=len(unnamed)))

    def check_file_mentions(self):
        """Note estate files a ticket file names by path without linking them (#384): one NOTE per
        ticket, at the first occurrence's line, with a count of distinct files. Only a path that
        exists in the ticket folder or under a record root is counted, so a path quoted from a
        repo or an example never is."""
        for path in sorted(self.tickets):
            raw = self.raw.get(path)
            if raw is None:
                continue
            text = without_links(history_blanked(without_frontmatter(fences_blanked(raw))))
            seen: dict[str, int] = {}
            for match in FILE_MENTION_RE.finditer(text):
                token = match.group(1)
                if token in seen:
                    continue
                try:
                    exists = (path.parent / token).is_file() or (
                        token.split("/", 1)[0] in RECORD_ROOTS and (self.root / token).is_file())
                except OSError:
                    exists = False
                if exists:
                    seen[token] = text.count("\n", 0, match.start()) + 1
            if seen:
                self.note("UNLINKED_FILE", path, FILE_MESSAGE.format(n=len(seen)), min(seen.values()))

    def knowledge_assets(self) -> list[Path]:
        """Every non-Markdown file in both knowledge trees, without following symlinks, skipping
        the excluded folders, hidden names and .gitkeep/.DS_Store housekeeping."""
        found: list[Path] = []
        pending = [self.root / name for name in (GAK, GHK)]
        while pending:
            folder = pending.pop()
            if not folder.is_dir() or folder.is_symlink():
                continue
            for path in self.entries(folder):
                if path.name in EXCLUDED or path.name.startswith(".") or path.is_symlink():
                    continue
                if path.is_dir():
                    pending.append(path)
                elif path.is_file() and path.suffix.lower() != ".md":
                    found.append(path)
        return sorted(found)

    def check_ticket_files(self):
        """Note the retained files of each ticket that its ticket file cannot reach through actual
        links (#397): one UNLINKED_TICKET_FILE note per ticket with a count. ticket-files.py owns
        the inventory and the meaning of "reachable"; without it the check is skipped and the
        coverage report says so rather than claiming every file is linked."""
        module = ticket_files_module()
        if module is None:
            return
        self.ticket_files_checked = True
        for primary in sorted(self.tickets):
            raw = self.raw.get(primary)
            if raw is None:
                continue
            try:
                files, skipped, _ = module.inventory(primary.parent, primary.name)
            except module.Refused:
                self.note("UNAVAILABLE", primary.parent, "Ticket folder could not be listed; ticket-file coverage is incomplete.")
                continue
            for rel, reason in skipped:
                self.note("TICKET_FILE_SKIPPED", primary.parent / rel.rstrip("/"), f"Not inventoried: {reason}.")
            index = self.raw.get(primary.parent / "AI-Knowledge" / "_index.md")
            if not module.has_rules_link(raw):
                heading = re.search(r"^# ", without_frontmatter(raw), re.M)
                self.note("UNLINKED_RULES", primary, RULES_MESSAGE,
                          raw.count("\n", 0, heading.start()) + 1 if heading else 1)
            reach = module.reachable(raw, index)
            unlinked = [rel for rel in files if rel not in reach]
            self.ticket_files += len(files)
            self.ticket_files_linked += len(files) - len(unlinked)
            if unlinked:
                heading = re.search(r"^##[ \t]+Ticket files[ \t#]*$", raw, re.M)
                line = raw.count("\n", 0, heading.start()) + 1 if heading else 1
                self.note("UNLINKED_TICKET_FILE", primary, TICKET_FILES_MESSAGE.format(n=len(unlinked)), line)

    def report(self) -> dict:
        self.collect()
        self.check_frontmatter()
        self.check_external_links()
        self.check_file_mentions()
        self.check_ticket_files()
        self.check_workbooks()
        for path, text in sorted(self.documents.items()):
            self.edges[path] = set()
            for line, target, estate_relative in routes(text):
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
        # Non-Markdown files in the knowledge trees (an SVG, a script, a licence): each must be
        # linked from a note the root indexes reach, as every note must (#397).
        linked = set().union(*(self.targets.get(path, set()) for path in reachable))
        self.assets = self.knowledge_assets()
        for path in sorted(set(self.assets) - linked):
            self.note("ORPHAN_FILE", path, "Non-Markdown file no reachable note links; link it from the note it belongs to.")
        self.assets_linked = len(set(self.assets) & linked)
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
                             "ticket_files": self.ticket_files,
                             "ticket_files_linked": self.ticket_files_linked,
                             "ticket_files_checked": self.ticket_files_checked,
                             "knowledge_files": len(self.assets), "knowledge_files_linked": self.assets_linked,
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
        # The ticket-file figure is stated either way, so an absent helper never reads as full coverage.
        files = (f"{coverage['ticket_files_linked']}/{coverage['ticket_files']} retained ticket files reachable"
                 if coverage["ticket_files_checked"] else "ticket files not checked (ticket-files.py absent)")
        print(f"NOTE [work-map] {report['files_scanned']} Markdown files, {report['links_checked']} local links; "
              f"{coverage['mapped']}/{coverage['tickets']} initialized tickets mapped; "
              f"{coverage['frontmatter_present']}/{coverage['frontmatter_expected']} documents carry repos frontmatter; "
              f"{files}; {coverage['knowledge_files_linked']}/{coverage['knowledge_files']} other knowledge-tree "
              f"files linked; {len(report['findings'])} findings{history}.")
    return int(arguments.strict and bool(report["findings"]))


if __name__ == "__main__":
    raise SystemExit(main())