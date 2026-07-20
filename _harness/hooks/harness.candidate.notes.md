# harness.candidate.json — CANDIDATE (#44 phase 1)

`harness.candidate.json` in this directory is the **deployment-proven VS Code
Copilot IDE-agent hook schema**, staged for a clean public confirmation run on a
disposable estate. It is **not** the shipped example yet — that is
`hooks.example.json`, which is rewritten in phase 2 from the confirmed witness.

Shape: `version` at top level, the three events nested under a `hooks` wrapper,
each entry keyed on `bash` with `cwd` and `timeoutSec` (no legacy
`command`/`toolFilter`/`${WORKSPACE_ROOT}`). The file is kept byte-clean to the
parsed shape — no `$comment` key — so nothing extra is a variable in the fire.

**Witness placeholder** — the operator fills what was actually seen firing:

- product: VS Code Copilot IDE agent
- version: _TODO — record from the confirmation run_
- date: _TODO — record from the confirmation run_

**Do not auto-load this in the canonical repo.** It lives under `_harness/hooks/`
(a tracked fixture), NOT `.github/hooks/`, precisely so the VS Code Copilot IDE
agent does not fire auto-commits into the product repo (#44 cond 0). The
`make-scratch-estate.sh` scaffolding copies it into a disposable estate's
`.github/hooks/harness.json`, where firing it is safe.
