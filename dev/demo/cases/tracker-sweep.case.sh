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

case_tracker_sweep() {
  ts_fixture
  ts_divergence
  ts_fails_open
  ts_zero_network
  rm -rf "$G81_ROOT"
}
