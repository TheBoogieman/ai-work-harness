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

## Working on this harness
- Make the change that's asked for; don't invent scope. If it seems to need
  reading or editing a file that wasn't named, flag that before doing it.
- Comment every CODE change in plain English — WHAT it does and WHY, not a
  restatement of syntax (project rule "G7"). This applies to bash/python and
  hooks.example.json. Agent .md files and the constitution are prose and are
  exempt from line-comments but must stay clear.
- Run the demo: `bash _harness/scripts/run_demo.sh`. It must end with
  "ALL 6 DEMO STAGES PASSED" — it is the truth-teller for any change. (Stage 5
  deliberately breaks and restores a deployment — an internal FAIL followed by
  "healthy after fix" is that stage working, not a failure.)
- Branch workflow — never commit to `main` directly (a direct push is rejected). Per
  change: branch from the issue (`NN-slug`), commit (behaviour and docs in SEPARATE
  commits), run the demo, then push the BRANCH (branch pushes are safe; `main` is
  protected). Open a PR that closes the issue (`Fixes #NN`). Opening or updating the PR
  runs the demo workflow (`.github/workflows/demo.yml`) on Linux + macOS; both lanes
  must be green before merge (enforced as required status checks on `main`), and the CI
  run URL is the release evidence. STOP at the PR — do not merge; the operator merges
  once CI is green. A red lane means that lane failed; read it — the demo is the
  truth-teller.
- Before pushing, self-check: the demo passes, the commit is scoped to one
  concern, and every claim you wrote (including in comments) is true at HEAD.

## Hard rules for changing this codebase
- Every bug fix ships with a regression guard that provably FAILS on the
  pre-fix code (prove it by reverting the fix and watching the guard go red).
  No bug is "fixed" without one. (Project rule "G5".)
- Every claim in README, the constitution, and INSTALL must be true at HEAD
  or removed. A code comment is a claim too — a comment that misdescribes the
  code is a defect. (Project rule "G4".)
- Comment-only passes commit SEPARATELY from behaviour changes.
- Keep commits focused — one concern each — and messages honest (the message
  must describe what the diff actually does).
- Public text — repo files, code comments, output strings, commit messages,
  and issue text — cites only immutable identifiers: GitHub issue numbers and
  commit hashes. NEVER internal or ephemeral labels (wave/milestone tags like
  "M1"/"W3"/"004a", or transient review/finding numbers) — they drift, and mean
  nothing (or something different) to a later reader; a finding that needs a
  durable public reference gets a GitHub issue number. (The existing
  `[R-09]`-style guard labels already baked into the demo are internal, stable
  test names — leave them; this rule governs NEW public references to findings.)
- Public-surface privacy: never put work-context identifiers (employer,
  internal workspace names, board keys, internal IDs) in repo files, issue
  text, or commit messages. Generic language only. (Project rule "G6".)
- The ticket-recognition pattern lives in ONE home
  (_harness/scripts/ticket-grammar.sh), sourced by both the validator and
  status. Never duplicate it — an edit there must move both tools.

## Cross-platform
This runs on Linux, macOS, and Windows. Windows support is lane-specific: WSL
is fully supported (develop here); Git Bash is best-effort — the previously-known
MSYS-path/Windows-Store-Python hooks-parse issue is fixed (#8); plain PowerShell runs
git only, not the bash machinery. Linux and macOS are the fully-tested lanes: CI runs
the demo on both on every push to `main` and every PR into `main`, so a change is proven
on both before it merges.
Write portably — no GNU-only flags without a BSD/macOS fallback. Verify on the
platform where a fix's failure mode can actually occur.

## Environment (WSL)
Real Linux, so the demo runs fully. Requirements already installed: node/npm,
claude-code, `unzip` (and `zip`; `zip` is optional — `make_context_pack` falls
back to Python's zipfile), and the `nbformat` python package (the notebook helper
needs it: `pip install nbformat --break-system-packages`). Git push works over
HTTPS via `gh auth`. `gh` is a **development** convenience only — used for
pushing and issue management while working on the harness. NO shipped harness
component (validation, status, the git safety net, agents, hooks) depends on
`gh`; the harness runs fully on a host without it.

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
