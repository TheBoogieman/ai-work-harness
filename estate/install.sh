#!/usr/bin/env bash
# install.sh — scaffold or complete a harness Work ESTATE from this source distribution.
#
# It is a DUMB CREATOR (#39 cond 2): it creates only what is ABSENT and NEVER edits, appends to,
# or repairs any file that already exists — even a broken one. Surfacing and fixing broken state
# is the validator's/status's/agent's job, on the record; the installer judges nothing and heals
# nothing. A second run finds nothing absent, so it creates nothing: the plan reports "PRODUCT
# files to create: 0" and each prerequisite already in place says so and is left untouched.
#
# THAT LAW TAKES EXACTLY ONE EXCEPTION, and it is opt-in: `--upgrade` (#134). The law used to be
# stated here as ABSOLUTE and no longer is, because the word became false the day this mode
# landed. The bound and the three classes of file the exception is drawn over are stated at
# UPGRADE MODE below. Two things about it belong at the top of this file, because a reader
# meeting the word "dumb creator" has to know them straight away:
#   * WITHOUT `--upgrade` NOTHING BELOW CHANGES. Every default run still creates only what is
#     absent. The exception is reachable only by asking for it by name.
#   * THE EXCEPTION IS A MOVE, NEVER A DELETE. A superseded or replaced file is moved into a
#     quarantine folder inside the estate and REPORTED at the moment it happens with the command
#     that puts it back; a RECORD is never touched at all. Nothing this installer touches, in
#     either mode, ever stops existing.
#
# It is the SHIPPING BOUNDARY (#43 cond 2): it lays down PRODUCT files ONLY, DERIVED from the
# source tree by derive_product_paths below (#282). A fresh estate contains ZERO dev files.
#
# Runs FROM the source distribution (this file's directory), targeting an estate dir.
#   Usage: install.sh [--dry-run] [--yes] [--upgrade] [TARGET_DIR]
#     --dry-run  print the full plan and touch nothing
#     --yes      non-interactive: accept every suggested default
#     --upgrade  the ONE exception above: bring an EXISTING estate's machinery up to this
#                source's, retiring what this release supersedes. Records untouched, settings
#                carried forward, nothing deleted. Combine with --dry-run to see the plan first.
#     TARGET_DIR the estate root to create/complete (default: current directory — but the estate
#                must be SEPARATE from the source checkout, so in practice pass a target dir)
#
# SHAPE (#128): every step below is a FUNCTION that main() calls in order — roughly one function
# per thing the installer says out loud. The code inside each is the code that used to sit at the
# top level, MOVED rather than rewritten, which is what lets a run print exactly what it printed
# before. Two conventions keep that move faithful:
#   - the steps hand values to each other through GLOBAL variables (the moved code declares no
#     `local`), because that is precisely how the old top-level sequence passed them along;
#   - EXIT STATUS IS DELIBERATE (#261) — and this is a PROPERTY, not a checklist. NO FUNCTION IN
#     THIS FILE MAY HAND A BARE CALLER A STATUS IT DID NOT MEAN. "Bare" means a call that neither
#     tests the status nor guards it with `||`: a plain call under `set -e`, or an assignment from
#     a command substitution. It binds EVERY function here, not just the steps main() calls in
#     order — this convention was once written for the steps alone, and both defects this file has
#     actually had were HELPERS (detect_model, #200, which killed the run; detect_board, #233,
#     whose leaked status happened to measure zero), so the rule as written covered neither.
#     THE HAZARD is a tail whose status an UNSTATED BRANCH decided. A trailing non-zero that merely
#     CONTINUED at the top level (the tail of an `&&`/`||` list, say) becomes, once the same code
#     is a function, that function's RETURN value — which `set -e` treats as a reason to abort the
#     whole run, and which a command substitution turns into a fatal assignment.
#     THE MECHANISM, which is NOT the property: a function whose tail status would come from such
#     a branch ends with an explicit `return 0`, which says the zero rather than inheriting it.
#     Most functions here do. Three other shapes satisfy the property WITHOUT one and must not be
#     swept into it — the test is "did an unstated branch decide this status", never "is the word
#     `return` present":
#       * EMITTERS, whose tail IS the emission — detect_model, read_version, src_of, route_change.
#         The zero belongs to the emission itself; no branch chose it.
#       * DELIBERATE PROPAGATORS — sedi and was_created hand the caller the inner command's status
#         ON PURPOSE, which is the entire reason each exists.
#       * GUARDS THAT END IN `exit` — guard_target_is_source and guard_no_remote end in `exit 1`.
#         Those two are INSIDE this property, not an exception to it: `exit` hands no status to a
#         caller at all, it ends the run on purpose, and every non-exit path in both returns
#         explicitly. Stated out loud because the old wording ("each step ends with an explicit
#         `return 0`") was literally false of them, and an unstated exception is how the gap this
#         convention just closed got in.
#     WHAT THIS DOES NOT BUY, said plainly so nobody reads it as a general defence: it covers a
#     LEAKED status and nothing else. It is NO defence against a function that KILLS the run. Under
#     `set -euo pipefail` a bare failing command inside a function aborts AT that command, before
#     any tail statement runs, so the explicit `return 0` is never reached —
#     `f() { grep -q x /dev/null; return 0; }` called bare ends the script at the grep. That is a
#     different failure needing a different remedy, and this file does not claim to have one.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# THE INSTALLER NOW SHIPS FROM INSIDE THE ESTATE TREE (#136), so where this file sits is what
# says which of two things it is running as, and the two need different roots:
#   SOURCE DISTRIBUTION — <root>/estate/install.sh, with the development tree sitting beside the
#                         estate tree. SOURCE is <root>.
#   INSTALLED ESTATE    — <estate>/install.sh, laid down at the estate root with nothing above
#                         it. SOURCE is the estate itself, and the create path never runs.
# The DISCRIMINATOR is THE DEVELOPMENT TREE (#282): a source checkout has one sitting beside the
# estate tree, an installed estate never does — that was always the real fact, and the ship
# manifest that used to be tested here was only standing in for it. NOT the directory's NAME,
# which a user may rename the moment they clone.
if [ -d "$HERE/../dev" ]; then
  SOURCE="$(cd "$HERE/.." && pwd)"
else
  SOURCE="$HERE"
fi
ESTATE_SRC="$HERE"                              # the estate tree: what a laydown copies FROM
# INVOKE — how the caller ran this script, spelled relative to SOURCE, so the fix the refusal
# below prescribes is the command that actually works from where they are standing.
INVOKE="install.sh"
[ "$HERE" = "$SOURCE" ] || INVOKE="${HERE#"$SOURCE"/}/install.sh"

# ---- state the steps share --------------------------------------------------------------------
DRY=0; YES=0; TARGET=""
RECONFIGURE=0
# CREATED — paths (relative to TARGET) this run actually created; the ONLY things config may touch.
CREATED=()
plan_create=(); plan_exists=()
# NEED_GIT (#64) default: reconfigure-only skips the create block that computes this, so define it
# here (an existing estate needs no init) for the deploy_agents gate in audit_estate.
NEED_GIT=0
DETECTED_BOARD="PROJ"; DETECTED_BOARD_REAL=0
# ---- upgrade-mode state (#134). All of it is defined HERE, unconditionally, because three
# functions that run in EVERY mode read it — audit_estate's deploy gate and the two summary
# lines — and under `set -u` an unset array read is a fatal error rather than an empty answer.
UPGRADE=0
# QUARANTINE: one folder per run, UTC-stamped, at the estate root. Stamped so two upgrades never
# share a folder and a file retired today can never be overwritten by one retired tomorrow —
# overwriting would be a delete wearing a move's clothes. It sits at the estate root because that
# is where the estate's own whitelist leaves it UNTRACKED, which is a decided property: the
# report the run prints is then the only signal a retirement ever gives.
QUAR_REL="_retired/$(date -u +%Y%m%dT%H%M%SZ)"
QUAR_DEST=""
# The shipped retire list — versioned DATA, read from the source, never inferred from a disk.
RETIRE_LIST="$ESTATE_SRC/_harness/retire-list.tsv"
up_create=(); up_replace=(); up_retire=(); up_keep=()
up_same=0; up_record=0; UPGRADE_PARAM=""

