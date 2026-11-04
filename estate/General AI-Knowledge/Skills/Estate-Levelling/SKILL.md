# Estate-Levelling — SKILL.md

## WHEN TO USE
Read this at the start of every levelling: bringing an installed estate up to a newer harness source
(`install.sh --upgrade`), whether the `orchestrator` runs it under a standing delegation or a default
session runs it from an operator's prompt. Trigger keywords: level the estate, levelling, upgrade the
estate, install.sh --upgrade, three-way merge, last levelled commit, new harness release, `LEFTOVER:`.
It is the runbook behind CONSTITUTION §18.1, which owns the rules; this module owns the procedure,
the commands and the traps.

## CRAFT GUIDANCE

**The rule that governs the run.** The estate's custom files trump the source (§18.1). Any file that
differs from what the source shipped belongs to the estate; the source never overwrites it, and an
upstream change reaches it only through a three-way merge in which every estate line survives. When a
line cannot be told apart as customisation or old upstream text, ask the operator. Nothing leaves the
machine except `git` against the public harness repository; every estate write waits for the
operator's yes to the diff it will make.

Work in temporary copies outside the estate (a scratch folder under the system temp root). Write
throw-away helpers there as bash or Python files rather than long one-liners (see Traps).

### 1. Paths and the record of the last levelling
- Confirm with the operator the estate root (it holds `CONSTITUTION.md`, `AGENTS.md`, `_agents/`,
  `Tickets/`) and the source checkout. A source checkout on a feature branch is switched to `main`
  only when its working tree is clean.
- Read the estate's **last levelled** line in its tools note (§2). It names the source commit this
  estate was last levelled to: the merge base for every file below. No line: prove the base (step 5).
- Open the tools note's `Standing delegation` section; with none, every approval goes to the operator.

### 2. Update the source and rehearse
- `git fetch <public remote> --tags`, `git checkout main`, `git pull <public remote> main`. Name the
  remote: a bare `git fetch` also contacts any fork remote the checkout carries.
- Report the commit and tag. Newer than the operator expected: say what it adds and wait.
- `mkdir -p <temp root>`, then `bash estate/install.sh --rehearsal --yes <temp root>/estate </dev/null`.
  It must finish with the validator and status green; delete the folder afterwards.

### 3. Dry-run, and classify every replace row by bytes, not by eye
- `bash estate/install.sh --upgrade --dry-run <estate> </dev/null`. Group the plan as create / replace /
  retire / repoint / keep.
- For each **replace** row, compare the estate copy byte for byte with the source at the base commit.
  Identical: unedited, safe to replace. Different: customised; it is restored and merged after step 4.
- Two traps in that comparison: `.gitignore`, `.gitattributes`, `README.md`, `AGENTS.md` and `LICENSE`
  ship from the source's root, not from `estate/`; and `README.md` is laid down with its links
  rewritten, so compare it with that installed form (`product_form` in `install.sh`).
- Kept files (`CONSTITUTION.md`, `AGENTS.md`, agent contracts, the two harness documents, the hook
  config, `ticket-grammar.sh`, the context pack) are never replaced; they are merged in step 5.

### 4. Upgrade, pins and quarantine
- Read every `model:` pin in `_agents/*.agent.md` first. Without a terminal that can answer prompts,
  add `--yes` with stdin from `/dev/null`: the cheap pin then comes from `ticket-scribe` and the
  second pin from `ticket-init`. Check that every created contract carries the estate's pin, never a
  `PICK-A-*` placeholder.
- Report every line about `_retired/`. Restore each customised replaced file with the `mv` the run
  printed, and confirm it is byte-identical to the estate's last commit of it.

### 5. Prove the base, then classify every shipped path
- **Prove the base** when no record names it: for each candidate commit on `main` (and any branch the
  estate was levelled from), count shipped files whose estate copy is byte-identical to that commit's
  (`git ls-tree -r` blobs against `git hash-object`). The base leaves the most unedited files
  identical. Commits whose shipped trees are identical tie as one base; break a real tie by line
  distance on the disputed files and by the estate's own git log of its last levelling.
- **Classify** each shipped path two ways: did the source change it between base and now, and does
  the estate copy equal the base, equal the new source, or neither (customised). Merge only
  *changed upstream x customised*; a file the estate never edited simply takes the upstream change.
- **A file never levelled before** (its closest upstream version is much older than the base, found
  by ranking every source commit that touched it by line distance) cannot be merged against the
  base. Put it to the operator: take the new source plus the estate's pins, keep the estate's copy, or
  hand-port the new sections. A decision, never a guess.

### 6. Merge in a temporary copy
- Build two scratch trees, base and new, with `git archive <commit> estate | tar -x` plus the root
  files. Bring both to the estate's conventions first, so the merge sees only real change:
  - section-link style: `python3 <estate>/_harness/scripts/anchor-style.py --to <estate's style>`
    over the scratch tree (an estate read in Obsidian uses `--to obsidian`);
  - the template ticket's folder, file name and board key renamed to the estate's.
