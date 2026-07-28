#!/usr/bin/env bash
# check_ticket_log.sh — entry-gate validator. Facts only, no AI.
# Output grammar: single-line OK: / WARN: / FAIL: / NOTE: records. Exit !=0 on any FAIL.
#
# SHAPE (#128): the per-ticket checks are FUNCTIONS that main()'s loop calls in the order they have
# always run. The code inside each is the code that used to sit inside that loop, MOVED rather than
# rewritten, so the records read exactly as they did. Two conventions keep that move faithful:
#   - the checks share GLOBAL variables (the moved code declares no `local`), which is how the loop
#     body already passed values along — $name, $md, $ok and $fails above all;
#   - each check ends with an explicit `return 0`. A trailing non-zero status that merely CONTINUED
#     inside the loop (the tail of an `&&` list, say) becomes, once the same code is a function,
#     that function's RETURN value — which `set -e` would treat as a reason to abort the run
#     mid-ticket. The explicit return keeps the old meaning; a failure that aborted before still
#     aborts, since `set -e` is just as live inside a function as it was in the loop.
# The `continue` statements stay in main()'s loop, where the loop they act on is visible.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKETS="$WORK_ROOT/Tickets"
STAMPS="${HARNESS_STATE_DIR:-$HOME/.harness}/validated"
# One grammar home: the validator and harness-status source the SAME definition of
# "what is a ticket" so their view of the estate can never drift apart (R-09).
source "$SCRIPT_DIR/ticket-grammar.sh"
# epoch_from_ts14 (ts14->epoch) is SHARED with harness-status via portability.sh — one home so the
# validator and status can never drift on how a session-log header converts to epoch (R-21).
source "$SCRIPT_DIR/portability.sh"
# ---- portability compat (GNU/BSD) — issue #1 (file_mtime is validator-only, so it stays local)
file_mtime() {  # epoch mtime, GNU stat -c / BSD stat -f
  if stat -c %Y "$1" >/dev/null 2>&1; then stat -c %Y "$1"; else stat -f %m "$1"; fi
}

fails=0
checked=0

