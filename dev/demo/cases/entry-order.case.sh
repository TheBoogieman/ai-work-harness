#!/usr/bin/env bash
# entry-order.case.sh — Session Log entries are placed by code, not judgement (#377). SOURCED by the
# runner; see dev/scripts/run-demo.sh for the contract.
#
# ticket-scribe used to write its entry by hand-editing the ticket, with a timestamp the parent read
# off the clock and passed in. In a 32-ticket sweep it put two entries mid-log instead of at the
# bottom. The validator reads only the LAST header in file order, so it reported "changed but no new
# Session Log entry" on a ticket that had just been given one, and the real cause took a manual
# diagnosis to find. Two guards close both halves:
#   [newest-entry-last] the validator NAMES a misplaced newest entry instead of misreporting it.
#   [append-helper]     the shipped helper appends by code: local-clock header, at the bottom,
#                       accepted by the validator; every refusal leaves the file byte-identical.

eo_validate() {
  set +e; EO_OUT=$(bash estate/_harness/scripts/check-ticket-log.sh 2>&1); EO_RC=$?; set -e
}

eo_hash() { { shasum -a 256 "$1" 2>/dev/null || sha256sum "$1" 2>/dev/null; } | cut -d' ' -f1; }

# [newest-entry-last] a newer entry inserted ABOVE an older one, exactly the hand-edit that went
#   wrong, must fail with a message that says so. The sleep before stamping makes the stamp's wall
#   clock strictly newer than the probe entry, which is the real estate's shape and what made the
#   pre-fix validator print the misleading "no new entry" instead.
#   REVERT-PROVABLE: drop the order check from check_recency and this reds on the message grep.
eo_newest_entry_last() {
  echo "--- entry-order: the newest Session Log entry must be the last one ---"
  EO1="estate/Tickets/202607U-PROJ-41"; local md="$EO1/202607U-PROJ-41.md" ts
  r09_make "$EO1"
  sleep 1
  bash estate/_harness/scripts/check-ticket-log.sh >/dev/null 2>&1 || true
  sleep 1
  ts=$(date +%Y%m%d%H%M%S)
  # Insert the new block before the LAST entry header, leaving that older entry at the bottom.
  awk -v ts="$ts" '
    { lines[NR] = $0; if ($0 ~ /^## [0-9]{14} - /) last = NR }
    END {
      for (i = 1; i <= NR; i++) {
        if (i == last) { print "## " ts " - misplaced newer entry"; print "- written above an older one"; print "" }
        print lines[i]
      }
    }' "$md" > "$md.tmp" && mv "$md.tmp" "$md"
  eo_validate
  [ "$EO_RC" -ne 0 ] \
    || { echo "BUG [newest-entry-last]: a misplaced newest entry passed validation:"; \
         printf '%s\n' "$EO_OUT"; exit 1; }
  printf '%s\n' "$EO_OUT" | grep -q "202607U-PROJ-41 newest Session Log entry ($ts) is not at the bottom" \
    || { echo "BUG [newest-entry-last]: the validator refused the ticket but never said the newest"; \
         echo "    entry is out of place, so the reader is sent looking for a missing entry:"; \
         printf '%s\n' "$EO_OUT" | grep 202607U-PROJ-41; exit 1; }
  echo "  ok [newest-entry-last] — a newest entry above an older one is refused by name, with its fix"
  rm -rf "$EO1"
}

# [append-helper] the helper is the scribe's only write path for an entry, so it must be right by
#   construction. The SUCCESS case runs first on purpose: before the helper exists every call fails
#   and every file stays unchanged, so refusal checks alone would pass on the pre-fix tree.
#   REVERT-PROVABLE: delete estate/_harness/scripts/append-session-entry.sh and this reds at once.
eo_append_helper() {
  echo "--- entry-order: append-session-entry.sh writes the entry by code ---"
  EO2="estate/Tickets/202607V-PROJ-42"; local md="$EO2/202607V-PROJ-42.md" helper before after out rc h
  helper="estate/_harness/scripts/append-session-entry.sh"
  r09_make "$EO2"
  sleep 1
  bash estate/_harness/scripts/check-ticket-log.sh >/dev/null 2>&1 || true
  sleep 1

  # 1. Success: local clock, strict header, at the very bottom, and the validator accepts it.
  before=$(date +%Y%m%d%H%M%S)
  set +e; out=$(printf -- '- helper probe body\n' | bash "$helper" "$md" "helper probe" 2>&1); rc=$?; set -e
  after=$(date +%Y%m%d%H%M%S)
  [ "$rc" -eq 0 ] \
    || { echo "BUG [append-helper]: the helper failed on a valid append (rc $rc):"; printf '%s\n' "$out"; exit 1; }
  h=$(grep -E '^## [0-9]{14} - ' "$md" | tail -1)
  [[ "$h" =~ ^##\ ([0-9]{14})\ -\ helper\ probe$ ]] \
    || { echo "BUG [append-helper]: the last header is not the helper's entry: '$h'"; exit 1; }
  [[ ! "${BASH_REMATCH[1]}" < "$before" && ! "${BASH_REMATCH[1]}" > "$after" ]] \
    || { echo "BUG [append-helper]: header time ${BASH_REMATCH[1]} is not the local clock" \
           "($before..$after)"; exit 1; }
  [ "$(tail -1 "$md")" = "- helper probe body" ] \
    || { echo "BUG [append-helper]: the body is not the end of the file"; tail -3 "$md"; exit 1; }
  printf '%s\n' "$out" | grep -qF "$h" \
    || { echo "BUG [append-helper]: the helper did not print the header it wrote:"; printf '%s\n' "$out"; exit 1; }
  eo_validate
  printf '%s\n' "$EO_OUT" | grep -q "OK: 202607V-PROJ-42 validated" \
    || { echo "BUG [append-helper]: the validator refused the helper's entry:"; \
         printf '%s\n' "$EO_OUT" | grep 202607V-PROJ-42; exit 1; }

  # 2. Every refusal is LOUD and leaves the ticket byte-identical.
  eo_refuses() {  # $1 label, $2 description, $3 body, $4 file
    local h0 rc0 o0
    h0=$(eo_hash "$4")
    set +e; o0=$(printf '%s' "$3" | bash "$helper" "$4" "$2" 2>&1); rc0=$?; set -e
    [ "$rc0" -ne 0 ] && printf '%s\n' "$o0" | grep -q '^REFUSED:' \
      || { echo "BUG [append-helper]: '$1' was not refused (rc $rc0):"; printf '%s\n' "$o0"; exit 1; }
    [ "$(eo_hash "$4")" = "$h0" ] \
      || { echo "BUG [append-helper]: '$1' was refused but the file changed"; exit 1; }
  }
  sleep 1
  eo_refuses "empty description" "" $'- body\n' "$md"
  eo_refuses "two-line description" $'first\nsecond' $'- body\n' "$md"
  eo_refuses "empty body" "no body" "" "$md"
  eo_refuses "body opening a heading" "smuggled heading" $'- fine\n## 20990101000000 - forged\n' "$md"
  # A newest entry dated in the future: the clock is behind it, so appending would misorder the log.
  printf '\n## 20991231235959 - future entry\n- dated ahead of the clock\n' >> "$md"
  eo_refuses "clock behind the newest entry" "behind" $'- body\n' "$md"
  # A file whose last section is not the Session Log: appending at the end would land elsewhere.
  printf '\n## Notes\n- a section after the log\n' >> "$md"
  eo_refuses "Session Log not the last section" "elsewhere" $'- body\n' "$md"
  echo "  ok [append-helper] — local-clock header appended at the bottom and validated; six bad" \
    "inputs refused with the file unchanged"
  rm -rf "$EO2"
}

# [entry-current-state] (#382) the entry and Current State are one step (CONSTITUTION §5, §6), and
#   the scribe used to do the second half with a hand edit it sometimes refused to make. The helper
#   now takes --now / --next / --blocked and rewrites those lines in the same command as the entry.
#   The SUCCESS case runs first: before the options exist every call is refused as a usage error and
#   the file stays unchanged, so refusal checks alone would pass on the pre-fix tree.
#   REVERT-PROVABLE: drop the option parsing from append-session-entry.sh and step 1 reds at once.
eo_current_state() {
  echo "--- entry-order: the helper rewrites Now / Next / Blocked with the entry ---"
  EO3="estate/Tickets/202607W-PROJ-43"; local md="$EO3/202607W-PROJ-43.md" helper out rc sec want h0
  helper="estate/_harness/scripts/append-session-entry.sh"
  r09_make "$EO3"
  sleep 1
  # eo_cs FILE — the body of the Current State section: its heading down to the next level-2 heading.
  eo_cs() { awk '/^## Current State/ { on = 1; next } on && /^## / { exit } on { print }' "$1"; }

  # 1. All three lines and the entry, in one command.
  set +e
  out=$(printf -- '- state probe body\n' | bash "$helper" --now "fix merged" --next "close the ticket" \
    --blocked "none" "$md" "state probe" 2>&1); rc=$?
  set -e
  [ "$rc" -eq 0 ] \
    || { echo "BUG [entry-current-state]: the helper failed with --now/--next/--blocked (rc $rc):"; \
         printf '%s\n' "$out"; exit 1; }
  sec=$(eo_cs "$md")
  for want in "- Now: fix merged" "- Next: close the ticket" "- Blocked: none"; do
    printf '%s\n' "$sec" | grep -qFx -- "$want" \
      || { echo "BUG [entry-current-state]: Current State lacks the line '$want':"; \
           printf '%s\n' "$sec"; exit 1; }
  done
  [ "$(printf '%s\n' "$sec" | grep -cE '^- (Now|Next|Blocked):')" -eq 3 ] \
    || { echo "BUG [entry-current-state]: an old Now/Next/Blocked line survived beside the new one:"; \
         printf '%s\n' "$sec"; exit 1; }
  [ "$(tail -1 "$md")" = "- state probe body" ] \
    || { echo "BUG [entry-current-state]: the entry is not the end of the file"; tail -3 "$md"; exit 1; }
  grep -q '^## Background' "$md" && grep -q 'r09 probe' "$md" \
    || { echo "BUG [entry-current-state]: a section or an older entry outside Current State was lost"; exit 1; }
  eo_validate
  printf '%s\n' "$EO_OUT" | grep -q "OK: 202607W-PROJ-43 validated" \
    || { echo "BUG [entry-current-state]: the validator refused the ticket after the rewrite:"; \
         printf '%s\n' "$EO_OUT" | grep 202607W-PROJ-43; exit 1; }

  # 2. One option alone changes one line and leaves the other two as they were.
  sleep 1
  set +e
  out=$(printf -- '- second body\n' | bash "$helper" --now "second state" "$md" "state probe two" 2>&1); rc=$?
  set -e
  sec=$(eo_cs "$md")
  [ "$rc" -eq 0 ] && printf '%s\n' "$sec" | grep -qFx -- "- Now: second state" \
    && printf '%s\n' "$sec" | grep -qFx -- "- Next: close the ticket" \
    && printf '%s\n' "$sec" | grep -qFx -- "- Blocked: none" \
    || { echo "BUG [entry-current-state]: --now alone did not change Now only (rc $rc):"; \
         printf '%s\n' "$out" "$sec"; exit 1; }

  # 3. A value that is not one plain line is refused, and the ticket is byte-identical.
  sleep 1
  h0=$(eo_hash "$md")
  set +e
  out=$(printf -- '- body\n' | bash "$helper" --now $'two\nlines' "$md" "bad state" 2>&1); rc=$?
  set -e
  [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^REFUSED:' && [ "$(eo_hash "$md")" = "$h0" ] \
    || { echo "BUG [entry-current-state]: a two-line --now was not refused with the file unchanged" \
           "(rc $rc):"; printf '%s\n' "$out"; exit 1; }
  echo "  ok [entry-current-state] — Now / Next / Blocked rewritten in the same command as the entry," \
    "one option changes one line, and a two-line value is refused with the file unchanged"
  rm -rf "$EO3"
}

case_entry_order() {
  eo_newest_entry_last
  eo_append_helper
  eo_current_state
}
