#!/usr/bin/env bash
# run_demo.sh — proves the harness machinery works on THIS machine in ~20s.
# No Copilot needed. Safe: uses temp state, creates+destroys one scratch ticket.
set -euo pipefail
export HARNESS_DEMO=1   # lets status treat a template-clone remote as a NOTE, not a FAIL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."
DEMO_ROOT=$PWD
export HARNESS_STATE_DIR=$(mktemp -d) HARNESS_AGENT_DEPLOY_DIR=$(mktemp -d) PACK_OUT_DIR=$(mktemp -d)

# cleanup runs on EXIT — normal, a set -e abort, or Ctrl-C. It removes the temp dirs AND any
# Tickets/ folder THIS run created but didn't tear down. Success-path teardown is explicit below,
# but a run that DIES mid-stage used to leave scratch tickets behind (untracked, so git stayed
# clean) and the NEXT run then red-blocked at stage 1 on the leftovers — a misleading second
# failure (the "leftover-scratch-folder collision"). Snapshotting the real tickets up front and
# deleting anything not in that snapshot makes an aborted run clean up after itself, and never
# touches a pre-existing (real) ticket. DEMO_SNAPSHOT_DONE guards the window before the snapshot
# exists, so a very early death can't delete real tickets.
DEMO_PRE_TICKETS=""; DEMO_SNAPSHOT_DONE=0
cleanup() {
  rm -rf "$HARNESS_STATE_DIR" "$HARNESS_AGENT_DEPLOY_DIR" "$PACK_OUT_DIR"
  [ "$DEMO_SNAPSHOT_DONE" = 1 ] || return 0
  local d name
  for d in "$DEMO_ROOT/Tickets"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    printf '%s\n' "$DEMO_PRE_TICKETS" | grep -Fxq "$name" || rm -rf "$d"
  done
}
trap cleanup EXIT
S="Tickets/999911Z-PROJ-99998"; rm -rf "$S"
# Snapshot the real (pre-existing) tickets so cleanup removes ONLY what THIS run creates.
DEMO_PRE_TICKETS=$(for d in "$DEMO_ROOT/Tickets"/*/; do [ -d "$d" ] && basename "$d"; done 2>/dev/null)
DEMO_SNAPSHOT_DONE=1

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

# [R-09 D] the context-pack builder handles a space-named ticket at exit 0 (needs zip). It writes to
# its OWN throwaway pack dir (like the [#14 guard] below), NOT the demo's shared PACK_OUT_DIR: if this
# pack and stage 6's both landed in the shared dir across a minute boundary (make_context_pack's STAMP
# is minute-granular), two harness-pack-*.zip would accumulate there and stage 6's unzip glob would
# match both and fail — the timing flake CI caught on the slower macOS runner. Own dir = timing can't matter.
R09D_OUT=$(mktemp -d)
set +e; PACK_OUT_DIR="$R09D_OUT" bash _harness/scripts/make_context_pack.sh --ticket "My Random Ticket 42" >/dev/null; R09_RC=$?; set -e
rm -rf "$R09D_OUT"
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
#   watermark and is accepted — header and watermark share the absolute frame (a local-time header
#   converts to the same epoch date +%s records: epoch_from_ts14(local) == date +%s). A validator that parsed the header as UTC would
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
#   honest work. Naming the clock as local in the convention and the ticket-scribe agent is what stops a scribe writing this header.
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

# [#86 worktree store] Both size reporters must resolve the REAL git store from a LINKED WORKTREE,
# where .git is a pointer FILE rather than a directory. Pre-fix, harness-status path-tested
# `[ -d "$WORK_ROOT/.git" ]` and the whole nudge vanished without a word, so the demo could not pass
# from any worktree — which is exactly where parallel-lane build work runs; harness-housekeeping
# du'd the same path and reported a ~4 KiB ".git" while repacking the real store correctly, i.e. a
# truthful action with a false report. FIXTURE: a THROWAWAY repo carrying a copy of _harness (status
# derives its root from its own location, so the script must live inside the fixture) plus a linked
# worktree of it. The real estate is never worktree-added, so nothing is registered in the user's
# repo and no record is touched. NOTE: the fixture is not a full estate, so harness-status exits
# non-zero there on unrelated checks — assert on the nudge LINE, never on the fixture's exit code.
# Cleanup is an explicit rm (the demo's single EXIT trap belongs to cleanup(); do not add another).
echo "--- #86: size probes resolve the store from a linked worktree ---"
W86=$(mktemp -d)
mkdir -p "$W86/repo"
git -C "$W86/repo" init -q
cp -R _harness "$W86/repo/_harness"
git -C "$W86/repo" -c user.email=demo@local -c user.name=demo add -A
git -C "$W86/repo" -c user.email=demo@local -c user.name=demo commit -q -m "seed"
git -C "$W86/repo" -c user.email=demo@local -c user.name=demo worktree add -q "$W86/wt" -b w86
W86_EXPECT=$(du -sk "$W86/repo/.git" 2>/dev/null | awk '{print $1}')

set +e; W86_OUT=$(cd "$W86/wt" && HARNESS_GIT_WARN_MB=0 bash _harness/scripts/harness-status.sh 2>&1); set -e
printf '%s\n' "$W86_OUT" | grep -q "WARN: the record repo's .git is" \
  || { echo "BUG [#86 worktree store]: the .git-size nudge did not fire from a linked worktree — the probe still assumes .git is a directory:"; printf '%s\n' "$W86_OUT"; rm -rf "$W86"; exit 1; }
printf '%s\n' "$W86_OUT" | grep -q "\.git is 0\.0 MiB" \
  && { echo "BUG [#86 worktree store]: the nudge weighed the .git POINTER FILE (0.0 MiB), not the shared store:"; printf '%s\n' "$W86_OUT"; rm -rf "$W86"; exit 1; }
echo "  ok [#86 worktree store] — status nudge fires from a worktree and weighs the real store"

set +e; W86_OUT2=$(cd "$W86/wt" && HARNESS_GIT_WARN_MB=1000000 bash _harness/scripts/harness-status.sh 2>&1); set -e
printf '%s\n' "$W86_OUT2" | grep -q "WARN: the record repo's .git is" \
  && { echo "BUG [#86 worktree store]: the nudge fired from a worktree while under threshold:"; printf '%s\n' "$W86_OUT2"; rm -rf "$W86"; exit 1; }
echo "  ok [#86 worktree store] — under threshold, no nudge from a worktree either"

set +e; W86_HK=$(bash _harness/scripts/harness-housekeeping.sh "$W86/wt" 2>&1); W86_HK_RC=$?; set -e
[ "$W86_HK_RC" -eq 0 ] || { echo "BUG [#86 worktree store]: housekeeping exited non-zero against a worktree (rc=$W86_HK_RC):"; printf '%s\n' "$W86_HK"; rm -rf "$W86"; exit 1; }
W86_GOT=$(printf '%s\n' "$W86_HK" | sed -n 's/^BEFORE: \.git \([0-9-]*\) KiB.*/\1/p')
[ "$W86_GOT" = "$W86_EXPECT" ] \
  || { echo "BUG [#86 worktree store]: housekeeping reported .git as ${W86_GOT} KiB from a worktree; the real store is ${W86_EXPECT} KiB — the report is a fiction:"; printf '%s\n' "$W86_HK"; rm -rf "$W86"; exit 1; }
W86_WT=$(printf '%s\n' "$W86_HK" | sed -n 's/^BEFORE: .* working tree \([0-9-]*\) KiB.*/\1/p')
case "$W86_WT" in -*|"") echo "BUG [#86 worktree store]: housekeeping reported a negative/blank working tree (${W86_WT} KiB) — an out-of-tree store was subtracted:"; printf '%s\n' "$W86_HK"; rm -rf "$W86"; exit 1 ;; esac
echo "  ok [#86 worktree store] — housekeeping weighs the real store (${W86_EXPECT} KiB) and keeps the working tree honest"
rm -rf "$W86"
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
# code_has / code_hasE — does the comment-stripped script text $code contain PATTERN?
# HERE-STRING, deliberately NOT `printf '%s' "$code" | grep -q`: under `set -o pipefail`
# grep -q's early exit on a match closes the pipe while printf is still writing, printf
# takes SIGPIPE, and pipefail turns that into a FALSE pipeline failure on a match (#35 —
# the exact class the #10 guard already avoids). A here-string has no pipe, so a match
# always reads as success. code_has = BRE (grep -q); code_hasE = ERE (grep -qE).
code_has()  { grep -q  "$1" <<< "$code"; }
code_hasE() { grep -qE "$1" <<< "$code"; }
for s in _harness/scripts/*.sh; do
  [ "$(basename "$s")" = "run_demo.sh" ] && continue
  code=$(sed 's/#.*//' "$s")     # drop comments (full + inline); only executable text is scanned
  if code_has 'stat -c' && ! code_has 'stat -f'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'stat -c' with no BSD 'stat -f' fallback."; g1_bad=1; fi
  if code_has 'date -d' && ! code_has 'date -j'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'date -d' with no BSD 'date -j' fallback."; g1_bad=1; fi
  if code_hasE 'sed +(-[A-Za-z]+ +)*-i'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU in-place sed (not BSD-portable; use tmp+mv)."; g1_bad=1; fi
  if code_hasE 'find .*-printf'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'find -printf' (absent in BSD find)."; g1_bad=1; fi
  if code_has 'readlink -f'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'readlink -f' (absent in BSD readlink)."; g1_bad=1; fi
  if code_hasE 'grep -[a-zA-Z]*P'; then
    echo "FAIL [#1]: $(basename "$s") uses GNU 'grep -P' PCRE (absent in BSD grep)."; g1_bad=1; fi
