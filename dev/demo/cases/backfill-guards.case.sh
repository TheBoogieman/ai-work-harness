#!/usr/bin/env bash
# backfill-guards.case.sh — issue #18: retroactive guards for #1, #3 and #10, plus the #35
# here-string safety proof they depend on. SOURCED by the runner; see run-demo.sh.
#
# These three bugs were fixed and closed BEFORE the guard-per-bug law (#18) existed, so they
# shipped without guards. One guard each below, all witnessable on this host (no Mac needed), each
# provably red on the pre-fix behaviour.

# code_has / code_hasE — does the comment-stripped script text $code contain PATTERN?
# HERE-STRING, deliberately NOT `printf '%s' "$code" | grep -q`: under `set -o pipefail`
# grep -q's early exit on a match closes the pipe while printf is still writing, printf
# takes SIGPIPE, and pipefail turns that into a FALSE pipeline failure on a match (#35 —
# the exact class the #10 guard already avoids). A here-string has no pipe, so a match
# always reads as success. code_has = BRE (grep -q); code_hasE = ERE (grep -qE).
code_has()  { grep -q  "$1" <<< "$code"; }
code_hasE() { grep -qE "$1" <<< "$code"; }

# [bsd-fallback] — the macOS/BSD portability contract. Static lexical check: every GNU-only command
# in the shell machinery must sit behind a BSD fallback, so nothing bare-GNU can regress in. HONEST
# LIMITATION: this is a commit-time lexical check, NOT a BSD runtime test (that needs BSD hardware
# — a deferred evidence box); it catches the #1 regression CLASS (GNU-only commands with no
# fallback) without a Mac. Comments are stripped first so a construct merely NAMED in prose doesn't
# count. Paired forms (stat -c/-f, date -d/-j) must co-occur per file (a GNU call implies its BSD
# twin); unpaired GNU-only forms (GNU in-place sed, find -printf, readlink -f, grep -P) must be
# absent.
#
# SCOPE, STATED: the scan is `estate/_harness/scripts/*.sh`. The suite's OWN sources under dev/demo/
# are outside that glob, and deliberately so — this very file necessarily holds the six token
# patterns as SEARCH LITERALS (they would self-match), and its sibling cases hold GNU/BSD probe
# pairs written for a different purpose. That is the same carve-out the pre-split suite had, where
# the one file holding those literals was skipped by name; splitting moved the literals out of
# estate/_harness/scripts/ entirely, so the skip is gone rather than relocated and the runner
# itself is
# now scanned like every other script in that directory. The demo files are covered instead by
# being RUN end to end, on both CI lanes, by the demo you are reading.
bg_bsd_fallback() {
  local g1_bad=0 s code
  echo "--- #1/#3/#10: retroactive backfill guards (issue #18) ---"
  for s in estate/_harness/scripts/*.sh; do
    code=$(sed 's/#.*//' "$s")     # drop comments (full + inline); only executable text is scanned
    if code_has 'stat -c' && ! code_has 'stat -f'; then
      echo "FAIL [bsd-fallback]: $(basename "$s") uses GNU 'stat -c' with no BSD" \
        "'stat -f' fallback."
      g1_bad=1; fi
    if code_has 'date -d' && ! code_has 'date -j'; then
      echo "FAIL [bsd-fallback]: $(basename "$s") uses GNU 'date -d' with no BSD" \
        "'date -j' fallback."
      g1_bad=1; fi
    if code_hasE 'sed +(-[A-Za-z]+ +)*-i'; then
      echo "FAIL [bsd-fallback]: $(basename "$s") uses GNU in-place sed (not BSD-portable;" \
        "use tmp+mv)."
      g1_bad=1; fi
    if code_hasE 'find .*-printf'; then
      echo "FAIL [bsd-fallback]: $(basename "$s") uses GNU 'find -printf' — not in BSD."
      g1_bad=1; fi
    if code_has 'readlink -f'; then
      echo "FAIL [bsd-fallback]: $(basename "$s") uses GNU 'readlink -f' (absent in BSD readlink)."
      g1_bad=1; fi
    if code_hasE 'grep -[a-zA-Z]*P'; then
      echo "FAIL [bsd-fallback]: $(basename "$s") uses GNU 'grep -P' PCRE — not in BSD."
      g1_bad=1; fi
  done
  [ "$g1_bad" -eq 0 ] \
    || { echo "BUG [bsd-fallback]: an unguarded GNU-only construct is present (see FAILs above)"; \
         exit 1; }
  echo "  ok [bsd-fallback] — every GNU call has a BSD fallback"
}