# ---- args -------------------------------------------------------------------------------------
# parse_args — read the command line into DRY / YES / TARGET. An unknown option, or a second
# TARGET_DIR, is a usage error: say so on stderr and exit 2.
parse_args() {
  for a in "$@"; do
    case "$a" in
      --dry-run) DRY=1 ;;
      --yes)     YES=1 ;;
      --upgrade) UPGRADE=1 ;;
      -*)        echo "install: unknown option: $a" >&2; exit 2 ;;
      *)
        [ -z "$TARGET" ] || { echo "install: only one TARGET_DIR allowed" >&2; exit 2; }
        TARGET="$a" ;;
    esac
  done
  [ -n "$TARGET" ] || TARGET="$PWD"
  return 0
}

# resolve_target — resolve TARGET to an absolute path WITHOUT creating it: --dry-run must touch
# nothing, not even the target dir. A real run creates it in create_products below.
resolve_target() {
  if [ -d "$TARGET" ]; then
    TARGET="$(cd "$TARGET" && pwd)"
    return 0
  fi
  parent="$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd || true)"
  [ -n "$parent" ] || {
    echo "install: the parent of TARGET does not exist: $(dirname "$TARGET")" >&2
    exit 1
  }
  TARGET="$parent/$(basename "$TARGET")"
  return 0
}

# ---- safety -----------------------------------------------------------------------------------
# TARGET==SOURCE has TWO cases (#64). SOURCE is where THIS install.sh lives, so it is SOURCE both
# for a dev checkout AND for an ESTATE running its OWN shipped copy in place
# (cd ~/Work && ./install.sh):
#   - key present (harness.estate=true, the #60 estate marker) -> this IS an estate re-running
#     itself -> RECONFIGURE-ONLY MODE: review/guide config, create/repair NOTHING (there is no
#     source in-estate).
#   - key absent -> a genuine source checkout run in place -> BLOCK with #62's concrete-fix message.
# Additive-only: only a keyed estate gains passage; keyless source-in-place and stripped no-key
# copies still block, and the remote guard below is unchanged. Pipe-free key test (the #60 guard's
# own shape).
guard_target_is_source() {
  [ "$TARGET" = "$SOURCE" ] || return 0
  if [ "$(git -C "$TARGET" config --local harness.estate 2>/dev/null)" = "true" ]; then
    RECONFIGURE=1
    return 0
  fi
  echo "install: TARGET is the source distribution itself —" \
       "the estate must be a SEPARATE directory." >&2
  echo "  Pass one outside this checkout, e.g.:  bash $INVOKE $(dirname "$SOURCE")/Work" >&2
  exit 1
}

# guard_no_remote — estates are LOCAL-ONLY: refuse a target whose git repo already has a remote
# (the prompt path's rule).
guard_no_remote() {
  git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$TARGET" remote | grep -q . || return 0
  echo "install: TARGET already has a git REMOTE configured; estates must be local-only." \
       "Remove it first: git -C '$TARGET' remote remove <name>" >&2
  exit 1
}

# guard_upgrade_mode — --upgrade needs a SOURCE distribution to copy the new machinery FROM, and
# an estate re-running its own shipped installer has none: that absence is the whole of
# reconfigure-only mode. Refuse by name and print the command that works, rather than printing an
# upgrade plan of zero-everything and letting somebody believe their estate was upgraded when the
# run had nothing to upgrade it from. Runs AFTER guard_target_is_source, which is what sets
# RECONFIGURE.
guard_upgrade_mode() {
  [ "$UPGRADE" -eq 1 ] || return 0
  [ "$RECONFIGURE" -eq 1 ] || return 0
  echo "install: --upgrade cannot run from inside the estate — there is no source here to" \
       "upgrade from." >&2
  echo "  Run it from your harness SOURCE checkout, targeting this estate, e.g.:" >&2
  echo "    bash $INVOKE --upgrade $TARGET" >&2
  exit 1
}

# guard_source_tree — the create path copies FROM the source distribution's estate tree, and the
# estate's own shipped install.sh has no such tree beneath it (an estate IS the estate tree, with
# nothing above it). Reconfigure-only never copies anything, so require it ONLY for the create
# path (#64). This replaces the old manifest test (#282): the file is gone, and the thing the
# create path actually needs is the tree it reads, not a list describing it.
guard_source_tree() {
  [ "$RECONFIGURE" -eq 1 ] || [ -d "$SOURCE/estate" ] || {
    echo "install: cannot find $SOURCE/estate — run install.sh from the harness source" \
         "distribution." >&2
    exit 1
  }
  return 0
}

