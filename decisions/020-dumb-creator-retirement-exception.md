# 020 — The dumb-creator law takes its first exception: superseded machinery may be RETIRED, never deleted

## Context

The installer is a DUMB CREATOR. It creates what is absent and edits nothing —
not an existing file, not a broken one. Surfacing and repairing broken state
belongs to the validator, to status, and to an agent working on the record; the
installer judges nothing and heals nothing. A second run finds nothing absent
and says so.

That law is not merely written down. It is structurally true of the code: the
installer performs no remove and no move operation anywhere. There is no `rm`,
no `mv`, no `rmdir`, no `unlink`, no `git rm` and no `git mv` in it. Its only
write verbs are a copy into a path it has just established as absent, a
here-and-now creation of empty scaffolding, and an in-place substitution
guarded to files THIS RUN created. Nothing an estate already holds is reachable
by it.

The law is stated in its ABSOLUTE form in more than one home — in the project's
working rules, and again in the installer's own header comment, where the word
used is "ABSOLUTE". That is why an exception cannot be introduced quietly, and
why it is recorded here before any machinery relies on it.

The pressure that forces the exception is renaming. Restructuring work renames
shipped files inside a live estate — scripts and the constitution among them.
Under the law as written, an upgraded estate ends up holding BOTH names for
every renamed file: the old one, which nothing removes, and the new one, which
the installer creates because it is absent. The estate accumulates its own
history as clutter, and a reader cannot tell which of the two the machinery
actually loads. The operator ruled that the answer is to RETIRE, not to delete.

## Decision

The dumb-creator law takes ONE exception, and this is its whole extent.

**The exception.** Superseded machinery may be RETIRED. To retire a file is to
MOVE it to a quarantine path inside the estate and REPORT that move in the run's
own summary, naming the exact command that puts it back. It stays reversible by
hand, by a user who reads the report and disagrees. DELETION REMAINS FORBIDDEN,
without exception and in every class below. Nothing the installer touches ever
stops existing.

**The bound, over THREE classes of file and not two.**

1. **RECORDS** — tickets, logs, knowledge files, everything an estate exists to
   hold. These may NEVER be touched, under any circumstance, retirement
   included. The record is the reason the law exists at all; an installer that
   can move a ticket is not a harness component, it is a hazard. This clause is
   stated as flatly as the grant because an exception that names only what it
   permits widens by reading.

2. **PLAIN MACHINERY** — a shipped file that is identical on every estate. May
   be retired. The estate's copy carries nothing the source copy does not, so
   the replacement loses nothing.

3. **PARAMETERISED MACHINERY** — a file the installer writes PER-ESTATE at
   laydown from a value the USER owns. May be retired ONLY IF those values are
   carried forward into the replacement. Otherwise it is LEFT IN PLACE and
   REPORTED for manual merge. A retirement that silently resets a user's
   parameter to the shipped default is a data loss wearing a rename's clothes.

**Who owns the parameter decides the class, and that is the test between the
second and the third.** A value the USER chose — their board key, their model
pins — makes the file that holds it parameterised machinery. A value the
INSTALLER itself owns and maintains — a version stamp it writes, should the
upgrade machinery introduce one — does NOT. A file whose only per-estate content
is installer-owned is PLAIN machinery and must be replaced, because an installer
that treated its own stamp as user configuration would refuse to update it and
no estate could ever be upgraded.

**The third class is DERIVED from the installer's own structure, never curated.**
A hand-kept list beside the installer drifts from it silently, and the drift is
invisible precisely when it matters — at an upgrade. The derivation is a UNION
of two halves, because either half alone gives a wrong answer:

- **Files substituted into on create.** The in-place substitutions the installer
  applies to files this run created.
- **Files the installer explicitly DECLINES TO EDIT when present.** Substitution
  targets alone miss the hook configuration, which is copied VERBATIM with no
  substitution at all, yet governs whether the estate commits by itself, and
  which the installer tells the user in its own voice to edit while promising to
  leave it alone.

**Key the derivation on STRUCTURE, not on wording.** Counting the installer's
untouched-file messages gives a different answer for every pattern anyone
chooses, because those messages are prose. The stable query is the ELSE-ARM OF A
LAID-DOWN FILE'S OWN CREATION TEST — that file's HANDLER — as against any line
that merely names a path. A closing-summary line that mentions a file passes a
path filter and is NOT that file's handler; a future summary naming a file the
installer does not own would inject a false member that no path filter can
catch.

**Deduplicate.** One file is both a substitution target and a declined-edit
handler, so the union returns it twice before dedupe. Run against the installer
as it stands, the query returns three members: the ticket-grammar script (in
BOTH halves — substituted into when created, explicitly not edited when
present), the agent definition files carrying the model pins (substitution
only), and the estate's hook configuration (declined-edit only). That list is
written here as a worked example of the query, not as a list to maintain. The
generator is the authority; if it ever disagrees with this paragraph, the
generator is right and this paragraph is stale.

## Consequences

What is UNCHANGED: everything except retirement. The installer still creates
only what is absent, still edits no pre-existing file, still repairs nothing and
heals nothing, and still routes a changed answer to the user rather than
applying it. Deletion is forbidden before this record and after it.

What is GAINED: an estate can be restructured without holding two names for
every renamed file, and without a user losing a board key or a model pin to an
upgrade.

What is SPENT: the law's absoluteness, which was worth something on its own. An
absolute law needs no reader to judge anything; this one now has a boundary that
someone has to apply correctly, and the ownership test in the class-3 clause is
where a future seat will get it wrong. The mitigation is that the boundary is
mechanical wherever it can be: the third class is generated from the installer,
not remembered.

The concrete failure a two-class bound would cause, stated so it is not
rediscovered the hard way. Retire the estate's ticket-grammar script and lay
down the shipped default, and the board pattern reverts to its hyphen-free form.
In an estate whose board key contains a hyphen — the flagship example in the
constitution — every existing ticket folder stops matching at once and the whole
estate reports as non-conforming, at the exact moment the user was told an
upgrade had succeeded. The model-pin case is quieter and no better: pins revert
to their placeholders, and the installer's own summary already states that an
unset placeholder means the agents will not run.

A canary for the derivation, worth stating before the machinery exists. A
version stamp should have NO declined-edit handler, because the installer
maintains it. If one is ever written, that is the moment the stamp becomes
user-owned — and a generated list catches the change on the next run instead of
waiting for somebody to notice.

Routing. The law is stated in its absolute form in the working rules and in the
installer's own header comment, and those statements are incomplete without this
record. Anyone who meets the absolute form comes here. Amending those homes to
point at this record belongs with the machinery that implements retirement, not
with the law: this record lands first precisely so the amendment is not carried
in conversation while that machinery is built.

## Status

Accepted; operator ruling, recorded here on its own issue `#133`. This is the
FIRST exception the dumb-creator law has ever taken, and it is deliberately a
STANDALONE record rather than a paragraph inside the upgrade item that needs it
— on the same reasoning that split the earlier law amendment from its machinery
(`decisions/019`): a constitutional law amended in conversation evaporates, and
every seat between the ruling and the writing runs on an unrecorded amendment.
It supersedes no record. It AMENDS the dumb-creator law itself, narrowly: move
with a report, for machinery, never for records, never a delete.
