# 001 — Local-only git, no remote, ever

## Context

The harness was born to make AI-assisted work leave a durable record. The
obvious place for that record is git. But a work estate holds an operator's raw
working context — ticket notes, board keys, captured learnings — none of which
should ever leave the machine. A remote is a permanent exfiltration risk and a
single misconfigured push can spill the estate.

## Decision

The estate git repo is **local-only and never gets a remote**. `install.sh`
initialises the repo with a day-zero commit and no `origin`; nothing in the
harness ever adds a remote or pushes. The public development repo is the
sanitised exception that proves the rule — it exists so the harness can be
shared, and it carries no estate material.

## Consequences

The record is private by construction: with no remote, there is nothing to push
and nowhere to leak to. The cost is that cross-machine sync is the operator's own
problem (a folder copy or move, which keeps history and the estate key). It also
means the single-writer, one-active-session assumption holds — there is no shared
remote to coordinate against.

## Status

Accepted, foundational. See `#39` (the manifest-driven installer that lays the
local-only repo) and the README **Assumptions** section, which states the repo
must never get a remote.
