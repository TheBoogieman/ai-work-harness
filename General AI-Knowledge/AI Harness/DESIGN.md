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

**Diagram currency (2026-07):** Sheets REV Q/F fold the #60 estate-key containment
into both layers — commit hooks are drawn keyed-estate-only; the refusal case is
depicted on Sheet 2.

**Diagram currency (2026-07-23):** the roster grew to SEVEN agents — `#70` adds
`ticket-recall`, a read-only reader that narrates one ticket at pickup. Both
sheets are now stale on the agent count: Sheet 1 labels the L4 box "SIX AGENTS"
and lists the six writers; Sheet 2 draws the six-writer roster. No wave edits an
SVG — the sheets are operator-maintained; this note records the lag until the
operator redraws them to show the seventh agent (the estate's only reader).
Refresh owed under `#83`.

**Diagram currency (2026-07-24):** the roster grew again to EIGHT agents — `#73`
adds `weekly-digest`, a read-only period reader that narrates a window of the
record (active tickets, their knowledge, status deltas). The sheets fall further
behind: the sheets depict six agents, `#70` added the seventh, `#73` the eighth.
Sheet 1 still labels the L4 box "SIX AGENTS" and Sheet 2 still draws the
six-writer roster. No wave edits an SVG — this note records the lag; the operator
redraws on their own schedule. Refresh owed under `#83`.

**Diagram currency (2026-07-24):** the roster grew again to NINE agents — `#85` adds
`retrospective`, a sonnet-tier reader that writes a period retrospective for the human
into `General Human Knowledge/`. The sheets fall further behind still: they depict six
agents, `#70` added the seventh, `#73` the eighth, `#85` the ninth. Sheet 1 still
labels the L4 box "SIX AGENTS" and Sheet 2 still draws the six-writer roster. No wave
edits an SVG — this note records the lag; the operator redraws on their own schedule.
Refresh owed under `#83`.

**Diagram currency (2026-07-24):** the roster grew again to TEN agents — `#108` adds
`harness-recall`, a read-only topic reader that FINDS where a subject appears across
tickets and knowledge (grep + git, no stored index). The sheets fall further behind
still: they depict six agents, `#70` added the seventh, `#73` the eighth, `#85` the
ninth, `#108` the tenth. Sheet 1 still labels the L4 box "SIX AGENTS" and Sheet 2 still
draws the six-writer roster. No wave edits an SVG — this note records the lag; the
operator redraws on their own schedule. Refresh owed under `#83`.

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
  judgment only; the agents are tiered accordingly.
- Growth is governed: mint a new agent on the THIRD repetition of a task,
  authored in _agents/, inheriting all constraints. PR review — not agent
  restraint — is the standards gate for shared code.

**Operational doctrine:** red blocks, yellow schedules, never fabricate,
late-but-true beats fiction. Full state table: backbone PART II.
