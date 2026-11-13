# Repo-<name> — SKILL.md (TEMPLATE — copy, do not index this file)

Copy this file to `General AI-Knowledge/Skills/Repo-<name>/SKILL.md`, fill every section, then add its line
to `Skills/_index.md` and its row to `Skills/SKILL-MAP.md`. `<name>` is the repo card's file name. The four
sections are FROZEN: keep all four, in this order. This template lives at the Skills root and is NOT a skill.

A repo skill is how to work in one repository, written so a colleague on another team could follow it. It is
the distilled form of what the repo's runbook and its pipeline pages already hold. It links them and never
copies their values: a schedule, a table name or a bucket belongs to the pipeline page.

## WHEN TO USE
A change, a review or a question in the `<name>` repository. Triggers: `<name>`, <the kinds of work done
there>, <the file types or folders that mean this repo>.

## CRAFT GUIDANCE
**What the repository is for:** <one or two sentences: what it builds or runs, and for whom>.

**Layout:** <the folders that matter and what lives in each; where a new model, job, test or config goes>.

**How a change is made here:**
1. <Branch naming and where to branch from.>
2. <Where the change goes, and the pattern to copy.>
3. <How to test it locally, and what "passing" looks like.>
4. <How it is delivered: PR, checks, environments, who approves.> Link the delivery runbook
   (`General Human Knowledge/Repo Workflows/<runbook>.md`) with a relative link; do not repeat its steps.

**Conventions a reviewer expects:** <naming, where configuration lives instead of code, what is shared and
must not be duplicated, the tests every change needs>.

**Prefer the existing mechanism:** <the framework features, shared helpers and declarative options this
repository already has, and what each is for, so a change uses them instead of new code>.

**Traps:** <the mistakes that have cost time here, each with how to avoid it>.

**Pipelines hosted here:** <links to the pipeline pages; one line each on what differs>.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). TOOLS ADVISE, NEVER GATE.

- `<tool> <exact invocation>` — <what it does here; what to do if the tool is absent>

Last reviewed: YYYY-MM-DD