done
[ "$g1_bad" -eq 0 ] || { echo "BUG [#1 guard]: an unguarded GNU-only construct is present (see FAILs above)"; exit 1; }
echo "  ok [#1 guard: no unguarded GNU-only construct] — every GNU call has a BSD fallback"

# [sigpipe-safety guard (#35)] — proves the #1 match helpers are here-string-safe: a match
# under pipefail reads as SUCCESS, never a SIGPIPE-false-fail. DETERMINISTIC: with a LARGE
# $code whose match token is at the very top, the old `printf | grep -q` form would reliably
# SIGPIPE (printf can't drain ~500 KiB into a 64 KiB pipe buffer before grep exits), so this
# goes RED the instant code_has/code_hasE are reverted to the piped form; the here-string
# form passes. Subshell so the large $code never leaks to later stages.
if ( code=$(printf 'SIGPIPE_PROBE_TOKEN\n'; head -c 500000 /dev/zero | tr '\000' 'x')
     code_has 'SIGPIPE_PROBE_TOKEN' && code_hasE 'SIGPIPE_PROBE_TOKEN' ); then
  echo "  ok [sigpipe-safety] — code_has/code_hasE return success on a large-input match under pipefail (no SIGPIPE)"
else
  echo "FAIL [sigpipe-safety]: a large-input match did not read as success — helpers are not here-string-safe (#35)."; exit 1
fi

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
# Buffer the full history first, THEN grep it via a here-string — not `git log -p | grep -q`, whose
# early exit SIGPIPEs git and, under the demo's pipefail, fails the pipeline even ON a match, so the
# named WIP-absorption assertion silently never fires and the corroborating check fires instead.
g10_hist=$(git -C "$G10" log -p 2>/dev/null || true)
if grep -q "UNCOMMITTED-WIP-MARKER" <<<"$g10_hist"; then
  echo "BUG [#10 guard]: the dirty tracked WIP was ABSORBED into a commit (a real clone's work must never be committed under DID_INIT=0):"; git -C "$G10" log --oneline; exit 1
fi
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

# [#44 hooks-schema] STRUCTURAL check of the SHIPPED, witnessed hooks.example.json — it must parse
# and carry the deployment-proven shape: top-level "version", the three camelCase events NESTED
# UNDER a "hooks" wrapper (NOT top-level — the proven v4 config wraps them), entries keyed on
# "bash" with NO legacy "command"/"toolFilter". This is STRUCTURE ONLY: it does NOT and must not
# pretend to witness a hook firing — the live fire stayed an honest human-witnessed box (#44 cond
# 3). Revert-provable: drop the "hooks" wrapper, a wrapped event key, or the "bash" key and this
# guard reds. (A guard that passed a wrapper-less config is exactly the bug to catch.)
if ! HS44_OUT=$(python3 - "_harness/hooks/hooks.example.json" <<'PY' 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("version") == 1, "top-level 'version' must be 1"
hooks = d.get("hooks")
assert isinstance(hooks, dict), "events must be nested under a 'hooks' wrapper object"
for e in ("sessionStart", "postToolUse", "sessionEnd"):
    assert e in hooks and isinstance(hooks[e], list) and hooks[e], f"missing or empty wrapped event: hooks.{e}"
    for entry in hooks[e]:
        assert "bash" in entry, f"hooks.{e}: entry missing the verified 'bash' key"
        assert "command" not in entry, f"hooks.{e}: entry carries the legacy 'command' key"
        assert "toolFilter" not in entry, f"hooks.{e}: entry carries the legacy 'toolFilter' key"
PY
); then
  echo "BUG [#44 hooks-schema]: the shipped hooks.example.json failed its verified-schema structural check:"
  printf '%s\n' "$HS44_OUT"
  exit 1
fi
echo "  ok [#44 hooks-schema] — hooks.example.json parses; hooks.{sessionStart,postToolUse,sessionEnd} present; verified 'bash' shape, no legacy command/toolFilter"

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

