# The drafting tests — closed history, 2026-07-29

This note reproduces the nineteen tests that were used to draft the items on this
project's board, in the words of the seats that produced them. It is a record of
something finished: it is dated, it is not a live index, and it is not
maintained. These are what one loop learned over one fortnight — not standing
law. Nothing in this note binds a change to this repository; the rules that do
bind one are in `CLAUDE.md`, and a reader who arrived here expecting current
doctrine should read that instead.

The distinction matters more here than it does for most dated notes. A reader
who finds a list of tests in a repository that enforces truth mechanically will
reasonably assume the list is enforced too. It is not, and it never was: there
is no detector for any test below, no registry that records which items were
drafted against them, and no check that reds when one is ignored. They were
applied by people reading them and choosing to.

## Why the list exists at all

Every test here was produced by a failure, not by foresight. That is the reason
to trust them and the reason to expect more: a distillation of what we know
decays as the reasoning fades, and a record of what we got wrong stays evidence.
**If this list looks complete, that is the list being wrong.**

Several were found by catching a check after it passed, which is worth stating
because it is the only mechanism that has reliably produced one: **a failed check
teaches nothing, because it stops you. A passing check that should have failed
teaches everything, and is only ever found by someone asking what the pass
actually proved.**

The tests below are given at the length they were written. Each carries the case
that produced it, and the case is not decoration — a test separated from its case
is an aphorism a future reader cannot apply to anything. Shortening the list was
considered and ruled against at the time the list was written down; the record of
that ruling is in the last section.

## The eleven, recorded 2026-07-25

These are the tests as they stood when the item that commissioned this note was
filed.

**1 · Blocks versus completes-incorrectly.** A dependency that would BLOCK an
item if unmet is a trap. One that would let the item COMPLETE INCORRECTLY is a
goal condition — because a blocked item stops and gets noticed, while an item
that completes incorrectly reads as done. Scope, by contrast, is a goal condition
by default; packaging stays a trap.

**2 · An action outside the repository gets its own item.** An item whose
acceptance requires something no pull request can perform — a settings change, a
deployment, a commission — will close on merge with that acceptance unmet. Split
it: the merge closes what the merge achieved, and the external act stays open
until someone does it.

**3 · Unverified has a shape.** A claim nobody can reproduce is not nothing. Do
not mint a fix for it and do not leave it in a message; mint a VERIFICATION item
whose success condition includes discovering there is no defect, recorded, with a
name on it. A negative result written down is worth more than a claim in an
archive.

**4 · A stated condition with no trigger.** A rule that is written down, correct,
and reached by no mechanism is worse than an unwritten one, because it looks
handled. When one is found, ask whether an existing derivation already computes
it — the answer is often yes — and rewrite the condition as a description of the
mechanism rather than as an instruction nobody is assigned.

**5 · Causation, not proximity.** A change that falsifies a claim elsewhere is
not finished until that claim is true, and "caused" means the claim was true
before the change and false after — a diff, not a judgement. If the falsified
file belongs to another lane, that is not a scheduling problem but evidence the
work was divided wrongly.

**6 · A check that returns a pass while the property is false is answering an
easier question than the one asked.** The tell is that the check is a lookup
where the claim is a comparison — "does the body contain the fix" instead of
"does the title describe what the body delivers"; "did the suite pass" instead of
"did the sabotage reach the guard it was aimed at". Before trusting a pass, state
the question the check actually answered and compare it to the one you meant.

*Worked example.* A document's most-read line can make a claim its content
contradicts, and the contradiction is invisible to any check that reads only the
content. An item's title offered two options its body proved were both wrong; a
check asking whether the body contained the fix passed on all four items
examined. The decision-record ruling and this case are the same defect from
opposite directions — one restated a rule it should only have identified, the
other identified a decision that had been rejected.

**7 · Validate a pattern against a known instance before trusting it wide.** A
mechanical check with the wrong pattern is not better than recall — it is recall
with a false warrant, and it reads as evidence. Run the search over something
already known to be there, confirm it finds that, then run it wide. A count
produced by an unvalidated pattern should be treated as unmeasured rather than as
a result.

**8 · A question is determinable if a measurement would settle it — not if the
answer feels like a matter of fact.** The test is not whether it reads as a
judgement call. A choice framed as policy ("who should own this document") can
dissolve entirely once two sets are counted and compared, and the framing is what
hides that. Before routing anything as a genuine choice, ask what measurement
would make the choice disappear.

**9 · An addition falsifies its neighbours, and the addition is not finished
until they are true.** A change that is entirely correct can leave an adjacent
line describing the state before it — a count, a summary, a title, a trap.
Checking that the addition landed cannot find this, because the addition did
land. **After adding, read what the addition made false.**

**10 · Determine before routing.** A question with a determinable answer must not
be handed to whoever has the least context. Do the work, then route the
recommendation — a recommendation can be overruled in one word; a question nobody
has researched cannot be resolved at all. And route decisions rather than work:
"should someone do this" is a task with its cost unstated, not a decision.

