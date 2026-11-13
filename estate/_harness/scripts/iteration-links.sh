#!/usr/bin/env bash
# iteration-links.sh — ONE home for "which prompt, output and review files does a ticket hold, and
# does its ticket file link each of them" (#384). SOURCED, never run:
#   - append-session-entry.sh uses iter_sync to link every unlinked file under "## Iterations" in the
#     same write as the entry, so no agent has to remember to;
#   - check-ticket-log.sh uses iter_unlinked to fail a changed ticket that still holds an unlinked file;
#   - backfill-iterations.sh uses iter_unlinked to find the older tickets worth an entry.
# Three readers of one definition cannot drift apart on what "linked" means.
#
# WHAT COUNTS: a file named NN-<anything>.md (two digits) directly in the ticket's Agent-Prompts/ or
# Agent-Output/ folder. It is LINKED when the ticket file holds a Markdown link whose destination is
# that relative path, anywhere in the file: "(Agent-Prompts/01-x.md)", with a space written %20, or
# the angle form "(<Agent-Prompts/01 x.md>)".
#
# Pure bash and awk, no arrays keyed by name, so it runs on the bash 3.2 macOS ships.

# iter_files DIR — the ticket folder's ledger files as relative paths, one per line, ordered by
# file name so one iteration's prompt, output and review come out together (prompt first).
iter_files() {
  local dir="$1" sub f
  for sub in Agent-Prompts Agent-Output; do
    [ -d "$dir/$sub" ] || continue
    for f in "$dir/$sub"/[0-9][0-9]-*.md; do
      [ -f "$f" ] || continue          # an unmatched glob stays literal; skip it
      printf '%s\t%s/%s\n' "$(basename "$f")" "$sub" "$(basename "$f")"
    done
  done | LC_ALL=C sort -s -t "$(printf '\t')" -k1,1 | cut -f2
}

