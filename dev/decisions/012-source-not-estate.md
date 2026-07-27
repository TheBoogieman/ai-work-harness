# 012 — The source checkout is not a work estate

## Context

The harness is developed in a git checkout with a remote, branches, and CI — a
`source` repo. It is installed into a local-only `estate` that must never have a
remote. Confusing the two is dangerous in both directions: running the harness's
own record-keeping against the dev repo, or installing an estate on top of the
source checkout, would mix development machinery (branches, PRs, `CLAUDE.md`) into
a workspace whose law forbids exactly that.

## Decision

**Source and estate are always distinct directories.** `install.sh` requires a
target directory separate from the source, and a bare re-run from inside the
checkout is refused with a concrete fix. `CLAUDE.md` is classified DEV and never
ships, and its header states plainly that finding it on an installed estate means
the install was wrong. The demo runs from the source checkout and needs no estate.

## Consequences

Development concerns (remote, branches, CI, dev docs) can never leak into an
estate, and estate record-keeping never runs against the dev repo. The cost is
that the operator must supply a distinct estate path to the installer — the
refusal that enforces this is itself guarded, so the boundary cannot silently
erode.

## Status

Accepted, foundational. See `#62` (install.sh teaches source-checkout is not the
estate and the source-refusal names a concrete fix) and `#43` (CLAUDE.md
self-identifies as DEV and cannot ship).
