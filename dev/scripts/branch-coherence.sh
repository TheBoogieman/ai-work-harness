#!/usr/bin/env bash
# branch-coherence.sh — number↔issue coherence at the merge gate (#47 cond 3).
# Dev infrastructure under .github/; never ships (#43). Single-sourced between
# the governance CI job and the local demo.
#
# RULE (membership — reviewer-ratified generalisation of the body's "equal" so
# it holds for multi-issue PRs): the branch's LEADING issue number must be a
# MEMBER of the PR's closing-issue set (the NN's from Fixes/Closes/Resolves in
# the body). If it is, the branch delivers an anchor it actually claims — ok.
# If not, the branch claims an anchor the PR doesn't deliver — RED (this is the
# wrong-issue-auto-close accident class, caught before it can happen).
#
# Inputs: $1 = branch name; stdin = the closing-issue set (whitespace-separated
# NN's, as emitted by check-issue-ref.sh — one parse, shared).

branch="${1:-}"
if [[ -z "$branch" ]]; then
  echo "branch-coherence: no branch name given (usage: branch-coherence.sh <branch> <<<'<NN list>')" >&2
  exit 2
fi

# Read the closing set from stdin and normalise to space-separated tokens.
closing_set="$(cat)"
# shellcheck disable=SC2206
set_arr=( $closing_set )

# An EMPTY closing set is #49's failure (no anchor at all), not this check's —
# reporting it here too would double-red the same PR. Pass and let the
# pr-issue-link job own that red.
if [[ ${#set_arr[@]} -eq 0 ]]; then
  exit 0
fi

# The branch's leading number is the run of digits before the first hyphen.
# (Grammar conformance is the branch-grammar.sh job's concern; here we only
# need the leading NN, which a conforming branch always has.)
branch_nn=""
[[ "$branch" =~ ^([0-9]+) ]] && branch_nn="${BASH_REMATCH[1]}"
if [[ -z "$branch_nn" ]]; then
  # No leading number to check coherence against — the grammar job already reds
  # a nameless/nonconforming branch, so don't add a second red here.
  exit 0
fi

# Membership test: is the branch's NN among the PR's closing NN's?
for nn in "${set_arr[@]}"; do
  if [[ "$nn" == "$branch_nn" ]]; then
    exit 0
  fi
done

# Miss: the branch's leading number is not in the closing set. Prescribe BOTH
# remedies (#47 cond 3) so the author picks whichever matches their intent.
{
  echo "FAIL [branch↔issue coherence]: branch '$branch' leads with #$branch_nn, but the PR body closes {${set_arr[*]}} — #$branch_nn is not among them."
  echo "  A branch must anchor to an issue the PR actually closes. Fix EITHER:"
  echo "    • add 'Fixes #$branch_nn' to the PR body (if this branch is really for #$branch_nn), or"
  echo "    • rename the branch to one of the closing issues, e.g. ${set_arr[0]}-<short-slug>, and re-push."
} >&2
exit 1
