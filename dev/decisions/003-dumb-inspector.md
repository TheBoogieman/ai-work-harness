# 003 — The session-start validator is a dumb inspector

## Context

Something has to catch an undocumented mess before a new session builds on top of
it. The tempting design is a smart checker that understands intent, repairs small
gaps, and makes judgement calls. That design rots: it accumulates special cases,
it hides real breakage behind auto-repair, and it becomes a second source of
truth that drifts from the constitution.

## Decision

The session-start validator (`check_ticket_log.sh`) is a **dumb inspector**: it
checks facts only — was the log appended, does Current State exist, does the
index match the files on disk — and it **prescribes but never repairs**. Every
failure prints an exact fix. It forms no opinion about the quality of the work;
it only asserts that the record exists and is internally consistent.

## Consequences

The checker stays small, portable, and trustworthy — a red genuinely means a
broken record, never a checker mood. A fixed record is always a human act, which
keeps accountability with the operator. The cost is that the operator (or an
agent, on instruction) must do the repair by hand; the harness will not silently
paper over a gap.

## Status

Accepted, foundational. The inspector's fact-checks are exercised by the demo's
`R-NN` regression guards; see `#37` (guarding status against a conforming ticket
that lacks AI-Knowledge so the roster does not abort).