# [#37] harness-status must NOT abort on a conforming ticket that has NO AI-Knowledge/ dir
# (hand-made/legacy — the validator tolerates it). Pre-fix, the unguarded find at
# harness-status.sh:155 exits non-zero on the missing dir and (pipefail + set -e) aborts the
# roster loop BEFORE this ticket's line prints — suppressing the whole estate's roster. This
# is the FIRST conforming-ticket-without-AI-Knowledge fixture in the demo (r09_make builds its
# conforming fixtures WITH AI-Knowledge, so the field hit a case the demo never covered).
# NOTE: the demo runs with CWD = repo root and never defines WORK_ROOT (harness-status resolves
# it internally); like every other fixture here the ticket path is relative to Tickets/.
set +e; PRE37_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); PRE37_RC=$?; set -e
NOAK="Tickets/202607D-PROJ-777"
mkdir -p "$NOAK"     # deliberately NO AI-Knowledge/ subdir — the bug trigger
cat > "$NOAK/202607D-PROJ-777.md" <<'MD'
# 202607D-PROJ-777
## Current State
Legacy ticket imported by hand; no learnings captured yet.
## Session Log
## 20260704120000 - imported
Hand-created for the #37 fixture.
MD
set +e; NOAK_OUT=$(bash _harness/scripts/harness-status.sh 2>&1); NOAK_RC=$?; set -e
printf '%s\n' "$NOAK_OUT" | grep -q '202607D-PROJ-777.*knowledge files: 0' \
  || { echo "BUG [#37]: harness-status did not reach the AI-Knowledge-less ticket's roster line (it aborted at the unguarded find):"; printf '%s\n' "$NOAK_OUT"; exit 1; }
[ "$NOAK_RC" -le "$PRE37_RC" ] || { echo "BUG [#37]: the AI-Knowledge-less ticket added a NEW failure / abort (rc=$NOAK_RC > baseline=$PRE37_RC)"; exit 1; }
rm -rf "$NOAK"
echo "  ok [#37] — harness-status completes on a conforming ticket with no AI-Knowledge/ (roster reached, no new failure)"

# [#38 junk-ignore] objective editor/OS junk must be ignored even inside re-included dirs so it
# never enters the record. Pre-fix (no junk patterns in .gitignore), git add -A stages it — red.
J="Tickets/junk-probe"; mkdir -p "$J"
: > "$J/scratch.tmp"; : > "$J/backup~"; : > "$J/.file.swp"; : > "$J/Thumbs.db"
JUNK_STAGED=$(git add -A --dry-run 2>/dev/null | grep -E 'junk-probe/(scratch\.tmp|backup~|\.file\.swp|Thumbs\.db)' || true)
[ -z "$JUNK_STAGED" ] || { echo "BUG [#38 junk-ignore]: objective junk would be staged (not ignored):"; printf '%s\n' "$JUNK_STAGED"; exit 1; }
rm -rf "$J"
echo "  ok [#38 junk-ignore] — *.tmp / *~ / *.swp / Thumbs.db ignored, never staged"

# [#38 oversize WARN] a ticket whose TRACKED root (excluding the ignored Logs/, Dump/) grows
# large gets a yellow WARN prescribing Dump/ — never a block. Also proves Dump/ is EXCLUDED
# from the measure (so moving scratch there actually clears it) and the knob is honoured both
# ways. ~2 MiB of padding lands the root over a 1 MiB threshold.
O="Tickets/202607E-PROJ-888"; mkdir -p "$O"
cat > "$O/202607E-PROJ-888.md" <<'MD'
# 202607E-PROJ-888
## Current State
Oversize-root fixture for #38.
## Session Log
## 20260705120000 - fixture
MD
head -c 2097152 /dev/zero > "$O/big-scratch.bin"     # ~2 MiB in the TRACKED root
# (1) oversized root -> WARN fires with the Dump/ prescription, exit 0 (yellow)
set +e; O38=$(HARNESS_TICKET_WARN_MB=1 bash _harness/scripts/harness-status.sh 2>&1); O38_RC=$?; set -e
printf '%s\n' "$O38" | grep -qE 'Tickets/202607E-PROJ-888 tracks .* in its root' \
  || { echo "BUG [#38 oversize WARN]: oversized ticket root did not fire the WARN:"; printf '%s\n' "$O38"; exit 1; }
printf '%s\n' "$O38" | grep -q 'Dump/' \
  || { echo "BUG [#38 oversize WARN]: the WARN did not prescribe Dump/:"; printf '%s\n' "$O38"; exit 1; }
[ "$O38_RC" -eq 0 ] || { echo "BUG [#38 oversize WARN]: the size nudge must be yellow (exit 0), got rc=$O38_RC"; exit 1; }
# (2) move padding into Dump/ -> WARN must NOT fire (Dump/ is excluded; the prescription works)
mkdir -p "$O/Dump"; mv "$O/big-scratch.bin" "$O/Dump/big-scratch.bin"
set +e; O38b=$(HARNESS_TICKET_WARN_MB=1 bash _harness/scripts/harness-status.sh 2>&1); set -e
printf '%s\n' "$O38b" | grep -qE 'Tickets/202607E-PROJ-888 tracks .* in its root' \
  && { echo "BUG [#38 oversize WARN]: moving scratch to Dump/ did NOT clear the WARN (Dump/ not excluded):"; printf '%s\n' "$O38b"; exit 1; }
# (3) knob honoured: a huge threshold silences it even with padding back in the root
mv "$O/Dump/big-scratch.bin" "$O/big-scratch.bin"
set +e; O38c=$(HARNESS_TICKET_WARN_MB=1000000 bash _harness/scripts/harness-status.sh 2>&1); set -e
printf '%s\n' "$O38c" | grep -qE 'Tickets/202607E-PROJ-888 tracks .* in its root' \
  && { echo "BUG [#38 oversize WARN]: the size nudge fired while under the knob threshold:"; printf '%s\n' "$O38c"; exit 1; }
rm -rf "$O"
echo "  ok [#38 oversize WARN] — fires with Dump/ prescription (yellow), clears when scratch moves to Dump/, honours the knob"

# [#47 + #49 governance gates] revert-proofs for the LOCALLY-decidable gate scripts under
# .github/scripts/ (the API existence/OPEN check is CI-only and witnessed at the seat, not here).
# Same shape as #38: these call the very scripts the workflow calls, so weakening a grammar or
# pattern turns the matching guard RED. CWD is the repo root, so the relative paths resolve.

# [#47 branch-grammar] the NN-slug grammar ACCEPTS the conforming set AND REJECTS the
# non-conforming set — both directions, so loosening OR tightening the regex reds this guard.
GRAM=.github/scripts/branch-grammar.sh
for good in 37-status-abort-fix 47-governance-pair; do
  bash "$GRAM" "$good" >/dev/null 2>&1 || { echo "BUG [#47 branch-grammar]: conforming '$good' was rejected"; exit 1; }
