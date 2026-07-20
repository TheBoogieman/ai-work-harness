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
audit-trail notebook; every file write is auto-committed to a local-only git repo (via a Copilot hook, when it fires); and a
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
round-trips the notebook helper, breaks and manually restores an agent deployment, and
produces a scrubbed context pack with a manifest self-audit. If all six
stages pass, the machinery works on your machine.

The same demo runs in CI: on every push to `main`, on every pull request into `main`,
and on manual dispatch, GitHub Actions runs `run_demo.sh` on both Linux and macOS, so
the GNU/BSD portability branches are exercised for real on macOS, not via shims.

**Then wire your AI assistant:** follow `INSTALL.md` (~30 minutes) —
personalise the backbone, pin real model IDs into the six agents, deploy
them, install the hooks, run the acceptance test. `setup-prompt.md` lets a
strong-model Copilot session drive the install for you.

## Assumptions

This harness assumes — and only works as designed with — the following.
Anything marked *swappable* degrades gracefully if you differ.

- **A single operator working one active session at a time** — not concurrent
  multi-user access to a shared record repo. The auto-commit-per-write and
  single-writer git model assume one writer.
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
  stock macOS works without installing coreutils). **Windows:** the integrated
  **Git-Bash/Cygwin** bash runs the machinery (the #8 hooks-parse fix makes it
  viable); WSL also works. Plain PowerShell can push the repo with git but
  cannot run the scripts.

## Repository tour

- `folder-structure.md` — **the constitution.** Part I loads every session;
  Part II on demand. Start here.
