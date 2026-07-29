#!/usr/bin/env bash
# session-clock.case.sh — the session-log header clock is LOCAL machine time. SOURCED by the
# runner; see dev/scripts/run-demo.sh for the contract.
#
# The validator reads a 14-digit header via epoch_from_ts14 (date -d/-j — LOCAL tz) and compares it
# to the watermark stamp_wall (date +%s — absolute epoch). Those two frames agree ONLY when the
# header is written in LOCAL time; a UTC header on a non-UTC machine is parsed hours behind and can
# land below the watermark, tripping a false "no new Session Log entry" FAIL that red-blocks honest
# work. That is the R-10 gap the now-named convention closes. This family pins BOTH directions: a
# local-now header is accepted, and a UTC header on a simulated non-UTC machine is (correctly)
# refused — proving the comparison IS clock-sensitive, so the convention MUST name the clock. It
# runs before the tour's abort-prone break-and-restore call, like the family above it. TZ is forced
# to a fixed non-UTC zone here and restored afterwards so it never leaks into the rest of the run.

# r10_validate — run the validator once for the two cases below, capturing BOTH halves of its
# answer: the MESSAGE into R10_OUT (the greps at each site read it) and the EXIT CODE into R10_RC,
# which is asserted HERE. $1 is what the calling site requires of that code — "clean" (0: an
# accepted header must not block) or "blocked" (non-zero: a refusal must actually red-block) — and
# $2 is the guard label for the BUG line. The exit-code half lives in ONE place so the two sites
# cannot drift apart on it; the message assertions stay at their sites because each names a
# different outcome. Neither half subsumes the other — the message says WHICH failure fired, the
# exit code says that it BLOCKED, and a validator that printed the right words while exiting the
# wrong way is exactly what this pairing catches (#161). set +e brackets the call so an expected
# non-zero rc cannot abort the demo before the assertions read it.
r10_validate() {
  set +e; R10_OUT=$(bash estate/_harness/scripts/check-ticket-log.sh 2>&1); R10_RC=$?; set -e
  if [ "$1" = clean ] && [ "$R10_RC" -ne 0 ]; then
    echo "BUG [$2]: the validator exited $R10_RC on a header it must ACCEPT — honest work blocked:"
    printf '%s\n' "$R10_OUT"; exit 1
  fi
  if [ "$1" = blocked ] && [ "$R10_RC" -eq 0 ]; then
    echo "BUG [$2]: the validator exited 0 on a header it must REFUSE — the refusal did not block:"
    printf '%s\n' "$R10_OUT"; exit 1
  fi
}

# sc_fixture — a conforming ticket under a pinned UTC+10 zone (no DST, so local differs from UTC by
# a clear 10h), validated once so stamp_wall (date +%s) is written for it.
sc_fixture() {
  echo "--- session-clock: session-log header clock is LOCAL machine time ---"
  R10="estate/Tickets/202607R-PROJ-10"
  R10_TZ_SAVE="${TZ-__unset__}"
  export TZ='Etc/GMT-10'   # fixed UTC+10, no DST — makes local differ from UTC by a clear 10h
  r09_make "$R10"
  bash estate/_harness/scripts/check-ticket-log.sh >/dev/null 2>&1 || true
}

# [local-clock-ok] a LOCAL-now header (what the named convention requires) is newer than the
#   watermark and is accepted — header and watermark share the absolute frame (a local-time header
#   converts to the same epoch date +%s records: epoch_from_ts14(local) == date +%s). A validator
#   that parsed the header as UTC would misread this and the OK below would vanish.
#
# BOTH halves of the validator's answer are asserted at this site: r10_validate checks the EXIT
# CODE — 0, because an accepted header must not block honest work — and the greps below check the
# MESSAGE, which names the outcome. Neither subsumes the other, so a validator that printed the
# right words while exiting the wrong way no longer passes here (#161).
sc_local_clock_ok() {
  sleep 1
  printf '\n## %s - local-clock session\n- work recorded in local machine time\n' \
    "$(date +%Y%m%d%H%M%S)" >> "$R10/202607R-PROJ-10.md"
  r10_validate clean local-clock-ok      # exit code asserted here; message asserted below
  printf '%s\n' "$R10_OUT" | grep -q "202607R-PROJ-10 changed but no new Session Log entry" \
    && { echo "BUG [local-clock-ok]: a LOCAL-time header was misread as stale (false FAIL) —" \
           "clock frames disagree:"; printf '%s\n' "$R10_OUT"; exit 1; }
  printf '%s\n' "$R10_OUT" | grep -q "OK: 202607R-PROJ-10 validated" \
    || { echo "BUG [local-clock-ok]: local-time header not accepted:"; \
         printf '%s\n' "$R10_OUT"; exit 1; }
  echo "  ok [local-clock-ok] — local-time session header accepted (header and watermark share" \
    "the frame)"
}

# [utc-clock-stale] a UTC header on this simulated non-UTC machine (exactly what a UTC-writing
#   scribe would emit) is parsed 10h behind by the LOCAL-tz validator, lands below the watermark,
#   and is correctly refused. This is the pre-fix bug reproduced: it proves the comparison is
#   clock-sensitive and that leaving the clock unnamed lets a scribe red-block honest work. Naming
#   the clock as local in the convention and the ticket-scribe agent is what stops a scribe writing
#   this header.
#
# As above, both halves: r10_validate requires a NON-ZERO exit code (this refusal must actually
# BLOCK) and the grep below requires the stale-record message (that the RIGHT refusal fired). A
# validator that printed this refusal and exited 0 satisfies the message check on its own — that is
# precisely the failure this pairing closes (#161). The expected non-zero rc cannot abort the demo:
# the helper brackets the call in set +e.
sc_utc_clock_stale() {
  sleep 1
  printf '\n## %s - utc-clock session (wrong clock)\n- work stamped in UTC by mistake\n' \
    "$(date -u +%Y%m%d%H%M%S)" >> "$R10/202607R-PROJ-10.md"
  r10_validate blocked utc-clock-stale   # exit code asserted here; message asserted below
  printf '%s\n' "$R10_OUT" | grep -q "202607R-PROJ-10 changed but no new Session Log entry" \
    || { echo "BUG [utc-clock-stale]: a UTC header on a non-UTC machine was NOT caught — the" \
           "guard is blind to the clock frame:"; printf '%s\n' "$R10_OUT"; exit 1; }
  echo "  ok [utc-clock-stale] — UTC-on-non-UTC header refused as stale (clock frame matters;" \
    "convention must name it)"
}

case_session_clock() {
  sc_fixture
  sc_local_clock_ok
  sc_utc_clock_stale
  # Restore TZ (whatever it was, including unset) and tear down this family's scratch ticket.
  if [ "$R10_TZ_SAVE" = "__unset__" ]; then unset TZ; else export TZ="$R10_TZ_SAVE"; fi
  rm -rf "$R10"
}
