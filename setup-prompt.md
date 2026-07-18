# Setup prompt — paste into a strong-model Copilot session after INSTALL steps 0-3

You are in my workspace; `folder-structure.md` at the root is the backbone.
Read PART I. Then, showing me diffs before each write:
1. Verify prerequisites: `venv_global` exists and is the default interpreter;
   the git repo is initialised, whitelist-scoped, remote-free.
2. Personalisation audit: find every remaining placeholder
   (`<Your Name>`, `PROJ` if I haven't set my board key, `PICK-A-*-MODEL`,
   `<org>/...` repo examples) and walk me through filling them.
3. Enumerate the models actually enabled in my Copilot org; pin real scalar
   IDs into each `_agents/*.agent.md` (cheap tier for scribes/keeper/doc,
   Sonnet-class for init/curator). Run `_harness/scripts/deploy_agents.sh`
   and confirm all six load in the agent picker.
4. Check the CURRENT docs for hook config location and schema on this
   Copilot version; adapt `_harness/hooks/hooks.example.json` accordingly
   and install it. Do not trust cached knowledge of the format.
5. Run the full acceptance test from INSTALL.md §6, fixing anything that
   fails, then commit.
Non-goals: no orchestrator agents, no dashboards, no self-healing, no remote
on this repo, no changes inside `GitHub/`. Propose anything beyond this in a
plan and wait.
