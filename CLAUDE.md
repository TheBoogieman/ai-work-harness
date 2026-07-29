# CLAUDE.md — instructions for an AI working on this repository

> **⚠️ DEVELOPMENT-REPO INSTRUCTIONS ONLY — this file is DEV, it never ships to a
> work estate.** It sits outside the `estate/` tree, which is what the installer
> derives the shipped set from, so it is never laid down. If you are reading this on an installed Work
> estate, the install was WRONG: this file describes how to develop the harness
> (branches, PRs, CI) and directly contradicts an estate's law (no remote ever).
> Delete it from the estate and re-install with `estate/install.sh`, which ships PRODUCT
> files only.

This file is for an AI assistant (e.g. Claude Code) developing the
ai-work-harness project itself. It is NOT the harness's user-facing rules —
those live in estate/CONSTITUTION.md (the constitution). Read that too when a
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
- Comment every code change in plain English. That rule's one home — its full
  statement, the reason it exists, and what enforces it — is PLAIN-ENGLISH
  COMMENTS under "Hard rules" below; it is not restated here.
- Run the demo — `bash dev/scripts/run-demo.sh` — for every BEHAVIOUR CHANGE
  TO SHIPPED MACHINERY. It must end with "ALL 6 DEMO STAGES PASSED"; it is the
  truth-teller for such a change and nothing here weakens that. (Stage 5
  deliberately breaks and restores a deployment — an internal FAIL followed by
  "healthy after fix" is that stage working, not a failure.) Which changes fall
  OUTSIDE that class is written in exactly one place: the exempt classes of the
  guard-per-bug rule under "Hard rules" below. Its first three exemptions are
  classes of change, they are precisely the changes that are not behaviour
  changes to shipped machinery, and they do not require the full run — a rename
  or move still owes that rule's byte-identical-output proof, which is how you
  know it was one. Its fourth exemption is a coverage condition, not a class of
  change: an existing guard already catching a defect excuses writing a NEW
  guard, never the demo — the demo is where that guard is SHOWN failing. That
  list is not repeated here, and this loop is not repeated in README; README
  points at this file.
- Branch workflow — never commit to `main` directly (a direct push is rejected). Per
  change: branch from the issue (`NN-slug`), commit (behaviour and docs in SEPARATE
  commits), run the demo, then push the BRANCH (branch pushes are safe; `main` is
  protected). Open a PR that closes the issue (`Fixes #NN`). Opening or updating the PR
  REPORTS the demo workflow's two lanes (`.github/workflows/demo.yml`, Linux + macOS);
  both must be green before merge (enforced as required status checks on `main`), and the
  CI run URL is the release evidence. A green lane is NOT proof the demo ran: the job
  always reports, but skips its body on changes that cannot move its verdict — read the
  run log and say which of the two happened. Which changes skip its body is decided in
  `.github/workflows/demo.yml` itself. THE DOCUMENTATION CHECK IS THE EXCEPTION: it is a
  step in the same job's Linux leg and is NEVER skipped, so a green `demo (ubuntu-latest)`
  always means the four detectors ran and passed, whatever the demo's own body did.
  STOP at the PR — do not merge; the operator merges once CI is green. A red lane means
  that lane failed; read it — the demo is the truth-teller.
- Branch grammar + PR anchor — a CONVENTION now, not a gate (#281 removed the workflow
  that enforced it, along with the docs, shell-lint and Windows-witness workflows). A
  branch should still match `^[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$` (leading issue number +
  lowercase-kebab slug, e.g. `281-the-great-cut`) with its leading number among the PR's
  `Fixes #NN` set, and every PR body should still carry a closing reference
  (`Fixes`/`Closes`/`Resolves #NN`) to a real, OPEN issue. The regex above IS the pattern
  — the four scripts that used to hold and enforce it went with their workflow, so this
  line is its only home. What keeps it now is review.
- Before pushing, self-check: the demo passes, the commit is scoped to one
  concern, and every claim you wrote (including in comments) is true at HEAD.

## Hard rules for changing this codebase

### The four standing rules

Four rules bind every change to this repository. This section is their ONE home:
each carries a descriptive name, its full statement, the reason it exists, and
the instrument that enforces it — so a rule can be obeyed from this file, with no
tag to look up somewhere else. Where the instrument is a person rather than a
script, that is said plainly: an honest "no detector yet" is worth more than an
enforcement claim the repository cannot cash.

