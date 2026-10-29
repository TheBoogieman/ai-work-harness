#!/usr/bin/env bash
# agent-invocability.case.sh — [agents-invocable]: every agent is directly human-callable.
# SOURCED by the runner; see dev/scripts/run-demo.sh.
#
# Asserts every estate/_agents/*.agent.md declares `user-invocable: true`. The clerk agents
# ticket-scribe still closes completed ticket work; knowledge-keeper and check-scribe now run only
# for qualified candidates. A human must still be able to invoke any agent directly. This case
# FAILS on pre-flip code (where those three were `user-invocable: false`), so the suite pins the flip.

case_agent_invocability() {
  local r08_total=0 r08_bad=0 a
  echo "--- agent-invocability: all agents are user-invocable ---"
  for a in estate/_agents/*.agent.md; do
    r08_total=$((r08_total+1))
    grep -q '^user-invocable: true$' "$a" \
      || { echo "FAIL [agents-invocable]: $a is not 'user-invocable: true' — every agent must be" \
             "directly human-callable."; r08_bad=$((r08_bad+1)); }
  done
  [ "$r08_bad" -eq 0 ] \
    || { echo "BUG [agents-invocable]: $r08_bad agent(s) not invocable"; exit 1; }
  echo "  ok [agents-invocable] — all $r08_total agents are user-invocable: true"
  ac_core_roster
  ac_orchestrator_roster
}

# [agents-core] the agents a daily workflow cannot run without — the planner/implementer loop,
# close-out and the audit among them — are on harness-status's CORE list, so a missing contract is
# a red with its fix, not a silently shorter roster. Each is moved aside in turn and restored.
ac_core_roster() {
  local a out
  echo "--- [agents-core]: a missing core agent contract is a status FAIL that names it ---"
  for a in planner implementer ticket-closer estate-auditor; do
    mv "estate/_agents/$a.agent.md" "estate/_agents/$a.agent.md.aside"
    set +e; out=$(bash estate/_harness/scripts/harness-status.sh 2>&1); set -e
    mv "estate/_agents/$a.agent.md.aside" "estate/_agents/$a.agent.md"
    printf '%s\n' "$out" | grep -q "^FAIL: core agent $a.agent.md missing" \
      || { echo "BUG [agents-core]: with $a.agent.md missing, status did not FAIL naming it:"; \
           printf '%s\n' "$out" | grep -E '^(FAIL|WARN)'; exit 1; }
  done
  echo "  ok [agents-core] — planner, implementer, ticket-closer and estate-auditor are core:" \
    "each missing contract is a FAIL with its fix"
}

# [orchestrator-roster] (#354) the orchestrator runs a ticket end to end by starting the other
# agents, so its frontmatter agents: list must name every agent the harness ships. A new agent left
# off that list could never be reached by an orchestrated session, and nothing else would notice.
# The guard checks that the contract exists, that it carries the strong-tier placeholder pin the
# installer's second model question fills (so the orchestrator needs no new installer question),
# and that every other contract's name is on its list. It then adds a throwaway probe contract and
# checks the list check names it, so each run shows that check can fail.
AC_ORCH=estate/_agents/orchestrator.agent.md

# ac_orch_missing — prints, one per line, each shipped agent the orchestrator's agents: list omits.
# Only the frontmatter is read (the block between the first two --- lines), so a body line that
# happens to start with "agents:" cannot satisfy the check. Brackets and commas become spaces,
# which leaves one agent name per word.
ac_orch_missing() {
  local list a name
  list=$(awk 'NR == 1 && /^---$/ { fm = 1; next } fm && /^---$/ { exit } fm && /^agents:/ { print }' \
    "$AC_ORCH" | sed -e 's/^agents://' -e 's/\[//g' -e 's/\]//g' -e 's/,/ /g')
  for a in estate/_agents/*.agent.md; do
    name=$(basename "$a" .agent.md)
    [ "$name" = orchestrator ] && continue   # the orchestrator does not list itself
    case " $list " in *" $name "*) ;; *) echo "$name" ;; esac
  done
  return 0
}

ac_orchestrator_roster() {
  local missing probe=estate/_agents/zz-roster-probe.agent.md
  echo "--- [orchestrator-roster]: the orchestrator can start every shipped agent ---"
  [ -f "$AC_ORCH" ] \
    || { echo "BUG [orchestrator-roster]: $AC_ORCH is missing, so no agent can run the ticket" \
           "loop end to end"; exit 1; }
  grep -q '^model: PICK-A-SONNET-CLASS-MODEL$' "$AC_ORCH" \
    || { echo "BUG [orchestrator-roster]: $AC_ORCH is not pinned" \
           "'model: PICK-A-SONNET-CLASS-MODEL', the strong-tier placeholder the installer fills"; \
         exit 1; }
  missing=$(ac_orch_missing)
  [ -z "$missing" ] \
    || { echo "BUG [orchestrator-roster]: the orchestrator's agents: list omits shipped agent(s):" \
           $missing; exit 1; }
  # Prove the list check can fail: a contract the list does not name must be reported by name.
  # The probe is removed before the verdict, so a red here leaves no stray file in _agents/.
  : > "$probe"
  missing=$(ac_orch_missing)
  rm -f "$probe"
  [ "$missing" = zz-roster-probe ] \
    || { echo "BUG [orchestrator-roster]: an agent missing from the list was not reported by name" \
           "(got: '$missing')"; exit 1; }
  echo "  ok [orchestrator-roster] — orchestrator.agent.md is on the strong-tier pin, its agents:" \
    "list names every other shipped agent, and an unlisted probe agent is reported by name"
}
