#!/usr/bin/env bash
# shape-check.sh — the ENFORCING half of the code-shape gate (#120). It measures every tracked
# shell script with shape-measure.awk and fails when any file exceeds a limit it is not exempt
# from. DEV infrastructure: it lives under .github/ and never ships to a user estate (#43); no
# PRODUCT script references it, and the harness runs fully on a host that has never seen it.
#
# Usage:
#   bash .github/scripts/shape-check.sh              # the gate: measure, compare, exit 0 or 1
#   bash .github/scripts/shape-check.sh --regenerate # rewrite the exemption ledger from the
#                                                    # measurement, then exit 0
#   bash .github/scripts/shape-check.sh --report     # print every measured number and exit 0
#
# THE EXEMPTION LEDGER IS GENERATED, NEVER HAND-WRITTEN, AND IS PER LIMIT RATHER THAN PER FILE.
# A file over the line-length limit stays enforced on the other three, so a file leaves the ledger
# one limit at a time and never stops being enforced on the limits it already meets. Each row names
# the item whose acceptance deletes it, and deleting the row is part of that item's acceptance —
# which makes the ledger a shrinking record of known debt rather than a permanent carve-out.
#
# THE RECORDED NUMBER IS A CEILING, NOT A CLAIM ABOUT HEAD. An exempt file may improve freely; it
# may not get worse. That distinction is what keeps this gate from contending with every other item
# on the board: ordinary work inside an exempt file neither reds the gate nor forces a ledger
# rewrite, while a file that regresses on a limit it already fails reds by name. Raising a ceiling
# is possible — regenerate — but it is a visible diff in a tracked file, never a silent loosening.
#
# WHY IT REDS ON A STALE ROW: a row whose file now meets the limit is a false claim in a tracked
# file, and the fix (delete the row) is the last step of the item that earned it.
set -uo pipefail
export LC_ALL=C   # one measurement, identical on the Ubuntu runner and on the dev seat

SC_MEASURE=.github/scripts/shape-measure.awk
SC_LEDGER=.github/shape-exemptions.txt
SC_COLS=100       # the line-length limit, in characters; the ONE home for the number

# sc_limits — the four limits, one row each: "<key><TAB><budget><TAB><name><TAB><what it counts>".
# The key is what shape-measure.awk prints; the budget is the largest PASSING value.
sc_limits() {
  printf '%s\t%s\t%s\t%s\n' \
    longlines 0  line-length      "lines longer than $SC_COLS characters" \
    outside   40 outside-function "lines of code outside any function" \
    depth     4  nesting-depth    "deepest nesting of compound commands" \
    funclen   50 function-length  "longest function, in lines"
}

# sc_owner — the item whose acceptance deletes this file's exemptions. Per FILE because the shape
# items are per file: each one's goal condition is that its file meets EVERY limit. Anything not
# named here belongs to the sweep item, which owns the shape debt of every remaining script.
# #143 no longer appears here: its acceptance was that the acceptance suite meets every limit
# without an exemption, and the suite's files (the runner, the tour and the case files) now do.
# Anything they might owe in a later wave belongs to the sweep item, like every other script.
sc_owner() {
  case "$1" in
    .github/scripts/docs-check.sh) printf '#129\n' ;;
    install.sh) printf '#128\n' ;;
    _harness/scripts/harness-status.sh) printf '#128\n' ;;
    _harness/scripts/check_ticket_log.sh) printf '#128\n' ;;
    *) printf '#175\n' ;;
  esac
}

