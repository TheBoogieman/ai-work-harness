#!/usr/bin/env bash
# status-consolidation.case.sh — the awkward hooks path, the shipped hook schema, the zip fallback,
# the stale-commit WARN and the uncommitted-work WARN. SOURCED by the runner; see
# dev/scripts/run-demo.sh.

# [awkward-hooks-path] — the hooks-parse check must work when the path contains a character that
# would BREAK a Python source-string literal. A single quote is the reliable case (a space or plain
# unicode does NOT break the literal, verified); it reproduces the #8/R-05 "path corrupts the
# source string" class on ANY host — the Git-Bash MSYS case is the same class. We point status at
# an awkward-named copy of the real hooks file via HARNESS_HOOKS_FILE and assert it still parses
# OK. (The Git-Bash MSYS-path FORMAT half additionally wants a Git-Bash witness; the cygpath branch
# is dormant/untested on this host.)
sk_awkward_hooks_path() {
  local G8DIR G8 G8_OUT
  echo "--- status consolidation (awkward hooks path, zip fallback, stale-commit and" \
    "uncommitted WARNs) ---"
  G8DIR=$(mktemp -d); G8="$G8DIR/quote'inside hooks.json"
  cp estate/_harness/hooks/hooks.example.json "$G8"
  set +e
  G8_OUT=$(HARNESS_HOOKS_FILE="$G8" bash estate/_harness/scripts/harness-status.sh 2>&1)
  set -e
  printf '%s\n' "$G8_OUT" | grep -q "OK: hooks config parses." \
    || { echo "BUG [awkward-hooks-path]: valid JSON at an awkward (quote-bearing) path was NOT" \
           "parsed — the argv fix regressed:"; printf '%s\n' "$G8_OUT" | grep -i hooks; exit 1; }
  printf '%s\n' "$G8_OUT" | grep -q "hooks config is invalid JSON" \
    && { echo "BUG [awkward-hooks-path]: awkward path wrongly reported as invalid JSON" \
           "(source-string mangling):"; printf '%s\n' "$G8_OUT" | grep -i hooks; exit 1; }
  rm -rf "$G8DIR"
  echo "  ok [awkward-hooks-path] — quote-bearing path parses OK"
}

# [hooks-schema] STRUCTURAL check of the SHIPPED, witnessed hooks.example.json — it must parse and
# carry the deployment-proven shape: top-level "version", the three camelCase events NESTED UNDER a
# "hooks" wrapper (NOT top-level — the proven v4 config wraps them), entries keyed on "bash" with
# NO legacy "command"/"toolFilter". This is STRUCTURE ONLY: it does NOT and must not pretend to
# witness a hook firing — the live fire stayed an honest human-witnessed box (#44 cond 3).
# Revert-provable: drop the "hooks" wrapper, a wrapped event key, or the "bash" key and this reds.
# (A guard that passed a wrapper-less config is exactly the bug to catch.)
sk_hooks_schema() {
  local HS44_OUT
  if ! HS44_OUT=$(python3 - "estate/_harness/hooks/hooks.example.json" <<'PY' 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("version") == 1, "top-level 'version' must be 1"
hooks = d.get("hooks")
assert isinstance(hooks, dict), "events must be nested under a 'hooks' wrapper object"
for e in ("sessionStart", "postToolUse", "sessionEnd"):
    msg = f"missing or empty wrapped event: hooks.{e}"
    assert e in hooks and isinstance(hooks[e], list) and hooks[e], msg
    for entry in hooks[e]:
        assert "bash" in entry, f"hooks.{e}: entry missing the verified 'bash' key"
        assert "command" not in entry, f"hooks.{e}: entry carries the legacy 'command' key"
        assert "toolFilter" not in entry, f"hooks.{e}: entry carries the legacy 'toolFilter' key"
PY
  ); then
    echo "BUG [hooks-schema]: the shipped hooks.example.json failed its verified-schema" \
      "structural check:"
    printf '%s\n' "$HS44_OUT"
    exit 1
  fi
  echo "  ok [hooks-schema] — hooks.example.json parses;" \
    "hooks.{sessionStart,postToolUse,sessionEnd} present; verified 'bash' shape, no legacy" \
    "command/toolFilter"
}

