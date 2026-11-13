# Skill map

Last reviewed: 2026-11-13

Which skill fits which situation, and which agent reads which. An agent doing craft work still matches its
task against [the index](_index.md) and reads one `SKILL.md`; this page is for deciding where a situation
belongs, and where a new skill would go. Skills advise and never gate. Every skill folder is linked here.

## Situation → skill

| You are about to | Read |
|---|---|
| Write or review SQL, a query or a dbt model | [SQL-Writing](SQL-Writing/SKILL.md) |
| Write anything the operator will read: a reply, a status, an approval request | [i-have-adhd](i-have-adhd/SKILL.md) |
| Post a comment or a finding on the tracker | [Doc-Tracker-Update](Doc-Tracker-Update/SKILL.md) |
| Open or edit a pull request | [Doc-PR-Description](Doc-PR-Description/SKILL.md) |
| Create or refresh a pipeline page | [Doc-Pipeline-Home](Doc-Pipeline-Home/SKILL.md) |
| Close a ticket with a walkthrough | [Doc-Ticket-Walkthrough](Doc-Ticket-Walkthrough/SKILL.md) |
| Write or correct a repo's delivery runbook | [Doc-Repo-Workflow](Doc-Repo-Workflow/SKILL.md) |
| Write a reusable topic note | [Doc-Knowledge-Topic](Doc-Knowledge-Topic/SKILL.md) |
| Write a ticket knowledge note the user asked for | [Doc-AI-Knowledge-Note](Doc-AI-Knowledge-Note/SKILL.md) |
| Write a README | [Doc-Readme](Doc-Readme/SKILL.md) |
| Level the estate to a newer harness | [Estate-Levelling](Estate-Levelling/SKILL.md) |
| Work in a particular repository | its `Repo-<name>` skill, when the estate has minted one |
| Make a kind of change the estate has made before | its `Pipeline-<pattern>` skill, when the estate has minted one |

## Agent → skills

| Agent | Skills it reads |
|---|---|
| Every operator-facing agent | `i-have-adhd` at the start of each run |
| `doc-writer` | The `Doc-*` skill of the document it is asked for |
| `planner` | `Repo-<name>` and `Pipeline-<pattern>` for the ticket's repo and kind of change; `SQL-Writing` before writing SQL into a prompt |
| `implementer` | Only what its prompt names |
| `reviewer` | `Repo-<name>` and `Pipeline-<pattern>`, to check a change against how the estate does it; `SQL-Writing` |
| `ticket-closer` | `Doc-Ticket-Walkthrough` and `Doc-Pipeline-Home`, through `doc-writer` |
| `orchestrator` | `Estate-Levelling` before every levelling |
| `knowledge-curator` | The templates below, when minting a skill |

## The two families an estate grows

The harness ships these as templates only. An estate mints its own on the operator's approval, through
`knowledge-curator`; any agent may propose one.

| Family | What it holds | Template |
|---|---|---|
| `Repo-<name>` | How to work in one repository: layout, how to build, test and deliver, the conventions a reviewer expects, the traps | [REPO-SKILL-TEMPLATE.md](REPO-SKILL-TEMPLATE.md) |
| `Pipeline-<pattern>` | How one kind of change is implemented, step by step, wherever it recurs: adding a column, a new source, a new data-quality check | [PIPELINE-SKILL-TEMPLATE.md](PIPELINE-SKILL-TEMPLATE.md) |

Both are the distilled, shareable form of what pipeline pages and design workbooks hold: the pattern, with
one estate's names and values left out. They never replace those owners. A pipeline page's Change recipes
section links the skill and keeps the pipeline's own values; the workbook stays the design.

## Adding a skill

1. Copy the matching template to `Skills/<Skill-Name>/SKILL.md` and fill every section.
2. Add its line to [the index](_index.md).
3. Add its row to the situation table above.
