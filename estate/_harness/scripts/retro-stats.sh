#!/usr/bin/env bash
# retro-stats.sh — the retrospective's DUMB counting pre-pass. It reads the ticket records and
# emits plain counts; it makes NO judgement about impact or theme (that is the retrospective
# agent's job, ABOVE the arithmetic). It reads local files only — no git history, nothing on the
# network — and it ALWAYS exits 0: a sparse or brand-new estate yields ZEROS, never an error, so
# the retrospective still runs on a thin estate (the fails-open family of #79/#81). The agent runs
# this, then folds the numbers INTO the human-facing document rather than leaving them beside it.
#
# Three groups of counts, all derived from ticket grammar + each ticket's own record + record
# markers:
#   1. tickets (#381) — every conforming, ticket-bearing folder except the year-9999 templates
#      (examples, not work; tracker-sweep and audit-inventory skip them too), read from its record:
#      - CLOSED when its Current State "Now:" line starts with "Closed" (the form audit-inventory
#        reads). Its completion date is the first YYYY-MM-DD in that line, else the date of its
#        LAST Session Log entry; a closed ticket with neither is reported as undated. NEVER a git
#        date: an estate-wide commit (a link sweep, a frontmatter backfill, an upgrade) touches
#        every folder, so a folder's commit date says when it was last edited, not when its work
#        closed. #381 found every ticket counted as closed in the month of one such commit.
#      - OPEN otherwise. Open and undated tickets have no completion month, so they are reported
#        on their own lines and the window does not apply to them.
#      - For the closed tickets inside the window: the count by completion month; how many were
#        dated from the log; the days from pickup (the FIRST Session Log entry, else the first day
#        of the folder's YYYYMM month) to completion, as median and maximum, and how many used the
#        folder month; the count per repo and per pipeline from the frontmatter `repos` /
#        `pipelines` lists; and the distinct PRs their headers record as merged (a line of the
#        header's "Pull Requests:" block that says "merged", keyed by its first link address, so a
#        PR shared by several tickets counts once).
#   2. checks captured — replay-definition code cells across every ticket's Checks notebook. This
#      is record volume, not proof that cells were executed or evidence verified.
#   3. knowledge promoted — tombstone lines in every AI-Knowledge/_index.md (a promotion to
#      General AI-Knowledge/ leaves a `promoted -> ...` tombstone).
#
# Window: --since / --until (YYYY-MM or YYYY-MM-DD) bound the COMPLETION month of the closed
# tickets counted in group 1; unset means all-time. The retrospective agent passes its own
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

# Optional date window. Compared as plain strings: a YYYY-MM month sorts and compares
# correctly against a YYYY-MM (or YYYY-MM-DD, truncated to 7 chars) bound.
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
# Truncate bounds to the YYYY-MM month so they compare against a completion month.
SINCE="${SINCE:0:7}"; UNTIL="${UNTIL:0:7}"

TICKETS_DIR="$WORK_ROOT/Tickets"

