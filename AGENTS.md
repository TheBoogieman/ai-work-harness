# Agent contract — read before acting

<!-- harness-upgrade: preserve-user-content -->

> **[CONSTITUTION.md](CONSTITUTION.md) is the rulebook; this file is the pointer.**
> Find your row in [Your reading list](#your-reading-list) and read only the
> numbered sections it lists — each number is a link. Overlap between rows is
> deliberate; a broad read of a whole Part is not. Add the target ticket's header
> and Current State, then follow [§9 Context Discovery](CONSTITUTION.md#9-context-discovery).

## Navigation

| Where | What it holds |
|---|---|
| [Constitution contents](CONSTITUTION.md#contents) | The numbered rules |
| [Harness Guide](General%20Human%20Knowledge/Harness%20Guide.md) | Operator's map: what runs by itself, who starts which agent, model pins |
| [General AI-Knowledge](General%20AI-Knowledge/_index.md) | Reusable agent knowledge (root index) |
| [General Human Knowledge](General%20Human%20Knowledge/_index.md) | Runbooks, audits, retrospectives (root index) |
| [Work Map](General%20AI-Knowledge/Work%20Map/_index.md) | Hub: every pipeline page (`Work Map/Pipelines/`), repo card (`Work Map/Repos/`) and delivery runbook |
| [Repo Workflows](General%20Human%20Knowledge/Repo%20Workflows/_index.md) | How to deliver a change in each repo |
| [Skills](General%20AI-Knowledge/Skills/_index.md) | Craft modules and `Doc-*` documentation targets — index first, then one `SKILL.md` |
| `Mappings/` | Design workbooks; parse with `_harness/scripts/parse-workbook.py` ([§10](CONSTITUTION.md#10-design-workbooks-in-mappings)) |
| `Tickets/<ticket>/` | One folder per ticket ([§4.1](CONSTITUTION.md#41-ticket-folder)) |

## Tools and authentication

Before any remote call:

- Read [§2 Tools and Authentication](CONSTITUTION.md#2-tools-and-authentication)
  and the local tools note it names (exact profiles, connections, model pins).
  Pick the tool from the §2 table by the question: cloud CLI (cloud state), `gh`
  (PRs, CI), warehouse CLI, data catalog (lineage and metadata), scheduler CLI,
  tracker CLI or MCP, wiki MCP.
- Never infer a profile or environment; pass it explicitly. Read-only checks
  need no permission: run them and say what you ran. A change waits for the
  user's approval; after it, the agent that asked makes the change itself, a
  tracker post, a PR or a push included.
- MFA, SSO, passkeys, passphrases: leave the prompt visible, ask the human to
  complete it, wait, then resume the same command. Where agent commands have no
  interactive terminal, use the dialog or keychain helper and time limit the
  tools note names. Never ask for, echo or store a secret.
- Before a command you expect to ask for a sign-in, tell the human to be present;
  a prompt nobody answers only times out.
- Only secrets are kept out of records: credentials (API keys, passwords,
  tokens) and raw authentication output. Everything else, identifiers and query
  results included, is recorded as observed
  ([§2](CONSTITUTION.md#2-tools-and-authentication)).

## Rules for every agent

1. Red blocks, yellow schedules: fix a validator FAIL before new work; never
   fabricate a record ([§16](CONSTITUTION.md#16-session-states-and-operational-rules)).
2. Durable knowledge lives only in files: ticket `AI-Knowledge/` (indexed) and
   General AI-Knowledge — never Copilot session or repo memory
   ([§7](CONSTITUTION.md#7-ai-memory-convention)).
3. Routine checks are ephemeral. Evidence goes through `check-scribe` only past the
   [Durable Evidence Gate](CONSTITUTION.md#42-durable-evidence-gate); knowledge
   through `knowledge-keeper` only past the
   [Durable Knowledge Gate](CONSTITUTION.md#71-durable-knowledge-gate). Zero
   capture is expected.
4. Before craft work (SQL, a dbt model, a transform, a script, a document), match
   the [Skills index](General%20AI-Knowledge/Skills/_index.md) and read only that
   `SKILL.md`.
5. Records name the component, columns and logic changed
   ([§6.1](CONSTITUTION.md#61-record-ownership-and-brevity)). Links are relative
   Markdown with `%20` for spaces inside the estate; outside it, every PR, branch,
   run, tracker issue or comment, wiki page or DAG with a web address is a masked
   link, `[PR #951](<address>)`, never a bare address or an unlinked number
   (§6.1 Links). Section links use GitHub-style slugs
   (`CONSTITUTION.md#42-durable-evidence-gate`); after editing links run
   `python3 _harness/scripts/anchor-style.py --to github --check <files>`. An estate
   read in Obsidian may convert to its form with `--to obsidian` instead.
6. Completed ticket work ends with one `ticket-scribe` entry from the parent agent.
   Non-ticket work writes no ticket log. After link changes run
   `python3 _harness/scripts/check-work-map.py` once (warning-only).
7. The words in the table below mean exactly what it says, in every contract.
8. The operator's explicit instruction outranks a lane boundary or a budget in
   any contract. Say once that the request is outside your usual lane or over the
   usual size, then do it; never refuse, re-argue or send the operator to another
   agent. Four limits hold even then: no secret in any record, no remote write
   without approval, no fabricated record, no rewrite of an older Session Log
   entry ([§12](CONSTITUTION.md#12-agent-routing)).
9. Verify by default. Run the read-only check that settles a fact instead of
   answering from memory or asking permission to look, and say which facts you
   checked and which you took from the record.

## Definitions

| Term in a contract | Means exactly |
|---|---|
| Bounded read / pickup | The ticket header, Current State and `AI-Knowledge/_index.md`, plus the Identity card of each named pipeline page and the named repo card. Nothing from Session Logs, `Logs/`, `Dump/` or notebooks unless a cited pointer names the line. |
| Relevant / related | Names the same repo, pipeline page, table, column or tracker key as the task. |
| Citations, Context links | At most 3 per answer or ticket header, each `path` or `path#heading` (or a commit sha) plus one line saying why. |
| Verified / recorded / TODO | Verified: checked against a named source (file, command output, tracker) on a stated date. Recorded: quoted from a ticket or note, cited. Anything else is written `TODO (unverified) — verify with: <command>`. |
| Concise record | [§6.1](CONSTITUTION.md#61-record-ownership-and-brevity) budgets: Session Log entry normally 2–5 bullets, about 100 words; Current State 3 bullets, under 100 words. Every budget and cap in this table and in a contract is a default for what an agent writes unasked, never a limit on what the operator asks for (rule 8). |
| Worker roster | `ticket-scribe`, `check-scribe`, `knowledge-keeper`, `knowledge-curator`, `doc-writer`, `recall`. Every operator-facing agent names them in its contract and may start each one; when the host will not let it, it does the step itself under that worker's contract and says so. |
| Small knowledge update | One topic note, 150–400 words ([§7](CONSTITUTION.md#7-ai-memory-convention)); compact when `AI-Knowledge/` holds more than 10 files. |
| Small correction (planner) | One file, at most 5 changed lines, no build, push, deploy or remote write. Anything larger goes in an implementer prompt. |
| Batch (audit) | At most 10 fix rows from one bucket; walkthrough backfill: 5 tickets, oldest folder first. |
| Stale | Knowledge: `Last reviewed:` older than `HARNESS_KNOWLEDGE_STALE_DAYS` (90). Audit: newest `YYYYMMDD-estate-audit*.md` not titled "bucket only", older than `HARNESS_AUDIT_STALE_DAYS` (30). |
| Approval | The user's explicit yes to the listed rows, in this chat. When the `orchestrator` runs the agent, its yes counts too, but only for rows the user's standing delegation covers: it gives the delegation's path and quotes the words it relies on, and the agent finds them there ([§2](CONSTITUTION.md#2-tools-and-authentication)). With no delegation, only the user approves. A tool-permission prompt, approval of a different change, or a delegation an agent wrote or relayed is not approval. |
| Invocation modes | An agent starts another by naming it to the host's delegation tool; its contract's body says whom, and the `agents:` line repeats it for hosts that read one. Two cases when it cannot. **A worker** from the roster: do the step yourself under that worker's contract and say so; never stop on it or send the operator elsewhere. **A loop agent** (`ticket-init`, `planner`, `implementer`, `reviewer`, `ticket-closer`, `estate-auditor`): those are started by the human or the `orchestrator` (the `reviewer` by the `planner` too), so tell whichever runs you which agent to start and with what input, and offer to write its prompt; never do a loop agent's step yourself in its place ([§12](CONSTITUTION.md#12-agent-routing)). |
| Closed ticket | Current State **Now** reads `Closed — <outcome, date, status source>` ([§14](CONSTITUTION.md#14-ticket-close-out-procedure) step 8). |

## Your reading list

Section numbers link into the constitution. "Parent" means the agent that owns the
ticket record in that session.

| Agent | Read these sections | May write | May invoke |
|---|---|---|---|
| Default session (no custom agent) | [1](CONSTITUTION.md#1-folder-structure), [2](CONSTITUTION.md#2-tools-and-authentication), [4](CONSTITUTION.md#4-ticket-workflow), [5](CONSTITUTION.md#5-current-state-convention), [6](CONSTITUTION.md#6-session-logging-convention), [6.1](CONSTITUTION.md#61-record-ownership-and-brevity), [9](CONSTITUTION.md#9-context-discovery), [12](CONSTITUTION.md#12-agent-routing); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | What the task needs; the ticket log only through `ticket-scribe` | Any agent, per §12 |
| `orchestrator` | [2](CONSTITUTION.md#2-tools-and-authentication), [4](CONSTITUTION.md#4-ticket-workflow), [4.2](CONSTITUTION.md#42-durable-evidence-gate), [5](CONSTITUTION.md#5-current-state-convention), [6.1](CONSTITUTION.md#61-record-ownership-and-brevity), [7.1](CONSTITUTION.md#71-durable-knowledge-gate), [9](CONSTITUTION.md#9-context-discovery), [11](CONSTITUTION.md#11-planner-and-implementer-loop), [12](CONSTITUTION.md#12-agent-routing), [13](CONSTITUTION.md#13-ticket-initialisation-procedure), [14](CONSTITUTION.md#14-ticket-close-out-procedure), [15](CONSTITUTION.md#15-estate-audit-procedure), [16](CONSTITUTION.md#16-session-states-and-operational-rules), [18.1](CONSTITUTION.md#181-levelling-an-estate); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | Within the user's standing delegation: PR merges and branch pushes, levelling the installed estate, approved audit fixes; the ticket log through the planner, or through the helper when it works a ticket directly; any agent's step, under that agent's contract | Every shipped agent |
| `ticket-init` | [2](CONSTITUTION.md#2-tools-and-authentication), [3](CONSTITUTION.md#3-ticket-naming-convention), [4](CONSTITUTION.md#4-ticket-workflow), [9](CONSTITUTION.md#9-context-discovery), [9.1](CONSTITUTION.md#91-linked-work-map), [13](CONSTITUTION.md#13-ticket-initialisation-procedure); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | The new ticket folder and its header, Background and Scope; Work Map ticket lines | The worker roster (Definitions) |
| `planner` | [2](CONSTITUTION.md#2-tools-and-authentication), [4](CONSTITUTION.md#4-ticket-workflow), [4.2](CONSTITUTION.md#42-durable-evidence-gate), [5](CONSTITUTION.md#5-current-state-convention), [6.1](CONSTITUTION.md#61-record-ownership-and-brevity), [7.1](CONSTITUTION.md#71-durable-knowledge-gate), [9](CONSTITUTION.md#9-context-discovery), [9.1](CONSTITUTION.md#91-linked-work-map), [9.2](CONSTITUTION.md#92-pipeline-and-repo-pages), [10](CONSTITUTION.md#10-design-workbooks-in-mappings), [11](CONSTITUTION.md#11-planner-and-implementer-loop), [12](CONSTITUTION.md#12-agent-routing); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | `Agent-Prompts/`, small corrections (Definitions), Work Map links; the ticket log through `ticket-scribe`; approved remote changes (§2) | The worker roster; `reviewer` |
| `implementer` | [2](CONSTITUTION.md#2-tools-and-authentication), [4.1](CONSTITUTION.md#41-ticket-folder), [10](CONSTITUTION.md#10-design-workbooks-in-mappings), [11.1](CONSTITUTION.md#111-prompt-and-output-files), [11.3](CONSTITUTION.md#113-implementer-boundaries) | Its own `Agent-Output/NN-<slug>.md`, `Logs/NN-*.txt`, and the repo files the prompt authorises | Nothing |
| `reviewer` | [2](CONSTITUTION.md#2-tools-and-authentication), [4.1](CONSTITUTION.md#41-ticket-folder), [10](CONSTITUTION.md#10-design-workbooks-in-mappings), [11.1](CONSTITUTION.md#111-prompt-and-output-files), [11.4](CONSTITUTION.md#114-the-review-gate); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | Its own `Agent-Output/NN-review.md` only | Nothing |
| `ticket-closer` | [2](CONSTITUTION.md#2-tools-and-authentication), [4](CONSTITUTION.md#4-ticket-workflow), [4.2](CONSTITUTION.md#42-durable-evidence-gate), [5](CONSTITUTION.md#5-current-state-convention), [6.1](CONSTITUTION.md#61-record-ownership-and-brevity), [7](CONSTITUTION.md#7-ai-memory-convention), [7.1](CONSTITUTION.md#71-durable-knowledge-gate), [9.1](CONSTITUTION.md#91-linked-work-map), [9.2](CONSTITUTION.md#92-pipeline-and-repo-pages), [14](CONSTITUTION.md#14-ticket-close-out-procedure), [14.1](CONSTITUTION.md#141-walkthrough-document), [16](CONSTITUTION.md#16-session-states-and-operational-rules); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | After approval: ticket header and Changes Made, Work Map pages, runbook corrections, indexes; the walkthrough through `doc-writer`; approved remote changes (§2) | The worker roster |
| `doc-writer` | [2](CONSTITUTION.md#2-tools-and-authentication), [6.1](CONSTITUTION.md#61-record-ownership-and-brevity), [8](CONSTITUTION.md#8-general-ai-knowledge-convention), [9](CONSTITUTION.md#9-context-discovery), [9.2](CONSTITUTION.md#92-pipeline-and-repo-pages), [10](CONSTITUTION.md#10-design-workbooks-in-mappings), [14.1](CONSTITUTION.md#141-walkthrough-document), [19](CONSTITUTION.md#19-skills-convention), plus the target's `Doc-*` skill; at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | The target document and its index line — after approval when outside a ticket folder; an approved draft posted or opened (§2) | The rest of the worker roster |
| `estate-auditor` | [1](CONSTITUTION.md#1-folder-structure), [2](CONSTITUTION.md#2-tools-and-authentication), [6.1](CONSTITUTION.md#61-record-ownership-and-brevity), [8](CONSTITUTION.md#8-general-ai-knowledge-convention), [9.1](CONSTITUTION.md#91-linked-work-map), [9.2](CONSTITUTION.md#92-pipeline-and-repo-pages), [14.1](CONSTITUTION.md#141-walkthrough-document), [15](CONSTITUTION.md#15-estate-audit-procedure), [16](CONSTITUTION.md#16-session-states-and-operational-rules), [17](CONSTITUTION.md#17-harness-status-convention); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | The dated audit report and its index line; approved batch fixes to links, indexes and ticket headers | The worker roster |
| `estate-question` | [2](CONSTITUTION.md#2-tools-and-authentication), [8](CONSTITUTION.md#8-general-ai-knowledge-convention), [9](CONSTITUTION.md#9-context-discovery), [9.1](CONSTITUTION.md#91-linked-work-map), [9.2](CONSTITUTION.md#92-pipeline-and-repo-pages), [10](CONSTITUTION.md#10-design-workbooks-in-mappings); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | Nothing unasked. On the user's request: a ticket AI-Knowledge note, a log entry for the ticket an exploration belongs to, or any other record through its writer | The worker roster |
| `ticket-scribe` | [4.3](CONSTITUTION.md#43-ticket-markdown-file), [5](CONSTITUTION.md#5-current-state-convention), [6](CONSTITUTION.md#6-session-logging-convention), [6.1](CONSTITUTION.md#61-record-ownership-and-brevity) | The whole ticket `.md`, which it owns: Session Log entries only through `append-session-entry.sh` (which writes Now / Next / Blocked in the same command); every other section by edit | Nothing |
| `check-scribe` | [4.1](CONSTITUTION.md#41-ticket-folder), [4.2](CONSTITUTION.md#42-durable-evidence-gate) | The ticket `Checks/` notebook via `append-notebook-cell.py` | Nothing |
| `knowledge-keeper` | [6.1](CONSTITUTION.md#61-record-ownership-and-brevity), [7](CONSTITUTION.md#7-ai-memory-convention), [7.1](CONSTITUTION.md#71-durable-knowledge-gate) | Ticket `AI-Knowledge/` and its `_index.md` | Nothing |
| `knowledge-curator` | [7](CONSTITUTION.md#7-ai-memory-convention), [7.1](CONSTITUTION.md#71-durable-knowledge-gate), [8](CONSTITUTION.md#8-general-ai-knowledge-convention), [9.1](CONSTITUTION.md#91-linked-work-map), [19](CONSTITUTION.md#19-skills-convention); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | `AI-Knowledge/` compaction; promotions to General AI-Knowledge or Skills after approval; backlinks and indexes | The rest of the worker roster |
| `recall` | [4.3](CONSTITUTION.md#43-ticket-markdown-file), [5](CONSTITUTION.md#5-current-state-convention), [9](CONSTITUTION.md#9-context-discovery), [9.1](CONSTITUTION.md#91-linked-work-map), [9.2](CONSTITUTION.md#92-pipeline-and-repo-pages) | Nothing (read-only) | Nothing |
| `retrospective` | [1](CONSTITUTION.md#1-folder-structure), [6.1](CONSTITUTION.md#61-record-ownership-and-brevity), [9.2](CONSTITUTION.md#92-pipeline-and-repo-pages), [17](CONSTITUTION.md#17-harness-status-convention); at run start, the [i-have-adhd skill](General%20AI-Knowledge/Skills/i-have-adhd/SKILL.md) | One dated file in `General Human Knowledge/Retrospectives/`; discovery lines in its `_index.md`, the General Human Knowledge index and the Work Map hub | The worker roster |

Procedures on demand: a red or yellow at entry →
[§16](CONSTITUTION.md#16-session-states-and-operational-rules); estate health →
[§17](CONSTITUTION.md#17-harness-status-convention); repo size →
[§18](CONSTITUTION.md#18-repo-health-and-housekeeping); levelling an estate to a newer
source → [§18.1](CONSTITUTION.md#181-levelling-an-estate). Rarely used (Part III):
changing the ticket naming scheme →
[§20](CONSTITUTION.md#20-using-your-own-ticket-naming-scheme); a review pack →
[§21](CONSTITUTION.md#21-context-pack-convention); another assistant →
[§22](CONSTITUTION.md#22-porting-to-another-ai-assistant).