# sc_pins — THE CENSUS PIN. The function census is what three of the four limits are computed
# against, so a matcher that quietly stops finding a definition would report a SMALLER, passing
# number for the file that lost it. These rows name the shapes the census must find, chosen because
# each one breaks a different plausible tightening of the matcher; the pin reds by name rather than
# the count drifting silently. A TOTAL is deliberately NOT asserted: ordinary growth would red it,
# the constant would get bumped until bumping is reflex, and a bare number explains nothing.
# Rows: "<file><TAB><function><TAB>single|multi". "single" means the definition opens and closes on
# one line. Nine single-line definitions are pinned; the double-space one between "()" and "{" is
# the fixture that a tightened pattern drops while recovering the other eight. The set is a chosen
# BASIS, not a census of every definition in the tree — the acceptance suite alone now holds more
# single-line definitions than are listed here, and pinning each would turn this table into the
# bare count the paragraph above refuses to assert.
sc_pins() {
  printf '%s\t%s\t%s\n' \
    .github/scripts/docs-check.sh            oh_surface     single \
    _harness/scripts/harness-drill.sh        say            single \
    _harness/scripts/harness-housekeeping.sh dir_kb         single \
    _harness/demo/cases/backfill-guards.case.sh  code_has   single \
    _harness/demo/cases/backfill-guards.case.sh  code_hasE  single \
    _harness/demo/cases/recovery-drill.case.sh   hd_manifest single \
    _harness/demo/cases/estate-key.case.sh       g60_commits single \
    install.sh                               sedi           single \
    install.sh                               was_created    single \
    _harness/scripts/check_ticket_log.sh     file_mtime     multi \
    .github/scripts/docs-check.sh            md_slugs       multi \
    _harness/scripts/harness-drill.sh        undo_drill     multi \
    _harness/scripts/run_demo.sh             r09_make       multi \
    install.sh                               detect_board   multi
}

# sc_measure — run the scanner over every TRACKED shell script, resolved at run time by git rather
# than from a list, so a script added in a later item is measured the day it lands.
sc_measure() {
  local f files=()
  while IFS= read -r f; do files+=("$f"); done < <(git ls-files '*.sh')
  [ "${#files[@]}" -gt 0 ] \
    || { echo "shape-check: no tracked *.sh found — run this from the repository root."; return 1; }
  awk -v LIMIT="$SC_COLS" -f "$SC_MEASURE" "${files[@]}"
}

# sc_ledger_rows — the ledger, GENERATED: one row per (file, limit) whose measured value exceeds
# the default budget, carrying that value as the ceiling and the owning item.
sc_ledger_rows() {
  awk -F'\t' -v LIM="$1" '
    FILENAME == LIM { budget[$1] = $2; name[$1] = $3; next }
    ($2 in budget) && ($3 + 0 > budget[$2] + 0) { print $1 "\t" name[$2] "\t" $3 }
  ' "$1" "$2" | while IFS=$'\t' read -r f n v; do
    printf '%s\t%s\t%s\t%s\n' "$f" "$n" "$v" "$(sc_owner "$f")"
  done
}

# sc_regenerate — rewrite the ledger from the measurement. The banner is part of the artifact: a
# reader who does not know it is generated will hand-edit it, and a hand-edited ledger is a
# permanent carve-out wearing a generated file's clothes.
sc_regenerate() {
  {
    printf '# shape-exemptions.txt — GENERATED by .github/scripts/shape-check.sh --regenerate.\n'
    printf '# Do not hand-edit: a row is deleted by fixing the file, not by editing this line.\n'
    printf '# One row per (file, limit) that exceeds its limit TODAY; every other limit stays\n'
    printf '# enforced on that same file. Columns, TAB-delimited:\n'
    printf '#   <path>  <limit>  <ceiling: the worst value tolerated>  <item deleting the row>\n'
    printf '# The ceiling is a tolerance, not a claim about HEAD: the file may improve freely and\n'
    printf '# may not get worse. When it meets the limit outright the gate reds until the row is\n'
    printf '# deleted, which is the last step of the item named in it. A NEW script is expected\n'
    printf '# to meet every limit; regenerating to exempt one is a visible diff needing a reason.\n'
    printf '\n'
    sc_ledger_rows "$1" "$2" | sort
  } > "$SC_LEDGER"
  echo "shape-check: wrote $SC_LEDGER"
}

