# DEVELOPMENT.md — how this project is built

This file records the METHOD by which ai-work-harness is developed: a small
society of AI roles with separated powers, an adversarial review seat, and a
human at the centre holding merge authority. It is DEV — it documents how the
work is done, not how the shipped harness behaves (that is folder-structure.md,
the constitution). It is historical-first: the account of how the project was
actually built comes first; guidance for adopting the method comes second, and
the `dev-loop/` folder beside this file holds the empty starter templates.

## Part I — how this project was actually built

### The shape of the loop

Change enters as a GitHub issue and leaves as a merged, audited commit. Between
those two points the work passes through four roles, each holding different
powers and deliberately unable to do each other's jobs. The separation is the
point: no single seat can both decide what "done" means and declare itself done.

### The four roles

- **ARCHITECT** — writes the spec, verifies the delivered work against it, and
  cuts the release. The architect decides WHAT gets built and confirms it was
  built, but does not implement and does not merge.

- **REVIEWER/PRODUCT-OWNER** — runs an independent, adversarial audit. This seat
  sets the goal conditions a change must satisfy and NEVER the implementation
  that satisfies them; it executes every guard to failure at least once, so a
  guard that cannot be made to go red is treated as no guard at all. Because it
  directs from goal conditions only, it can judge the work without having shaped
  how the work was written.

- **IMPLEMENTER** — the mechanical executor. It applies exactly what the spec
  names and flags anything the spec does not cover rather than inventing scope.
  It is, deliberately, the SOLE tool- and credential-bearing seat: the only role
  that can touch the repository, run the machinery, or push. Concentrating the
  tools in one directed seat is what makes the directing seats' audit
  independent — they reason about the work from the outside, holding no
  credentials of their own.

- **OPERATOR** — the human. Sovereign over the whole loop, courier who carries
  messages between the seats, and the SOLE merge authority. No AI seat merges;
  the operator does, once the evidence is in.

### The five working laws

1. **Specs bind to verbatim issue bodies.** The issue body as written is the
   contract; a seat builds from the live body, not from a summary of it.
2. **Merges close, independent audit confirms or reopens.** A merge closes an
   issue provisionally; the independent audit either confirms the close or
   reopens it. Closing is not the same as being right.
3. **Every bug closes with a guard that provably fails on pre-fix code.** A fix
   without a regression guard that goes red when the fix is reverted is not a
   fix. The guard's red state is the proof.
4. **Security-shaped changes get an attack cycle BEFORE a spec exists.** When a
   change touches a security surface, the loop runs an attack cycle first and
   lets what it finds shape the spec, rather than speccing blind and auditing
   after.
5. **Claims live at HEAD or get removed.** Every claim in a doc, a comment, or a
   printed line must be true at the current HEAD or be deleted. A stale claim is
   a defect, not a footnote.

### The seat surfaces

The directing seats — architect and reviewer/product-owner — are chat-based:
they hold shared context and reason about the work in conversation, carrying no
tools and no credentials. The executor seat is embedded in an IDE and holds the
tools: it reads and writes files, runs the machinery, and pushes. The operator
moves between them. The method is vendor-neutral — it works with any AI coding
assistant that can fill these surfaces, and this file names no product.

### Continuity patterns

Three patterns keep the loop coherent across seats and across time. They are
described here at method level only; each running loop keeps its own filled
contents, paths, and tooling to itself.

- **File-based inbox.** Seats exchange role-signed message files through
  per-seat inbox folders. Messages are written freely by any seat and read on
  the operator's command, so the operator stays the courier even when the seats
  write asynchronously.
- **Seat restart.** Durable role charters, plus a maintained restart checkpoint,
  plus one cold-boot file per seat, make a session ending routine recovery
  rather than an incident: a restarted seat re-reads its charter and the
  checkpoint and resumes where the loop left off.
- **Tracker mirror.** The tool-bearing seat periodically caches verbatim issue
  bodies and comments as freshness-stamped files that the credential-free
  directing seats read as spec source. The cache is provenanced — each file
  carries its stamp and the fetch command that produced it — the tracker stays
  authoritative, and a stale or body-empty file is invalid regardless of its
  stamp.

## Part II — adopting the method

The method is not specific to this project. To run your own loop, use the empty
templates in `dev-loop/` beside this file:

- Read `dev-loop/SETUP.md` first — it is soft guidance, not a rule.
- Copy `dev-loop/role-charter.template.md` once per seat you decide to run and
  fill it in.
- Adopt `dev-loop/working-agreement.template.md` for issue flow, merge
  authority, and the evidence each hop must produce.
- Adopt `dev-loop/message-format.template.md` for the ROLE → ROLE message
  convention.

Keep your FILLED copies out of the repository. The templates ship empty on
purpose — the same source-versus-instance pattern the harness uses everywhere:
the repo carries the skeleton, your working copies carry the content.

Four seats is a worked example, not a minimum. Smaller efforts may COLLAPSE
roles — one person or one seat can hold several — as long as the separation that
matters to you survives the collapse.
