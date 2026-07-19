#!/usr/bin/env bash
# deploy_agents.sh — sync _agents/ (source of truth) -> Copilot user-level discovery dir.
# Live copies are derived and disposable; source wins on any disagreement.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_DIR="${HARNESS_AGENT_DEPLOY_DIR:-$HOME/.copilot/agents}"
mkdir -p "$DEPLOY_DIR"
# Copy every agent contract from the versioned source into the discovery dir, overwriting any
# existing copy (-f): deployed copies are derived, so source always wins and any drift is erased.
n=0
for src in "$WORK_ROOT"/_agents/*.agent.md; do
  cp -f "$src" "$DEPLOY_DIR/"; n=$((n+1))
done
echo "OK: deployed $n agent(s) to $DEPLOY_DIR."
echo "NOTE: verify the discovery directory for YOUR Copilot version (preview-grade; see INSTALL.md) — override with HARNESS_AGENT_DEPLOY_DIR."
