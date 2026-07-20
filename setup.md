# setup.md — final-gate prompt for your AI assistant (paste after `install.sh`)

Paste everything below into your AI assistant of choice, working **in the newly
installed estate**. `install.sh` has already laid down the PRODUCT files,
scaffolded absent ticket anatomy, initialised a whitelist-scoped, remote-free
git repo with a day-zero commit, copied the verified hook config, deployed the
agents, and run the validator + status. Your job is the **final gate**: audit
what the installer established, verify green, finish the personalisation the
installer deliberately left to you, and check the hook fires — you build
nothing the installer already built.

---

You are in my freshly-installed harness estate; `folder-structure.md` at the
root is the backbone — read **PART I** first. `install.sh` has run. Showing me
diffs before every write:

1. **Read the installer's closing SUMMARY** (board key, model pins, the derived
   workspace root, and the tunable knobs with their defaults). Confirm the git
   repo is whitelist-scoped and has **no remote** (estates are local-only).
2. **Manifest audit:** confirm the estate contains **zero DEV files** — nothing
   from the DEV class of `.github/ship-manifest.txt` in the source (`.github/`,
   `CLAUDE.md`, `run_demo.sh`, the manifest itself).
3. **Green verification:** run `_harness/scripts/check_ticket_log.sh` and
   `_harness/scripts/harness-status.sh`; both must be green. Spot-check the
   scaffolded tickets — each has a valid `AI-Knowledge/_index.md` and the
   git-ignored `Logs/` + `Dump/`.
4. **Finish the personalisation the installer left to me** (it never edits a
   pre-existing file): any model pin still `PICK-A-*` → enumerate the models
   actually enabled in my Copilot org and pin real **scalar** IDs into each
   `_agents/*.agent.md` (cheap tier for scribes/keeper/doc-writer, Sonnet-class
   for init/curator), then re-run `_harness/scripts/deploy_agents.sh`;
   the `LICENSE` name; the `make_context_pack.sh` scrub-table seeds (my
   identifier classes — employee ID, org domains, cloud account IDs); the
   `folder-structure.md` Owner and key-repos lines.
5. **Live hook-fire check:** with the config at `.github/hooks/harness.json`,
   confirm `postToolUse` produces an auto-commit in a real session. Per
   INSTALL.md's activation caveat, a freshly-created workspace may not fire
   until a first real session or a Copilot restart — the git safety net is the
   backstop, so if a write isn't auto-committed, commit it by hand.
6. **Format is load-bearing:** if I later try to CHANGE an already-established
   ticket-folder format, warn me it will break the harness and show exactly
   what would have to change — never rename or edit my tickets for me.

Non-goals: no orchestrator agents, no dashboards, no self-healing, no remote on
this repo, no changes inside `GitHub/`. Propose anything beyond this in a plan
and wait.
