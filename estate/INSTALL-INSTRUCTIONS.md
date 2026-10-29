# Installing the harness

**This page is the one home for every install command, prerequisite and
caveat.** The front page (`README.md`) links here and repeats none of them: two
install documents drift apart, which is the exact failure an earlier
consolidation was made to end. The command registry that once enforced that
mechanically was removed with the rest of the doctrine detectors (#281), so the
separation is now kept by review — if you add a command here, it stays here.

The harness installs onto a **work estate** — a local folder it turns into a
disciplined, record-keeping workspace. Two steps: prove the machinery runs on
your machine (the demo — no AI assistant needed), then lay down the estate and
wire your assistant.

**1 · Prove the machinery — `run-demo.sh`.** Clone the repo to a **source**
location and run the demo from that checkout — the demo needs no estate, so
running it in place is correct. It does need Python: **create the environment
described under step 2 (*Prerequisite you create*) first**, with both `nbformat`
and `openpyxl` installed, and activate it in the terminal you run the demo from —
the demo calls `python3` and exercises the notebook helper and the workbook parser:

- **macOS / Linux** — your terminal's bash (stock macOS works as-is; the scripts
  auto-detect GNU vs BSD userland):
  ```bash
  git clone https://github.com/TheBoogieman/ai-work-harness.git ~/ai-work-harness
  cd ~/ai-work-harness && bash dev/scripts/run-demo.sh
  ```
