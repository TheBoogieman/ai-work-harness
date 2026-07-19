# CLAUDE.md — instructions for an AI working on this repository

This file is for an AI assistant (e.g. Claude Code) developing the
ai-work-harness project itself. It is NOT the harness's user-facing rules —
those live in folder-structure.md (the constitution). Read that too when a
change touches harness behaviour.

## What this project is
A local-first "work harness" that turns an AI coding assistant into a
disciplined colleague. Core pattern at every layer: a file states the rule →
the agent does the work → a hook catches the miss → git undoes the damage.
Doctrine you must never violate when changing this code:
- Red blocks, yellow schedules. Nothing self-heals — a fixed record is a
  human act. Never fabricate a record. Late-but-true beats fiction.
- Surface, don't impose: recommend conventions, never force them on users.
  The one exception is the harness's own internal controlled paths.

## How development is organised (the three roles)
- Architect: a separate Claude chat that holds the plan, writes wave specs,
  and verifies results. It hands specs to you via the operator (paste).
- Implementer: YOU (Claude Code, running in WSL in this repo). You apply the
  spec's exact edits, run the demo, commit, and — after the architect
  verifies your report — push.
- Reviewer / Product Owner: a separate Claude chat that audits and sets goals.
  You do not act on its output directly; the architect turns it into specs.

## The working loop (follow this every wave)
1. The operator pastes a spec from the architect.
2. Apply exactly what the spec names. Do not invent scope. If a spec seems to
   require reading or changing files it didn't name, say so before doing it.
3. Comment every CODE change in plain English — WHAT it does and WHY, not a
   restatement of syntax (project rule "G7"). This applies to bash/python and
   hooks.example.json. Agent .md files and the constitution are prose and are
   exempt from line-comments but must stay clear.
4. Run the demo: `bash _harness/scripts/run_demo.sh`. It must end with
   "ALL 6 DEMO STAGES PASSED". (Stage 5 deliberately breaks and restores a
   deployment — an internal FAIL followed by "healthy after fix" is that
   stage working, not a failure.)
5. STOP and report before pushing. The architect verifies your report first.
   Report: commit hashes + messages, `git diff --stat`, the demo's final
   line, and any judgment calls you made.
6. Push only when the architect releases the push step.

## Hard rules for changing this codebase
- Every bug fix ships with a regression guard that provably FAILS on the
  pre-fix code (prove it by reverting the fix and watching the guard go red).
  No bug is "fixed" without one. (Project rule "G5".)
- Every claim in README, the constitution, and INSTALL must be true at HEAD
  or removed. A code comment is a claim too — a comment that misdescribes the
  code is a defect. (Project rule "G4".)
- Comment-only passes commit SEPARATELY from behaviour changes.
- One wave, one concern. Keep commits focused; keep messages honest (the
  message must describe what the diff actually does).
- Public text — repo files, code comments, output strings, commit messages,
  and issue text — cites only immutable identifiers: R-IDs (R-09, etc.),
  GitHub issue numbers, and commit hashes. NEVER internal wave/milestone
  labels (like "M1", "W3", "004a") — those are private development
  choreography that drift and mean nothing to someone reading the repo later.
- Public-surface privacy: never put work-context identifiers (employer,
  internal workspace names, board keys, internal IDs) in repo files, issue
  text, or commit messages. Generic language only. (Project rule "G6".)
- The ticket-recognition pattern lives in ONE home
  (_harness/scripts/ticket-grammar.sh), sourced by both the validator and
  status. Never duplicate it — an edit there must move both tools.

## Cross-platform
This runs on Linux, macOS, and Windows. Windows support is lane-specific: WSL
is fully supported (develop here); Git Bash is best-effort (a known MSYS-path
+ Windows Store Python issue affects it); plain PowerShell runs git only, not
the bash machinery. Write portably — no GNU-only flags without a BSD/macOS
fallback. Verify on the platform where a fix's failure mode can actually
occur.

## Environment (WSL)
Real Linux, so the demo runs fully. Requirements already installed: node/npm,
claude-code, zip, and the `nbformat` python package (the notebook helper needs
it: `pip install nbformat --break-system-packages`). Git push works over
HTTPS via `gh auth`.

## Porting to another AI assistant (the vendor seam)

The harness is coupled to GitHub Copilot at exactly **three** thin, isolated
points. Everything else — the doctrine, the bash/python machinery, the git
safety net, the validation model, the ticket states, context packs — is
assistant-agnostic and works with any AI coding tool. (This repo is in fact
developed using Claude Code, not Copilot, which exercises that portability.)
The three Copilot-specific pieces:

1. **`_agents/*.agent.md`** (six files) use Copilot's agent format —
   frontmatter like `user-invocable` and `tools`. The instruction *content* is
   portable; only the wrapper format is Copilot-specific.
2. **`_harness/hooks/hooks.example.json`** uses Copilot's `postToolUse` hook
   format to fire the auto-commit on file writes. Another assistant's hook
   system would use a different config shape.
3. **`_harness/scripts/deploy_agents.sh`** targets the Copilot agents directory
   (`~/.copilot/agents`).

Porting to another assistant means translating these three — mechanical work,
not redesign; the ~90% of value above this line carries over untouched.

**FUTURE (not built yet):** an `ADAPTERS/` layer would formalise this — one
subdirectory per assistant (`copilot/`, `claude-code/`, …) holding that
assistant's agent-format files, hook config, and deploy target, with the
portable core referencing whichever adapter is active. This is deliberately
**not** implemented yet (YAGNI until multi-assistant support is actually
wanted); this note is the marker so the design intent isn't lost. Revisit once
the issue board is clear and the project is self-contained.

## Where to look
- folder-structure.md — the constitution (harness rules for the user's work;
  Part I always-load, Part II on-demand).
- _harness/scripts/ — the machinery (validator, status, context-pack, demo,
  deploy, notebook helper, and the ticket-grammar home).
- _agents/ — the six Copilot agent contracts.
- _harness/scripts/run_demo.sh — the 6-stage acceptance demo; the truth-teller
  for any change.
