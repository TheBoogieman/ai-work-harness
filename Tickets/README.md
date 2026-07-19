# Tickets

One folder per ticket, initialised from the template by the `ticket-init`
agent. The human map of the whole harness is the repository root `README.md`;
the law is `folder-structure.md`.

Nothing requires a specific ticket-folder name. Name folders however suits
your workflow — the tools recognise a recommended default pattern
(`YYYYMM<seq>-<BOARD>-<num>`) but never force it. A folder here is always in
one of four states:

1. **Matches the pattern + holds a ticket record** → auto-validated (a real,
   enforced ticket).
2. **Hand-made, holds a record, doesn't match** → `harness-status` gives a
   heads-up (WARN): rename it to match, or `touch .not-a-ticket` if it isn't
   really a ticket. Never blocked.
3. **Pending** (marked `.ticket-pending` by `ticket-init` when it couldn't
   name the ticket) → a **non-silenceable** WARN. Completing it takes two
   steps: rename the folder to a conforming name **and** remove the
   `.ticket-pending` marker; it nags until both are done. The marker, not the
   name, is the lifecycle token — a conforming rename alone never completes it,
   so a real ticket can't be silently misfiled. Takes precedence over
   `.not-a-ticket`, so a real ticket can't be dismissed.
4. **No ticket content, or marked `.not-a-ticket`** → silent.

Nothing is ever blocked — the tools nudge with yellow, never wall you off. The
two markers: `.not-a-ticket` means "this is not a ticket, leave it alone"
(silences state 2); `.ticket-pending` means "this is a real ticket awaiting
completion — rename **and** remove the marker" (non-silenceable). To use your
own naming scheme, edit the
one `TICKET_RE` line in `_harness/scripts/ticket-grammar.sh` — both the
validator and `harness-status` follow it. See `folder-structure.md` for the
full story and the hyphenated-board worked example.
