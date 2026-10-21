#!/usr/bin/env bash
# tracker-sweep.case.sh — [tracker-sweep]: the on-demand board-drift report, stub-based and
# zero-network. SOURCED by the runner; see dev/scripts/run-demo.sh.
#
# tracker-sweep.sh reads each active ticket's upstream status through a PLUGGABLE fetch seam and
# WARNs per divergence. Three properties must hold or the tool lies. The whole family runs against
# a THROWAWAY Tickets/ fixture (HARNESS_WORK_ROOT) driven by LOCAL stub fetchers — no real
# ticket,
# no network. No credential material appears anywhere below, not even a fake-looking one.

# ts_fixture — two conforming tickets in the fixture estate: one will read 'closed' upstream (the
# divergence), one 'open' (no divergence). Presence of the folder IS the local fact ("active"); no
# .md needed. Plus the two stub fetchers the sweep is pointed at.
ts_fixture() {
  echo "--- [tracker-sweep]: board-drift sweep WARNs divergences, fails open, reaches nothing ---"
  G81_ROOT=$(mktemp -d)
  mkdir -p "$G81_ROOT/Tickets/202607A-PROJ-1" "$G81_ROOT/Tickets/202607B-PROJ-2"
  # Divergence stub: maps ticket id -> upstream status. 202607A-PROJ-1 is closed on the board while
  # still present (active) locally — the exact drift #81 exists to surface; every other id is open.
  cat > "$G81_ROOT/stub-diverge.sh" <<'G81_STUB'
#!/usr/bin/env bash
case "$1" in
  202607A-PROJ-1) echo closed ;;
  *)              echo open ;;
esac
G81_STUB
  # Unreachable stub: always exits non-zero, simulating a tracker that cannot be reached
  # (a dropped VPN).
  cat > "$G81_ROOT/stub-down.sh" <<'G81_STUB'
#!/usr/bin/env bash
exit 1
G81_STUB
  chmod +x "$G81_ROOT/stub-diverge.sh" "$G81_ROOT/stub-down.sh"
}

# 1. DIVERGENCE — a ticket closed upstream but active locally is WARNed WITH its fix named, and the
#    still-open ticket is NOT flagged. rc stays 0 (a WARN is yellow, it never blocks).
ts_divergence() {
  local G81_DIV G81_DIV_RC
  set +e
  G81_DIV=$(HARNESS_WORK_ROOT="$G81_ROOT" HARNESS_TRACKER_FETCH_CMD="$G81_ROOT/stub-diverge.sh" \
    bash estate/_harness/scripts/tracker-sweep.sh 2>&1); G81_DIV_RC=$?
  set -e
  printf '%s\n' "$G81_DIV" | grep -qE '^WARN: 202607A-PROJ-1 .*board.*active locally' \
    && printf '%s\n' "$G81_DIV" | grep -qi 'reconcile' \
    || { echo "BUG [tracker-divergence]: a ticket closed upstream but active locally was not" \
           "WARNed with its fix named"; echo "$G81_DIV"; exit 1; }
  printf '%s\n' "$G81_DIV" | grep -q '202607B-PROJ-2' \
    && { echo "BUG [tracker-divergence]: an open (non-diverging) ticket was flagged — only" \
           "closed-upstream/active-locally tickets divergence"; echo "$G81_DIV"; exit 1; }
  [ "$G81_DIV_RC" -eq 0 ] \
    || { echo "BUG [tracker-divergence]: a divergence report exited non-zero ($G81_DIV_RC) — a" \
           "WARN is yellow and must never red"; exit 1; }
  echo "  ok [tracker-divergence] — divergence WARNed with its fix, non-diverging ticket left" \
    "alone, rc=0"
}

# 2. FAILS OPEN — an unreachable tracker yields ONE quiet NOTE and rc=0, never a red and never a
#    WARN. This is the load-bearing property: a dropped VPN must not train users to ignore reds.
ts_fails_open() {
  local G81_DOWN G81_DOWN_RC
  set +e
  G81_DOWN=$(HARNESS_WORK_ROOT="$G81_ROOT" HARNESS_TRACKER_FETCH_CMD="$G81_ROOT/stub-down.sh" \
    bash estate/_harness/scripts/tracker-sweep.sh 2>&1); G81_DOWN_RC=$?
  set -e
  [ "$G81_DOWN_RC" -eq 0 ] \
    || { echo "BUG [tracker-fails-open]: an unreachable tracker did not fail open — expected" \
           "rc=0, got $G81_DOWN_RC (it must never red)"; echo "$G81_DOWN"; exit 1; }
  [ "$(printf '%s\n' "$G81_DOWN" | grep -c '^NOTE:')" -eq 1 ] \
    && ! printf '%s\n' "$G81_DOWN" | grep -q '^WARN:' \
    || { echo "BUG [tracker-fails-open]: an unreachable tracker did not fail open — expected" \
           "exactly ONE quiet NOTE and no WARN"; echo "$G81_DOWN"; exit 1; }
  echo "  ok [tracker-fails-open] — unreachable tracker fails open: one quiet NOTE, no WARN, rc=0"
}

