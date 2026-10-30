# Doc-Ticket-Walkthrough — SKILL.md

## WHEN TO USE
Writing the human-facing handover / implementation walkthrough for one ticket at close-out, or on request
mid-ticket. Triggers: walkthrough, handover, implementation walkthrough, explain the ticket, close-out document,
summary for PM or lead.

## CRAFT GUIDANCE
**Kind:** one document per ticket (or per chain, see Shared mode), written by `doc-writer` for `ticket-closer` (or on the user's request).
**Destination:** `Tickets/<folder>/<BOARD-num>-walkthrough.md`, beside the primary ticket file; add it to the
ticket header's Context and to the ticket's line on its Work Map pages.

**Frontmatter (CONSTITUTION §9.2):** the file opens with a properties block above its first line. `repos`
holds every repo the ticket's frontmatter lists (a shared walkthrough: every chain ticket's repos); `pipelines`
the same for pipeline pages, or `[]`. Copy the values from the ticket; never guess one. No YAML comments.

```yaml
---
repos:
  - <repo>
pipelines: []
---
```

**Reader:** a technical person who was not in the room. Hand-hold: explain every term, every command and every
flag; say why each step was needed. No machine logs, no pasted transcripts, no bare commit hashes — a hash, run
ID or path appears only with what it is and why it matters.

**Required sections, in order (CONSTITUTION §14.1):**

1. **Summary** — status as of a date and its source; one plain paragraph; links (ticket log, tracker, PRs,
   pipeline page, runbook).
2. **Why it was needed** — business context and the problem in the pipeline.
3. **How the pipeline works** — a short tour with a Mermaid diagram marking where this change sits.
4. **How we worked out what to change** — discovery, design workbook version and rows, decisions, rejected options.
5. **What changed** — table: repo | file path | added / changed / removed | why. Then columns added or removed
   (name, type, source, output key) and config or schema changes.
6. **How we tested it** — each test, CI run, UAT run or validation query: what it proves and its outcome; what
   was not tested.
7. **How we shipped it** — branches, PRs (links, state), merge, build, UAT and PROD deploy commands with every
   flag explained, activation, post-deploy checks.
8. **Caveats and gotchas**.
9. **Questions a PM or lead might ask** — short Q&A.
10. **Glossary**.
11. **Where everything lives** — paths and links.
12. **How we got here** — a short timeline linking each `Agent-Prompts/NN-<slug>.md` / `Agent-Output/NN-<slug>.md` pair.

**Sources to mine, in order:** the ticket header, Current State and Changes Made; Session Log entries (read them
here — this is the one document that needs the whole story); `Agent-Prompts/` and `Agent-Output/`; PR
descriptions and CI runs (`gh pr view`); the pipeline page and runbook; the design workbook extract. Prefer
VERIFIED statements from outputs; mark anything else as recorded or not verified.

**Honesty rules:** say what was not tested; separate "deployed" from "verified"; keep the user's stated status
and any contradiction you found side by side.

**Retrospective mode (audit backfill, CONSTITUTION §14.1 and §15 step 6).** Requested by `estate-auditor` for a
ticket that never got a walkthrough. First line after the frontmatter block: `Written retrospectively on <YYYY-MM-DD> from the record; not a
close-out.` Same twelve sections. Sources in this order: the ticket `.md` in full (header, Background, Scope,
Changes Made, Current State, Session Log); `AI-Knowledge/` notes; `Agent-Prompts/` and `Agent-Output/`; saved
outputs of `Checks/` notebooks; the Work Map pipeline pages and repo cards that name the ticket
folder; the repo runbooks; `gh pr view` for each PR in the header. Section 1's status comes from Current State
with its date, labelled RECORDED. A section the sources cannot support reads `Not recorded — <which source is
missing>`; never fill it from general knowledge. Return to the auditor the list of `Not recorded` sections and
the ticket's `walkthrough_gaps` it was given. Do not change Current State or close the ticket.

**Shared mode (CONSTITUTION §14.1 Shared walkthrough).** Used when the parent names a chain of tickets layered on
one change. Write one document in the last ticket's folder, named for that ticket. Section 1 opens with a table of
the chain: ticket key, tracker link, PRs (links, state) and status with its source. Sections 4–7 split by ticket
only where the facts differ; section 12 covers every ticket's `Agent-Prompts/` / `Agent-Output/` pairs. Mine every
chain ticket's record, in the source order above, plus its older explainer and Q&A files; those are sources, not
facts — check each claim against the ticket records, let the record or the later correction win, and note the
disagreement in Caveats. Return the list of legacy files merged, so the parent can delete them once the document
lands, and the header Context line each earlier ticket needs. A duplicate ticket, or one fixed by another ticket's
change with no change of its own, gets no walkthrough: the parent links the fixing ticket's walkthrough instead.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate; repository-required
tests, CI, security and release checks still apply. Tool absence is not a passing check.

- `gh pr view <n> --repo <owner/repo> --json title,state,mergedAt,mergeCommit,url` — PR facts (read-only).
- `gh run view <id> --repo <owner/repo>` — CI or deploy run outcome (read-only).
- `git -C <repo> log --oneline <base>..<branch>` — commit list to explain, not to paste.

Last reviewed: 2026-10-30
