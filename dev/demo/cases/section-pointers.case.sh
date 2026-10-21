#!/usr/bin/env bash
# section-pointers.case.sh — [section-pointers]: every pointer into the constitution lands on a
# section that exists. SOURCED by the runner; see dev/scripts/run-demo.sh.
#
# The constitution is numbered (§1–§22) and the agents, AGENTS.md's reading list, the operator
# guide and the scripts' own messages cite those numbers. A renumbering or a retired name that
# leaves a pointer behind sends an agent to read the wrong rules, and nothing else would notice:
# the links checker sees Markdown links, not "§11.3" in prose or a script's printed fix line.

SP_CON=estate/CONSTITUTION.md

# sp_cited_sections — every §N / §N.M cited by the files that point agents into the constitution.
sp_cited_sections() {
  grep -ohE '§[0-9]+(\.[0-9]+)?' AGENTS.md estate/_agents/*.agent.md estate/_harness/scripts/* \
    "estate/General Human Knowledge/Harness Guide.md" "$SP_CON" | sort -u
}

# 1. Each cited number has its heading: "## N. Title" for a section, "### N.M Title" below it.
sp_numbers_resolve() {
  local s n missing=""
  echo "--- [section-pointers]: constitution pointers resolve; retired names are gone ---"
  while IFS= read -r s; do
    n=${s#§}
    case "$n" in
      *.*) grep -qE "^### ${n//./\\.} " "$SP_CON" || missing="$missing $s" ;;
      *)   grep -qE "^## ${n}\. " "$SP_CON" || missing="$missing $s" ;;
    esac
  done < <(sp_cited_sections)
  [ -z "$missing" ] \
    || { echo "BUG [section-pointers-resolve]: cited section(s) with no heading in $SP_CON:$missing"; \
         exit 1; }
  echo "  ok [section-pointers-resolve] — every cited §-number has its constitution heading"
}

# 2. The retired "backbone PART I" pointer survives in no agent, script or root document.
sp_retired_names() {
  local hits
  hits=$(grep -lE 'backbone PART|PART I'"'"'s' AGENTS.md estate/_agents/*.agent.md \
    estate/_harness/scripts/* "$SP_CON" 2>/dev/null || true)
  [ -z "$hits" ] \
    || { echo "BUG [section-pointers-retired]: these files still point at the retired" \
           "'backbone PART I' name:"; printf '  %s\n' $hits; exit 1; }
  echo "  ok [section-pointers-retired] — no agent, script or root document cites the retired name"
}

# 3. The validator's printed fix for a missing Current State names the numbered section, executed
#    in a throwaway estate (the validator resolves its root from its own location).
sp_validator_fix_line() {
  local fix out
  fix=$(mktemp -d)
  cp -R estate/_harness "$fix/_harness"
  mkdir -p "$fix/Tickets/202601A-PROJ-1"
  printf '# PROJ-1\n\n## %s - fixture\n- seeded\n' "$(date +%Y%m%d%H%M%S)" \
    > "$fix/Tickets/202601A-PROJ-1/202601A-PROJ-1.md"
  set +e; out=$(HARNESS_STATE_DIR="$fix/.state" bash "$fix/_harness/scripts/check-ticket-log.sh" 2>&1); set -e
  rm -rf "$fix"
  printf '%s\n' "$out" | grep -F "missing '## Current State'" | grep -qF 'CONSTITUTION §5' \
    || { echo "BUG [section-pointers-validator]: the missing-Current-State fix line does not" \
           "name CONSTITUTION §5:"; printf '%s\n' "$out"; exit 1; }
  echo "  ok [section-pointers-validator] — the validator's fix line names CONSTITUTION §5"
}

case_section_pointers() {
  sp_numbers_resolve
  sp_retired_names
  sp_validator_fix_line
}
