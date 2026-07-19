#!/usr/bin/env bash
# harness-status.sh — estate-wide health. Read-only, stdout only, writes NOTHING.
# Grammar: OK: / WARN: / FAIL: / NOTE: single lines. Exit !=0 if any FAIL.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_DIR="${HARNESS_AGENT_DEPLOY_DIR:-$HOME/.copilot/agents}"
# One grammar home: share the validator's exact definition of "what is a ticket"
# ($TICKET_RE, ticket_bearing, ticket_silenced) so status and validator never drift (R-09).
source "$SCRIPT_DIR/ticket-grammar.sh"
# ---- portability compat (GNU/BSD) — issue #1
epoch_from_date() {  # YYYY-MM-DD -> epoch
  if date -d "1970-01-01" +%s >/dev/null 2>&1; then date -d "$1" +%s 2>/dev/null || echo 0
  else date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null || echo 0; fi
}
# epoch_from_ts14 — YYYYMMDDHHMMSS -> epoch (LOCAL tz; see the session-log clock note in the
# constitution, R-10). MIRRORS check_ticket_log.sh's epoch_from_ts14 verbatim: the two are the
# only consumers today, so this is a deliberate small duplication rather than a new shared lib.
# If a third consumer appears — or the two must agree exactly — promote both to a shared
# portability lib (the ticket-grammar.sh pattern). Keep this copy in lockstep with the validator's.
epoch_from_ts14() {  # YYYYMMDDHHMMSS -> epoch, GNU date -d / BSD date -j
  local t="$1"
  if date -d "1970-01-01" +%s >/dev/null 2>&1; then
    date -d "${t:0:8} ${t:8:2}:${t:10:2}:${t:12:2}" +%s 2>/dev/null || echo 0
  else
    date -j -f "%Y%m%d%H%M%S" "$t" +%s 2>/dev/null || echo 0
  fi
}
fails=0
CORE=(ticket-init ticket-scribe check-scribe doc-writer knowledge-keeper knowledge-curator)

# machinery checks its siblings
# ticket-grammar.sh is in this list too: it is the shared grammar both tools source,
# so a missing/inert grammar lib must itself be caught here, not silently tolerated.
for f in check_ticket_log.sh harness-status.sh ticket-grammar.sh append_notebook_cell.py make_context_pack.sh deploy_agents.sh harness-housekeeping.sh; do
  p="$SCRIPT_DIR/$f"
  [[ -f "$p" ]] || { echo "FAIL: missing script $f. Fix: restore from git: git -C '$WORK_ROOT' checkout -- '_harness/scripts/$f'"; fails=$((fails+1)); continue; }
  [[ -x "$p" ]] || { echo "FAIL: $f not executable. Fix: chmod +x '$p'"; fails=$((fails+1)); }
done

# git liveness
if git -C "$WORK_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  last=$(git -C "$WORK_ROOT" log -1 --format=%cr 2>/dev/null || echo "never")
  echo "OK: work repo present; last commit $last."
  if git -C "$WORK_ROOT" remote | grep -q .; then
    if [[ -n "${HARNESS_DEMO:-}" ]]; then
      echo "NOTE: remote present — fine for a template clone; your real Work repo must have none."
    else
      echo "FAIL: work repo has a REMOTE configured — it must be local-only. Fix: git -C '$WORK_ROOT' remote remove <name>"; fails=$((fails+1))
    fi
  fi
else
  echo "FAIL: no git repo at $WORK_ROOT. Fix: git -C '$WORK_ROOT' init (whitelist .gitignore already present)."; fails=$((fails+1))
fi

