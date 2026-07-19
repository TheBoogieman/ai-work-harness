# AI Work Harness — Workspace Backbone

> **For AI agents:** Read this file at the start of every session. It explains who this workspace belongs to, how it is organised, and the conventions you must follow when logging work or creating ticket folders.
>
> **Context budget (STRICT):** By default, load only (1) **PART I** of this file and (2) the target ticket's header + **Current State** section. Do **not** read the full Session Log, the `AI-Knowledge/` contents, or `Logs/` unless the user explicitly asks for a deep dive or the Current State points you at a specific file. Context is metered — organise it, don't hoard it.
>
> **PART II routing (load only the section your task needs):** initialising a ticket → *Ticket Initialisation Procedure* · a FAIL/WARN at entry, or any operational question → *Session States* · building a review pack → *Context Pack Convention* · estate health → *Harness Status Convention*.
>
> **Check logging (STRICT):** record every ad-hoc verification — SQL, Python, shell, whatever your work is — in the ticket's `Checks/checks_master.ipynb`, so the check + its result are kept; see the note under §2.

---

## Owner

**<Your Name>** — <Your Role>, <Your Team>. (Edit me on install.)

---

# PART I — SESSION CORE (always loaded)

---

## Folder Structure (the `Work/` root — the directory containing this file)

```
Work/
├── Tickets/        Active and completed Jira ticket working folders
│   └── README.md   Thin pointer (the validator only validates recognised names; harness-status surfaces the rest)
├── GitHub/         Local checkouts of your code repos (primary dev work; never touched by the harness)
├── General AI-Knowledge/  Non-ticket knowledge base — tooling/setup/how-to docs (one subfolder per topic)
├── _harness/scripts/   THE MACHINERY — validator, status, notebook helper, context pack, agent deploy (versioned: the enforcement layer has undo + history)
├── _agents/        SOURCE OF TRUTH for all .agent.md definitions (versioned; deployed to the user-level Copilot agent directory — live copies are derived and disposable; filesystem wins on drift)
├── <anything else>/  Your other folders — untracked by the whitelist, no conventions imposed
└── folder-structure.md   ← this file
```

Ticket folders live **outside** the VS Code multi-repo workspace (`GitHub/<your>.code-workspace`), so nothing under `Tickets/` can be committed to a team repo by mistake.

`Work/` is the root of a **LOCAL-ONLY git repository**, scoped by a WHITELIST `.gitignore`: everything is untracked by default, and only the record set is re-included — `folder-structure.md`, `AGENTS.md`, `_agents/`, `_harness/`, `Tickets/`, and `General AI-Knowledge/`. Within tickets, each `Logs/` and `Dump/` is ignored too (regenerable output and re-droppable inputs — working bulk, not records; the record is the ticket `.md`, `AI-Knowledge/`, and the `Checks/` notebook). Every other folder in `Work/` — `GitHub/` and any other folder you keep here — never enters history by construction, so new folders are automatically outside. One history for all records means promotion never exits version control and culling stale knowledge is safe. The repo versions records, not the warehouse. No remote ever exists; nothing ever pushes.

---

## Ticket Naming Convention

Nothing requires a specific ticket-folder name. Name folders however suits
your workflow. The tools recognise a **recommended default pattern** out of
the box but never force it — naming is nudged, never enforced. A `Tickets/`
folder is always in exactly one of four states:

1. **Matches the pattern + holds a ticket record → auto-validated.** A real,
   enforced ticket: the entry-gate validator checks its log and Current State
   every session.
2. **Hand-made, holds a ticket record, doesn't match → a heads-up (WARN).**
   `harness-status` surfaces it so you never mistake an unvalidated folder for
   a validated one: rename it to match, or — if it isn't really a ticket —
   `touch .not-a-ticket` to silence it. Never blocked.
