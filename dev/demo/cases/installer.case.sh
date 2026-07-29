#!/usr/bin/env bash
# installer.case.sh — #39 installer guards: the non-destructive / dumb-creator claims are the
# richest revert surface, so every one gets a case that reds if a run WOULD edit/clobber a
# pre-existing file or leak a DEV file. SOURCED by the runner; see dev/scripts/run-demo.sh.
#
# install.sh is exercised for real into a throwaway estate (agent deploy is sent to a throwaway dir
# so nothing touches $HOME). Plain-English asserts; guard-per-bug on each claim. I39_ROOT, I39_EST
# and I39_DEPLOY are file-scope: built once, read by every sub-case, removed at the end. I39_OUT is
# file-scope too, but REWRITTEN by every in_install call: it holds the LAST install's output, so a
# sub-case that wants it must read it straight after its own call.

in_fixture() {
  echo "--- #39 installer: non-destructive, PRODUCT-only, single-schema-home, idempotent ---"
  I39_ROOT=$(mktemp -d); I39_EST="$I39_ROOT/estate"; I39_DEPLOY=$(mktemp -d)
}

# in_install — THE ONE WAY THIS CASE INVOKES THE INSTALLER when the invocation is expected to
# SUCCEED (#262). WHAT: runs install.sh with the given arguments, keeps its combined output in
# $I39_OUT for callers that need to read it, and — if it exits non-zero — prints which guard was
# running, what status the installer exited with, and the tail of what it said, then reds.
# WHY: under the runner's `set -e` a bare `bash estate/install.sh …` that fails kills the case AT
# THAT LINE, printing ZERO BYTES. Two seats hit that silence with different sabotages and neither
# got a message, because the case's own diagnostic for a failed install sits in a later sub-case
# the death never reaches. Seven of this file's eight expected-to-succeed invocations had no
# handler; one of those seven was doubly silent, dying inside a `pipefail` command substitution.
# A sabotaged installer must red with a SENTENCE, not in silence.
# IT MUST NOT SWALLOW THE FAILURE: it exits 1, so the run stays red — legibility, not tolerance.
# The interactive re-runs below that end in `|| true` are NOT routed through here: those are
# deliberately allowed to exit non-zero and their sub-case asserts on the output instead. Nor is
# the rc-capturing call in [missing-value-audible], whose exit status IS that guard's subject.
in_install() {   # $1 = guard name to report under; $2.. = install.sh's own arguments
  local guard="$1"; shift
  local rc=0
  I39_OUT="$I39_ROOT/install.out"
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh "$@" >"$I39_OUT" 2>&1 || rc=$?
  # `if` rather than `[ … ] && return`: a bare test as the last command of a function would make
  # the function's own status the test's, which under `set -e` is a second way to die quietly.
  if [ "$rc" -eq 0 ]; then return 0; fi
  echo "BUG [$guard]: install.sh EXITED rc=$rc — invoked as: install.sh $*"
  echo "    The installer failed, so the [$guard] guard never ran."
  # Say which it was rather than printing an empty heading: a silent failure is itself the most
  # useful thing to report, and a "last output was:" heading with nothing under it claims a tail
  # that does not exist.
  if [ -s "$I39_OUT" ]; then
    echo "    Its last output was:"
    tail -5 "$I39_OUT" | sed 's/^/      /'
  else
    echo "    It printed NOTHING — the installer failed silently."
  fi
  exit 1
}

