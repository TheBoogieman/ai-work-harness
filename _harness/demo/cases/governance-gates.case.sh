#!/usr/bin/env bash
# governance-gates.case.sh — revert-proofs for the LOCALLY-decidable gate scripts under
# .github/scripts/ (the API existence/OPEN check is CI-only and witnessed at the seat, not here).
# SOURCED by the runner; see _harness/scripts/run_demo.sh.
#
# Same shape as #38: these call the very scripts the workflow calls, so weakening a grammar or
# pattern turns the matching case RED. CWD is the repo root, so the relative paths resolve.

# [branch-grammar] the NN-slug grammar ACCEPTS the conforming set AND REJECTS the non-conforming
# set — both directions, so loosening OR tightening the regex reds this case.
gg_branch_grammar() {
  local GRAM good bad GRAM_MISS
  GRAM=.github/scripts/branch-grammar.sh
  for good in 37-status-abort-fix 47-governance-pair; do
    bash "$GRAM" "$good" >/dev/null 2>&1 \
      || { echo "BUG [branch-grammar]: conforming '$good' was rejected"; exit 1; }
  done
  for bad in WSL-canonical Feature/Foo 47_governance mixedCase; do
    bash "$GRAM" "$bad" 47 >/dev/null 2>&1 \
      && { echo "BUG [branch-grammar]: non-conforming '$bad' was accepted"; exit 1; }
  done
  # Capture the miss message before grepping — the script exits non-zero by design, and
  # grepping it through a pipe would let pipefail red this even when the text matches.
  GRAM_MISS=$(bash "$GRAM" "Feature/Foo" 47 2>&1 || true)
  printf '%s\n' "$GRAM_MISS" | grep -q 'git branch -m' \
    || { echo "BUG [branch-grammar]: miss message lacks the literal 'git branch -m' rename" \
           "prescription"; exit 1; }
  echo "  ok [branch-grammar] — conforming accepted, non-conforming rejected, rename" \
    "prescription emitted"
}

# [branch-coherence] the branch's leading NN must be a MEMBER of the PR's closing-issue set.
gg_branch_coherence() {
  local COH COH_MISS
  COH=.github/scripts/branch-coherence.sh
  printf '47 49\n' | bash "$COH" 47-governance-pair >/dev/null 2>&1 \
    || { echo "BUG [branch-coherence]: NN present in the closing set was wrongly red"; exit 1; }
  printf '47 49\n' | bash "$COH" 99-wrong-anchor >/dev/null 2>&1 \
    && { echo "BUG [branch-coherence]: NN absent from the closing set was wrongly accepted"; \
         exit 1; }
  # the script exits non-zero by design, so capture the message rather than pipe it
  COH_MISS=$(printf '47 49\n' | bash "$COH" 99-wrong-anchor 2>&1 || true)
  printf '%s\n' "$COH_MISS" | grep -q 'not among them' \
    || { echo "BUG [branch-coherence]: mismatch lacks the both-remedies coherence prescription"; \
         exit 1; }
  printf '' | bash "$COH" 47-governance-pair >/dev/null 2>&1 \
    || { echo "BUG [branch-coherence]: an empty closing set must pass here (it is #49's red), but" \
           "went red"; exit 1; }
  echo "  ok [branch-coherence] — NN in closing-set green, NN absent red (both remedies)," \
    "empty set defers to #49"
}

# [closing-ref] a CLOSING keyword is required, and the closing-set is parsed for coherence.
gg_closing_ref() {
  local REF REF_OUT REF_MISS
  REF=.github/scripts/check-issue-ref.sh
  REF_OUT=$(printf 'Title\nFixes #47 and Closes #49\n' | bash "$REF" 2>/dev/null) \
    || { echo "BUG [closing-ref]: a valid Fixes/Closes body was rejected"; exit 1; }
  [ "$REF_OUT" = "47 49" ] \
    || { echo "BUG [closing-ref]: closing-set mis-parsed (got '$REF_OUT', want '47 49')"; exit 1; }
  printf 'mentions #38 only\n' | bash "$REF" >/dev/null 2>&1 \
    && { echo "BUG [closing-ref]: a bare '#38' with no closing keyword was accepted"; exit 1; }
  REF_MISS=$(printf 'no anchor here\n' | bash "$REF" 2>&1 || true)   # exits non-zero by design
  printf '%s\n' "$REF_MISS" | grep -q 'no closing issue reference' \
    || { echo "BUG [closing-ref]: the missing-anchor prescription is absent"; exit 1; }
  echo "  ok [closing-ref] — closing keyword required + set parsed; bare mention and no-ref" \
    "both red"
}

# [waiver-label] the gate-waiver label greens the checks AND emits a loud, on-record line.
gg_waiver_label() {
  local WAIV WOUT WRC
  WAIV=.github/scripts/gate-waiver.sh
  set +e; WOUT=$(printf 'enhancement\ngate-waiver\n' | bash "$WAIV" "PR #0" 2>&1); WRC=$?; set -e
  [ "$WRC" -eq 0 ] \
    || { echo "BUG [waiver-label]: the gate-waiver label did not green the check (rc=$WRC)"; \
         exit 1; }
  printf '%s\n' "$WOUT" | grep -q 'GATE-WAIVER' \
    || { echo "BUG [waiver-label]: the waiver fired WITHOUT the mandatory loud log line"; exit 1; }
  printf 'enhancement\n' | bash "$WAIV" "PR #0" >/dev/null 2>&1 \
    && { echo "BUG [waiver-label]: the waiver fired with NO gate-waiver label present"; exit 1; }
  echo "  ok [waiver-label] — waiver label greens + emits the loud line; absent label does" \
    "not waive"
}

case_governance_gates() {
  gg_branch_grammar
  gg_branch_coherence
  gg_closing_ref
  gg_waiver_label
}