# ---- helpers ----------------------------------------------------------------------------------
ask() {  # ask <prompt> <default> ; echoes the answer (default under --yes or on empty Enter)
  local prompt="$1" def="$2" ans=""
  if [ "$YES" -eq 1 ]; then printf '%s' "$def"; return; fi
  # The hint names the SAME $def the code returns on empty input — ONE variable, so the advertised
  # default can never drift from the real fallback (a guarded G4 claim, not decoration).
  printf '%s\n  [PRESS ENTER TO ACCEPT DEFAULT: %s]: ' "$prompt" "$def" >&2
  IFS= read -r ans || true
  [ -n "$ans" ] && printf '%s' "$ans" || printf '%s' "$def"
  # WHAT: say this function's zero out loud instead of inheriting it from the list above.
  # WHY: the status of an `&&`/`||` list is whichever branch ran last, and here that measures zero
  # only because BOTH branches are the same command. That is an accident of the two matching, not
  # something ask() states. All four callers assign ask through a command substitution, so under
  # `set -euo pipefail` any later edit that gave one branch a non-zero tail would end the whole
  # install with no output at all — detect_model's defect (#200) for the third time in this file.
  # The explicit return makes the list's status stop being the return value, so that edit stays a
  # local mistake instead of a silent death. It changes nothing today: the status was already zero.
  return 0
}
# Portable in-place sed: GNU sed wants `-i`, BSD/macOS sed wants `-i ''`. Detect via --version
# (GNU prints it, BSD errors). Project rule: no GNU-only flag without a BSD fallback.
sedi() { if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi; }
# detect_board <estate> — the board key ALREADY established in an estate, read from the estate's
# OWN tickets (its source of truth). Sets DETECTED_BOARD to a real (non-template) conforming
# ticket's board segment when one exists (DETECTED_BOARD_REAL=1), else to the template default
# PROJ (DETECTED_BOARD_REAL=0 — honest: no established ticket yet). The board is the segment
# between the date+sequence prefix and the trailing number, extracted so a widened hyphenated
# board (DATA-ENG) survives.
detect_board() {
  local root="$1" d base
  DETECTED_BOARD="PROJ"; DETECTED_BOARD_REAL=0
  for d in "$root"/Tickets/*/; do
    [ -d "$d" ] || continue
    base="$(basename "$d")"
    [ "$base" = "999912Z-PROJ-99999" ] && continue
    if printf '%s' "$base" | grep -qE '^[0-9]{6}[A-Z]+-[A-Z][A-Z0-9-]*-[0-9]+$'; then
      DETECTED_BOARD="$(printf '%s' "$base" | sed -E 's/^[^-]*-(.*)-[^-]*$/\1/')"
      DETECTED_BOARD_REAL=1
      return 0
    fi
  done
  # Nothing conforming found: DETECTED_BOARD keeps the template default set above and
  # DETECTED_BOARD_REAL stays 0, which is how the caller tells a real board from a default. The
  # zero is now SAID rather than inherited from whichever branch the loop last took. This is a
  # helper, and the SHAPE note's convention at the top of this file now covers helpers too (#261)
  # for exactly the hazard met here: interview_board calls this bare under `set -e`, so a non-zero
  # tail would end the run with no output, as detect_model's once did.
  return 0
}
# detect_model <estate> <reference-agent> — the model pin already set on a reference agent's
# frontmatter (greppable `model: <x>`). Cheap tier reads doc-writer, sonnet tier reads ticket-init
# (fixed per the template's placeholder assignment). Echoes empty if the agent isn't present.
# A value this CANNOT FIND is MISSING, not an ERROR (#200). Both "no such agent file" and "that file
# carries no `model:` line" now echo nothing and return 0, leaving the caller to decide what a
# missing value means. Returning non-zero was the defect: the caller assigns this inside a command
# substitution, `set -euo pipefail` (top of file) treats that non-zero as fatal, and the installer
# died with ZERO OUTPUT on the line ABOVE its own placeholder fallback — which therefore never ran.
detect_model() {
  local f="$1/_agents/$2" line=""
  [ -f "$f" ] || return 0
  # `|| true` is load-bearing under `pipefail`: an agent file present but carrying no `model:` line
  # makes grep exit 1, and that status would otherwise become this function's fatal return exactly
  # as an absent file's did. Extraction is unchanged — the same sed on the same matched line.
  line="$(grep -m1 '^model:' "$f" || true)"
  [ -n "$line" ] || return 0
  printf '%s' "$line" | sed -E 's/^model:[[:space:]]*//'
}
# note_missing_pin <reference-agent> <placeholder> — say what could not be read and what was used
# instead (#200's goal condition: the installer never goes QUIET about a value it could not
# determine). On stderr, because that is where the interview already speaks — ask() reserves stdout
# for the answer it hands back through a command substitution.
note_missing_pin() {
  echo "note: no model pin readable from _agents/$1 — offering the placeholder $2 instead." >&2
  return 0
}
# read_version <root> — the harness version recorded at <root>, or the word "unknown" when no
# VERSION file is there. It READS the stamp; it never restates the number, so VERSION stays the one
# home of that fact and this script carries no version literal to drift from it. "unknown" is the
# honest answer for an estate laid down before the stamp existed — a number inferred from what the
# estate happens to contain would be a guess that a reader would take for a fact. Only the FIRST
# line is read (the stamp is one line) and a trailing carriage return is stripped, because a clone
# with core.autocrlf=true checks the file out CRLF and the version would otherwise carry a CR.
read_version() {
  local v=""
  [ -f "$1/VERSION" ] && { IFS= read -r v < "$1/VERSION" || true; }
  v="${v%$'\r'}"
  [ -n "$v" ] || v="unknown"
  printf '%s' "$v"
}
# route_change <label> <established> <typed> <file-to-edit> — a re-run answer that DIFFERS from the
# established value is ROUTED, never applied: the installer edits NOTHING pre-existing (cond 2).
# It warns, names the exact file to edit, and offers the AI-assistant handoff (setup.md).
route_change() {
  echo "WARN: you asked to change the $1 from '$2' (established) to '$3'." \
       "Changing established config"
  echo "  can break the harness, so the installer changes NOTHING." \
       "To apply it, edit $4 yourself, or"
  echo "  hand it to your AI assistant (see setup.md):" \
       "\"Change the $1 from $2 to $3 in $4, re-validate.\""
}
# NOTE on array expansion: stock-macOS bash 3.2 errors on "${arr[@]}" when arr is EMPTY under
# `set -u`, so every expansion below uses the "${arr[@]+"${arr[@]}"}" idiom — it yields the quoted
# elements when set (spaces in paths like "General AI-Knowledge/" preserved) and nothing when empty.

# ---- reconfigure-mode banner (#64): announce the mode UP FRONT, before the interview, so BOTH
# intents are visible immediately — reconfigure is served here; create/repair points back to the
# source checkout. Every line is true in-estate: there genuinely is no source tree here to
# create or repair from.
banner_reconfigure() {
  [ "$RECONFIGURE" -eq 1 ] || return 0
  echo "Reconfigure mode — this is your estate's own installer. It can review and guide" \
       "config changes"
  echo "(board key, model pins) but CANNOT create or repair files here (there is no source" \
       "to copy from)."
  echo "To add or repair files, re-run install.sh from your harness source checkout," \
       "targeting this estate."
  echo
  return 0
}

# ---- identity interview (ask-everything + re-run REVIEW loop; #39 amendment A/C) ---------------
# On a RE-RUN of an established estate, every DETECTABLE established value becomes the OFFERED
# default (ask()'s hint shows it), so a user can Enter-through to REVIEW or type to change. The
# installer still edits NOTHING pre-existing — a changed answer is ROUTED (route_change: warn +
# name the file + assistant handoff), never applied (amendment C / cond 2 absolute). A first run
# has no established values, so it falls back to today's defaults.
interview_board() {
  DEF_BOARD="PROJ"
  BOARD_WIDEN=0
  ESTABLISHED=0
  [ -e "$TARGET/_harness/scripts/ticket-grammar.sh" ] && ESTABLISHED=1
  # Board key: offered default is the established board on a re-run, else PROJ.
  if [ "$ESTABLISHED" -eq 1 ]; then
    detect_board "$TARGET"
    board_default="$DETECTED_BOARD"
  else
    board_default="$DEF_BOARD"
  fi
  BOARD="$(ask "Ticket-naming board key (uppercase; single-segment)" "$board_default")"
  # Established estate: a changed board is ROUTED to ticket-grammar.sh, never applied here.
  if [ "$ESTABLISHED" -eq 1 ]; then
    [ "$BOARD" = "$board_default" ] && return 0
    route_change "board key" "$board_default" "$BOARD" "_harness/scripts/ticket-grammar.sh"
    BOARD="$board_default"
    return 0
  fi
  offer_board_widening
  return 0
}

# offer_board_widening — FIRST RUN only: offer the documented hyphen widening escape hatch
# (amendment B). The default grammar's board segment is [A-Z][A-Z0-9]* (no internal hyphen), so a
# board that already conforms needs nothing; one the grammar could accept WIDENED gets the offer;
# one it could not recognise even widened gets a warning and no offer.
offer_board_widening() {
  if printf '%s' "$BOARD" | grep -qE '^[A-Z][A-Z0-9]*$'; then return 0; fi
  if ! printf '%s' "$BOARD" | grep -qE '^[A-Z][A-Z0-9-]*$'; then
    echo "  warning: '$BOARD' has characters the grammar can't recognise even widened;" \
         "tickets under it won't validate until you edit ticket-grammar.sh" \
         "(see folder-structure.md)." >&2
    return 0
  fi
  echo "  note: '$BOARD' contains a hyphen, which the default ticket grammar's board segment" \
       "rejects." >&2
  q="  Widen ticket-grammar.sh's board segment to allow hyphens"
  q="$q ([A-Z0-9]* -> [A-Z0-9-]*)? (y/n)"
  w="$(ask "$q" "y")"
  case "$w" in y*|Y*) BOARD_WIDEN=1 ;; esac
  return 0
}

