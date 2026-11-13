#!/usr/bin/env bash
# mappings-index.case.sh — [mappings-index]: mappings-index.py lists the design workbooks and the
# pipeline page that names each (#385). SOURCED by the runner; see dev/scripts/run-demo.sh.
#
# An estate may hold dozens of workbooks in Mappings/, one per pipeline, each with several
# versions, and nothing listed them or showed which pipeline page owns which. The fixture is built
# here with openpyxl in a temporary estate, so no real design document is ever read; like the
# workbook-parse case, a Python without openpyxl is a red, not a skip.
#   [mappings-index]         rows, versions, pages and both gap lists are right; a lock file is
#                            not a workbook; nothing in Mappings/ changes; a second write is
#                            byte-identical.
#   [mappings-index-shipped] the page the harness ships is exactly what the script writes for an
#                            estate with no workbooks, so the shipped page cannot drift from it.
# The checker's warnings for the same two gaps are [work-map-workbooks], in work-map.case.sh.

mi_fixture() {
  echo "--- [mappings-index]: workbooks, their versions and the pipeline pages that name them ---"
  MI_ROOT=$(mktemp -d)
  MI_PY="${HARNESS_TEST_PYTHON:-python3}"
  MI_TOOL="$PWD/estate/_harness/scripts/mappings-index.py"
  [ -f "$MI_TOOL" ] || { echo "BUG [mappings-index]: the script is absent ($MI_TOOL)"; exit 1; }
  "$MI_PY" -c 'import openpyxl' 2>/dev/null \
    || { echo "BUG [mappings-index]: $MI_PY cannot import openpyxl — this case needs it" \
           "(python3 -m pip install openpyxl)"; exit 1; }
  mkdir -p "$MI_ROOT/Mappings" "$MI_ROOT/General AI-Knowledge/Work Map/Pipelines"
  # Three workbooks: one with a version-history tab, one with only a version column and a space in
  # its name, one that no page names. Plus an Office lock file, which is not a workbook.
  "$MI_PY" - "$MI_ROOT/Mappings" <<'MIPY'
import sys
from pathlib import Path
import openpyxl

folder = Path(sys.argv[1])

book = openpyxl.Workbook()
sheet = book.active
sheet.title = "Mapping"
sheet.append(["Field", "Type", "Version"])
sheet.append(["alpha", "int", "16.5"])
sheet.append(["beta", "str", "16.6"])
history = book.create_sheet("Version History")
history.append(["Version", "Description"])
history.append(["16.5", "first cut"])
history.append(["16.6", "adds beta"])
book.save(folder / "billing-design.xlsx")

book = openpyxl.Workbook()
sheet = book.active
sheet.title = "Mapping"
sheet.append(["Field", "Type", "Version"])
sheet.append(["gamma", "int", "2.10"])
sheet.append(["delta", "str", "2.9"])
book.save(folder / "Orders Design.xlsx")

book = openpyxl.Workbook()
book.active.append(["Field"])
book.save(folder / "unowned.xlsx")

(folder / "~$billing-design.xlsx").write_bytes(b"lock")
MIPY
  # Two pipeline pages. billing names its workbook and one that is not there; orders names the
  # workbook with a space, in the block-list form Obsidian writes.
  printf -- '---\nrepos: []\npipelines:\n  - billing\nworkbooks: [billing-design.xlsx, gone.xlsx]\n---\n# Billing\n' \
    > "$MI_ROOT/General AI-Knowledge/Work Map/Pipelines/billing.md"
  printf -- '---\nrepos: []\npipelines:\n  - orders\nworkbooks:\n  - Orders Design.xlsx\n---\n# Orders\n' \
    > "$MI_ROOT/General AI-Knowledge/Work Map/Pipelines/orders.md"
  MI_SUM=$(cd "$MI_ROOT/Mappings" && cksum ./* | LC_ALL=C sort)
}

mi_index() {
  local out page="$MI_ROOT/General AI-Knowledge/Work Map/Mappings.md" first
  out=$("$MI_PY" "$MI_TOOL" --root "$MI_ROOT" 2>&1) \
    || { echo "BUG [mappings-index]: the script failed on a well-formed estate:"; echo "$out"; exit 1; }
  # The history tab's order is kept and its last version is the latest.
  printf '%s\n' "$out" | grep -qF '| [billing-design.xlsx](../../Mappings/billing-design.xlsx) | 16.5, 16.6 | 16.6 | [billing](Pipelines/billing.md) |' \
    || { echo "BUG [mappings-index]: the workbook with a history tab has the wrong row:"; echo "$out"; exit 1; }
  # No history tab: the tagged versions, ordered as numbers (2.9 before 2.10), and a %20 link.
  printf '%s\n' "$out" | grep -qF '| [Orders Design.xlsx](../../Mappings/Orders%20Design.xlsx) | 2.9, 2.10 | 2.10 | [orders](Pipelines/orders.md) |' \
    || { echo "BUG [mappings-index]: the workbook with only a version column has the wrong row:"; echo "$out"; exit 1; }
  printf '%s\n' "$out" | grep -qF '| [unowned.xlsx](../../Mappings/unowned.xlsx) | none found | — | — |' \
    || { echo "BUG [mappings-index]: a workbook no page names has the wrong row:"; echo "$out"; exit 1; }
  if printf '%s\n' "$out" | grep -qF '~$'; then
    echo "BUG [mappings-index]: an Office lock file was listed as a workbook:"; echo "$out"; exit 1
  fi
  # The two gap lists.
  printf '%s\n' "$out" | awk '/^## Workbooks no pipeline page names/ { on = 1; next } /^## / { on = 0 } on' \
    | grep -qFx -- '- `unowned.xlsx`' \
    || { echo "BUG [mappings-index]: the unnamed workbook is not in its gap list:"; echo "$out"; exit 1; }
  printf '%s\n' "$out" | grep -qFx -- '- [billing](Pipelines/billing.md) names `gone.xlsx`' \
    || { echo "BUG [mappings-index]: a page naming an absent workbook is not in its gap list:"; echo "$out"; exit 1; }
  # Printing writes nothing; --write writes the same text, twice the same bytes.
  [ ! -e "$page" ] \
    || { echo "BUG [mappings-index]: printing the index wrote a file"; exit 1; }
  "$MI_PY" "$MI_TOOL" --root "$MI_ROOT" --write >/dev/null \
    || { echo "BUG [mappings-index]: --write failed"; exit 1; }
  [ "$(cat "$page")" = "$out" ] \
    || { echo "BUG [mappings-index]: the written page differs from the printed index"; exit 1; }
  first=$(cksum < "$page")
  "$MI_PY" "$MI_TOOL" --root "$MI_ROOT" --write >/dev/null
  [ "$(cksum < "$page")" = "$first" ] \
    || { echo "BUG [mappings-index]: a second --write changed the page; it must be reproducible"; exit 1; }
  # Nothing inside Mappings/ was written, re-saved or added.
  [ "$(cd "$MI_ROOT/Mappings" && cksum ./* | LC_ALL=C sort)" = "$MI_SUM" ] \
    || { echo "BUG [mappings-index]: the script changed something inside Mappings/"; exit 1; }
  echo "  ok [mappings-index] — one row per workbook with its versions and its pipeline page, both" \
    "gap lists, no lock file, a reproducible page and an untouched Mappings/"
}

# [mappings-index-shipped] The Work Map hub links Mappings.md, so the harness ships one. It must be
# what the script writes for an estate with no workbooks, or a fresh estate's first run would show
# a diff nobody made.
mi_shipped() {
  local shipped="estate/General AI-Knowledge/Work Map/Mappings.md" out
  [ -f "$shipped" ] \
    || { echo "BUG [mappings-index-shipped]: $shipped is not shipped, so the Work Map hub's link" \
           "to it is dead on a fresh estate"; exit 1; }
  out=$("$MI_PY" "$MI_TOOL" --root "$PWD/estate" 2>&1) \
    || { echo "BUG [mappings-index-shipped]: the script failed on the shipped estate:"; echo "$out"; exit 1; }
  [ "$out" = "$(cat "$shipped")" ] \
    || { echo "BUG [mappings-index-shipped]: the shipped page is not what the script writes for an" \
           "estate with no workbooks; regenerate it with --write:"; \
         diff <(printf '%s\n' "$out") "$shipped" || true; exit 1; }
  echo "  ok [mappings-index-shipped] — the shipped Mappings.md is exactly the script's output for" \
    "an estate with no workbooks"
}

case_mappings_index() {
  mi_fixture
  mi_index
  mi_shipped
  rm -rf "$MI_ROOT"
}
