# AI Work Harness

**A local-first harness that turns an AI coding assistant into a disciplined
colleague.** Rules live in one file, cheap agents do the bookkeeping, a bash
script catches misses, and git undoes mistakes. Born from a 40,000-credit
month of undisciplined frontier-model use; rebuilt so that never happens
again — to anyone. MIT licensed.

## Setup

The harness installs onto a **work estate** — a local folder it turns into a
disciplined, record-keeping workspace. Two steps: prove the machinery runs on
your machine (the demo — no AI assistant needed), then lay down the estate and
wire your assistant.

**1 · Prove the machinery — `run_demo.sh` (~60 seconds).** Clone the repo to a
**source** location and run the demo from that checkout — the demo needs no estate,
so running it in place is correct:

- **macOS / Linux** — your terminal's bash (stock macOS works as-is; the scripts
  auto-detect GNU vs BSD userland):
  ```bash
  git clone https://github.com/TheBoogieman/ai-work-harness.git ~/ai-work-harness
  cd ~/ai-work-harness && bash _harness/scripts/run_demo.sh
  ```
- **Windows** — the integrated **Git-Bash/Cygwin** terminal (plain PowerShell can
  push git but cannot run the bash machinery):
  ```bash
  git clone https://github.com/TheBoogieman/ai-work-harness.git ~/ai-work-harness
  cd ~/ai-work-harness && bash _harness/scripts/run_demo.sh
  ```

It must end with **ALL 6 DEMO STAGES PASSED**. The demo inits the local git
safety net, validates the template ticket, runs a scratch ticket through the
happy path, **deliberately corrupts a record and shows the validator refusing
with an exact fix**, round-trips the notebook helper, breaks and restores an
agent deployment, and builds a scrubbed context pack with a manifest self-audit.
The same demo runs in CI on Linux + macOS on every push and PR into `main`, so
the GNU/BSD portability branches are exercised for real, not via shims.

**2 · Install onto your estate and wire your assistant (~10 minutes).**