# sc_verdicts — join limits, ledger and measurement into one verdict per (file, limit):
#   ok      within the limit, no exemption
#   exempt  over the limit but at or under its recorded ceiling
#   over    over the limit with no exemption            -> FAIL
#   worse   over its ceiling                            -> FAIL
#   stale   exempt but now meets the limit outright     -> FAIL (delete the row)
#   orphan  a ledger row nothing measured               -> FAIL (stale path or limit key)
sc_verdicts() {
  awk -F'\t' -v LIM="$1" -v LED="$2" '
    FILENAME == LIM { budget[$1] = $2; name[$1] = $3; key[$3] = $1; next }
    FILENAME == LED {
      if ($0 ~ /^#/ || NF < 4) next
      ceil[$1 SUBSEP $2] = $3; own[$1 SUBSEP $2] = $4; next
    }
    ($2 in budget) { v[$1 SUBSEP name[$2]] = $3; if (!($1 in seen)) { seen[$1] = 1; f[++n] = $1 } }
    END {
      for (i = 1; i <= n; i++) for (k in key) {
        idx = f[i] SUBSEP k; b = budget[key[k]] + 0; val = v[idx] + 0; o = own[idx]
        if (!(idx in ceil)) print (val > b ? "over" : "ok") "\t" f[i] "\t" k "\t" val "\t" b "\t-"
        else if (val <= b) print "stale\t" f[i] "\t" k "\t" val "\t" b "\t" o
        else if (val > ceil[idx] + 0) print "worse\t" f[i] "\t" k "\t" val "\t" ceil[idx] "\t" o
        else print "exempt\t" f[i] "\t" k "\t" val "\t" ceil[idx] "\t" o
        delete ceil[idx]
      }
      for (idx in ceil) {
        split(idx, a, SUBSEP)
        print "orphan\t" a[1] "\t" a[2] "\t-\t" ceil[idx] "\t" own[idx]
      }
    }
  ' "$1" "$2" "$3" | sort
}

# sc_report_pins — assert every pinned shape is still found, with the shape it was pinned as.
sc_report_pins() {
  local pf pn ps row got rc=0
  while IFS=$'\t' read -r pf pn ps; do
    row=$(awk -F'\t' -v f="$pf" -v n="$pn" '$1==f && $2=="census" && $3==n {print $7}' "$1")
    if [ -z "$row" ]; then
      echo "FAIL [shape census]: the census no longer finds $pn() in $pf — the function matcher"
      echo "      stopped recognising a shape it must find, so every count for that file is now"
      echo "      wrong in the passing direction. Fix the matcher in $SC_MEASURE; never the pin."
      rc=1; continue
    fi
    got=multi; [ "$row" = "1" ] && got=single
    [ "$got" = "$ps" ] && continue
    echo "FAIL [shape census]: $pn() in $pf is pinned as a $ps-line definition but the census read"
    echo "      it as $got — the brace matcher changed. Fix $SC_MEASURE, or change the pin only if"
    echo "      the definition itself was deliberately rewritten."
    rc=1
  done < <(sc_pins)
  return "$rc"
}

# sc_gate — the whole verdict, printed in full before the exit code, so the log is the evidence.
sc_gate() {
  local st f lim val bud own rc=0 nex=0
  while IFS=$'\t' read -r st f lim val bud own; do
    case "$st" in
      ok) ;;
      exempt) nex=$((nex + 1)) ;;
      over)
        echo "FAIL [shape $lim]: $f measures $val against a limit of $bud, and holds no exemption."
        echo "      Bring it inside the limit. An exemption is not the remedy: the ledger is"
        echo "      generated from the debt that existed when it landed, and it only shrinks."
        rc=1 ;;
      worse)
        echo "FAIL [shape $lim]: $f measures $val, worse than the $bud it is exempt up to ($own)."
        echo "      An exempt file may improve freely and may not regress. Bring it back to $bud"
        echo "      or below. If the growth is genuinely part of the work, --regenerate raises the"
        echo "      ceiling — that is a reviewable diff in a tracked file and needs saying why."
        rc=1 ;;
      stale)
        echo "FAIL [shape $lim]: $f now meets this limit ($val against $bud) but still carries an"
        echo "      exemption. Delete its row from $SC_LEDGER; that deletion is the last step"
        echo "      of $own."
        rc=1 ;;
      orphan)
        echo "FAIL [shape $lim]: $SC_LEDGER exempts '$f' on '$lim', which nothing measures."
        echo "      The path or the limit name is stale — regenerate the ledger."
        rc=1 ;;
    esac
  done < <(sc_verdicts "$1" "$SC_LEDGER" "$2")
  echo "shape-check: $nex exemption(s) in force; every other (file, limit) pair enforced."
  return "$rc"
}

