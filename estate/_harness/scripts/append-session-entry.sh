#!/usr/bin/env bash
# append-session-entry.sh — append ONE Session Log entry to a ticket record, placed by code (#377).
#
#   bash _harness/scripts/append-session-entry.sh <ticket.md> "<short one-line description>" <<'EOF'
#   - first bullet
#   - second bullet
#   EOF
#
# It is the only write path for an entry: ticket-scribe's, a parent agent's, and a human's by hand
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
#   - CURRENT STATE (#382): with --now / --next / --blocked, those lines of the Current State
#     section are rewritten in the same write, and nothing outside that section changes:
#       bash _harness/scripts/append-session-entry.sh --now "<now>" --next "<next>" \
#         --blocked "<blocked>" <ticket.md> "<description>" < body
# Anything that would break one of those is REFUSED with the reason, exit 2, and the ticket is left
# byte-identical. Outside the Current State lines an option names and the Iterations section (below),
# it never edits an existing line, so it can never rewrite an older entry.
#
# ITERATION LINKS (#384): every call also links, under "## Iterations", each prompt, output and
# review file of the ticket (Agent-Prompts/NN-*.md, Agent-Output/NN-*.md) that the ticket file does
# not link yet, in the same atomic write. It needs no option: an agent cannot forget it.
set -euo pipefail
export LC_ALL=C

refuse() {
  printf 'REFUSED: %s\n' "$*" >&2
  exit 2
}

ENTRY_RE='^## [0-9]{14} - '

# Optional Current State lines (#382). The entry and Current State are one step (CONSTITUTION §5,
# §6), and the second half used to be a hand edit the scribe sometimes declined to make. Each option
# replaces that one line of the Current State section in the same atomic write as the entry; an
# option not given leaves its line alone.
cs_now=""; cs_next=""; cs_blocked=""; set_now=0; set_next=0; set_blocked=0
# one_line LABEL VALUE — a Current State value becomes one bullet, so it must be one plain line.
one_line() {
  case "$2" in
    *$'\n'*|*$'\r'*) refuse "the $1 value must be one line" ;;
  esac
  [ -n "${2//[[:space:]]/}" ] || refuse "the $1 value is empty"
  case "$2" in '#'*) refuse "the $1 value must not start with '#'" ;; esac
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --now)     [ "$#" -ge 2 ] || refuse "--now needs a value";     one_line --now "$2";     cs_now="$2";     set_now=1;     shift 2 ;;
    --next)    [ "$#" -ge 2 ] || refuse "--next needs a value";    one_line --next "$2";    cs_next="$2";    set_next=1;    shift 2 ;;
    --blocked) [ "$#" -ge 2 ] || refuse "--blocked needs a value"; one_line --blocked "$2"; cs_blocked="$2"; set_blocked=1; shift 2 ;;
    --) shift; break ;;
    --*) refuse "unknown option $1 (known: --now, --next, --blocked)" ;;
    *) break ;;
  esac
done

[ "$#" -eq 2 ] || refuse "usage: append-session-entry.sh [--now <text>] [--next <text>] [--blocked <text>] <ticket.md> \"<description>\" < body (two arguments, body on stdin)"
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
# `base` is the ticket as it stands before the entry is appended: the ticket itself, or, when a
# Current State option was given, a second copy with those lines rewritten.
base="$md"; cs_tmp=""; it_tmp=""
trap 'rm -f "$tmp" "$cs_tmp" "$it_tmp"' EXIT

# cs_strip FILE — the file without the body of its Current State section, so two files can be
# compared on everything else. The section runs from its heading to the next level-2 heading.
cs_strip() { awk '/^## Current State/ { print; on = 1; next } on && /^## / { on = 0 } !on { print }' "$1"; }

