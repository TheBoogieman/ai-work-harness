#!/usr/bin/env bash
# warn-aging.case.sh — #71 WARN aging + #72 knowledge staleness. SOURCED by the runner; see
# dev/scripts/run_demo.sh for the contract.
#
# Every string below is anchored with one of the warn-aging-* labels or [knowledge-staleness], and
# every assertion is revert-provable RED against pre-fix code.

# [warn-aging-render] — a WARN whose first-seen is OLD renders with escalating threshold styling; a
# FRESH one (first-seen = today) renders PLAIN; and the gate is unchanged (a yellow WARN keeps exit
# 0 with aging on). Deterministic via a case-LOCAL state file (A2 layer 2) that we SEED with an old
# first-seen for the fixture's exact key, so the age is fixed regardless of wall-clock. The fixture
# is an unrecognised ticket folder (a guaranteed WARN); its key is "unrecognised:<name>". BUG on
# miss: aging did not fire / a fresh WARN was decorated / aging flipped a yellow to red.
wa_render() {
  local AG71T AG71_STATE ag71_old AG71_OUT AG71_RC AG71_FRESH AG71_OUT2
  echo "--- #71 WARN aging + #72 knowledge staleness ---"
  AG71T="$DEMO_ROOT/estate/Tickets/aging fixture 71"; mkdir -p "$AG71T"
  printf '# rec\n## Current State\nwip\n' > "$AG71T/rec.md"
  AG71_STATE=$(mktemp)
  ag71_old=$(( $(date +%s) - 200*86400 ))          # 200 days back → past the alarm tier
  printf '%s\tunrecognised:aging fixture 71\n' "$ag71_old" > "$AG71_STATE"
  set +e; AG71_OUT=$(HARNESS_WARN_STATE_FILE="$AG71_STATE" \
    bash estate/_harness/scripts/harness-status.sh 2>&1); AG71_RC=$?; set -e
  # 1. old-dated WARN → age rendered with the escalating (alarm-tier) styling on its own line
  printf '%s\n' "$AG71_OUT" | grep -F "aging fixture 71" | grep -q "parked 200d" \
    || { echo "BUG [warn-aging-render]: an aged WARN (first-seen 200d ago) rendered NO parked age" \
           "— aging did not fire:"; printf '%s\n' "$AG71_OUT" | grep -iF "aging fixture 71"; \
         exit 1; }
  printf '%s\n' "$AG71_OUT" | grep -F "aging fixture 71" | grep -q '!!!' \
    || { echo "BUG [warn-aging-render]: a WARN past the alarm tier (200d) did not escalate to the" \
           "loud marker:"; printf '%s\n' "$AG71_OUT" | grep -iF "aging fixture 71"; exit 1; }
  # 3. gate behaviour unchanged: an unrecognised-ticket WARN is YELLOW — rc stays 0 with aging on
  [ "$AG71_RC" -eq 0 ] \
    || { echo "BUG [warn-aging-render]: aging changed the gate — a yellow WARN must keep exit 0," \
           "got rc=$AG71_RC"; exit 1; }
  # 2. FRESH WARN (empty state → first-seen = now) → PLAIN, no age decoration on the same line
  AG71_FRESH=$(mktemp); : > "$AG71_FRESH"
  set +e; AG71_OUT2=$(HARNESS_WARN_STATE_FILE="$AG71_FRESH" \
    bash estate/_harness/scripts/harness-status.sh 2>&1); set -e
  printf '%s\n' "$AG71_OUT2" | grep -F "aging fixture 71" | grep -qE 'parked|\[!' \
    && { echo "BUG [warn-aging-render]: a FRESH WARN rendered age decoration — a just-seen WARN" \
           "must be plain:"; printf '%s\n' "$AG71_OUT2" | grep -iF "aging fixture 71"; exit 1; }
  rm -rf "$AG71T" "$AG71_STATE" "$AG71_FRESH"
  echo "  ok [warn-aging-render] — aged WARN shows escalating styled age, fresh WARN is plain," \
    "gate stays yellow (rc 0)"
}

