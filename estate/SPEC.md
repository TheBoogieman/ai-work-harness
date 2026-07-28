# SPEC — what the AI Work Harness guarantees today

This is a **descriptive** specification: it states what the installed product
does **now**, not what it aspires to. If a line here is not true at HEAD, it is
a defect — fix the product or fix the line. README is the tour and Setup guide;
this file is the contract and the reader's key. The rules the product enforces
live in `CONSTITUTION.md` (the constitution); the reasoning behind each
design choice lives in the code and prose that implement it. This file sits between
them: the guarantees, plus a glossary so a newcomer can read the vocabulary the
product uses about itself. The rules that govern DEVELOPMENT of the harness are
not here — they live with the development instructions, which never ship.

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
  complete-or-repair run comes from the source checkout. That law takes exactly
  one exception, and it is the next bullet.
- **An upgrade that moves and never deletes.** `install.sh --upgrade` brings an
  existing estate's machinery up to the source's, and you have to ask for it by
  name — without the flag nothing above changes. It shows every create, replace
  and retire before it does anything; it moves a replaced or superseded file
  into a quarantine folder inside the estate rather than deleting it, and
  reports each move as it happens with the command that puts it back; it carries
  the files holding your own settings forward untouched; and it never touches a
  record. Running it twice is safe and says so. What it may and may not reach is
  recorded in `install.sh`'s own header, which states the exception and its bounds.
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
- **guard** — a mechanical check that refuses to let a defect through. A guard
  is proven rather than asserted: it is written against a real defect and shown
  failing on the code that still carried it, so a later green run is evidence
  and not merely an absence. Guards live in the acceptance suite and in the
  scripts themselves, and each is cited by the behaviour it defends, so its
  logic is never repeated in the documents that refer to it.
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
