# 015 — The tracker fetch seam is pluggable and fork-layer

## Context

After a ticket is created, the estate and the external board drift silently: a
ticket closed upstream still reads as Active locally, and nothing notices. Issue
`#81` adds `tracker_sweep.sh` — an on-demand, human-run sweep that reports that
drift. To read an upstream status the sweep must talk to *some* board, but this
repo is the public product and must ship **tracker-agnostic**: naming a real
tracker's API here would leak one deployment's board into everyone's product and
couple the harness to a vendor it has no business knowing about.

Two forces pull against each other: the sweep needs a way to fetch status, and
the product must contain no tracker-specific fetch code and make no network call
of its own.

## Decision

The sweep talks to the board through a **pluggable fetch seam**, and nothing
tracker-specific lives in this repo:

- **The fetch seam is an injected command.** `HARNESS_TRACKER_FETCH_CMD` names a
  command that maps a ticket id to its upstream status. The product ships with it
  **unset** — there is no default fetcher. Tracker-specific fetchers are
  **fork-layer** material; if code in this repo starts naming a real tracker's
  API, it has left the product.
- **The board coupling is ONE editable line.** Which status words mean "closed"
  lives in a single, user-editable line in `tracker_sweep.sh`, mirroring the
  `ticket-grammar.sh` precedent (`decisions/006-one-home-doctrine.md`): the board
  coupling has one home, not a scatter of hard-coded strings.
- **The sweep fails open.** An unreachable tracker — or no fetcher configured at
  all — yields ONE quiet NOTE and exit 0, never a red. Every finding is a yellow
  WARN or a NOTE, so the sweep never blocks and an offline estate stays fully
  functional (`decisions/010-red-blocks-yellow-schedules.md`).
- **Credentials live in the environment or a keychain at runtime.** Any token the
  fetcher needs is read at runtime by the fetcher itself; the sweep passes the
  caller's environment through and never reads, prints, or writes a token. Nothing
  in this repo — script, output, or fixture — ever holds credential material.

## Consequences

The public product stays tracker-agnostic and offline-safe: it names no vendor,
makes no network call, and works with any board a fork can write a one-line
fetcher for. The demo proves the behaviour with a local stub only, so there is
zero network in the demo path. The cost is that a real deployment must supply its
own fetcher at the fork layer — deliberate, and the same seam shape the harness
already uses to stay assistant-agnostic and board-agnostic elsewhere.

## Lineage

The **credential norm codified here is not new with `#81`.** "A token lives in
the environment or a keychain at runtime, never on disk, never in recorded output,
never in a fixture" is the implementer seat's standing, flag-first credential
practice — already in force across the harness. This ADR does not invent that
rule; it *records* it as the load-bearing constraint on the fetch seam so a
fork-layer fetcher author reads it in one place. Claiming novelty for a practice
already in force would itself be a small fabrication, so the lineage is stated
plainly: pre-existing practice, newly written down.

## Status

Accepted. Evidence: `#81`. The seam, the one-line board coupling, and the
fails-open behaviour live in `_harness/scripts/tracker_sweep.sh`; the stub-based,
zero-network, revert-provable guard lives in `_harness/scripts/run_demo.sh`.
