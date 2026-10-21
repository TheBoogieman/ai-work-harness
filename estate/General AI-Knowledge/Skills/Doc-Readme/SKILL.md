# Doc-Readme — SKILL.md

## WHEN TO USE
Drafting or refreshing a repository or module README. Triggers: README, module readme, project readme,
getting started section.

## CRAFT GUIDANCE
**Kind:** draft only unless the user explicitly asks for a local edit in a repo; the human (or an implementer
prompt) commits it. **Destination:** the repo's own README path, on the ticket's branch.

**Shape:** what it is (one paragraph) · how to run it locally · how to test · how it is deployed (link the
runbook rather than duplicating it) · configuration · where to get help. Keep commands copy-pasteable with
placeholders.

**Rules:** component-first and concrete; no work identifiers, secrets or customer data in anything public;
link the pipeline page or runbook in the estate only from estate documents, not from the repo.

**Sources to mine:** the repo's existing README, Makefile, CI workflows and config on the remote default
branch; the repo's runbook under `General Human Knowledge/Repo Workflows/`.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). The harness adds no craft-quality gate.

- `git -C <repo> show origin/<default>:README.md` — the current README on the default branch.

Last reviewed: 2026-10-20
