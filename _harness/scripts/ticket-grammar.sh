#!/usr/bin/env bash
# ticket-grammar.sh — the ONE home for what the tools treat as a ticket.
# Sourced (not run) by check_ticket_log.sh and harness-status.sh so the
# validator and the estate view share ONE answer to every "is this a
# ticket?" question and can never drift apart. Owns three predicates.

# 1. CONFORMING NAME — YYYYMM (exactly 6 digits) + a month-sequence of one
#    or more letters (A, B, ... Z, AA, ... — unbounded, so a month is never
#    capped at 26 tickets) + a board key + a numeric identifier of any
#    length. Only the date width is fixed; sequence, board, and number are
#    all unbounded. Example: 202607AAZ-NEXLKMPROJECTMAX-989812366178163
#    Edit THIS line (and only this line) to retarget the tools to your board.
export TICKET_RE='^[0-9]{6}[A-Z]+-[A-Z][A-Z0-9]*-[0-9]+$'

# 2. TICKET-BEARING — does a folder hold a ticket record? (the WARN trigger)
#    True if it contains a <foldername>.md, or any .md with "## Current
#    State". This is what tells a real-but-misnamed ticket apart from a
#    scratch dir.
ticket_bearing() {  # $1 = folder path
  local d="$1" base; base=$(basename "$d")
  [[ -f "$d/$base.md" ]] && return 0
  grep -lq "## Current State" "$d"/*.md 2>/dev/null && return 0
  return 1
}

# 3. SILENCED — has the user opted this folder out of the WARN?
#    True if a .not-a-ticket marker file is present. The marker lives in
#    the tracked tree, so silencing is a recorded, versioned human act.
export TICKET_NOT_MARKER='.not-a-ticket'
ticket_silenced() {  # $1 = folder path
  [[ -f "$1/$TICKET_NOT_MARKER" ]]
}

# 4. PENDING — a ticket that ticket-init created but could not name properly
#    (tracker unreachable and the user didn't supply an identity). Marked with
#    a .ticket-pending file. Unlike .not-a-ticket, this is NOT a "leave me
#    alone" flag — it means "this is a real ticket still awaiting its proper
#    name," so status nags about it until it's renamed.
export TICKET_PENDING_MARKER='.ticket-pending'
ticket_pending() {  # $1 = folder path
  [[ -f "$1/$TICKET_PENDING_MARKER" ]]
}
