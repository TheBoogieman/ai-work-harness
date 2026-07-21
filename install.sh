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
#     TARGET_DIR the estate root to create/complete (default: current directory — but the estate
#                must be SEPARATE from the source checkout, so in practice pass a target dir)
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
# TARGET==SOURCE has TWO cases (#64). SOURCE is where THIS install.sh lives, so it is SOURCE both for a
# dev checkout AND for an ESTATE running its OWN shipped copy in place (cd ~/Work && ./install.sh):
#   - key present (harness.estate=true, the #60 estate marker) -> this IS an estate re-running itself ->
#     RECONFIGURE-ONLY MODE: review/guide config, create/repair NOTHING (there is no source in-estate).
#   - key absent -> a genuine source checkout run in place -> BLOCK with #62's concrete-fix message.
# Additive-only: only a keyed estate gains passage; keyless source-in-place and stripped no-key copies
# still block, and the remote guard below is unchanged. Pipe-free key test (the #60 guard's own shape).
RECONFIGURE=0
if [ "$TARGET" = "$SOURCE" ]; then
  if [ "$(git -C "$TARGET" config --local harness.estate 2>/dev/null)" = "true" ]; then
    RECONFIGURE=1
  else
    echo "install: TARGET is the source distribution itself — the estate must be a SEPARATE directory." >&2
    echo "  Pass one outside this checkout, e.g.:  bash install.sh $(dirname "$SOURCE")/Work" >&2
    exit 1
  fi
fi
# Estates are LOCAL-ONLY: refuse a target whose git repo already has a remote (the prompt path's rule).
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 && git -C "$TARGET" remote | grep -q .; then
  echo "install: TARGET already has a git REMOTE configured; estates must be local-only. Remove it first: git -C '$TARGET' remote remove <name>" >&2
  exit 1
fi
# The estate's own shipped install.sh has NO manifest (it is DEV, does not ship) and reconfigure-only
# never reads one — so require the manifest ONLY for the create path (#64).
[ "$RECONFIGURE" -eq 1 ] || [ -f "$MANIFEST" ] || { echo "install: cannot find $MANIFEST — run install.sh from the harness source distribution." >&2; exit 1; }

# ---- helpers --------------------------------------------------------------------------------
ask() {  # ask <prompt> <default> ; echoes the answer (default under --yes or on empty Enter)
  local prompt="$1" def="$2" ans=""
  if [ "$YES" -eq 1 ]; then printf '%s' "$def"; return; fi
  # The hint names the SAME $def the code returns on empty input — ONE variable, so the advertised
  # default can never drift from the real fallback (a guarded G4 claim, not decoration).
  printf '%s\n  [PRESS ENTER TO ACCEPT DEFAULT: %s]: ' "$prompt" "$def" >&2
  IFS= read -r ans || true
  [ -n "$ans" ] && printf '%s' "$ans" || printf '%s' "$def"
}
CREATED=()   # paths (relative to TARGET) this run actually created — the ONLY things config may touch
plan_create=(); plan_exists=()
NEED_GIT=0   # (#64) default: reconfigure-only skips the create block that computes this, so define it
             # here (an existing estate needs no init) for the deploy_agents gate below.
