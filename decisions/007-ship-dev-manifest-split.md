# 007 — Ship/dev classification split in one manifest

## Context

The repo holds two kinds of file: PRODUCT files that must land on a user's estate
(the constitution, agents, scripts) and DEV infrastructure that must never leave
the repo (CI workflows, governance scripts, `CLAUDE.md`, the demo). If that split
lived only in the installer's logic, it would be invisible and un-auditable — a
DEV file could silently ship, carrying development assumptions (branches, remotes)
into an estate whose law forbids them.

## Decision

Every tracked file is classified in **one manifest**, `.github/ship-manifest.txt`,
as either `PRODUCT` or `DEV`, one line each. `install.sh` lays down PRODUCT files
generically from this manifest; DEV files are greppable and provably cannot ship.
The demo's classification guard enforces both directions: every tracked file
appears exactly once, and the class is honoured.

## Consequences

Adding a file forces a conscious classification decision — the guard reds on any
tracked file with no manifest line. The installer needs no per-file knowledge; it
reads the manifest. The cost is one bookkeeping line per new file, which is the
point: classification is explicit, not inferred.

## Status

Accepted, foundational. See `#43` (ship/dev manifest plus the classification
guard) and `#39` (the manifest-driven installer that consumes it).
