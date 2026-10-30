#!/usr/bin/env bash
# junk-ignored.case.sh — [junk-ignored]: objective editor/OS junk must be ignored even inside
# re-included dirs so it never enters the record. SOURCED by the runner; see run-demo.sh.
# Pre-fix (no junk patterns in .gitignore), git add -A stages it — red.

case_junk_ignored() {
  local J JUNK_STAGED
  J="estate/Tickets/junk-probe"; mkdir -p "$J"
  : > "$J/scratch.tmp"; : > "$J/backup~"; : > "$J/.file.swp"; : > "$J/Thumbs.db"
  # Bytecode lands beside a script that was imported, inside the re-included _harness/ (#331).
  mkdir -p estate/_harness/scripts/__pycache__
  : > estate/_harness/scripts/__pycache__/junk-probe.cpython-3.pyc
  JUNK_STAGED=$(git add -A --dry-run 2>/dev/null \
    | grep -E 'junk-probe/(scratch\.tmp|backup~|\.file\.swp|Thumbs\.db)|__pycache__/junk-probe' || true)
  rm -f estate/_harness/scripts/__pycache__/junk-probe.cpython-3.pyc
  rmdir estate/_harness/scripts/__pycache__ 2>/dev/null || true
  [ -z "$JUNK_STAGED" ] \
    || { echo "BUG [junk-ignored]: objective junk would be staged (not ignored):"; \
         printf '%s\n' "$JUNK_STAGED"; exit 1; }
  rm -rf "$J"
  echo "  ok [junk-ignored] — *.tmp / *~ / *.swp / Thumbs.db / __pycache__ ignored, never staged"
}
