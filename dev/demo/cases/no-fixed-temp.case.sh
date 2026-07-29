#!/usr/bin/env bash
# no-fixed-temp.case.sh — [no-fixed-temp] (#210): no literal system-temp path anywhere in the
# acceptance suite's own source. SOURCED by the runner; see dev/scripts/run-demo.sh.
#
# WHAT IT ASSERTS: every file the suite is made of — the runner, the tour, and every case file —
# carries no literal system-temp path. The file list comes from demo_suite_files() in the runner,
# which is derived from the cases directory rather than written out here, so adding a case file
# widens this scan on the day it lands.
#
# WHY IT SCANS ALL OF THEM AND NOT ONE FILE: the defect #210 fixed lived in the break-and-restore
# stage, which saves an agent file and later restores it from the same path. A half-fix that routes
# the SAVE through mktemp and leaves the RESTORE on a fixed name must red exactly as loudly as no
# fix at all. Those two sites now live in tour.sh rather than in the runner, so a scan aimed at a
# single file would pass straight over both. Scanning the whole suite is what keeps the reach the
# guard was written to have.
#
# WHAT IT DOES NOT ASSERT — said plainly so a pass is not read as more than it is: the pattern
# below recognises the LITERAL system temp roots and NOTHING else. A fixed out-of-tree path built
# from $HOME, $TMPDIR or ~ is the same defect class #210 exists to retire, and this stays GREEN on
# it. Widening the pattern to reach those is deliberately left as separate work rather than bolted
# on here, so what stands in its place is an honest message: the success line below names only the
# property actually measured. A guard whose message outruns its pattern is worse than no guard,
# because it teaches its reader to trust a check that was never made.
#
# SCOPE — STATED, NEVER IMPLIED: temporaries OUTSIDE the working tree. The in-tree scratch ticket
# S="estate/Tickets/999911Z-PROJ-99998", set by demo_setup in the runner, is also a hard-coded
# path this
# suite creates, and it is a NAMED, REASONED EXCLUSION rather than an oversight. It CANNOT go
# through mktemp: the product's own convention is that the machinery only sees a ticket sitting
# inside the estate's Tickets/ directory, so moving it to a temp dir would hide it from the
# validator, status and the pack builder — it would delete the thing being demonstrated. The
# pattern below is anchored to the SYSTEM TEMP ROOTS, so that in-tree relative path is outside what
# this case measures at all. There is no undocumented carve-out buried in the regex for a later
# reader to find, because a mechanical check with a hidden exclusion reads as evidence while
# proving less than it claims.
#
# Full-line comments are skipped so this block's own description is not counted as a live use. A
# trailing comment cannot smuggle one past: only a line whose FIRST non-blank character is "#" is
# skipped, and a comment creates no files, so nothing enforceable is lost.
# REVERT-PROOF: reinstate a fixed system-temp path at EITHER site in tour.sh and this reds by name.

# Each scan target must EXIST before its scan means anything: without that check a target that
# stopped resolving would make grep err, the `|| true` below would swallow the error, the result
# would come back empty and the case would report ok having read nothing — a vacuous pass, the one
# failure mode a green check cannot show you. The loop is fed by process substitution so it runs in
# THIS shell: a bare `exit 1` here really does stop the demo, which it could not do from inside a
# command substitution.
case_no_fixed_temp() {
  local nft_f nft_hits NFT_RE NFT_HITS
  echo "--- no-fixed-temp: no hard-coded system-temp path in the suite ---"
  NFT_RE='(^|[^[:alnum:]_.-])/(var/)?tmp([^[:alnum:]]|$)'
  NFT_HITS=""
  while IFS= read -r nft_f; do
    [ -f "$nft_f" ] || { echo "BUG [no-fixed-temp]: scan target not found: $nft_f"; exit 1; }
    nft_hits=$(grep -nE "$NFT_RE" "$nft_f" | grep -vE '^[0-9]+:[[:space:]]*#' || true)
    if [ -n "$nft_hits" ]; then
      NFT_HITS="${NFT_HITS}$(printf '%s\n' "$nft_hits" | sed "s#^#${nft_f}:#")"$'\n'
    fi
  done < <(demo_suite_files)
  if [ -n "$NFT_HITS" ]; then
    echo "BUG [no-fixed-temp]: hard-coded system-temp path(s) in the acceptance suite. Route every"
    echo "  temporary outside the working tree through mktemp — BOTH the save site and the" \
      "restore site:"
    printf '%s' "$NFT_HITS"
    exit 1
  fi
  echo "  ok [no-fixed-temp] — no literal system-temp path in this suite"
}
