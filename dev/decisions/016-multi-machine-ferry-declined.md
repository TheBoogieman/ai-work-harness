# 016 — Multi-machine sync declined; the sole egress is a hand-carried sealed bundle

## Context

The estate lives on one machine, and `decisions/001-local-only-no-remote.md`
makes that load-bearing: the git repo is local-only and never gets a remote,
because a remote is a permanent exfiltration risk. But a real design question
stands beside that law: when a person keeps a second estate on another machine,
the record is local-only by law and there is no sanctioned way to carry it
across. `#77` posed exactly this — could sealed `git bundle` snapshots, ferried
through user-controlled storage, provide sync *without* a live remote and
*without* opening the wall the no-remote law defends?

## Decision

No remote, and no syncing two machines — ever. The sole sanctioned egress is a
**human-carried, symmetrically encrypted bundle** with an **interactive
passphrase**, produced at the user's own judgement. **No ferry tool ships now**,
because no second live estate exists to need one — and an unused ferry is
untested, safety-critical code sitting in the manifest pretending to work. The
mechanism is declined; the reasoning is recorded so it is not re-fought from
scratch at a future remint.

Findings that stand on the record:

- **Continuous two-machine sync is declined on doctrine, not on difficulty.** A
  ferry that merges is a ferry that *decides*, and nothing in this estate
  self-heals or decides. That holds independent of the no-remote law — even with
  a remote, an auto-merging sync would violate the harness's deepest rule.
- **The only surviving shape is one-way, boundary-triggered, and
  human-invoked** — a snapshot pushed out at a moment a person chooses, never a
  background reconciliation.
- **The passphrase is interactive — no argument, no environment variable, never
  on disk.** It is two things at once: the credential norm satisfied on a
  machine the key was never on (the human carries the passphrase, not a file),
  and the automation brake (a scheduler cannot type one). The answer to
  automation creep is a prompt, not a plea.
- **The bundle streams to stdout piped straight into encryption**, so zero
  plaintext ever rests on disk — no temp file, no crash-window artifact for a
  synced folder to grab. Witnessed on git 2.43.
- **A seal refuses any destination inside the estate root.** The containment
  whitelist swallows bundles path-dependently: `Logs/` and `Dump/` are excluded,
  so a bundle there is ignored, but one dropped in a ticket folder proper, in
  `AI-Knowledge/` or `Checks/`, or under `General AI-Knowledge/`, is tracked and
  auto-committed — the record inside the record, every drop. Path-dependent
  behaviour is the worst kind, because "it was fine in `Dump/`" teaches a false
  generalisation.
- **Restore refuses on any divergence** — it never merges, never resolves, never
  picks a side.

## Consequences

`#77` closes as a documented decline. The **remint condition, stated plainly:** a
real second live estate. Until one exists, the ferry stays undesigned; `#75`'s
local bundle-drill remains the rehearsed on-ramp — the artifact already exists
and has been exercised, so the skill is learned before any ferry is built.

A docs rider belongs here rather than in a separate doc: **a bundle is the whole
record, nothing scrubbed.** Unlike a context pack, "structure travels, payload
never" does not apply, because with a bundle the payload is the entire point.
Anyone carrying a work estate through third-party storage should check their own
and their employer's rules first. Method public, judgement sovereign.

## Lineage

This clarifies `decisions/001-local-only-no-remote.md`. The hand-carried bundle
is the one exception to "no remote, ever", and it now sits on the record beside
the law rather than contradicting it from a chat log. The law is unchanged; the
exception is bounded — human-carried, interactively sealed, one-way, and refused
inside the estate root.

## Status

Accepted. Evidence: `#77` (the design discussion and the operator ruling that
declined the mechanism and set the remint condition).
