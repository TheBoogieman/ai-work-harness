#!/usr/bin/env bash
# workbook-parse.case.sh — [workbook-parse]: parse-workbook.py turns a design workbook into files an
# agent can read, and refuses the three writes that would damage a user's copy. SOURCED by the
# runner; see dev/scripts/run-demo.sh.
#
# The workbook is generated here with openpyxl, so no real design document is ever read. The
# parser needs openpyxl too; a Python without it is a red, not a skip, because CI is the only lane
# that would otherwise prove this family. Cleanup is an explicit rm (the runner owns the trap).

wp_fixture() {
  echo "--- [workbook-parse]: workbook -> INDEX, history, sheet CSVs, per-version changes;" \
    "refusals hold ---"
  WP_ROOT=$(mktemp -d)
  WP_PY="${HARNESS_TEST_PYTHON:-python3}"
  WP_HELPER="${HARNESS_PARSE_WORKBOOK:-$PWD/estate/_harness/scripts/parse-workbook.py}"
  [ -f "$WP_HELPER" ] || { echo "BUG [workbook-parse-present]: the parser is absent ($WP_HELPER)"; exit 1; }
  "$WP_PY" -c 'import openpyxl' 2>/dev/null \
    || { echo "BUG [workbook-parse-openpyxl]: $WP_PY cannot import openpyxl — the parser and this" \
           "case need it (python3 -m pip install openpyxl)"; exit 1; }
  mkdir -p "$WP_ROOT/Mappings"
  # A mapping tab under a one-row group band, with a design-version and a sprint column, and a
  # version-history tab: the shape the parser exists for. Version 16.6 tags two of three rows.
  "$WP_PY" - "$WP_ROOT/Mappings/design.xlsx" <<'WPPY'
import sys
import openpyxl

book = openpyxl.Workbook()
sheet = book.active
sheet.title = "Mapping"
sheet.append(["Source", None, "Target", None])
sheet.append(["Field", "Type", "Version", "Sprint Version"])
sheet.append(["alpha", "int", "16.5", "S1"])
sheet.append(["beta", "str", "16.6", "S2"])
sheet.append(["gamma", "str", "16.6, 16.7", None])
history = book.create_sheet("Version History")
history.append(["Version", "Description"])
history.append(["16.5", "first cut"])
history.append(["16.6", "adds beta and gamma"])
book.save(sys.argv[1])
WPPY
  WP_SUM=$(cksum < "$WP_ROOT/Mappings/design.xlsx")
}

# 1. One run writes every promised file, and changes-16.6.md carries exactly the tagged rows.
wp_extract() {
  local out d="$WP_ROOT/out/design" f
  out=$("$WP_PY" "$WP_HELPER" "$WP_ROOT/Mappings/design.xlsx" --out "$WP_ROOT/out" --version 16.6 2>&1) \
    || { echo "BUG [workbook-parse-runs]: the parser failed on a well-formed workbook:"; echo "$out"; exit 1; }
  for f in INDEX.md version-history.md sheets/01-Mapping.csv changes-16.6.md; do
    [ -f "$d/$f" ] || { echo "BUG [workbook-parse-outputs]: $f was not written under out/design/"; exit 1; }
  done
  grep -q 'sha256' "$d/INDEX.md" \
    || { echo "BUG [workbook-parse-provenance]: INDEX.md carries no sha256 of the workbook"; exit 1; }
  grep -qF 'Field (A): beta' "$d/changes-16.6.md" && grep -qF 'Field (A): gamma' "$d/changes-16.6.md" \
    && ! grep -qF 'Field (A): alpha' "$d/changes-16.6.md" \
    || { echo "BUG [workbook-parse-version]: changes-16.6.md does not hold exactly the rows tagged" \
           "16.6:"; cat "$d/changes-16.6.md"; exit 1; }
  echo "  ok [workbook-parse-outputs] — INDEX (with sha256), history, sheet CSV and the 16.6" \
    "change list (exactly the tagged rows)"
}

# 2. Refusals: an existing extract without --force, output inside the workbook's folder, and an
#    Office lock file. Each must exit 1 and write nothing; the workbook itself never changes.
wp_refusals() {
  local rc
  set +e
  "$WP_PY" "$WP_HELPER" "$WP_ROOT/Mappings/design.xlsx" --out "$WP_ROOT/out" >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -eq 1 ] || { echo "BUG [workbook-parse-no-clobber]: an existing extract was replaced" \
    "without --force (rc=$rc)"; exit 1; }
  set +e
  "$WP_PY" "$WP_HELPER" "$WP_ROOT/Mappings/design.xlsx" --out "$WP_ROOT/Mappings" >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -eq 1 ] && [ ! -e "$WP_ROOT/Mappings/design" ] \
    || { echo "BUG [workbook-parse-beside]: the parser wrote beside the workbook (rc=$rc)"; exit 1; }
  cp "$WP_ROOT/Mappings/design.xlsx" "$WP_ROOT/Mappings/~\$design.xlsx"
  set +e
  "$WP_PY" "$WP_HELPER" "$WP_ROOT/Mappings/~\$design.xlsx" --out "$WP_ROOT/lock" >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -eq 1 ] && [ ! -e "$WP_ROOT/lock" ] \
    || { echo "BUG [workbook-parse-lock-file]: an Office lock file was parsed (rc=$rc)"; exit 1; }
  [ "$(cksum < "$WP_ROOT/Mappings/design.xlsx")" = "$WP_SUM" ] \
    || { echo "BUG [workbook-parse-read-only]: the workbook changed"; exit 1; }
  echo "  ok [workbook-parse-refusals] — no clobber without --force, never beside the workbook," \
    "lock files refused, workbook byte-unchanged"
}

case_workbook_parse() {
  wp_fixture
  wp_extract
  wp_refusals
  rm -rf "$WP_ROOT"
}
