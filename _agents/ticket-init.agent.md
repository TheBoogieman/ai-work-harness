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
