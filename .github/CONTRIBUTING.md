# Contributing

Thanks for helping improve the AI work harness. This project runs on one
simple law, borrowed from the product itself: **work leaves a record.** Every
change on `main` traces to a numbered, discussable issue. The notes below —
and the automated merge gates — exist to make that easy, not to bounce you.
Outside contributors are welcome; the rules bind the maintainers' own
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
If a check reds, its message carries the remedy: a grammar miss prints the exact
`git branch -m` + re-push commands, and a number-mismatch prints both ways out —
add `Fixes #NN` for the number the branch leads with, or rename the branch to an
issue the PR does close.

## The merge gates (and where the authoritative list lives)

This guide does not enumerate the checks, and that is deliberate. A workflow
file under `.github/workflows/` declares a *job*; whether that job is
**required** to merge is a branch-protection setting on `main` — repository
configuration, not a file in the tree, and not readable from anything you can
clone. So any list written out here is a curated copy of a set maintained
elsewhere: this section has been completed before and was overtaken twice in one
afternoon by gates that landed without touching this file.

**Read the authoritative set; don't trust a copy of it:**

- **The checks on your own PR** — the live rendering, and the one that decides
  your merge: whatever reports there is what you have to get green.
- **Branch protection on `main`** — the setting itself, under the repository's
  Settings → Branches, or
  `gh api repos/<owner>/<repo>/branches/main/protection --jq '.required_status_checks.contexts'`
  (needs admin access on the repo).

What is stable is the *kinds* of gate. Individual checks come and go; these
categories don't. Each has its own workflow, and each runs from your PR's own
HEAD:

- **Governance** — the record-keeping rules above: the branch matches the
  grammar and its leading number is one the PR closes, and the body carries a
  closing reference (`Fixes/Closes/Resolves #NN`) resolving to a **real, open**
  issue in this repo. (`governance.yml`)
- **Product proof** — the acceptance demo, on more than one operating system.
  It is the truth-teller for any behaviour change; the next section covers what
  it proves and when its body is skipped. (`demo.yml`)
- **Documentation** — doc completeness, the dev/product separation, and drift
  between a rule's one home and the documents that quote it. (`docs.yml`)
- **Code quality** — static checks over every tracked shell script: linting, and
  budgets on the shape of the code. (`shell-lint.yml`, `shape.yml`)

Two things that catch people out. **Reporting is not the same as being
required** — a job can report on your PR without blocking the merge, and a
workflow's own header comments describe the state on the day that workflow
landed, not the branch-protection setting today. And **a required check name
that no job renders never goes red; it stays pending forever** — so if a check
you were expecting simply never appears, say so on the PR rather than waiting it
out.

<!-- UNOWNED (raised by #181, not this file's to fix): the second half of that
     warning is live today. `.github/workflows/shell-lint.yml` and
     `.github/workflows/shape.yml` both still carry a header comment saying
     "NOT ADDED TO BRANCH PROTECTION" — the operator promoted both after those
     workflows landed, and each is a required context on `main` now. Whoever
     owns those two files next should date the comment or drop it. -->


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
`gate-waiver` label, which passes the two governance checks with a loud,
on-the-record log line. It waives **only** those two — the demo, the
documentation gate and the code-quality checks are untouched by it. Applying a
label needs repo write access, so this path is maintainer-only by construction —
it is rare, loud, and never silent.

## The flow, end to end

`open/claim an issue → branch (NN-slug) or fork → PR with Fixes #NN →
every required check on the PR green (see "The merge gates" above) →
a maintainer merges → the merge auto-closes the issue and deletes the branch.`
