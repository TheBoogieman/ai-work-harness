# 014 — Status keeps one primary observation record

## Context

`harness-status.sh` declared, in its own header and (harder, in bold) in the
constitution, that it "prints to stdout and writes nothing to disk," on the
rationale that status output is a *derived view* and derived views are
regenerated, never kept. Issue `#71` needs status to age a parked yellow: a WARN
that has sat for months should visibly grow older. But the filesystem does not
record *when* a condition began, so aging requires remembering each WARN's
**first-seen** day — a WRITE, which contradicts the stated invariant.

An executed attack cycle on this design (by hand, before it was built) showed the
old claim bundled TWO separate properties that must be told apart:

1. **EPISTEMIC** — the printed report is a derived view, regenerated every run and
   never stored, so a *stored view* can never drift from reality.
2. **SAFETY** — running status is side-effect-free: safe in the demo, safe on any
   estate, incapable of corrupting the record.

A first-seen timestamp is a **primary observation**, not a derived view: it cannot
be recomputed from the filesystem later, and status is the only observer present
at a WARN's onset. So the two properties do NOT narrow together.

## Decision

Status keeps **exactly one** thing on disk: each active WARN's first-seen day, in
a small state file inside the estate whitelist (operator ruling 4a — the aging
record is itself part of the record). Everything status *derives* stays unstored.

- Property (1) EPISTEMIC narrows **honestly and minimally**: status stores nothing
  *derived*, and keeps exactly one *primary observation*.
- Property (2) SAFETY does **not** narrow at all. It is preserved *by
  construction*: the write is atomic (temp-file-then-rename), fails open (a write
  or read failure prints one note and never changes the verdict rc), and mutates
  only when the WARN set changes (no per-run churn, so no commit-per-run bloat).

Aging routes through **one** WARN chokepoint so every WARN class ages from a
single home (ruling 4c); the tunable tiers live as named variables at the top of
the script (ruling 4b). Yellow stays yellow — only the typographic weight
escalates, never the exit code.

Three alternative shapes were considered and **rejected**:

- **A separate writer invoked alongside status** — cosmetic purity only. The
  user-visible property (running status writes) is identical; the code has merely
  moved to a second file, at the cost of a second thing to keep in step.
- **The hook layer** — couples aging to arming. Aging must work in hook-silent
  estates (a host without the auto-commit hook), so it cannot depend on hooks
  firing.
- **Mining git history for first-seen** — the WARN predicates would have to be
  re-evaluated at historical commits (expensive and fragile), and hook-silent
  estates commit irregularly, so history is not a reliable clock for onset.

## Consequences

The invariant is now stated truthfully rather than aspirationally: status is
*side-effect-free* and keeps *one primary observation*, and the four homes of the
old "writes nothing" claim (the script header, the constitution's bold claim, the
README folder-map line, and the demo's load-bearing comment) were corrected in the
same commit as the mechanism. A parked WARN visibly ages; the `#72` knowledge
staleness sweep, being fully derived from each note's own `Last reviewed:` date,
is fenced OFF this state file (one wave, two mechanisms, exactly one writer). The
cost is one small versioned file per estate and the discipline that every future
WARN site route through the chokepoint.

## Lineage

This refines `decisions/003-dumb-inspector.md`. The dumb-inspector ADR established
that status/validation *checks facts, prescribes, and never repairs*; it did not
distinguish the epistemic claim (no stored derived view) from the safety claim (no
side effects). This ADR draws that line and narrows only the epistemic one. Per
the project's ADR convention, a refinement of an existing decision is recorded as
ONE ADR with this lineage section rather than a graveyard of superseded files; 003
stays accepted and foundational, and this ADR is read alongside it.

## Status

Accepted. Evidence: `#71` (and the `#72` knowledge staleness sweep it ships
with); the mechanism and its two attack-cycle guards (PORCELAIN, FAILS-OPEN) live
in `_harness/scripts/run_demo.sh`.
