# INSTALL — the flat-pack instructions

Parts: this repo. Tools: GitHub Copilot (agents + hooks support), Python 3.12,
git. Time: ~30 minutes.

## 0. Prerequisite — `venv_global` (you create this; the harness never does)
    python3.12 -m venv ~/venvs/venv_global   # 3.12 is the assumed version; a newer python3 works for the scripts
    source ~/venvs/venv_global/bin/activate && pip install nbformat  # + your toolchain (dbt etc.)
Register its Jupyter kernel and set it as your workspace default interpreter.
`pip install` works directly INSIDE the activated venv. If instead you install
`nbformat` into a **system** Python, modern distros (PEP 668) require
`pip install nbformat --break-system-packages` — as CLAUDE.md's environment note shows.

## 1. Place the workspace
Clone into (or copy over) your work root so `folder-structure.md` sits at the
top — the harness self-anchors: **the Work root is the directory containing
that file.** Keep your real code checkouts under `GitHub/` (gitignored here;
this repo never touches them).

## 2. Personalise (5 minutes)
- `folder-structure.md`: Owner line; your board key (replace `PROJ`); your
  key-repos list.
- `_agents/*.agent.md`: replace `PICK-A-CHEAP-MODEL` / `PICK-A-SONNET-CLASS-MODEL`
  with real model IDs enabled in YOUR Copilot org (scalar strings only —
  arrays break the CLI loader).
- `LICENSE`: your name.
- `_harness/scripts/make_context_pack.sh`: seed the SCRUB table with your
  identifier classes (employee ID, org domains, cloud account IDs).

## 3. Git safety net
    git init && git add -A && git commit -m "harness: day zero"
Verify `git status` shows ONLY the record set (whitelist `.gitignore` does
this). Never add a remote to this repo — publish a SANITISED copy separately
if you want one (that is what this repo is).

## 4. Deploy agents
    _harness/scripts/deploy_agents.sh
Verify all six appear in your Copilot agent picker. Discovery directory is
preview-grade: override with `HARNESS_AGENT_DEPLOY_DIR` if yours differs.

## 5. Hooks
`_harness/hooks/hooks.example.json` encodes the design (validate on
sessionStart, commit on postToolUse, sessionEnd = bonus). **Verify event
names, config location, and payload fields against your Copilot version's
docs** — schemas differ across CLI/VS Code and change often — then install.

## 6. Acceptance test (do not skip)
1. `_harness/scripts/check_ticket_log.sh` → validates the template (OK); re-run → vacuous pass.
2. Copy the template to a scratch ticket, edit its `.md`, re-run → OK + stamped.
3. Delete an index line for a knowledge file → re-run → FAIL with a working fix.
4. `_harness/scripts/harness-status.sh` → zero FAILs; rename one deployed
   agent → FAIL with fix; restore.
5. `_harness/scripts/make_context_pack.sh --ticket <scratch>` → zip on your
   Desktop; MANIFEST reads "self-audit: zero scrub-table hits".
6. Delete the scratch ticket; commit.

## 7. Daily use
New ticket: pick **ticket-init** in Copilot, paste the issue link, answer
three questions. Work normally. Walk away — nothing must fire. Full
choreography: Sheet 2 in `General AI-Knowledge/AI Harness/`. Doctrine:
**red blocks, yellow schedules, never fabricate.**
