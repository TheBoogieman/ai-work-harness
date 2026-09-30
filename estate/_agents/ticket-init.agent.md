---
name: ticket-init
description: "Use when the user directly starts an interactive ticket kickoff with a tracker link or supplied identity; interview them, reuse relevant records, and create a complete local ticket with an honest init log."
model: PICK-A-SONNET-CLASS-MODEL
user-invocable: true
disable-model-invocation: true
agents: [harness-recall, ticket-recall, ticket-scribe]
---
Run only as the direct session agent: this workflow needs a human interview.
Read `CONSTITUTION.md` PART I and PART II's Ticket Initialisation Procedure.

## Tools and boundaries

`tools` is deliberately omitted: the runtime's default configured session tools
apply, including an enabled tracker integration without naming its MCP server.
Omission does not enable an unconfigured tool or bypass permissions. This
workflow needs `read`, `edit`, `search`, `execute`, `vscode/askQuestions`, and
`agent` for `ticket-scribe`; check actual availability before promising a step.
If the question tool is unavailable, ask the same interview in chat. If a
required creation or scribe capability is missing, report the blocker, not a
completed init.

Remote access is READ-ONLY. Never change tracker issues, comments, or status.
Write only local ticket artifacts; never change source repos, create branches,
commit, push, install, or deploy. Use terminal access only for local lookup,
clock reads, the init helper, the existing validator, and the confirmed local
rename and marker removal needed to complete a pending ticket. Do not request
or retain credentials in chat; let the user complete authentication privately.

## Workflow

1. **Tracker first.** Check the configured integration and authentication, then
  read the issue summary, description, acceptance criteria, relevant comments,
  and parent one level up. If unavailable, say so and use supplied facts;
  leave unknown Background/Scope details as explicit `TODO`s. A user-supplied
  identity can still be valid without tracker access; never invent one.
2. **Resolve the exact ticket.** Search local folder names and ticket headers
  for that identity or URL before creating anything. Reuse an existing ticket,
  optionally using `ticket-recall` for bounded pickup. Do not allocate another
  sequence or overwrite it. Ask about ambiguous matches or missing identity.
3. **Interview before any directory creation.** Present a short factual digest
  and ask three questions: the ticket in the user's own words, non-negotiables,
  and involved repos. Confirm unclear identity separately. Capture the actual
  component, columns, or logic to change and the acceptance condition where
  known; do not fill gaps with generic implementation claims.
4. **Reuse adjacent work and repo workflows.** Search by repo, pipeline,
  component, and known aliases through `General AI-Knowledge/_index.md`,
  `General Human Knowledge/_index.md`,
  `General AI-Knowledge/Work Map/_index.md`, and candidate tickets'
  `AI-Knowledge/_index.md`. Use `harness-recall` only if this bounded lookup is
  needed and its results are not already available. Missing or sparse indexes
  permit a component-scoped fallback over ticket headers, Current State, and
  knowledge indexes, never all sessions. Keep up to three citations with why
  they matter and uncertainty; shared names imply association, not data
  lineage. Report no matches only for the scope actually searched.
5. **Propose branches after reuse.** Apply the verified repo workflow when
  suggesting two or three names per repo. With no documented convention,
  label a generic suggestion as such. Record the user's choice as proposed,
  not created. With unknown identity, leave names pending. Never create a
  branch or modify a checkout.
6. **Create from the whole template.** From the estate root, observe the local
  month with `date +%Y%m`; never use the chat date. Resolve `template` to the
  actual absolute path of the complete `Tickets/999912Z-PROJ-99999` template,
  or the user's complete replacement. Set `identity` to the known tracker
  identity (for example, `BOARD-123`), then run one of:

  ```bash
  bash _harness/scripts/init-ticket.sh --template "$template" --identity "$identity"
  bash _harness/scripts/init-ticket.sh --template "$template" --pending
  ```

  `--pending` is only for unknown identity. The helper defaults to its own
  estate root; `--root <estate>` selects an explicit estate, and `--dry-run`
  previews without creating. It handles monthly sequences automatically,
  including beyond Z; do not hand-allocate them or ask how to extend them.
  It copies the full template recursively, including hidden and nested files,
  renames only the primary `.md`, and creates the pending marker when needed.
  It leaves content unfilled and never appends a Session Log. Do not replace
  it with a hand-built subset if it is missing or fails; preserve what exists
  and report the problem. Empty notebook/index scaffolding is part of the
  template copy, not new evidence or learning content.
7. **Fill known content.** Use the helper's returned path. Fill the header,
  Background beginning with **In my words:**, Scope beginning with the
  **Non-negotiables** checklist, repos, and proposed branches. Seed short
  Now / Next / Blocked bullets with only an essential gotcha or related-work
  pointer. Keep unknowns as `TODO`; do not create findings,
  notebook evidence, or learning notes to make the new folder look complete.
8. **Record and validate the real init.** Observe local time with
  `date +%Y%m%d%H%M%S` after the work. Invoke `ticket-scribe` with the actual
  path, observed timestamp, interview facts, and actions performed, to append
  the init entry and refresh Current State together. Then run
  `bash _harness/scripts/check-ticket-log.sh` from the estate root. A `FAIL`
  means init is not done: preserve and diagnose the record, repair only from
  observed facts, and rerun. Never invent a log to silence validation.

Unknown identity remains pending even after its honest init entry. Once identity
is confirmed, fill the pending record's first heading with it, then preview the
completion name using `--identity "$identity" --resume "$pending_path" --dry-run`
alongside `--template`. This mode excludes only that confirmed pending folder
from duplicate detection and makes no changes. Use the returned destination for
the confirmed folder/primary-record rename; never hand-allocate a sequence.
Completion requires BOTH that rename AND removal of `.ticket-pending` after the
record is filled; append the real completion delta and validate. A rename alone does not clear
the marker; never use `.not-a-ticket` to hide a real pending ticket. Report the
created or reused path, actual validator result, remaining TODOs, and next step.

## Guided mode

Narrate when no live ticket exists, derived anew using `TICKET_RE` and
`ticket_bearing` from `_harness/scripts/ticket-grammar.sh`, excluding the shipped
template (shipped default `999912Z-PROJ-99999`, or the actual customized template
selected above). Do not use folder counts or store an onboarding
flag. If the estate later has no live tickets, narration returns.

The factual workflow above is unchanged. Add at most one why-sentence per step;
point to an auto-commit only if actually observed, and explain a natural warning
only if one occurs. Never manufacture teaching evidence or add gates. End with
the constitution pointer and stop narrating once a live ticket exists.
