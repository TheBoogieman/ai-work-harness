#!/usr/bin/env bash
# harness-status.sh — estate-wide health. Side-effect-free; stdout only. Keeps exactly ONE
# primary observation on disk — each WARN's first-seen day, for aging (#71) — and NOTHING derived.
# "Side-effect-free" is the safety property (running status can never corrupt an estate); the one
# stored record is a primary observation the filesystem doesn't remember, not a stored derived view.
# See decisions/014. Grammar: OK: / WARN: / FAIL: / NOTE: single lines. Exit !=0 if any FAIL.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_DIR="${HARNESS_AGENT_DEPLOY_DIR:-$HOME/.copilot/agents}"
# One grammar home: share the validator's exact definition of "what is a ticket"
# ($TICKET_RE, ticket_bearing, ticket_silenced) so status and validator never drift (R-09).
source "$SCRIPT_DIR/ticket-grammar.sh"
# epoch_from_ts14 (ts14->epoch) now lives once, in portability.sh, sourced by BOTH the validator
# and status so they can't drift on the conversion (R-21 — it used to be a duplicated copy here).
source "$SCRIPT_DIR/portability.sh"
# ---- portability compat (GNU/BSD) — issue #1 (epoch_from_date is status-only, so it stays local)
epoch_from_date() {  # YYYY-MM-DD -> epoch
  if date -d "1970-01-01" +%s >/dev/null 2>&1; then date -d "$1" +%s 2>/dev/null || echo 0
  else date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null || echo 0; fi
}
fails=0
CORE=(ticket-init ticket-scribe check-scribe doc-writer knowledge-keeper knowledge-curator)

# ---- #71 WARN aging: one primary-observation state file + tunable tiers + the WARN chokepoint ----
# Doctrine says yellow SCHEDULES, but nothing aged a yellow, so a months-old WARN silently read as
# normal. #71 fixes that by remembering the FIRST time each WARN was seen. The filesystem does not
# record when a condition began, and status is the only observer present at onset, so this first-seen
# day is a PRIMARY OBSERVATION, not a derived view — status still stores nothing derived. Ruling 4a
# puts the record inside the estate whitelist (the aging record is itself part of the record).
# HARNESS_WARN_STATE_FILE lets the demo/tests redirect the single write to a throwaway path; the
# default lives under _harness/ (whitelisted) so a real estate versions and auto-commits it. This
# file does NOT exist in the dev repo — it is created only in a user estate at runtime (no manifest
# line). run_demo.sh EXPORTS an override globally so status stays side-effect-free across all its runs.
HARNESS_WARN_STATE_FILE="${HARNESS_WARN_STATE_FILE:-$WORK_ROOT/_harness/state/warn-aging.tsv}"
# Escalating age tiers in days (ruling 4b — tunable, obvious, at the top). Why these numbers: 14 = a
# fortnight, a yellow that outlived one sprint; 45 = ~six weeks, past the monthly review it was meant
# to prompt; 90 = a quarter, a yellow nobody can still call recent. Yellow stays yellow at EVERY tier
# — only the typographic WEIGHT escalates, never the severity or the exit code.
HARNESS_WARN_AGE_NOTICE_DAYS="${HARNESS_WARN_AGE_NOTICE_DAYS:-14}"
HARNESS_WARN_AGE_CONCERN_DAYS="${HARNESS_WARN_AGE_CONCERN_DAYS:-45}"
HARNESS_WARN_AGE_ALARM_DAYS="${HARNESS_WARN_AGE_ALARM_DAYS:-90}"
# Knowledge staleness threshold (#72, ruling 5a) — a note whose 'Last reviewed:' date is older than
# this many days draws a WARN. Default 90 (a quarter); replaces the old hardcoded 183-day sweep that
# only nagged at half a year (see the GAK block below).
HARNESS_KNOWLEDGE_STALE_DAYS="${HARNESS_KNOWLEDGE_STALE_DAYS:-90}"

