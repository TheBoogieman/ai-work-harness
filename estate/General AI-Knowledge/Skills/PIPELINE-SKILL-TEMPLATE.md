# Pipeline-<pattern> — SKILL.md (TEMPLATE — copy, do not index this file)

Copy this file to `General AI-Knowledge/Skills/Pipeline-<pattern>/SKILL.md`, fill every section, then add its
line to `Skills/_index.md` and its row to `Skills/SKILL-MAP.md`. `<pattern>` names the kind of change, in
kebab-case: `Pipeline-add-column`, `Pipeline-new-source`, `Pipeline-data-quality-check`. The four sections
are FROZEN: keep all four, in this order. This template lives at the Skills root and is NOT a skill.

A pipeline skill is how one kind of change is implemented, wherever it recurs, written so a colleague on
another team could follow it. It is the distilled form of what pipeline pages and design workbooks hold:
the pattern, with one pipeline's names and values left out. It never replaces them. Each pipeline page's
Change recipes section links this skill and keeps that pipeline's own values.

## WHEN TO USE
<The kind of change, in the words a ticket uses.> Triggers: <keywords>, <the workbook tabs or columns that
signal it>, <the files it touches>.

## CRAFT GUIDANCE
**What the change is, in business terms:** <one or two plain sentences: what the business gets>.

**Read first:** the pipeline page's Identity card and Change recipes; the design workbook rows for the
version the ticket names (`parse-workbook.py`, CONSTITUTION §10).

**Steps:**
1. <From the design row to the first file: which workbook column means what.>
2. <Each layer the change passes through, in order, with the pattern to copy.>
3. <Configuration and parameters: what is set where, and what must not be hardcoded.>
4. <Tests to add or extend, and what each proves.>
5. <How to validate the result in each environment: the query or check, and what a good result looks like.>

**Use the simplest mechanism:** <when a declarative option, a framework feature or a shared component does
this job, and when new code is justified>.

**What it can break:** <downstream readers, schedules, contracts and costs to check before merging>.

**Traps:** <the mistakes this kind of change has produced, each with how to avoid it>.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). TOOLS ADVISE, NEVER GATE.

- `<tool> <exact invocation>` — <what it does for this change; what to do if the tool is absent>

Last reviewed: YYYY-MM-DD
