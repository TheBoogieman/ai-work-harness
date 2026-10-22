#!/usr/bin/env python3
"""audit-inventory.py — read-only inventory of an estate for the estate-auditor (CONSTITUTION §15).

It observes; it never writes, repairs or judges truth. It reports what the other
observers do not:

  tickets    every Tickets/<folder>/<folder>.md (year-9999 templates skipped): last
             Session Log stamp and its age, whether Current State exists and says
             "Closed", PR links in the header and the state words beside them,
             TODO markers in header and Current State, the walkthrough
             (<ID>-walkthrough.md, or a header link to another ticket's one: shared,
             CONSTITUTION §14.1), older explainer/Q&A files, and the
             Agent-Prompts/Agent-Output ledger (prompts with no output and the reverse);
             the sources a walkthrough can draw on (Session Log entries, AI-Knowledge
             notes, evidence notebooks with saved output, Work Map pipeline pages that
             link the ticket) and a fixed list of walkthrough gaps
  documents  every Markdown file under General AI-Knowledge and General Human
             Knowledge, plus the root AGENTS.md, CONSTITUTION.md, README.md and
             folder-map.md: kind, 'Last reviewed:' age, TODO count, size, broken
             #anchors in relative links, missing relative file targets in the
             root documents, missing pipeline-page sections, and duplicate first
             headings
  audits     the newest YYYYMMDD-estate-audit*.md report in General Human
             Knowledge/Audits/ and the
             Work commit it recorded ("Work commit audited: <sha>"), plus the files
             changed since that commit (the incremental audit scope)

Ticket recognition is deliberately grammar-free (a folder holding <folder>/<folder>.md),
the same rule check-work-map.py uses, so the one ticket grammar stays in ticket-grammar.sh.
Broken file links outside the root documents, orphans and unmapped tickets are
check-work-map.py's job; run both.
Exit code is always 0 (an observer), 2 only for bad arguments.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

LAST_REVIEWED_RE = re.compile(r"Last reviewed:\s*(\d{4}-\d{2}-\d{2})")
# A Session Log heading is the 14-digit stamp, then a title or nothing: an untitled
# "## 20260615132700" is still an entry, so the stamp may end the line.
SESSION_RE = re.compile(r"^## (\d{14})(?:[ \t]|$)", re.M)
PR_RE = re.compile(r"https://github\.com/[^/\s)]+/[^/\s)]+/pull/\d+")
STATE_WORDS_RE = re.compile(r"\b(draft|in review|open|merged|closed|abandoned)\b", re.I)
# A header that states "Pull Requests: None" (same line or first bullet) has no PR on purpose,
# so the walkthrough gap "no PR link in header" does not apply to it.
PR_NONE_RE = re.compile(r"^Pull Requests:[ \t]*(?:\n[ \t]*-?[ \t]*)?None\b", re.M | re.I)
LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\)")
FENCE_RE = re.compile(r"^\s*(```|~~~)")
WALKTHROUGH_RE = re.compile(r"^.+-\d+-walkthrough\.md$")
SHARED_WALKTHROUGH_RE = re.compile(r"\]\(<?\.\./([^/()<>\s]+)/([^/()<>\s]+-\d+-walkthrough\.md)>?\)")
LEGACY_DOC_RE = re.compile(r"(explainer-source|walkthrough-QA|implementation-walkthrough)\.md$", re.I)
LEDGER_RE = re.compile(r"^(\d{2})-.+\.md$")
# Fixed pipeline-page sections the audit reports when absent; Dependency Chain added by #333.
PIPELINE_SECTIONS = ["Identity card", "How it works", "Dependency Chain", "Deploy", "Validate", "Behaviour and traps", "Ticket history"]
ROOT_DOCS = ["AGENTS.md", "CONSTITUTION.md", "README.md", "folder-map.md"]
SKIP_DIRS = {"Logs", "Dump", ".git", "_retired", ".ipynb_checkpoints"}


def slug(heading: str) -> str:
    """GitHub-style heading anchor: lowercase, drop punctuation except - and _, spaces to hyphens."""
    text = re.sub(r"[^a-z0-9 _-]", "", heading.strip().lower())
    return text.replace(" ", "-")


def prose_lines(text: str, keep_code: bool = False) -> list[str]:
    """Lines outside fenced code blocks; inline code spans blanked unless keep_code."""
    out, fenced = [], False
    for line in text.splitlines():
        if FENCE_RE.match(line):
            fenced = not fenced
            out.append("")
            continue
        if fenced:
            out.append("")
        else:
            out.append(line.replace("`", "") if keep_code else re.sub(r"`[^`]*`", "", line))
    return out


def anchors_of(path: Path, cache: dict[Path, set[str]]) -> set[str]:
    if path not in cache:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            cache[path] = set()
            return cache[path]
        found = set()
        # Heading slugs keep inline-code text, as GitHub does.
        for line in prose_lines(text, keep_code=True):
            match = re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line)
            if match:
                found.add(slug(match.group(1)))
                # Obsidian-style fragments (anchor-style.py --to obsidian) are the heading text itself.
                found.add(match.group(1).strip().lower())
        cache[path] = found
    return cache[path]


def broken_anchors(path: Path, root: Path, cache: dict[Path, set[str]]) -> list[str]:
    broken = []
    text = path.read_text(encoding="utf-8", errors="replace")
    for number, line in enumerate(prose_lines(text), start=1):
        for target in LINK_RE.findall(line):
            if "#" not in target or re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
                continue
            file_part, fragment = target.split("#", 1)
            # Skip empty fragments, Obsidian block refs and GitHub line anchors (#L12, #L1-L14).
            if not fragment or fragment.startswith("^") or re.fullmatch(r"L\d+(-L\d+)?", fragment):
                continue
            dest = path if not file_part else (path.parent / unquote(file_part)).resolve()
            if root not in dest.parents or dest.suffix.lower() != ".md" or not dest.is_file():
                continue  # missing files are check-work-map.py's finding; outside the estate is not ours
            if unquote(fragment).lower() not in anchors_of(dest, cache):
                broken.append(f"{number}: {target}")
    return broken


def broken_file_links(path: Path) -> list[str]:
    """Relative links whose target file or folder does not exist. Used for the root documents
    only: check-work-map.py resolves links in the knowledge trees and tickets, not at the root."""
    broken = []
    text = path.read_text(encoding="utf-8", errors="replace")
    for number, line in enumerate(prose_lines(text), start=1):
        for target in LINK_RE.findall(line):
            file_part = target.split("#", 1)[0]
            if not file_part or re.match(r"^[a-z][a-z0-9+.-]*:", file_part, re.I):
                continue  # same-file anchors and URLs are not file links
            if not (path.parent / unquote(file_part)).exists():
                broken.append(f"{number}: {target}")
    return broken


def age_days(date_text: str | None, today: dt.date) -> int | None:
    if not date_text:
        return None
    try:
        return (today - dt.date.fromisoformat(date_text)).days
    except ValueError:
        return None


def section(text: str, heading: str) -> str:
    match = re.search(rf"^##\s+{re.escape(heading)}\s*$(.*?)(?=^##\s|\Z)", text, re.M | re.S)
    return match.group(1) if match else ""


def executed_notebooks(folder: Path) -> tuple[int, int]:
    """(notebooks, notebooks with saved non-error output) under the ticket's Checks/ and SQL/.

    An error output is not evidence: a template cell that failed (for example a missing
    profile) leaves an output behind, so only non-error outputs count as saved output.
    """
    books = sorted(folder.glob("Checks/*.ipynb")) + sorted(folder.glob("SQL/**/*.ipynb"))
    executed = 0
    for book in books:
        try:
            cells = json.loads(book.read_text(encoding="utf-8")).get("cells", [])
        except (OSError, ValueError):
            continue
        executed += any(o.get("output_type") != "error" for c in cells for o in c.get("outputs", []))
    return len(books), executed


def ticket_record(folder: Path, today: dt.date, pipeline_links: dict[str, list[str]]) -> dict:
    md = folder / f"{folder.name}.md"
    text = md.read_text(encoding="utf-8", errors="replace")
    head = text.split("\n## ", 1)[0]
    current = section(text, "Current State")
    stamps = SESSION_RE.findall(text)
    last = stamps[-1] if stamps else None
    last_age = None
    if last:
        last_age = (today - dt.datetime.strptime(last[:8], "%Y%m%d").date()).days
    now_line = next((l.strip() for l in current.splitlines() if l.strip().lower().startswith("- now:")), "")
    prs = []
    for line in head.splitlines():
        for url in PR_RE.findall(line):
            states = STATE_WORDS_RE.findall(line)
            prs.append({"url": url, "state_words": sorted({s.lower() for s in states})})
    prompts = {m.group(1): p.name for p in (folder / "Agent-Prompts").glob("*.md") if (m := LEDGER_RE.match(p.name))}
    outputs = {m.group(1): p.name for p in (folder / "Agent-Output").glob("*.md") if (m := LEDGER_RE.match(p.name))}
    walkthrough = sorted(p.name for p in folder.glob("*.md") if WALKTHROUGH_RE.match(p.name) and not LEGACY_DOC_RE.search(p.name))
    shared = False
    if not walkthrough:
        for other, name in SHARED_WALKTHROUGH_RE.findall(head):
            if (folder.parent / unquote(other) / unquote(name)).is_file():
                walkthrough, shared = [f"../{unquote(other)}/{unquote(name)}"], True
                break
    notes = [p for p in (folder / "AI-Knowledge").glob("*.md") if p.name != "_index.md"]
    books, executed = executed_notebooks(folder)
    pages = pipeline_links.get(folder.name, [])
    # Fixed gap vocabulary so audit reports stay comparable run to run.
    gaps = [label for label, missing in (
        ("no walkthrough", not walkthrough),
        ("no Work Map pipeline page links this ticket", not pages),
        ("no PR link in header", not prs and not PR_NONE_RE.search(head)),
        ("no AI-Knowledge notes", not notes),
        ("no evidence notebook with saved output", not executed),
        ("at most one Session Log entry", len(stamps) <= 1),
    ) if missing]
    return {
        "ticket": folder.name,
        "record": str(md),
        "last_session": last,
        "last_session_age_days": last_age,
        "has_current_state": bool(current.strip()),
        "now": now_line[:200],
        "closed": now_line.lower().startswith("- now: closed"),
        "pull_requests": prs,
        "todo_markers": len(re.findall(r"\bTODO\b", head + current)),
        "walkthrough": walkthrough,
        "walkthrough_shared": shared,
        "legacy_docs": sorted(p.name for p in folder.glob("*.md") if LEGACY_DOC_RE.search(p.name)),
        "prompts": len(prompts),
        "outputs": len(outputs),
        "prompts_without_output": sorted(prompts[n] for n in prompts if n not in outputs),
        "outputs_without_prompt": sorted(outputs[n] for n in outputs if n not in prompts),
        "session_entries": len(stamps),
        "ai_knowledge_notes": len(notes),
        "notebooks": books,
        "notebooks_with_output": executed,
        "pipeline_pages": pages,
        "walkthrough_gaps": gaps,
    }


def doc_kind(rel: str) -> str:
    if rel in ROOT_DOCS:
        return "root"
    if "/Work Map/Pipelines/" in rel:
        return "pipeline-page"
    if "/Work Map/Repos/" in rel:
        return "repo-card"
    if "/Work Map/" in rel:
        return "work-map"
    if "/Skills/" in rel:
        return "skill"
    if rel.startswith("General Human Knowledge/Repo Workflows/"):
        return "runbook"
    if rel.startswith("General Human Knowledge/Audits/"):
        return "audit"
    if rel.startswith("General Human Knowledge/Retrospectives/"):
        return "retrospective"
    if rel.startswith("General Human Knowledge/"):
        return "human-reference"
    return "topic-note"


def document_records(root: Path, today: dt.date, stale_days: int) -> list[dict]:
    files = [root / name for name in ROOT_DOCS if (root / name).is_file()]
    for tree in ("General AI-Knowledge", "General Human Knowledge"):
        for dirpath, dirnames, filenames in os.walk(root / tree):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
            files += [Path(dirpath) / f for f in sorted(filenames) if f.endswith(".md")]
    cache: dict[Path, set[str]] = {}
    records, titles = [], {}
    for path in files:
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        reviewed = LAST_REVIEWED_RE.search(text)
        age = age_days(reviewed.group(1) if reviewed else None, today)
        kind = doc_kind(rel)
        title_match = re.search(r"^#\s+(.+)$", text, re.M)
        title = title_match.group(1).strip() if title_match else ""
        if title:
            titles.setdefault(title.lower(), []).append(rel)
        headings = anchors_of(path, cache)
        missing = []
        if kind == "pipeline-page":
            missing = [s for s in PIPELINE_SECTIONS if slug(s) not in headings]
        records.append({
            "path": rel,
            "kind": kind,
            "title": title,
            "last_reviewed": reviewed.group(1) if reviewed else None,
            "review_age_days": age,
            "stale": age is not None and age > stale_days,
            "lines": text.count("\n") + 1,
            "todo_markers": len(re.findall(r"\bTODO\b", text)),
            "broken_anchors": broken_anchors(path, root, cache),
            "broken_links": broken_file_links(path) if kind == "root" else [],
            "missing_pipeline_sections": missing,
        })
    duplicates = {t: paths for t, paths in titles.items() if len(paths) > 1}
    for record in records:
        record["duplicate_title_with"] = [p for p in duplicates.get(record["title"].lower(), []) if p != record["path"]]
    return records


def audit_state(root: Path) -> dict:
    # The §15 report name only; other dated notes in Audits/ (e.g. handoffs) are not audits.
    audits = sorted((root / "General Human Knowledge" / "Audits").glob("[0-9]" * 8 + "-estate-audit*.md"))
    state = {"latest_report": None, "recorded_commit": None, "changed_since": None}
    if not audits:
        return state
    latest = audits[-1]
    state["latest_report"] = latest.relative_to(root).as_posix()
    match = re.search(r"Work commit audited:\s*`?([0-9a-f]{7,40})", latest.read_text(encoding="utf-8", errors="replace"))
    if match:
        state["recorded_commit"] = match.group(1)
        try:
            out = subprocess.run(
                ["git", "-C", str(root), "log", "--name-only", "--pretty=format:", f"{match.group(1)}..HEAD"],
                capture_output=True, text=True, check=True,
            ).stdout
            state["changed_since"] = sorted({l for l in out.splitlines() if l.strip()})
        except (subprocess.CalledProcessError, FileNotFoundError):
            state["changed_since"] = None
    return state


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only estate inventory for the estate-auditor.")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]), help="estate root (default: this script's estate)")
    parser.add_argument("--json", action="store_true", help="print the full inventory as JSON")
    parser.add_argument("--stale-days", type=int, default=int(os.environ.get("HARNESS_KNOWLEDGE_STALE_DAYS", "90")),
                        help="review age that counts as stale (default HARNESS_KNOWLEDGE_STALE_DAYS or 90)")
    args = parser.parse_args()
    root = Path(args.root).expanduser().resolve()
    if not (root / "Tickets").is_dir():
        print(f"audit-inventory: no Tickets/ under {root}", file=sys.stderr)
        return 2

    today = dt.date.today()
    # Which Work Map pipeline pages mention each ticket folder (pages link tickets by path).
    pipeline_links: dict[str, list[str]] = {}
    folders = sorted(p for p in (root / "Tickets").iterdir() if p.is_dir())
    for page in sorted((root / "General AI-Knowledge" / "Work Map" / "Pipelines").glob("*.md")):
        text = page.read_text(encoding="utf-8", errors="replace")
        for folder in folders:
            if folder.name in text:
                pipeline_links.setdefault(folder.name, []).append(page.name)
    tickets = []
    for folder in folders:
        if folder.name.startswith("9999") or not (folder / f"{folder.name}.md").is_file():
            continue
        tickets.append(ticket_record(folder, today, pipeline_links))
    documents = document_records(root, today, args.stale_days)
    inventory = {"root": str(root), "date": today.isoformat(), "tickets": tickets, "documents": documents, "audits": audit_state(root)}

    if args.json:
        print(json.dumps(inventory, indent=2))
        return 0

    open_prs = [t for t in tickets if t["pull_requests"] and not t["closed"]]
    print(f"audit-inventory: {root} on {today}")
    print(f"  tickets: {len(tickets)}; closed: {sum(t['closed'] for t in tickets)}; "
          f"with walkthrough: {sum(bool(t['walkthrough']) for t in tickets)}; open with PR links: {len(open_prs)}")
    for t in tickets:
        notes = []
        if not t["has_current_state"]:
            notes.append("no Current State")
        if t["prompts_without_output"]:
            notes.append(f"prompts without output: {', '.join(t['prompts_without_output'])}")
        if t["outputs_without_prompt"]:
            notes.append(f"outputs without prompt: {', '.join(t['outputs_without_prompt'])}")
        if t["closed"] and not t["walkthrough"]:
            notes.append("closed without walkthrough")
        if t["todo_markers"]:
            notes.append(f"{t['todo_markers']} TODO in header/Current State")
        if t["walkthrough_gaps"] and not t["walkthrough"]:
            notes.append("walkthrough gaps: " + ", ".join(t["walkthrough_gaps"]))
        if notes:
            print(f"  NOTE ticket {t['ticket']}: " + "; ".join(notes))
    stale = [d for d in documents if d["stale"]]
    print(f"  documents: {len(documents)}; stale (> {args.stale_days} days): {len(stale)}; "
          f"undated: {sum(d['last_reviewed'] is None for d in documents)}")
    for d in documents:
        if d["broken_anchors"]:
            print(f"  NOTE broken anchor(s) in {d['path']}: " + "; ".join(d["broken_anchors"][:5]))
        if d["broken_links"]:
            print(f"  NOTE broken link(s) in {d['path']}: " + "; ".join(d["broken_links"][:5]))
        if d["missing_pipeline_sections"]:
            print(f"  NOTE pipeline page {d['path']} lacks: {', '.join(d['missing_pipeline_sections'])}")
        if d["duplicate_title_with"]:
            print(f"  NOTE duplicate title '{d['title']}': {d['path']} = {', '.join(d['duplicate_title_with'])}")
    audits = inventory["audits"]
    print(f"  latest audit: {audits['latest_report'] or 'none'}; recorded commit: {audits['recorded_commit'] or 'none'}; "
          f"files changed since: {len(audits['changed_since']) if audits['changed_since'] is not None else 'n/a'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
