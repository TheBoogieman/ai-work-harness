#!/usr/bin/env bash
# run_demo.sh — proves the harness machinery works on THIS machine in ~20s.
# No Copilot needed. Safe: uses temp state, creates+destroys one scratch ticket.
set -euo pipefail
export HARNESS_DEMO=1   # lets status treat a template-clone remote as a NOTE, not a FAIL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."
export HARNESS_STATE_DIR=$(mktemp -d) HARNESS_AGENT_DEPLOY_DIR=$(mktemp -d) PACK_OUT_DIR=$(mktemp -d)
trap 'rm -rf "$HARNESS_STATE_DIR" "$HARNESS_AGENT_DEPLOY_DIR" "$PACK_OUT_DIR"' EXIT
S="Tickets/999911Z-PROJ-99998"; rm -rf "$S"

DID_INIT=0
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init -q .; git add -A; git -c user.email=demo@local -c user.name=demo commit -qm "harness: day zero"
  DID_INIT=1
fi

# demo_close_commit — the demo's closing auto-commit, GATED so it only fires when the demo
# ITSELF created the repo (issue #10). In a real clone (.git already present -> DID_INIT=0) it
# must do NOTHING, so the demo never sweeps a user's uncommitted work into a "demo: pass"
# commit. Factored into a function so the [#10 guard] below tests THIS exact gate, not a copy
# that could drift from it.
demo_close_commit() {  # $1 = DID_INIT flag (1 iff the demo created the repo), $2 = repo dir
  local did_init="$1" repo="$2"
  [ "$did_init" -eq 1 ] || return 0                      # real clone -> skip; never absorb WIP
  git -C "$repo" add -A >/dev/null
  git -C "$repo" -c user.email=demo@local -c user.name=demo commit -qm "demo: pass" >/dev/null 2>&1 || true
}

# R-03 portability guard: reject in-place sed under _harness/ (BSD-incompatible; use tmp+mv instead)
if grep -rnE 'sed +(-[A-Za-z]+ +)*-i' _harness/; then
  echo "FAIL: in-place sed found under _harness/ — not BSD-portable. Fix: rewrite via tmp+mv (grep for deletes, sed for substitutions)."; exit 1
fi

echo "=== 1/6 validator: first pass + vacuous rerun ==="
bash _harness/scripts/check_ticket_log.sh
bash _harness/scripts/check_ticket_log.sh

echo "=== 2/6 scratch ticket: happy path ==="
cp -r Tickets/999912Z-PROJ-99999 "$S"
mv "$S/999912Z-PROJ-99999.md" "$S/999911Z-PROJ-99998.md"
printf '\n## %s - Demo work session\n- Added the new field to the staging model\n' "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
echo "- notes.md — platform quirk — read before editing" >> "$S/AI-Knowledge/_index.md"
echo "quirk" > "$S/AI-Knowledge/notes.md"
bash _harness/scripts/check_ticket_log.sh

echo "=== 3/6 corruption must FAIL loudly (this is the point) ==="
# R-04 index-grammar regressions. The validator names a file ONLY by an index line's first
# token after "- "; prose, '#' comments and '<...>' placeholders are inert (grammar pinned in
# folder-structure.md). These cases prove that in BOTH directions: honest records must PASS
# (no false ghosts, no false orphans — the R-12 point) and real breakage must FAIL. A parser
# that scans whole prose lines flips the PASS cases to false FAILs — see the R-04 revert-proof.

# ak_reset rebuilds the scratch ticket's AI-Knowledge/ from nothing: $1 is the _index.md body
# (embed \n via $'...' for multiple lines); each remaining arg is a real .md file to create.
ak_reset() {
  local body="$1"; shift
  rm -rf "$S/AI-Knowledge"; mkdir -p "$S/AI-Knowledge"
  printf '%s\n' "$body" > "$S/AI-Knowledge/_index.md"
  local f; for f in "$@"; do printf 'content\n' > "$S/AI-Knowledge/$f"; done
}
# reg_run bumps the ticket log with a fresh session entry (so the watermark check passes and the
# log mtime advances, forcing re-validation) then runs the validator once, capturing exit code +
# output into REG_RC / REG_OUT. sleep 1 keeps session timestamps and mtimes strictly increasing.
reg_run() {
  sleep 1
  printf '\n## %s - regression probe\n- exercising the index grammar\n' "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
  set +e; REG_OUT=$(bash _harness/scripts/check_ticket_log.sh 2>&1); REG_RC=$?; set -e
}
# reg_pass asserts an honest index was accepted ($1 = case label). A false FAIL here is the R-12
# defect — an honest record RED-blocked — so we abort the demo loudly with the validator output.
reg_pass() {
  if [ "$REG_RC" -ne 0 ]; then echo "BUG [$1]: honest index RED-blocked (validator failed, should pass):"; printf '%s\n' "$REG_OUT"; exit 1; fi
  echo "  ok [$1] — honest record accepted"
}
# reg_fail asserts real breakage was refused ($1 = label) AND that the printed reason matches $2,
# so we prove the RIGHT failure fired (e.g. the orphan we expected), not an unrelated one.
reg_fail() {
  if [ "$REG_RC" -eq 0 ] || ! printf '%s\n' "$REG_OUT" | grep -q "$2"; then echo "BUG [$1]: expected a FAIL matching '$2' (rc=$REG_RC):"; printf '%s\n' "$REG_OUT"; exit 1; fi
  echo "  ok [$1] — correctly refused: $2"
}

# 1. TRUTHFUL PROSE INERT: a filename in the DESCRIPTION is not an entry. A prose-scanning parser
#    raises old-plan.md as a false ghost and red-blocks this honest record — the core R-12 case.
ak_reset "- notes.md — supersedes old-plan.md" notes.md
reg_run; reg_pass "1 truthful-prose"

# 2. REAL ORPHAN CAUGHT: a real file with no entry line must FAIL. Then apply the printed fix
#    (repair is a human act; reg_run gives it its own log entry) and watch the ticket go green.
ak_reset "- covered.md — the only entry" covered.md orphan.md
reg_run; reg_fail "2 real-orphan" "orphan file AI-Knowledge/orphan.md"
echo "  --- applying the printed fix: add the missing index line, re-validate ---"
echo "- orphan.md — now indexed" >> "$S/AI-Knowledge/_index.md"
reg_run; reg_pass "2 orphan-repaired"

