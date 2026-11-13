# Doc-PR-Description — SKILL.md

## WHEN TO USE
Drafting a pull-request title and description for a ticket's change. Triggers: PR description, pull request
body, PR summary, write the PR.

## CRAFT GUIDANCE
**Kind:** draft first. Show it in chat (or, on request, write it to `Tickets/<folder>/Dump/`); after the
user's yes, open or edit the PR yourself (CONSTITUTION §2), or hand it over when they prefer to. Markdown,
postable exactly as written.

**The reader** is a reviewer who has not seen the ticket. They need to know what this change does and why
before they open the diff, and what to look at hardest once they do.

**Shape:** the repository's own PR template when it has one (`.github/pull_request_template.md`, or a file
under `.github/PULL_REQUEST_TEMPLATE/`, on the remote default branch). Keep its headings and its order, fill
every section, and write "None" in a section that does not apply; do not add sections of your own.

With no template:
- **Title** `<TICKET-ID>: <what changes, in the reader's words>`.
- **What and why**, first: two or three plain sentences. What the change does, and the problem it solves,
  with a link to the ticket.
- **What changed**: the components, files, columns and logic, old → new. A table when there are more than
  three.
- **How it was tested**: each check with what it proves and its result. Say "not run" honestly.
- **Deploy notes**: order, flags, rollback. Leave the heading out when there are none.

**Rules.**
- The point comes before any number. A reader who stops after the first paragraph should know what merges.
- A long command, query or log is included only when it carries the argument. Otherwise say what was run and
  what it showed, and link the file or run that holds the detail.
- Passive voice and plain words; one idea per sentence.
- What to cover is a judgement, not a template: say what the change could break, how risky it is and
  whether it is as small as it could be when a reviewer would want to know, in a line each.
- Data is written as observed in an internal PR (CONSTITUTION §2). Only secrets are left out. For a public
  repository, omit every work identifier and use generic examples.
- Links are masked links (CONSTITUTION §6.1).

**Sources to mine:** the repository's PR template; the ticket's Changes Made and Current State; the latest
`Agent-Output/` for the change and its tests; `git diff --stat origin/<default>...<branch>`.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate.

- `git -C <repo> show origin/<default>:.github/pull_request_template.md` — the repository's template, when it has one.
- `git -C <repo> diff --stat origin/<default>...<branch>` — the file list the description must cover.
- `gh pr view <n> --repo <owner/repo>` — the current PR body when refreshing one (read-only).
- `gh pr create` / `gh pr edit` with `--body-file <file>` — open or edit the PR after the user's yes.

Last reviewed: 2026-11-13
