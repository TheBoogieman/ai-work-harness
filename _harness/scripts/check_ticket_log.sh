#!/usr/bin/env bash
# check_ticket_log.sh — entry-gate validator. Facts only, no AI.
# Output grammar: single-line OK: / WARN: / FAIL: / NOTE: records. Exit !=0 on any FAIL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKETS="$WORK_ROOT/Tickets"
STAMPS="${HARNESS_STATE_DIR:-$HOME/.harness}/validated"
# One grammar home: the validator and harness-status source the SAME definition of
# "what is a ticket" so their view of the estate can never drift apart (R-09).
source "$SCRIPT_DIR/ticket-grammar.sh"
# ---- portability compat (GNU/BSD) — issue #1
file_mtime() {  # epoch mtime, GNU stat -c / BSD stat -f
  if stat -c %Y "$1" >/dev/null 2>&1; then stat -c %Y "$1"; else stat -f %m "$1"; fi
}
epoch_from_ts14() {  # YYYYMMDDHHMMSS -> epoch, GNU date -d / BSD date -j
  local t="$1"
  if date -d "1970-01-01" +%s >/dev/null 2>&1; then
    date -d "${t:0:8} ${t:8:2}:${t:10:2}:${t:12:2}" +%s 2>/dev/null || echo 0
  else
    date -j -f "%Y%m%d%H%M%S" "$t" +%s 2>/dev/null || echo 0
  fi
}

mkdir -p "$STAMPS"

