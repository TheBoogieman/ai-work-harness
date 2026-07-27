# 005 — Whitelist containment for the tracked record set

## Context

A work estate holds far more than the record: bulk logs, re-droppable inputs,
clones of real code under `GitHub/`, scratch files, editor junk. If git tracked
everything by default (a blocklist model), one forgotten ignore rule would pull an
operator's private code or a huge binary into history — and history is forever.

## Decision

The estate `.gitignore` is a **whitelist**: deny everything, then re-include only
the record set — ticket `.md` files (minus each `Logs/` and `Dump/`), the
constitution, `AGENTS.md`, and `General AI-Knowledge/`. Everything else — `GitHub/`,
`Diagrams/`, `Mappings/`, and objective junk — never enters history. Oversized
tracked ticket roots draw a WARN so accidental bulk is caught early.

## Consequences

Nothing can drift into version control by accident: a new junk folder is excluded
until explicitly whitelisted, which is the safe default. The cost is that a
genuinely new record location must be added to the whitelist deliberately — the
`.git/info/exclude` hatch handles a personal, un-tracked ignore without touching
the shared whitelist.

## Status

Accepted, foundational. See `#38` (hardening the whitelist to ignore objective
junk and WARN on oversized tracked ticket roots).
