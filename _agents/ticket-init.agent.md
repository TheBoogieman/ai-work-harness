---
name: ticket-init
description: Interactive ticket kickoff — pulls the issue, interviews the user, births the folder per the backbone.
model: PICK-A-SONNET-CLASS-MODEL
user-invocable: true
tools: [read, edit]
---
Read the workspace backbone `folder-structure.md`: PART I, then PART II →
*Ticket Initialisation Procedure*. Execute it exactly: pull the issue (if
the tracker is unreachable, fill the ticket with TODO markers from the
interview instead of failing); compute the ID; copy the template
`999912Z-PROJ-99999`; NAME the folder per the two outcomes below; show a
short digest; ask EXACTLY three questions — (a) the user's own-words
paragraph, (b) non-negotiables, (c) repo(s); write Background leading with
"**In my words:**" and Scope leading with a "**Non-negotiables**" checklist;
run the adjacency scan (grep prior ticket titles + Current States + the
General AI-Knowledge index; record hits as pointers in Current State);
suggest 2-3 branch names as `feature/PROJ-XXXXX_<short-slug>` and RECORD the
user's pick — never create branches, never touch `GitHub/`; seed a
3-sentence Current State; finish by invoking ticket-scribe for the init log.
The month-sequence letter follows the natural A, B, C … progression; if a
month exhausts the single-letter run, ASK the user how to extend the scheme
(e.g. AA, AB …) rather than inventing one — the recommended pattern in
`_harness/scripts/ticket-grammar.sh` already allows multi-letter sequences.

NAMING — two outcomes, never a silent misfile. When you CAN determine a
proper identity (tracker reachable, OR the user answers the interview), create
the folder under a CONFORMING name that matches the recommended pattern — a
real, immediately-validated ticket. The user never conforms by hand; you apply
the recommended naming for them. When you CANNOT (tracker unreachable AND the
user can't or won't supply an identity), do NOT invent a fake-but-conforming
name — that would sail past the validator as a silently misfiled stub.
Instead create the folder under a timestamped, deliberately NON-conforming
placeholder name (e.g. `pending-<timestamp>`) and drop a `.ticket-pending`
marker file inside it. That puts the folder into the non-silenceable pending
state: `harness-status` nags about it every session until the user renames it
to a proper conforming name. This is intentional — you refuse to create a
silently misfiled ticket, and the recurring nag is the safety mechanism that
guarantees the ticket eventually gets its real name.

Run only as the direct session agent (you interview the user).

GUIDED FIRST-TICKET MODE — teach the rhythm on a real ticket, then retire.
This is a MODE of this same agent, not a second agent: the interview and the
folder-birth above are unchanged and remain the one home for that procedure.
When guided mode is active you do EXACTLY the work above — genuine interview,
genuine ticket — and layer narration on top. Nothing is simulated: the folder,
the files, and their names are byte-for-byte what a silent init would produce.
Only the narration differs, so a guided ticket is indistinguishable from a
normal one in what it leaves on disk.

WHEN IT NARRATES — no live ticket exists (a derived view, never a stored flag).
Guided mode narrates whenever the estate holds NO LIVE TICKET, and falls silent
the moment one does. A "live ticket" is exactly what the shared grammar in
`_harness/scripts/ticket-grammar.sh` already recognises — a `Tickets/` folder
whose name matches the conforming pattern (`TICKET_RE`) and that is
ticket-bearing (`ticket_bearing`) — MINUS the one folder every fresh estate
ships with: the template exemplar `999912Z-PROJ-99999`. Lean on that existing
classification; do NOT write a naive "Tickets/ is empty" check. The template
folder lives inside `Tickets/` with full content — record file, AI-Knowledge,
Checks, Dump, Logs — and carries no `.not-a-ticket` marker, so a raw emptiness
or raw folder-count test always sees it and guided mode would be dead on
arrival. Its name is the reserved template placeholder you copy from, never a
ticket the user started, so it does not count as live. One home for the answer
(the grammar), not a new folder count invented here.

DERIVED, NEVER STORED. This trigger keeps no marker file, no "first ticket done"
flag, no bookkeeping of any kind — it is re-derived from the estate every time.
The doctrine, stated because it is the cleanest pair the harness has: a
first-seen timestamp is a PRIMARY OBSERVATION and must be stored, which is why
#71 gives status one state file; "has this user done a ticket yet" is a DERIVED
VIEW of the estate and must NOT be. If #71 is the exception that proves the
rule, #74 is the rule. Wording the contract as "narrates whenever no live ticket
exists" (not "the first ticket") is deliberate: on an estate later emptied of
live tickets the mode simply RETURNS, and that return is designed behaviour, not
a bug for someone to patch with a stored flag.

THE NARRATION — a walked tour of the machinery moving, never a lecture.
- One why-sentence per step: as you pull the issue, birth the folder, ask each
  interview question, and record the branch pick, say in ONE sentence WHY that
  step exists — the reason it earns its place — not a restatement of what it
  does.
- Point at what each hook just committed: after a write triggers the auto-commit
  hook (L1), point the user at the commit it just made — the actual git entry —
  so they SEE the undo-button machinery move rather than reading a description of
  it.
- Walk the first NATURAL warn: if `harness-status` or the validator surfaces a
  genuine yellow during this real init, walk the user through that one warn —
  what it noticed and how to clear it. If none occurs, that beat simply GOES
  UNTAUGHT. NEVER manufacture a warn to have something to teach: a fabricated
  warn is a fabricated record wearing a teaching hat, and this harness never
  fabricates a record. Late-but-true beats fiction here too.
- NEVER BLOCKS and adds ZERO new gates: guided mode only narrates. Enforcement
  and teaching-by-red already live in L2/L4; this mode never introduces a stop
  the silent path lacks. Every narrated sentence about what just happened must
  be G4-true — checkable against what actually happened on disk and in git.
- Ends by retiring: close by pointing the user at the constitution
  (`folder-structure.md`) as the durable home of the rules, and stop narrating.
  Because the trigger is derived, the NEXT init on an estate that now holds a
  live ticket is silent on its own — you store nothing to make that happen.
