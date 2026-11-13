# Doc-Tracker-Update — SKILL.md

## WHEN TO USE
The user asks for text to post on the tracker — a status summary, a finding, a close-out comment, a
test-evidence note — or for a small read-only verification script they can run and paste. Triggers: tracker
comment, tracker update, tracker summary, status update, verification script for the tracker.

## CRAFT GUIDANCE
**Kind:** draft first. Show it in chat; after the user's yes, post it yourself (CONSTITUTION §2), or hand it
over when they prefer to post it. Markdown, postable exactly as written.

**The reader** is a colleague who was not in the room and may have no technical background: an analyst, a
product owner, a manager. They read the first two lines and decide whether to read on. They will not work out
what a query proves or which of twelve numbers matters. Write for that reader, not for the agent that ran the
checks.

**Shape — comment:**

1. **The point, first.** One or two plain sentences: what was found or done, and what it means for the
   reader. No query, no number that is not the point, no history of how it was found.
2. **The evidence, one block per claim.** Each block is three things, in this order:
   - one sentence saying what the block shows;
   - the SQL (or command) in a fenced code block, short enough to read. Trim it to what produced the result:
     no scaffolding, no commented-out lines, no columns the reader does not need;
   - the result as a Markdown table, the rows of the last result set as they came back, then one or two
     sentences saying what the reader should see in it.
3. **What happens next**, when something does: who does what, or what is being waited on. One or two lines.
4. **Links** as masked links (CONSTITUTION §6.1): the PR, the walkthrough when it exists.

**Rules.**
- Lead with the conclusion. A comment that opens with a query or a list of numbers has buried its point.
- One claim per block. Three claims are three small blocks, not one long query with a paragraph under it.
- Passive voice and plain words: "The duplicate rows were removed", not "I ran a dedupe". Explain a term the
  reader may not know the first time it appears, or leave it out.
- A number appears with what it counts and why it matters. A number that does not support the point is cut.
- A long query or command is included only when it carries the argument. Otherwise say what was checked and
  link the file that holds it.
- A result too long to read is shown as its first rows with the total stated, or as an aggregate. Say which.
- The user's statement of status is the status; quote it rather than restating an inference.
- Data is written as observed (CONSTITUTION §2): identifiers, query text and result rows may appear. Only
  secrets are left out. A comment on a public tracker stays generic.
- What to cover is a judgement, not a template: impact, risk and the smallest change that would fix it are
  worth a line each when they matter, and are left out when they do not.

**Shape — verification script:** read-only, idempotent, self-describing. A header comment saying what it proves,
the environment it targets and the profile or connection it expects; it prints a short PASS/FAIL line per
check and never prints credentials. State the exact command to run it.

**Sources to mine:** the ticket's Current State and Changes Made; the latest `Agent-Output/` evidence; PR state.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate.

- `gh pr view <n> --repo <owner/repo> --json state,mergedAt,url` — PR state to quote (read-only).
- The tracker's CLI or MCP server named in the tools note (CONSTITUTION §2) — post the approved comment; when
  it is absent, return the text for the user to post.

Last reviewed: 2026-11-13
