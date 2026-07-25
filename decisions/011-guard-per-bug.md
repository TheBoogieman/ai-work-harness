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

**AMENDED — READ THE PARAGRAPH ABOVE AS THE DECISION TAKEN, NOT AS THE RULE TO
OBEY.** As decided here the rule was absolute, and absolute is not what is live
at HEAD: its scope was narrowed to a behaviour change to shipped machinery, and a
closed set of exempt classes was written down (`#117`). The unqualified sentence
above is therefore false as a statement of the current rule — including about the
correction you are reading, which one of the exemptions covers and which
consequently ships no guard. Those classes are not repeated here and no reader
should look for them here: they have exactly one editable home, `CLAUDE.md` under
"Hard rules for changing this codebase", and a second telling of them in this
record is the drift a one-home fact exists to prevent (`#167`).

## Consequences

Regressions are caught the moment they reappear, and a fix that does not actually
change behaviour cannot pass its own guard. The cost is that every fix carries the
extra work of authoring a revert-provable guard — which is the discipline that
makes the fix credible rather than asserted.

## Status

Accepted, foundational rule (`G5`). Exercised across the demo's guard set; recent
examples include `#35` (a portability guard) and `#86` (a demo guard proving the
git store resolves from a worktree).

AMENDED TWICE, SUPERSEDED NEVER. `#117` amended its SCOPE — the rule reaches a
behaviour change to shipped machinery, and the classes it does not reach are
listed in their one home (see the note under Decision). `decisions/019` amended
its ENFORCEMENT — who witnesses the guard's red state, and how often. Neither
touched the substance: inside the rule's scope a guard, and its provable red,
remain mandatory.