# Workspace root is NO LONGER ASKED (#39 v3): nothing consumes it post-#44 (hooks are cwd:"."), so
# a prompted value could only mislabel. The summary derives it from the real install TARGET instead.
#
# interview_models — offered defaults are the established pins on a re-run (cheap tier read from
# doc-writer, sonnet tier from ticket-init — the template's fixed placeholder assignment), else the
# PICK-A-* placeholders (honest "not yet set"). A changed pin on a re-run is ROUTED, never applied.
interview_models() {
  if [ "$ESTABLISHED" -eq 1 ]; then
    # These two fallbacks are the ones #200 made unreachable: detect_model's non-zero return aborted
    # the run one line above each of them. They are reached now, and each says so out loud.
    cheap_default="$(detect_model "$TARGET" doc-writer.agent.md)"
    [ -n "$cheap_default" ] || {
      cheap_default="PICK-A-CHEAP-MODEL"
      note_missing_pin doc-writer.agent.md "$cheap_default"
    }
    sonnet_default="$(detect_model "$TARGET" ticket-init.agent.md)"
    [ -n "$sonnet_default" ] || {
      sonnet_default="PICK-A-SONNET-CLASS-MODEL"
      note_missing_pin ticket-init.agent.md "$sonnet_default"
    }
  else
    cheap_default="PICK-A-CHEAP-MODEL"; sonnet_default="PICK-A-SONNET-CLASS-MODEL"
  fi
  q="Model pin for the CHEAP agents (leave the placeholder to choose later)"
  CHEAP_MODEL="$(ask "$q" "$cheap_default")"
  q="Model pin for the SONNET-CLASS agents (leave the placeholder to choose later)"
  SONNET_MODEL="$(ask "$q" "$sonnet_default")"
  [ "$ESTABLISHED" -eq 1 ] || return 0
  [ "$CHEAP_MODEL" = "$cheap_default" ] || {
    route_change "cheap model pin" "$cheap_default" "$CHEAP_MODEL" \
      "_agents/*.agent.md (cheap-tier agents)"
    CHEAP_MODEL="$cheap_default"
  }
  [ "$SONNET_MODEL" = "$sonnet_default" ] || {
    route_change "sonnet model pin" "$sonnet_default" "$SONNET_MODEL" \
      "_agents/*.agent.md (sonnet-class agents)"
    SONNET_MODEL="$sonnet_default"
  }
  return 0
}

# ---- the shipped set, DERIVED from the tree (#282) ---------------------------------------------
# THE RULE, and it is the whole of it: everything under the estate tree, plus the five files an
# external system requires at the REPOSITORY ROOT — the two the code host renders (README.md,
# LICENSE), the two git itself applies (.gitignore, .gitattributes), and the one an AI assistant
# auto-loads (AGENTS.md). Those five are not a convenience list and must not be folded into the
# estate tree to tidy the rule: moving any of them breaks the host, git, or the assistant.
#
# DERIVED FROM THE GIT INDEX, NEVER FROM A DIRECTORY WALK. A walk would sweep up whatever happens
# to be sitting untracked in a developer's checkout — a scratch ticket, a stray note — and lay it
# down in a user's estate. `git ls-files` answers "what does this distribution consist of", which
# is the question being asked. It replaces dev/ship-manifest.txt, a hand-maintained list of 142
# rows that could drift from the tree it claimed to describe; the rule cannot.
derive_product_paths() {
  git -C "$SOURCE" ls-files | while IFS= read -r dp_p; do
    case "$dp_p" in
      estate/*|README.md|AGENTS.md|LICENSE|.gitignore|.gitattributes) printf '%s\n' "$dp_p" ;;
    esac
  done
}

# ---- PRODUCT laydown plan (create-absent-only, from the derivation) ----------------------------
# install.sh and setup.md are PRODUCT (the user-facing surface); they live under the estate tree,
# so the rule above picks them up with everything else and they are laid down too.
plan_product() {
  product_paths="$(derive_product_paths)"
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    # THE STRIP IS A TREE RELATIONSHIP, not a text edit: what is wanted is the row's path
    # RELATIVE TO THE ESTATE ROOT, and in the source distribution the estate root is the estate
    # tree. Anchored to the front (${row#estate/}) so a path that merely CONTAINS the word
    # further down is untouched. A root-pinned PRODUCT file carries no prefix and passes through.
    rel="${row#estate/}"
    if [ -e "$TARGET/$rel" ]; then plan_exists+=("$rel"); else plan_create+=("$rel"); fi
  done <<< "$product_paths"
  return 0
}

# src_of — where an estate-relative path is READ FROM in the source distribution. A PRODUCT file
# lives in one of exactly two places: inside the estate tree (nearly all of them), or root-pinned
# at the repository root because an external system requires that location (the front page, the
# licence, the root rule file and the two git control files). The estate tree is tried first.
src_of() {
  [ -e "$ESTATE_SRC/$1" ] && { printf '%s' "$ESTATE_SRC/$1"; return 0; }
  printf '%s' "$SOURCE/$1"
}

# ---- ticket scaffolding plan (absent anatomy of existing hand-made tickets) --------------------
# The minimal legal anatomy a ticket needs: an AI-Knowledge/ dir with a valid empty _index.md,
# and the git-ignored Logs/ + Dump/ (kept by .gitkeep). We only CREATE absent pieces.
plan_scaffold() {
  scaffold_targets=()
  [ -d "$TARGET/Tickets" ] || return 0
  for d in "$TARGET/Tickets"/*/; do
    [ -d "$d" ] || continue
    base="$(basename "$d")"
    [ "$base" = "README.md" ] && continue
    for miss in "AI-Knowledge/_index.md" "Logs/.gitkeep" "Dump/.gitkeep"; do
      [ -e "$d$miss" ] || scaffold_targets+=("Tickets/$base/$miss")
    done
  done
  return 0
}

# plan_prereqs — the two non-file prerequisites: a git record repo, and the hook config.
plan_prereqs() {
  NEED_GIT=0; git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 || NEED_GIT=1
  HOOK_REL=".github/hooks/harness.json"
  NEED_HOOK=0; [ -e "$TARGET/$HOOK_REL" ] || NEED_HOOK=1
  return 0
}

# ---- print the plan (always; the whole plan for --dry-run) -------------------------------------
print_plan() {
  echo "=== install plan for estate: $TARGET ==="
  echo "PRODUCT files to create: ${#plan_create[@]}   (already present: ${#plan_exists[@]})"
  for p in ${plan_create[@]+"${plan_create[@]}"}; do echo "  create   $p"; done
  for s in ${scaffold_targets[@]+"${scaffold_targets[@]}"}; do echo "  scaffold $s"; done
  [ "$NEED_HOOK" -eq 1 ] \
    && echo "  create   $HOOK_REL   (hook config, copied from _harness/hooks/hooks.example.json)"
  [ "$NEED_GIT" -eq 1 ] && echo "  git init + whitelist-scoped day-zero commit"
  echo "  deploy agents; then run validator + status"
  if [ "$DRY" -eq 1 ]; then
    echo "=== --dry-run: nothing was touched. ==="
    exit 0
  fi
  return 0
}

# ---- execute: create absent PRODUCT files (dumb creator — absent only) -------------------------
create_products() {
  # Real run only (print_plan already exited for --dry-run): only now is it safe to create the
  # estate dir itself.
  mkdir -p "$TARGET"
  for rel in ${plan_create[@]+"${plan_create[@]}"}; do
    mkdir -p "$(dirname "$TARGET/$rel")"
    cp -p "$(src_of "$rel")" "$TARGET/$rel"
    CREATED+=("$rel")
  done
  return 0
}

