# 011 — Every bug fix ships with a regression guard (guard-per-bug)

## Context

A fix without a test proves nothing and protects nothing: the same bug can return
on the next refactor with no alarm. Worse, a fix can be claimed without the code
actually changing behaviour. The project needs a mechanical standard that a bug is
genuinely fixed and stays fixed.

## Decision

Every bug fix ships with a **regression guard that provably FAILS on the pre-fix
code** — demonstrated by reverting the fix and watching the guard go red. No bug
is "fixed" without one. A guard is a check that reproduces the defect it was
written for and refuses it; guards live in the acceptance demo and in the gates
that run beside it, the documentation-state gate
(`.github/scripts/docs-check.sh`) among them. The demo (`run_demo.sh`) is the
truth-teller, and CI runs them end-to-end on every push to `main` and on every
pull request whose changes can move its verdict — a documentation-only pull
request reports green without running them, on criteria whose one home is
`.github/CONTRIBUTING.md`.

AMENDED (`#117`): every telling of the rule in this record is the unqualified one
as taken; the rule live at HEAD is bounded and its exempt classes have one home,
`CLAUDE.md`. Not restated here.

## Consequences

Regressions are caught the moment they reappear, and a fix that does not actually
change behaviour cannot pass its own guard. The cost is that every fix carries the
extra work of authoring a revert-provable guard — which is the discipline that
makes the fix credible rather than asserted.

## Status

Accepted, foundational rule. Exercised across the guard set carried by the demo
and the gates beside it; recent examples include `#35` (a portability guard) and
`#86` (a demo guard proving the git store resolves from a worktree).

UNOWNED — read by the seat that made the two corrections above (`#167`, `#180`)
and deliberately NOT corrected by it, because neither was in that seat's scope.
Recorded so a later reader does not mistake unchecked text for checked text:

- The red-side proof is described here as a hand-executed revert. That
  ENFORCEMENT was amended by `decisions/019` — the sabotage runs in CI and the
  reviewer's pass became an adversarial spot-check — and this record carries no
  pointer to it, although that record names itself the routing target for
  exactly this.
- "recent examples" names `#35` and `#86`, both long past.
- The cost sentence under Consequences ("every fix carries the extra work") is
  the record's second unqualified telling of the rule. The AMENDED note under
  Decision governs it; the sentence itself was left as taken.
