#!/usr/bin/env bash
# retro-stats.case.sh — #85 [retro-counts]: retro_stats.sh is a DUMB counter, so a fixture estate
# with KNOWN ticket dates, checks, and promotions must yield KNOWN numbers. SOURCED by the runner.
#
# retro_stats derives the estate it scans from HARNESS_WORK_ROOT, so we point the REAL shipped
# script at a throwaway fixture (no copy of the script — the exact shipped code runs). Fixture:
# three conforming tickets (two committed in 2026-03, one in 2026-05, so their last-commit months
# are deterministic); ticket A carries two promotion tombstones; ticket C carries two checks
# appended via the real notebook helper (the template's own setup cell is NOT a check and is
# subtracted out). Revert-proof: break the counting in retro_stats.sh and this reds on the asserted
# numbers. Cleanup is an explicit rm on every exit path — the runner's single `trap ... EXIT`
# already owns the trap slot, so we add NO second one (#86).

# r85_commit ties a folder's LAST commit to a fixed date so its bucket month is deterministic.
r85_commit() {  # $1 = commit label, $2 = YYYY-MM-DD
  git -C "$R85" add -A >/dev/null
  GIT_AUTHOR_DATE="$2 12:00:00" GIT_COMMITTER_DATE="$2 12:00:00" \
    git -C "$R85" -c user.email=demo@local -c user.name=demo commit -qm "$1" >/dev/null
}

# rs_fixture — the throwaway fixture estate (its own git repo) and its three tickets.
rs_fixture() {
  local a b c
  echo "--- #85 retrospective: retro_stats counts a fixture estate ---"
  R85=$(mktemp -d)
  git -C "$R85" init -q
  mkdir -p "$R85/Tickets"
  # ticket A — March, with two promotion tombstones in its AI-Knowledge index.
  a="$R85/Tickets/202603A-PROJ-1"
  cp -r estate/Tickets/999912Z-PROJ-99999 "$a"
  mv "$a/999912Z-PROJ-99999.md" "$a/202603A-PROJ-1.md"
  printf -- '- foo.md (promoted -> General AI-Knowledge/Topic)\n' >> "$a/AI-Knowledge/_index.md"
  printf -- '- bar.md (promoted -> General AI-Knowledge/Other)\n' >> "$a/AI-Knowledge/_index.md"
  r85_commit 202603A-PROJ-1 2026-03-10
  # ticket B — March, no extras.
  b="$R85/Tickets/202603B-PROJ-2"
  cp -r estate/Tickets/999912Z-PROJ-99999 "$b"
  mv "$b/999912Z-PROJ-99999.md" "$b/202603B-PROJ-2.md"
  r85_commit 202603B-PROJ-2 2026-03-20
  # ticket C — May, with two captured checks appended through the real notebook helper.
  c="$R85/Tickets/202605A-PROJ-3"
  cp -r estate/Tickets/999912Z-PROJ-99999 "$c"
  mv "$c/999912Z-PROJ-99999.md" "$c/202605A-PROJ-3.md"
  python3 estate/_harness/scripts/append_notebook_cell.py "$c/Checks/checks_master.ipynb" \
    "check one" "SELECT 1;" >/dev/null
  python3 estate/_harness/scripts/append_notebook_cell.py "$c/Checks/checks_master.ipynb" \
    "check two" "SELECT 2;" >/dev/null
  r85_commit 202605A-PROJ-3 2026-05-05
}

rs_counts() {
  local R85_OUT R85_RC r85_need
  set +e
  R85_OUT=$(HARNESS_WORK_ROOT="$R85" bash estate/_harness/scripts/retro_stats.sh); R85_RC=$?
  set -e
  [ "$R85_RC" -eq 0 ] \
    || { echo "BUG [retro-counts]: retro_stats did not exit 0 on the fixture (rc=$R85_RC):"; \
         printf '%s\n' "$R85_OUT"; rm -rf "$R85"; exit 1; }
  for r85_need in "tickets-closed-total: 3" "  2026-03: 2" "  2026-05: 1" "checks-captured: 2" \
                  "knowledge-promoted: 2"; do
    printf '%s\n' "$R85_OUT" | grep -qF -- "$r85_need" \
      || { echo "BUG [retro-counts]: retro_stats miscounted the fixture — expected line" \
             "'$r85_need':"; printf '%s\n' "$R85_OUT"; rm -rf "$R85"; exit 1; }
  done
  echo "  ok [retro-counts] — retro_stats counts 3 tickets (2 in Mar, 1 in May), 2 checks," \
    "2 promotions on the fixture"
}

case_retro_stats() {
  rs_fixture
  rs_counts
  rm -rf "$R85"
}
