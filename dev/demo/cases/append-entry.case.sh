#!/usr/bin/env bash
# append-entry.case.sh — #80 [append-entry]: the one-home mechanical record appender. SOURCED by
# the runner; see dev/scripts/run_demo.sh for the contract.
#
# append_entry.sh is a DUMB creator: text+ticket+section -> a stamped, ATOMIC append under an
# EXISTING header. Its pre-flight validates the LANDING ZONE only (file/header present+unique) and
# DECLINES otherwise; its post-flight composes with check_ticket_log.sh (write-then-validate), so a
# red NEVER rolls back a good write. These four cases are revert-provable BOTH directions: break
# the write and (1)/(3) red; stop declining on a duplicate header and (2) reds byte-changed;
# name-resolve a slash-bearing path (drop the #82 branch) and (4) reds on the doubled Tickets/
# echo.

# a80_make builds a conforming, validator-ready ticket from the template plus a seed session entry
# (so the appended-to file already has a Session Log the watermark check can read).
a80_make() {
  local dir="$1" base; base=$(basename "$dir")
  rm -rf "$dir"; cp -r estate/Tickets/999912Z-PROJ-99999 "$dir"
  mv "$dir/999912Z-PROJ-99999.md" "$dir/$base.md"
  printf '\n## %s - a80 seed\n- seed session\n' "$(date +%Y%m%d%H%M%S)" >> "$dir/$base.md"
}

# 1) HEALTHY -> the stamped entry lands UNDER the requested header AND the post-flight validator
#    runs and its verdict passes through (this ticket validates OK). The awk asserts the probe text
#    appears at/after the '## Session Log' header, i.e. inside the right section.
ae_healthy() {
  local A80H A80_OUT
  echo "--- #80 append_entry: healthy lands+validator passes; dup-header declines byte-unchanged;" \
    "red passes through ---"
  A80H="estate/Tickets/202607T-PROJ-8001"; a80_make "$A80H"
  set +e; A80_OUT=$(bash estate/_harness/scripts/append_entry.sh 202607T-PROJ-8001 "Session Log" \
    "a80 healthy probe #80"); set -e
  awk '/^## Session Log/{f=1} f&&/a80 healthy probe #80/{ok=1} END{exit !ok}' \
    "$A80H/202607T-PROJ-8001.md" \
    || { echo "BUG [append-entry]: healthy append did NOT land the entry under the" \
           "'## Session Log' header"; exit 1; }
  printf '%s\n' "$A80_OUT" | grep -q "OK: 202607T-PROJ-8001 validated." \
    || { echo "BUG [append-entry]: post-flight validator did not run / verdict not passed through" \
           "on the healthy ticket:"; printf '%s\n' "$A80_OUT"; exit 1; }
  rm -rf "$A80H"
  echo "  ok [append-entry] — healthy: entry lands under the right header and the" \
    "validator verdict passes through"
}

# 2) DUPLICATED HEADER -> the appender DECLINES with a NAMED fix and the file is BYTE-UNCHANGED
#    (pre-flight refuses an ambiguous landing zone; nothing is written). cmp is a byte comparison,
#    not an eyeball. The '.before' snapshot lives OUTSIDE AI-Knowledge/ so it cannot mint an orphan.
ae_duplicate_header() {
  local A80D A80_OUT A80_RC
  A80D="estate/Tickets/202607T-PROJ-8002"; a80_make "$A80D"
  # two identical '## Notes' headers
  printf '\n## Notes\nalpha\n## Notes\nbeta\n' >> "$A80D/202607T-PROJ-8002.md"
  cp "$A80D/202607T-PROJ-8002.md" "$A80D/before.snap"          # exact byte snapshot pre-append
  set +e; A80_OUT=$(bash estate/_harness/scripts/append_entry.sh 202607T-PROJ-8002 "Notes" \
    "must not land"); A80_RC=$?; set -e
  [ "$A80_RC" -ne 0 ] \
    || { echo "BUG [append-entry]: duplicated header did NOT cause a decline (rc=0):"; \
         printf '%s\n' "$A80_OUT"; exit 1; }
  printf '%s\n' "$A80_OUT" | grep -q "Fix:" \
    || { echo "BUG [append-entry]: the decline did not NAME a fix:"; \
         printf '%s\n' "$A80_OUT"; exit 1; }
  cmp -s "$A80D/202607T-PROJ-8002.md" "$A80D/before.snap" \
    || { echo "BUG [append-entry]: a declined append still MUTATED the file (not byte-unchanged)"; \
         exit 1; }
  rm -rf "$A80D"
  echo "  ok [append-entry] — duplicated header: declines with a named fix, file byte-unchanged"
}

