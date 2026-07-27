#!/usr/bin/env bash
# oversize-root.case.sh — [oversize-root-warn]: a ticket whose TRACKED root (excluding the ignored
# Logs/, Dump/) grows large gets a yellow WARN prescribing Dump/ — never a block. SOURCED by the
# runner; see dev/scripts/run_demo.sh.
#
# It also proves Dump/ is EXCLUDED from the measure (so moving scratch there actually clears it)
# and that the knob is honoured both ways. ~2 MiB of padding lands the root over a 1 MiB threshold.

case_oversize_root() {
  local O O38 O38_RC O38b O38c
  O="estate/Tickets/202607E-PROJ-888"; mkdir -p "$O"
  cat > "$O/202607E-PROJ-888.md" <<'MD'
# 202607E-PROJ-888
## Current State
Oversize-root fixture for #38.
## Session Log
## 20260705120000 - fixture
MD
  head -c 2097152 /dev/zero > "$O/big-scratch.bin"     # ~2 MiB in the TRACKED root
  # (1) oversized root -> WARN fires with the Dump/ prescription, exit 0 (yellow)
  set +e
  O38=$(HARNESS_TICKET_WARN_MB=1 bash estate/_harness/scripts/harness-status.sh 2>&1); O38_RC=$?
  set -e
  printf '%s\n' "$O38" | grep -qE 'Tickets/202607E-PROJ-888 tracks .* in its root' \
    || { echo "BUG [oversize-root-warn]: oversized ticket root did not fire the WARN:"; \
         printf '%s\n' "$O38"; exit 1; }
  printf '%s\n' "$O38" | grep -q 'Dump/' \
    || { echo "BUG [oversize-root-warn]: the WARN did not prescribe Dump/:"; \
         printf '%s\n' "$O38"; exit 1; }
  [ "$O38_RC" -eq 0 ] \
    || { echo "BUG [oversize-root-warn]: the size nudge must be yellow (exit 0), got rc=$O38_RC"; \
         exit 1; }
  # (2) move padding into Dump/ -> WARN must NOT fire (Dump/ is excluded; the prescription works)
  mkdir -p "$O/Dump"; mv "$O/big-scratch.bin" "$O/Dump/big-scratch.bin"
  set +e; O38b=$(HARNESS_TICKET_WARN_MB=1 bash estate/_harness/scripts/harness-status.sh 2>&1); set -e
  printf '%s\n' "$O38b" | grep -qE 'Tickets/202607E-PROJ-888 tracks .* in its root' \
    && { echo "BUG [oversize-root-warn]: moving scratch to Dump/ did NOT clear the WARN" \
           "(Dump/ not excluded):"; printf '%s\n' "$O38b"; exit 1; }
  # (3) knob honoured: a huge threshold silences it even with padding back in the root
  mv "$O/Dump/big-scratch.bin" "$O/big-scratch.bin"
  set +e
  O38c=$(HARNESS_TICKET_WARN_MB=1000000 bash estate/_harness/scripts/harness-status.sh 2>&1)
  set -e
  printf '%s\n' "$O38c" | grep -qE 'Tickets/202607E-PROJ-888 tracks .* in its root' \
    && { echo "BUG [oversize-root-warn]: the size nudge fired while under the knob threshold:"; \
         printf '%s\n' "$O38c"; exit 1; }
  rm -rf "$O"
  echo "  ok [oversize-root-warn] — fires with Dump/ prescription (yellow), clears when scratch" \
    "moves to Dump/, honours the knob"
}
