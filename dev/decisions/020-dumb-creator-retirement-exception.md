# 020 — The dumb-creator law takes its first exception: superseded machinery may be RETIRED, never deleted

## Context

**Read this section in the past tense.** It describes the installer AS IT STOOD
when the exception was ruled on, which is the situation that forced the ruling;
it is not a description of HEAD. The machinery landed with `#134`, so two of the
statements below are deliberately no longer true of the code — the installer now
holds exactly one `mv`, and its header no longer uses the word ABSOLUTE. Where
each of those homes now stands is recorded under Routing in Consequences, and
that paragraph is the one to check against HEAD.

The installer is a DUMB CREATOR. It creates what is absent and edits nothing —
not an existing file, not a broken one. Surfacing and repairing broken state
belongs to the validator, to status, and to an agent working on the record; the
installer judges nothing and heals nothing. A second run finds nothing absent
and says so.

That law is not merely written down. It is structurally true of the code: the
installer performs no remove and no move operation anywhere. There is no `rm`,
no `mv`, no `rmdir`, no `unlink`, no `git rm` and no `git mv` in it. Its
file-creating verbs are a copy into a path it has just established as absent
and a here-and-now creation of empty scaffolding; its one in-place substitution
is guarded to files THIS RUN created. It writes git's own metadata besides — an
init, a day-zero commit, and the estate key that arms the hooks — but no file an
estate already holds as record or as machinery is reachable by it.

The law is stated in its ABSOLUTE form in more than one home — in `README.md`
and `estate/SPEC.md`, which both call the installer non-destructive, and again in the
installer's own header comment, where the word used is "ABSOLUTE". That is why
an exception cannot be introduced quietly, and why it is recorded here before
any machinery relies on it.

The pressure that forces the exception is renaming. A planned restructuring
renames shipped files inside a live estate — scripts and the constitution among
them. Under the law as written, an upgraded estate ends up holding BOTH names for
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

**Deduplicate.** A file can land in both halves, so the union may return it twice
before dedupe. Run against the installer as it stands, the query returns THREE
members: the ticket-grammar script, the agent definition files carrying the
model pins, and the estate's hook configuration. That list is written here as a
worked example of the query, not as a list to maintain. The generator is the
authority; if it ever disagrees with this paragraph, the generator is right and
this paragraph is stale.

**Where the generator has already corrected this paragraph, recorded rather than
quietly rewritten** (`#134`). The sentence above once said the ticket-grammar
script lands in BOTH halves — substituted into when created, explicitly not
edited when present. The generator returns it from the SUBSTITUTION half only.
Both are defensible readings of "declined-edit handler" and the shipped one is
narrower on purpose: it requires the function to TEST whether it created a file
AND to CREATE that file, and the board-widening step substitutes without ever
creating. The narrower test is what keeps the plan-printing step — which tests
the same creation flag and merely NAMES a path — out of the result, and that
false member is the one this record warns no path filter can catch. THE UNION IS
UNCHANGED: the same three members, by the same reasoning, with the hook
configuration still reachable only through the declined-edit half. Only the
attribution of one member to one half moved.

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

How the union and the ownership test fit together, since a reader can take them
for two answers to one question. The union yields CANDIDATES — every file the
installer treats as per-estate. Ownership then decides which candidates are
class 3: a candidate whose per-estate content is installer-owned is plain
machinery and may be replaced outright.

The canary for that is no longer something a person has to remember to check; it
is what the generator does, every run. It was written here as a CONDITIONAL —
"if such a handler is ever written, that is the moment the stamp became
user-owned" — and a conditional with no trigger implies somebody is assigned to
watch for it. Nobody was, which is exactly what made it inert. The machinery
landed with `#134` and the condition now computes itself, so it is described
here as a mechanism rather than an instruction:

- The version stamp has NO declined-edit handler today, because the installer
  maintains it. The query therefore does not return it, and `--upgrade` replaces
  the stamp like any other plain machinery — which is the only reason an estate
  can be upgraded at all.
- Write a declined-edit handler for that stamp, and the generator returns
  `VERSION` on the very next run. No watcher, no reminder, no interval: the file
  joins the carried-forward class the moment the CODE says it is user-owned.

The canary fires by existing rather than by being checked. Nobody is assigned to
it, and nobody needs to be.

Routing. The law is stated in its absolute form in `README.md`, in `estate/SPEC.md`,
in `estate/installing.md`, and in the installer's own header comment, and those
statements are incomplete without this record. Anyone who meets the absolute form
comes here. Amending those homes to point at this record belongs with the
machinery that implements retirement, not with the law: this record lands first
precisely so the amendment is not carried in conversation while that machinery is
built.

That amendment came due with `#134`, and this is where its state is recorded so a
reader can check the homes rather than take this paragraph's word for it. The
installer's own header no longer calls the law ABSOLUTE and names the exception in
its opening lines; `estate/SPEC.md` and `estate/installing.md` now carry the
exception beside the law they state. `README.md`'s catalogue row still describes
the installer as "the non-destructive dumb creator" with no mention of the
exception, and is the one home still owed the amendment — it could not be made in
the same change because that file was being edited elsewhere at the time.

## Status

Accepted; operator ruling, recorded here on its own issue `#133`. This is the
FIRST exception the dumb-creator law has ever taken, and it is deliberately a
STANDALONE record rather than a paragraph inside the upgrade item that needs it
— on the same reasoning that split the earlier law amendment from its machinery
(`dev/decisions/019`): a constitutional law amended in conversation evaporates, and
every seat between the ruling and the writing runs on an unrecorded amendment.
It supersedes no record. It AMENDS the dumb-creator law itself, narrowly: move
with a report, for machinery, never for records, never a delete.
