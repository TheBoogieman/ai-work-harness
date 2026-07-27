#!/usr/bin/env bash
# crlf-tripwire.case.sh — [crlf-tripwire]: no TRACKED shell/python script may carry a carriage
# return. SOURCED by the runner; see dev/scripts/run_demo.sh.
#
# A CRLF in a shebang or heredoc breaks execution, and .gitattributes only helps clones that HAVE
# it — this case is the standing backstop that reads the working-tree bytes directly, so it catches
# a CR no matter how the clone was configured. Detection is `tr -dc '\r'` (POSIX, GNU/BSD-portable):
# strip everything but CR; non-empty output means the file carries one. Uses a while-read loop, not
# mapfile, so it runs on the macOS runner's bash 3.2.
#
# ALIVENESS AND COMPLETENESS ARE DIFFERENT PROPERTIES, AND THIS CASE ONLY GUARDED THE FIRST (#270).
# The self-test below proves the DETECTOR can fail. It says nothing about whether the detector was
# shown every file the success line claims for it. The scan set used to shrink in silence: a script
# in the index but absent from the working tree was skipped by a bare existence filter, so deleting
# one tracked script left this case printing "no tracked *.sh/*.py carries a CR" — a claim about
# files it had never opened. Two outcomes are now RESULTS rather than skips: an entry that cannot
# be read, and a list that came back empty at all (git ls-files prints nothing outside a
# repository, and a scan of nothing used to print the same success line as a scan of everything).
# The success line reports the number of files actually READ, so it can no longer outrun the scan.

case_crlf_tripwire() {
  local CRLF_BAD="" CRLF_GONE="" f CRLF_FIX CRLF_N=0
  while IFS= read -r f; do
    CRLF_N=$((CRLF_N + 1))
    # An unreadable entry is a RESULT, not a skip — see the header. Written as if/elif rather than
    # the old `[ … ] && VAR=…` so neither branch's status can reach `set -e`.
    if [ ! -f "$f" ]; then
      CRLF_GONE="${CRLF_GONE}${f}"$'\n'
    elif [ -n "$(tr -dc '\r' < "$f")" ]; then
      CRLF_BAD="${CRLF_BAD}${f}"$'\n'
    fi
  done < <(git ls-files '*.sh' '*.py')
  if [ "$CRLF_N" -eq 0 ]; then
    echo "BUG [crlf-tripwire]: git ls-files matched NO tracked *.sh/*.py at all, so this" \
      "tripwire read nothing. It cannot report a clean tree it never scanned."
    exit 1
  fi
  if [ -n "$CRLF_GONE" ]; then
    echo "BUG [crlf-tripwire]: tracked script(s) are in the index but absent from the working" \
      "tree, so they were never read for a carriage return:"
    printf '%s' "$CRLF_GONE"
    exit 1
  fi
  if [ -n "$CRLF_BAD" ]; then
    echo "BUG [crlf-tripwire]: tracked script(s) carry a carriage return (CRLF will break" \
      "execution):"
    printf '%s' "$CRLF_BAD"
    exit 1
  fi
  # Self-test proves the detector is not vacuous (the guard-per-bug requirement): feed it a
  # CR-injected throwaway fixture, which it MUST flag. If the detector ever stops catching this,
  # the tripwire is silently dead — so this reds instead. (Reverting the detector reds HERE.)
  CRLF_FIX=$(mktemp)
  printf 'echo hi\r\n' > "$CRLF_FIX"
  if [ -z "$(tr -dc '\r' < "$CRLF_FIX")" ]; then
    echo "BUG [crlf-tripwire]: the CR detector failed to flag a CR-injected fixture — the" \
      "tripwire is vacuous"
    rm -f "$CRLF_FIX"; exit 1
  fi
  rm -f "$CRLF_FIX"
  echo "  ok [crlf-tripwire] — read all $CRLF_N tracked *.sh/*.py, none carries a CR (detector" \
    "proven on a CR fixture)"
}
