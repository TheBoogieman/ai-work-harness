#!/usr/bin/env bash
# ticket-recognition.case.sh — surface (never enforce) unrecognised ticket folders, plus the
# pending fourth state and its completion path. SOURCED by the runner; see run_demo.sh.
#
# This family runs BEFORE the tour's break-and-restore demonstration ON PURPOSE: it is the first
# thing after deploy_agents, which makes no status call, so a lane where a plain `harness-status`
# aborts under set -e (e.g. the Git-Bash issue #8) still reaches and witnesses every case here
# before that abort-prone call. The status rc assertions are baseline-relative (see BASELINE_RC):
# each fixture must add no NEW failure versus the untouched estate, so a pre-existing estate
# failure on such a lane is tested-around, not mis-attributed to a fixture here. Every folder
# below is built from the shipped template (r09_make, in the runner) and torn down at the end.
#
# The fixture paths and BASELINE_RC are file-scope: they are built by one function, read by
# several, and removed by the teardown.

# tr_baseline — status's rc on the UNTOUCHED estate, captured before any fixture exists. Wrapped
# in set +e so this call itself never aborts the demo — the whole point is to witness these even
# on a lane where the later plain status call would die. The run's OUTPUT is not part of any
# assertion — only its exit code is — so it goes to /dev/null rather than into a variable nothing
# reads. The call itself must stay: it is what produces the rc.
tr_baseline() {
  echo "--- ticket-recognition: unrecognised ticket folders are surfaced, never enforced ---"
  set +e; bash estate/_harness/scripts/harness-status.sh >/dev/null 2>&1; BASELINE_RC=$?; set -e
  R09_SPACE="estate/Tickets/My Random Ticket 42" # real ticket record under a space-bearing name
  R09_CONF="estate/Tickets/202607A-PROJ-7"              # conforming, low ticket number
  R09_LONG="estate/Tickets/202607AB-LONGBOARD-1000000"  # conforming, multi-letter seq + long number
  # malformed: 5-digit date — must NOT be recognised
  R09_BAD="estate/Tickets/20260A-PROJ-42"
  # non-conforming placeholder name init would coin
  R09_PEND="estate/Tickets/pending-20260719120000"
  # a user's own non-conforming folder (contrast)
  R09_HAND="estate/Tickets/handmade-notes"
  R09_KCONF="estate/Tickets/202607K-PROJ-500"           # a pending ticket after a conforming rename
  # a pending ticket renamed to conforming garbage
  R09_MGARB="estate/Tickets/202607M-XYZ-1"
}