3. **Pending (`.ticket-pending`) → a non-silenceable WARN.** When `ticket-init`
   creates a ticket but can't name it properly (tracker unreachable **and** no
   identity supplied), it gives the folder a deliberately non-conforming
   placeholder name and drops a `.ticket-pending` marker. Completing it takes
   **two steps**: rename the folder to a conforming name, **and** remove the
   `.ticket-pending` marker. `harness-status` nags every session until both are
   done — while the name is still non-conforming it says "rename to a conforming
   name to complete it"; once the name conforms but the marker lingers it
   switches to "remove it to finish: `rm .../.ticket-pending`". The **marker**,
   not the name, is the lifecycle token: a conforming rename alone never
   completes a pending ticket, so a real ticket can never be silently misfiled
   under a made-up conforming name. The pending WARN takes precedence over
   `.not-a-ticket`, so a real pending ticket can't be dismissed; only the
   recorded human act of removing the marker finishes it.
4. **No ticket content, or marked `.not-a-ticket` → silent.**

Nothing is ever blocked — there is no red `FAIL` for a naming choice; the
tools nudge with yellow, never wall you off. The two markers:

- `.not-a-ticket` — "this folder is **not** a ticket, leave it alone."
  Silences the state-2 heads-up. Your call; tracked in git, so silencing is a
  recorded, versioned choice.
- `.ticket-pending` — "this **is** a real ticket, still awaiting completion."
  Non-silenceable; the folder is completed by renaming it to a conforming name
  **and** removing this marker (a recorded human act). A conforming rename
  alone does not finish it — the marker is the lifecycle token, so a real
  ticket can't slip through silently misfiled.

The **recommended default** pattern:

```
YYYYMM<seq>-<BOARD>-<num>
```

| Part      | Meaning                                                                            |
|-----------|-----------------------------------------------------------------------------------|
| `YYYYMM`  | Year+month the ticket was picked up — exactly 6 digits (the only fixed-width part) |
| `<seq>`   | Chronological order within the month — one or more letters (A, B, … Z, AA, AB, …; unbounded, so a month is never capped) |
| `<BOARD>` | Your issue-tracker board key (set your own)                                        |
| `<num>`   | The tracker's ticket number — digits, any length                                  |

**Example:** the first ticket picked up in May 2026, ticket number
PROJ-65474 → `202605A-PROJ-65474`. A busy month past `Z` rolls to `AA`,
`AB`, … — `ticket-init` asks you how to extend rather than guessing.

### Using your own scheme — one editable home

The recognition pattern lives in exactly one place: the `TICKET_RE` line in
`_harness/scripts/ticket-grammar.sh`, sourced by both the validator and
`harness-status`, so editing that one line moves both tools together. Real
teams have board schemes the default can't anticipate; adapting is a one-line
change.

**Worked example — a hyphenated board key.** A team whose issue-tracker board
key contains a hyphen (e.g. `DATA-ENG`, so tickets read like
`202607A-DATA-ENG-42`) finds these **unrecognised by default**: the default
pattern expects a single board segment with no internal hyphen, so the extra
`-ENG` segment doesn't match. The right fix is **not** to mark them
`.not-a-ticket` (they ARE tickets) — it's to widen the board segment in
`ticket-grammar.sh` to allow hyphens: `[A-Z0-9]*` → `[A-Z0-9-]*`. One line,
and both tools now validate the team's real tickets. This is the canonical
reason the pattern is editable: the default stays hyphen-free on purpose —
for the common case it keeps names unambiguous and human-parseable — while
editability is the escape hatch for everyone whose board it can't anticipate.

---

## Ticket Workflow

### 1. Local ticket folder — initialised via the `ticket-init` agent
When picking up a new ticket, invoke **`ticket-init`** with the Jira link. Its 8-step procedure — also the manual fallback — lives in **PART II → Ticket Initialisation Procedure**.

The resulting folder:

```
Tickets/
└── 202605A-PROJ-65474/
    ├── 202605A-PROJ-65474.md    ← primary ticket log file (source of truth)
    ├── AI-Knowledge/           ← AI agent memory .md files for this ticket (indexed + compacted, see below)
    ├── Checks/                 ← reproducible evidence: checks_master.ipynb (+ scratch files / per-tool subfolders as YOUR stack needs)
    ├── Logs/                   ← long run logs (build/test/pipeline output) — dump here so grep can slice them
    └── Dump/                   ← user-dropped misc files for the AI to read (.csv, screenshots, .docx/.pptx/.eml)
```

