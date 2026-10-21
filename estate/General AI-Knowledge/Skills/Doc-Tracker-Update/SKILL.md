# Doc-Tracker-Update — SKILL.md

## WHEN TO USE
The user asks for text to post on the tracker — a status summary, a close-out comment, a test-evidence
note — or for a small read-only verification script they can run and paste. Triggers: tracker comment, tracker update,
tracker summary, status update, verification script for the tracker.

## CRAFT GUIDANCE
**Kind:** draft only. Return it in chat. The user posts it; agents never write to the tracker.

**Shape — comment:** one-line outcome · what changed (component, columns, logic) · how it was verified (named
checks and their result, with the environment and date) · links (PRs, walkthrough when it exists) · what is
left, if anything. Tracker markdown: headings, bullets, code fences and tables render.

**Shape — verification script:** read-only, idempotent, self-describing. A header comment saying what it proves,
the environment it targets and the profile or connection it expects; it prints a short PASS/FAIL line per check
and never prints customer rows or credentials. SQL uses aggregates (counts, null counts, min/max dates);
shell uses metadata calls. State the exact command to run it.

**Rules:** the user's statement of status is the status; quote it rather than restating an inference.

**Sources to mine:** the ticket's Current State and Changes Made; the latest `Agent-Output/` evidence; PR state.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate.

- `gh pr view <n> --repo <owner/repo> --json state,mergedAt,url` — PR state to quote (read-only).

Last reviewed: 2026-10-20
