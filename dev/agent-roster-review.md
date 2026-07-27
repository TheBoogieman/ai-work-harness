# agent-roster-review.md — what each agent is for, and whether any two are one agent

DEV material. This is a dated review of the agent roster as it stood at commit
`748273e`, produced for #130. It is a point-in-time reading, not a standing
description of the roster: the roster grows, and the job of describing an agent
at HEAD belongs to that agent's own file. Read this to learn what the review
found; read `../estate/_agents/` to learn what an agent does today.

It changes no agent file. Any consolidation this review recommended would be a
separate item with its own ruling — see the verdict below, which recommends none.

## Method

Each job line below was derived by reading the agent's instruction BODY, not its
frontmatter `description` field. That distinction is load-bearing here, because
the two disagree: the description field is a one-line dropdown label written to
help a user pick an agent, and in several files it omits an entire
responsibility that the body carries. The clearest cases:

- `ticket-init`'s description says "interactive ticket kickoff". Its body also
  defines guided first-ticket mode — the harness's onboarding tour — which is
  more than half the file and appears in the description not at all.
- `knowledge-curator`'s description says it compacts and proposes promotions.
  Its body also makes it the door through which a `SKILL.md` is drafted. The
  description does not mention skills.
- `weekly-digest`'s description says it narrates a period. Its body also lets it
  run `harness-status.sh` itself, which is why it holds `execute` at all.
- `check-scribe`'s description says it never hand-edits `.ipynb`. Only the body
  shows the consequence: it holds no `edit` tool, so a script it executes is its
  only writing hand.

The same reason defeats reading the roster by declared toolset. Four agents hold
`[read, execute]` with no `edit` — `check-scribe`, `harness-recall`,
`ticket-recall`, `weekly-digest`. Three of those four call themselves read-only;
`check-scribe` writes a notebook through `append_notebook_cell.py`. The
toolset therefore reports three writers and four non-editors for the same set,
and neither number is the answer. Behaviour is.

## The roster — one job each

| Agent | Its job, in one line |
| --- | --- |
| [check-scribe](../estate/_agents/check-scribe.agent.md) | Appends each keepworthy check to the ticket's `checks_master.ipynb` as one why-note plus one code cell, exclusively through `append_notebook_cell.py` — holding no `edit` tool, the script is its only writing hand and the notebook JSON is never touched by hand. |
| [doc-writer](../estate/_agents/doc-writer.agent.md) | Turns three named ticket sections — header, Current State, Changes Made — into outbound prose for a PR description or README, reading nothing else in the repo and performing no publish; the closed reading list, not the output format, is what makes it its own agent. |
| [harness-recall](../estate/_agents/harness-recall.agent.md) | Answers "what does the estate already hold about X?" by re-grepping `Tickets/**` and `General AI-Knowledge/**` from scratch every run — never a stored index — and returning ranked citations under three fixed headings including the regions it searched and found empty. |
| [knowledge-curator](../estate/_agents/knowledge-curator.agent.md) | Compacts a ticket's `AI-Knowledge/` in place (merge, delete, re-index), then works the one human-approved door out of the ticket: a generic promotion into `General AI-Knowledge/<Topic>/` or a drafted `SKILL.md`, neither of which it may self-approve. |
| [knowledge-keeper](../estate/_agents/knowledge-keeper.agent.md) | At task end, applies a three-part keep-filter to what the session actually learned and writes zero to two small notes plus their `_index.md` lines into the ticket's `AI-Knowledge/` — files only, never assistant-side session or repo memory, and zero is a normal result. |
| [retrospective](../estate/_agents/retrospective.agent.md) | Once a review cycle, reads each ticket's settled end-state to build a themed, impact-framed account of what COMPLETED in a window (12 months by default, plus a short still-in-flight section), folds `retro_stats.sh`'s offline counts into the prose, and lands it as exactly one new timestamped file it may never rewrite. |
| [ticket-init](../estate/_agents/ticket-init.agent.md) | Births a ticket folder from a three-question interview and an adjacency scan, refusing to invent a conforming name when identity is unknown — it files a deliberately non-conforming `pending-` stub that status nags about instead — and narrates that same real init as the onboarding tour whenever the estate holds no live ticket. |
| [ticket-recall](../estate/_agents/ticket-recall.agent.md) | At pickup, reconstructs where ONE ticket stands under four fixed headings ending in a suggested next step, reading structured sources first and `Logs/`/`Dump/` only where a structured source cites them, and routing anything worth keeping to `ticket-scribe` rather than writing it. |
| [ticket-scribe](../estate/_agents/ticket-scribe.agent.md) | At every task end, performs the ticket record's one atomic update — a strictly-formatted local-time Session Log block, a rewritten 3-8 sentence Current State, and the Repos/Branches/PRs header if it moved — and stops rather than guessing when the session's actions are unclear. |
| [weekly-digest](../estate/_agents/weekly-digest.agent.md) | Resurfaces a sprint-length window (14 days by default, passed in every run and never remembered) by narrating the ACTIVE tickets' movement and knowledge captured, and may run the status sweep itself so the aging-knowledge warnings replay inside the digest. |

