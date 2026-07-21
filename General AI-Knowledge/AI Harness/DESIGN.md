# Design notes — why the harness is shaped like this
Last reviewed: 2026-07-19

**Diagram currency (2026-07-19):** the two SVG sheets have been brought up to
date with the machinery they document. Sheet 1 now draws the shared-recognition
home (`ticket-grammar.sh`) and shared portability shims (`portability.sh`) as
one-home boxes both the validator (L2) and status (M) source; the human-run
`harness-housekeeping.sh` lane in the maintenance port; and the two Tickets/
edge markers (`.not-a-ticket`, `.ticket-pending`). Sheet 2 now draws the
four-state entry sweep — how `check_ticket_log.sh` sorts each Tickets/ subdir
(recognised → validate · `.not-a-ticket` → silent · `.ticket-pending` →
non-silenceable nag · hand-made → status WARN). Deliberately NOT on the runtime
sheets: the setup/acceptance tooling (`deploy_agents.sh`, `run_demo.sh`) and the
notebook helper (`append_notebook_cell.py`, named in Sheet 1's footnote) — these
are install/CI machinery, not runtime layers, and belong to README's Setup section. For
current enforcement/status/naming behaviour, `folder-structure.md` (the
constitution) is the source of truth.

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
  dir is a derived copy (drift-checked); status output and
  context packs are derived views, never stored state.
- Promotion never exits version control (the "black hole" fix): knowledge
  moves ticket → General AI-Knowledge inside one history; culling is safe.
- Determinism over intelligence wherever possible: notebook edits via
  nbformat helper (any language), linting via linters, validation via bash. Models are for
  judgment only; the six agents are tiered accordingly.
- Growth is governed: mint a new agent on the THIRD repetition of a task,
  authored in _agents/, inheriting all constraints. PR review — not agent
  restraint — is the standards gate for shared code.

**Operational doctrine:** red blocks, yellow schedules, never fabricate,
late-but-true beats fiction. Full state table: backbone PART II.
