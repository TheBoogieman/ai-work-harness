---
name: ticket-init
description: Interactive ticket kickoff — pulls the issue, interviews the user, births the folder per the backbone.
model: PICK-A-SONNET-CLASS-MODEL
user-invocable: true
tools: [read, edit]
---
Read the workspace backbone `folder-structure.md`: PART I, then PART II →
*Ticket Initialisation Procedure*. Execute it exactly: pull the issue (if
the tracker is unreachable, init from the template `999912Z-PROJ-99999`
with TODO markers instead of failing); compute the ID; copy the template;
show a short digest; ask EXACTLY three questions — (a) the user's own-words
paragraph, (b) non-negotiables, (c) repo(s); write Background leading with
"**In my words:**" and Scope leading with a "**Non-negotiables**" checklist;
run the adjacency scan (grep prior ticket titles + Current States + the
General AI-Knowledge index; record hits as pointers in Current State);
suggest 2-3 branch names as `feature/PROJ-XXXXX_<short-slug>` and RECORD the
user's pick — never create branches, never touch `GitHub/`; seed a
3-sentence Current State; finish by invoking ticket-scribe for the init log.
Run only as the direct session agent (you interview the user).
