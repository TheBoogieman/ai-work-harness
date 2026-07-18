#!/usr/bin/env bash
# check_ticket_log.sh — entry-gate validator. Facts only, no AI.
# Output grammar: single-line OK: / WARN: / FAIL: / NOTE: records. Exit !=0 on any FAIL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKETS="$WORK_ROOT/Tickets"
STAMPS="${HARNESS_STATE_DIR:-$HOME/.harness}/validated"
mkdir -p "$STAMPS"

fails=0
ticket_dirs() {
  find "$TICKETS" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null \
    | grep -E '^[0-9]{6}[A-Z]-[A-Z][A-Z0-9]*-[0-9]{3,6}$' || true
}

checked=0
for name in $(ticket_dirs); do
  dir="$TICKETS/$name"; md="$dir/$name.md"; stamp="$STAMPS/$name"
  [[ -f "$md" ]] || { echo "FAIL: $name has no $name.md — create it from the template. Fix: cp -r Tickets/999912Z-PROJ-99999/* '$dir/' and rename."; fails=$((fails+1)); continue; }
  stamp_epoch=0; [[ -f "$stamp" ]] && stamp_epoch=$(cat "$stamp")
  md_epoch=$(stat -c %Y "$md")
  (( md_epoch > stamp_epoch )) || continue   # unchanged since last successful validation
  checked=$((checked+1))
  ok=1

  # 1) newest session-log header must be at/after the watermark
  latest=$(grep -oE '^## [0-9]{14} ' "$md" | tail -1 | tr -dc '0-9' || true)
  if [[ -z "$latest" ]]; then
    echo "FAIL: $name has no Session Log entry. Fix: run ticket-scribe (or reconstruct from: git -C '$WORK_ROOT' log -- 'Tickets/$name')."; ok=0
  else
    latest_epoch=$(date -d "${latest:0:8} ${latest:8:2}:${latest:10:2}:${latest:12:2}" +%s 2>/dev/null || echo 0)
    if (( latest_epoch < stamp_epoch )); then
      echo "FAIL: $name changed but no new Session Log entry since last validation. Fix: run ticket-scribe (or log 'session unrecorded; changes per commits' from git history)."; ok=0
    fi
  fi

  # 2) Current State section exists
  grep -q '^## Current State' "$md" || { echo "FAIL: $name missing '## Current State'. Fix: add the section per backbone PART I and have ticket-scribe fill it."; ok=0; }

  # 3) AI-Knowledge index integrity
  ak="$dir/AI-Knowledge"; idx="$ak/_index.md"
  if [[ -d "$ak" ]]; then
    [[ -f "$idx" ]] || { echo "FAIL: $name AI-Knowledge/ has no _index.md. Fix: create it listing one line per file."; ok=0; }
    live=0
    if [[ -f "$idx" ]]; then
      while IFS= read -r f; do
        base=$(basename "$f"); [[ "$base" == "_index.md" ]] && continue
        live=$((live+1))
        grep -q "$base" "$idx" || { echo "FAIL: $name orphan file AI-Knowledge/$base not in _index.md. Fix: echo '- $base — <what it covers>' >> '$idx'"; ok=0; }
      done < <(find "$ak" -maxdepth 1 -name '*.md' -type f)
      while IFS= read -r ref; do
        [[ "$ref" == "_index.md" ]] && continue
        if [[ ! -f "$ak/$ref" ]] && ! grep -q "promoted" <(grep -F "$ref" "$idx"); then
          echo "FAIL: $name ghost entry '$ref' in _index.md (no file, no tombstone). Fix: remove the line or add '(promoted → General AI-Knowledge/<topic>)'."; ok=0
        fi
      done < <(grep -oE '[A-Za-z0-9._-]+\.md' "$idx" | sort -u || true)
      (( live > 10 )) && echo "NOTE: $name AI-Knowledge is fat ($live files) — run knowledge-curator."
      sessions=$(grep -cE '^## [0-9]{14} ' "$md" || true)
      (( sessions >= 3 && live == 0 )) && echo "NOTE: $name has $sessions sessions and zero captured knowledge — is knowledge-keeper being invoked?"
    fi
  fi

  if (( ok == 1 )); then
    echo "$md_epoch" > "$stamp"
    echo "OK: $name validated."
  else
    fails=$((fails+1))
  fi
done

(( checked == 0 )) && echo "OK: no tickets modified since last validation — vacuous pass."
(( fails == 0 )) || { echo "FAIL: $fails ticket(s) need attention — red blocks."; exit 1; }
exit 0
