#!/usr/bin/env bash
# pack-audits-itself.case.sh — [pack-audits-itself] (#340): a context pack carries no term its scrub
# table names, including inside the pack's own copy of make-context-pack.sh. SOURCED by the runner;
# see dev/scripts/run-demo.sh.
#
# The pack stages every _harness/scripts/* file, make-context-pack.sh included, and that script holds
# the scrub table itself. The self-audit used to skip that file by name, so whatever the table names
# rode into every pack unchecked. The shipped placeholder rows hid it: a literal row scrubs its own
# text. A row written as a pattern does not, and its literal parts leaked while the MANIFEST said
# "zero scrub-table hits". The fixture is exactly that: a pattern seed whose literal part an audit
# term matches.
#
# THE SEED IS ASSEMBLED AT RUNTIME, never written contiguously in this file, so this file is never a
# carrier of it (the same belt-and-braces as [scrub-case-agree]). Own throwaway estate and pack dir:
# the fixture edits its own copy of the script, never the shipped one.
#
# THREE assertions: the build passes (exit 0); no file in the pack matches the audit term — the
# script's copy above all, which is what reds on the pre-fix code; and the copy still ships, with
# its table replaced by a marker rather than the file dropped from the pack.

case_pack_audits_itself() {
  local P340 P340_SEED P340_SCRIPT P340_RC P340_OUT P340_ZIP P340_HITS
  P340=$(mktemp -d)
  P340_SEED=$(printf 'zz%sseed' 340)
  mkdir -p "$P340/General AI-Knowledge/AI Harness"
  cp -R estate/_harness "$P340/_harness"
  P340_SCRIPT="$P340/_harness/scripts/make-context-pack.sh"
  # A pattern seed (the [a-z] keeps it from matching, and so scrubbing, its own text) and the audit
  # term that matches its literal part, as an operator seeding a home path would write them. awk to
  # a temp file (portable on GNU and BSD); the two lines reach it through ENVIRON, which, unlike -v,
  # leaves their backslashes alone.
  P340_ROW="  's|/[a-z]/Users/$P340_SEED|<home>|gI'" \
  P340_AUDIT="AUDIT_TERMS='Users[\\\\/]+$P340_SEED'" \
  awk '/^SCRUB=\(/     { print; print ENVIRON["P340_ROW"]; next }
       /^AUDIT_TERMS=/ { print ENVIRON["P340_AUDIT"]; next }
                       { print }' "$P340_SCRIPT" > "$P340_SCRIPT.tmp" \
    && mv "$P340_SCRIPT.tmp" "$P340_SCRIPT"
  grep -q "Users/$P340_SEED" "$P340_SCRIPT" \
    || { echo "BUG [pack-audits-itself]: the fixture failed to seed its own scrub table"; exit 1; }
  printf '# fixture note\nThe checkout lives at /c/Users/%s/work.\n' "$P340_SEED" \
    > "$P340/General AI-Knowledge/AI Harness/fixture-340.md"
  set +e
  P340_OUT=$(PACK_OUT_DIR="$P340/out" bash "$P340_SCRIPT" 2>&1); P340_RC=$?
  set -e
  P340_ZIP=$(ls "$P340"/out/harness-pack-*.zip 2>/dev/null | head -1 || true)
  P340_HITS=""
  if [ -n "$P340_ZIP" ]; then
    # Every file in the archive, read through Python's zipfile so no unzip flags differ by platform.
    P340_HITS=$(python3 - "$P340_ZIP" "$P340_SEED" <<'PY'
import re, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
pat = re.compile(r"Users[\\/]+" + re.escape(sys.argv[2]), re.I)
for n in z.namelist():
    if pat.search(z.read(n).decode("utf-8", "replace")):
        print(n)
PY
)
  fi
  local P340_HAS_COPY=0
  [ -n "$P340_ZIP" ] && python3 -c "import sys,zipfile; sys.exit(0 if '_harness/scripts/make-context-pack.sh' in zipfile.ZipFile(sys.argv[1]).namelist() else 1)" "$P340_ZIP" && P340_HAS_COPY=1
  rm -rf "$P340"
  [ "$P340_RC" -eq 0 ] \
    || { echo "BUG [pack-audits-itself]: the pack build failed (rc=$P340_RC):"; \
         printf '%s\n' "$P340_OUT"; exit 1; }
  [ -z "$P340_HITS" ] \
    || { echo "BUG [pack-audits-itself]: a scrub-table term reached the pack, unseen by the" \
           "self-audit, in:"; printf '  %s\n' $P340_HITS; exit 1; }
  [ "$P340_HAS_COPY" -eq 1 ] \
    || { echo "BUG [pack-audits-itself]: the pack no longer carries make-context-pack.sh — the" \
           "table must be blanked in the copy, not the file dropped"; exit 1; }
  echo "  ok [pack-audits-itself] — no scrub-table term in any packed file, the packer's own copy" \
    "included; that copy ships with its table blanked"
}
