#!/usr/bin/env bash
# install.sh — scaffold or complete a harness Work ESTATE from this source distribution.
#
# It is a DUMB CREATOR (#39 cond 2, ABSOLUTE): it creates only what is ABSENT and NEVER edits,
# appends to, or repairs any file that already exists — even a broken one. Surfacing and fixing
# broken state is the validator's/status's/agent's job, on the record; the installer judges
# nothing and heals nothing. A second run finds nothing absent and says "nothing to do."
#
# It is the SHIPPING BOUNDARY (#43 cond 2): it lays down PRODUCT files ONLY, read from
# .github/ship-manifest.txt (the one classification home). A fresh estate contains ZERO dev files.
#
# Runs FROM the source distribution (this file's directory), targeting an estate dir.
#   Usage: install.sh [--dry-run] [--yes] [TARGET_DIR]
#     --dry-run  print the full plan and touch nothing
#     --yes      non-interactive: accept every suggested default
#     TARGET_DIR the estate root to create/complete (default: current directory)
set -euo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SOURCE/.github/ship-manifest.txt"

# ---- args -----------------------------------------------------------------------------------
DRY=0; YES=0; TARGET=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --yes)     YES=1 ;;
    -*)        echo "install: unknown option: $a" >&2; exit 2 ;;
    *)         [ -z "$TARGET" ] || { echo "install: only one TARGET_DIR allowed" >&2; exit 2; }; TARGET="$a" ;;
  esac
done
[ -n "$TARGET" ] || TARGET="$PWD"
# Resolve TARGET to an absolute path WITHOUT creating it — --dry-run must touch nothing, not even
# the target dir. A real run creates it in the execute section below.
if [ -d "$TARGET" ]; then
  TARGET="$(cd "$TARGET" && pwd)"
else
  parent="$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd || true)"
  [ -n "$parent" ] || { echo "install: the parent of TARGET does not exist: $(dirname "$TARGET")" >&2; exit 1; }
  TARGET="$parent/$(basename "$TARGET")"
fi

# ---- safety ---------------------------------------------------------------------------------
# Never install onto the source itself (that is a dev checkout, not an estate).
[ "$TARGET" != "$SOURCE" ] || { echo "install: TARGET is the source distribution itself — choose a separate estate dir." >&2; exit 1; }
# Estates are LOCAL-ONLY: refuse a target whose git repo already has a remote (the prompt path's rule).
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 && git -C "$TARGET" remote | grep -q .; then
  echo "install: TARGET already has a git REMOTE configured; estates must be local-only. Remove it first: git -C '$TARGET' remote remove <name>" >&2
  exit 1
fi
[ -f "$MANIFEST" ] || { echo "install: cannot find $MANIFEST — run install.sh from the harness source distribution." >&2; exit 1; }

# ---- helpers --------------------------------------------------------------------------------
ask() {  # ask <prompt> <default> ; echoes the answer (default under --yes or on empty Enter)
  local prompt="$1" def="$2" ans=""
  if [ "$YES" -eq 1 ]; then printf '%s' "$def"; return; fi
  printf '%s [%s]: ' "$prompt" "$def" >&2
  IFS= read -r ans || true
  [ -n "$ans" ] && printf '%s' "$ans" || printf '%s' "$def"
}
CREATED=()   # paths (relative to TARGET) this run actually created — the ONLY things config may touch
plan_create=(); plan_exists=()

# ---- identity interview (ask-everything, strong defaults; #39 amendment A) -------------------
DEF_BOARD="PROJ"
BOARD="$(ask "Ticket-naming board key (uppercase; the default pattern accepts any single-segment key)" "$DEF_BOARD")"
BOARD_WIDEN=0
# Board-key escape hatch (amendment B): the default grammar's board segment is [A-Z][A-Z0-9]* —
# no internal hyphen. If the entered key needs a hyphen (or other rejected char), OFFER the
# documented one-line widening ([A-Z0-9]* -> [A-Z0-9-]*) at the moment it is needed.
if ! printf '%s' "$BOARD" | grep -qE '^[A-Z][A-Z0-9]*$'; then
  if printf '%s' "$BOARD" | grep -qE '^[A-Z][A-Z0-9-]*$'; then
    echo "  note: '$BOARD' contains a hyphen, which the default ticket grammar's board segment rejects." >&2
    w="$(ask "  Widen ticket-grammar.sh's board segment to allow hyphens ([A-Z0-9]* -> [A-Z0-9-]*)? (y/n)" "y")"
    case "$w" in y*|Y*) BOARD_WIDEN=1 ;; esac
  else
    echo "  warning: '$BOARD' has characters the grammar can't recognise even widened; tickets under it won't validate until you edit ticket-grammar.sh (see folder-structure.md)." >&2
  fi
