#!/usr/bin/env bash
# append-session-entry.sh — append ONE Session Log entry to a ticket record, placed by code (#377).
#
#   bash _harness/scripts/append-session-entry.sh <ticket.md> "<short one-line description>" <<'EOF'
#   - first bullet
#   - second bullet
#   EOF
#
# It is ticket-scribe's only write path for an entry, and anyone else's who writes one by hand
# (CONSTITUTION §6). It exists because placement and the clock were judgement: the scribe hand-edited
# the file with a timestamp the parent read off the clock and passed in, and in a 32-ticket sweep it
# put two entries mid-log, where the validator could not see them as new.
#
# WHAT IT GUARANTEES, each by code rather than by care:
#   - THE CLOCK: the header time is read here, from LOCAL machine time (`date +%Y%m%d%H%M%S`, the
#     clock the validator parses, §6). Nobody passes a timestamp, so nobody can pass a wrong one.
#   - THE HEADER: exactly `## YYYYMMDDHHMMSS - <description>`, the strict form §6 pins.
#   - THE PLACE: the very end of the file, which must be the Session Log (the last `## ` section).
#   - THE ORDER: the new time must be later than every entry already there.
#   - ATOMICITY: the entry is written to a copy, the copy is checked (original bytes untouched, one
#     new entry, it is last and newest), and only then does the copy replace the ticket.
# Anything that would break one of those is REFUSED with the reason, exit 2, and the ticket is left
# byte-identical. It never edits an existing line, so it can never rewrite an older entry.
set -euo pipefail
export LC_ALL=C

refuse() {
  printf 'REFUSED: %s\n' "$*" >&2
  exit 2
}

ENTRY_RE='^## [0-9]{14} - '

[ "$#" -eq 2 ] || refuse "usage: append-session-entry.sh <ticket.md> \"<description>\" < body (two arguments, body on stdin)"
md="$1"; desc="$2"
[ -f "$md" ] || refuse "no such ticket record: $md"

# The description becomes the header's tail, so it must be one plain line.
case "$desc" in
  *$'\n'*|*$'\r'*) refuse "the description must be one line" ;;
esac
desc_trim="${desc#"${desc%%[![:space:]]*}"}"; desc_trim="${desc_trim%"${desc_trim##*[![:space:]]}"}"
[ -n "$desc_trim" ] || refuse "the description is empty"
case "$desc_trim" in '#'*) refuse "the description must not start with '#'" ;; esac

# The body is the entry's bullets. A line opening a level-1 or level-2 heading would end the entry
# early and start a section (or a forged entry) the validator would read as real.
body=$(cat)
body="${body%"${body##*[![:space:]]}"}"
[ -n "$body" ] || refuse "the entry body is empty; pass the bullets on stdin"
if printf '%s\n' "$body" | grep -qE '^#{1,2}( |$)'; then
  refuse "a body line opens a '#' or '##' heading, which would split the Session Log"
fi

# The end of the file must be the Session Log: the last level-2 heading that is not an entry.
last_section=$(grep -E '^## ' "$md" | grep -vE "$ENTRY_RE" | tail -1 | sed -E 's/[[:space:]#]*$//' || true)
[ "$last_section" = "## Session Log" ] \
  || refuse "the last section of $md is '${last_section:-none}', not '## Session Log'; appending at the end would land outside the log"

ts=$(date +%Y%m%d%H%M%S)
newest=$(grep -oE '^## [0-9]{14} ' "$md" | tr -dc '0-9\n' | sort | tail -1 || true)
if [ -n "$newest" ] && [ ! "$ts" \> "$newest" ]; then
  refuse "the local clock ($ts) is not after the newest entry ($newest); a future-dated or wrong-clock entry must be corrected first, or wait a second if one was just written"
fi
header="## $ts - $desc_trim"

tmp=$(mktemp "$(dirname "$md")/.append-session-entry.XXXXXX")
trap 'rm -f "$tmp"' EXIT
cp -p "$md" "$tmp"
size=$(wc -c < "$md" | tr -d ' ')
# A file that does not end in a newline gets one; then one blank line separates the entries.
if [ "$size" -gt 0 ] && [ "$(tail -c 1 "$md" | od -An -c | tr -d ' ')" != '\n' ]; then printf '\n' >> "$tmp"; fi
if [ -n "$(tail -n 1 "$tmp")" ]; then printf '\n' >> "$tmp"; fi
printf '%s\n%s\n' "$header" "$body" >> "$tmp"

# Check the copy before it replaces anything: the original bytes are its prefix, exactly one entry
# was added, and that entry is both the last and the newest.
head -c "$size" "$tmp" | cmp -s - "$md" || refuse "internal check: the original bytes changed in the copy"
before_n=$(grep -cE "$ENTRY_RE" "$md" || true)
after_n=$(grep -cE "$ENTRY_RE" "$tmp" || true)
[ "$after_n" -eq $((before_n + 1)) ] || refuse "internal check: expected one new entry, found $((after_n - before_n))"
[ "$(grep -E "$ENTRY_RE" "$tmp" | tail -1)" = "$header" ] || refuse "internal check: the new entry is not the last one"
[ "$(grep -oE '^## [0-9]{14} ' "$tmp" | tr -dc '0-9\n' | sort | tail -1)" = "$ts" ] \
  || refuse "internal check: the new entry is not the newest one"

mv "$tmp" "$md"
trap - EXIT
printf 'OK: appended to %s\n%s\n' "$md" "$header"
