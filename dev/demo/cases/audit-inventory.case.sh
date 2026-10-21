#!/usr/bin/env bash
# audit-inventory.case.sh — [audit-inventory]: the estate-auditor's read-only inventory reports what
# the other observers do not, and reports it truthfully. SOURCED by the runner; see
# dev/scripts/run-demo.sh.
#
# Everything runs against a THROWAWAY estate built here — no operator record is ever read. Each
# label below is revert-provable: point HARNESS_AUDIT_INVENTORY at a copy of the helper that lacks
# the behaviour and that label reds by name. Cleanup is an explicit rm; the runner owns the trap.

# ai_manifest — every fixture file's checksum, one per line, read path by path because the
# fixture's folder names carry spaces ("General Human Knowledge").
ai_manifest() {
  (cd "$AI_ROOT" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done)
}

# ai_fixture — four tickets, two root documents and two dated notes under Audits/, each shaped to
# exercise exactly one rule:
#   202601A-PROJ-1  closed; "Pull Requests: None"; an untitled Session Log heading; a notebook whose
#                   only saved output is an error
#   202601B-PROJ-2  no PR section at all; a notebook with real output; its header links the
#                   walkthrough that lives in 202601C (a shared walkthrough)
#   202601C-PROJ-3  owns PROJ-3-walkthrough.md
#   202601D-PROJ-4  links a walkthrough file that does not exist
ai_fixture() {
  echo "--- [audit-inventory]: read-only inventory — sessions, PRs, notebooks, walkthroughs," \
    "root links, audits ---"
  AI_ROOT=$(mktemp -d)
  AI_PY="${HARNESS_TEST_PYTHON:-python3}"
  AI_HELPER="${HARNESS_AUDIT_INVENTORY:-$PWD/estate/_harness/scripts/audit-inventory.py}"
  [ -f "$AI_HELPER" ] \
    || { echo "BUG [audit-inventory-present]: the helper is absent ($AI_HELPER)"; exit 1; }
  local t
  for t in 202601A-PROJ-1 202601B-PROJ-2 202601C-PROJ-3 202601D-PROJ-4; do
    mkdir -p "$AI_ROOT/Tickets/$t/Checks"
  done
  cat > "$AI_ROOT/Tickets/202601A-PROJ-1/202601A-PROJ-1.md" <<'AIMD'
# PROJ-1 — closed ticket with no PR

Pull Requests:
- None.

## Current State
- Now: Closed — finished, 2026-01-02, tracker
- Next: none
- Blocked: none

## Session Log

## 20260101090000 - first entry
- started

## 20260102090000
AIMD
  # A notebook whose only saved output is an error (a template cell that failed) is not evidence.
  printf '%s\n' '{"cells":[{"cell_type":"code","execution_count":1,"id":"a1","metadata":{},' \
    '"outputs":[{"output_type":"error","ename":"ProfileNotFound","evalue":"x","traceback":[]}],' \
    '"source":"x"}],"metadata":{},"nbformat":4,"nbformat_minor":5}' \
    > "$AI_ROOT/Tickets/202601A-PROJ-1/Checks/checks_master.ipynb"
  cat > "$AI_ROOT/Tickets/202601B-PROJ-2/202601B-PROJ-2.md" <<'AIMD'
# PROJ-2 — layered on PROJ-3

Context:
- [Shared walkthrough](../202601C-PROJ-3/PROJ-3-walkthrough.md)

## Current State
- Now: in progress
AIMD
  printf '%s\n' '{"cells":[{"cell_type":"code","execution_count":1,"id":"b1","metadata":{},' \
    '"outputs":[{"output_type":"stream","name":"stdout","text":"42\n"}],"source":"x"}],' \
    '"metadata":{},"nbformat":4,"nbformat_minor":5}' \
    > "$AI_ROOT/Tickets/202601B-PROJ-2/Checks/checks_master.ipynb"
  printf '# PROJ-3\n\n## Current State\n- Now: in progress\n' \
    > "$AI_ROOT/Tickets/202601C-PROJ-3/202601C-PROJ-3.md"
  printf '# PROJ-3 walkthrough\n' > "$AI_ROOT/Tickets/202601C-PROJ-3/PROJ-3-walkthrough.md"
  printf '# PROJ-4\n\nContext:\n- [Gone](../202601C-PROJ-3/PROJ-9-walkthrough.md)\n\n## Current State\n- Now: x\n' \
    > "$AI_ROOT/Tickets/202601D-PROJ-4/202601D-PROJ-4.md"
  # Root documents: one dead relative link in README.md, one live link in AGENTS.md.
  printf '# Readme\n[Install](missing-install.md) and [Rules](CONSTITUTION.md)\n' > "$AI_ROOT/README.md"
  printf '# Agents\n[Rules](CONSTITUTION.md#rules)\n' > "$AI_ROOT/AGENTS.md"
  printf '# Constitution\n\n## Rules\n' > "$AI_ROOT/CONSTITUTION.md"
  # Audits: the dated estate audit, and a LATER dated note that is not an audit (a handoff).
  mkdir -p "$AI_ROOT/General Human Knowledge/Audits" "$AI_ROOT/General AI-Knowledge"
  printf '# Audit\nWork commit audited: `abc1234`\n' \
    > "$AI_ROOT/General Human Knowledge/Audits/20260101-estate-audit.md"
  printf '# Handoff\n' > "$AI_ROOT/General Human Knowledge/Audits/20260301-harness-handoff.md"
  AI_BEFORE=$(ai_manifest)
}