# in_shipped_paths / in_dev_paths — the two halves of the tree, DERIVED the way install.sh derives
# them (#282): everything under estate/ plus the five root files an external system requires at the
# repository root is PRODUCT; every other tracked file is DEV. The ship manifest that used to
# answer both questions is gone, so these guards ask the tree directly. The rule is RESTATED here
# rather than imported from install.sh on purpose — a guard that called the code under test could
# not tell a broken rule from a broken installer.
in_shipped_paths() {
  git ls-files | while IFS= read -r in_p; do
    case "$in_p" in
      estate/*|README.md|AGENTS.md|LICENSE|.gitignore|.gitattributes) printf '%s\n' "$in_p" ;;
    esac
  done
}
in_dev_paths() {
  git ls-files | while IFS= read -r in_p; do
    case "$in_p" in
      estate/*|README.md|AGENTS.md|LICENSE|.gitignore|.gitattributes) ;;
      *) printf '%s\n' "$in_p" ;;
    esac
  done
}

# in_product_count — how many of the DERIVED PRODUCT files actually exist in an estate.
# THE SUBJECT-EXISTS PRIMITIVE (#264). WHY it is needed: every guard below concludes something
# about an installed estate's CONTENTS, and an empty result set carries two meanings — "nothing
# found" and "nothing looked at". A guard that cannot tell them apart reports success about an
# estate that was never created. Counting the PRODUCT files that DID arrive separates the two.
# Derived paths carry the source tree's `estate/` prefix, which install.sh strips when it lays
# them down, so strip it here too. The total is read at run time and never hard-coded: a
# number baked into this file would silently go stale the next time a shipped file is added.
in_product_count() {   # $1 = estate dir; prints how many derived PRODUCT files are present
  local est="$1" p rel n=0
  while IFS= read -r p; do
    rel=${p#estate/}
    if [ -e "$est/$rel" ]; then n=$((n + 1)); fi
  done < <(in_shipped_paths)
  printf '%s\n' "$n"
}

# (l) installer-ran (#264): THE ASSERTION THAT THE INSTALLER DID SOMETHING. Nothing in this case
#     used to ask. What ended the run when the installer was neutralised was an unguarded write
#     into a directory that was never created — an accident, not a check — and an accident is not
#     an assertion: it depends on a later sub-case happening to touch the missing estate, so it
#     moves or disappears whenever that sub-case is edited. This asks the question directly, on
#     its OWN fresh estate so it depends on no other sub-case, and reds by name when the answer
#     is no. Deliberately NOT an expected-count check: the claim is "the installer laid something
#     down", not "the installer laid down exactly N files", which would be a claim about the
#     size of the shipped set and would go stale the next time a file joins it.
in_installer_ran() {
  local i39_ran i39_n
  i39_ran="$I39_ROOT/ranest"
  in_install installer-ran --yes "$i39_ran"
  i39_n=$(in_product_count "$i39_ran")
  [ "$i39_n" -gt 0 ] \
    || { echo "BUG [installer-ran]: install.sh --yes exited 0 but laid down NONE of the PRODUCT" \
           "files the derivation names — the installer ran and did nothing"; exit 1; }
  echo "  ok [installer-ran] — the installer created the estate ($i39_n PRODUCT files present)"
}

# (v) no-version-claim (#298): A FRESH ESTATE STATES NO VERSION, in either of the two places one
#     could survive. Deleting the stamp and deleting the sentences that printed it are separate
#     mistakes, and either one alone leaves the claim half-made — a shipped VERSION file nothing
#     prints is still a number the user finds and believes, and a summary line printing "unknown"
#     over an estate with no stamp is the machinery talking about a fact it does not have. So both
#     halves are asserted: no VERSION at the estate root, and no version claim anywhere in what
#     the install said.
#     ON ITS OWN FRESH ESTATE, so it depends on no other sub-case and reads an $I39_OUT that
#     nothing else has rewritten under it.
#     THE OUTPUT PATTERN IS DELIBERATELY BROAD — any line matching "version", case-insensitively.
#     A grep for the exact old wording ("Harness version:") would pass the day somebody prints a
#     release number a different way, and printing it a different way is precisely the failure
#     this item exists to prevent. ONE line is excluded, and it is excluded because it is a claim
#     about the USER'S EDITOR rather than about this harness: deploy-agents.sh tells them to verify
#     the discovery directory for their Copilot version.
#     REVERT-PROVABLE BOTH WAYS: restore estate/VERSION and the file half reds; restore
#     print_summary_version in install.sh and the output half reds, quoting the line it found.
in_no_version_claim() {
  local i39_nv i39_hits
  i39_nv="$I39_ROOT/nvest"
  in_install no-version-claim --yes "$i39_nv"
  [ ! -e "$i39_nv/VERSION" ] \
    || { echo "BUG [no-version-claim]: the installed estate holds a VERSION file. Nothing in the" \
           "machinery states a version (#298) — a tag is this project's only version artifact"; \
         exit 1; }
  i39_hits=$(grep -i 'version' "$I39_OUT" | grep -v 'Copilot version' || true)
  [ -z "$i39_hits" ] \
    || { echo "BUG [no-version-claim]: the install PRINTED a version claim. An estate makes no"; \
         echo "    claim it cannot keep, and a release number it has no way to check is exactly"; \
         echo "    that — it was wrong six times before anyone looked. What it printed:"; \
         printf '%s\n' "$i39_hits" | sed 's/^/      /'; exit 1; }
  echo "  ok [no-version-claim] — a fresh estate holds no VERSION file and the install printed no" \
    "version claim"
}

# (a) single schema home: install.sh must carry NO hook-schema literal (it copies from the one
#     home, hooks.example.json, by path). A second literal here is the two-homes finding.
in_schema_one_home() {
  grep -qE '"(sessionStart|postToolUse|sessionEnd|timeoutSec)"' estate/install.sh \
    && { echo "BUG [schema-one-home]: install.sh carries a hook-schema literal — the schema must" \
           "live only in estate/_harness/hooks/hooks.example.json"; exit 1; }
  echo "  ok [schema-one-home] — install.sh carries no schema literal (single home:" \
    "hooks.example.json)"
}

# (b) PRODUCT-only (#43 cond 2 / #39): a fresh --yes install lays down zero DEV files.
#     ITS CLAIM IS "the installer ships only PRODUCT files"; the DEV scan below tests "are there
#     DEV files here". Those two diverge on any estate that came out EMPTY — a directory that was
#     never created contains zero DEV files vacuously — and this guard used to print success on
#     exactly that (#264). It now establishes its SUBJECT before concluding anything about the
#     subject's contents: no PRODUCT file present means there is nothing to scan, and "no DEV
#     files" would be an answer to the easier question rather than to its own.
in_product_only() {
  local i39_leak=0 d i39_n
  in_install clean-install --yes "$I39_EST"
  i39_n=$(in_product_count "$I39_EST")
  [ "$i39_n" -gt 0 ] \
    || { echo "BUG [product-only]: nothing to scan — the estate holds ZERO of the PRODUCT files" \
           "the derivation names, so 'contains no DEV files' would be vacuously true"; exit 1; }
  while IFS= read -r d; do
    if [ -e "$I39_EST/$d" ]; then echo "  DEV leak: $d"; i39_leak=1; fi
  done < <(in_dev_paths)
  [ "$i39_leak" -eq 0 ] \
    || { echo "BUG [product-only]: a DEV file reached the installed estate"; exit 1; }
  # The success line says what was MEASURED, not the broader claim: an estate that demonstrably
  # holds PRODUCT files, and zero DEV files among them.
  echo "  ok [product-only] — installed estate holds $i39_n PRODUCT files and zero DEV files"
}

# (b2) estate-root-tracked (#140): every ROOT-PINNED product file the installer lays down must be
#      TRACKABLE in the estate it lands in. This is the failure that ships silently and looks fine.
#      The shipped `.gitignore` denies everything at the root and re-admits named files, so the
#      estate's own documents are tracked only because a line names each one. Rename a document and
#      leave its line behind and the file is still on disk, the estate still reports healthy, and
#      the record has silently stopped covering it — including the constitution.
#
#      IT ASKS THE QUESTION STRUCTURALLY, so it never needs editing when a name changes. The subject
#      is derived: the product paths with no directory component, which is the same "root-pinned"
#      shape upgrade_is_machinery uses. `git check-ignore` is the only thing that can answer this —
#      a grep for the expected line would be a restatement of the whitelist, not a test of it, and
#      would pass on a line that git parses differently from the way the grep read it.
#
#      `--no-index` IS LOAD-BEARING AND THIS GUARD WAS WRITTEN WITHOUT IT FIRST. By default
#      check-ignore says nothing about a path that is already in the index, and the installer
#      commits the estate it creates — so every file this guard asks about is tracked by the time
#      it asks, and the first version returned "not ignored" for all twelve with the whitelist
#      deliberately broken underneath it. It reported ok twice on a sabotaged estate. `--no-index`
#      is git's own answer to exactly that question ("why did this path become tracked when the
#      rules say ignore"), and it is what makes the answer about the WHITELIST rather than about
#      what happens to be staged.
#
#      WATCHED FAILING: with `--no-index` in place, putting the three pre-#140 whitelist lines back
#      into an installed estate reds this guard by name on all three renamed documents.
in_estate_root_tracked() {
  local i39_p i39_rel i39_seen=0 i39_ignored=0 i39_rc
  # THE TOOL IS ASSERTED ABLE TO ANSWER (#269). check-ignore exits 0 when the path IS ignored, 1
  # when it looked and it is not, and 128 when it could not look at all — and this guard reads
  # "not zero" as the clean answer, so an estate with no git repo in it would report every file
  # fine while nothing had been examined. The repo is established before the loop, and a 128 from
  # inside the loop is caught separately below rather than being counted as clean.
  git -C "$I39_EST" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "BUG [estate-root-tracked]: $I39_EST is not a git repository, so nothing can be" \
           "asked about what its whitelist ignores — and 'nothing is ignored' is what this guard" \
           "would print. The installer is supposed to create the record repo; it did not."; exit 1; }
  # THE SUBJECT COMES FIRST. An estate that was never created has no root-pinned file to be
  # ignored, so "nothing was ignored" would be the same answer as a clean whitelist.
  while IFS= read -r i39_p; do
    i39_rel=${i39_p#estate/}
    case "$i39_rel" in */*) continue ;; esac      # root-pinned only: no directory component
    [ -e "$I39_EST/$i39_rel" ] || continue
    i39_seen=$((i39_seen + 1))
    i39_rc=0; git -C "$I39_EST" check-ignore -q --no-index -- "$i39_rel" || i39_rc=$?
    if [ "$i39_rc" -eq 0 ]; then
      echo "  IGNORED at the estate root: $i39_rel"
      i39_ignored=$((i39_ignored + 1))
    elif [ "$i39_rc" -gt 1 ]; then
      echo "BUG [estate-root-tracked]: git check-ignore exited $i39_rc on '$i39_rel' — it could" \
        "not look, which is not the same answer as 'this file is inside the record'."
      exit 1
    fi
  done < <(in_shipped_paths)
  [ "$i39_seen" -gt 0 ] \
    || { echo "BUG [estate-root-tracked]: the estate holds ZERO root-pinned PRODUCT files, so" \
           "'none of them is ignored' would be vacuously true — the installer laid nothing down"; \
         exit 1; }
  [ "$i39_ignored" -eq 0 ] \
    || { echo "BUG [estate-root-tracked]: $i39_ignored root-pinned PRODUCT file(s) named above" \
           "are IGNORED in the installed estate — they are on disk but OUTSIDE the record, and the" \
           "estate will still report healthy. Add each one's re-include to the ESTATE block of" \
           ".gitignore (a renamed file needs its whitelist line renamed with it)."; exit 1; }
  echo "  ok [estate-root-tracked] — all $i39_seen root-pinned PRODUCT files at the estate root" \
    "are inside the record (none ignored)"
}

