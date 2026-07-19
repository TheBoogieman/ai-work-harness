# Tickets

One folder per ticket, initialised from the template by the `ticket-init`
agent. The human map of the whole harness is the repository root `README.md`;
the law is `folder-structure.md`.

Nothing requires a specific ticket-folder name. Name folders however suits
your workflow. Names matching the recommended pattern
(`YYYYMM<seq>-<BOARD>-<num>`) are auto-validated; a differently-named folder
that holds a ticket record is surfaced by harness-status as a heads-up (never
blocked); non-matching names never break the tools. To use your own scheme,
edit the one pattern in `_harness/scripts/ticket-grammar.sh`.

In short: matching names are validated; non-matching ticket-bearing folders
are surfaced (WARNed), not validated; non-matching names never break the
tools. To silence the heads-up on a folder that is deliberately not a ticket,
drop a `.not-a-ticket` marker in it: `touch 'Tickets/<name>/.not-a-ticket'`.
