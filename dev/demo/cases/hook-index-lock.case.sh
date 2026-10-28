#!/usr/bin/env bash
# hook-index-lock.case.sh — [hook-index-lock] (#343): a commit-bearing hook meets a held git index
# lock without failing. SOURCED by the runner; see dev/scripts/run-demo.sh.
#
# Another git process holds .git/index.lock for a moment after every write — VS Code's Git
# extension runs `git status` within a second of each auto-commit — and the hook's `git add -A` used
# to fail outright ("Unable to create '.../index.lock': File exists"), after which the `|| git commit`
# that follows it failed the same way: two fatal lines in front of the user, and a non-zero exit.
# The hook now waits briefly for the lock and, if it is still held, leaves the change to the next
# hook with a NOTE. It never deletes a lock: one left by a running git is not the hook's to remove.
#
# Each commit-bearing command is PARSED from the one schema home (as [estate-key-containment] does),
# so a third commit hook inherits coverage. Per command, three runs against a dirty estate fixture:
#   HELD      the lock stays put: exit 0, no fatal line, a NOTE, no commit, the lock untouched;
#   RELEASED  the lock clears while the hook waits: the change is committed;
#   FREE      no lock at all: the change is committed (the ordinary path still works).
# REVERT-PROOF: drop the wait from hooks.example.json and HELD reds on the exit code and the fatal line.

hl_make_estate() {  # <dir> — an estate-keyed repo with a base commit, a stub validator and a dirty file
  local d="$1"; mkdir -p "$d/_harness/scripts"; git -C "$d" init -q
  git -C "$d" config user.email t@t.local; git -C "$d" config user.name t
  git -C "$d" config harness.estate true
  printf 'echo "OK: stub validator"\n' > "$d/_harness/scripts/check-ticket-log.sh"
  echo seed > "$d/f"; git -C "$d" add -A; git -C "$d" commit -q -m seed
}

hl_commits() { git -C "$1" rev-list --count HEAD; }

case_hook_index_lock() {
  local HL_TMP HL_CMDS=() hl_line hl_cmd hl_d hl_lock hl_b hl_out hl_rc hl_n=0
  echo "--- #343 hook-index-lock: a held index lock is waited for, never a fatal line ---"
  HL_TMP=$(mktemp -d)
  while IFS= read -r hl_line; do
    [ -n "$hl_line" ] && HL_CMDS+=("$hl_line")
  done < <(python3 -c "
import json
d = json.load(open('estate/_harness/hooks/hooks.example.json'))
for entries in d['hooks'].values():
    for e in entries:
        if 'git commit' in e.get('bash', ''):
            print(e['bash'])
")
  [ "${#HL_CMDS[@]}" -ge 2 ] \
    || { echo "BUG [hook-index-lock]: expected >=2 commit-bearing hooks, got ${#HL_CMDS[@]}"; exit 1; }
  for hl_cmd in "${HL_CMDS[@]}"; do
    hl_n=$((hl_n + 1)); hl_d="$HL_TMP/estate$hl_n"; hl_make_estate "$hl_d"
    hl_lock="$hl_d/.git/index.lock"
    # HELD: the lock never clears.
    echo change1 >> "$hl_d/f"; : > "$hl_lock"; hl_b=$(hl_commits "$hl_d")
    set +e; hl_out=$( cd "$hl_d" && bash -c "$hl_cmd" 2>&1 ); hl_rc=$?; set -e
    [ "$hl_rc" -eq 0 ] \
      || { echo "BUG [hook-index-lock]: hook $hl_n exited $hl_rc while the index lock was held:"; \
           printf '%s\n' "$hl_out"; exit 1; }
    printf '%s\n' "$hl_out" | grep -qi 'fatal' \
      && { echo "BUG [hook-index-lock]: hook $hl_n printed a fatal line for a held lock:"; \
           printf '%s\n' "$hl_out"; exit 1; }
    printf '%s\n' "$hl_out" | grep -q 'NOTE \[auto-commit\]' \
      || { echo "BUG [hook-index-lock]: hook $hl_n gave up on a held lock without saying so:"; \
           printf '%s\n' "$hl_out"; exit 1; }
    [ "$(hl_commits "$hl_d")" = "$hl_b" ] \
      || { echo "BUG [hook-index-lock]: hook $hl_n committed through a held lock"; exit 1; }
    [ -e "$hl_lock" ] \
      || { echo "BUG [hook-index-lock]: hook $hl_n deleted a lock it did not own"; exit 1; }
    # RELEASED: another git finishes while the hook waits.
    hl_b=$(hl_commits "$hl_d")
    ( sleep 0.5; rm -f "$hl_lock" ) &
    ( cd "$hl_d" && bash -c "$hl_cmd" ) >/dev/null 2>&1 || true
    wait
    [ "$(hl_commits "$hl_d")" -gt "$hl_b" ] \
      || { echo "BUG [hook-index-lock]: hook $hl_n did not commit after the lock cleared"; exit 1; }
    # FREE: no lock, the ordinary path.
    echo change2 >> "$hl_d/f"; hl_b=$(hl_commits "$hl_d")
    ( cd "$hl_d" && bash -c "$hl_cmd" ) >/dev/null 2>&1 || true
    [ "$(hl_commits "$hl_d")" -gt "$hl_b" ] \
      || { echo "BUG [hook-index-lock]: hook $hl_n did not commit with no lock held"; exit 1; }
  done
  rm -rf "$HL_TMP"
  echo "  ok [hook-index-lock] — $hl_n commit-bearing hook(s): a held lock gets a NOTE and exit 0," \
    "no fatal line, no commit, the lock untouched; a lock that clears in time, and no lock, both commit"
}