- `cp <estate copy> merged; git merge-file --diff3 -L mine -L base -L upstream merged base new`.
  `--diff3` shows the base side of each conflict, which is what tells the estate's edit from upstream's.
- **Clean merge**: prove it. The change from the estate copy to the result must equal the change
  from base to new source, and base-to-estate must equal new-to-result (compare `diff` bodies, not line
  numbers).
- **Conflict**: keep the estate's side and port only the new upstream fact into the estate's wording.
  Patterns a real levelling met:
  - upstream added a sentence inside a paragraph the estate reworded: add the sentence to the
    estate's paragraph;
  - a frontmatter `tools:` or `agents:` line: keep the estate's tools, take upstream's agent list;
  - the conflict pairs the estate's rewritten block with an unrelated base neighbour (an intro
    against a navigation line): keep the estate's block and apply upstream's one-line change to the
    estate's own copy of that line, which sits outside the conflict;
  - a neighbouring-line conflict where the estate never edited the upstream line: take upstream's
    line and keep the estate's neighbour;
  - a row upstream deleted because its agent retired: the deletion wins even if the estate reworded
    the row.
- Show the operator the diff from the estate copy to the result, file by file, with a table of what
  came in and what of the estate's was kept. Write only after their yes, and refuse to write a file
  whose estate copy changed since the merge was computed.
- A changed template ticket needs its own Session Log entry through `ticket-scribe`, or the
  validator goes red. The parent passes the timestamp from `date +%Y%m%d%H%M%S`.

### 7. Shipped records the upgrade never creates
The upgrade never creates a record (anything outside `_harness/`, `_agents/`, the root files and the
two harness documents). A release that adds a skill, an index or a template file therefore reaches
the estate only by hand. List every shipped path missing from the estate; check the estate's git log
for a deliberate deletion (`git log --diff-filter=D -- <path>`) before proposing to create it; create
the rest from the new source, in the estate's link style, after approval.

### 8. Stale references
Search the estate outside `Tickets/`, `_retired/` and code checkouts for retired agent names and for
notes the release made false. Dated, append-only records (audits, retrospectives, Session Logs) stay as
written; living notes are proposed for correction. `_harness/retire-list.tsv` and the design notes'
diagram-currency entries keep old names on purpose.

### 9. Deploy, prove, record
- `bash _harness/scripts/deploy-agents.sh` from the estate, even though the upgrade deployed once:
  that copy held the unmerged contracts. Delete exactly the files on its `LEFTOVER:` lines once the
  operator approves, then confirm every deployed contract is byte-identical to `_agents/`.
- `bash _harness/scripts/check-ticket-log.sh` and `bash _harness/scripts/harness-status.sh`, both
  green; `python3 _harness/scripts/check-work-map.py` once, counting its link notes per ticket without
  fixing them (that is an `estate-auditor` batch).
- A second `--upgrade --dry-run` must print `NOTHING TO DO`. Anything else is a finding, not a pass.
- Report one line per merged file: what came in, what of the estate's was kept, and how each conflict
  was decided. Then propose the **last levelled** line for the tools note and write it after the
  operator's yes: `Last levelled: harness <tag> (<commit>), <YYYY-MM-DD>.`
- When the levelling itself produced an upstream pull request, level the estate from that branch, so
  the estate already carries the change; once the pull request merges, move the last levelled line to
  its merge commit and run the dry-run once more. It must say `NOTHING TO DO`, with no levelling.

### Traps
- **zsh history modifiers**: in zsh `"$B:e"` or `"$c:A"` apply `:e` / `:A` to the variable, so a
  `git show "$B:estate/..."` silently reads the wrong path. Write `"${B}:estate/..."`, or put the
  loop in a bash script file.
- **zsh `==`**: a bare `echo ===` is an expansion error; quote separators.
- **`$(...)` strips trailing newlines**: compare bytes with a pipe into `cmp -s -`, never through a
  captured variable.
- **The demo's Python**: the acceptance demo needs `nbformat` and `openpyxl`; put an interpreter
  that has them first on `PATH`.
- **Never-levelled files** look like heavy customisation against the base; rank their history before
  calling every difference the estate's.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(compare and read by hand, and say so). TOOLS ADVISE, NEVER GATE.

- `bash estate/install.sh --rehearsal --yes <temp>/estate </dev/null` — practice install that writes
  nothing outside its target.
- `bash estate/install.sh --upgrade --dry-run <estate>` — the plan; without `--dry-run`, the upgrade.
- `git merge-file --diff3 -L mine -L base -L upstream <merged> <base> <new>` — the three-way merge.
- `git ls-tree -r <commit>` with `git hash-object <file>` — byte comparison for proving the base.
- `python3 _harness/scripts/anchor-style.py --to <style> [--check] <files>` — section-link style.
- `bash _harness/scripts/deploy-agents.sh` — deploy contracts; prints `LEFTOVER:` lines.
- `bash _harness/scripts/check-ticket-log.sh`, `bash _harness/scripts/harness-status.sh`,
  `python3 _harness/scripts/check-work-map.py` — the proof.

Last reviewed: 2026-11-04
