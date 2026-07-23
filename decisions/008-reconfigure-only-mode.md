# 008 — In-estate re-run enters reconfigure-only mode

## Context

Re-running `install.sh` serves two genuinely different intents: reviewing or
changing an established board key / model pins, versus adding or repairing estate
files. A single undifferentiated re-run either risks re-scaffolding over a live
estate, or cannot help the operator adjust settings — and an estate has no
manifest or source to copy from, so it cannot create files from within itself.

## Decision

An `install.sh` re-run **from inside the estate** recognises the estate by its
`harness.estate` key and enters **reconfigure-only mode**: it offers the
established values as defaults and never creates files. A changed answer is WARNed
with the file to edit and an AI-assistant handoff — the installer never edits the
config itself; that stays the operator's deliberate act on the record. Completing
or repairing files is a separate intent, run from the **source checkout** targeting
the estate.

## Consequences

The two intents cannot be confused, and reconfigure never silently rewrites a
config — the change stays a recorded human act via `setup.md`. The cost is that
the operator must know which directory to run from; README documents the split
explicitly.

## Status

Accepted. See `#64` (in-estate re-run enters reconfigure-only mode) and `#62`
(source-checkout is not the estate; the source-refusal names a concrete fix).
