# The folder map

The annotated structure of a work estate: every folder, what it is for, and
which part of the machinery owns it. This is the estate's **structure** — the
**rules** are `CONSTITUTION.md` (the constitution), and the front page is
`README.md`.

The map lives in its own document because it has to grow every time the
machinery grows: every shipped script's filename appears below, so a front page
that carried the map would grow with the machinery and stop being a front page.

```
Work/                                        [git root · local-only · whitelist]
│
├── .gitignore                               /* deny-all → re-include record set
├── .gitattributes                           pins tracked *.sh/*.py to LF on any clone (a stray CR breaks a shebang)
├── README.md                                THE FRONT PAGE · the tour, and the Setup that wires your assistant · laid down with its links aimed at this estate, not the source repo
├── CONSTITUTION.md                          THE CONSTITUTION (the rulebook) · numbered, linked Contents · Part I: read the sections your AGENTS.md row lists / Part II on demand · user-owned after laydown, KEEP on upgrade
├── SPEC.md                                  what this harness guarantees TODAY · descriptive: a line untrue at HEAD is a defect
├── folder-map.md                            THIS PAGE · the estate's structure (the rules are CONSTITUTION.md)
├── WORKED-EXAMPLE.md                        one piece of work end to end — the day-in-the-life a newcomer reads first
├── AGENTS.md                                THE POINTER · navigation, tools/auth, six rules, per-agent reading list → numbered CONSTITUTION.md sections · user-owned after laydown, KEEP on upgrade
├── INSTALL-INSTRUCTIONS.md                  the ONE home for every install command, prerequisite and caveat
├── install.sh                               the dumb creator that laid this estate down · manual: INSTALL-INSTRUCTIONS.md
├── AI-SETUP-PROMPT.md                       the AI-assistant final gate, pasted in after the install
├── LICENSE                                  MIT · root-pinned because the code host renders it there
├── .github/hooks/harness.json               THE ONLY .github/ an estate has: the auto-commit hook config, written AT INSTALL
│
├── _harness/
│   ├── hooks/hooks.example.json             the ONE hook-schema home · install.sh copies it to .github/hooks/harness.json above
│   ├── retire-list.tsv                      shipped DATA (not code): which paths a release SUPERSEDED · the ONLY thing --upgrade retires · cumulative · never inferred
│   └── scripts/                             THE MACHINERY (versioned)
│       ├── check-ticket-log.sh              ← sessionStart hook │ sessionEnd (bonus)
│       │       └── watermark →              ~/.harness/validated/<ticket>  [state · unversioned]
│       ├── check-work-map.py                ← second sessionStart command · read-only, warning-only navigation observer (links, mapped tickets, orphan notes) · --json for counts · --strict is manual-only, never a hook · asserts no lineage or truth
│       ├── harness-status.sh                stdout report + one primary-observation record (each WARN's first-seen, for aging #71) · roster = _agents/ · checks siblings
│       ├── ticket-grammar.sh                recognition home: TICKET_RE + ticket predicates · validator + status both source it (edit only to change the naming pattern; any board key already matches)
│       ├── init-ticket.sh                   ticket-init's full-template scaffold helper · local month/sequence, duplicate refusal, pending completion preview · never invents ticket facts
│       ├── portability.sh                   shared GNU/BSD shims: ts14→epoch, sourced by validator + status (one home · no drift)
│       ├── append-notebook-cell.py          ← check-scribe · THE ONE DOOR into a notebook: appends one selected evidence capsule · runs on whatever python3 is on the path, needs nbformat [user-created prereq]
│       ├── make-context-pack.sh             → ~/Desktop/harness-pack-*.zip [disposable · outside repo] · scrub table user-owned, KEEP on upgrade
│       ├── tracker-sweep.sh                 human-run · on-demand board-vs-estate drift report · pluggable fetch seam · tracker-agnostic · fails open offline
│       ├── retro-stats.sh                    dumb counter for the retrospective agent · tickets-by-month + checks + promotions · offline · exits 0 always
│       ├── deploy-agents.sh                 → user-level agent dir (sync source → live)
│       ├── init-ticket.sh                   ← ticket-init · allocates the folder and copies the template; the agent owns every fact
│       ├── check-work-map.py                ← SessionStart hook │ human-run · read-only Work Map link observer · warnings only
│       ├── parse-workbook.py                human-run · Mappings/ workbook → ticket Dump/workbooks/ (INDEX, version history, sheet CSVs, changes-<V>) · needs openpyxl · CONSTITUTION §10
│       ├── audit-inventory.py               ← estate-auditor │ human-run · read-only inventory: ticket staleness, PRs, walkthroughs, broken #anchors, pipeline-page sections · CONSTITUTION §15
│       ├── anchor-style.py                  human-run · rewrites section links between GitHub slugs and Obsidian heading text · --check reports unresolved links
│       ├── harness-housekeeping.sh          human-run · git gc + size report · never touches records
│       └── harness-drill.sh                 human-run · rehearse restore/bundle/undo · read-only toward the estate
│
├── _agents/                                 SOURCE OF TRUTH (versioned) · 15 agents · who reads what: AGENTS.md reading list
│   ├── ticket-init.agent.md                 ┐
│   ├── planner.agent.md                     │ hand-started · plans, writes Agent-Prompts/, reviews Agent-Output/
│   ├── implementer.agent.md                 │ hand-started · runs ONE prompt · no ticket log, no agents
│   ├── ticket-closer.agent.md               │ hand-started · close-out + walkthrough (CONSTITUTION §14)
│   ├── estate-auditor.agent.md              │ hand-started · dated audit + batch fixes + walkthrough backfill (CONSTITUTION §15)
│   ├── estate-question.agent.md             │ hand-started · answers one general question with citations · writes nothing
│   ├── ticket-scribe.agent.md               │ deploy-agents.sh → user-level dir
│   ├── ticket-recall.agent.md               │
│   ├── check-scribe.agent.md                │   [live · derived · unversioned]
│   ├── doc-writer.agent.md                  │   drift check (status): differ ⇒ FAIL
│   ├── knowledge-keeper.agent.md            │   fix ⇒ re-run deploy-agents.sh
│   ├── knowledge-curator.agent.md           │
│   ├── weekly-digest.agent.md               │
│   ├── harness-recall.agent.md              │
│   └── retrospective.agent.md               ┘
│
├── Tickets/                                 RECORDS ONLY
│   ├── README.md                            thin pointer (the map lives at the Work root)
│   └── YYYYMM<seq>-<BOARD>-<num>/            one per ticket (recommended name; template: 999912Z-PROJ-99999)
│       ├── YYYYMM<seq>-<BOARD>-<num>.md       source of truth ← ticket-scribe (log + state, atomic)
│       ├── <BOARD>-<num>-walkthrough.md       ← ticket-closer via doc-writer · one human-facing walkthrough at close-out (CONSTITUTION §14.1)
│       ├── Agent-Prompts/NN-<slug>.md         ← planner · one prompt per implementer run (CONSTITUTION §11.1) [tracked]
│       ├── Agent-Output/NN-<slug>.md          ← implementer · its handback for the matching prompt [tracked]
│       ├── AI-Knowledge/                    ← knowledge-keeper (capture) │ curator (compact)
│       │   ├── _index.md                    roster · tombstones
│       │   └── *.md                         —promotion (approved)→ General AI-Knowledge/
│       ├── Checks/                          selected durable evidence (any language) · routine checks stay ephemeral · workspace default kernel
│       ├── Logs/                            [gitignored · regenerable bulk]
│       └── Dump/                            [gitignored · re-droppable inputs · workbooks/ = parse-workbook.py output]
│
├── General AI-Knowledge/                    durable knowledge (versioned · cull-safe via history)
│   ├── _index.md                           read-before triggers for reusable knowledge, tools and ways of working
│   ├── AI Harness/                          the sheets + build/design notes · Last reviewed: dated
│   ├── Work Map/                            THE HUB · associations, not lineage · _index.md starts empty and links every repo card, runbook and pipeline page as real work establishes them (CONSTITUTION §9.1–9.2)
│   │   ├── Pipelines/                       one page per pipeline · the one home of its facts (identity card, deploy, validate UAT/PROD)
│   │   └── Repos/                           one card per repo · routing: path, code-host repo, default branch, runbook, pipelines hosted
│   └── Skills/                              the worker tier's craft modules + Doc-* documentation targets · _index.md is BOTH the convention home and the availability index (read the index, then ONE SKILL.md)
│
├── General Human Knowledge/                 human-facing references and dated outputs · agents may read both
│   ├── _index.md                           living discovery index
│   ├── Harness Guide.md                    operator guide · what runs by itself, who starts which agent, model pins, sample prompts
│   ├── Repo Workflows/                     living repo runbooks · _index.md routes to verified delivery and environment steps
│   ├── Audits/                             ← estate-auditor · one dated report per audit, "Work commit audited: <sha>" · _index.md is living
│   └── Retrospectives/                      ← retrospective agent · one timestamped file per run
│
├── _retired/<timestamp>/                    QUARANTINE — appears only after install.sh --upgrade [gitignored · deliberately outside the record]
│   └── <original path>                      your copy of a replaced or superseded file, moved never deleted · the run printed the mv that restores it
│
├── _rehearsal/                              appears only after install.sh --rehearsal [gitignored · outside the record, like _retired/]
│   ├── agents/                              where a PRACTICE run deploys, instead of your live assistant directory
│   └── state/                               where a PRACTICE run stamps, instead of ~/.harness/validated
│
└── [GitHub/ · Diagrams/ · Mappings/ · …]    [never enter history — whitelist excludes them] · Mappings/ = design workbooks, parsed into a ticket's Dump/ (CONSTITUTION §10)
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
`CONSTITUTION.md` for the worked example.
