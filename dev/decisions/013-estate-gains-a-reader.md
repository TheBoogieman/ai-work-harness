# 013 — The estate gains a reader

## Context

Every agent in the roster was a WRITER: ticket-init births the folder,
ticket-scribe appends the log, check-scribe records checks, doc-writer drafts
docs, the knowledge pair captures and promotes. The estate had no READER.
Returning to a ticket cold meant hand-reconstructing its state from raw
folders at frontier prices — the exact context-budget waste the harness exists
to prevent. Rehydration at pickup (backbone P2) is deliberately minimal and
must stay so, which left a real gap: nothing narrated a ticket cheaply and
truthfully at pickup.

## Decision

Add a seventh agent, **ticket-recall** — a cheap-tier, user-invocable,
READ-ONLY agent that narrates one ticket in fixed sections (Done / Changed /
Unresolved / Suggested next) at pickup. It reads structured sources first
(Current State, Session Log, provenance-tagged notebooks, working-file
headers), drops into `Logs/`/`Dump/` only when a structured source cites them,
and may read `git log` scoped to the ticket's paths. It writes NOTHING; the
recap is ephemeral and anything keepable flows through ticket-scribe.

Because it only reads, it has no validator behind it — a writer that invents a
record gets caught by the validation model, but a reader that invents is
caught by nothing. Its safety property is therefore **groundedness, not
validation**: every claim must trace to a named cell, entry, file, or commit,
and the contract states plainly that an embellished recap is a fabricated
record. That discipline lives in the contract because that is the only place
it can live.

## Consequences

Pickup gets a cheap, disciplined narrator, and the six-writers-no-reader
asymmetry is closed. The cost is a new failure mode that no hook can catch: a
grounded-ness violation is invisible to the machinery, so the contract's
prose is load-bearing in a way a writer's is not. The tiered-consumption rule
keeps the reader inside the context budget; a reader that bulk-read `Logs/`
would reintroduce the very cost it was built to remove.

## Status

Accepted. See `#70` (ticket-recall — invokable read-only agent narrating a
single ticket at pickup).