# (c) dumb creator (cond 2, ABSOLUTE): a pre-existing (corrupted) file is byte-UNCHANGED by a
#     re-run. Compare with cmp against a snapshot (portable — no sha256sum, which stock macOS
#     lacks).
in_dumb_creator() {
  echo "GARBAGE" > "$I39_EST/AGENTS.md"; cp "$I39_EST/AGENTS.md" "$I39_ROOT/agents.snapshot"
  in_install dumb-creator --yes "$I39_EST"
  cmp -s "$I39_ROOT/agents.snapshot" "$I39_EST/AGENTS.md" \
    || { echo "BUG [dumb-creator]: install EDITED a pre-existing file (AGENTS.md changed) — it" \
           "must create only what is absent"; exit 1; }
  echo "  ok [dumb-creator] — pre-existing file left byte-unchanged (creates only what is absent)"
}

# (d) idempotency: a re-run finds nothing absent and creates zero.
in_idempotent_rerun() {
  local i39_plan
  # This call was the DOUBLY silent one (#262): it ran inside a `$( … | grep | head )` command
  # substitution, so under `pipefail` a failed install AND a grep that matched nothing each killed
  # the case with no message and no output — the installer's own words went into the pipe. Routing
  # it through in_install gives the first case a sentence; reading the kept output with `|| true`
  # gives the second one, because an empty $i39_plan now reaches the named assertion below instead
  # of aborting above it.
  in_install idempotent-rerun --yes "$I39_EST"
  i39_plan=$(grep -oE 'PRODUCT files to create: [0-9]+' "$I39_OUT" | head -1 || true)
  [ "$i39_plan" = "PRODUCT files to create: 0" ] \
    || { echo "BUG [idempotent-rerun]: a re-run wanted to create files ($i39_plan)"; exit 1; }
  echo "  ok [idempotent-rerun] — re-run creates nothing (nothing absent)"
}

# (e) --dry-run touches nothing: a dry-run against a fresh path must not create it.
in_dry_run() {
  local i39_fresh
  i39_fresh="$I39_ROOT/dryrun-never"
  in_install dry-run --dry-run --yes "$i39_fresh"
  [ ! -e "$i39_fresh" ] \
    || { echo "BUG [dry-run]: --dry-run created the target dir — it must touch nothing"; exit 1; }
  echo "  ok [dry-run] — --dry-run plans without touching the filesystem"
}

# (f) re-run-board (#39 v3, subsumes the v2 re-run-identity): on a re-run of an established estate
#     the board key is OFFERED as the default (review loop), and Enter-through reports it. Establish
#     a board via a real non-template ticket, re-run all-Enter, and assert BOTH the offered default
#     (the hint, on stderr) and the reported summary value are the established board.
in_board_default() {
  local i39_re i39_bhint
  i39_re="$I39_ROOT/reest"
  in_install board-default --yes "$i39_re"
  mkdir -p "$i39_re/Tickets/202607A-XRAY-1"; : > "$i39_re/Tickets/202607A-XRAY-1/202607A-XRAY-1.md"
  printf '\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh "$i39_re" \
    >"$I39_ROOT/re.out" 2>"$I39_ROOT/re.err" || true
  i39_bhint=$(grep -oE 'ACCEPT DEFAULT: [A-Za-z0-9-]+' "$I39_ROOT/re.err" | head -1 \
    | sed 's/.*: //')
  [ "$i39_bhint" = "XRAY" ] \
    || { echo "BUG [board-default]: re-run did NOT offer the established board as the default" \
           "(got '$i39_bhint', want XRAY)"; exit 1; }
  grep -qE 'board key += +XRAY' "$I39_ROOT/re.out" \
    || { echo "BUG [board-default]: summary did not report the established board (XRAY):"; \
         grep -i 'board key' "$I39_ROOT/re.out"; exit 1; }
  echo "  ok [board-default] — established board offered as the default and reported (XRAY)"
}

# (h) re-run-models: an established model pin is OFFERED as the default on a re-run. Set the cheap
#     tier's reference agent (doc-writer) to a marker, re-run, assert the cheap-model prompt (the
#     2nd ACCEPT DEFAULT) offers it. The awk-rewrite-to-tmp+mv is BSD-portable (no in-place edit).
in_model_pin_offered() {
  local i39_m i39_dw i39_mhint
  i39_m="$I39_ROOT/mest"
  in_install model-pin-offered --yes "$i39_m"
  i39_dw="$i39_m/_agents/doc-writer.agent.md"
  awk '/^model:/{print "model: MZAP"; next} {print}' "$i39_dw" > "$I39_ROOT/dw.tmp" \
    && mv "$I39_ROOT/dw.tmp" "$i39_dw"
  printf '\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh "$i39_m" \
    2>"$I39_ROOT/m.err" >/dev/null || true
  i39_mhint=$(grep -oE 'ACCEPT DEFAULT: [A-Za-z0-9-]+' "$I39_ROOT/m.err" | sed -n '2p' \
    | sed 's/.*: //')
  [ "$i39_mhint" = "MZAP" ] \
    || { echo "BUG [model-pin-offered]: re-run did NOT offer the established cheap model pin (got" \
           "'$i39_mhint', want MZAP)"; exit 1; }
  echo "  ok [model-pin-offered] — established model pin offered as the default (MZAP)"
}