fails=0
ticket_dirs() {
  # Emit one basename per Tickets/ subdir that matches the shared grammar's
  # $TICKET_RE (sourced above). Matching IS the validation boundary — only
  # recognised names are validated here; harness-status surfaces the rest.
  local d
  for d in "$TICKETS"/*/; do [[ -d "$d" ]] && basename "$d"; done 2>/dev/null \
    | grep -E "$TICKET_RE" || true
}

checked=0
# Read ticket names line-by-line rather than `for name in $(ticket_dirs)`: the old
# word-splitting form shattered a space-bearing folder like "My Random Ticket 42"
# into bogus names ("My", "Random", ...). Line-at-a-time keeps each name whole (R-09).
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  dir="$TICKETS/$name"; md="$dir/$name.md"; stamp="$STAMPS/$name"
  [[ -f "$md" ]] || { echo "FAIL: $name has no $name.md — create it from the template. Fix: cp -r Tickets/999912Z-PROJ-99999/* '$dir/' and rename."; fails=$((fails+1)); continue; }
  stamp_wall=0; stamp_mtime=0
  if [[ -f "$stamp" ]]; then
    stamp_wall=$(sed -n 1p "$stamp"); stamp_mtime=$(sed -n 2p "$stamp")
    [[ -z "$stamp_mtime" ]] && stamp_mtime=$stamp_wall   # legacy single-line stamp
  fi
  md_epoch=$(file_mtime "$md")
  (( md_epoch > stamp_mtime )) || continue   # unchanged since last successful validation
  checked=$((checked+1))
  ok=1

  # 1) newest session-log header must be at/after the watermark
  latest=$(grep -oE '^## [0-9]{14} ' "$md" | tail -1 | tr -dc '0-9' || true)
  if [[ -z "$latest" ]]; then
    echo "FAIL: $name has no Session Log entry. Fix: run ticket-scribe (or reconstruct from: git -C '$WORK_ROOT' log -- 'Tickets/$name')."; ok=0
  else
    latest_epoch=$(epoch_from_ts14 "$latest")
    if (( latest_epoch < stamp_wall )); then
      echo "FAIL: $name changed but no new Session Log entry since last validation. Fix: run ticket-scribe (or log 'session unrecorded; changes per commits' from git history)."; ok=0
    fi
  fi

  # 2) Current State section exists
  grep -q '^## Current State' "$md" || { echo "FAIL: $name missing '## Current State'. Fix: add the section per backbone PART I and have ticket-scribe fill it."; ok=0; }

  # 3) AI-Knowledge index integrity
  ak="$dir/AI-Knowledge"; idx="$ak/_index.md"
  if [[ -d "$ak" ]]; then
    [[ -f "$idx" ]] || { echo "FAIL: $name AI-Knowledge/ has no _index.md. Fix: create it listing one line per file."; ok=0; }
    live=0
    if [[ -f "$idx" ]]; then
      # ---- AI-Knowledge index grammar: ONE rule feeds orphan-coverage AND ghost-detection (R-04).
      # Pinned in folder-structure.md (AI Memory Convention). A line names a file ONLY via its
      # first token after "- "; the prose that follows is never scanned. Scanning prose is what
      # minted false ghosts — a truthful entry like "- notes.md — supersedes old-plan.md" would
      # raise old-plan.md as a ghost and RED-BLOCK an honest record (R-12). '#' comment lines and
      # '<...>' placeholder tokens name no file. Orphan and ghost read the SAME set, so they agree.
      entry_files=""    # newline-delimited set of real entry filenames (first tokens); feeds orphan-coverage
      ghost_lines=""    # entries whose filename backs no file and whose line is not a tombstone; reported below
      entry_re='^- ([^[:space:]]+)'   # entry candidate = starts "- " then a token
      # Pass 1 — read the index once; reduce each line to at most one filename.
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == \#* ]] && continue                 # comment line: inert, skip entirely
        [[ "$line" =~ $entry_re ]] || continue           # not "- <token>...": not an entry line
        tok="${BASH_REMATCH[1]}"                          # the filename is the FIRST token, nothing after it
        case "$tok" in *"<"*|*">"*) continue;; esac       # <...> placeholder: illustrative — skip deliberately, not by char-class luck
        [[ "$tok" =~ ^[A-Za-z0-9._-]+\.md$ ]] || continue # first token isn't a *.md filename: skip
        entry_files+="$tok"$'\n'
        # A tombstone (promotion record) exempts an entry from ghosting. Legacy estates may hold
        # tombstones written with the UNICODE arrow (the pre-004b fix-line taught it), so accept
        # BOTH "(promoted ->" and "(promoted →" — else an honest legacy tombstone flips
        # valid->ghost and red-blocks a real record (the exact R-04 failure). The emitted/
        # prescribed form stays ASCII "->" (see the fix-line below): accept-loose, prescribe-strict.
        if [[ ! -f "$ak/$tok" && "$line" != *"(promoted ->"* && "$line" != *"(promoted →"* ]]; then
          ghost_lines+="$tok"$'\n'                        # named a file that isn't here, and not a tombstone
        fi
      done < "$idx"
      # Orphan-coverage — every real AI-Knowledge/ file must equal some entry's first token.
      while IFS= read -r f; do
        base=$(basename "$f"); [[ "$base" == "_index.md" ]] && continue
        live=$((live+1))                                  # count real files (drives the fat/empty NOTEs below)
        printf '%s' "$entry_files" | grep -Fxq -- "$base" \
          || { echo "FAIL: $name orphan file AI-Knowledge/$base not in _index.md. Fix: echo '- $base — <what it covers>' >> '$idx'"; ok=0; }
      done < <(find "$ak" -maxdepth 1 -name '*.md' -type f)
      # Ghost-detection — report the entries collected in pass 1 (first-token name, no file, not a tombstone).
      while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        echo "FAIL: $name ghost entry '$ref' in _index.md (no file, no tombstone). Fix: remove the line or add '(promoted -> General AI-Knowledge/<Topic>)'."; ok=0
      done < <(printf '%s' "$ghost_lines")
      (( live > 10 )) && echo "NOTE: $name AI-Knowledge is fat ($live files) — run knowledge-curator."
      sessions=$(grep -cE '^## [0-9]{14} ' "$md" || true)
      (( sessions >= 3 && live == 0 )) && echo "NOTE: $name has $sessions sessions and zero captured knowledge — is knowledge-keeper being invoked?"
    fi
  fi

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
