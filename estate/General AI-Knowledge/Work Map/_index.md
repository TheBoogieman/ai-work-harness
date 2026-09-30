# Work Map
Last reviewed: 2026-09-30

Find tickets and knowledge by repo or pipeline. This is a living link directory,
not data lineage, a deployment inventory or a replacement for ticket records.

## Repositories

No operator repositories indexed yet. Add links to `Repos/<repo>.md` as real
ticket work establishes them.

## Pipelines

No operator pipelines indexed yet. Add links to `Pipelines/<stable-name>.md` as
real ticket work establishes them. Record only observed aliases, not guesses.

## Page Shape

- Exact component name and observed aliases.
- Related repo/pipeline links, only when backed by a source.
- Links to the existing runbook and reusable knowledge notes.
- Ticket links with one-line context; keep status and change detail in the ticket.

Use relative Markdown links and encode spaces. A page linking to a ticket creates
the Obsidian graph connection without changing historical logs. On new/active
tickets, add useful reverse links under Context. No plugin is required. For a
focused graph, filter to `path:Tickets OR path:"General AI-Knowledge/Work Map"`;
use a repo/pipeline page's local graph for its immediate neighbours.

## Coverage

This template contains no indexed work. Record coverage as links are added.
Absence here is not evidence of no related ticket: fall back to scoped searches
of ticket headers, Current States and knowledge indexes. Follow at most three
relevant pointers by default. Do not bulk-read logs or notebooks.

[Reusable knowledge](../_index.md) | [Repo workflows](../../General%20Human%20Knowledge/Repo%20Workflows/_index.md)