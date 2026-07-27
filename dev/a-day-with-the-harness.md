# A day with the harness — a worked example

This document follows one piece of work from the moment somebody picks it up to
the moment they put it down: what the person does, what the machinery does in
reply, and what is left on disk afterwards.

It is written for a reader who has never seen this project before. Every term it
uses is explained where it is used. You should not have to open another document
to follow it.

**It prints real output rather than describing it.** Everything below the `$`
lines is what the commands actually printed, copied from a real run. That is not
a style choice: a sentence like "the validator confirms everything is in order"
cannot be checked by a machine, so a document written that way rots quietly. This
one is executed — see *How this document is kept true* at the end.

---

## The words you will need

**The harness** is a set of small shell scripts and written rules that sit
alongside an AI coding assistant. The assistant does the work; the harness makes
the assistant leave a record a human can read later without having been in the
room.

**An estate** is one folder on your own machine holding all of that: your work
records, your notes, and the harness's own scripts. It is an ordinary git
repository with no remote — nothing is ever pushed anywhere. The estate in this
document lives at `~/Work`.

**A ticket** is one piece of work. It is a folder under `Tickets/` whose name
follows a fixed pattern — year and month, one or more letters marking its order
within that month, the name of your issue board, and the issue's number — for example
`202607A-PROJ-4021`. Inside it sits a markdown file with the same name: that file
is **the record** of the work.

**The session log** is a section at the bottom of that record. Each work session
appends one block headed `## YYYYMMDDHHMMSS - <one line saying what happened>`.
That fourteen-digit stamp is your machine's local date and time.

**A knowledge note** is anything you learned that would be expensive to learn
twice. It goes in the ticket's `AI-Knowledge/` folder as its own markdown file,
and it must be listed in that folder's `_index.md` — one line per file, saying
what the file covers.

**The validator** is `_harness/scripts/check_ticket_log.sh`. It reads the records
and refuses the ones that are broken. It judges nothing subjective: it checks
that a changed record gained a session-log entry, that the record has a
`## Current State` section, and that the knowledge index and the knowledge files
agree with each other. It prints one line per finding and exits non-zero if any
line says `FAIL:`.

**The status report** is `_harness/scripts/harness-status.sh`. It looks at the
whole estate rather than one ticket, and it never changes anything. Its lines
start with `OK:`, `NOTE:`, `WARN:` or `FAIL:`. A `WARN:` schedules work; a
`FAIL:` blocks.

**An agent** is a markdown file under `_agents/` holding instructions for the AI
assistant — one file per job. `ticket-scribe`, for instance, is the one that
writes session-log entries. In a normal day you never type the commands that
those agents run; you ask your assistant, and it does what its agent file says.
This document types them out so that you can see exactly what lands on disk.

**A context pack** is a throwaway zip of the estate's own state, with a small
list of known identifiers stripped out of it, for handing to something outside
your machine.

---

## How to read the blocks below

Inside each block, a line beginning with `$ ` is a command that was typed.
Every other line is output the machinery printed, exactly as it printed it.

Six spans differ from machine to machine and are written in angle brackets. They
are the **only** things below that are not literal:

| Span | What it is |
| --- | --- |
| `<ESTATE>` | the absolute path of your estate, e.g. `/home/you/Work` |
| `<HOW-LONG-AGO>` | git's phrasing for the age of the last commit, e.g. `3 seconds ago` |
| `<SIZE>` | a size in MiB, e.g. `0.3` |
| `<TIMESTAMP>` | a fourteen-digit local date-and-time stamp |
| `<PACK-DIR>` | the folder a context pack was written to |
| `<PACK-STAMP>` | a pack's own date-and-time stamp, e.g. `20260727-2120` |

Angle brackets also appear inside the harness's own messages — `<what it covers>`
is a blank the harness is asking *you* to fill in. Those are literal text and are
compared character for character like everything else.

One more difference is not a span but a platform quirk, and it is named here
rather than hidden. The status report builds its count of knowledge files with
the `wc` command, and the `wc` that ships with macOS pads its number with spaces
where the one on Linux does not. On a Mac that line therefore reads
`knowledge files:` followed by a run of spaces and then the number. No single
page can print both, so the check treats that run of spaces as one space — and
still compares the number itself exactly.

## What the day assumes