# commit-vs-session liveness cross-check (issue #4 / R-11): the auto-commit hook should capture
# every write, so the last commit must never lag behind session activity. If the newest session
# log entry across all tickets is meaningfully NEWER than the last commit, the safety net may have
# silently stopped firing — the exact failure the hook exists to prevent. Surface it (WARN, exit
# stays 0 — a yellow nudge, not a block). It compares WHEN work happened (session headers, local
# time) against WHEN it was last committed (git commit time). A margin (default 300s, tunable via
# HARNESS_COMMIT_LAG_WARN_S) absorbs the normal seconds between a write and its auto-commit.
# Suppressed under HARNESS_DEMO: the demo/template context deliberately has scratch tickets whose
# session logs outpace the last commit (the demo doesn't run the auto-commit hook, and a fresh
# 60-second-try clone's HEAD is an old upstream commit), so the nudge would be a false alarm there.
# HARNESS_LIVENESS_FORCE re-enables it so the demo's own [R-11 guard] can exercise the real check.
if { [[ -z "${HARNESS_DEMO:-}" ]] || [[ -n "${HARNESS_LIVENESS_FORCE:-}" ]]; } \
   && git -C "$WORK_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  commit_epoch=$(git -C "$WORK_ROOT" log -1 --format=%ct 2>/dev/null || echo 0)
  newest_session=0; newest_ts=""
  while IFS= read -r name; do
    md="$WORK_ROOT/Tickets/$name/$name.md"; [[ -f "$md" ]] || continue
    ts=$(grep -oE '^## [0-9]{14} ' "$md" | tail -1 | tr -dc '0-9' || true)
    [[ -n "$ts" ]] || continue
    e=$(epoch_from_ts14 "$ts")
    (( e > newest_session )) && { newest_session=$e; newest_ts=$ts; }
  done < <(for d in "$WORK_ROOT/Tickets"/*/; do [[ -d "$d" ]] && basename "$d"; done 2>/dev/null | grep -E "$TICKET_RE" || true)
  lag_margin="${HARNESS_COMMIT_LAG_WARN_S:-300}"
  if (( newest_session > 0 && commit_epoch > 0 && newest_session > commit_epoch + lag_margin )); then
    echo "WARN: recent session activity (newest entry $newest_ts) is newer than the last commit ($(git -C "$WORK_ROOT" log -1 --format=%cr)) — the auto-commit hook may not be firing. Fix: check your hook config (_harness/hooks/hooks.example.json) and that writes are being committed."
  fi
fi

# repo-size nudge (issue #16): the record repo grows with every auto-write commit and every
# tracked-notebook revision, so .git creeps up over months of use. Surface it when it gets
# large and prescribe the fix — the same observe-and-prescribe pattern as the ticket WARNs.
# This is a WARN, never a FAIL: storage growth is a yellow nudge to tidy, not a broken record
# to block on, and the remedy (git gc via harness-housekeeping.sh) is a human act per doctrine.
# The threshold is tunable via HARNESS_GIT_WARN_MB (default 50 MiB) — high enough to stay quiet
# on a young repo, low enough to catch real bloat before it hurts. du -sk is portable (GNU/BSD);
# the working-tree size is total-minus-.git since du --exclude is GNU-only.
if [[ -d "$WORK_ROOT/.git" ]]; then
  git_warn_mb="${HARNESS_GIT_WARN_MB:-50}"
  git_kb=$(du -sk "$WORK_ROOT/.git" 2>/dev/null | awk '{print $1}')
  work_kb=$(( $(du -sk "$WORK_ROOT" 2>/dev/null | awk '{print $1}') - git_kb ))
  git_mib=$(awk -v k="$git_kb" 'BEGIN{ printf "%.1f", k/1024 }')
  work_mib=$(awk -v k="$work_kb" 'BEGIN{ printf "%.1f", k/1024 }')
  if (( git_kb > git_warn_mb * 1024 )); then
    echo "WARN: the record repo's .git is ${git_mib} MiB (working tree ${work_mib} MiB). This grows with every auto-write commit and tracked notebook revision. Run _harness/scripts/harness-housekeeping.sh to repack and reclaim space (tune the threshold with HARNESS_GIT_WARN_MB, default 50)."
  else
    echo "OK: record repo .git ${git_mib} MiB (working tree ${work_mib} MiB) — under the ${git_warn_mb} MiB housekeeping threshold."
  fi
fi

# hooks config parses. HARNESS_HOOKS_FILE overrides the path (flexibility + testable).
hooks="${HARNESS_HOOKS_FILE:-$WORK_ROOT/_harness/hooks/hooks.example.json}"
if [[ -f "$hooks" ]]; then
  # The path is passed as sys.argv[1], NEVER interpolated into the Python source. A path with a
  # quote, backslash, or an MSYS form (/c/... under Git Bash) corrupts the source string literal
  # open('$path') — that string-mangling is the R-05 anti-pattern and the #8 bug, which the old
  # swallowed error then disguised as "invalid JSON". argv passes the path as data, immune to it.
  hpath="$hooks"
  # Git-Bash half of #8: Windows Store Python can't open an MSYS /c/... path, so under MSYS convert
  # to a Windows-native path when cygpath is available. Guarded by MSYSTEM, so POSIX hosts are
  # untouched (this branch is dormant on Linux/macOS/WSL and UNWITNESSED here — needs a Git-Bash host).
  if [[ -n "${MSYSTEM:-}" ]] && command -v cygpath >/dev/null 2>&1; then
    hpath=$(cygpath -w "$hooks" 2>/dev/null || echo "$hooks")
  fi
  # Distinguish "can't read the file" (exit 3) from "invalid JSON" (exit 4) — conflating them under
  # 2>/dev/null is exactly what let #8 (an unreadable path) masquerade as invalid JSON. The signal
  # now travels via exit code, not a swallowed traceback.
  hk_rc=0
  python3 -c 'import json,sys
try: f=open(sys.argv[1])
except OSError: sys.exit(3)
try: json.load(f)
except ValueError: sys.exit(4)' "$hpath" 2>/dev/null || hk_rc=$?
  case "$hk_rc" in
    0) echo "OK: hooks config parses." ;;
    3) echo "FAIL: hooks config could not be READ at '$hooks' (path or permission problem, not JSON). Fix: check the path exists and is readable (under Git Bash a /c/... path may need cygpath -w)."; fails=$((fails+1)) ;;
    *) echo "FAIL: hooks config is invalid JSON. Fix: repair '$hooks' (git history has the last good copy)."; fails=$((fails+1)) ;;
  esac
fi

# agents: _agents/ is the roster; deployed copies must match source
for a in "${CORE[@]}"; do
  [[ -f "$WORK_ROOT/_agents/$a.agent.md" ]] || { echo "FAIL: core agent $a.agent.md missing from _agents/. Fix: git -C '$WORK_ROOT' checkout -- '_agents/$a.agent.md'"; fails=$((fails+1)); }
done
shopt -s nullglob
for src in "$WORK_ROOT"/_agents/*.agent.md; do
  base=$(basename "$src"); dep="$DEPLOY_DIR/$base"
  if [[ ! -f "$dep" ]]; then
    echo "FAIL: agent $base not deployed to $DEPLOY_DIR. Fix: _harness/scripts/deploy_agents.sh"; fails=$((fails+1))
  elif ! cmp -s "$src" "$dep"; then
    echo "FAIL: agent $base drifted from source. Fix: _harness/scripts/deploy_agents.sh"; fails=$((fails+1))
  fi
done

# GAK staleness
now=$(date +%s)
while IFS= read -r f; do
  d=$(grep -m1 -oE 'Last reviewed: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" | grep -oE '[0-9-]{10}' || true)
  if [[ -n "$d" ]]; then
    age=$(( (now - $(epoch_from_date "$d")) / 86400 ))
    (( age > 183 )) && echo "WARN: stale knowledge ($age days): ${f#$WORK_ROOT/} — re-verify or cull (history keeps it)."
  fi
done < <(find "$WORK_ROOT/General AI-Knowledge" -name '*.md' -type f 2>/dev/null || true)

# per-ticket summary — matched against the SHARED $TICKET_RE so the summary and the
# validator recognise the exact same set (a name valid under the expanded grammar must
# appear here, not fall through into the WARN sweep below).
while IFS= read -r name; do
  md="$WORK_ROOT/Tickets/$name/$name.md"; [[ -f "$md" ]] || continue
  latest=$(grep -oE '^## [0-9]{14} ' "$md" | tail -1 | tr -dc '0-9' || true)
  live=$(find "$WORK_ROOT/Tickets/$name/AI-Knowledge" -maxdepth 1 -name '*.md' ! -name '_index.md' 2>/dev/null | wc -l)
  echo "OK: $name — last session ${latest:-none}, knowledge files: $live."
done < <(for d in "$WORK_ROOT/Tickets"/*/; do [[ -d "$d" ]] && basename "$d"; done 2>/dev/null | grep -E "$TICKET_RE" || true)