# 3. '#' COMMENT INERT: a .md name inside a comment line is not scanned. A prose-scanning parser
#    reads notes.md out of the comment and mints a false ghost.
ak_reset $'# see notes.md for the mapping\n- real.md — the real entry' real.md
reg_run; reg_pass "3 comment-inert"

# 4. PLACEHOLDER INERT: a <...> first token is illustrative, never a real entry or ghost —
#    guaranteed by a deliberate angle-bracket check in the validator, not by char-class luck.
ak_reset $'- <file>.md — placeholder shown in the grammar\n- real.md — the real entry' real.md
reg_run; reg_pass "4 placeholder-inert"

# 5. SUBSTRING DECOY: entry "- release-extra.md" must NOT cover the different real file extra.md.
#    First-token EQUALITY (not substring) leaves extra.md an orphan. [R-01, now grammar-enforced]
#    BOTH decoys are REAL files, so release-extra.md is covered by its own entry and does not
#    ghost — the stage then fails for EXACTLY ONE reason (the extra.md orphan). That isolates the
#    orphan property specifically: a future orphan-check regression can't hide behind a ghost
#    failure here. (Cleanup: the next case's ak_reset rebuilds AI-Knowledge/, clearing both.)
ak_reset "- release-extra.md — decoy" extra.md release-extra.md
reg_run; reg_fail "5 substring-decoy" "orphan file AI-Knowledge/extra.md"

# 6. UNIFICATION: one validation, one rule, both directions — good.md is correctly covered by its
#    exact entry (orphan side) while missing.md is correctly flagged (ghost side).
ak_reset $'- good.md — real and covered\n- missing.md — names no file' good.md
reg_run; reg_fail "6 unification" "ghost entry 'missing.md'"
if printf '%s\n' "$REG_OUT" | grep -q "orphan file AI-Knowledge/good.md"; then echo "BUG [6]: good.md wrongly flagged orphan — the orphan side broke"; exit 1; fi
echo "  ok [6] — one token rule drove BOTH orphan-coverage (good.md) and ghost-detection (missing.md)"

# 7. TOMBSTONE ACCEPTED: "- old.md (promoted -> ...)" names no file but is a tombstone, not a
#    ghost — the promotion record is legitimate and must PASS.
ak_reset $'- old.md (promoted -> General AI-Knowledge/Foo)\n- real.md — kept' real.md
reg_run; reg_pass "7 tombstone-accepted"

# 8. DASHLESS PRE-FIX ENTRY: a hand-written line predating the leading-dash rule, WITHOUT the
#    leading "- ", is not an entry under the grammar, so its file reads as an orphan and FAILs. This
#    is CORRECT — the leading dash is now enforced. MIGRATION: operators with old dashless indexes
#    must prepend "- " (the keeper agent now writes the dash, so only pre-existing hand-written
#    indexes hit this). Asserting FAIL here proves the dash is load-bearing.
ak_reset "notes.md — quirk" notes.md
reg_run; reg_fail "8 dashless-pre-fix" "orphan file AI-Knowledge/notes.md"

# 9. UNICODE-ARROW TOMBSTONE ACCEPTED (E-2 dual-accept): a legacy tombstone written with the
#    unicode arrow must still be exempt from ghosting — else honest legacy records flip
#    valid->ghost and red-block (the R-04 failure). The matcher accepts both arrows; the
#    prescription (fix-line) teaches ASCII "->" only.
ak_reset $'- old.md (promoted → General AI-Knowledge/Foo)\n- real.md — kept' real.md
reg_run; reg_pass "9 unicode-tombstone"

# 10. E-1 PRESCRIPTION IS ASCII: the ghost fix-line must teach the canonical ASCII tombstone,
#     never the unicode arrow — else a user who follows the printed fix writes a tombstone the
#     gate (post-Flag-2) rejects. Trigger a ghost, then assert the printed fix-line contains
#     ASCII "promoted ->" and NOT the unicode arrow. (Assertion, not a pass/fail stage: the
#     ghost is expected to fire; we check the fix-line's bytes.)
ak_reset $'- ghosty.md — names no file\n- real.md — kept' real.md
reg_run   # REG_OUT now holds the ghost FAIL and its fix-line
if ! printf '%s\n' "$REG_OUT" | grep -q "promoted ->"; then echo "BUG [10]: ghost fix-line missing ASCII 'promoted ->':"; printf '%s\n' "$REG_OUT"; exit 1; fi
if printf '%s\n' "$REG_OUT" | grep -q "promoted →"; then echo "BUG [10]: ghost fix-line emits the UNICODE arrow — E-1 regressed:"; printf '%s\n' "$REG_OUT"; exit 1; fi
echo "  ok [10 fixline-ascii] — ghost fix-line prescribes ASCII '(promoted -> ...)', no unicode arrow"

# leave the scratch ticket green for the remaining stages
ak_reset "- notes.md — platform quirk — read before editing" notes.md
reg_run; reg_pass "clean-exit"

echo "=== 4/6 notebook helper (deterministic .ipynb writes) ==="
python3 _harness/scripts/append_notebook_cell.py "$S/Checks/checks_master.ipynb" "check: row counts match" "SELECT COUNT(*) FROM model;"
# R-07: exercise check-scribe's LITERAL contract form — invoke the helper DIRECTLY (bit + shebang, not python3),
# so a stripped execute bit turns this stage RED (the python3 call above never sees the bit).
if ! _harness/scripts/append_notebook_cell.py "$S/Checks/checks_master.ipynb" "check: direct-exec contract (R-07)" "SELECT 1;"; then
  echo "FAIL: append_notebook_cell.py not directly executable — execute bit or shebang missing. Fix: git update-index --chmod=+x _harness/scripts/append_notebook_cell.py"; exit 1
fi

echo "=== 5/6 deploy + status; break an agent; watch it prescribe ==="
bash _harness/scripts/deploy_agents.sh

