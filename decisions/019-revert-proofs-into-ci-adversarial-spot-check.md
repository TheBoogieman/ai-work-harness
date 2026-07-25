# 019 — Revert-proofs automate into CI; the reviewer's red-side pass becomes adversarial fixture authorship

## Context

`decisions/011` made guard-per-bug mechanical: a defect the rule covers is not
fixed until a guard has been watched going RED against the pre-fix code. The
load-bearing part of that rule was never the guard's existence — it was somebody
having run it to failure. And that proof had nowhere mechanical to live.
Revert-proofs have never run in continuous integration, by design: CI runs the
demo forwards, over code that is supposed to work, and nothing in it reverts a
fix and demands the guard notice. So a guard that CANNOT fail ships green, joins
the demo's ok-lines, and proves nothing — because green is exactly what a
working guard looks like too. The two states are indistinguishable from the
outside, and only an executed sabotage tells them apart.

The standing law closed that gap with a human. The reviewer independently
executes every sabotage, per merge, in merge order — independence being the
whole point, since the seat that authored a guard is not a credible witness that
it can fail. The project's single reopen is the standing proof that this failure
mode is real rather than theoretical: a guard that had never been run to failure
shipped green, and the independent audit had to reopen a closed issue to say so
(`#71`).

Per-merge manual execution does not scale with the guard set, and the operator
ruled that revert-proofs automate into CI and the reviewer's red-side pass
becomes a spot-check. This record exists because the word "spot-check", left
alone, is a load-bearing ambiguity — and because a law amended in conversation
and written down phases later leaves every seat running on an unrecorded
amendment in the meantime.

## Decision

Revert-proofs move into CI. Each guard ships with a sabotage fixture; CI applies
the fixture, asserts the guard reds, restores, and asserts it greens. What was
manual becomes continuous, and every guard is exercised on every run rather than
once at its merge.

The reviewer's red-side pass becomes a SPOT-CHECK — sampled, not exhaustive. And
the residual duty is stated here precisely, because this is the clause the whole
record exists for:

**The reviewer's residual duty is ADVERSARIAL FIXTURE AUTHORSHIP. For each
sampled guard the reviewer writes a DIFFERENT sabotage from the shipped one and
checks that the guard still fails.**

Not "rerun a sample of what CI already did". Rerunning CI's own fixtures is
worth nothing: CI ran them minutes ago and will run them again on the next push.
The reviewer's sample is only worth a seat's time if what it applies is new.

The rationale is the half that is easy to lose. Each sabotage fixture is written
by the author of the guard it tests. CI applying that fixture proves the PAIR
SELF-CONSISTENT — this guard catches this sabotage — which is a strictly weaker
claim than the guard being strong. A guard that only recognises the one mutation
its author had in mind passes its own fixture forever while missing the whole
class it was commissioned to cover. So: **automation converts a MISSING check
into a SELF-GRADED one.** Both halves of that sentence are true, and only the
first is obvious. Writing a different sabotage is the only part of the old law
that CI structurally cannot inherit, because it requires a mind that did not
write the guard.

SCOPE CARVE-OUT: full-strength adversarial authorship — every guard, not a
sample — is RETAINED for the machinery items in the structure and
test-architecture phases. Those phases build the checking apparatus itself, so a
weak guard there is not one missed bug but a blind spot in the instrument that
finds bugs. Sampling and self-graded fixtures are each an acceptable reduction
in independence on ordinary work; applied together to the machinery that
everything else is checked by, the two reductions multiply rather than add.

## Consequences

What is UNCHANGED: guard-per-bug itself (`decisions/011`, project rule `G5`).
Nothing here widens or narrows what that rule covers. Red still blocks, nothing
self-heals, and the demo is still the truth-teller for the product. What changed
is only WHO executes the sabotage and HOW OFTEN — the standard of proof did not
move.

The rule's bound and its exempt classes have ONE home, `CLAUDE.md`. They are not
restated, named or paraphrased in this record.

What is GAINED: every guard is exercised on every CI run instead of once at its
merge, so a guard that decays into vacuity later is caught later, which manual
per-merge execution never did.

What is SPENT: exhaustive independent execution. That is a real loss, and the
adversarial spot-check is the deliberately partial replacement — a sample of
genuinely independent attacks in place of a full sweep of self-authored ones.
The failure mode to watch for is a reviewer who reads "spot-check" and reruns
shipped fixtures; that reviewer is doing zero work while the independence layer
still looks alive on paper. This record is the routing target for anyone who
meets the old per-merge law in an older document or an older conversation.

A worked example, which is more persuasive than the argument. The
whitelist-completeness detector — the check that every shipped file is actually
reachable on an installed estate — would have shipped VACUOUSLY GREEN. Its
reachability query is index-aware by default, so after the restructuring every
shipped file is tracked, and the detector would have reported the whole tree as
fine while an installed estate ignored all of it. It was caught only because
somebody ran it against a case it was supposed to catch. That is this record's
thesis demonstrated inside this repository, before the machinery this record
governs existed: the fixture that would have accompanied that detector was the
one its author already had in mind, and it would have passed.

## Status

Accepted; operator ruling, recorded here on the law's own issue `#118`. This
AMENDS the ENFORCEMENT of `decisions/011` (guard-per-bug) — how the red state is
witnessed and by whom — and supersedes NONE of its substance: the guard, and its
provable red, remain mandatory. It is deliberately decoupled from the
sabotage-fixture machinery it authorises, which lands several phases later; the
law is recorded first so no seat runs on an unwritten amendment in between.

UNOWNED — read by the seat that corrected the reopen citation above (`#189`) and
deliberately NOT corrected by it, because none of these was in that item's scope.
Recorded so a later reader does not mistake unchecked text for checked text:

- The gain is written in the PRESENT tense against machinery that does not exist
  at HEAD. "What is GAINED" says every guard is exercised on every CI run, and the
  Decision section says what was manual becomes continuous; no sabotage fixture,
  and no job that applies one, is tracked in this repository today — which the
  paragraph directly above concedes in the same breath. The identical class of
  present-tense CI claim was corrected in this record once already (`#180`).
- "shipped fixtures" under Consequences names an artefact no guard yet ships, so
  the failure mode it warns about cannot occur yet either.
- The interim is not disclosed anywhere. This record retires the reviewer's
  exhaustive red-side pass on the day it is accepted, while the automation meant
  to replace that pass lands later, so in between the coverage is thinner than
  under either the old law or the new one. What is SPENT is stated against the
  automated end state and never against the gap opened on the way to it.
