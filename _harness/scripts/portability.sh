#!/usr/bin/env bash
# portability.sh — the ONE home for computations shared by more than one harness tool.
# check_ticket_log.sh (recency: is the newest header at/after the watermark?) and harness-status.sh
# (commit-vs-session liveness) BOTH turn a YYYYMMDDHHMMSS session-log header into an epoch, so they
# must do it IDENTICALLY or their views disagree. It was duplicated once (M3) and that copy risked
# silent drift (R-21); sourcing this single definition in both tools makes drift impossible.
# (Single-consumer shims stay local: file_mtime lives in the validator, epoch_from_date in status —
# only computations with MORE THAN ONE consumer live here.)
# The 14 digits are LOCAL machine time, matching the session-log clock convention (R-10):
# interpret via GNU `date -d` or BSD `date -j`, in $TZ, and fall back to 0 on any parse failure.
epoch_from_ts14() {  # YYYYMMDDHHMMSS -> epoch
  local t="$1"
  if date -d "1970-01-01" +%s >/dev/null 2>&1; then
    date -d "${t:0:8} ${t:8:2}:${t:10:2}:${t:12:2}" +%s 2>/dev/null || echo 0
  else
    date -j -f "%Y%m%d%H%M%S" "$t" +%s 2>/dev/null || echo 0
  fi
}

# Resolve the true record store for a checkout (issue #86). In a normal clone this is <root>/.git;
# in a LINKED WORKTREE .git is a pointer FILE and the real store lives in the main checkout, so a
# path test like `[ -d "$root/.git" ]` silently finds nothing and a du of "$root/.git" weighs a
# ~4 KiB pointer instead of the history. `git rev-parse --git-common-dir` answers the question git
# itself would answer; it prints a path RELATIVE to the checkout in a normal clone and an ABSOLUTE
# one in a worktree, so we normalise both to absolute. Prints nothing (and returns 0) when $root is
# not a git checkout at all — callers treat empty as "no repo here" and skip, as they did before.
harness_git_store() {  # <checkout-root> -> absolute path of the git store, or empty
  local root="$1"
  local common=""
  # Assign on its own line: `local x=$(...)` would swallow git's exit status (local always
  # returns 0), and under `set -e` we need the failure to be visible here, not silently ignored.
  common=$(cd "$root" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null) || return 0
  [ -n "$common" ] || return 0
  (cd "$root" && cd "$common" 2>/dev/null && pwd) || return 0
}
