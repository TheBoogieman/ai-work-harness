# The folder map

The annotated structure of a work estate: every folder, what it is for, and
which part of the machinery owns it. This is the estate's **structure** — the
**rules** are `folder-structure.md` (the constitution), and the front page is
`README.md`.

The map lives in its own document because it has to grow every time the
machinery grows: a check requires every shipped script's filename to appear
below, so a front page that carried the map would grow with the machinery and
stop being a front page.

```
Work/                                        [git root · local-only · whitelist]
│
├── .gitignore                               /* deny-all → re-include record set
├── folder-structure.md                      THE CONSTITUTION · Part I always / Part II on demand
├── AGENTS.md                                door-note → folder-structure.md
├── install.sh                               the dumb creator that laid this estate down · manual: installing.md
├── setup.md                                 the AI-assistant final gate, pasted in after the install
├── .github/workflows/                       CI — the demo on Linux + macOS: every push to main; PRs by scope (see .github/CONTRIBUTING.md)
│
├── _harness/
│   ├── demo/                                THE ACCEPTANCE SUITE'S other two halves [dev-only · never installed]
│   │   ├── tour.sh                          the stage-based tour a newcomer watches: six stage banners + the machinery running · asserts nothing by name
│   │   └── cases/*.case.sh                  one case file per guard family — the regression suite · every named guard lives in exactly one of them
│   ├── retire-list.tsv                      shipped DATA (not code): which paths a release SUPERSEDED · the ONLY thing --upgrade retires · cumulative · never inferred
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
│       └── run_demo.sh                      the acceptance demo's RUNNER: owns the estate + the stage order, runs _harness/demo/ (see Setup) · wired to no hook
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
├── _retired/<timestamp>/                    QUARANTINE — appears only after install.sh --upgrade [gitignored · deliberately outside the record]
│   └── <original path>                      your copy of a replaced or superseded file, moved never deleted · the run printed the mv that restores it
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
