# SPEC — what the AI Work Harness guarantees today

This is a **descriptive** specification: it states what the installed product
does **now**, not what it aspires to. If a line here is not true at HEAD, it is
a defect — fix the product or fix the line. README is the tour and Setup guide;
this file is the contract and the reader's key. The rules the product enforces
live in `folder-structure.md` (the constitution); the reasoning behind each
design choice lives in `decisions/` (the ADR backfill). This file sits between
them: the guarantees, plus a glossary and a decoder so a newcomer can read the
project's own shorthand.

## Original goals

The harness was built after a month of undisciplined frontier-model use burned
roughly 40,000 credits and left no durable record of what had been decided or
why. The founding goals, unchanged since:

- **Leave records, not vibes.** Every unit of work leaves a log, a current
  state, and captured knowledge on disk — reconstructable later by a human who
  was not in the room.
- **Cheap clerks, expensive thinkers.** Small, cheap agents do the bookkeeping
  so the frontier model and the operator spend their budget on judgment.
- **Local-first and private.** The work record lives in a local-only git repo
  that never gets a remote and never phones home.
- **Rules in one place, enforced dumbly.** One file states the law; a bash
  inspector checks facts and refuses to judge; git undoes mistakes.
- **Surface, don't impose.** The tools recommend conventions and nudge in
  yellow; they wall the operator off only on a genuine broken record.

## What the product guarantees today

- **A local-only git safety net.** `install.sh` initialises a whitelist-scoped
  git repo at the estate root with a day-zero commit and no remote. The record
  set (ticket `.md` files, the constitution, `AGENTS.md`, promoted knowledge) is
  tracked; bulk and scratch folders are excluded and never enter history.
- **Auto-commit that only fires inside a real estate.** The Copilot
  `postToolUse` hook auto-commits file writes, but only where `.git/config`
  carries the positive-identity key `harness.estate=true`, so it can never
  commit into a nested foreign project repo. The git net is the backstop when
  the hook does not fire; nothing in the record depends on it firing.
- **A dumb inspector at session start.** `check_ticket_log.sh` checks facts
  only — log appended, current state present, index matches files — and fails
  loudly with an exact fix. It heals nothing and judges nothing.
- **A four-state view of ticket folders.** Any `Tickets/` folder is conforming
  + recorded, hand-made + recorded (yellow nudge), pending (non-silenceable
  yellow until a two-step completion), or not-a-ticket (silent). A naming choice
  is never blocked; only a genuinely broken record is red.
- **An offline health report.** `harness-status.sh` reports ticket ages, index
  nags, stale knowledge, and git/hook/agent liveness. Every FAIL line ends with
  its fix.
- **A scrubbed, disposable context pack.** `make_context_pack.sh` builds a
  datestamped zip of the harness structure for external review, with a manifest
  self-audit; the structure travels, the payload never.
- **A non-destructive installer.** `install.sh` is a dumb creator: it lays down
  PRODUCT files only, scaffolds absent ticket anatomy, and never edits an
  existing file. A re-run from inside the estate enters reconfigure-only mode; a
  complete-or-repair run comes from the source checkout.
- **One home per fact.** Each rule, pattern, or convention lives in exactly one
  file; everything else points at it. The ticket-recognition pattern, the branch
  grammar, and the ship/dev classification each have a single editable home.

What the product does **not** guarantee: concurrent multi-user access,
self-healing of a broken record, or any network behaviour. It assumes a single
operator, one active session at a time, and no remote — ever.

## Glossary

- **estate** — the local work folder `install.sh` turns into a disciplined,
  record-keeping workspace (the git root). Distinct from the **source** checkout
  you develop the harness in; the two are never the same directory.
- **guard** — a mechanical check that refuses to let a defect through. Two
  families: the runtime `R-NN` regression guards baked into the demo and
  scripts, and the `GN` project rules that govern development of the harness
  itself (see the decoder).
- **red/yellow** — the two-tone signalling law. **Red** (`FAIL`) blocks: fix
  before working. **Yellow** (`WARN`/`NOTE`) schedules: keep working, handle the
  chore at the next natural boundary. Nothing self-heals; a fixed record is
  always a human act.
- **one-home** — the doctrine that each fact, pattern, or rule has exactly one
  editable home, and every other reference points at it rather than copying it.
  Duplication is the drift bug this doctrine exists to prevent.
- **dumb inspector** — the session-start validator (`check_ticket_log.sh`): it
  checks facts only and prescribes fixes, but forms no opinion and repairs
  nothing. "Dumb" is the design goal, not a limitation — judgment lives in the
  operator, not the checker.

## Decoder — reading the project's shorthand

The tracker history and the code cite short identifiers. Two of them are not
self-explanatory to a newcomer:

- **A goal number** is written `#NN` — a GitHub issue number. Each architectural
  change is anchored to an issue: the branch is named `NN-slug`, the PR body
  carries `Fixes #NN`, and the commit and ADR cite `#NN`. So a goal number is a
  durable, clickable pointer to the issue that motivated a change and the PR that
  landed it. It is the ONLY project-history reference that is stable — ephemeral
  labels (wave or milestone tags) are never used in public text because they
  drift.
- **A guard tag** comes in two forms. An **`R-NN`** tag (e.g. `R-09`) is a stable
  internal name for one regression guard in the demo and scripts — it lets a
  specific behavioural check be referred to across files without repeating its
  logic. A **`GN`** tag (e.g. `G4`, `G5`, `G6`, `G7`) is a project rule
  governing how the harness itself is developed: `G4` claims-truth (nothing false
  at HEAD ships), `G5` guard-per-bug (every fix ships a guard that provably fails
  on the pre-fix code), `G6` public-surface privacy, `G7` plain-English comments.
  So a guard tag names *which* check or rule is in play; a goal number names
  *why* a change exists.
