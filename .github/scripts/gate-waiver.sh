#!/usr/bin/env bash
# gate-waiver.sh — the ONE home for the maintainer escape hatch (#49 cond 3).
# Dev infrastructure under .github/; never ships (#43). Consulted by BOTH
# governance jobs (branch-naming AND pr-issue-link) and by the local demo, so
# the waiver decision — and the mandatory loud log line — are single-sourced.
#
# The waiver is the ONLY exemption path: if the PR carries the `gate-waiver`
# label, both governance checks pass green. Owner-only by construction —
# applying a label to a PR requires triage/write access on the repo, which
# outside/fork contributors do not have; so no fork author can self-waive.
#
# A waiver is NEVER silent (reviewer's attached condition): when it fires this
# prints a loud line naming the label and the PR, on the record in the CI log.
#
# Inputs: $1 = a PR reference string for the log line (e.g. "PR #53"); stdin =
# the PR's label names, one per line. Exit 0 = WAIVED (loud line emitted);
# exit 1 = not waived (caller proceeds to the real checks; no output).
WAIVER_LABEL='gate-waiver'

pr_ref="${1:-this PR}"

# Is the waiver label among the PR's labels? Exact, whole-line match so a label
# that merely contains the substring can't trip it.
if grep -qxF "$WAIVER_LABEL" 2>/dev/null; then
  echo "GATE-WAIVER: ${pr_ref} carries the '${WAIVER_LABEL}' label — governance checks WAIVED by a maintainer. Logged on the record; a silent waiver is forbidden."
  exit 0
fi
exit 1