# --- R-09 regression: surface (never enforce) unrecognised ticket folders -------------
# Runs BEFORE the first harness-status call of stage 5 (the break-and-restore demonstration
# further down) ON PURPOSE: this block is the first thing after deploy_agents, which makes no
# status call, so a lane where a plain `harness-status` aborts under set -e (e.g. the
# Git-Bash issue #8) still reaches and witnesses every R-09 stage before that abort-prone
# call. The status rc assertions here are baseline-relative (see BASELINE_RC): each fixture
# must add no NEW failure versus the untouched estate, so a pre-existing estate failure on
# such a lane is tested-around, not mis-attributed to an R-09 fixture. Every folder below is
# built from the shipped template and torn down at the end of the block.
echo "--- R-09: unrecognised ticket folders are surfaced, never enforced ---"
# Baseline: status's rc on the UNTOUCHED estate, captured before any fixture exists. Wrapped
# in set +e so this call itself never aborts the demo — the whole point is to witness R-09
# even on a lane where the later plain status call would die.
set +e; BASELINE_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); BASELINE_RC=$?; set -e
R09_SPACE="Tickets/My Random Ticket 42"        # real ticket record under a space-bearing, non-matching name
R09_CONF="Tickets/202607A-PROJ-7"              # conforming, low ticket number
R09_LONG="Tickets/202607AB-LONGBOARD-1000000"  # conforming, multi-letter seq + long number (pins the expansion)
R09_BAD="Tickets/20260A-PROJ-42"               # malformed: 5-digit date — must NOT be recognised

# r09_make builds a ticket-bearing, validator-ready folder from the template: copy it,
# rename the inner .md to the folder's OWN name, and append a fresh session-log entry so
# the watermark check passes. For non-matching names the validator ignores the folder, but
# the rename still gives ticket_bearing() a <foldername>.md to find.
r09_make() {
  local dir="$1" base; base=$(basename "$dir")
  rm -rf "$dir"; cp -r Tickets/999912Z-PROJ-99999 "$dir"
  mv "$dir/999912Z-PROJ-99999.md" "$dir/$base.md"
  printf '\n## %s - r09 probe\n- exercising the ticket grammar\n' "$(date +%Y%m%d%H%M%S)" >> "$dir/$base.md"
}

