#!/usr/bin/env bash
# rehearsal-declared.case.sh — [rehearsal-*] and [deploy-*] (#304): a rehearsal install has to SAY
# SO, and the live agent directory refuses a deploy from an estate other than the one recorded as
# owning it. SOURCED by the runner; see dev/scripts/run-demo.sh.
#
# WHAT THIS FAMILY IS ABOUT. A rehearsal install and a real install were the same command, so the
# only thing keeping practice runs out of a person's live assistant configuration was every caller
# remembering to redirect the deploy target. One forgot, and fixture-pinned agent contracts —
# carrying a model pin the product never ships and the path of a script that exists under no name —
# were written into a real ~/.copilot/agents. The four guards below cover the two halves of the fix:
#   * the DECLARATION: `install.sh --rehearsal` confines every out-of-estate write to the target.
#   * the OWNERSHIP RULE that does not depend on anyone remembering the declaration —
#     THE FIRST DEPLOY ON A MACHINE CLAIMS IT; EVERY LATER ONE MUST PROVE IT OWNS IT.
# The second is the one that matters, because the first is only as good as the caller's memory —
# which is precisely what failed.
#
# HOW "LEAVES NOTHING IN A HOME DIRECTORY" IS MEASURED, since a claim like that is easy to assert
# and easy to fake: the rehearsal runs with HOME pointed at an EMPTY directory this case created,
# and the assertion is that the directory is still empty afterwards. Not "no .copilot appeared" —
# empty, so a write to any name at all reds. install.sh needs nothing from a home directory (it
# passes its git identity inline with -c), so an empty HOME is a faithful stand-in for a real one.

# rd_home_run — one install run under a private, EMPTY home. Echoes nothing; the caller inspects
# the directories afterwards. `set +e` around the run because a non-zero install is a thing some
# guard below may want to assert on rather than abort at.
#
# THE TWO REDIRECTS ARE STRIPPED FROM THE ENVIRONMENT, and that is the whole reason this helper
# exists rather than a bare call. The runner exports HARNESS_AGENT_DEPLOY_DIR and HARNESS_STATE_DIR
# globally, as the safety floor under every other unit — so a guard here that simply ran install.sh
# would measure the suite's own redirect and never the product's default, which is the only thing
# this family is about. It cost a red on CI and a green locally to find that, since a case file run
# on its own inherits neither. `env -u` rather than a subshell `unset` because the variables must be
# absent from the CHILD's environment, and it is the same spelling on GNU and BSD.
# $1 = the private HOME, $2.. = install.sh's own arguments.
rd_home_run() {
  local rd_home="$1"; shift
  set +e
  env -u HARNESS_AGENT_DEPLOY_DIR -u HARNESS_STATE_DIR HOME="$rd_home" \
    bash estate/install.sh "$@" >"$RD_OUT" 2>&1
  RD_RC=$?
  set -e
  return 0
}

# rd_dir_empty — "this directory contains nothing at all", dotfiles included. `ls -A` rather than a
# glob because a glob under `set -u` cannot see dotfiles without shopt, and the whole point of the
# assertion is that a write to ANY name counts.
rd_dir_empty() {
  [ -z "$(ls -A "$1" 2>/dev/null)" ]
}

