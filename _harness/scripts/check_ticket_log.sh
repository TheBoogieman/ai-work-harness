#!/usr/bin/env bash
# check_ticket_log.sh — entry-gate validator. Facts only, no AI.
# Output grammar: single-line OK: / WARN: / FAIL: / NOTE: records. Exit !=0 on any FAIL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKETS="$WORK_ROOT/Tickets"
STAMPS="${HARNESS_STATE_DIR:-$HOME/.harness}/validated"
# ---- portability compat (GNU/BSD) — issue #1
file_mtime() {  # epoch mtime, GNU stat -c / BSD stat -f
  if stat -c %Y "$1" >/dev/null 2>&1; then stat -c %Y "$1"; else stat -f %m "$1"; fi
}
epoch_from_ts14() {  # YYYYMMDDHHMMSS -> epoch, GNU date -d / BSD date -j
  local t="$1"
  if date -d "1970-01-01" +%s >/dev/null 2>&1; then
    date -d "${t:0:8} ${t:8:2}:${t:10:2}:${t:12:2}" +%s 2>/dev/null || echo 0
  else
    date -j -f "%Y%m%d%H%M%S" "$t" +%s 2>/dev/null || echo 0
  fi
}

mkdir -p "$STAMPS"

fails=0
ticket_dirs() {
  local d
  for d in "$TICKETS"/*/; do [[ -d "$d" ]] && basename "$d"; done 2>/dev/null \
    | grep -E '^[0-9]{6}[A-Z]-[A-Z][A-Z0-9]*-[0-9]{3,6}$' || true
}

checked=0
for name in $(ticket_dirs); do
  dir="$TICKETS/$name"; md="$dir/$name.md"; stamp="$STAMPS/$name"
  [[ -f "$md" ]] || { echo "FAIL: $name has no $name.md — create it from the template. Fix: cp -r Tickets/999912Z-PROJ-99999/* '$dir/' and rename."; fails=$((fails+1)); continue; }
  stamp_wall=0; stamp_mtime=0
  if [[ -f "$stamp" ]]; then
    stamp_wall=$(sed -n 1p "$stamp"); stamp_mtime=$(sed -n 2p "$stamp")
    [[ -z "$stamp_mtime" ]] && stamp_mtime=$stamp_wall   # legacy single-line stamp
  fi
  md_epoch=$(file_mtime "$md")
  (( md_epoch > stamp_mtime )) || continue   # unchanged since last successful validation
  checked=$((checked+1))
  ok=1

  # 1) newest session-log header must be at/after the watermark
  latest=$(grep -oE '^## [0-9]{14} ' "$md" | tail -1 | tr -dc '0-9' || true)
  if [[ -z "$latest" ]]; then
    echo "FAIL: $name has no Session Log entry. Fix: run ticket-scribe (or reconstruct from: git -C '$WORK_ROOT' log -- 'Tickets/$name')."; ok=0
  else
    latest_epoch=$(epoch_from_ts14 "$latest")
    if (( latest_epoch < stamp_wall )); then
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
        base_re=$(printf '%s' "$base" | sed 's/[.[\*^$]/\\&/g')
        grep -Eq "(^|[^A-Za-z0-9_.-])${base_re}([^A-Za-z0-9_.-]|$)" "$idx" || { echo "FAIL: $name orphan file AI-Knowledge/$base not in _index.md. Fix: echo '- $base — <what it covers>' >> '$idx'"; ok=0; }
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
    printf '%s\n%s\n' "$(date +%s)" "$md_epoch" > "$stamp"
    echo "OK: $name validated."
  else
    fails=$((fails+1))
  fi
done

(( checked == 0 )) && echo "OK: no tickets modified since last validation — vacuous pass."
(( fails == 0 )) || { echo "FAIL: $fails ticket(s) need attention — red blocks."; exit 1; }
exit 0
