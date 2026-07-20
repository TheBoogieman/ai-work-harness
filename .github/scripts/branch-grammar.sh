#!/usr/bin/env bash
# branch-grammar.sh — the ONE home for the branch-naming grammar (#47 cond 1).
# Dev infrastructure: this lives under .github/ and NEVER ships to a user's
# estate (#47 cond 7 / #43). Invoked identically by the governance CI job and
# the local demo, so the grammar is single-sourced and locally revert-provable
# (mirrors the ticket-grammar.sh single-home pattern).
#
# GRAMMAR — leading issue number + lowercase kebab slug: an issue number, a
# hyphen, then one or more lowercase-alphanumeric segments joined by hyphens.
# Edit THIS line (and only this line) to retarget the rule. Accepts e.g.
# 37-status-abort-fix, 47-governance-pair. Rejects WSL-canonical (uppercase),
# Feature/Foo (slash + case), 47_governance (underscore), mixedCase.
# NO escape prefix exists (#47 cond 5 ruling: none); fork PRs are exempt from
# the red and treated as informational-only — that leniency is applied in the
# workflow, not here (this script just answers "does the name conform?").
BRANCH_RE='^[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$'

branch="${1:-}"           # $1 = the head branch name to validate
suggest_nn="${2:-}"       # $2 = optional issue number (the PR's leading Fixes #NN) for a concrete rename suggestion

# Empty input is a usage error, not a grammar miss — fail loudly so a broken
# workflow wiring can't masquerade as a conforming branch.
if [[ -z "$branch" ]]; then
  echo "branch-grammar: no branch name given (usage: branch-grammar.sh <branch> [suggested-NN])" >&2
  exit 2
fi

if [[ "$branch" =~ $BRANCH_RE ]]; then
  exit 0
fi

# Miss: emit the LITERAL remedy so nothing has to be re-derived (#47 cond 2).
# Use the passed issue number when we have it, else a <NN> placeholder the
# author fills from their Fixes #NN. The slug is the author's to choose.
nn="${suggest_nn:-<NN>}"
{
  echo "FAIL [branch-name grammar]: '$branch' does not match the required NN-slug grammar."
  echo "  Expected: <issue-number>-<lowercase-kebab-slug>  (regex: $BRANCH_RE)"
  echo "  Examples: 37-status-abort-fix, 47-governance-pair"
  echo "  Fix — rename the branch and re-push (local naming stays free; the merge gate is the law):"
  echo "    git branch -m '$branch' ${nn}-<short-slug>"
  echo "    git push origin :'$branch' ${nn}-<short-slug>"
} >&2
exit 1
