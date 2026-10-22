# Work Map
Last reviewed: 2026-10-21

The estate's hub from repository or pipeline names to their pages, delivery
runbooks and ticket records. This is a living link directory, not data lineage,
a deployment inventory or a replacement for ticket records. Pipeline pages are
the one home of each pipeline's facts (CONSTITUTION §9.2): read a page's
Identity card first, then one section. Repo cards are routing.

[Reusable knowledge](../_index.md) | [Repo workflows](../../General%20Human%20Knowledge/Repo%20Workflows/_index.md) | [Pipeline page template](../Skills/Doc-Pipeline-Home/SKILL.md)

## Repositories

No operator repositories indexed yet. Add one row per repo card as real ticket
work establishes it:

| Repo card | Delivery runbook | Pipelines it hosts |
|---|---|---|
| `Repos/<repo>.md` | `General Human Knowledge/Repo Workflows/<runbook>.md` | one line |

## Pipelines

No operator pipelines indexed yet. Add one row per pipeline page as real ticket
work establishes it. Record only observed aliases, not guesses:

| Pipeline page | Runtime | Repos | Design workbook |
|---|---|---|---|
| `Pipelines/<stable-name>.md` | scheduler DAG or job name | repos | workbook in `Mappings/`, or — |

## Page Shape

- **Pipeline page** (`Pipelines/<stable-name>.md`): an Identity card, then fixed
  sections (How it works, Scheduling and triggers, Dependency Chain, Change recipes, Deploy,
  Validate, Behaviour and traps, Read before, Ticket history), each ending with a
  `Sources:` line. `doc-writer` creates and refreshes it with the
  [Doc-Pipeline-Home](../Skills/Doc-Pipeline-Home/SKILL.md) skill.
- **Repo card** (`Repos/<repo>.md`): local path, code-host repo, default branch,
  its delivery runbook, the pipelines it hosts, and ticket history.
- Related repo/pipeline links only when backed by a source; ticket links with
  one-line context; status and change detail stay in the ticket.

Use relative Markdown links and encode spaces. A page linking to a ticket creates
the Obsidian graph connection without changing historical logs. On new/active
tickets, add useful reverse links under Context. No plugin is required. For a
focused graph, filter to `path:Tickets OR path:"General AI-Knowledge/Work Map"`;
use a repo/pipeline page's local graph for its immediate neighbours.

## Maintenance

The parent agent adds or updates the repo/pipeline page and this index when work
first establishes a relationship, then hands the scribe the links. Afterwards run
the warning-only observer once; `--json` gives counts and findings, and
`--strict` is for manual use only, never a hook:

```
python3 _harness/scripts/check-work-map.py
python3 _harness/scripts/check-work-map.py --json
```

It reports link, mapping and orphan gaps, not whether a fact is true. See the
[Harness guide](../../General%20Human%20Knowledge/Harness%20Guide.md).

## Coverage

This template contains no indexed work. Record coverage as links are added.
Absence here is not evidence of no related ticket: fall back to scoped searches
of ticket headers, Current States and knowledge indexes. Follow at most three
relevant pointers by default. Do not bulk-read logs or notebooks.
