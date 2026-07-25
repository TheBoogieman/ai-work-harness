# Completion-goal numbering — closed history, 2026-07-25

This note decodes the `G1`–`G7` tags, and says plainly which of them the record
cannot decode. It is a record of something finished: it is dated, it is not a
live index, and it is not maintained. If you arrived here from a tag in a commit
message, an issue, or an old comment, the table below is the whole answer —
nothing has to be reconstructed to read it.

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
What the remaining two were is not recorded anywhere, and this note does not
invent it.

## The decoder

Each row gives the tag, the goal it named, the issue that is its permanent
record, and where the rule lives now if it is still live. The wording under "what
it named" is the issue's own title, quoted so that the tag can be decoded here
and nowhere else; the binding statement of each live rule is in `CLAUDE.md` and
is not repeated in this note.

| tag | what it named | issue | where it lives now |
| --- | --- | --- | --- |
| `G1` | not recorded — see "The two that are not recorded" below | — | — |
| `G2` | not recorded — see "The two that are not recorded" below | — | — |
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

## The two that are not recorded

`G1` and `G2` are not decoded here, because nothing in the record says what they
named. Three searches, run 2026-07-25 and discounting this note and the change
that added it, which necessarily name both tags:

- every tracked file at every commit reachable from every ref — zero occurrences
  of `G1` or `G2` as a standalone tag;
- every commit message — zero;
- every issue title and body — zero, apart from issue #124, which commissioned
  this note and names the range `G1` through `G7`.

So no reader will meet `G1` or `G2` in old text, and no meaning is invented for
them here. One further completion-goal issue survives from the same batch
carrying no tag anywhere — #13, cross-platform out of the box, closed
2026-07-19. Whether it held one of the two unattested numbers is not recorded,
and this note does not guess.

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
