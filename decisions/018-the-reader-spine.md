# 018 — The reader spine: FIND, not SYNTHESISE

## Context

The estate started with one reader — `ticket-recall` (`#70`), which narrates a
single ticket at pickup. Readers then multiplied: `weekly-digest` (`#73`)
narrates a window, `retrospective` (`#85`) writes a period review for the human,
and `harness-recall` (`#108`) finds a topic across the whole record. They were
each specified against the last one — "model it on ticket-recall" — so the shared
architecture lived only as a habit of copying, never written down. An unwritten
architecture drifts: the fourth reader can quietly relax an invariant the first
three held, and nothing notices.

`#74` had already drawn the neighbouring line — guided-first-ticket is a MODE on
`ticket-init`, not a new agent — establishing that a new capability is often a
contract clause rather than new mechanism. Read-side capability is the same
shape: a reader is a prose contract, not a new machine, and the readers share a
spine worth naming once.

## Decision

Name the READER SPINE — the invariants every reader contract carries, so `#82`'s
reader detector can enforce them against an explicit list rather than trusting
each author to copy them:

- **Grounded narration.** Every claim traces to a named cell, entry, file, or
  commit; the fabrication clause is carried VERBATIM (an embellished output is a
  fabricated record — a reader that invents is caught by NOTHING, so the
  discipline lives in the contract).
- **Fixed sections.** The output shape is declared and not renegotiated per
  invocation; an empty section stays, marked empty, never dropped or padded.
- **Tiered consumption.** Structured/headline sources first, `Logs/`-and-tail
  only when a structured source cites them — the context budget that makes a
  cheap reader worth having.

And the read-side scope test — **FIND, not SYNTHESISE**. A reader locates and
cites; it reconciles sources into a single account only when that account is as
CHECKABLE AT CONSUMPTION TIME as a citation. A citation self-verifies — the user
opens the named file and sees for themselves; a synthesised account costs as much
to verify as the work it replaced, and a reader has no validator behind it to
catch a bad join. So the default is the map, not the territory's summary. The
REMINT CONDITION is recorded: synthesis earns its place alongside a per-claim
spot-check mechanism that makes an account as cheap to verify as a citation — NOT
a bigger model, which produces more fluent joins without making one checkable.

## Consequences

Readers become a governed family, not a pile of look-alikes. `#82`'s
reader-agent detector checks the spine — fabrication clause present, fixed
sections stated, scope stated — against an explicit list that now reads
`ticket-recall`, `weekly-digest`, `retrospective`, `harness-recall` (four names);
a fifth reader joins the list and is held to the same spine, so the invariants
are checkable rather than aspirational. The FIND-not-SYNTHESISE default keeps the
read side cheap and honest by construction, and the mode-vs-contract test means a
new read capability ships as a contract (or a mode on an existing one) with its
coverage in the contract plus the detector — never as new mechanism demanding a
demo guard it cannot honestly carry.

## Status

Accepted. See `#76` (the cross-estate read-side design discussion) and `#108`
(`harness-recall`, the topic reader this ADR ships beside). LINEAGE: this EXTENDS
`decisions/013` (the estate gains a reader) from single-ticket scope to
estate-wide — the same reader concept over a wider substrate, and the mode test
of `#74` generalised to the read side. It supersedes nothing.
