#!/usr/bin/env bash
# installer.case.sh — #39 installer guards: the non-destructive / dumb-creator claims are the
# richest revert surface, so every one gets a case that reds if a run WOULD edit/clobber a
# pre-existing file or leak a DEV file. SOURCED by the runner; see dev/scripts/run_demo.sh.
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

# in_product_count — how many of the manifest's PRODUCT files actually exist in an estate.
# THE SUBJECT-EXISTS PRIMITIVE (#264). WHY it is needed: every guard below concludes something
# about an installed estate's CONTENTS, and an empty result set carries two meanings — "nothing
# found" and "nothing looked at". A guard that cannot tell them apart reports success about an
# estate that was never created. Counting the PRODUCT files that DID arrive separates the two.
# Manifest paths carry the source tree's `estate/` prefix, which install.sh strips when it lays
# them down, so strip it here too. The total is DERIVED at run time and never hard-coded: a
# number baked into this file would silently go stale on the next legitimate manifest edit.
in_product_count() {   # $1 = estate dir; prints how many manifest PRODUCT files are present
  local est="$1" p rel n=0
  while IFS= read -r p; do
    rel=${p#estate/}
    if [ -e "$est/$rel" ]; then n=$((n + 1)); fi
  done < <(awk -F'\t' '$1=="PRODUCT"{print $2}' dev/ship-manifest.txt)
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
#     manifest's size and would go stale on the next entry added to it.
in_installer_ran() {
  local i39_ran i39_n
  i39_ran="$I39_ROOT/ranest"
  in_install installer-ran --yes "$i39_ran"
  i39_n=$(in_product_count "$i39_ran")
  [ "$i39_n" -gt 0 ] \
    || { echo "BUG [installer-ran]: install.sh --yes exited 0 but laid down NONE of the PRODUCT" \
           "files the manifest names — the installer ran and did nothing"; exit 1; }
  echo "  ok [installer-ran] — the installer created the estate ($i39_n PRODUCT files present)"
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
           "the manifest names, so 'contains no DEV files' would be vacuously true"; exit 1; }
  while IFS= read -r d; do
    if [ -e "$I39_EST/$d" ]; then echo "  DEV leak: $d"; i39_leak=1; fi
  done < <(awk -F'\t' '$1=="DEV"{print $2}' dev/ship-manifest.txt)
  [ "$i39_leak" -eq 0 ] \
    || { echo "BUG [product-only]: a DEV file reached the installed estate"; exit 1; }
  # The success line says what was MEASURED, not the broader claim: an estate that demonstrably
  # holds PRODUCT files, and zero DEV files among them.
  echo "  ok [product-only] — installed estate holds $i39_n PRODUCT files and zero DEV files"
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
# --- #134 UPGRADE MODE — the dumb-creator law's one exception (dev/decisions/020) ----------------
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
  # THE RECORD GUARD'S SUBJECT HAS TO BE ONE THE UPGRADE COULD ACTUALLY REACH. A hand-made file
  # under a knowledge folder is not in the manifest, so no version of this installer would ever
  # consider it and asserting it survived proves nothing. The SHIPPED TEMPLATE TICKET is the
  # subject that bites: it IS a manifest path, so only the record test stops it being replaced —
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
  cp -p "$UP_TG" "$I39_ROOT/snap.tg"; cp -p "$UP_DW" "$I39_ROOT/snap.dw"
  cp -p "$UP_HOOK" "$I39_ROOT/snap.hk"; cp -p "$UP_REC" "$I39_ROOT/snap.rec"
  cp -p "$UP_TICK" "$I39_ROOT/snap.tick"
  return 0
}

# in_up_advance_source — the release the estate is about to receive: a RENAME (declared in the
# retire list, never inferred), an upstream change to a plain machinery file, and a new stamp.
# The rename is the half that has never run anywhere — replacement is the easy half.
in_up_advance_source() {
  local sc="$UP_SRC/estate/_harness/scripts"
  printf '0.2.0-upgrade-fixture\n' > "$UP_SRC/estate/VERSION"
  cp -p "$sc/retro_stats.sh" "$sc/retro-stats.sh"; rm -f "$sc/retro_stats.sh"
  sed 's|scripts/retro_stats\.sh|scripts/retro-stats.sh|' "$UP_SRC/dev/ship-manifest.txt" \
    > "$I39_ROOT/mf.t" && mv "$I39_ROOT/mf.t" "$UP_SRC/dev/ship-manifest.txt"
  printf '%s\t%s\t%s\n' 0.2.0-upgrade-fixture _harness/scripts/retro_stats.sh \
    "renamed to _harness/scripts/retro-stats.sh" >> "$UP_SRC/estate/_harness/retire-list.tsv"
  printf '# upgrade fixture: an upstream change to a plain machinery file.\n' \
    >> "$sc/harness-drill.sh"
  return 0
}

# (m) upgrade-plan: --upgrade --dry-run names every create, replace and retire BEFORE anything
#     happens, and touches nothing. Pre-fix, --upgrade is an unknown option and the run exits 2.
in_upgrade_plan() {
  in_up_run upgrade-plan --upgrade --dry-run --yes "$UP_EST"
  local v
  for v in 'create   _harness/scripts/retro-stats.sh' \
           'replace  _harness/scripts/harness-drill.sh' \
           'retire   _harness/scripts/retro_stats.sh'; do
    grep -Fq "  $v" "$UP_OUT" \
      || { echo "BUG [upgrade-plan]: the plan never said '$v' — every create, replace and retire"; \
           echo "    must be shown before anything happens. What it printed:"; \
           grep -E '^  (create|replace|retire|keep)' "$UP_OUT" | sed 's/^/      /'; exit 1; }
  done
  [ ! -e "$UP_EST/_retired" ] && [ -e "$UP_EST/_harness/scripts/retro_stats.sh" ] \
    || { echo "BUG [upgrade-plan]: --dry-run TOUCHED the estate — it must plan and stop"; exit 1; }
  echo "  ok [upgrade-plan] — create/replace/retire all shown before acting; --dry-run moved" \
    "nothing"
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
  [ ! -e "$UP_EST/_harness/scripts/retro_stats.sh" ] \
    || { echo "BUG [upgrade-retires]: the superseded file is STILL in place — an upgraded estate" \
           "would hold both names, which is the defect retirement exists to stop"; exit 1; }
  [ -e "$UP_EST/_harness/scripts/retro-stats.sh" ] \
    || { echo "BUG [upgrade-retires]: the replacement was never laid down"; exit 1; }
  find "$UP_EST/_retired" -name retro_stats.sh 2>/dev/null | grep -q . \
    || { echo "BUG [upgrade-retires]: the superseded file is not in quarantine — it was DELETED," \
           "and deletion is forbidden in every class (dev/decisions/020)"; exit 1; }
  grep -A2 '^RETIRED ' "$I39_ROOT/up.first" | grep -q 'RESTORE IT WITH: *mv ' \
    || { echo "BUG [upgrade-retires]: the retirement was not reported with the command that puts" \
           "it back. The quarantine folder is untracked, so that report is the only signal"; \
         exit 1; }
  echo "  ok [upgrade-retires] — superseded file MOVED to quarantine, replacement laid down," \
    "restore command reported"
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

# (p) upgrade-record-untouched: class 1 of dev/decisions/020. A record is never touched, under any
#     circumstance, retirement included.
#     ITS SUBJECT IS THE USER-EDITED SHIPPED TICKET, because that is a manifest path whose estate
#     copy DIFFERS from the source's — the exact condition under which every other machinery path
#     IS replaced, so only the record test spares it. That difference is asserted in the fixture
#     builder, BEFORE the upgrade runs; see the note there for why it cannot be asked afterwards.
#     The hand-made knowledge note is checked too, but it is the weaker claim: nothing in the
#     manifest names it, so no version of this installer would ever have considered it.
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
  grep -qE '^(CREATED|REPLACED|RETIRED)' "$UP_OUT" \
    && { echo "BUG [upgrade-idempotent]: a second run MOVED something — re-running must be safe"; \
         exit 1; }
  echo "  ok [upgrade-idempotent] — the second run says NOTHING TO DO and moves no file"
}

# (r) upgrade-restore-works: the printed restore command is EXECUTED, not read. A command that
#     names the right paths but cannot run is the same as no report at all, and the quarantine
#     folder is untracked, so this line is the entire reversal path a user has.
in_upgrade_restore_works() {
  local cmd
  cmd=$(grep -A2 '^RETIRED ' "$I39_ROOT/up.first" | grep -m1 'RESTORE IT WITH:' \
    | sed 's/.*RESTORE IT WITH: *//')
  [ -n "$cmd" ] \
    || { echo "BUG [upgrade-restore-works]: no restore command was printed to execute"; exit 1; }
  bash -c "$cmd" \
    || { echo "BUG [upgrade-restore-works]: the printed restore command FAILED to run: $cmd"; \
         exit 1; }
  [ -e "$UP_EST/_harness/scripts/retro_stats.sh" ] \
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
  in_product_only
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
  in_upgrade_keeps_settings
  in_upgrade_record_untouched
  in_upgrade_idempotent
  in_upgrade_restore_works
  in_upgrade_interrupted
  rm -rf "$I39_ROOT" "$I39_DEPLOY"
}
