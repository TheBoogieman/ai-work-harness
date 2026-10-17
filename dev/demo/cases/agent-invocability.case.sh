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
}