- **Windows** — the integrated **Git-Bash/Cygwin** terminal (plain PowerShell can
  push git but cannot run the bash machinery). This run, by hand on real Windows
  hardware, *is* how the Windows lane is verified — see **Assumptions**:
  ```bash
  git clone https://github.com/TheBoogieman/ai-work-harness.git ~/ai-work-harness
  cd ~/ai-work-harness && bash dev/scripts/run-demo.sh
  ```
  **A Windows venv has no `python3`.** It keeps its interpreter in `Scripts\` as
  `python.exe`, and the `python3` that answers on `PATH` is usually the Microsoft
  Store stub, which installs nothing and runs nothing. The scripts call `python3`,
  so give the venv one before the first run (and activate it with
  `source ~/venvs/venv_global/Scripts/activate` — `Scripts/`, not `bin/`):
  ```bash
  cp ~/venvs/venv_global/Scripts/python.exe ~/venvs/venv_global/Scripts/python3.exe
  ```

**How long it takes is not a number this page will quote.** The first run on a
machine is the slowest; after that the time scales with the number of assertions
the suite carries, and it gains assertions most batches. Four figures have been
measured on four hosts and none held on the others — so wait for the last line
rather than for a clock.

It must end with **ALL 6 DEMO STAGES PASSED**. The demo inits the local git
safety net, validates the template ticket, runs a scratch ticket through the
happy path, **deliberately corrupts a record and shows the validator refusing
with an exact fix**, round-trips the notebook helper, breaks and restores an
agent deployment, and builds a scrubbed context pack with a manifest self-audit.
The same demo runs in CI on Linux + macOS — in full on every push to `main`, and
on a pull request whose changes could move its verdict — so the GNU/BSD
portability branches are exercised for real, not via shims. It is the only
required check on a merge into `main`.

**2 · Install onto your estate and wire your assistant (~10 minutes).**

*Prerequisite you create (the harness never does):* **a Python environment whose
interpreter can `import nbformat`**, registered as a Jupyter kernel and set as
the workspace default interpreter. That is the whole requirement — the notebook
helper runs under whatever `python3` is on the path, and nothing in the harness
reads, requires or validates the environment's name. (`unzip` is optional — the
context-pack helper falls back to Python's zipfile without it. `openpyxl` is needed
to run the demo, whose workbook-parser case fails without it; after that only
`parse-workbook.py`, which reads design workbooks, needs it.)

**`venv_global` below is the documented default, not a fixed name** — every
document here uses it so that "the workspace default interpreter" means one
thing across tickets and assistants. Substitute your own and nothing notices.

```bash
python3.12 -m venv ~/venvs/venv_global   # 3.12 assumed; a newer python3 also works
source ~/venvs/venv_global/bin/activate && pip install nbformat openpyxl   # + your toolchain (dbt etc.)
```

On Windows, a per-user python.org install puts only the `py` launcher on `PATH`, not
`python3.12`, so make the venv with `py -3.12 -m venv ~/venvs/venv_global` and
activate it from `Scripts/` (step 1) (#349).

`pip install` works directly inside the activated venv; installing `nbformat`
into a **system** Python instead needs `pip install nbformat --break-system-packages`
on PEP 668 distros. Then run the installer, giving it an estate directory
**separate from this checkout** — `install.sh` needs a target dir distinct from the
source, and that path is required in practice (a bare re-run from inside the
checkout is refused, with a concrete fix):

```bash
bash estate/install.sh ~/Work
```

`install.sh` is a non-destructive **dumb creator** — it lays down PRODUCT files
only, scaffolds any absent ticket anatomy, initialises a whitelist-scoped
**local-only** git repo with a day-zero commit, copies the verified hook config
to `.github/hooks/harness.json`, deploys the agents, and runs the validator
(`_harness/scripts/check-ticket-log.sh`) and status
(`_harness/scripts/harness-status.sh`); it **never edits an existing file**, so a
re-run finds nothing absent.
(One flag changes that, and only if you type it: `--upgrade`, below. Every run
that does not carry it behaves exactly as this paragraph describes.) It
asks for your board key and model pins (Enter accepts each suggested default;
`--dry-run` plans without touching anything **and asks nothing** — a run that
creates no file can apply no answer — while `--yes` accepts every default). The
agents deploy to your Copilot version's discovery directory — verify that path
for your version (override with `HARNESS_AGENT_DEPLOY_DIR`). Finally, paste
`AI-SETUP-PROMPT.md` into your AI assistant, working in the new estate: it is the **final
validation gate** — it confirms the validator + status are green, spot-checks the
scaffolded tickets, and walks you through the personalisation the installer left
you (model pins, `LICENSE`, scrub-table seeds, Owner lines).

**One expected red, if this machine has had a harness estate on it before.** That
first validator run then reports `FAIL: 999912Z-PROJ-99999 changed but no new
Session Log entry since last validation.` and exits `1`, and the machinery is
working: the validator keeps its validation stamps in `~/.harness/validated/`
(`$HARNESS_STATE_DIR` if you set one), **outside every estate on purpose**, so
that deleting an estate never destroys its validation history. A stamp from your
previous estate therefore outlives it, and this estate's freshly-laid-down copy
of the template ticket is a newer file whose newest session-log header is still
the template's placeholder date. Clear it with the manual half of the fix the
validator prints — one session-log line appended to that ticket, then re-run it —
and everything is green from there. A first-ever install on a machine never sees
this. **Do not move or delete the stamp directory to make it go away**: its
location is the thing that survives an estate being deleted.

**Installing an estate stops for nothing else.** In particular the agent deploy
asks you nothing about a directory that was already there: **the first deploy on a
machine claims it**, whatever it held before, and records that it did.

**Where that record starts to matter is your SECOND estate.** Once a directory is
claimed, a deploy from a *different* estate stops rather than overwrite it — the
summary says `Agents: NOT DEPLOYED`, nothing was written and nothing was lost —
and it asks you to say, once, which estate this machine should read its agents
from:

```bash
HARNESS_AGENT_ADOPT=1 bash ~/Work/_harness/scripts/deploy-agents.sh
```

From then on that estate deploys silently; ownership moved with the command. The
reason it asks at all is below, under **Rehearsing**.

## Rehearsing the installer

If you are trying `install.sh` out on a machine that also uses the harness for
real — practising an upgrade, testing a change, following a walkthrough — say so:

```bash
bash estate/install.sh --rehearsal ~/scratch-estate
```

`--rehearsal` confines everything the installer would otherwise write **outside**
the estate to `_rehearsal/` inside it: the agent deploy goes to
`<target>/_rehearsal/agents` instead of your live assistant directory, and the
validator's stamps to `<target>/_rehearsal/state` instead of `~/.harness`. The run
says so at the top and again in its summary. **A rehearsal writes nothing outside
its own target directory** — delete that directory and the machine is as it was.

Without the flag, an install does what installing means: it puts agents where your
assistant will find them. That is correct and is not going to change. It is also
why a practice run that forgets to say it was practice once overwrote a real
assistant configuration with fixture-pinned contracts. What stops that happening
again is the ownership rule above rather than the flag — **the first deploy on a
machine claims the directory; every later one must prove it owns it** — because a
rehearsal is, by definition, run from an estate that does not own your live
agents. **The rule is the protection; the flag is the convenience**, and the flag
is the half that depends on you remembering.

## Re-running / reconfiguring

Re-running `install.sh` serves three different intents, each with its own home:

- **Reconfigure** (review or change your board key / model pins): run `install.sh`
  from **inside the estate** (`cd ~/Work && bash install.sh`). It recognises the estate
  by its `harness.estate` key, enters **reconfigure-only mode**, and offers your
  established values as defaults. A changed answer is **WARNed** with the file to edit
  and an AI-assistant handoff — the installer never edits your config for you; that
  stays your (or your assistant's) deliberate act via `AI-SETUP-PROMPT.md`, on the record.
  A board key the estate does not hold yet is not a change: an estate may hold several
  boards and the grammar already accepts it, so the re-run prints a NOTE pointing at your
  tools note's Boards table (CONSTITUTION §2) instead, and the summary lists every board
  the estate's tickets carry.
- **Complete or repair** (add or fix estate files): run `install.sh` from your
  **source checkout**, targeting the estate (`bash estate/install.sh ~/Work`). The estate's
  own copy cannot create files — there is no source tree inside an estate to copy from —
  and the reconfigure banner points you back to the checkout for this.
- **Upgrade** (bring an existing estate's machinery up to a newer source): run
  `install.sh` from your **source checkout** with `--upgrade`, targeting the estate.
  Look before you leap — `--dry-run` prints the whole plan and touches nothing:

  ```bash
  bash estate/install.sh --upgrade --dry-run ~/Work
  bash estate/install.sh --upgrade ~/Work
  ```

  This is the one thing in the harness that moves a file you already have, so read
  what it says. It **creates** what is absent, **replaces** a shipped machinery file
  whose contents differ from the new source's, and **retires** a file this release has
  superseded — usually one that was renamed. Replacing and retiring both mean the same
  thing: your copy is **moved into `_retired/<timestamp>/` inside the estate**, never
  deleted, and the run prints the exact `mv` that puts it back **at the moment it moves
  it**. That printed line matters: `_retired/` is deliberately outside the record, so
  nothing else anywhere will ever remind you. It carries your settings forward — your
  customized Constitution and `AGENTS.md`, context-pack scrub table, board grammar, model
  pins and hook configuration all keep the values you gave them — and it **never touches a
  record**: no ticket, log or knowledge file is replaced when present OR recreated
  when absent. User-owned shipped files declare that ownership in their own source
  marker, so even an estate installed before the marker existed is protected on its
  first upgrade; merge new upstream policy into those files deliberately rather than
  replacing local content.

  There is a fourth thing it does, and it is the only one that edits a file in place.
  A file carried forward for your settings can also be *naming* a file the same rename
  has retired — an agent contract calling a script under its old name, or your hook
  configuration pointing at the old validator. The upgrade **re-points** those: it
  rewrites **the dead path and nothing else**, leaves every other byte of the file
  exactly as you had it (hand-edits included), and reports each rewrite as it happens —
  naming the file, both paths in full, and a literal `cp` that restores your version
  from `_retired/<timestamp>/`, where a copy of the file as it stood before the rewrite
  is kept. Only a path a release declared as a rename is ever rewritten, and only
  inside a file that is being carried forward — never inside a record.
  Running it twice is safe; the second run says `NOTHING TO DO`.
  If a run is interrupted, run it again — every file it had already moved is in
  `_retired/`, and the re-run lays down whatever is missing. Skipping releases is
  expected and needs nothing special: one upgrade retires everything superseded across
  the whole span. Run from **inside** the estate, `--upgrade` refuses — there is no
  source in there to upgrade from, and it prints the command that works.

## Hook activation caveat

The auto-commit hook is *witnessed firing* on the VS Code Copilot IDE agent
(v1.129.1, 2026-07-20) on an **established, trusted** workspace. On a
**freshly-created** workspace, `postToolUse` did **not** auto-fire immediately in
testing — even after trusting the folder and reloading; the exact fresh-estate
activation trigger is not fully characterised, so expect a first real session or
a Copilot restart may be needed. The git safety net is the backstop — if a write
wasn't auto-committed, commit it by hand; nothing in the record depends on the
hook firing. (CLI and cloud Copilot surfaces are UNVERIFIED — their schema may
differ.) The hook config design ships as `_harness/hooks/hooks.example.json`. When
another git process holds the estate's index lock (VS Code's Git extension refreshes
right after each write), the commit hooks wait up to 2 seconds and otherwise leave
the change to the next hook with a `NOTE [auto-commit]` line, rather than failing
with git's "Another git process seems to be running" message (#343).

**Windows.** Copilot runs each hook's `powershell` command on Windows, and a bare
`bash` there is System32's WSL launcher, which fails whenever WSL is off; so every
hook entry also carries a `powershell` variant that runs the same `bash` text
through Git Bash (#339). Those variants were witnessed by hand from Windows
PowerShell 5.1, and live in VS Code's Copilot chat on its Copilot CLI harness
(VS Code 1.143.1, Copilot Chat 0.71.0): `sessionStart` ran the validator and
`postToolUse` committed each edit. `sessionEnd` has not been seen live yet: a window
reload doesn't end an open chat. A chat keeps the hook config it started with, so a
changed `harness.json` takes effect in new chats only (#349). An estate
installed before that change keeps its old `.github/hooks/harness.json` through
`--upgrade`, which carries the hook config forward unchanged: after upgrading, copy
the new one over it once, from the estate root (it holds no per-estate values):

```bash
cp _harness/hooks/hooks.example.json .github/hooks/harness.json
```

**Arming on migration.** The auto-commit hooks commit only where the estate's
`.git/config` carries `harness.estate=true` — a positive-identity key `install.sh`
sets, so the hooks can never auto-commit into a nested foreign project repo (e.g.
under `Github/`). Estates created before this version, or migrated via `git clone`
(clone does not copy local config), arrive with auto-commit **disarmed**; run
`git -C <estate> config harness.estate true` to arm it. A plain folder copy or move
keeps the key and needs nothing.

## Running the estate with Claude Code

The harness ships wired to Copilot (CONSTITUTION §22 names the three coupling
points). Claude Code can run the same estate, beside Copilot or instead of it, with
files you add to the estate and **nothing in the installed harness edited**. What
follows was observed on one Windows seat with the Claude Code VS Code extension
2.1.312 and VS Code 1.143.1 (#342); these products change monthly, so check each
point against their current documentation.

- **Instructions.** Claude Code reads `AGENTS.md` by itself (v2.1.277 and later),
  but only while no `CLAUDE.md` exists at or above the working directory. If you add
  an estate `CLAUDE.md` for notes of your own, put `@AGENTS.md` near its top: the
  import keeps `AGENTS.md` in force, also for older CLIs.
- **The three hook jobs** go in `.claude/settings.json`: `SessionStart` runs the
  validator and the work-map check (Claude Code adds their output to the session),
  `PostToolUse` and `SessionEnd` auto-commit. Three differences from the Copilot
  config matter:
  - a hook runs in the session's *current* directory, which can be inside
    `GitHub/`: take the estate root from the hook script's own location, not the
    working directory, and keep the `harness.estate` guard;
  - `SessionEnd` hooks share a 1.5-second budget unless their `timeout` raises it;
  - `PostToolUse` fires for parallel tool calls in parallel, so the commit needs a
    lock of its own.
- **Copilot reads Claude Code's files.** VS Code's defaults also load hooks from
  `.claude/settings.json`, `.claude/settings.local.json` and
  `~/.claude/settings.json` (`chat.hookFilesLocations`) and agents from
  `.claude/agents` (`chat.agentFilesLocations`). Turning those locations off in the
  workspace settings kept the agents out of Copilot's picker, but Copilot's own
  harness still ran the `.claude/settings.json` hooks, logged as "repo settings". So
  a Claude-format hook must check that Claude Code is running it: Claude Code sets
  `CLAUDECODE=1`. `CLAUDE_PROJECT_DIR` is no test — Copilot's harness sets it too.
- **Agents.** Each `_agents/*.agent.md` translates mechanically into a Claude Code
  subagent, `.claude/agents/<name>.md`: tools `read` → `Read, Glob, Grep`, `edit` →
  `Edit, Write, NotebookEdit`, `search` → `Glob, Grep`, `execute` → `Bash`, `web` →
  `WebFetch, WebSearch`, and `agent` with an `agents:` list → `Agent(<that list>)`;
  the body is copied unchanged. `user-invocable` and `disable-model-invocation` have
  no Claude Code equivalent. Treat the copies like the deployed Copilot agents:
  derived, regenerated after every change to `_agents/`, and picked up by a session
  that starts after the folder exists. The interactive agents (`ticket-init`,
  `planner`, `ticket-closer`, `estate-auditor`) need the human in the loop: run them
  as the session (`claude --agent <name>`), not as subagents. `ticket-scribe` has no
  shell, so it can't read the clock its header needs: pass it the local timestamp
  (`date +%Y%m%d%H%M%S`).
- **Model pins** in the agent files are Copilot picker names. Give the Claude Code
  copies their own models by the Harness Guide's tiers. On a Copilot plan whose
  picker offers only Auto, pin `Auto`: every Copilot agent then runs on that one
  model.
- **Keeping the adapter on the record.** The estate's whitelist `.gitignore` ignores
  every adapter file (`CLAUDE.md`, `.claude/`). To version the ones you write, add
  them once with `git add -f <path>`: an ignore rule never untracks a tracked file,
  the auto-commits keep them current, and the whitelist stays as shipped. Leave the
  generated agent copies and `.claude/settings.local.json` untracked.
