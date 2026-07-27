#!/usr/bin/env bash
# undo-drill.case.sh — #103 [undo-drill]: harness-drill ships THREE modes (issue #75); the #75
# family exercises only restore-drill and bundle-drill, leaving undo-drill — the git-undo rehearsal
# you reach for in an actual emergency — with ZERO demo coverage. SOURCED by the runner.
#
# This case runs the REAL undo-drill end to end and holds it to its OWN contract in
# harness-drill.sh: the mode builds a one-commit throwaway fixture, inflicts a tracked-file change,
# and proves BOTH everyday undos restore the record to its committed content — an UNCOMMITTED
# mistake reversed by 'git restore <file>', and a COMMITTED mistake reversed by 'git revert HEAD'.
# undo-drill reports each success as a 'PROVED:' line, but its internal check is
# `if grep …; then say PROVED; fi` with no else and no effect on rc — so a broken undo silently
# DROPS its PROVED line while the mode still exits 0. This case therefore keys on BOTH PROVED lines
# being present (not on rc alone): that is precisely what makes a neutered undo red here. The mode
# only ever writes into its own `mktemp -d`, never the estate, so we also prove the REAL repo is
# byte-untouched across the run (its porcelain dirty-state is identical before and after).
# undo-drill rm's its own fixture, so this case adds NO temp dir of its own and NO second EXIT
# trap (#86).

case_undo_drill() {
  local UD_BEFORE UD_OUT UD_RC UD_AFTER
  echo "--- #103: harness-drill undo-drill rehearses the git-undo net, real repo untouched ---"
  UD_BEFORE=$(git -C "$DEMO_ROOT" status --porcelain)   # real-repo dirty-state fingerprint, pre-run
  # Run the REAL undo-drill. set +e brackets the call so a non-zero rc becomes DATA (like the #75
  # siblings) rather than aborting the demo before we can read it. 2>&1 folds git's autocrlf stderr
  # notices into the captured output; they are inert to the PROVED-line greps below.
  set +e
  UD_OUT=$(bash "$DEMO_ROOT/estate/_harness/scripts/harness-drill.sh" undo-drill 2>&1); UD_RC=$?
  set -e
  [ "$UD_RC" -eq 0 ] \
    || { echo "BUG [undo-drill]: undo-drill did not exit 0 (rc=$UD_RC):"; \
         printf '%s\n' "$UD_OUT"; exit 1; }
  # The uncommitted-mistake undo: 'git restore <file>' must put the record back — undo-drill only
  # prints this PROVED line when the restored fixture file matches its committed content, so its
  # absence means the restore step failed to recover the record.
  printf '%s\n' "$UD_OUT" | grep -q "an uncommitted mistake is undone by 'git restore <file>'" \
    || { echo "BUG [undo-drill]: undo-drill did not prove the uncommitted-mistake undo —" \
           "'git restore <file>' did not restore the fixture record to its committed content:"; \
         printf '%s\n' "$UD_OUT"; exit 1; }
  # The committed-mistake undo: 'git revert HEAD' must put the record back — same contract, its
  # PROVED line prints only when the reverted fixture file matches its committed content.
  printf '%s\n' "$UD_OUT" | grep -q "a committed mistake is undone by 'git revert HEAD'" \
    || { echo "BUG [undo-drill]: undo-drill did not prove the committed-mistake undo —" \
           "'git revert HEAD' did not restore the fixture record to its committed content:"; \
         printf '%s\n' "$UD_OUT"; exit 1; }
  # THE REAL REPO IS UNTOUCHED: undo-drill writes only into its own mktemp fixture, so the live
  # working tree's dirty-state must be byte-identical before and after (fixture-only, like
  # every drill).
  UD_AFTER=$(git -C "$DEMO_ROOT" status --porcelain)
  [ "$UD_BEFORE" = "$UD_AFTER" ] \
    || { echo "BUG [undo-drill]: the REAL repo changed during undo-drill — the mode is not" \
           "fixture-only (the working tree must be byte-identical before and after)"; exit 1; }
  echo "  ok [undo-drill] — undo-drill proved both the git-restore and git-revert undos on its" \
    "fixture, real repo untouched"
}
