---
name: retrospective
description: "Use when the user requests a review-period retrospective; turn cited completed-ticket results, labelled operator-supplied context and period statistics into one new dated human-facing account, with discovery indexes and Work Map links updated."
model: PICK-A-SONNET-CLASS-MODEL
user-invocable: true
disable-model-invocation: true
tools: [read, edit, search, execute]
---
Run directly when the human requests a review, not as another agent's routine
task-end step. Read your row in `AGENTS.md` (CONSTITUTION.md §1, §6.1, §9.2
and §17). Produce an accomplishment-focused
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

The user may supply context the record does not hold: work that never became a
ticket (unblocking a colleague, guiding a deploy, building tooling), or detail
a ticket left out. Search the record for each item first and cite it when found.
When it is not found, include it only as the user stated it, labelled
`per operator, not in the record`, and never enlarge it, date it or give it an
outcome the user did not give. A labelled claim is the user's word, not
evidence; keep it out of the stats and say how many such claims the account
carries.

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

Where the record or the user states the conditions the work was done under
(a missing handover or knowledge transfer, an unfamiliar language or stack,
little or no supervision, a deadline), name them beside the accomplishment with
the same source pointer or label. Conditions are context for a reviewer, never
a complaint about a person; do not infer them from silence in the record.

Write in the first person unless the user asks for another voice: the account
is the user's own record of their work. Keep it plain and specific, without
promotional adjectives.

Use at most FIVE accomplishment themes and roughly 1,500 words for a
twelve-month window; offer a focused follow-up instead of a long tail. Sparse
sources mean a shorter account. State missing indexes, the searched
scope behind negative results, and unresolved claims. Do not confuse "no
matching record found" with "no work happened".

## Write and discover

Record the window near the top of the account. Before writing, read the
`since` / `until` frontmatter of existing retrospectives (their headers when an
older account has none): when the same window already exists, return that
path unless the user explicitly asks for a new edition. Otherwise write ONE new
file under `General Human Knowledge/Retrospectives/`, named using an observed
local timestamp; never overwrite a prior retrospective. A later correction belongs in a new dated account that
references the old one. Retrospectives stay append-only; repo workflow runbooks
are living references maintained in place by their writer.

Open the account with the frontmatter of CONSTITUTION §9.2: `since` and
`until`, the window's first and last dates as `YYYY-MM-DD`; `repos`, the union
of the `repos` lists of the tickets it cites; and `pipelines`, the union of
their `pipelines` lists. Copy repos and pipelines from those tickets' own
blocks, never guessed from prose; an empty union is `[]`. Under each
theme, link the Work Map repo card (`Work Map/Repos/<repo>.md`) or pipeline
page (`Work Map/Pipelines/<pipeline>.md`) the theme's tickets name, when that
page exists, with relative encoded links; a missing page is noted, not created.

The only other permitted writes are discovery entries. Add one line for the new
account to `General Human Knowledge/Retrospectives/_index.md`, creating that
index from the shipped template's shape when an older estate lacks it. Ensure
`General Human Knowledge/_index.md` routes to that index, and that
`General AI-Knowledge/Work Map/_index.md` links to it. Indexes are living
routing metadata, not retrospective content. Do not edit tickets, logs, AI
notes, workflows, Work Map pages, or other records. After the links are written,
run `python3 _harness/scripts/check-work-map.py` once and report its findings
for the new account; it is warning-only.

Return the file path, covered period, the count of operator-supplied claims,
and important evidence gaps. The account is local work context: remind the
human to review it before external sharing. Never publish it remotely or place
private identifiers in public examples.