- `AGENTS.md` — the six-rule contract Copilot reads on every surface.
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
├── .github/workflows/                       CI — runs the demo on Linux + macOS on every push to main and PR into main
│
├── _harness/
│   └── scripts/                             THE MACHINERY (versioned)
│       ├── check_ticket_log.sh              ← sessionStart hook │ sessionEnd (bonus)
│       │       └── watermark →              ~/.harness/validated/<ticket>  [state · unversioned]
│       ├── harness-status.sh                stdout only · roster = _agents/ · checks siblings
│       ├── ticket-grammar.sh                recognition home: TICKET_RE + ticket predicates · validator + status both source it (edit to retarget your board)
│       ├── portability.sh                   shared GNU/BSD shims: ts14→epoch, sourced by validator + status (one home · no drift)
│       ├── append_notebook_cell.py          ← check-scribe · runs on venv_global [user-created prereq]
│       ├── make_context_pack.sh             → ~/Desktop/harness-pack-*.zip [disposable · outside repo]
│       ├── deploy_agents.sh                 → user-level agent dir (sync source → live)
│       ├── harness-housekeeping.sh          human-run · git gc + size report · never touches records
│       └── run_demo.sh                      the acceptance demo: proves the machinery end-to-end on this host (see Setup) · wired to no hook
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
`.ticket-pending`) → a **non-silenceable** WARN, completed in two steps
(rename to a conforming name **and** remove the marker) and nagging until both
are done — the marker, not the name, is the lifecycle token, so a conforming
rename alone can't leave a real ticket silently misfiled; it also takes
precedence over `.not-a-ticket`, so a real ticket can't be dismissed; **(4)**
no ticket content, or marked `.not-a-ticket` → silent. Nothing is ever blocked
for a *naming* choice — the tools nudge with yellow, never wall you off. (One
edge case sits outside these four: a recognised name commits the folder to
validation, so a conforming folder missing its `.md` record is a validator
`FAIL` — add the record.) Two markers: `.not-a-ticket`
("not a ticket, leave it alone") and `.ticket-pending` ("a real ticket
awaiting completion — rename **and** remove the marker; non-silenceable"). The
recognition pattern lives in one editable line
(`_harness/scripts/ticket-grammar.sh`) that both tools share — e.g. a
hyphenated board key like `DATA-ENG` needs the board segment widened there;
see `folder-structure.md` for the worked example.

## The layers, bottom to top

- **L1 — Git (local-only, rooted at `Work/`, whitelist-scoped)** — the
  undo button. Every write auto-commits — via the Copilot `postToolUse` hook,
  when it fires; harness-status warns if commits fall behind session activity.
  One history covers the RECORDS:
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
  six-rule contract Copilot loads on every surface.
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
- `_harness/scripts/harness-housekeeping.sh` — the repo grows with use
  (an auto-write commit per file mutation, plus tracked `Checks/` notebooks
  rewritten whole on each append), so `.git` becomes several times the
  working-tree size over months. Run this by hand periodically to `git gc` /
  repack and reclaim the space — it preserves all history and records, deletes
  nothing. See *Repo Health / Housekeeping* in `folder-structure.md` for the
  full growth story and the optional notebook-stripping step.

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

> **About the SOURCE repository, not your work estate.** This section is for
> people hacking on the harness itself (branches, PRs, CI). None of it is estate
> setup — the files it names (`CLAUDE.md`, `.github/`, `run_demo.sh`) are
> classified DEV in `.github/ship-manifest.txt` and never ship. To *install* the
> harness, see [INSTALL.md](INSTALL.md); nothing here points a user at dev
> machinery.

The harness is built to be developed much the way you'd use it: clone the repo
locally and point an agentic AI coding assistant at it to work on the harness
itself. The repo root carries a **`CLAUDE.md`** — machine-facing instructions
the assistant reads automatically — holding the full development rules (the
working loop, the edit constraints, the acceptance gate).

**Recommended setup — native Windows (the documented lane):**

Follow these from zero; the shell steps run verbatim in the integrated
Git-Bash/Cygwin terminal, no improvisation needed:

1. Install **Git for Windows** (which provides Git Bash) — or Cygwin with git —
   and **VS Code**. *(Operator-confirmed step: exact installers are recorded
   during the walkthrough.)*
2. Clone the repo and pin LF line endings before anything else:
   ```bash
   git clone <repo-url>
   cd ai-work-harness
   git config core.autocrlf input
   ```
   `.gitattributes` already pins `*.sh`/`*.py` to LF, so the scripts stay
   byte-for-byte LF even under `core.autocrlf=true`; setting `input` also keeps
   your own edits clean at the source. This is the first thing to get right — a
   CRLF in a shell shebang or heredoc breaks the machinery.
3. Open the folder in VS Code and install your agent extension (e.g. Claude
   Code), then sign in. *(Operator-confirmed GUI step: the extension name and
   sign-in flow are recorded as evidence during the walkthrough.)*
4. In the integrated bash, install the demo's dependencies: `python3` with
   `nbformat` (`pip install nbformat`) and `unzip` (`zip` is optional —
   `make_context_pack` falls back to Python's zipfile).
5. Verify the machinery end to end — it must end with *ALL 6 DEMO STAGES PASSED*:
   ```bash
   bash _harness/scripts/run_demo.sh
   ```

Do all shell work in the integrated Git-Bash/Cygwin terminal; plain PowerShell
runs `git` but not the bash machinery.

**Linux / macOS / WSL:** Linux and macOS work identically and are the standing
fully-tested lanes (CI runs the demo on both on every PR); a `windows-latest`
MSYS job witnesses the Windows lane informationally. WSL is fine for an
*ephemeral* Linux check — clone inside your WSL home (`~`, **never** a `/mnt/c`
Windows-drive mount, which gives slow I/O and unreliable executable bits), run
the demo, discard — but it is not a standing development copy.

**The loop:** the assistant applies a change, runs the acceptance demo
(`bash _harness/scripts/run_demo.sh` — it must end with *ALL 6 DEMO STAGES
PASSED*), and commits, with you reviewing before anything is pushed. Every bug
fix ships with a regression guard in that demo that provably fails on the
pre-fix code (features are usually guarded too, but the law is bug-scoped). See
`CLAUDE.md` for the full rules; don't hand-edit the machinery from memory.

**Merge-gate governance:** work is issues-first — open or claim an issue, branch
or fork, then open a PR whose body closes it (`Fixes #NN`). Beyond the demo, two
checks gate every PR into `main` (`.github/workflows/governance.yml`): the branch
name must match `^[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$` (leading issue number +
lowercase-kebab slug, e.g. `47-governance-pair`) with its number among the PR's
`Fixes #NN`, and the PR must reference a real, open issue via a closing keyword.
Local branch names stay free; the gate is the law, and fork PRs get grammar
leniency but still need the issue anchor. These checks are development
infrastructure and never ship to an estate. Full contributor guide:
[CONTRIBUTING.md](.github/CONTRIBUTING.md).

**For an external design review** (rather than local iteration), run
`_harness/scripts/make_context_pack.sh`: it produces a scrubbed, disposable
zip of the harness to take to a design session — then come back with an
updated build prompt and let the acceptance tests prove the change before you
trust it. The system was built that way; keep it that way.

---

*Rev E · 2026-07 · MIT licensed. Built human-and-AI, pair-designed over ~20 review cycles.*