**CLAIMS-TRUTH — nothing false at HEAD ships.**
- *Statement.* Every claim in README and the constitution must be true at HEAD
  or removed. A code comment is a claim too — a comment that misdescribes the
  code it sits over is a defect, and gets fixed like one rather than left as a
  stale note.
- *Why it exists.* What this repository builds is a record a human trusts
  without having been in the room, and the same standard binds the repository's
  own documents. A document that is right about most things is worse than one
  that is silent: it teaches its reader to stop checking.
- *What enforces it.* Two things, and the split is worth knowing. FOUR DETECTORS RUN IN
  CI, as a step inside the demo job on the Linux leg (`.github/workflows/demo.yml`) —
  broken intra-repo links, unbalanced code fences, carriage returns in documents, dead
  pointers. They are the four that catch what a READER hits, they run on every pull
  request regardless of what it touched, and a red one FAILS THE JOB, so `demo
  (ubuntu-latest)` is red until it is fixed. #281 cut the other seventeen, which policed
  internal doctrine. EVERY OTHER CLAIM rests on review and on the pre-push self-check —
  no script judges an arbitrary sentence. Run `bash dev/scripts/docs-check.sh` before you
  push if you want the answer early; CI will run it either way.

**GUARD-PER-BUG — a fix is finished when a guard has been WATCHED failing.**
- *Statement.* A guard is required for a behaviour change to shipped machinery
  that no existing guard already catches — a regression guard that provably
  FAILS on the pre-fix code (prove it by reverting the fix and watching the
  guard go red). No such change is "fixed" without one. FOUR EXEMPTIONS, and no
  others: (1) documentation and prose, (2) comment-only passes, (3) pure renames
  and moves — the three CLASSES OF CHANGE that are not behaviour changes to
  shipped machinery — and (4) a defect an existing guard already catches, which
  is not a class of change but a coverage condition inside the machinery class.
  This list is the ONE home for those classes — nothing else in the repo
  restates them; a rule that needs them cites this list. Two of the four would
  self-certify without a proof, so each owes one: "pure rename or move" is a
  claim, not a fact — the proof is BYTE-IDENTICAL OUTPUT (a change that alters a
  printed string can never produce it); "an existing guard already catches it"
  is never asserted — that guard is SHOWN failing against the pre-fix code.
- *Why it exists.* A guard that has never been run to failure is
  indistinguishable from a guard that CANNOT fail, because green is what both
  look like from the outside; only an executed red tells them apart. (The decision
  records that carried the longer reasoning were deleted by #281; the rule as stated
  above is now its own whole statement.)
- *What enforces it.* The acceptance demo, `dev/scripts/run-demo.sh`, is
  where a guard lives and where it is shown failing. CI runs it on Linux and
  macOS as two required checks, and both must be green before a merge.

**PUBLIC-SURFACE PRIVACY — no work context reaches a public surface.**
- *Statement.* Never put work-context identifiers (employer, internal workspace
  names, board keys, internal IDs) in repo files, issue text, or commit
  messages. Generic language only.
- *Why it exists.* This repository is public and its history is permanent. An
  employer name or a real board key committed once is not removed by editing the
  file afterwards, so this rule has to hold BEFORE the commit — there is no
  version of it that can be applied late.
- *What enforces it.* No detector — a human, at the pre-push self-check and at
  review. That gap is stated rather than papered over: nothing mechanical here
  can tell a generic example from a real one. What the repository does instead
  is remove the occasions — the development fixtures are generic by construction
  (`dev/scripts/make-scratch-estate.sh` builds its scratch estate from the
  shipped template ticket, carrying no real board key), so an author who wants a
  realistic example already has one that costs nothing to use.

**PLAIN-ENGLISH COMMENTS — a code change says WHAT it does and WHY.**
- *Statement.* Comment every CODE change in plain English — WHAT it does and
  WHY, not a restatement of syntax. This applies to bash/python and
  hooks.example.json. Agent `.md` files and the constitution are prose and are
  exempt from line-comments, but must stay clear.
- *Why it exists.* WHAT and WHY are the parts of a change a diff cannot recover
  on its own; a comment that restates the syntax costs a line and returns
  nothing. The next reader here is routinely an assistant with no memory of the
  session that wrote the code, and it acts on what the comment says.
- *What enforces it.* No detector — review, and the pre-push self-check. The two
  checks that used to constrain the code a comment sits over (shellcheck and
  code-shape) were removed by #281, so nothing mechanical is left here at all.

