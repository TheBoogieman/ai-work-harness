#!/usr/bin/env bash
# sabotage.sh — THE SABOTAGE HARNESS (#144). It proves that the acceptance suite's guards can
# actually FAIL. A guard that has never been watched going red is indistinguishable from a guard
# that CANNOT go red, because green is what both look like from the outside; only an executed red
# tells them apart. Until now that red was produced by one person reverting a fix by hand, off the
# record and outside continuous integration. This harness produces it on demand, in a throwaway
# copy of the repository, and reads it strictly enough that only the RIGHT red counts.
#
# WHAT ONE PROOF IS. For a guard G with a fixture F, all five of these, in order:
#   1. SANDBOX — copy every tracked file into a temp dir. Nothing below ever touches the real
#      working tree, so a fixture that mis-applies cannot leave this repository sabotaged.
#   2. APPLY, AND ASSERT IT APPLIED — snapshot the sandbox, run F, and require that F changed
#      something. A fixture that silently fails to apply would otherwise report every guard as
#      strong and turn every red-proof into a claim nobody tested.
#   3. RED, UNDER G'S OWN NAME — run the WHOLE acceptance suite. It must fail, and the FIRST
#      "BUG [label]" line it prints must name G. A red under a neighbour's label is not evidence
#      for G and is reported as WRONG-GUARD, never counted as proof.
#   4. RESTORE, ASSERTED — put the snapshot back and require the tree to come back BYTE-IDENTICAL.
#      Never assumed: a fixture that fails to restore leaves a suite permanently red, or — quieter
#      and worse — permanently sabotaged.
#   5. GREEN AGAIN, BY NAME — run the suite once more on the restored tree. It must pass AND print
#      G's own "ok [G]" line, so "the guard passes again" is witnessed rather than inferred.
# Only all five together are PROVEN. Anything else is UNPROVEN and the verdict says which.
#
# WHY THE WHOLE SUITE, AND WHY THE FIRST BUG LINE. A guard sitting behind other guards cannot be
# proven by sabotaging what it protects: an elder fires first, the suite reddens, and the pair looks
# strong while the guard under test was never reached. Running the WHOLE suite is what puts the
# elders in the way; reading the FIRST label is what tells an elder's red from the target's. Either
# half alone would score an elder's red as proof, which is the exact mistake this harness exists to
# make impossible.
#
# STEP 5 IS SKIPPED WHEN THE VERDICT IS ALREADY UNPROVEN, and that is a saving, not a weakening:
# its job is to complete a proof, and there is no proof to complete. Step 4's byte-identity
# assertion still runs on every path, so restoration is never left unchecked.
#
# FIXTURE COVERAGE IS YELLOW, NEVER RED. The harness reports which guards have a fixture and which
# do not, and that report NEVER changes the exit code. Red blocks, yellow schedules: a red on every
# guard without a fixture would block every wave until the whole backfill landed. The guard count in
# that report is DERIVED at run time from the suite's own source; no figure is carried in this file.
#
# Usage:
#   bash _harness/demo/sabotage.sh                 # coverage report, then prove every fixture
#   bash _harness/demo/sabotage.sh --coverage      # the yellow coverage report alone
#   bash _harness/demo/sabotage.sh --only <guard>  # prove one guard's fixture
#   bash _harness/demo/sabotage.sh --self-test     # PROVE THE PROVER (see sab_self_test)
# Exit 0 when every fixture that exists proved its guard, 1 when one did not. Coverage gaps never
# affect it.
#
# HOW TO ADD A FIXTURE — the contract, in ONE place. A file
# _harness/demo/sabotage/<family>.fixtures.sh defines:
#   sab_fixtures_<family>()   one TAB row per fixture:
#                             "<guard label><TAB><apply function><TAB><what it breaks>"
#   sab_selftests_<family>()  OPTIONAL, and read only by --self-test:
#                             "<guard><TAB><apply fn><TAB><pre fn or -><TAB><expected verdict>
#                              <TAB><why this case exists>"
#   every apply/pre function takes $1 = the sandbox root and edits files under it, nothing else.
# Hyphens in <family> become underscores in the function name, exactly as the suite's runner does.
#
# NOT -e ON PURPOSE: this script's whole job is to survive a failing suite and classify it. `set -e`
# would abort the harness at the first red — the one outcome it exists to read.
set -uo pipefail

SAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAB_ROOT="$(cd "$SAB_DIR/../.." && pwd)"
SAB_FIXTURE_DIR="$SAB_DIR/sabotage"
SAB_SUITE_REL="_harness/scripts/run_demo.sh"
SAB_WORK=""; SAB_SB=""; SAB_SNAP=""
SAB_VERDICT=""; SAB_DETAIL=""; SAB_CAUGHT=""
SAB_MODE="all"; SAB_ONLY=""; SAB_FAIL=0
trap 'sab_cleanup' EXIT

