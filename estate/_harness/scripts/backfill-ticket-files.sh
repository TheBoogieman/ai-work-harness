#!/usr/bin/env bash
# backfill-ticket-files.sh — bring OLDER tickets up to the linked-file shape (#397).
#
#   bash _harness/scripts/backfill-ticket-files.sh --dry-run              # list what would change
#   bash _harness/scripts/backfill-ticket-files.sh                        # change it
#   bash _harness/scripts/backfill-ticket-files.sh --only <ticket> ...    # just these tickets (repeatable)
#
# WHY IT EXISTS. Since #397 every Session Log entry refreshes the ticket file's "## Ticket files"
# section, which links every retained file of the folder, and the validator fails a changed ticket
# whose AI-Knowledge/_index.md entry carries no link to its note. Tickets written before that have
# no section and bare index entries. They are not failed while they sit untouched, and the next
# entry on one adds the section anyway; this script does both for all of them at once, so every
# file in the estate is reachable from its ticket file after an upgrade.
#
# WHAT IT WRITES, per ticket with something to do:
#   1. AI-Knowledge/_index.md: the missing link on each entry and tombstone (ticket-files.py
#      --index --write). An entry with no file, or a tombstone whose note cannot be found, is
#      reported and left as it is: a link to nothing would claim a file exists.
#   2. ONE new Session Log entry through append-session-entry.sh, which links the Iterations files
#      and refreshes the Ticket files section in the same write. The entry is what keeps the
#      validator green: a ticket file that changes with no new entry is a FAIL. No older entry,
#      Current State line or other section changes, so a closed ticket stays closed.
# If the entry is refused, the index is put back as it was and the ticket is reported as skipped.
# Linking a file is navigation: nothing here reads a file's contents or says what a step produced.
#
# IDEMPOTENT. A second run finds nothing to do and writes nothing.
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKETS="$WORK_ROOT/Tickets"
# The same definition of "a ticket folder" the validator uses, and of the ledger files.
source "$SCRIPT_DIR/ticket-grammar.sh"
source "$SCRIPT_DIR/iteration-links.sh"
TF="$SCRIPT_DIR/ticket-files.py"

usage() { printf 'usage: backfill-ticket-files.sh [--dry-run] [--only <ticket>]...\n' >&2; exit 2; }
dry=0; only=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --only) [ "$#" -ge 2 ] || usage; only="${only}$2"$'\n'; shift 2 ;;
    *) usage ;;
  esac
done
command -v python3 >/dev/null 2>&1 \
  || { printf 'REFUSED: python3 is needed to inventory ticket folders; nothing written.\n' >&2; exit 2; }

changed=0; skipped=0; current=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  dir="$TICKETS/$name"; md="$dir/$name.md"
  [ -f "$md" ] || continue
  # The shipped template (and any 9999-prefixed copy of it) is not a real ticket.
  case "$name" in 9999*) continue ;; esac
  if [ -n "$only" ] && ! printf '%s' "$only" | grep -Fxq -- "$name"; then continue; fi

  # What there is to do: index links, section refresh, Iterations links. Each probe is a dry run.
  set +e
  idx_out=$(python3 "$TF" --index "$md" 2>&1); idx_rc=$?
  sec_out=$(python3 "$TF" "$md" 2>&1); sec_rc=$?
  set -e
  if [ "$idx_rc" -ge 2 ] || [ "$sec_rc" -ge 2 ]; then
    printf 'SKIPPED: %s — %s\n' "$name" "$(printf '%s\n%s\n' "$idx_out" "$sec_out" | grep -m1 'REFUSED' || true)"
    skipped=$((skipped + 1)); continue
  fi
  # Problems and skips the probes found are reported whether or not anything else changes.
  printf '%s\n%s\n' "$idx_out" "$sec_out" | grep -E '^(UNLINKED|SKIPPED|NOTE):' || true
  iter_n=$(iter_unlinked "$md" "$dir" | grep -c . || true)
  idx_n=$(printf '%s\n' "$idx_out" | sed -nE 's/^WOULD LINK: .* — ([0-9]+) entr.*/\1/p')
  [ -n "$idx_n" ] || idx_n=0
  if [ "$idx_rc" -eq 0 ] && [ "$sec_rc" -eq 0 ] && [ "$iter_n" -eq 0 ]; then
    current=$((current + 1)); continue
  fi
  sec_line=$(printf '%s\n' "$sec_out" | sed -nE 's/^(WOULD WRITE|UP TO DATE): [^ ]+ — //p' | head -1)
  if [ "$dry" -eq 1 ]; then
    printf 'WOULD LINK: %s — section: %s; index: %s entr(ies); iterations: %s file(s)\n' \
      "$name" "${sec_line:-up to date}" "$idx_n" "$iter_n"
    changed=$((changed + 1)); continue
  fi

  # 1. The index, with a copy kept so a refused entry can put it back.
  idx="$dir/AI-Knowledge/_index.md"; idx_keep=""
  if [ "$idx_n" -gt 0 ]; then
    idx_keep=$(mktemp "$dir/.ticket-files.XXXXXX")
    cp -p "$idx" "$idx_keep"
    if ! python3 "$TF" --index --write "$md" >/dev/null 2>&1; then
      rm -f "$idx_keep"
      printf 'SKIPPED: %s — the index could not be written\n' "$name"; skipped=$((skipped + 1)); continue
    fi
  fi
  # 2. One entry; the helper links the Iterations files and refreshes the section in the same write.
  files_n=$(printf '%s\n' "$sec_out" | sed -nE 's/.* ([0-9]+) retained file\(s\).*/\1/p' | head -1)
  body="- Ticket files section: added or refreshed by backfill-ticket-files.sh; it links the folder's ${files_n:-retained} retained file(s), directly or through the knowledge index and Iterations. Navigation only: no file was read or reviewed."
  [ "$idx_n" -eq 0 ] || body="$body"$'\n'"- AI-Knowledge/_index.md: added the link to its note on $idx_n entr(ies) or tombstone(s); file names and descriptions unchanged."
  [ "$iter_n" -eq 0 ] || body="$body"$'\n'"- Iterations: linked $iter_n prompt, output and review file(s)."
  set +e
  out=$(printf '%s\n' "$body" | bash "$SCRIPT_DIR/append-session-entry.sh" "$md" "Ticket files linked (backfill)" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    rm -f "$idx_keep"
    printf 'LINKED: %s — section: %s; index: %s entr(ies); iterations: %s file(s)\n' \
      "$name" "${sec_line:-up to date}" "$idx_n" "$iter_n"
    changed=$((changed + 1))
  else
    # The entry was refused, so the ticket is untouched; put the index back to match it.
    [ -z "$idx_keep" ] || mv -f "$idx_keep" "$idx"
    printf 'SKIPPED: %s — %s\n' "$name" "$(printf '%s' "$out" | head -1)"
    skipped=$((skipped + 1))
  fi
done < <(for d in "$TICKETS"/*/; do [ -d "$d" ] && basename "$d"; done 2>/dev/null | grep -E "$TICKET_RE" || true)

if [ "$dry" -eq 1 ]; then
  printf 'DRY RUN: %s ticket(s) would change, %s already current, %s skipped; nothing written.\n' "$changed" "$current" "$skipped"
else
  printf 'DONE: %s ticket(s) changed, %s already current, %s skipped.\n' "$changed" "$current" "$skipped"
fi
# A skipped ticket needs a person: say so with a non-zero exit, after doing everything else.
[ "$skipped" -eq 0 ]
