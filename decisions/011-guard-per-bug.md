# 011 — Every bug fix ships with a regression guard (guard-per-bug)

## Context

A fix without a test proves nothing and protects nothing: the same bug can return
on the next refactor with no alarm. Worse, a fix can be claimed without the code
actually changing behaviour. The project needs a mechanical standard that a bug is
genuinely fixed and stays fixed.

## Decision

Every bug fix ships with a **regression guard that provably FAILS on the pre-fix
code** — demonstrated by reverting the fix and watching the guard go red. No bug
is "fixed" without one (project rule `G5`). The guards are the `R-NN` checks in
the demo and scripts; the demo (`run_demo.sh`) is the truth-teller that runs them
end-to-end on every push and PR.

## Consequences

Regressions are caught the moment they reappear, and a fix that does not actually
change behaviour cannot pass its own guard. The cost is that every fix carries the
extra work of authoring a revert-provable guard — which is the discipline that
makes the fix credible rather than asserted.

## Status

Accepted, foundational rule (`G5`). Exercised across the demo's guard set; recent
examples include `#35` (a portability guard) and `#86` (a demo guard proving the
git store resolves from a worktree).