Any supporting files (spreadsheets, exports, scripts, etc.) also live in this folder.

Each ticket folder has four standard subfolders:

- **`AI-Knowledge/`** — AI agent memory/knowledge `.md` files for this ticket (see *AI Memory Convention* below — including the **index + compaction** rules).
- **`Checks/`** — the ticket's reproducible evidence, in ANY language your work needs (SQL, Python, shell, API probes). `checks_master.ipynb` is the default recorder — one markdown why-note + one code cell per verified check, appended via `append_notebook_cell.py`, on the `venv_global` kernel (register other kernels freely). Disposable spot-checks can live in scratch files; anything worth remembering goes in the notebook. Add per-tool subfolders if your stack wants them — the harness imposes none.
- **`Logs/`** — long-running command output (e.g. build/test output, dbt runs, pipeline logs). **AI agents: always redirect long logs here** instead of printing them into chat, so they can be sliced with `grep`/`tail`/`awk` and don't overflow the session context window.
- **`Dump/`** — the "landfill" for user-generated misc files dropped in for the AI to read: `.csv` extracts, screenshots (`.png`/`.jpg`), `.docx`/`.pptx`/`.eml`. This is *user input for the AI*, distinct from checks you write (`Checks/`) and command output (`Logs/`). **No customer PII, credentials, or secrets ever land in `Dump/`** — if an extract contains PII it doesn't belong in this folder tree at all; work with it in the approved location and reference it by path/description instead.

> **STRICT — check logging (AI agents & humans):** Run **all** ad-hoc verifications through **`Checks/checks_master.ipynb`** — **never** as throwaway terminal one-offs that vanish. Add each check as a new cell with a one-line markdown note (*what* and *why*), so the check **and its result** are preserved as a reproducible record of everything verified on the ticket. Disposable spot-checks may use scratch files, but anything worth remembering goes in the notebook.

**Python environment (PREREQUISITE):** the harness assumes a venv named exactly **`venv_global`** (Python 3.12, carrying the dbt toolchain + `nbformat`), created BY THE USER — the harness never creates it, it only depends on it. It must be set as the **workspace default interpreter** (in `GitHub/<your>.code-workspace`), so new terminals under `Work/` auto-activate it and notebooks default to its kernel — every ticket picks it up automatically. It also backs the Data Wrangler extension (view/clean `.csv`/`.parquet`/`.xlsx`). See *General AI-Knowledge/Python Environment*; create a repo-specific venv only when a repo needs different pins.

### 2. Ticket markdown file (`YYYYMM<seq>-<BOARD>-<num>.md`)
This is the **source of truth** for everything done on the ticket. It restores AI agent context without blowing up the context window — via the **Current State** section, not the full history.

**Top-level structure (strict order):**
```markdown
# <BOARD>-<num> — <Short Ticket Description>

**Ticket:** <Jira URL>
**Local path:** Work/Tickets/YYYYMM<seq>-<BOARD>-<num>

Repos:
- Work/GitHub/<repo>

Branches:
- `<branch>` in `<repo>`

Pull Requests:
- [#NNN](<PR URL>) in `<repo>` — draft | in review

---

## Current State
<3–8 sentences, always up to date — see convention below>

## Background
<Why this ticket exists, business context>

## Scope / What needs to be done
<Checklist or description of work>

## Changes Made
<Technical detail of what was changed and where>

---

## Session Log
```

Every ticket markdown file must include the **Repos**, **Branches**, and **Pull Requests** sections directly after the header, listing the repos worked in, the branches, and all active PRs (draft and in-review) with links, repo, and state. Keep them current as repos, branches, or PRs change.

---

## Current State Convention

**`## Current State` is the section AI agents read to rehydrate.** It is a living summary, 3–8 sentences, always reflecting *right now*:

- Where the work stands (done / in flight / blocked, and on what).
- The immediate next step.
- Anything non-obvious an agent must know before touching the ticket (gotchas, decisions made, files that matter).
- Pointers into `AI-Knowledge/` or the Session Log **only when** deeper context is genuinely needed (e.g. "see `AI-Knowledge/field-mapping.md` before editing the staging model").