ticket_dirs() {
  # Emit one basename per Tickets/ subdir that matches the shared grammar's
  # $TICKET_RE (sourced above). Matching IS the validation boundary — only
  # recognised names are validated here; harness-status surfaces the rest.
  local d
  for d in "$TICKETS"/*/; do [[ -d "$d" ]] && basename "$d"; done 2>/dev/null \
    | grep -E "$TICKET_RE" || true
}

# read_stamp — load this ticket's stamp into stamp_wall / stamp_mtime.
# The stamp holds TWO clocks, one per question, so a change judged on one axis is never measured
# against the other's clock (a legacy single-line stamp used one value for both, conflating them
# — see the fallback below):
#   line 1 stamp_wall  = wall-clock at last validation      → RECENCY: is the newest session-log
#                        header at/after that moment?
#   line 2 stamp_mtime = the .md's mtime at last validation → FRESHNESS: did the file actually
#                        change since we last validated it?
read_stamp() {
  stamp_wall=0; stamp_mtime=0
  [[ -f "$stamp" ]] || return 0
  stamp_wall=$(sed -n 1p "$stamp"); stamp_mtime=$(sed -n 2p "$stamp")
  # legacy single-line stamp: reuse wall for both axes
  [[ -z "$stamp_mtime" ]] && stamp_mtime=$stamp_wall
  return 0
}

# check_recency — 1) RECENCY (header time vs stamp line 1, the wall-clock watermark): the newest
# session-log header must sit at/after the last validation — a file that changed with no new log
# entry FAILs.
check_recency() {
  latest=$(grep -oE '^## [0-9]{14} ' "$md" | tail -1 | tr -dc '0-9' || true)
  if [[ -z "$latest" ]]; then
    echo "FAIL: $name has no Session Log entry. Fix: run ticket-scribe" \
         "(or reconstruct from: git -C '$WORK_ROOT' log -- 'Tickets/$name')."
    ok=0
    return 0
  fi
  latest_epoch=$(epoch_from_ts14 "$latest")
  (( latest_epoch < stamp_wall )) || return 0
  echo "FAIL: $name changed but no new Session Log entry since last validation." \
       "Fix: run ticket-scribe (or log 'session unrecorded; changes per commits' from git history)."
  ok=0
  return 0
}

# check_current_state — 2) the Current State section exists.
check_current_state() {
  grep -q '^## Current State' "$md" && return 0
  echo "FAIL: $name missing '## Current State'." \
       "Fix: add the section per backbone PART I and have ticket-scribe fill it."
  ok=0
  return 0
}

# ---- AI-Knowledge index grammar: ONE rule feeds orphan-coverage AND ghost-detection (R-04).
# Pinned in CONSTITUTION.md (AI Memory Convention). A line names a file ONLY via its
# first token after "- "; the prose that follows is never scanned. Scanning prose is what
# minted false ghosts — a truthful entry like "- notes.md — supersedes old-plan.md" would
# raise old-plan.md as a ghost and RED-BLOCK an honest record (R-12). '#' comment lines and
# '<...>' placeholder tokens name no file. Orphan and ghost read the SAME set, so they agree.
#
# scan_index — pass 1: read the index once; reduce each line to at most one filename.
# entry_files = newline-delimited set of real entry filenames (first tokens); feeds orphan-coverage.
# ghost_lines = entries whose filename backs no file and whose line is not a tombstone.
scan_index() {
  entry_files=""
  ghost_lines=""
  entry_re='^- ([^[:space:]]+)'   # entry candidate = starts "- " then a token
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == \#* ]] && continue        # comment line: inert, skip entirely
    [[ "$line" =~ $entry_re ]] || continue  # not "- <token>...": not an entry line
    tok="${BASH_REMATCH[1]}"                # the filename is the FIRST token, nothing after it
    # <...> placeholder: illustrative — skipped deliberately, not by char-class luck
    case "$tok" in *"<"*|*">"*) continue;; esac
    # first token isn't a *.md filename: skip
    [[ "$tok" =~ ^[A-Za-z0-9._-]+\.md$ ]] || continue
    entry_files+="$tok"$'\n'
    # A tombstone (promotion record) exempts an entry from ghosting. Legacy estates may hold
    # tombstones written with the UNICODE arrow (an earlier fix-line taught it), so accept
    # BOTH "(promoted ->" and "(promoted →" — else an honest legacy tombstone flips
    # valid->ghost and red-blocks a real record (the exact R-04 failure). The emitted/
    # prescribed form stays ASCII "->" (see the fix-line below): accept-loose, prescribe-strict.
    if [[ ! -f "$ak/$tok" && "$line" != *"(promoted ->"* && "$line" != *"(promoted →"* ]]; then
      ghost_lines+="$tok"$'\n'              # named a file that isn't here, and not a tombstone
    fi
  done < "$idx"
  return 0
}

# check_orphans — every real AI-Knowledge/ file must equal some entry's first token.
# NOTE: orphan-coverage compares filenames case-sensitively (grep -Fxq) while ghost-detection
# follows the filesystem (-f in scan_index). On a case-insensitive Mac, a USER index-entry whose
# case doesn't match the file can make the two disagree — but it red-blocks on both filesystems (a
# "fix your case" nudge), never a silent pass. Known, benign edge.
check_orphans() {
  while IFS= read -r f; do
    base=$(basename "$f"); [[ "$base" == "_index.md" ]] && continue
    live=$((live+1))                        # count real files (drives the fat/empty NOTEs below)
    printf '%s' "$entry_files" | grep -Fxq -- "$base" && continue
    echo "FAIL: $name orphan file AI-Knowledge/$base not in _index.md." \
         "Fix: echo '- $base — <what it covers>' >> '$idx'"
    ok=0
  done < <(find "$ak" -maxdepth 1 -name '*.md' -type f)
  return 0
}

# report_ghosts — report the entries collected in pass 1 (first-token name, no file, no tombstone).
report_ghosts() {
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    echo "FAIL: $name ghost entry '$ref' in _index.md (no file, no tombstone)." \
         "Fix: remove the line or add '(promoted -> General AI-Knowledge/<Topic>)'."
    ok=0
  done < <(printf '%s' "$ghost_lines")
  return 0
}

# check_knowledge — 3) AI-Knowledge index integrity, plus the two size NOTEs it can see.
check_knowledge() {
  ak="$dir/AI-Knowledge"; idx="$ak/_index.md"
  [[ -d "$ak" ]] || return 0
  [[ -f "$idx" ]] || {
    echo "FAIL: $name AI-Knowledge/ has no _index.md. Fix: create it listing one line per file."
    ok=0
  }
  live=0
  [[ -f "$idx" ]] || return 0
  scan_index
  check_orphans
  report_ghosts
  (( live > 10 )) && echo "NOTE: $name AI-Knowledge is fat ($live files) — run knowledge-curator."
  sessions=$(grep -cE '^## [0-9]{14} ' "$md" || true)
  (( sessions >= 3 && live == 0 )) \
    && echo "NOTE: $name has $sessions sessions and zero captured knowledge —" \
            "is knowledge-keeper being invoked?"
  return 0
}

# main — the validation loop. Ticket names are read line-by-line rather than
# `for name in $(ticket_dirs)`: the old word-splitting form shattered a space-bearing folder like
# "My Random Ticket 42" into bogus names ("My", "Random", ...). Line-at-a-time keeps each name
# whole (R-09).
main() {
  mkdir -p "$STAMPS"
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    dir="$TICKETS/$name"; md="$dir/$name.md"; stamp="$STAMPS/$name"
    [[ -f "$md" ]] || {
      echo "FAIL: $name has no $name.md — create it from the template." \
           "Fix: cp -r Tickets/999912Z-PROJ-99999/* '$dir/' and rename."
      fails=$((fails+1)); continue
    }
    read_stamp
    md_epoch=$(file_mtime "$md")
    # FRESHNESS (mtime vs stamp line 2): if the file hasn't changed since last validation, skip it.
    (( md_epoch > stamp_mtime )) || continue
    checked=$((checked+1))
    ok=1
    check_recency
    check_current_state
    check_knowledge
    if (( ok == 1 )); then
      printf '%s\n%s\n' "$(date +%s)" "$md_epoch" > "$stamp"
      echo "OK: $name validated."
    else
      fails=$((fails+1))
    fi
  done < <(ticket_dirs)

  (( checked == 0 )) && echo "OK: no tickets modified since last validation — vacuous pass."
  (( fails == 0 )) || { echo "FAIL: $fails ticket(s) need attention — red blocks."; exit 1; }
  exit 0
}

main "$@"