# sab_cleanup — one EXIT trap, one temp root. Every sandbox and log this run made lives under
# SAB_WORK, so an abort at any point (including Ctrl-C) leaves nothing behind.
sab_cleanup() { [ -n "$SAB_WORK" ] && rm -rf "$SAB_WORK"; return 0; }

# --- the suite this harness measures -------------------------------------------------------------
# sab_suite_files — the source files the acceptance suite is made of. The guard census below reads
# these, so a new case file joins the census on the day it lands with nobody having to remember.
sab_suite_files() {
  local f
  printf '%s\n' "$SAB_ROOT/$SAB_SUITE_REL" "$SAB_ROOT/_harness/demo/tour.sh"
  for f in "$SAB_ROOT"/_harness/demo/cases/*.case.sh; do
    if [ -f "$f" ]; then printf '%s\n' "$f"; fi
  done
}

# sab_guards — THE GUARD CENSUS, derived, never listed. A guard is a label the suite can report by
# name: it appears in a "BUG [label]" failure line, an "ok [label]" success line, or both. Reading
# both shapes matters — a guard that prints nothing on success (the runner's own case-completeness
# check is one) exists only in its BUG line, and a census built from ok-lines alone would not see
# it. The count this produces is measured at run time; nothing here carries a figure.
sab_guards() {
  local f
  while IFS= read -r f; do
    grep -ohE '(BUG|ok) \[[a-z0-9][a-z0-9-]*\]' "$f" 2>/dev/null || true
  done < <(sab_suite_files) | sed -E 's/^(BUG|ok) \[//; s/\]$//' | LC_ALL=C sort -u
}

# --- the fixtures ---------------------------------------------------------------------------------
sab_families() {
  local f
  for f in "$SAB_FIXTURE_DIR"/*.fixtures.sh; do
    if [ -f "$f" ]; then basename "$f" .fixtures.sh; fi
  done
}

# sab_load — source every family file. Sourcing (not executing) is what makes an apply function
# callable by name from here; the shellcheck directive says the path is computed at run time and
# silences no finding about the sourced code, which is linted as a tracked *.sh in its own right.
sab_load() {
  local f
  for f in "$SAB_FIXTURE_DIR"/*.fixtures.sh; do
    # shellcheck source=/dev/null
    if [ -f "$f" ]; then . "$f"; fi
  done
}

# sab_rows — every registered row of one KIND ("fixtures" or "selftests") across every family. A
# family that declares no self-tests simply has no such function, which is why the existence test
# is here rather than an error.
sab_rows() {
  local kind="$1" fam fn
  while IFS= read -r fam; do
    [ -n "$fam" ] || continue
    fn="sab_${kind}_$(printf '%s' "$fam" | tr '-' '_')"
    if declare -F "$fn" >/dev/null; then "$fn"; fi
  done < <(sab_families)
}

# --- the sandbox ----------------------------------------------------------------------------------
# sab_fill — copy every TRACKED file of the real repository into a fresh directory. Tracked-only is
# deliberate: it is exactly the set a fixture may sabotage, it excludes .git (so the suite's own
# `git init` inside the sandbox starts from nothing), and it leaves a developer's untracked scratch
# out of a run that would otherwise depend on it.
sab_fill() {
  local dest="$1" f
  while IFS= read -r f; do
    case "$f" in */*) mkdir -p "$dest/${f%/*}" ;; esac
    cp -p "$SAB_ROOT/$f" "$dest/$f"
  done < <(git -C "$SAB_ROOT" ls-files)
}

# sab_sandbox — a sandbox plus the snapshot the restore is later measured against. The snapshot is
# taken BEFORE the fixture runs, so it is the pristine tree by construction rather than by promise.
sab_sandbox() {
  SAB_SB="$SAB_WORK/sandbox"; SAB_SNAP="$SAB_WORK/snapshot"
  rm -rf "$SAB_SB" "$SAB_SNAP"; mkdir -p "$SAB_SB" "$SAB_SNAP"
  sab_fill "$SAB_SB"
  cp -Rp "$SAB_SB/." "$SAB_SNAP/"
}

# sab_run_suite — one full acceptance run inside the sandbox, its output captured to $1. The suite
# self-anchors on its own location, so the copy under the sandbox measures the sandbox.
sab_run_suite() {
  local rc=0
  ( cd "$SAB_SB" && bash "$SAB_SUITE_REL" ) >"$1" 2>&1 || rc=$?
  return "$rc"
}

