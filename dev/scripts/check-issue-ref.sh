#!/usr/bin/env bash
# check-issue-ref.sh — the text-level issue-linkage gate + closing-set parser
# (#49 cond 1,2). Dev infrastructure under .github/; never ships (#43).
# Single-sourced between the governance CI job and the local demo.
#
# Reads the PR title+body concatenated on stdin. PASS requires at least one
# CLOSING keyword reference — Fixes/Closes/Resolves #NN, case-insensitive, one
# or more spaces before the '#'. A bare "#38" mention is NOT enough: the anchor
# must be a CLOSING reference so the merge actually retires an issue.
#
# On success: prints the parsed closing-set (the unique NN's, space-separated)
# to STDOUT — the branch-coherence job consumes this, so the parse happens ONCE
# and both checks agree. On failure: nothing on stdout, a courteous prescription
# on stderr (worded as a welcome, not a bounce), exit 1.
#
# NOTE: existence/OPEN validation is NOT done here — it needs the GitHub API and
# lives in the governance workflow's pr-issue-link job. This script is purely the
# text gate + parser (so it is decidable offline and the demo can revert-prove it).

# The closing-keyword pattern. This is the ONE definition of "a valid anchor";
# CONTRIBUTING.md and the README/CLAUDE docs describe it and must match (G4).
CLOSING_RE='(Fixes|Closes|Resolves)[ ]+#[0-9]+'

text="$(cat)"

# Extract every closing reference, then reduce to the bare issue numbers, unique,
# preserving a stable order. grep -oiE is portable across GNU and BSD.
nns="$(printf '%s\n' "$text" | grep -oiE "$CLOSING_RE" | grep -oE '[0-9]+' | awk '!seen[$0]++' | paste -sd' ' -)"

if [[ -z "$nns" ]]; then
  {
    echo "FAIL [PR references an issue]: this PR has no closing issue reference."
    echo "  Every change on main traces to a numbered, discussable record. To anchor this PR:"
    echo "  open an issue describing the change, then add 'Fixes #NN' to this PR body — see CONTRIBUTING.md."
    echo "  (Welcome — this is how the project keeps every change reviewable, not a bounce.)"
  } >&2
  exit 1
fi

# stdout = the closing-set, for the coherence job (and for the demo to assert on).
printf '%s\n' "$nns"
exit 0
