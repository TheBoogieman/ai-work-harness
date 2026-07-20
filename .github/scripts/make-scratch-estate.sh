#!/usr/bin/env bash
# make-scratch-estate.sh — stand up a THROWAWAY, GENERIC harness Work-root for #44's
# live-fire hook confirmation run. DEV INFRASTRUCTURE: lives under .github/, never ships
# to an installed estate (#43).
#
# WHY: cond 0 (test-bench isolation) forbids live-fire hook testing on the canonical
# checkout — a real postToolUse auto-commit must never fire into the product repo. This
# builds a disposable estate that IS a valid Work-root (the machinery + a generic ticket +
# a git-init'd record repo) with the shipped, verified hook config already dropped where the
# VS Code Copilot IDE agent auto-loads it (.github/hooks/harness.json). The operator opens THIS
# folder in VS Code + Copilot, edits a file, and watches postToolUse commit into the SCRATCH
# repo — never the product repo. It is kept free of work identifiers (G6): only the generic
# 999912Z-PROJ template ticket (no real board keys) and a generic git identity.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Destination: an explicit path if given, else a fresh temp dir. Never overwrite.
DEST="${1:-}"
if [ -z "$DEST" ]; then DEST="$(mktemp -d)/harness-scratch-estate"; fi
if [ -e "$DEST" ]; then echo "make-scratch-estate: refusing to overwrite existing path: $DEST" >&2; exit 1; fi
mkdir -p "$DEST"

# Copy the machinery a live hook needs to run (scripts + agents), plus the whitelist and
# the constitution so the estate is a faithful Work-root.
cp -r "$REPO_ROOT/_harness" "$DEST/_harness"
cp -r "$REPO_ROOT/_agents"  "$DEST/_agents"
cp "$REPO_ROOT/.gitignore"  "$DEST/.gitignore"
# Carry the line-ending protection (#40): without .gitattributes a fresh git-init on Windows
# would CRLF the copied scripts on the next checkout and break the live hooks. Pin LF here too.
cp "$REPO_ROOT/.gitattributes" "$DEST/.gitattributes"
[ -f "$REPO_ROOT/folder-structure.md" ] && cp "$REPO_ROOT/folder-structure.md" "$DEST/"
[ -f "$REPO_ROOT/AGENTS.md" ] && cp "$REPO_ROOT/AGENTS.md" "$DEST/"

# One GENERIC ticket from the shipped template — no real board keys (G6).
mkdir -p "$DEST/Tickets"
cp -r "$REPO_ROOT/Tickets/999912Z-PROJ-99999" "$DEST/Tickets/999912Z-PROJ-99999"

# Drop the shipped, verified hook config where the VS Code Copilot IDE agent auto-loads it —
# so a re-confirmation fires the exact artifact users install (its one home, no separate copy).
mkdir -p "$DEST/.github/hooks"
cp "$REPO_ROOT/_harness/hooks/hooks.example.json" "$DEST/.github/hooks/harness.json"

# Git-init the disposable RECORD repo (local-only). A generic identity keeps anything
# personal out of the scratch history (G6). An initial commit gives postToolUse a HEAD to
# diff against so its first auto-commit is a clean single-write delta.
git -C "$DEST" init -q
# Match the documented first step (#40) so the disposable estate keeps LF at the source too.
git -C "$DEST" config core.autocrlf input
git -C "$DEST" add -A
git -C "$DEST" -c user.name="harness scratch" -c user.email="scratch@localhost" \
  commit -q -m "scratch estate: initial (generic template, disposable)"

echo "Scratch estate ready (disposable — NOT the canonical checkout):"
echo "  $DEST"
echo
echo "Confirmation-run steps — VS Code Copilot IDE agent:"
echo "  1. Open the folder:   code \"$DEST\""
echo "  2. Confirm the Copilot agent extension is active against this workspace."
echo "  3. sessionStart: start an agent session -> the validator (check_ticket_log.sh) runs."
echo "  4. postToolUse: have the agent EDIT a file under Tickets/999912Z-PROJ-99999/, then run"
echo "       git -C \"$DEST\" log --oneline"
echo "     and look for an 'auto-write ...' commit."
echo "  5. sessionEnd: end the session; look for an 'auto-session-end ...' commit (if the surface fires it)."
echo "  6. Discard when done:  rm -rf \"$DEST\""
