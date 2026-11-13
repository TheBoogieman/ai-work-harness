#!/usr/bin/env bash
# iteration-links.case.sh — every prompt, output and review file is linked from its ticket file
# (#384). SOURCED by the runner; see dev/scripts/run-demo.sh for the contract.
#
# The planner wrote Agent-Prompts/NN-<slug>.md, the implementer Agent-Output/NN-<slug>.md, and
# nothing linked either from the ticket file, so estates filled with files no reader could reach
# from the record. Three guards:
#   [iteration-links]    the entry helper links every unlinked file under "## Iterations" in the
#                        same write as the entry, adds to an iteration's existing line, and changes
#                        nothing else.
#   [iteration-unlinked] the validator fails a changed ticket that holds an unlinked file, by name.
#   [iteration-backfill] the backfill links older tickets with one new entry each, is idempotent,
#                        and leaves every older entry byte-identical.
# The work-map warning for a file named but not linked is [work-map-unlinked-file], in
# work-map.case.sh beside the other link notes.

il_hash() { { shasum -a 256 "$1" 2>/dev/null || sha256sum "$1" 2>/dev/null; } | cut -d' ' -f1; }

# il_fixture DIR — a conforming ticket holding one iteration's prompt and output and a review, none
# of them linked. The prompt carries the heading shape the planner writes.
il_fixture() {
  local dir="$1"
  r09_make "$dir"
  printf '# PROJ-1 — Prompt 01: Find the feed (read-only)\n\nbody\n' > "$dir/Agent-Prompts/01-find-feed.md"
  printf '# PROJ-1 — 01 find-feed output\n' > "$dir/Agent-Output/01-find-feed.md"
  printf '# PROJ-1 — 02 review\n' > "$dir/Agent-Output/02-review.md"
}