# [knowledge-staleness] a note past the threshold is LISTED and NAMES the knowledge-curator; a
# fresh note is not; an UNDATED note draws its OWN WARN. Pure date arithmetic against controlled
# dates so it's deterministic on any CI clock. Fixtures live under a scratch AI-Knowledge subfolder
# we create and remove. BUG on miss: old note not listed w/ curator / fresh flagged / undated
# silent / not yellow.
wa_knowledge_staleness() {
  local KS72_DIR ks72_old ks72_fresh KS72_OUT KS72_RC
  KS72_DIR="$DEMO_ROOT/estate/General AI-Knowledge/staleness fixture 72"; mkdir -p "$KS72_DIR"
  ks72_old=$(date -d "200 days ago" +%Y-%m-%d 2>/dev/null || date -v-200d +%Y-%m-%d)   # GNU || BSD
  ks72_fresh=$(date -d "3 days ago" +%Y-%m-%d 2>/dev/null || date -v-3d +%Y-%m-%d)
  printf '# old note\nLast reviewed: %s\n'   "$ks72_old"   > "$KS72_DIR/old.md"
  printf '# fresh note\nLast reviewed: %s\n' "$ks72_fresh" > "$KS72_DIR/fresh.md"
  printf '# undated note\n(no review stamp at all)\n'      > "$KS72_DIR/undated.md"
  set +e; KS72_OUT=$(bash estate/_harness/scripts/harness-status.sh 2>&1); KS72_RC=$?; set -e
  printf '%s\n' "$KS72_OUT" | grep -F "staleness fixture 72/old.md" | grep -q "knowledge-curator" \
    || { echo "BUG [knowledge-staleness]: the old note was not listed with the knowledge-curator" \
           "named as the next act:"; \
         printf '%s\n' "$KS72_OUT" | grep -iF "staleness fixture 72"; exit 1; }
  printf '%s\n' "$KS72_OUT" | grep -qF "staleness fixture 72/fresh.md" \
    && { echo "BUG [knowledge-staleness]: a fresh note (3 days) was wrongly flagged stale:"; \
         printf '%s\n' "$KS72_OUT" | grep -iF "staleness fixture 72"; exit 1; }
  printf '%s\n' "$KS72_OUT" | grep -F "staleness fixture 72/undated.md" | grep -q "undated" \
    || { echo "BUG [knowledge-staleness]: an undated note did not draw its own undated WARN:"; \
         printf '%s\n' "$KS72_OUT" | grep -iF "staleness fixture 72"; exit 1; }
  [ "$KS72_RC" -eq 0 ] \
    || { echo "BUG [knowledge-staleness]: the staleness sweep must be yellow (exit 0), got" \
           "rc=$KS72_RC"; exit 1; }
  rm -rf "$KS72_DIR"
  echo "  ok [knowledge-staleness] — old note listed w/ curator named, fresh silent, undated" \
    "draws its own WARN, exit 0"
}

# [warn-aging-porcelain] — a full status run must NOT dirty the estate (A2). The global
# HARNESS_WARN_STATE_FILE export (in the runner) sends status's one write to a throwaway path.
# TWO PROBES, covering the wall from different sides, because one of them used to cover neither.
# PROBE 1 (primary, fixture): a FRESH estate, committed so its baseline is EMPTY BY CONSTRUCTION.
#   The earlier version compared a baseline of the REAL tree snapshotted at this case's own start,
#   and self-masked: with the global export dropped, earlier stages had ALREADY written
#   _harness/state/ into the real tree, so the pollution sat in the baseline and BASE==NOW compared
#   equal while the tree was dirty (#71 reopen). Nothing upstream can pollute a fixture.
# PROBE 2 (secondary, real tree, BASELINE-RELATIVE): catches a mis-pointed call in THIS region that
#   newly dirties the real tree. It is deliberately baseline-relative, NOT absolute: a developer's
#   own uncommitted edits are always present here and an absolute check would false-red every local
#   run. That is why the original was written this way; the mistake was making it the ONLY probe.
#   Its cover is CONDITIONAL — if the tree already carries _harness/state/ from an earlier run,
#   this probe swallows it too. Probe 1 is the one that always holds.
# status derives its root from its own location, so the scripts must live inside the fixture. A
# scratch unrecognised ticket guarantees an active WARN: with no WARN there is no write at all, and
# either probe would pass for the wrong reason.
wa_porcelain_fixture() {
  local P71F P71_FBASE P71_FNOW
  P71F=$(mktemp -d)
  mkdir -p "$P71F/Tickets/porcelain check 71"
  cp -R estate/_harness "$P71F/_harness"
  printf '# rec\n## Current State\nx\n' > "$P71F/Tickets/porcelain check 71/rec.md"
  git -C "$P71F" init -q
  git -C "$P71F" -c user.email=demo@local -c user.name=demo add -A
  git -C "$P71F" -c user.email=demo@local -c user.name=demo commit -q -m "fixture"
  P71_FBASE=$(git -C "$P71F" status --porcelain)
  bash "$P71F/_harness/scripts/harness-status.sh" >/dev/null 2>&1 || true
  P71_FNOW=$(git -C "$P71F" status --porcelain)
  [ "$P71_FBASE" = "$P71_FNOW" ] \
    || { echo "BUG [warn-aging-porcelain]: a status run dirtied a CLEAN FIXTURE estate — the" \
           "global HARNESS_WARN_STATE_FILE export is not covering every write (status must be" \
           "side-effect-free on the estate). New/changed:"; \
         diff <(printf '%s\n' "$P71_FBASE") <(printf '%s\n' "$P71_FNOW") || true; \
         rm -rf "$P71F"; exit 1; }
  rm -rf "$P71F"
}

