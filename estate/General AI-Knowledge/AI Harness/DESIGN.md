# Design notes — why the harness is shaped like this
Last reviewed: 2026-07-26

**Diagram currency (2026-07-29):** both sheets LAG in four ways, and the fourth is
the newest.

**The architecture sheet labels the constitution `folder-structure.md`, a name
that no longer exists.** `#140` renamed the three estate root documents to say
what they contain — `folder-structure.md` → `CONSTITUTION.md`, `setup.md` →
`AI-SETUP-PROMPT.md`, `installing.md` → `INSTALL-INSTRUCTIONS.md` — and the sheet
renders the first of those as label text. Only the constitution is drawn, so this
is one stale label, not three. It is accepted knowingly: the sheet already carries
the false claim below, a redraw commission is required before the release
regardless, and no wave edits an SVG.

**The architecture sheet names three scripts the harness no longer ships.**
`check_run`, `append_entry` and `literate_capture` were removed by `#280` — none
had a job in the workflow, and nothing called any of them. Their labels are still
rendered on the sheet, so a reader taking it as an inventory will look for three
files that are not in their estate. `append-notebook-cell.py` is now the single
door into a notebook, and a session record is written by a person or by
`ticket-scribe`. **This is a false claim on a shipped picture and it is the one
thing on this list that actively misleads** — it is named here, not drawn out, and
the redraw is the operator's to schedule.

**Both sheets still show the pre-split repository layout.** The operator redrew
them on 2026-07-24 at REV R / REV G to the full agent roster. What they do not
show is the split landed by `#136`: every shipped file now sits under an estate
tree and every development file under a development tree, so a sheet read as a map
of THIS CHECKOUT points at pre-split locations. Read as a map of an installed
Work root, they are still right about where things sit.

**Both sheets spell six script names the way they were spelled before `#141`.**
That item settled every shipped script on the hyphen convention, so the sheets'
`make_context_pack.sh`, `tracker_sweep`, `retro_stats` and `append_notebook_cell.py`
(architecture) and `check_ticket_log.sh` (session flow) are all one underscore away
from the files an estate now holds. This is the mildest divergence on the list: the
names differ by a separator, so a reader looking for `check_ticket_log.sh` finds
`check-ticket-log.sh` beside it and loses a moment, not the thread. It is still a
false claim on a shipped picture, and it rides the same redraw as the three above.

NO WAVE EDITS AN SVG — the divergences are named rather than drawn, and `#178` is
where the redraw is tracked. For current enforcement/status/naming behaviour,
`CONSTITUTION.md` (the constitution) remains the source of truth.

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
  AGENTS.md, _agents/, _harness/, General AI-Knowledge, General Human
  Knowledge), alongside the harness's own shipped files; everything else
  never enters history — containment by construction. `.gitignore` IS the
  whitelist and settles the exact set; this list describes it, never
  overrides it.
- Source vs deployment everywhere: _agents/ is truth, the Copilot discovery
  dir is a derived copy (drift-checked); status output and
  context packs are derived views, never stored state.
- Promotion never exits version control (the "black hole" fix): knowledge
  moves ticket → General AI-Knowledge inside one history; culling is safe.
- Determinism over intelligence wherever possible: notebook edits via
  nbformat helper (any language), linting via linters, validation via bash. Models are for
  judgment only; the agents are tiered accordingly.
- Growth, as first sketched: mint a new agent on the THIRD repetition of a
  task, authored in _agents/, inheriting all constraints. RECORDED INTENT, NOT
  LAW (`#227` determined this) — the sentence dates to this repository's first
  commit and is still the only place it appears: nothing counts repetitions,
  no constitution clause or agent contract owns it, and no commit in the
  history cites it as the reason an agent was minted. The roster grew issue by
  issue instead. It is kept because it records what the design wanted; it is
  not a rule, and nothing is out of compliance for ignoring it. Contrast the
  SKILLS growth rule, which IS law and is fully homed — the constitution's
  *Skills Convention* states it, `knowledge-curator` owns it, and a skill lands
  only on explicit user approval. PR review — not agent restraint — is the
  standards gate for shared code.

**Operational doctrine:** red blocks, yellow schedules, never fabricate,
late-but-true beats fiction. Full state table: backbone PART II.
