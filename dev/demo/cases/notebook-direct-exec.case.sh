#!/usr/bin/env bash
# notebook-direct-exec.case.sh — R-07: exercise check-scribe's LITERAL contract form. SOURCED by
# the runner; see dev/scripts/run_demo.sh for the contract.
#
# Invoke the helper DIRECTLY (execute bit + shebang, not `python3 <path>`), so a stripped execute
# bit turns this RED. The tour's own stage-4 call goes through python3 and never sees the bit,
# which is exactly why this case exists alongside it. Silent on success.

case_notebook_direct_exec() {
  if ! estate/_harness/scripts/append_notebook_cell.py "$S/Checks/checks_master.ipynb" \
       "check: direct-exec contract (R-07)" "SELECT 1;"; then
    echo "FAIL: append_notebook_cell.py not directly executable — execute bit or shebang missing." \
      "Fix: git update-index --chmod=+x estate/_harness/scripts/append_notebook_cell.py"
    exit 1
  fi
}
