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
  its tickets, runbooks and reusable notes. The map root links each page in its
  Repositories and Pipelines tables. A pipeline page is the one home of that
  pipeline's facts (CONSTITUTION §9.2); a repo card is routing only.
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
  new runbook in its index. `ticket-closer` updates the affected Work Map pages
  at close-out, and `estate-auditor` repairs drift in approved batches.

The map is partial by design. A missing entry is not evidence of no related
work: fall back to a scoped search of ticket headers and knowledge indexes.

## Checking the graph

```
python3 _harness/scripts/check-work-map.py            # human-readable notes
python3 _harness/scripts/check-work-map.py --json     # counts and findings
python3 _harness/scripts/check-work-map.py --strict   # exit 1 on findings; manual use only
```

Its notes also cover the `repos` / `pipelines` frontmatter (CONSTITUTION §9.2): a document of a kind that
should carry `repos` but does not (`FRONTMATTER_MISSING`), a value with no repo card or pipeline page
(`UNKNOWN_REPO`, `UNKNOWN_PIPELINE`), a ticket whose `repos` differs from its Repos list or a page that does
not list itself (`FRONTMATTER_MISMATCH`), and a block it cannot read or a YAML comment
(`FRONTMATTER_MALFORMED`, `FRONTMATTER_COMMENT`). All are warnings.

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
| You, directly | `orchestrator`, `ticket-init`, `planner`, `implementer`, `ticket-closer`, `estate-auditor`, `estate-question`, `knowledge-curator`, `weekly-digest`, `retrospective` |
| The `orchestrator`, when you run one | Every other agent; it starts `ticket-init`, `planner`, `implementer`, `ticket-closer` and `estate-auditor` in your place |
| You or the parent agent | `ticket-recall`, `harness-recall` (read-only) |
| The parent, when ticket work completes | `ticket-scribe` |
| The parent, for a named valuable learning only | `knowledge-keeper` |
| The parent, for qualified evidence only | `check-scribe` |
| You, the parent, `planner`, `ticket-closer` or `estate-auditor`, on a requested document | `doc-writer` (targets: the `Doc-*` skills) |

The build loop (CONSTITUTION §11): start a `planner` session on the ticket; it
writes `Agent-Prompts/NN-<slug>.md`. Start an `implementer` session on that one
prompt; it writes `Agent-Output/NN-<slug>.md` and stops. Return to the planner to
review and write the next prompt. The implementer never writes the ticket log or
invokes agents; the planner owns the record. Finish with `ticket-closer`
(CONSTITUTION §14), which asks before writing outside the ticket folder. An
`orchestrator` session can run this whole loop for you: it starts each agent,
carries every hand-off, waits on CI through your host's PR notifications, and
brings you only what needs you. It approves, merges or pushes only under the
standing delegation you write yourself (below); without one, it asks you.

