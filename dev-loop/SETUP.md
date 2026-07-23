# dev-loop/ — set up your own multi-role build loop

This folder is a starter kit, not a rule. It gives you empty templates for
running the multi-role method described in ../DEVELOPMENT.md. Surface, don't
impose: take what helps, leave the rest.

## Pick your seats

Decide which roles you will run. The worked example in DEVELOPMENT.md uses four
— an architect, an independent reviewer/product-owner, a mechanical
implementer, and a human operator. That is an example, not a minimum: for a
smaller effort you may COLLAPSE seats, letting one person or one seat hold
several roles, as long as the separations you care about survive the collapse.

## Copy and fill the charters

Copy `role-charter.template.md` once for each seat you decided to run, rename
the copy for that seat, and fill in its responsibilities, powers, prohibitions,
and handoff format. Adopt `working-agreement.template.md` for how issues flow,
who holds merge authority, and what evidence each hop must produce. Adopt
`message-format.template.md` for the ROLE → ROLE message convention.

## Keep filled copies out of the repository

The templates ship empty on purpose. Your FILLED charters, agreements, and
messages are instance material — keep them wherever you actually work, not in
this repository. The repo carries the skeleton; your loop carries the content.