# [sigpipe-safety guard (#35)] — proves the #1 match helpers are here-string-safe: a match under
# pipefail reads as SUCCESS, never a SIGPIPE-false-fail. DETERMINISTIC: with a LARGE $code whose
# match token is at the very top, the old `printf | grep -q` form would reliably SIGPIPE (printf
# can't drain ~500 KiB into a 64 KiB pipe buffer before grep exits), so this goes RED the instant
# code_has/code_hasE are reverted to the piped form; the here-string form passes. Subshell so the
# large $code never leaks to later stages.
bg_sigpipe_safety() {
  if ( code=$(printf 'SIGPIPE_PROBE_TOKEN\n'; head -c 500000 /dev/zero | tr '\000' 'x')
       code_has 'SIGPIPE_PROBE_TOKEN' && code_hasE 'SIGPIPE_PROBE_TOKEN' ); then
    echo "  ok [sigpipe-safety] — code_has/code_hasE return success on a large-input match under" \
      "pipefail (no SIGPIPE)"
  else
    echo "FAIL [sigpipe-safety]: a large-input match did not read as success — helpers are not" \
      "here-string-safe (#35)."
    exit 1
  fi
}

# [independent-clocks] — the dual-clock watermark. The stamp is two lines: line 1 = wall-clock
# (date +%s; recency = newest header >= last validation), line 2 = md mtime (freshness = did the
# file change since last validation). Different clocks, kept separate. This pins that freshness
# reads line 2 (mtime), independent of line 1 (wall): a change whose new mtime lands BETWEEN the
# stored mtime and the stored wall time is noticed only by a line-2 read. A single-line stamp (one
# value for both) would use the wall clock for freshness and MISS such a change — the exact #3 bug.
# (Distinct from the session-clock family, about the header's TIMEZONE; this is about the two stamp
# lines being separate values.) touch -t is POSIX (GNU+BSD).
#
# Mnemonics: mt1 = the anchored mtime (Jan 1), mt2 = the advanced mtime (Feb 1), wall1 = the
# wall-clock at validation ('now'). Ordering that matters: mt1 < mt2 < wall1.
#
# Case A — advance mtime to Feb 1 (mt1 < mt2 < wall1) with NO new header. The change is above the
# stored mtime but below the wall clock, so only a line-2 (mtime) freshness read notices it.
# Two-clock → re-checks and FAILs "no new Session Log entry". Single-clock (line2=line1=wall1) →
# mt2 < wall1 → "unchanged" → silently skips (the bug).
# Case B — complement: a genuine new header at/after the watermark AND mtime advances → both axes
# satisfied → validates OK.
bg_independent_clocks() {
  local G3T g3md G3A G3B
  G3T="estate/Tickets/202607S-PROJ-33"; g3md="$G3T/202607S-PROJ-33.md"
  r09_make "$G3T"
  sleep 1   # make the validation wall-clock strictly after the header time
  touch -t "$(date +%Y)01010000" "$g3md"      # anchor mtime to Jan 1 this year (mt1)
  # the stamp is written here: line 1 = wall1 (now), line 2 = mt1 (Jan 1)
  bash estate/_harness/scripts/check-ticket-log.sh >/dev/null 2>&1 || true
  touch -t "$(date +%Y)02010000" "$g3md"
  set +e; G3A=$(bash estate/_harness/scripts/check-ticket-log.sh 2>&1); set -e
  printf '%s\n' "$G3A" | grep -q "202607S-PROJ-33 changed but no new Session Log entry" \
    || { echo "BUG [independent-clocks]: an mtime change below the wall clock was NOT noticed —" \
           "freshness isn't reading the stamp's mtime line:"; printf '%s\n' "$G3A"; exit 1; }
  printf '\n## %s - real new session\n- work recorded\n' "$(date +%Y%m%d%H%M%S)" >> "$g3md"
  set +e; G3B=$(bash estate/_harness/scripts/check-ticket-log.sh 2>&1); set -e
  printf '%s\n' "$G3B" | grep -q "OK: 202607S-PROJ-33 validated" \
    || { echo "BUG [independent-clocks]: a real new session header was not accepted:"; \
         printf '%s\n' "$G3B"; exit 1; }
  rm -rf "$G3T"
  echo "  ok [independent-clocks] — mtime change noticed, new header accepted"
}

