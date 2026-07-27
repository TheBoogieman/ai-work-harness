#!/usr/bin/env bash
# sed-portability.case.sh — [sed-portability]: reject in-place sed anywhere in the shipped
# machinery or the acceptance suite (BSD-incompatible;
# use tmp+mv instead). SOURCED by the runner; see dev/scripts/run_demo.sh for the contract.
#
# It runs FIRST, before the tour's first stage banner, because it is a lexical check over the
# source tree rather than a behaviour test: if the shipped machinery carries a GNU-only in-place
# sed there is no point running anything on a BSD lane.
#
# REACHABILITY, AND WHY THIS CASE NOW SPEAKS ON SUCCESS (#270). grep exits 1 for two different
# reasons — it matched nothing, and it could not read an operand — and this case used to treat
# both as "clean". Move the shipped machinery away and the scan wrote "No such file or directory"
# to stderr, matched nothing in the two operands that survived, and returned 0: a report of a clean
# tree it had never read. The operands are now asserted to EXIST before they are scanned.
#
# It used to be silent on success, which made that hole unreadable from the outside: a vacuous pass
# and a healthy pass were byte-identical, both printing nothing, so no reader could tell a scan of
# the whole tree from a scan of nothing. It now prints what it scanned and what it found, and the
# count in that line is the LENGTH OF THE OPERAND LIST rather than a number typed by hand, so the
# line cannot drift from the set it reports on.

case_sed_portability() {
  # THE SCAN SET IS THE SAME FILES IT ALWAYS WAS, spelled at their new homes (#136). Before the
  # tree split one prefix — _harness/ — held both the shipped machinery and the acceptance
  # suite; the split sent those two to opposite trees, so naming only one of them here would
  # QUIETLY NARROW this scan while every check stayed green. Both are named, and the runner
  # with them, because it lived under that prefix too. Named ONCE, in an array, because the
  # existence assertion and the scan below both read it: spelled twice they could disagree about
  # which operands this case covers, and the assertion would then be guarding a set nobody scans.
  local sp_operands sp_op sp_gone=0
  sp_operands=(estate/_harness/ dev/demo/ dev/scripts/run_demo.sh)
  # Every operand is checked before any is scanned, and a missing one reds under THIS case's own
  # tag instead of quietly shrinking the scan. All are reported, not just the first: a tree that
  # moved is easier to re-point when the case lists everything it could not find.
  for sp_op in "${sp_operands[@]}"; do
    [ -e "$sp_op" ] && continue
    sp_gone=1
    echo "BUG [sed-portability]: '$sp_op' does not exist, so the in-place-sed scan cannot read" \
      "it. This case scans exactly ${#sp_operands[@]} operands, and a missing one would let it" \
      "report a clean tree it never read. Restore the path, or re-point this case at whatever" \
      "replaced it."
  done
  [ "$sp_gone" -eq 0 ] || exit 1
  if grep -rnE 'sed +(-[A-Za-z]+ +)*-i' "${sp_operands[@]}"; then
    echo "FAIL: in-place sed found in the shipped machinery or the acceptance suite — not" \
      "BSD-portable. Fix: rewrite via tmp+mv" \
      "(grep for deletes, sed for substitutions)."
    exit 1
  fi
  echo "  ok [sed-portability] — all ${#sp_operands[@]} scan operands present and read; none" \
    "carries an in-place sed"
}
