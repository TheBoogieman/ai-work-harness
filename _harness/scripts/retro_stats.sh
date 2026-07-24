#!/usr/bin/env bash
# retro_stats.sh — the retrospective's DUMB counting pre-pass. It reads the record
# and the git history and emits plain counts; it makes NO judgement about impact or
# theme (that is the retrospective agent's job, ABOVE the arithmetic). It talks to
# NOTHING on the network and it ALWAYS exits 0 — a sparse or brand-new estate yields
# ZEROS, never an error, so the retrospective still runs on a thin estate (the
# fails-open family of #79/#81). The agent runs this, then folds the numbers INTO the
# human-facing document rather than leaving them beside it.
#
# Three counts, all derived from ticket grammar + git dates + record markers:
#   1. tickets by closing month  — each conforming, ticket-bearing folder bucketed by
#      the month of its LAST git commit (its concluding activity). The script does not
#      claim which tickets are truly done vs still in flight — that is judgement the
#      agent adds; here we only bucket by when work last landed.
#   2. checks captured           — code cells across every ticket's Checks notebook
#      (the notebook records one code cell per verified check).
#   3. knowledge promoted        — tombstone lines in every AI-Knowledge/_index.md
#      (a promotion to General AI-Knowledge/ leaves a `promoted -> ...` tombstone).
#
# Window: --since / --until (YYYY-MM or YYYY-MM-DD) bound which closing-months count
# toward the ticket tally; unset means all-time. The retrospective agent passes its own
# 12-month default window here so the numbers match the prose.

# Deliberately NOT `set -e`: this script must survive every partial estate and still
# exit 0. We guard each step instead and finish with an explicit `exit 0`.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The estate to scan. Defaults to the estate this script ships inside (../.. from the
# scripts dir); HARNESS_WORK_ROOT lets a test point it at a throwaway fixture estate
# WITHOUT copying the script, so the guard exercises this exact code (not a copy).
WORK_ROOT="${HARNESS_WORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ONE grammar home: share the validator/status definition of "what is a ticket"
# (TICKET_RE, ticket_bearing) so this counter can never drift from them. Sourced from
# the real scripts dir even when WORK_ROOT points elsewhere.
source "$SCRIPT_DIR/ticket-grammar.sh"

# Optional date window. Compared as plain strings: a YYYY-MM month bucket sorts and
# compares correctly against a YYYY-MM (or YYYY-MM-DD, truncated to 7 chars) bound.
SINCE=""; UNTIL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="${2:-}"; shift 2 ;;
    --until) UNTIL="${2:-}"; shift 2 ;;
    --since=*) SINCE="${1#--since=}"; shift ;;
    --until=*) UNTIL="${1#--until=}"; shift ;;
    *) shift ;;   # unknown args ignored — dumb tool, never errors on input
  esac
done
# Truncate bounds to the YYYY-MM month so they compare against a month bucket.
SINCE="${SINCE:0:7}"; UNTIL="${UNTIL:0:7}"

# in_window MONTH — true unless the month falls outside a set --since/--until bound.
in_window() {  # $1 = YYYY-MM
  local m="$1"
  [ -n "$SINCE" ] && [ "$m" \< "$SINCE" ] && return 1
  [ -n "$UNTIL" ] && [ "$m" \> "$UNTIL" ] && return 1
  return 0
}

TICKETS_DIR="$WORK_ROOT/Tickets"

# --- 1. tickets by closing (last-commit) month --------------------------------------
# Walk every Tickets/ subfolder; keep only those the grammar recognises as conforming
# AND ticket-bearing; bucket each by the month of its most recent git commit. A folder
# with no git history (never committed) is skipped — fails open, never an error.
declare -a MONTHS=()          # parallel arrays: MONTHS[i] -> COUNTS[i] tally
declare -a COUNTS=()
tickets_total=0
if [ -d "$TICKETS_DIR" ]; then
  for d in "$TICKETS_DIR"/*/; do
    [ -d "$d" ] || continue
    base=$(basename "$d")
    # conforming name AND holds a ticket record — both grammar predicates, one home.
    [[ "$base" =~ $TICKET_RE ]] || continue
    ticket_bearing "$d" || continue
    # month of the folder's last commit, taken from git (fails open to empty).
    rel="Tickets/$base"
    month=$(git -C "$WORK_ROOT" log -1 --format=%ad --date=format:%Y-%m -- "$rel" 2>/dev/null)
    [ -n "$month" ] || continue                 # uncommitted fixture/folder → skip
    in_window "$month" || continue
    tickets_total=$((tickets_total + 1))
    # accumulate into the month bucket (linear scan — the month set is tiny).
    found=0
    for i in "${!MONTHS[@]}"; do
      if [ "${MONTHS[$i]}" = "$month" ]; then COUNTS[$i]=$(( ${COUNTS[$i]} + 1 )); found=1; break; fi
    done
    [ "$found" -eq 1 ] || { MONTHS+=("$month"); COUNTS+=(1); }
  done
fi

# --- 2. checks captured -------------------------------------------------------------
# Sum code cells across every Checks/checks_master.ipynb under Tickets/. The notebook
# is JSON; a code cell is the line `"cell_type": "code"`. grep -c is the dumb count.
# Each notebook ships with exactly ONE mandatory setup code cell (template "cell 0 -
# setup"), which is NOT a captured check, so we subtract one per notebook and floor at
# zero. A fresh template ticket therefore honestly reports zero checks captured.
checks_total=0
if [ -d "$TICKETS_DIR" ]; then
  while IFS= read -r nb; do
    n=$(grep -c '"cell_type": "code"' "$nb" 2>/dev/null || true)
    n=${n:-0}
    n=$((n - 1))                      # drop the mandatory setup cell
    [ "$n" -gt 0 ] && checks_total=$((checks_total + n))
  done < <(find "$TICKETS_DIR" -type f -name 'checks_master.ipynb' 2>/dev/null)
fi

# --- 3. knowledge promoted ----------------------------------------------------------
# Sum tombstone lines across every AI-Knowledge/_index.md. A promotion to
# General AI-Knowledge/ leaves a `- <file> (promoted -> General AI-Knowledge/...)`
# tombstone LIST line. We anchor on the leading `- ` so the file's own `#` header
# comment (which spells out the tombstone FORMAT, paren and all) is never miscounted
# as a real promotion.
promoted_total=0
if [ -d "$TICKETS_DIR" ]; then
  while IFS= read -r idx; do
    n=$(grep -cE '^[[:space:]]*- .*promoted -> General AI-Knowledge/' "$idx" 2>/dev/null || true)
    promoted_total=$((promoted_total + ${n:-0}))
  done < <(find "$TICKETS_DIR" -type f -path '*/AI-Knowledge/_index.md' 2>/dev/null)
fi

# --- emit the counts ----------------------------------------------------------------
# Plain, stable, greppable lines so the agent (and the demo guard) read exact numbers.
echo "retro-stats since=${SINCE:-all} until=${UNTIL:-all}"
echo "tickets-closed-total: $tickets_total"
echo "tickets-closed-by-month:"
# Print month buckets in sorted order for a stable, human-readable report.
for pair in $(for i in "${!MONTHS[@]}"; do printf '%s:%s\n' "${MONTHS[$i]}" "${COUNTS[$i]}"; done | sort); do
  echo "  ${pair%%:*}: ${pair##*:}"
done
echo "checks-captured: $checks_total"
echo "knowledge-promoted: $promoted_total"

exit 0
