#!/usr/bin/env bash
# run_demo.sh — proves the harness machinery works on THIS machine in ~20s.
# No Copilot needed. Safe: uses temp state, creates+destroys one scratch ticket.
set -euo pipefail
export HARNESS_DEMO=1   # lets status treat a template-clone remote as a NOTE, not a FAIL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."
export HARNESS_STATE_DIR=$(mktemp -d) HARNESS_AGENT_DEPLOY_DIR=$(mktemp -d) PACK_OUT_DIR=$(mktemp -d)
trap 'rm -rf "$HARNESS_STATE_DIR" "$HARNESS_AGENT_DEPLOY_DIR" "$PACK_OUT_DIR"' EXIT
S="Tickets/999911Z-PROJ-99998"; rm -rf "$S"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init -q .; git add -A; git -c user.email=demo@local -c user.name=demo commit -qm "harness: day zero"
fi

echo "=== 1/6 validator: first pass + vacuous rerun ==="
bash _harness/scripts/check_ticket_log.sh
bash _harness/scripts/check_ticket_log.sh

echo "=== 2/6 scratch ticket: happy path ==="
cp -r Tickets/999912Z-PROJ-99999 "$S"
mv "$S/999912Z-PROJ-99999.md" "$S/999911Z-PROJ-99998.md"
printf '\n## %s - Demo work session\n- Added the new field to the staging model\n' "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
echo "- notes.md — platform quirk — read before editing" >> "$S/AI-Knowledge/_index.md"
echo "quirk" > "$S/AI-Knowledge/notes.md"
bash _harness/scripts/check_ticket_log.sh

echo "=== 3/6 corruption must FAIL loudly (this is the point) ==="
sleep 1; sed -i '/notes.md/d' "$S/AI-Knowledge/_index.md"; touch "$S/999911Z-PROJ-99998.md"
if bash _harness/scripts/check_ticket_log.sh; then echo "BUG: should have failed"; exit 1; fi
echo "--- correctly refused; applying the printed fix (repair gets its own log entry) ---"
echo "- notes.md — platform quirk — read before editing" >> "$S/AI-Knowledge/_index.md"
sleep 1
printf '\n## %s - Repaired records\n- restored the index line for notes.md\n' "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
bash _harness/scripts/check_ticket_log.sh
echo "--- regression #2: substring decoy must NOT cover a real file ---"
echo "decoy content" > "$S/AI-Knowledge/extra.md"
echo "- release-extra.md — decoy line, superstring of extra.md" >> "$S/AI-Knowledge/_index.md"
sleep 1; touch "$S/999911Z-PROJ-99998.md"
if bash _harness/scripts/check_ticket_log.sh; then echo "BUG: substring decoy accepted"; exit 1; fi
echo "--- correctly refused the decoy; cleaning up ---"
rm "$S/AI-Knowledge/extra.md"
grep -v "release-extra.md" "$S/AI-Knowledge/_index.md" > "$S/AI-Knowledge/_index.tmp" && mv "$S/AI-Knowledge/_index.tmp" "$S/AI-Knowledge/_index.md"
sleep 1
printf '\n## %s - Repaired records\n- removed decoy index line and file\n' "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
bash _harness/scripts/check_ticket_log.sh

echo "=== 4/6 notebook helper (deterministic .ipynb writes) ==="
python3 _harness/scripts/append_notebook_cell.py "$S/Checks/checks_master.ipynb" "check: row counts match" "SELECT COUNT(*) FROM model;"

echo "=== 5/6 deploy + status; break an agent; watch it prescribe ==="
bash _harness/scripts/deploy_agents.sh
bash _harness/scripts/harness-status.sh
mv "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md" /tmp/dw.bak
bash _harness/scripts/harness-status.sh || echo "--- correctly failed with a fix line ---"
mv /tmp/dw.bak "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md"
bash _harness/scripts/harness-status.sh >/dev/null && echo "healthy after fix"

echo "=== 6/6 scrubbed context pack + self-audit ==="
bash _harness/scripts/make_context_pack.sh --ticket 999911Z-PROJ-99998
unzip -p "$PACK_OUT_DIR"/harness-pack-*.zip MANIFEST.txt | tail -1

rm -rf "$S"; git add -A >/dev/null; git -c user.email=demo@local -c user.name=demo commit -qm "demo: pass" >/dev/null 2>&1 || true
echo; echo "ALL 6 DEMO STAGES PASSED — the machinery works. Next: INSTALL.md to wire Copilot."