done
for bad in WSL-canonical Feature/Foo 47_governance mixedCase; do
  bash "$GRAM" "$bad" 47 >/dev/null 2>&1 && { echo "BUG [#47 branch-grammar]: non-conforming '$bad' was accepted"; exit 1; }
done
# Capture the miss message before grepping — the script exits non-zero by design, and
# grepping it through a pipe would let pipefail red this even when the text matches.
GRAM_MISS=$(bash "$GRAM" "Feature/Foo" 47 2>&1 || true)
printf '%s\n' "$GRAM_MISS" | grep -q 'git branch -m' \
  || { echo "BUG [#47 branch-grammar]: miss message lacks the literal 'git branch -m' rename prescription"; exit 1; }
echo "  ok [#47 branch-grammar] — conforming accepted, non-conforming rejected, rename prescription emitted"

# [#47 coherence] the branch's leading NN must be a MEMBER of the PR's closing-issue set.
COH=.github/scripts/branch-coherence.sh
printf '47 49\n' | bash "$COH" 47-governance-pair >/dev/null 2>&1 \
  || { echo "BUG [#47 coherence]: NN present in the closing set was wrongly red"; exit 1; }
printf '47 49\n' | bash "$COH" 99-wrong-anchor >/dev/null 2>&1 \
  && { echo "BUG [#47 coherence]: NN absent from the closing set was wrongly accepted"; exit 1; }
COH_MISS=$(printf '47 49\n' | bash "$COH" 99-wrong-anchor 2>&1 || true)   # capture: exits non-zero by design
printf '%s\n' "$COH_MISS" | grep -q 'not among them' \
  || { echo "BUG [#47 coherence]: mismatch lacks the both-remedies coherence prescription"; exit 1; }
printf '' | bash "$COH" 47-governance-pair >/dev/null 2>&1 \
  || { echo "BUG [#47 coherence]: an empty closing set must pass here (it is #49's red), but went red"; exit 1; }
echo "  ok [#47 coherence] — NN in closing-set green, NN absent red (both remedies), empty set defers to #49"

# [#49 issue-ref] a CLOSING keyword is required, and the closing-set is parsed for coherence.
REF=.github/scripts/check-issue-ref.sh
REF_OUT=$(printf 'Title\nFixes #47 and Closes #49\n' | bash "$REF" 2>/dev/null) \
  || { echo "BUG [#49 issue-ref]: a valid Fixes/Closes body was rejected"; exit 1; }
[ "$REF_OUT" = "47 49" ] \
  || { echo "BUG [#49 issue-ref]: closing-set mis-parsed (got '$REF_OUT', want '47 49')"; exit 1; }
printf 'mentions #38 only\n' | bash "$REF" >/dev/null 2>&1 \
  && { echo "BUG [#49 issue-ref]: a bare '#38' with no closing keyword was accepted"; exit 1; }
REF_MISS=$(printf 'no anchor here\n' | bash "$REF" 2>&1 || true)   # capture: exits non-zero by design
printf '%s\n' "$REF_MISS" | grep -q 'no closing issue reference' \
  || { echo "BUG [#49 issue-ref]: the missing-anchor prescription is absent"; exit 1; }
echo "  ok [#49 issue-ref] — closing keyword required + set parsed; bare mention and no-ref both red"

# [#49 label-escape] the gate-waiver label greens the checks AND emits a loud, on-record line.
WAIV=.github/scripts/gate-waiver.sh
set +e; WOUT=$(printf 'enhancement\ngate-waiver\n' | bash "$WAIV" "PR #0" 2>&1); WRC=$?; set -e
[ "$WRC" -eq 0 ] \
  || { echo "BUG [#49 label-escape]: the gate-waiver label did not green the check (rc=$WRC)"; exit 1; }
printf '%s\n' "$WOUT" | grep -q 'GATE-WAIVER' \
  || { echo "BUG [#49 label-escape]: the waiver fired WITHOUT the mandatory loud log line"; exit 1; }
printf 'enhancement\n' | bash "$WAIV" "PR #0" >/dev/null 2>&1 \
  && { echo "BUG [#49 label-escape]: the waiver fired with NO gate-waiver label present"; exit 1; }
echo "  ok [#49 label-escape] — waiver label greens + emits the loud line; absent label does not waive"

# [#40 crlf-tripwire] No TRACKED shell/python script may carry a carriage return: a CRLF in a
# shebang or heredoc breaks execution, and .gitattributes only helps clones that HAVE it — this
# guard is the standing backstop that reads the working-tree bytes directly, so it catches a CR
# no matter how the clone was configured. Detection is `tr -dc '\r'` (POSIX, GNU/BSD-portable):
# strip everything but CR; non-empty output means the file carries one. Uses a while-read loop,
# not mapfile, so it runs on the macOS runner's bash 3.2.
CRLF_BAD=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  [ -n "$(tr -dc '\r' < "$f")" ] && CRLF_BAD="${CRLF_BAD}${f}"$'\n'
done < <(git ls-files '*.sh' '*.py')
if [ -n "$CRLF_BAD" ]; then
  echo "BUG [#40 crlf-tripwire]: tracked script(s) carry a carriage return (CRLF will break execution):"
  printf '%s' "$CRLF_BAD"
  exit 1
fi
# Self-test proves the detector is not vacuous (the guard-per-bug requirement): feed it a
# CR-injected throwaway fixture, which it MUST flag. If the detector ever stops catching this,
# the tripwire is silently dead — so this reds instead. (Reverting the detector reds HERE.)
CRLF_FIX=$(mktemp)
printf 'echo hi\r\n' > "$CRLF_FIX"
if [ -z "$(tr -dc '\r' < "$CRLF_FIX")" ]; then
  echo "BUG [#40 crlf-tripwire]: the CR detector failed to flag a CR-injected fixture — the tripwire is vacuous"
  rm -f "$CRLF_FIX"; exit 1
fi
rm -f "$CRLF_FIX"
echo "  ok [#40 crlf-tripwire] — no tracked *.sh/*.py carries a CR (detector proven on a CR fixture)"

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

# NOTE (#42 decoupling, cond 2): the documentation-completeness and branch-grammar doc checks that
# used to live here have MOVED to .github/scripts/docs-check.sh (run by .github/workflows/docs.yml).
# The demo now carries ZERO documentation knowledge — doc state can never again red the product
# demo. The demo gates the PRODUCT; docs.yml gates the docs. Two truths, two instruments.

