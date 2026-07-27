#!/usr/bin/env bash
# append_entry.sh — one-home mechanical appender for ticket record files (#80).
# Agents and humans must NEVER hand-edit a ticket .md to add a record — wrong section,
# broken formatting, half-written non-atomic saves. They call THIS instead, exactly as
# check-scribe calls append_notebook_cell.py for notebooks. It is a DUMB creator: it
# stamps the text and drops it under an EXISTING header, atomically. It never validates
# content, never invents structure, never rewrites an existing line.
#
# Usage: append_entry.sh <ticket> <section> <text>
#   <ticket>   a ticket folder name (resolved to Tickets/<name>/<name>.md) OR a direct
#              path to the record .md file.
#   <section>  the EXISTING header to append under, with or without leading '#'
#              (e.g. "Session Log" or "## Session Log").
#   <text>     the entry body (may span multiple lines).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Exactly three args; anything else is a usage error, not a silent no-op (same contract
# as append_notebook_cell.py — a miscall must be loud).
if [[ $# -ne 3 ]]; then
  echo "FAIL: usage: append_entry.sh <ticket|record.md> <section> <text>"; exit 2
fi
ticket="$1"; section_arg="$2"; text="$3"

# Resolve the target record file. A ticket-folder NAME never contains a slash, so any slash-bearing
# argument is a PATH and is used as-is — even a non-existent one, so the decline below names the
# LITERAL path the caller gave, never a doubled Tickets/<path>/Tickets/<path> from name-resolving a
# path by mistake (#82 truth-up). A bare, slash-free name resolves to its record under Tickets/.
if [[ -f "$ticket" || "$ticket" == */* ]]; then
  md="$ticket"
else
  md="$WORK_ROOT/Tickets/$ticket/$ticket.md"
fi

# Normalise the requested section to a bare title: strip any leading '#' markers and the
# surrounding whitespace, so "## Session Log" and "Session Log" name the same header.
title="$section_arg"
title="${title#"${title%%[^#]*}"}"        # drop leading '#' run
title="${title#"${title%%[![:space:]]*}"}" # drop leading whitespace
title="${title%"${title##*[![:space:]]}"}" # drop trailing whitespace

# ---- PRE-FLIGHT: validate the LANDING ZONE ONLY. On any failure we DECLINE and name the
# fix; we never touch the file. (Content correctness is check_ticket_log.sh's job, invoked
# as the post-flight below — this stage only proves the entry has somewhere valid to land.)

# 1) The record file must exist — the appender adds to a record, it never creates one.
if [[ ! -f "$md" ]]; then
  echo "FAIL: no record file at '$md'. Fix: create the ticket first (ticket-init), or pass an existing record path."; exit 1
fi

# 2+3) The header must be PRESENT and UNIQUE. We match a markdown header line at any level
# whose title (markers + surrounding space stripped) equals the requested title exactly.
# Count is done with awk so a title bearing regex metacharacters is compared literally.
hcount=$(awk -v t="$title" '
  function htitle(l){ sub(/^#+[ \t]+/,"",l); sub(/[ \t]+$/,"",l); return l }
  /^#+[ \t]/ && htitle($0)==t { n++ }
  END { print n+0 }
' "$md")
if [[ "$hcount" -eq 0 ]]; then
  echo "FAIL: '$md' has no '## $title' header. Fix: add the section first, or pass a section that already exists."; exit 1
fi
if [[ "$hcount" -gt 1 ]]; then
  echo "FAIL: '$md' has $hcount '## $title' headers — ambiguous landing zone. Fix: de-duplicate the header so exactly one remains."; exit 1
fi

# ---- ATOMIC APPEND. Find the unique header's line number, then the next header line after
# it (any level) — the entry lands just before that boundary, i.e. at the end of the header's
# own block, so it can never fall into a sibling section. With no following header the entry
# lands at end-of-file.
hline=$(awk -v t="$title" '
  function htitle(l){ sub(/^#+[ \t]+/,"",l); sub(/[ \t]+$/,"",l); return l }
  /^#+[ \t]/ && htitle($0)==t { print NR; exit }
' "$md")
nline=$(awk -v h="$hline" 'NR>h && /^#+[ \t]/ { print NR; exit }' "$md")
if [[ -z "$nline" ]]; then
  nline=$(( $(wc -l < "$md") + 1 ))   # no next header: insertion point is one past the last line
fi

# Stamp the entry with a UTC timestamp on its own '### ' heading. The stamp is deliberately
# ISO-8601 (hyphenated), NOT the 14-digit session-log grammar, so a generic appended record
# never masquerades as a ticket-scribe session entry.
stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Assemble the new file in a temp file in the SAME directory, then move it into place — a
# half-written record can never be observed (write-to-temp-then-rename is the atomic contract).
tmp=$(mktemp "$(dirname "$md")/.append_entry.XXXXXX")
{
  head -n "$((nline-1))" "$md"        # everything up to the insertion boundary
  printf '\n### %s\n%s\n' "$stamp" "$text"   # the stamped entry (blank line separates it from prior content)
  tail -n "+$nline" "$md"             # the rest of the file, unchanged
} > "$tmp"
mv "$tmp" "$md"
echo "OK: appended a stamped entry under '## $title' in $md"

# ---- POST-FLIGHT: compose, don't duplicate. Hand off to the shared validator and let its
# verdict — stdout AND exit code — become ours, untouched. write-then-validate: the append
# above already happened, so a RED here NEVER un-writes it. A fixed record is a human act; a
# machine that silently un-writes a record is worse than one that reports the problem.
exec bash "$SCRIPT_DIR/check_ticket_log.sh"