**11 · Two checks that look like a pair can cover disjoint failures.** Citation
verification proves nothing about omission; a coverage claim proves nothing about
fabrication. Neither implies the other, and a suite holding only one reads as
thorough — which is the instinct this corrects: "we already check that" is true of
a different failure. Ask what each check would still pass while the artifact was
wrong.

## The eight added later, recorded 2026-07-29

The eleven above were filed with a trap attached to them, which said in advance
that the list would have grown by the time anyone wrote it down:

> *"The list above may be incomplete by the time this is worked. Reproduce what
> is found rather than assuming the list is complete."*

It had. Everything in this section came out of a single working stretch after the
item was parked, and none of it was known when the eleven were written. That the
prediction held is itself the strongest available evidence that the eleven were
never the finished set — and that this section will be out of date too.

**12 · Run it, do not read it.** Three seats reasoned carefully about one script
and reached three different wrong conclusions; the person who *used* the
machinery corrected all three in minutes. **Reading instructions produces
confident agreement; running them produces facts.**

**13 · Check the instrument before believing the result.** A rate-limited API
returned an error object that parsed as a count. An empty home directory made a
healthy suite report six failures. A comparison harness silently compared a
commit to itself and produced a clean *"the fix changes nothing"*. **In every
case the wrong answer looked exactly like a right one.**

**14 · A seat cannot see what it is not editing.** Four wrong reports in two
batches about files outside a lane's own surface — three about the same file, from
three independent lanes. **The cleanest example was state that lived in a home
directory, in no worktree at all.** Treat any claim about an unowned file as
unmeasured.

**15 · A success-shaped response is not a success.** Twenty-five issue closures
each returned an identifier and a URL and did nothing; the enum was silently
ignored for being the wrong case. **Found by counting the board afterwards, not
by reading twenty-five replies.**

**16 · A stated intention is not an act.** A mint announced in a document and
never performed; a ruling written in a working note instead of on the item where
a lane reads. **Both looked done to their author and were invisible to everyone
else.**

**17 · A rule reaches nobody unless something carries it.** A convention was
drafted, refined twice into genuinely better wording, and **applied by nobody** —
three passes on the phrasing and zero on what would deliver it. Fixed by one line
in the brief that lanes actually read.

**18 · The seat with the least context and no stake in the machinery is the most
reliable detector.** Every overstatement this fortnight was caught by the
operator, not by either reviewing seat. **That is not a compliment — it is a fact
about where the blind spots sit**, and it argues for showing work earlier rather
than at the end.

**19 · Corrected figures are unmeasured by default.** A revision carries the
authority of a second look it has not necessarily had. **One correct figure was
revised into a wrong one, in the paragraph announcing more honest arithmetic.**

## What the tests were used for

These tests decided the shape of more than forty live items: trap-versus-goal-
condition placements, at least one item's restructuring, one item's entire
existence, and one clause folded into another. That was recorded in July 2026 and
is not recounted here; it is stated so that a reader knows the tests were applied
to real work rather than proposed.

Before this note existed they lived only in archived messages and in
conversations that end, and nothing in the repository reached them. **They were
therefore an instance of test 4** — *a stated condition with no trigger*: written
down somewhere, correct, and reached by no mechanism. That was noticed within an
hour of test 4 being named, which is the strongest available evidence that the
class is real rather than clever. This note is the fix for that one instance, and
it does not generalise: writing the tests down is not a mechanism that applies
them.

The reason the list was written down at all is the failure mode it protects
against. A restart inherits the items and not the reasoning that shaped them. The
next person drafting against a board will use instinct, and the board slowly
stops being coherent in a way no single item's review would catch.

## Which copy is canonical

The tests are reproduced in GitHub issue #206 as well as here. That duplication
was deliberate and was ruled on 2026-07-26, before this note existed, so that the
question would not be reopened by whoever noticed it later:

**This file is canonical from the moment it landed.** The issue body is a frozen
snapshot dated 2026-07-25, is not maintained against this file, and is **not a
second telling** — the reproduction in the issue exists so that the reasoning
would survive if the item were never worked. That is a survival mechanism, never
a rival home. The ruling was recorded in advance because no mechanical check
reads an issue body, so nothing would ever have raised the question; it would
have surfaced as a judgement call made months later by whoever happened to
notice, long after both seats had forgotten the duplication was on purpose.

Three things follow for a reader who finds a difference between the two.

- This file wins. The issue body was correct on 2026-07-25 and has not been
  updated since.
- The eight later tests reached the issue as a comment rather than as an edit to
  the body, so the body on its own shows eleven. Nineteen is the count, and it is
  the count only because the comment is read too.
- This note is not maintained either. If the tests grew again after 2026-07-29,
  they grew somewhere else, and the trap attached to the original eleven applies
  to this file exactly as it applied to the issue: reproduce what is found rather
  than assuming this list is complete.
