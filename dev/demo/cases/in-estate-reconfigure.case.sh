#!/usr/bin/env bash
# in-estate-reconfigure.case.sh — #64: an estate re-running its OWN install.sh reaches guidance,
# not abort — and nothing previously blocked is now allowed. SOURCED by the runner.
#
# install.sh ships PRODUCT into the estate and has a real reconfigure-on-re-run feature (established
# detection + route_change). But the natural in-estate gesture (cd ~/Work && ./install.sh) has
# TARGET==SOURCE (the estate's own copy), which used to abort at the source guard BEFORE that
# feature ran — and a naive relax dies at the source-tree wall (an estate has no estate/ tree
# beneath it to copy from; before #282 the same wall was spelled as a missing ship manifest).
# The fix: a KEYED estate (harness.estate=true, #60) enters RECONFIGURE-ONLY mode — skip the
# create path entirely, run the interview + validator + status + summary. This proves it COMPLETES
# (reaches the audit, no source-tree error, no abort) and stays a DUMB CREATOR (a pre-existing file
# byte-unchanged).

ir_reconfigure_completes() {
  local G64_PROBE G64_BEFORE G64_OUT G64_AFTER
  echo "--- #64 in-estate reconfigure: keyed estate re-running its own install.sh reaches the" \
    "audit ---"
  G64_ROOT=$(mktemp -d); G64_EST="$G64_ROOT/Work"; G64_DEPLOY=$(mktemp -d)
  HARNESS_AGENT_DEPLOY_DIR="$G64_DEPLOY" bash estate/install.sh --yes "$G64_EST" >/dev/null 2>&1 \
    || { echo "BUG [reconfigure-setup]: could not build the estate fixture"; exit 1; }
  # dumb-creator witness (a pre-existing file)
  G64_PROBE="$G64_EST/AGENTS.md"; G64_BEFORE=$(cksum "$G64_PROBE")
  # Run the ESTATE'S OWN install.sh in place: TARGET defaults to $PWD == the estate == that
  # install.sh's SOURCE. Keyed -> reconfigure-only.
  set +e
  G64_OUT=$(cd "$G64_EST" && HARNESS_AGENT_DEPLOY_DIR="$G64_DEPLOY" bash install.sh --yes 2>&1)
  set -e
  echo "$G64_OUT" | grep -q 'Reconfigure mode' \
    || { echo "BUG [in-estate-reconfigure]: no reconfigure banner"; exit 1; }
  echo "$G64_OUT" | grep -q -- '--- validator ---' \
    || { echo "BUG [in-estate-reconfigure]: did not reach the validator/status audit (reconfigure" \
           "did not complete)"; exit 1; }
  # The create-path guard's own refusal, matched on the tail of its message rather than on the
  # path it names — the path is a temp dir that changes every run. That message moved from the
  # ship manifest to the source tree in #282; the assertion is the same one either way, that a
  # keyed estate never reaches the guard at all.
  if echo "$G64_OUT" | grep -qi 'run install.sh from the harness source'; then
    echo "BUG [in-estate-reconfigure]: hit the create-path source-tree guard — the create path"
    echo "    was not skipped"
    exit 1
  fi
  if echo "$G64_OUT" | grep -qi 'source distribution itself'; then
    echo "BUG [in-estate-reconfigure]: aborted at the source guard — the estate-key branch is" \
      "missing"
    exit 1
  fi
  G64_AFTER=$(cksum "$G64_PROBE")
  [ "$G64_BEFORE" = "$G64_AFTER" ] \
    || { echo "BUG [reconfigure-creates-only]: the reconfigure re-run changed a pre-existing file" \
           "($G64_PROBE)"; exit 1; }
  echo "  ok [in-estate-reconfigure] — banner + validator/status reached, no source-tree error," \
    "no abort; pre-existing file byte-unchanged"
}

# #64 block preserved: only a KEYED estate gains passage; a genuine source checkout (no key) and a
# key-stripped copy must still block with #62's concrete-fix message — nothing previously blocked
# is now allowed (additive-only).
ir_block_preserved() {
  local G64_KL G64_KLOUT G64_KLRC G64_STOUT G64_STRC
  echo "--- #64 block preserved: keyless source-in-place and key-stripped copies still refuse ---"
  G64_KL=$(mktemp -d); cp estate/install.sh "$G64_KL/install.sh"
  git -C "$G64_KL" init -q   # NO key -> a source checkout
  set +e
  G64_KLOUT=$(cd "$G64_KL" && bash install.sh --dry-run 2>&1 >/dev/null); G64_KLRC=$?
  set -e
  [ "$G64_KLRC" -ne 0 ] \
    || { echo "BUG [source-block-preserved]: a keyless source-in-place run did NOT abort —" \
           "the key test is broken open"; exit 1; }
  echo "$G64_KLOUT" | grep -qi 'source distribution itself' \
    || { echo "BUG [source-block-preserved]: keyless run aborted but not with #62's concrete-fix" \
           "message"; exit 1; }
  # strip the key from the real estate
  git -C "$G64_EST" config --unset harness.estate 2>/dev/null || true
  set +e
  G64_STOUT=$(cd "$G64_EST" && bash install.sh --dry-run 2>&1 >/dev/null); G64_STRC=$?
  set -e
  [ "$G64_STRC" -ne 0 ] \
    || { echo "BUG [source-block-preserved]: a key-stripped estate copy did NOT abort"; exit 1; }
  echo "$G64_STOUT" | grep -qi 'source distribution itself' \
    || { echo "BUG [source-block-preserved]: key-stripped run aborted but not with #62's message"; \
         exit 1; }
  echo "  ok [source-block-preserved] — keyless source-in-place and key-stripped copies still" \
    "refuse with #62's concrete-fix message"
  rm -rf "$G64_KL"
}

case_in_estate_reconfigure() {
  ir_reconfigure_completes
  ir_block_preserved
  rm -rf "$G64_ROOT" "$G64_DEPLOY"
}