# sab_first_bug — the label of the FIRST failure the suite reported. First, not any: the suite stops
# at its first red, and the guard that stopped it is the only one the fixture can be said to have
# reached.
sab_first_bug() {
  grep -oE 'BUG \[[a-z0-9][a-z0-9-]*\]' "$1" 2>/dev/null | head -1 \
    | sed -E 's/^BUG \[//; s/\]$//'
}

# --- the five steps -------------------------------------------------------------------------------
# sab_apply — steps 2 and 3. Sets SAB_VERDICT to PENDING only when the suite redded under the
# target guard's own name; every other outcome is a terminal UNPROVEN verdict, named.
# The "no pre function" value is the literal "-", never an empty field: `read` with IFS set to TAB
# treats a RUN of tabs as one delimiter (tab is IFS whitespace), so an empty column would silently
# shift every field after it and the harness would call the wrong function with the wrong argument.
sab_apply() {  # $1 guard, $2 apply fn, $3 pre fn ("-" for none)
  local guard="$1" applyfn="$2" prefn="$3" rc=0
  [ "$prefn" = "-" ] || "$prefn" "$SAB_SB"
  "$applyfn" "$SAB_SB"
  if [ -z "$(diff -r "$SAB_SNAP" "$SAB_SB" 2>&1)" ]; then
    SAB_VERDICT="NOT-APPLIED"
    SAB_DETAIL="the fixture changed no byte of the sandbox — it never ran"
    return 0
  fi
  sab_run_suite "$SAB_WORK/$guard.red.log" || rc=$?
  if [ "$rc" -eq 0 ]; then
    SAB_VERDICT="NOT-RED"
    SAB_DETAIL="the sabotaged suite PASSED — this guard did not catch its own fixture"
    return 0
  fi
  SAB_CAUGHT="$(sab_first_bug "$SAB_WORK/$guard.red.log")"
  if [ "$SAB_CAUGHT" != "$guard" ]; then
    SAB_VERDICT="WRONG-GUARD"
    SAB_DETAIL="the first failure was [${SAB_CAUGHT:-<no BUG label>}], not [$guard]"
    return 0
  fi
  SAB_VERDICT="PENDING"; SAB_DETAIL="first failure: [$SAB_CAUGHT]"
}

# sab_restore — step 4. The snapshot is overlaid rather than swapped in, so a file the fixture ADDED
# survives the copy and shows up in the diff instead of being silently erased by a rebuild. The
# suite's own `git init` is removed first: it is state the RUN created, not state the fixture
# touched, and dropping it lets the restore assertion be a plain whole-tree diff with no exclusions
# — the strongest shape available — and lets the confirming run start from the same conditions as
# the first.
sab_restore() {
  local residue
  rm -rf "$SAB_SB/.git"
  cp -Rp "$SAB_SNAP/." "$SAB_SB/"
  residue="$(diff -r "$SAB_SNAP" "$SAB_SB" 2>&1)"
  [ -z "$residue" ] && return 0
  SAB_VERDICT="RESTORE-FAILED"
  SAB_DETAIL="the sandbox did not come back byte-identical: $(printf '%s' "$residue" | head -3 \
    | tr '\n' ';')"
}

# sab_ok_line_bearing — does this guard print an "ok [guard]" line of its OWN anywhere in the
# suite's SOURCE? Not every guard does. Some share one ok-line with the rest of their family (the
# elder [source-refusal-aborts] is covered by its junior's line), and the runner's own
# case-completeness check prints nothing at all on success by design. Asking the source, rather than
# assuming, is what stops step 5 from reporting such a guard UNPROVEN for a property it never had.
sab_ok_line_bearing() {
  local f
  while IFS= read -r f; do
    if grep -Fq "ok [$1]" "$f"; then return 0; fi
  done < <(sab_suite_files)
  return 1
}

