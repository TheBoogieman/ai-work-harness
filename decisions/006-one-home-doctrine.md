# 006 — One home per fact (the one-home doctrine)

## Context

A rule or pattern that appears in two files will, over time, be edited in one and
not the other. The two copies drift, and a later reader cannot tell which is
authoritative. The ticket-recognition regex, the branch grammar, and the ship/dev
classification are each consumed by more than one tool — prime candidates for
silent divergence.

## Decision

Each fact, pattern, or rule has **exactly one editable home**, and every other
place that needs it either sources that home or is checked against it. The
ticket-recognition pattern lives only in `_harness/scripts/ticket-grammar.sh`
(sourced by both the validator and status). The branch regex lives only in
`.github/scripts/branch-grammar.sh`, and a docs guard asserts every doc that
quotes it matches verbatim. The classification lives only in
`.github/ship-manifest.txt`.

## Consequences

There is always a single answer to "where do I change this?", and a drift guard
can mechanically prove the copies agree. The cost is a small indirection — a tool
sources or greps its home rather than inlining the value — which is the price of
never shipping two disagreeing truths.

## Status

Accepted, foundational. See `#43` (the ship/dev manifest as the one classification
home) and the docs-check grammar-drift detector that pins the branch regex to its
single home.