### The other standing obligations
- Comment-only passes commit SEPARATELY from behaviour changes.
- Keep commits focused — one concern each — and messages honest (the message
  must describe what the diff actually does).
- Public text — repo files, code comments, output strings, commit messages,
  and issue text — cites only immutable identifiers: GitHub issue numbers and
  commit hashes. NEVER internal or ephemeral labels (wave/milestone tags like
  "M1"/"W3"/"004a", or review-finding tags like "R-09") — they drift, and mean
  nothing (or something different) to a later reader; a finding that needs a
  durable public reference gets a GitHub issue number. These instructions name
  those retired tags so they stay decodable: the commit messages and issue text
  carrying them can never be rewritten, so a reader doing archaeology needs
  somewhere to meet them. Naming them here is a dictionary, not a licence —
  this rule still governs every NEW public reference.
- The ticket-recognition pattern lives in ONE home
  (estate/_harness/scripts/ticket-grammar.sh), sourced by both the validator and
  status. Never duplicate it — an edit there must move both tools.
- Diagram ownership (STANDING LAW, #42, binds every wave): the SVG diagram FILES
  in `estate/General AI-Knowledge/AI Harness/` are OPERATOR-owned and maintained by
  hand — NO WAVE EVER EDITS AN SVG. A wave's only diagram duty is the DESIGN.md
  currency note: when a change touches machinery the sheets depict, update that
  note to name the divergence (honest lag), and the operator redraws on their own
  schedule. README embeds NO diagrams — one pointer to the folder, no more. Both
  halves used to be enforced by the docs check; #281 removed those detectors, so
  this is now kept by the author and by review.

## Cross-platform
This runs on Linux, macOS, and Windows. The canonical DEVELOPMENT lane is a
NATIVE WINDOWS checkout — VS Code on Windows with the agent extension, all shell
work in the integrated Git-Bash/Cygwin bash (the MSYS-path/Windows-Store-Python
hooks-parse issue that once made Git Bash fragile is fixed, #8). Agents working on
THIS repo execute shell via that native integrated bash, NOT WSL. Linux and macOS
remain the STANDING fully-tested lanes via CI (the demo runs on ubuntu-latest +
macos-latest on every push to `main`, and on a pull request whose changes could
move its verdict — `.github/workflows/demo.yml` decides which), so a machinery
change is proven on both before it merges. THE WINDOWS WITNESS JOB IS GONE (#281):
the Windows lane is now verified only by a hand-run on this seat, which is the
documented development lane anyway. WSL is used ONLY as
ephemeral verification (fresh clone → run → discard), never a standing copy;
plain PowerShell runs git only, not the bash machinery.
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
(`zip` optional — `make-context-pack` falls back to Python's zipfile). Git push
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

1. **`estate/_agents/*.agent.md`** (one file per agent) use Copilot's agent format —
   frontmatter like `user-invocable` and `tools`. The instruction *content* is
   portable; only the wrapper format is Copilot-specific.
2. **`estate/_harness/hooks/hooks.example.json`** uses Copilot's `postToolUse` hook
   format to fire the auto-commit on file writes. Another assistant's hook
   system would use a different config shape.
3. **`estate/_harness/scripts/deploy-agents.sh`** targets the Copilot agents directory
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
- estate/CONSTITUTION.md — the constitution (harness rules for the user's work;
  Part I always-load, Part II on-demand).
- estate/_harness/scripts/ — the machinery (validator, status, context-pack, demo,
  deploy, notebook helper, and the ticket-grammar home).
- estate/_agents/ — the Copilot agent contracts.
- dev/scripts/run-demo.sh — the 6-stage acceptance demo; the truth-teller
  for the shipped product, and now the ONLY required check on a merge. WHICH
  changes must run it is stated once, under "Working on this harness" above — it is
  not every change. It is the RUNNER of a suite split three ways (#143): it owns the
  shared estate and the stage ORDER, `dev/demo/tour.sh` is the stage-based tour a
  person watches, and `dev/demo/cases/*.case.sh` is one case file per guard family —
  where every named guard lives. A new guard goes in the case file for its family (or
  a new one), and a NEW case file must be added to `demo_order()` in the runner;
  the runner's `[case-completeness]` check reds by name if it is not.
- dev/scripts/docs-check.sh — the four documentation detectors (#281). CI runs it as a
  step in the demo job's Linux leg, unconditionally; a red fails that lane.
