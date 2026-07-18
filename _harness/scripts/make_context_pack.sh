#!/usr/bin/env bash
# make_context_pack.sh — scrubbed, deterministic, disposable export of harness state.
# Output: ~/Desktop/harness-pack-YYYYMMDD-HHMM.zip (override: PACK_OUT_DIR). Never inside the repo.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${PACK_OUT_DIR:-$HOME/Desktop}"
STAMP=$(date +%Y%m%d-%H%M)
STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT

# ---- SCRUB TABLE — single source of scrubbing truth. Extend HERE when a new
# identifier class appears. sed -E 's|find|replace|g' pairs.
SCRUB=(
  's|<YOUR-EMPLOYEE-ID>|<user>|g'
  's|<YOUR-ORG-DOMAIN>|<org>|g'
  's|<YOUR-CLOUD-ACCOUNT-ID>|<account>|g'
)
# Terms that must NOT appear in the final pack (self-audit):
AUDIT_TERMS='<YOUR-EMPLOYEE-ID>|<YOUR-ORG-DOMAIN>|<YOUR-CLOUD-ACCOUNT-ID>'

TICKET=""
[[ "${1:-}" == "--ticket" ]] && TICKET="${2:?--ticket needs an ID}"

stage_one() { # $1 = path relative to WORK_ROOT
  local rel="$1" src="$WORK_ROOT/$1" dst="$STAGE/$1"
  [[ -f "$src" ]] || return 0
  mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"
  for rule in "${SCRUB[@]}"; do sed -E -i "$rule" "$dst"; done
}

# Harness state per the backbone's Context Pack Convention
stage_one folder-structure.md
stage_one AGENTS.md
stage_one README.md
for f in "$WORK_ROOT"/_agents/*.agent.md;        do stage_one "_agents/$(basename "$f")"; done
for f in "$WORK_ROOT"/_harness/scripts/*;        do stage_one "_harness/scripts/$(basename "$f")"; done
for f in "$WORK_ROOT"/_harness/hooks/*;          do stage_one "_harness/hooks/$(basename "$f")"; done
while IFS= read -r f; do stage_one "${f#$WORK_ROOT/}"; done \
  < <(find "$WORK_ROOT/General AI-Knowledge/AI Harness" -type f 2>/dev/null || true)
if [[ -n "$TICKET" ]]; then
  stage_one "Tickets/$TICKET/$TICKET.md"
  stage_one "Tickets/$TICKET/AI-Knowledge/_index.md"
fi

# Deterministic MANIFEST + self-audit
( cd "$STAGE"
  find . -type f ! -name MANIFEST.txt | sort | sed 's|^\./||' > MANIFEST.txt
  if grep -RqiE "$AUDIT_TERMS" . --exclude=MANIFEST.txt --exclude='make_context_pack.sh' 2>/dev/null; then
    echo "self-audit: FAILED — scrub-table terms found" >> MANIFEST.txt
    echo "FAIL: scrub-table terms survived staging. Fix the SCRUB table in make_context_pack.sh and re-run." >&2
    exit 1
  fi
  echo "self-audit: zero scrub-table hits" >> MANIFEST.txt
)

mkdir -p "$OUT_DIR"
ZIP="$OUT_DIR/harness-pack-$STAMP.zip"
( cd "$STAGE" && find . -type f | sort | sed 's|^\./||' | zip -X -q "$ZIP" -@ )
echo "OK: pack written to $ZIP (disposable — delete after upload; regenerate anytime)."
echo "NOTE: manually SKIM the zip before it leaves the machine. Automation reduces redaction errors; it does not replace the human check."