# [R-09 A] space-named ticket-bearing folder → harness-status WARNs it, exit stays 0.
#          Pins Model 1: a real-but-misnamed ticket is surfaced so nobody assumes it's
#          validated when it's silently skipped — and surfacing NEVER fails the estate.
r09_make "$R09_SPACE"
set +e; R09_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "WARN: Tickets/My Random Ticket 42" \
  || { echo "BUG [R-09 A]: space-named ticket-bearing folder not surfaced as WARN:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -le "$BASELINE_RC" ] || { echo "BUG [R-09 A]: surfacing a misnamed folder added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
echo "  ok [R-09 A] — space-named ticket-bearing folder surfaced (WARN), no new failure vs baseline"

# [R-09 B] same folder + a tracked .not-a-ticket marker → silent (no WARN), exit 0.
#          Pins the recorded, versioned opt-out.
touch "$R09_SPACE/.not-a-ticket"
set +e; R09_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "WARN: Tickets/My Random Ticket 42" \
  && { echo "BUG [R-09 B]: silenced folder still WARNed:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -le "$BASELINE_RC" ] || { echo "BUG [R-09 B]: silencing added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
echo "  ok [R-09 B] — .not-a-ticket marker silences the WARN, no new failure vs baseline"

# [R-09 C] conforming low-number ticket → validated; no naming FAIL, and no whitespace
#          breakage from the space-named sibling created above.
r09_make "$R09_CONF"
set +e; R09_OUT=$(bash _harness/scripts/check_ticket_log.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "OK: 202607A-PROJ-7 validated" \
  || { echo "BUG [R-09 C]: conforming low-number ticket not validated:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -eq 0 ] || { echo "BUG [R-09 C]: validator exited non-zero (rc=$R09_RC):"; printf '%s\n' "$R09_OUT"; exit 1; }
echo "  ok [R-09 C] — 202607A-PROJ-7 validated (low number accepted, space sibling didn't break it)"

# [R-09 E] multi-letter sequence + long number → validated. Pins the EXPANDED pattern
#          (a month past Z, a board key longer than PROJ, a number wider than 5 digits).
r09_make "$R09_LONG"
set +e; R09_OUT=$(bash _harness/scripts/check_ticket_log.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "OK: 202607AB-LONGBOARD-1000000 validated" \
  || { echo "BUG [R-09 E]: expanded-pattern ticket not validated:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -eq 0 ] || { echo "BUG [R-09 E]: validator exited non-zero (rc=$R09_RC):"; printf '%s\n' "$R09_OUT"; exit 1; }
echo "  ok [R-09 E] — 202607AB-LONGBOARD-1000000 validated (multi-letter seq + long number)"

# [R-09 F] malformed name (5-digit date) → NOT recognised, so NEVER validated. Proves the
#          expansion still has a shape — it widened the fields, it didn't go formless.
r09_make "$R09_BAD"
set +e; R09_OUT=$(bash _harness/scripts/check_ticket_log.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "20260A-PROJ-42 validated" \
  && { echo "BUG [R-09 F]: malformed 5-digit-date name was validated — the grammar went formless:"; printf '%s\n' "$R09_OUT"; exit 1; }
echo "  ok [R-09 F] — 20260A-PROJ-42 not recognised, correctly left unvalidated"

# [R-09 D] the context-pack builder handles a space-named ticket at exit 0 (needs zip).
set +e; bash _harness/scripts/make_context_pack.sh --ticket "My Random Ticket 42" >/dev/null; R09_RC=$?; set -e
[ "$R09_RC" -eq 0 ] || { echo "BUG [R-09 D]: context pack failed on a space-named ticket (rc=$R09_RC)"; exit 1; }
echo "  ok [R-09 D] — make_context_pack.sh handled a space-named ticket, exit 0"

# --- pending-ticket fourth state (graceful cancellation of custom names) — issue #25 ---
# A ticket ticket-init couldn't name gets a deliberately non-conforming placeholder name
# PLUS a .ticket-pending marker: a REAL ticket that must NAG until renamed, and cannot be
# silenced. These guards pin that the pending WARN is a DISTINCT message from the
# silenceable hand-made WARN and is non-silenceable. A broken build flips them: checking
# .not-a-ticket before .ticket-pending reddens [R-09 H]; reusing the hand-made-WARN text reddens [R-09 I].
R09_PEND="Tickets/pending-20260719120000"   # non-conforming placeholder name init would coin
R09_HAND="Tickets/handmade-notes"           # a user's own non-conforming folder (contrast case)

# [R-09 G] pending folder (non-conforming name + ticket .md + .ticket-pending) → the
#          PENDING "rename to complete" WARN, exit 0. Pins that the fourth state exists.
r09_make "$R09_PEND"; touch "$R09_PEND/.ticket-pending"
set +e; R09_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "Tickets/pending-20260719120000 is a pending ticket" \
  || { echo "BUG [R-09 G]: pending folder did not get the PENDING WARN:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -le "$BASELINE_RC" ] || { echo "BUG [R-09 G]: pending WARN added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
echo "  ok [R-09 G] — pending folder surfaced with the non-silenceable PENDING WARN, no new failure vs baseline"

# [R-09 H] pending folder that ALSO carries a .not-a-ticket marker → STILL the PENDING WARN
#          (pending is checked first). Pins the non-silenceable semantics: you cannot
#          silence a ticket init flagged as unfinished.
touch "$R09_PEND/.not-a-ticket"
set +e; R09_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "Tickets/pending-20260719120000 is a pending ticket" \
  || { echo "BUG [R-09 H]: .not-a-ticket silenced a pending ticket — precedence is wrong:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -le "$BASELINE_RC" ] || { echo "BUG [R-09 H]: added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
echo "  ok [R-09 H] — .not-a-ticket did NOT silence the pending ticket (pending wins)"

# [R-09 I] contrast: a hand-made ticket-bearing folder with NO markers → the silenceable hand-made
#          WARN, and NOT the pending WARN. Proves the two WARNs are distinct message types.
r09_make "$R09_HAND"
set +e; R09_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "Tickets/handmade-notes holds a .md record but doesn't match" \
  || { echo "BUG [R-09 I]: hand-made folder lost its silenceable hand-made WARN:"; printf '%s\n' "$R09_OUT"; exit 1; }
printf '%s\n' "$R09_OUT" | grep -q "Tickets/handmade-notes is a pending ticket" \
  && { echo "BUG [R-09 I]: hand-made folder wrongly got the PENDING WARN:"; printf '%s\n' "$R09_OUT"; exit 1; }
echo "  ok [R-09 I] — hand-made folder kept the silenceable hand-made WARN (distinct from pending)"

# [R-09 J] hand-made folder + .not-a-ticket → silent (unchanged behaviour). Proves the silenceable
#          WARN's .not-a-ticket escape still works for genuinely user-owned folders.
touch "$R09_HAND/.not-a-ticket"
set +e; R09_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "Tickets/handmade-notes" \
  && { echo "BUG [R-09 J]: silenced hand-made folder still surfaced:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -le "$BASELINE_RC" ] || { echo "BUG [R-09 J]: added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
echo "  ok [R-09 J] — hand-made folder silenced by .not-a-ticket, no new failure vs baseline"

# --- R-14: the pending COMPLETION path — the marker, not the name, is the lifecycle token -
# The nag must follow the .ticket-pending MARKER, not the folder name. A conforming rename
# alone must NOT complete a pending ticket (that would let a real ticket go silently misfiled
# under a made-up name); only removing the marker — a recorded human act — completes it.
# A name-first implementation reddens [R-09 K] (marker stranded → wrongly silent) and
# [R-09 M] (conforming-garbage rename → wrongly silent, the evasion).
R09_KCONF="Tickets/202607K-PROJ-500"   # a pending ticket after a legitimate conforming rename (marker still inside)
R09_MGARB="Tickets/202607M-XYZ-1"      # a pending ticket renamed to a conforming-but-arbitrary (garbage) identity

# [R-09 K] pending folder whose name now CONFORMS but marker remains → the "remove the marker
#          to finish" completion WARN, no new failure. Pins the mandatory exit path.
r09_make "$R09_KCONF"; touch "$R09_KCONF/.ticket-pending"
set +e; R09_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "Tickets/202607K-PROJ-500 looks complete" \
  || { echo "BUG [R-09 K]: conforming-named pending folder did not get the completion WARN:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -le "$BASELINE_RC" ] || { echo "BUG [R-09 K]: completion WARN added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
echo "  ok [R-09 K] — conforming name + lingering marker → 'remove the marker' completion WARN"

# [R-09 L] that same folder after `rm .ticket-pending` → the validator validates it AND status
#          goes silent for it. Pins that removing the marker actually COMPLETES the ticket.
rm "$R09_KCONF/.ticket-pending"
set +e; R09_OUT=$(bash _harness/scripts/check_ticket_log.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "OK: 202607K-PROJ-500 validated" \
  || { echo "BUG [R-09 L]: completed ticket did not validate after marker removal:"; printf '%s\n' "$R09_OUT"; exit 1; }
set +e; R09_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "Tickets/202607K-PROJ-500" \
  && { echo "BUG [R-09 L]: completed ticket still surfaced a WARN after marker removal:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -le "$BASELINE_RC" ] || { echo "BUG [R-09 L]: added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
echo "  ok [R-09 L] — marker removed → ticket validated and status silent (completion completes)"

# [R-09 M] pending folder renamed to conforming GARBAGE, marker still present → STILL nags
#          (the completion WARN). Pins that the nag follows the MARKER, not the name — the
#          rename-to-conforming-garbage evasion is closed.
r09_make "$R09_MGARB"; touch "$R09_MGARB/.ticket-pending"
set +e; R09_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); R09_RC=$?; set -e
printf '%s\n' "$R09_OUT" | grep -q "Tickets/202607M-XYZ-1 looks complete" \
  || { echo "BUG [R-09 M]: conforming-garbage rename silenced the nag — the marker no longer governs:"; printf '%s\n' "$R09_OUT"; exit 1; }
[ "$R09_RC" -le "$BASELINE_RC" ] || { echo "BUG [R-09 M]: added a NEW failure (rc=$R09_RC > baseline=$BASELINE_RC)"; exit 1; }
echo "  ok [R-09 M] — conforming-garbage rename STILL nags (nag follows the marker, not the name)"
# --- end pending-state guards (issue #25 / R-14) --------------------------------------

# Tear down the R-09 scratch folders so the estate is clean for the demonstration below.
rm -rf "$R09_SPACE" "$R09_CONF" "$R09_LONG" "$R09_BAD" "$R09_PEND" "$R09_HAND" "$R09_KCONF" "$R09_MGARB"
# --- end R-09 regression --------------------------------------------------------------

# --- R-10: the session-log header clock is LOCAL machine time -------------------------
# The validator reads a 14-digit header via epoch_from_ts14 (date -d/-j — LOCAL tz) and
# compares it to the watermark stamp_wall (date +%s — absolute epoch). Those two frames
# agree ONLY when the header is written in LOCAL time; a UTC header on a non-UTC machine is
# parsed hours behind and can land below the watermark, tripping a false "no new Session Log
# entry" FAIL that red-blocks honest work. That is the R-10 gap the now-named convention
# closes. This guard pins BOTH directions: a local-now header is accepted, and a UTC header
# on a simulated non-UTC machine is (correctly) refused — proving the comparison IS
# clock-sensitive, so the convention MUST name the clock. Runs before the first abort-prone
# harness-status call, like the R-09 block. TZ is forced to a fixed non-UTC zone here and
# restored afterwards so it never leaks into the rest of the demo.
echo "--- R-10: session-log header clock is LOCAL machine time ---"
R10="Tickets/202607R-PROJ-10"
R10_TZ_SAVE="${TZ-__unset__}"
export TZ='Etc/GMT-10'   # fixed UTC+10, no DST — makes local differ from UTC by a clear 10h
r09_make "$R10"
# Establish the watermark: validate once so stamp_wall (date +%s) is written for this ticket.
bash _harness/scripts/check_ticket_log.sh >/dev/null 2>&1 || true

# [R-10 local] a LOCAL-now header (what the named convention requires) is newer than the
#   watermark and is accepted — header and watermark share the absolute frame (EDIT 3 proved
#   epoch_from_ts14(local) == date +%s). A validator that parsed the header as UTC would
#   misread this and the OK below would vanish.
sleep 1
printf '\n## %s - local-clock session\n- work recorded in local machine time\n' "$(date +%Y%m%d%H%M%S)" >> "$R10/202607R-PROJ-10.md"
set +e; R10_OUT=$(bash _harness/scripts/check_ticket_log.sh 2>&1); R10_RC=$?; set -e
printf '%s\n' "$R10_OUT" | grep -q "202607R-PROJ-10 changed but no new Session Log entry" \
  && { echo "BUG [R-10]: a LOCAL-time header was misread as stale (false FAIL) — clock frames disagree:"; printf '%s\n' "$R10_OUT"; exit 1; }
printf '%s\n' "$R10_OUT" | grep -q "OK: 202607R-PROJ-10 validated" \
  || { echo "BUG [R-10]: local-time header not accepted:"; printf '%s\n' "$R10_OUT"; exit 1; }
echo "  ok [R-10 local] — local-time session header accepted (header and watermark share the frame)"

# [R-10 skew] a UTC header on this simulated non-UTC machine (exactly what a UTC-writing
#   scribe would emit) is parsed 10h behind by the LOCAL-tz validator, lands below the
#   watermark, and is correctly refused. This is the pre-fix bug reproduced: it proves the
#   comparison is clock-sensitive and that leaving the clock unnamed lets a scribe red-block
#   honest work. Naming the clock (EDIT 1/2) is what stops a scribe writing this header.
sleep 1
printf '\n## %s - utc-clock session (wrong clock)\n- work stamped in UTC by mistake\n' "$(date -u +%Y%m%d%H%M%S)" >> "$R10/202607R-PROJ-10.md"
set +e; R10_OUT=$(bash _harness/scripts/check_ticket_log.sh 2>&1); R10_RC=$?; set -e
printf '%s\n' "$R10_OUT" | grep -q "202607R-PROJ-10 changed but no new Session Log entry" \
  || { echo "BUG [R-10]: a UTC header on a non-UTC machine was NOT caught — the guard is blind to the clock frame:"; printf '%s\n' "$R10_OUT"; exit 1; }
echo "  ok [R-10 skew] — UTC-on-non-UTC header refused as stale (clock frame matters; convention must name it)"

# Restore TZ (whatever it was, including unset) and tear down the R-10 scratch ticket.
if [ "$R10_TZ_SAVE" = "__unset__" ]; then unset TZ; else export TZ="$R10_TZ_SAVE"; fi
rm -rf "$R10"
# --- end R-10 -------------------------------------------------------------------------

# --- G3: the human-run housekeeping script exists, runs, and reports (issue #16) ------
# Pins that harness-housekeeping.sh runs cleanly and reports sizes without touching records.
# It runs against a THROWAWAY repo (not the demo's real tree) so `git gc` has zero side effect
# on the estate — the demo's "uses temp state" promise holds. We assert only that it exits 0
# and reports .git size; NOT a specific reclaim amount (that varies with repo state).
echo "--- G3: housekeeping runs clean (human-run repo maintenance) ---"
G3_REPO=$(mktemp -d)
git -C "$G3_REPO" init -q
git -C "$G3_REPO" -c user.email=demo@local -c user.name=demo commit -q --allow-empty -m "seed"
set +e; G3_OUT=$(bash _harness/scripts/harness-housekeeping.sh "$G3_REPO" 2>&1); G3_RC=$?; set -e
[ "$G3_RC" -eq 0 ] || { echo "BUG [G3]: housekeeping exited non-zero (rc=$G3_RC):"; printf '%s\n' "$G3_OUT"; exit 1; }
printf '%s\n' "$G3_OUT" | grep -q "\.git" \
  || { echo "BUG [G3]: housekeeping did not report .git size:"; printf '%s\n' "$G3_OUT"; exit 1; }
printf '%s\n' "$G3_OUT" | grep -q "REPACK: git gc" \
  || { echo "BUG [G3]: housekeeping did not run the git gc repack step:"; printf '%s\n' "$G3_OUT"; exit 1; }
rm -rf "$G3_REPO"
echo "  ok [G3 housekeeping runs clean] — script runs, reports sizes, repacks, exit 0 (no record touched)"

# [G3 bloat WARN] harness-status nudges (WARN) when .git exceeds HARNESS_GIT_WARN_MB, and the
# nudge is YELLOW — exit stays 0, never a red FAIL. Force it by setting the threshold to 0 so
# any non-empty .git trips it; then set it very high and assert it does NOT fire — pinning both
# directions. Read-only: harness-status writes nothing, so running it on the real repo is safe.
set +e; G3W_OUT=$(HARNESS_GIT_WARN_MB=0 bash _harness/scripts/harness-status.sh 2>&1); G3W_RC=$?; set -e
printf '%s\n' "$G3W_OUT" | grep -q "WARN: the record repo's .git is" \
  || { echo "BUG [G3 bloat WARN]: the .git-size nudge did not fire at threshold 0:"; printf '%s\n' "$G3W_OUT"; exit 1; }
[ "$G3W_RC" -eq 0 ] || { echo "BUG [G3 bloat WARN]: the size nudge must be yellow (exit 0), got rc=$G3W_RC:"; printf '%s\n' "$G3W_OUT"; exit 1; }
echo "  ok [G3 bloat WARN] — .git-size nudge fires and stays non-blocking (WARN, exit 0)"
set +e; G3W_OUT2=$(HARNESS_GIT_WARN_MB=1000000 bash _harness/scripts/harness-status.sh 2>&1); set -e
printf '%s\n' "$G3W_OUT2" | grep -q "WARN: the record repo's .git is" \
  && { echo "BUG [G3 bloat WARN]: the size nudge fired while under threshold:"; printf '%s\n' "$G3W_OUT2"; exit 1; }
echo "  ok [G3 bloat WARN] — under threshold, no nudge (fires only when it should)"
# --- end G3 ---------------------------------------------------------------------------

# --- Backfill regression guards (issue #18): retroactive guards for #1, #3, #10 -------
# These three bugs were fixed and closed BEFORE the guard-per-bug law (#18) existed, so they
# shipped without guards. One guard each below, all witnessable on this host (no Mac needed),
# each provably red on the pre-fix behaviour.

# [#1 guard: no unguarded GNU-only construct] — the macOS/BSD portability contract. Static
# lexical check: every GNU-only command in the shell machinery must sit behind a BSD fallback,
# so nothing bare-GNU can regress in. HONEST LIMITATION: this is a commit-time lexical check,
# NOT a BSD runtime test (that needs BSD hardware — a deferred evidence box); it catches the #1
# regression CLASS (GNU-only commands with no fallback) without a Mac. Comments are stripped
# first so a construct merely NAMED in prose doesn't count. Paired forms (stat -c/-f, date -d/-j)
# must co-occur per file (a GNU call implies its BSD twin); unpaired GNU-only forms (GNU in-place
# sed, find -printf, readlink -f, grep -P) must be absent. run_demo.sh is skipped: it necessarily
# holds these token patterns as search literals (they would self-match), and it is itself run
# end-to-end on this host by the demo you are reading.
echo "--- #1/#3/#10: retroactive backfill guards (issue #18) ---"
g1_bad=0
for s in _harness/scripts/*.sh; do
  [ "$(basename "$s")" = "run_demo.sh" ] && continue
  code=$(sed 's/#.*//' "$s")     # drop comments (full + inline); only executable text is scanned
  if printf '%s' "$code" | grep -q 'stat -c' && ! printf '%s' "$code" | grep -q 'stat -f'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'stat -c' with no BSD 'stat -f' fallback."; g1_bad=1; fi
  if printf '%s' "$code" | grep -q 'date -d' && ! printf '%s' "$code" | grep -q 'date -j'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'date -d' with no BSD 'date -j' fallback."; g1_bad=1; fi
  if printf '%s' "$code" | grep -qE 'sed +(-[A-Za-z]+ +)*-i'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU in-place sed (not BSD-portable; use tmp+mv)."; g1_bad=1; fi
  if printf '%s' "$code" | grep -qE 'find .*-printf'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'find -printf' (absent in BSD find)."; g1_bad=1; fi
  if printf '%s' "$code" | grep -q 'readlink -f'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'readlink -f' (absent in BSD readlink)."; g1_bad=1; fi
  if printf '%s' "$code" | grep -qE 'grep -[a-zA-Z]*P'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'grep -P' PCRE (absent in BSD grep)."; g1_bad=1; fi
done
[ "$g1_bad" -eq 0 ] || { echo "BUG [#1 guard]: an unguarded GNU-only construct is present (see FAILs above)"; exit 1; }
echo "  ok [#1 guard: no unguarded GNU-only construct] — every GNU call has a BSD fallback"

# [#3 guard: freshness and recency use independent clocks] — the dual-clock watermark. The stamp
# is two lines: line 1 = wall-clock (date +%s; recency = newest header >= last validation), line 2
# = md mtime (freshness = did the file change since last validation). Different clocks, kept
# separate. This pins that freshness reads line 2 (mtime), independent of line 1 (wall): a change
# whose new mtime lands BETWEEN the stored mtime and the stored wall time is noticed only by a
# line-2 read. A single-line stamp (one value for both) would use the wall clock for freshness and
# MISS such a change — the exact #3 bug. (Distinct from the R-10 guard, which is about the header's
# TIMEZONE; this is about the two stamp lines being separate values.) touch -t is POSIX (GNU+BSD).
G3T="Tickets/202607S-PROJ-33"; g3md="$G3T/202607S-PROJ-33.md"
r09_make "$G3T"
sleep 1                                     # make the validation wall-clock strictly after the header time
# mnemonics below: mt1 = the anchored mtime (Jan 1), mt2 = the advanced mtime (Feb 1),
# wall1 = the wall-clock at validation ('now'). Ordering that matters: mt1 < mt2 < wall1.
touch -t "$(date +%Y)01010000" "$g3md"      # anchor mtime to Jan 1 this year (mt1) — months before 'now' (wall1)
bash _harness/scripts/check_ticket_log.sh >/dev/null 2>&1 || true   # stamp written: line1=wall1(now), line2=mt1(Jan1)
# Case A — advance mtime to Feb 1 (mt1 < mt2 < wall1) with NO new header. The change is above the
# stored mtime but below the wall clock, so only a line-2 (mtime) freshness read notices it. Two-clock
# → re-checks and FAILs "no new Session Log entry". Single-clock (line2=line1=wall1) → mt2 < wall1 →
# "unchanged" → silently skips (the bug).
touch -t "$(date +%Y)02010000" "$g3md"
set +e; G3A=$(bash _harness/scripts/check_ticket_log.sh 2>&1); set -e
printf '%s\n' "$G3A" | grep -q "202607S-PROJ-33 changed but no new Session Log entry" \
  || { echo "BUG [#3 guard]: an mtime change below the wall clock was NOT noticed — freshness isn't reading the stamp's mtime line:"; printf '%s\n' "$G3A"; exit 1; }
# Case B — complement: a genuine new header at/after the watermark AND mtime advances → both axes
# satisfied → validates OK.
printf '\n## %s - real new session\n- work recorded\n' "$(date +%Y%m%d%H%M%S)" >> "$g3md"
set +e; G3B=$(bash _harness/scripts/check_ticket_log.sh 2>&1); set -e
printf '%s\n' "$G3B" | grep -q "OK: 202607S-PROJ-33 validated" \
  || { echo "BUG [#3 guard]: a real new session header was not accepted:"; printf '%s\n' "$G3B"; exit 1; }
rm -rf "$G3T"
echo "  ok [#3 guard: freshness and recency use independent clocks] — mtime change noticed, new header accepted"

# [#10 guard: real clone WIP not absorbed] — the demo's closing commit is gated behind DID_INIT so
# it fires ONLY when the demo created the repo. In a real clone (DID_INIT=0) it must do nothing,
# never sweeping a user's uncommitted work into a "demo: pass" commit. Exercises the ACTUAL gate
# (demo_close_commit — the same function the demo's closing step calls) against a throwaway repo
# that already has .git and a dirty tracked file. This is the reviewer's WIP-absorption probe made
# a standing guard.
G10=$(mktemp -d)
git -C "$G10" init -q
printf 'committed line\n' > "$G10/tracked.txt"
git -C "$G10" add -A; git -C "$G10" -c user.email=demo@local -c user.name=demo commit -qm "seed" >/dev/null
G10_HEAD=$(git -C "$G10" rev-parse HEAD)
printf 'UNCOMMITTED-WIP-MARKER\n' >> "$G10/tracked.txt"   # dirty the TRACKED file — a real clone's in-progress work
demo_close_commit 0 "$G10"                                # DID_INIT=0 → the gate must do NOTHING
# The load-bearing #10/P-i check: the dirty WIP must NOT be absorbed into any commit. Grep the WHOLE
# history for the WIP marker — a broken gate that commits the working tree leaves the marker in a
# commit, and this finds it. (The old guard only checked "no demo: pass commit", which ANY
# unconditional commit trips even with zero WIP present — that tautology was R-20; this asserts the
# WIP-specific property, and the revert-proof now flips because the WIP is ABSORBED, not merely
# because a commit exists.)
git -C "$G10" log -p 2>/dev/null | grep -q "UNCOMMITTED-WIP-MARKER" \
  && { echo "BUG [#10 guard]: the dirty tracked WIP was ABSORBED into a commit (a real clone's work must never be committed under DID_INIT=0):"; git -C "$G10" log --oneline; exit 1; }
# Corroborate: HEAD never moved (no new commit at all) and the working tree still reads as dirty.
[ "$(git -C "$G10" rev-parse HEAD)" = "$G10_HEAD" ] \
  || { echo "BUG [#10 guard]: HEAD advanced — the gate committed under DID_INIT=0"; git -C "$G10" log --oneline; exit 1; }
[ -n "$(git -C "$G10" status --porcelain)" ] \
  || { echo "BUG [#10 guard]: the working tree is clean — the dirty WIP was swept into a commit"; exit 1; }
rm -rf "$G10"
echo "  ok [#10 guard: real clone WIP not absorbed] — dirty tracked WIP stays uncommitted under DID_INIT=0"

# [R-21 guard: ts14->epoch has one home] — epoch_from_ts14 must live ONCE (portability.sh), sourced by
# both the validator and status so they can't drift (they were duplicated in M3). Assert: neither
# script defines its own copy; both source portability.sh; and the one shared function converts a
# known header correctly. Re-introducing a local copy in either script reddens this.
grep -qE '^[[:space:]]*epoch_from_ts14\(\)' _harness/scripts/check_ticket_log.sh \
  && { echo "BUG [R-21 guard]: check_ticket_log.sh defines its own epoch_from_ts14 (drift risk — source portability.sh)"; exit 1; }
grep -qE '^[[:space:]]*epoch_from_ts14\(\)' _harness/scripts/harness-status.sh \
  && { echo "BUG [R-21 guard]: harness-status.sh defines its own epoch_from_ts14 (drift risk — source portability.sh)"; exit 1; }
{ grep -q 'source .*portability\.sh' _harness/scripts/check_ticket_log.sh && grep -q 'source .*portability\.sh' _harness/scripts/harness-status.sh; } \
  || { echo "BUG [R-21 guard]: both the validator and status must source portability.sh"; exit 1; }
( source _harness/scripts/portability.sh
  r21_got=$(epoch_from_ts14 "20260101120000")
  r21_want=$(date -d "2026-01-01 12:00:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "2026-01-01 12:00:00" +%s 2>/dev/null || echo x)
  [ -n "$r21_got" ] && [ "$r21_got" = "$r21_want" ] \
    || { echo "BUG [R-21 guard]: shared epoch_from_ts14 gave '$r21_got', expected '$r21_want'"; exit 1; } )
echo "  ok [R-21 guard: ts14->epoch has one home] — single shared function, both tools source it, converts correctly"
# --- end backfill guards --------------------------------------------------------------

# --- status consolidation guards (#8+R-05, #14, R-11) --------------------------------
echo "--- status consolidation (#8+R-05 argv, #14 zip fallback, R-11 stale-commit) ---"

# [#8+R-05 guard: hooks path passed as argv, awkward path safe] — the hooks-parse check must work
# when the path contains a character that would BREAK a Python source-string literal. A single
# quote is the reliable case (a space or plain unicode does NOT break the literal, verified); it
# reproduces the #8/R-05 "path corrupts the source string" class on ANY host — the Git-Bash MSYS
# case is the same class. We point status at an awkward-named copy of the real hooks file via
# HARNESS_HOOKS_FILE and assert it still parses OK. (The Git-Bash MSYS-path FORMAT half additionally
# wants a Git-Bash witness; the cygpath branch is dormant/untested on this host.)
G8DIR=$(mktemp -d); G8="$G8DIR/quote'inside hooks.json"
cp _harness/hooks/hooks.example.json "$G8"
set +e; G8_OUT=$(HARNESS_HOOKS_FILE="$G8" bash _harness/scripts/harness-status.sh 2>&1); set -e
printf '%s\n' "$G8_OUT" | grep -q "OK: hooks config parses." \
  || { echo "BUG [#8+R-05 guard]: valid JSON at an awkward (quote-bearing) path was NOT parsed — the argv fix regressed:"; printf '%s\n' "$G8_OUT" | grep -i hooks; exit 1; }
printf '%s\n' "$G8_OUT" | grep -q "hooks config is invalid JSON" \
  && { echo "BUG [#8+R-05 guard]: awkward path wrongly reported as invalid JSON (source-string mangling):"; printf '%s\n' "$G8_OUT" | grep -i hooks; exit 1; }
rm -rf "$G8DIR"
echo "  ok [#8+R-05 guard: hooks path passed as argv, awkward path safe] — quote-bearing path parses OK"

# [#14 guard: pack completes without zip] — with the zip CLI unavailable the context pack must still
# build via the Python zipfile fallback (python3 is already required). HARNESS_PACK_NO_ZIP=1 forces
# the fallback deterministically (cleaner than PATH surgery, and it exercises the exact fallback
# path). Assert the pack is produced and is a readable archive.
G14_OUT_DIR=$(mktemp -d)
set +e; G14_OUT=$(HARNESS_PACK_NO_ZIP=1 PACK_OUT_DIR="$G14_OUT_DIR" bash _harness/scripts/make_context_pack.sh --ticket 999911Z-PROJ-99998 2>&1); G14_RC=$?; set -e
[ "$G14_RC" -eq 0 ] || { echo "BUG [#14 guard]: pack failed with zip forced off (rc=$G14_RC):"; printf '%s\n' "$G14_OUT"; exit 1; }
g14zip=$(ls "$G14_OUT_DIR"/harness-pack-*.zip 2>/dev/null | head -1 || true)   # no-match must not trip set -e/pipefail
{ [ -n "$g14zip" ] && python3 -c 'import zipfile,sys; sys.exit(1 if zipfile.ZipFile(sys.argv[1]).testzip() else 0)' "$g14zip" 2>/dev/null; } \
  || { echo "BUG [#14 guard]: no readable pack archive produced by the fallback:"; printf '%s\n' "$G14_OUT"; exit 1; }
rm -rf "$G14_OUT_DIR"
echo "  ok [#14 guard: pack completes without zip] — Python zipfile fallback produced a readable archive"

# [R-11 guard: stale-commit WARN] — status must nudge (WARN) when session activity is newer than the
# last commit + margin (auto-commit may have silently stopped), and stay silent otherwise; either
# way exit 0 (yellow). The check is HARNESS_DEMO-suppressed, so the guard sets HARNESS_LIVENESS_FORCE
# to exercise the real code. Both directions are driven deterministically by the margin knob against
# a scratch ticket dated NEXT YEAR: margin 0 → the future session outpaces the commit → WARN fires;
# a ~30-year margin → even a next-year session is within margin → no WARN. HARNESS_DEMO stays set so
# the remote reads as a NOTE (rc 0), isolating the nudge from the estate's exit code.
R11T="Tickets/202607L-PROJ-11"; r11md="$R11T/202607L-PROJ-11.md"
r09_make "$R11T"
r11_nyr=$(( $(date +%Y) + 1 ))    # next year → a session-header epoch always beyond 'now'
printf '\n## %s0101000000 - future-dated session\n- work newer than the last commit\n' "$r11_nyr" >> "$r11md"
set +e; R11_OUT=$(HARNESS_LIVENESS_FORCE=1 HARNESS_COMMIT_LAG_WARN_S=0 bash _harness/scripts/harness-status.sh 2>&1); R11_RC=$?; set -e
printf '%s\n' "$R11_OUT" | grep -q "recent session activity" \
  || { echo "BUG [R-11 guard]: session activity newer than the last commit did NOT raise the stale-commit WARN:"; printf '%s\n' "$R11_OUT"; exit 1; }
[ "$R11_RC" -eq 0 ] || { echo "BUG [R-11 guard]: the stale-commit nudge must be yellow (exit 0), got rc=$R11_RC"; exit 1; }
set +e; R11_OUT2=$(HARNESS_LIVENESS_FORCE=1 HARNESS_COMMIT_LAG_WARN_S=999999999 bash _harness/scripts/harness-status.sh 2>&1); set -e
printf '%s\n' "$R11_OUT2" | grep -q "recent session activity" \
  && { echo "BUG [R-11 guard]: stale-commit WARN fired while within the lag margin (commit current):"; printf '%s\n' "$R11_OUT2"; exit 1; }
rm -rf "$R11T"
echo "  ok [R-11 guard: stale-commit WARN] — fires when session activity outpaces the last commit, silent within margin"
# --- end status consolidation guards -------------------------------------------------

# Break-and-restore status demonstration — deliberately runs AFTER the R-09 block so that on
# a lane where a plain `harness-status` aborts under set -e, the R-09 stages have already been
# witnessed. The first call shows a healthy estate; then we remove a deployed agent and watch
# status prescribe the fix (its rc=1 is the point — the `|| echo` keeps the demo alive);
# restore it; and confirm the estate reads healthy again.
bash _harness/scripts/harness-status.sh
mv "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md" /tmp/dw.bak
bash _harness/scripts/harness-status.sh || echo "--- correctly failed with a fix line ---"
mv /tmp/dw.bak "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md"
bash _harness/scripts/harness-status.sh >/dev/null && echo "healthy after fix"

# --- R-08 guard: every agent is directly human-callable -------------------------------
# Asserts every _agents/*.agent.md declares `user-invocable: true`. The clerk agents
# (ticket-scribe, knowledge-keeper, check-scribe) still run automatically at task end, but
# a human must also be able to invoke any of them directly. This guard FAILS on pre-flip
# code (where those three were `user-invocable: false`), so the demo pins the flip.
echo "--- R-08: all agents are user-invocable ---"
r08_total=0; r08_bad=0
for a in _agents/*.agent.md; do
  r08_total=$((r08_total+1))
  grep -q '^user-invocable: true$' "$a" || { echo "FAIL [R-08]: $a is not 'user-invocable: true' — every agent must be directly human-callable."; r08_bad=$((r08_bad+1)); }
done
[ "$r08_bad" -eq 0 ] || { echo "BUG [R-08]: $r08_bad agent(s) not user-invocable"; exit 1; }
echo "  ok [R-08] — all $r08_total agents are user-invocable: true"
# --- end R-08 guard -------------------------------------------------------------------

echo "=== 6/6 scrubbed context pack + self-audit ==="
bash _harness/scripts/make_context_pack.sh --ticket 999911Z-PROJ-99998
unzip -p "$PACK_OUT_DIR"/harness-pack-*.zip MANIFEST.txt | tail -1

rm -rf "$S"
demo_close_commit "$DID_INIT" "."   # gated: commits only if the demo created this repo (issue #10)
echo; echo "ALL 6 DEMO STAGES PASSED — the machinery works. Next: INSTALL.md to wire Copilot."
