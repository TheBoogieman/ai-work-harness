#!/usr/bin/env bash
# source-refusal.fixtures.sh — sabotage fixtures for the [source-refusal-*] guard family (#144).
# SOURCED by _harness/demo/sabotage.sh; never executed on its own. Read that file's header for the
# five steps a proof is made of and for the row formats below.
#
# WHY THIS FAMILY IS THE ONE THE HARNESS SHIPS WITH. Its two guards are a real ELDER/JUNIOR PAIR
# over a single shipped function, install.sh's guard_target_is_source():
#   [source-refusal-aborts]      install-into-source EXITS NON-ZERO.        asserted FIRST
#   [source-refusal-prescribes]  that abort names a runnable separate-dir fix.  asserted SECOND
# The junior sits BEHIND the elder in the same case, so the obvious sabotage — delete the refusal —
# reddens at the elder and says nothing whatever about the junior. That is the exact trap this
# harness exists to catch, and it is reproduced here on purpose as a self-test rather than described
# (see sr_break_everything). A family whose guards happened to be independent would have made every
# fixture narrow by accident and demonstrated nothing.
#
# HOW EACH FIXTURE IS KEPT NARROW — the property that makes it reach its own guard:
#   sr_break_abort        turns the refusal's `exit 1` into `return 0` and CHANGES NOTHING ELSE.
#                         Both message lines still print, so the junior guard's evidence is intact
#                         and the only assertion that can fail is the elder's own: does it abort.
#   sr_break_prescription deletes ONLY the second message line. The abort still fires, so the elder
#                         passes and the run reaches the junior — which is the whole point.
# Both are also narrow across the rest of the suite: guard_target_is_source() short-circuits unless
# TARGET==SOURCE, and no case before this family runs install.sh against its own directory, so
# neither fixture can red an earlier guard. The keyed-estate branch is untouched by both, which
# keeps the later [in-estate-reconfigure] family honest as well.

# sr_rewrite — the ONE door every fixture here edits through. awk to a temp file inside the sandbox
# and then mv: BSD-portable (no in-place -i, which stock macOS spells differently), and the temp
# name is under the harness's per-run sandbox, so nothing collides between concurrent runs.
sr_rewrite() {  # $1 = file to rewrite, $2 = awk program
  local target="$1" prog="$2" tmp="$1.sabotage"
  awk "$prog" "$target" >"$tmp" && mv "$tmp" "$target"
}

sr_install() { printf '%s\n' "$1/install.sh"; }
sr_case() { printf '%s\n' "$1/_harness/demo/cases/source-refusal.case.sh"; }

# THE FIXTURE for [source-refusal-aborts]. Inside guard_target_is_source() only, the abort becomes a
# fall-through. Scoped by the function's own braces rather than by line number, so it survives edits
# elsewhere in install.sh and fails loudly (as NOT-APPLIED) if the function is ever renamed.
sr_break_abort() {
  sr_rewrite "$(sr_install "$1")" '
    /^guard_target_is_source\(\) \{/ { inf = 1 }
    inf && /^\}/ { inf = 0 }
    inf && $0 == "  exit 1" { print "  return 0"; next }
    { print }
  '
}

# THE FIXTURE for [source-refusal-prescribes]. The refusal still refuses; it just stops saying what
# to do instead. This is the narrow sabotage the elder cannot see, which is why it reaches the guard
# that owns the claim.
sr_break_prescription() {
  sr_rewrite "$(sr_install "$1")" '
    /^guard_target_is_source\(\) \{/ { inf = 1 }
    inf && /^\}/ { inf = 0 }
    inf && /Pass one outside this checkout/ { next }
    { print }
  '
}

# SELF-TEST MATERIAL ONLY — neither function below is a fixture, and neither is ever used to prove a
# guard. Both exist to be run against the harness itself.

# sr_break_everything — THE OBVIOUS SABOTAGE, kept deliberately broad: the refusal returns before it
# can abort OR speak. Declared against [source-refusal-prescribes], it must NOT be accepted as proof
# of that guard, because the elder [source-refusal-aborts] catches it first. This is the worked
# example the item records, reproduced mechanically so the harness's ability to tell the two reds
# apart is measured on every run rather than remembered.
sr_break_everything() {
  sr_rewrite "$(sr_install "$1")" '
    /^guard_target_is_source\(\) \{/ { print; print "  return 0"; next }
    { print }
  '
}

# sr_weaken_prescribes — DELIBERATELY WEAKEN A REAL GUARD. The junior guard's evidence check is a
# grep for a runnable "bash install.sh <dir>/Work" fix in the refusal's stderr; this replaces that
# pattern with "." — any output at all. The guard still runs, still prints its ok-line, and can no
# longer fail. Its own fixture is then applied on top, and the harness must report the guard
# UNPROVEN.
#
# WHY THIS GUARD AND NOT THE ELDER. Weakening [source-refusal-aborts] instead would leave the suite
# red anyway: [source-block-preserved], in the later in-estate-reconfigure family, asserts the same
# abort from a different angle, so the run would stop there and the harness would answer WRONG-GUARD
# — a true verdict about a neighbour rather than the measurement wanted here. The junior's claim has
# no second holder, so weakening it leaves the entire rest of the suite honest and green, and the
# only thing the harness can be reacting to is the weakening itself.
sr_weaken_prescribes() {
  sr_rewrite "$(sr_case "$1")" '
    /grep -Eq/ && /bash install/ { sub(/bash install\\\.sh \.\+Work/, ".") }
    { print }
  '
}

# THE REGISTRY — the fixtures this family offers the harness, one TAB row each.
sab_fixtures_source_refusal() {
  printf '%s\t%s\t%s\n' \
    source-refusal-aborts sr_break_abort \
      "install.sh stops aborting on TARGET==SOURCE; both message lines still print" \
    source-refusal-prescribes sr_break_prescription \
      "the refusal still aborts but loses its runnable separate-dir fix line"
}

# THE SELF-TEST ROWS — read only by `sabotage.sh --self-test`. Columns: guard, apply fn, pre fn (the
# weakening, or "-" for none), the verdict the harness MUST reach, and why the row exists. The
# no-op column is "-" rather than blank because a blank TAB field collapses under `read`.
sab_selftests_source_refusal() {
  printf '%s\t%s\t%s\t%s\t%s\n' \
    source-refusal-prescribes sr_break_prescription sr_weaken_prescribes NOT-RED \
      "a REAL shipped guard, deliberately weakened, then given its own real fixture" \
    source-refusal-prescribes sr_break_everything - WRONG-GUARD \
      "the obvious broad sabotage: the elder [source-refusal-aborts] catches it first"
}
