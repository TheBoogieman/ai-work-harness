#!/usr/bin/env python3
"""mappings-index.py: list the design workbooks in Mappings/ and the pipeline page that names each.

    python3 _harness/scripts/mappings-index.py            # print the index
    python3 _harness/scripts/mappings-index.py --write    # write it to the Work Map

An estate may hold dozens of design workbooks, one per pipeline, each with several versions.
Nothing listed them, or showed which pipeline page owns which (#385). This script writes one
generated page, General AI-Knowledge/Work Map/Mappings.md:

  - one row per workbook: its versions, the latest one, and the pipeline page(s) whose
    frontmatter `workbooks:` list names it;
  - workbooks no pipeline page names;
  - pipeline pages naming a workbook that is not in Mappings/.

THE DIRECTION IS ONE WAY. A pipeline page names its workbook; nothing is ever written inside
Mappings/, and a workbook is never opened for writing. The page this script writes is derived:
re-run the script instead of editing it. Its output holds no date and no machine path, so two
runs over the same estate write the same bytes.

VERSIONS come from the workbook itself, read with the same code parse-workbook.py uses: the
version-history tab when there is one, else every design-version column. That needs openpyxl.
Without it, or for a workbook that cannot be read, the versions cell says so and the rest of the
index is still written. `--no-versions` skips reading workbooks altogether (fast, names only).

Exit status is 0 whatever the gaps are: this is a listing, not a check. check-work-map.py reports
the same two gaps as warnings.
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
import warnings
from pathlib import Path
from urllib.parse import quote

GAK = "General AI-Knowledge"
OUTPUT = f"{GAK}/Work Map/Mappings.md"
WORKBOOK_SUFFIXES = (".xlsx", ".xlsm")


def sibling(name: str):
    """Load a sibling script as a module. Their file names hold a hyphen, so a plain import cannot."""
    path = Path(__file__).resolve().parent / name
    spec = importlib.util.spec_from_file_location(name.replace("-", "_").removesuffix(".py"), path)
    module = importlib.util.module_from_spec(spec)
    # dataclasses and typing look a module up by name while it is being executed.
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def workbooks_in(root: Path) -> list[str]:
    """Workbook file names directly in Mappings/, sorted. Office lock files (~$...) are not workbooks."""
    folder = root / "Mappings"
    if not folder.is_dir():
        return []
    return sorted((p.name for p in folder.iterdir()
                   if p.is_file() and p.suffix.lower() in WORKBOOK_SUFFIXES and not p.name.startswith("~$")),
                  key=str.lower)


def pages_naming(root: Path, read_frontmatter) -> dict[str, list[str]]:
    """Map each workbook name to the pipeline page slugs whose frontmatter `workbooks:` lists it."""
    named: dict[str, list[str]] = {}
    folder = root / GAK / "Work Map" / "Pipelines"
    if not folder.is_dir():
        return named
    for page in sorted(folder.glob("*.md"), key=lambda p: p.name.lower()):
        try:
            properties, _ = read_frontmatter(page.read_text(encoding="utf-8"))
        except (OSError, UnicodeError):
            continue
        for workbook in (properties or {}).get("workbooks") or []:
            named.setdefault(workbook, []).append(page.stem)
    return named


def versions_of(path: Path, parser) -> tuple[str, str]:
    """(all versions, latest) for one workbook, as text for a table cell.

    The history tab is chronological, so its order is kept and its last version is the latest.
    With no history tab, the versions tagged in design-version columns are sorted numerically.
    """
    try:
        from openpyxl import load_workbook
    except ImportError:
        return "not read (openpyxl is not installed)", "—"
    warnings.filterwarnings("ignore", category=UserWarning, module="openpyxl")
    try:
        book = load_workbook(path, data_only=True, read_only=False)
        sheets = [parser.Sheet(ws, 10) for ws in book.worksheets]
    except Exception as exc:  # openpyxl raises several types for a damaged or protected file
        return f"not read ({type(exc).__name__})", "—"
    ordered: list[str] = []
    history = parser.find_history(sheets)
    if history is not None:
        for _, tokens in sorted(parser.history_versions(history).items()):
            ordered.extend(t for t in tokens if t not in ordered)
    if not ordered:
        seen: set[str] = set()
        for sheet in sheets:
            for row in sheet.data_rows():
                seen.update(sheet.row_versions(row, "design"))
        ordered = sorted(seen, key=parser.version_key)
    if not ordered:
        return "none found", "—"
    return ", ".join(ordered), ordered[-1]


def cell(text: str) -> str:
    """Text safe inside a Markdown table cell."""
    return text.replace("|", "\\|").replace("\n", " ")


def build(root: Path, read_versions: bool) -> str:
    check = sibling("check-work-map.py")
    parser = sibling("parse-workbook.py") if read_versions else None
    books = workbooks_in(root)
    named = pages_naming(root, check.frontmatter)
    lines = [
        "# Design workbooks",
        "",
        # harness-status warns about a knowledge page with no "Last reviewed:" line, and about one
        # whose date is old. This page is generated, so it has no review to date: the line is
        # there with no date in it, which the status sweep reads as "nothing to check". A real
        # date would also make two runs on different days differ.
        "Last reviewed: not applicable (generated; re-run the script instead of reviewing it)",
        "",
        "Generated by `_harness/scripts/mappings-index.py --write`. Do not edit this page: re-run the",
        "script. A pipeline page names its workbook in its frontmatter `workbooks:` list; nothing is",
        "written inside `Mappings/` (CONSTITUTION §10).",
        "",
    ]
    if not books and not named:
        lines += ["No workbooks indexed yet: `Mappings/` holds none and no pipeline page names one.", ""]
        return "\n".join(lines)
    lines += ["| Workbook | Versions | Latest | Pipeline page |", "|---|---|---|---|"]
    for name in books:
        versions, latest = versions_of(root / "Mappings" / name, parser) if parser else ("not read", "—")
        pages = " · ".join(f"[{slug}](Pipelines/{quote(slug)}.md)" for slug in named.get(name, [])) or "—"
        link = f"[{cell(name)}](../../Mappings/{quote(name)})"
        lines.append(f"| {link} | {cell(versions)} | {cell(latest)} | {pages} |")
    lines.append("")
    unlisted = [name for name in books if name not in named]
    lines += ["## Workbooks no pipeline page names", ""]
    lines += [f"- `{name}`" for name in unlisted] or ["None."]
    lines.append("")
    absent = sorted((name, slug) for name, slugs in named.items() if name not in books for slug in slugs)
    lines += ["## Pipeline pages naming a workbook that is not in Mappings/", ""]
    lines += [f"- [{slug}](Pipelines/{quote(slug)}.md) names `{name}`" for name, slug in absent] or ["None."]
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="List the design workbooks in Mappings/ and the pipeline page that names each.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2],
                        help="estate root (default: the estate this script sits in)")
    parser.add_argument("--write", action="store_true", help=f"write the index to {OUTPUT} instead of printing it")
    parser.add_argument("--no-versions", action="store_true", help="do not open the workbooks; list names and pages only")
    args = parser.parse_args()
    root = args.root.expanduser().resolve()
    text = build(root, not args.no_versions)
    if not args.write:
        # Bytes, not text: the page holds characters a Windows console codec may not have.
        sys.stdout.buffer.write(text.encode("utf-8"))
        return 0
    target = root / OUTPUT
    target.parent.mkdir(parents=True, exist_ok=True)
    # Written as LF bytes on every platform, so a Windows run and a CI run agree byte for byte.
    target.write_bytes(text.encode("utf-8"))
    print(f"OK: wrote {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