# [iteration-links] The SUCCESS case runs first on purpose: on the pre-fix helper the entry is
#   appended and no section appears, so the first assertion is the one that reds.
#   REVERT-PROVABLE: drop the iter_sync call from append-session-entry.sh and this reds on the
#   missing Iterations line.
il_helper_links() {
  echo "--- iteration-links: an entry links the ticket's prompt, output and review files ---"
  IL1="estate/Tickets/202607W-PROJ-43"; local md="$IL1/202607W-PROJ-43.md" helper out rc before
  helper="estate/_harness/scripts/append-session-entry.sh"
  il_fixture "$IL1"
  sleep 1
  before=$(awk '/^## Session Log/ { on = 1 } on' "$md")

  # 1. One entry links all three files, in a new section above the Session Log.
  set +e; out=$(printf -- '- first iteration done\n' | bash "$helper" "$md" "iteration probe" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] \
    || { echo "BUG [iteration-links]: the helper failed on a valid append (rc $rc):"; printf '%s\n' "$out"; exit 1; }
  grep -qFx -- '- 01 — Find the feed (read-only) — [prompt](Agent-Prompts/01-find-feed.md) · [output](Agent-Output/01-find-feed.md)' "$md" \
    || { echo "BUG [iteration-links]: iteration 01 has no line linking its prompt and output:"; \
         awk '/^## Iterations/,/^## Session Log/' "$md"; exit 1; }
  grep -qFx -- '- 02 — review — [review](Agent-Output/02-review.md)' "$md" \
    || { echo "BUG [iteration-links]: the review file has no line of its own:"; \
         awk '/^## Iterations/,/^## Session Log/' "$md"; exit 1; }
  printf '%s\n' "$out" | grep -qx 'Iterations linked: 3 file(s)' \
    || { echo "BUG [iteration-links]: the helper did not report the three files it linked:"; printf '%s\n' "$out"; exit 1; }
  [ "$(grep -n '^## Iterations$' "$md" | cut -d: -f1)" -lt "$(grep -n '^## Session Log$' "$md" | cut -d: -f1)" ] \
    || { echo "BUG [iteration-links]: the Iterations section is not above the Session Log"; exit 1; }
  # The log as it stood is still there, byte for byte, with the new entry after it.
  [ "$(awk '/^## Session Log/ { on = 1 } on' "$md" | head -n "$(printf '%s\n' "$before" | wc -l | tr -d ' ')")" = "$before" ] \
    || { echo "BUG [iteration-links]: linking changed an older Session Log entry"; exit 1; }
  [ "$(tail -1 "$md")" = "- first iteration done" ] \
    || { echo "BUG [iteration-links]: the entry is not the end of the file"; tail -3 "$md"; exit 1; }

  # 2. The validator accepts the result, and no temp file is left in the ticket folder.
  set +e; out=$(bash estate/_harness/scripts/check-ticket-log.sh 2>&1); rc=$?; set -e
  printf '%s\n' "$out" | grep -q 'OK: 202607W-PROJ-43 validated' \
    || { echo "BUG [iteration-links]: the validator did not accept the linked ticket:"; \
         printf '%s\n' "$out" | grep 202607W-PROJ-43; exit 1; }
  [ -z "$(find "$IL1" -maxdepth 1 -name '.*' -type f)" ] \
    || { echo "BUG [iteration-links]: a temp file was left in the ticket folder:"; ls -a "$IL1"; exit 1; }

  # 3. A later file of an iteration that already has a line is added to that line, after its last
  #    link, and what the scribe wrote on the line is kept. A new iteration gets a new line.
  awk '{ if ($0 ~ /^- 02 — review — /) print $0 " — passed, no findings"; else print }' "$md" > "$md.tmp" && mv "$md.tmp" "$md"
  printf '# PROJ-1 — Prompt 02: Fix the load\n' > "$IL1/Agent-Prompts/02-fix-load.md"
  printf '# out\n' > "$IL1/Agent-Output/03-recheck.md"
  sleep 1
  set +e; out=$(printf -- '- second iteration done\n' | bash "$helper" "$md" "second probe" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] \
    || { echo "BUG [iteration-links]: the second append failed (rc $rc):"; printf '%s\n' "$out"; exit 1; }
  grep -qFx -- '- 02 — review — [review](Agent-Output/02-review.md) · [prompt](Agent-Prompts/02-fix-load.md) — passed, no findings' "$md" \
    || { echo "BUG [iteration-links]: a later file was not added to its iteration's line, or the"; \
         echo "    words after the links were lost:"; awk '/^## Iterations/,/^## Session Log/' "$md"; exit 1; }
  grep -qFx -- '- 03 — recheck — [output](Agent-Output/03-recheck.md)' "$md" \
    || { echo "BUG [iteration-links]: a new iteration with no prompt got no line named from its file:"; \
         awk '/^## Iterations/,/^## Session Log/' "$md"; exit 1; }

  # 4. With nothing left to link, an entry changes nothing but the log.
  before=$(awk '/^## Iterations/,/^## Session Log/' "$md")
  sleep 1
  set +e; out=$(printf -- '- nothing new\n' | bash "$helper" "$md" "third probe" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] && [ "$(awk '/^## Iterations/,/^## Session Log/' "$md")" = "$before" ] \
    || { echo "BUG [iteration-links]: an entry with nothing to link changed the Iterations section"; exit 1; }
  if printf '%s\n' "$out" | grep -q 'Iterations linked'; then
    echo "BUG [iteration-links]: the helper reported links when there was nothing to link:"; printf '%s\n' "$out"; exit 1
  fi
  echo "  ok [iteration-links] — an entry links every unlinked prompt, output and review under" \
    "Iterations, adds to an existing line without losing its words, and leaves the log untouched"
  rm -rf "$IL1"
}

# [iteration-unlinked] A ticket changed by hand, with a hand-written entry, while it holds an
#   unlinked file: the entry satisfies the recency check, so only the new check can refuse it.
#   REVERT-PROVABLE: drop check_iterations from check-ticket-log.sh and the ticket validates.
il_validator_fails() {
  echo "--- iteration-links: the validator fails a changed ticket with an unlinked file ---"
  IL2="estate/Tickets/202607X-PROJ-44"; local md="$IL2/202607X-PROJ-44.md" out rc
  il_fixture "$IL2"
  set +e; out=$(bash estate/_harness/scripts/check-ticket-log.sh 2>&1); rc=$?; set -e
  [ "$rc" -ne 0 ] \
    || { echo "BUG [iteration-unlinked]: a ticket holding unlinked prompt, output and review files" \
           "passed validation:"; printf '%s\n' "$out" | grep 202607X-PROJ-44; exit 1; }
  printf '%s\n' "$out" | grep -q 'FAIL: 202607X-PROJ-44 file Agent-Prompts/01-find-feed.md is not linked' \
    && printf '%s\n' "$out" | grep -q 'FAIL: 202607X-PROJ-44 file Agent-Output/02-review.md is not linked' \
    || { echo "BUG [iteration-unlinked]: the validator did not name each unlinked file:"; \
         printf '%s\n' "$out" | grep 202607X-PROJ-44; exit 1; }
  # A link anywhere in the ticket file is enough: link all three by hand and it validates.
  printf '\nSee [p](Agent-Prompts/01-find-feed.md), [o](Agent-Output/01-find-feed.md), [r](Agent-Output/02-review.md).\n' >> "$md"
  set +e; out=$(bash estate/_harness/scripts/check-ticket-log.sh 2>&1); rc=$?; set -e
  printf '%s\n' "$out" | grep -q 'OK: 202607X-PROJ-44 validated' \
    || { echo "BUG [iteration-unlinked]: a ticket whose files are all linked was still refused:"; \
         printf '%s\n' "$out" | grep 202607X-PROJ-44; exit 1; }
  echo "  ok [iteration-unlinked] — an unlinked prompt, output or review fails its ticket by name," \
    "and a link anywhere in the ticket file clears it"
  rm -rf "$IL2"
}

