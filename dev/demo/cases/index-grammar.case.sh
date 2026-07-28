#!/usr/bin/env bash
# index-grammar.case.sh — R-04 index-grammar regressions, the substance of tour stage 3. SOURCED
# by the runner; see dev/scripts/run_demo.sh for the contract.
#
# The validator names a file ONLY by an index line's first token after "- "; prose, '#' comments
# and '<...>' placeholders are inert (grammar pinned in CONSTITUTION.md). These cases prove
# that in BOTH directions: honest records must PASS (no false ghosts, no false orphans — the R-12
# point) and real breakage must FAIL. A parser that scans whole prose lines flips the PASS cases
# to false FAILs — see the R-04 revert-proof.

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
  printf '\n## %s - regression probe\n- exercising the index grammar\n' \
    "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
  set +e; REG_OUT=$(bash estate/_harness/scripts/check_ticket_log.sh 2>&1); REG_RC=$?; set -e
}

# reg_pass asserts an honest index was accepted ($1 = case label). A false FAIL here is the R-12
# defect — an honest record RED-blocked — so we abort the demo loudly with the validator output.
reg_pass() {
  if [ "$REG_RC" -ne 0 ]; then
    echo "BUG [$1]: honest index RED-blocked (validator failed, should pass):"
    printf '%s\n' "$REG_OUT"; exit 1
  fi
  echo "  ok [$1] — honest record accepted"
}

# reg_fail asserts real breakage was refused ($1 = label) AND that the printed reason matches $2,
# so we prove the RIGHT failure fired (e.g. the orphan we expected), not an unrelated one.
reg_fail() {
  if [ "$REG_RC" -eq 0 ] || ! printf '%s\n' "$REG_OUT" | grep -q "$2"; then
    echo "BUG [$1]: expected a FAIL matching '$2' (rc=$REG_RC):"
    printf '%s\n' "$REG_OUT"; exit 1
  fi
  echo "  ok [$1] — correctly refused: $2"
}

# 1. TRUTHFUL PROSE INERT: a filename in the DESCRIPTION is not an entry. A prose-scanning parser
#    raises old-plan.md as a false ghost and red-blocks this honest record — the core R-12 case.
ig_truthful_prose() {
  ak_reset "- notes.md — supersedes old-plan.md" notes.md
  reg_run; reg_pass "truthful-prose"
}

# 2. REAL ORPHAN CAUGHT: a real file with no entry line must FAIL. Then apply the printed fix
#    (repair is a human act; reg_run gives it its own log entry) and watch the ticket go green.
ig_real_orphan() {
  ak_reset "- covered.md — the only entry" covered.md orphan.md
  reg_run; reg_fail "real-orphan" "orphan file AI-Knowledge/orphan.md"
  echo "  --- applying the printed fix: add the missing index line, re-validate ---"
  echo "- orphan.md — now indexed" >> "$S/AI-Knowledge/_index.md"
  reg_run; reg_pass "orphan-repaired"
}

# 3. '#' COMMENT INERT: a .md name inside a comment line is not scanned. A prose-scanning parser
#    reads notes.md out of the comment and mints a false ghost.
ig_comment_inert() {
  ak_reset $'# see notes.md for the mapping\n- real.md — the real entry' real.md
  reg_run; reg_pass "comment-inert"
}

# 4. PLACEHOLDER INERT: a <...> first token is illustrative, never a real entry or ghost —
#    guaranteed by a deliberate angle-bracket check in the validator, not by char-class luck.
ig_placeholder_inert() {
  ak_reset $'- <file>.md — placeholder shown in the grammar\n- real.md — the real entry' real.md
  reg_run; reg_pass "placeholder-inert"
}

# 5. SUBSTRING DECOY: entry "- release-extra.md" must NOT cover the different real file extra.md.
#    First-token EQUALITY (not substring) leaves extra.md an orphan — now grammar-enforced.
#    BOTH decoys are REAL files, so release-extra.md is covered by its own entry and does not
#    ghost — the stage then fails for EXACTLY ONE reason (the extra.md orphan). That isolates the
#    orphan property specifically: a future orphan-check regression can't hide behind a ghost
#    failure here. (Cleanup: the next case's ak_reset rebuilds AI-Knowledge/, clearing both.)
ig_substring_decoy() {
  ak_reset "- release-extra.md — decoy" extra.md release-extra.md
  reg_run; reg_fail "substring-decoy" "orphan file AI-Knowledge/extra.md"
}