# Portable in-place sed: GNU sed wants `-i`, BSD/macOS sed wants `-i ''`. Detect via --version
# (GNU prints it, BSD errors). Project rule: no GNU-only flag without a BSD fallback.
sedi() { if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi; }
# detect_board <estate> — the board key ALREADY established in an estate, read from the estate's
# OWN tickets (its source of truth). Sets DETECTED_BOARD to a real (non-template) conforming
# ticket's board segment when one exists (DETECTED_BOARD_REAL=1), else to the template default
# PROJ (DETECTED_BOARD_REAL=0 — honest: no established ticket yet). The board is the segment
# between the date+sequence prefix and the trailing number, extracted so a widened hyphenated
# board (DATA-ENG) survives.
DETECTED_BOARD="PROJ"; DETECTED_BOARD_REAL=0
detect_board() {
  local root="$1" d base
  DETECTED_BOARD="PROJ"; DETECTED_BOARD_REAL=0
  for d in "$root"/Tickets/*/; do
    [ -d "$d" ] || continue
    base="$(basename "$d")"
    [ "$base" = "999912Z-PROJ-99999" ] && continue
    if printf '%s' "$base" | grep -qE '^[0-9]{6}[A-Z]+-[A-Z][A-Z0-9-]*-[0-9]+$'; then
      DETECTED_BOARD="$(printf '%s' "$base" | sed -E 's/^[^-]*-(.*)-[^-]*$/\1/')"; DETECTED_BOARD_REAL=1; return 0
    fi
  done
}
# detect_model <estate> <reference-agent> — the model pin already set on a reference agent's
# frontmatter (greppable `model: <x>`). Cheap tier reads doc-writer, sonnet tier reads ticket-init
# (fixed per the template's placeholder assignment). Echoes empty if the agent isn't present.
detect_model() {
  local f="$1/_agents/$2"
  [ -f "$f" ] && grep -m1 '^model:' "$f" | sed -E 's/^model:[[:space:]]*//'
}
# route_change <label> <established> <typed> <file-to-edit> — a re-run answer that DIFFERS from the
# established value is ROUTED, never applied: the installer edits NOTHING pre-existing (cond 2).
# It warns, names the exact file to edit, and offers the AI-assistant handoff (setup.md).
route_change() {
  echo "WARN: you asked to change the $1 from '$2' (established) to '$3'. Changing established config"
  echo "  can break the harness, so the installer changes NOTHING. To apply it, edit $4 yourself, or"
  echo "  hand it to your AI assistant (see setup.md): \"Change the $1 from $2 to $3 in $4, re-validate.\""
}
# NOTE on array expansion: stock-macOS bash 3.2 errors on "${arr[@]}" when arr is EMPTY under
# `set -u`, so every expansion below uses the "${arr[@]+"${arr[@]}"}" idiom — it yields the quoted
# elements when set (spaces in paths like "General AI-Knowledge/" preserved) and nothing when empty.

# ---- reconfigure-mode banner (#64): announce the mode UP FRONT, before the interview, so BOTH intents
# are visible immediately — reconfigure is served here; create/repair points back to the source checkout.
# Every line is true in-estate: there genuinely is no manifest/source here to create or repair from.
if [ "$RECONFIGURE" -eq 1 ]; then
  echo "Reconfigure mode — this is your estate's own installer. It can review and guide config changes"
  echo "(board key, model pins) but CANNOT create or repair files here (there is no source to copy from)."
  echo "To add or repair files, re-run install.sh from your harness source checkout, targeting this estate."
  echo
fi

# ---- identity interview (ask-everything + re-run REVIEW loop; #39 amendment A/C) --------------
# On a RE-RUN of an established estate, every DETECTABLE established value becomes the OFFERED
# default (ask()'s hint shows it), so a user can Enter-through to REVIEW or type to change. The
# installer still edits NOTHING pre-existing — a changed answer is ROUTED (route_change: warn +
# name the file + assistant handoff), never applied (amendment C / cond 2 absolute). A first run
# has no established values, so it falls back to today's defaults.
DEF_BOARD="PROJ"
BOARD_WIDEN=0
ESTABLISHED=0
[ -e "$TARGET/_harness/scripts/ticket-grammar.sh" ] && ESTABLISHED=1

# Board key: offered default is the established board on a re-run, else PROJ.
if [ "$ESTABLISHED" -eq 1 ]; then detect_board "$TARGET"; board_default="$DETECTED_BOARD"; else board_default="$DEF_BOARD"; fi
BOARD="$(ask "Ticket-naming board key (uppercase; single-segment)" "$board_default")"
if [ "$ESTABLISHED" -eq 1 ]; then
  # Established estate: a changed board is ROUTED to ticket-grammar.sh, never applied here.
  if [ "$BOARD" != "$board_default" ]; then
    route_change "board key" "$board_default" "$BOARD" "_harness/scripts/ticket-grammar.sh"
    BOARD="$board_default"
  fi
