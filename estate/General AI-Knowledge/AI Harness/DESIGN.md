# Design notes — why the harness is shaped like this
Last reviewed: 2026-07-29

**Diagram currency (2026-07-29):** the operator redrew both sheets to REV S /
REV H, which cleared three of the four divergences this note used to carry. TWO
remain, and the second is newly true rather than newly noticed.

**RESOLVED at REV S / REV H.** The architecture sheet labelled the constitution
`folder-structure.md` after `#140` renamed it to `CONSTITUTION.md`; it named
`check_run`, `append_entry` and `literate_capture`, three scripts `#280` removed;
and both sheets spelled the script names the way they were spelled before `#141`
settled every shipped script on the hyphen convention. The redraw corrected all
three: the constitution's label, the scripts strip (three boxes removed, the three
survivors respaced), and every filename on both sheets — `make-context-pack.sh`,
`tracker-sweep`, `retro-stats`, `append-notebook-cell.py` and
`check-ticket-log.sh`. It also corrected the loader's rule count from six to seven,
matching `AGENTS.md`, and dropped a "(NEW)" from the scripts-strip heading that had
long stopped being true.

**Both sheets still show the pre-split repository layout.** This is the one
divergence the redraw did not close. What the sheets do not show is the split
landed by `#136`: every shipped file now sits under an estate tree and every
development file under a development tree, so a sheet read as a map of THIS
CHECKOUT points at pre-split locations. Read as a map of an installed Work root —
which is how an estate's reader meets them — they are still right about where
things sit.

**Both sheets carry `PROJECT: AI HARNESS v2` in the title block.** `#298` deleted
the version apparatus and removed every version statement from the estate's prose,
so these two title blocks are now the only place in the tree that states a harness
version. The claim is not wrong so much as orphaned: nothing else issues or tracks
a "v2", so a reader has no way to check it and no other statement to reconcile it
against. It is named here rather than drawn out.

NO WAVE EDITS AN SVG — the remaining divergences are named rather than drawn, and
`#178` is where the redraw is tracked and stays OPEN: REV S / REV H discharged the
label corrections, not the layout. For current enforcement/status/naming behaviour,
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