# 3) PRE-EXISTING UNRELATED RED -> the append STILL lands and the red passes through:
#    write-then-validate, a red must not roll back a good write. The red is an orphan AI-Knowledge
#    file (unrelated to the entry).
ae_red_passthrough() {
  local A80R A80_OUT A80_RC
  A80R="estate/Tickets/202607T-PROJ-8003"; a80_make "$A80R"
  # not listed in _index.md -> validator FAILs, unrelated to the append
  echo "orphan body" > "$A80R/AI-Knowledge/orphan.md"
  set +e; A80_OUT=$(bash estate/_harness/scripts/append_entry.sh 202607T-PROJ-8003 "Session Log" \
    "a80 red-passthrough probe #80"); A80_RC=$?; set -e
  grep -q "a80 red-passthrough probe #80" "$A80R/202607T-PROJ-8003.md" \
    || { echo "BUG [append-entry]: a pre-existing red ROLLED BACK the write — the entry is gone"; \
         exit 1; }
  printf '%s\n' "$A80_OUT" | grep -q "orphan file AI-Knowledge/orphan.md not in _index.md" \
    || { echo "BUG [append-entry]: the pre-existing unrelated red did NOT pass through the" \
           "appender:"; printf '%s\n' "$A80_OUT"; exit 1; }
  [ "$A80_RC" -ne 0 ] \
    || { echo "BUG [append-entry]: appender masked the validator's red (rc=0 despite a FAIL" \
           "passing through)"; exit 1; }
  rm -rf "$A80R"
  echo "  ok [append-entry] — pre-existing red: append lands, red passes through, write not" \
    "rolled back"
}

# 4) SLASH-BEARING NON-EXISTENT PATH -> declines naming the LITERAL path, never a DOUBLED
#    Tickets/ construction (#82 truth-up). Pre-fix, a slash-bearing argument fell to
#    Tickets/<arg>/<arg>.md name-resolution and echoed a doubled 'Tickets/.../Tickets/...' path
#    in the decline. THE ARGUMENT AND THE NEEDLE ARE ESTATE-RELATIVE ON PURPOSE: the argument
#    is a ticket name a caller types and the needle is the doubling the fix removed, so neither
#    carries the estate/ tree prefix this repository stores the estate under. The decline
#    was always correct (it declines, names a fix); this only asserts the ECHO is clean.
#    Revert-proof: drop the `|| "$ticket" == */*` branch in append_entry.sh and (4) reds on the
#    doubled path.
ae_slash_path() {
  local A80_OUT A80_RC
  set +e; A80_OUT=$(bash estate/_harness/scripts/append_entry.sh "Tickets/does-not-exist-8004" \
    "Session Log" "must not land"); A80_RC=$?; set -e
  [ "$A80_RC" -ne 0 ] \
    || { echo "BUG [append-entry]: a non-existent slash-bearing path did NOT decline (rc=0):"; \
         printf '%s\n' "$A80_OUT"; exit 1; }
  printf '%s\n' "$A80_OUT" | grep -q "Fix:" \
    || { echo "BUG [append-entry]: the slash-path decline did not NAME a fix:"; \
         printf '%s\n' "$A80_OUT"; exit 1; }
  printf '%s\n' "$A80_OUT" | grep -q "Tickets/Tickets" \
    && { echo "BUG [append-entry]: the decline echoed a DOUBLED Tickets/ path (a slash-bearing" \
           "path was name-resolved):"; printf '%s\n' "$A80_OUT"; exit 1; }
  printf '%s\n' "$A80_OUT" | grep -q "Tickets/does-not-exist-8004" \
    || { echo "BUG [append-entry]: the decline did not name the LITERAL path the caller gave:"; \
         printf '%s\n' "$A80_OUT"; exit 1; }
  echo "  ok [append-entry] — slash-bearing non-existent path: declines naming the literal path," \
    "no doubled Tickets/"
}

case_append_entry() {
  ae_healthy
  ae_duplicate_header
  ae_red_passthrough
  ae_slash_path
}