Which constitution sections each agent reads: the reading list in
[AGENTS.md](../AGENTS.md#your-reading-list).

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
| `check-scribe`, `harness-recall`, `knowledge-keeper`, `ticket-recall`, `ticket-scribe`, `weekly-digest` | `Claude Sonnet 5.5 (copilot)` |
| `ticket-init`, `planner`, `ticket-closer`, `doc-writer`, `estate-auditor`, `estate-question`, `knowledge-curator`, `retrospective` | `Claude Opus 5.5 (copilot)` |
| `orchestrator` | the strongest model available: an Opus- or Fable-class profile such as `Claude Opus 5.5 (copilot)` |
| `implementer` | the cheapest long-context model that follows a prompt exactly (it judges nothing) |

Pin the model picker's display name exactly. Lowercase model IDs were tried and
fell back silently to the session model; display names were confirmed with
tool-free probe agents.

This profile was applied on the maintainer's live setup. That does not guarantee
the names exist on other accounts.

## Orchestrator and standing delegation

The `orchestrator` (CONSTITUTION §12) runs a ticket end to end. What it may
approve, merge, push or act on for you comes from one place: a **Standing
delegation** section you write in your local tools note (CONSTITUTION §2), with
your words quoted, the date, and what they cover. No agent writes or widens it.
Without it the orchestrator is a courier, and you approve everything as before.

Hosts differ in whether one agent can start another. An agent that cannot start
the agent a step needs hands that step back (`AGENTS.md` Definitions: Invocation
modes).

| Host | What was found |
|---|---|
| VS Code agents | Naming an agent in another agent's `agents:` list overrides its `disable-model-invocation: true`; the listing agent needs the `agent` tool. A subagent cannot start further subagents unless `chat.subagents.allowInvocationsFromSubagents` is on (off by default; nesting depth at most 5). Read in the VS Code docs on 2026-10-29: [subagents](https://code.visualstudio.com/docs/agents/run/subagents), [custom agent file reference](https://code.visualstudio.com/docs/agents/reference/custom-agent-file-reference). |
| Copilot CLI and cloud agent | They do not accept the `agents:` field and delegate through their own task tool. How they treat `disable-model-invocation` and nested agents is not verified. |
| Claude Code | `user-invocable` and `disable-model-invocation` have no equivalent (`INSTALL-INSTRUCTIONS.md`, "Running the estate with Claude Code"). On one seat, a subagent started a further subagent of its own (2026-10-29). |

## Tool adapters

Optional, never harness dependencies: `aws`, `gh`, `snow`, `astro`, `dbt`, Obsidian's CLI (read commands only,
see "Obsidian" below) and
any configured MCP server. Keep the real profile, account, role and
environment mappings in an indexed local `Tools and Environments` note under
General AI-Knowledge (recommended), never in public files. A configured tool is
not an authenticated one. For MFA, SSO or passphrases, the human completes the
prompt in the terminal or browser and the agent waits; secrets never go through
chat.

## Sample prompts

- Init: "Start ticket `<tracker link>`; reuse related work."
- Plan (`planner`): "Plan `<ticket>`; write the first implementer prompt."
- Implement (`implementer`): "Run `Tickets/<ticket>/Agent-Prompts/01-<slug>.md`."
- Review (`planner`): "Review `Agent-Output/01-<slug>.md` and write the next prompt."
- Recall: "What do we already know about `<repo or pipeline>`? Cite at most three."
- Record: "Record this ticket's completed change, update the map links, run the checker."
- Close (`ticket-closer`): "Close `<ticket>`: it is merged and deployed to PROD."
- Audit (`estate-auditor`): "Audit the estate; propose the first batch of fixes."
- Backfill (`estate-auditor`): "Propose the next five tickets for retrospective walkthroughs."
- Ask (`estate-question`): "How can I check when a table was last recreated?" or "Which warehouse table does the `<pipeline>` pipeline write?"
- Document (`doc-writer`): "Refresh the `<pipeline>` pipeline page; verify live."
- Workbook: "Parse `Mappings/<workbook>.xlsx` version `<V>` into `<ticket>`."
- Curate: "Compact and promote knowledge for `<ticket>`; show me before publishing."

## Obsidian

Nothing in the harness needs Obsidian; this recipe makes an estate easier to browse in it. Obsidian keeps its
settings in the estate's `.obsidian/` folder, which the estate does not track, so set these once per machine.

1. **Excluded files** (Settings → Files and links → Excluded files): `GitHub/`, `_retired/`, the Python
   environment folder (for example `venv_global/`) and your assistant's settings folder (for example
   `.claude/`). Code checkouts otherwise fill the graph with notes that are not records.
2. **Graph colour groups** (Graph view → Groups). The first matching group colours a note, so keep this order:
   `file:walkthrough`, `path:Tickets`, `path:"General AI-Knowledge/Work Map"`,
   `path:"General AI-Knowledge/Skills"`, `path:"General AI-Knowledge"`, `path:"General Human Knowledge"`.
   To colour by repo instead, put one group `[repos:<repo>]` per repo above these; it matches the name in
   block and flow lists alike (`[pipelines:<pipeline>]` works the same way).