fi
WORKSPACE_ROOT="$(ask "Workspace root (the estate path; used where a hook needs an absolute path)" "$TARGET")"
CHEAP_MODEL="$(ask "Model pin for the CHEAP agents (leave the placeholder to choose later)" "PICK-A-CHEAP-MODEL")"
SONNET_MODEL="$(ask "Model pin for the SONNET-CLASS agents (leave the placeholder to choose later)" "PICK-A-SONNET-CLASS-MODEL")"

# ---- PRODUCT laydown plan (create-absent-only, from the manifest) ----------------------------
# The manifest is TAB-delimited "CLASS<TAB>path"; take PRODUCT paths only. install.sh and setup.md
# are PRODUCT (the user-facing surface); the manifest classifies them so they are laid down too.
product_paths="$(awk -F'\t' '$1=="PRODUCT"{print $2}' "$MANIFEST")"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ -e "$TARGET/$rel" ]; then plan_exists+=("$rel"); else plan_create+=("$rel"); fi
done <<< "$product_paths"

# ---- ticket scaffolding plan (absent anatomy of existing hand-made tickets) ------------------
# The minimal legal anatomy a ticket needs: an AI-Knowledge/ dir with a valid empty _index.md,
# and the git-ignored Logs/ + Dump/ (kept by .gitkeep). We only CREATE absent pieces.
scaffold_targets=()
if [ -d "$TARGET/Tickets" ]; then
  for d in "$TARGET/Tickets"/*/; do
    [ -d "$d" ] || continue
    base="$(basename "$d")"
    [ "$base" = "README.md" ] && continue
    for miss in "AI-Knowledge/_index.md" "Logs/.gitkeep" "Dump/.gitkeep"; do
      [ -e "$d$miss" ] || scaffold_targets+=("Tickets/$base/$miss")
    done
  done
fi

NEED_GIT=0; git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 || NEED_GIT=1
HOOK_REL=".github/hooks/harness.json"
NEED_HOOK=0; [ -e "$TARGET/$HOOK_REL" ] || NEED_HOOK=1

# ---- print the plan (always; the whole plan for --dry-run) -----------------------------------
echo "=== install plan for estate: $TARGET ==="
echo "PRODUCT files to create: ${#plan_create[@]}   (already present: ${#plan_exists[@]})"
for p in "${plan_create[@]}"; do echo "  create   $p"; done
for s in "${scaffold_targets[@]}"; do echo "  scaffold $s"; done
[ "$NEED_HOOK" -eq 1 ] && echo "  create   $HOOK_REL   (hook config, copied from _harness/hooks/hooks.example.json)"
[ "$NEED_GIT" -eq 1 ] && echo "  git init + whitelist-scoped day-zero commit"
echo "  deploy agents; then run validator + status"
if [ "$DRY" -eq 1 ]; then
  echo "=== --dry-run: nothing was touched. ==="
  exit 0
fi

# ---- execute: create absent PRODUCT files (dumb creator — absent only) -----------------------
mkdir -p "$TARGET"   # real run only (dry-run already exited): now it is safe to create the estate dir
for rel in "${plan_create[@]}"; do
  mkdir -p "$(dirname "$TARGET/$rel")"
  cp -p "$SOURCE/$rel" "$TARGET/$rel"
  CREATED+=("$rel")
done
# ticket scaffolding — create absent anatomy only
for rel in "${scaffold_targets[@]}"; do
  mkdir -p "$(dirname "$TARGET/$rel")"
  case "$rel" in
    */_index.md) printf '%s\n%s\n' \
      '# _index.md — one line per file: `- <file>.md — <what it covers> — <when to read it>`' \
      '# Tombstones for promoted files: `- <file>.md (promoted -> General AI-Knowledge/<Topic>)`' > "$TARGET/$rel" ;;
    *) : > "$TARGET/$rel" ;;   # .gitkeep placeholders
  esac
  CREATED+=("$rel")
done

# ---- config applied AT LAYDOWN, to CREATED files ONLY (amendment C reconciles cond 2) --------
# We parameterise only files THIS run created. A pre-existing file is reported, never edited.
was_created() { local q="$1" c; for c in "${CREATED[@]}"; do [ "$c" = "$q" ] && return 0; done; return 1; }
# Board widening: edit the CREATED ticket-grammar.sh only.
if [ "$BOARD_WIDEN" -eq 1 ]; then
  if was_created "_harness/scripts/ticket-grammar.sh"; then
    # The documented one-line widening: board segment [A-Z0-9]* -> [A-Z0-9-]* (folder-structure.md).
    sed -i "s/\[A-Z\]\[A-Z0-9\]\*/[A-Z][A-Z0-9-]*/" "$TARGET/_harness/scripts/ticket-grammar.sh"
  else
    echo "note: ticket-grammar.sh already existed — NOT edited. To widen it yourself, change [A-Z0-9]* to [A-Z0-9-]* (see folder-structure.md)."
  fi
