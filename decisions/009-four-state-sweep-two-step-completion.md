# 009 — Four-state ticket sweep and two-step pending completion

## Context

The tools should recognise a recommended ticket-folder pattern without forcing it
— surfacing conventions, not imposing them. But a real ticket that the init agent
could not name must not be silently misfiled, and a folder that is deliberately
not a ticket must be dismissible. A single "conforms or not" flag cannot express
all of this without either nagging forever or hiding a genuine misfile.

## Decision

Every `Tickets/` folder resolves to one of **four states**: (1) conforming +
recorded (auto-validated); (2) hand-made + recorded (silenceable yellow nudge);
(3) pending — a real ticket marked `.ticket-pending`, a **non-silenceable** yellow
that nags until a **two-step completion** (rename to a conforming name AND remove
the marker); (4) not a ticket (silent, or explicitly `.not-a-ticket`). The
**marker, not the name, is the lifecycle token**: a conforming rename alone cannot
clear a pending ticket, and `.ticket-pending` takes precedence over `.not-a-ticket`.

## Consequences

A naming choice is never blocked, but a real ticket cannot be dismissed or
silently misfiled — clearing it takes two deliberate acts. The cost is the
two-step ritual on pending tickets, which is exactly the friction that prevents a
half-finished ticket from disappearing.

## Status

Accepted. See `#36` (the SVG sheets teaching the two-step pending completion) and
the four-states passage in README's folder map.
