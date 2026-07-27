# Design notes — why the harness is shaped like this
Last reviewed: 2026-07-26

**Diagram currency (2026-07-27):** both sheets are CURRENT on WHAT the machinery
is and WHERE it sits IN AN ESTATE, and now LAG on where it sits in this
repository. The operator redrew them on 2026-07-24 at REV R / REV G to the full
agent roster, and every script they name still exists, still does the same job
and still sits at the same estate-relative path — an installation is unchanged,
so a reader using a sheet to understand a Work root is not misled. What the
sheets do not show is the repository split landed by `#136`: every shipped file
now sits under an estate tree and every development file under a development
tree, so a sheet read as a map of THIS CHECKOUT points at the pre-split
locations. The divergence is named rather than drawn — NO WAVE EDITS AN SVG —
and the operator redraws on their own schedule; `#178` is where that redraw is
tracked. For current enforcement/status/naming behaviour,
`folder-structure.md` (the constitution) remains the source of truth.

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
