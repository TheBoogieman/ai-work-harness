# Design notes — why the harness is shaped like this
Last reviewed: 2026-07-18

**The pattern (every layer):** file states the rule → agent does the work →
hook catches the miss → git undoes the damage. Corollary: status observes,
failures prescribe, nothing heals itself — a fixed record is a human act.

**Key decisions**
- One constitution, two parts: PART I loads every session; PART II on demand.
  The rulebook obeys its own context budget.
- Session semantics are unreliable (idle chats fire nothing; sessionEnd may
  never fire, or fire per-turn) → commits anchor to WRITES (postToolUse),
  validation anchors to ENTRY (sessionStart), sessionEnd is a bonus.
- Whitelist repo: records versioned (tickets minus Logs/Dump, constitution,
  AGENTS.md, _agents/, _harness/, General AI-Knowledge); everything else
  never enters history — containment by construction.
- Source vs deployment everywhere: _agents/ is truth, the Copilot discovery
  dir is a derived copy (drift-checked); dashboards, status output, and
  context packs are derived views, never stored state.
- Promotion never exits version control (the "black hole" fix): knowledge
  moves ticket → General AI-Knowledge inside one history; culling is safe.
- Determinism over intelligence wherever possible: notebook edits via
  nbformat helper, linting via linters, validation via bash. Models are for
  judgment only; the six agents are tiered accordingly.
- Growth is governed: mint a new agent on the THIRD repetition of a task,
  authored in _agents/, inheriting all constraints. PR review — not agent
  restraint — is the standards gate for shared code.

**Operational doctrine:** red blocks, yellow schedules, never fabricate,
late-but-true beats fiction. Full state table: backbone PART II.
