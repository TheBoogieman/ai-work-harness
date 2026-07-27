#!/usr/bin/env bash
# source-refusal.case.sh — #62: installing into the source aborts AND names a concrete fix.
# SOURCED by the runner; see _harness/scripts/run_demo.sh.
#
# install.sh must refuse TARGET==SOURCE (source/estate separation is fundamental) — but the refusal
# has to PRESCRIBE, not just name the wrong. Two assertions, both revert-provable:
#   (a) install-into-source EXITS NON-ZERO (guards the abort — break the condition and it reds);
#   (b) stderr offers a runnable `bash install.sh <separate-dir>/Work` fix (revert the message ->
#       it reds).
# Fixture: a minimal SOURCE-like dir (install.sh + the manifest it reads) git-init'd with NO REMOTE.
# Isolation matters — a real checkout carries an origin remote, and install.sh's SEPARATE
# remote-refusal guard would MASK a broken source-guard (both abort), so (a) could never red. With
# no remote here, a broken source-guard falls through to the --yes --dry-run plan-and-exit-0
# (touching no disk) and (a) reds cleanly; with the guard intact, TARGET==SOURCE aborts first.

case_source_refusal() {
  local G62_SRC G62_ERR G62_RC
  echo "--- #62 source-refusal prescribes: install-into-source aborts with a concrete fix ---"
  G62_SRC=$(mktemp -d)
  cp install.sh "$G62_SRC/install.sh"
  mkdir -p "$G62_SRC/.github"; cp .github/ship-manifest.txt "$G62_SRC/.github/ship-manifest.txt"
  # a repo but with NO remote, so the remote-refusal guard cannot mask (a)
  git -C "$G62_SRC" init -q
  set +e
  G62_ERR=$(bash "$G62_SRC/install.sh" --yes --dry-run "$G62_SRC" 2>&1 >/dev/null); G62_RC=$?
  set -e
  [ "$G62_RC" -ne 0 ] \
    || { echo "BUG [source-refusal-aborts]: install.sh with TARGET==SOURCE did not exit" \
           "non-zero — the source/estate guard is broken"; exit 1; }
  # (b) match the REAL stderr against the prescriptive shape (a runnable install.sh + a Work
  # target), not a hardcoded verbatim string — the old non-prescriptive message carries no such
  # command, so it reds.
  echo "$G62_ERR" | grep -Eq 'bash install\.sh .+Work' \
    || { echo "BUG [source-refusal-prescribes]: the source-refusal abort does not prescribe a" \
           "concrete 'bash install.sh <separate-dir>/Work' fix; stderr was: $G62_ERR"; exit 1; }
  rm -rf "$G62_SRC"
  echo "  ok [source-refusal-prescribes] — install-into-source aborts (non-zero) and names a" \
    "concrete separate-dir fix"
}
