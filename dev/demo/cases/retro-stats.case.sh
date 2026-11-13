#!/usr/bin/env bash
# retro-stats.case.sh — [retro-counts] (#85; reworked for #381): retro-stats.sh is a DUMB counter,
# so a fixture estate with KNOWN ticket records must yield KNOWN numbers. SOURCED by the runner.
#
# #381 found the counter dating every ticket by the last git commit touching its folder and
# printing every ticket as closed, so one estate-wide commit moved every ticket into that month and
# open tickets were counted as closed. The rule this guard holds it to: a ticket is closed when its
# Current State "Now:" line starts with "Closed"; it is dated by the first YYYY-MM-DD in that line,
# else by its last Session Log entry, and never by git. Its pickup is its first Session Log entry,
# else the first day of its folder's YYYYMM month.
#
# retro-stats derives the estate it scans from HARNESS_WORK_ROOT, so we point the REAL shipped
# script at a throwaway fixture (no copy of the script — the exact shipped code runs). The fixture
# is its own git repo, and a final "sweep" commit re-commits every ticket folder in 2026-11, as an
# estate-wide edit (a link sweep, a frontmatter backfill, an upgrade) does: a counter that still
# read git dates would print one 2026-11 bucket and red here. Its tickets:
#   A 202603A-PROJ-1  closed, "Now:" dated 2026-03-30 though its last log entry is 2026-04-02 (the
#                     line wins); pickup 2026-03-02, its first entry, not its folder month (28 days);
#                     repo alpha, pipeline orders (block lists); PR #11 merged; two promotions.
#   B 202604A-PROJ-2  closed, no date in "Now:", so dated by its last log entry, 2026-04-15; pickup
#                     2026-04-01 (14 days); repos alpha and beta; PRs #11 (the same link as A's,
#                     counted once) and #12, both merged.
#   C 202605A-PROJ-3  open, though its header records PR #13 merged: an open ticket's PRs are not
#                     counted; two captured checks.
#   D 202606A-PROJ-4  closed, dated 2026-06-20, no log entry, so its pickup is its folder month,
#                     2026-06-01 (19 days); repo gamma, pipelines orders and billing (flow lists);
#                     PR #14 abandoned, so not counted.
#   E 202607A-PROJ-5  closed with no date anywhere: reported apart as undated, in no month.
#   T 999912Z-PROJ-99999  the shipped template, copied as is: a year-9999 example that the other
#                     observers (tracker-sweep, audit-inventory) skip, so it is neither open nor closed.
# The same counter then runs with a window, and on an empty directory, where it must print zeros
# and exit 0. Revert-proof: the git-dated counter prints "tickets-closed-total: 6" in one 2026-11
# bucket and reds on the first count. Cleanup is an explicit rm on every exit path — the runner's
# single `trap ... EXIT` already owns the trap slot, so we add NO second one (#86).

# r85_commit commits everything in the fixture at a fixed date, so every folder's last-commit
# month is known: it is the month a git-dated counter would wrongly report.
r85_commit() {  # $1 = commit label, $2 = YYYY-MM-DD
  git -C "$R85" add -A >/dev/null
  GIT_AUTHOR_DATE="$2 12:00:00" GIT_COMMITTER_DATE="$2 12:00:00" \
    git -C "$R85" -c user.email=demo@local -c user.name=demo commit -qm "$1" >/dev/null
}

# rs_fail prints why the guard failed and what the counter printed, removes both fixture dirs and
# stops the demo; every failure goes through it, so none leaves a temp dir behind.
rs_fail() {  # $1 = what went wrong, $2 = the counter's output
  echo "BUG [retro-counts]: $1"
  printf '%s\n' "$2"
  rm -rf "$R85" "$R85E"
  exit 1
}

