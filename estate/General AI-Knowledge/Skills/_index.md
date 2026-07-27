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
#    every line here names a folder that exists. SKILL-TEMPLATE.md at the root is the blank template,
#    not a skill — it is exempt by name.
#  - Skill folder names are single-token kebab-case (e.g. SQL-Writing); the name in the line below IS
#    the folder name.
#
# LINE FORMAT (one per skill): `- <Skill-Name> — triggers: <keywords> — tools: <tool[, tool...] | none>`
- SQL-Writing — triggers: sql, query, select, join, cte, window, aggregation, dbt model, warehouse query — tools: sqlfluff, dbt