# (i) change-routing: a re-run answer that DIFFERS from established is ROUTED, never applied. Re-run
#     answering a different board; assert ticket-grammar.sh is BYTE-UNCHANGED and the warn names the
#     file to edit. Revert-provable: a version that edits the file (or omits the warn) reds.
in_change_routed() {
  local i39_cr i39_crout
  i39_cr="$I39_ROOT/crest"
  in_install change-routed --yes "$i39_cr"
  cp "$i39_cr/_harness/scripts/ticket-grammar.sh" "$I39_ROOT/tg.snap"
  i39_crout=$(printf 'NEWB\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" \
    bash estate/install.sh "$i39_cr" 2>&1 || true)
  cmp -s "$I39_ROOT/tg.snap" "$i39_cr/_harness/scripts/ticket-grammar.sh" \
    || { echo "BUG [change-routed]: install EDITED ticket-grammar.sh on a re-run change — it must" \
           "route, not apply"; exit 1; }
  printf '%s\n' "$i39_crout" | grep -qE 'WARN.*board key' \
    || { echo "BUG [change-routed]: a changed board key did not WARN + route"; exit 1; }
  printf '%s\n' "$i39_crout" | grep -q 'ticket-grammar.sh' \
    || { echo "BUG [change-routed]: the route did not name the file to edit (ticket-grammar.sh)"; \
         exit 1; }
  echo "  ok [change-routed] — a changed answer WARNs + names the file, edits nothing"
}

# (j) workspace-derived: the workspace-root QUESTION is gone; the summary line is derived from the
#     real install target, always true by construction.
in_workspace_derived() {
  local i39_ws i39_wsabs i39_wsline
  i39_ws="$I39_ROOT/wsest"
  printf '\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh "$i39_ws" \
    >"$I39_ROOT/ws.out" 2>"$I39_ROOT/ws.err" || true
  grep -qi 'Workspace root' "$I39_ROOT/ws.err" \
    && { echo "BUG [workspace-derived]: a 'Workspace root' question is still asked — it must be" \
           "removed"; exit 1; }
  i39_wsabs="$(cd "$i39_ws" && pwd)"
  i39_wsline=$(grep -oE 'workspace root += +[^ ]+' "$I39_ROOT/ws.out" | head -1 \
    | sed -E 's/.*= +//')
  [ "$i39_wsline" = "$i39_wsabs" ] \
    || { echo "BUG [workspace-derived]: summary workspace root ('$i39_wsline') != install target" \
           "('$i39_wsabs')"; exit 1; }
  echo "  ok [workspace-derived] — workspace root derived from the target, no question asked"
}

# (g) prompt-default truthfulness (#39 v2): the "[PRESS ENTER TO ACCEPT DEFAULT: <v>]" hint must
#     name the SAME value the script uses on empty input. Drive a fresh install with all-Enter
#     stdin, then assert the board prompt's advertised default equals the board the summary reports.
#     Single-sourced in ask(), so they must match; a hard-coded mismatched hint reds this.
in_prompt_default() {
  local i39_id i39_hint i39_used
  i39_id="$I39_ROOT/idest"
  printf '\n\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh "$i39_id" \
    >"$I39_ROOT/id.out" 2>"$I39_ROOT/id.err" || true
  i39_hint=$(grep -oE 'ACCEPT DEFAULT: [A-Za-z0-9._/-]+' "$I39_ROOT/id.err" | head -1 \
    | sed 's/.*: //')
  i39_used=$(grep -oE 'board key += +[A-Za-z0-9-]+' "$I39_ROOT/id.out" | head -1 \
    | sed -E 's/.*= +//')
  [ -n "$i39_hint" ] && [ "$i39_hint" = "$i39_used" ] \
    || { echo "BUG [prompt-default]: the board prompt advertised default '$i39_hint' but" \
           "Enter used '$i39_used' — the hint is a lie"; exit 1; }
  echo "  ok [prompt-default] — the Enter-to-accept hint names the value actually used ($i39_hint)"
}

# (k) missing-value-audible (#200): on an ESTABLISHED estate missing an agent file, detect_model
#     returned non-zero; under install.sh's `set -euo pipefail` the command substitution that
#     assigned it killed the run with ZERO output, one line ABOVE the placeholder fallback written
#     for exactly that case — so the fallback could never execute.
#     WHAT THIS CASE MEASURES IS REACHABILITY, NOT THAT A MESSAGE APPEARED. Asserting a message
#     would be the cheaper question: a line can print while the fallback below it still never runs.
#     The load-bearing assertion is the SUMMARY'S CHEAP-PIN VALUE — PICK-A-CHEAP-MODEL can only
#     reach that line if the fallback ASSIGNMENT itself executed. Two fixture facts stop that value
#     arriving by any other route: ticket-grammar.sh is present (so the run takes the ESTABLISHED
#     branch, not the fresh branch that placeholders both tiers), and the sonnet pin is set to a
#     marker the run must DETECT — the summary carrying marker AND placeholder side by side proves
#     the established branch ran and that only the cheap tier fell back. The stderr check at the
#     end is a SEPARATE, WEAKER claim (the run said WHICH file it could not read); it is not what
#     proves reachability, and it would still pass on code whose fallback never ran.
in_missing_value_audible() {
  local i39_mv i39_mvti i39_mvrc i39_mvbytes
  i39_mv="$I39_ROOT/mvest"
  in_install missing-value-audible --yes "$i39_mv"
  # Marker on the sonnet tier's reference agent; awk-to-tmp+mv is BSD-portable (no in-place edit).
  i39_mvti="$i39_mv/_agents/ticket-init.agent.md"
  awk '/^model:/{print "model: MVSONNET"; next} {print}' "$i39_mvti" > "$I39_ROOT/mvti.tmp" \
    && mv "$I39_ROOT/mvti.tmp" "$i39_mvti"
  rm -f "$i39_mv/_agents/doc-writer.agent.md"   # THE FIXTURE: one agent file absent
  [ -e "$i39_mv/_harness/scripts/ticket-grammar.sh" ] \
    || { echo "BUG [missing-value-audible]: fixture is not an ESTABLISHED estate — the" \
           "guard would"; \
         echo "    be testing the fresh branch, which placeholders both tiers anyway"; exit 1; }
  set +e
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh --yes "$i39_mv" \
    >"$I39_ROOT/mv.out" 2>"$I39_ROOT/mv.err"
  i39_mvrc=$?
  set -e
  i39_mvbytes=$(( $(wc -c <"$I39_ROOT/mv.out") + $(wc -c <"$I39_ROOT/mv.err") ))
  [ "$i39_mvrc" -eq 0 ] \
    || { echo "BUG [missing-value-audible]: install EXITED rc=$i39_mvrc, one agent file absent,"; \
         echo "    emitting $i39_mvbytes bytes of output — a silent exit is the defect"; exit 1; }
  # THE REACHABILITY ASSERTION: the fallback's VALUE arrived in the summary.
  grep -qE 'cheap model pin += +PICK-A-CHEAP-MODEL' "$I39_ROOT/mv.out" \
    || { echo "BUG [missing-value-audible]: the placeholder fallback never RAN — no cheap-pin"; \
         grep -i 'model pin' "$I39_ROOT/mv.out"; exit 1; }
  # ...and the marker beside it proves the established branch is what produced that placeholder.
  grep -qE 'sonnet model pin += +MVSONNET' "$I39_ROOT/mv.out" \
    || { echo "BUG [missing-value-audible]: established sonnet pin not detected — the run did" \
           "not"; \
         echo "    take the established branch, so the cheap placeholder proves nothing"; exit 1; }
  # The separate, weaker claim: the run SAID which value it could not read.
  grep -q 'doc-writer.agent.md' "$I39_ROOT/mv.err" \
    || { echo "BUG [missing-value-audible]: the run never named the unreadable agent file"; \
         exit 1; }
  echo "  ok [missing-value-audible] — missing value: fallback REACHED (value reaches the summary)"
}

# ================================================================================================
# --- #134 UPGRADE MODE — the dumb-creator law's one exception -----------------------------------
# ================================================================================================
# SEVEN guards over ONE fixture, because the fixture is the expensive part of this family: a
# scratch SOURCE distribution built from this tree, an estate installed from it, that estate
# CUSTOMISED, and then the source moved on a version — a rename DECLARED in the shipped retire
# list, plus an upstream change to a plain machinery file.
#
# WHY THE CUSTOMISATION IS NOT DECORATION. A fresh estate holds the shipped defaults for
# everything, so an upgrade that silently reset somebody's board pattern, model pins and hook
# configuration would pass perfectly against one. Widening the grammar, moving a model pin off its
# placeholder and editing the hook config is what lets these guards fail in the way that matters.
#
# WHAT THEY DO NOT PROVE, stated here rather than left to be assumed: a scratch estate has no
# months of accumulated tickets, no dirty working tree, no long history and no hand-made folders.
# These guards prove the upgrade's LOGIC. They say nothing about a real installation.
#
# UP_SRC / UP_EST / UP_OUT are file-scope, built once by in_upgrade_fixture and read by every
# guard below; they live under $I39_ROOT so the case's existing teardown removes them.

# in_up_run — THE ONE WAY THESE GUARDS INVOKE THE SCRATCH INSTALLER when it is expected to
# SUCCEED. Same reason in_install exists above: under the runner's `set -e` a bare failing install
# kills the case AT THAT LINE and prints zero bytes, and a guard that dies silently is
# indistinguishable from one that was never written.
in_up_run() {   # $1 = guard name to report under; $2.. = install.sh's own arguments
  local guard="$1" rc=0; shift
  UP_OUT="$I39_ROOT/up.out"
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash "$UP_SRC/estate/install.sh" "$@" \
    >"$UP_OUT" 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then return 0; fi
  echo "BUG [$guard]: the scratch installer EXITED rc=$rc — invoked as: install.sh $*"
  echo "    The install failed, so the [$guard] guard never ran. Its last output was:"
  tail -6 "$UP_OUT" | sed 's/^/      /'
  exit 1
}

# in_upgrade_fixture — build the scratch source, install an estate from it, customise it, then
# advance the source by one version. The source is copied from `git ls-files` rather than from a
# hand-written path list, so a file added to this repository is in the fixture the day it lands.
in_upgrade_fixture() {
  local f
  UP_SRC="$I39_ROOT/upsrc"; UP_EST="$I39_ROOT/upest"
  while IFS= read -r f; do
    mkdir -p "$UP_SRC/$(dirname "$f")"; cp -p "$f" "$UP_SRC/$f"
  done < <(git ls-files)
  # THE SCRATCH SOURCE IS GIT-INITIALISED, because install.sh now derives the shipped set from
  # the git index (#282) and a bare directory copy has none — the installer would find nothing
  # to lay down. `add -f` because the copy carries this repository's whitelist .gitignore,
  # which would otherwise ignore most of what was just copied in; the set being forced is
  # exactly the set `git ls-files` handed over, so nothing untracked can enter this way.
  git -C "$UP_SRC" init -q
  git -C "$UP_SRC" add -A -f
  in_up_run upgrade-fixture --yes "$UP_EST"
  in_up_customise
  in_up_advance_source
}

# in_up_customise — the three settings a user owns, moved off their shipped defaults, and a record
# written by hand. Snapshots are taken so the assertions below are BYTE comparisons rather than
# greps: a grep can pass on a file the upgrade rewrote around the pattern it looked for.
# The rewrite-to-tmp+mv idiom is BSD-portable — stock macOS sed has no GNU-style in-place edit.
in_up_customise() {
  UP_TG="$UP_EST/_harness/scripts/ticket-grammar.sh"; UP_DW="$UP_EST/_agents/doc-writer.agent.md"
  UP_HOOK="$UP_EST/.github/hooks/harness.json"; UP_REC="$UP_EST/General AI-Knowledge/up-note.md"
  sed 's/\[A-Z\]\[A-Z0-9\]\*/[A-Z][A-Z0-9-]*/' "$UP_TG" > "$I39_ROOT/tg.t" \
    && mv "$I39_ROOT/tg.t" "$UP_TG"
  awk '/^model:/{print "model: UPCHEAP"; next} {print}' "$UP_DW" > "$I39_ROOT/dw.t" \
    && mv "$I39_ROOT/dw.t" "$UP_DW"
  sed 's/"timeoutSec": 60/"timeoutSec": 137/' "$UP_HOOK" > "$I39_ROOT/hk.t" \
    && mv "$I39_ROOT/hk.t" "$UP_HOOK"
  printf '# a hand-made note\nLast reviewed: 2026-01-01\nnobody but me put this here\n' > "$UP_REC"
  # A PRE-#298 ESTATE HOLDS A VERSION STAMP, and this line is what makes UP_EST one. The scratch
  # source stopped shipping VERSION when #298 deleted it, so an estate installed from that source
  # has none — and [upgrade-retires-version] below would then be asserting about a file that was
  # never there, which is a vacuous pass (#269) rather than a check. Planted BEFORE the upgrade
  # runs, exactly as an estate laid down by an older release would be carrying it.
  printf '0.1.0\n' > "$UP_EST/VERSION"
  # THE RECORD GUARD'S SUBJECT HAS TO BE ONE THE UPGRADE COULD ACTUALLY REACH. A hand-made file
  # under a knowledge folder is not a shipped path, so no version of this installer would ever
  # consider it and asserting it survived proves nothing. The SHIPPED TEMPLATE TICKET is the
  # subject that bites: it IS a shipped path, so only the record test stops it being replaced —
  # and editing it here is what makes the estate's copy differ from the source's, which is the
  # condition under which a replacement would happen. A user annotating their example ticket is
  # the most ordinary thing in this estate.
  UP_TICK="$UP_EST/Tickets/999912Z-PROJ-99999/999912Z-PROJ-99999.md"
  printf '\n## 20260101000001 - my own note on the example ticket\n- I edited this.\n' >> "$UP_TICK"
  # THE SOUNDNESS CHECK IS TAKEN HERE, BEFORE THE UPGRADE RUNS, and that placement is the point.
  # Asked afterwards it cannot tell "the fixture was never set up" from "the upgrade overwrote the
  # ticket with the source's copy" — the two leave identical bytes on disk, and the second is the
  # data loss the guard exists to catch. Asked now, only the first is possible.
  cmp -s "$UP_TICK" "$UP_SRC/estate/Tickets/999912Z-PROJ-99999/999912Z-PROJ-99999.md" \
    && { echo "BUG [upgrade-record-untouched]: fixture unsound — the estate's ticket already"; \
         echo "    matches the source's, so nothing would replace it whether a record test"; \
         echo "    exists or not, and the guard below would be asserting a coincidence"; exit 1; }
  # THE RE-POINT SUBJECT (#287). retrospective.agent.md is a carried-forward file (it holds a model
  # pin) that NAMES the script this fixture is about to rename — so it is the one file here that is
  # both protected by KEEP and made wrong by the rename, which is exactly the defect. Its pin is
  # moved off the shipped default for the same reason the others are: the guard has to be able to
  # tell "the path was re-pointed" from "the whole file was re-derived from source".
  UP_RETRO="$UP_EST/_agents/retrospective.agent.md"
  awk '/^model:/{print "model: UPRETRO"; next} {print}' "$UP_RETRO" > "$I39_ROOT/rt.t" \
    && mv "$I39_ROOT/rt.t" "$UP_RETRO"
  grep -q '_harness/scripts/retro-stats.sh' "$UP_RETRO" \
    || { echo "BUG [upgrade-repoints]: fixture unsound — the agent contract does not name the"; \
         echo "    script this fixture renames, so there is no stale path for the upgrade to"; \
         echo "    re-point and the guard below would assert nothing"; exit 1; }
  cp -p "$UP_TG" "$I39_ROOT/snap.tg"; cp -p "$UP_DW" "$I39_ROOT/snap.dw"
  cp -p "$UP_HOOK" "$I39_ROOT/snap.hk"; cp -p "$UP_REC" "$I39_ROOT/snap.rec"
  cp -p "$UP_TICK" "$I39_ROOT/snap.tick"; cp -p "$UP_RETRO" "$I39_ROOT/snap.retro"
  return 0
}

# in_up_advance_source — the release the estate is about to receive: a RENAME (declared in the
# retire list, never inferred) and an upstream change to a plain machinery file. It used to write a
# new VERSION stamp into the scratch source too; there is no stamp to write since #298.
# The rename is the half that has never run anywhere — replacement is the easy half.
#
# THE ROW IT APPENDS CARRIES THREE FIELDS (#287): path, prose, and the NEW PATH. The third is what
# [upgrade-repoints] below runs on — drop it and the parser reads the row as a REMOVAL, nothing is
# re-pointed, and that guard reds on its first assertion. That is how the guard is revert-proved.
in_up_advance_source() {
  local sc="$UP_SRC/estate/_harness/scripts"
  # The fixture's rename is SYNTHETIC — retro-counts.sh is a name the product never ships. It used
  # to rename retro_stats.sh -> retro-stats.sh, which stopped being a rename the day #141 settled
  # every script on the hyphen convention and made retro-stats.sh the real shipped name. A fixture
  # whose two halves collapse to one name deletes the file instead of renaming it, so the pair is
  # now anchored to a target that cannot collide with a real one.
  cp -p "$sc/retro-stats.sh" "$sc/retro-counts.sh"; rm -f "$sc/retro-stats.sh"
  # The rename has to reach the scratch source's INDEX, because that is what the installer now
  # derives the shipped set from (#282). This line used to edit the ship manifest instead: the
  # same declaration, made to the tree rather than to a list describing the tree.
  git -C "$UP_SRC" add -A -f
  printf '%s\t%s\t%s\n' _harness/scripts/retro-stats.sh \
    "renamed to _harness/scripts/retro-counts.sh" _harness/scripts/retro-counts.sh \
    >> "$UP_SRC/estate/_harness/retire-list.tsv"
  printf '# upgrade fixture: an upstream change to a plain machinery file.\n' \
    >> "$sc/harness-drill.sh"
  return 0
}

# (m) upgrade-plan: --upgrade --dry-run names every create, replace, retire and repoint BEFORE
#     anything happens, and touches nothing. Pre-fix, --upgrade is an unknown option and the run
#     exits 2.
in_upgrade_plan() {
  in_up_run upgrade-plan --upgrade --dry-run --yes "$UP_EST"
  local v
  for v in 'create   _harness/scripts/retro-counts.sh' \
           'replace  _harness/scripts/harness-drill.sh' \
           'retire   _harness/scripts/retro-stats.sh' \
           'repoint  _agents/retrospective.agent.md'; do
    grep -Fq "  $v" "$UP_OUT" \
      || { echo "BUG [upgrade-plan]: the plan never said '$v' — every create, replace, retire"; \
           echo "    and repoint must be shown before anything happens. What it printed:"; \
           grep -E '^  (create|replace|retire|repoint|keep)' "$UP_OUT" | sed 's/^/      /'; \
           exit 1; }
  done
  [ ! -e "$UP_EST/_retired" ] && [ -e "$UP_EST/_harness/scripts/retro-stats.sh" ] \
    || { echo "BUG [upgrade-plan]: --dry-run TOUCHED the estate — it must plan and stop"; exit 1; }
  echo "  ok [upgrade-plan] — create/replace/retire/repoint all shown before acting; --dry-run" \
    "moved nothing"
}

# (t) upgrade-needs-source: an estate re-running its OWN shipped installer has no source to copy
#     new machinery from, so --upgrade there must REFUSE by name and print the command that works.
#     The failure it prevents is quiet: a plan of zero-everything reads exactly like an estate that
#     was already current, and the user walks away believing they upgraded.
in_upgrade_needs_source() {
  local out rc=0
  out=$(cd "$UP_EST" && HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash ./install.sh --upgrade --yes \
    2>&1) || rc=$?
  [ "$rc" -ne 0 ] \
    || { echo "BUG [upgrade-needs-source]: the estate's own installer accepted --upgrade and"; \
         echo "    exited 0. It has no source to upgrade from, so it can only have done nothing"; \
         echo "    while looking like a success. Its output:"; printf '%s\n' "$out" | tail -4; \
         exit 1; }
  printf '%s\n' "$out" | grep -q -- '--upgrade cannot run from inside the estate' \
    || { echo "BUG [upgrade-needs-source]: refused, but never said why or what to run instead:"; \
         printf '%s\n' "$out" | tail -4; exit 1; }
  echo "  ok [upgrade-needs-source] — in-estate --upgrade refuses by name and prescribes the fix"
}

# (n) upgrade-retires: the rename half. The superseded file is MOVED to quarantine (never deleted),
#     the replacement is laid down, and the run names the restore command at the moment it happens.
in_upgrade_retires() {
  in_up_run upgrade-retires --upgrade --yes "$UP_EST"
  cp -p "$UP_OUT" "$I39_ROOT/up.first"
  [ ! -e "$UP_EST/_harness/scripts/retro-stats.sh" ] \
    || { echo "BUG [upgrade-retires]: the superseded file is STILL in place — an upgraded estate" \
           "would hold both names, which is the defect retirement exists to stop"; exit 1; }
  [ -e "$UP_EST/_harness/scripts/retro-counts.sh" ] \
    || { echo "BUG [upgrade-retires]: the replacement was never laid down"; exit 1; }
  find "$UP_EST/_retired" -name retro-stats.sh 2>/dev/null | grep -q . \
    || { echo "BUG [upgrade-retires]: the superseded file is not in quarantine — it was DELETED," \
           "and deletion is forbidden in every class"; exit 1; }
  grep -A2 '^RETIRED ' "$I39_ROOT/up.first" | grep -q 'RESTORE IT WITH: *mv ' \
    || { echo "BUG [upgrade-retires]: the retirement was not reported with the command that puts" \
           "it back. The quarantine folder is untracked, so that report is the only signal"; \
         exit 1; }
  echo "  ok [upgrade-retires] — superseded file MOVED to quarantine, replacement laid down," \
    "restore command reported"
}

# (u) upgrade-retires-version (#298): THE ONE NEW BEHAVIOUR IN A CHANGE THAT IS OTHERWISE ALL
#     SUBTRACTION. Deleting VERSION from the shipped set does not remove it from anybody's estate.
#     An estate installed before this release is already holding one, has no remote, and runs
#     nothing that would ever correct it — the stamp would sit at the root forever as a number no
#     tool reads and no user thinks to doubt, which is worse than the drift that prompted the
#     deletion. So VERSION retires like any other superseded path: through a row in the very list
#     whose format this same release changed, moved to quarantine, restore command printed.
#     ITS SUBJECT IS PLANTED IN in_up_customise — see the note there for why it has to be.
#     REVERT-PROVABLE: drop the VERSION row from estate/_harness/retire-list.tsv and this reds on
#     its first assertion, because the upgrade then has no declaration telling it to move anything.
in_upgrade_retires_version() {
  [ ! -e "$UP_EST/VERSION" ] \
    || { echo "BUG [upgrade-retires-version]: the estate STILL holds its VERSION stamp after the" \
           "upgrade — a release number nothing reads, that nothing will ever correct"; exit 1; }
  find "$UP_EST/_retired" -name VERSION 2>/dev/null | grep -q . \
    || { echo "BUG [upgrade-retires-version]: the stamp is not in quarantine — it was DELETED," \
           "and deletion is forbidden in every class, retirement included"; exit 1; }
  grep -A2 '^RETIRED  VERSION$' "$I39_ROOT/up.first" | grep -q 'RESTORE IT WITH: *mv ' \
    || { echo "BUG [upgrade-retires-version]: the stamp was moved without the command that puts"; \
         echo "    it back. _retired/ sits outside the record, so that printed line is the whole"; \
         echo "    of what a user who wanted the file gets. What the run said about it:"; \
         grep -A2 '^RETIRED  VERSION$' "$I39_ROOT/up.first" | sed 's/^/      /'; exit 1; }
  echo "  ok [upgrade-retires-version] — a pre-#298 estate's VERSION stamp is MOVED to quarantine" \
    "and its restore command is reported"
}

# (o) upgrade-keeps-settings: the three files carrying values the USER owns come through an upgrade
#     BYTE-IDENTICAL. The hook config is the worst one to get wrong — it governs whether the estate
#     commits by itself — and it is the member a substitution-only derivation misses entirely.
in_upgrade_keeps_settings() {
  local n f s
  for n in tg:"$UP_TG" dw:"$UP_DW" hk:"$UP_HOOK"; do
    s="$I39_ROOT/snap.${n%%:*}"; f="${n#*:}"
    cmp -s "$s" "$f" \
      || { echo "BUG [upgrade-keeps-settings]: the upgrade CHANGED $f, which carries a value the"; \
           echo "    user chose. A retirement that silently resets somebody's configuration is a"; \
           echo "    data loss wearing a rename's clothes. Diff:"; diff "$s" "$f" | head -5; \
           exit 1; }
  done
  grep -q '_harness/scripts/ticket-grammar.sh' "$I39_ROOT/up.first" \
    && grep -q '.github/hooks/harness.json' "$I39_ROOT/up.first" \
    || { echo "BUG [upgrade-keeps-settings]: the run never SAID which files it carried forward —" \
           "a silently-correct upgrade is indistinguishable from a lucky one"; exit 1; }
  echo "  ok [upgrade-keeps-settings] — board grammar, model pin and HOOK CONFIG byte-unchanged" \
    "and named in the run"
}

# (v) upgrade-repoints (#287): THE FOURTH VERB. KEEP protects a carried-forward file from being
#     replaced — and protects the dead filenames inside it just as thoroughly, so a rename declared
#     in the retire list reached the estate's machinery but never the agent contract that calls it.
#     An upgraded estate ended up holding an agent instructing an assistant to run a script the
#     same run had just moved to quarantine.
#     WHAT IT ASSERTS, and the second half is the harder one: the dead path is gone AND the file is
#     otherwise untouched — the model pin survives and EXACTLY ONE LINE differs from the user's
#     copy. A fix that re-derived the whole document from source would clear the first assertion
#     and fail the second, which is the wider fix this item was narrowed away from.
#     REVERT-PROVABLE: drop the third field from the retire row in in_up_advance_source and this
#     reds on its first assertion — the row parses as a removal, which has no new path to point at.
in_upgrade_repoints() {
  grep -q '_harness/scripts/retro-stats.sh' "$UP_RETRO" \
    && { echo "BUG [upgrade-repoints]: the carried-forward agent contract STILL names the script"; \
         echo "    this run moved to quarantine — the assistant reading it is being sent to a"; \
         echo "    file that is not there any more"; exit 1; }
  grep -q '_harness/scripts/retro-counts.sh' "$UP_RETRO" \
    || { echo "BUG [upgrade-repoints]: the stale path is gone but the NEW one never arrived —" \
           "the mention was destroyed rather than re-pointed"; exit 1; }
  grep -q '^model: UPRETRO' "$UP_RETRO" \
    || { echo "BUG [upgrade-repoints]: the user's model pin is gone. Re-pointing a path must not" \
           "cost the setting the file was carried forward to protect"; exit 1; }
  in_upgrade_repoints_bound
  in_upgrade_repoints_reported
  echo "  ok [upgrade-repoints] — the dead path is re-pointed, the pin survives, exactly one line" \
    "moved, and the rewrite is reported with a restore command that runs"
}

# in_upgrade_repoints_bound — "rewrite paths only. Never a line, never a sentence, never a whole
# file." Counted rather than eyeballed: one changed line, and what changed on it is the path.
in_upgrade_repoints_bound() {
  local d n
  # THE DIFF IS TAKEN ONCE INTO A VARIABLE, and the `|| true` is load-bearing rather than defensive:
  # this suite runs under `pipefail`, and `diff` exits 1 whenever the files differ — which is every
  # time this guard is doing its job — so piping it straight into grep fails the pipeline on the
  # success path and reds a passing fix.
  d=$(diff "$I39_ROOT/snap.retro" "$UP_RETRO" || true)
  n=$(printf '%s\n' "$d" | grep -c '^[<>]' || true)
  [ "$n" -eq 2 ] \
    || { echo "BUG [upgrade-repoints]: $n diff lines between the user's copy and the re-pointed"; \
         echo "    one — a path rewrite is ONE line out and ONE line in. Anything more means the"; \
         echo "    upgrade rewrote prose the user may have edited. Diff:"; \
         printf '%s\n' "$d" | head -8; exit 1; }
  printf '%s\n' "$d" | grep '^>' | grep -q 'retro-counts.sh' \
    || { echo "BUG [upgrade-repoints]: the one line that changed is not the path line. Diff:"; \
         printf '%s\n' "$d" | head -8; exit 1; }
}

# in_upgrade_repoints_reported — editing a user's file silently is the thing this project exists to
# prevent, even when the edit is right. So the rewrite is reported like a retirement: named, both
# paths spelled out, and a LITERAL restore command that is EXECUTED here rather than read.
# THE RE-RUN AT THE END IS NOT TIDYING. It leaves the estate re-pointed for the guards after this
# one, and on the way it proves the property the plan is built on: re-pointing is driven off the
# whole retire list, not off what this run retired. retro-stats.sh is long gone from the estate by
# now, so that run retires NOTHING and must still correct the file the restore just made stale.
in_upgrade_repoints_reported() {
  local cmd
  grep -q '^REPOINTED _agents/retrospective.agent.md$' "$I39_ROOT/up.first" \
    || { echo "BUG [upgrade-repoints]: the run edited a file the user owns and never said so"; \
         exit 1; }
  cmd=$(grep -A3 '^REPOINTED _agents/retrospective.agent.md$' "$I39_ROOT/up.first" \
    | grep -m1 'RESTORE IT WITH:' | sed 's/.*RESTORE IT WITH: *//')
  [ -n "$cmd" ] \
    || { echo "BUG [upgrade-repoints]: no restore command was printed to execute"; exit 1; }
  bash -c "$cmd" || { echo "BUG [upgrade-repoints]: the restore command FAILED: $cmd"; exit 1; }
  cmp -s "$I39_ROOT/snap.retro" "$UP_RETRO" \
    || { echo "BUG [upgrade-repoints]: the restore ran but did not give the user their file back" \
           "byte-for-byte"; exit 1; }
  in_up_run upgrade-repoints --upgrade --yes "$UP_EST"
  grep -qE '^RETIRED ' "$UP_OUT" \
    && { echo "BUG [upgrade-repoints]: fixture unsound — that run retired something, so it cannot" \
           "show re-pointing happening independently of retirement"; exit 1; }
  grep -q '^REPOINTED _agents/retrospective.agent.md$' "$UP_OUT" \
    || { echo "BUG [upgrade-repoints]: a run that retired nothing left the stale path in place —" \
           "re-pointing is reading this run's retirements, not the cumulative list"; exit 1; }
}

# (p) upgrade-record-untouched: class 1 of the upgrade's three. A record is never touched, under any
#     circumstance, retirement included.
#     ITS SUBJECT IS THE USER-EDITED SHIPPED TICKET, because that is a shipped path whose estate
#     copy DIFFERS from the source's — the exact condition under which every other machinery path
#     IS replaced, so only the record test spares it. That difference is asserted in the fixture
#     builder, BEFORE the upgrade runs; see the note there for why it cannot be asked afterwards.
#     The hand-made knowledge note is checked too, but it is the weaker claim: it is not a
#     shipped path, so no version of this installer would ever have considered it.
in_upgrade_record_untouched() {
  cmp -s "$I39_ROOT/snap.tick" "$UP_TICK" \
    || { echo "BUG [upgrade-record-untouched]: the upgrade REPLACED a user-edited ticket. An"; \
         echo "    installer that can overwrite a record is not a harness component, it is a"; \
         echo "    hazard. What it lost:"; diff "$I39_ROOT/snap.tick" "$UP_TICK" | head -5; \
         exit 1; }
  cmp -s "$I39_ROOT/snap.rec" "$UP_REC" \
    || { echo "BUG [upgrade-record-untouched]: the upgrade TOUCHED a hand-made knowledge record"; \
         exit 1; }
  echo "  ok [upgrade-record-untouched] — a user-edited shipped ticket (differing from source)" \
    "and a hand-made record both came through byte-unchanged"
}

# (q) upgrade-idempotent: the second run reports itself as having nothing to do, IN WORDS. Three
#     zeros a reader has to add up is not the same claim as the run saying it is safe to re-run.
in_upgrade_idempotent() {
  in_up_run upgrade-idempotent --upgrade --yes "$UP_EST"
  grep -q 'NOTHING TO DO' "$UP_OUT" \
    || { echo "BUG [upgrade-idempotent]: a second run did not report itself as a no-op:"; \
         grep -E '^(  (create|replace|retire)|Upgraded this run)' "$UP_OUT" | sed 's/^/      /'; \
         exit 1; }
  grep -qE '^(CREATED|REPLACED|RETIRED|REPOINTED)' "$UP_OUT" \
    && { echo "BUG [upgrade-idempotent]: a second run MOVED or REWROTE something — re-running"; \
         echo "    must be safe, and a repoint that fires twice is rewriting a file it already"; \
         echo "    corrected"; exit 1; }
  echo "  ok [upgrade-idempotent] — the second run says NOTHING TO DO and moves no file"
}

# (r) upgrade-restore-works: the printed restore command is EXECUTED, not read. A command that
#     names the right paths but cannot run is the same as no report at all, and the quarantine
#     folder is untracked, so this line is the entire reversal path a user has.
#     IT NAMES ITS RETIREMENT RATHER THAN TAKING THE FIRST ONE. The run retires TWO paths since
#     #298 — the fixture's rename and the estate's old VERSION stamp — and this guard's assertion
#     is about retro-stats.sh coming back, so it has to execute retro-stats.sh's restore line. An
#     unanchored "first RETIRED block" would restore the stamp and then red on a file it never
#     asked about, which reads as an installer defect and is not one.
in_upgrade_restore_works() {
  local cmd
  cmd=$(grep -A2 '^RETIRED  _harness/scripts/retro-stats.sh$' "$I39_ROOT/up.first" \
    | grep -m1 'RESTORE IT WITH:' | sed 's/.*RESTORE IT WITH: *//')
  [ -n "$cmd" ] \
    || { echo "BUG [upgrade-restore-works]: no restore command was printed to execute"; exit 1; }
  bash -c "$cmd" \
    || { echo "BUG [upgrade-restore-works]: the printed restore command FAILED to run: $cmd"; \
         exit 1; }
  [ -e "$UP_EST/_harness/scripts/retro-stats.sh" ] \
    || { echo "BUG [upgrade-restore-works]: the restore command ran but the file did not come" \
           "back — the report names a reversal that does not reverse anything"; exit 1; }
  echo "  ok [upgrade-restore-works] — the printed restore command runs and puts the file back"
}

# (s) upgrade-interrupted: THE REALISTIC WAY A PERSON LOSES WORK. The first three guards all assume
#     the upgrade FINISHES; "safe to run twice" says nothing about a run that stopped halfway,
#     because it assumes the first one completed. The interruption is deterministic rather than a
#     race: the source copy of a file scheduled for REPLACE is taken away, so the run dies inside
#     the copy that follows the quarantine move — some files new, some old, one half-replaced.
#     BOTH HALVES ARE ASSERTED: nothing was lost, and re-running from there finishes the job.
in_upgrade_interrupted() {
  local rel="_harness/scripts/harness-drill.sh" rc=0
  printf '# an estate-local edit, so this file is a REPLACE candidate.\n' >> "$UP_EST/$rel"
  mv "$UP_SRC/estate/$rel" "$I39_ROOT/held.drill"
  set +e
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash "$UP_SRC/estate/install.sh" --upgrade --yes \
    "$UP_EST" >"$I39_ROOT/up.kill" 2>&1
  rc=$?
  set -e
  [ "$rc" -ne 0 ] \
    || { echo "BUG [upgrade-interrupted]: the fixture did not interrupt anything — the run"; \
         echo "    completed, so nothing below is a statement about a half-finished upgrade"; \
         exit 1; }
  in_upgrade_interrupted_check "$rel"
}

# in_upgrade_interrupted_check — the two halves, split out so each stays inside the function-length
# limit and so the failure messages sit next to the thing they are asserting.
in_upgrade_interrupted_check() {
  local rel="$1"
  [ ! -e "$UP_EST/$rel" ] \
    || { echo "BUG [upgrade-interrupted]: fixture unsound — the file was never mid-replace"; \
         exit 1; }
  find "$UP_EST/_retired" -name harness-drill.sh 2>/dev/null | grep -q . \
    || { echo "BUG [upgrade-interrupted]: the half-replaced file is NOT in quarantine. It is gone" \
           "from the estate and gone from the record — that is the work destroyed"; exit 1; }
  mv "$I39_ROOT/held.drill" "$UP_SRC/estate/$rel"
  in_up_run upgrade-interrupted --upgrade --yes "$UP_EST"
  [ -e "$UP_EST/$rel" ] \
    || { echo "BUG [upgrade-interrupted]: re-running after the interruption did NOT finish the" \
           "job — the estate stays broken with no way back"; exit 1; }
  grep -Fq "CREATED  $rel" "$I39_ROOT/up.out" \
    || { echo "BUG [upgrade-interrupted]: the recovery run never said what it repaired"; exit 1; }
  echo "  ok [upgrade-interrupted] — killed mid-replace: nothing lost (the file was in" \
    "quarantine), and re-running finished the job"
}

case_installer() {
  in_fixture
  in_schema_one_home
  in_installer_ran
  in_no_version_claim
  in_product_only
  in_estate_root_tracked
  in_dumb_creator
  in_idempotent_rerun
  in_dry_run
  in_board_default
  in_model_pin_offered
  in_change_routed
  in_workspace_derived
  in_prompt_default
  in_missing_value_audible
  # #134 — the upgrade family. It runs LAST because it is the only group here that builds a second
  # source distribution, and every guard above must keep proving what it proves about the plain
  # create path without that fixture standing anywhere near it.
  in_upgrade_fixture
  in_upgrade_plan
  in_upgrade_needs_source
  in_upgrade_retires
  in_upgrade_retires_version
  in_upgrade_keeps_settings
  in_upgrade_repoints
  in_upgrade_record_untouched
  in_upgrade_idempotent
  in_upgrade_restore_works
  in_upgrade_interrupted
  rm -rf "$I39_ROOT" "$I39_DEPLOY"
}