# iter_is_linked MD REL — does the ticket file link this relative path?
iter_is_linked() {
  local md="$1" rel="$2" enc
  enc=${rel// /%20}
  grep -qF -- "($enc)" "$md" || grep -qF -- "(<$rel>)" "$md"
}

# iter_unlinked MD DIR — the ledger files in DIR that MD does not link, one relative path per line.
# MD and DIR are separate arguments because the entry helper checks a working copy of the ticket.
iter_unlinked() {
  local md="$1" dir="$2" rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    iter_is_linked "$md" "$rel" || printf '%s\n' "$rel"
  done < <(iter_files "$dir")
  return 0
}

# iter_kind REL — the link label: prompt, output or review. A review is an Agent-Output file named
# NN-review.md (or NN-review-<more>.md), the name the reviewer contract writes.
iter_kind() {
  case "$1" in
    Agent-Prompts/*) printf 'prompt' ;;
    Agent-Output/[0-9][0-9]-review.md|Agent-Output/[0-9][0-9]-review-*.md) printf 'review' ;;
    *) printf 'output' ;;
  esac
}

# iter_goal DIR NN FALLBACK_NAME — the words a new Iterations line opens with. The prompt's own
# heading says it best ("# <ID> — Prompt NN: <goal> (<scope>)" gives "<goal> (<scope>)"); with no
# prompt, or a prompt with no heading, the file name's slug with its hyphens as spaces.
iter_goal() {
  local dir="$1" nn="$2" name="$3" p h=""
  for p in "$dir/Agent-Prompts/$nn"-*.md; do
    [ -f "$p" ] || continue
    h=$(grep -m1 -E '^# ' "$p" | sed -E 's/^# +//; s/[[:space:]]+$//' | tr -d '\r\t' || true)
    break
  done
  case "$h" in *"Prompt $nn: "*) h=${h#*"Prompt $nn: "} ;; esac
  if [ -z "$h" ]; then
    h=${name#[0-9][0-9]-}; h=${h%.md}; h=${h//-/ }
  fi
  printf '%s' "$h"
}

# iter_strip FILE — the file without its Iterations section and without blank or "---" lines, so two
# versions can be compared on everything the sync must not touch.
iter_strip() {
  awk '/^## Iterations[[:space:]]*$/ { on = 1; next } on && /^## / { on = 0 }
       !on && !/^(---)?[[:space:]]*$/ { print }' "$1"
}

# iter_sync MD DIR OUT — write to OUT the ticket file MD with every unlinked ledger file of DIR
# linked under "## Iterations", and set ITER_LINKED to how many files that was. With nothing to
# link, OUT is a byte-identical copy and ITER_LINKED is 0.
#   - An iteration that already has a line ("- NN ...") gets the new link added after that line's
#     last link, so whatever the scribe wrote on the line (goal, outcome) is kept.
#   - An iteration with no line gets "- NN — <goal> — [prompt](..) · [output](..) · [review](..)"
#     at the end of the section.
#   - A ticket with no Iterations section gets one, just above the Session Log.
# Nothing outside that section changes; the caller checks that with iter_strip.
iter_sync() {
  local md="$1" dir="$2" out="$3" want staged rel nn name kind enc cur="" links="" goal=""
  ITER_LINKED=0
  want=$(mktemp "$dir/.iteration-links.XXXXXX"); staged=$(mktemp "$dir/.iteration-links.XXXXXX")
  # One line per iteration that needs links: NN <tab> the links, joined <tab> the goal.
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    name=${rel##*/}; nn=${name%%-*}; kind=$(iter_kind "$rel"); enc=${rel// /%20}
    if [ "$nn" != "$cur" ]; then
      [ -z "$cur" ] || printf '%s\t%s\t%s\n' "$cur" "$links" "$goal" >> "$want"
      cur=$nn; links=""; goal=$(iter_goal "$dir" "$nn" "$name")
    fi
    links="${links:+$links · }[$kind]($enc)"
    ITER_LINKED=$((ITER_LINKED + 1))
  done < <(iter_unlinked "$md" "$dir")
  [ -z "$cur" ] || printf '%s\t%s\t%s\n' "$cur" "$links" "$goal" >> "$want"

  if [ "$ITER_LINKED" -eq 0 ]; then
    cat "$md" > "$out"; rm -f "$want" "$staged"; return 0
  fi

  # Step 1: make sure the section exists. Blank and "---" lines are held back so the new heading
  # lands above the rule that closes the ticket's body, not between it and the Session Log.
  if grep -qE '^## Iterations[[:space:]]*$' "$md"; then
    cat "$md" > "$staged"
  else
    awk '
      /^(---)?[[:space:]]*$/ { held[++h] = $0; next }
      /^## Session Log[[:space:]#]*$/ && !made { print ""; print "## Iterations"; made = 1 }
      { for (i = 1; i <= h; i++) print held[i]; h = 0; print }
      END { for (i = 1; i <= h; i++) print held[i] }
    ' "$md" > "$staged"
  fi

  # Step 2: add the links. The first file is the want list, the second the ticket.
  awk -F '\t' '
    # addlinks — put the new links after the last ledger link already on the line, or after the
    # whole line when it has none.
    function addlinks(line, l,   p, i, rest, c) {
      p = 0; rest = line
      while ((i = index(rest, "](Agent-")) > 0) { p += i; rest = substr(rest, i + 1) }
      if (p == 0) return line " — " l
      c = index(substr(line, p), ")")
      if (c == 0) return line " — " l
      c = p + c - 1
      return substr(line, 1, c) " · " l substr(line, c + 1)
    }
    # flush — print the buffered section: its lines, then a new line for each iteration that had
    # none, then the blank and "---" lines that closed it.
    function flush(   i, last) {
      last = n
      while (last > 0 && buf[last] ~ /^(---)?[[:space:]]*$/) last--
      for (i = 1; i <= last; i++) print buf[i]
      for (i = 1; i <= k; i++) if (!(nn[i] in done)) print "- " nn[i] " — " goal[nn[i]] " — " links[nn[i]]
      for (i = last + 1; i <= n; i++) print buf[i]
      n = 0
    }
    FNR == NR { nn[++k] = $1; links[$1] = $2; goal[$1] = $3; next }
    /^## Iterations[[:space:]]*$/ && !seen { print; on = 1; seen = 1; next }
    on && /^## / { flush(); on = 0 }
    on {
      if ($0 ~ /^- [0-9][0-9]( |$)/) {
        id = substr($0, 3, 2)
        if ((id in links) && !(id in done)) { $0 = addlinks($0, links[id]); done[id] = 1 }
      }
      buf[++n] = $0; next
    }
    { print }
    END { if (on) flush() }
  ' "$want" "$staged" > "$out"
  rm -f "$want" "$staged"
  return 0
}