*Prerequisite you create (the harness never does):* a Python virtualenv named
exactly **`venv_global`** with `nbformat`, registered as a Jupyter kernel and set
as the workspace default interpreter. (`unzip` is optional — the context-pack
helper falls back to Python's zipfile without it.)

```bash
python3.12 -m venv ~/venvs/venv_global   # 3.12 assumed; a newer python3 also works
source ~/venvs/venv_global/bin/activate && pip install nbformat   # + your toolchain (dbt etc.)
```

`pip install` works directly inside the activated venv; installing `nbformat`
into a **system** Python instead needs `pip install nbformat --break-system-packages`
on PEP 668 distros. Then run the installer, giving it an estate directory
**separate from this checkout** — `install.sh` needs a target dir distinct from the
source, and that path is required in practice (a bare re-run from inside the
checkout is refused, with a concrete fix):

```bash
bash install.sh ~/Work
```

`install.sh` is a non-destructive **dumb creator** — it lays down PRODUCT files
only, scaffolds any absent ticket anatomy, initialises a whitelist-scoped
**local-only** git repo with a day-zero commit, copies the verified hook config
to `.github/hooks/harness.json`, deploys the agents, and runs the validator +
status; it **never edits an existing file**, so a re-run finds nothing absent. It
asks for your board key and model pins (Enter accepts each suggested default;
`--dry-run` plans without touching anything, `--yes` accepts every default). The
agents deploy to your Copilot version's discovery directory — verify that path
for your version (override with `HARNESS_AGENT_DEPLOY_DIR`). Finally, paste
`setup.md` into your AI assistant, working in the new estate: it is the **final
validation gate** — it confirms the validator + status are green, spot-checks the
scaffolded tickets, and walks you through the personalisation the installer left
you (model pins, `LICENSE`, scrub-table seeds, Owner lines).

### Re-running / reconfiguring

Re-running `install.sh` serves two different intents, each with its own home:

- **Reconfigure** (review or change your board key / model pins): run `install.sh`
  from **inside the estate** (`cd ~/Work && bash install.sh`). It recognises the estate
  by its `harness.estate` key, enters **reconfigure-only mode**, and offers your
  established values as defaults. A changed answer is **WARNed** with the file to edit
  and an AI-assistant handoff — the installer never edits your config for you; that
  stays your (or your assistant's) deliberate act via `setup.md`, on the record.
- **Complete or repair** (add or fix estate files): run `install.sh` from your
  **source checkout**, targeting the estate (`bash install.sh ~/Work`). The estate's
  own copy cannot create files — there is no manifest or source to copy from in-estate
  — and the reconfigure banner points you back to the checkout for this.

### Hook activation caveat

The auto-commit hook is *witnessed firing* on the VS Code Copilot IDE agent
(v1.129.1, 2026-07-20) on an **established, trusted** workspace. On a
**freshly-created** workspace, `postToolUse` did **not** auto-fire immediately in
testing — even after trusting the folder and reloading; the exact fresh-estate
activation trigger is not fully characterised, so expect a first real session or
a Copilot restart may be needed. The git safety net is the backstop — if a write
wasn't auto-committed, commit it by hand; nothing in the record depends on the
hook firing. (CLI and cloud Copilot surfaces are UNVERIFIED — their schema may
differ.) The hook config design ships as `_harness/hooks/hooks.example.json` —
verify its schema against your Copilot version.

**Arming on migration.** The auto-commit hooks commit only where the estate's
`.git/config` carries `harness.estate=true` — a positive-identity key `install.sh`
sets, so the hooks can never auto-commit into a nested foreign project repo (e.g.
under `Github/`). Estates created before this version, or migrated via `git clone`
(clone does not copy local config), arrive with auto-commit **disarmed**; run
`git -C <estate> config harness.estate true` to arm it. A plain folder copy or move
keeps the key and needs nothing.

## What it does, plainly

You work on tickets with an AI assistant. The harness makes that work leave
**records** instead of vibes: every ticket folder keeps its own log, current
state, and captured knowledge; every ad-hoc check — SQL, Python, whatever your
work is — lands in an audit-trail notebook; every file write auto-commits to a
local-only git repo (via a Copilot hook, when it fires); and a dumb bash
validator refuses to let a session start on top of an undocumented mess. Small
AI agents do the clerical work (logging, capturing, compacting) so the
expensive model — and you — only do the thinking. Nothing self-heals, nothing
phones home, and one markdown file is the law.

## Assumptions

This harness assumes — and only works as designed with — the following.
Anything marked *swappable* degrades gracefully if you differ.

- **A single operator working one active session at a time** — not concurrent
  multi-user access to a shared record repo. The auto-commit-per-write and
  single-writer git model assume one writer.
- **GitHub Copilot with custom agents + lifecycle hooks** (CLI and/or
  VS Code). Both features are preview-grade — verify config schemas against your
  version's docs (see **Setup**). Without Copilot the conventions and scripts
  still work — you just invoke agents' jobs by hand.
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
  viable); plain PowerShell can push the repo with git but cannot run the
  scripts. WSL is for an *ephemeral* Linux check only (clone inside `~`, never a
  `/mnt/c` mount) — never a standing home.

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
│       │       └── append_entry.sh          record appender: text+ticket+section → stamped atomic append under an existing header, then check_ticket_log verdict
│       ├── harness-status.sh                stdout report + one primary-observation record (each WARN's first-seen, for aging #71) · roster = _agents/ · checks siblings
│       ├── ticket-grammar.sh                recognition home: TICKET_RE + ticket predicates · validator + status both source it (edit to retarget your board)
│       ├── portability.sh                   shared GNU/BSD shims: ts14→epoch, sourced by validator + status (one home · no drift)
│       ├── append_notebook_cell.py          ← check-scribe · runs on venv_global [user-created prereq]
│       ├── literate_capture.py              transport: delimited SQL/python blocks → notebook cells (hash-deduped)
│       ├── check_run.sh                     run-and-record: runs a command, appends one notebook cell (command, output, exit code, timestamp)
│       ├── make_context_pack.sh             → ~/Desktop/harness-pack-*.zip [disposable · outside repo]
│       ├── tracker_sweep.sh                 human-run · on-demand board-vs-estate drift report · pluggable fetch seam · tracker-agnostic · fails open offline
│       ├── retro_stats.sh                    dumb counter for the retrospective agent · tickets-by-month + checks + promotions · offline · exits 0 always
│       ├── deploy_agents.sh                 → user-level agent dir (sync source → live)
│       ├── harness-housekeeping.sh          human-run · git gc + size report · never touches records
│       ├── harness-drill.sh                 human-run · rehearse restore/bundle/undo · read-only toward the estate
│       └── run_demo.sh                      the acceptance demo: proves the machinery end-to-end on this host (see Setup) · wired to no hook
│
├── _agents/                                 SOURCE OF TRUTH (versioned)
│   ├── ticket-init.agent.md                 ┐
│   ├── ticket-scribe.agent.md               │ deploy_agents.sh → user-level dir
│   ├── ticket-recall.agent.md               │
│   ├── check-scribe.agent.md                │   [live · derived · unversioned]
│   ├── doc-writer.agent.md                  │   drift check (status): differ ⇒ FAIL
│   ├── knowledge-keeper.agent.md            │   fix ⇒ re-run deploy_agents.sh
│   ├── knowledge-curator.agent.md           │
│   ├── weekly-digest.agent.md               │
│   ├── harness-recall.agent.md              │
│   └── retrospective.agent.md               ┘
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
├── General Human Knowledge/                 human-facing OUTPUT the machinery writes (append-only · inside the whitelist)
│   └── Retrospectives/                      ← retrospective agent · one timestamped file per run
│
└── [GitHub/ · Diagrams/ · Mappings/ · …]    [never enter history — whitelist excludes them]
```

**On ticket-folder names:** nothing requires a specific ticket-folder name —
name folders however suits your workflow. The tools recognise a recommended
default pattern but never force it. A `Tickets/` folder is in one of four states:

- **(1) Conforming + recorded** — matches the pattern *and* holds a ticket
  record → auto-validated.
- **(2) Hand-made + recorded** — holds a record but doesn't match the pattern →
  `harness-status` gives a heads-up (WARN) to either rename it *or* `touch
  .not-a-ticket` to silence it. Never blocked.
- **(3) Pending** — a real ticket `ticket-init` couldn't name, marked
  `.ticket-pending` → a **non-silenceable** WARN. It nags until *both* of its
  completion steps are done:
  - Two-step completion: rename to a conforming name **and** remove the marker.
  - The **marker, not the name, is the lifecycle token** — a conforming rename
    alone can't leave a real ticket silently misfiled.
  - `.ticket-pending` takes **precedence over `.not-a-ticket`**, so a real
    ticket can't be dismissed.
- **(4) Not a ticket** — no ticket content, *or* explicitly marked
  `.not-a-ticket` → silent.

**Outside the four states**, one edge case: a recognised name commits the folder
to validation, so a conforming folder *missing* its `.md` record is a validator
`FAIL` — add the record.

The two markers:

- `.not-a-ticket` — "not a ticket, leave it alone."
- `.ticket-pending` — "a real ticket awaiting completion; rename **and** remove
  the marker — non-silenceable."

Nothing is ever blocked for a *naming* choice: the tools nudge with yellow,
never wall you off. The recognition pattern lives in one editable line
(`_harness/scripts/ticket-grammar.sh`) that both tools share — e.g. a hyphenated
board key like `DATA-ENG` needs the board segment widened there; see
`folder-structure.md` for the worked example.

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
  seven-rule contract Copilot loads on every surface.
- **L4 — The agents** — the workers:
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
- **L5 — You + a frontier model** — the thinking. Everything below exists so
  this layer stays cheap, focused, and honest.

## The maintenance port (offline, on demand)

- `_harness/scripts/harness-status.sh` — estate-wide health report: ticket ages,
  index nags, stale general knowledge, git/hook/agent liveness. Every FAIL
  line ends with the exact fix.
- `_harness/scripts/tracker_sweep.sh` — on-demand board-vs-estate drift report.
  After a ticket is created the estate and the external board can drift silently
  (closed upstream, still Active locally). This human-run sweep reads each active
  ticket's upstream status through a **pluggable fetch seam** and WARNs per
  divergence with the fix named. It ships **tracker-agnostic**: the public product
  names no board and makes no network call of its own — you point it at your own
  fetcher (`HARNESS_TRACKER_FETCH_CMD`) at the fork layer, and the one line naming
  which statuses mean "closed" is user-editable (the `ticket-grammar.sh`
  precedent). It **fails open**: an unreachable tracker or no fetcher yields one
  quiet note, never a red, so an offline estate stays fully functional. Any token
  lives in the environment or a keychain at runtime — never on disk. See
  `decisions/015-pluggable-tracker-fetch-seam.md`.
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
- `_harness/scripts/harness-drill.sh` — a recovery *rehearsal* you run on a
  calm day. Backups exist, but a restore nobody has practised is a hope, not a
  capability, and the git undo net is doctrine read rather than muscle memory.
  Three read-only modes prove the record can be rebuilt before you ever need it:
  `restore-drill` rebuilds the record from the estate's own `.git` into a temp
  dir and checks it validates; `bundle-drill` makes a local `git bundle`,
  restores from *that*, and checks it validates (the bundle stays local);
  `undo-drill` walks you through undoing an uncommitted and a committed mistake
  on a throwaway fixture. Every mode leaves the live estate byte-untouched.

## Capture — checks, records, literate blocks

Everything you verify or record goes through a dumb, one-home writer — never a
hand-edit — so half-written records are never seen and the format detail lives in
exactly one place: each script's own commented header. Three capture tools:

- **`_harness/scripts/literate_capture.py`** — *literate capture*: mark blocks in
  your `.sql`/`.py` with a `%%` host-language comment (the comment lines above
  become the why-note), and it appends each as a markdown + code cell pair —
  content-hashed and re-runnable, sources byte-unchanged, transport never
  execution. The delimiter grammar and properties live in the script's header.
- **`_harness/scripts/append_entry.sh`** — the sanctioned way to add an entry to a
  ticket `.md` (as `append_notebook_cell.py` is for notebooks): text + ticket +
  an **existing** header → a stamped, atomic append, then `check_ticket_log.sh`
  runs and its verdict passes straight through (write-then-validate; a red never
  un-writes a good record). It **declines with the fix named**, never invents
  structure. Detail: the script's header.
- **`_harness/scripts/check_run.sh`** — capture an ad-hoc terminal check as you run
  it: `check_run.sh "<command>"` runs your literal command and records four fields
  (command, output, exit code, timestamp) to the notebook named by
  `CHECK_RUN_NOTEBOOK`. Adds no auth surface, fails open, never touches the
  network. Detail: the script's header.

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
> setup — the files it names (`CLAUDE.md`, `.github/`, `run_demo.sh`) are
> classified DEV in `.github/ship-manifest.txt` and never ship. To *install* the
> harness, see **Setup** above; nothing here points a user at dev machinery.

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

**Linux / macOS (and WSL for ephemeral checks only):** Linux and macOS work
identically and are the standing fully-tested lanes (CI runs the demo on both on
every PR); a `windows-latest` MSYS job witnesses the Windows lane
informationally. WSL is *only* for a throwaway Linux check — clone inside your
WSL home (`~`, **never** a `/mnt/c` Windows-drive mount, which gives slow I/O and
unreliable executable bits), run the demo, discard — never a standing
development copy.

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

## Document catalogue

Every documentation surface in the repo, with its audience and its one home.
**Pointers only** — a row points at where a thing lives; it never restates the
thing (the one-home law), and the folder map above owns estate *structure* while
this owns document *navigation*. **Audiences:** *user* (installs and runs an
estate) · *estate* (lives inside an installed estate) · *developer* (hacks on the
harness itself) · *machine* (an AI assistant reads it). Each fact has exactly one
home; everything else points at it.

| Document | Audience | Purpose (its one home) | Referenced by |
|----------|----------|------------------------|---------------|
| `README.md` | user | The front door: setup, usage, the folder map, and this catalogue. | entry point (rendered by GitHub) |
| `folder-structure.md` | estate | **The constitution — the rules.** Every harness convention; Part I always-load, Part II on demand. | `AGENTS.md`, `setup.md`, this README |
| `AGENTS.md` | machine | The seven-rule door-note the assistant loads on every surface → points to the constitution. | the AI assistant; this README |
| `SPEC.md` | developer | The project spec: glossary + decoder for the tracker shorthand. | `docs-check` (#69 glossary check) |
| `setup.md` | estate | The AI-assistant final-gate prompt: confirms validator + status green, walks the post-install personalisation. | this README (Setup), `install.sh` |
| `install.sh` | estate | The non-destructive dumb creator that lays down / reconfigures an estate. | this README (Setup), `setup.md` |
| `LICENSE` | user | MIT licence terms. | this README, `setup.md` |
| `CLAUDE.md` | developer | Dev instructions the AI reads when working **on** the harness (DEV — never ships to an estate). | this README (Developing), `docs-check` (grammar-drift) |
| `DEVELOPMENT.md` | developer | The dev-loop method doc: the four roles + five working laws (DEV). | `dev-loop/`, `docs-check` (#68) |
| `dev-loop/` (`SETUP.md` + three `*.template.md`) | developer | Starter kit to stand up the multi-seat dev loop; the templates ship **empty**. | `DEVELOPMENT.md`, `docs-check` (#68) |
| `decisions/` (`000` template + `001`–`018`) | developer | Architecture Decision Records — *the why* of each design choice. | `docs-check` (#69 ADR); later ADRs cross-cite |
| `General AI-Knowledge/AI Harness/DESIGN.md` | developer / user | Design notes + the dated diagram-currency ledger (the honest-lag record). | the folder map, `docs-check` (B4) |
| `General AI-Knowledge/AI Harness/` (Architecture + Session-flow sheets) | user | The two operator-maintained blueprint drawings — what the machine is, and how a day moves through it. | the folder map, `DESIGN.md` |
| `General AI-Knowledge/Skills/` (`_index.md`, `SKILL-TEMPLATE.md`, `SQL-Writing/SKILL.md`) | user / machine | Worker-tier craft modules, discovered index-first. | `AGENTS.md` (rule 7), constitution (Skills Convention) |
| `Tickets/README.md` | estate | Thin pointer — the map lives at the `Work/` root. | the Work-root folder map |

---

*Rev E · 2026-07 · MIT licensed. Built human-and-AI, pair-designed over ~20 review cycles.*
