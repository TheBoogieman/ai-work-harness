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
fails=0
CORE=(ticket-init ticket-scribe check-scribe doc-writer knowledge-keeper knowledge-curator)

# machinery checks its siblings
# ticket-grammar.sh is in this list too: it is the shared grammar both tools source,
# so a missing/inert grammar lib must itself be caught here, not silently tolerated.
for f in check_ticket_log.sh harness-status.sh ticket-grammar.sh append_notebook_cell.py make_context_pack.sh deploy_agents.sh; do
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

# hooks config parses
hooks="$WORK_ROOT/_harness/hooks/hooks.example.json"
if [[ -f "$hooks" ]]; then
  python3 -c "import json;json.load(open('$hooks'))" 2>/dev/null && echo "OK: hooks config parses." \
    || { echo "FAIL: hooks config is invalid JSON. Fix: repair '$hooks' (git history has the last good copy)."; fails=$((fails+1)); }
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
  if ticket_bearing "$d"; then                     # hand-made ticket-bearing folder: silenceable M1 WARN
    echo "WARN: Tickets/$name holds a .md record but doesn't match the recognised ticket pattern, so it isn't validated. If it's a ticket, rename to match or edit the pattern; if not, run: touch 'Tickets/$name/.not-a-ticket' to silence this."
  fi                                               # else: no ticket content (e.g. a scratch dir) → stay silent
done

(( fails == 0 )) && echo "OK: estate healthy." || { echo "FAIL: $fails issue(s) above — each line names its fix."; exit 1; }