fi
# Model pins: replace placeholders in CREATED agent files only.
for rel in "${CREATED[@]}"; do
  case "$rel" in _agents/*.agent.md)
    [ "$CHEAP_MODEL" = "PICK-A-CHEAP-MODEL" ] || sed -i "s/PICK-A-CHEAP-MODEL/$CHEAP_MODEL/" "$TARGET/$rel"
    [ "$SONNET_MODEL" = "PICK-A-SONNET-CLASS-MODEL" ] || sed -i "s/PICK-A-SONNET-CLASS-MODEL/$SONNET_MODEL/" "$TARGET/$rel"
  ;; esac
done

# ---- hook config: COPY the single schema home (no second literal lives here) ------------------
if [ "$NEED_HOOK" -eq 1 ]; then
  mkdir -p "$TARGET/.github/hooks"
  # The verified #44 schema uses cwd "." (relative), so there is no workspace path to substitute;
  # we copy the shipped example verbatim. This is the ONLY schema source — install.sh carries none.
  cp -p "$SOURCE/_harness/hooks/hooks.example.json" "$TARGET/$HOOK_REL"
  CREATED+=("$HOOK_REL")
else
  echo "exists — $HOOK_REL present; to change it, edit that file (see setup.md). Left untouched."
fi

# ---- prerequisite path: git init (whitelist-scoped) + day-zero commit ------------------------
if [ "$NEED_GIT" -eq 1 ]; then
  git -C "$TARGET" init -q
  git -C "$TARGET" config core.autocrlf input     # #40: keep tracked scripts LF at the source
  git -C "$TARGET" add -A
  git -C "$TARGET" -c user.name="harness install" -c user.email="install@localhost" \
    commit -q -m "day-zero: harness estate scaffolded by install.sh" || true
else
  echo "exists — git repo present; left untouched (no re-commit)."
fi

# ---- deploy agents, then AUDIT with validator + status (agent-as-auditor flow, cond 3) --------
if [ ${#CREATED[@]} -gt 0 ] || [ "$NEED_GIT" -eq 1 ]; then
  bash "$TARGET/_harness/scripts/deploy_agents.sh" || echo "note: agent deploy reported an issue — see above (verify your Copilot agent dir)."
fi
echo "--- validator ---"; bash "$TARGET/_harness/scripts/check_ticket_log.sh" || echo "(validator surfaced issues above — fix on the record; the installer heals nothing)"
echo "--- status ---";    bash "$TARGET/_harness/scripts/harness-status.sh"   || echo "(status surfaced issues above — fix on the record)"

# ---- format-divergence nudge (amendment 2): surface, never enforce ---------------------------
# harness-status already WARNs hand-made / non-conforming ticket folders; we echo the pointer so
# a heavy divergence is noticed at install time. We NEVER rename or edit — the user decides.
echo "note: if status WARNed a ticket whose name diverges from the grammar, that ticket is surfaced"
echo "      but not validated. Rename it to conform, widen the grammar (see folder-structure.md),"
echo "      or mark it '.not-a-ticket'. The installer changes nothing here."

# ---- CLOSING SUMMARY = a record (amendment D) -----------------------------------------------
echo
echo "======================== INSTALL SUMMARY ========================"
echo "Estate: $TARGET"
echo "Created this run: ${#CREATED[@]} file(s); ${#plan_exists[@]} PRODUCT file(s) already existed (untouched)."
echo "Choices (asked or defaulted):"
echo "  board key         = $BOARD$( [ "$BOARD_WIDEN" -eq 1 ] && echo '  (grammar widened for hyphens)')"
echo "  workspace root    = $WORKSPACE_ROOT"
echo "  cheap model pin   = $CHEAP_MODEL"
echo "  sonnet model pin  = $SONNET_MODEL"
echo "Tunable knobs (not asked; defaults shown, each has ONE home = the named env var):"
echo "  HARNESS_GIT_WARN_MB       default 50   — .git housekeeping nudge threshold (harness-status.sh)"
echo "  HARNESS_TICKET_WARN_MB    default 5    — per-ticket tracked-root size WARN (harness-status.sh)"
echo "  HARNESS_COMMIT_LAG_WARN_S default 300  — commit-vs-session lag WARN (harness-status.sh)"
echo "  HARNESS_AGENT_DEPLOY_DIR  default ~/.copilot/agents — agent deploy target (deploy_agents.sh)"
echo "Declared residuals (honest): verifying the hook fires inside a live assistant session, and any"
echo "  platform whose agent directory differs (HARNESS_AGENT_DEPLOY_DIR override stands). Any model"
echo "  pin left as PICK-A-* must be set before the agents will run."
echo "================================================================="

# ---- AI-ASSISTANT FINAL GATE (amendment 2; OPERATOR-witnessed) -------------------------------
echo
echo "FINAL STEP — hand this estate to your AI assistant of choice as the last gate. Paste setup.md's"
echo "prompt (it references everything established above), then have the assistant: read the SUMMARY,"
echo "confirm validator + status are green, spot-check the scaffolded tickets, and nudge you to fix"
echo "anything red — on the record. That live validation is the final gate for local deployment."
