# INSTALL — the flat-pack instructions

Parts: this repo. Tools: GitHub Copilot (agents + hooks support), Python 3.12,
git. Time: ~30 minutes.

## 0. Prerequisite — `venv_global` (you create this; the harness never does)
    python3.12 -m venv ~/venvs/venv_global   # 3.12 is the assumed version; a newer python3 works for the scripts
    source ~/venvs/venv_global/bin/activate && pip install nbformat  # + your toolchain (dbt etc.)
Register its Jupyter kernel and set it as your workspace default interpreter.
`pip install` works directly INSIDE the activated venv. If instead you install
`nbformat` into a **system** Python, modern distros (PEP 668) require
`pip install nbformat --break-system-packages`.

## 1. Run the installer
    bash install.sh /path/to/your/Work
`install.sh` is a non-destructive **dumb creator**: it lays down PRODUCT files
only (per `.github/ship-manifest.txt` — a fresh estate has **zero** dev files),
scaffolds any absent ticket anatomy, initialises a whitelist-scoped,
**local-only** git repo with a day-zero commit, copies the verified hook config
to `.github/hooks/harness.json`, deploys the agents, and runs the validator +
status. It **never edits an existing file** — a re-run finds nothing absent and
says "nothing to do".

It asks for your **board key** (offering the documented grammar-widening if your
board key contains a hyphen) and **model pins** — press Enter to accept each
suggested default; on a re-run it offers the ESTABLISHED values so you can
review and Enter-through, and a changed answer is warned-and-routed, never
applied (the installer edits nothing that pre-exists). Flags: `--dry-run` prints the full plan
and touches nothing; `--yes` accepts every default non-interactively. Read the
closing **SUMMARY** — it records every choice and every tunable knob with its
default and its one env-var home.

> **Hook activation caveat (honest — what was actually seen, not the wish).**
> The hook schema is *witnessed firing* on the VS Code Copilot IDE agent
> (v1.129.1, 2026-07-20) on an **established, trusted** workspace. On a
> **freshly-created** workspace, `postToolUse` did **not** auto-fire immediately
> in testing — even after trusting the folder and reloading. The exact
> fresh-estate activation trigger is not fully characterised: trust the folder,
> and expect a first real session or a Copilot restart may be needed. The git
> safety net is the backstop — if a write wasn't auto-committed, commit it by
> hand; nothing in the record depends on the hook firing. (CLI and cloud Copilot
> surfaces are UNVERIFIED — their schema may differ.)

## 2. Final gate — hand the estate to your AI assistant
Paste the prompt in **`setup.md`** into your AI assistant of choice, working in
the new estate. It is the last step and the **final validation gate**: the
assistant reads what the installer established, confirms the validator + status
are green, spot-checks the scaffolded tickets, walks you through the
personalisation the installer left to you (any model pin still `PICK-A-*`, the
`LICENSE` name, the `make_context_pack.sh` scrub-table seeds, the
`folder-structure.md` Owner/key-repos lines), does the live hook-fire check, and
nudges you to fix anything red — on the record.

## 7. Daily use
New ticket: pick **ticket-init** in Copilot, paste the issue link, answer
three questions. Work normally. Walk away — nothing must fire. Full
choreography: Sheet 2 in `General AI-Knowledge/AI Harness/`. Doctrine:
**red blocks, yellow schedules, never fabricate.**

**Maintenance:** monthly, or whenever `harness-status` warns that `.git` is
large, run `bash _harness/scripts/harness-housekeeping.sh` (repacks history;
touches no records).