# [pack-without-zip] — with the zip CLI unavailable the context pack must still build via the
# Python zipfile fallback (python3 is already required). HARNESS_PACK_NO_ZIP=1 forces the fallback
# deterministically (cleaner than PATH surgery, and it exercises the exact fallback path). Assert
# the pack is produced and is a readable archive.
sk_pack_without_zip() {
  local G14_OUT_DIR G14_OUT G14_RC g14zip
  G14_OUT_DIR=$(mktemp -d)
  set +e; G14_OUT=$(HARNESS_PACK_NO_ZIP=1 PACK_OUT_DIR="$G14_OUT_DIR" \
    bash estate/_harness/scripts/make-context-pack.sh --ticket 999911Z-PROJ-99998 2>&1)
  G14_RC=$?; set -e
  [ "$G14_RC" -eq 0 ] \
    || { echo "BUG [pack-without-zip]: pack failed with zip forced off (rc=$G14_RC):"; \
         printf '%s\n' "$G14_OUT"; exit 1; }
  # A no-match must not trip set -e / pipefail, hence the `|| true`.
  g14zip=$(ls "$G14_OUT_DIR"/harness-pack-*.zip 2>/dev/null | head -1 || true)
  { [ -n "$g14zip" ] \
    && python3 -c \
         'import zipfile,sys; sys.exit(1 if zipfile.ZipFile(sys.argv[1]).testzip() else 0)' \
         "$g14zip" 2>/dev/null; } \
    || { echo "BUG [pack-without-zip]: no readable pack archive produced by the fallback:"; \
         printf '%s\n' "$G14_OUT"; exit 1; }
  rm -rf "$G14_OUT_DIR"
  echo "  ok [pack-without-zip] — Python zipfile fallback produced a readable archive"
}

# [stale-commit-warn] — status must nudge (WARN) when session activity is newer than the last
# commit + margin (auto-commit may have silently stopped), and stay silent otherwise; either way
# exit 0 (yellow). The check is HARNESS_DEMO-suppressed, so this sets HARNESS_LIVENESS_FORCE to
# exercise the real code. Both directions are driven deterministically by the margin knob against a
# scratch ticket dated NEXT YEAR: margin 0 → the future session outpaces the commit → WARN fires; a
# ~30-year margin → even a next-year session is within margin → no WARN. HARNESS_DEMO stays set so
# the remote reads as a NOTE (rc 0), isolating the nudge from the estate's exit code.
sk_stale_commit_warn() {
  local R11T r11md r11_nyr R11_OUT R11_RC R11_OUT2
  R11T="estate/Tickets/202607L-PROJ-11"; r11md="$R11T/202607L-PROJ-11.md"
  r09_make "$R11T"
  r11_nyr=$(( $(date +%Y) + 1 ))    # next year → a session-header epoch always beyond 'now'
  printf '\n## %s0101000000 - future-dated session\n- work newer than the last commit\n' \
    "$r11_nyr" >> "$r11md"
  set +e; R11_OUT=$(HARNESS_LIVENESS_FORCE=1 HARNESS_COMMIT_LAG_WARN_S=0 \
    bash estate/_harness/scripts/harness-status.sh 2>&1); R11_RC=$?; set -e
  printf '%s\n' "$R11_OUT" | grep -q "recent session activity" \
    || { echo "BUG [stale-commit-warn]: session activity newer than the last commit did NOT raise" \
           "the stale-commit WARN:"; printf '%s\n' "$R11_OUT"; exit 1; }
  [ "$R11_RC" -eq 0 ] \
    || { echo "BUG [stale-commit-warn]: the stale-commit nudge must be yellow (exit 0), got" \
           "rc=$R11_RC"; exit 1; }
  set +e; R11_OUT2=$(HARNESS_LIVENESS_FORCE=1 HARNESS_COMMIT_LAG_WARN_S=999999999 \
    bash estate/_harness/scripts/harness-status.sh 2>&1); set -e
  printf '%s\n' "$R11_OUT2" | grep -q "recent session activity" \
    && { echo "BUG [stale-commit-warn]: stale-commit WARN fired while within the lag margin" \
           "(commit current):"; printf '%s\n' "$R11_OUT2"; exit 1; }
  rm -rf "$R11T"
  echo "  ok [stale-commit-warn] — fires when session activity outpaces the last commit," \
    "silent within margin"
}