# --- ship/dev classification guard (#43) ----------------------------------------------
# The ship-manifest is the ONE home for ship/dev classification. Assert every tracked file
# is classified EXACTLY once and every manifest entry names a real tracked file (both
# directions, #43 cond 6c) — so a new file can't be born unclassified and a manifest line
# can't outlive its file. This is a SELF-CONTAINED block: #42 absorbs this exact logic later
# (do not fork it into a second live copy). Manifest is TAB-delimited "CLASS<TAB>path"; the
# here-string matches (grep <<<) avoid the pipefail SIGPIPE trap the docs-inventory note explains.
echo "--- ship/dev classification: every tracked file is PRODUCT or DEV, exactly once ---"
CLASS_MANIFEST=.github/ship-manifest.txt
class_fail=0
# The classified paths (skip # comments and any line without a TAB-separated path).
class_paths=$(awk -F'\t' '/^#/ || NF < 2 { next } { print $2 }' "$CLASS_MANIFEST")
# (a) no path classified more than once.
class_dupe=$(printf '%s\n' "$class_paths" | LC_ALL=C sort | uniq -d)
[ -z "$class_dupe" ] || { echo "BUG [#43 classification]: path(s) classified more than once in $CLASS_MANIFEST:"; printf '  %s\n' "$class_dupe"; exit 1; }
# (b) every tracked file appears in the manifest — prescriptive on a miss (name the line to add).
while IFS= read -r f; do
  grep -Fqx -- "$f" <<<"$class_paths" \
    || { echo "BUG [#43 classification]: tracked file not classified — add 'PRODUCT<TAB>$f' or 'DEV<TAB>$f' to $CLASS_MANIFEST:"; echo "    $f"; class_fail=1; }
done < <(git ls-files)
# (c) every manifest entry is a real tracked file (no stale line for a deleted/renamed file).
while IFS= read -r m; do
  [ -z "$m" ] && continue
  git ls-files --error-unmatch -- "$m" >/dev/null 2>&1 \
    || { echo "BUG [#43 classification]: $CLASS_MANIFEST lists a path that is not a tracked file: $m"; class_fail=1; }
done <<<"$class_paths"
[ "$class_fail" -eq 0 ] || exit 1
class_total=$(printf '%s\n' "$class_paths" | grep -c .)
echo "  ok [#43 classification] — all $class_total tracked files classified exactly once (PRODUCT/DEV), both directions"
# --- end ship/dev classification guard ------------------------------------------------

# --- installer guards (#39): the non-destructive / dumb-creator claims are the richest revert ---
# surface, so every one gets a guard that reds if a run WOULD edit/clobber a pre-existing file or
# leak a DEV file. install.sh is exercised for real into a throwaway estate (agent deploy is sent
# to a throwaway dir so nothing touches $HOME). Plain-English asserts; guard-per-bug on each claim.
echo "--- #39 installer: non-destructive, PRODUCT-only, single-schema-home, idempotent ---"
I39_ROOT=$(mktemp -d); I39_EST="$I39_ROOT/estate"; I39_DEPLOY=$(mktemp -d)
# (a) single schema home: install.sh must carry NO hook-schema literal (it copies from the one
#     home, hooks.example.json, by path). A second literal here is the two-homes finding.
grep -qE '"(sessionStart|postToolUse|sessionEnd|timeoutSec)"' install.sh \
  && { echo "BUG [#39 schema-home]: install.sh carries a hook-schema literal — the schema must live only in _harness/hooks/hooks.example.json"; exit 1; }
echo "  ok [#39 schema-home] — install.sh carries no schema literal (single home: hooks.example.json)"
# (b) PRODUCT-only (#43 cond 2 / #39): a fresh --yes install lays down zero DEV files.
HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh --yes "$I39_EST" >/dev/null 2>&1 \
  || { echo "BUG [#39 install]: a clean --yes install failed"; exit 1; }
i39_leak=0
while IFS= read -r d; do [ -e "$I39_EST/$d" ] && { echo "  DEV leak: $d"; i39_leak=1; }; done < <(awk -F'\t' '$1=="DEV"{print $2}' .github/ship-manifest.txt)
[ "$i39_leak" -eq 0 ] || { echo "BUG [#39 product-only]: a DEV file reached the installed estate"; exit 1; }
echo "  ok [#39 product-only] — fresh estate contains zero DEV files"
# (c) dumb creator (cond 2, ABSOLUTE): a pre-existing (corrupted) file is byte-UNCHANGED by a re-run.
# Compare with cmp against a snapshot (portable — no sha256sum, which stock macOS lacks).
echo "GARBAGE" > "$I39_EST/AGENTS.md"; cp "$I39_EST/AGENTS.md" "$I39_ROOT/agents.snapshot"
HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh --yes "$I39_EST" >/dev/null 2>&1
cmp -s "$I39_ROOT/agents.snapshot" "$I39_EST/AGENTS.md" || { echo "BUG [#39 dumb-creator]: install EDITED a pre-existing file (AGENTS.md changed) — it must create only what is absent"; exit 1; }
echo "  ok [#39 dumb-creator] — pre-existing file left byte-unchanged (creates only what is absent)"
# (d) idempotency: a re-run finds nothing absent and creates zero.
i39_plan=$(HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh --yes "$I39_EST" 2>&1 | grep -oE 'PRODUCT files to create: [0-9]+' | head -1)
[ "$i39_plan" = "PRODUCT files to create: 0" ] || { echo "BUG [#39 idempotency]: a re-run wanted to create files ($i39_plan)"; exit 1; }
echo "  ok [#39 idempotency] — re-run creates nothing (nothing absent)"
# (e) --dry-run touches nothing: a dry-run against a fresh path must not create it.
i39_fresh="$I39_ROOT/dryrun-never"
HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh --dry-run --yes "$i39_fresh" >/dev/null 2>&1
[ ! -e "$i39_fresh" ] || { echo "BUG [#39 dry-run]: --dry-run created the target dir — it must touch nothing"; exit 1; }
echo "  ok [#39 dry-run] — --dry-run plans without touching the filesystem"
# (f) re-run-board (#39 v3, subsumes the v2 re-run-identity): on a re-run of an established estate
#     the board key is OFFERED as the default (review loop), and Enter-through reports it. Establish
#     a board via a real non-template ticket, re-run all-Enter, and assert BOTH the offered default
#     (the hint, on stderr) and the reported summary value are the established board.
i39_re="$I39_ROOT/reest"
HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh --yes "$i39_re" >/dev/null 2>&1
mkdir -p "$i39_re/Tickets/202607A-XRAY-1"; : > "$i39_re/Tickets/202607A-XRAY-1/202607A-XRAY-1.md"
printf '\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh "$i39_re" >"$I39_ROOT/re.out" 2>"$I39_ROOT/re.err" || true
i39_bhint=$(grep -oE 'ACCEPT DEFAULT: [A-Za-z0-9-]+' "$I39_ROOT/re.err" | head -1 | sed 's/.*: //')
[ "$i39_bhint" = "XRAY" ] \
  || { echo "BUG [#39 re-run-board]: re-run did NOT offer the established board as the default (got '$i39_bhint', want XRAY)"; exit 1; }
grep -qE 'board key += +XRAY' "$I39_ROOT/re.out" \
  || { echo "BUG [#39 re-run-board]: summary did not report the established board (XRAY):"; grep -i 'board key' "$I39_ROOT/re.out"; exit 1; }