## Overlap verdict — no pair overlaps enough to justify merging

Three candidate pairs were examined. Each was rejected, and each for a different
reason, which is itself evidence that the roster's boundaries were drawn
deliberately rather than by accident of naming.

**`weekly-digest` and `retrospective` — the closest pair, and still not one
agent.** They share an axis no other pair shares: both take a time window as a
stateless argument and narrate it from the same structured sources. Their
differences are not parameters of one operation, they are incompatible
properties.

- Their scopes PARTITION the ticket set rather than duplicating it: the digest
  is active-ticket-centric and explicitly not an archive crawl; the
  retrospective is closed-ticket-centric with a short still-in-flight coda.
  Merging them would not remove duplicated work, because there is none.
- The digest holds no `edit` tool and states that it writes nothing; the
  retrospective holds `edit` and one write door. A merged agent must hold `edit`
  on every invocation, so the frequent cheap call would gain a write capability
  it does not need. `dev/scripts/docs-check.sh` asserts the digest's
  no-`edit` property by name, so the merge would delete a live guard.
- Their registers are deliberately opposed. The retrospective's file states it
  is the one reader whose register is not neutral; the digest is a neutral
  report. One agent cannot hold both defaults honestly.
- Their model tiers differ, and the tier is not decoration: merging forces the
  fortnightly call onto the expensive tier or guts the year-scale judgement.

**`ticket-recall` and `harness-recall` — nearly identical furniture, opposed
cores.** They share toolset, tier, fixed-sections discipline, the fabrication
clause near-verbatim, the never-a-subagent rule, and their length and
degrade-gracefully clauses. What differs is the one thing that cannot be shared:
`harness-recall` is bound by a find-not-synthesise ruling, recorded with the
condition under which it could be revisited, while `ticket-recall`'s entire
output IS a synthesis of one ticket into Done / Changed / Unresolved / Suggested
next. A merged agent would need a mode switch that flips its own central design
ruling, which is two agents wearing one name. `harness-recall`'s opening
paragraph already states this boundary against both of its siblings.

**`knowledge-keeper` and `knowledge-curator` — the merge argument someone will
actually raise.** They are the only pair that writes to the same file: both
maintain a ticket's `AI-Knowledge/_index.md`, under the same convention, with
the same toolset. They are still two agents, and the curator's own file gives
the reason — a subagent cannot exceed its parent's cost tier, so a cheap parent
would silently downgrade and gut the job. The keeper is a cheap end-of-task
reflex invoked from inside a session; the curator is a deliberate direct-session
compaction that also owns the human-approved promotion gate. Merging puts the
promotion gate behind a cheap model, or makes every task end pay for the
expensive one.

Two further pairs were considered and dismissed without argument. `check-scribe`
and `ticket-scribe` share a name-part and the end-of-task moment but write to
disjoint surfaces through disjoint mechanisms. `doc-writer` and `retrospective`
both produce human-facing prose, but from disjoint sources to disjoint
destinations — one leaves the estate for a repo audience, the other never leaves
`General Human Knowledge/`.

## One defect observed, not fixed here

Reading `../estate/_agents/ticket-recall.agent.md` confirms the claims-truth defect that
motivated this review: its opening line declares it the estate's only reader,
while `harness-recall` and `weekly-digest` hold the same read-only capability
and the same narration contract. The claim is false at `748273e`.

It is not corrected in this review, and this review must not be read as having
corrected it. It is owned by #131, whose first act is that correction.
