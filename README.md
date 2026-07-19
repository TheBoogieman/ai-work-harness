# AI Work Harness

**A local-first harness that turns an AI coding assistant into a disciplined
colleague.** Rules live in one file, cheap agents do the bookkeeping, a bash
script catches misses, and git undoes mistakes. Born from a 40,000-credit
month of undisciplined frontier-model use; rebuilt so that never happens
again — to anyone. MIT licensed.

## What it does, plainly

You work on tickets with an AI assistant. The harness makes that work leave
**records** instead of vibes: every ticket folder keeps its own log, current
state, and captured knowledge; every ad-hoc check — SQL, Python, whatever your work is — lands in an
audit-trail notebook; every file write is auto-committed to a local-only git repo; and a
dumb bash validator refuses to let a session start on top of an undocumented
mess. Six small AI agents do the clerical work (logging, capturing,
compacting) so the expensive model — and you — only do the thinking. Nothing
self-heals, nothing phones home, and one markdown file is the law.

## Setup

**Try it in 60 seconds (no AI assistant required):**

```bash
git clone https://github.com/TheBoogieman/ai-work-harness.git ~/Work
cd ~/Work
bash _harness/scripts/run_demo.sh
```

The demo initialises the local git safety net, validates the template
ticket, runs a scratch ticket through the happy path, **deliberately
corrupts a record and shows the validator refusing with an exact fix**,
round-trips the notebook helper, breaks and heals an agent deployment, and
produces a scrubbed context pack with a manifest self-audit. If all six
stages pass, the machinery works on your machine.

**Then wire your AI assistant:** follow `INSTALL.md` (~30 minutes) —
personalise the backbone, pin real model IDs into the six agents, deploy
them, install the hooks, run the acceptance test. `setup-prompt.md` lets a
strong-model Copilot session drive the install for you.

## Assumptions

This harness assumes — and only works as designed with — the following.
Anything marked *swappable* degrades gracefully if you differ.

- **GitHub Copilot with custom agents + lifecycle hooks** (CLI and/or
  VS Code). Both features are preview-grade; `INSTALL.md` tells you to
  verify config schemas against your version's docs. Without Copilot the
  conventions and scripts still work — you just invoke agents' jobs by hand.
- **VS Code** as the editor (*swappable* — nothing hard-depends on it, but
  the notebook/interpreter flow is written for it).
- **git** installed; the harness creates a **local-only** repo at the
  workspace root (whitelist-scoped; it must never get a remote — this
  public repo is the sanitised exception that proves the rule).
- **Python 3.12** and a venv named exactly **`venv_global`** (with
  `nbformat`), created by you, set as the workspace default interpreter.
  The harness depends on it and never creates it.
- **An issue tracker** — Jira assumed, any works (*swappable*). Replace the
  `PROJ` board key with yours; `ticket-init` degrades to template-with-TODOs
  when the tracker is unreachable.
- **Your real code lives under `GitHub/`** in the workspace (a folder of
  clones and a `.code-workspace`; *optional* — the harness gitignores it and
  never touches it, but the repo-mapping conventions assume it exists).
- **bash** (macOS/Linux; the scripts auto-detect GNU vs BSD userland, so
  stock macOS works without installing coreutils). **Windows:** run the harness
  inside **WSL** (`wsl --install`, then work from your Linux home, not
  `/mnt/c`) — plain PowerShell can push the repo with git but cannot run
  the scripts.

## Repository tour

- `folder-structure.md` — **the constitution.** Part I loads every session;
  Part II on demand. Start here.
- `AGENTS.md` — the ten-line contract Copilot reads on every surface.
- `_agents/` — six agent definitions (source of truth; deployed copies are
  derived).
- `_harness/scripts/` — validator, status, notebook helper, context pack,
  deploy, demo. All tested; every failure line ends with its fix.
- `_harness/hooks/hooks.example.json` — the hook design (verify schema
  against your Copilot version).
- `Tickets/999912Z-PROJ-99999/` — the template ticket.
- `General AI-Knowledge/AI Harness/` — the two blueprint sheets + design
  notes.
- `INSTALL.md` / `setup-prompt.md` — the flat-pack instructions and the
  prompt that assembles it.

## The drawings