# create_scaffold — ticket scaffolding: create absent anatomy only.
create_scaffold() {
  for rel in ${scaffold_targets[@]+"${scaffold_targets[@]}"}; do
    mkdir -p "$(dirname "$TARGET/$rel")"
    case "$rel" in
    */_index.md)
      printf '%s\n%s\n' \
      '# _index.md — one line per file: `- <file>.md — <what it covers> — <when to read it>`' \
      '# Tombstones for promoted files: `- <file>.md (promoted -> General AI-Knowledge/<Topic>)`' \
      > "$TARGET/$rel" ;;
    *) : > "$TARGET/$rel" ;;   # .gitkeep placeholders
    esac
    CREATED+=("$rel")
  done
  return 0
}

# ---- config applied AT LAYDOWN, to CREATED files ONLY (amendment C reconciles cond 2) ----------
# We parameterise only files THIS run created. A pre-existing file is reported, never edited.
# created_this_run — the membership scan behind was_created(): is <path> in CREATED?
created_this_run() {
  local c
  for c in ${CREATED[@]+"${CREATED[@]}"}; do
    [ "$c" = "$1" ] && return 0
  done
  return 1
}
# was_created <path> — did THIS run create <path>? Deliberately a ONE-LINE definition: the code-
# shape census pins its shape, and the scan itself will not fit a one-liner inside the line-length
# limit, so the scan lives in created_this_run above and this stays the name the callers read.
was_created() { created_this_run "$1"; }

# apply_board_widen — board widening: edit the CREATED ticket-grammar.sh only.
apply_board_widen() {
  [ "$BOARD_WIDEN" -eq 1 ] || return 0
  if was_created "_harness/scripts/ticket-grammar.sh"; then
    # The documented one-line widening: board segment [A-Z0-9]* -> [A-Z0-9-]* (folder-structure.md).
    sedi "s/\[A-Z\]\[A-Z0-9\]\*/[A-Z][A-Z0-9-]*/" "$TARGET/_harness/scripts/ticket-grammar.sh"
    return 0
  fi
  echo "note: ticket-grammar.sh already existed — NOT edited. To widen it yourself, change" \
       "[A-Z0-9]* to [A-Z0-9-]* (see folder-structure.md)."
  return 0
}

# apply_model_pins — model pins: replace placeholders in CREATED agent files only.
apply_model_pins() {
  for rel in ${CREATED[@]+"${CREATED[@]}"}; do
    case "$rel" in _agents/*.agent.md)
      [ "$CHEAP_MODEL" = "PICK-A-CHEAP-MODEL" ] \
        || sedi "s/PICK-A-CHEAP-MODEL/$CHEAP_MODEL/" "$TARGET/$rel"
      [ "$SONNET_MODEL" = "PICK-A-SONNET-CLASS-MODEL" ] \
        || sedi "s/PICK-A-SONNET-CLASS-MODEL/$SONNET_MODEL/" "$TARGET/$rel"
    ;; esac
  done
  return 0
}

# ---- hook config: COPY the single schema home (no second literal lives here) --------------------
create_hook_config() {
  if [ "$NEED_HOOK" -eq 0 ]; then
    echo "exists — $HOOK_REL present; to change it, edit that file (see setup.md). Left untouched."
    return 0
  fi
  mkdir -p "$TARGET/.github/hooks"
  # The verified #44 schema uses cwd "." (relative), so there is no workspace path to substitute;
  # we copy the shipped example verbatim. This is the ONLY schema source — install.sh carries none.
  cp -p "$(src_of "_harness/hooks/hooks.example.json")" "$TARGET/$HOOK_REL"
  CREATED+=("$HOOK_REL")
  return 0
}

# ---- prerequisite path: git init (whitelist-scoped) + day-zero commit --------------------------
init_git_record() {
  if [ "$NEED_GIT" -eq 0 ]; then
    echo "exists — git repo present; left untouched (no re-commit)."
    return 0
  fi
  git -C "$TARGET" init -q
  git -C "$TARGET" config core.autocrlf input     # #40: keep tracked scripts LF at the source
  git -C "$TARGET" add -A
  git -C "$TARGET" -c user.name="harness install" -c user.email="install@localhost" \
    commit -q -m "day-zero: harness estate scaffolded by install.sh" || true
  return 0
}

# ---- CREATE PATH (#64): laydown plan -> file-copy execute -> git init. SKIPPED WHOLESALE in
# reconfigure-only mode — every step below derives the shipped set or copies from $SOURCE, and
# neither exists in-estate. The order of these calls IS the order the old top-level block ran in.
create_path() {
  plan_product
  plan_scaffold
  plan_prereqs
  print_plan
  create_products
  create_scaffold
  apply_board_widen
  apply_model_pins
  create_hook_config
  init_git_record
  return 0
}

# ---- reconfigure-only (#64): the interview + route_change above WAS the whole job — no plan, no
# laydown, no copy. Announce it, honour --dry-run, then fall through to the estate-local audit.
reconfigure_only() {
  echo "=== reconfigure-only for estate: $TARGET —" \
       "reviewing config; creating and repairing nothing ==="
  [ "$DRY" -eq 0 ] || { echo "=== --dry-run: nothing was touched. ==="; exit 0; }
  return 0
}

# ================================================================================================
# ---- UPGRADE MODE (#134) — the dumb-creator law's one exception --------------------------------
# ================================================================================================
# THREE VERBS, and nothing else happens to an estate:
#   CREATE   an absent shipped file is copied in, exactly as the create path does.
#   REPLACE  a present PLAIN-MACHINERY file whose bytes differ from this source's is MOVED to
#            quarantine and this source's copy laid down in its place. The move is what keeps the
#            promise that nothing stops existing: a user who hand-edited a script gets their
#            version back from quarantine with the command printed in the run.
#   RETIRE   a path the shipped retire list names as superseded is MOVED to quarantine, with NO
#            replacement laid down at that path — that is how a rename stops leaving an estate
#            holding both names.
# Anything that is neither — a record, or a file carrying the user's own settings — is KEPT and
# said out loud. There is no fourth verb, and in particular there is no delete.

# upgrade_paths — the estate-relative shipped paths, from the SAME derivation the create path uses
# (#282), so the two can never disagree about what ships. The `estate/` prefix is a fact about the
# source tree, not about an installed estate, so it is stripped exactly as plan_product strips it.
upgrade_paths() {
  derive_product_paths | sed 's|^estate/||'
  return 0
}

# upgrade_is_machinery <estate-relative path> — MACHINERY (classes 2 and 3, replaceable) or RECORD
# (class 1, never touched)? STRUCTURAL, with no list of record folders to keep in step: a shipped
# path is machinery when it is ROOT-PINNED (no directory component — the estate's own documents,
# its installer, its version stamp, its git control files) or when it sits under one of the TWO
# trees this installer lays the harness machinery down into. Everything else is a record.
# THE FAIL-SAFE DIRECTION IS "LEAVE IT ALONE": an unrecognised folder reads as a record, so a
# record folder invented after this was written is protected without anyone editing this function.
upgrade_is_machinery() {
  case "$1" in
    _harness/*|_agents/*) return 0 ;;
    */*)                  return 1 ;;
    *)                    return 0 ;;
  esac
}

