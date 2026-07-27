#!/usr/bin/env bash
# junk-ignored.case.sh — [junk-ignored]: objective editor/OS junk must be ignored even inside
# re-included dirs so it never enters the record. SOURCED by the runner; see run_demo.sh.
# Pre-fix (no junk patterns in .gitignore), git add -A stages it — red.

case_junk_ignored() {
  local J JUNK_STAGED
  J="Tickets/junk-probe"; mkdir -p "$J"
  : > "$J/scratch.tmp"; : > "$J/backup~"; : > "$J/.file.swp"; : > "$J/Thumbs.db"
  JUNK_STAGED=$(git add -A --dry-run 2>/dev/null \
    | grep -E 'junk-probe/(scratch\.tmp|backup~|\.file\.swp|Thumbs\.db)' || true)
  [ -z "$JUNK_STAGED" ] \
    || { echo "BUG [junk-ignored]: objective junk would be staged (not ignored):"; \
         printf '%s\n' "$JUNK_STAGED"; exit 1; }
  rm -rf "$J"
  echo "  ok [junk-ignored] — *.tmp / *~ / *.swp / Thumbs.db ignored, never staged"
}