if [ $((set_now + set_next + set_blocked)) -gt 0 ]; then
  grep -q '^## Current State' "$md" \
    || refuse "$md has no '## Current State' section, so --now/--next/--blocked have nowhere to go"
  cs_tmp=$(mktemp "$(dirname "$md")/.append-session-entry.XXXXXX")
  # Rewrite the section in a copy. A line that opens "- Now:", "- Next:" or "- Blocked:" (bold
  # markers allowed) is replaced when its option was given; a given line the section lacks is added
  # after its last non-blank line. The values travel in the environment, never through awk -v,
  # which would expand backslashes in them.
  CS_NOW="$cs_now" CS_NEXT="$cs_next" CS_BLOCKED="$cs_blocked" \
  awk -v sn="$set_now" -v sx="$set_next" -v sb="$set_blocked" '
    # flush — print the buffered section body: its lines, then any given line it lacked, then the
    # blank lines that closed it.
    function flush(   i, last) {
      last = n
      while (last > 0 && buf[last] ~ /^[[:space:]]*$/) last--
      for (i = 1; i <= last; i++) print buf[i]
      if (sn == 1 && !seen_now)     print "- Now: " ENVIRON["CS_NOW"]
      if (sx == 1 && !seen_next)    print "- Next: " ENVIRON["CS_NEXT"]
      if (sb == 1 && !seen_blocked) print "- Blocked: " ENVIRON["CS_BLOCKED"]
      for (i = last + 1; i <= n; i++) print buf[i]
      n = 0
    }
    /^## Current State/ && !done { print; on = 1; next }
    on && /^## / { flush(); on = 0; done = 1 }
    on {
      if ($0 ~ /^- \**Now:/     && sn == 1) { $0 = "- Now: " ENVIRON["CS_NOW"];         seen_now = 1 }
      if ($0 ~ /^- \**Next:/    && sx == 1) { $0 = "- Next: " ENVIRON["CS_NEXT"];       seen_next = 1 }
      if ($0 ~ /^- \**Blocked:/ && sb == 1) { $0 = "- Blocked: " ENVIRON["CS_BLOCKED"]; seen_blocked = 1 }
      buf[++n] = $0; next
    }
    { print }
    END { if (on) flush() }
  ' "$md" > "$cs_tmp"
  # Check the rewrite before building on it: nothing outside the section changed, and each given
  # line is now in the file exactly as given.
  cs_strip "$md" | cmp -s - <(cs_strip "$cs_tmp") \
    || refuse "internal check: the Current State rewrite changed something outside that section"
  [ "$set_now" -eq 0 ]     || grep -qFx -- "- Now: $cs_now" "$cs_tmp"         || refuse "internal check: the Now line was not written"
  [ "$set_next" -eq 0 ]    || grep -qFx -- "- Next: $cs_next" "$cs_tmp"       || refuse "internal check: the Next line was not written"
  [ "$set_blocked" -eq 0 ] || grep -qFx -- "- Blocked: $cs_blocked" "$cs_tmp" || refuse "internal check: the Blocked line was not written"
  base="$cs_tmp"
fi

# ITERATION LINKS (#384). A prompt, output or review file that the ticket file does not link is an
# orphan: neither a reader nor an agent picking the ticket up can find it from the record. Linking
# it used to be something an agent had to remember. Every entry now links whatever is unlinked, under
# "## Iterations", in the same atomic write, so the validator's unlinked-file check cannot fail on
# a ticket whose entries go through this helper. The shared definition of "linked" lives in
# iteration-links.sh, which the validator reads too.
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/iteration-links.sh"
ticket_dir=$(dirname "$md")
it_tmp=$(mktemp "$ticket_dir/.append-session-entry.XXXXXX")
iter_sync "$base" "$ticket_dir" "$it_tmp"
if [ "$ITER_LINKED" -gt 0 ]; then
  # Check the sync before building on it: nothing outside the Iterations section changed (blank
  # and "---" lines aside, which a new section moves), and no ledger file is left unlinked.
  iter_strip "$base" | cmp -s - <(iter_strip "$it_tmp") \
    || refuse "internal check: linking the iteration files changed something outside '## Iterations'"
  [ -z "$(iter_unlinked "$it_tmp" "$ticket_dir")" ] \
    || refuse "internal check: a prompt, output or review file is still unlinked after the sync"
  base="$it_tmp"
fi

cp -p "$md" "$tmp"
cat "$base" > "$tmp"
size=$(wc -c < "$base" | tr -d ' ')
# A file that does not end in a newline gets one; then one blank line separates the entries.
if [ "$size" -gt 0 ] && [ "$(tail -c 1 "$base" | od -An -c | tr -d ' ')" != '\n' ]; then printf '\n' >> "$tmp"; fi
if [ -n "$(tail -n 1 "$tmp")" ]; then printf '\n' >> "$tmp"; fi
printf '%s\n%s\n' "$header" "$body" >> "$tmp"

# Check the copy before it replaces anything: the bytes before the entry are its prefix (the ticket
# itself, or the ticket with only Current State rewritten), exactly one entry was added, and that
# entry is both the last and the newest.
head -c "$size" "$tmp" | cmp -s - "$base" || refuse "internal check: the original bytes changed in the copy"
before_n=$(grep -cE "$ENTRY_RE" "$md" || true)
after_n=$(grep -cE "$ENTRY_RE" "$tmp" || true)
[ "$after_n" -eq $((before_n + 1)) ] || refuse "internal check: expected one new entry, found $((after_n - before_n))"
[ "$(grep -E "$ENTRY_RE" "$tmp" | tail -1)" = "$header" ] || refuse "internal check: the new entry is not the last one"
[ "$(grep -oE '^## [0-9]{14} ' "$tmp" | tr -dc '0-9\n' | sort | tail -1)" = "$ts" ] \
  || refuse "internal check: the new entry is not the newest one"

mv "$tmp" "$md"
rm -f "$cs_tmp" "$it_tmp"
trap - EXIT
printf 'OK: appended to %s\n%s\n' "$md" "$header"
# Say which Current State lines were rewritten, so the caller need not read the file to know.
if [ $((set_now + set_next + set_blocked)) -gt 0 ]; then
  printf 'Current State rewritten:%s%s%s\n' \
    "$([ "$set_now" -eq 1 ] && printf ' Now')" "$([ "$set_next" -eq 1 ] && printf ' Next')" \
    "$([ "$set_blocked" -eq 1 ] && printf ' Blocked')"
fi
# Say how many files were linked, for the same reason.
if [ "$ITER_LINKED" -gt 0 ]; then
  printf 'Iterations linked: %s file(s)\n' "$ITER_LINKED"
fi
