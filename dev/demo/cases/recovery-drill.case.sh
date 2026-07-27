#!/usr/bin/env bash
# recovery-drill.case.sh — #75 [recovery-drill]: harness-drill rehearses recovery and must be
# READ-ONLY toward the estate it rehearses on. SOURCED by the runner; see run_demo.sh.
#
# This family builds a FIXTURE estate (a throwaway git repo carrying a copy of _harness plus one
# valid ticket — harness-drill derives its root from its OWN location, so the script must live
# INSIDE the fixture, exactly like the #86 case), then proves three things: (1) a restore-drill
# from the fixture's own .git yields a copy that passes check_ticket_log.sh; (2) a bundle-drill
# (local git bundle -> restore) yields a copy that passes check_ticket_log.sh; and (3) the fixture
# estate is BYTE-IDENTICAL before and after — a recovery tool that damaged the record it is
# rehearsing to protect would be the worst possible bug in this repo, so this is a byte-comparison,
# not an eyeball. Cleanup is an explicit rm on every exit path — the runner's single
# `trap ... EXIT` already owns the trap slot, so we must NOT add a second one (#86).

# hd_manifest — a byte-level fingerprint of the fixture's RECORDS (working-tree files, excluding
# the .git store): every file's cksum, sorted. Comparing it before and after the drills is the
# 'estate byte-untouched' proof. We exclude .git only because git's own READ operations may touch
# pack mtimes; the record a user cares about is the working tree, and that must not move one byte.
hd_manifest() { find "$HD_FIX" -type f -not -path '*/.git/*' | sort | xargs cksum; }

# hd_fixture — the throwaway estate that plays the 'live estate'. A minimal but VALID ticket — a
# <name>.md with a Current State section and one session-log header — so check_ticket_log.sh
# validates the RESTORED copy green (a vacuous pass would prove nothing).
hd_fixture() {
  echo "--- #75: harness-drill rehearses restore/bundle recovery, estate byte-untouched ---"
  HD_FIX=$(mktemp -d)
  git -C "$HD_FIX" init -q
  # harness-drill resolves its root from its own location, so the machinery lands at the
  # fixture estate's OWN root while the source side carries the tree prefix
  cp -R estate/_harness "$HD_FIX/_harness"
  mkdir -p "$HD_FIX/Tickets/202607D-PROJ-1"
  cat > "$HD_FIX/Tickets/202607D-PROJ-1/202607D-PROJ-1.md" <<HDMD
# 202607D-PROJ-1

## Current State
Rehearsal fixture ticket.

## $(date +%Y%m%d%H%M%S) - fixture session
- seeded for the harness-drill restore rehearsal
HDMD
  git -C "$HD_FIX" -c user.email=demo@local -c user.name=demo add -A
  git -C "$HD_FIX" -c user.email=demo@local -c user.name=demo commit -q -m "fixture estate"
  HD_BEFORE=$(hd_manifest)
}

# 1. restore-drill on the fixture -> the restored copy passes check_ticket_log.sh (exit 0). Run the
#    fixture's OWN copy of the script so WORK_ROOT resolves to the fixture, never the live estate.
hd_restore_drill() {
  local HD_OUT HD_RC
  set +e
  HD_OUT=$(bash "$HD_FIX/_harness/scripts/harness-drill.sh" restore-drill 2>&1); HD_RC=$?
  set -e
  [ "$HD_RC" -eq 0 ] \
    || { echo "BUG [recovery-drill]: restore-drill on a fixture did not exit 0 — the restored" \
           "copy failed to validate (rc=$HD_RC):"; printf '%s\n' "$HD_OUT"; \
         rm -rf "$HD_FIX"; exit 1; }
  printf '%s\n' "$HD_OUT" | grep -q "restored copy validates green" \
    || { echo "BUG [recovery-drill]: restore-drill did not report the restored copy validating" \
           "green:"; printf '%s\n' "$HD_OUT"; rm -rf "$HD_FIX"; exit 1; }
  echo "  ok [recovery-drill] — restore-drill rebuilt the record from .git and it validated green"
}

# 2. bundle-drill on the SAME fixture -> the restored-from-bundle copy passes check_ticket_log.sh.
hd_bundle_drill() {
  local HD_OUT HD_RC
  set +e
  HD_OUT=$(bash "$HD_FIX/_harness/scripts/harness-drill.sh" bundle-drill 2>&1); HD_RC=$?
  set -e
  [ "$HD_RC" -eq 0 ] \
    || { echo "BUG [recovery-drill]: bundle-drill on a fixture did not exit 0 — the" \
           "bundle-restored copy failed to validate (rc=$HD_RC):"; printf '%s\n' "$HD_OUT"; \
         rm -rf "$HD_FIX"; exit 1; }
  printf '%s\n' "$HD_OUT" | grep -q "restored from the bundle validates green" \
    || { echo "BUG [recovery-drill]: bundle-drill did not report the bundle-restored copy" \
           "validating green:"; printf '%s\n' "$HD_OUT"; rm -rf "$HD_FIX"; exit 1; }
  echo "  ok [recovery-drill] — bundle-drill made a local bundle and the restore from it" \
    "validated green"
}

# 3. THE ESTATE IS BYTE-UNTOUCHED: the fixture's record fingerprint must be identical after both
#    drills. This is the assertion that matters most — a rehearsal that mutates the thing it
#    protects is a catastrophe — so it is a byte-comparison, never an eyeball.
hd_estate_untouched() {
  local HD_AFTER
  HD_AFTER=$(hd_manifest)
  [ "$HD_BEFORE" = "$HD_AFTER" ] \
    || { echo "BUG [recovery-drill]: the fixture estate changed during the drills — harness-drill" \
           "is NOT read-only toward the estate (records must be byte-identical before and after)"; \
         rm -rf "$HD_FIX"; exit 1; }
  echo "  ok [recovery-drill] — the estate is byte-identical after both drills (read-only proven)"
}

case_recovery_drill() {
  hd_fixture
  hd_restore_drill
  hd_bundle_drill
  hd_estate_untouched
  rm -rf "$HD_FIX"
}