# [uncommitted-warn] (#306) — status must say whether the work is COMMITTED, not only when the last
# commit was. The defect it guards: on a fresh estate with work left uncommitted, the report said
# only "last commit 0 seconds ago" (the installer's commit) and stayed green. Built on a REAL
# rehearsal install, run as a user's machine runs it: HARNESS_DEMO removed (it suppresses the check)
# and HARNESS_WARN_STATE_FILE removed, so the aging record lands at its real in-estate path and the
# exclusion of status's own write is exercised too. The agent deploy dir points at the rehearsal's
# own, so the clean estate exits 0 and the exit code isolates this check. Three assertions:
#   1. dirty tree → the WARN fires, the recency line is STILL printed, and the exit stays 0 (yellow,
#      never red — uncommitted work is not damage);
#   2. after a hand commit → the OK coverage line prints and the WARN is gone;
#   3. a SECOND run after that still reads clean — status wrote its own aging record on the run
#      before, and counting that write would flip the report back to dirty after every commit.
# REVERT-PROOF: remove check_uncommitted from main() and assertion 1 reds by name.
uw_status() {  # run the estate's own status as a user would; stdout+stderr to stdout
  ( cd "$UW_EST" && env -u HARNESS_DEMO -u HARNESS_WARN_STATE_FILE \
      HARNESS_AGENT_DEPLOY_DIR="$UW_EST/_rehearsal/agents" \
      HARNESS_STATE_DIR="$UW_EST/_rehearsal/state" \
      bash _harness/scripts/harness-status.sh 2>&1 )
}
sk_uncommitted_warn() {
  local UW_ROOT UW_EST UW_OUT UW_RC
  UW_ROOT=$(mktemp -d); UW_EST="$UW_ROOT/Work"
  bash estate/install.sh --yes --rehearsal "$UW_EST" >"$UW_ROOT/install.out" 2>&1 \
    || { echo "BUG [uncommitted-warn]: could not build the rehearsal estate:"; \
         tail -5 "$UW_ROOT/install.out"; exit 1; }
  git -C "$UW_EST" config user.email harness@localhost
  git -C "$UW_EST" config user.name "harness demo"
  # A day's work by hand, uncommitted: one modified record and one whole new ticket.
  printf '\n## 20260101000001 - hand edit\n- uncommitted\n' \
    >> "$UW_EST/Tickets/999912Z-PROJ-99999/999912Z-PROJ-99999.md"
  mkdir -p "$UW_EST/Tickets/202607A-PROJ-306"
  cp "$UW_EST/Tickets/999912Z-PROJ-99999/999912Z-PROJ-99999.md" \
     "$UW_EST/Tickets/202607A-PROJ-306/202607A-PROJ-306.md"
  set +e; UW_OUT=$(uw_status); UW_RC=$?; set -e
  printf '%s\n' "$UW_OUT" | grep -q "^WARN: 2 uncommitted change(s) in the estate" \
    || { echo "BUG [uncommitted-warn]: a dirty estate (2 uncommitted changes) did NOT raise the" \
           "uncommitted WARN — the report answered only WHEN the last commit was:"; \
         printf '%s\n' "$UW_OUT"; exit 1; }
  printf '%s\n' "$UW_OUT" | grep -q "^OK: work repo present; last commit" \
    || { echo "BUG [uncommitted-warn]: the recency line was removed — it must stay beside the" \
           "coverage line, not be replaced by it:"; printf '%s\n' "$UW_OUT"; exit 1; }
  [ "$UW_RC" -eq 0 ] \
    || { echo "BUG [uncommitted-warn]: uncommitted work must be yellow (exit 0), got rc=$UW_RC:"; \
         printf '%s\n' "$UW_OUT"; exit 1; }
  git -C "$UW_EST" add -A && git -C "$UW_EST" commit -q -m "by hand"
  set +e; UW_OUT=$(uw_status); set -e
  { printf '%s\n' "$UW_OUT" | grep -q "^OK: nothing uncommitted" \
    && ! printf '%s\n' "$UW_OUT" | grep -q "uncommitted change(s)"; } \
    || { echo "BUG [uncommitted-warn]: after a hand commit the report did not read clean:"; \
         printf '%s\n' "$UW_OUT"; exit 1; }
  set +e; UW_OUT=$(uw_status); set -e
  printf '%s\n' "$UW_OUT" | grep -q "^OK: nothing uncommitted" \
    || { echo "BUG [uncommitted-warn]: the run after a clean one reads dirty — status counted its" \
           "own aging-record write as uncommitted work:"; printf '%s\n' "$UW_OUT"; \
         git -C "$UW_EST" status --short; exit 1; }
  rm -rf "$UW_ROOT"
  echo "  ok [uncommitted-warn] — dirty estate WARNs (exit 0) beside the recency line;" \
    "clean after a hand commit, and stays clean on the next run"
}

case_status_consolidation() {
  sk_awkward_hooks_path
  sk_hooks_schema
  sk_pack_without_zip
  sk_stale_commit_warn
  sk_uncommitted_warn
}
