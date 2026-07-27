#!/usr/bin/env bash
# housekeeping.case.sh — issue #16: the human-run repo-maintenance script runs and reports, and
# status's .git-size nudge fires in both directions. SOURCED by the runner; see run_demo.sh.

# [housekeeping-ok] Pins that harness-housekeeping.sh runs cleanly and reports sizes without
# touching records. It runs against a THROWAWAY repo (not the demo's real tree) so `git gc` has
# zero side effect on the estate — the demo's "uses temp state" promise holds. We assert only that
# it exits 0 and reports .git size; NOT a specific reclaim amount (that varies with repo state).
hk_runs_clean() {
  local G3_REPO G3_OUT G3_RC
  echo "--- housekeeping: runs clean (human-run repo maintenance) ---"
  G3_REPO=$(mktemp -d)
  git -C "$G3_REPO" init -q
  git -C "$G3_REPO" -c user.email=demo@local -c user.name=demo commit -q --allow-empty -m "seed"
  set +e; G3_OUT=$(bash estate/_harness/scripts/harness-housekeeping.sh "$G3_REPO" 2>&1); G3_RC=$?; set -e
  [ "$G3_RC" -eq 0 ] \
    || { echo "BUG [housekeeping-ok]: housekeeping exited non-zero (rc=$G3_RC):"; \
         printf '%s\n' "$G3_OUT"; exit 1; }
  printf '%s\n' "$G3_OUT" | grep -q "\.git" \
    || { echo "BUG [housekeeping-ok]: no .git size reported:"; printf '%s\n' "$G3_OUT"; exit 1; }
  printf '%s\n' "$G3_OUT" | grep -q "REPACK: git gc" \
    || { echo "BUG [housekeeping-ok]: housekeeping did not run the git gc repack step:"; \
         printf '%s\n' "$G3_OUT"; exit 1; }
  rm -rf "$G3_REPO"
  echo "  ok [housekeeping-ok] — script runs, reports sizes, repacks, exit 0 (no record touched)"
}

# [git-size-warn] / [git-size-quiet] — harness-status nudges (WARN) when .git exceeds
# HARNESS_GIT_WARN_MB, and the nudge is YELLOW — exit stays 0, never a red FAIL. Force it by
# setting the threshold to 0 so any non-empty .git trips it; then set it very high and assert it
# does NOT fire — pinning both directions. Side-effect-free: status's only write (the #71
# first-seen record) is redirected by the global HARNESS_WARN_STATE_FILE export in the runner to a
# throwaway temp path, so status on the real repo touches nothing — safe.
hk_git_size_nudge() {
  local G3W_OUT G3W_RC G3W_OUT2
  set +e; G3W_OUT=$(HARNESS_GIT_WARN_MB=0 bash estate/_harness/scripts/harness-status.sh 2>&1); \
    G3W_RC=$?; set -e
  printf '%s\n' "$G3W_OUT" | grep -q "WARN: the record repo's .git is" \
    || { echo "BUG [git-size-warn]: the .git-size nudge did not fire at threshold 0:"; \
         printf '%s\n' "$G3W_OUT"; exit 1; }
  [ "$G3W_RC" -eq 0 ] \
    || { echo "BUG [git-size-warn]: the size nudge must be yellow (exit 0), got rc=$G3W_RC:"; \
         printf '%s\n' "$G3W_OUT"; exit 1; }
  echo "  ok [git-size-warn] — .git-size nudge fires and stays non-blocking (WARN, exit 0)"
  set +e
  G3W_OUT2=$(HARNESS_GIT_WARN_MB=1000000 bash estate/_harness/scripts/harness-status.sh 2>&1)
  set -e
  printf '%s\n' "$G3W_OUT2" | grep -q "WARN: the record repo's .git is" \
    && { echo "BUG [git-size-quiet]: the size nudge fired while under threshold:"; \
         printf '%s\n' "$G3W_OUT2"; exit 1; }
  echo "  ok [git-size-quiet] — under threshold, no nudge (fires only when it should)"
}

case_housekeeping() {
  hk_runs_clean
  hk_git_size_nudge
}
