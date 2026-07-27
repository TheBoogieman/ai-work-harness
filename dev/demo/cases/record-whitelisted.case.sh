#!/usr/bin/env bash
# record-whitelisted.case.sh — [record-whitelisted]: the whitelist re-include
# (`!/estate/`, which re-includes the whole estate tree) must make a file dropped under
# estate/General Human Knowledge/
# TRACKABLE: these are record artifacts, versioned. SOURCED by the runner; see run_demo.sh.
#
# Probe: create a file there and assert `git add -A --dry-run` WOULD stage it. This is #38's
# junk-ignore method run in the OPPOSITE direction — #38 proves junk is NEVER staged, this proves
# record IS. Revert-proof: remove the `!/estate/` line from .gitignore and the
# probe stops being staged, reddening this case. The probe is cleaned up with an explicit rm.
#
# THE PROBE ANSWERS A NARROWER QUESTION THAN THE CASE USED TO CLAIM (#270). "would this file stage"
# and "the `!/estate/` re-include is present and working" agree on every tree that HAS an ignore
# file, and diverge on exactly one tree: the tree with no ignore file at all. There, nothing is
# ignored, so the probe staged for the opposite of the reason this case exists — and the old
# success line announced a whitelist it had never looked at. The revert-proof named in the header
# is the NARROW one (delete the re-include line, the probe stops staging); the wider question —
# is the subject even there — was never asked. It is asked first now: the ignore file must exist
# and must carry the re-include line before the staging probe is allowed to conclude anything.
#
# ORDERING NOTE, because it costs something. Asserting the subject FIRST means the header's
# documented revert-proof (delete the `!/estate/` line) now reds on the line assertion rather than
# on the staging probe — the probe's own red is masked for that one fixture. That is the right
# trade: the assertion is the remedy this case was missing, and the probe is still exercised on
# every green run, because the success line below only prints when the probe actually staged.

case_record_whitelisted() {
  local R85_PROBE R85_STAGED
  # SUBJECT BEFORE CONCLUSION. Two separate reds, because they are two separate faults with two
  # different repairs: no ignore file at all, and an ignore file that has lost the re-include.
  if [ ! -f .gitignore ]; then
    echo "BUG [record-whitelisted]: .gitignore does not exist, so the whitelist re-include cannot" \
      "be checked. With no ignore file EVERY path stages, which would let the probe below pass" \
      "without the re-include existing at all. Restore .gitignore."
    exit 1
  fi
  if ! grep -Fxq '!/estate/' .gitignore; then
    echo "BUG [record-whitelisted]: .gitignore carries no '!/estate/' line — the re-include that" \
      "makes the estate tree trackable is gone. Restore it."
    exit 1
  fi
  R85_PROBE="estate/General Human Knowledge/whitelist-probe"
  : > "$R85_PROBE"
  R85_STAGED=$(git add -A --dry-run 2>/dev/null \
    | grep -F 'estate/General Human Knowledge/whitelist-probe' || true)
  [ -n "$R85_STAGED" ] \
    || { echo "BUG [record-whitelisted]: a file under the estate tree's Human Knowledge folder" \
           "would NOT be" \
           "staged — the whitelist re-include is missing or broken."; rm -f "$R85_PROBE"; \
         exit 1; }
  rm -f "$R85_PROBE"
  echo "  ok [record-whitelisted] — .gitignore carries the '!/estate/' re-include, and a probe" \
    "file under estate/General Human Knowledge/ would be staged"
}