else
  # First run only: offer the documented hyphen widening escape hatch (amendment B). The default
  # grammar's board segment is [A-Z][A-Z0-9]* (no internal hyphen).
  if ! printf '%s' "$BOARD" | grep -qE '^[A-Z][A-Z0-9]*$'; then
    if printf '%s' "$BOARD" | grep -qE '^[A-Z][A-Z0-9-]*$'; then
      echo "  note: '$BOARD' contains a hyphen, which the default ticket grammar's board segment rejects." >&2
      w="$(ask "  Widen ticket-grammar.sh's board segment to allow hyphens ([A-Z0-9]* -> [A-Z0-9-]*)? (y/n)" "y")"
      case "$w" in y*|Y*) BOARD_WIDEN=1 ;; esac
    else
      echo "  warning: '$BOARD' has characters the grammar can't recognise even widened; tickets under it won't validate until you edit ticket-grammar.sh (see folder-structure.md)." >&2
    fi
  fi
fi

# Workspace root is NO LONGER ASKED (#39 v3): nothing consumes it post-#44 (hooks are cwd:"."), so
# a prompted value could only mislabel. The summary derives it from the real install TARGET instead.

# Model pins: offered defaults are the established pins on a re-run (cheap tier read from
# doc-writer, sonnet tier from ticket-init — the template's fixed placeholder assignment), else the
# PICK-A-* placeholders (honest "not yet set"). A changed pin on a re-run is ROUTED, never applied.
if [ "$ESTABLISHED" -eq 1 ]; then
  cheap_default="$(detect_model "$TARGET" doc-writer.agent.md)";  [ -n "$cheap_default" ]  || cheap_default="PICK-A-CHEAP-MODEL"
  sonnet_default="$(detect_model "$TARGET" ticket-init.agent.md)"; [ -n "$sonnet_default" ] || sonnet_default="PICK-A-SONNET-CLASS-MODEL"
else
  cheap_default="PICK-A-CHEAP-MODEL"; sonnet_default="PICK-A-SONNET-CLASS-MODEL"
fi
CHEAP_MODEL="$(ask "Model pin for the CHEAP agents (leave the placeholder to choose later)" "$cheap_default")"
SONNET_MODEL="$(ask "Model pin for the SONNET-CLASS agents (leave the placeholder to choose later)" "$sonnet_default")"
if [ "$ESTABLISHED" -eq 1 ]; then
  [ "$CHEAP_MODEL" = "$cheap_default" ]   || { route_change "cheap model pin" "$cheap_default" "$CHEAP_MODEL" "_agents/*.agent.md (cheap-tier agents)"; CHEAP_MODEL="$cheap_default"; }
  [ "$SONNET_MODEL" = "$sonnet_default" ] || { route_change "sonnet model pin" "$sonnet_default" "$SONNET_MODEL" "_agents/*.agent.md (sonnet-class agents)"; SONNET_MODEL="$sonnet_default"; }
fi

# ---- CREATE PATH (#64): laydown plan -> file-copy execute -> git init. SKIPPED WHOLESALE in
# reconfigure-only mode — every step reads the manifest or copies from $SOURCE, none of which exists
# in-estate. The body below is kept at its original indentation so the #64 change reads as a wrapper,
# not a reindent of ~100 lines; the matching `else`/`fi` is just above the estate-key arming.
if [ "$RECONFIGURE" -eq 0 ]; then

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
for p in ${plan_create[@]+"${plan_create[@]}"}; do echo "  create   $p"; done
for s in ${scaffold_targets[@]+"${scaffold_targets[@]}"}; do echo "  scaffold $s"; done
[ "$NEED_HOOK" -eq 1 ] && echo "  create   $HOOK_REL   (hook config, copied from _harness/hooks/hooks.example.json)"
[ "$NEED_GIT" -eq 1 ] && echo "  git init + whitelist-scoped day-zero commit"
echo "  deploy agents; then run validator + status"
if [ "$DRY" -eq 1 ]; then
  echo "=== --dry-run: nothing was touched. ==="
  exit 0
fi

