# Doc-Repo-Workflow — SKILL.md

## WHEN TO USE
Creating or correcting a repository's delivery runbook: how a change travels from a laptop to PROD in that
repo (branching, local build and test, PR and review, environment promotion, deploy, verify, recovery, traps).
Triggers: repo workflow, runbook, delivery guide, how to deploy this repo, correct the runbook, workflow drift.

## CRAFT GUIDANCE
**Kind:** living, human-facing reference under `General Human Knowledge/Repo Workflows/`, corrected in place.
**Destination:** the existing owner for the repo (`Repo Workflows/<date>-<repo>.md`); create one only when no
file owns the repo. Register a new runbook in `Repo Workflows/_index.md` and
note every correction there so it is visible, then make sure the repo card in `Work Map/Repos/<repo>.md` links it.
**Frontmatter (CONSTITUTION §9.2):** the runbook opens with `repos` naming the repo card it delivers into, in a
block above its first line (`---`, `repos:`, `  - <repo>`, `---`). No YAML comments.

**Shape (match the existing runbooks):** what the repo does · why it is separate · what "finished" looks like ·
how a change travels (diagram) · Step 1 pick up the work · Step 2 build and test locally · Step 3 build the
artefact (when there is one) · per environment: deploy, activate, prove · recovery · reference (where to click,
traps, checked against).

**Rules.**
- The runbook owns HOW to deliver in the repo; pipeline-specific values (app names, DAG ids, buckets, tables)
  belong to pipeline pages under `General AI-Knowledge/Work Map/Pipelines/` — add a "Pipelines in this repo"
  list linking them instead of copying their facts.
- Commands are exact and copy-pasteable, with placeholders in `<angle brackets>` and every flag explained.
- Say what each step was checked against (repo ref, workflow file, date). Unverified steps are labelled.
- A merged duplicate note leaves a one-line "Moved →" stub only where a dated record still links it.

**Sources to mine, in order:** the existing runbook; the repo's README, Makefile, CI workflow files and deploy
scripts on the remote default branch; recent tickets' Changes Made and `Agent-Output/` build/deploy outputs;
the repo card and pipeline pages.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate; repository-required
tests, CI, security and release checks still apply. Tool absence is not a passing check.

- `git -C <repo> show origin/<default>:.github/workflows/<file>` — the real CI and deploy entry points.
- `gh workflow list --repo <owner/repo>` / `gh workflow view <name>` — workflow names and inputs (read-only).

Last reviewed: 2026-10-30
