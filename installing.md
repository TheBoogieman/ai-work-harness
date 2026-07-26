# Installing the harness

**This page is the one home for every install command, prerequisite and
caveat.** The front page (`README.md`) links here and repeats none of them: two
install documents drift apart, which is the exact failure an earlier
consolidation was made to end. So the commands below are registered, and the
docs gate reds if a registered command appears on both pages.

The harness installs onto a **work estate** — a local folder it turns into a
disciplined, record-keeping workspace. Two steps: prove the machinery runs on
your machine (the demo — no AI assistant needed), then lay down the estate and
wire your assistant.

**1 · Prove the machinery — `run_demo.sh` (~60 seconds).** Clone the repo to a
**source** location and run the demo from that checkout — the demo needs no estate,
so running it in place is correct:

- **macOS / Linux** — your terminal's bash (stock macOS works as-is; the scripts
  auto-detect GNU vs BSD userland):
  ```bash
  git clone https://github.com/TheBoogieman/ai-work-harness.git ~/ai-work-harness
  cd ~/ai-work-harness && bash _harness/scripts/run_demo.sh
  ```
- **Windows** — the integrated **Git-Bash/Cygwin** terminal (plain PowerShell can
  push git but cannot run the bash machinery). This run, by hand on real Windows
  hardware, *is* how the Windows lane is verified — see **Assumptions**:
  ```bash
  git clone https://github.com/TheBoogieman/ai-work-harness.git ~/ai-work-harness
  cd ~/ai-work-harness && bash _harness/scripts/run_demo.sh
  ```

It must end with **ALL 6 DEMO STAGES PASSED**. The demo inits the local git
safety net, validates the template ticket, runs a scratch ticket through the
happy path, **deliberately corrupts a record and shows the validator refusing
with an exact fix**, round-trips the notebook helper, breaks and restores an
agent deployment, and builds a scrubbed context pack with a manifest self-audit.
The same demo runs in CI on Linux + macOS — in full on every push to `main`, and
on a pull request whose changes could move its verdict — so the GNU/BSD
portability branches are exercised for real, not via shims. Which pull requests
skip it is stated once, in `.github/CONTRIBUTING.md`.

**2 · Install onto your estate and wire your assistant (~10 minutes).**

*Prerequisite you create (the harness never does):* a Python virtualenv named
exactly **`venv_global`** with `nbformat`, registered as a Jupyter kernel and set
as the workspace default interpreter. (`unzip` is optional — the context-pack
helper falls back to Python's zipfile without it.)

```bash
python3.12 -m venv ~/venvs/venv_global   # 3.12 assumed; a newer python3 also works
source ~/venvs/venv_global/bin/activate && pip install nbformat   # + your toolchain (dbt etc.)
```

`pip install` works directly inside the activated venv; installing `nbformat`
into a **system** Python instead needs `pip install nbformat --break-system-packages`
on PEP 668 distros. Then run the installer, giving it an estate directory
**separate from this checkout** — `install.sh` needs a target dir distinct from the
source, and that path is required in practice (a bare re-run from inside the
checkout is refused, with a concrete fix):

```bash
bash install.sh ~/Work
```

`install.sh` is a non-destructive **dumb creator** — it lays down PRODUCT files
only, scaffolds any absent ticket anatomy, initialises a whitelist-scoped
**local-only** git repo with a day-zero commit, copies the verified hook config
to `.github/hooks/harness.json`, deploys the agents, and runs the validator +
status; it **never edits an existing file**, so a re-run finds nothing absent. It
asks for your board key and model pins (Enter accepts each suggested default;
`--dry-run` plans without touching anything, `--yes` accepts every default). The
agents deploy to your Copilot version's discovery directory — verify that path
for your version (override with `HARNESS_AGENT_DEPLOY_DIR`). Finally, paste
`setup.md` into your AI assistant, working in the new estate: it is the **final
validation gate** — it confirms the validator + status are green, spot-checks the
scaffolded tickets, and walks you through the personalisation the installer left
you (model pins, `LICENSE`, scrub-table seeds, Owner lines).

## Re-running / reconfiguring

Re-running `install.sh` serves two different intents, each with its own home:

- **Reconfigure** (review or change your board key / model pins): run `install.sh`
  from **inside the estate** (`cd ~/Work && bash install.sh`). It recognises the estate
  by its `harness.estate` key, enters **reconfigure-only mode**, and offers your
  established values as defaults. A changed answer is **WARNed** with the file to edit
  and an AI-assistant handoff — the installer never edits your config for you; that
  stays your (or your assistant's) deliberate act via `setup.md`, on the record.
- **Complete or repair** (add or fix estate files): run `install.sh` from your
  **source checkout**, targeting the estate (`bash install.sh ~/Work`). The estate's
  own copy cannot create files — there is no manifest or source to copy from in-estate
  — and the reconfigure banner points you back to the checkout for this.

## Hook activation caveat

The auto-commit hook is *witnessed firing* on the VS Code Copilot IDE agent
(v1.129.1, 2026-07-20) on an **established, trusted** workspace. On a
**freshly-created** workspace, `postToolUse` did **not** auto-fire immediately in
testing — even after trusting the folder and reloading; the exact fresh-estate
activation trigger is not fully characterised, so expect a first real session or
a Copilot restart may be needed. The git safety net is the backstop — if a write
wasn't auto-committed, commit it by hand; nothing in the record depends on the
hook firing. (CLI and cloud Copilot surfaces are UNVERIFIED — their schema may
differ.) The hook config design ships as `_harness/hooks/hooks.example.json`.

**Arming on migration.** The auto-commit hooks commit only where the estate's
`.git/config` carries `harness.estate=true` — a positive-identity key `install.sh`
sets, so the hooks can never auto-commit into a nested foreign project repo (e.g.
under `Github/`). Estates created before this version, or migrated via `git clone`
(clone does not copy local config), arrive with auto-commit **disarmed**; run
`git -C <estate> config harness.estate true` to arm it. A plain folder copy or move
keeps the key and needs nothing.
