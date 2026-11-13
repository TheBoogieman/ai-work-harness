#!/usr/bin/env bash
# backfill-iterations.sh — link the prompt, output and review files of OLDER tickets (#384).
#
#   bash _harness/scripts/backfill-iterations.sh --dry-run    # list what would be linked, write nothing
#   bash _harness/scripts/backfill-iterations.sh              # link them
#
# WHY IT EXISTS. Since #384 every Session Log entry links the ticket's unlinked prompt, output and
# review files under "## Iterations", and the validator fails a changed ticket that still holds an
# unlinked one. Tickets written before that hold files nothing links. They are not failed while
# they sit untouched, and the next entry on one links its files anyway; this script does the same
# for all of them at once, so the whole estate is navigable from its ticket files after an upgrade.
#
# WHAT IT WRITES. For each ticket with at least one unlinked file, ONE new Session Log entry through
# append-session-entry.sh, which adds the links in the same write. The entry is what keeps the
# validator green: a ticket file that changes with no new entry is a FAIL. It writes nothing else:
# no older entry, no Current State line, no other section. A ticket whose file cannot take an entry
# (no Session Log section, a newer-than-now entry) is reported and skipped, never forced.
#
# IDEMPOTENT. A second run finds nothing unlinked and writes nothing.
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKETS="$WORK_ROOT/Tickets"
# The same definition of "a ticket folder" and of "linked" the validator uses.
source "$SCRIPT_DIR/ticket-grammar.sh"
source "$SCRIPT_DIR/iteration-links.sh"

dry=0
case "${1:-}" in
  --dry-run) dry=1 ;;
  "") ;;
  *) printf 'usage: backfill-iterations.sh [--dry-run]\n' >&2; exit 2 ;;
esac

linked=0; tickets=0; skipped=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  dir="$TICKETS/$name"; md="$dir/$name.md"
  [ -f "$md" ] || continue
  # The shipped template (and any 9999-prefixed copy of it) is not a real ticket.
  case "$name" in 9999*) continue ;; esac
  unlinked=$(iter_unlinked "$md" "$dir")
  [ -n "$unlinked" ] || continue
  n=$(printf '%s\n' "$unlinked" | grep -c . || true)
  if [ "$dry" -eq 1 ]; then
    printf 'WOULD LINK: %s — %s file(s)\n' "$name" "$n"
    printf '%s\n' "$unlinked" | sed 's/^/  /'
    tickets=$((tickets + 1)); linked=$((linked + n))
    continue
  fi
  # The helper links the files and appends the entry in one atomic write, or refuses and leaves the
  # ticket byte-identical. A refusal is reported with its reason and the run goes on.
  set +e
  out=$(printf -- '- Linked %s prompt, output and review file(s) under the Iterations section (backfill-iterations.sh); no other change.\n' "$n" \
        | bash "$SCRIPT_DIR/append-session-entry.sh" "$md" "Iteration files linked (backfill)" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'LINKED: %s — %s file(s)\n' "$name" "$n"
    tickets=$((tickets + 1)); linked=$((linked + n))
  else
    printf 'SKIPPED: %s — %s\n' "$name" "$(printf '%s' "$out" | head -1)"
    skipped=$((skipped + 1))
  fi
done < <(for d in "$TICKETS"/*/; do [ -d "$d" ] && basename "$d"; done 2>/dev/null | grep -E "$TICKET_RE" || true)

if [ "$dry" -eq 1 ]; then
  printf 'DRY RUN: %s file(s) in %s ticket(s) would be linked; nothing written.\n' "$linked" "$tickets"
else
  printf 'DONE: %s file(s) linked in %s ticket(s); %s ticket(s) skipped.\n' "$linked" "$tickets" "$skipped"
fi
# A skipped ticket needs a person: say so with a non-zero exit, after doing everything else.
[ "$skipped" -eq 0 ]
