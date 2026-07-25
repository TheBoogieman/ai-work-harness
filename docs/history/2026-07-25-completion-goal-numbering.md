# Completion-goal numbering — closed history, 2026-07-25

This note decodes all seven of the `G1`–`G7` tags, and says plainly why two of
them were never written down in this repository. It is a record of something
finished: it is dated, it is not a live index, and it is not maintained. If you
arrived here from a tag in a commit message, an issue, or an old comment, the
table below is the whole answer — nothing has to be reconstructed to read it.

## Why a decoder exists at all

The tags are retired from live text, but they cannot be deleted from the places
that carry them permanently: commit subjects and bodies, and issue titles and
bodies. A reader doing archaeology on this repository will meet `G4` in a commit
message long after the last one has left the working tree. Retiring the tags
without leaving a dictionary would make that reader's job impossible, so the
dictionary outlives the tags on purpose.

## What the numbering was

In the project's first week the product owner set a short list of completion
goals and standing policies and filed them as GitHub issues. Each was given a
short tag of the form `GN`, and code comments, commit messages and issue text
then cited the tag rather than the issue. The numbering ran `G1` through `G7`.

It was retired because a tag is exactly the thing a reader cannot decode from the
file that uses it. Four of the goals hardened into rules that still bind every
change to this repository; those rules now have descriptive names and one home,
`CLAUDE.md`, and are cited by name. A fifth was a completion bar and it closed.
The remaining two are the pair this note had to recover from outside the
repository: one was the cross-platform goal, which was filed here as an issue and
simply never joined to its tag; the other was a deployment goal for a private
estate, which was deliberately never filed on this public board at all.

## The decoder

Each row gives the tag, the goal it named, the issue that is its permanent
record, and where the rule lives now if it is still live. Where a goal has an
issue, the wording under "what it named" is that issue's own title, quoted so
that the tag can be decoded here and nowhere else; the binding statement of each
live rule is in `CLAUDE.md` and is not repeated in this note. One goal has no
issue, by design, and so is described rather than quoted — and `G1` and `G2`
share a single entry between them, for the reason given under "The two that were
never publicly recorded" below.

| tag | what it named | issue | where it lives now |
| --- | --- | --- | --- |
| `G1` | one of a pair decoded together below: the cross-platform goal, or a deployment goal for a private estate. Which tag took which is the one thing still unrecorded. | #13 for the cross-platform goal, closed 2026-07-19; none for the other, by design | No live rule. The cross-platform commitment is the "Cross-platform" section of `CLAUDE.md`. |
| `G2` | the other of that same pair — see the `G1` row; the two are decodable only together | as above | as above |
| `G3` | "Local record repo must not bloat over months of use" | #16, closed 2026-07-19 | No live rule. It closed as delivered machinery: `_harness/scripts/harness-housekeeping.sh`, plus the repository-size nudge in `_harness/scripts/harness-status.sh`. |
| `G4` | "Every documented claim is true at HEAD or removed" | #17, closed 2026-07-19 | Live, as CLAIMS-TRUTH under "Hard rules for changing this codebase" in `CLAUDE.md`. |
| `G5` | "No bug closes without a regression guard that fails on pre-fix code" | #18, closed 2026-07-19 | Live, as GUARD-PER-BUG in `CLAUDE.md`. The rule as tagged was unqualified; the rule at HEAD is bounded and carries named exemptions, so a tagged citation is not a safe statement of the rule today. Its reasoning is `decisions/011`, and how the failing guard is witnessed was later amended by `decisions/019`. |
| `G6` | "No work-context identifiers on any public surface" | #19, closed 2026-07-19 | Live, as PUBLIC-SURFACE PRIVACY in `CLAUDE.md`. |
| `G7` | "All code commented in plain English" | #20, closed 2026-07-19 | Live, as PLAIN-ENGLISH COMMENTS in `CLAUDE.md`. |

## How the five mappings were established

Three are stated outright in a commit subject, which is the strongest evidence
available because a commit subject cannot be edited after the fact:

- `G3` is #16 — commit `9e58759`, "G3 (#16): human-run housekeeping + status
  size-nudge for the growing record repo".