echo "  ok [#39 re-run-board] — established board offered as the default and reported (XRAY)"
# (h) re-run-models: an established model pin is OFFERED as the default on a re-run. Set the cheap
#     tier's reference agent (doc-writer) to a marker, re-run, assert the cheap-model prompt (the
#     2nd ACCEPT DEFAULT) offers it. The awk-rewrite-to-tmp+mv is BSD-portable (no in-place edit).
i39_m="$I39_ROOT/mest"
HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh --yes "$i39_m" >/dev/null 2>&1
i39_dw="$i39_m/_agents/doc-writer.agent.md"
awk '/^model:/{print "model: MZAP"; next} {print}' "$i39_dw" > "$I39_ROOT/dw.tmp" && mv "$I39_ROOT/dw.tmp" "$i39_dw"
printf '\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh "$i39_m" 2>"$I39_ROOT/m.err" >/dev/null || true
i39_mhint=$(grep -oE 'ACCEPT DEFAULT: [A-Za-z0-9-]+' "$I39_ROOT/m.err" | sed -n '2p' | sed 's/.*: //')
[ "$i39_mhint" = "MZAP" ] \
  || { echo "BUG [#39 re-run-models]: re-run did NOT offer the established cheap model pin (got '$i39_mhint', want MZAP)"; exit 1; }