3. **Properties.** Documents with `repos` / `pipelines` frontmatter (CONSTITUTION §9.2) show both in the
   Properties panel. Property types are vault-wide settings in `.obsidian/`; set both to *List* if Obsidian
   picks another type. Write lists in block form (one `- item` line each): any edit in Obsidian rewrites a
   flow list (`[a, b]`) to block form, keeping the key order, so block form keeps diffs quiet. Quote any
   value that contains `: ` (for example `title: "Orders: daily load"`); unquoted, Obsidian ignores the whole
   block and the note shows no properties at all.
4. **Bases.** With the Bases core plugin on, open `General Human Knowledge/Estate.base`. Its views list
   tickets, tickets in one repo, walkthroughs, Work Map pages, runbooks and knowledge notes. For each repo,
   duplicate the "Tickets in one repo" view and change the name in its `repos.contains("...")` filter.
   Grouping a view by a list property makes one group per exact list (a note listing two repos sits only
   under the group for that pair), so each repo gets its own filtered view instead.
5. **Views are read-only by convention.** Editing a cell or dragging a card writes straight into the file's
   frontmatter, and a ticket file that changes without a Session Log entry fails the validator at the next
   session start. Change `repos` / `pipelines` through the agents (`ticket-scribe` for a ticket).
6. **Obsidian CLI (optional).** Obsidian ships a command-line interface that talks to the running app (checked
   on 1.14.5; on Windows the binary is `Obsidian.com` in the install folder). To enable it, close Obsidian,
   back up the app's `obsidian.json` (on Windows `%APPDATA%\obsidian\obsidian.json`), add `"cli": true` to it,
   and start Obsidian again; `Obsidian.com help` lists the commands. Record it in your tools note (binary path,
   version, date enabled). Agents use only its read commands, for example
   `search query="[repos:<repo>]" total`, `properties name=repos counts`, `property:read`,
   `base:query path="General Human Knowledge/Estate.base" view="Tickets" format=paths`, `links`, `backlinks`
   and `unresolved`. They never run its write commands on records (`create`, `append`, `prepend`, `delete`,
   `move`, `rename`, `property:set`, `property:remove`, `base:create`, `template:insert`, `history:restore`,
   `plugin:*`, `eval`, `dev:*`): a write changes a file without its owner, and a ticket file changed without a
   Session Log entry fails the validator.

Checked in Obsidian 1.14.5 (2026-10-30): a `[repos:<repo>]` search or graph group matches block and flow
lists; grouping a Base by a list gives one group per exact list; a quoted wiki-link in a property
(`"[[page]]"`) draws a graph edge and a backlink, but `repos` and `pipelines` hold plain names, which is what
`check-work-map.py` checks; an edit in the Properties panel rewrites flow lists to block form
(`check-work-map.py` reads both); an unquoted `: ` in any value hides the whole block from Obsidian,
and `check-work-map.py` reports it as `FRONTMATTER_MALFORMED`.

For a focused graph, filter with
`path:Tickets OR path:"General AI-Knowledge/Work Map"`. Open a repo or pipeline
page and use its local graph for immediate neighbours.

## Auditing

Start an `estate-auditor` session (CONSTITUTION §15). It runs
`_harness/scripts/audit-inventory.py` (read-only: stale tickets, open PRs, missing
walkthroughs, broken `#anchors`, pipeline-page gaps) and the map checker, writes a
dated report under `General Human Knowledge/Audits/` recording `Work commit audited: <sha>`, then
proposes fixes batch by batch — each stating what is fixed, added, changed or
removed — and applies only what you approve. `harness-status.sh` warns when the
latest audit is older than `HARNESS_AUDIT_STALE_DAYS` (default 30). A run limited to some
buckets titles its report "… bucket only" and does not reset that clock.

The same rules bind a hand audit: label each claim as observed from a source
(code, CI, a tracker) or only recorded in a note, and fix the owner rather than
copying the fact. Preserve history: leave dated logs and retrospectives as
written, add a new dated entry for corrections, and edit only living references
in place.
