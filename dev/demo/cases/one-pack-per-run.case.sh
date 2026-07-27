#!/usr/bin/env bash
# one-pack-per-run.case.sh — [one-pack-per-run]: the shared PACK_OUT_DIR must hold EXACTLY the one
# pack the tour's stage 6 just built, before anything globs it. SOURCED by the runner.
#
# Every other pack-building case ([space-named-pack], [pack-without-zip], [scrub-case-agree])
# writes to its OWN throwaway dir. Assert it, so a regression that drops a second pack here fails
# LOUDLY right here instead of as a cryptic `unzip` exit 11 when the glob matches two archives (the
# flake CI caught on the slower macOS runner). find (no -printf) is portable. Silent on success;
# the MANIFEST line it prints afterwards is the tour's own output, kept next to the check that
# makes globbing it safe.

case_one_pack_per_run() {
  local n_packs
  n_packs=$(find "$PACK_OUT_DIR" -maxdepth 1 -name 'harness-pack-*.zip' 2>/dev/null \
    | wc -l | tr -d ' ')
  [ "$n_packs" = "1" ] \
    || { echo "BUG [one-pack-per-run]: expected exactly 1 pack in PACK_OUT_DIR, found" \
           "$n_packs — a second pack makes the unzip glob ambiguous:"; \
         ls -1 "$PACK_OUT_DIR"; exit 1; }
  unzip -p "$PACK_OUT_DIR"/harness-pack-*.zip MANIFEST.txt | tail -1
}