* An estate already exists at `~/Work`, created by the installer. Installing is a
  separate job with its own manual, `estate/installing.md`; this document starts
  the morning after.
* Every command is run from the top of the estate (`cd ~/Work`).
* Git knows who you are — the usual `user.name` and `user.email` settings.

---

## 1. Morning: ask the estate how it is

You have not opened anything yet. The first question is whether the estate is
sound, and the status report answers it. Nothing here is written to; the report
only looks.

```console
$ bash _harness/scripts/harness-status.sh
NOTE: harness version 0.1.0 (from VERSION, laid down by install.sh).
OK: work repo present; last commit <HOW-LONG-AGO>.
OK: record repo .git <SIZE> MiB (working tree <SIZE> MiB) — under the 50 MiB housekeeping threshold.
OK: hooks config parses.
OK: 999912Z-PROJ-99999 — last session 20260101000000, knowledge files: 0.
OK: estate healthy.
```

The one ticket it can see is `999912Z-PROJ-99999`, the empty template every
estate ships with. Its session-log stamp is a placeholder date. Nothing has
happened here yet.

## 2. Pick the work up

The issue you have been handed is number 4021 on a board called `PROJ`: rows are
going missing from a staging model. You start a ticket for it by copying the
template and renaming both the folder and the record inside it to the ticket's
name. When you work through your assistant, the `ticket-init` agent does this
for you and interviews you for the background; the two commands are what it
performs.

Then you ask the validator whether the estate accepts what you just made.

```console
$ cp -r Tickets/999912Z-PROJ-99999 Tickets/202607A-PROJ-4021
$ mv Tickets/202607A-PROJ-4021/999912Z-PROJ-99999.md Tickets/202607A-PROJ-4021/202607A-PROJ-4021.md
$ bash _harness/scripts/check_ticket_log.sh
OK: 202607A-PROJ-4021 validated.
```

The template ticket is not mentioned because it has not changed since the last
time it was validated — the validator only re-reads records that moved.

## 3. Do the work, and record it

You spend the morning on the staging model and find the cause: rows whose
effective date is null are dropped. That is worth keeping, so it becomes a
knowledge note. Then you record the session in the log the way the
`ticket-scribe` agent writes one: a block headed with the local timestamp, and a
line saying what happened. (That agent also refreshes the record's
`## Current State` section in the same breath. That part is prose about your own
work rather than machinery, so it is left out of this transcript.)

Then you ask the validator again.

```console
$ printf '%s\n' 'Rows with a null effective date are dropped by the staging model.' > Tickets/202607A-PROJ-4021/AI-Knowledge/staging-model-quirk.md
$ printf '\n## %s - Traced the missing rows\n- Null effective dates are dropped by the staging model.\n' "$(date +%Y%m%d%H%M%S)" >> Tickets/202607A-PROJ-4021/202607A-PROJ-4021.md
$ bash _harness/scripts/check_ticket_log.sh
FAIL: 202607A-PROJ-4021 orphan file AI-Knowledge/staging-model-quirk.md not in _index.md. Fix: echo '- staging-model-quirk.md — <what it covers>' >> '<ESTATE>/Tickets/202607A-PROJ-4021/AI-Knowledge/_index.md'
FAIL: 1 ticket(s) need attention — red blocks.
$ echo $?
1
```

This is the part worth watching. You wrote a note and did not list it, so the
next person to open the folder would find a file nobody had described. The
validator refuses, names the file, names the index it is missing from, and hands
you the exact line to run. It exits `1`, which is what "red blocks" means: a
tool wired to this exit code stops here.

Notice also what it did **not** do. It did not add the missing line for you. A
record that a machine quietly repaired is no longer a record of what happened.

## 4. Do what the red line says

```console
$ echo '- staging-model-quirk.md — null effective dates are dropped — read before editing the model' >> Tickets/202607A-PROJ-4021/AI-Knowledge/_index.md
$ bash _harness/scripts/check_ticket_log.sh
OK: 202607A-PROJ-4021 validated.
```

Green. The index now describes every file beside it.

## 5. Commit the record

The estate is a git repository, so every version of the record is kept. When you
work through an assistant, a hook commits after each write and you never type
this. By hand it is two commands, and they print nothing when they succeed.

