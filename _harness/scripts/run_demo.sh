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

DID_INIT=0
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init -q .; git add -A; git -c user.email=demo@local -c user.name=demo commit -qm "harness: day zero"
  DID_INIT=1
fi

# R-03 portability guard: reject in-place sed under _harness/ (BSD-incompatible; use tmp+mv instead)
if grep -rnE 'sed +(-[A-Za-z]+ +)*-i' _harness/; then
  echo "FAIL: in-place sed found under _harness/ — not BSD-portable. Fix: rewrite via tmp+mv (grep for deletes, sed for substitutions)."; exit 1
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
sleep 1; grep -v "notes.md" "$S/AI-Knowledge/_index.md" > "$S/AI-Knowledge/_index.tmp" && mv "$S/AI-Knowledge/_index.tmp" "$S/AI-Knowledge/_index.md"; touch "$S/999911Z-PROJ-99998.md"
if bash _harness/scripts/check_ticket_log.sh; then echo "BUG: should have failed"; exit 1; fi
echo "--- correctly refused; applying the printed fix (repair gets its own log entry) ---"
echo "- notes.md — platform quirk — read before editing" >> "$S/AI-Knowledge/_index.md"
sleep 1
printf '\n## %s - Repaired records\n- restored the index line for notes.md\n' "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
bash _harness/scripts/check_ticket_log.sh
echo "--- regression #2: substring decoy must NOT cover a real file (token match, not substring) ---"
echo "decoy content" > "$S/AI-Knowledge/extra.md"
echo "release note" > "$S/AI-Knowledge/release-extra.md"          # real file: ghost check passes, isolates the orphan check
echo "- release-extra.md — decoy" >> "$S/AI-Knowledge/_index.md"  # no bare 'extra.md' token: substring would cover it, token does not
sleep 1; touch "$S/999911Z-PROJ-99998.md"
set +e
decoy_out=$(bash _harness/scripts/check_ticket_log.sh 2>&1)
decoy_rc=$?
set -e
printf '%s\n' "$decoy_out"
if [ "$decoy_rc" -eq 0 ] || ! printf '%s\n' "$decoy_out" | grep -q "orphan file AI-Knowledge/extra.md"; then
  echo "BUG: substring decoy accepted — token-match orphan check did not fire on real file extra.md"; exit 1
fi
echo "--- correctly refused the decoy (real file extra.md flagged as orphan by token match); cleaning up ---"
rm "$S/AI-Knowledge/extra.md" "$S/AI-Knowledge/release-extra.md"
grep -v "release-extra.md" "$S/AI-Knowledge/_index.md" > "$S/AI-Knowledge/_index.tmp" && mv "$S/AI-Knowledge/_index.tmp" "$S/AI-Knowledge/_index.md"
sleep 1
printf '\n## %s - Repaired records\n- removed decoy index line and both decoy files\n' "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
bash _harness/scripts/check_ticket_log.sh

echo "=== 4/6 notebook helper (deterministic .ipynb writes) ==="
python3 _harness/scripts/append_notebook_cell.py "$S/Checks/checks_master.ipynb" "check: row counts match" "SELECT COUNT(*) FROM model;"
# R-07: exercise check-scribe's LITERAL contract form — invoke the helper DIRECTLY (bit + shebang, not python3),
# so a stripped execute bit turns this stage RED (the python3 call above never sees the bit).
if ! _harness/scripts/append_notebook_cell.py "$S/Checks/checks_master.ipynb" "check: direct-exec contract (R-07)" "SELECT 1;"; then
  echo "FAIL: append_notebook_cell.py not directly executable — execute bit or shebang missing. Fix: git update-index --chmod=+x _harness/scripts/append_notebook_cell.py"; exit 1
fi

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

rm -rf "$S"
if [ "$DID_INIT" -eq 1 ]; then
  git add -A >/dev/null; git -c user.email=demo@local -c user.name=demo commit -qm "demo: pass" >/dev/null 2>&1 || true
fi
echo; echo "ALL 6 DEMO STAGES PASSED — the machinery works. Next: INSTALL.md to wire Copilot."
