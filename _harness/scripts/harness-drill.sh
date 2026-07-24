#!/usr/bin/env bash
# harness-drill.sh — rehearse recovery BEFORE the emergency (issue #75). Backups exist, but a
# restore nobody has practised is a hope, not a capability; the git undo net is doctrine that has
# been read, not muscle memory. This script turns both into a rehearsal you run on a calm day.
# THREE modes, ALL read-only toward the live estate — each only ever WRITES into its own `mktemp -d`
# scratch dir, so the estate's own files and history are never modified:
#   restore-drill  restore the record from the estate's OWN .git into a temp dir; prove it validates.
#   bundle-drill   make a LOCAL `git bundle` of the record, restore from THAT; prove it validates.
#                  The bundle STAYS LOCAL — ferrying it anywhere is issue #77 and out of scope here.
#   undo-drill     a guided calm-conditions git-undo rehearsal on a throwaway FIXTURE (never live
#                  data), so the undo net is muscle memory before the emergency, not discovered in one.
# Output is prescriptive throughout: each step says what it PROVED and what the human would do FOR
# REAL. Invoked BY HAND by someone who decided to rehearse — there is deliberately no status nag
# (ruling 8b): the harness never nags you to practise; it just makes practice cheap.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Source portability.sh for harness_git_store: in a LINKED WORKTREE the estate's .git is a pointer
# FILE, not a directory, and the real object store lives in the main checkout. Path-testing .git
# ourselves would silently find nothing there (the #86 bug); harness_git_store asks git for the
# store git itself would use, so restore-drill works from a worktree too.
source "$SCRIPT_DIR/portability.sh"

# say — one prefix-free teaching line, so the whole rehearsal reads as a single guided script.
say() { printf '%s\n' "$*"; }

# validate_copy — run a RESTORED copy's OWN validator against its OWN records, with a throwaway
# state dir so no stamp from the real estate is read or written (a fresh state dir also guarantees
# the restored files are actually re-validated, not skipped as unchanged). Returns the validator's
# rc so the caller can prove the restored record is green — a restore producing an unvalidatable
# record is a FAILED restore. $1 = restored checkout root.
validate_copy() {
  local root="$1" st rc
  st=$(mktemp -d)
  # set +e around the validator: we WANT its non-zero rc as data, not an abort under set -e.
  set +e
  HARNESS_STATE_DIR="$st" bash "$root/_harness/scripts/check_ticket_log.sh"
  rc=$?
  set -e
  rm -rf "$st"
  return "$rc"
}

# restore_drill — the core recovery move: rebuild the record from the estate's OWN .git into a
# scratch dir and prove the rebuilt copy validates. A `git clone` READS the source store and writes
# only into the destination, so the live estate is never modified.
restore_drill() {
  local store tmp restored
  # Resolve the true store via harness_git_store (handles the linked-worktree pointer-file case).
  store=$(harness_git_store "$WORK_ROOT")
  [ -n "$store" ] || { say "harness-drill: $WORK_ROOT is not a git checkout — nothing to restore from."; return 1; }
  tmp=$(mktemp -d); restored="$tmp/restored"
  say "=== restore-drill — restore the record from the estate's OWN .git ==="
  say "  reading (read-only) from the store: $store"
  git clone --quiet "$store" "$restored"
  say "  restored a full working copy into: $restored"
  if validate_copy "$restored"; then
    say "  PROVED: the restored copy validates green — the record can be rebuilt from .git alone."
  else
    say "  the restored copy did NOT validate — investigate before trusting this backup."
    rm -rf "$tmp"; return 1
  fi
  say "  FOR REAL: if the working tree were lost, this IS the recovery — clone <estate>/.git into a"
  say "            fresh dir (or run 'git restore .' in place) and your record is back."
  rm -rf "$tmp"
}

