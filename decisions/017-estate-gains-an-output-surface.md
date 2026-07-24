# 017 — The estate gains an output surface

## Context

Everything the estate does reads the record or writes into it FOR THE MACHINERY:
tickets, logs, knowledge notes, checks, status — all of it is the machine talking to
itself so it can stay disciplined. `General AI-Knowledge/` is the purest form of that
inward surface: durable knowledge the machinery READS on later work.

End-of-cycle reviews (EOY, mid-year) exposed the missing direction. The estate holds
the whole story of a period, but offered no way to tell that story to a HUMAN in
review register — so people hand-mined months of work from memory. The record pointed
inward only; there was no surface aimed the other way.

## Decision

Add `General Human Knowledge/` — a top-level folder that MIRRORS `General
AI-Knowledge/` but points the opposite way. GAK is what the machinery reads; GHK is
what it WRITES for the human. Two mirrors, pointing opposite ways.

Its first inhabitant is `General Human Knowledge/Retrospectives/`, written by the new
`retrospective` agent. Two conventions govern the folder:

- **APPEND-ONLY.** Files are timestamped on creation and NEVER edited. This is the
  never-rewrite-the-record doctrine applied to human deliverables: a retrospective is
  a dated statement of what was true when it was written, not a living document.
- **INSIDE THE WHITELIST.** These artifacts ARE record — a review deliverable is
  worth versioning and keeping — so the folder sits inside the `.gitignore` whitelist
  and its contents are tracked, not treated as disposable scratch.

The `retrospective` agent has EXACTLY ONE WRITE DOOR: each run creates one new
timestamped file under `General Human Knowledge/Retrospectives/`, never edits an
existing file, and never writes anywhere else in the estate. That single append-only
door is the whole safety story of an agent that writes human-facing prose.

## Consequences

The estate can now speak to the human in review register, not just to itself. The
cost is a new class of output that carries estate content — ticket names, work detail,
board identifiers — into a document meant for a person's judgement. So the output
carries a standing PRIVACY LINE: it is for the human to read and weigh, and it should
be reviewed before being pasted into employer systems, review tools, or anywhere it
leaves the machine. That caution belongs to the output-surface concept itself, not
merely to one agent's prose.

Because GHK is inside the whitelist, its files auto-commit and version like any other
record; because it is append-only, history stays honest — a retrospective is never
silently rewritten after the fact.

## Status

Accepted. See `#85` (retrospective — period review agent writing to General Human
Knowledge). LINEAGE: this ADR supersedes NOTHING. It EXTENDS the estate's shape for
the first time since the original folders were laid down — a genuinely new top-level
surface, not a revision of an existing one — which is worth saying plainly.
