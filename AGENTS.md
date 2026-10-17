# Agent contract — read before acting

1. The rulebook is `CONSTITUTION.md` at this workspace root. Read PART I
   before doing anything; pull PART II sections only when your task needs them.
2. Context budget: backbone PART I + the target ticket's header + Current
   State ONLY, unless pointed deeper. Never bulk-read Session Logs,
   AI-Knowledge folders, or Logs/.
3. At the end of completed TICKET work, invoke `ticket-scribe` once. Invoke
   `knowledge-keeper` only for a named candidate that passes the constitution's
   Durable Knowledge Gate; zero capture is expected. Non-ticket work invokes
   neither.
4. Routine checks are ephemeral. Invoke `check-scribe` only for an observed
   result that passes the constitution's Durable Evidence Gate; most searches,
   probes and validation runs never enter the notebook. A captured, unexecuted
   cell is not proof.
5. Never persist durable knowledge into Copilot session or repo memory.
   Files in the ticket's `AI-Knowledge/` (indexed) are the only memory store.
6. On a FAIL from the validator: fix before new work. Red blocks, yellow
   schedules. Never fabricate a record.
7. Before craft work (writing SQL, a dbt model, a transform, a script), check
   `General AI-Knowledge/Skills/_index.md` for a matching module and read only
   that `SKILL.md` — index-first, never crawl the tree.
8. At ticket pickup or a change of repo/pipeline, follow PART I's *Context
   Discovery* route: ticket knowledge index, both general knowledge indexes,
   and the Work Map. Agents may read human-facing runbooks. Read only matching
   notes and workflows; use `harness-recall` for bounded adjacent-ticket
   research before implementation. Before closing out, update the affected map
   links and run `python3 _harness/scripts/check-work-map.py` once (warning-only).
9. Use available CLI/MCP tools (`aws`, `gh`, `snow`, configured Atlassian MCP)
   for task-relevant live facts. Follow PART I's *Tools and Authentication*:
   resolve the environment from local setup notes and runbooks, never infer
   per-environment profiles, default to read-only, and wait for the human to
   authenticate without collecting secrets.
10. Records name the component, columns and logic changed. Follow *Record
    Writing* and *Agent Routing*; do not narrate tool activity or invoke agents
    merely to increase their usage. Route by the job and the retention gates.