# sab_confirm — step 5, reached only from PENDING. For a guard that HAS an ok-line, green alone is
# not enough: its own line must be in the output, or "it passes again" would be a claim about the
# suite rather than about this guard. For a guard that has none, a green suite is the whole of the
# available evidence — so the harness accepts it and SAYS SO in the verdict, rather than either
# failing the guard for a line it was never going to print or quietly passing off the weaker basis
# as the stronger one.
sab_confirm() {
  local guard="$1" rc=0
  sab_run_suite "$SAB_WORK/$guard.green.log" || rc=$?
  if [ "$rc" -ne 0 ]; then
    SAB_VERDICT="STILL-RED"
    SAB_DETAIL="the restored suite did NOT pass (rc=$rc)"
    return 0
  fi
  if ! sab_ok_line_bearing "$guard"; then
    SAB_VERDICT="PROVEN"
    SAB_DETAIL="restored byte-identical, then GREEN again — this guard prints no ok-line of its"
    SAB_DETAIL="$SAB_DETAIL own, so a green suite is the whole of the re-pass evidence"
    return 0
  fi
  if ! grep -Fq "ok [$guard]" "$SAB_WORK/$guard.green.log"; then
    SAB_VERDICT="NO-OK-LINE"
    SAB_DETAIL="the restored suite passed but never printed its own 'ok [$guard]' line"
    return 0
  fi
  SAB_VERDICT="PROVEN"
  SAB_DETAIL="restored byte-identical, then green again WITH its own ok [$guard] line"
}

# sab_prove — the whole proof for one guard, and the only place the five steps are sequenced.
sab_prove() {  # $1 guard, $2 apply fn, $3 pre fn ("-" for none)
  SAB_VERDICT=""; SAB_DETAIL=""; SAB_CAUGHT=""
  sab_sandbox
  sab_apply "$1" "$2" "$3"
  sab_restore
  [ "$SAB_VERDICT" = "PENDING" ] && sab_confirm "$1"
  return 0
}

# --- reporting ------------------------------------------------------------------------------------
# sab_say_verdict — one guard's result, in the shape a reviewer reads. A PROVEN line NAMES the guard
# that caught the fixture; that name is what separates proof from a neighbour's red.
sab_say_verdict() {  # $1 guard, $2 what the fixture breaks
  if [ "$SAB_VERDICT" = "PROVEN" ]; then
    echo "  PROVEN   [$1] — caught by [$SAB_CAUGHT]; $SAB_DETAIL"
    echo "             fixture: $2"
    return 0
  fi
  echo "  UNPROVEN [$1] ($SAB_VERDICT) — $SAB_DETAIL"
  echo "             fixture: $2"
}

# sab_prove_row — prove one registered fixture row and fold its verdict into the exit code. An
# UNPROVEN guard among the ones this repository CLAIMS to prove is a defect, so it reds; a guard
# with no fixture at all is a coverage gap, and coverage is yellow (see sab_coverage).
sab_prove_row() {  # $1 guard, $2 apply fn, $3 what it breaks
  echo "--- proving [$1] (a full suite run that must go red, then a second that must go green) ---"
  sab_prove "$1" "$2" "-"
  sab_say_verdict "$1" "$3"
  [ "$SAB_VERDICT" = "PROVEN" ] || SAB_FAIL=1
  return 0
}

# sab_coverage — THE YELLOW REPORT. It prints what has a fixture and what does not, and it changes
# nothing: no exit code, no early return, no failure. Red blocks and yellow schedules, and a red on
# every uncovered guard would block every wave until the whole backfill finished — the failure this
# report exists to avoid rather than cause. Both numbers are counted here, from the census and the
# registry, so neither can drift from a figure written down somewhere.
sab_coverage() {
  local guards covered missing n_all n_cov
  guards="$(sab_guards)"
  covered="$(sab_rows fixtures | cut -f1 | LC_ALL=C sort -u)"
  n_all="$(printf '%s\n' "$guards" | grep -c . || true)"
  n_cov="$(printf '%s\n' "$covered" | grep -c . || true)"
  # LC_ALL=C on comm as well as on the sorts that feed it: comm compares in the AMBIENT collation,
  # so a C-sorted input read under a locale ordering hyphens differently makes it warn and, worse,
  # mis-set-difference. One collation end to end is the only version of this that is correct.
  missing="$(LC_ALL=C comm -23 <(printf '%s\n' "$guards") <(printf '%s\n' "$covered"))"
  echo "--- sabotage fixture coverage (YELLOW — this report never changes the exit code) ---"
  echo "  guards in the acceptance suite: $n_all (counted now, from the suite's own source)"
  echo "  guards with a sabotage fixture: $n_cov"
  echo "  guards still to be backfilled:  $(printf '%s\n' "$missing" | grep -c . || true)"
  printf '%s\n' "$missing" | sed 's/^/      /'
  echo "  YELLOW [fixture-coverage] — $n_cov of $n_all guards carry a fixture; the rest are"
  echo "    SCHEDULED, not blocked. Red blocks, yellow schedules."
}