- `G4` is #17 — commit `fbd6311`, "docs: claims-truth sweep — correct 10
  stale/overstated doc claims (#17, G4)".
- `G7` is #20 — commit `4dcc836`, "docs: G7 comment backfill, wave-label cleanup
  (R-17), truthify pack header (#20)".

Two rest on content plus the ordering the other three fix:

- `G5` is #18. `decisions/011` states the guard-per-bug policy and tags it `G5`;
  #18 is that policy, filed in the same batch.
- `G6` is #19. `.github/scripts/make-scratch-estate.sh` tags the
  no-work-identifiers rule `G6`; #19 is that goal.
- The three commit-attested mappings run #16 to `G3`, #17 to `G4` and #20 to
  `G7`, so the batch was numbered in issue order. That places `G5` at #18 and
  `G6` at #19, which agrees with the content evidence and contradicts nothing.

## The two that were never publicly recorded

`G1` and `G2` named two real goals, and neither tag was ever written into this
repository. That is not the same as lost, and the difference is the whole point
of this section: there is nothing here to find, so a reader who keeps searching
is searching for something that was never put here.

**One was the cross-platform goal.** It is #13, "[Goal] Cross-platform out of the
box (Windows/macOS/Linux)", closed 2026-07-19 — filed in the same first-week
batch as the other five and still readable in full. What was never written is the
single line joining a tag to it, which is why an earlier reading of the record
could find the issue and could not attach a number to it. Nothing was lost here;
a link was never made.

**The other was a deployment goal for a private estate.** It was kept off this
board on purpose. This repository is public and its history is permanent, so a
goal that could not be stated without naming a work context could not be filed
here — which is the rule now carried in `CLAUDE.md` as PUBLIC-SURFACE PRIVACY,
itself one of these same seven goals (#19). Its absence from the public record is
that rule working, not the record failing.

**What that goal was is not stated here and will not be.** A note that explained
the silence by breaking it would violate the rule it exists to document, in the
document that records that rule's existence. "A deployment goal for a private
estate" is the level of detail this note is permitted, and it is the level a
reader needs: enough to know the search is over, and nothing the silence was
protecting.

Which of the two tags took which goal is the one thing still unrecorded. Both
goals are named above, so a reader meeting either tag in old text has the pair
and can stop; assigning one number to one goal would be a guess, and this note
does not guess.

The three searches below are why the paragraphs above are safe to rely on rather
than something to re-run. Run 2026-07-25, discounting this note and the change
that added it, which necessarily name both tags:

- every tracked file at every commit reachable from every ref — zero occurrences
  of `G1` or `G2` as a standalone tag;
- every commit message — zero;
- every issue title and body — zero, apart from issue #124, which commissioned
  this note and names the range `G1` through `G7`.

Those searches measured what is written in this repository, which is all a search
of a repository can measure. They establish that no reader will ever meet `G1` or
`G2` in old text here. They do not establish that the goals were lost: the decode
above comes from contemporaneous records held outside this repository, on which
two independent sources agree. The searches and the decode do not disagree,
because they were never looking at the same thing.

## Where the tags still appear, as at this date

Permanently and beyond reach: commit subjects and bodies, and issue titles and
bodies. Issue #86's title, for one, quotes an acceptance-suite guard label with a
tag inside it.

In the working tree, and excluding this note itself: 27 occurrences across 10
tracked files — code comments, two workflow comments, two decision records, an
agent contract, the installer, and the acceptance suite's guard labels. Removing
those is #127. This note creates only the place a reader lands afterwards; it
deliberately changes none of them, because two changes editing the same tokens in
the same files would collide.

An earlier census quoted in issues #122 and #124 counted thirty-seven. That was
measured before #123 landed, which deleted the shorthand decoder from `SPEC.md`
and took the tags out of the rule statements in `CLAUDE.md`; the same count run
over the tree immediately before #123 gives thirty-eight, the one-token
difference being where the counting rule draws a token boundary rather than a
change in the text.

## For the change that removes the tags

UNOWNED, raised here because the item that wrote this note could not act on it.
The documentation gate, `.github/scripts/docs-check.sh`, names `CLAUDE.md` as the
single exemption for retired identifier shapes. No goal-tag shape is registered
in that gate today, so this note is legal where it sits. When #127 registers
`G1`–`G7` as a retired shape, that gate's exemption has to move to this note's
path in the same change, or the gate will red on the dictionary written to
satisfy it.