# 6. UNIFICATION: one validation, one rule, both directions — good.md is correctly covered by its
#    exact entry (orphan side) while missing.md is correctly flagged (ghost side).
ig_unification() {
  ak_reset $'- good.md — real and covered\n- missing.md — names no file' good.md
  reg_run; reg_fail "ghost-side" "ghost entry 'missing.md'"
  if printf '%s\n' "$REG_OUT" | grep -q "orphan file AI-Knowledge/good.md"; then
    echo "BUG [orphan-side]: good.md wrongly flagged orphan — the orphan side broke"; exit 1
  fi
  echo "  ok [orphan-side] — one token rule drove BOTH orphan-coverage (good.md) and" \
    "ghost-detection (missing.md)"
}

# 7. TOMBSTONE ACCEPTED: "- old.md (promoted -> ...)" names no file but is a tombstone, not a
#    ghost — the promotion record is legitimate and must PASS.
ig_tombstone() {
  ak_reset $'- old.md (promoted -> General AI-Knowledge/Foo)\n- real.md — kept' real.md
  reg_run; reg_pass "tombstone-accepted"
}

# 8. DASHLESS PRE-FIX ENTRY: a hand-written line predating the leading-dash rule, WITHOUT the
#    leading "- ", is not an entry under the grammar, so its file reads as an orphan and FAILs.
#    This is CORRECT — the leading dash is now enforced. MIGRATION: operators with old dashless
#    indexes must prepend "- " (the keeper agent now writes the dash, so only pre-existing
#    hand-written indexes hit this). Asserting FAIL here proves the dash is load-bearing.
ig_dashless() {
  ak_reset "notes.md — quirk" notes.md
  reg_run; reg_fail "dashless-pre-fix" "orphan file AI-Knowledge/notes.md"
}

# 9. UNICODE-ARROW TOMBSTONE ACCEPTED (E-2 dual-accept): a legacy tombstone written with the
#    unicode arrow must still be exempt from ghosting — else honest legacy records flip
#    valid->ghost and red-block (the R-04 failure). The matcher accepts both arrows; the
#    prescription (fix-line) teaches ASCII "->" only.
ig_unicode_tombstone() {
  ak_reset $'- old.md (promoted → General AI-Knowledge/Foo)\n- real.md — kept' real.md
  reg_run; reg_pass "unicode-tombstone"
}

# 10. E-1 PRESCRIPTION IS ASCII: the ghost fix-line must teach the canonical ASCII tombstone,
#     never the unicode arrow — else a user who follows the printed fix writes a tombstone the
#     gate (post-Flag-2) rejects. Trigger a ghost, then assert the printed fix-line contains
#     ASCII "promoted ->" and NOT the unicode arrow. (Assertion, not a pass/fail stage: the
#     ghost is expected to fire; we check the fix-line's bytes.)
ig_fixline_ascii() {
  ak_reset $'- ghosty.md — names no file\n- real.md — kept' real.md
  reg_run   # REG_OUT now holds the ghost FAIL and its fix-line
  if ! printf '%s\n' "$REG_OUT" | grep -q "promoted ->"; then
    echo "BUG [fixline-ascii]: ghost fix-line missing ASCII 'promoted ->':"
    printf '%s\n' "$REG_OUT"; exit 1
  fi
  if printf '%s\n' "$REG_OUT" | grep -q "promoted →"; then
    echo "BUG [fixline-ascii]: ghost fix-line emits the UNICODE arrow — E-1 regressed:"
    printf '%s\n' "$REG_OUT"; exit 1
  fi
  echo "  ok [fixline-ascii] — ghost fix-line prescribes ASCII '(promoted -> ...)', no" \
    "unicode arrow"
}

# Leave the scratch ticket green for the remaining stages — every later family runs against it.
ig_clean_exit() {
  ak_reset "- notes.md — platform quirk — read before editing" notes.md
  reg_run; reg_pass "clean-exit"
}

case_index_grammar() {
  ig_truthful_prose
  ig_real_orphan
  ig_comment_inert
  ig_placeholder_inert
  ig_substring_decoy
  ig_unification
  ig_tombstone
  ig_dashless
  ig_unicode_tombstone
  ig_fixline_ascii
  ig_clean_exit
}
