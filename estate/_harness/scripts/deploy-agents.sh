#!/usr/bin/env bash
# deploy-agents.sh — sync _agents/ (source of truth) -> Copilot user-level discovery dir.
# Live copies are derived and disposable; source wins on any disagreement.
#
# THE DEPLOY DIRECTORY IS A SINGLE-SLOT SHARED RESOURCE (#304), and that is what makes this script
# the one place the rehearsal-versus-real distinction can be enforced. There is exactly ONE
# ~/.copilot/agents on a machine, every estate on that machine deploys into it, and a deploy
# OVERWRITES whatever is there. A rehearsal install and a real install are the same command, so
# nothing above this line knows which one is running — but this line can see something neither
# caller states: whether the contracts about to be overwritten came from THIS estate or somebody
# else's. It refuses the second case rather than guessing, because the failure it is guessing
# about is writing fixture-pinned contracts into a person's live assistant configuration, which is
# what happened. TWO ways past the refusal, both DECLARATIONS rather than inferences, and both
# printed in the refusal itself:
#   * HARNESS_AGENT_DEPLOY_DIR=<dir>  — a rehearsal saying so, by deploying somewhere throwaway.
#     `install.sh --rehearsal` sets it for you, under the estate being rehearsed.
#   * HARNESS_AGENT_ADOPT=1           — a real hand-off saying so: this estate now owns the live
#     directory. It is recorded, so it is asked for once and never again.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_DIR="${HARNESS_AGENT_DEPLOY_DIR:-$HOME/.copilot/agents}"
ADOPT="${HARNESS_AGENT_ADOPT:-0}"
# The ownership record, written by this script and read by the next run of it. It is a dotfile so
# it can never be mistaken for a contract, and it holds ONE line: the estate root the live copies
# were last deployed from.
OWNER_FILE="$DEPLOY_DIR/.deployed-from"
mkdir -p "$DEPLOY_DIR"

# refuse — the one output shape for a stopped deploy, in ONE home so both refusals below print the
# same two ways out. Exit 3 rather than 1: install.sh distinguishes "the deploy was REFUSED, and
# nothing was written" from "the deploy tried and broke", and only the first has a fix a person
# can type. The arguments are the sentence that says what was found, joined with a single space so
# a long one can be wrapped across source lines without changing a byte of what is printed.
refuse() {
  echo "REFUSED: $*" >&2
  echo "  Nothing was written. $DEPLOY_DIR is untouched." >&2
  echo "  If this is a REHEARSAL, say so — deploy somewhere throwaway instead:" >&2
  echo "    HARNESS_AGENT_DEPLOY_DIR=<throwaway-dir> $0" >&2
  echo "    (or re-run the installer as: install.sh --rehearsal <target>)" >&2
  echo "  If this estate really is the one this machine should read agents from, adopt the" >&2
  echo "  directory once — it is recorded, so you are asked once:" >&2
  echo "    HARNESS_AGENT_ADOPT=1 $0" >&2
  exit 3
}

# The gate. An adopting run skips it by declaration; everything else has to be accounted for.
if [ "$ADOPT" != "1" ]; then
  if [ -f "$OWNER_FILE" ]; then
    # A recorded owner that is not us means this deploy would take the directory off another
    # estate. That is a legitimate act (people move estates) but never an accidental one.
    owner=$(head -n1 "$OWNER_FILE")
    [ "$owner" = "$WORK_ROOT" ] \
      || refuse "$DEPLOY_DIR holds agents deployed from a DIFFERENT estate: $owner"
  else
    # No record, but contracts are present: they came from somewhere nothing wrote down. Adopting
    # them silently is exactly the hole the accident went through — a run with no way of knowing
    # whose configuration it was overwriting, overwriting it anyway. A `for` loop rather than a
    # glob test because an unmatched glob under `set -u` stays a literal path, which does not exist
    # and so correctly reads as "nothing here".
    for f in "$DEPLOY_DIR"/*.agent.md; do
      [ -e "$f" ] || continue
      refuse "$DEPLOY_DIR already holds agent contracts and no record says which estate they" \
             "came from — this deploy would overwrite them."
    done
  fi
fi

# Copy every agent contract from the versioned source into the discovery dir, overwriting any
# existing copy (-f): deployed copies are derived, so source always wins and any drift is erased.
n=0
for src in "$WORK_ROOT"/_agents/*.agent.md; do
  cp -f "$src" "$DEPLOY_DIR/"; n=$((n+1))
done
# Record the owner AFTER the copies land, so a deploy that died half-way never leaves a record
# claiming an estate owns contracts it did not finish writing.
printf '%s\n' "$WORK_ROOT" > "$OWNER_FILE"
echo "OK: deployed $n agent(s) to $DEPLOY_DIR."
echo "NOTE: verify the discovery directory for YOUR Copilot version (preview-grade; see README Setup) — override with HARNESS_AGENT_DEPLOY_DIR."
