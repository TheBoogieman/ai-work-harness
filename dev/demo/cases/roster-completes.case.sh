#!/usr/bin/env bash
# roster-completes.case.sh — [roster-completes]: harness-status must NOT abort on a conforming
# ticket with NO AI-Knowledge/ dir (hand-made/legacy — the validator tolerates it). SOURCED by the
# runner; see dev/scripts/run-demo.sh.
#
# Pre-fix, the unguarded find in harness-status's roster loop exits non-zero on the missing dir and
# (pipefail + set -e) aborts that loop BEFORE this ticket's line prints — suppressing the whole
# estate's roster. This is the FIRST conforming-ticket-without-AI-Knowledge fixture in the suite
# (r09_make builds its conforming fixtures WITH AI-Knowledge, so the field hit a case the demo
# never covered). NOTE: the suite runs with CWD = repo root and never defines WORK_ROOT
# (harness-status resolves it internally); like every other fixture here the ticket path is
# relative to Tickets/.
#
# Pre-fixture baseline: only the rc is used (compared against NOAK_RC below), so the output is
# discarded instead of captured. The call must stay — it is what establishes the baseline rc.

case_roster_completes() {
  local PRE37_RC NOAK NOAK_OUT NOAK_RC
  set +e; bash estate/_harness/scripts/harness-status.sh >/dev/null 2>&1; PRE37_RC=$?; set -e
  NOAK="estate/Tickets/202607D-PROJ-777"
  mkdir -p "$NOAK"     # deliberately NO AI-Knowledge/ subdir — the bug trigger
  cat > "$NOAK/202607D-PROJ-777.md" <<'MD'
# 202607D-PROJ-777
## Current State
Legacy ticket imported by hand; no learnings captured yet.
## Session Log
## 20260704120000 - imported
Hand-created for the #37 fixture.
MD
  set +e; NOAK_OUT=$(bash estate/_harness/scripts/harness-status.sh 2>&1); NOAK_RC=$?; set -e
  printf '%s\n' "$NOAK_OUT" | grep -q '202607D-PROJ-777.*knowledge files: 0' \
    || { echo "BUG [roster-completes]: harness-status did not reach the AI-Knowledge-less" \
           "ticket's roster line (it aborted at the unguarded find):"; \
         printf '%s\n' "$NOAK_OUT"; exit 1; }
  [ "$NOAK_RC" -le "$PRE37_RC" ] \
    || { echo "BUG [roster-completes]: the AI-Knowledge-less ticket added a NEW failure / abort" \
           "(rc=$NOAK_RC > baseline=$PRE37_RC)"; exit 1; }
  rm -rf "$NOAK"
  echo "  ok [roster-completes] — harness-status completes on a conforming ticket with no" \
    "AI-Knowledge/ (roster reached, no new failure)"
}