# ai_assert — run the helper once with --json and check every rule in one Python pass, so each
# failure is printed by its own label. A missing JSON key is a failure, never a crash. The checker
# is written to its own temp file (outside the fixture, so the read-only manifest is unaffected).
ai_assert() {
  local ai_json ai_rc ai_check
  set +e
  ai_json=$("$AI_PY" "$AI_HELPER" --root "$AI_ROOT" --json 2>&1); ai_rc=$?
  set -e
  [ "$ai_rc" -eq 0 ] \
    || { echo "BUG [audit-inventory-runs]: the helper exited rc=$ai_rc:"; echo "$ai_json"; exit 1; }
  ai_check=$(mktemp)
  cat > "$ai_check" <<'AIPY'
import json
import sys

inv = json.load(sys.stdin)
tickets = {x["ticket"]: x for x in inv["tickets"]}
docs = {x["path"]: x for x in inv["documents"]}
bad = []


def check(label, ok, why):
    if not ok:
        bad.append("BUG [%s]: %s" % (label, why))


one = tickets.get("202601A-PROJ-1", {})
two = tickets.get("202601B-PROJ-2", {})
four = tickets.get("202601D-PROJ-4", {})
check("inventory-untitled-session", one.get("session_entries") == 2,
      "an untitled '## <14 digits>' heading was not counted (entries=%r, want 2)"
      % one.get("session_entries"))
check("inventory-closed", one.get("closed") is True, "a '- Now: Closed' ticket did not read as closed")
check("inventory-pr-none", "no PR link in header" not in one.get("walkthrough_gaps", ["?"]),
      "an explicit 'Pull Requests: None' still raised the no-PR gap")
check("inventory-pr-gap", "no PR link in header" in two.get("walkthrough_gaps", []),
      "a header with no PR section did not raise the no-PR gap")
check("inventory-error-output", one.get("notebooks_with_output") == 0,
      "an error-only notebook counted as saved output (%r)" % one.get("notebooks_with_output"))
check("inventory-real-output", two.get("notebooks_with_output") == 1,
      "a notebook with real output was not counted (%r)" % two.get("notebooks_with_output"))
check("inventory-shared-walkthrough",
      two.get("walkthrough_shared") is True
      and "no walkthrough" not in two.get("walkthrough_gaps", ["no walkthrough"]),
      "a header link to another ticket's existing walkthrough did not count as the walkthrough")
check("inventory-shared-missing", "no walkthrough" in four.get("walkthrough_gaps", []),
      "a header link to a walkthrough file that does not exist counted as a walkthrough")
readme = docs.get("README.md", {})
agents = docs.get("AGENTS.md", {})
check("inventory-root-links", any("missing-install.md" in b for b in readme.get("broken_links", [])),
      "a dead link in a root document was not listed (broken_links=%r)" % readme.get("broken_links"))
check("inventory-root-links-live", agents.get("broken_links", ["?"]) == [],
      "a live root-document link was listed as broken (%r)" % agents.get("broken_links"))
latest = inv.get("audits", {}).get("latest_report") or ""
check("inventory-audit-name", latest.endswith("20260101-estate-audit.md"),
      "a later dated note that is not an estate audit was taken as the latest audit (%s)" % latest)
if bad:
    print("\n".join(bad))
sys.exit(1 if bad else 0)
AIPY
  printf '%s\n' "$ai_json" | "$AI_PY" "$ai_check" || { rm -f "$ai_check"; exit 1; }
  rm -f "$ai_check"
  [ "$(ai_manifest)" = "$AI_BEFORE" ] \
    || { echo "BUG [audit-inventory-read-only]: the inventory changed a file in the estate it read"; \
         exit 1; }
  echo "  ok [audit-inventory] — untitled session counted, PR None honoured, error-only notebook" \
    "not evidence, shared walkthrough counted (missing one not), root dead link listed, only" \
    "estate-audit reports date the audit, nothing written"
}

case_audit_inventory() {
  ai_fixture
  ai_assert
  rm -rf "$AI_ROOT"
}