# --- prove the prover -----------------------------------------------------------------------------
# sab_self_test — THE HARNESS'S OWN ACCEPTANCE, and the reason anything above can be believed. A
# harness that reports every guard as strong looks exactly like a harness that works, unless a guard
# is weakened on purpose and the harness is watched failing to call it strong. Each self-test row
# names a guard, a REAL fixture, an optional weakening of a REAL EXISTING GUARD, and the verdict the
# harness must reach. A synthetic guard written for this test would prove nothing: it could exercise
# a path the real fixtures never touch, leaving the harness honest about the synthetic case and
# crude everywhere else. So the weakened guard is one the suite actually ships.
sab_self_test() {
  local guard applyfn prefn want why
  echo "=== PROVE THE PROVER: the harness must report a weakened REAL guard as UNPROVEN ==="
  while IFS=$'\t' read -r guard applyfn prefn want why; do
    [ -n "$guard" ] || continue
    echo "--- self-test on [$guard]: expecting verdict $want ---"
    echo "    $why"
    sab_prove "$guard" "$applyfn" "$prefn"
    sab_self_check "$guard" "$want"
  done < <(sab_rows selftests)
  [ "$SAB_FAIL" -eq 0 ] && echo "SELF-TEST PASSED — the harness distinguishes a strong guard from"\
    "a weak one. It proves the HARNESS; it proves no guard."
  [ "$SAB_FAIL" -eq 0 ] || echo "SELF-TEST FAILED — every PROVEN verdict this harness prints is" \
    "now unsupported. Fix the harness before believing any of them."
  return 0
}

# sab_self_check — the assertion the self-test turns on. It demands the EXACT verdict, not merely
# "not PROVEN": a harness that reached UNPROVEN for the wrong reason (say, by failing to apply the
# fixture at all) would pass a looser test while being just as blind.
sab_self_check() {  # $1 guard, $2 expected verdict
  if [ "$SAB_VERDICT" = "$2" ]; then
    echo "  ok — the harness reported [$1] as $SAB_VERDICT: $SAB_DETAIL"
    return 0
  fi
  echo "BUG [sabotage-self-test]: with a REAL guard weakened, the harness reported [$1] as"
  echo "  '$SAB_VERDICT' but must report '$2'. A harness that cannot tell a weakened guard from a"
  echo "  strong one turns every red-proof it publishes into a claim nobody has tested."
  echo "  detail: $SAB_DETAIL"
  SAB_FAIL=1
}

# --- entry ----------------------------------------------------------------------------------------
sab_parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --coverage)  SAB_MODE="coverage" ;;
      --self-test) SAB_MODE="self-test" ;;
      --only)      SAB_MODE="only"; shift; SAB_ONLY="${1:-}" ;;
      *) echo "sabotage: unknown argument '$1' (see the usage block at the top of this file)" >&2
         exit 2 ;;
    esac
    shift
  done
  [ "$SAB_MODE" != "only" ] || [ -n "$SAB_ONLY" ] || {
    echo "sabotage: --only needs a guard label" >&2; exit 2; }
}

# sab_prove_all — every registered fixture, or the one named by --only. A --only that matches
# nothing is an error rather than a silent success: a typo must never read as a clean run.
sab_prove_all() {
  local guard applyfn what seen=0
  while IFS=$'\t' read -r guard applyfn what; do
    [ -n "$guard" ] || continue
    [ "$SAB_MODE" = "only" ] && [ "$guard" != "$SAB_ONLY" ] && continue
    seen=1
    sab_prove_row "$guard" "$applyfn" "$what"
  done < <(sab_rows fixtures)
  [ "$seen" -eq 1 ] && return 0
  echo "sabotage: no fixture matches ${SAB_ONLY:-<any guard>} — nothing was proven." >&2
  SAB_FAIL=1
}

# sab_main — each mode closes with a line that is true OF THAT MODE, and no other. A coverage-only
# run proves nothing and says nothing about proof; a self-test proves the HARNESS, not any guard,
# and closes in sab_self_test. Only the proving mode may claim guards were proven — a run that said
# "every guard was PROVEN" while applying no fixture would be precisely the false green this whole
# instrument was built to delete, printed by the instrument itself.
sab_main() {
  sab_parse_args "$@"
  SAB_WORK="$(mktemp -d)"
  sab_load
  case "$SAB_MODE" in
    coverage)  sab_coverage; return 0 ;;
    self-test) sab_self_test; return "$SAB_FAIL" ;;
  esac
  sab_coverage; echo; sab_prove_all
  echo
  [ "$SAB_FAIL" -eq 0 ] && echo "SABOTAGE HARNESS: every guard measured on this run was PROVEN."
  [ "$SAB_FAIL" -eq 0 ] || echo "SABOTAGE HARNESS: at least one guard is UNPROVEN (see above)."
  return "$SAB_FAIL"
}

sab_main "$@"
