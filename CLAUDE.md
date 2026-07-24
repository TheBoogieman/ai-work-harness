# CLAUDE.md — instructions for an AI working on this repository

> **⚠️ DEVELOPMENT-REPO INSTRUCTIONS ONLY — this file is DEV, it never ships to a
> work estate.** It is classified DEV in `.github/ship-manifest.txt` and the
> installer never lays it down. If you are reading this on an installed Work
> estate, the install was WRONG: this file describes how to develop the harness
> (branches, PRs, CI) and directly contradicts an estate's law (no remote ever).
> Delete it from the estate and re-install with `install.sh`, which ships PRODUCT
> files only.

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
- Branch grammar + PR anchor (enforced at the merge gate by
  `.github/workflows/governance.yml`, #47 + #49): a merging branch must match
  `^[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$` (leading issue number + lowercase-kebab slug, e.g.
  `47-governance-pair`; no exception prefix) and its leading number must be among the
  PR's `Fixes #NN` set. Every PR body must carry a closing reference
  (`Fixes`/`Closes`/`Resolves #NN`) to a real, OPEN issue. Local branch names stay free;
  the gate is the law. The grammar's one editable home is
  `.github/scripts/branch-grammar.sh` — these checks never ship to a user's estate (#43).
  See `.github/CONTRIBUTING.md` for the contributor-facing version.
- Before pushing, self-check: the demo passes, the commit is scoped to one
  concern, and every claim you wrote (including in comments) is true at HEAD.

## Hard rules for changing this codebase
- Every bug fix ships with a regression guard that provably FAILS on the
  pre-fix code (prove it by reverting the fix and watching the guard go red).
  No bug is "fixed" without one. (Project rule "G5".)
- Every claim in README and the constitution must be true at HEAD
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
- Diagram ownership (STANDING LAW, #42, binds every wave): the SVG diagram FILES
  in `General AI-Knowledge/AI Harness/` are OPERATOR-owned and maintained by
  hand — NO WAVE EVER EDITS AN SVG. A wave's only diagram duty is the DESIGN.md
  currency note: when a change touches machinery the sheets depict, update that
  note to name the divergence (honest lag), and the operator redraws on their own
  schedule. README embeds NO diagrams — one pointer to the folder, no more. The
  docs check (.github/scripts/docs-check.sh) enforces both: a machinery change
  with no DESIGN.md note (and no `[diagrams-unaffected: reason]` in the PR body)
  reds, and any `.svg` reference re-entering README reds.

## Cross-platform
This runs on Linux, macOS, and Windows. The canonical DEVELOPMENT lane is a
NATIVE WINDOWS checkout — VS Code on Windows with the agent extension, all shell
work in the integrated Git-Bash/Cygwin bash (the MSYS-path/Windows-Store-Python
hooks-parse issue that once made Git Bash fragile is fixed, #8). Agents working on
THIS repo execute shell via that native integrated bash, NOT WSL. Linux and macOS
remain the STANDING fully-tested lanes via CI (the demo runs on ubuntu-latest +
macos-latest on every push to `main` and every PR into `main`), so a change is
proven on both before it merges; a windows-latest MSYS job witnesses the Windows
lane informationally (non-gating). WSL is used ONLY as ephemeral verification
(fresh clone → run → discard), never a standing copy; plain PowerShell runs git
only, not the bash machinery.
Write portably — no GNU-only flags without a BSD/macOS fallback. Verify on the
platform where a fix's failure mode can actually occur.

## Environment (native Windows)
The canonical dev seat is a native-Windows checkout driven through Git-Bash/Cygwin
bash, where the demo runs fully. Line endings come FIRST: set
`git config core.autocrlf input` at clone so tracked scripts stay LF in the
working tree; `.gitattributes` pins `*.sh`/`*.py` to LF as the permanent backstop,
and the demo's CRLF tripwire reds if any tracked script ever carries a carriage
return. Requirements: node/npm, claude-code (or your agent tool), `python3` with
`nbformat` (the notebook helper needs it: `pip install nbformat`), and `unzip`
(`zip` optional — `make_context_pack` falls back to Python's zipfile). Git push
works over HTTPS via `gh auth`. `gh` is a **development** convenience only — used
for pushing and issue management while working on the harness. NO shipped harness
component (validation, status, the git safety net, agents, hooks) depends on
`gh`; the harness runs fully on a host without it.

The UNSUPPORTED anti-pattern is a Windows-DRIVE checkout accessed THROUGH WSL (a
`C:\…` path under `/mnt/c`): slow cross-boundary I/O and unreliable executable
bits. If you need a Linux witness, clone fresh inside the WSL filesystem (`~/…`,
never `/mnt/c`), run the demo, and discard it — WSL is verification, not a home.

## Porting to another AI assistant (the vendor seam)

The harness is coupled to GitHub Copilot at exactly **three** thin, isolated
points. Everything else — the doctrine, the bash/python machinery, the git
safety net, the validation model, the ticket states, context packs — is
assistant-agnostic and works with any AI coding tool. (This repo is in fact
developed using Claude Code, not Copilot, which exercises that portability.)
The three Copilot-specific pieces:

1. **`_agents/*.agent.md`** (seven files) use Copilot's agent format —
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
- _agents/ — the seven Copilot agent contracts.
- _harness/scripts/run_demo.sh — the 6-stage acceptance demo; the truth-teller
  for any change.
