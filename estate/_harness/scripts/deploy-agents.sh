#!/usr/bin/env bash
# deploy-agents.sh — sync _agents/ (source of truth) -> Copilot user-level discovery dir.
# Live copies are derived and disposable; source wins on any disagreement.
#
# THE DEPLOY DIRECTORY IS A SINGLE-SLOT SHARED RESOURCE (#304), and that is what makes this script
# the one place the rehearsal-versus-real distinction can be enforced. There is exactly ONE
# ~/.copilot/agents on a machine, every estate on that machine deploys into it, and a deploy
# OVERWRITES whatever is there. A rehearsal install and a real install are the same command, so
# nothing above this line knows which one is running — but this line can see something neither
# caller states: which estate the contracts about to be overwritten came from.
#
# THE RULE, AND IT IS THE WHOLE DESIGN:
#   THE FIRST DEPLOY ON A MACHINE CLAIMS IT; EVERY LATER ONE MUST PROVE IT OWNS IT.
# The claim is the record written at the foot of this file. It is written on EVERY deploy, silent
# ones included — without it the rule stops being true after its first word, because nothing would
# ever arm the ownership test.
#
# TWO ways past the refusal, both DECLARATIONS rather than inferences, and both printed in it:
#   * HARNESS_AGENT_DEPLOY_DIR=<dir>  — a rehearsal saying so, by deploying somewhere throwaway.
#     `install.sh --rehearsal` sets it for you, under the estate being rehearsed.
#   * HARNESS_AGENT_ADOPT=1           — a real hand-off saying so: this estate now owns the live
#     directory. It is recorded, so it is asked for once and never again.
#
# WHAT THIS DELIBERATELY DOES NOT CHECK, so the next reader does not restore it thinking it was
# overlooked: contracts present with NO record are CLAIMED, not refused. An earlier version of this
# gate refused them, and that arm was the one that would have caught the original accident — a
# rehearsal writing fixture-pinned contracts into a live assistant configuration. It was removed on
# an operator ruling: NO FRICTION DURING THE INSTALLATION OF AN ESTATE. The friction it caused was
# real but purely transitional — it could only ever reach a machine that deployed agents BEFORE
# this feature existed, never a fresh install — and the operator did not want it at all. What is
# given up is exactly one deploy per machine, the first one after this release, on the shrinking
# population of machines that already hold pre-feature contracts. Every deploy after that is
# covered, because the record is written on the way through.
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

# refuse — the one output shape for a stopped deploy. Exit 3 rather than 1: install.sh
# distinguishes "the deploy was REFUSED, and
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

# THE GATE, and it is one test: a RECORDED owner that is not us. An adopting run skips it by
# declaration; a directory with no record at all is claimed by the deploy below, per the ruling at
# the top of this file. So there is exactly one shape that stops here — this deploy would take the
# directory off another estate, which is a legitimate act (people move estates, and people rehearse)
# but never an accidental one.
if [ "$ADOPT" != "1" ] && [ -f "$OWNER_FILE" ]; then
  owner=$(head -n1 "$OWNER_FILE")
  [ "$owner" = "$WORK_ROOT" ] \
    || refuse "$DEPLOY_DIR holds agents deployed from a DIFFERENT estate: $owner"
fi

# Copy every agent contract from the versioned source into the discovery dir, overwriting any
# existing copy (-f): deployed copies are derived, so source always wins and any drift is erased.
n=0
for src in "$WORK_ROOT"/_agents/*.agent.md; do
  cp -f "$src" "$DEPLOY_DIR/"; n=$((n+1))
done
# THE CLAIM. Written on EVERY deploy — the silent first one on a fresh machine, the silent one that
# claims a directory holding unaccounted contracts, and the declared adoption alike. This line is
# what arms the gate above; without it nothing is ever owned and the gate can never fire.
# It is written AFTER the copies land, so a deploy that died half-way never leaves a record
# claiming an estate owns contracts it did not finish writing.
printf '%s\n' "$WORK_ROOT" > "$OWNER_FILE"
echo "OK: deployed $n agent(s) to $DEPLOY_DIR."
echo "NOTE: verify the discovery directory for YOUR Copilot version (preview-grade; see README Setup) — override with HARNESS_AGENT_DEPLOY_DIR."