```console
$ git add -A
$ git commit -q -m "PROJ-4021: traced the missing rows; captured the quirk"
```

## 6. Ask the estate how it is again

The same command as this morning, and the difference is the point: the day's
ticket is now part of what the estate reports on, with the session stamp you
wrote and a count of the knowledge you captured.

```console
$ bash _harness/scripts/harness-status.sh
NOTE: harness version 0.1.0 (from VERSION, laid down by install.sh).
OK: work repo present; last commit <HOW-LONG-AGO>.
OK: record repo .git <SIZE> MiB (working tree <SIZE> MiB) — under the 50 MiB housekeeping threshold.
OK: hooks config parses.
OK: 202607A-PROJ-4021 — last session <TIMESTAMP>, knowledge files: 1.
OK: 999912Z-PROJ-99999 — last session 20260101000000, knowledge files: 0.
OK: estate healthy.
```

## 7. Hand the work on

Somebody else needs the context — or a fresh assistant session does. The pack
builder bundles the estate's own state and the named ticket's record into one
zip, removing a short list of known identifiers on the way. The zip is
disposable; you can build another one whenever you like. Left to itself it lands
on your Desktop.

```console
$ bash _harness/scripts/make_context_pack.sh --ticket 202607A-PROJ-4021
OK: pack written to <PACK-DIR>/harness-pack-<PACK-STAMP>.zip (disposable — delete after upload; regenerate anytime).
NOTE: manually SKIM the zip before it leaves the machine. Automation reduces redaction errors; it does not replace the human check.
```

The second line is the harness being honest about its own limits: the stripping
is a fixed list, not a judgement, so a human still looks before anything leaves
the machine.

## 8. What is on disk at the end of the day

Four things, and you can read all of them without any tool.

```console
$ ls -1 Tickets/202607A-PROJ-4021
202607A-PROJ-4021.md
AI-Knowledge
Checks
Dump
Logs
$ cat Tickets/202607A-PROJ-4021/AI-Knowledge/_index.md
# _index.md — one line per file: `- <file>.md — <what it covers> — <when to read it>`
# Tombstones for promoted files: `- <file>.md (promoted -> General AI-Knowledge/<Topic>)`
- staging-model-quirk.md — null effective dates are dropped — read before editing the model
$ sed -n '/^## Session Log/,$p' Tickets/202607A-PROJ-4021/202607A-PROJ-4021.md
## Session Log

## 20260101000000 - Template initialised
- Created from the harness template; awaiting first real session.

## <TIMESTAMP> - Traced the missing rows
- Null effective dates are dropped by the staging model.
$ git log --format='%s'
PROJ-4021: traced the missing rows; captured the quirk
day-zero: harness estate scaffolded by install.sh
```

The ticket folder, the index describing the knowledge beside it, the session log
with the day's entry appended under the template's, and a commit history in
which the day is one line. `Checks/`, `Dump/` and `Logs/` came from the template:
`Checks/` holds a notebook and scratch queries, and the other two are for bulk
that git deliberately ignores.

---

## How this document is kept true

Every command above is run by an automatic check, in the order it appears, in a
brand-new estate built from scratch for the purpose. The check compares what each
command actually printed against what this document says it printed — character
for character, apart from the six angle-bracket spans listed near the top, each
of which is matched against a tight pattern rather than skipped.

It waits a second between the steps, and that is worth knowing because it says
something about the machinery: the validator decides whether a record has changed
by comparing whole-second file timestamps, so two acts inside the same second look
like one act to it. A person's day never does that. A check running the day back
to back would, so it pauses to keep the spacing a real day has.

The check fails if any output line differs from the line printed here, and it
fails if a block produces more or fewer lines than this document shows. A command
that has stopped working is caught by the same rule rather than by a separate
one: it stops printing what this document says it prints. When the check fails it
names this file, gives the line number in it, and prints the document's line
above the line that was actually produced.

So: if a script is renamed, if a message is reworded, if the version stamp moves,
if a check gains a line — this document goes red and says so. Prose usually rots
in silence. This prose reports when it has rotted, and the report is the
instruction to fix it: bring the block back into line with what the machinery now
prints, or change the machinery back.

The check lives in `dev/demo/cases/worked-example.case.sh` and runs as part of
the project's acceptance suite, `dev/scripts/run_demo.sh`.