# tr_status — run harness-status once, capturing BOTH halves of its answer into R09_OUT / R09_RC.
# set +e brackets the call so an expected non-zero rc becomes data rather than an abort.
tr_status() {
  set +e; R09_OUT=$(bash estate/_harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
}

# tr_validate — the same, for the validator.
tr_validate() {
  set +e; R09_OUT=$(bash estate/_harness/scripts/check_ticket_log.sh 2>&1); R09_RC=$?; set -e
}

# [misnamed-warn] space-named ticket-bearing folder → harness-status WARNs it, exit stays 0.
#          Pins Model 1: a real-but-misnamed ticket is surfaced so nobody assumes it's
#          validated when it's silently skipped — and surfacing NEVER fails the estate.
tr_misnamed_warn() {
  r09_make "$R09_SPACE"
  tr_status
  printf '%s\n' "$R09_OUT" | grep -q "WARN: Tickets/My Random Ticket 42" \
    || { echo "BUG [misnamed-warn]: space-named ticket-bearing folder not surfaced as WARN:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -le "$BASELINE_RC" ] \
    || { echo "BUG [misnamed-warn]: surfacing a misnamed folder added a NEW failure" \
           "(rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
  echo "  ok [misnamed-warn] — space-named ticket-bearing folder surfaced (WARN), no new failure" \
    "vs baseline"
}

# [opt-out-silent] same folder + a tracked .not-a-ticket marker → silent (no WARN), exit 0.
#          Pins the recorded, versioned opt-out.
tr_opt_out_silent() {
  touch "$R09_SPACE/.not-a-ticket"
  tr_status
  printf '%s\n' "$R09_OUT" | grep -q "WARN: Tickets/My Random Ticket 42" \
    && { echo "BUG [opt-out-silent]: silenced folder still WARNed:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -le "$BASELINE_RC" ] \
    || { echo "BUG [opt-out-silent]: silencing added a NEW failure" \
           "(rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
  echo "  ok [opt-out-silent] — .not-a-ticket marker silences the WARN, no new failure vs baseline"
}

# [low-number-ok] conforming low-number ticket → validated; no naming FAIL, and no whitespace
#          breakage from the space-named sibling created above.
tr_low_number_ok() {
  r09_make "$R09_CONF"
  tr_validate
  printf '%s\n' "$R09_OUT" | grep -q "OK: 202607A-PROJ-7 validated" \
    || { echo "BUG [low-number-ok]: conforming low-number ticket not validated:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -eq 0 ] \
    || { echo "BUG [low-number-ok]: validator exited non-zero (rc=$R09_RC):"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  echo "  ok [low-number-ok] — 202607A-PROJ-7 validated (low number accepted, space sibling" \
    "didn't break it)"
}

# [wide-fields-ok] multi-letter sequence + long number → validated. Pins the EXPANDED pattern
#          (a month past Z, a board key longer than PROJ, a number wider than 5 digits).
tr_wide_fields_ok() {
  r09_make "$R09_LONG"
  tr_validate
  printf '%s\n' "$R09_OUT" | grep -q "OK: 202607AB-LONGBOARD-1000000 validated" \
    || { echo "BUG [wide-fields-ok]: expanded-pattern ticket not validated:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -eq 0 ] \
    || { echo "BUG [wide-fields-ok]: validator exited non-zero (rc=$R09_RC):"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  echo "  ok [wide-fields-ok] — 202607AB-LONGBOARD-1000000 validated (multi-letter seq + long" \
    "number)"
}

# [malformed-ignored] malformed name (5-digit date) → NOT recognised, so NEVER validated. Proves
#          the expansion still has a shape — it widened the fields, it didn't go formless.
tr_malformed_ignored() {
  r09_make "$R09_BAD"
  tr_validate
  printf '%s\n' "$R09_OUT" | grep -q "20260A-PROJ-42 validated" \
    && { echo "BUG [malformed-ignored]: malformed 5-digit-date name was validated — the grammar" \
           "went formless:"; printf '%s\n' "$R09_OUT"; exit 1; }
  echo "  ok [malformed-ignored] — 20260A-PROJ-42 not recognised, correctly left unvalidated"
}

# [space-named-pack] the pack builder handles a space-named ticket at exit 0 (zip needed). Writes
# to its OWN throwaway pack dir (like [pack-without-zip]), NOT the run's shared PACK_OUT_DIR: if
# this pack and the tour's stage-6 pack both landed in the shared dir across a minute boundary
# (make_context_pack's STAMP is minute-granular), two harness-pack-*.zip would accumulate there
# and stage 6's unzip glob would match both and fail — the timing flake CI caught on the slower
# macOS runner. Own dir = timing can't matter.
tr_space_named_pack() {
  local R09D_OUT
  R09D_OUT=$(mktemp -d)
  set +e
  PACK_OUT_DIR="$R09D_OUT" bash estate/_harness/scripts/make_context_pack.sh \
    --ticket "My Random Ticket 42" >/dev/null; R09_RC=$?
  set -e
  rm -rf "$R09D_OUT"
  [ "$R09_RC" -eq 0 ] \
    || { echo "BUG [space-named-pack]: context pack failed on a space-named ticket (rc=$R09_RC)"; \
         exit 1; }
  echo "  ok [space-named-pack] — make_context_pack.sh handled a space-named ticket, exit 0"
}

# --- pending-ticket fourth state (graceful cancellation of custom names) — issue #25 -------------
# A ticket ticket-init couldn't name gets a deliberately non-conforming placeholder name PLUS a
# .ticket-pending marker: a REAL ticket that must NAG until renamed, and cannot be silenced. These
# cases pin that the pending WARN is a DISTINCT message from the silenceable hand-made WARN and is
# non-silenceable. A broken build flips them: checking .not-a-ticket before .ticket-pending reddens
# [pending-wins]; reusing the hand-made-WARN text reddens [handmade-warn].

# [pending-warn] pending folder (non-conforming name + ticket .md + .ticket-pending) → the
#          PENDING "rename to complete" WARN, exit 0. Pins that the fourth state exists.
tr_pending_warn() {
  r09_make "$R09_PEND"; touch "$R09_PEND/.ticket-pending"
  tr_status
  printf '%s\n' "$R09_OUT" | grep -q "Tickets/pending-20260719120000 is a pending ticket" \
    || { echo "BUG [pending-warn]: pending folder did not get the PENDING WARN:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -le "$BASELINE_RC" ] \
    || { echo "BUG [pending-warn]: pending WARN added a NEW failure" \
           "(rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
  echo "  ok [pending-warn] — pending folder surfaced with the non-silenceable PENDING WARN, no" \
    "new failure vs baseline"
}

# [pending-wins] pending folder that ALSO carries a .not-a-ticket marker → STILL the PENDING WARN
#          (pending is checked first). Pins the non-silenceable semantics: you cannot
#          silence a ticket init flagged as unfinished.
tr_pending_wins() {
  touch "$R09_PEND/.not-a-ticket"
  tr_status
  printf '%s\n' "$R09_OUT" | grep -q "Tickets/pending-20260719120000 is a pending ticket" \
    || { echo "BUG [pending-wins]: .not-a-ticket silenced a pending ticket — precedence is" \
           "wrong:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -le "$BASELINE_RC" ] \
    || { echo "BUG [pending-wins]: added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; \
         exit 1; }
  echo "  ok [pending-wins] — .not-a-ticket did NOT silence the pending ticket (pending wins)"
}

# [handmade-warn] contrast: a hand-made ticket-bearing folder with NO markers → the silenceable
#          hand-made WARN, and NOT the pending WARN. Proves the two WARNs are distinct types.
tr_handmade_warn() {
  r09_make "$R09_HAND"
  tr_status
  printf '%s\n' "$R09_OUT" | grep -q "Tickets/handmade-notes holds a .md record but doesn't match" \
    || { echo "BUG [handmade-warn]: hand-made folder lost its silenceable hand-made WARN:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  printf '%s\n' "$R09_OUT" | grep -q "Tickets/handmade-notes is a pending ticket" \
    && { echo "BUG [handmade-warn]: hand-made folder wrongly got the PENDING WARN:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  echo "  ok [handmade-warn] — hand-made folder kept the silenceable hand-made WARN (distinct" \
    "from pending)"
}

# [handmade-silent] hand-made folder + .not-a-ticket → silent (unchanged behaviour). Proves the
#          silenceable WARN's .not-a-ticket escape still works for genuinely user-owned folders.
tr_handmade_silent() {
  touch "$R09_HAND/.not-a-ticket"
  tr_status
  printf '%s\n' "$R09_OUT" | grep -q "Tickets/handmade-notes" \
    && { echo "BUG [handmade-silent]: silenced hand-made folder still surfaced:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -le "$BASELINE_RC" ] \
    || { echo "BUG [handmade-silent]: added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; \
         exit 1; }
  echo "  ok [handmade-silent] — hand-made folder silenced by .not-a-ticket, no new failure" \
    "vs baseline"
}

# --- R-14: the pending COMPLETION path — the marker, not the name, is the lifecycle token --------
# The nag must follow the .ticket-pending MARKER, not the folder name. A conforming rename alone
# must NOT complete a pending ticket (that would let a real ticket go silently misfiled under a
# made-up name); only removing the marker — a recorded human act — completes it. A name-first
# implementation reddens [completion-warn] (marker stranded → wrongly silent) and
# [nag-follows-marker] (conforming-garbage rename → wrongly silent, the evasion).

# [completion-warn] pending folder whose name now CONFORMS but marker remains → the "remove the
#          marker to finish" completion WARN, no new failure. Pins the mandatory exit path.
tr_completion_warn() {
  r09_make "$R09_KCONF"; touch "$R09_KCONF/.ticket-pending"
  tr_status
  printf '%s\n' "$R09_OUT" | grep -q "Tickets/202607K-PROJ-500 looks complete" \
    || { echo "BUG [completion-warn]: conforming-named pending folder did not get the completion" \
           "WARN:"; printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -le "$BASELINE_RC" ] \
    || { echo "BUG [completion-warn]: completion WARN added a NEW failure" \
           "(rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
  echo "  ok [completion-warn] — conforming name + lingering marker → 'remove the marker'" \
    "completion WARN"
}

# [completion-done] that same folder after `rm .ticket-pending` → the validator validates it AND
#          status goes silent for it. Pins that removing the marker actually COMPLETES the ticket.
tr_completion_done() {
  rm "$R09_KCONF/.ticket-pending"
  tr_validate
  printf '%s\n' "$R09_OUT" | grep -q "OK: 202607K-PROJ-500 validated" \
    || { echo "BUG [completion-done]: completed ticket did not validate after marker removal:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  tr_status
  printf '%s\n' "$R09_OUT" | grep -q "Tickets/202607K-PROJ-500" \
    && { echo "BUG [completion-done]: completed ticket still surfaced a WARN after marker" \
           "removal:"; \
         printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -le "$BASELINE_RC" ] \
    || { echo "BUG [completion-done]: added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; \
         exit 1; }
  echo "  ok [completion-done] — marker removed → ticket validated and status silent (completion" \
    "completes)"
}

# [nag-follows-marker] pending folder renamed to conforming GARBAGE, marker still present → STILL
#          nags (the completion WARN). Pins that the nag follows the MARKER, not the name — the
#          rename-to-conforming-garbage evasion is closed.
tr_nag_follows_marker() {
  r09_make "$R09_MGARB"; touch "$R09_MGARB/.ticket-pending"
  tr_status
  printf '%s\n' "$R09_OUT" | grep -q "Tickets/202607M-XYZ-1 looks complete" \
    || { echo "BUG [nag-follows-marker]: conforming-garbage rename silenced the nag — the marker" \
           "no longer governs:"; printf '%s\n' "$R09_OUT"; exit 1; }
  [ "$R09_RC" -le "$BASELINE_RC" ] \
    || { echo "BUG [nag-follows-marker]: added a NEW failure" \
           "(rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
  echo "  ok [nag-follows-marker] — conforming-garbage rename STILL nags (nag follows the marker," \
    "not the name)"
}

case_ticket_recognition() {
  tr_baseline
  tr_misnamed_warn
  tr_opt_out_silent
  tr_low_number_ok
  tr_wide_fields_ok
  tr_malformed_ignored
  tr_space_named_pack
  tr_pending_warn
  tr_pending_wins
  tr_handmade_warn
  tr_handmade_silent
  tr_completion_warn
  tr_completion_done
  tr_nag_follows_marker
  # Tear down the scratch folders above so the estate is clean for the tour's demonstration.
  rm -rf "$R09_SPACE" "$R09_CONF" "$R09_LONG" "$R09_BAD" "$R09_PEND" "$R09_HAND" \
    "$R09_KCONF" "$R09_MGARB"
}
