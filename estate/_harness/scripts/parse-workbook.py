#!/usr/bin/env python3
"""parse-workbook.py — turn a design workbook (.xlsx) into files an AI agent can read.

Design workbooks are spreadsheets with several tabs, a header row per tab (often
under a one-row group band such as "Source" / "Target"), and one or more version
columns ("Version", "Sprint Version") that say which design change introduced a
row. A version-history tab usually logs each version with a description. This
script reads the workbook READ-ONLY and writes, under <out>/<workbook-stem>/:

  INDEX.md               provenance (sha256, size, modified time), the latest
                         version found in the history tab, and one row per sheet:
                         state, header row, data rows, used columns, version
                         columns and the versions they hold
  version-history.md     the version-history tab as a table (when one is found)
  sheets/NN-<sheet>.csv  every data row, keyed by its Excel row number, with
                         header names suffixed by their column letter
  comments.md            every cell comment (when any exist)
  changes-<V>.md         per --version V: the history row(s) for V and every row
                         whose design-version cell names V, as `Header (column): value`
  changes-sprint-<S>.md  per --sprint S: the same, matched on sprint columns
  changes-since-<V>.md   per --since V: every row tagged with a numeric design
                         version greater than V

A header containing "sprint" (Sprint Version, SprintVersion, even "Sprin Version")
is a sprint column; any other header containing "version" is a design-version column.

It never writes into the workbook's own folder, skips `~$` lock files, and
replaces an earlier extract only with --force. Needs openpyxl (pip install
openpyxl). Exit codes: 0 done, 1 refused or bad arguments, 2 openpyxl missing
or the workbook could not be read.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import re
import shutil
import sys
import warnings
from pathlib import Path

PARSER_VERSION = "1"
MARKER = "<!-- parse-workbook output -->"
# Matches "Version", "Version #", "Sprint Version" and joined "SprintVersion", but not "Conversion".
VERSION_HEADER_RE = re.compile(r"(?<![a-z])(?:version|sprint)", re.I)
HISTORY_SHEET_RE = re.compile(r"^(version|versions|version history|change ?log|revisions?)$", re.I)
# A version token: optional "v", then digits joined by dots or hyphens (16.6, 13.0, 25-07, v2).
TOKEN_RE = re.compile(r"^v?(\d+(?:[.\-]\d+)*)$", re.I)
NUMERIC_TOKEN_RE = re.compile(r"^\d+(?:\.\d+)*$")
SPLIT_RE = re.compile(r"[\s,;/&]+|\band\b", re.I)


def fail(code: int, message: str) -> None:
    print(f"parse-workbook: {message}", file=sys.stderr)
    sys.exit(code)


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("_") or "sheet"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def decimals_in(number_format: str) -> int | None:
    """Decimal places an Excel number format asks for, or None for General."""
    if not number_format or number_format.lower() == "general":
        return None
    first = number_format.split(";")[0]
    match = re.search(r"\.([0#]+)", first)
    return len(match.group(1)) if match else 0


def render(value, number_format: str = "General") -> str:
    """The text a reader of the sheet sees, so 16.10 stays 16.10 and dates stay dates."""
    if value is None:
        return ""
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, dt.datetime):
        if value.time() == dt.time(0, 0):
            return value.date().isoformat()
        return value.isoformat(sep=" ")
    if isinstance(value, (dt.date, dt.time)):
        return value.isoformat()
    if isinstance(value, (int, float)):
        places = decimals_in(number_format)
        if "%" in (number_format or ""):
            return f"{value * 100:.{places or 0}f}%"
        if places is None:
            if isinstance(value, float) and value.is_integer():
                return str(int(value))
            return repr(value) if isinstance(value, float) else str(value)
        return f"{value:.{places}f}"
    text = str(value).replace("\r\n", "\n").replace("\r", "\n").strip()
    return text.replace("\n", "\\n")


def version_key(token: str) -> tuple[int, ...]:
    parts = [int(p) for p in token.split(".")]
    while len(parts) > 1 and parts[-1] == 0:
        parts.pop()
    return tuple(parts)


def tokens_in(text: str) -> list[str]:
    found = []
    for piece in SPLIT_RE.split(text or ""):
        match = TOKEN_RE.match(piece.strip())
        if match:
            found.append(match.group(1))
    return found


def same_version(token: str, wanted: str) -> bool:
    if NUMERIC_TOKEN_RE.match(token) and NUMERIC_TOKEN_RE.match(wanted):
        return version_key(token) == version_key(wanted)
    return token.lower() == wanted.lower()


def fill_of(cell) -> str:
    fill = cell.fill
    if fill is None or fill.fill_type in (None, "none"):
        return ""
    colour = fill.fgColor
    if colour is None:
        return ""
    if colour.type == "rgb" and isinstance(colour.rgb, str):
        return "" if colour.rgb in ("00000000", "FFFFFFFF") else colour.rgb
    if colour.type == "theme":
        # Theme 0 with no tint is the default white background, not a highlight.
        if colour.theme == 0 and not colour.tint:
            return ""
        return f"theme{colour.theme}{'+' if (colour.tint or 0) >= 0 else ''}{round(colour.tint or 0, 2)}"
    if colour.type == "indexed" and colour.indexed not in (64,):
        return f"indexed{colour.indexed}"
    return ""


class Sheet:
    """One worksheet reduced to its used grid, header row and version columns."""

    def __init__(self, ws, scan_rows: int):
        self.ws = ws
        self.title = ws.title
        self.state = ws.sheet_state
        self.grid: dict[int, dict[int, str]] = {}
        for row in ws.iter_rows():
            for cell in row:
                text = render(cell.value, cell.number_format)
                if text != "":
                    self.grid.setdefault(cell.row, {})[cell.column] = text
        self.max_row = max(self.grid) if self.grid else 0
        self.max_col = max((max(cols) for cols in self.grid.values()), default=0)
        self.header_row = self._find_header(scan_rows)
        self.groups = self._groups()
        self.headers = self._headers()
        self.version_cols = {
            # "sprin" also catches the real-world misspelling "Sprin Version".
            col: ("sprint" if "sprin" in name.lower() else "design")
            for col, name in self.raw_headers.items()
            if VERSION_HEADER_RE.search(name.lower())
        }

    def _find_header(self, scan_rows: int) -> int:
        # The header is the early row with the most text cells; a group band above it has fewer.
        best_row, best_score = 0, 1
        for row in range(1, min(scan_rows, self.max_row) + 1):
            cells = self.grid.get(row, {})
            text_cells = [v for v in cells.values() if not re.fullmatch(r"[-\d.,%:\s]+", v)]
            score = len(text_cells) + (2 if any(VERSION_HEADER_RE.search(v.lower()) for v in text_cells) else 0)
            if len(text_cells) >= 2 and score > best_score:
                best_row, best_score = row, score
        return best_row

    def _groups(self) -> dict[int, str]:
        if self.header_row <= 1:
            return {}
        band = self.grid.get(self.header_row - 1, {})
        if not band or len(band) * 2 > len(self.grid.get(self.header_row, {})):
            return {}
        groups, current = {}, ""
        for col in range(1, self.max_col + 1):
            current = band.get(col, current)
            groups[col] = current
        return groups

    def _headers(self) -> dict[int, str]:
        self.raw_headers = {
            col: re.sub(r"\s+", " ", name.replace("\\n", " ")).strip()
            for col, name in self.grid.get(self.header_row, {}).items()
        } if self.header_row else {}
        named = {}
        for col in range(1, self.max_col + 1):
            letter = self.letter(col)
            base = self.raw_headers.get(col) or "Column"
            named[col] = f"{base} ({letter})"
        return named

    @staticmethod
    def letter(col: int) -> str:
        from openpyxl.utils import get_column_letter

        return get_column_letter(col)

    def data_rows(self) -> list[int]:
        return [r for r in sorted(self.grid) if r > self.header_row]

    def row_hidden(self, row: int) -> bool:
        dim = self.ws.row_dimensions.get(row)
        return bool(dim and dim.hidden)

    def row_fills(self, row: int) -> str:
        fills = set()
        for col in self.grid.get(row, {}):
            colour = fill_of(self.ws.cell(row=row, column=col))
            if colour:
                fills.add(colour)
        return " ".join(sorted(fills))

    def row_versions(self, row: int, kind: str | None = None) -> list[str]:
        tokens: list[str] = []
        for col, col_kind in self.version_cols.items():
            if kind is None or col_kind == kind:
                tokens.extend(tokens_in(self.grid.get(row, {}).get(col, "")))
        return tokens

    def row_comments(self, row: int) -> list[str]:
        notes = []
        for col in sorted(self.grid.get(row, {})) or []:
            comment = self.ws.cell(row=row, column=col).comment
            if comment is not None:
                notes.append(f"{self.letter(col)}{row}: {render(comment.text)}")
        return notes


def row_block(sheet: Sheet, row: int) -> list[str]:
    state = "hidden row" if sheet.row_hidden(row) else "visible"
    lines = [f"### Row {row} ({state})", ""]
    fills = sheet.row_fills(row)
    versions = sheet.row_versions(row)
    if versions:
        lines.append(f"- _versions_: {', '.join(versions)}")
    if fills:
        lines.append(f"- _fill_: {fills}")
    for col in sorted(sheet.grid.get(row, {})):
        group = sheet.groups.get(col)
        prefix = f"{group} › " if group else ""
        lines.append(f"- {prefix}{sheet.headers[col]}: {sheet.grid[row][col]}")
    for note in sheet.row_comments(row):
        lines.append(f"- _comment_ {note}")
    lines.append("")
    return lines


def find_history(sheets: list[Sheet]) -> Sheet | None:
    for sheet in sheets:
        if HISTORY_SHEET_RE.match(sheet.title.strip()):
            return sheet
    for sheet in sheets:
        names = " ".join(sheet.raw_headers.values()).lower()
        if "description" in names and any(k == "design" for k in sheet.version_cols.values()):
            return sheet
    return None


def history_versions(history: Sheet) -> dict[int, list[str]]:
    first_version_col = next((c for c, k in history.version_cols.items() if k == "design"), None)
    result = {}
    for row in history.data_rows():
        cell = history.grid[row].get(first_version_col, "") if first_version_col else ""
        result[row] = tokens_in(cell)
    return result


def markdown_table(sheet: Sheet, rows: list[int]) -> list[str]:
    cols = list(range(1, sheet.max_col + 1))
    cols = [c for c in cols if any(c in sheet.grid.get(r, {}) for r in rows + [sheet.header_row])]
    head = ["Row"] + [sheet.raw_headers.get(c) or sheet.letter(c) for c in cols]
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for row in rows:
        cells = [str(row)] + [sheet.grid.get(row, {}).get(c, "").replace("|", "\\|") for c in cols]
        out.append("| " + " | ".join(cells) + " |")
    return out


def write_csv(sheet: Sheet, path: Path) -> None:
    cols = list(range(1, sheet.max_col + 1))
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["_row", "_hidden", "_fill"] + [sheet.headers[c] for c in cols])
        for row in sheet.data_rows():
            values = sheet.grid[row]
            writer.writerow(
                [row, "Y" if sheet.row_hidden(row) else "", sheet.row_fills(row)]
                + [values.get(c, "") for c in cols]
            )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parse a design workbook (.xlsx) into AI-readable Markdown and CSV, read-only.",
        epilog="Example: parse-workbook.py 'Mappings/Design.xlsx' --out 'Tickets/<ticket>/Dump/workbooks' --version 16.6",
    )
    parser.add_argument("workbook", help="path to the .xlsx/.xlsm workbook (never modified)")
    parser.add_argument("--out", required=True, help="output root; files go to <out>/<workbook-stem>/")
    parser.add_argument("--version", action="append", default=[], metavar="V",
                        help="write changes-<V>.md for rows whose design-version column names V (repeatable)")
    parser.add_argument("--sprint", action="append", default=[], metavar="S",
                        help="write changes-sprint-<S>.md for rows whose sprint column names S (repeatable)")
    parser.add_argument("--since", metavar="V", help="write changes-since-<V>.md for rows tagged with a numeric design version > V")
    parser.add_argument("--sheet", action="append", default=[], metavar="NAME",
                        help="limit to these sheet names (repeatable); default all")
    parser.add_argument("--skip-hidden", action="store_true", help="leave hidden sheets out (they are included by default and flagged)")
    parser.add_argument("--header-scan", type=int, default=10, metavar="N", help="rows scanned for the header row (default 10)")
    parser.add_argument("--force", action="store_true", help="replace an earlier extract of this workbook")
    args = parser.parse_args()

    workbook = Path(args.workbook).expanduser().resolve()
    if workbook.name.startswith("~$"):
        fail(1, f"refused: {workbook.name} is an Office lock file, not a workbook")
    if not workbook.is_file():
        fail(1, f"refused: workbook not found: {workbook}")
    if workbook.suffix.lower() not in (".xlsx", ".xlsm"):
        fail(1, f"refused: expected .xlsx or .xlsm, got {workbook.suffix or 'no extension'}")
    if args.since and not NUMERIC_TOKEN_RE.match(args.since):
        fail(1, f"refused: --since needs a numeric version like 16.5, got {args.since!r}")

    out_root = Path(args.out).expanduser().resolve()
    if out_root == workbook.parent or workbook.parent in out_root.parents:
        fail(1, f"refused: output must not be inside the workbook's folder ({workbook.parent})")
    target = out_root / safe_name(workbook.stem)
    if target.exists() and any(target.iterdir()):
        index = target / "INDEX.md"
        if not args.force:
            fail(1, f"refused: {target} already holds an extract; re-run with --force to replace it")
        if not (index.is_file() and MARKER in index.read_text(encoding="utf-8", errors="replace")):
            fail(1, f"refused: {target} was not written by parse-workbook; not replacing it")
        shutil.rmtree(target)

    try:
        import openpyxl  # noqa: F401
        from openpyxl import load_workbook
    except ImportError:
        fail(2, "openpyxl is not installed for this Python; run `python3 -m pip install openpyxl` or use the interpreter that has it")

    # Unsupported embedded images (e.g. WMF) only trigger openpyxl warnings; cell data is unaffected.
    warnings.filterwarnings("ignore", category=UserWarning, module="openpyxl")
    try:
        wb = load_workbook(workbook, data_only=True, read_only=False)
    except Exception as exc:  # openpyxl raises several types for damaged or protected files
        fail(2, f"could not read {workbook.name}: {exc}")

    stat = workbook.stat()
    digest = sha256(workbook)
    wanted = set(args.sheet)
    missing = sorted(wanted - set(wb.sheetnames))
    if missing:
        fail(1, f"refused: no sheet named {', '.join(repr(m) for m in missing)}; sheets are {wb.sheetnames}")

    sheets: list[Sheet] = []
    for ws in wb.worksheets:
        if wanted and ws.title not in wanted:
            continue
        if args.skip_hidden and ws.sheet_state != "visible":
            continue
        sheets.append(Sheet(ws, args.header_scan))

    (target / "sheets").mkdir(parents=True, exist_ok=True)
    history = find_history(sheets)
    hist_versions = history_versions(history) if history else {}
    # History tabs are chronological, so the last row carrying a version is the latest one.
    latest = next((toks[0] for _, toks in sorted(hist_versions.items(), reverse=True) if toks), None)

    index = [
        MARKER,
        f"# Workbook extract — {workbook.name}",
        "",
        "Read-only extract for AI agents. Re-run the parser instead of editing these files.",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Source | `{workbook}` |",
        f"| sha256 | `{digest}` |",
        f"| Size | {stat.st_size} bytes |",
        f"| Modified | {dt.datetime.fromtimestamp(stat.st_mtime).isoformat(sep=' ', timespec='seconds')} |",
        f"| Version history sheet | {repr(history.title) if history else 'not found'} |",
        f"| Latest version in history | {latest or 'not found'} (last history row) |",
        f"| Parser | parse-workbook.py v{PARSER_VERSION} |",
        "",
        "## Sheets",
        "",
        "| # | Sheet | State | Header row | Data rows | Columns | Version columns (kind: versions) | CSV |",
        "|---|---|---|---|---|---|---|---|",
    ]
    columns_section: list[str] = ["", "## Columns by sheet", ""]
    comments: list[str] = []
    for number, sheet in enumerate(sheets, start=1):
        csv_name = f"{number:02d}-{safe_name(sheet.title)}.csv"
        write_csv(sheet, target / "sheets" / csv_name)
        version_summary = []
        for col, kind in sheet.version_cols.items():
            values = sorted({t for r in sheet.data_rows() for t in tokens_in(sheet.grid[r].get(col, ""))},
                            key=lambda t: (not NUMERIC_TOKEN_RE.match(t), version_key(t) if NUMERIC_TOKEN_RE.match(t) else (0,), t))
            shown = ", ".join(values[-12:]) + (f" (+{len(values) - 12} older)" if len(values) > 12 else "")
            version_summary.append(f"{sheet.headers[col]} {kind}: {shown or 'none'}")
        index.append(
            f"| {number} | {sheet.title} | {sheet.state} | {sheet.header_row or 'none'} | {len(sheet.data_rows())} "
            f"| {sheet.max_col} | {'<br>'.join(version_summary) or '—'} | `sheets/{csv_name}` |"
        )
        hidden_rows = sum(1 for r in sheet.data_rows() if sheet.row_hidden(r))
        merged = len(sheet.ws.merged_cells.ranges)
        columns_section.append(f"### {sheet.title}")
        columns_section.append("")
        columns_section.append(f"Hidden data rows: {hidden_rows}. Merged ranges: {merged}.")
        columns_section.append("")
        for col in range(1, sheet.max_col + 1):
            group = sheet.groups.get(col)
            columns_section.append(f"- {sheet.headers[col]}" + (f" — group: {group}" if group else ""))
        columns_section.append("")
        for row in sheet.data_rows() + ([sheet.header_row] if sheet.header_row else []):
            for note in sheet.row_comments(row):
                comments.append(f"- {sheet.title} {note}")

    index.extend(columns_section)
    index.extend([
        "## Use",
        "",
        "- Cite a fact as `<workbook> v<version>, sheet '<name>' row <n>`; quote the sha256 when a decision rests on it.",
        "- Grep the CSVs by header or value; `_row` is the Excel row number, `_hidden` flags hidden rows, `_fill` lists highlight colours.",
        "",
    ])
    (target / "INDEX.md").write_text("\n".join(index), encoding="utf-8")

    if history:
        lines = [f"# Version history — {workbook.name}", "", f"Sheet {history.title!r}, header row {history.header_row}.", ""]
        lines += markdown_table(history, history.data_rows())
        (target / "version-history.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    if comments:
        (target / "comments.md").write_text(f"# Cell comments — {workbook.name}\n\n" + "\n".join(comments) + "\n", encoding="utf-8")

    def changes(title: str, matcher, filename: str, kind: str) -> int:
        lines = [f"# {title} — {workbook.name}", "", f"sha256 `{digest}`", ""]
        if history and kind == "design":
            hist_rows = [r for r, toks in hist_versions.items() if any(matcher(t) for t in toks)]
            lines += ["## Version history rows", ""]
            lines += markdown_table(history, hist_rows) if hist_rows else ["None found."]
            lines.append("")
        total = 0
        for sheet in sheets:
            if sheet is history:
                continue
            rows = [r for r in sheet.data_rows() if any(matcher(t) for t in sheet.row_versions(r, kind))]
            if not rows:
                continue
            total += len(rows)
            cols = ", ".join(sheet.headers[c] for c, k in sheet.version_cols.items() if k == kind)
            lines += [f"## Sheet '{sheet.title}' — {len(rows)} row(s)", "", f"Matched on: {cols}", ""]
            for row in rows:
                lines += row_block(sheet, row)
        if total == 0:
            lines += ["No sheet rows carry this version.", ""]
        (target / filename).write_text("\n".join(lines), encoding="utf-8")
        return total

    summary = []
    for wanted_version in args.version:
        token = wanted_version.lstrip("vV")
        count = changes(f"Changes for version {token}", lambda t, w=token: same_version(t, w),
                        f"changes-{safe_name(token)}.md", "design")
        summary.append(f"version {token}: {count} row(s)")
        if count == 0:
            print(f"parse-workbook: WARN no rows tagged {token}; check INDEX.md for the versions present", file=sys.stderr)
    for wanted_sprint in args.sprint:
        count = changes(f"Changes for sprint {wanted_sprint}", lambda t, w=wanted_sprint: same_version(t, w),
                        f"changes-sprint-{safe_name(wanted_sprint)}.md", "sprint")
        summary.append(f"sprint {wanted_sprint}: {count} row(s)")
    if args.since:
        floor = version_key(args.since)
        count = changes(f"Changes since version {args.since}",
                        lambda t: bool(NUMERIC_TOKEN_RE.match(t)) and version_key(t) > floor,
                        f"changes-since-{safe_name(args.since)}.md", "design")
        summary.append(f"since {args.since}: {count} row(s)")

    print(f"parse-workbook: {workbook.name} -> {target}")
    print(f"  sheets: {len(sheets)}; history: {history.title if history else 'not found'}; latest version: {latest or 'not found'}")
    for line in summary:
        print(f"  {line}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