# ---- CLASS 3 (parameterised machinery), DERIVED FROM THIS INSTALLER'S OWN STRUCTURE ------------
# NO CURATED LIST IS ALLOWED HERE, and the reason is the same one that removed the ship
# manifest: a list kept beside the installer drifts from it silently, and the drift is
# invisible exactly when it matters — at an upgrade. So the set is GENERATED, as a union of
# two halves, from the PARSED function bodies of
# this file (`declare -f`, which strips comments — so no comment and no closing-summary line can
# inject a member):
#   SUBSTITUTED  a body that runs this installer's one in-place substitution verb, `sedi`. The
#                file it edits carries a value the user chose, by construction.
#   DECLINED     a body that BOTH tests whether it created a file (`was_created`, or a NEED_*
#                flag) AND creates that file — its other arm is the declined-edit handler. The
#                "and creates" half is load-bearing rather than decoration: print_plan tests
#                NEED_HOOK too and merely NAMES the path, and that is precisely the false member
#                020 warns no path filter can catch.
# THE CANARY 020 ASKS FOR COMES FREE. It says a version stamp should have no declined-edit
# handler, and that writing one is the moment the stamp became user-owned. Write one and this
# query returns VERSION on the very next run, with nobody assigned to remember.
# WHAT IT DOES NOT DO, said plainly: the OWNERSHIP test — 020's boundary between classes 2 and 3 —
# is a human judgement and is NOT mechanised here. This returns CANDIDATES. Today every candidate
# is user-owned, so the candidate set and class 3 coincide; a future installer-owned candidate
# has to be ruled on by a person, and the generated list is what puts it in front of them.
upgrade_param_globs() {
  local fn body
  while read -r _ _ fn; do
    # The generator does not read ITSELF. These three functions carry the query's own patterns as
    # string literals, so a body quoting `sedi` would report itself as a substitution site.
    case "$fn" in upgrade_param_*) continue ;; esac
    body="$(declare -f "$fn")"
    upgrade_param_substituted "$body"
    upgrade_param_declined "$body"
  done < <(declare -F)
  return 0
}

# upgrade_param_substituted <function body> — half one. A `sedi` call's last argument is the file
# it edits, spelled "$TARGET/<path>". When the substitution loops over what the run created, that
# argument is "$TARGET/$rel" and the real subject is the CASE PATTERN guarding the loop body — so
# a literal `$rel` is resolved to that pattern rather than reported as a path.
upgrade_param_substituted() {
  local t
  printf '%s\n' "$1" | grep -q 'sedi ' || return 0
  while IFS= read -r t; do
    if [ "$t" = '$rel' ]; then
      printf '%s\n' "$1" | sed -nE 's/^[[:space:]]+([^ (]+)\)$/\1/p'
    else
      printf '%s\n' "$t"
    fi
  done < <(printf '%s\n' "$1" | grep 'sedi ' | grep -oE '\$TARGET/[^"]+' | sed 's|^\$TARGET/||')
  return 0
}

# upgrade_param_declined <function body> — half two. A body qualifies only if it BOTH carries a
# creation test AND creates a laid-down file; the path it creates is the subject. A `$VAR` operand
# is expanded, because the member this half exists for — the hook configuration, which 020 calls
# the worst one to get wrong, since it governs whether the estate commits by itself — is spelled
# "$TARGET/$HOOK_REL" and would otherwise be reported as the literal text of a variable name.
upgrade_param_declined() {
  local p v
  printf '%s\n' "$1" | grep -qE 'was_created "|\[ "\$NEED_[A-Z]+"' || return 0
  while IFS= read -r p; do
    case "$p" in '$'*) v="${p#\$}"; p="${!v:-}" ;; esac
    [ -n "$p" ] && printf '%s\n' "$p"
  done < <(printf '%s\n' "$1" | grep -E '(^|[[:space:]])cp[[:space:]]|>[[:space:]]*"\$TARGET/' \
    | grep -oE '"\$TARGET/[^"]+"' | sed -E 's|^"\$TARGET/||; s|"$||')
  return 0
}

# upgrade_param_set — run the generator ONCE per run into UPGRADE_PARAM. Once, because the plan
# and the execute step have to be reading the same answer: a set computed twice could differ
# between what the user was shown and what was done to their estate.
upgrade_param_set() {
  UPGRADE_PARAM="$(upgrade_param_globs | LC_ALL=C sort -u | grep -v '^$' || true)"
  return 0
}

# upgrade_is_param <estate-relative path> — is this path class 3? The stored entries are GLOBS
# (the agent files are one pattern, not ten paths), so the test is a glob match, not equality.
upgrade_is_param() {
  local g
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    # shellcheck disable=SC2254  # the unquoted $g is the point: these entries ARE glob patterns.
    case "$1" in $g) return 0 ;; esac
  done <<< "$UPGRADE_PARAM"
  return 1
}

# upgrade_retire_rows — the shipped retire list, one row per superseded path. Its format, why it
# is data rather than inference, and why it is CUMULATIVE (which is what makes an upgrade that
# skips versions retire everything across the whole span) are documented in the file itself; that
# is its one home and none of it is restated here. Carriage returns are stripped so a checkout
# made with core.autocrlf=true parses identically to one made with `input`.
upgrade_retire_rows() {
  [ -f "$RETIRE_LIST" ] || return 0
  tr -d '\r' < "$RETIRE_LIST" | awk -F'\t' '/^#/ || NF < 2 { next } { print }'
  return 0
}

# ---- the plan: classify EVERYTHING before touching ANYTHING -------------------------------------
# plan_upgrade — decide, for every shipped path and every retired path, which of the four things
# happens. It moves nothing: the whole point of a separate planning step is that the plan can be
# printed in full, and --dry-run can exit, before the first file has been touched.
plan_upgrade() {
  up_create=(); up_replace=(); up_retire=(); up_keep=()
  up_same=0; up_record=0
  upgrade_param_set
  plan_upgrade_products
  plan_upgrade_retirements
  return 0
}

# plan_upgrade_products — the shipped set, in the order the tests have to be applied: absent wins
# over everything (it is a create, not a decision about an existing file); then the user's own
# settings, which are carried forward whatever else is true of the path; then records; and only
# then a byte comparison, so an estate already current is reported as such instead of being
# rewritten with identical bytes it does not need.
plan_upgrade_products() {
  local rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if [ ! -e "$TARGET/$rel" ];        then up_create+=("$rel"); continue; fi
    if upgrade_is_param "$rel";        then up_keep+=("$rel"); continue; fi
    if ! upgrade_is_machinery "$rel";  then up_record=$((up_record + 1)); continue; fi
    if cmp -s "$(src_of "$rel")" "$TARGET/$rel"; then up_same=$((up_same + 1)); continue; fi
    up_replace+=("$rel")
  done < <(upgrade_paths)
  # The hook configuration is LAID DOWN but is not a shipped path — it is copied from the shipped
  # example under a different name — so the loop above never sees it. It is class 3 and it is the
  # member 020 singles out, so it is named in the plan by itself rather than going unmentioned.
  upgrade_is_param "$HOOK_REL" && [ -e "$TARGET/$HOOK_REL" ] && up_keep+=("$HOOK_REL")
  return 0
}

# plan_upgrade_retirements — the retire list, filtered to what this estate ACTUALLY HOLDS. A path
# the estate never had, or already retired on an earlier run, is simply absent and is skipped:
# that is what makes a second run a no-op and what stops a fresh estate failing on a list of files
# it was never old enough to own. A row naming a RECORD is REFUSED OUT LOUD rather than silently
# dropped — class 1 is never touched, retirement included, and a retire list that has drifted into
# naming a record is a defect the user should hear about.
plan_upgrade_retirements() {
  local row rel
  while IFS= read -r row; do
    rel="$(printf '%s' "$row" | cut -f2)"
    [ -n "$rel" ] || continue
    [ -e "$TARGET/$rel" ] || continue
    if upgrade_is_machinery "$rel"; then up_retire+=("$row"); continue; fi
    echo "REFUSED: the retire list names '$rel', which is a RECORD path. Records are never" \
         "touched, retirement included — leaving it exactly where it is."
  done < <(upgrade_retire_rows)
  return 0
}

# ---- print the plan: every create, replace and retire, BEFORE anything happens -----------------
print_upgrade_plan() {
  echo "=== upgrade plan for estate: $TARGET ==="
  echo "  version $(read_version "$TARGET")  ->  $(read_version "$ESTATE_SRC")" \
       "  (this source's stamp)"
  print_upgrade_rows
  print_upgrade_keeps
  echo "  untouched: $up_record record file(s); $up_same machinery file(s) already current"
  print_upgrade_quarantine_line
  if [ "$DRY" -eq 1 ]; then
    echo "=== --dry-run: nothing was touched. ==="
    exit 0
  fi
  return 0
}