Both blueprint sheets live canonically at
`General AI-Knowledge/AI Harness/` — these are embedded views, not
copies. If an image is broken, the build hasn't placed the sheets yet.

**Sheet 1 — Architecture** (what the machine is):

![Sheet 1 — Harness architecture blueprint](General%20AI-Knowledge/AI%20Harness/harness-architecture.svg)

**Sheet 2 — Session flow** (how a day moves through it — cyan boxes are
the only places you act):

![Sheet 2 — Session operational flow](General%20AI-Knowledge/AI%20Harness/harness-session-flow.svg)

---

## The folder map

```
Work/                                        [git root · local-only · whitelist]
│
├── .gitignore                               /* deny-all → re-include record set
├── folder-structure.md                      THE CONSTITUTION · Part I always / Part II on demand
├── AGENTS.md                                door-note → folder-structure.md
│
├── _harness/
│   └── scripts/                             THE MACHINERY (versioned)
│       ├── check_ticket_log.sh              ← sessionStart hook │ sessionEnd (bonus)
│       │       └── watermark →              ~/.harness/last-validated  [state · unversioned]
│       ├── harness-status.sh                stdout only · roster = _agents/ · checks siblings
│       ├── append_notebook_cell.py          ← check-scribe · runs on venv_global [user-created prereq]
│       ├── make_context_pack.sh             → ~/Desktop/harness-pack-*.zip [disposable · outside repo]
│       └── deploy_agents.sh                 → user-level agent dir (sync source → live)
│
├── _agents/                                 SOURCE OF TRUTH (versioned)
│   ├── ticket-init.agent.md                 ┐
│   ├── ticket-scribe.agent.md               │ deploy_agents.sh → user-level dir
│   ├── check-scribe.agent.md                │   [live · derived · unversioned]
│   ├── doc-writer.agent.md                  │   drift check (status): differ ⇒ FAIL
│   ├── knowledge-keeper.agent.md            │   fix ⇒ re-run deploy_agents.sh
│   └── knowledge-curator.agent.md           ┘
│
├── Tickets/                                 RECORDS ONLY
│   ├── README.md                            thin pointer (the map lives at the Work root)
│   └── YYYYMM<seq>-<BOARD>-<num>/            one per ticket (recommended name; template: 999912Z-PROJ-99999)
│       ├── YYYYMM<seq>-<BOARD>-<num>.md       source of truth ← ticket-scribe (log + state, atomic)
│       ├── AI-Knowledge/                    ← knowledge-keeper (capture) │ curator (compact)
│       │   ├── _index.md                    roster · tombstones
│       │   └── *.md                         —promotion (approved)→ General AI-Knowledge/
│       ├── Checks/                          audit-trail notebook (any language) · venv_global kernel
│       ├── Logs/                            [gitignored · regenerable bulk]
│       └── Dump/                            [gitignored · re-droppable inputs]
│
├── General AI-Knowledge/                    durable knowledge (versioned · cull-safe via history)
│   └── AI Harness/                          the sheets + build/design notes · Last reviewed: dated
│
└── [GitHub/ · Diagrams/ · Mappings/ · …]    [never enter history — whitelist excludes them]
```

**On ticket-folder names:** nothing requires a specific ticket-folder name.
Name folders however suits your workflow — the tools recognise a recommended
default pattern but never force it. A `Tickets/` folder is in one of four
states: **(1)** matches the pattern + holds a ticket record → auto-validated;
**(2)** hand-made, holds a record, doesn't match → `harness-status` gives a
heads-up (WARN) to rename it or `touch .not-a-ticket` to silence it — never
blocked; **(3)** a pending ticket `ticket-init` couldn't name (marked
`.ticket-pending`) → a **non-silenceable** WARN that nags until you give it a
proper name (this takes precedence over `.not-a-ticket`, so a real ticket is
never silently misfiled); **(4)** no ticket content, or marked `.not-a-ticket`
→ silent. Nothing is ever blocked — the tools nudge with yellow, never wall
you off. Two markers: `.not-a-ticket` ("not a ticket, leave it alone") and
`.ticket-pending` ("a real ticket awaiting its name, non-silenceable"). The
recognition pattern lives in one editable line
(`_harness/scripts/ticket-grammar.sh`) that both tools share — e.g. a
hyphenated board key like `DATA-ENG` needs the board segment widened there;
see `folder-structure.md` for the worked example.

