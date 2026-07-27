#!/usr/bin/env bash
# crlf-tripwire.case.sh — [crlf-tripwire]: no TRACKED shell/python script may carry a carriage
# return. SOURCED by the runner; see dev/scripts/run_demo.sh.
#
# A CRLF in a shebang or heredoc breaks execution, and .gitattributes only helps clones that HAVE
# it — this case is the standing backstop that reads the working-tree bytes directly, so it catches
# a CR no matter how the clone was configured. Detection is `tr -dc '\r'` (POSIX, GNU/BSD-portable):
# strip everything but CR; non-empty output means the file carries one. Uses a while-read loop, not
# mapfile, so it runs on the macOS runner's bash 3.2.

case_crlf_tripwire() {
  local CRLF_BAD="" f CRLF_FIX
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    [ -n "$(tr -dc '\r' < "$f")" ] && CRLF_BAD="${CRLF_BAD}${f}"$'\n'
  done < <(git ls-files '*.sh' '*.py')
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
  echo "  ok [crlf-tripwire] — no tracked *.sh/*.py carries a CR (detector proven on a CR fixture)"
}
