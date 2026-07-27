#!/usr/bin/env bash
# governance-gates.case.sh — revert-proofs for the LOCALLY-decidable gate scripts under
# dev/scripts/ (the API existence/OPEN check is CI-only and witnessed at the seat, not here).
# SOURCED by the runner; see dev/scripts/run_demo.sh.
#
# Same shape as #38: these call the very scripts the workflow calls, so weakening a grammar or
# pattern turns the matching case RED. CWD is the repo root, so the relative paths resolve.
#
# The documentation gate is such a script, and its success-line guard lives here too, at the foot
# of this file (#252). It runs against a scratch COPY of the checkout rather than against the
# checkout itself, which is what keeps this suite's standing property intact: no document's wording
# can red the acceptance demo. The block above gg_docs_ok_lines says how that is achieved.

# [branch-grammar] the NN-slug grammar ACCEPTS the conforming set AND REJECTS the non-conforming
# set — both directions, so loosening OR tightening the regex reds this case.
gg_branch_grammar() {
  local GRAM good bad GRAM_MISS
  GRAM=dev/scripts/branch-grammar.sh
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
  COH=dev/scripts/branch-coherence.sh
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
  REF=dev/scripts/check-issue-ref.sh
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
  WAIV=dev/scripts/gate-waiver.sh
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

# [docs-gate-ok-lines] (#252) — THE DOCUMENTATION GATE NEVER PRINTS A SUCCESS LINE FOR A CHECK THAT
# FAILED, AND NEVER WITHHOLDS ONE FROM A CHECK THAT PASSED. The gate records a failure in one shared
# variable, and every detector decides whether to print its ok-line by comparing that variable
# against the value it saved before it started. While the variable was a set-once flag the
# comparison degenerated: after the first failure ANYWHERE the flag was already set, every later
# comparison read "unchanged", and the gate that enforces claims-truth announced green for checks
# that had just printed their own red, six lines apart. The same shared flag failed the other way
# round for the two ok-lines that tested it directly rather than a saved value: those detectors
# printed nothing at all when something earlier had failed, however clean their own subject was.
#
# IT PROVES A MECHANISM, NOT THIS REPOSITORY'S DOC STATE, and that is load-bearing rather than
# tidy: this suite carries no documentation knowledge and nothing a document says may red it. So
# the gate runs over a scratch COPY, and both verdicts are conditioned on what that sabotaged run
# itself printed — a detector that failed for an unrelated reason is EXCUSED, never counted. Editing
# a document therefore cannot turn this case red. What can, and should, is the fixture ceasing to
# reach a detector it aims at: that is asserted by name, because a sabotage that misses is a green
# proving nothing, which is the failure mode a guard cannot show you.

# gg_dg_tree — a scratch COPY of this checkout's tracked working-tree files, carrying its own git
# index because the gate reads its subject through git ls-files. Copying is what lets the sabotage
# below be violent without touching the tree the rest of the suite is running against. autocrlf is
# pinned off so a seat whose global git config rewrites line endings still gets a faithful copy.
gg_dg_tree() {
  local dgt_d dgt_f
  dgt_d=$(mktemp -d)
  while IFS= read -r dgt_f; do
    [ -f "$dgt_f" ] || continue
    mkdir -p "$dgt_d/$(dirname "$dgt_f")"
    cp "$dgt_f" "$dgt_d/$dgt_f"
  done < <(git ls-files)
  ( cd "$dgt_d" || exit 1
    git init -q .
    git config core.autocrlf false
    git add -A ) >/dev/null 2>&1
  printf '%s\n' "$dgt_d"
}

# gg_dg_sabotage — three edits inside the scratch tree, chosen so that ONE run of the gate exercises
# every shape of the defect at once: a failure in the FIRST detector to run, so the shared record is
# already dirty when every later one starts; failures in detectors whose ok-line is spelled
# `[ "$fail" -ne "$saved" ] || dc_ok ...`; and a failure in one spelled
# `[ "$fail" -eq "$saved" ] || return 0` above its ok-line. THOSE TWO SPELLINGS ARE THE SAME
# STATEMENT, and a guard aimed at only the first is green while the second still stands.
gg_dg_sabotage() {
  local dgs_tag
  # A shipped script the folder map cannot name, carrying a retired token family: this reds
  # map-inventory (which runs first) and no-lookup at once, and neither red depends on the wording
  # of any document. The tag is assembled at run time so this file never carries it contiguously —
  # the gate scans every tracked file, so a literal here would red the real gate on this case.
  dgs_tag=$(printf '%s%s' W 3)
  printf '#!/usr/bin/env bash\n# fixture probe, cites %s\n' "$dgs_tag" \
    > estate/_harness/scripts/zz-fixture-probe.sh
  # Narrow the demo workflow's operating-system matrix: reds ci-name-contract. Rewriting the FIRST
  # os: line, rather than matching the values it holds today, keeps this from rotting on a reword.
  awk '/^[[:space:]]*os:/ && !d { sub(/,.*/, "]"); d=1 } { print }' \
    .github/workflows/demo.yml > .sab && mv .sab .github/workflows/demo.yml
  # Copy a registered install command into README: reds install-home, which #252 names as the one
  # victim already in shipped machinery — it is what guarantees install commands have a single home.
  printf '\nbash estate/install.sh ~/Work\n' >> README.md
  git add -A >/dev/null 2>&1
}

# gg_dg_labels — the gate's printed labels, reduced to BASE TAGS. A failure prints a sub-tag after a
# colon and a success never does, so comparing the two sets by full label returns clean with the
# defect on the screen; cutting at the colon is the whole reason this comparison can see it.
# $1 = the run's output, $2 = the line kind, FAIL or ok.
gg_dg_labels() {
  printf '%s\n' "$1" | sed -n "s/^[[:space:]]*$2 \[docs \([^]]*\)\].*/\1/p" \
    | sed 's/:.*//' | sort -u
}

# gg_dg_emitters — the detectors that emit a success line AT ALL, read out of the gate's own source
# instead of listed here. A hand-written list would be a second copy of the labels, stale on the
# first rename — the very defect this repository already had to fix for its citations. Comment lines
# go first: the gate's prose names its own helpers where it explains them, and a comment is no call.
gg_dg_emitters() {
  grep -vE '^[[:space:]]*#' "$1" | grep -oE 'dc_ok[[:space:]]+("[^"]*"|[^[:space:]]+)' \
    | sed -E 's/^dc_ok[[:space:]]+//; s/"//g' | sed 's/:.*//' | sort -u
}

# gg_dg_no_false_success — direction ONE: a detector that printed a failure must not also print its
# success line in that same run. $1 = base tags that failed, $2 = base tags that printed ok.
gg_dg_no_false_success() {
  local dgn_t
  while IFS= read -r dgn_t; do
    [ -n "$dgn_t" ] || continue
    if ! printf '%s\n' "$2" | grep -qxF -- "$dgn_t"; then continue; fi
    echo "BUG [docs-gate-ok-lines]: the documentation gate printed both a FAIL and an ok line for"
    echo "  '$dgn_t' in one run — it announced green for a check that had just failed. Every"
    echo "  success line must be conditioned on that detector's OWN failures: COUNT failures in"
    echo "  dc_fail; a set-once flag makes each later comparison read as unchanged."
    exit 1
  done < <(printf '%s\n' "$1")
}

# gg_dg_no_false_suppression — direction TWO, and it fails the OPPOSITE way round. The shared record
# also SILENCED success lines: a detector whose own subject was clean printed nothing because
# something earlier in the run had failed. So every detector that emits a success line at all must,
# in this run, either have printed one or have printed a failure of its own.
# $1 = emitting detectors, $2 = base tags that failed, $3 = base tags that printed ok.
gg_dg_no_false_suppression() {
  local dgp_t
  while IFS= read -r dgp_t; do
    [ -n "$dgp_t" ] || continue
    if printf '%s\n' "$3" | grep -qxF -- "$dgp_t"; then continue; fi
    if printf '%s\n' "$2" | grep -qxF -- "$dgp_t"; then continue; fi
    echo "BUG [docs-gate-ok-lines]: '$dgp_t' neither failed nor printed its success line — another"
    echo "  detector's failure silenced it, so the run reported less than it actually checked."
    echo "  Compare against the value this detector saved before it started, never against the"
    echo "  shared record on its own."
    exit 1
  done < <(printf '%s\n' "$1")
}

# gg_dg_reached — a sabotage that misses its target proves nothing, and it proves nothing QUIETLY:
# both verdicts above are conditioned on what actually failed, so a fixture that stopped landing
# would leave them vacuously true. This names every detector the sabotage aims at, and the list
# spans BOTH ok-line spellings, so a later edit cannot narrow this case to one of them in silence.
# $1 = base tags that failed.
gg_dg_reached() {
  local dgr_want
  for dgr_want in map-inventory no-lookup install-home ci-name-contract; do
    if printf '%s\n' "$1" | grep -qxF -- "$dgr_want"; then continue; fi
    echo "BUG [docs-gate-ok-lines]: the fixture no longer reaches '$dgr_want' — it did not fail,"
    echo "  so this case would have passed without testing what it claims. Repair the sabotage in"
    echo "  gg_dg_sabotage; never drop a name from this list to make the case green."
    exit 1
  done
}

gg_docs_ok_lines() {
  local dgm_tree dgm_out dgm_rc dgm_failed dgm_oks dgm_emit dgm_here
  dgm_here=$PWD
  dgm_tree=$(gg_dg_tree)
  cd "$dgm_tree" || { echo "BUG [docs-gate-ok-lines]: no scratch tree to run in"; exit 1; }
  gg_dg_sabotage
  # The gate exits non-zero by design here, so capture rather than pipe: pipefail would otherwise
  # red the suite on a run this case NEEDS to be red. The two inputs are set EMPTY rather than left
  # unset: an unset DOCS_CHANGED_FILES sends the gate to `git diff` against a base ref this scratch
  # tree does not have. They are spelled '' because a bare `VAR=` reads to a linter as a typo.
  set +e
  dgm_out=$(DOCS_CHANGED_FILES='' PR_BODY='' bash dev/scripts/docs-check.sh 2>&1); dgm_rc=$?
  set -e
  dgm_emit=$(gg_dg_emitters dev/scripts/docs-check.sh)   # the gate that produced that output
  cd "$dgm_here" || exit 1
  rm -rf "$dgm_tree"          # every exit path below is already past the teardown
  [ "$dgm_rc" -ne 0 ] || { echo "BUG [docs-gate-ok-lines]: the sabotaged gate exited 0 — the" \
    "fixture reached nothing at all; repair gg_dg_sabotage"; exit 1; }
  dgm_failed=$(gg_dg_labels "$dgm_out" FAIL)
  dgm_oks=$(gg_dg_labels "$dgm_out" ok)
  gg_dg_reached "$dgm_failed"
  gg_dg_no_false_success "$dgm_failed" "$dgm_oks"
  gg_dg_no_false_suppression "$dgm_emit" "$dgm_failed" "$dgm_oks"
  echo "  ok [docs-gate-ok-lines] — with four detectors failing in a scratch copy, none printed a" \
    "success line for its own failure and none was silenced by another's; both ok-line spellings" \
    "covered. LIMIT: ONE run, and a detector failing for an unrelated reason is excused, not" \
    "counted."
}

case_governance_gates() {
  gg_branch_grammar
  gg_branch_coherence
  gg_closing_ref
  gg_waiver_label
  gg_docs_ok_lines
}
