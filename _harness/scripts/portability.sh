#!/usr/bin/env bash
# portability.sh — the ONE home for the ts14->epoch conversion shared by the validator and status.
# check_ticket_log.sh (recency: is the newest header at/after the watermark?) and harness-status.sh
# (commit-vs-session liveness) BOTH turn a YYYYMMDDHHMMSS session-log header into an epoch, so they
# must do it IDENTICALLY or their views disagree. It was duplicated once (M3) and that copy risked
# silent drift (R-21); sourcing this single definition in both tools makes drift impossible.
# (Single-consumer shims stay local: file_mtime lives in the validator, epoch_from_date in status —
# only the SHARED conversion lives here.)
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
