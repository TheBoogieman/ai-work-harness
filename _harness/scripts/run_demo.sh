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

# 8. DASHLESS PRE-FIX ENTRY: a pre-004a hand-written line WITHOUT the leading "- " is not an entry
#    under the grammar, so its file reads as an orphan and FAILs. This is CORRECT — the leading
#    dash is now enforced. MIGRATION: operators with old dashless indexes must prepend "- " (the
#    keeper agent already writes the dash post-004a, so only pre-existing hand-written indexes hit
#    this). Asserting FAIL here proves the dash is load-bearing.
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
bash _harness/scripts/harness-status.sh
mv "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md" /tmp/dw.bak
bash _harness/scripts/harness-status.sh || echo "--- correctly failed with a fix line ---"
mv /tmp/dw.bak "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md"
bash _harness/scripts/harness-status.sh >/dev/null && echo "healthy after fix"

echo "=== 6/6 scrubbed context pack + self-audit ==="
bash _harness/scripts/make_context_pack.sh --ticket 999911Z-PROJ-99998
unzip -p "$PACK_OUT_DIR"/harness-pack-*.zip MANIFEST.txt | tail -1

rm -rf "$S"
if [ "$DID_INIT" -eq 1 ]; then
  git add -A >/dev/null; git -c user.email=demo@local -c user.name=demo commit -qm "demo: pass" >/dev/null 2>&1 || true
fi
echo; echo "ALL 6 DEMO STAGES PASSED — the machinery works. Next: INSTALL.md to wire Copilot."