**AI agents: update Current State at the end of every session, as part of the same step as the Session Log append.** Overwrite it — unlike the Session Log, it has no history; history lives in the log. If the user asks a question the Current State can't answer, *then* deep-dive the Session Log / AI-Knowledge and say you're doing so.

---

## Session Logging Convention

**Default: automatic.** At the end of every completed task or working session, the AI agent appends a chronological record of work actions to the ticket markdown file under **Session Log** — without waiting to be asked. The user vetoes or amends; they do not have to initiate. (The user may still say "log this now" mid-session to force a checkpoint.)

**Section header format (strict — do not deviate):**
```
## YYYYMMDDHHMMSS - [Short one line description of session update]
```

**The timestamp is LOCAL machine time** — the same clock as the shell command
`date +%Y%m%d%H%M%S`. Do not write UTC (unless the machine's timezone is UTC):
the validator interprets this header in the machine's local timezone, so a
header written in a different zone can be misread as stale and wrongly
red-block the next session.

**Example:**
```markdown
## 20260611143000 - Threaded the new field through the staging SQL

- Reviewed existing dbt models in `<your dbt repo>`
- Added `dm_new_metric` CTE to `intm__staging_model.sql`
- Fixed sqlfluff violations (table qualifiers, capitalisation)
- Updated unit test YAML to include the new field mock input
- Opened PR `feature/PROJ-99999_example` for review
```

Logs are bullet points only — concise, factual, in past tense. Each new session appends a new block; older blocks are never edited. The header must strictly follow `## YYYYMMDDHHMMSS - [Short one line description of session update]` — no other format is accepted.

Appending a Session Log block and refreshing **Current State** (and the Repos/Branches/PRs sections if they changed) are **one atomic step** — never do one without the other.

---

## AI Memory Convention

Create any new memory `.md` files under `Tickets/YYYYMM<seq>-<BOARD>-<num>/AI-Knowledge/`. If memory must be created in session/agent memory first (where the folder is not directly writable), copy those `.md` files into the ticket's `AI-Knowledge/` folder after creation. Each ticket's AI knowledge base lives in its own `AI-Knowledge/` subfolder so context survives across sessions.

**Index + compaction rules (STRICT — this folder is not a landfill):**

- Maintain an **`AI-Knowledge/_index.md`** whose every line follows this canonical grammar — the SINGLE authoritative spec the validator and both knowledge agents anchor on:
    - **Entry line:** `- <file>.md — <what it covers> — <when to read it>`
    - **Tombstone line:** `- <file>.md (promoted -> General AI-Knowledge/<Topic>)`
    - **Comment line:** any line starting with `#` is INERT — not an entry.
    - **Placeholder:** any token wrapped in `< >` (e.g. `<file>`, `<Topic>`) is illustrative and INERT — never parsed as a real filename.
    - **Rule:** every entry begins with `- ` (dash-space); the filename is the FIRST token after `- `. Prose after the filename (the `—` descriptions) is NOT parsed for filenames.
- Agents read the index first and pull **only** the specific files the task needs; never bulk-read the folder.
- **Before creating a new file, check the index.** If a file on the topic exists, extend or rewrite it — do not create `topic-2.md` / `topic-final.md` variants.
- **Compact on close-out** (and whenever the folder exceeds ~10 files): merge overlapping files, delete anything superseded or restatable in one Current State sentence, and refresh the index. Knowledge worth keeping long-term beyond the ticket graduates to `General AI-Knowledge/`.
- Prefer updating **Current State** over writing a memory file. A memory file earns its place only when the content is too long or too specialised for the ticket log.

---

## General AI-Knowledge Convention

Work that is **not tied to a Jira ticket** — tool setup, local environment configuration, reusable how-tos — is documented under `General AI-Knowledge/`. Each distinct topic gets its own subfolder containing a single, self-contained, human-readable markdown file named after the topic.

```
General AI-Knowledge/
└── AWS CLI Setup/
    └── AWS CLI Setup.md
```

Conventions:
- **One subfolder per topic**; the folder name *is* the topic (e.g. `AWS CLI Setup`).
- The markdown file mirrors the folder name and should stand alone: what was done, why, the exact commands, and a worked **Example** section.
- **Never commit secrets** (access keys, tokens). Use placeholders and reference the discovery commands instead.

---

## GitHub Repos (Key ones)

All repos live under `Work/GitHub/` (relative to this workspace root). List YOUR key repos here so agents can map ticket components to code — for example:

- `<org>/<dbt-models-repo>` — analytics models
- `<org>/<etl-repo>` — pipeline code
- `<org>/<shared-modules-repo>` — shared libraries
- `<org>/<infra-repo>` — infrastructure config

---

# PART II — PROCEDURES & MAINTENANCE (load on demand)

---

## Ticket Initialisation Procedure (`ticket-init`, or manual fallback)

Invoked with the Jira link; every step below is also the by-hand fallback:

1. Pull the full Jira issue — summary, description, acceptance criteria, comments, and the epic/parent one level up. (If Jira is unreachable, fill Background/Scope with `TODO` markers from the interview instead of failing — a *content* fallback; naming is decided separately in step 3.)
2. Compute the ticket ID: scan `Tickets/` for this month's highest chronological letter and take the next one.
3. Copy the `999912Z-PROJ-99999` template; fill the header (Jira URL, local path); then **name the folder and `.md` per two outcomes, never a silent misfile.** When you *can* determine the ticket's identity (tracker reachable, or the user supplied it), give it a **conforming** name matching the recommended pattern — an immediately-validated ticket; you conform on the user's behalf. When you *cannot* (tracker unreachable **and** no identity supplied), do **not** invent a fake-but-conforming name (it would validate silently as a misfiled stub); instead give the folder a deliberately non-conforming placeholder name (e.g. `pending-<timestamp>`) and drop a `.ticket-pending` marker inside it — a non-silenceable pending ticket that `harness-status` nags about until it is *completed*: renamed to a conforming name **and** the `.ticket-pending` marker removed (both steps — the marker, not the name, is what clears the nag, so a conforming rename alone can't leave a real ticket silently misfiled). The nag is the intended safety mechanism.
4. Present a short digest of the issue, then ask the user EXACTLY three things: (a) a paragraph explaining the ticket **in their own words**, (b) the **non-negotiables**, (c) the repo(s) involved.
5. Write **Background** — leading with the user's paragraph as an "**In my words:**" block, followed by the Jira-derived context — and **Scope**, leading with a "**Non-negotiables**" checklist.
6. **Adjacency scan:** grep prior ticket titles and Current States plus the `General AI-Knowledge/` index for related work; record any hits as pointers in Current State (e.g. "see 202605A-PROJ-65474, AI-Knowledge/field-mapping.md").
7. For each repo given, suggest 2–3 branch names in the `feature/PROJ-XXXXX_<short-slug>` convention; the user picks or edits; record the choice in **Branches**. The agent NEVER creates branches or touches `GitHub/` — recording only.
8. Seed a 3-sentence **Current State** (not started / next step / gotchas), then invoke `ticket-scribe` for the init Session Log entry.

## Session States — Operational Rules

The one rule: **red blocks, yellow schedules.** `FAIL` = fix before any new
work. `WARN`/`NOTE` = keep working; schedule the chore at the next natural
boundary. Never fabricate a record to silence the gate — a gap you cannot
reconstruct is logged honestly AS a gap. These rules bind agents and human
alike.

**S0 — Green.** Entry gate silent. Work normally; scribe + keeper run at
task end as usual.

**S1 — FAIL at entry.** This is about the *previous* session, not the
current one. Triage in two bins:
- *Mechanical* (index orphan/ghost, missing section): apply the printed fix
  — delegable to the session agent. A minute, done.
- *Substantive* (missing Session Log entry, stale Current State):
  reconstruct honestly — from memory via `ticket-scribe`, or from
  `git -C <Work root> log` / `diff` — the Work root is the directory containing this file — (the auto-commits
  captured every write even though the paperwork failed). Late-but-true
  beats fabricated. Truly unreconstructable? Log it as:
  `## <ts> - Session unrecorded; changes per commits <range>`.
Then re-run `check_ticket_log.sh` to confirm green, and start work.

**S2 — WARN/NOTE nags.** Never interrupt flow for these. Fat index → run
`knowledge-curator` at ticket close-out or end of day. Zero-capture nag →
verify the keeper gets invoked at the next task end. Stale General
AI-Knowledge → batch into a review pass.

**S3 — Resumed, compacted, or abandoned sessions.** Entry validation
re-fires on resume; preCompact re-points the agent at the conventions. A
chat left idle for days: prefer a fresh session — the entry gate plus a
clean context beats a stale 200k-token one.

**S4 — An agent wrote garbage.** Git is the undo: inspect the log, revert
the specific paths, re-run the agent or fix by hand. The same failure
three times = upstream bug (agent instructions, contract, or platform) —
stop hand-fixing and take a context pack to a design session.

**S5 — The machinery itself is broken** (hook silent, agent missing from
the picker, a script erroring): run `harness-status.sh` and follow its
prescriptions. Machinery failure never blocks ticket delivery — but every
session run with broken machinery ends with a MANUAL `ticket-scribe`
invocation, and the breakage gets fixed before it becomes normal.

---

## Context Pack Convention (harness maintenance)

When taking the harness itself for external review/design (outside sanctioned
tooling), never hand-assemble files. Run:

```
_harness/scripts/make_context_pack.sh [--ticket <TICKET-ID>]
```

It stages the harness state — `folder-structure.md`, `README.md`,
`AGENTS.md`, all `.agent.md` files, the hooks config, `check_ticket_log.sh`,
and `General AI-Knowledge/AI Harness/` — applies the scrub table (employee
ID and personal paths → `<user>`, Jira/SharePoint URLs, Platform B account
locators, AWS profile/account names), and zips it with a datestamped name. With
`--ticket`, it additionally includes that ticket's `.md` and
`AI-Knowledge/_index.md` (scrubbed) — never notebooks, `Logs/`, or `Dump/`.

Output rules:
- The zip lands at `~/Desktop/harness-pack-YYYYMMDD-HHMM.zip` — OUTSIDE both
  repos, always. A pack is a derived view: disposable, regenerated on
  demand, deleted after upload, never stored anywhere inside the `Work/`
  repo (where auto-commit would archive it forever).
- Contents are deterministic: stable sorted file ordering (two packs from
  the same state are byte-comparable), OS junk excluded at staging, and a
  generated `MANIFEST.txt` inside listing every included file plus a
  self-audit line confirming zero scrub-table hits.

Rules:
- The scrub table lives at the top of the script — extend it there whenever a
  new identifier class appears; the script is the single source of scrubbing
  truth.
- The script prints a final reminder to **manually skim the zip before it
  leaves the machine**. Automation reduces redaction errors; it does not
  replace the human check.
- Structure travels, payload never does: no query results, no data extracts,
  no repo code in a context pack, ever.

---

## Harness Status Convention (on-demand health check)

To see the health of the whole estate — not just the last session — run:

```
_harness/scripts/harness-status.sh
```

Read-only, deterministic, no AI, no credits. **It prints to stdout and writes
nothing to disk** — status output is a derived view of the filesystem, never
stored state (derived views are regenerated, not kept). Want a snapshot? Redirect it yourself, deliberately.
It reports, with `OK` / `WARN` / `FAIL` prefixes:

- Per active ticket: last Session Log timestamp, Current State age,
  `AI-Knowledge/` file count and any nag conditions (fat index, sessions
  without capture).
- `General AI-Knowledge/`: entries whose `Last reviewed:` date is older than
  6 months.
- Liveness: last commit in the Work local git (auto-commit is alive),
  hooks config parses, all five `.agent.md` files present and registered
  (agents can fail to load *silently* after Copilot updates).

Every `FAIL` line includes the exact command or edit that fixes it.

Principle (applies to all harness tooling): **status observes, failures
prescribe, nothing heals itself.** No auto-repair, no dashboards — a fixed
record must always be a human act, or the audit trail stops meaning anything.
