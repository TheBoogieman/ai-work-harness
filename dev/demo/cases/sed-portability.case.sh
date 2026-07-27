#!/usr/bin/env bash
# sed-portability.case.sh — R-03: reject in-place sed anywhere under _harness/ (BSD-incompatible;
# use tmp+mv instead). SOURCED by the runner; see dev/scripts/run_demo.sh for the contract.
#
# It runs FIRST, before the tour's first stage banner, because it is a lexical check over the
# source tree rather than a behaviour test: if the shipped machinery carries a GNU-only in-place
# sed there is no point running anything on a BSD lane. Silent on success — grep prints the
# offending lines itself when there are any.

case_sed_portability() {
  if grep -rnE 'sed +(-[A-Za-z]+ +)*-i' _harness/; then
    echo "FAIL: in-place sed found under _harness/ — not BSD-portable. Fix: rewrite via tmp+mv" \
      "(grep for deletes, sed for substitutions)."
    exit 1
  fi
}
