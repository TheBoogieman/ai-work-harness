#!/usr/bin/env bash
# check_run.sh — run-and-record primitive for ad-hoc shell checks (#79).
# WHAT IT IS: a dumb wrapper. It runs the user's LITERAL command in the user's
# own shell session (their environment, their credentials) and appends ONE
# notebook cell recording four fields — the command, its output, its exit code,
# and a timestamp — through the existing append_notebook_cell.py plumbing.
# WHY IT EXISTS: ad-hoc verification commands run in the terminal and vanish;
# this captures one as a durable record without changing how it runs.
#
# Non-negotiable properties (each is also an acceptance line in #79):
#  - ADDS NO AUTH SURFACE: it runs the user's command under the user's own
#    credentials; it acquires nothing, prompts for nothing, stores nothing.
#  - NO SECRET EVER LANDS IN RECORDED TEXT: the recorded text is only the command
#    as typed and the output as produced; the wrapper reads/writes no credential
#    material of its own.
#  - EXECUTES NOTHING BEYOND THE LITERAL COMMAND: no retries, no env mutation, no
#    helpful wrapping — just the command the user passed.
#  - FAILS OPEN: if recording fails, the command's result still reaches the user
#    and the wrapper's exit code still reflects the COMMAND's rc, never the
#    recorder's. A broken notebook must never swallow a result.
#  - OFFLINE-SAFE: no network call, ever.
#
# Target notebook: the CHECK_RUN_NOTEBOOK env var names the .ipynb to append to
# (it must already exist — the append helper only appends). If it is unset or the
# append fails, recording is skipped (fails-open) and the command result stands.
#
# NOT set -e: a non-zero command exit is normal DATA here (we record failing
# commands too), so an -e abort would be exactly the wrong behaviour. We keep -u
# for unset-var safety and pipefail for honest pipe status inside this wrapper.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Exactly one argument: the command string. Anything else is a usage error.
if [ "$#" -ne 1 ]; then
  echo "check_run: usage: check_run.sh \"<command>\"" >&2
  exit 2
fi
cmd="$1"

# Timestamp the run in UTC ISO-8601. -u and +FORMAT are POSIX (GNU + BSD both).
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Run the user's LITERAL command in a shell that inherits their environment and
# credentials — not a sandbox. We capture combined stdout+stderr as "its output"
# and read the command's own exit code. Nothing is added to the command line.
output="$(bash -c "$cmd" 2>&1)"
rc=$?

# The command's result reaches the user FIRST, before any recording is attempted.
# This ordering is what makes the wrapper fail open: the output is already out and
# the exit code is already fixed, so whatever happens to the recorder below can
# neither hide the result nor change the status.
printf '%s\n' "$output"

# Build the ONE record cell holding all four fields. The markdown note carries the
# full record (command, exit code, timestamp, output); the code cell holds the
# literal command so the check stays re-runnable from the notebook.
note="check_run - ran a command and recorded the result

- command: \`$cmd\`
- exit code: \`$rc\`
- timestamp: \`$ts\`
- output:

\`\`\`
$output
\`\`\`"

# Attempt to record. Every failure path here is swallowed to stderr (a warning,
# never a block) so the command's rc — captured above — is the only thing that
# governs our exit. Recording is skipped cleanly when no notebook is configured.
nb="${CHECK_RUN_NOTEBOOK:-}"
if [ -z "$nb" ]; then
  echo "check_run: CHECK_RUN_NOTEBOOK unset — result not recorded (command result stands)." >&2
elif ! python3 "$SCRIPT_DIR/append_notebook_cell.py" "$nb" "$note" "$cmd" >/dev/null 2>&1; then
  echo "check_run: recording to '$nb' failed — result not recorded (command result stands)." >&2
fi

# Exit with the COMMAND's exit code, never the recorder's — the fails-open promise.
exit "$rc"
