#!/usr/bin/env bash
# run_demo.sh — proves the harness machinery works on THIS machine in ~20s.
# No Copilot needed. Safe: uses temp state, creates+destroys one scratch ticket.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."
export HARNESS_STATE_DIR=$(mktemp -d) HARNESS_AGENT_DEPLOY_DIR=$(mktemp -d) PACK_OUT_DIR=$(mktemp -d)
trap 'rm -rf "$HARNESS_STATE_DIR" "$HARNESS_AGENT_DEPLOY_DIR" "$PACK_OUT_DIR"' EXIT
S="Tickets/999911Z-PROJ-99998"; rm -rf "$S"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init -q .; git add -A; git -c user.email=demo@local -c user.name=demo commit -qm "harness: day zero"
fi

echo "=== 1/6 validator: first pass + vacuous rerun ==="
_harness/scripts/check_ticket_log.sh
_harness/scripts/check_ticket_log.sh

echo "=== 2/6 scratch ticket: happy path ==="
cp -r Tickets/999912Z-PROJ-99999 "$S"
mv "$S/999912Z-PROJ-99999.md" "$S/999911Z-PROJ-99998.md"
printf '\n## %s - Demo work session\n- Added the new field to the staging model\n' "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
echo "- notes.md — platform quirk — read before editing" >> "$S/AI-Knowledge/_index.md"
echo "quirk" > "$S/AI-Knowledge/notes.md"
_harness/scripts/check_ticket_log.sh

echo "=== 3/6 corruption must FAIL loudly (this is the point) ==="
sleep 1; sed -i '/notes.md/d' "$S/AI-Knowledge/_index.md"; touch "$S/999911Z-PROJ-99998.md"
if _harness/scripts/check_ticket_log.sh; then echo "BUG: should have failed"; exit 1; fi
echo "--- correctly refused; applying the printed fix ---"
echo "- notes.md — platform quirk — read before editing" >> "$S/AI-Knowledge/_index.md"
sleep 1; touch "$S/999911Z-PROJ-99998.md"; _harness/scripts/check_ticket_log.sh

echo "=== 4/6 notebook helper (deterministic .ipynb writes) ==="
python3 _harness/scripts/append_notebook_cell.py "$S/SQL/Master/master_examples.ipynb" "check: row counts match" "SELECT COUNT(*) FROM model;"

echo "=== 5/6 deploy + status; break an agent; watch it prescribe ==="
_harness/scripts/deploy_agents.sh
_harness/scripts/harness-status.sh
mv "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md" /tmp/dw.bak
_harness/scripts/harness-status.sh || echo "--- correctly failed with a fix line ---"
mv /tmp/dw.bak "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md"
_harness/scripts/harness-status.sh >/dev/null && echo "healthy after fix"

echo "=== 6/6 scrubbed context pack + self-audit ==="
_harness/scripts/make_context_pack.sh --ticket 999911Z-PROJ-99998
unzip -p "$PACK_OUT_DIR"/harness-pack-*.zip MANIFEST.txt | tail -1

rm -rf "$S"; git add -A >/dev/null; git -c user.email=demo@local -c user.name=demo commit -qm "demo: pass" >/dev/null 2>&1 || true
echo; echo "ALL 6 DEMO STAGES PASSED — the machinery works. Next: INSTALL.md to wire Copilot."