wa_porcelain_real_tree() {
  local P71_BASE P71T P71_NOW
  P71_BASE=$(git -C "$DEMO_ROOT" status --porcelain)
  P71T="$DEMO_ROOT/estate/Tickets/porcelain check 71"; mkdir -p "$P71T"
  printf '# rec\n## Current State\nx\n' > "$P71T/rec.md"
  bash estate/_harness/scripts/harness-status.sh >/dev/null 2>&1 || true
  rm -rf "$P71T"
  P71_NOW=$(git -C "$DEMO_ROOT" status --porcelain)
  [ "$P71_BASE" = "$P71_NOW" ] \
    || { echo "BUG [warn-aging-porcelain]: a status run in this region newly changed the real" \
           "tree — a call here is mis-pointed at the default in-repo state path. New/changed:"; \
         diff <(printf '%s\n' "$P71_BASE") <(printf '%s\n' "$P71_NOW") || true; exit 1; }
  echo "  ok [warn-aging-porcelain] — a status run leaves a clean fixture estate untouched, and" \
    "adds nothing to the real tree"
}

# [warn-aging-fails-open] — a bookkeeping write to an unwritable state path must NOT change the
# tool's answer (A3, the same law #79 shipped for its recorder). We point the state file under a
# regular FILE (so the mkdir -p can't succeed on any OS: ENOTDIR) with an active WARN present, and
# assert the rc is IDENTICAL to a control run on a writable path, the full report still prints, and
# the one 'aging unavailable' note appears. Revert-proof: drop the fails-open wrapper in
# warn_state_sync and set -euo pipefail aborts status mid-write — the rc flips and the verdict line
# vanishes; this reds.
#
# Only the control run's exit CODE is compared below (against FO71_RC), never its text, so the
# output is discarded rather than captured into a variable nothing reads. The run itself stays.
wa_fails_open() {
  local FO71T FO71_OK FO71_CTRL_RC FO71_BADPARENT FO71_OUT FO71_RC
  FO71T="$DEMO_ROOT/estate/Tickets/failsopen check 71"; mkdir -p "$FO71T"
  printf '# rec\n## Current State\nx\n' > "$FO71T/rec.md"
  FO71_OK=$(mktemp)                        # control: a writable case-local state path
  set +e; HARNESS_WARN_STATE_FILE="$FO71_OK" bash estate/_harness/scripts/harness-status.sh >/dev/null 2>&1
  FO71_CTRL_RC=$?; set -e
  # a regular FILE — using it as a directory parent forces ENOTDIR on any OS
  FO71_BADPARENT=$(mktemp)
  set +e; FO71_OUT=$(HARNESS_WARN_STATE_FILE="$FO71_BADPARENT/sub/warn-aging.tsv" \
    bash estate/_harness/scripts/harness-status.sh 2>&1); FO71_RC=$?; set -e
  rm -rf "$FO71T"; rm -f "$FO71_OK" "$FO71_BADPARENT"
  [ "$FO71_RC" -eq "$FO71_CTRL_RC" ] \
    || { echo "BUG [warn-aging-fails-open]: an unwritable state path changed status's exit code" \
           "(got rc=$FO71_RC, writable control rc=$FO71_CTRL_RC) — the write must fail open:"; \
         printf '%s\n' "$FO71_OUT"; exit 1; }
  printf '%s\n' "$FO71_OUT" | grep -q "aging unavailable" \
    || { echo "BUG [warn-aging-fails-open]: an unwritable state path did not emit the 'aging" \
           "unavailable' fails-open note:"; printf '%s\n' "$FO71_OUT"; exit 1; }
  printf '%s\n' "$FO71_OUT" | grep -qE "estate healthy|issue\(s\) above" \
    || { echo "BUG [warn-aging-fails-open]: the full status report did not print under an" \
           "unwritable state path (verdict line missing):"; printf '%s\n' "$FO71_OUT"; exit 1; }
  echo "  ok [warn-aging-fails-open] — unwritable state path: full report prints, one note, exit" \
    "code unchanged vs control"
}

case_warn_aging() {
  wa_render
  wa_knowledge_staleness
  wa_porcelain_fixture
  wa_porcelain_real_tree
  wa_fails_open
}
