# 010 — Red blocks, yellow schedules, nothing self-heals

## Context

A checker that tries to be helpful by auto-fixing what it finds destroys the one
thing the harness exists to protect: an honest record. An auto-repaired log is a
fabricated log — it asserts something happened that a human never did. The system
needs a signalling law that distinguishes "stop, this is broken" from "note this,
handle it later," without ever inventing a record to make a red go away.

## Decision

**Red blocks, yellow schedules, nothing self-heals.** A `FAIL` at session start
means fix before working — apply the printed fix, or reconstruct the record from
the estate's git history; never fabricate one. `WARN`/`NOTE` means keep working
and handle the chore at the next natural boundary. A fixed record is always a
human act; the machinery observes and prescribes but never heals itself.
Late-but-true beats fiction.

## Consequences

The record can always be trusted, because nothing in the system ever writes a
record on the operator's behalf to clear a signal. The cost is that the operator
cannot delegate repair to the tool — a red genuinely stops work until a human acts
— which is the intended friction.

## Status

Accepted, foundational doctrine. See the README **When it yells** section and
`#37` (a status guard that keeps a yellow nudge from escalating into a spurious
abort).