# Surface, never enforce (Model 1): a folder that HOLDS a ticket record but whose name
# the grammar doesn't recognise is silently skipped by the validator — so a user could
# believe it's being validated when it isn't. WARN it (exit stays 0; we never block) so
# the gap is visible. Conforming names are validated elsewhere; user-silenced folders
# opt out via a tracked .not-a-ticket marker; nameless scratch dirs stay quiet. The `*/`
# glob is whitespace-safe and already excludes Tickets/README.md (a file, not a dir).
# Three distinct WARNs come out of this sweep — pending (two forms) and hand-made, below.
for d in "$WORK_ROOT/Tickets"/*/; do
  [[ -d "$d" ]] || continue
  name=$(basename "$d")
  # The .ticket-pending marker is the ticket's lifecycle token, NOT its name — so it is
  # tested FIRST, even ahead of the conforming-name skip below. A pending ticket completes
  # only when a human REMOVES the marker (a recorded act — "a fixed record is a human act");
  # renaming the folder alone never completes it. Testing the marker before the name closes
  # two evasions the name-first order allowed: a rename to a conforming-but-garbage name
  # can't silence the nag, and a marker stranded inside a properly-renamed ticket is still
  # surfaced. The nag follows the marker, not the name. (This also keeps pending winning
  # over .not-a-ticket — you can't silence a ticket init flagged as unfinished.)
  if ticket_pending "$d"; then
    if [[ "$name" =~ $TICKET_RE ]]; then
      # Name conforms but the marker lingers: the ticket looks done — the only thing left is
      # to remove the marker. We never auto-remove it; completion is the human's recorded act.
      echo "WARN: Tickets/$name looks complete (the name conforms) but still carries a .ticket-pending marker. Remove it to finish: rm 'Tickets/$name/.ticket-pending'"
    else
      # Still unnamed: the original pending nag, which omits the .not-a-ticket escape because
      # the intended resolution is naming the ticket, not waving it away.
      echo "WARN: Tickets/$name is a pending ticket — ticket-init created it but couldn't determine its proper name. Rename it to a conforming name to complete it (this IS a real ticket). See the recognised pattern in folder-structure.md or _harness/scripts/ticket-grammar.sh."
    fi
    continue
  fi
  [[ "$name" =~ $TICKET_RE ]] && continue          # recognised, no pending marker → validated elsewhere, nothing to surface
  ticket_silenced "$d" && continue                 # hand-made folder the user opted out of via .not-a-ticket
  if ticket_bearing "$d"; then                     # hand-made ticket-bearing folder → the silenceable WARN
    echo "WARN: Tickets/$name holds a .md record but doesn't match the recognised ticket pattern, so it isn't validated. If it's a ticket, rename to match or edit the pattern; if not, run: touch 'Tickets/$name/.not-a-ticket' to silence this."
  fi                                               # else: no ticket content (e.g. a scratch dir) → stay silent
done

(( fails == 0 )) && echo "OK: estate healthy." || { echo "FAIL: $fails issue(s) above — each line names its fix."; exit 1; }
