# Harness Guide

How the harness keeps records connected, what runs by itself, what you start,
and which model profile suits which agent. Rules live in the
[constitution](../CONSTITUTION.md); this guide is the operator's map of them.
Entry points: [Work Map](../General%20AI-Knowledge/Work%20Map/_index.md),
[General AI-Knowledge](../General%20AI-Knowledge/_index.md) and
[General Human Knowledge](_index.md).

## How the graph is maintained

The graph is plain relative Markdown links. No plugin, database or agent holds
it; the files do.

- A repo or pipeline page under `Work Map/Repos/` or `Work Map/Pipelines/` links
  its tickets, runbooks and reusable notes. The map root links each page.
- The parent agent (the session you are talking to) updates the affected page
  and the map root when work first establishes a relationship, and adds up to
  three useful reverse links under the ticket's Context header.
- On creating, moving or renaming a note or runbook, the parent updates the
  matching general root index. Promotion leaves a valid tombstone in the ticket
  index.
- `ticket-scribe` validates the links it is given and asks the parent to repair
  gaps; it does not rebuild the broad map. `ticket-init` needs the new ticket's
  page entries linked before its final scribe step. `knowledge-curator` repairs
  backlinks and root indexes after renames and promotion. `doc-writer` registers a
  new runbook in its index.

The map is partial by design. A missing entry is not evidence of no related
work: fall back to a scoped search of ticket headers and knowledge indexes.

## Checking the graph

```
python3 _harness/scripts/check-work-map.py            # human-readable notes
python3 _harness/scripts/check-work-map.py --json     # counts and findings
python3 _harness/scripts/check-work-map.py --strict   # exit 1 on findings; manual use only
```

The helper is warning-only and read-only; the default root is its own estate.
It observes encoded relative links, reference definitions, file-index entries
and promotion links, which initialized tickets are reachable from a map entity
page, orphaned General AI-Knowledge or Human Knowledge notes, and gaps in what
it could read. It excludes `Logs`, `Dump`, notebooks and templates, and counts
uninitialized tickets explicitly. It does not judge whether a fact is true, and
it does not establish lineage or anything about cloud state. Its docstring lists
the Markdown it does not parse. Run it after a batch of link changes; links to
files outside the estate and uninitialized tickets are reported, not forced
clean. `--strict` is never wired into a hook.

## What runs automatically, and what you start

Mechanical hooks (see `_harness/hooks/hooks.example.json`):

| Event | Action |
|---|---|
| `sessionStart` | Ticket validator and a separate work-map observer command (navigation notes only; the validator command is unchanged) |
| `postToolUse` | Auto-commit of records, only while the hook is active and the estate key is set |
| `sessionEnd` | Validator plus a best-effort commit |

Agent contracts are instructions followed by the session that invokes them, not
a scheduler. Hooks do not launch custom agents. The parent assistant is
instructed to invoke the specialists below when their conditions apply; this
depends on the assistant following the contract, not a guaranteed background job.

| Start it | Agent |
|---|---|
| You, directly | `ticket-init`, `knowledge-curator`, `weekly-digest`, `retrospective` |
| You or the parent agent | `ticket-recall`, `harness-recall` (read-only) |
| The parent, when ticket work completes | `ticket-scribe` |
| The parent, for a named valuable learning only | `knowledge-keeper` |
| The parent, for qualified evidence only | `check-scribe` |
| You or the parent, on a requested PR or runbook | `doc-writer` |

All of them can be called by a human. Retention is gated: non-ticket work
invokes neither scribe nor keeper, and zero capture is the expected result.
Prose cannot guarantee judgement; the checker's warnings are observations and
never block.

## Model profile

Optional and operator-chosen. The public template keeps its placeholder pins,
which the installer asks you to set; a tier is a capability guide, not a price
guarantee, and the installer's "SONNET-CLASS" label is historical, so it accepts
an Opus profile too.

| Agents | Profile |
|---|---|
| `check-scribe`, `doc-writer`, `harness-recall`, `knowledge-keeper`, `ticket-recall`, `ticket-scribe`, `weekly-digest` | `Claude Sonnet 5.5 (copilot)` |
| `ticket-init`, `knowledge-curator`, `retrospective` | `Claude Opus 5.5 (copilot)` |

This profile was applied on the maintainer's live setup and confirmed with two
tool-free probes. That does not guarantee the names exist on other accounts.

## Tool adapters

Optional, never harness dependencies: `aws`, `gh`, `snow`, `astro`, `dbt` and
any configured MCP server. Keep the real profile, account, role and
environment mappings in an indexed local `Tools and Environments` note under
General AI-Knowledge (recommended), never in public files. A configured tool is
not an authenticated one. For MFA, SSO or passphrases, the human completes the
prompt in the terminal or browser and the agent waits; secrets never go through
chat.

## Sample prompts

- Init: "Start ticket `<tracker link>`; reuse related work."
- Recall: "What do we already know about `<repo or pipeline>`? Cite at most three."
- Closeout: "Record this ticket's completed change, update the map links, run the checker."
- Curate: "Compact and promote knowledge for `<ticket>`; show me before publishing."

## Graph view

In Obsidian, filter the graph with
`path:Tickets OR path:"General AI-Knowledge/Work Map"`. Open a repo or pipeline
page and use its local graph for immediate neighbours.

## Auditing

To audit the estate's Markdown, run the checker and read its full report one
finding at a time. Label each claim as observed from a source (code, CI, a
tracker) or only recorded in a note, and fix the owner rather than copying the
fact. Preserve history: leave dated logs and retrospectives as written, add a
new dated entry for corrections, and edit only living references in place.