# [iteration-backfill] Two older tickets: one with unlinked files, one with none. The dry run
#   writes nothing; the run links the first with one new entry and leaves the second alone; a
#   second run writes nothing.
#   REVERT-PROVABLE: delete estate/_harness/scripts/backfill-iterations.sh and this reds at once.
il_backfill() {
  echo "--- iteration-links: the backfill links older tickets once, by one entry each ---"
  IL3="estate/Tickets/202607Y-PROJ-45"; IL4="estate/Tickets/202607Z-PROJ-46"
  local md3="$IL3/202607Y-PROJ-45.md" md4="$IL4/202607Z-PROJ-46.md" tool out rc h3 h4 old n
  tool="estate/_harness/scripts/backfill-iterations.sh"
  il_fixture "$IL3"; r09_make "$IL4"
  sleep 1
  h3=$(il_hash "$md3"); h4=$(il_hash "$md4")
  old=$(awk '/^## Session Log/ { on = 1 } on' "$md3")
  n=$(grep -cE '^## [0-9]{14} - ' "$md3")

  set +e; out=$(bash "$tool" --dry-run 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q 'WOULD LINK: 202607Y-PROJ-45 — 3 file(s)' \
    || { echo "BUG [iteration-backfill]: the dry run did not list the ticket and its three files" \
           "(rc $rc):"; printf '%s\n' "$out"; exit 1; }
  [ "$(il_hash "$md3")" = "$h3" ] \
    || { echo "BUG [iteration-backfill]: the dry run wrote to a ticket"; exit 1; }

  set +e; out=$(bash "$tool" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q 'LINKED: 202607Y-PROJ-45 — 3 file(s)' \
    || { echo "BUG [iteration-backfill]: the run did not link the ticket (rc $rc):"; printf '%s\n' "$out"; exit 1; }
  grep -qF '[prompt](Agent-Prompts/01-find-feed.md) · [output](Agent-Output/01-find-feed.md)' "$md3" \
    && grep -qF '[review](Agent-Output/02-review.md)' "$md3" \
    || { echo "BUG [iteration-backfill]: the files are not linked after the run:"; \
         awk '/^## Iterations/,/^## Session Log/' "$md3"; exit 1; }
  [ "$(grep -cE '^## [0-9]{14} - ' "$md3")" -eq $((n + 1)) ] \
    || { echo "BUG [iteration-backfill]: the run did not add exactly one entry to the ticket"; exit 1; }
  [ "$(awk '/^## Session Log/ { on = 1 } on' "$md3" | head -n "$(printf '%s\n' "$old" | wc -l | tr -d ' ')")" = "$old" ] \
    || { echo "BUG [iteration-backfill]: the run changed an older Session Log entry"; exit 1; }
  [ "$(il_hash "$md4")" = "$h4" ] \
    || { echo "BUG [iteration-backfill]: the run wrote to a ticket that had nothing to link"; exit 1; }
  # The backfilled ticket is one the validator accepts: the entry is what keeps it green.
  set +e; out=$(bash estate/_harness/scripts/check-ticket-log.sh 2>&1); rc=$?; set -e
  if printf '%s\n' "$out" | grep -q 'FAIL: 202607Y-PROJ-45'; then
    echo "BUG [iteration-backfill]: the validator refuses the backfilled ticket:"
    printf '%s\n' "$out" | grep 202607Y-PROJ-45; exit 1
  fi

  h3=$(il_hash "$md3")
  set +e; out=$(bash "$tool" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] && [ "$(il_hash "$md3")" = "$h3" ] \
    && printf '%s\n' "$out" | grep -q 'DONE: 0 file(s) linked in 0 ticket(s)' \
    || { echo "BUG [iteration-backfill]: a second run was not a no-op (rc $rc):"; printf '%s\n' "$out"; exit 1; }
  echo "  ok [iteration-backfill] — the dry run writes nothing, the run links an older ticket with" \
    "one new entry and no change to older ones, and a second run does nothing"
  rm -rf "$IL3" "$IL4"
}

case_iteration_links() {
  il_helper_links
  il_validator_fails
  il_backfill
}