# Read the state ONCE, fails-open (A3/A4): an unreadable OR unparseable/corrupt file is treated as
# ABSENT — status regenerates from the current WARN set and prints one note, it never dies. Guarded
# so no read failure can trip set -e mid-report.
WARN_STATE_OLD=""     # in-memory snapshot of the prior first-seen records ("<epoch>\t<key>" lines)
WARN_STATE_NOTE=""    # set to a one-line NOTE if the record degraded this run; printed near the verdict
WARN_ACTIVE=""        # accumulates "<epoch>\t<key>" for every WARN seen THIS run (drives the reconcile)
if [[ -f "$HARNESS_WARN_STATE_FILE" ]]; then
  if WARN_STATE_OLD=$(cat "$HARNESS_WARN_STATE_FILE" 2>/dev/null); then
    # A4 corrupt-check: every non-empty line must be "<digits><TAB><non-empty key>". Any other shape
    # (a torn/truncated write) means the file is untrustworthy → drop it and regenerate.
    if [[ -n "$WARN_STATE_OLD" ]] && printf '%s\n' "$WARN_STATE_OLD" | grep -qvE $'^[0-9]+\t.+$' 2>/dev/null; then
      WARN_STATE_OLD=""
      WARN_STATE_NOTE="NOTE: WARN-aging state was corrupt at $HARNESS_WARN_STATE_FILE — ages reset this run (regenerated from the current WARN set)."
    fi
  else
    WARN_STATE_OLD=""
    WARN_STATE_NOTE="NOTE: WARN-aging state unreadable at $HARNESS_WARN_STATE_FILE — ages reset this run."
  fi
fi

# warn_age_suffix — render the parked age with escalating weight at the tiers. Age 0 (seen THIS run)
# is PLAIN so a fresh WARN reads exactly as it always did; then bracketed, then flagged, then a loud
# marker. The escalation is TYPOGRAPHIC ONLY — the exit code is never touched here.
warn_age_suffix() {
  local d="$1"
  if   (( d >= HARNESS_WARN_AGE_ALARM_DAYS ));   then printf ' [!!! parked %sd — past the %sd mark]' "$d" "$HARNESS_WARN_AGE_ALARM_DAYS"
  elif (( d >= HARNESS_WARN_AGE_CONCERN_DAYS )); then printf ' [!! parked %sd]' "$d"
  elif (( d >= HARNESS_WARN_AGE_NOTICE_DAYS ));  then printf ' [! parked %sd]' "$d"
  elif (( d > 0 ));                              then printf ' [parked %sd]' "$d"
  fi   # d == 0 → no suffix (a fresh WARN is plain)
}

# warn — the ONE chokepoint every NON-dated WARN class routes through (ruling 4c). Aging lives in a
# single home: one edit here ages ALL classes; seven edited call sites would be seven chances to miss
# one, and an un-aged class looks fresh forever. It (1) looks up or assigns this WARN's first-seen day,
# (2) records the key as active so the end-of-run reconcile keeps it, (3) prints "WARN: <body>" with
# the age suffix. It NEVER changes an exit code — yellow stays yellow. $1 = a STABLE key (identifies
# the CONDITION across runs, not the wording, so a size/date that changes each run doesn't churn the
# record); $2 = the message body (printed verbatim after "WARN: ", so existing greps still match).
warn() {
  local key="$1" body="$2" today seen age_days
  today=$(date +%s)
  # look up first-seen for this key in the immutable in-memory snapshot; absent → newly seen (age 0)
  seen=$(printf '%s\n' "$WARN_STATE_OLD" | awk -F'\t' -v k="$key" '$2==k{print $1; exit}')
  [[ -n "$seen" ]] || seen="$today"
  # record this key as active (dedup so a class emitting twice can't double the record)
  case $'\n'"$WARN_ACTIVE" in
    *$'\n'"$seen"$'\t'"$key"$'\n'*) : ;;
    *) WARN_ACTIVE="${WARN_ACTIVE}${seen}"$'\t'"${key}"$'\n' ;;
  esac
  age_days=$(( (today - seen) / 86400 ))
  printf 'WARN: %s%s\n' "$body" "$(warn_age_suffix "$age_days")"
}

