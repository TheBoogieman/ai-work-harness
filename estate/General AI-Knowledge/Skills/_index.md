# Skills/_index.md — the convention home AND the availability index for the worker tier's craft modules.
#
# CONVENTION (the rules live HERE, with the skills; the constitution only points):
#  - INDEX-FIRST DISCOVERY: match your task against the skill lines below and read ONLY the one
#    matching SKILL.md. Never crawl the tree — this is the context-budget doctrine applied to skills.
#  - One folder per skill under Skills/, each holding one SKILL.md, carrying exactly four FROZEN
#    sections in this order: WHEN TO USE / CRAFT GUIDANCE / NAMED TOOLS / Last reviewed: YYYY-MM-DD.
#  - Every SKILL.md declares TOOL AVAILABILITY: check each named tool exists before relying on it,
#    and degrade gracefully to guidance-only if it is absent. Residual constraints are declared,
#    never assumed — that line is what keeps a skill from sending an agent chasing an uninstalled binary.
#  - TOOLS ADVISE, NEVER GATE (this is law, not a suggestion): lint and tool output is craft feedback
#    for the agent to heed. It MUST NEVER gate a commit, redden a check, or block any flow. The
#    enforcement layer records facts, not content quality.
#  - This index stays in EXACT correspondence with the folders: every skill folder has a line here,
#    every line here names a folder that exists. The *-TEMPLATE.md files and SKILL-MAP.md at the root
#    are not skills — they are exempt by name.
#  - Skill folder names are single-token kebab-case (e.g. SQL-Writing); the name in the line below IS
#    the folder name.
#  - SKILL-MAP.md, beside this file, says which skill fits which situation and which agent reads which.
#    Every skill folder is linked there. This index is what an agent matches a task against; the map is
#    for a person, or an agent, deciding where a new skill belongs.
#  - Two families an estate grows for itself, each from its template at this root: Repo-<name> (how to
#    work in one repository, from REPO-SKILL-TEMPLATE.md) and Pipeline-<pattern> (how one kind of change
#    is implemented, from PIPELINE-SKILL-TEMPLATE.md). The harness ships the templates only. Any agent
#    may propose one; knowledge-curator mints it on the operator's approval.
#
# LINE FORMAT (one per skill): `- <Skill-Name> — triggers: <keywords> — tools: <tool[, tool...] | none>`
# Doc-* skills are doc-writer's documentation targets (CONSTITUTION §19): each names its destination,
# kind (living, append-only or draft-first), section template, sources and indexes.
- SQL-Writing — triggers: sql, query, select, join, cte, window, aggregation, dbt model, warehouse query — tools: sqlfluff, dbt
- Doc-Pipeline-Home — triggers: pipeline doc, pipeline home, pipeline page, identity card, refresh pipeline page, schedule, DAG, tables populated, dependency chain, design workbook, why didn't it run — tools: git, parse-workbook.py, mappings-index.py, check-work-map.py
- Doc-Ticket-Walkthrough — triggers: walkthrough, handover, implementation walkthrough, close-out document, explain the ticket — tools: gh, git
- Doc-Repo-Workflow — triggers: repo workflow, runbook, delivery guide, how to deploy this repo, correct the runbook — tools: git, gh
- Doc-Knowledge-Topic — triggers: general knowledge note, topic note, how-to, tool setup note, technique note — tools: check-work-map.py
- Doc-AI-Knowledge-Note — triggers: ticket knowledge note, AI-Knowledge note (user-requested only) — tools: check-ticket-log.sh
- Doc-PR-Description — triggers: PR description, pull request body, PR summary, PR template — tools: git, gh
- Doc-Readme — triggers: README, module readme, getting started — tools: git
- Doc-Tracker-Update — triggers: tracker comment, tracker update, status summary, finding for the tracker, SQL evidence, verification script — tools: gh, tracker CLI or MCP
- i-have-adhd — triggers: reply to the user, status report, next action, approval request, handback; loaded at run start by the operator-facing agents — tools: none
- Estate-Levelling — triggers: level the estate, levelling, upgrade the estate, install.sh --upgrade, three-way merge, last levelled commit, LEFTOVER; read at the start of every levelling — tools: git, install.sh, deploy-agents.sh, anchor-style.py, check-ticket-log.sh, harness-status.sh, check-work-map.py

[SQL-Writing module](SQL-Writing/SKILL.md) | [i-have-adhd module](i-have-adhd/SKILL.md) | [Estate-Levelling module](Estate-Levelling/SKILL.md) | [Skill map](SKILL-MAP.md) | [Skill template](SKILL-TEMPLATE.md) | [Repo skill template](REPO-SKILL-TEMPLATE.md) | [Pipeline skill template](PIPELINE-SKILL-TEMPLATE.md) | Documentation targets: [Doc-Pipeline-Home](Doc-Pipeline-Home/SKILL.md) · [Doc-Ticket-Walkthrough](Doc-Ticket-Walkthrough/SKILL.md) · [Doc-Repo-Workflow](Doc-Repo-Workflow/SKILL.md) · [Doc-Knowledge-Topic](Doc-Knowledge-Topic/SKILL.md) · [Doc-AI-Knowledge-Note](Doc-AI-Knowledge-Note/SKILL.md) · [Doc-PR-Description](Doc-PR-Description/SKILL.md) · [Doc-Readme](Doc-Readme/SKILL.md) · [Doc-Tracker-Update](Doc-Tracker-Update/SKILL.md)