# 3. ZERO NETWORK — the sweep must reach the board ONLY through the injected fetch seam, never on
#    its own. Prove the shipped script carries no network primitive, so even a misbehaving stub
#    cannot make the demo path reach out. Revert-proof: add a curl/wget to tracker-sweep.sh -> reds.
ts_zero_network() {
  local G81_NET
  G81_NET=$(grep -nE 'curl|wget|netcat|/dev/tcp' estate/_harness/scripts/tracker-sweep.sh || true)
  [ -z "$G81_NET" ] \
    || { echo "BUG [tracker-zero-network]: tracker-sweep.sh contains a network primitive — it" \
           "must reach out only through HARNESS_TRACKER_FETCH_CMD, never itself:"; \
         echo "$G81_NET"; exit 1; }
  echo "  ok [tracker-zero-network] — zero network in the sweep: it reaches the board only" \
    "through the injected fetch seam"
}

# 4. LOCAL STATE — a ticket is closed locally when its Current State reads "- Now: Closed", so the
#    sweep compares both sides: closed/closed is silent, closed upstream but open locally WARNs (as
#    above), closed locally but open upstream WARNs the other way, a stale "- Now: Closed" line that
#    sits in the Session Log (not Current State) is not a closure, and the year-9999 template is
#    never fetched. The stub fails for the template id, so fetching it would fail the run open with
#    a NOTE before any WARN — which is exactly how the pre-fix sweep behaved on a real estate.
ts_local_state() {
  local G9_ROOT G9_OUT
  G9_ROOT=$(mktemp -d)
  mkdir -p "$G9_ROOT/Tickets/202607C-PROJ-3" "$G9_ROOT/Tickets/202607D-PROJ-4" \
    "$G9_ROOT/Tickets/202607E-PROJ-5" "$G9_ROOT/Tickets/999912Z-PROJ-99999"
  printf '# PROJ-3\n\n## Current State\n- Now: Closed — merged, 2026-07-30, board\n' \
    > "$G9_ROOT/Tickets/202607C-PROJ-3/202607C-PROJ-3.md"
  printf '# PROJ-4\n\n## Current State\n- Now: Closed — abandoned, 2026-07-30, user\n' \
    > "$G9_ROOT/Tickets/202607D-PROJ-4/202607D-PROJ-4.md"
  printf '# PROJ-5\n\n## Current State\n- Now: in review\n\n## Session Log\n- Now: Closed (old note)\n' \
    > "$G9_ROOT/Tickets/202607E-PROJ-5/202607E-PROJ-5.md"
  printf '# PROJ-99999\n\n## Current State\n- Now: template only\n' \
    > "$G9_ROOT/Tickets/999912Z-PROJ-99999/999912Z-PROJ-99999.md"
  cat > "$G9_ROOT/stub.sh" <<'G9_STUB'
#!/usr/bin/env bash
case "$1" in
  999912Z-*)      exit 1 ;;
  202607C-PROJ-3) echo Done ;;
  *)              echo open ;;
esac
G9_STUB
  chmod +x "$G9_ROOT/stub.sh"
  G9_OUT=$(HARNESS_WORK_ROOT="$G9_ROOT" HARNESS_TRACKER_FETCH_CMD="$G9_ROOT/stub.sh" \
    bash estate/_harness/scripts/tracker-sweep.sh 2>&1)
  rm -rf "$G9_ROOT"
  printf '%s\n' "$G9_OUT" | grep -q '^NOTE:' \
    && { echo "BUG [tracker-template-skipped]: the sweep fetched the year-9999 template and failed" \
           "open before checking a single real ticket:"; echo "$G9_OUT"; exit 1; }
  printf '%s\n' "$G9_OUT" | grep -qE '^WARN: 202607D-PROJ-4 is closed locally' \
    || { echo "BUG [tracker-closed-locally]: a ticket closed locally but open on the board was not" \
           "WARNed:"; echo "$G9_OUT"; exit 1; }
  printf '%s\n' "$G9_OUT" | grep -qE '202607C-PROJ-3|202607E-PROJ-5' \
    && { echo "BUG [tracker-local-state]: closed/closed, or a stale Session Log line, was flagged" \
           "as drift:"; echo "$G9_OUT"; exit 1; }
  echo "  ok [tracker-local-state] — closed/closed silent, closed-locally-open-upstream WARNed," \
    "stale Session Log line ignored, template never fetched"
}

case_tracker_sweep() {
  ts_fixture
  ts_divergence
  ts_fails_open
  ts_zero_network
  ts_local_state
  rm -rf "$G81_ROOT"
}
