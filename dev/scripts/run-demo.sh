#!/usr/bin/env bash
# run-demo.sh — THE RUNNER of the acceptance suite (#143). It owns the shared estate the suite
# runs against, the ORDER the suite runs in, and nothing else. The suite itself is two other
# kinds of artifact, and the split is the point:
#   dev/demo/tour.sh          the STAGE-BASED TOUR — a demonstration a person watches. It
#                                  prints the six stage banners and performs the machinery a
#                                  newcomer came to see. It asserts nothing by name.
#   dev/demo/cases/*.case.sh  ONE CASE FILE PER GUARD FAMILY — the regression suite a
#                                  machine runs. Every named guard lives in exactly one of them.
# Those two serve different readers, which is why they are different files: a reader who wants to
# see the harness work reads the tour, and a reader who wants to know what is PROVEN reads the
# case file for that family. Keeping both in one artifact is what produced the file this split
# undoes.
#
# Proves the harness machinery works on THIS machine. No Copilot needed. Safe: uses temp state,
# creates+destroys one scratch ticket.
#
# NO RUNTIME IS STATED HERE, ON PURPOSE (#201). This line used to promise ~20s. Four figures have
# now been measured for the same suite on different hosts — 20, 32, 53 and 388 seconds — and none
# of them was right anywhere but where it was taken; a fifth measurement would produce a fifth
# figure and a fifth wrong comment. What a reader actually needs is the SHAPE, and the shape is
# stable: the first run on a machine is the slowest, and after that the time scales with the
# number of assertions the suite carries — which grows most batches. So that is what the front
# page and the install document say, and neither they nor this header quote a number.
#
# WHAT THIS SUITE DOES NOT KNOW (#42 decoupling, cond 2): the documentation checks that once
# lived inside it MOVED OUT to dev/scripts/docs-check.sh, and the suite carries ZERO
# documentation knowledge — doc state can never red the product demo. That separation is
# unchanged; what changed in #281 is the other side of it. docs-check.sh became a standalone
# tool with four detectors, run as a STEP on the Linux leg of .github/workflows/demo.yml — the
# repository's only workflow, and the one THIS suite is the rest of. Between them they are the
# whole merge gate: if both are green, nothing else is standing behind them.
#
# HOW A UNIT IS NAMED AND FOUND: demo_order() below prints one unit per line as "<kind>:<name>".
# "tour:<name>" calls tour_<name> in tour.sh; "case:<name>" calls case_<name>, which is defined by
# cases/<name>.case.sh. Hyphens in a name become underscores in the function. NO CASE FILE CARRIES
# AN ORDINAL PREFIX: the order is data in demo_order(), not a property of a filename, so ordering
# the suite never mints the numbered-identifier class this split exists to delete.
set -euo pipefail

# --- setup: the shared estate every unit runs against ------------------------------------------
# Assign each temp dir on its OWN line, THEN export the names. `export VAR=$(cmd)` returns export's
# own status — always 0 — so under `set -euo pipefail` a failing mktemp would leave the variable
# EMPTY and the demo would run on with an unset state dir, mis-pointing every guard beneath it.
# Split apart, the assignment's status is the script's status: a failing mktemp aborts here,
# loudly, instead of producing a silently wrong run.
#
# HARNESS_WARN_STATE_DIR is ONE global override for status's first-seen record, exported ONCE here
# so it covers EVERY harness-status invocation in this suite and every future guard for free.
# Threading an override per call site would be the wrong shape: a single missed site in a later
# wave would silently write the real estate. Individual case files may still layer a case-LOCAL
# state path on top for determinism — the global export is the SAFETY floor under all of them.
demo_setup() {
  export HARNESS_DEMO=1   # lets status treat a template-clone remote as a NOTE, not a FAIL
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$SCRIPT_DIR/../.."
  DEMO_ROOT=$PWD
  HARNESS_STATE_DIR=$(mktemp -d)
  HARNESS_AGENT_DEPLOY_DIR=$(mktemp -d)
  PACK_OUT_DIR=$(mktemp -d)
  export HARNESS_STATE_DIR HARNESS_AGENT_DEPLOY_DIR PACK_OUT_DIR
  HARNESS_WARN_STATE_DIR=$(mktemp -d)
  export HARNESS_WARN_STATE_DIR
  export HARNESS_WARN_STATE_FILE="$HARNESS_WARN_STATE_DIR/warn-aging.tsv"
  DEMO_RAN=""                                  # the case names actually executed (see Part 3 below)
  S="estate/Tickets/999911Z-PROJ-99998"; rm -rf "$S"  # the shared scratch ticket the tour builds
  demo_arm_cleanup
  demo_init_repo
}

