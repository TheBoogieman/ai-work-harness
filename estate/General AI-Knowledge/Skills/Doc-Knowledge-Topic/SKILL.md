# Doc-Knowledge-Topic — SKILL.md

## WHEN TO USE
Creating or refreshing a reusable General AI-Knowledge topic note: a technique, tool setup or constraint that
applies across tickets and pipelines (for example schema resolution, a CLI setup, an output-contract rule).
Triggers: GAK note, general knowledge, topic note, how-to, tool setup note, technique note, refresh topic.

## CRAFT GUIDANCE
**Kind:** living reference. **Destination:** `General AI-Knowledge/<Topic>/<Topic>.md` (one folder per topic,
file named after the folder), with one line in `General AI-Knowledge/_index.md` written as a read-before
trigger. Pipelines and repos are NOT topics: use Doc-Pipeline-Home or the repo card instead.

**Shape:** `Last reviewed: YYYY-MM-DD (<what was checked>)` · Purpose (one paragraph; read-before trigger) ·
the technique or facts in short sections · exact commands with placeholders · a worked **Example** · Gotchas ·
Sources.

**Rules.** Expressible with no ticket references (cite tickets only as evidence); one owner per topic; never
secrets — use placeholders and discovery commands. Promotion of a ticket note into a topic note is
`knowledge-curator`'s job with the user's approval; this skill writes the target once that is approved or when
the user asks directly. Link the topic from each pipeline page's Read before section that needs it.

**Sources to mine, in order:** the existing note; ticket `AI-Knowledge/` notes being promoted; the source code
or tool documentation on the remote default branch; observed outputs in `Agent-Output/`.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate.

- `python3 _harness/scripts/check-work-map.py` — confirms the new note is reachable from its root index.

Last reviewed: 2026-10-20