# (1) [rehearsal-confined] — a declared rehearsal writes nothing outside its own target.
# REVERT-PROOF: delete either export in confine_rehearsal (or the confine_rehearsal call in main)
# and the private home gains .copilot/ or .harness/ -> this reds naming what appeared.
rd_confined() {
  local rd_est rd_home rd_left
  rd_est="$RD_TMP/rehearsed"; rd_home="$RD_TMP/home"; mkdir -p "$rd_home"
  rd_home_run "$rd_home" --rehearsal --yes "$rd_est"
  [ "$RD_RC" -eq 0 ] \
    || { echo "BUG [rehearsal-confined]: --rehearsal install exited rc=$RD_RC; its output was:"; \
         sed 's/^/    /' "$RD_OUT"; exit 1; }
  rd_dir_empty "$rd_home" || {
    rd_left=$(ls -A "$rd_home" | tr '\n' ' ')
    echo "BUG [rehearsal-confined]: a REHEARSAL wrote into the home directory. It left: $rd_left"
    echo "  Everything the installer writes outside the estate must be redirected under"
    echo "  TARGET/_rehearsal/ by confine_rehearsal in estate/install.sh."; exit 1; }
  [ -d "$rd_est/_rehearsal/agents" ] \
    || { echo "BUG [rehearsal-confined]: the home directory is clean but the agents went nowhere" \
           "— $rd_est/_rehearsal/agents does not exist, so the run confined the deploy by" \
           "SKIPPING it rather than redirecting it, and the rehearsal proved nothing"; exit 1; }
  grep -q 'REHEARSAL: this run is practice' "$RD_OUT" \
    || { echo "BUG [rehearsal-confined]: the run never SAID it was a rehearsal — the banner is" \
           "half the mechanism, because a person who typed the flag by accident finds out here"; \
         exit 1; }
  echo "  ok [rehearsal-confined] — --rehearsal left an empty HOME untouched; agents and stamps" \
    "landed under the target's _rehearsal/"
}

# (2) [rehearsal-default-unsafe] — THE HONEST HALF, and it matters MORE now that the unrecorded-
# contracts arm is gone, not less. Without the flag, the very same command deploys straight into the
# home directory. This asserts that behaviour rather than deploring it: the installer's default MUST
# reach the live directory or an install is useless, so the safety cannot live in this flag. It is
# here so no later reader mistakes --rehearsal for the protection.
rd_default_reaches_home() {
  local rd_est rd_home
  rd_est="$RD_TMP/real"; rd_home="$RD_TMP/home-real"; mkdir -p "$rd_home"
  rd_home_run "$rd_home" --yes "$rd_est"
  [ -f "$rd_home/.copilot/agents/doc-writer.agent.md" ] \
    || { echo "BUG [rehearsal-default-unsafe]: a plain install did NOT reach the live agent" \
           "directory. That is not a safety improvement, it is a broken install — the default" \
           "target is correct and must stay."; exit 1; }
  echo "  ok [rehearsal-default-unsafe] — an undeclared run still deploys to HOME, which is why" \
    "the ownership rule below is where the protection lives"
}

# (3) [deploy-claims-unrecorded] — THE FIRST HALF OF THE RULE: the first deploy on a machine CLAIMS
# it. A directory holding contracts that no record accounts for is deployed into, silently, rc 0 —
# and the record is written on the way through, which is what arms the ownership test for every
# deploy after this one.
#
# THIS GUARD REPLACED ITS OWN OPPOSITE, and saying so is part of its job. It used to assert that
# such a directory was REFUSED — the arm that would have caught the original accident — and that arm
# was removed on an operator ruling of NO FRICTION DURING AN ESTATE'S INSTALLATION. A guard
# asserting a refusal that no longer happens can never red, so it went with the arm rather than
# being left behind as a green that measures nothing.
# REVERT-PROOF: restore the unrecorded-contracts arm in deploy-agents.sh and this reds on rc 3.
rd_claims_unrecorded() {
  local rd_est rd_live rd_rc
  rd_est="$RD_TMP/rehearsed"          # the estate guard (1) built; its scripts are what we run
  rd_live="$RD_TMP/live-unrecorded"; mkdir -p "$rd_live"
  # A contract of unknown provenance, standing in for what was actually found on the machine: a
  # real filename carrying a fixture's contents.
  printf 'model: NOT-A-REAL-PIN\n' > "$rd_live/doc-writer.agent.md"
  set +e
  HARNESS_AGENT_DEPLOY_DIR="$rd_live" \
    bash "$rd_est/_harness/scripts/deploy-agents.sh" >/dev/null 2>&1
  rd_rc=$?
  set -e
  [ "$rd_rc" -eq 0 ] \
    || { echo "BUG [deploy-claims-unrecorded]: deploying into a directory whose contracts no" \
           "record accounts for returned rc=$rd_rc, not 0. An estate's installation must meet no" \
           "friction — the ownership test arms on the RECORD, never on the contracts."; exit 1; }
  cmp -s "$rd_est/_agents/doc-writer.agent.md" "$rd_live/doc-writer.agent.md" \
    || { echo "BUG [deploy-claims-unrecorded]: rc was 0 but the contract was not replaced — the" \
           "deploy reported success without deploying"; exit 1; }
  [ "$(head -n1 "$rd_live/.deployed-from" 2>/dev/null)" = "$rd_est" ] \
    || { echo "BUG [deploy-claims-unrecorded]: the deploy claimed the directory but wrote no" \
           "record naming itself, so nothing is owned and the gate can never fire again. The" \
           "record reads:" \
           "$(head -n1 "$rd_live/.deployed-from" 2>/dev/null || echo '<absent>')"; exit 1; }
  echo "  ok [deploy-claims-unrecorded] — unaccounted-for contracts are claimed without friction," \
    "and the claim is recorded"
}