## The layers, bottom to top

- **L1 — Git (local-only, rooted at `Work/`, whitelist-scoped)** — the
  undo button. Every write auto-commits. One history covers the RECORDS:
  tickets (minus each `Logs/` and `Dump/`), the constitution, `AGENTS.md`,
  and General AI-Knowledge — promoted knowledge never leaves version
  control, and every other `Work/` folder never enters it. No remote
  exists, nothing ever pushes.
- **L2 — Hooks + `check_ticket_log.sh`** — the dumb inspector. Runs at
  session START (the entry gate — it audits what the previous session left
  behind; sessionEnd is a best-effort bonus), checks facts only: log appended? Current State exists? Index
  matches files? Fails loudly, judges nothing.
- **L3 — Filesystem** — single source of truth. `folder-structure.md` holds
  every rule; each ticket folder holds its own log, state, and knowledge;
  `General AI-Knowledge/` holds the durable stuff; `AGENTS.md` is the
  ten-line contract Copilot loads on every surface.
- **L4 — Six agents** — the workers:
  - `ticket-init` (smart, at pickup) — pulls Jira, interviews you (your
    words, non-negotiables, repos), suggests branch names, births the folder
  - `ticket-scribe` (cheap) — writes Session Log + Current State
  - `check-scribe` (cheap) — records verified checks (any language) via the helper
  - `doc-writer` (cheap) — drafts PR descriptions and READMEs
  - `knowledge-keeper` (cheap) — captures learnings into `AI-Knowledge/`
  - `knowledge-curator` (smart, rare) — compacts and promotes, with human
    approval; direct invocation only
- **L5 — You + a frontier model** — the thinking. Everything below exists so
  this layer stays cheap, focused, and honest.

## The maintenance port (offline, on demand)

- `_harness/scripts/harness-status.sh` — estate-wide health report: ticket ages,
  index nags, stale general knowledge, git/hook/agent liveness. Every FAIL
  line ends with the exact fix.
- `_harness/scripts/make_context_pack.sh` — scrubbed, datestamped
  zip of the harness for external design review, landing on your Desktop.
  Disposable: upload, delete, regenerate anytime. Structure travels, payload
  never. Skim before it leaves the machine.

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

## Where information lives

- `folder-structure.md` — *the rules* (what the conventions are)
- `_agents/*.agent.md` — *the how* (each agent's operating instructions;
  versioned source — the user-level copies Copilot reads are deployments)
- `General AI-Knowledge/AI Harness/` — *the why* (design notes, the
  blueprint drawing, debugging guidance)

Each fact has exactly one home; everything else points at it.

## Developing this harness with an AI assistant

The harness is built to be developed much the way you'd use it: clone the repo
locally and point an agentic AI coding assistant at it to work on the harness
itself. The repo root carries a **`CLAUDE.md`** — machine-facing instructions
the assistant reads automatically — holding the full development rules (the
working loop, the edit constraints, the acceptance gate).

**Recommended setup:**

- A real Unix environment — Linux or macOS, or **WSL** on Windows
  (`wsl --install`, then work from your Linux home, not `/mnt/c`). The
  acceptance demo needs a POSIX shell, `python3` with `nbformat`, and `zip`.
  On Windows use WSL rather than **Git Bash** (a known MSYS-path +
  Windows-Store-Python issue affects Git Bash); plain PowerShell can run `git`
  but not the bash machinery.
- An agentic AI coding tool (e.g. Claude Code) launched in the repo directory,
  with git credentials configured so it can commit and push.

**The loop:** the assistant applies a change, runs the acceptance demo
(`bash _harness/scripts/run_demo.sh` — it must end with *ALL 6 DEMO STAGES
PASSED*), and commits, with you reviewing before anything is pushed. Every
behaviour change ships with a regression guard in that demo. See `CLAUDE.md`
for the full rules; don't hand-edit the machinery from memory.

**For an external design review** (rather than local iteration), run
`_harness/scripts/make_context_pack.sh`: it produces a scrubbed, disposable
zip of the harness to take to a design session — then come back with an
updated build prompt and let the acceptance tests prove the change before you
trust it. The system was built that way; keep it that way.

---

*Rev E · 2026-07 · MIT licensed. Built human-and-AI, pair-designed over ~20 review cycles.*