# --- 1. tickets, read from their own records (#381) ---------------------------------
# ticket_records decides only WHICH records to read and prints one "folder<TAB>record path"
# line for each: a conforming name AND a ticket-bearing folder (both grammar predicates, one
# home), minus the year-9999 templates. The awk program below reads the records and does all
# the counting, so no bash 4 feature is needed (macOS ships bash 3.2) and a path holding spaces
# passes through intact. No Tickets/ folder, or no tickets in it, prints nothing: all zeros.
ticket_records() {
  local d base rec
  [ -d "$TICKETS_DIR" ] || return 0
  for d in "$TICKETS_DIR"/*/; do
    [ -d "$d" ] || continue
    base=$(basename "$d")
    [[ "$base" =~ $TICKET_RE ]] || continue
    # The shipped template and its copies are examples, not work (tracker-sweep skips them too).
    case "$base" in 9999*) continue ;; esac
    ticket_bearing "$d" || continue
    # The record is <folder>.md; failing that, the first .md holding "## Current State", which
    # is the other way ticket_bearing recognises a ticket. No record found: nothing to count.
    rec="$d$base.md"
    [ -f "$rec" ] || rec=$(grep -l '^## Current State' "$d"*.md 2>/dev/null | head -n 1)
    { [ -n "$rec" ] && [ -f "$rec" ]; } || continue
    printf '%s\t%s\n' "$base" "$rec"
  done
}

# TICKET_AWK reads each "folder<TAB>record path" line, parses that record, and at the end prints
# the ticket counts. POSIX awk only (the demo runs it under mawk on Linux and the BSD awk on
# macOS), run with LC_ALL=C so buckets sort in byte order on every platform. It is one
# single-quoted shell string, so the program holds no apostrophe; \047 stands for one.
TICKET_AWK='
# civil: whole days since a fixed origin for a YYYY-MM-DD date (the days-from-civil method), so
# two dates subtract to a day count by integer arithmetic alone, with no date command.
function civil(s,    y, m, d, era, yoe, doy) {
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m <= 2) y = y - 1
  era = int(y / 400)
  yoe = y - era * 400
  doy = int((153 * (m > 2 ? m - 3 : m + 9) + 2) / 5) + d - 1
  return era * 146097 + yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
}

# day: the YYYY-MM-DD date of a 14-digit Session Log stamp (YYYYMMDDHHMMSS).
function day(t) {
  return substr(t, 1, 4) "-" substr(t, 5, 2) "-" substr(t, 7, 2)
}

# trim: the text without leading and trailing blanks.
function trim(s) {
  sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
  return s
}

# item: add one frontmatter list value to the list of its key, trimmed and with one pair of
# surrounding quotes removed (the same reading check-work-map.py applies).
function item(key, v,    q) {
  v = trim(v)
  q = substr(v, 1, 1)
  if (length(v) >= 2 && (q == "\"" || q == "\047") && substr(v, length(v), 1) == q) {
    v = substr(v, 2, length(v) - 2)
  }
  if (v == "") return
  if (key == "repos") rep[++nrep] = v
  if (key == "pipelines") pip[++npip] = v
}

# stamp: the 14 digits of a Session Log heading ("## YYYYMMDDHHMMSS - title"), else "".
function stamp(line,    t) {
  if (substr(line, 1, 3) != "## ") return ""
  t = substr(line, 4, 14)
  if (length(t) != 14 || t !~ /^[0-9]+$/) return ""
  if (length(line) > 17 && substr(line, 18, 1) != " " && substr(line, 18, 1) != "\t") return ""
  return t
}

# firstdate: the first YYYY-MM-DD in a line, else "".
function firstdate(s) {
  if (match(s, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) return substr(s, RSTART, 10)
  return ""
}

# ticket: read one record (folder = its ticket folder name, path = its .md), then count it.
function ticket(folder, path,    line, n, fm, key, v, k, i, j, head, inprs, incs, now, first, last, t, rest, cdate, pdate, month, fromlog) {
  nrep = 0; npip = 0; nprs = 0
  n = 0; fm = 0; key = ""; head = 1; inprs = 0; incs = 0; now = ""; first = ""; last = ""
  while ((getline line < path) > 0) {
    n++
    sub(/\r$/, "", line)
    # Frontmatter: opened by "---" on line 1 and closed by the next "---". Only repos and
    # pipelines are read, as a flow list ("key: [a, b]") or a block list ("key:" then "  - a").
    if (n == 1 && line == "---") { fm = 1; continue }
    if (fm) {
      if (line == "---") { fm = 0; continue }
      if (substr(trim(line), 1, 1) == "#") continue
      if (match(line, /^[^ \t:-][^:]*:/)) {
        key = substr(line, 1, RLENGTH - 1)
        v = trim(substr(line, RLENGTH + 1))
        if (key != "repos" && key != "pipelines") key = ""
        if (key != "" && v != "") {
          if (substr(v, 1, 1) == "[" && substr(v, length(v), 1) == "]") {
            k = split(substr(v, 2, length(v) - 2), parts, ",")
            for (i = 1; i <= k; i++) item(key, parts[i])
          }
          key = ""
        }
        continue
      }
      if (key != "" && match(line, /^[ \t]*-[ \t]/)) item(key, substr(line, RLENGTH + 1))
      continue
    }
    # The header is everything above the first "## " heading. Only its "Pull Requests:" block
    # is read: a list line there that says "merged" records one merged PR, keyed by its first
    # link address (or by the line itself when it holds no link). A blank line or a line that
    # is not part of the list ends the block.
    if (head && substr(line, 1, 3) == "## ") head = 0
    if (head) {
      if (trim(line) == "Pull Requests:") { inprs = 1; continue }
      if (inprs && (trim(line) == "" || line !~ /^[ \t-]/)) inprs = 0
      if (inprs && (" " tolower(line) " ") ~ /[^a-z]merged[^a-z]/) {
        i = index(line, "](")
        if (i > 0) {
          rest = substr(line, i + 2)
          j = index(rest, ")")
          if (j > 0) rest = substr(rest, 1, j - 1)
          prs[++nprs] = rest
        } else {
          prs[++nprs] = trim(line)
        }
      }
      continue
    }
    # Below the header: the first "- Now:" line of Current State, and every Session Log stamp
    # (the first one is the pickup, the last one the fallback completion date).
    if (substr(line, 1, 3) == "## ") incs = (trim(line) == "## Current State")
    if (incs && now == "" && tolower(trim(line)) ~ /^- now:/) now = trim(line)
    t = stamp(line)
    if (t != "") {
      if (first == "") first = t
      last = t
    }
  }
  close(path)
  if (n == 0) return
  # Open: the Now line does not start with "Closed". Undated: closed, but no date in that line
  # and no Session Log entry. Neither has a completion month, so the window never applies.
  if (index(tolower(now), "- now: closed") != 1) { opennow++; return }
  cdate = firstdate(now)
  fromlog = 0
  if (cdate == "" && last != "") { cdate = day(last); fromlog = 1 }
  if (cdate == "") { undated++; return }
  # The window selects by completion month; YYYY-MM strings compare correctly as text.
  month = substr(cdate, 1, 7)
  if (lo != "" && (month "") < (lo "")) return
  if (hi != "" && (month "") > (hi "")) return
  closed++
  bymonth[month]++
  if (fromlog) fromlogn++
  if (first != "") {
    pdate = day(first)
  } else {
    pdate = substr(folder, 1, 4) "-" substr(folder, 5, 2) "-01"
    foldermonth++
  }
  # A completion dated before the pickup (a ticket logged after the fact) counts as 0 days.
  k = civil(cdate) - civil(pdate)
  if (k < 0) k = 0
  dur[++ndur] = k
  # A repo or pipeline counts once per ticket; a PR counts once across all the tickets counted.
  split("", seen)
  for (i = 1; i <= nrep; i++) {
    v = "r" rep[i]
    if (!(v in seen)) { seen[v] = 1; byrepo[rep[i]]++ }
  }
  for (i = 1; i <= npip; i++) {
    v = "p" pip[i]
    if (!(v in seen)) { seen[v] = 1; bypipe[pip[i]]++ }
  }
  for (i = 1; i <= nprs; i++) {
    v = prs[i]
    if (!(v in prseen)) { prseen[v] = 1; merged++ }
  }
}

# sortnum: sort a[1..n] ascending as numbers (insertion sort; the lists are short).
function sortnum(a, n,    i, j, v) {
  for (i = 2; i <= n; i++) {
    v = a[i]; j = i - 1
    while (j > 0 && a[j] > v) { a[j + 1] = a[j]; j-- }
    a[j + 1] = v
  }
}

# bucket: print one "  key: count" line per entry of a count table, keys in byte order.
function bucket(arr,    k, n, keys, i, j, v) {
  n = 0
  for (k in arr) keys[++n] = k
  for (i = 2; i <= n; i++) {
    v = keys[i]; j = i - 1
    while (j > 0 && (keys[j] "") > (v "")) { keys[j + 1] = keys[j]; j-- }
    keys[j + 1] = v
  }
  for (i = 1; i <= n; i++) print "  " keys[i] ": " arr[keys[i]]
}

# Start every count at 0 and make every table an array up front, so an estate with no ticket
# still prints each count as 0 and each bucket list as empty.
BEGIN {
  opennow = 0; closed = 0; undated = 0; fromlogn = 0; foldermonth = 0; merged = 0; ndur = 0
  split("", bymonth); split("", byrepo); split("", bypipe); split("", prseen); split("", dur)
}

# Each input line is "folder<TAB>record path", from ticket_records.
{
  tab = index($0, "\t")
  if (tab > 0) ticket(substr($0, 1, tab - 1), substr($0, tab + 1))
}

# Every count prints, as 0 when nothing was counted. The median of an even count is the mean of
# the two middle values, rounded down to whole days.
END {
  sortnum(dur, ndur + 0)
  med = 0; mx = 0
  if (ndur > 0) {
    if (ndur % 2 == 1) {
      med = dur[(ndur + 1) / 2]
    } else {
      med = int((dur[ndur / 2] + dur[ndur / 2 + 1]) / 2)
    }
    mx = dur[ndur]
  }
  print "tickets-open-now: " (opennow + 0)
  print "tickets-closed-total: " (closed + 0)
  print "tickets-closed-by-month:"
  bucket(bymonth)
  print "tickets-closed-undated: " (undated + 0)
  print "tickets-closed-dated-from-log: " (fromlogn + 0)
  print "pickup-to-close-days-median: " med
  print "pickup-to-close-days-max: " mx
  print "pickup-from-folder-month: " (foldermonth + 0)
  print "tickets-closed-by-repo:"
  bucket(byrepo)
  print "tickets-closed-by-pipeline:"
  bucket(bypipe)
  print "prs-merged-on-closed-tickets: " (merged + 0)
}
'

# --- 2. recorded check definitions --------------------------------------------------
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
# A printed label is a claim, so the output itself says what its ticket counts measure and
# where each date comes from (#381); the header comment above says the same at more length.
echo "note: closed = a Current State \"Now:\" line starting \"Closed\", dated by the first YYYY-MM-DD in that line, else by the last Session Log entry; no git dates, no remote calls."
echo "note: --since/--until select closed tickets by completion month; tickets-open-now and tickets-closed-undated have no completion month and ignore them."
echo "note: pickup = the first Session Log entry, else the first day of the folder's month; merged PRs = distinct links on header \"Pull Requests:\" lines saying merged, on the closed tickets counted."
ticket_records | LC_ALL=C awk -v lo="$SINCE" -v hi="$UNTIL" "$TICKET_AWK"
echo "checks-captured: $checks_total"
echo "knowledge-promoted: $promoted_total"

exit 0
