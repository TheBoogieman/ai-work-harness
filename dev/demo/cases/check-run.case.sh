#!/usr/bin/env bash
# check-run.case.sh — #79 [run-and-record]: the run-and-record wrapper runs the user's LITERAL
# command and appends ONE notebook cell holding four fields (command, output, exit code,
# timestamp), FAILS OPEN when recording breaks (the command's result and rc always reach the
# caller), and executes nothing beyond the command. SOURCED by the runner; see run_demo.sh.
#
# This family proves those three properties on fixture commands. Cleanup is an explicit rm on
# EVERY exit path — the runner's single `trap ... EXIT` already owns the trap slot, so we must NOT
# add a second one (#86).

cr_fixture() {
  echo "--- #79: check_run runs a command and records it as one notebook cell ---"
  CR_TMP=$(mktemp -d)
  CR_NB="$CR_TMP/checks.ipynb"
  python3 -c "import nbformat,sys; nbformat.write(nbformat.v4.new_notebook(), sys.argv[1])" "$CR_NB"
}

# 1. A fixture command → EXACTLY ONE cell recording ALL FOUR fields (command, output, exit code,
#    timestamp). The wrapper appends a note+code pair, and exactly one of those cells must carry
#    every field. CR_FIELDCELLS counts cells whose source contains all four field markers.
cr_one_cell_four_fields() {
  local CR_FIELDCELLS
  CHECK_RUN_NOTEBOOK="$CR_NB" bash _harness/scripts/check_run.sh "echo demo79-output" \
    >/dev/null 2>&1
  CR_FIELDCELLS=$(python3 -c "import nbformat,sys
nb=nbformat.read(sys.argv[1],as_version=4)
need=('command:','output:','exit code:','timestamp:')
hit=[c for c in nb.cells if all(n in c.source for n in need) and 'demo79-output' in c.source]
print(len(hit))" "$CR_NB")
  [ "$CR_FIELDCELLS" = "1" ] \
    || { echo "BUG [run-and-record]: a fixture command did not produce exactly ONE cell recording" \
           "all four fields (command, output, exit code, timestamp) — got $CR_FIELDCELLS such" \
           "cell(s)"; rm -rf "$CR_TMP"; exit 1; }
  echo "  ok [run-and-record] — one fixture command recorded exactly one cell with all four fields"
}

# 2. A FAILING fixture command → recorded WITH its exit code, and the wrapper's OWN rc equals the
#    command's rc (not the recorder's). The command exits 42; the wrapper must exit 42 and the
#    record must carry that code.
cr_failing_command() {
  local CR_RC
  set +e
  CHECK_RUN_NOTEBOOK="$CR_NB" bash _harness/scripts/check_run.sh "exit 42" >/dev/null 2>&1
  CR_RC=$?; set -e
  [ "$CR_RC" = "42" ] \
    || { echo "BUG [run-and-record]: a failing command's rc was not passed through — wrapper" \
           "exited $CR_RC, want 42 (rc must reflect the command, never the recorder)"; \
         rm -rf "$CR_TMP"; exit 1; }
  grep -Fq -- "exit code: \`42\`" "$CR_NB" \
    || { echo "BUG [run-and-record]: the failing command's exit code 42 was not recorded in the" \
           "notebook"; rm -rf "$CR_TMP"; exit 1; }
  echo "  ok [run-and-record] — a failing command is recorded with its code and the wrapper" \
    "rc mirrors it"
}

# 3. FAILS OPEN: point recording at an ABSENT notebook target so the append breaks. The command's
#    output must STILL reach the caller and the wrapper's rc must STILL reflect the command — a
#    broken notebook may never swallow a result. This is the property most worth guarding.
cr_fails_open() {
  local CR_ABSENT CR_FO_OUT CR_FO_RC
  CR_ABSENT="$CR_TMP/no-such-notebook.ipynb"
  set +e
  CR_FO_OUT=$(CHECK_RUN_NOTEBOOK="$CR_ABSENT" bash _harness/scripts/check_run.sh \
    "echo failopen79; exit 9" 2>/dev/null); CR_FO_RC=$?
  set -e
  printf '%s\n' "$CR_FO_OUT" | grep -Fq "failopen79" \
    || { echo "BUG [run-and-record]: with a broken recording target the command's output did NOT" \
           "reach the caller — the wrapper did not fail open:"; printf '%s\n' "$CR_FO_OUT"; \
         rm -rf "$CR_TMP"; exit 1; }
  [ "$CR_FO_RC" = "9" ] \
    || { echo "BUG [run-and-record]: with a broken recording target the wrapper rc was $CR_FO_RC," \
           "want 9 — a recorder failure must not change the command's exit code"; \
         rm -rf "$CR_TMP"; exit 1; }
  echo "  ok [run-and-record] — recording failure fails open: command output reaches the caller" \
    "and rc reflects the command"
}

case_check_run() {
  cr_fixture
  cr_one_cell_four_fields
  cr_failing_command
  cr_fails_open
  rm -rf "$CR_TMP"
}