# print_upgrade_rows — the three mutating verbs, one line each, named individually. These are the
# lines a person reads before deciding to let the run proceed, so none of them is ever collapsed
# into a count.
print_upgrade_rows() {
  local p row
  for p in ${up_create[@]+"${up_create[@]}"}; do echo "  create   $p"; done
  for p in ${up_replace[@]+"${up_replace[@]}"}; do
    echo "  replace  $p   (your copy is moved to quarantine first)"
  done
  for row in ${up_retire[@]+"${up_retire[@]}"}; do
    echo "  retire   $(printf '%s' "$row" | cut -f2)   (superseded at" \
         "$(printf '%s' "$row" | cut -f1): $(printf '%s' "$row" | cut -f3))"
  done
  return 0
}

# upgrade_moves — how many files this run will move (replace + retire). The no-op case is the
# whole reason it exists: a run with nothing to move must not name a quarantine folder it is
# never going to create, and must not tell the user their files are in one.
upgrade_moves() {
  printf '%s' "$(( ${#up_replace[@]} + ${#up_retire[@]} ))"
}

# print_upgrade_quarantine_line — name the quarantine folder only when something is actually going
# into it. A SECOND RUN SAYS SO IN SO MANY WORDS: "safe to run twice" is a claim the run itself
# has to make, not something a reader should have to infer from three zeros.
print_upgrade_quarantine_line() {
  if [ "${#up_create[@]}" -eq 0 ] && [ "$(upgrade_moves)" -eq 0 ]; then
    echo "  NOTHING TO DO — this estate's machinery already matches this source. Safe to re-run:"
    echo "    no file will be created, replaced or retired, and no quarantine folder is made."
    return 0
  fi
  echo "  quarantine for this run: $QUAR_REL"
  echo "    — untracked by design, so the RESTORE lines this run prints are your only signal"
  return 0
}

# print_upgrade_keeps — the files carrying the user's own settings, listed by name rather than
# counted. A count would be the wrong shape here: the whole hazard this class exists to prevent is
# somebody's hook configuration or board pattern being reset without them noticing, and "3 files
# kept" is not something a reader can check against what they configured.
print_upgrade_keeps() {
  local p
  echo "  keep     ${#up_keep[@]} file(s) carrying YOUR settings — derived, not listed by hand:"
  for p in ${up_keep[@]+"${up_keep[@]}"}; do echo "             $p"; done
  return 0
}

# ---- execute: the only two operations that ever remove a file from where the user left it ------
# quarantine_move <estate-relative path> — MOVE the file into this run's quarantine folder. Sets
# QUAR_DEST so the report below can name the exact restore command. This function and the copy
# that follows it are deliberately adjacent with nothing printed between them: the window in which
# a replaced path is momentarily absent is two system calls wide, and the report comes after.
quarantine_move() {
  QUAR_DEST="$TARGET/$QUAR_REL/$1"
  mkdir -p "$(dirname "$QUAR_DEST")"
  mv "$TARGET/$1" "$QUAR_DEST"
  return 0
}

# quarantine_report <verb> <path> <why> — SAID AT THE MOMENT THE MOVE HAPPENED, not collected for
# the summary. The quarantine folder is untracked, so this is the only signal a retirement gives:
# a user who disagrees has to be able to reverse it from what they read here, which is why the
# restore command is a literal command rather than a description of one.
quarantine_report() {
  echo "$1 $2"
  echo "    your copy is kept at: $QUAR_REL/$2   ($3)"
  echo "    RESTORE IT WITH:      mv \"$QUAR_DEST\" \"$TARGET/$2\""
  return 0
}

# upgrade_execute — the mutations, in an order that is the INTERRUPTION story rather than a
# preference. Everything that ADDS runs before anything that REMOVES, so a run killed halfway
# leaves an estate holding BOTH names rather than neither, and re-running from there creates
# whatever is absent and retires whatever is still there. Nothing is lost in either case, because
# every file this loop removes from its place is sitting in the quarantine folder.
upgrade_execute() {
  local rel row
  for rel in ${up_create[@]+"${up_create[@]}"}; do
    mkdir -p "$(dirname "$TARGET/$rel")"
    cp -p "$(src_of "$rel")" "$TARGET/$rel"
    CREATED+=("$rel")
    echo "CREATED  $rel"
  done
  for rel in ${up_replace[@]+"${up_replace[@]}"}; do
    quarantine_move "$rel"
    cp -p "$(src_of "$rel")" "$TARGET/$rel"
    quarantine_report "REPLACED" "$rel" "your copy, superseded by this release's"
  done
  for row in ${up_retire[@]+"${up_retire[@]}"}; do
    rel="$(printf '%s' "$row" | cut -f2)"
    quarantine_move "$rel"
    quarantine_report "RETIRED " "$rel" "superseded at $(printf '%s' "$row" | cut -f1)"
  done
  return 0
}

# ---- UPGRADE PATH: plan -> show -> execute. It deliberately does NOT scaffold ticket anatomy;
# that is the complete-or-repair run's job and it writes inside Tickets/, which is where an
# upgrade has no business being. Model pins still run, because an agent file this run CREATED is
# absent-not-present and must come out carrying the estate's established pins rather than the
# shipped placeholders. create_hook_config and init_git_record are called for their EXISTING-file
# arms: on an established estate each says out loud that it left the thing alone.
upgrade_path() {
  plan_prereqs
  plan_upgrade
  print_upgrade_plan
  mkdir -p "$TARGET"
  upgrade_execute
  apply_board_widen
  apply_model_pins
  create_hook_config
  init_git_record
  return 0
}

# ---- arm the auto-commit hooks: the estate-key that marks THIS repo as a genuine harness estate -
# The commit-bearing hooks (postToolUse/sessionEnd) refuse to commit unless .git/config carries
# harness.estate=true — a positive identity a nested foreign project repo cannot reach or forge
# (#60). Set it on EVERY install run and UNCONDITIONALLY — deliberately NOT inside the NEED_GIT
# init block above, which runs ONLY for a brand-new repo: an existing-repo re-install (arming an
# estate created before this version) passes through the `else` branch and must still be armed.
# git config is idempotent, so re-setting it every run is safe. install.sh already refused a
# remoted TARGET (top), so this key can only ever land on a local-only estate.
arm_estate_key() {
  git -C "$TARGET" config harness.estate true
  return 0
}