# bundle_drill — package the whole history into a single portable file with `git bundle`, then
# restore FROM that file, exactly as a recipient would. Proves the bundle is a self-contained,
# restorable artifact. `git bundle create` reads refs and writes only the bundle into our scratch
# dir; it never modifies the estate. The bundle STAYS LOCAL (ferrying it is issue #77, out of scope).
bundle_drill() {
  local tmp bundle restored
  tmp=$(mktemp -d); bundle="$tmp/estate.bundle"; restored="$tmp/from-bundle"
  say "=== bundle-drill — restore from a LOCAL git bundle of the record ==="
  git -C "$WORK_ROOT" bundle create "$bundle" --all
  say "  wrote a LOCAL bundle: $bundle"
  say "  (the bundle STAYS LOCAL — ferrying it off this machine is issue #77, out of scope here.)"
  git clone --quiet "$bundle" "$restored"
  say "  restored a full working copy FROM the bundle into: $restored"
  if validate_copy "$restored"; then
    say "  PROVED: the copy restored from the bundle validates green — the bundle is a true backup."
  else
    say "  the bundle-restored copy did NOT validate — the bundle is not a trustworthy backup."
    rm -rf "$tmp"; return 1
  fi
  say "  FOR REAL: 'git bundle create record.bundle --all' makes a single-file backup you can copy"
  say "            to external media; restore it with 'git clone record.bundle <dir>'."
  rm -rf "$tmp"
}

# undo_drill — rehearse the git undo net on a THROWAWAY fixture, never live data. Builds a tiny
# repo and practises the two everyday recoveries: an uncommitted mistake (git restore) and a
# committed mistake (git revert). The estate is never read or written here.
undo_drill() {
  local fix; fix=$(mktemp -d)
  say "=== undo-drill — a calm-conditions revert on a THROWAWAY fixture (never live data) ==="
  git -C "$fix" init --quiet
  printf 'good record v1\n' > "$fix/record.md"
  git -C "$fix" -c user.email=drill@local -c user.name=drill add -A
  git -C "$fix" -c user.email=drill@local -c user.name=drill commit --quiet -m "good record"
  say "  fixture seeded with one good commit."
  # Rehearsal 1 — an UNCOMMITTED mistake is undone by restoring the file from the index/HEAD.
  printf 'OOPS destructive edit\n' > "$fix/record.md"
  say "  simulated an uncommitted bad edit; recovering with: git restore record.md"
  git -C "$fix" restore record.md
  if grep -q 'good record v1' "$fix/record.md"; then
    say "  PROVED: an uncommitted mistake is undone by 'git restore <file>' — the file is back."
  fi
  # Rehearsal 2 — a COMMITTED mistake is undone by git revert, which records the undo AS history
  # (nothing is erased: the estate keeps both the mistake and its reversal — late-but-true).
  printf 'bad record v2\n' > "$fix/record.md"
  git -C "$fix" -c user.email=drill@local -c user.name=drill commit --quiet -am "bad commit"
  say "  simulated a committed bad change; recovering with: git revert HEAD"
  git -C "$fix" -c user.email=drill@local -c user.name=drill revert --no-edit --quiet HEAD
  if grep -q 'good record v1' "$fix/record.md"; then
    say "  PROVED: a committed mistake is undone by 'git revert HEAD' — history keeps both the"
    say "          mistake and its reversal, so the record stays honest."
  fi
  say "  FOR REAL: uncommitted damage -> 'git restore <path>'; a bad commit -> 'git revert <sha>'."
  rm -rf "$fix"
}

# usage — the modes, printed when no (or an unknown) mode is given.
usage() {
  cat <<'EOF'
harness-drill.sh — rehearse recovery on a calm day (issue #75). Read-only toward the estate.
Usage: harness-drill.sh <mode>
  restore-drill   restore the record from the estate's own .git into a temp dir; prove it validates
  bundle-drill    make a LOCAL git bundle, restore from it into a temp dir; prove it validates
  undo-drill      guided calm-conditions git-undo rehearsal on a throwaway fixture
  all             run all three in sequence
EOF
}

# Dispatch on the requested mode.
case "${1:-}" in
  restore-drill) restore_drill ;;
  bundle-drill)  bundle_drill ;;
  undo-drill)    undo_drill ;;
  all)           restore_drill; bundle_drill; undo_drill ;;
  ""|-h|--help|help) usage ;;
  *) say "harness-drill: unknown mode '$1'"; usage; exit 2 ;;
esac