# ---- execute: create absent PRODUCT files (dumb creator — absent only) -----------------------
mkdir -p "$TARGET"   # real run only (dry-run already exited): now it is safe to create the estate dir
for rel in ${plan_create[@]+"${plan_create[@]}"}; do
  mkdir -p "$(dirname "$TARGET/$rel")"
  cp -p "$SOURCE/$rel" "$TARGET/$rel"
  CREATED+=("$rel")
done
# ticket scaffolding — create absent anatomy only
for rel in ${scaffold_targets[@]+"${scaffold_targets[@]}"}; do
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
was_created() { local q="$1" c; for c in ${CREATED[@]+"${CREATED[@]}"}; do [ "$c" = "$q" ] && return 0; done; return 1; }
# Board widening: edit the CREATED ticket-grammar.sh only.
if [ "$BOARD_WIDEN" -eq 1 ]; then
  if was_created "_harness/scripts/ticket-grammar.sh"; then
    # The documented one-line widening: board segment [A-Z0-9]* -> [A-Z0-9-]* (folder-structure.md).
    sedi "s/\[A-Z\]\[A-Z0-9\]\*/[A-Z][A-Z0-9-]*/" "$TARGET/_harness/scripts/ticket-grammar.sh"
  else
    echo "note: ticket-grammar.sh already existed — NOT edited. To widen it yourself, change [A-Z0-9]* to [A-Z0-9-]* (see folder-structure.md)."
  fi
fi
# Model pins: replace placeholders in CREATED agent files only.
for rel in ${CREATED[@]+"${CREATED[@]}"}; do
  case "$rel" in _agents/*.agent.md)
    [ "$CHEAP_MODEL" = "PICK-A-CHEAP-MODEL" ] || sedi "s/PICK-A-CHEAP-MODEL/$CHEAP_MODEL/" "$TARGET/$rel"
    [ "$SONNET_MODEL" = "PICK-A-SONNET-CLASS-MODEL" ] || sedi "s/PICK-A-SONNET-CLASS-MODEL/$SONNET_MODEL/" "$TARGET/$rel"
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

else
  # ---- reconfigure-only (#64): the interview + route_change above WAS the whole job — no plan, no
  # laydown, no copy. Announce it, honour --dry-run, then fall through to the estate-local audit below.
  echo "=== reconfigure-only for estate: $TARGET — reviewing config; creating and repairing nothing ==="
  [ "$DRY" -eq 0 ] || { echo "=== --dry-run: nothing was touched. ==="; exit 0; }
fi

# ---- arm the auto-commit hooks: the estate-key that marks THIS repo as a genuine harness estate --
# The commit-bearing hooks (postToolUse/sessionEnd) refuse to commit unless .git/config carries
# harness.estate=true — a positive identity a nested foreign project repo cannot reach or forge (#60).
# Set it on EVERY install run and UNCONDITIONALLY — deliberately NOT inside the NEED_GIT init block
# above, which runs ONLY for a brand-new repo: an existing-repo re-install (arming an estate created
# before this version) passes through the `else` branch and must still be armed. git config is
# idempotent, so re-setting it every run is safe. install.sh already refused a remoted TARGET (top),
# so this key can only ever land on a local-only estate.
git -C "$TARGET" config harness.estate true

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
if [ "$RECONFIGURE" -eq 1 ]; then
  echo "Created this run: 0 file(s) — reconfigure-only mode (reviewed config; created and repaired nothing)."
else
  echo "Created this run: ${#CREATED[@]} file(s); ${#plan_exists[@]} PRODUCT file(s) already existed (untouched)."
fi
echo "Choices (asked or defaulted):"
if [ "$ESTABLISHED" -eq 1 ]; then
  if [ "$DETECTED_BOARD_REAL" -eq 1 ]; then
    echo "  board key         = $BOARD (established; to change it, edit ticket-grammar.sh — see setup.md). Left untouched."
  else
    echo "  board key         = $BOARD (template default; no established ticket yet)."
  fi
else
  echo "  board key         = $BOARD$( [ "$BOARD_WIDEN" -eq 1 ] && echo '  (grammar widened for hyphens)')"
fi
echo "  workspace root    = $TARGET   (derived from the install target — not asked)"
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