# sc_cleanup — the EXIT trap. It reads a GLOBAL rather than sc_main's local, because a local is
# already out of scope by the time an exit trap runs and "set -u" would then kill the script during
# its own teardown, turning a clean pass into a confusing failure.
sc_cleanup() {
  [ -n "${SC_TMP:-}" ] && rm -rf "$SC_TMP"
  return 0
}

sc_main() {
  local lim meas rc=0
  SC_TMP=$(mktemp -d); lim="$SC_TMP/limits"; meas="$SC_TMP/measure"
  trap sc_cleanup EXIT
  sc_limits > "$lim"
  # The scanner is an .awk file, so neither .gitattributes' *.sh pin nor the suite's carriage-return
  # tripwire covers it. A CR would make awk fail with a parse error nobody could read as a line
  # ending, so name the cause here instead. Detection matches the suite's: strip all but CR.
  [ -z "$(tr -dc '\r' < "$SC_MEASURE")" ] \
    || { echo "FAIL [shape scanner]: $SC_MEASURE carries a carriage return — check it out"; \
         echo "      with LF endings (git config core.autocrlf input)."; return 1; }
  sc_measure > "$meas" || return 1
  # THE SCANNER'S HONESTY CHECK, before any verdict is read. Shell that parses closes every block,
  # quote and heredoc, so a leftover is a defect in the MEASUREMENT rather than in the source — and
  # a scanner that has lost its place reports numbers that are wrong in the passing direction.
  local bad
  bad=$(awk -F'\t' '$2=="fatal" || $2=="error" || ($2=="balance" && $3+0!=0)' "$meas")
  if [ -n "$bad" ]; then
    echo "FAIL [shape scanner]: the measurement could not account for the source below, so no"
    echo "      number it prints can be trusted. Fix $SC_MEASURE before reading any verdict."
    printf '%s\n' "$bad" | sed 's/^/    /'
    return 1
  fi
  # --report must work BEFORE a ledger exists (that is how the first one is read), so it reads an
  # empty ledger rather than a missing file. The gate itself still refuses to run without one.
  local led="$SC_LEDGER"
  [ -f "$led" ] || led=/dev/null
  case "${1:-}" in
    --regenerate) sc_regenerate "$lim" "$meas"; return 0 ;;
    --report) sc_verdicts "$lim" "$led" "$meas"; return 0 ;;
  esac
  [ -f "$SC_LEDGER" ] \
    || { echo "FAIL [shape ledger]: $SC_LEDGER is missing — regenerate it."; return 1; }
  sc_report_pins "$meas" || rc=1
  sc_gate "$lim" "$meas" || rc=1
  [ "$rc" -eq 0 ] && echo "shape-check: PASS — every tracked shell script is inside its budget."
  [ "$rc" -eq 0 ] || echo "shape-check: FAILED — each line above names its fix."
  return "$rc"
}

sc_main "$@"