# ---- deploy agents, then AUDIT with validator + status (agent-as-auditor flow, cond 3) ---------
audit_estate() {
  # The REPLACEMENT arm of the gate (#134): an upgrade that rewrote agent definitions created
  # nothing, so the CREATED test alone would leave the deployed copies at their pre-upgrade
  # contents while the estate reported success. Replacing a file is a reason to redeploy too.
  if [ ${#CREATED[@]} -gt 0 ] || [ "$NEED_GIT" -eq 1 ] || [ ${#up_replace[@]} -gt 0 ]; then
    bash "$TARGET/_harness/scripts/deploy_agents.sh" \
      || echo "note: agent deploy reported an issue — see above (verify your Copilot agent dir)."
  fi
  echo "--- validator ---"
  bash "$TARGET/_harness/scripts/check_ticket_log.sh" \
    || echo "(validator surfaced issues above — fix on the record; the installer heals nothing)"
  echo "--- status ---"
  bash "$TARGET/_harness/scripts/harness-status.sh" \
    || echo "(status surfaced issues above — fix on the record)"
  return 0
}

# ---- format-divergence nudge (amendment 2): surface, never enforce -----------------------------
# harness-status already WARNs hand-made / non-conforming ticket folders; we echo the pointer so
# a heavy divergence is noticed at install time. We NEVER rename or edit — the user decides.
divergence_nudge() {
  echo "note: if status WARNed a ticket whose name diverges from the grammar," \
       "that ticket is surfaced"
  echo "      but not validated. Rename it to conform, widen the grammar (see folder-structure.md),"
  echo "      or mark it '.not-a-ticket'. The installer changes nothing here."
  return 0
}

# ---- CLOSING SUMMARY = a record (amendment D) --------------------------------------------------
print_summary() {
  echo
  echo "======================== INSTALL SUMMARY ========================"
  echo "Estate: $TARGET"
  print_summary_version
  print_summary_created
  echo "Choices (asked or defaulted):"
  print_summary_board
  echo "  workspace root    = $TARGET   (derived from the install target — not asked)"
  echo "  cheap model pin   = $CHEAP_MODEL"
  echo "  sonnet model pin  = $SONNET_MODEL"
  print_summary_knobs
  return 0
}

# print_summary_version — the version line of the record. It reports the ESTATE's stamp, because
# that is the only version true OF THE ESTATE: the installer creates only what is ABSENT, so a
# repair run from a NEWER source leaves an older estate's stamp exactly where it found it. When the
# two differ, say so plainly instead of printing the source's number over an estate that does not
# carry it — that would be the summary claiming an upgrade the installer never performed. The note
# stays silent in the ordinary cases: on a fresh install the estate's stamp was just copied from
# the source's; in reconfigure-only mode TARGET and SOURCE are the same directory, so both reads
# return the same number; and after an --upgrade the stamp is root-pinned plain machinery the run
# REPLACED, so the two agree because the estate genuinely moved. The source side is read from the
# ESTATE TREE, which is where the version stamp ships from; in an installed estate that tree and
# the estate root are one directory.
print_summary_version() {
  est_version="$(read_version "$TARGET")"
  src_version="$(read_version "$ESTATE_SRC")"
  echo "Harness version: $est_version   (this estate's VERSION stamp)"
  [ "$est_version" = "$src_version" ] && return 0
  # The prescription now NAMES the mode that would move the stamp (#134). This line used to end
  # "Nothing here upgrades an estate" — true of every mode the installer had, and false from the
  # day --upgrade landed. A summary telling a user no upgrade path exists is worse than silence,
  # because it is the sentence that stops them looking for one.
  echo "  NOTE: the source you ran is $src_version. A plain run creates only what is absent, so"
  echo "        it did NOT replace this estate's stamp. To bring this estate's machinery up to"
  echo "        this source's, re-run from the source checkout with --upgrade (--dry-run first)."
  return 0
}

# print_summary_created — the one honest count line: reconfigure-only never creates anything, and
# an upgrade's count is FOUR numbers rather than one, because "created" is not the interesting
# figure in a run whose whole risk lives in the other three (#134).
print_summary_created() {
  if [ "$RECONFIGURE" -eq 1 ]; then
    echo "Created this run: 0 file(s) — reconfigure-only mode" \
         "(reviewed config; created and repaired nothing)."
    return 0
  fi
  if [ "$UPGRADE" -eq 1 ]; then
    print_summary_upgrade
    return 0
  fi
  echo "Created this run: ${#CREATED[@]} file(s);" \
       "${#plan_exists[@]} PRODUCT file(s) already existed (untouched)."
  return 0
}

# print_summary_upgrade — the upgrade's own count line, plus the sentence a user needs most when
# they read this a week later and disagree with something the run did: where their copies are.
# The per-file RESTORE commands were printed at the moment each move happened; this says the
# folder holding them is untracked, so nothing but those lines and this one records them.
print_summary_upgrade() {
  echo "Upgraded this run: ${#up_create[@]} created, ${#up_replace[@]} replaced," \
       "${#up_retire[@]} retired, ${#up_keep[@]} left carrying your settings."
  echo "  Untouched: $up_record record file(s); $up_same machinery file(s) already current."
  # The quarantine sentence is CONDITIONAL for the same reason the plan's line is: on a re-run
  # nothing moved, and telling a user their copies are in a folder that was never created is a
  # false statement in the closing record — the one place they are most likely to trust it.
  if [ "$(upgrade_moves)" -eq 0 ]; then
    echo "  Nothing was moved, so no quarantine folder was created."
    return 0
  fi
  echo "  NOTHING WAS DELETED. Every replaced and retired file is under $QUAR_REL, which is"
  echo "  untracked — the RESTORE lines printed above are the only record of those moves."
  return 0
}

# print_summary_board — the board line says WHERE the value came from, so a template default is
# never mistaken for an established one.
print_summary_board() {
  if [ "$ESTABLISHED" -eq 0 ]; then
    widened=""
    [ "$BOARD_WIDEN" -eq 1 ] && widened="  (grammar widened for hyphens)"
    echo "  board key         = $BOARD$widened"
    return 0
  fi
  if [ "$DETECTED_BOARD_REAL" -eq 1 ]; then
    echo "  board key         = $BOARD (established; to change it, edit ticket-grammar.sh —" \
         "see setup.md). Left untouched."
    return 0
  fi
  echo "  board key         = $BOARD (template default; no established ticket yet)."
  return 0
}

# print_summary_knobs — the tunables and the declared residuals, closing the record.
print_summary_knobs() {
  echo "Tunable knobs (not asked; defaults shown, each has ONE home = the named env var):"
  echo "  HARNESS_GIT_WARN_MB       default 50   — .git housekeeping nudge threshold" \
       "(harness-status.sh)"
  echo "  HARNESS_TICKET_WARN_MB    default 5    — per-ticket tracked-root size WARN" \
       "(harness-status.sh)"
  echo "  HARNESS_COMMIT_LAG_WARN_S default 300  — commit-vs-session lag WARN (harness-status.sh)"
  echo "  HARNESS_AGENT_DEPLOY_DIR  default ~/.copilot/agents — agent deploy target" \
       "(deploy_agents.sh)"
  echo "Declared residuals (honest): verifying the hook fires inside a live assistant session," \
       "and any"
  echo "  platform whose agent directory differs (HARNESS_AGENT_DEPLOY_DIR override stands)." \
       "Any model"
  echo "  pin left as PICK-A-* must be set before the agents will run."
  echo "================================================================="
  return 0
}

# ---- AI-ASSISTANT FINAL GATE (amendment 2; OPERATOR-witnessed) ---------------------------------
final_gate() {
  echo
  echo "FINAL STEP — hand this estate to your AI assistant of choice as the last gate." \
       "Paste setup.md's"
  echo "prompt (it references everything established above), then have the assistant:" \
       "read the SUMMARY,"
  echo "confirm validator + status are green, spot-check the scaffolded tickets," \
       "and nudge you to fix"
  echo "anything red — on the record. That live validation is the final gate for local deployment."
  return 0
}

# main — the whole run, in the order it has always happened.
main() {
  parse_args "$@"
  resolve_target
  guard_target_is_source
  guard_upgrade_mode
  guard_no_remote
  guard_source_tree
  banner_reconfigure
  interview_board
  interview_models
  # THREE MODES, tested in this order because they are not siblings: reconfigure-only is decided
  # by WHERE the installer is running from and overrides everything (it has no source to work
  # from at all), --upgrade is asked for by name, and the create path is what happens otherwise.
  if [ "$RECONFIGURE" -eq 1 ]; then
    reconfigure_only
  elif [ "$UPGRADE" -eq 1 ]; then
    upgrade_path
  else
    create_path
  fi
  arm_estate_key
  audit_estate
  divergence_nudge
  print_summary
  final_gate
}

main "$@"
