#!/usr/bin/env bash
# sed-portability.case.sh — R-03: reject in-place sed anywhere in the shipped machinery or the
# acceptance suite (BSD-incompatible;
# use tmp+mv instead). SOURCED by the runner; see dev/scripts/run_demo.sh for the contract.
#
# It runs FIRST, before the tour's first stage banner, because it is a lexical check over the
# source tree rather than a behaviour test: if the shipped machinery carries a GNU-only in-place
# sed there is no point running anything on a BSD lane. Silent on success — grep prints the
# offending lines itself when there are any.

case_sed_portability() {
  # THE SCAN SET IS THE SAME FILES IT ALWAYS WAS, spelled at their new homes (#136). Before the
  # tree split one prefix — _harness/ — held both the shipped machinery and the acceptance
  # suite; the split sent those two to opposite trees, so naming only one of them here would
  # QUIETLY NARROW this scan while every check stayed green. Both are named, and the runner
  # with them, because it lived under that prefix too.
  if grep -rnE 'sed +(-[A-Za-z]+ +)*-i' estate/_harness/ dev/demo/ dev/scripts/run_demo.sh; then
    echo "FAIL: in-place sed found in the shipped machinery or the acceptance suite — not" \
      "BSD-portable. Fix: rewrite via tmp+mv" \
      "(grep for deletes, sed for substitutions)."
    exit 1
  fi
}
