# Contributing

Thanks for helping improve the AI work harness. This project runs on one
simple law, borrowed from the product itself: **work leaves a record.** Every
change on `main` traces to a numbered, discussable issue. The notes below —
and two automated merge-gate checks — exist to make that easy, not to bounce
you. Outside contributors are welcome; the rules bind the maintainers' own
discipline first.

> This file is **development** infrastructure for the harness repository. It is
> never deployed into a user's estate.

## Issues-first workflow

1. **Open or claim an issue** describing the change. A bug, a feature, a doc
   fix — all start as an issue, so the work is anchored to a record before any
   diff exists. (Two well-meant external PRs have already died unanchored; an
   issue first is what prevents that waste.)
2. **Branch** (if you have write access) or **fork** (if you don't).
3. **Open a PR** whose body references the issue with a closing keyword —
   `Fixes #NN` (also `Closes #NN` / `Resolves #NN`). The merge then
   auto-closes the issue.

## Branch naming

Local branch names are yours — name them however you like while you work. The
name is only enforced **at the merge gate**. A branch that merges must match:

```
<issue-number>-<lowercase-kebab-slug>
```

i.e. the leading issue number, a hyphen, then one or more
lowercase-alphanumeric segments joined by hyphens (regex
`^[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$`). Examples: `37-status-abort-fix`,
`47-governance-pair`. Not accepted: `WSL-canonical` (uppercase),
`Feature/Foo` (slash + case), `47_governance` (underscore). There is **no
exception prefix** — a merging branch either conforms or is renamed.

The branch's leading number must also be one of the issues the PR closes
(its `Fixes #NN` set) — so a branch never auto-closes an issue it wasn't for.
If a check reds, its message prints the exact `git branch -m` + re-push
commands; nothing to re-derive.

## The required checks (and why)

Two governance checks run on every PR into `main`, alongside the acceptance
demo:

- **`branch-name grammar (NN-slug)`** — the branch conforms to the grammar
  above and its number matches the PR's `Fixes #NN`.
- **`PR references an issue`** — the body carries a closing reference
  (`Fixes/Closes/Resolves #NN`) that resolves to a **real, open** issue in
  this repo. A dangling number or an already-closed one reds with its own
  message.

## What the acceptance demo covers (and when it is skipped)

`CLAUDE.md` and `README.md` point at this section rather than restating it —
one telling to keep true, so the three documents cannot drift apart.

The demo's two lanes — **`demo (ubuntu-latest)`** and **`demo (macos-latest)`** —
are required checks. They **report on every PR into `main`**, and both must be
green before it can merge. Reporting is not the same as running: the job always
reports, so a required check is never left pending, but its expensive steps are
conditional and a documentation-only PR goes green in seconds *without running
the demo*.

A PR skips the demo only when **both** of these hold (the decision is made by
the step "Decide whether this change can affect the demo" in
`.github/workflows/demo.yml` — read it there, it is the authority):

- every file in the PR is a content **edit** — one addition, deletion or rename
  anywhere, of any file, and the demo runs; **and**
- every one of those edited paths is a `*.md` **at the repository root**,
  something under `decisions/`, or something under
  `General AI-Knowledge/AI Harness/`.

Everything else runs the demo in full — including markdown deliberately left off
that list (`_agents/*.agent.md`, `General AI-Knowledge/Skills/**`, `Tickets/**`),
a push to `main`, a manual dispatch, and any run that cannot work out what
changed.

When the body is skipped the job prints a notice saying so, and the demo runs in
full on the push to `main` after the merge. The demo is still the truth-teller
for any behaviour change — so read the job log, not the check mark, and say which
of the two happened.

## Outside contributors (forks)

Fork PRs are welcome and treated as guests:

- **Branch grammar and coherence are informational only** for forks — they
  annotate, they don't block. Name your fork branch however you like.
- **The issue anchor is still required.** Every PR, fork or not, must reference
  an issue with a closing keyword. If your PR reds for a missing anchor, open
  an issue describing the change and add `Fixes #NN` to the PR body.

## Escape hatch (maintainers only)

For genuine trivia (a typo-class change), a maintainer may apply the
`gate-waiver` label, which passes both governance checks with a loud,
on-the-record log line. Applying a label needs repo write access, so this
path is maintainer-only by construction — it is rare, loud, and never silent.

## The flow, end to end

`open/claim an issue → branch (NN-slug) or fork → PR with Fixes #NN →
green checks (demo ×2 + the two governance checks) → a maintainer merges →
the merge auto-closes the issue and deletes the branch.`
