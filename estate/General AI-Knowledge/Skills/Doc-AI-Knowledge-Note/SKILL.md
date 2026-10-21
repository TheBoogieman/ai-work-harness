# Doc-AI-Knowledge-Note — SKILL.md

## WHEN TO USE
The user explicitly asks for a ticket knowledge note to be written or updated (a retrieval card in
`Tickets/<folder>/AI-Knowledge/`). Triggers: write an AI-Knowledge note, update the ticket knowledge, capture
this for the ticket. Agent-initiated capture does NOT use this skill: it goes through `knowledge-keeper` and
the Durable Knowledge Gate (CONSTITUTION §7.1).

## CRAFT GUIDANCE
**Kind:** ticket-local living note. **Destination:** `Tickets/<folder>/AI-Knowledge/<topic>.md` plus its
`_index.md` line in the canonical grammar `- <file>.md — <what it covers> — <when to read it>`.

**Before writing:** read the index. If a note owns the topic, update it; never create `topic-2.md`.

**Shape — a retrieval card, 150–400 words, compress before 500:**

```markdown
# <Topic>

**Finding:** <the durable fact>
**Evidence:** <pointer: path:line, Agent-Output section, PR, query capsule — not a transcript>
**Use when:** <read before doing X>
**Consequence:** <the action or mistake it changes>
```

**Rules:** no session narrative, no check transcripts, nothing obvious from code; no secrets or customer data.
A fact that also matters to other tickets belongs on the pipeline page or a General AI-Knowledge note — say so
and let `knowledge-curator` promote it with approval.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate.

- `bash _harness/scripts/check-ticket-log.sh` — confirms the index and folder still agree after the write.

Last reviewed: 2026-10-20
