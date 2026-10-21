# Doc-PR-Description — SKILL.md

## WHEN TO USE
Drafting a pull-request title and description for a ticket's change. Triggers: PR description, pull request
body, PR summary, write the PR.

## CRAFT GUIDANCE
**Kind:** draft only. Return it in chat (or, on request, write it to `Tickets/<folder>/Dump/`); the human or the
implementer opens or edits the PR. Never create or edit a PR yourself.

**Shape:** follow the repository's PR template if one exists (`.github/pull_request_template.md` on the remote
default branch); otherwise: title `<TICKET-ID>: <component> — <what changed>` · **What** (component-first: files,
columns added/removed, logic old → new) · **Why** (one paragraph, link the ticket) · **How it was tested** (named
tests, CI, UAT evidence; say "not run" honestly) · **Deploy notes** (order, flags, rollback) · **Out of scope**.

**Rules:** no secrets, customer data or internal-only links in PRs that leave the organisation; for a public
repository, omit every work identifier and use generic examples.

**Sources to mine:** the ticket's Changes Made and Current State; the latest `Agent-Output/` for the change and
its tests; `git diff --stat origin/<default>...<branch>`.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate.

- `git -C <repo> diff --stat origin/<default>...<branch>` — the file list the description must cover.
- `gh pr view <n> --repo <owner/repo>` — the current PR body when refreshing one (read-only).

Last reviewed: 2026-10-20