# cleanup runs on EXIT — normal, a set -e abort, or Ctrl-C. It removes the temp dirs AND any
# estate/Tickets/ folder THIS run created but didn't tear down. Success-path teardown is explicit in
# demo_finish, but a run that DIES mid-stage used to leave scratch tickets behind (untracked, so
# git stayed clean) and the NEXT run then red-blocked at stage 1 on the leftovers — a misleading
# second failure (the "leftover-scratch-folder collision"). Snapshotting the real tickets up front
# and deleting anything not in that snapshot makes an aborted run clean up after itself, and never
# touches a pre-existing (real) ticket. DEMO_SNAPSHOT_DONE guards the window before the snapshot
# exists, so a very early death can't delete real tickets.
demo_cleanup() {
  rm -rf "$HARNESS_STATE_DIR" "$HARNESS_AGENT_DEPLOY_DIR" "$PACK_OUT_DIR" "$HARNESS_WARN_STATE_DIR"
  [ "$DEMO_SNAPSHOT_DONE" = 1 ] || return 0
  local d name
  for d in "$DEMO_ROOT/estate/Tickets"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    printf '%s\n' "$DEMO_PRE_TICKETS" | grep -Fxq "$name" || rm -rf "$d"
  done
}

# demo_arm_cleanup — install the single EXIT trap and take the pre-existing-ticket snapshot it
# reads. THIS SUITE OWNS EXACTLY ONE TRAP SLOT: a case file that needs teardown does it with an
# explicit rm on every exit path, never a second `trap ... EXIT`, which would replace this one.
demo_arm_cleanup() {
  DEMO_PRE_TICKETS=""; DEMO_SNAPSHOT_DONE=0
  trap demo_cleanup EXIT
  DEMO_PRE_TICKETS=$(for d in "$DEMO_ROOT/estate/Tickets"/*/; do [ -d "$d" ] \
    && basename "$d"; done 2>/dev/null)
  DEMO_SNAPSHOT_DONE=1
}

# demo_init_repo — a bare directory with no .git gets one, so the suite can demonstrate the git
# safety net. DID_INIT records whether THIS run created it, which is what gates the closing commit.
demo_init_repo() {
  DID_INIT=0
  git rev-parse --git-dir >/dev/null 2>&1 && return 0
  git init -q .; git add -A
  git -c user.email=demo@local -c user.name=demo commit -qm "harness: day zero"
  DID_INIT=1
}

# demo_close_commit — the suite's closing auto-commit, GATED so it only fires when the demo ITSELF
# created the repo (issue #10). In a real clone (.git already present -> DID_INIT=0) it must do
# NOTHING, so the demo never sweeps a user's uncommitted work into a "demo: pass" commit. It is a
# function so the [wip-not-absorbed] case tests THIS exact gate, not a copy that could drift.
demo_close_commit() {  # $1 = DID_INIT flag (1 iff the demo created the repo), $2 = repo dir
  local did_init="$1" repo="$2"
  [ "$did_init" -eq 1 ] || return 0                      # real clone -> skip; never absorb WIP
  git -C "$repo" add -A >/dev/null
  git -C "$repo" -c user.email=demo@local -c user.name=demo \
    commit -qm "demo: pass" >/dev/null 2>&1 || true
}

# r09_make — the SHARED conforming-ticket fixture builder, used by four case families, which is
# why it lives here rather than in one of them. It builds a ticket-bearing, validator-ready folder
# from the shipped template: copy it, rename the inner .md to the folder's OWN name, and append a
# fresh session-log entry so the watermark check passes. For non-matching names the validator
# ignores the folder, but the rename still gives ticket_bearing() a <foldername>.md to find.
r09_make() {
  local dir="$1" base; base=$(basename "$dir")
  rm -rf "$dir"; cp -r estate/Tickets/999912Z-PROJ-99999 "$dir"
  mv "$dir/999912Z-PROJ-99999.md" "$dir/$base.md"
  printf '\n## %s - r09 probe\n- exercising the ticket grammar\n' \
    "$(date +%Y%m%d%H%M%S)" >> "$dir/$base.md"
}

# --- the order, and the two sets it has to agree with ------------------------------------------
# demo_order — THE ONE READABLE HOME FOR STAGE ORDER. Every unit the suite runs, in the order it
# runs. Read it top to bottom and you have read the shape of the demo. A case file is placed by
# its line here, never by its name, which is what keeps ordinal prefixes out of the filenames.
demo_order() {
  printf '%s\n' \
    case:sed-portability \
    tour:validator \
    tour:happy-path \
    tour:corruption \
    case:index-grammar \
    tour:notebook \
    case:notebook-direct-exec \
    tour:deploy \
    case:ticket-recognition \
    case:session-clock \
    case:housekeeping \
    case:worktree-store \
    case:backfill-guards \
    case:recovery-drill \
    case:undo-drill \
    case:status-consolidation \
    case:warn-aging \
    case:roster-completes \
    case:junk-ignored \
    case:oversize-root \
    case:retro-stats \
    case:record-whitelisted \
    case:crlf-tripwire \
    tour:break-restore \
    case:no-fixed-temp \
    case:agent-invocability \
    case:skills-index \
    case:installer \
    case:worked-example \
    case:tracker-sweep \
    case:estate-key \
    case:source-refusal \
    case:in-estate-reconfigure \
    case:rehearsal-declared \
    tour:context-pack \
    case:one-pack-per-run \
    case:scrub-case-agree
}

# demo_cases_dir / demo_case_names — where case files live and what they are called. Both the
# loader and the completeness guard read the directory through these, so "what a case file is"
# has one definition and the two can never disagree about it.
demo_cases_dir() { printf '%s\n' "$DEMO_ROOT/dev/demo/cases"; }

demo_case_names() {
  local f
  for f in "$(demo_cases_dir)"/*.case.sh; do
    if [ -f "$f" ]; then basename "$f" .case.sh; fi
  done
}

# demo_suite_files — every source file the suite is made of. The [no-fixed-temp] case scans this
# list, so widening the suite by adding a case file widens that scan on the same day, with nobody
# having to remember to extend it.
demo_suite_files() {
  local f
  printf '%s\n' "$DEMO_ROOT/dev/scripts/run-demo.sh" "$DEMO_ROOT/dev/demo/tour.sh"
  for f in "$(demo_cases_dir)"/*.case.sh; do
    if [ -f "$f" ]; then printf '%s\n' "$f"; fi
  done
}

# demo_load — source the tour and every case file. Sourcing (not executing) is deliberate: the
# units share one estate, one scratch ticket and one EXIT trap, and a subprocess would see none of
# them. The shellcheck directive says the path is computed at run time; it silences no finding
# about the sourced code, which is linted in its own right as a tracked *.sh.
demo_load() {
  local f
  # shellcheck source=/dev/null
  . "$DEMO_ROOT/dev/demo/tour.sh"
  for f in "$(demo_cases_dir)"/*.case.sh; do
    if [ -f "$f" ]; then
      # shellcheck source=/dev/null
      . "$f"
    fi
  done
}

# demo_dispatch — run every unit in demo_order()'s order, and RECORD each case as it runs. The
# record is what the completeness guard reads: it is the set actually EXECUTED, not the set the
# order list claims, so a unit that is listed but never dispatched is caught too.
demo_dispatch() {
  local unit kind name fn
  while IFS= read -r unit; do
    [ -n "$unit" ] || continue
    kind=${unit%%:*}; name=${unit#*:}
    fn="${kind}_$(printf '%s' "$name" | tr '-' '_')"
    "$fn"
    # "case" is QUOTED deliberately: bare, it is the shell keyword that opens a case statement, and
    # the code-shape scanner tokenises this line the same way — an unquoted one reads as a compound
    # command that never reaches its esac, and every shape number for this file goes wrong.
    if [ "$kind" = "case" ]; then DEMO_RAN="${DEMO_RAN}${name}"$'\n'; fi
  done < <(demo_order)
}

# --- [case-completeness] — the guard a split suite cannot do without (#143 acceptance, part 3) --
# A SPLIT SUITE CAN SILENTLY RUN FEWER CASES THAN IT HAS. A case file that exists but is absent
# from demo_order() simply does not run: every remaining assertion passes, the runner reports
# success, and the suite is quietly smaller. Nothing else in this repository would notice — the
# baseline comparison catches it on the day of the split and never again, and the day someone adds
# a case file and forgets the list is months later.
#
# So the runner asserts that the set of case files it EXECUTED equals the set that EXISTS on disk,
# and names the difference in either direction. REVERT-PROOF: delete one line from demo_order()
# and this reds naming that case; add a case file without listing it and this reds naming it too.
#
# IT PRINTS NOTHING ON SUCCESS, on purpose. The suite's success lines are the acceptance evidence
# for this split and they had to stay byte-identical to the pre-split baseline, so a new ok-line
# here would have been the one difference in the comparison that proves nothing was lost. A silent
# assertion above a loud failure is an idiom this suite already uses ([one-pack-per-run] and the
# sed-portability case are the same shape); the failure is what has to be readable, and it is.
demo_completeness() {
  local ran have unrun unlisted
  ran=$(printf '%s' "$DEMO_RAN" | LC_ALL=C sort -u)
  have=$(demo_case_names | LC_ALL=C sort -u)
  unrun=$(comm -13 <(printf '%s\n' "$ran") <(printf '%s\n' "$have"))
  unlisted=$(comm -23 <(printf '%s\n' "$ran") <(printf '%s\n' "$have"))
  demo_completeness_report "$unrun" "$unlisted"
}

demo_completeness_report() {  # $1 = case files never executed, $2 = executed names with no file
  if [ -n "$1" ]; then
    echo "BUG [case-completeness]: case file(s) EXIST but the runner never executed them, so"
    echo "  every assertion they hold was silently skipped. Add each to demo_order() in"
    echo "  dev/scripts/run-demo.sh, at the point in the run where it belongs:"
    printf '%s\n' "$1" | sed 's/^/    /'
    exit 1
  fi
  if [ -n "$2" ]; then
    echo "BUG [case-completeness]: the runner executed case name(s) with no matching case file"
    echo "  under dev/demo/cases/ — the file was renamed or deleted and demo_order() in"
    echo "  dev/scripts/run-demo.sh still names the old identity:"
    printf '%s\n' "$2" | sed 's/^/    /'
    exit 1
  fi
}

# demo_finish — tear the scratch ticket down, take the gated closing commit, and say the words CI
# and the README both key on. Nothing may print between the last case and this banner.
demo_finish() {
  rm -rf "$S"
  demo_close_commit "$DID_INIT" "."   # gated: commits only if the demo created this repo (#10)
  echo; echo "ALL 6 DEMO STAGES PASSED — the machinery works. Next: README Setup to wire Copilot."
}

demo_main() {
  demo_setup
  demo_load
  demo_dispatch
  demo_completeness
  demo_finish
}

demo_main "$@"
