#!/usr/bin/env bash
# installer.case.sh — #39 installer guards: the non-destructive / dumb-creator claims are the
# richest revert surface, so every one gets a case that reds if a run WOULD edit/clobber a
# pre-existing file or leak a DEV file. SOURCED by the runner; see dev/scripts/run_demo.sh.
#
# install.sh is exercised for real into a throwaway estate (agent deploy is sent to a throwaway dir
# so nothing touches $HOME). Plain-English asserts; guard-per-bug on each claim. I39_ROOT, I39_EST
# and I39_DEPLOY are file-scope: built once, read by every sub-case, removed at the end.

in_fixture() {
  echo "--- #39 installer: non-destructive, PRODUCT-only, single-schema-home, idempotent ---"
  I39_ROOT=$(mktemp -d); I39_EST="$I39_ROOT/estate"; I39_DEPLOY=$(mktemp -d)
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
in_product_only() {
  local i39_leak=0 d
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh --yes "$I39_EST" >/dev/null 2>&1 \
    || { echo "BUG [clean-install]: a clean --yes install failed"; exit 1; }
  while IFS= read -r d; do
    if [ -e "$I39_EST/$d" ]; then echo "  DEV leak: $d"; i39_leak=1; fi
  done < <(awk -F'\t' '$1=="DEV"{print $2}' dev/ship-manifest.txt)
  [ "$i39_leak" -eq 0 ] \
    || { echo "BUG [product-only]: a DEV file reached the installed estate"; exit 1; }
  echo "  ok [product-only] — fresh estate contains zero DEV files"
}

# (c) dumb creator (cond 2, ABSOLUTE): a pre-existing (corrupted) file is byte-UNCHANGED by a
#     re-run. Compare with cmp against a snapshot (portable — no sha256sum, which stock macOS
#     lacks).
in_dumb_creator() {
  echo "GARBAGE" > "$I39_EST/AGENTS.md"; cp "$I39_EST/AGENTS.md" "$I39_ROOT/agents.snapshot"
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh --yes "$I39_EST" >/dev/null 2>&1
  cmp -s "$I39_ROOT/agents.snapshot" "$I39_EST/AGENTS.md" \
    || { echo "BUG [dumb-creator]: install EDITED a pre-existing file (AGENTS.md changed) — it" \
           "must create only what is absent"; exit 1; }
  echo "  ok [dumb-creator] — pre-existing file left byte-unchanged (creates only what is absent)"
}

# (d) idempotency: a re-run finds nothing absent and creates zero.
in_idempotent_rerun() {
  local i39_plan
  i39_plan=$(HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh --yes "$I39_EST" 2>&1 \
    | grep -oE 'PRODUCT files to create: [0-9]+' | head -1)
  [ "$i39_plan" = "PRODUCT files to create: 0" ] \
    || { echo "BUG [idempotent-rerun]: a re-run wanted to create files ($i39_plan)"; exit 1; }
  echo "  ok [idempotent-rerun] — re-run creates nothing (nothing absent)"
}

# (e) --dry-run touches nothing: a dry-run against a fresh path must not create it.
in_dry_run() {
  local i39_fresh
  i39_fresh="$I39_ROOT/dryrun-never"
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh --dry-run --yes "$i39_fresh" \
    >/dev/null 2>&1
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
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh --yes "$i39_re" >/dev/null 2>&1
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
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh --yes "$i39_m" >/dev/null 2>&1
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
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh --yes "$i39_cr" >/dev/null 2>&1
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
  HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash estate/install.sh --yes "$i39_mv" >/dev/null 2>&1
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

case_installer() {
  in_fixture
  in_schema_one_home
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
  rm -rf "$I39_ROOT" "$I39_DEPLOY"
}
