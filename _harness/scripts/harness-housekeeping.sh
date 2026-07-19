#!/usr/bin/env bash
# harness-housekeeping.sh — HUMAN-RUN maintenance. Repacks the Work repo and reports
# growth; it NEVER runs itself. No hook invokes this — it is a deliberate human act,
# consistent with the harness doctrine "status observes, failures prescribe, nothing heals
# itself." It is SAFE: it compacts git storage and reports sizes; it deletes no ticket, no
# log, no record, and rewrites no history. `git gc` only repacks and drops already-unreachable
# objects — every commit and every tracked file survives untouched.
#
# Usage: harness-housekeeping.sh [--aggressive] [repo-root]
#   --aggressive  run `git gc --aggressive` (recompresses every object from scratch — much
#                 slower, occasionally a little smaller). Plain gc already collapses the
#                 per-write auto-commit loose objects into packs, which is the whole point;
#                 reach for --aggressive rarely, if ever.
#   repo-root     operate on this repo instead of the Work repo this script lives in (used by
#                 the demo to run against a throwaway repo; humans normally omit it).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

AGGRESSIVE=0
TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --aggressive) AGGRESSIVE=1 ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "FAIL: unknown flag '$1'. Fix: see --help."; exit 2 ;;
    *)  TARGET="$1" ;;
  esac
  shift
done
REPO="${TARGET:-$WORK_ROOT}"

# Must be a git repo, or there is nothing to compact.
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "FAIL: no git repo at $REPO. Fix: run this against the Work repo (or 'git -C \"$REPO\" init')."; exit 1; }

# du -sk (kibibytes) is portable across GNU/BSD; --exclude is NOT, so we derive the
# working-tree size by subtracting .git from the total rather than excluding it.
dir_kb() { du -sk "$1" 2>/dev/null | awk '{print $1}'; }

# ---- 1) REPORT THE "BEFORE" so the human sees the starting point --------------------
git_kb_before=$(dir_kb "$REPO/.git")
total_kb=$(dir_kb "$REPO")
work_kb=$(( total_kb - git_kb_before ))               # working tree minus history
commits=$(git -C "$REPO" rev-list --count HEAD 2>/dev/null || echo 0)
# Ratio of history to live tree — the number that climbs as per-write commits pile up.
# Only meaningful when the working tree has measurable size; print "n/a" otherwise.
ratio_before=$(awk -v g="$git_kb_before" -v w="$work_kb" 'BEGIN{ if (w>0) printf "%.1fx", g/w; else printf "n/a" }')
echo "harness-housekeeping — repo: $REPO"
echo "BEFORE: .git ${git_kb_before} KiB | working tree ${work_kb} KiB | ratio ${ratio_before} | commits ${commits}"

# ---- 2) REPACK — the core reclaim ---------------------------------------------------
# The postToolUse safety net commits on every file mutation, leaving thousands of tiny
# loose objects over months of use. `git gc` collapses them into packfiles and expires
# already-unreachable objects; nothing reachable is ever removed, so no record or history
# is lost. This is the one action that actually shrinks .git.
if (( AGGRESSIVE )); then
  echo "REPACK: git gc --aggressive (full recompress — slower) ..."
  git -C "$REPO" gc --aggressive --quiet
else
  echo "REPACK: git gc ..."
  git -C "$REPO" gc --quiet
fi
git_kb_after=$(dir_kb "$REPO/.git")
reclaimed_kb=$(( git_kb_before - git_kb_after ))       # negative on a tiny/tidy repo (pack overhead)
# Phrase the outcome honestly: real reclaim on a bloated repo, "already compact" when there was
# nothing loose to collapse (a small repo can even grow a little from fresh pack structures).
if (( reclaimed_kb > 0 )); then
  reclaim_note="reclaimed ${reclaimed_kb} KiB"
else
  reclaim_note="already compact — no loose objects to reclaim"
fi
echo "AFTER:  .git ${git_kb_after} KiB (${reclaim_note})"

# ---- 3) NOTEBOOK HYGIENE — REPORT ONLY (never mutate a record here) ------------------
# Checks/ notebooks are tracked JSON that append_notebook_cell.py rewrites in full on every
# cell append, and git delta-compresses them poorly, so they are the other real accumulator.
# We only REPORT the largest tracked notebooks. Stripping outputs shrinks them but MUTATES a
# record, so it stays a deliberate manual choice (see the constitution's Repo Health section),
# NOT something this script does on its own.
echo "NOTEBOOKS (largest tracked .ipynb — report only; this script never edits them):"
nb_list=$(git -C "$REPO" ls-files '*.ipynb' 2>/dev/null || true)
if [[ -z "$nb_list" ]]; then
  echo "  (none tracked)"
else
  # Emit "size<TAB>path" per notebook, largest first; whitespace-safe via NUL-delimited paths.
  while IFS= read -r -d '' nb; do
    [[ -f "$REPO/$nb" ]] && du -k "$REPO/$nb" 2>/dev/null
  done < <(git -C "$REPO" ls-files -z '*.ipynb') | sort -rn | head -5 | sed 's/^/  /'
  echo "  To shrink one, strip its outputs by hand (a record-mutating choice), e.g.:"
  echo "    jupyter nbconvert --clear-output --inplace '<ticket>/Checks/checks_master.ipynb'"
fi

# ---- 4) SUMMARY ---------------------------------------------------------------------
echo "DONE: repacked history (${reclaim_note}); no record, log, or commit was deleted."
echo "NEXT: run this again monthly, or whenever .git feels large. History and records are intact."