# warn_state_sync — reconcile + atomically persist the first-seen record ONCE, at the end, just before
# the verdict. NO-CHURN (A5): write ONLY when the active WARN set differs from what's on disk —
# first-seen kept for a persisting WARN, added when one appears, PRUNED when one clears (so a WARN that
# clears and returns starts a NEW episode at age zero — "how long has THIS sat" is the current
# continuous episode). Because the estate auto-commits every write, a touch-every-run file would mint a
# commit per status run and eat the G3 bloat budget; writing only on a real change avoids that.
# ATOMIC (A4): temp-file-then-rename kills torn files at the source; no locks (single-user estate).
# FAILS-OPEN (A3): a write to an unwritable/missing path must NOT abort the (already-printed) report or
# change the verdict rc — on any failure we print ONE note and return. Same law #79 shipped for its
# recorder: bookkeeping failure never changes the tool's answer.
warn_state_sync() {
  local desired current dir tmp
  desired=$(printf '%s' "$WARN_ACTIVE" | sed '/^$/d' | LC_ALL=C sort -u)   # canonical, order-free
  current=$(printf '%s\n' "$WARN_STATE_OLD" | sed '/^$/d' | LC_ALL=C sort -u)
  [[ "$desired" == "$current" ]] && return 0                              # A5: unchanged → no write
  dir=$(dirname "$HARNESS_WARN_STATE_FILE")
  { mkdir -p "$dir" 2>/dev/null \
      && tmp=$(mktemp "$dir/.warn-aging.XXXXXX" 2>/dev/null) \
      && printf '%s\n' "$desired" | sed '/^$/d' > "$tmp" 2>/dev/null \
      && mv "$tmp" "$HARNESS_WARN_STATE_FILE" 2>/dev/null; } \
    || { [[ -n "${tmp:-}" ]] && rm -f "$tmp" 2>/dev/null
         echo "NOTE: aging unavailable: state file unwritable at $HARNESS_WARN_STATE_FILE (report is complete; ages reset next run)."
         return 0; }
  return 0
}

