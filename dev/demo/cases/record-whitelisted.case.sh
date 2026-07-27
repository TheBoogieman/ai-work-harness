#!/usr/bin/env bash
# record-whitelisted.case.sh — [record-whitelisted]: the whitelist re-include
# (`!/estate/General Human Knowledge/`) must make a file dropped under estate/General Human Knowledge/
# TRACKABLE: these are record artifacts, versioned. SOURCED by the runner; see run_demo.sh.
#
# Probe: create a file there and assert `git add -A --dry-run` WOULD stage it. This is #38's
# junk-ignore method run in the OPPOSITE direction — #38 proves junk is NEVER staged, this proves
# record IS. Revert-proof: remove the `!/estate/General Human Knowledge/` line from .gitignore and the
# probe stops being staged, reddening this case. The probe is cleaned up with an explicit rm.

case_record_whitelisted() {
  local R85_PROBE R85_STAGED
  R85_PROBE="estate/General Human Knowledge/whitelist-probe"
  : > "$R85_PROBE"
  R85_STAGED=$(git add -A --dry-run 2>/dev/null \
    | grep -F 'estate/General Human Knowledge/whitelist-probe' || true)
  [ -n "$R85_STAGED" ] \
    || { echo "BUG [record-whitelisted]: a file under estate/General Human Knowledge/ would NOT be" \
           "staged — the whitelist re-include is missing or broken."; rm -f "$R85_PROBE"; \
         exit 1; }
  rm -f "$R85_PROBE"
  echo "  ok [record-whitelisted] — estate/General Human Knowledge/ is inside the whitelist (a probe" \
    "file would be staged)"
}
