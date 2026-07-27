# <Skill-Name> — SKILL.md (TEMPLATE — copy, do not index this file)

Copy this file to `General AI-Knowledge/Skills/<Skill-Name>/SKILL.md`, fill every section, then
add one line to `Skills/_index.md` so the module is discoverable index-first. The four sections
below are FROZEN: keep all four, in this order, in every skill. This template lives at the Skills
root and is NOT a skill itself — it is exempt from the index by name.

## WHEN TO USE
A trigger description an agent can MATCH AGAINST ITS TASK: the kinds of work, the keywords, and the
task or file shapes that mean "read this module". Concrete enough to match on, no broader.

## CRAFT GUIDANCE
The actual craft: how to do this work well, the conventions that separate good from adequate, and
the traps to avoid. Keep it dialect-agnostic and house-neutral — flavoured or warehouse-specific
guidance is fork-layer material and never ships in the public tree.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). TOOLS ADVISE, NEVER GATE: tool output is craft feedback
to heed, never a gate on a commit or a check. List each helpful tool with its EXACT invocation:

- `<tool> <exact invocation>` — <what it does for this craft; what to do if the tool is absent>

Last reviewed: YYYY-MM-DD
