# 004 — Hooks are a convenience, not a dependency

## Context

The auto-commit-per-write behaviour is delivered through a Copilot `postToolUse`
hook. Hooks are preview-grade and assistant-specific: on a freshly-created
workspace the hook did not always auto-fire immediately in testing, and CLI/cloud
Copilot surfaces use a different schema. If the record's integrity depended on the
hook firing, the whole harness would be as fragile as a preview feature.

## Decision

The hook is a **convenience layer, never a dependency**. The git safety net is
the backstop: if a write was not auto-committed, it is committed by hand, and
`harness-status.sh` warns when commits fall behind session activity. Nothing in
the record depends on the hook firing. The shipped hook config is the
witnessed-firing schema, with an honest activation caveat in README.

## Consequences

The harness runs fully on any host and any assistant — porting to a non-Copilot
tool means translating the hook config, not redesigning the record model. The
cost is that on assistants or fresh workspaces where the hook does not fire, the
operator carries the small discipline of a manual commit, which the status report
surfaces so it is never silently skipped.

## Status

Accepted. See `#44` (baking the witnessed hook schema into the shipped example
with an honest activation caveat) and `#60` (the estate-key arming that gates
when the hook may commit).
