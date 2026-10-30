# Doc-Pipeline-Home — SKILL.md

## WHEN TO USE
Creating or refreshing a pipeline's home page under `General AI-Knowledge/Work Map/Pipelines/<pipeline>.md`
(one file per pipeline, no folders): documenting where a pipeline lives, its schedule, DAG / data-pipeline /
cluster names, tables it populates, egress destination, configuration, the upstream dependency chain, and how
to deploy and validate it in UAT and PROD. Triggers: pipeline doc, pipeline home, pipeline page, document
pipeline, refresh pipeline page, identity card, dependency chain, why didn't it run, after a ticket changes a
pipeline, close-out refresh, audit refresh.

## CRAFT GUIDANCE
**Kind:** living reference, edited in place; git history is the record. **Destination:** the page named by the
pipeline's exact runtime name in kebab-case (e.g. `Pipelines/orders-daily-load.md`); register a new page
in `Work Map/_index.md` (Pipelines table) and link it from each hosting repo card in `Work Map/Repos/`.

**Template (keep the headings verbatim so agents can open one section at a time):**

```markdown
---
repos:
  - <repo>
pipelines:
  - <pipeline-file-name>
---
# <Pipeline display name>

Last reviewed: YYYY-MM-DD (<what was checked against what: repo ref, environment, date>)

Aliases: `<runtime name>`, `<names seen in tickets>`. Read the Identity card first; open one section at a time.

## Identity card

| Item | UAT | PROD |
|---|---|---|
| Repos and source paths | <repo>: `<path>` (both) | |
| Runtime (DAG / data pipeline / job) | | |
| Compute (cluster / warehouse) | | |
| Schedule and trigger | | |
| Sources | | |
| Tables populated | | |
| Egress destination | | |
| Configuration (event handlers, tenant vars) | | |
| Design workbook | `Mappings/<file>.xlsx`, sheets <...> | |
| Delivery runbook | [<repo> workflow](<relative link>) | |

Sources: <path:line, ticket, or command + date>

## How it works
## Scheduling and triggers
## Dependency Chain

Hops and gates apply to both environments (config read on <production branch/ref>; UAT differences below).

| Hop | Runtime | Waits on | Produces | PROD timing (observed YYYY-MM-DD) | UAT timing (observed YYYY-MM-DD) | Check |
|---|---|---|---|---|---|---|
| 1 | <first upstream job / DAG / load>, `<ENV>_name` where names differ | <its own gate> | <table, file or event> | <start → end> or Pending | <start → end> | <read-only command, log or query; PROD and UAT target> |
| N | this pipeline's trigger | <file, table and sensor dependencies> | <run / activation> | | | <trigger log or run listing> |

TODO (unverified): PROD timings marked Pending — verify with: <checks, PROD target>

UAT differences: <config or behaviour that differs from PROD for a hop this page owns, with path:line>

## Change recipes
## Deploy
### UAT
### PROD
## Validate
### UAT
### PROD
## Behaviour and traps
## Read before
## Ticket history
```

**Rules.**
- One owner per fact: delivery mechanics (branching, build, generic deploy commands) belong to the repo's
  runbook in `General Human Knowledge/Repo Workflows/`; this page holds the pipeline-specific VALUES plugged
  into them (app name, definition names, YAML patterns, DAG ids, buckets) and the validation recipe. Link, never copy.
- Every section ends with `Sources:`. A fact is either verified (say against what and when), recorded (cite the
  ticket or note), or `TODO (unverified) — verify with: <exact read-only command>`. Never fill a cell by analogy
  with a sibling pipeline.
- Mutable runtime facts (schedules, last run, deployed version) carry their observation date.
- Ticket history: one line per ticket, newest last, `[<ID>](<relative link to the primary record>) — <final
  outcome in one line>`; link the walkthrough when one exists.
- Keep the Identity card under about 25 lines; push detail into sections.
- Frontmatter (CONSTITUTION §9.2): `repos` lists every hosting repo by its repo card file name (the same repos
  as the Identity card's "Repos and source paths" row); `pipelines` lists this page's own file name without
  `.md`. No YAML comments; `check-work-map.py` reports a page whose block is missing or wrong.
- Dependency Chain: one row per hop, ordered from the first upstream producer to this pipeline's own trigger,
  so a reader can walk up from whatever is missing. Name each hop's gate exactly as it is configured (file
  type, table and date column, sensor and metric row) and give the check that proves it passed. A hop that
  another pipeline page owns gets one row with a link to that page, not a copy of its internals. Timings are
  dated observations. A diagram is optional; the table is the record. Where the chain splits (for example
  per portfolio or region), say which branch holds which output.
- Dependency Chain environments: PROD is the primary environment. Write the hops and gates once for both
  environments, read from the production branch or config, and keep one table with a dated `PROD timing` and
  `UAT timing` column. Prefer a normal day's timing and say which business date it is. Runtime names that
  differ by environment are written once as `<ENV>_name`. A PROD cell not yet observed reads `Pending`, with one
  `TODO (unverified)` line under the table naming the checks. Config or behaviour that differs between
  environments goes in a short **UAT differences** list on the page that owns the hop. Do not add a second
  table or diagram per environment; a diagram that shows one environment's names says so in a caption.
- Refresh mode: show the user each changed fact as **old → new** with its source before writing. A stale fact
  found while writing an approved change, on a page that change already edits, is fixed in the same write and
  reported old → new afterwards (CONSTITUTION §15 step 6).

**Sources to mine, in order (stop when the fact is settled):** the existing page; the repo card and runbook;
linked tickets' header, Current State and Changes Made (not Session Logs); ticket `AI-Knowledge/_index.md`
then the selected note; `Agent-Output/` files for verified observations; the repo's default branch
(`git show origin/<default>:<path>`, never a working tree on another branch); the design workbook via
`parse-workbook.py`; live read-only metadata when the request authorises it. For the Dependency Chain, start
from this pipeline's trigger or sensor configuration on the default branch, follow each dependency to the
configuration of the job that produces it, and stop at a hop another page already owns; confirm timings and
gates from the scheduler's run history and the trigger's own logs.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate; repository-required
tests, CI, security and release checks still apply. Tool absence is not a passing check.
Resolve and approve remote targets before use (CONSTITUTION §2):

- `git -C <repo> fetch origin && git -C <repo> show origin/<default>:<path>` — read source facts from the remote default branch.
- `python3 _harness/scripts/parse-workbook.py "<Mappings/file.xlsx>" --out "<Dump dir>" --version <V>` — design rows (needs openpyxl).
- Your cloud CLI's read-only job or pipeline listing, with an explicit profile (for example `aws ... --profile '<profile>'`) — runtime names, state and schedule (human MFA).
- The scheduler's CLI or UI — DAG ids and schedules (read-only; human SSO).
- The trigger's or scheduler's run and task logs — which dependency a run waited on and when it passed (read-only).
- `python3 _harness/scripts/check-work-map.py` — confirm links after writing.

Last reviewed: 2026-10-30
