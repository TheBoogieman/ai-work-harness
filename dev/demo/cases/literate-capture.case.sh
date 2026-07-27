#!/usr/bin/env bash
# literate-capture.case.sh — #78: the transport script turns comment-native delimiter blocks
# (`-- %% [label]` for SQL, `# %% [label]` for python) into notebook cell pairs through the
# append_notebook_cell.py plumbing. SOURCED by the runner; see dev/scripts/run_demo.sh.
#
# It is re-runnable (hash-dedupe), provenance-bearing, safe on malformed input, and NEVER touches
# the source bytes. This family proves all five properties on a two-block fixture. Cleanup is an
# explicit rm on EVERY exit path — the runner's single `trap ... EXIT` already owns the trap slot,
# so we must NOT add a second one (#86).
#
# The fixture variables (LC_TMP, LC_SRC, LC_SRC_SNAP, LC_NB) are built once and read by every
# assertion, so they stay file-scope rather than local to the builder.

lc_fixture() {
  LC_TMP=$(mktemp -d)
  LC_SRC="$LC_TMP/capture.sql"                 # a two-block SQL working file
  cat > "$LC_SRC" <<'LCSQL'
-- row counts must match between staging and prod
-- %% [row-parity]
SELECT COUNT(*) FROM staging.orders;
SELECT COUNT(*) FROM prod.orders;

-- no null customer ids after the backfill
-- %% [null-check]
SELECT COUNT(*) FROM prod.orders WHERE customer_id IS NULL;
LCSQL
  LC_SRC_SNAP=$(cksum "$LC_SRC")               # snapshot for the byte-identical assertion (#5)
  LC_NB="$LC_TMP/capture.ipynb"
  python3 -c "import nbformat,sys; nbformat.write(nbformat.v4.new_notebook(), sys.argv[1])" "$LC_NB"
}

# lc_ncells — how many cells the fixture notebook holds right now. One home, because two of the
# five assertions below ask the same question and a second copy could drift from this one.
lc_ncells() {
  python3 -c "import nbformat,sys
nb = nbformat.read(sys.argv[1], as_version=4)
print(len(nb.cells))" "$LC_NB"
}

# 1. Two blocks in → EXACTLY four cells out, alternating markdown and code.
lc_four_cells() {
  local LC_TYPES
  python3 estate/_harness/scripts/literate_capture.py "$LC_NB" "$LC_SRC" >/dev/null
  LC_TYPES=$(python3 -c "import nbformat,sys
nb = nbformat.read(sys.argv[1], as_version=4)
print(','.join(c.cell_type for c in nb.cells))" "$LC_NB")
  [ "$LC_TYPES" = "markdown,code,markdown,code" ] \
    || { echo "BUG [literate-capture]: two blocks did not yield exactly four alternating md/code" \
           "cells (got '$LC_TYPES') — check the block parser and the append pairing"; \
         rm -rf "$LC_TMP"; exit 1; }
  echo "  ok [literate-capture] — two blocks → four cells, alternating markdown/code"
}

# 2. Provenance present in each markdown cell: source path, label, and hash.
lc_provenance() {
  local lc_need
  for lc_need in "capture.sql" "row-parity" "null-check" "hash:"; do
    grep -Fq -- "$lc_need" "$LC_NB" \
      || { echo "BUG [literate-capture]: provenance is missing '$lc_need' from the markdown cells" \
             "— each md cell must record source path, label, and content hash"; \
           rm -rf "$LC_TMP"; exit 1; }
  done
  echo "  ok [literate-capture] — provenance (source path, label, hash) present in the" \
    "markdown cells"
}

# 3. Re-run over the same input → ZERO new cells (hash-dedupe holds).
lc_dedupe() {
  local LC_NCELLS
  python3 estate/_harness/scripts/literate_capture.py "$LC_NB" "$LC_SRC" >/dev/null
  LC_NCELLS=$(lc_ncells)
  [ "$LC_NCELLS" -eq 4 ] \
    || { echo "BUG [literate-capture]: a re-run over identical input added cells (now $LC_NCELLS," \
           "want 4) — hash-dedupe is not holding"; rm -rf "$LC_TMP"; exit 1; }
  echo "  ok [literate-capture] — re-run over the same input added zero cells (dedupe holds)"
}

# 4. Malformed input (content but no delimiter) → clean no-op with a prescriptive line, and the
#    notebook is untouched (non-destructive). Capture the output; it exits 0 (a guided no-op).
lc_malformed_noop() {
  local LC_BAD LC_BADOUT LC_NCELLS2
  LC_BAD="$LC_TMP/bad.sql"
  printf 'SELECT 1;\n-- a plain comment, no delimiter marker\n' > "$LC_BAD"
  set +e
  LC_BADOUT=$(python3 estate/_harness/scripts/literate_capture.py "$LC_NB" "$LC_BAD" 2>&1)
  set -e
  printf '%s\n' "$LC_BADOUT" | grep -q "no delimiter in" \
    || { echo "BUG [literate-capture]: malformed input did not emit the prescriptive" \
           "'no delimiter in ...' line:"; printf '%s\n' "$LC_BADOUT"; rm -rf "$LC_TMP"; exit 1; }
  LC_NCELLS2=$(lc_ncells)
  [ "$LC_NCELLS2" -eq 4 ] \
    || { echo "BUG [literate-capture]: malformed input was not a clean no-op — the notebook" \
           "changed (now $LC_NCELLS2 cells, want 4)"; rm -rf "$LC_TMP"; exit 1; }
  echo "  ok [literate-capture] — malformed input is a clean no-op with a prescriptive line," \
    "notebook untouched"
}

# 5. The source file is byte-identical before and after every run — this one is absolute.
lc_source_untouched() {
  [ "$(cksum "$LC_SRC")" = "$LC_SRC_SNAP" ] \
    || { echo "BUG [literate-capture]: the source file changed — capture must NEVER modify a" \
           "source (bytes must be identical before and after)"; rm -rf "$LC_TMP"; exit 1; }
  echo "  ok [literate-capture] — source file byte-identical after capture (sources are never" \
    "modified)"
}

case_literate_capture() {
  echo "--- #78: literate capture transports delimited blocks into notebook cells ---"
  lc_fixture
  lc_four_cells
  lc_provenance
  lc_dedupe
  lc_malformed_noop
  lc_source_untouched
  rm -rf "$LC_TMP"
}