# (4) [deploy-owner-enforced] — THE SECOND HALF OF THE RULE: every deploy after the first must prove
# it owns the directory. The owning estate is silent forever after; a DIFFERENT estate refuses with
# the contract left intact; and the declared hand-off is the way past, taking ownership with it. One
# guard over the record's three consequences, because they are one fact read three ways.
# REVERT-PROOF: stop writing .deployed-from and the owner's next deploy reds; drop the
# owner-mismatch test and the foreign deploy returns 0 -> reds.
rd_owner_enforced() {
  local rd_est rd_other rd_live rd_rc
  rd_est="$RD_TMP/rehearsed"; rd_other="$RD_TMP/real"
  rd_live="$RD_TMP/live-unrecorded"   # guard (3) left this recorded as $rd_est's
  HARNESS_AGENT_DEPLOY_DIR="$rd_live" bash "$rd_est/_harness/scripts/deploy-agents.sh" \
    >/dev/null 2>&1 \
    || { echo "BUG [deploy-owner-enforced]: the OWNING estate was refused on its next deploy —" \
           "the claim must be recorded, or the rule stops being true after its first word"; \
         exit 1; }
  set +e
  HARNESS_AGENT_DEPLOY_DIR="$rd_live" bash "$rd_other/_harness/scripts/deploy-agents.sh" \
    >/dev/null 2>&1
  rd_rc=$?
  set -e
  [ "$rd_rc" -eq 3 ] \
    || { echo "BUG [deploy-owner-enforced]: a DIFFERENT estate deployed into a directory recorded" \
           "as another estate's and got rc=$rd_rc instead of the refusal (3) — the record is" \
           "written but nothing reads it"; exit 1; }
  cmp -s "$rd_est/_agents/doc-writer.agent.md" "$rd_live/doc-writer.agent.md" \
    || { echo "BUG [deploy-owner-enforced]: it printed a refusal but OVERWROTE the contract" \
           "anyway — a refusal that writes is worse than no refusal, because the message says the" \
           "opposite of what happened"; exit 1; }
  HARNESS_AGENT_ADOPT=1 HARNESS_AGENT_DEPLOY_DIR="$rd_live" \
    bash "$rd_other/_harness/scripts/deploy-agents.sh" >/dev/null 2>&1 \
    || { echo "BUG [deploy-owner-enforced]: an ADOPTING deploy was still refused — the" \
           "declaration is the way past the refusal and must always work"; exit 1; }
  [ "$(head -n1 "$rd_live/.deployed-from")" = "$rd_other" ] \
    || { echo "BUG [deploy-owner-enforced]: the adoption deployed but did not take ownership, so" \
           "the new owner would be refused on its own next run"; exit 1; }
  echo "  ok [deploy-owner-enforced] — owner silent, foreign estate refused with the contract" \
    "intact, adoption hands ownership over"
}

case_rehearsal_declared() {
  echo "--- #304 rehearsal-declared: a rehearsal has to say so; the first deploy claims the live" \
    "agent dir and every later one must own it ---"
  RD_TMP=$(mktemp -d); RD_OUT="$RD_TMP/install.out"; RD_RC=0
  rd_confined
  rd_default_reaches_home
  rd_claims_unrecorded
  rd_owner_enforced
  rm -rf "$RD_TMP"
}