# [wip-not-absorbed] — the suite's closing commit is gated behind DID_INIT so it fires ONLY when
# the demo created the repo. In a real clone (DID_INIT=0) it must do nothing, never sweeping a
# user's uncommitted work into a "demo: pass" commit. Exercises the ACTUAL gate (demo_close_commit
# — the same function demo_finish calls) against a throwaway repo that already has .git and a dirty
# tracked file. This is the reviewer's WIP-absorption probe made a standing guard.
#
# The load-bearing #10/P-i check: the dirty WIP must NOT be absorbed into any commit. Grep the
# WHOLE history for the WIP marker — a broken gate that commits the working tree leaves the marker
# in a commit, and this finds it. (The old guard only checked "no demo: pass commit", which ANY
# unconditional commit trips even with zero WIP present — that tautology was R-20; this asserts the
# WIP-specific property, and the revert-proof now flips because the WIP is ABSORBED, not merely
# because a commit exists.) Buffer the full history first, THEN grep it via a here-string — not
# `git log -p | grep -q`, whose early exit SIGPIPEs git and, under the demo's pipefail, fails the
# pipeline even ON a match, so the named WIP-absorption assertion silently never fires and the
# corroborating check fires instead.
bg_wip_not_absorbed() {
  local G10 G10_HEAD g10_hist
  G10=$(mktemp -d)
  git -C "$G10" init -q
  printf 'committed line\n' > "$G10/tracked.txt"
  git -C "$G10" add -A
  git -C "$G10" -c user.email=demo@local -c user.name=demo commit -qm "seed" >/dev/null
  G10_HEAD=$(git -C "$G10" rev-parse HEAD)
  printf 'UNCOMMITTED-WIP-MARKER\n' >> "$G10/tracked.txt"   # dirty the TRACKED file
  demo_close_commit 0 "$G10"                                # DID_INIT=0 → the gate must do NOTHING
  g10_hist=$(git -C "$G10" log -p 2>/dev/null || true)
  if grep -q "UNCOMMITTED-WIP-MARKER" <<<"$g10_hist"; then
    echo "BUG [wip-not-absorbed]: the dirty tracked WIP was ABSORBED into a commit (a real" \
      "clone's work must never be committed under DID_INIT=0):"
    git -C "$G10" log --oneline; exit 1
  fi
  # Corroborate: HEAD never moved (no new commit at all) and the working tree still reads as dirty.
  [ "$(git -C "$G10" rev-parse HEAD)" = "$G10_HEAD" ] \
    || { echo "BUG [wip-not-absorbed]: HEAD advanced — the gate committed under DID_INIT=0"; \
         git -C "$G10" log --oneline; exit 1; }
  [ -n "$(git -C "$G10" status --porcelain)" ] \
    || { echo "BUG [wip-not-absorbed]: the working tree is clean — the dirty WIP was swept into a" \
           "commit"; exit 1; }
  rm -rf "$G10"
  echo "  ok [wip-not-absorbed] — dirty tracked WIP stays uncommitted under DID_INIT=0"
}

# [epoch-one-home] — epoch_from_ts14 must live ONCE (portability.sh), sourced by both the validator
# and status so they can't drift (they were duplicated once). Assert: neither script defines its
# own copy; both source portability.sh; and the one shared function converts a known header
# correctly. Re-introducing a local copy in either script reddens this.
bg_epoch_one_home() {
  grep -qE '^[[:space:]]*epoch_from_ts14\(\)' estate/_harness/scripts/check-ticket-log.sh \
    && { echo "BUG [epoch-one-home]: check-ticket-log.sh defines its own epoch_from_ts14 (drift" \
           "risk — source portability.sh)"; exit 1; }
  grep -qE '^[[:space:]]*epoch_from_ts14\(\)' estate/_harness/scripts/harness-status.sh \
    && { echo "BUG [epoch-one-home]: harness-status.sh defines its own epoch_from_ts14 (drift" \
           "risk — source portability.sh)"; exit 1; }
  { grep -q 'source .*portability\.sh' estate/_harness/scripts/check-ticket-log.sh \
    && grep -q 'source .*portability\.sh' estate/_harness/scripts/harness-status.sh; } \
    || { echo "BUG [epoch-one-home]: validator and status must source portability.sh"; exit 1; }
  ( source estate/_harness/scripts/portability.sh
    r21_got=$(epoch_from_ts14 "20260101120000")
    r21_want=$(date -d "2026-01-01 12:00:00" +%s 2>/dev/null \
      || date -j -f "%Y-%m-%d %H:%M:%S" "2026-01-01 12:00:00" +%s 2>/dev/null || echo x)
    [ -n "$r21_got" ] && [ "$r21_got" = "$r21_want" ] \
      || { echo "BUG [epoch-one-home]: shared epoch_from_ts14 gave '$r21_got', expected" \
             "'$r21_want'"; exit 1; } )
  echo "  ok [epoch-one-home] — single shared function, both tools source it, converts correctly"
}

case_backfill_guards() {
  bg_bsd_fallback
  bg_sigpipe_safety
  bg_independent_clocks
  bg_wip_not_absorbed
  bg_epoch_one_home
}