# rs_ticket copies the shipped template folder (its Checks notebook and AI-Knowledge index feed
# the check and promotion counts) and replaces its record with the text on stdin, so each fixture
# ticket holds exactly the frontmatter, header, Current State and Session Log its numbers rest on,
# whatever the template's own record says.
rs_ticket() {  # $1 = ticket folder name; stdin = its record
  cp -r estate/Tickets/999912Z-PROJ-99999 "$R85/Tickets/$1"
  rm -f "$R85/Tickets/$1/999912Z-PROJ-99999.md"
  cat > "$R85/Tickets/$1/$1.md"
}

# rs_fixture builds the fixture estate described at the top of this file, and an empty directory.
rs_fixture() {
  local t
  echo "--- #85/#381 retrospective: retro-stats counts a fixture estate from its records ---"
  R85=$(mktemp -d)
  R85E=$(mktemp -d)
  git -C "$R85" init -q
  mkdir -p "$R85/Tickets"
  rs_ticket 202603A-PROJ-1 <<'EOF'
---
repos:
  - alpha
pipelines:
  - orders
---
# PROJ-1 — fixture: closed in March, its close-out logged in April

**Ticket:** PROJ-1

Pull Requests:
- [#11](https://example.com/alpha/pull/11) in `alpha` — merged 2026-03-30

---

## Current State
- Now: Closed — delivered, 2026-03-30; status from the operator.
- Next: none.
- Blocked: none.

## Session Log

## 20260302090000 - Ticket initialised
- Fixture entry.

## 20260402100000 - Close-out recorded
- Fixture entry.
EOF
  printf -- '- foo.md (promoted -> General AI-Knowledge/Topic)\n' \
    >> "$R85/Tickets/202603A-PROJ-1/AI-Knowledge/_index.md"
  printf -- '- bar.md (promoted -> General AI-Knowledge/Other)\n' \
    >> "$R85/Tickets/202603A-PROJ-1/AI-Knowledge/_index.md"
  rs_ticket 202604A-PROJ-2 <<'EOF'
---
repos:
  - alpha
  - beta
pipelines: []
---
# PROJ-2 — fixture: closed with no date in its Now line

**Ticket:** PROJ-2

Pull Requests:
- [#11](https://example.com/alpha/pull/11) in `alpha` — merged
- [#12](https://example.com/beta/pull/12) in `beta` — merged

---

## Current State
- Now: Closed — delivered; status from the operator.
- Next: none.
- Blocked: none.

## Session Log

## 20260401090000 - Ticket initialised
- Fixture entry.

## 20260415170000 - Closed
- Fixture entry.
EOF
  rs_ticket 202605A-PROJ-3 <<'EOF'
---
repos:
  - beta
pipelines: []
---
# PROJ-3 — fixture: still open

**Ticket:** PROJ-3

Pull Requests:
- [#13](https://example.com/beta/pull/13) in `beta` — merged

---

## Current State
- Now: Delivered in part; the issue stays open.
- Next: the rest of the change.
- Blocked: none.

## Session Log

## 20260505090000 - Ticket initialised
- Fixture entry.
EOF
  python3 estate/_harness/scripts/append-notebook-cell.py \
    "$R85/Tickets/202605A-PROJ-3/Checks/checks_master.ipynb" "check one" "SELECT 1;" >/dev/null
  python3 estate/_harness/scripts/append-notebook-cell.py \
    "$R85/Tickets/202605A-PROJ-3/Checks/checks_master.ipynb" "check two" "SELECT 2;" >/dev/null
  rs_ticket 202606A-PROJ-4 <<'EOF'
---
repos: [gamma]
pipelines: [orders, billing]
---
# PROJ-4 — fixture: closed and dated, no Session Log entry

**Ticket:** PROJ-4

Pull Requests:
- [#14](https://example.com/gamma/pull/14) in `gamma` — abandoned

---

## Current State
- Now: Closed — delivered, 2026-06-20.
- Next: none.
- Blocked: none.

## Session Log
EOF
  rs_ticket 202607A-PROJ-5 <<'EOF'
---
repos: []
pipelines: []
---
# PROJ-5 — fixture: closed with no date anywhere

**Ticket:** PROJ-5

Pull Requests:
- none yet

---

## Current State
- Now: Closed — dropped by the operator.
- Next: none.
- Blocked: none.

## Session Log
EOF
  # The template as shipped, record and all: it must be skipped, not counted as open or closed.
  cp -r estate/Tickets/999912Z-PROJ-99999 "$R85/Tickets/999912Z-PROJ-99999"
  r85_commit "fixture tickets" 2026-03-01
  # The sweep: one later commit that touches every ticket folder, as an estate-wide edit does.
  for t in "$R85"/Tickets/*/; do printf 'sweep\n' > "${t}Dump/sweep.txt"; done
  r85_commit "estate-wide sweep" 2026-11-05
  # Precondition, so the trap cannot silently disarm: the folders' last commit really is 2026-11.
  [ "$(git -C "$R85" log -1 --format=%ad --date=format:%Y-%m -- Tickets/202603A-PROJ-1)" = 2026-11 ] \
    || rs_fail "fixture setup: the sweep commit did not date the ticket folders in 2026-11" \
               "(the counter has not run yet)"
}

# rs_run runs the shipped counter on one estate, with or without a window, into RS_OUT, and fails
# unless it exits 0: the counter must never error, whatever it is pointed at.
rs_run() {  # $1 = estate root; optional $2 = --since value, $3 = --until value
  local rc
  set +e
  if [ -n "${2:-}" ]; then
    RS_OUT=$(HARNESS_WORK_ROOT="$1" bash estate/_harness/scripts/retro-stats.sh --since "$2" --until "$3")
  else
    RS_OUT=$(HARNESS_WORK_ROOT="$1" bash estate/_harness/scripts/retro-stats.sh)
  fi
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || rs_fail "retro-stats did not exit 0 on $1 (rc=$rc):" "$RS_OUT"
}

# rs_line fails unless the output holds this exact whole line (-x), so "total: 3" cannot pass on
# "total: 30". It reads a here-string, not a pipe, so pipefail cannot turn a match into a miss.
rs_line() {  # $1 = output, $2 = expected line, $3 = run label
  grep -qxF -- "$2" <<<"$1" \
    || rs_fail "retro-stats miscounted the fixture ($3) — expected line '$2':" "$1"
}

# rs_bucket compares a whole bucket list at once: the indented lines under one "header:" line,
# joined with "|". A missing, extra or misnamed bucket reds, not only a wrong number. The header
# itself must be printed, so an empty list is a stated nothing, not a vanished section.
rs_bucket() {  # $1 = output, $2 = header line, $3 = expected joined lines, $4 = run label
  local got
  grep -qxF -- "$2" <<<"$1" || rs_fail "retro-stats printed no '$2' line ($4):" "$1"
  got=$(awk -v h="$2" 'p && /^  / { sub(/^  /, ""); out = out (out == "" ? "" : "|") $0; next }
                       { p = ($0 == h) }
                       END { print out }' <<<"$1")
  [ "$got" = "$3" ] \
    || rs_fail "retro-stats bucketed the fixture wrongly ($4) — under '$2' expected '$3', got '$got':" "$1"
}

# rs_counts checks the all-time numbers: three closed tickets in their record months (none in the
# sweep's 2026-11), one open and one undated reported apart, the template skipped, the new counts.
rs_counts() {
  rs_run "$R85"
  rs_line "$RS_OUT" "tickets-closed-total: 3" "all time"
  rs_bucket "$RS_OUT" "tickets-closed-by-month:" "2026-03: 1|2026-04: 1|2026-06: 1" "all time"
  rs_line "$RS_OUT" "retro-stats since=all until=all" "all time"
  rs_line "$RS_OUT" "tickets-open-now: 1" "all time"
  rs_line "$RS_OUT" "tickets-closed-undated: 1" "all time"
  rs_line "$RS_OUT" "tickets-closed-dated-from-log: 1" "all time"
  rs_line "$RS_OUT" "pickup-to-close-days-median: 19" "all time"
  rs_line "$RS_OUT" "pickup-to-close-days-max: 28" "all time"
  rs_line "$RS_OUT" "pickup-from-folder-month: 1" "all time"
  rs_bucket "$RS_OUT" "tickets-closed-by-repo:" "alpha: 2|beta: 1|gamma: 1" "all time"
  rs_bucket "$RS_OUT" "tickets-closed-by-pipeline:" "billing: 1|orders: 2" "all time"
  rs_line "$RS_OUT" "prs-merged-on-closed-tickets: 2" "all time"
  rs_line "$RS_OUT" "checks-captured: 2" "all time"
  rs_line "$RS_OUT" "knowledge-promoted: 2" "all time"
  # The old output called its numbers a last-commit proxy; no line may still say so.
  if grep -qiE 'last[- ]commit' <<<"$RS_OUT"; then
    rs_fail "retro-stats still describes a last-commit proxy (all time):" "$RS_OUT"
  fi
}

# rs_window checks that --since/--until select by completion month (B alone, 2026-04), that every
# closed-ticket count follows the window, and that the open and undated counts do not: they have
# no completion month. The YYYY-MM-DD bound is cut to its month.
rs_window() {
  rs_run "$R85" 2026-04-01 2026-05
  rs_line "$RS_OUT" "retro-stats since=2026-04 until=2026-05" "window"
  rs_line "$RS_OUT" "tickets-closed-total: 1" "window"
  rs_bucket "$RS_OUT" "tickets-closed-by-month:" "2026-04: 1" "window"
  rs_line "$RS_OUT" "tickets-open-now: 1" "window"
  rs_line "$RS_OUT" "tickets-closed-undated: 1" "window"
  rs_line "$RS_OUT" "pickup-to-close-days-median: 14" "window"
  rs_line "$RS_OUT" "pickup-to-close-days-max: 14" "window"
  rs_line "$RS_OUT" "pickup-from-folder-month: 0" "window"
  rs_bucket "$RS_OUT" "tickets-closed-by-repo:" "alpha: 1|beta: 1" "window"
  rs_bucket "$RS_OUT" "tickets-closed-by-pipeline:" "" "window"
  rs_line "$RS_OUT" "prs-merged-on-closed-tickets: 2" "window"
}

# rs_empty checks the fails-open contract on a bare directory (no Tickets/, no git): every count
# is zero, every bucket list is empty, and the counter still exits 0.
rs_empty() {
  local need
  rs_run "$R85E"
  for need in "tickets-closed-total: 0" "tickets-open-now: 0" "tickets-closed-undated: 0" \
              "tickets-closed-dated-from-log: 0" "pickup-to-close-days-median: 0" \
              "pickup-to-close-days-max: 0" "pickup-from-folder-month: 0" \
              "prs-merged-on-closed-tickets: 0" "checks-captured: 0" "knowledge-promoted: 0"; do
    rs_line "$RS_OUT" "$need" "empty estate"
  done
  rs_bucket "$RS_OUT" "tickets-closed-by-month:" "" "empty estate"
  rs_bucket "$RS_OUT" "tickets-closed-by-repo:" "" "empty estate"
  rs_bucket "$RS_OUT" "tickets-closed-by-pipeline:" "" "empty estate"
}

case_retro_stats() {
  rs_fixture
  rs_counts
  rs_window
  rs_empty
  rm -rf "$R85" "$R85E"
  echo "  ok [retro-counts] — retro-stats dates 3 closed tickets by their records (Mar, Apr, Jun;" \
    "none in the sweep month), reports 1 open and 1 undated apart, skips the template, windows by" \
    "completion month, counts 2 checks, 2 promotions and 2 merged PRs; an empty estate gives zeros"
}
