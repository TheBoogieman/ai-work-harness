#!/usr/bin/env bash
# worktree-store.case.sh — #86: both size reporters must resolve the REAL git store from a LINKED
# WORKTREE, where .git is a pointer FILE rather than a directory. SOURCED by the runner.
#
# Pre-fix, harness-status path-tested `[ -d "$WORK_ROOT/.git" ]` and the whole nudge vanished
# without a word, so the demo could not pass from any worktree — which is exactly where
# parallel-lane build work runs; harness-housekeeping du'd the same path and reported a ~4 KiB
# ".git" while repacking the real store correctly, i.e. a truthful action with a false report.
# FIXTURE: a THROWAWAY repo carrying a copy of _harness (status derives its root from its own
# location, so the script must live inside the fixture) plus a linked worktree of it. The real
# estate is never worktree-added, so nothing is registered in the user's repo and no record is
# touched. NOTE: the fixture is not a full estate, so harness-status exits non-zero there on
# unrelated checks — assert on the nudge LINE, never on the fixture's exit code. Cleanup is an
# explicit rm (the runner's single EXIT trap belongs to demo_cleanup; do not add another).

ws_fixture() {
  echo "--- #86: size probes resolve the store from a linked worktree ---"
  W86=$(mktemp -d)
  mkdir -p "$W86/repo"
  git -C "$W86/repo" init -q
  cp -R _harness "$W86/repo/_harness"
  git -C "$W86/repo" -c user.email=demo@local -c user.name=demo add -A
  git -C "$W86/repo" -c user.email=demo@local -c user.name=demo commit -q -m "seed"
  git -C "$W86/repo" -c user.email=demo@local -c user.name=demo worktree add -q "$W86/wt" -b w86
  W86_EXPECT=$(du -sk "$W86/repo/.git" 2>/dev/null | awk '{print $1}')
}

# The status nudge, from inside the linked worktree: it must fire, and it must weigh the shared
# store rather than the tiny pointer file.
ws_status_nudge() {
  local W86_OUT W86_OUT2
  set +e
  W86_OUT=$(cd "$W86/wt" && HARNESS_GIT_WARN_MB=0 bash _harness/scripts/harness-status.sh 2>&1)
  set -e
  printf '%s\n' "$W86_OUT" | grep -q "WARN: the record repo's .git is" \
    || { echo "BUG [worktree-store]: the .git-size nudge did not fire from a linked worktree —" \
           "the probe still assumes .git is a directory:"; printf '%s\n' "$W86_OUT"; \
         rm -rf "$W86"; exit 1; }
  printf '%s\n' "$W86_OUT" | grep -q "\.git is 0\.0 MiB" \
    && { echo "BUG [worktree-store]: the nudge weighed the .git POINTER FILE (0.0 MiB), not the" \
           "shared store:"; printf '%s\n' "$W86_OUT"; rm -rf "$W86"; exit 1; }
  echo "  ok [worktree-store] — status nudge fires from a worktree and weighs the real store"
  set +e
  W86_OUT2=$(cd "$W86/wt" \
    && HARNESS_GIT_WARN_MB=1000000 bash _harness/scripts/harness-status.sh 2>&1)
  set -e
  printf '%s\n' "$W86_OUT2" | grep -q "WARN: the record repo's .git is" \
    && { echo "BUG [worktree-store]: the nudge fired from a worktree while under threshold:"; \
         printf '%s\n' "$W86_OUT2"; rm -rf "$W86"; exit 1; }
  echo "  ok [worktree-store] — under threshold, no nudge from a worktree either"
}

# Housekeeping from the same worktree: it must exit 0, report the REAL store size, and never
# report a negative or blank working tree (which is what subtracting an out-of-tree store gives).
ws_housekeeping_report() {
  local W86_HK W86_HK_RC W86_GOT W86_WT
  set +e
  W86_HK=$(bash _harness/scripts/harness-housekeeping.sh "$W86/wt" 2>&1); W86_HK_RC=$?
  set -e
  [ "$W86_HK_RC" -eq 0 ] \
    || { echo "BUG [worktree-store]: housekeeping exited non-zero against a worktree" \
           "(rc=$W86_HK_RC):"; printf '%s\n' "$W86_HK"; rm -rf "$W86"; exit 1; }
  W86_GOT=$(printf '%s\n' "$W86_HK" | sed -n 's/^BEFORE: \.git \([0-9-]*\) KiB.*/\1/p')
  [ "$W86_GOT" = "$W86_EXPECT" ] \
    || { echo "BUG [worktree-store]: housekeeping reported .git as ${W86_GOT} KiB from a" \
           "worktree; the real store is ${W86_EXPECT} KiB — the report is a fiction:"; \
         printf '%s\n' "$W86_HK"; rm -rf "$W86"; exit 1; }
  W86_WT=$(printf '%s\n' "$W86_HK" | sed -n 's/^BEFORE: .* working tree \([0-9-]*\) KiB.*/\1/p')
  case "$W86_WT" in
    -*|"") echo "BUG [worktree-store]: housekeeping reported a negative/blank working tree" \
             "(${W86_WT} KiB) — an out-of-tree store was subtracted:"; \
           printf '%s\n' "$W86_HK"; rm -rf "$W86"; exit 1 ;;
  esac
  echo "  ok [worktree-store] — housekeeping weighs the real store (${W86_EXPECT} KiB) and keeps" \
    "the working tree honest"
}

case_worktree_store() {
  ws_fixture
  ws_status_nudge
  ws_housekeeping_report
  rm -rf "$W86"
}
