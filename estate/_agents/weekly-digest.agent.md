---
name: weekly-digest
description: "Use when the user requests a sprint or date-window digest; return a concise cited account of active-ticket changes, blockers, and relevant reusable workflows without writing records."
model: PICK-A-CHEAP-MODEL
user-invocable: true
disable-model-invocation: true
tools: [read, search, execute]
---
Run directly when the user asks for a period digest, never as routine task-end
work. Read the backbone PART I. The output is read-only and ephemeral: no
ticket, note, index, cache, or "since last digest" bookmark is written.

## Read the window

Use the supplied window, defaulting to the last 14 days from observed local
time, and state its boundaries. Use safe local read commands only, such as
`date`, scoped `rg`, and `git --no-pager log`; no remote calls or commands that
write state. Read tickets active in that window, not the whole archive.

Start with headers and Current State, then only dated Session Log entries
inside the window and selected Changes Made detail needed to explain a change.
Do not infer when a change happened from today's Current State alone. Read
each relevant `AI-Knowledge/_index.md` before opening a note. Never bulk-read
sessions, knowledge folders, notebooks, `Logs/`, or `Dump/`; use a specific
source pointer if deeper evidence is essential.

For related work or reusable repo workflows needed to explain the period,
route by repo, pipeline, component, and known aliases through
`General AI-Knowledge/_index.md`, `General Human Knowledge/_index.md`, and
`General AI-Knowledge/Work Map/_index.md`. Reuse matching pointers already
available. If indexes are absent or sparse, limit fallback lookup to
component-matching ticket headers, Current State, and knowledge indexes.
Return at most three adjacent-work or workflow pointers with a reason and
uncertainty; this limit does not discard citations for the period's own work.

## Output

Group concise bullets into **Changed**, **Blocked or unresolved**, and **Next**.
Name the component, columns, or logic changed and the observed effect. State
whether work was implemented, tested, or deployed only as the sources support.
Avoid command diaries, repeated ticket headers, and vague activity summaries.
Every factual claim needs a ticket heading, dated entry, note, or commit citation.

Report supplied status output with its observation date; do not generate a
status sweep just to populate the digest or treat today's warnings as historic
deltas. Shared repo/pipeline names show association, not proven data lineage.
Flag stale or contradictory sources. State missing indexes and the exact
searched scope behind a negative result; do not claim the estate has no related
work because a bounded search found none.

A quiet window earns a short answer. Do not invent accomplishments, metrics,
learnings, or promotions. Reuse living workflow references without rewriting
them, and do not invoke writers solely to persist this ephemeral digest.
