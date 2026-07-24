#!/usr/bin/env bash
# tracker_sweep.sh — on-demand board-vs-estate drift report. A dumb M-lane sibling of
# harness-status: HUMAN-RUN and ON-DEMAND, NEVER wired to a hook. It reads each local
# ticket's upstream status through a PLUGGABLE FETCH SEAM, compares it against the local
# fact (the ticket folder is present, so the ticket is ACTIVE locally), and WARNs per
# divergence with the fix named. It only reports; it never edits an estate.
#
# FAILS OPEN (the load-bearing property): if the tracker is unreachable — or no fetcher is
# configured at all — this prints ONE quiet NOTE and exits 0. It NEVER reds. An estate with
# no network stays fully functional; a sweep that went red because a VPN dropped would only
# train users to ignore reds. Every finding here is a yellow WARN or a NOTE, so the exit code
# is ALWAYS 0 (yellow schedules, it never blocks — the harness's red/yellow doctrine).
#
# GENERIC / TRACKER-AGNOSTIC: the public product names no real tracker and makes no network
# call of its own. The only tracker coupling is two seams, both user-supplied at the fork
# layer: (1) the fetch command (env HARNESS_TRACKER_FETCH_CMD) that maps a ticket id to its
# upstream status, and (2) the ONE editable line below naming which upstream status words mean
# "closed". Tracker-specific fetchers are FORK-LAYER material and must never land in this repo.
# This mirrors the ticket-grammar precedent: the board coupling lives in ONE editable home,
# not scattered through the code.
#
# CREDENTIALS: any token the fetcher needs is read from the environment (or a keychain) at
# RUNTIME by the fetcher itself. This script passes the caller's environment through to the
# fetcher and never reads, prints, or writes a token — nothing here ever puts a credential on
# disk or into recorded output. See decisions/015 (this codifies the standing practice).
set -uo pipefail   # NOT -e: this tool fails open, so a stray non-zero must never abort it as a red
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# WORK_ROOT is derived from the script's location by default. HARNESS_WORK_ROOT overrides it so
# the demo guard can point the sweep at a throwaway Tickets/ fixture — no real tickets, no network.
WORK_ROOT="${HARNESS_WORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# One grammar home: reuse the validator/status definition of "what is a ticket" ($TICKET_RE,
# ticket_silenced) so the three tools recognise the exact same folders and can never drift.
source "$SCRIPT_DIR/ticket-grammar.sh"

# --- BOARD COUPLING — the ONE editable line (the ticket-grammar precedent) --------------------
# Which upstream status words mean a ticket is CLOSED/DONE on your board. Edit THIS line (and
# only this line) to match your tracker's closed vocabulary. Generic defaults; matched
# case-insensitively against the fetched status after whitespace is stripped.
HARNESS_TRACKER_CLOSED_RE="${HARNESS_TRACKER_CLOSED_RE:-^(closed|done|resolved|cancelled|complete|completed)$}"

# --- THE FETCH SEAM — pluggable, fork-layer, tracker-agnostic ---------------------------------
# HARNESS_TRACKER_FETCH_CMD names a command that, given ONE ticket id as its argument, prints
# that ticket's upstream status to stdout and exits 0; a non-zero exit means "could not reach
# the tracker". The public product ships with NO fetcher (this is empty) — write one at your
# fork layer. tracker_fetch_status is the single call site, and in this repo it reaches nothing.
tracker_fetch_status() {  # $1 = ticket id -> prints upstream status, rc 0; rc!=0 = unreachable
  [ -n "${HARNESS_TRACKER_FETCH_CMD:-}" ] || return 127   # no fetcher configured (defensive)
  "$HARNESS_TRACKER_FETCH_CMD" "$1"
}

# No fetcher configured at all → fail open with ONE quiet NOTE. This is the DEFAULT product
# state (the harness ships tracker-agnostic), and it is normal offline — never an error.
if [ -z "${HARNESS_TRACKER_FETCH_CMD:-}" ]; then
  echo "NOTE: no tracker fetcher configured — board-drift sweep skipped. Set HARNESS_TRACKER_FETCH_CMD to your fork-layer fetcher to enable it (this is normal; the estate stays fully functional)."
  exit 0
fi

# Enumerate locally-active tickets: folders under Tickets/ whose name conforms and that the user
# hasn't silenced. Presence in Tickets/ IS the local fact — an existing ticket is ACTIVE locally.
divergences=0
while IFS= read -r name; do
  d="$WORK_ROOT/Tickets/$name"
  ticket_silenced "$d" && continue          # user opted this folder out via .not-a-ticket
  # Fetch the upstream status through the seam. A non-zero exit = unreachable → FAIL OPEN: print
  # ONE quiet NOTE and stop. We never partially red and never guess — this is the load-bearing
  # branch that keeps a dropped VPN from turning into a red.
  if ! status="$(tracker_fetch_status "$name" 2>/dev/null)"; then
    echo "NOTE: tracker unreachable — board-drift sweep incomplete, no findings recorded (this is not an error; the estate stays fully functional offline)."
    exit 0
  fi
  # Normalise for comparison: lower-case and strip surrounding whitespace so "Closed", "closed ",
  # etc. all compare alike against the closed vocabulary above.
  status_norm="$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  # BY FACT: the ticket is present locally (active). If the board says it is closed, that is the
  # drift the issue names — closed upstream, active locally. WARN with the fix named.
  if printf '%s\n' "$status_norm" | grep -qiE "$HARNESS_TRACKER_CLOSED_RE"; then
    echo "WARN: $name is '$status' on the board but still active locally — reconcile: record the closure in the ticket's Current State and archive/close it locally (a fixed record is a human act)."
    divergences=$((divergences+1))
  fi
done < <(for dd in "$WORK_ROOT/Tickets"/*/; do [ -d "$dd" ] && basename "$dd"; done 2>/dev/null | grep -E "$TICKET_RE" || true)

# No divergence found → say so plainly. This is still just a report; the exit code stays 0.
if [ "$divergences" -eq 0 ]; then
  echo "OK: no board-vs-estate drift — every active ticket matches its upstream status."
fi
exit 0   # advisory only: every finding is a yellow WARN or a NOTE; the sweep never reds