# machinery checks its siblings
# ticket-grammar.sh is in this list too: it is the shared grammar both tools source,
# so a missing/inert grammar lib must itself be caught here, not silently tolerated.
for f in check_ticket_log.sh harness-status.sh ticket-grammar.sh portability.sh append_notebook_cell.py make_context_pack.sh deploy_agents.sh harness-housekeeping.sh; do
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
    warn "commit-lag" "recent session activity (newest entry $newest_ts) is newer than the last commit ($(git -C "$WORK_ROOT" log -1 --format=%cr)) — the auto-commit hook may not be firing. Fix: check your hook config (_harness/hooks/hooks.example.json) and that writes are being committed."
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
# The store is resolved by git, not by path (issue #86): in a linked worktree .git is a pointer
# file, so the old `[[ -d "$WORK_ROOT/.git" ]]` test skipped this whole check without a word.
# The working-tree figure subtracts the store only when the store actually sits inside the tree —
# in a worktree the shared store lives elsewhere, and subtracting it would go negative.
git_store="$(harness_git_store "$WORK_ROOT")"
if [[ -n "$git_store" ]]; then
  git_warn_mb="${HARNESS_GIT_WARN_MB:-50}"
  git_kb=$(du -sk "$git_store" 2>/dev/null | awk '{print $1}')
  total_kb=$(du -sk "$WORK_ROOT" 2>/dev/null | awk '{print $1}')
  case "$git_store/" in
    "$WORK_ROOT"/*) work_kb=$(( total_kb - git_kb )) ;;
    *)              work_kb=$total_kb ;;
  esac
  git_mib=$(awk -v k="$git_kb" 'BEGIN{ printf "%.1f", k/1024 }')
  work_mib=$(awk -v k="$work_kb" 'BEGIN{ printf "%.1f", k/1024 }')
  if (( git_kb > git_warn_mb * 1024 )); then
    warn "git-bloat" "the record repo's .git is ${git_mib} MiB (working tree ${work_mib} MiB). This grows with every auto-write commit and tracked notebook revision. Run _harness/scripts/harness-housekeeping.sh to repack and reclaim space (tune the threshold with HARNESS_GIT_WARN_MB, default 50)."
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

# GAK staleness sweep (#72) + the undated-note WARN. A note's 'Last reviewed:' date is a claim about
# currency that, until now, nothing read. Status reads it (pure date arithmetic) and nags when the
# note ages past HARNESS_KNOWLEDGE_STALE_DAYS (ruling 5a, default 90 — was a hardcoded 183; #72 folds
# the sweep into status per ruling 5b and tightens it to a quarter). It PRESCRIBES the next act BY
# NAME: the knowledge-curator re-verifies or culls (this repo prescribes, it does not merely observe).
# A note with NO 'Last reviewed:' line at all draws its OWN WARN — a date is a claim, and a missing
# one is a claim that cannot be checked. A note whose line is still the placeholder (e.g. a template's
# 'YYYY-MM-DD') is a skeleton, not a filled note, so the sweep stays silent on it.
# SCOPE FENCE (A6): this sweep is fully DERIVED from the note's own date — it is self-dated and does
# NOT touch the #71 aging state file (one wave, two mechanisms, exactly ONE writer). So these WARNs
# print DIRECTLY, never through the warn() chokepoint.
now=$(date +%s)
while IFS= read -r f; do
  rel="${f#$WORK_ROOT/}"
  d=$(grep -m1 -oE 'Last reviewed: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" | grep -oE '[0-9-]{10}' || true)
  if [[ -n "$d" ]]; then
    age=$(( (now - $(epoch_from_date "$d")) / 86400 ))
    (( age > HARNESS_KNOWLEDGE_STALE_DAYS )) && echo "WARN: stale knowledge ($age days, reviewed $d): $rel — knowledge-curator: re-verify or cull (history keeps it)."
  elif grep -q 'Last reviewed:' "$f"; then
    :  # has a 'Last reviewed:' line but not a real date (placeholder/template skeleton) → stay silent
  else
    echo "WARN: undated knowledge: $rel carries no 'Last reviewed:' date — a date is a claim, a missing one cannot be checked. knowledge-curator: review and stamp it."
  fi
done < <(find "$WORK_ROOT/General AI-Knowledge" -name '*.md' -type f 2>/dev/null || true)

# per-ticket summary — matched against the SHARED $TICKET_RE so the summary and the
# validator recognise the exact same set (a name valid under the expanded grammar must
# appear here, not fall through into the WARN sweep below).
# Per-ticket tracked-root size guard (#38): a ticket's TRACKED footprint should stay lean —
# large scratch/inputs belong in the git-ignored Logs/ or Dump/, not the tracked root.
# Tunable via HARNESS_TICKET_WARN_MB (default 5); WARN never blocks (yellow).
ticket_warn_mb="${HARNESS_TICKET_WARN_MB:-5}"
while IFS= read -r name; do
  md="$WORK_ROOT/Tickets/$name/$name.md"; [[ -f "$md" ]] || continue
  latest=$(grep -oE '^## [0-9]{14} ' "$md" | tail -1 | tr -dc '0-9' || true)
  # A conforming ticket may have no AI-Knowledge/ yet (hand-made or legacy — the validator
  # tolerates it via the same [[ -d ]] guard). WITHOUT this guard, find on the missing dir
  # exits non-zero; 2>/dev/null hides stderr but not the exit code, pipefail carries it through
  # wc, and set -e aborts the roster loop mid-run before any verdict (#37). Absent dir -> 0.
  ak="$WORK_ROOT/Tickets/$name/AI-Knowledge"
  live=0; [[ -d "$ak" ]] && live=$(find "$ak" -maxdepth 1 -name '*.md' ! -name '_index.md' 2>/dev/null | wc -l)
  echo "OK: $name — last session ${latest:-none}, knowledge files: $live."
  # Tracked ROOT = ticket total minus the git-ignored bulk (Logs/, Dump/). du -sk is portable;
  # du --exclude is GNU-only, so subtract. GUARD each subdir du with [[ -d ]] — an absent Logs/
  # or Dump/ makes du exit non-zero, and (pipefail + set -e) would abort the roster loop, the
  # exact class fixed at #37. Absent subdir -> 0.
  t_total=$(du -sk "$WORK_ROOT/Tickets/$name" 2>/dev/null | awk '{print $1}')
  t_logs=0; [[ -d "$WORK_ROOT/Tickets/$name/Logs" ]] && t_logs=$(du -sk "$WORK_ROOT/Tickets/$name/Logs" 2>/dev/null | awk '{print $1}')
  t_dump=0; [[ -d "$WORK_ROOT/Tickets/$name/Dump" ]] && t_dump=$(du -sk "$WORK_ROOT/Tickets/$name/Dump" 2>/dev/null | awk '{print $1}')
  t_root_kb=$(( ${t_total:-0} - ${t_logs:-0} - ${t_dump:-0} ))
  if (( t_root_kb > ticket_warn_mb * 1024 )); then
    t_root_mib=$(awk -v k="$t_root_kb" 'BEGIN{ printf "%.1f", k/1024 }')
    warn "ticket-root:$name" "Tickets/$name tracks ${t_root_mib} MiB in its root (excluding the ignored Logs/ and Dump/). Large scratch or dropped inputs belong in Dump/ (git-ignored), or add a personal, uncommitted ignore to .git/info/exclude — keep the tracked ticket lean. Tune with HARNESS_TICKET_WARN_MB (default 5)."
  fi
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
      warn "pending-complete:$name" "Tickets/$name looks complete (the name conforms) but still carries a .ticket-pending marker. Remove it to finish: rm 'Tickets/$name/.ticket-pending'"
    else
      # Still unnamed: the original pending nag, which omits the .not-a-ticket escape because
      # the intended resolution is naming the ticket, not waving it away.
      warn "pending-unnamed:$name" "Tickets/$name is a pending ticket — ticket-init created it but couldn't determine its proper name. Rename it to a conforming name to complete it (this IS a real ticket). See the recognised pattern in folder-structure.md or _harness/scripts/ticket-grammar.sh."
    fi
    continue
  fi
  [[ "$name" =~ $TICKET_RE ]] && continue          # recognised, no pending marker → validated elsewhere, nothing to surface
  ticket_silenced "$d" && continue                 # hand-made folder the user opted out of via .not-a-ticket
  if ticket_bearing "$d"; then                     # hand-made ticket-bearing folder → the silenceable WARN
    warn "unrecognised:$name" "Tickets/$name holds a .md record but doesn't match the recognised ticket pattern, so it isn't validated. If it's a ticket, rename to match or edit the pattern; if not, run: touch 'Tickets/$name/.not-a-ticket' to silence this."
  fi                                               # else: no ticket content (e.g. a scratch dir) → stay silent
done

# #71: print any state-degradation note, then persist the first-seen record (single write, atomic,
# fails-open). This happens AFTER the full report so a bookkeeping failure never truncates it, and it
# does not touch $fails — aging bookkeeping can never change the verdict.
[[ -n "$WARN_STATE_NOTE" ]] && echo "$WARN_STATE_NOTE"
warn_state_sync

(( fails == 0 )) && echo "OK: estate healthy." || { echo "FAIL: $fails issue(s) above — each line names its fix."; exit 1; }
