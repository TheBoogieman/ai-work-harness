# AI Work Harness

**A local-first harness that turns an AI coding assistant into a disciplined
colleague.** Rules live in one file, cheap agents do the bookkeeping, a bash
script catches misses, and git undoes mistakes. Born from a 40,000-credit
month of undisciplined frontier-model use; rebuilt so that never happens
again — to anyone. MIT licensed.

## What it does, plainly

You work on tickets with an AI assistant. The harness makes that work leave
**records** instead of vibes: every ticket folder keeps its own log, current
state, and captured knowledge; every ad-hoc check — SQL, Python, whatever your
work is — lands in an audit-trail notebook; every file write auto-commits to a
local-only git repo; and a dumb bash validator refuses to let a session start on
top of an undocumented mess. Small
AI agents do the clerical work (logging, capturing, compacting) so the
expensive model — and you — only do the thinking. Nothing self-heals, nothing
phones home, and one markdown file is the law.

## Setup

Installing takes two steps and about ten minutes. **Every command,
prerequisite and caveat lives in exactly one place —
[INSTALL-INSTRUCTIONS.md](estate/INSTALL-INSTRUCTIONS.md)**, which also carries
reconfiguration and the hook-activation caveat. This page repeats none of them
on purpose: two install documents drift apart, so every install command is told
once, there.

## Assumptions

This harness assumes — and only works as designed with — the following.
Anything marked *swappable* degrades gracefully if you differ.

### Who is working, and with what

- **A single operator working one active session at a time** — not concurrent
  multi-user access to a shared record repo. The auto-commit-per-write and
  single-writer git model assume one writer.
- **GitHub Copilot with custom agents + lifecycle hooks** (CLI and/or
  VS Code). Both features are preview-grade — verify config schemas against your
  version's docs (see **Setup**). Without Copilot the conventions and scripts
  still work — you just invoke agents' jobs by hand.
- **VS Code** as the editor (*swappable* — nothing hard-depends on it, but
  the notebook/interpreter flow is written for it).

### The toolchain it expects

- **git** installed; the harness creates a **local-only** repo at the
  workspace root (it must never get a remote — this public repo is the
  sanitised exception that proves the rule).
- **Python 3.12** and a venv named exactly **`venv_global`** (with
  `nbformat`), created by you, set as the workspace default interpreter.
  The harness depends on it and never creates it.
- **An issue tracker** — Jira assumed, any works (*swappable*). Replace the
  `PROJ` board key with yours; `ticket-init` degrades to template-with-TODOs
  when the tracker is unreachable.
- **Your real code lives under `GitHub/`** in the workspace (a folder of
  clones and a `.code-workspace`; *optional* — the harness gitignores it and
  never touches it, but the repo-mapping conventions assume it exists).

### Where the machinery runs

- **bash** (macOS/Linux; the scripts auto-detect GNU vs BSD userland, so
  stock macOS works without installing coreutils).
