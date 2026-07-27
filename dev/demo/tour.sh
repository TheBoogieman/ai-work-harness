#!/usr/bin/env bash
# tour.sh — THE STAGE-BASED TOUR of the acceptance suite (#143). SOURCED by
# dev/scripts/run_demo.sh, never executed on its own: every unit here runs against the shared
# estate that runner builds ($S, $DEMO_ROOT, the temp deploy dir, the single EXIT trap).
#
# WHAT THIS FILE IS FOR, AND WHAT IT IS DELIBERATELY NOT. It is the demonstration a PERSON watches:
# six stage banners and the machinery a newcomer came to see actually running — the validator
# passing, a ticket built and validated, corruption refused, a notebook written, agents deployed,
# an agent broken and the estate prescribing the fix, a scrubbed context pack built. It carries no
# named guard. Every assertion the suite makes lives in a case file under cases/, because a
# regression suite and a demonstration are read by different people for different reasons, and the
# artifact that tries to be both is the one this split undoes.
#
# The tour is not assertion-free by accident of style: it runs under the runner's `set -e`, so
# every command here is still required to succeed. What it does not do is name a property and
# claim to have proven it — that is a case file's job, and a case file is where a reviewer looks.

# --- 1/6 -----------------------------------------------------------------------------------------
# Two validator passes over the untouched estate: the first does the work, the second is the
# vacuous rerun that must also pass (nothing changed, so nothing is re-validated).
tour_validator() {
  echo "=== 1/6 validator: first pass + vacuous rerun ==="
  bash estate/_harness/scripts/check_ticket_log.sh
  bash estate/_harness/scripts/check_ticket_log.sh
}

# --- 2/6 -----------------------------------------------------------------------------------------
# The happy path: clone the shipped template into the scratch ticket $S, give it a session-log
# entry and one indexed knowledge note, and watch the validator accept it.
tour_happy_path() {
  echo "=== 2/6 scratch ticket: happy path ==="
  cp -r estate/Tickets/999912Z-PROJ-99999 "$S"
  mv "$S/999912Z-PROJ-99999.md" "$S/999911Z-PROJ-99998.md"
  printf '\n## %s - Demo work session\n- Added the new field to the staging model\n' \
    "$(date +%Y%m%d%H%M%S)" >> "$S/999911Z-PROJ-99998.md"
  echo "- notes.md — platform quirk — read before editing" >> "$S/AI-Knowledge/_index.md"
  echo "quirk" > "$S/AI-Knowledge/notes.md"
  bash estate/_harness/scripts/check_ticket_log.sh
}

# --- 3/6 -----------------------------------------------------------------------------------------
# The banner only. The stage's substance is the index-grammar case family that follows it: ten
# cases proving honest records PASS and real breakage FAILs. That is where the corruption is
# staged and refused, and that is where a reviewer sabotaging this stage should look.
tour_corruption() {
  echo "=== 3/6 corruption must FAIL loudly (this is the point) ==="
}

# --- 4/6 -----------------------------------------------------------------------------------------
# The notebook helper writes a deterministic cell pair into the scratch ticket's checks notebook.
tour_notebook() {
  echo "=== 4/6 notebook helper (deterministic .ipynb writes) ==="
  python3 estate/_harness/scripts/append_notebook_cell.py "$S/Checks/checks_master.ipynb" \
    "check: row counts match" "SELECT COUNT(*) FROM model;"
}

# --- 5/6 -----------------------------------------------------------------------------------------
# Deploy the agents into the run's throwaway deploy dir. The break-and-restore demonstration that
# gives this stage its name is tour_break_restore below — it runs much later on purpose (see
# there), after the case families that must be witnessed even on a lane where a plain
# harness-status call aborts.
tour_deploy() {
  echo "=== 5/6 deploy + status; break an agent; watch it prescribe ==="
  bash estate/_harness/scripts/deploy_agents.sh
}

# Break-and-restore: the visible heart of stage 5, and the reason it is placed HERE rather than
# next to the stage banner. On a lane where a plain `harness-status` aborts under set -e (e.g. the
# Git-Bash issue #8), everything above has already been witnessed by the time this runs. The first
# call shows a healthy estate; then we remove a deployed agent and watch status prescribe the fix
# (its rc=1 is the point — the `|| echo` keeps the demo alive); restore it; and confirm the estate
# reads healthy again.
#
# #210 — the saved agent file goes to a PER-RUN mktemp path, never a fixed one. It used to be a
# machine-global name under the system temp root, so two demos running at once overwrote each
# other's save and BOTH restores then took the wrong file — the mechanical reason the "never
# overlap demo runs" instruction had to exist. ONE variable feeds BOTH the save and the restore
# below, so the pair cannot drift into a half-fix that randomises the save and leaves the restore
# pointing at the old location, which would be worse than the original defect. The [no-fixed-temp]
# case scans this file (and every other file of the suite) to keep that true.
tour_break_restore() {
  local dw_bak_dir dw_bak
  bash estate/_harness/scripts/harness-status.sh
  dw_bak_dir=$(mktemp -d)
  dw_bak="$dw_bak_dir/doc-writer.agent.md"
  mv "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md" "$dw_bak"
  bash estate/_harness/scripts/harness-status.sh || echo "--- correctly failed with a fix line ---"
  mv "$dw_bak" "$HARNESS_AGENT_DEPLOY_DIR/doc-writer.agent.md"
  rm -rf "$dw_bak_dir"
  # This line is the RESTORE's own check: status must read healthy again, and under set -e a
  # failure here aborts the demo. The [no-fixed-temp] case proves the save path was private; this
  # proves the file landed back.
  bash estate/_harness/scripts/harness-status.sh >/dev/null && echo "healthy after fix"
}

# --- 6/6 -----------------------------------------------------------------------------------------
# Build the scrubbed context pack for the scratch ticket into the run's shared PACK_OUT_DIR. What
# that directory must contain, and what the pack must have had scrubbed out of it, are the
# [one-pack-per-run] and [scrub-case-agree] cases that follow.
tour_context_pack() {
  echo "=== 6/6 scrubbed context pack + self-audit ==="
  bash estate/_harness/scripts/make_context_pack.sh --ticket 999911Z-PROJ-99998
}
