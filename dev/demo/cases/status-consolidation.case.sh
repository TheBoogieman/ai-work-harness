#!/usr/bin/env bash
# status-consolidation.case.sh — the awkward hooks path, the shipped hook schema, the zip fallback
# and the stale-commit WARN. SOURCED by the runner; see dev/scripts/run_demo.sh.

# [awkward-hooks-path] — the hooks-parse check must work when the path contains a character that
# would BREAK a Python source-string literal. A single quote is the reliable case (a space or plain
# unicode does NOT break the literal, verified); it reproduces the #8/R-05 "path corrupts the
# source string" class on ANY host — the Git-Bash MSYS case is the same class. We point status at
# an awkward-named copy of the real hooks file via HARNESS_HOOKS_FILE and assert it still parses
# OK. (The Git-Bash MSYS-path FORMAT half additionally wants a Git-Bash witness; the cygpath branch
# is dormant/untested on this host.)
sk_awkward_hooks_path() {
  local G8DIR G8 G8_OUT
  echo "--- status consolidation (awkward hooks path, zip fallback, stale-commit WARN) ---"
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
    bash estate/_harness/scripts/make_context_pack.sh --ticket 999911Z-PROJ-99998 2>&1)
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

case_status_consolidation() {
  sk_awkward_hooks_path
  sk_hooks_schema
  sk_pack_without_zip
  sk_stale_commit_warn
}
