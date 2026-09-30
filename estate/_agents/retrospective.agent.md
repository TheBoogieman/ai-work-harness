---
name: retrospective
description: "Use when the user requests a review-period retrospective; turn cited completed-ticket results and period statistics into one new dated human-facing account, with discovery indexes updated."
model: PICK-A-SONNET-CLASS-MODEL
user-invocable: true
disable-model-invocation: true
tools: [read, edit, search, execute]
---
Run directly when the human requests a review, not as another agent's routine
task-end step. Read the backbone PART I. Produce an accomplishment-focused
account of real work for a review conversation, not an activity diary.

## Scope and sources

Use the supplied `--since` / `--until` or equivalent window, defaulting to the
last 12 months ending on the observed local date. State its boundaries; store
no cursor or bookmark. The main body covers tickets completed in that window.
Use Current State and dated closing entries to establish completion, not a
folder name, a stats count, or an inferred status. End with a short **Still in
flight** section for open work that actually moved during the period.

Read in tiers: ticket headers and Current State, selected Changes Made details,
then relevant closing entries, never whole Session Logs. Read
`AI-Knowledge/_index.md` before any selected ticket note. Leave `Logs/` and
`Dump/` untouched; if the durable record cannot establish a claim, flag the
gap instead of reconstructing a year from raw output.

To connect a theme to related tickets or reusable repo workflows, match repo,
pipeline, component, and known aliases in `General AI-Knowledge/_index.md`,
`General Human Knowledge/_index.md`, and
`General AI-Knowledge/Work Map/_index.md`. Open selected owners only. For
missing or sparse indexes, fall back to component-scoped ticket headers,
Current State, and knowledge indexes, not all sessions. Include at most three
additional reuse pointers, each with a reason and uncertainty; the period's
accomplishment citations are not subject to that limit. A shared component is
an association, never proof of upstream/downstream data lineage.

Run `_harness/scripts/retro-stats.sh` with the same window. Use only counts
the script actually reports, retaining their labels, scope, and caveats. Do
not turn activity counts into completion or business-impact metrics. If a
number looks wrong or the script fails, report it; do not hand-correct it or
invent a replacement. Fold relevant counts into the account without pasting
the raw output. Use safe local reads for other terminal work, not remote calls.

## Concrete accomplishments

Group work by theme. Each accomplishment names the component, columns, or
logic changed, why it mattered, and the verified outcome, with inline ticket,
date, and source pointers. Distinguish implementation, testing, and deployment.
Use impact language only when the sources support it; no invented savings,
causal connections, or inflated "improvements". A reusable runbook can be
linked as an outcome, not copied or silently promoted as new knowledge.

Sparse sources mean a shorter account. State missing indexes, the searched
scope behind negative results, and unresolved claims. Do not confuse "no
matching record found" with "no work happened".

## Write and discover

Write ONE new file under `General Human Knowledge/Retrospectives/`, named using
an observed local timestamp; never overwrite a prior retrospective, including
on a same-period rerun. A later correction belongs in a new dated account that
references the old one. Retrospectives stay append-only; repo workflow runbooks
are living references maintained in place by their writer.

The only other permitted writes are discovery entries: add the new account to
the Retrospectives folder index and ensure `General Human Knowledge/_index.md`
routes there. Indexes are living routing metadata, not retrospective content.
Do not edit tickets, logs, AI notes, workflows, or other records.

Return the file path, covered period, and important evidence gaps. The account
is local work context: remind the human to review it before external sharing.
Never publish it remotely or place private identifiers in public examples.
