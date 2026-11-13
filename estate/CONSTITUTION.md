# AI Work Harness — Constitution (the rulebook)

<!-- harness-upgrade: preserve-user-content -->

> **For AI agents:** this file is the **rulebook**; [AGENTS.md](AGENTS.md) is the **pointer**. Find your row in AGENTS.md and read only the numbered sections it lists — every section is linked from the [Contents](#contents) below. Overlap between rows is deliberate; a broad read of a whole Part is not.
>
> **Context budget (STRICT):** load your row's sections plus the target ticket's header and **Current State**, then follow the index-first [Context Discovery](#9-context-discovery) route. Do **not** read full Session Logs, `AI-Knowledge/` folders, `Logs/`, `Dump/`, `Agent-Prompts/` or `Agent-Output/` unless the task or a specific pointer requires it. Context is metered — organise it, don't hoard it.
>
> **Tools and authentication first:** before any remote call, read [§2 Tools and Authentication](#2-tools-and-authentication) and the local tools note it names. Read-only by default; the human completes MFA/SSO; secrets never pass through chat.
>
> **Check retention (STRICT):** routine verification is ephemeral. Preserve only an observed result that passes the [Durable Evidence Gate](#42-durable-evidence-gate) in the ticket's `Checks/checks_master.ipynb`; most searches, probes and validation runs never enter a notebook.

---

## Contents

**Navigation:** [AGENTS.md](AGENTS.md) (who reads what) · [Harness Guide](General%20Human%20Knowledge/Harness%20Guide.md) · [General AI-Knowledge](General%20AI-Knowledge/_index.md) · [General Human Knowledge](General%20Human%20Knowledge/_index.md) · [Work Map](General%20AI-Knowledge/Work%20Map/_index.md) · [Repo Workflows](General%20Human%20Knowledge/Repo%20Workflows/_index.md) · [Skills](General%20AI-Knowledge/Skills/_index.md)

**PART I — Session core** (read the sections your AGENTS.md row lists)

| § | Section | Subsections | Read it when |
|---|---|---|---|
| 1 | [Folder Structure](#1-folder-structure) | | You need to know where something lives |
| 2 | [Tools and Authentication](#2-tools-and-authentication) | | **Before any remote call** (cloud, code host, warehouse, scheduler, tracker, wiki) |
| 3 | [Ticket Naming Convention](#3-ticket-naming-convention) | | Creating, renaming or recognising a ticket folder |
| 4 | [Ticket Workflow](#4-ticket-workflow) | 4.1 [Ticket Folder](#41-ticket-folder) · 4.2 [Durable Evidence Gate](#42-durable-evidence-gate) · 4.3 [Ticket Markdown File](#43-ticket-markdown-file) | Working inside a ticket folder or keeping evidence |
| 5 | [Current State Convention](#5-current-state-convention) | | Reading or refreshing Current State |
| 6 | [Session Logging Convention](#6-session-logging-convention) | 6.1 [Record Ownership and Brevity](#61-record-ownership-and-brevity) | Writing any ticket record |
| 7 | [AI Memory Convention](#7-ai-memory-convention) | 7.1 [Durable Knowledge Gate](#71-durable-knowledge-gate) | Capturing or reading ticket `AI-Knowledge/` |
| 8 | [General AI-Knowledge Convention](#8-general-ai-knowledge-convention) | | Writing non-ticket knowledge |
| 9 | [Context Discovery](#9-context-discovery) | 9.1 [Linked Work Map](#91-linked-work-map) · 9.2 [Pipeline and Repo Pages](#92-pipeline-and-repo-pages) | Picking up work, or changing repo or pipeline |
| 10 | [Design Workbooks in Mappings](#10-design-workbooks-in-mappings) | | A task names a design spreadsheet or version |
| 11 | [Planner and Implementer Loop](#11-planner-and-implementer-loop) | 11.1 [Prompt and Output Files](#111-prompt-and-output-files) · 11.2 [Planner Duties](#112-planner-duties) · 11.3 [Implementer Boundaries](#113-implementer-boundaries) · 11.4 [The Review Gate](#114-the-review-gate) | Running or reading a planner/implementer iteration |
| 12 | [Agent Routing](#12-agent-routing) | | Choosing or invoking another agent |

**PART II — Procedures and maintenance** (load on demand)

| § | Section | Read it when |
|---|---|---|
| 13 | [Ticket Initialisation Procedure](#13-ticket-initialisation-procedure) | Starting a ticket |
| 14 | [Ticket Close-out Procedure](#14-ticket-close-out-procedure) — 14.1 [Walkthrough Document](#141-walkthrough-document) | Closing a deployed or concluded ticket |
| 15 | [Estate Audit Procedure](#15-estate-audit-procedure) | Auditing and tidying the estate |
| 16 | [Session States and Operational Rules](#16-session-states-and-operational-rules) | A FAIL/WARN at entry, or any operational question |
| 17 | [Harness Status Convention](#17-harness-status-convention) | Checking estate health |
| 18 | [Repo Health and Housekeeping](#18-repo-health-and-housekeeping) — 18.1 [Levelling an Estate](#181-levelling-an-estate) | The Work repo has grown large; levelling an estate to a newer source |
| 19 | [Skills Convention](#19-skills-convention) | Craft work, or choosing a documentation target |

**PART III — Rarely used** (only when the task names one of these)

| § | Section | Read it when |
|---|---|---|
| 20 | [Using Your Own Ticket Naming Scheme](#20-using-your-own-ticket-naming-scheme) | Changing the folder-name pattern (a new board needs no change) |
| 21 | [Context Pack Convention](#21-context-pack-convention) | Building a harness review pack for an outside design review |
| 22 | [Porting to Another AI Assistant](#22-porting-to-another-ai-assistant) | Moving the harness to another assistant |

**Local appendix** (edit on install): [Owner](#owner) · [GitHub Repos](#github-repos)

---

# PART I — SESSION CORE

---

## 1. Folder Structure

Estate root: the `Work/` directory holding this file.

```
Work/
├── AGENTS.md       THE POINTER — which sections of this file each agent reads, plus navigation links
├── CONSTITUTION.md ← this file (THE RULEBOOK)
├── Tickets/        Active and completed ticket working folders, from one board or several (tree in §4.1; the validator only validates recognised names; harness-status surfaces the rest)
├── Mappings/       Design workbooks (.xlsx) — the canonical copies the user names per task; read through parse-workbook.py (§10); never edited by agents
├── GitHub/         Local checkouts of your code repos (primary dev work; never touched by the harness). Work in any of them goes through a ticket on the board that tracks it (GitHub Repos, at the end of this file)
├── General AI-Knowledge/  Non-ticket knowledge base — what the machinery READS: Work Map/ (Pipelines/ and Repos/ pages, §9.2), Skills/ (craft and Doc-* documentation targets, §19), one subfolder per other topic (tooling, setup, how-to)
├── General Human Knowledge/  Human-facing OUTPUTS (Harness Guide.md, Repo Workflows/, Audits/, Retrospectives/) — what the machinery WRITES for you; agents may read these references too (versioned; history append-only, references living — see below)
├── _harness/scripts/   THE MACHINERY — validator, status, notebook helper, context pack, agent deploy (versioned: the enforcement layer has undo + history)
├── _agents/        SOURCE OF TRUTH for all .agent.md definitions (versioned; deployed to the user-level Copilot agent directory — live copies are derived and disposable; filesystem wins on drift). That directory is SHARED BY EVERY ESTATE ON THE MACHINE and is one of the few things the harness writes outside an estate: THE FIRST DEPLOY CLAIMS IT and records which estate it came from; EVERY LATER ONE MUST PROVE IT OWNS IT, so a deploy from a different estate REFUSES and names the two ways to say which run it is (`HARNESS_AGENT_DEPLOY_DIR` for a rehearsal, `HARNESS_AGENT_ADOPT=1` for a hand-off). Installing an estate meets no friction from this. A practice install declares itself with `install.sh --rehearsal` and writes nothing outside its own target.
└── <anything else>/  Your other folders — untracked by the whitelist, no conventions imposed
```

Ticket folders live **outside** the VS Code multi-repo workspace (`GitHub/<your>.code-workspace`), so nothing under `Tickets/` can be committed to a team repo by mistake.

`Work/` is the root of a **LOCAL-ONLY git repository**, scoped by a WHITELIST `.gitignore`: everything is untracked by default, and only the record set is re-included — `CONSTITUTION.md`, `AGENTS.md`, `_agents/`, `_harness/`, `Tickets/`, `General AI-Knowledge/`, and `General Human Knowledge/`. Within tickets, each `Logs/` and `Dump/` is ignored too (regenerable output and re-droppable inputs — working bulk, not records; the record is the ticket `.md`, the walkthrough, `AI-Knowledge/`, the `Checks/` notebook, and the `Agent-Prompts/` / `Agent-Output/` iteration ledger). Every other folder in `Work/` — `GitHub/`, `Mappings/` and any other folder you keep here — never enters history by construction, so new folders are automatically outside. One history for all records means promotion never exits version control and culling stale knowledge is safe. The repo versions records, not the warehouse. No remote ever exists; nothing ever pushes. For personal, uncommitted ignores beyond the shared whitelist, use `.git/info/exclude` (local-only, never shared or tracked).

`General Human Knowledge/` mirrors `General AI-Knowledge/` the other way round: GAK is what the machinery **reads**, GHK is what it **writes for you** — human-facing outputs (`Retrospectives/` from the `retrospective` agent, `Audits/` from `estate-auditor`, `Repo Workflows/` and the `Harness Guide.md`). Two rules govern it:

- **HISTORY IS APPEND-ONLY; REFERENCES ARE LIVING.** Dated deliverables, including `Retrospectives/` and `Audits/` (estate audits, §15), are timestamped and never rewritten once frozen: an audit report freezes when its audit session ends, and a retrospective stays open for the user's in-place edits and cuts until they agree to close it. A later retrospective or audit is a new file; only `Audits/_index.md` and `Retrospectives/_index.md` are living. `Repo Workflows/`, `Harness Guide.md`, `General AI-Knowledge/Work Map/` and the discovery `_index.md` files are living references: correct them in place when their sources change, and note substantive runbook corrections in their index. New folders are append-only unless explicitly declared living here. Agents may read human-facing runbooks; the audience label is not an access restriction.
- **INSIDE THE WHITELIST.** These artifacts **are** record — a review deliverable is worth keeping and versioning — so the folder is re-included above and its contents are tracked and auto-committed like any other record, never treated as disposable scratch.

---

## 2. Tools and Authentication

> **Read this before any remote call.** Keep the live inventory — installed CLIs, exact cloud profiles, warehouse connections, scheduler workspaces and agent model pins — in one local tools note under `General AI-Knowledge/` (for example `Tools and Environments/`), routed from its index, with per-tool setup notes beside it. This section owns the rules; that note owns the facts.

Use available tools for task-relevant authoritative facts before asking the user
to paste output. They are optional adapters, not harness dependencies. Pick the
tool by the question, in this order:

| Question | First tool | Then |
|---|---|---|
| Cloud state: storage, catalog tables, query engine, batch jobs | your cloud CLI with an explicit profile (for example `aws ... --profile <exact profile>`) | — |
| PRs, CI runs, branches, releases | `gh` (or your code host's CLI) | the code host's web UI |
| Warehouse objects, row counts, approved queries | your warehouse CLI with a named connection | the data catalog, for metadata only |
| Lineage: what feeds or reads a table, which job writes it, column lineage | the data catalog's lineage search, if configured | repo code search |
| Catalog metadata: owners, descriptions, tags, data-quality verdict | the data catalog | — |
| Scheduler deployments and runs | the scheduler's CLI | its web UI |
| Tracker issue fields, status, search | your tracker CLI or MCP server | the tracker's web UI |
| Wiki pages and search | your wiki MCP server or CLI | — |
| Obsidian views: property search, Bases rows, links and backlinks | Obsidian's CLI, read commands only, with the app running (Harness Guide, "Obsidian") | the Obsidian app, without editing a view |

**Boards.** An estate may hold tickets from one board or several, each on its own tracker. List
them in the tools note's **Boards** table, one row per board:

| Board | Tracker: where its issues live | Identity rule: issue → `<BOARD>-<num>` | Repos it delivers into | Closed words |
|---|---|---|---|---|
| `<BOARD>` | the tracker and its project or repo | for example the issue number as is, or a number carried in the issue title | `GitHub/<repo>`, … | only if they differ from `tracker-sweep.sh`'s default |

This section owns the shape; the tools note owns the rows. The ticket grammar (§3) accepts any
board key, so a new board needs a row and no machinery change. `ticket-init` takes the board and
its identity rule from this table ([§13](#13-ticket-initialisation-procedure)). A one-board
estate may keep one row, or none.

**Standing delegation.** An operator who runs the `orchestrator` ([§12](#12-agent-routing)) may
let it approve, merge, push or act on audit findings for them. Only the operator writes that grant,
in the tools note's **Standing delegation** section: their own words, quoted, with the date and
what they cover. No agent writes, widens or relays it. An agent asked to accept the orchestrator's
yes finds the quoted words there ([AGENTS.md](AGENTS.md) Definitions: Approval). With no section,
the operator approves everything, exactly as before.

Check availability and the local tools note first; never assume a tool or profile
exists, and a configured tool is not an authenticated one. Catalog, tracker and
wiki writes (tags, descriptions, comments, links, transitions) are remote
mutations: draft them, never apply them without the user's explicit approval. If
a tool is unavailable, state the limit and the next useful action.

- **Resolve the target first.** Resolve the configured profile/connection, account,
  region, role and test/production target from the local tools note and the repo
  runbooks before a remote operation. Do not infer per-environment profiles, silently
  fall back to a default account, or switch environment to bypass denied access.
  Actual mappings belong in those local references, not public agent contracts.
- **Reads run unasked; changes wait.** Run the read-only check that settles a fact
  without asking permission to look, and say what you ran. Request explicit
  approval before changing remote data, infrastructure or tracker state;
  authentication is access, not permission to mutate. After the approval, the
  agent that asked makes the change itself, a tracker post, a PR or a push
  included; it does not hand the user a draft and send them elsewhere. Do not run
  unrelated services on every task.
- **The human authenticates.** For MFA, passkeys, SSO or key passphrases, leave the
  terminal, system or browser prompt visible and ask the human to complete it
  directly (for example "Please enter the MFA code in the dialog"). Some agent
  hosts run commands without an interactive terminal (stdin is not a TTY), so a
  terminal prompt either fails or waits where the human cannot answer it. On such
  a host, use a credential helper that shows a system dialog or reads the OS
  keychain, and run every command that can prompt inside a time limit (for
  example `timeout 180s ...`); record both in the local tools note. Wait and
  resume the same operation after completion. If the time limit expires, report
  it and do not retry while a prompt is still open; never retry in a loop,
  abandon the check, switch profile, or substitute an assumption. Never collect
  secrets through chat/question tools, echo them, save them, or wrap interactive
  commands in output filters.
- **Tell the human before a prompt.** Before running a command you expect to ask
  for MFA or a sign-in, say so and wait until the human is present; a prompt
  nobody answers only times out.
- **Only secrets are banned.** API keys, passwords, tokens, credentials and raw
  authentication output never go into any record, prompt, output, draft or chat.
  Everything else may be recorded as observed: customer and account identifiers,
  names, query text with literal values and result rows, in ticket logs,
  notebooks, prompts, outputs, knowledge notes and drafts for the tracker or an
  internal PR, at whatever size the record needs. Do not redact it, reduce it to
  counts or ask again before writing it. An estate whose organisation is stricter
  says so in its tools note, and that note then governs. One surface stays
  generic whatever the estate allows: a public repository, issue or PR, and the
  context pack, which stays scrubbed ([§21](#21-context-pack-convention)).
  Report an unverified result honestly.

---

## 3. Ticket Naming Convention

Every ticket folder is named by the **recommended default** pattern:

```
YYYYMM<seq>-<BOARD>-<num>
```

| Part      | Meaning                                                                            |
|-----------|-----------------------------------------------------------------------------------|
| `YYYYMM`  | Year+month the ticket was picked up — exactly 6 digits (the only fixed-width part) |
| `<seq>`   | Chronological order within the month — one or more letters (A, B, … Z, AA, AB, …; unbounded, so a month is never capped) |
| `<BOARD>` | The key of the board the ticket comes from; an estate may hold several ([§2](#2-tools-and-authentication), Boards) |
| `<num>`   | The ticket's number on that board, by the board's identity rule — digits, any length |

**Example:** the first ticket picked up in May 2026, ticket number
PROJ-65474 → `202605A-PROJ-65474`. A busy month past `Z` rolls to `AA`,
`AB`, … automatically. The primary record inside it has the same name plus `.md`. Tickets from several boards sit side by side under the same pattern (`202605B-XRAY-812` beside `202605A-PROJ-65474`), and the month sequence runs across all of them.

Never pick the letter by hand: `init-ticket.sh` allocates the name from the local
machine month and existing names, not from the chat date or folder count ([§13](#13-ticket-initialisation-procedure)
step 5). The pattern is one line, `TICKET_RE` in `_harness/scripts/ticket-grammar.sh`,
sourced by both the validator and `harness-status`; changing it is
[§20](#20-using-your-own-ticket-naming-scheme).

**How the tools treat a folder name.** A name matching the pattern commits the
folder to validation; any other name is nudged, never blocked. By name and markers,
a `Tickets/` folder falls into one of four states (with one validation edge case
noted after the list):

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

Nothing is ever blocked *for a naming choice* — the tools nudge with yellow,
never wall you off. (One edge case sits outside these four states: a recognised
name additionally commits the folder to validation, so a conforming folder that
is MISSING its `.md` record is a validator `FAIL` — fix by adding the record,
not by a naming nudge.) The two markers:

- `.not-a-ticket` — "this folder is **not** a ticket, leave it alone."
  Silences the state-2 heads-up. Your call; tracked in git, so silencing is a
  recorded, versioned choice.
- `.ticket-pending` — "this **is** a real ticket, still awaiting completion."
  Non-silenceable; the folder is completed by renaming it to a conforming name
  **and** removing this marker (a recorded human act). A conforming rename
  alone does not finish it — the marker is the lifecycle token, so a real
  ticket can't slip through silently misfiled.

---

## 4. Ticket Workflow

A ticket's life: `ticket-init` scaffolds the folder (§13) → `planner` and `implementer` iterate (§11) → `ticket-scribe` records each completed milestone (§6) → `ticket-closer` closes it out and writes the walkthrough (§14).

### 4.1 Ticket Folder
When picking up a new ticket, invoke **`ticket-init`** with the tracker link. Its procedure — also the manual fallback — is [§13](#13-ticket-initialisation-procedure). It copies the installed template ticket whole (shipped default `Tickets/999912Z-PROJ-99999`, possibly customised).

The resulting folder:

```
Tickets/
└── 202605A-PROJ-65474/
    ├── 202605A-PROJ-65474.md    ← primary ticket log file (source of truth)
    ├── PROJ-65474-walkthrough.md ← human-facing handover, written by ticket-closer at close-out (§14.1)
    ├── AI-Knowledge/           ← AI agent memory .md files for this ticket (indexed + compacted, see §7)
    ├── Agent-Prompts/          ← planner → implementer prompts: NN-<slug>.md (§11.1)
    ├── Agent-Output/           ← implementer results: NN-<slug>.md, same name as its prompt (§11.1); reviewer verdicts: NN-review.md (§11.4)
    ├── Checks/                 ← selected durable evidence: checks_master.ipynb (+ scratch files / per-tool subfolders as YOUR stack needs)
    ├── Logs/                   ← long run logs (build/test/pipeline output, implementer NN-<topic>.txt) — dump here so grep can slice them
    └── Dump/                   ← user-dropped misc files for the AI to read (.csv, screenshots, .docx/.pptx/.eml) and parsed workbooks (§10)
```

Any supporting files (exports, scripts, etc.) also live in this folder. Design workbooks do not: they live in `Mappings/` (§10).

The standard subfolders:

- **`AI-Knowledge/`** — AI agent memory/knowledge `.md` files for this ticket (see [§7](#7-ai-memory-convention) — including the **index + compaction** rules).
- **`Agent-Prompts/`** and **`Agent-Output/`** — the planner/implementer iteration ledger ([§11.1](#111-prompt-and-output-files)). Tracked records: the planner writes prompts, the implementer writes outputs, the reviewer writes its reviews beside them ([§11.4](#114-the-review-gate)), and `ticket-closer` cites them in the walkthrough. Never credentials, tokens, customer rows or raw authentication output.
- **`Checks/`** — selected, reproducible evidence in ANY language your work needs (SQL, Python, shell, API probes). `checks_master.ipynb` is the default recorder — one markdown why-note + one code cell per durable claim, appended via `append-notebook-cell.py`, on the workspace default kernel (`venv_global` by convention — see *Python environment* below; register other kernels freely). Routine verification stays ephemeral; scratch files may hold temporary work. Add per-tool subfolders if your stack wants them — the harness imposes none.
- **`Logs/`** — long-running command output (e.g. build/test output, dbt runs, pipeline logs). **AI agents: always redirect long logs here** instead of printing them into chat, so they can be sliced with `grep`/`tail`/`awk` and don't overflow the session context window.
- **`Dump/`** — the "landfill" for user-generated misc files dropped in for the AI to read: `.csv` extracts, screenshots (`.png`/`.jpg`), `.docx`/`.pptx`/`.eml`, plus parsed workbook output (`Dump/workbooks/`). This is *user input for the AI*, distinct from checks you write (`Checks/`) and command output (`Logs/`). Large scratch or dropped inputs belong **here** (git-ignored), not in the tracked ticket root — `harness-status` WARNs (yellow, never blocks) if a ticket's tracked root grows past `HARNESS_TICKET_WARN_MB` (default 5), pointing you here. **No customer PII, credentials, or secrets ever land in `Dump/`** — if an extract contains PII it doesn't belong in this folder tree at all; work with it in the approved location and reference it by path/description instead.

### 4.2 Durable Evidence Gate

The durable unit is a **claim or decision**, not a command. The parent agent that
observed the work applies this gate BEFORE invoking `check-scribe`; the scribe
records a qualified handoff and never investigates for something to retain. If a
gate answer is unknown, do not capture. Zero notebook additions is the expected
outcome of ordinary ticket work.

**All prerequisites must hold:**

1. The exact check ran and its result was observed in this session.
2. Source tests, CI, a PR check, a durable application log, or an existing notebook
   capsule do not already retain the result adequately.
3. The command and output are safe to retain: no credentials, tokens or transient
   authentication material ([§2](#2-tools-and-authentication)).
4. A future reader could safely replay it, or it is explicitly scoped as a
   point-in-time observation that must not be replayed blindly.

**At least one durable-value condition must hold:** it directly proves an
acceptance criterion or release decision with no better durable evidence; it is
the minimal reproduction of a non-obvious defect likely to recur; it establishes a
baseline, contract, reconciliation or production observation likely to be compared
later; or it justifies an irreversible, regulated, high-risk or operational
decision.

**Never capture** navigation and discovery (`pwd`, `ls`, search, file reads, symbol
lookups); git inspection; environment activation; import/syntax/format checks;
iterative lint, compile, build or unit-test runs already owned by source tests or
CI; failed attempts superseded by the decisive result; or exploratory queries that
support no retained decision. Consolidate related commands into ONE capsule that
proves ONE claim.

An appended but unexecuted cell is a **captured replay definition**, not verified
evidence. It becomes **verified evidence** only after execution in the notebook and
saved output. Never imply that appending a cell proved the claim; until notebook
execution by the agent is demonstrated, the human runs it.

**Python environment (PREREQUISITE):** the harness requires **a Python environment whose interpreter can `import nbformat`** — that, and nothing else (only `parse-workbook.py`, §10, also needs `openpyxl`). `append-notebook-cell.py` runs under whatever `python3` is on the path and sets no kernel, so **no part of the machinery reads, requires or validates the environment's name**. It is created BY THE USER — the harness never creates it, it only depends on it. Set it as the **workspace default interpreter** (in `GitHub/<your>.code-workspace`), so new terminals under `Work/` auto-activate it and notebooks default to its kernel — every ticket picks it up automatically. It also backs the Data Wrangler extension (view/clean `.csv`/`.parquet`/`.xlsx`). Create a repo-specific venv only when a repo needs different pins.

**The name is a convention, not a requirement.** These documents call it **`venv_global`** (Python 3.12 with `nbformat` + your toolchain, e.g. dbt) and one shared name is worth keeping — it is what makes "the workspace default interpreter" mean the same thing in every ticket and every conversation with an assistant. Rename it if you have a reason to; nothing will notice.

### 4.3 Ticket Markdown File
The primary file is `YYYYMM<seq>-<BOARD>-<num>.md`. This is the **source of truth** for everything done on the ticket. It restores AI agent context without blowing up the context window — via the **Current State** section, not the full history.

**Top-level structure (strict order):**
```markdown
---
repos:
  - <repo>
pipelines: []
---
# <BOARD>-<num> — <Short Ticket Description>

**Ticket:** [<BOARD>-<num>](<the issue's address on its board's tracker>)
**Local path:** Work/Tickets/YYYYMM<seq>-<BOARD>-<num>

Repos:
- Work/GitHub/<repo>

Branches:
- [`<branch>`](<the branch's address on the code host>) in `<repo>`

Pull Requests:
- [PR #NNN](<PR address>) in `<repo>` — draft | in review

Context:
- <Links to matching repo/pipeline pages, runbook and directly related work>

---

## Current State
- Now: <component and current outcome>
- Next: <one concrete next action>
- Blocked: <blocker or none; essential gotcha/link if needed>

## Background
<Why this ticket exists, business context>

## Scope / What needs to be done
<Checklist or description of work>

## Changes Made
<Technical detail of what was changed and where>

---

## Session Log
```

Every ticket markdown file must include the **Repos**, **Branches**, and **Pull Requests** sections directly after the header, listing the repos worked in, the branches, and every PR (draft, in review, merged or closed) with links, repo, and state. Keep them current as repos, branches, or PRs change. At close-out `ticket-closer` adds the walkthrough to **Context** (§14). The file opens with a frontmatter block whose `repos` list names the same repos as the **Repos** section's `GitHub/<repo>` entries (`[]` while none is known) and whose optional `pipelines` list names the pipeline pages it touches ([§9.2](#92-pipeline-and-repo-pages) owns the grammar); `ticket-scribe` changes the section and the list together.

---

## 5. Current State Convention

**`## Current State` is the section AI agents read to rehydrate.** It is a living summary, normally three short bullets labelled **Now**, **Next**, and **Blocked**, reflecting *right now*. Aim for under 100 words; add only a load-bearing gotcha or pointer:

- Where the work stands (done / in flight / blocked, and on what).
- The immediate next step.
- Anything non-obvious an agent must know before touching the ticket (gotchas, decisions made, files that matter).
- Pointers into `AI-Knowledge/` or the Session Log **only when** deeper context is genuinely needed (e.g. "see `AI-Knowledge/field-mapping.md` before editing the staging model").

**AI agents: update Current State at the end of every ticket session, as part of the same step as the Session Log append.** The helper does both in one command (`--now`, `--next`, `--blocked`, [§6](#6-session-logging-convention)). Overwrite it — unlike the Session Log, it has no history; history lives in the log. If the user asks a question the Current State can't answer, *then* deep-dive the Session Log / AI-Knowledge and say you're doing so.

---

## 6. Session Logging Convention

**Default: automatic for ticket work.** At the end of completed ticket work, append one outcome delta under **Session Log**, without waiting to be asked. Do not create a ticket merely to log a general tooling or navigation task. The user vetoes or amends; they may say "log this now" to force a checkpoint.

**Section header format (strict — do not deviate):**
```
## YYYYMMDDHHMMSS - [Short one line description of session update]
```

**The timestamp is LOCAL machine time** — the same clock as the shell command
`date +%Y%m%d%H%M%S`. Do not write UTC (unless the machine's timezone is UTC):
the validator interprets this header in the machine's local timezone, so a
header written in a different zone can be misread as stale and wrongly
red-block the next session. The helper below reads this clock itself, which is
why no one hands a timestamp to anyone.

**The newest entry goes at the BOTTOM** — recency is judged on the last entry in
file order. When an entry newer than the last validation sits above an older one,
the validator fails with *"newest Session Log entry (…) is not at the bottom"*
and names the block to move; the helper below cannot produce that state.

**Writing an entry: `_harness/scripts/append-session-entry.sh`.** Every new
Session Log entry is written by this one helper, never by editing the file:
`ticket-scribe` runs it, any parent agent may run it directly when starting the
scribe would cost more than the entry, and a human recording a gap by hand
(§16 S1, S5) runs the same command. From the estate root:

```bash
bash _harness/scripts/append-session-entry.sh Tickets/<ticket>/<ticket>.md "<short one-line description>" <<'EOF'
- <what changed: component, columns, logic>
- Verification: <check and observed outcome, or "not run">
EOF
```

| It guarantees | How |
|---|---|
| The clock | It reads LOCAL machine time (`date +%Y%m%d%H%M%S`) at the moment of writing. No timestamp is passed in, so none can be omitted, mistyped or UTC. |
| The header | Exactly `## YYYYMMDDHHMMSS - <description>`, the strict form above. |
| The place | The very end of the file, which must be the Session Log: the last `## ` section that is not an entry. |
| The order | The new time must be later than every entry already in the file. |
| No damage | The entry goes into a copy; the copy is checked (original bytes intact, exactly one new entry, it is both last and newest) before it replaces the ticket. Older entries are never touched. |

It prints `OK: appended to <file>` and the header it wrote. Anything it cannot
guarantee is `REFUSED: <reason>`, exit 2, with the file byte-identical: two
arguments not given, an empty or multi-line description, a description
starting with `#`, an empty body, a body line opening a `#` or `##` heading (it
would split the log or forge an entry), a file whose last section is not the
Session Log, or a clock at or behind the newest entry (a future-dated or
wrong-clock entry is corrected first; within the same second, wait one and run it
again). A refusal is never worked around by editing the file.

**Current State in the same command.** `--now "<text>"`, `--next "<text>"` and
`--blocked "<text>"`, given before the ticket path, each rewrite that one line of
the Current State section in the same write as the entry; an option not given
leaves its line alone, and nothing outside that section changes. A value that is
not one plain line is `REFUSED` like any other bad input.

```bash
bash _harness/scripts/append-session-entry.sh --now "<now>" --next "<next>" --blocked "<blocked>" \
  Tickets/<ticket>/<ticket>.md "<short one-line description>" <<'EOF'
- <what changed>
EOF
```

**`ticket-scribe` owns the ticket file.** With the parent's context it keeps the
whole record true: it may edit any section (header, frontmatter, Background,
Scope, Changes Made) and writes Session Log entries and Now / Next / Blocked
through the helper. It never edits an older entry. A gap in the hand-off is the
scribe's to fill: it reads the ticket, the latest output or a PR's address
rather than bouncing the hand-off, and returns finished work with any gap it
could not fill named. It writes an entry at a completed milestone, whenever the
operator says "log this", and when an exploration in another agent turns out to
belong to a ticket.

**What the parent hands the scribe:** the ticket, the outcome, the meaningful
changes, the verification summary, Now / Next / Blocked, header deltas and the
links with their addresses (§6.1). Never a timestamp. The scribe returns the
header the helper printed, and the parent then runs the validator.

**Example:**
```markdown
## 20260611143000 - Added source-aware order deduplication

- `orders` pipeline: added `source_id`; changed the dedup key from `order_id` to (`order_id`, `source_id`).
- Verification: the two-source fixture retained both orders; the same-source duplicate was removed.
- Deployment: not run; awaiting review.
```

Logs are bullet points only — concise, factual, in past tense. Each new session appends a new block; older blocks are never edited. The header must strictly follow `## YYYYMMDDHHMMSS - [Short one line description of session update]` — no other format is accepted.

Appending a Session Log block and refreshing **Current State** (and the Repos/Branches/PRs sections if they changed) are **one atomic step** — never do one without the other. The helper writes the block; Current State and the header are edited in the same step.

### 6.1 Record Ownership and Brevity

Write for someone asking "what changed?", not "what did the agent do?" Name the
pipeline, table, workflow or file first. List added/removed columns and explain
changed keys, filters, joins, mappings or timing as **old -> new** when known.
Do not invent a type, previous value, deployment or result. Investigation-only
work names the finding and says that no implementation changed.

Every fact gets one durable owner; other surfaces point to it or summarize it in
one line.

| Surface | Sole job | Default budget | Excludes |
|---|---|---:|---|
| Header | Repo, branch and PR addresses; relevant Context links | Compact lists | Narrative, commit history, check details |
| Frontmatter (`repos`, `pipelines`) | Which repos and pipelines a document touches, as lists Obsidian views and `check-work-map.py` read (§9.2) | Two short lists | Status, type, dates, narrative |
| Current State | Now, Next, Blocked; essential gotcha or pointer | Three short bullets; under 100 words | Completed chronology, command lists, copied evidence |
| Changes Made | Settled component-first change bullets | Update only on meaningful implementation change | Session-by-session replay |
| Session Log | Outcome delta since the previous entry | Normally 2–5 bullets; about 100 words | Copied explanations, tool lists, repeated header state, exact check bodies |
| Checks | Selected evidence for a durable claim or decision | Default 0; normally at most 2 capsules per task | Iteration history, duplicate CI evidence |
| AI-Knowledge | Finding, evidence link, use-when trigger and consequence for a hidden fact costly to rediscover | Default 0; normally at most 1 topic update per task | Session narrative, check results, facts already owned by code or a runbook |
| Agent-Prompts / Agent-Output | Iteration ledger: what the planner asked, what the implementer did and observed | One pair per iteration | Durable conclusions (the planner carries them into the record) |
| Walkthrough | Human-facing close-out explanation of the whole ticket | One file, written at close-out | Machine logs, unexplained hashes, raw transcripts |
| Pipeline / repo pages | Sole owner of pipeline-specific facts; one-line ticket history | Identity card plus fixed sections (§9.2) | Ticket chronology, delivery mechanics owned by Repo Workflows |
| General indexes / Work Map hub | Links and one-line retrieval cues | One line per entry | Duplicated facts or histories |
| Logs | Bulky temporary command output | As needed; git-ignored | Durable conclusions |
| Git, CI, PR, tracker | Canonical history already retained there | Link, do not copy | Duplicated transcripts in ticket files |

Keep verification separate from implementation; name the check and observed
outcome, or say "not run". Link to CI, PRs and detailed evidence instead of copying
them. Prefer "added source_id" to "enhanced traceability" and a named test to
"validated end to end". These budgets are defaults for what an agent writes
unasked, never a reason to shorten or refuse what the operator asked for
([AGENTS.md](AGENTS.md) rule 8). They are writer stop conditions and review
targets, not validator gates: keep load-bearing detail when omitting it would make
the record misleading. Never rewrite old Session Log entries just to apply the new
style.

**Links.** Every reference to something outside the estate that has a web address —
a PR, a branch, a CI or scheduler run, a tracker issue or comment, a wiki page, a
scheduler DAG, a dashboard, a catalog asset — is a masked Markdown link when its
address was found: a label that says what it is, and the address behind it.
`[PR #951](<address>)`, `[comment by <name> on <BOARD>-123](<address>)`,
`[orders_daily DAG](<address>)`, `[UAT run 2026-11-03](<address>)`. Never a bare
address. Record the address an agent actually found — in command output
(`gh pr view <n> --json url`), on a tracker issue or page it read, or from the
user — and never build or guess one; when none was found, write the name plainly
and carry on. References inside the estate are relative links (§9.1). A writer
hands addresses on with the names: a parent gives `ticket-scribe` a PR's address
when it has one. Older Session Log entries are not rewritten to add links.
`check-work-map.py` notes bare addresses and unlinked PR numbers (warning-only; a
PR's address is one `gh pr view` away); everything else external rests on the
writer.

---

## 7. AI Memory Convention

Create any new memory `.md` files under `Tickets/YYYYMM<seq>-<BOARD>-<num>/AI-Knowledge/`. If memory must be created in session/agent memory first (where the folder is not directly writable), copy those `.md` files into the ticket's `AI-Knowledge/` folder after creation. Each ticket's AI knowledge base lives in its own `AI-Knowledge/` subfolder so context survives across sessions.

### 7.1 Durable Knowledge Gate

The parent agent invokes `knowledge-keeper` only with a NAMED candidate from the
current ticket task, never merely to prove that zero is correct. The gate governs
what agents capture unasked: a note the operator asks for by name is written, with
one line saying which tests it would not have passed. Otherwise neither agent
searches for something to preserve. A candidate must pass all six tests:

1. **Non-obvious:** a competent future agent would not infer it quickly from code,
   tests, the ticket header, or normal tool output.
2. **Verified:** this session established it from a named authoritative source or a
   reproducible observation.
3. **Retrievable:** there is a credible trigger expressible as "read before doing X."
4. **Costly to rediscover:** losing it would force a fresh investigation or create
   material delivery, data, security, or operational risk.
5. **No better owner:** it is not already canonical in code comments, tests,
   project documentation, the tracker, a PR, retained checks, Current State, or
   General AI-Knowledge.
6. **One topic owner:** the index was checked and an existing note is updated
   whenever it already covers the topic.

Ticket-local knowledge need only stay useful after context loss on THIS ticket;
promotion keeps the stronger test: useful on a future unrelated ticket,
expressible without ticket references, and not already covered. A note is a
compact retrieval card — **Finding**, **Evidence** (a pointer), **Use when** (the
trigger) and **Consequence** — of roughly 150–400 words, compressed before 500.
Zero is expected; one topic update is normal; two independent notes require the
parent to state why they cannot share an owner.

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

## 8. General AI-Knowledge Convention

Work that is **not tied to a tracker ticket** — tool setup, local environment configuration, reusable how-tos — is documented under `General AI-Knowledge/`. Each distinct topic gets its own subfolder containing a single, self-contained, human-readable markdown file named after the topic.

```
General AI-Knowledge/
└── AWS CLI Setup/
    └── AWS CLI Setup.md
```

Conventions:
- **One subfolder per topic**; the folder name *is* the topic (e.g. `AWS CLI Setup`).
- The markdown file mirrors the folder name and should stand alone: what was done, why, the exact commands, and a worked **Example** section.
- **Never commit secrets** (access keys, tokens). Use placeholders and reference the discovery commands instead.
- **Frontmatter (optional):** a topic about specific repos or pipelines may open with `repos` / `pipelines` lists ([§9.2](#92-pipeline-and-repo-pages)); they are checked when present and kept when a note is promoted.
- **Exceptions with their own homes:** pipelines and repos are one file each under `Work Map/Pipelines/` and `Work Map/Repos/` ([§9.2](#92-pipeline-and-repo-pages)); craft and documentation targets are `Skills/` modules ([§19](#19-skills-convention)).

---

## 9. Context Discovery

At pickup, before implementation, and when the target repo/pipeline changes:

1. Read the ticket header and Current State; check its `AI-Knowledge/_index.md`
   for a matching retrieval trigger. Open only the relevant note. Non-ticket work
   starts with the general indexes; do not create a ticket for discovery.
2. Check [General AI-Knowledge](General%20AI-Knowledge/_index.md) for reusable
   tooling, constraints and ways of working; check
   [General Human Knowledge](General%20Human%20Knowledge/_index.md) for repo
   runbooks. Read the matching workflow before choosing build, branch, deployment
   or environment commands. Human-facing references are available to agents too.
3. Search the [Work Map](General%20AI-Knowledge/Work%20Map/_index.md) by exact
   repo/pipeline name and recorded aliases. Open the pipeline page
   (`Work Map/Pipelines/<pipeline>.md`) and read its Identity card first, then only
   the section you need; open the repo card (`Work Map/Repos/<repo>.md`) for its
   runbook. Follow at most three relevant tickets or notes. `recall` can do
   this as a bounded read-only subtask.
4. If the map has no match, use a scoped search of ticket headers, Current States
   and knowledge indexes. State what was searched and what was not found; a
   missing map entry does not prove no related work exists.

Reuse observed findings with a link; recheck mutable runtime/deployment facts
using the source repo or service. Do not treat old ticket status as live evidence.
Do not repeat the scan every tool call or bulk-load Session Logs, notebooks,
Logs or Dump. Go deeper only when a specific source or the user asks for it.

### 9.1 Linked Work Map

`General AI-Knowledge/Work Map/` is the estate's navigation hub. `_index.md` links
every page under `Repos/` and `Pipelines/` and every delivery runbook under
`General Human Knowledge/Repo Workflows/`. Pipeline pages are knowledge owners
(§9.2); everything else in the map is routing. Ticket links on an entity page mean
"this ticket discusses this component", **not** data lineage or deployment.

The parent agent maintains affected links when work first establishes an entity
or relationship. Only create a page backed by a source; do not generate pages for
every noun. Use ordinary relative Markdown links (encode spaces), which work in
editors and Obsidian without a plugin. Verify link targets. Never use bare ticket
IDs as links when the actual filename has a month/sequence prefix.

Add useful entity/runbook links under the optional **Context** header in new or
actively updated tickets. Legacy records need not be rewritten: entity-page links
already connect them in the graph. Maintain the appropriate general root index
when adding/moving a topic or runbook; promotion also updates the existing ticket
index/tombstone. Keep one owner for the underlying fact. The map may be partial;
its index declares coverage, and discovery always has the fallback above.

**Maintenance duties.** Before handing off to `ticket-scribe`, the parent updates
the impacted repo/pipeline page and the map root for any new relationship, adds up
to three useful reverse links under Context, and updates the General AI-Knowledge
or General Human Knowledge root index when a note or runbook is created, moved or
renamed. Promotion tombstones must stay valid. After the links are closed out,
run `python3 _harness/scripts/check-work-map.py` once. It is a read-only,
warning-only observer (`--json` for counts and findings; `--strict` is opt-in and
never wired into a hook) of encoded relative links, file-index and promotion
links, whether each initialized ticket is reachable from a map entity page,
orphaned general notes, and the `repos` / `pipelines` frontmatter (§9.2). It
reads only the Markdown syntax it supports (its
docstring lists the limits); it does not establish that a fact is true, lineage,
or cloud state. Report existing uninitialized tickets and references outside the
estate; never force a fake fix and do not update old tickets to silence it. The
parent hands the scribe the known links and the checker outcome as an ephemeral
summary, not extra AI knowledge. The scribe validates the links it was given,
writes no broad map, and asks the parent to repair gaps rather than reporting a
false completion. `ticket-init` needs the new ticket's page entries linked before
its final scribe step; `ticket-closer` turns the ticket's page lines into final
outcomes at close-out; `knowledge-curator` repairs backlinks and root indexes
after a rename or promotion; `doc-writer` registers a new page or runbook in its
index; `estate-auditor` reports what drifted.
See the [Harness Guide](General%20Human%20Knowledge/Harness%20Guide.md).

### 9.2 Pipeline and Repo Pages

One file per entity, no folders:

- **Pipeline page** — `General AI-Knowledge/Work Map/Pipelines/<pipeline>.md` is the
  pipeline's **home**: the one owner of what the pipeline is, where it runs and how
  to prove it. It opens with an **Identity card** (aliases; repos and source paths;
  runtime names per environment — scheduler DAG or job, pipeline or cluster id;
  schedule and trigger; sources; tables populated per environment; egress
  destination; trigger or tenant configuration; design workbook in `Mappings/`;
  delivery runbook). Fixed sections follow: How it works ·
  Scheduling and triggers · Dependency Chain · Change recipes · Deploy (UAT, PROD) · Validate (UAT,
  PROD) · Behaviour and traps · Read before · Ticket history. The **Dependency Chain**
  lists every upstream hop that must finish before the pipeline's own trigger fires —
  runtime, what it waits on, what it produces, dated PROD and UAT timing and the
  read-only check that proves it — linking hops another page owns. PROD is the
  primary environment: the hops are written once, and differences are listed
  as UAT differences. **Read the card
  first; open one section at a time.**
- **Repo card** — `General AI-Knowledge/Work Map/Repos/<repo>.md` is thin: local path,
  GitHub repo, default branch, its living delivery runbook, the pipelines it hosts,
  and ticket history.
- **Who owns what.** Repo Workflows own **how to deliver** a change in a repo (branch,
  build, test, PR, generic deploy mechanics). Pipeline pages own the
  **pipeline-specific values** plugged into those steps and the validation recipe.
  Reusable cross-pipeline techniques stay as General AI-Knowledge topic notes and
  are linked from a page's Read before section. Link between owners; never copy.
- **Frontmatter.** Tickets, walkthroughs, repo cards, pipeline pages and Repo
  Workflows runbooks open with a YAML block (Obsidian calls it properties) that
  lists what they touch, so views can filter by repo or pipeline:

  ```yaml
  ---
  repos:
    - <repo>
  pipelines:
    - <pipeline>
  ---
  ```

  `repos` holds repo card names (`Work Map/Repos/<repo>.md` without `.md`) and
  `pipelines` pipeline page names (`Work Map/Pipelines/<pipeline>.md` without
  `.md`); a value is never a path or a wiki-link. A ticket's `repos` equals the
  `GitHub/<repo>` entries of its header **Repos** list; a walkthrough carries at
  least its ticket's repos; a repo card lists itself; a pipeline page lists the
  repos that host it and its own name in `pipelines`; a runbook lists the repo it
  delivers into. A retrospective lists the union of the `repos` and `pipelines`
  its cited tickets list (`[]` when they list none), and also carries `since`
  and `until`: the first and last dates of its covered window as `YYYY-MM-DD`,
  the one exception to the two-list rule, kept because nothing in the path says
  which period an account covers and an append-only account never changes
  them. `check-work-map.py` checks the list values but does not yet report a
  retrospective without the block, and records `since` / `until` without
  reading them. Elsewhere both lists are optional. An unknown value is an empty
  list (`[]`), never a guess. The block is plain: `---` on line 1, one `key:` per
  line with `- item` lines (the form Obsidian writes back) or a flow list
  (`[a, b]`), a closing `---`, then the
  first line of the document; no YAML comments, because other scripts read a `#`
  line as a heading; a value containing `: ` is quoted, or Obsidian ignores the
  whole block (`check-work-map.py` reports an unquoted one as malformed). There is no `type`, `status` or `reviewed` property: the path
  already says what a document is, and Obsidian writes view edits back into the
  file, which would change a ticket without a Session Log entry. `check-work-map.py`
  reports a missing, unknown, mismatched or malformed block as a NOTE, so files
  written before this rule stay valid until a backfill (§15).
- **Provenance.** Each section ends with a `Sources:` line (path:line, ticket, or
  command and date). Unknowns stay `TODO (unverified)` with the command that would
  verify them; a dated observation says so. `doc-writer` creates and refreshes pages
  with the [Doc-Pipeline-Home](General%20AI-Knowledge/Skills/Doc-Pipeline-Home/SKILL.md)
  skill.

---

## 10. Design Workbooks in Mappings

`Mappings/` at the estate root holds the canonical design workbooks: mapping
spreadsheets with several tabs and a version column used to design and implement
pipeline changes. It is outside the git whitelist. The user names the workbook and
version for each task; an agent never silently picks "the latest".

- Never edit, re-save, copy or write beside a workbook in `Mappings/`. Ignore `~$…`
  lock files.
- Parse it rather than hand-dumping it, with a Python that can `import openpyxl`
  (add it to the workspace default interpreter: `pip install openpyxl`):

  ```bash
  python3 _harness/scripts/parse-workbook.py "Mappings/<workbook>.xlsx" \
    --out "Tickets/<ticket>/Dump/workbooks" --version <version>
  ```

  Output lands in `Dump/workbooks/<workbook-stem>/` (git-ignored): `INDEX.md`
  (provenance and sha256, sheets, header rows, version columns and the versions
  they hold), `version-history.md`, one CSV per sheet keyed by Excel row number,
  and `changes-<version>.md` (the history row plus every row tagged with that
  version, as `Header (column): value`). Re-run it rather than editing its output;
  `--help` lists the other options.
- Cite workbook facts as `<workbook> v<version>, sheet '<name>' row <n>`, and quote
  the sha256 from `INDEX.md` when a decision rests on it. A design row is a
  requirement, not evidence that the pipeline already does it.
- Pipeline pages name their workbook and sheets in the Identity card. Historical
  tickets keep their own copies and extracts in `Dump/`; new work reads `Mappings/`.

---

## 11. Planner and Implementer Loop

Delivery runs as two agents in two chats, with a third that checks them. The courier
who carries each hand-off and watches the chats is the human, or the `orchestrator`
when the human runs one ([§12](#12-agent-routing)).

| Role | Agent | Job |
|---|---|---|
| Planner | `planner` | Explains every step to the human, writes the implementer's prompt, then reads and verifies the output. The parent agent: owns the ticket record and the capture gates. |
| Implementer | `implementer` | Executes one prompt exactly: long context, logs, commands and code changes. Not a knowledge worker; hands every judgement back. |
| Reviewer | `reviewer` | Trusts neither of them: checks the plan before it is built and the change before its PR. Its blocking findings stop the loop ([§11.4](#114-the-review-gate)). |

### 11.1 Prompt and Output Files

- Prompts: `Tickets/<ticket>/Agent-Prompts/NN-<slug>.md` (planner). Outputs:
  `Tickets/<ticket>/Agent-Output/NN-<slug>.md` (implementer) — the same
  `NN-<slug>.md` name in both folders. Bulky output: `Tickets/<ticket>/Logs/NN-<topic>.txt`.
- `NN` is two digits, sequential per ticket, never reused. A rework or follow-up
  takes the next number; an issued prompt is never edited or overwritten.
- A review is `Tickets/<ticket>/Agent-Output/NN-review.md`: it takes the next
  unused number and has no prompt file of its own ([§11.4](#114-the-review-gate)).
- Both folders are tracked records: no credentials, tokens or raw authentication
  output; any other data is recorded as observed ([§2](#2-tools-and-authentication)).
- **Prompt shape:** `# <ID> — Prompt NN: <goal> (<scope>)`; a one-line worker role;
  `Context the planner already verified` (facts, plus any small correction the
  planner made since the last output); `## 0. Hard rules` (the implementer
  contract's standard rules apply — list only the extras: allowed git verbs, files
  it may change, STOP conditions); numbered steps with exact commands, expected
  results and what to record; a final Handback step.
- **Output shape:** `# <ID> — NN <slug> output`, `Run at: <local time>`, sections
  mirroring the prompt's steps, written incrementally. Every finding is **VERIFIED**
  (cite `path:line`, `Logs/NN-x.txt:line` or the command), **INFERRED**, or
  **NOT FOUND** (with what was searched). It ends with `## Handback to planner`:
  done, deviations, open questions, judgement calls declined, suggested next step.

### 11.2 Planner Duties

- Before each prompt, explain to the human what the iteration does and why; after
  each output, explain what was found or changed and what it means.
- Verify, don't trust: re-check the output's load-bearing claims with read-only
  commands before building on them; say what was verified and what was taken on
  trust.
- Run commands and make small corrections directly when that saves a round trip;
  record each correction under the next prompt's `Context the planner already
  verified` so the implementer's picture stays true.
- Own the record: invoke `ticket-scribe` for each completed milestone, and
  `check-scribe` / `knowledge-keeper` only through their gates (§4.2, §7.1);
  maintain Work Map links (§9.1); call `recall` or `doc-writer` when they
  save work.

### 11.3 Implementer Boundaries

- Writes only its own `Agent-Output/NN-<slug>.md`, `Logs/NN-*.txt`, and the repo
  files the prompt authorises. Never edits a prompt, the ticket `.md`,
  `AI-Knowledge/`, `Checks/`, General AI/Human Knowledge, `CONSTITUTION.md`,
  `AGENTS.md`, `_harness/` or the estate's own `_agents/`.
- Invokes no agents and decides no judgement call: an ambiguity, a failed
  expectation or a scope question goes into the handback.
- Follows §2 exactly: waits for MFA/SSO, never retries in a loop, never switches
  profile or environment, never prints secrets.

### 11.4 The Review Gate

The planner verifies its own plan and the implementer's output, so nothing else in
the loop is built to disagree. The `reviewer` is: a senior architect's read, from a
fresh context, that trusts neither the plan nor the build nor the stated approach.

- **When.** A design check on the plan before the first build prompt. A review of
  the finished change before the PR (before it is marked ready, where the repo
  opens a draft early), and again whenever the branch changes after a pass.
- **What it is given.** The ticket (header, Scope, acceptance criteria) and the plan
  or the diff. Never the planner's reasoning.
- **What it checks.** Whether the change is in the right repo and uses the simplest
  mechanism that does the job; whether the build matches what the specification
  promised; the data it produces; what it may break downstream; complexity and
  duplicated helpers; configuration and hardcoded parameters; whether the tests
  could fail. It runs what it needs and lists the commands with their results.
- **What it writes.** Only `Agent-Output/NN-review.md` ([§11.1](#111-prompt-and-output-files)):
  a verdict (PASS, PASS WITH IMPROVEMENTS or BLOCKED), numbered blocking findings
  with the required action, and improvements marked non-blocking. It changes no
  code and no record, and starts no agent.
- **The gate.** A blocking finding blocks. The planner answers each by number and
  has it implemented; the reviewer re-reviews and marks each earlier finding
  fixed, partly fixed, open or regressed. There is no round cap. The loop ends
  when the reviewer passes the change or the operator unblocks a finding in their
  own words. No agent waives a finding, and a standing delegation does not
  reach one.
- **By hand.** The operator may start the reviewer on any PR or branch; then its
  findings go to the operator.
- **Not a worker.** An agent that cannot start the reviewer asks whoever runs it
  to start it, and never reviews its own work in its place.

---

## 12. Agent Routing

Choose an agent for its job, not to make the roster look busy. Supply the target,
question and relevant pointers; a delegated reader returns findings, not new work.
Each agent's reading list is its row in [AGENTS.md](AGENTS.md).

| Need | Agent | Boundary |
|---|---|---|
| Run a ticket end to end: start each agent, carry the hand-offs, wait on CI | `orchestrator` | Human-started; approves, merges and pushes only under the operator's standing delegation (§2); may do an agent's step itself under that agent's contract, or work a ticket directly when the operator asks |
| Start a ticket, interview and scaffold | `ticket-init` | Direct interactive session (§13) |
| Plan, explain and verify a ticket iteration | `planner` | Parent agent; writes prompts, verifies output, owns records (§11) |
| Execute one planner prompt | `implementer` | Worker; writes its output, logs and authorised repo files only; invokes nothing (§11.3) |
| Check a plan before build, or a change before its PR | `reviewer` | Started by the `planner`, the `orchestrator` or the human; trusts nothing it is handed; writes only its review; its blocking findings stop the loop until it passes or the operator unblocks (§11.4) |
| Close a deployed or concluded ticket | `ticket-closer` | Started by the human or the `orchestrator`; approval before writing outside the ticket; tracker read-only (§14) |
| Create or refresh a document | `doc-writer` | Target from a `Doc-*` skill; approval before writing outside a ticket; posts or opens a draft itself after the user's yes |
| Audit and tidy the estate | `estate-auditor` | Started by the human or the `orchestrator`; dated report; fixes batch by batch with approval (§15) |
| Answer a general question from the estate, repos and read-only live tools | `estate-question` | Human-started; writes nothing unasked; on the user's request it keeps what the answer found (a ticket note, a log entry, a page correction) itself or through the worker whose job it is |
| Resume one ticket, or find related tickets and workflows for a topic | `recall` | Read-only, bounded, at most three pointers; parent may delegate |
| Record completed ticket changes | `ticket-scribe` | Owns the ticket file: one factual outcome delta per entry through the helper, every other section by edit; fills gaps itself; never for non-ticket work |
| Capture knowledge | `knowledge-keeper` | Named candidate passing the Durable Knowledge Gate; default zero |
| Capture evidence | `check-scribe` | Parent-qualified observed result passing the Durable Evidence Gate; default zero |
| Consolidate/promote knowledge | `knowledge-curator` | User-directed maintenance; approval for promotion |
| Write a dated review deliverable for a window | `retrospective` | User-requested; interviews, then frozen once the user closes it |

**Lanes are defaults; the operator's word wins.** The table says who normally does
what, so that work lands with the agent built for it. It is not a list of
refusals. Every operator-facing agent holds edit, execute and the agent tool for
the whole worker roster ([AGENTS.md](AGENTS.md) Definitions), so a request never
forces the operator to switch agent: the agent in front of them starts the worker
whose job it is, or does the step under that worker's contract. When the operator
explicitly asks for something outside an agent's lane or over a budget, the agent
says so once and does it (AGENTS.md rule 8). What still holds: no secret in any
record, no remote write without approval, no fabricated record, no rewrite of an
older Session Log entry.

**Automatic versus invoked.** Mechanical hooks fire without anyone asking:
`sessionStart` runs the ticket validator and, as a separate command, the
warning-only work-map observer; `postToolUse` auto-commits records while the hook
is active; `sessionEnd` is a best-effort validate-and-commit. Agent contracts are
instructions for the session that invokes them, not a scheduler or a guarantee:
hooks do not launch custom agents, and the parent assistant is instructed to
invoke the specialists when their conditions apply, which depends on it following
the contract rather than any background job. Started by the human: `orchestrator`,
`estate-question`, `retrospective`; by the human
or the `orchestrator`: `ticket-init`, `planner`, `implementer`, `ticket-closer`,
`estate-auditor`; `reviewer` by the `planner`, the `orchestrator` or the human;
`recall`, `doc-writer` and `knowledge-curator`
by the human or a parent; `ticket-scribe` by the parent for a completed ticket task;
`knowledge-keeper` and `check-scribe` only for a qualified candidate. The
`implementer` is never a parent: it invokes nothing, and neither does the `reviewer`. Every agent may also be called
by a human. A step that needs an agent the running one cannot start follows the
invocation modes in [AGENTS.md](AGENTS.md) Definitions. Publishing a draft is
authorized by the parent; no agent pushes autonomously, and the `orchestrator`
pushes only under the operator's standing delegation (§2). Prose cannot guarantee
judgement, and the objective checkers'
warnings do not block style.

**Model profile (optional, operator-chosen).** The `model:` pin in each agent's
frontmatter is the live selection, written as the model picker's display name (a
lowercase model ID silently falls back to the session model). Routine agents
(`check-scribe`, `knowledge-keeper`, `recall`, `ticket-scribe`) suit
`Claude Sonnet 5.5 (copilot)`; `ticket-init`,
`planner`, `ticket-closer`, `doc-writer`, `estate-auditor`, `estate-question`,
`knowledge-curator` and `retrospective` suit `Claude Opus 5.5 (copilot)`;
`orchestrator` suits the strongest model available, an Opus- or Fable-class profile,
and shares the installer's second pin with that group; `reviewer` ships on the same
pin and is better re-pinned by hand to a strong model from a different vendor than
the planner's, so the two do not share blind spots;
`implementer` judges nothing and suits the cheapest long-context model that follows
a prompt exactly. Public template pins stay installer-configurable; tiers are a
capability guide, not a price guarantee. See the
[Harness Guide](General%20Human%20Knowledge/Harness%20Guide.md).

---

# PART II — PROCEDURES AND MAINTENANCE (load on demand)

---

## 13. Ticket Initialisation Procedure

Run by `ticket-init`; every step below is also the by-hand fallback. Invoked with the tracker link:

1. Resolve the link's board from the tools note's Boards table ([§2](#2-tools-and-authentication)): its row names the tracker to read and the identity rule. An estate with no table has one board, which applies as before; a link from a board with no row is asked about, never guessed. Then pull the full tracker issue — summary, description, acceptance criteria, comments, and the epic/parent one level up. Follow [§2](#2-tools-and-authentication). If the tracker is unreachable, fill Background/Scope with `TODO` markers from the interview instead of failing — a content fallback; identity and naming are handled separately below.
2. Before creating anything, search for that exact tracker identity across existing ticket names, including earlier months. Resume an existing ticket; do not allocate a second folder. Present a short digest and ask the three kickoff questions: (a) the ticket **in the user's own words**, (b) **non-negotiables**, (c) repo(s). Reuse answers already provided; do not ask the user to repeat them.
3. Follow [§9 Context Discovery](#9-context-discovery): inspect matching workflow/knowledge indexes, pipeline pages and related tickets before proposing work. Keep at most three directly relevant links and one-line reasons; report a bounded negative search honestly.
4. For each repo, suggest 2-3 branch names following its documented workflow (fallback `feature/<BOARD>-<num>_<short-slug>`). Record the user's choice only. The init agent never creates branches or edits code repos.
5. Take `<BOARD-num>` from the board's identity rule (step 1), never from the link's shape alone. Locate the actual installed template (shipped default `Tickets/999912Z-PROJ-99999`, possibly customized). Run `bash _harness/scripts/init-ticket.sh --template <actual-path> --identity <BOARD-num>`; use `--dry-run` to inspect the proposed name first. The helper reads local machine time, considers all boards in that month, orders sequences by length then alphabetically, increments past Z, copies the full tree including dotfiles, and renames the primary markdown only. It refuses duplicate identities, unsafe paths and collisions. Do not reconstruct a subset or hand-edit notebooks. `--root <estate>` is available when explicitly targeting another estate.
6. If no identity can be determined, explicitly use `--pending` instead of `--identity`. The unfinished scaffold has a non-conforming name and `.ticket-pending`. Once identity is confirmed, put it in the record's first heading and preview with `--identity <BOARD-num> --resume <pending-path> --dry-run` alongside `--template`. This excludes only that confirmed pending folder from duplicate checks; it writes nothing. Complete the confirmed folder/primary-markdown rename using the returned name, fill the record, **remove the marker**, and record/validate the real completion. Never invent a conforming tracker identity. Copying a template is not a completed or validated ticket.
7. Fill the real header, Context links, Background and Scope. Background starts with **In my words:** plus at most five tracker-context bullets; Scope contains **Non-negotiables** and acceptance criteria once. Do not copy comment transcripts. Seed Now / Next / Blocked, retaining unknowns as TODOs. Preserve all copied scaffold files; create no Checks capsule or AI-Knowledge note during initialization, and add no invented evidence or learnings.
8. Link the new ticket from its repo/pipeline page entries (and the map root for a new entity), and add up to three useful Context links to the ticket header. Then invoke `ticket-scribe` with the observed initialization actions, the known links and the local timestamp for one real init entry. Run `bash _harness/scripts/check-ticket-log.sh`; resolve any FAIL before calling initialization complete. Run `python3 _harness/scripts/check-work-map.py` once and report its warning-only findings. A copied template or successful helper exit is not validation. If blocked, report the unfinished path and actual problem; do not manufacture another log entry to make a red disappear.
9. Hand over: the ticket continues in a `planner` session (§11), which reads the header and Current State first.

## 14. Ticket Close-out Procedure

Run by `ticket-closer`, started by the human or the `orchestrator` once the ticket is
deployed to PROD or
the work has otherwise concluded. Every step is also the by-hand fallback.

1. **Take the user's status.** Record the user's stated final status (for example
   "deployed to PROD on <date>; PR merged") and what "done" means for this ticket.
   Read the header, Current State, Changes Made, `AI-Knowledge/_index.md` and the
   `Agent-Prompts/` / `Agent-Output/` file names; open individual files only as the
   walkthrough needs them.
2. **Validate the estate first.** Run `bash _harness/scripts/check-ticket-log.sh`,
   `bash _harness/scripts/harness-status.sh` and
   `python3 _harness/scripts/check-work-map.py`. A FAIL on this ticket is fixed
   honestly ([§16](#16-session-states-and-operational-rules) S1) before close-out
   continues; other findings are reported.
3. **Reconcile the status, read-only ([§2](#2-tools-and-authentication)).** Check
   the tracker issue status, each PR's state and merge commit (`gh pr view`),
   whether branches still exist, and the deployment evidence the repo's runbook
   names (workflow runs, release tags, the deployed artefact or DAG version).
   Compare with the user's statement; report every disagreement and never overwrite
   the user's statement with an inference. The tracker stays read-only: on request,
   draft a summary or a read-only verification script for the user to post.
4. **Present the closing plan; wait for approval.** List every file the close-out
   will touch, grouped as **add / change / remove**, one line each: ticket header and
   Context, Changes Made, Current State, Work Map pipeline and repo pages, the
   pipeline-page sections whose facts changed, any Repo Workflow correction, root
   indexes, knowledge actions and the walkthrough path. Nothing outside the ticket
   folder is written before approval ([AGENTS.md](AGENTS.md) Definitions).
5. **Link the work everywhere.** Header PR states and Context links (pipeline page,
   repo card, runbook, walkthrough); the ticket's line on each Work Map pipeline and
   repo page becomes its final one-line outcome; the pipeline page's affected
   sections (columns, stage chain, deploy/validate values, traps) through a
   `doc-writer` refresh; a Repo Workflow correction in place, noted in its folder
   index; root indexes when a page or runbook was added.
6. **Settle knowledge.** Compact `AI-Knowledge/` ([§7](#7-ai-memory-convention))
   through `knowledge-curator`; pass a named candidate to `knowledge-keeper` only
   through [§7.1](#71-durable-knowledge-gate); propose promotions to
   `knowledge-curator` for the user's approval. Zero capture is a valid outcome.
7. **Write the walkthrough** ([§14.1](#141-walkthrough-document)) next to the ticket
   log, through `doc-writer` and its Doc-Ticket-Walkthrough skill.
8. **Record and re-validate.** Invoke `ticket-scribe` with the observed close-out
   actions for one final Session Log entry and a Current State whose **Now** reads
   `Closed — <outcome, date, status source>`. Re-run the validator and
   `check-work-map.py`; report the results, the walkthrough path and any open
   disagreement.

### 14.1 Walkthrough Document

`Tickets/<folder>/<BOARD-num>-walkthrough.md`, beside the primary ticket file (for
example `PROJ-65474-walkthrough.md`). One document per ticket, or per chain, written for a technical
reader who was not in the room: plain language, every term explained, nothing
pasted from machine logs, and any commit hash, run ID or path given with what it
is and why it matters. It opens with the ticket's `repos` / `pipelines`
frontmatter ([§9.2](#92-pipeline-and-repo-pages)), above its first line.

**Shared walkthrough.** When tickets are layered on one change (each builds on the
last, and the last carries all of it), one walkthrough in the last ticket's folder
covers the chain; each earlier ticket links it from its header Context. Older
explainer and Q&A files are merged into it and then deleted; git history keeps them.
A duplicate ticket, or one fixed by another ticket's change with no change of its
own, links that ticket's walkthrough the same way and gets none of its own.

Required sections, in order:

1. **Summary** — status as of a date and its source; one plain paragraph; links to
   the ticket log, tracker, PRs, pipeline page and runbook.
2. **Why it was needed** — business context and the problem in the pipeline.
3. **How the pipeline works** — a short tour with a Mermaid diagram, marking where
   this change sits.
4. **How we worked out what to change** — discovery, the design workbook version and
   rows, decisions and the alternatives rejected.
5. **What changed** — a table of repo, file path, added/changed/removed and why;
   columns added or removed (name, type, source, output key); config and schema
   changes.
6. **How we tested it** — local tests, CI, UAT runs and validation queries: what each
   proves and its outcome; what was not tested.
7. **How we shipped it** — branches, PRs (links and state), merge, build, UAT and PROD
   deploy commands with every flag explained, activation, post-deploy checks.
8. **Caveats and gotchas** — limits, traps met, follow-ups.
9. **Questions a PM or lead might ask** — short Q&A.
10. **Glossary** — the domain and tooling words used.
11. **Where everything lives** — paths and links.
12. **How we got here** — a short timeline of iterations linking each
    `Agent-Prompts/` and `Agent-Output/` pair.

**Retrospective walkthroughs.** A ticket with no walkthrough gets one through the
audit backfill (§15 step 6), written by `doc-writer` with the same twelve sections.
The Session Log may be read in full for this purpose only. Sources, in order: the
ticket `.md` (header, Background, Scope, Changes Made, Current State, Session Log);
`AI-Knowledge/` notes; `Agent-Prompts/` and `Agent-Output/`; executed `Checks/`
notebook outputs; the Work Map pipeline pages and repo cards that link the
ticket; the repo runbooks; PRs read through `gh`. A section the sources cannot
support says `Not recorded` and names the missing source — never inferred. The
document opens with `Written retrospectively on <date> from the record; not a
close-out.` A retrospective walkthrough does not close the ticket.

## 15. Estate Audit Procedure

Run by `estate-auditor`, started by the human or the `orchestrator`. `harness-status`
warns when the
newest `YYYYMMDD-estate-audit*.md` report in `General Human Knowledge/Audits/` is older than
`HARNESS_AUDIT_STALE_DAYS` (default 30); hooks never start the audit. A run limited to some
buckets titles its report `# Estate audit <date> — <Bucket> bucket only`; such a report is not a
full audit, so `harness-status` and `audit-inventory.py` skip it when dating the last audit.

1. **Scope.** Full, or incremental: everything changed since the Work commit recorded
   in the last audit report (`git log --name-only <commit>..HEAD`), plus anything
   past its review age. The user may narrow it to tickets, knowledge or the map.
2. **Mechanical sweep.** Run `python3 _harness/scripts/audit-inventory.py --json`
   (read-only), the validator, `harness-status.sh`, `check-work-map.py --json` and,
   when the tracker is reachable, `tracker-sweep.sh`. They produce the candidate
   findings; do not re-derive what a script already reports.
3. **Live status, read-only.** Batch PR states and tracker statuses for tickets whose
   header still shows open work, to find tickets that are done but not closed out.
4. **Triage one item at a time with small reads** (header, Current State, Changes
   Made; a document's own text). Classify each: broken or missing link; stale or
   unverified fact; duplicate owner; ticket needing close-out; knowledge to compact
   or promote; harness defect or improvement.
5. **Report.** Write `General Human Knowledge/Audits/YYYYMMDD-estate-audit.md` and its
   index line: scope and the Work commit audited, counts, findings, a
   **Walkthrough coverage** table (one row per ticket from `audit-inventory.py`:
   walkthrough present or missing, its `walkthrough_gaps`, and the pipeline pages
   that link it), a numbered fix
   plan (each row: add / change / remove, file, why, owning agent), harness
   improvement proposals written as issue drafts (problem, evidence, proposed
   change, guard), and what was not checked.
6. **Fix batch by batch, with approval.** Present one batch at a time stating exactly
   what will be added, changed or removed and why; apply it only after approval
   ([AGENTS.md](AGENTS.md) Definitions), then append the batch outcome to the report's Fix log. **Incidental
   findings:** a stale or wrong fact found while working an approved batch is fixed
   in that batch, on a page the batch already edits and by the same owner, and
   reported old → new with its source in the batch outcome. A finding on another
   page or for another owner becomes a new row. The auditor
   fixes links, indexes, ticket headers and frontmatter itself (a ticket `.md`
   only through `ticket-scribe`, which writes its Session Log entry); content refreshes go to
   `doc-writer`; compaction and promotion to `knowledge-curator`; close-outs are
   listed for the user to run `ticket-closer`. **Walkthrough backfill:** tickets
   with no walkthrough are proposed in batches of five, oldest folder first; for each
   approved ticket `doc-writer` writes a retrospective walkthrough (§14.1), and every
   section it marks `Not recorded` is copied into the report's Walkthrough coverage
   table as a gap to act on. Harness changes are never
   self-applied — they go to a planning session. Session Logs, retrospectives and
   earlier audits are never edited; once the audit session ends its report is
   frozen.
7. **Close.** Re-run the sweep scripts and report what is still open.

## 16. Session States and Operational Rules

The one rule: **red blocks, yellow schedules.** `FAIL` = fix before any new
work. `WARN`/`NOTE` = keep working; schedule the chore at the next natural
boundary. Never fabricate a record to silence the gate — a gap you cannot
reconstruct is logged honestly AS a gap. These rules bind agents and human
alike.

**S0 — Green.** Entry gate silent. Work normally; at the end of completed
ticket work the parent invokes `ticket-scribe` (in the planner loop, once per
completed milestone). Non-ticket work invokes neither scribe nor keeper;
`knowledge-keeper` runs only for a named candidate that passes the Durable
Knowledge Gate, and zero capture is expected. An `implementer` session that meets
a FAIL reports it in its handback and leaves the repair to the planner.

**S1 — FAIL at entry.** This is about the *previous* session, not the
current one. Triage in two bins:
- *Mechanical* (index orphan/ghost, missing section): apply the printed fix
  — delegable to the session agent. A minute, done.
- *Substantive* (missing Session Log entry, stale Current State):
  reconstruct honestly — from memory via `ticket-scribe`, or from
  `git -C <Work root> log` / `diff` — the Work root is the directory containing this file — (the auto-commits
  captured every write even though the paperwork failed). Late-but-true
  beats fabricated. Truly unreconstructable? Log it with the helper (§6,
  *Writing an entry*), description `Session unrecorded; changes per commits <range>`.
Then re-run `check-ticket-log.sh` to confirm green, and start work.

**S2 — WARN/NOTE nags.** Never interrupt flow for these. Fat index → run
`knowledge-curator` at ticket close-out or end of day. Stale General
AI-Knowledge → batch into a review pass.

**S3 — Resumed, compacted, or abandoned sessions.** Entry validation
re-fires on resume; there is no compaction hook, so on a compacted session it
is `AGENTS.md` (which Copilot loads on every surface) that re-points the agent
at the conventions. A chat left idle for days: prefer a fresh session — the
entry gate plus a clean context beats a stale 200k-token one.

**S4 — An agent wrote garbage.** Git is the undo: inspect the log, revert
the specific paths, re-run the agent or fix by hand. The same failure
three times = upstream bug (agent instructions, contract, or platform) —
stop hand-fixing and take a context pack to a design session.

**S5 — The machinery itself is broken** (hook silent, agent missing from
the picker, a script erroring): run `harness-status.sh` and follow its
prescriptions. Machinery failure never blocks ticket delivery — but every
session run with broken machinery ends with a MANUAL `ticket-scribe`
invocation (or, with the agent itself unavailable, the same
`append-session-entry.sh` command run by hand, §6), and the breakage gets fixed before it becomes normal.

---

## 17. Harness Status Convention

To see the health of the whole estate — not just the last session — run:

```
_harness/scripts/harness-status.sh
```

Deterministic, no AI, no credits. **It is side-effect-free and prints its report
to stdout; the only thing it keeps on disk is one *primary observation* — the day
each WARN was first seen, so a parked yellow can visibly age (#71).** Everything
status *derives* stays unstored: a derived view is regenerated, never kept, so it
can't drift. But the filesystem does not remember *when* a condition began, and
status is the only observer present at onset — that first-seen record is an
observation the tool must make, not a view it can recompute, so it is stored (once,
inside the estate whitelist — the aging record is itself part of the record). What
narrows is what status *stores*, never what it is *safe* to run: running status
still cannot corrupt an estate, because the write is atomic, fails open, and
mutates only when the WARN set changes. Want a snapshot of the
report? Redirect it yourself, deliberately.
It reports, with `OK` / `WARN` / `FAIL` prefixes:

- Per active ticket: last Session Log timestamp and `AI-Knowledge/` file count.
  (The fat-index NOTE is the *validator*'s, not status; status does not report
  Current State age.)
- Naming: a `Tickets/` folder that holds a record but isn't recognised, or a
  pending ticket awaiting its name (the WARN sweep).
- Repo size past the threshold, session activity newer than the last
  commit (auto-commit-lag), and uncommitted changes in the working tree —
  all WARNs. A dirty tree means the auto-commit hook does not appear to be
  running (when it runs, the tree stays clean); the fix is a hand commit,
  `git add -A && git commit`, and nobody has broken a rule by working by
  hand (#306).
- `General AI-Knowledge/`: entries whose `Last reviewed:` date is older than
  the staleness threshold (default 90 days, tunable via
  `HARNESS_KNOWLEDGE_STALE_DAYS`), and entries carrying no `Last reviewed:`
  date at all — each names the knowledge-curator as the next act (#72).
- Audit age: a WARN when the newest `YYYYMMDD-estate-audit*.md` report in
  `General Human Knowledge/Audits/` is older than `HARNESS_AUDIT_STALE_DAYS`
  (default 30), naming `estate-auditor` as the next act (§15). A report titled
  "bucket only" does not count.
- Liveness: the age of the last commit in the Work local git (the repository
  is alive — recency only: the installer's commit counts, so this is not
  evidence that your work is committed; the uncommitted-changes WARN above is),
  hooks config parses, every `.agent.md` file present and registered
  (agents can fail to load *silently* after Copilot updates).

Every `FAIL` line includes the exact command or edit that fixes it.

Principle (applies to all harness tooling): **status observes, failures
prescribe, nothing heals itself.** No auto-repair, no dashboards — a fixed
record must always be a human act, or the audit trail stops meaning anything.

---

## 18. Repo Health and Housekeeping

**The Work repo grows structurally, not accidentally.** Every file mutation
triggers an auto-write commit (the safety net), and `Checks/` notebooks are
tracked JSON that the notebook helper rewrites in full on each cell append —
which git delta-compresses poorly. So the `.git` directory grows with the
**number of commits and the churn of notebook revisions**, not with the live
working-tree size. Over months of heavy use this is real: expect `.git` to
become several times the working-tree size (already ~3× at only a couple dozen
commits). This is the cost of the safety net, and it is worth paying — but it
needs an occasional, deliberate tidy-up.

**The remedy — run it by hand, periodically:**

```
_harness/scripts/harness-housekeeping.sh
```

It reports `.git` size, working-tree size, their ratio, and the commit count;
runs `git gc` to collapse the thousands of loose per-write objects into
packfiles (the actual reclaim); and reports the largest tracked notebooks.
Run it monthly, or whenever `.git` feels large. It is **safe**: it repacks
storage and preserves *all* history and records — it deletes no ticket, no
log, no commit, and rewrites no history (`git gc` only drops
already-unreachable objects). Pass `--aggressive` for a full recompress
(slower, rarely worth it; plain `gc` already does the job).

You don't have to remember a schedule: **`harness-status.sh` will WARN when
`.git` grows past a threshold** (default 50 MiB) and prescribe the housekeeping
command right there — the same observe-and-prescribe nudge as the ticket WARNs,
yellow not red. Tune the threshold with the `HARNESS_GIT_WARN_MB` environment
variable.

**The notebook accumulator.** A heavily-checked ticket's
`Checks/checks_master.ipynb` is the other thing that grows, because every
appended cell re-commits the whole JSON file. If one gets large, you may strip
its saved **outputs** to shrink it — e.g.
`jupyter nbconvert --clear-output --inplace '<ticket>/Checks/checks_master.ipynb'`.
This is a **deliberate manual choice**, never automatic: stripping mutates a
record (it drops the saved cell outputs), so the housekeeping script only
*reports* notebook sizes and never edits them for you.

**Squares with the doctrine.** Housekeeping is a human act, never automatic —
consistent with *status observes, failures prescribe, nothing heals itself*.
No hook invokes the script; you do. It compacts *storage*; it never alters or
deletes the *content* of a record.

### 18.1 Levelling an Estate

**Levelling** brings an installed estate up to a newer harness source, run from the
source checkout. The order: rehearse (`install.sh --rehearsal` into a throwaway target,
then delete it); dry-run (`install.sh --upgrade --dry-run <estate>`) and read the plan;
upgrade (the same without `--dry-run`); merge (below); deploy
(`_harness/scripts/deploy-agents.sh`, then delete each contract it names on a
`LEFTOVER:` line once the operator approves); prove (validator and `harness-status`
green, `check-work-map.py` run once, and a second dry-run that has nothing to do).

**The estate's custom files trump the source.** Any file in the estate that differs
from what the source shipped belongs to the estate: a customised agent contract,
`AGENTS.md`, this constitution, the template ticket, a skill, an index, `Estate.base`,
the tools note, anything the operator or their agents wrote or edited. The source never
overwrites it. The upgrade keeps such files and never touches records; if it replaced
a file the estate had customised, restore that copy from `_retired/` with the command
the upgrade printed. The two documents that describe the harness itself, the Harness
Guide and `General AI-Knowledge/AI Harness/DESIGN.md`, are laid down when absent and
kept when present, like this constitution. Upstream
changes then reach each one only through a meticulous three-way merge:

1. Base it on the source commit the estate was last levelled to, and run
   `git merge-file <estate copy> <source at that commit> <source now>` on a temporary
   copy outside the estate.
2. Read the result line by line against the estate copy: every estate line survives
   (model pins, board keys, tools-note references, section-link style, wording), only
   the upstream change comes in, and nothing upstream is dropped silently.
3. Show the operator the diff between the estate copy and the result, file by file,
   and write it only after approval (AGENTS.md Definitions).
4. On a conflict the estate's side wins unless the operator decides otherwise. A line
   that cannot be told apart as customisation or old upstream text goes to the
   operator, never guessed, and no conflict is resolved by taking the source's side
   wholesale.

A file that differs from both the old and the new source is listed for the operator.
A contract the upgrade creates takes the estate's model pins, never a `PICK-A-*`
placeholder. The levelling report gives one line per merged file: what came in, what
of the estate's was kept, and how each conflict was decided. The commit levelled to is
recorded as one **last levelled** line in the tools note (§2), which no upgrade ships or
merges, so the next levelling has its base. The procedure, its commands and its traps
live in the `Estate-Levelling` skill, which whoever levels reads first.

---

## 19. Skills Convention

Prescriptive craft guidance and tool knowledge for the worker tier live in a Skills tree at
`General AI-Knowledge/Skills/`, discovered **index-first**: an agent matches its task against
`Skills/_index.md` and reads only the matching `SKILL.md`, never crawling the tree. **The rules
live with the skills** — the convention text, the frozen module shape (WHEN TO USE / CRAFT GUIDANCE
/ NAMED TOOLS / Last reviewed), the tool-availability requirement, and the *tools advise, never
gate* law are all stated in `Skills/_index.md` and `Skills/SKILL-TEMPLATE.md`. This constitution
only points; read those two files for the convention itself. New skills are minted through
`knowledge-curator` on explicit user approval — the same promote-with-approval gate as General
AI-Knowledge.

**Documentation targets are skills.** Every document type `doc-writer` produces is a
`Doc-*` skill (for example `Doc-Pipeline-Home`, `Doc-Ticket-Walkthrough`,
`Doc-Repo-Workflow`): its CRAFT GUIDANCE names the destination path, whether the
target is living, append-only or draft-only, the section template, the sources to
mine in order, and the indexes to update afterwards. Adding a target means adding
one skill folder and its index line; `doc-writer` needs no change.

---

# PART III — RARELY USED (load only when the task names it)

---

## 20. Using Your Own Ticket Naming Scheme

[§3](#3-ticket-naming-convention) gives the recommended default. Real teams have
board schemes the default can't anticipate; adapting is a one-line change. The recognition pattern lives in
exactly one place: the `TICKET_RE` line in `_harness/scripts/ticket-grammar.sh`,
sourced by both the validator and `harness-status`, so editing that one line moves
both tools together. Then update the template ticket name and the example in §3.

**A second board is not a new scheme.** The default pattern already accepts any board key
without a hyphen, so adding a board changes nothing here: give it a row in the tools note's
Boards table ([§2](#2-tools-and-authentication)) and start its first ticket. Edit the pattern
only for a name the default cannot parse, such as the hyphenated key below.

**Worked example — a hyphenated board key.** A board key containing a hyphen
(e.g. `DATA-ENG`, so tickets read like `202607A-DATA-ENG-42`) is **unrecognised by
default**: the pattern expects a single board segment with no internal hyphen. The
fix is **not** to mark such folders `.not-a-ticket` (they ARE tickets) — it is to
widen the board segment in `ticket-grammar.sh`: `[A-Z0-9]*` → `[A-Z0-9-]*`. One
line, and both tools validate the real tickets. The default stays hyphen-free on
purpose, because it keeps names unambiguous and human-parseable.

---

## 21. Context Pack Convention

When taking the harness itself for external review/design (outside sanctioned
tooling), never hand-assemble files. Run:

```
_harness/scripts/make-context-pack.sh [--ticket <TICKET-ID>]
```

It stages the harness state — `CONSTITUTION.md`, `README.md`,
`AGENTS.md`, all `.agent.md` files, the hooks config, the `_harness/scripts/`,
and `General AI-Knowledge/AI Harness/` — applies the scrub table (employee IDs
and personal paths, org/tracker URLs, cloud account locators) and zips it with a
datestamped name. With `--ticket`, it also includes that ticket's `.md` and
`AI-Knowledge/_index.md` (scrubbed) — never notebooks, `Logs/`, or `Dump/`.

Output rules:
- The zip lands at `~/Desktop/harness-pack-YYYYMMDD-HHMM.zip` — OUTSIDE both
  repos, always. A pack is a derived view: disposable, regenerated on
  demand, deleted after upload, never stored anywhere inside the `Work/`
  repo (where auto-commit would archive it forever).
- Contents have a stable file SET and sorted ORDER, captured in a generated
  `MANIFEST.txt` inside (every included file, plus a self-audit line confirming
  zero scrub-table hits); OS junk is excluded at staging. The `.zip` itself is
  NOT byte-reproducible — it records per-run file mtimes (and the Python
  zipfile fallback differs again); what is stable is the file set and the MANIFEST.

Rules:
- The scrub table lives at the top of the script — extend it there whenever a
  new identifier class appears; the script is the single source of scrubbing
  truth. The pack carries the script itself with that table blanked, and the
  self-audit reads every packed file, so a seed written as a pattern never ships.
- The script prints a final reminder to **manually skim the zip before it
  leaves the machine**. Automation reduces redaction errors; it does not
  replace the human check.
- Structure travels, payload never does: no query results, no data extracts,
  no repo code in a context pack, ever.

---

## 22. Porting to Another AI Assistant

The harness is coupled to GitHub Copilot at only three thin, isolated points —
the `_agents/*.agent.md` format, the `hooks.example.json` hook shape, and
`deploy-agents.sh`'s deploy target; everything else is assistant-agnostic.
Porting means translating those three — mechanical work, not redesign. There is
no adapter layer to select: the three points are edited in place. To run Claude
Code beside Copilot (or instead of it) without editing them, add its own files to
the estate as [INSTALL-INSTRUCTIONS.md](INSTALL-INSTRUCTIONS.md#running-the-estate-with-claude-code)
describes.

---

# LOCAL APPENDIX — edit on install

Unnumbered on purpose: the numbered sections above are the shared rulebook; these
two sections are yours.

## Owner

**<Your Name>** — <Your Role>, <Your Team>. (Edit me on install.)

## GitHub Repos

All repos live under `Work/GitHub/` (relative to this workspace root). Each mapped repo has a card under [Work Map/Repos](General%20AI-Knowledge/Work%20Map/_index.md) linking its delivery runbook. Every repo under `GitHub/` is worked the same way: through a ticket on the board that tracks it ([§2](#2-tools-and-authentication), Boards), with its own repo card and delivery runbook. The repo's own instructions govern its code; this estate governs the records. List YOUR key repos here so agents can map ticket components to code — for example:

- `<org>/<dbt-models-repo>` — analytics models
- `<org>/<etl-repo>` — pipeline code
- `<org>/<shared-modules-repo>` — shared libraries
- `<org>/<infra-repo>` — infrastructure config
