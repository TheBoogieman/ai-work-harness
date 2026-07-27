# 002 — How the harness knows a folder is a genuine estate

## Context

The auto-commit hook fires on file writes. It must fire inside a real estate and
NEVER inside a nested foreign project repo (e.g. a clone under `GitHub/`), or it
would auto-commit into someone else's repository. So the harness needs a reliable
answer to one question: "is this directory a genuine harness estate?" That answer
was gotten wrong more than once before it settled, which is why this decision
carries a lineage section rather than a graveyard of dead files.

## Decision

An estate is identified by a **positive-identity config key**: the hook
auto-commits only where the estate's `.git/config` carries `harness.estate=true`,
a key `install.sh` sets. Identity is a property the installer stamps, not a guess
inferred from paths or marker files.

## Lineage (superseded approaches, kept here not as dead files)

- **Remote-refusal** — the earliest instinct was to key off "has no remote."
  Fragile: plenty of non-estate repos also have no remote, and it is a negative
  test that cannot distinguish an estate from any other local-only repo.
- **File-sentinel** — a marker file in the working tree. This broke twice: a
  marker in the tree is copyable, gets committed and cloned around, and travels
  to places that are not estates, so it mis-armed the hook.
- **Config-key** (current) — `harness.estate=true` in local `.git/config`. Local
  config is not copied by `git clone`, so a cloned or freshly-migrated estate
  arrives **disarmed** (safe default) and is armed deliberately with
  `git -C <estate> config harness.estate true`; a plain folder copy or move keeps
  the key and needs nothing.

## Consequences

The hook can never auto-commit into a foreign repo. The trade-off is that
clone-migrated estates arrive disarmed and need one explicit arming command —
documented in README under **Arming on migration** — which is the correct
fail-safe direction (disarmed-and-visible beats armed-into-the-wrong-repo).

## Status

Accepted; config-key is current. See `#60` (auto-commit hooks commit only in a
genuine estate via the `harness.estate` key) and the README migration note.
