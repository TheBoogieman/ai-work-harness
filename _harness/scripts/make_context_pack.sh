#!/usr/bin/env bash
# make_context_pack.sh — scrubbed, disposable export of harness state with a stable, sorted file set.
# Bundling the scrubbed files is the job — the .zip is NOT byte-reproducible (zip records per-run
# file mtimes; the Python zipfile fallback differs again). What IS stable: the file SET and the
# sorted MANIFEST inside it.
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
  for rule in "${SCRUB[@]}"; do sed -E "$rule" "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst"; done
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
# Package the scrubbed stage into $ZIP. Prefer the `zip` CLI; fall back to Python's zipfile when
# zip is absent — zip is not installed by default on some hosts (Windows especially), and python3
# is already a hard dependency (nbformat), so the pack never hinges on a separate archiver (#14).
# Both consume the SAME sorted file list; the two archives may differ in metadata but carry
# identical scrubbed contents — bundling those files is the pack's only job. HARNESS_PACK_NO_ZIP
# forces the fallback (testable, deterministic).
if [[ -z "${HARNESS_PACK_NO_ZIP:-}" ]] && command -v zip >/dev/null 2>&1; then
  ( cd "$STAGE" && find . -type f | sort | sed 's|^\./||' | zip -X -q "$ZIP" -@ )
else
  # Python fallback: read the newline-delimited, already-sorted relative paths from stdin and add
  # each to the zip in that order (deterministic). $ZIP is absolute, so cwd=$STAGE is only the read root.
  ( cd "$STAGE" && find . -type f | sort | sed 's|^\./||' | python3 -c '
import sys, zipfile
names = [ln.rstrip("\n") for ln in sys.stdin if ln.strip()]
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for n in names:
        z.write(n, n)
' "$ZIP" )
fi
echo "OK: pack written to $ZIP (disposable — delete after upload; regenerate anytime)."
echo "NOTE: manually SKIM the zip before it leaves the machine. Automation reduces redaction errors; it does not replace the human check."