echo "  ok [#39 re-run-models] — established model pin offered as the default (MZAP)"
# (i) change-routing: a re-run answer that DIFFERS from established is ROUTED, never applied. Re-run
#     answering a different board; assert ticket-grammar.sh is BYTE-UNCHANGED and the warn names the
#     file to edit. Revert-provable: a version that edits the file (or omits the warn) reds.
i39_cr="$I39_ROOT/crest"
HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh --yes "$i39_cr" >/dev/null 2>&1
cp "$i39_cr/_harness/scripts/ticket-grammar.sh" "$I39_ROOT/tg.snap"
i39_crout=$(printf 'NEWB\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh "$i39_cr" 2>&1 || true)
cmp -s "$I39_ROOT/tg.snap" "$i39_cr/_harness/scripts/ticket-grammar.sh" \
  || { echo "BUG [#39 change-routing]: install EDITED ticket-grammar.sh on a re-run change — it must route, not apply"; exit 1; }
printf '%s\n' "$i39_crout" | grep -qE 'WARN.*board key' \
  || { echo "BUG [#39 change-routing]: a changed board key did not WARN + route"; exit 1; }
printf '%s\n' "$i39_crout" | grep -q 'ticket-grammar.sh' \
  || { echo "BUG [#39 change-routing]: the route did not name the file to edit (ticket-grammar.sh)"; exit 1; }
echo "  ok [#39 change-routing] — a changed answer WARNs + names the file, edits nothing"
# (j) workspace-derived: the workspace-root QUESTION is gone; the summary line is derived from the
#     real install target, always true by construction.
i39_ws="$I39_ROOT/wsest"
printf '\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh "$i39_ws" >"$I39_ROOT/ws.out" 2>"$I39_ROOT/ws.err" || true
grep -qi 'Workspace root' "$I39_ROOT/ws.err" \
  && { echo "BUG [#39 workspace-derived]: a 'Workspace root' question is still asked — it must be removed"; exit 1; }
i39_wsabs="$(cd "$i39_ws" && pwd)"
i39_wsline=$(grep -oE 'workspace root += +[^ ]+' "$I39_ROOT/ws.out" | head -1 | sed -E 's/.*= +//')
[ "$i39_wsline" = "$i39_wsabs" ] \
  || { echo "BUG [#39 workspace-derived]: summary workspace root ('$i39_wsline') != install target ('$i39_wsabs')"; exit 1; }
echo "  ok [#39 workspace-derived] — workspace root derived from the target, no question asked"
# (g) prompt-default truthfulness (#39 v2): the "[PRESS ENTER TO ACCEPT DEFAULT: <v>]" hint must
#     name the SAME value the script uses on empty input. Drive a fresh install with all-Enter
#     stdin, then assert the board prompt's advertised default equals the board the summary reports.
#     Single-sourced in ask(), so they must match; a hard-coded mismatched hint reds this.
i39_id="$I39_ROOT/idest"
printf '\n\n\n\n' | HARNESS_AGENT_DEPLOY_DIR="$I39_DEPLOY" bash install.sh "$i39_id" >"$I39_ROOT/id.out" 2>"$I39_ROOT/id.err" || true
i39_hint=$(grep -oE 'ACCEPT DEFAULT: [A-Za-z0-9._/-]+' "$I39_ROOT/id.err" | head -1 | sed 's/.*: //')
i39_used=$(grep -oE 'board key += +[A-Za-z0-9-]+' "$I39_ROOT/id.out" | head -1 | sed -E 's/.*= +//')
[ -n "$i39_hint" ] && [ "$i39_hint" = "$i39_used" ] \
  || { echo "BUG [#39 prompt-default]: the board prompt advertised default '$i39_hint' but Enter used '$i39_used' — the hint is a lie"; exit 1; }
echo "  ok [#39 prompt-default] — the Enter-to-accept hint names the value actually used ($i39_hint)"
rm -rf "$I39_ROOT" "$I39_DEPLOY"
# --- end installer guards -------------------------------------------------------------

# --- #60 auto-commit estate-key guard: commit-bearing hooks no-op outside a genuine estate ---
# The hook cwd is "." (the workspace root), so if a session's effective repo is a NESTED FOREIGN
# project (e.g. under Github/), a naive auto-commit would commit into THAT repo. The fix: both
# commit-bearing hooks refuse to commit unless .git/config holds harness.estate=true — a positive
# identity the worktree can neither reach nor forge (install.sh writes it). This block proves
# containment IN ISOLATION (it sets/unsets the key itself; no dependency on install.sh), across
# EVERY commit-bearing hook PARSED from the one schema home (a future third commit-hook inherits
# coverage), against DIRTY fixtures (a clean repo false-greens — nothing to commit either way),
# and the non-estate set INCLUDES a REMOTED repo (the remote-protection OUTCOME stays proven even
# though the mechanism is now the key, not remote-refusal). REVERT-PROOF: strip the guard prefix
# from hooks.example.json -> the remoted + local-only fixtures auto-commit -> this reds, for BOTH hooks.
echo "--- #60 estate-key guard: commit-bearing hooks commit ONLY in a genuine estate ---"
G60_TMP=$(mktemp -d)
# Parse the commit-bearing commands (bash contains 'git commit') from the SHIPPED schema — read the
# real strings, never re-type them. While-read (not mapfile) for the macOS runner's bash 3.2.
G60_CMDS=()
while IFS= read -r g60_line; do [ -n "$g60_line" ] && G60_CMDS+=("$g60_line"); done < <(python3 -c "
import json
d = json.load(open('_harness/hooks/hooks.example.json'))
for entries in d['hooks'].values():
    for e in entries:
        if 'git commit' in e.get('bash', ''):
            print(e['bash'])
")
[ "${#G60_CMDS[@]}" -ge 2 ] || { echo "BUG [#60]: expected >=2 commit-bearing hooks parsed from hooks.example.json, got ${#G60_CMDS[@]}"; exit 1; }

# One DIRTY fixture per class: a base commit, an identity so a commit CAN happen, then an
# uncommitted edit the hook could pick up.
g60_make_repo() {  # <dir> [remote-url] [set-estate-key]
  local d="$1"; mkdir -p "$d"; git -C "$d" init -q
  git -C "$d" config user.email t@t.local; git -C "$d" config user.name t
  [ -n "${2:-}" ] && git -C "$d" remote add origin "$2"
  [ -n "${3:-}" ] && git -C "$d" config harness.estate true
  echo seed > "$d/f"; git -C "$d" add -A; git -C "$d" commit -q -m seed
  echo dirty >> "$d/f"   # DIRTY: uncommitted change present
}
G60_REMOTED="$G60_TMP/remoted"; g60_make_repo "$G60_REMOTED" "https://example.invalid/x.git"
G60_LOCAL="$G60_TMP/local";     g60_make_repo "$G60_LOCAL"
G60_ESTATE="$G60_TMP/estate";   g60_make_repo "$G60_ESTATE" "" true
G60_NONREPO="$G60_TMP/nonrepo"; mkdir -p "$G60_NONREPO"; echo x > "$G60_NONREPO/f"   # not a repo at all
g60_commits() { git -C "$1" rev-list --count HEAD 2>/dev/null || echo 0; }
g60_fail=0
for g60_cmd in "${G60_CMDS[@]}"; do
  # DIRTY every repo fixture for THIS command. Re-dirtying per command matters twice over: a clean
  # fixture false-greens (nothing to commit either way), AND without it the first parsed hook consumes
  # the dirty state so a second hook's miss would hide in the revert-proof — it must RED for BOTH hooks.
  for g60_fx in "$G60_REMOTED" "$G60_LOCAL" "$G60_ESTATE"; do echo change >> "$g60_fx/f"; done
  # non-estate repos (remoted + local-only) must NOT gain a commit
  for g60_fx in "$G60_REMOTED" "$G60_LOCAL"; do
    g60_b=$(g60_commits "$g60_fx")
    ( cd "$g60_fx" && bash -c "$g60_cmd" ) >/dev/null 2>&1 || true
    g60_a=$(g60_commits "$g60_fx")
    [ "$g60_b" = "$g60_a" ] || { echo "BUG [#60 containment]: a commit-bearing hook committed in non-estate repo ($g60_fx: $g60_b->$g60_a)"; g60_fail=1; }
  done
  # non-repo dir: the guard's git config errors -> empty -> != true -> exit; no repo/commit created
  ( cd "$G60_NONREPO" && bash -c "$g60_cmd" ) >/dev/null 2>&1 || true
  [ ! -e "$G60_NONREPO/.git" ] || { echo "BUG [#60 containment]: a hook initialised a repo in a non-repo dir"; g60_fail=1; }
  # estate (key=true, dirty): the happy path is unchanged -> this one commit lands
  g60_b=$(g60_commits "$G60_ESTATE")
  ( cd "$G60_ESTATE" && bash -c "$g60_cmd" ) >/dev/null 2>&1 || true
  g60_a=$(g60_commits "$G60_ESTATE")
  [ "$g60_a" -gt "$g60_b" ] || { echo "BUG [#60 estate]: the guard blocked a commit in a genuine estate ($g60_b->$g60_a)"; g60_fail=1; }
done
[ "$g60_fail" -eq 0 ] || exit 1
echo "  ok [#60 estate-key guard] — ${#G60_CMDS[@]} commit-bearing hook(s): commit in estate, no-op in remoted/local-only/non-repo (dirty fixtures)"

# install.sh ARMS the key UNCONDITIONALLY — including an EXISTING repo (NEED_GIT=0), the migration
# path. REVERT-PROOF for the "unconditional, not init-nested" trap: nest the key-set inside the
# NEED_GIT init block and this existing-repo install leaves the key unset -> reds.
G60_EST="$G60_TMP/preexisting"; mkdir -p "$G60_EST"; git -C "$G60_EST" init -q   # a repo BEFORE install => NEED_GIT=0
G60_DEPLOY=$(mktemp -d)
set +e; HARNESS_AGENT_DEPLOY_DIR="$G60_DEPLOY" bash install.sh --yes "$G60_EST" >/dev/null 2>&1; set -e
g60_key=$(git -C "$G60_EST" config --local harness.estate 2>/dev/null || true)
[ "$g60_key" = "true" ] || { echo "BUG [#60 arming]: install.sh did not set harness.estate=true on a pre-existing (NEED_GIT=0) repo — the key-set must be UNCONDITIONAL, not nested in the git-init block (got '$g60_key')"; exit 1; }
echo "  ok [#60 arming] — install.sh sets harness.estate=true unconditionally, incl. an existing repo (migration path)"
rm -rf "$G60_TMP" "$G60_DEPLOY"
# --- end #60 estate-key guard ---------------------------------------------------------------

# --- #62 source-refusal prescribes: installing into the source aborts AND names a concrete fix ---
# install.sh must refuse TARGET==SOURCE (source/estate separation is fundamental) — but the refusal
# has to PRESCRIBE, not just name the wrong. Two assertions, both revert-provable:
#   (a) install-into-source EXITS NON-ZERO (guards the abort — break the condition and it reds);
#   (b) stderr offers a runnable `bash install.sh <separate-dir>/Work` fix (revert the message -> it reds).
# Fixture: a minimal SOURCE-like dir (install.sh + the manifest it reads) git-init'd with NO REMOTE.
# Isolation matters — a real checkout carries an origin remote, and install.sh's SEPARATE remote-refusal
# guard would MASK a broken source-guard (both abort), so (a) could never red. With no remote here, a
# broken source-guard falls through to the --yes --dry-run plan-and-exit-0 (touching no disk) and (a)
# reds cleanly; with the guard intact, TARGET==SOURCE aborts first.
echo "--- #62 source-refusal prescribes: install-into-source aborts with a concrete fix ---"
G62_SRC=$(mktemp -d)
cp install.sh "$G62_SRC/install.sh"
mkdir -p "$G62_SRC/.github"; cp .github/ship-manifest.txt "$G62_SRC/.github/ship-manifest.txt"
git -C "$G62_SRC" init -q   # a repo but with NO remote, so the remote-refusal guard can't mask (a)
set +e; G62_ERR=$(bash "$G62_SRC/install.sh" --yes --dry-run "$G62_SRC" 2>&1 >/dev/null); G62_RC=$?; set -e
[ "$G62_RC" -ne 0 ] || { echo "BUG [#62 abort]: install.sh with TARGET==SOURCE did not exit non-zero — the source/estate guard is broken"; exit 1; }
# (b) match the REAL stderr against the prescriptive shape (a runnable install.sh + a Work target), not
# a hardcoded verbatim string — the old non-prescriptive message carries no such command, so it reds.
echo "$G62_ERR" | grep -Eq 'bash install\.sh .+Work' || { echo "BUG [#62 message]: the source-refusal abort does not prescribe a concrete 'bash install.sh <separate-dir>/Work' fix; stderr was: $G62_ERR"; exit 1; }
rm -rf "$G62_SRC"
echo "  ok [#62 source-refusal prescribes] — install-into-source aborts (non-zero) and names a concrete separate-dir fix"
# --- end #62 source-refusal guard -----------------------------------------------------------

# --- #64 in-estate reconfigure: an estate re-running its OWN install.sh reaches guidance, not abort --
# install.sh ships PRODUCT into the estate and has a real reconfigure-on-re-run feature (established
# detection + route_change). But the natural in-estate gesture (cd ~/Work && ./install.sh) has
# TARGET==SOURCE (the estate's own copy), which used to abort at the source guard BEFORE that feature
# ran — and a naive relax dies at the manifest wall (the manifest is DEV, doesn't ship). The fix: a
# KEYED estate (harness.estate=true, #60) enters RECONFIGURE-ONLY mode — skip manifest/laydown/copy,
# run the interview + validator + status + summary. This proves it COMPLETES (reaches the audit, no
# manifest error, no abort) and stays a DUMB CREATOR (a pre-existing file byte-unchanged).
echo "--- #64 in-estate reconfigure: keyed estate re-running its own install.sh reaches the audit ---"
G64_ROOT=$(mktemp -d); G64_EST="$G64_ROOT/Work"; G64_DEPLOY=$(mktemp -d)
HARNESS_AGENT_DEPLOY_DIR="$G64_DEPLOY" bash install.sh --yes "$G64_EST" >/dev/null 2>&1 \
  || { echo "BUG [#64 setup]: could not build the estate fixture"; exit 1; }
G64_PROBE="$G64_EST/AGENTS.md"; G64_BEFORE=$(cksum "$G64_PROBE")   # dumb-creator witness (a pre-existing file)
# Run the ESTATE'S OWN install.sh in place: TARGET defaults to $PWD == the estate == that install.sh's
# SOURCE. Keyed -> reconfigure-only.
set +e; G64_OUT=$(cd "$G64_EST" && HARNESS_AGENT_DEPLOY_DIR="$G64_DEPLOY" bash install.sh --yes 2>&1); set -e
echo "$G64_OUT" | grep -q 'Reconfigure mode'     || { echo "BUG [#64 in-estate reconfigure]: no reconfigure banner"; exit 1; }
echo "$G64_OUT" | grep -q -- '--- validator ---' || { echo "BUG [#64 in-estate reconfigure]: did not reach the validator/status audit (reconfigure did not complete)"; exit 1; }
if echo "$G64_OUT" | grep -qi 'cannot find.*ship-manifest'; then echo "BUG [#64 in-estate reconfigure]: hit a manifest error — the create path was not skipped"; exit 1; fi
if echo "$G64_OUT" | grep -qi 'source distribution itself'; then echo "BUG [#64 in-estate reconfigure]: aborted at the source guard — the estate-key branch is missing"; exit 1; fi
G64_AFTER=$(cksum "$G64_PROBE")
[ "$G64_BEFORE" = "$G64_AFTER" ] || { echo "BUG [#64 dumb-creator]: the reconfigure re-run changed a pre-existing file ($G64_PROBE)"; exit 1; }
echo "  ok [#64 in-estate reconfigure] — banner + validator/status reached, no manifest error, no abort; pre-existing file byte-unchanged"

# --- #64 block preserved: keyless source-in-place and key-stripped copies STILL refuse (additive-only) --
# Only a KEYED estate gains passage; a genuine source checkout (no key) and a key-stripped copy must
# still block with #62's concrete-fix message — nothing previously blocked is now allowed.
echo "--- #64 block preserved: keyless source-in-place and key-stripped copies still refuse ---"
G64_KL=$(mktemp -d); cp install.sh "$G64_KL/install.sh"; git -C "$G64_KL" init -q   # NO key -> a source checkout
set +e; G64_KLOUT=$(cd "$G64_KL" && bash install.sh --dry-run 2>&1 >/dev/null); G64_KLRC=$?; set -e
[ "$G64_KLRC" -ne 0 ] || { echo "BUG [#64 block preserved]: a keyless source-in-place run did NOT abort — the key test is broken open"; exit 1; }
echo "$G64_KLOUT" | grep -qi 'source distribution itself' || { echo "BUG [#64 block preserved]: keyless run aborted but not with #62's concrete-fix message"; exit 1; }
git -C "$G64_EST" config --unset harness.estate 2>/dev/null || true   # strip the key from the real estate
set +e; G64_STOUT=$(cd "$G64_EST" && bash install.sh --dry-run 2>&1 >/dev/null); G64_STRC=$?; set -e
[ "$G64_STRC" -ne 0 ] || { echo "BUG [#64 block preserved]: a key-stripped estate copy did NOT abort"; exit 1; }
echo "$G64_STOUT" | grep -qi 'source distribution itself' || { echo "BUG [#64 block preserved]: key-stripped run aborted but not with #62's message"; exit 1; }
echo "  ok [#64 block preserved] — keyless source-in-place and key-stripped copies still refuse with #62's concrete-fix message"
rm -rf "$G64_ROOT" "$G64_KL" "$G64_DEPLOY"
# --- end #64 in-estate reconfigure guards ---------------------------------------------------

echo "=== 6/6 scrubbed context pack + self-audit ==="
bash _harness/scripts/make_context_pack.sh --ticket 999911Z-PROJ-99998
# The shared PACK_OUT_DIR must hold EXACTLY this one pack before we glob it — every other pack-building
# stage (R-09 D, the [#14 guard]) writes to its OWN throwaway dir. Assert it, so a regression that drops
# a second pack here fails LOUDLY right here instead of as a cryptic `unzip` exit 11 when the glob
# matches two archives (the flake CI caught on the slower macOS runner). find (no -printf) is portable.
n_packs=$(find "$PACK_OUT_DIR" -maxdepth 1 -name 'harness-pack-*.zip' 2>/dev/null | wc -l | tr -d ' ')
[ "$n_packs" = "1" ] || { echo "BUG [stage 6]: expected exactly 1 pack in PACK_OUT_DIR, found $n_packs — a second pack makes the unzip glob ambiguous:"; ls -1 "$PACK_OUT_DIR"; exit 1; }
unzip -p "$PACK_OUT_DIR"/harness-pack-*.zip MANIFEST.txt | tail -1

rm -rf "$S"
demo_close_commit "$DID_INIT" "."   # gated: commits only if the demo created this repo (issue #10)
echo; echo "ALL 6 DEMO STAGES PASSED — the machinery works. Next: README Setup to wire Copilot."