- **Windows:** the integrated **Git-Bash/Cygwin** bash runs the machinery (the
  #8 hooks-parse fix makes it viable); plain PowerShell can push the repo with
  git but cannot run the scripts.
- **WSL** is for an *ephemeral* Linux check only (clone inside `~`, never a
  `/mnt/c` mount) — never a standing home.

### How the Windows lane is verified (the one home for this fact)

By the maintainer, by hand — `run_demo.sh` ending in *ALL 6 DEMO STAGES PASSED*
in Git-Bash/Cygwin on real Windows hardware, which is the seat this harness is
developed on.

**No automated check touches Windows at all** — the `windows-latest` witness job
that used to re-run the demo informationally was removed (#281). The lanes that
gate a change are the Linux + macOS ones named under **Developing this harness
with an AI assistant**, below.

On your own Windows box the demo you run (**Setup**, step 1) is the proof; there
is no green badge standing in for it.

---

## The folder map

The annotated estate structure — every folder, what it is for, which part of the
machinery owns it, and the four states a `Tickets/` folder can be in — lives in
**[folder-map.md](estate/folder-map.md)**. It has its own document because it names
every shipped script, so the map grows every time the machinery grows; a front page
cannot carry that and stay a front page.

## The layers, bottom to top

### L1 — Git (local-only, rooted at `Work/`, whitelist-scoped)

The undo button. Every write auto-commits — via the Copilot `postToolUse` hook,
when it fires; harness-status warns if commits fall behind session activity.

One history covers the RECORDS: tickets (minus each `Logs/` and `Dump/`), the
constitution, `AGENTS.md`, and General AI-Knowledge — promoted knowledge never
leaves version control, and every other `Work/` folder never enters it. No
remote exists, nothing ever pushes.

### L2 — Hooks + `check_ticket_log.sh`

The dumb inspector. Runs at session START (the entry gate — it audits what the
previous session left behind; sessionEnd is a best-effort bonus), and checks
facts only: log appended? Current State exists? Index matches files? Fails
loudly, judges nothing.

### L3 — Filesystem

Single source of truth. `CONSTITUTION.md` holds every rule; each ticket folder
holds its own log, state, and knowledge; `General AI-Knowledge/` holds the
durable stuff; `AGENTS.md` is the seven-rule contract Copilot loads on every
surface.

### L4 — The agents

The workers:

- `ticket-init` (smart, at pickup) — pulls Jira, interviews you (your
  words, non-negotiables, repos), suggests branch names, births the folder
- `ticket-recall` (cheap, at pickup) — read-only; narrates one ticket in
  fixed sections (Done / Changed / Unresolved / Suggested next), writes nothing
- `ticket-scribe` (cheap) — writes Session Log + Current State
- `check-scribe` (cheap) — records verified checks (any language) via the helper
- `doc-writer` (cheap) — drafts PR descriptions and READMEs
- `knowledge-keeper` (cheap) — captures learnings into `AI-Knowledge/`
- `knowledge-curator` (smart, rare) — compacts and promotes, with human
  approval; direct invocation only
- `weekly-digest` (cheap, at a boundary) — read-only; narrates a period
  (default 14 days) from the record — active tickets, knowledge, status
  deltas — writes nothing
- `harness-recall` (cheap, on demand) — read-only; FINDS where a topic
  appears across tickets and knowledge, one cited hit per line — grep + git,
  no stored index — writes nothing
- `retrospective` (smart, at review time) — writes a period retrospective
  (default 12 months) FOR THE HUMAN in accomplishment register — one
  timestamped file to `General Human Knowledge/Retrospectives/`, nothing else

### L5 — You + a frontier model

The thinking. Everything below exists so this layer stays cheap, focused, and
honest.

## The maintenance port (offline, on demand)

Five human-run tools; each has a one-line purpose in the folder map, and its full
telling lives in `CONSTITUTION.md` (Part II) or the home named inline.

- `harness-status.sh` — estate-wide health report; every FAIL line ends with its fix.
- `tracker_sweep.sh` — board-vs-estate drift through a pluggable, tracker-agnostic
  fetch seam that fails open offline; the seam is documented in the script's header.
- `make_context_pack.sh` — scrubbed, disposable zip of the harness for external
  review; skim before it leaves the machine.
- `harness-housekeeping.sh` — `git gc`/repack to reclaim `.git` growth, all history kept.
- `harness-drill.sh` — rehearse recovery on a calm day: three read-only modes
  (`restore-drill`, `bundle-drill`, `undo-drill`); modes documented in the script's header.

## Capture — checks and records

**There is one door into a notebook, and a session record is written by hand.**

- **`_harness/scripts/append_notebook_cell.py`** — the single deterministic writer
  for `Checks/checks_master.ipynb`: one why-note + one **real, executable** code
  cell per verified check. The `check-scribe` agent appends the cell; you open the
  notebook and run it, and the notebook format binds the actual output to the cell
  that produced it. An executed cell is a stronger record than a transcription.
  Detail: the script's own commented header.
- **A session entry in a ticket `.md` you write yourself**, or ask the
  `ticket-scribe` agent to write. It is not a stamping job: an entry restates
  where the ticket now stands, which is judgement. `check_ticket_log.sh` then
  validates what was written and names the exact fix if it is wrong.

Three earlier tools sat here — a record appender, a shell-output transcriber and a
block-transport helper (#280). Nothing called any of them, and none had a job the
two routes above do not do better; they were removed rather than kept for symmetry.

## The one pattern, repeated everywhere

file states the rule → agent does the work → hook catches the miss →
git undoes the damage

And its corollary: **status observes, failures prescribe, nothing heals
itself.** A fixed record is always a human act.

## When it yells

**Red blocks, yellow schedules.** A `FAIL` at session start = fix before
working — apply the printed fix, or reconstruct the record from the Work
git history; never fabricate one. `WARN`/`NOTE` = keep working, handle the
chore at the next natural boundary. Machinery itself misbehaving =
`harness-status.sh` prescribes. Full state table: backbone, *Session
States — Operational Rules*.

## Developing this harness with an AI assistant

> **About the SOURCE repository, not your work estate.** This section is for
> people hacking on the harness itself (branches, PRs, CI). None of it is estate
> setup — the files it names (`CLAUDE.md`, `.github/`, `run_demo.sh`) live
> outside the `estate/` tree and never ship. To *install* the harness, see
> **Setup** above; nothing here points a user at dev machinery.

### The rules live in `CLAUDE.md`, not here

The harness is developed the way you'd use it: clone the repo and point an
agentic AI assistant at it. The repo root's **`CLAUDE.md`** — read automatically
by the assistant — holds the full development rules **and** the environment
setup: LF line endings (`core.autocrlf input` + the `.gitattributes` pins), the
demo dependencies, the Linux/macOS standing lanes, and WSL as an ephemeral check
only (never a `/mnt/c` home).

**The development loop is stated once, in `CLAUDE.md`, and this section does not
restate it** — which changes must run the demo, which classes of change are exempt,
and the regression guard a fix owes all live there, in one home, so the two
documents cannot drift apart. Read it before you change anything; don't hand-edit
the machinery from memory.

### Setting up the native-Windows lane

Install **Git for Windows** (or Cygwin) and **VS Code** with your agent
extension, and do all shell work in the integrated Git-Bash/Cygwin terminal —
plain PowerShell runs `git` but not the bash machinery.

Verify the host once, end to end:

```bash
bash dev/scripts/run_demo.sh   # must end with: ALL 6 DEMO STAGES PASSED
```

That hand-run is the whole of the Windows lane's verification, because no merge
gate covers Windows (**Assumptions**, above, is the one home for that fact).

### Merge gate

Work is issues-first — open or claim an issue, branch or fork, then open a PR
whose body closes it (`Fixes #NN`). **One workflow gates every merge**
(`.github/workflows/demo.yml`):

- **The acceptance demo on Linux *and* macOS** — required on both because the
  GNU/BSD split is real and the demo is the only thing that exercises it.
- **Four documentation detectors** — broken links, unbalanced code fences,
  carriage returns, dead pointers — which run as a step in the Linux lane on
  every pull request and fail it when one reds.

Four separate gates used to sit beside the demo: documentation, governance,
shell lint and a Windows witness. They were removed (#281) — a checking layer
built to make an implementer paranoid has no job once the findings come from
using the product; the four detectors worth keeping moved into the lane that
was already running.

Branch naming and issue anchoring are still the convention
(`NN-lowercase-kebab`), now kept by review rather than by a script.

### For an external design review

Take the scrubbed, disposable zip from `make_context_pack.sh` (the maintenance
port, above) to a design session, then let the acceptance demo prove the change
you bring back. The system was built that way.

## Document catalogue

The documentation surfaces this page does not already point at, each with its
one home. **Pointers only** — an entry points at where a thing lives; it never
restates the thing (the one-home law).

A document reached from **Setup**, **The folder map** or **Developing this
harness** above is not repeated here, and `folder-map.md` owns estate
*structure* while this owns document *navigation*.

### The project spec

**[`estate/SPEC.md`](estate/SPEC.md)** — what the harness guarantees today, and
the vocabulary those guarantees are written in. *Referenced by:* this page.

### Skills — the worker-tier craft modules

**[`estate/General AI-Knowledge/Skills/`](<estate/General AI-Knowledge/Skills/>)**
— `_index.md`, `SKILL-TEMPLATE.md` and `SQL-Writing/SKILL.md`, discovered
index-first. *Referenced by:* `AGENTS.md` (rule 7), constitution (Skills
Convention).

### Design notes and the diagram-currency ledger

**[`estate/General AI-Knowledge/AI Harness/DESIGN.md`](<estate/General AI-Knowledge/AI Harness/DESIGN.md>)**
— design notes plus the dated diagram-currency ledger (the honest-lag record).
*Referenced by:* the folder map, `CLAUDE.md` (diagram ownership).

### The two blueprint drawings

**[`estate/General AI-Knowledge/AI Harness/`](<estate/General AI-Knowledge/AI Harness/>)**
— the Architecture and Session-flow sheets, operator-maintained: what the
machine is, and how a day moves through it. *Referenced by:* the folder map,
`DESIGN.md`.

### The development rules

**[`CLAUDE.md`](CLAUDE.md)** — the four standing rules, the branch/PR loop, the
environment. *Referenced by:* this page (Developing this harness).

---

*Rev E · 2026-07 · MIT licensed. Built human-and-AI, pair-designed over ~20 review cycles.*
