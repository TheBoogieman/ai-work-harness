# Agent contract — read before acting

1. The rulebook is `folder-structure.md` at this workspace root. Read PART I
   before doing anything; pull PART II sections only when your task needs them.
2. Context budget: backbone PART I + the target ticket's header + Current
   State ONLY, unless pointed deeper. Never bulk-read Session Logs,
   AI-Knowledge folders, or Logs/.
3. At the end of every completed task, invoke `ticket-scribe` and
   `knowledge-keeper`. This is not optional.
4. Record every query worth keeping via `sql-scribe` — never as throwaway
   one-offs.
5. Never persist durable knowledge into Copilot session or repo memory.
   Files in the ticket's `AI-Knowledge/` (indexed) are the only memory store.
6. On a FAIL from the validator: fix before new work. Red blocks, yellow
   schedules. Never fabricate a record.
