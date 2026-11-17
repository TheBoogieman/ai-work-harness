#!/usr/bin/env bash
# ticket-files.case.sh — every retained file of a ticket folder is reachable from its ticket file
# (#397). SOURCED by the runner; see dev/scripts/run-demo.sh for the contract.
#
# #384 linked prompts, outputs and reviews. Everything else a ticket folder holds — notebooks,
# scripts, SQL, logs, extracts, screenshots, dropped inputs — had no link, so a reader of the record
# could not reach it. ticket-files.py now owns a generated "## Ticket files" block, refreshed by the
# entry helper. Five guards:
#   [ticket-files-entry]     an entry adds the block in the same write: every retained file, any
#                            depth or extension, Logs/ and Dump/ included; housekeeping, the ledger
#                            files Iterations links and the notes the index links left out; text
#                            outside the markers, Current State and older entries untouched; a
#                            second entry changes nothing; added, removed and renamed files follow.
#   [ticket-files-encoding]  awkward names produce links the checker's own parser resolves to the
#                            file, and the checker counts every file reachable.
#   [ticket-files-atomic]    broken markers and an unreadable folder refuse with the ticket
#                            byte-identical; symlinks and another checkout are never followed.
#   [ticket-files-backfill]  the backfill links the section and the knowledge index of an older,
#                            closed ticket with one entry, keeps it closed, is idempotent, and puts
#                            the index back when a ticket's entry is refused.
#   [ticket-files-template]  a ticket made by init-ticket.sh from a customised template has working
#                            one-way links (ticket -> index; notebooks by their real names).
# The validator's linked-index rule is in index-grammar.case.sh, the checker's coverage note in
# work-map.case.sh, beside the rules they extend.

tf_hash() { { shasum -a 256 "$1" 2>/dev/null || sha256sum "$1" 2>/dev/null; } | cut -d' ' -f1; }

# tf_block MD — the generated block of a ticket file, markers included.
tf_block() { awk '/^<!-- ticket-files:begin/ { on = 1 } on { print } /^<!-- ticket-files:end/ { on = 0 }' "$1"; }

# tf_resolves MD — every link in the block decodes, through check-work-map.py's own parser, to a
# file that exists in the ticket folder; prints the decoded paths, one per line, or fails.
tf_resolves() {
  python3 - "$1" "$PWD/estate/_harness/scripts/check-work-map.py" <<'PY'
import importlib.util, pathlib, sys, urllib.parse
md, helper = pathlib.Path(sys.argv[1]), sys.argv[2]
spec = importlib.util.spec_from_file_location("cwm", helper); cwm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cwm)
text = md.read_text(encoding="utf-8")
block = text[text.index("<!-- ticket-files:begin"):text.index("<!-- ticket-files:end")]
for _, raw, _ in cwm.routes(cwm.prose(block)):
    rel = urllib.parse.unquote(urllib.parse.urlsplit(raw).path)
    if not (md.parent / rel).is_file():
        sys.exit(f"unresolved: {raw}")
    print(rel)
PY
}

# [ticket-files-entry] The success path runs first on purpose: on the pre-fix helper the entry is
#   appended and no section appears, so the first assertion is the one that reds.
#   REVERT-PROVABLE: drop the ticket-files.py call from append-session-entry.sh and this reds.
tf_entry() {
  echo "--- ticket-files: an entry links every retained file of the ticket folder ---"
  TF1="estate/Tickets/202608A-PROJ-51"; local md="$TF1/202608A-PROJ-51.md" helper out rc before cs intro listed f
  helper="estate/_harness/scripts/append-session-entry.sh"
  r09_make "$TF1"
  mkdir -p "$TF1/Logs" "$TF1/Dump/nested/deep" "$TF1/SQL" "$TF1/__pycache__" "$TF1/.ipynb_checkpoints"
  for f in Logs/03-build.txt "Dump/extract (1).csv" Dump/nested/deep/shot.png SQL/q.sql run.sh \
           AI-Knowledge/note.md Agent-Prompts/01-load.md; do printf 'x\n' > "$TF1/$f"; done
  printf -- '- note.md — [Read note](note.md) — a note — read before loading\n' >> "$TF1/AI-Knowledge/_index.md"
  for f in .DS_Store Logs/.gitkeep __pycache__/m.cpython-312.pyc .ipynb_checkpoints/q-checkpoint.ipynb "~\$draft.docx"; do
    printf 'x\n' > "$TF1/$f"
  done
  sleep 1
  before=$(awk '/^## Session Log/ { on = 1 } on' "$md")
  cs=$(awk '/^## Current State/,/^## Background/' "$md")
  intro=$(awk '/^## Ticket files/ { getline; print }' "$md")

  set +e; out=$(printf -- '- Loaded the feed; logs for this step are in [build output](Logs/03-build.txt), script [run.sh](run.sh).\n' \
                | bash "$helper" "$md" "ticket files probe" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] || { echo "BUG [ticket-files-entry]: the helper failed (rc $rc):"; printf '%s\n' "$out"; exit 1; }
  [ -n "$(tf_block "$md")" ] \
    || { echo "BUG [ticket-files-entry]: the entry added no Ticket files block"; exit 1; }
  listed=$(tf_resolves "$md") || { echo "BUG [ticket-files-entry]: a block link does not resolve: $listed"; exit 1; }
  for f in Logs/03-build.txt "Dump/extract (1).csv" Dump/nested/deep/shot.png SQL/q.sql run.sh \
           Checks/checks_master.ipynb Checks/scratch.sql; do
    printf '%s\n' "$listed" | grep -Fxq -- "$f" \
      || { echo "BUG [ticket-files-entry]: retained file $f is not linked from the block:"; tf_block "$md"; exit 1; }
  done
  # Owned elsewhere or housekeeping: never listed one by one.
  for f in AI-Knowledge/note.md Agent-Prompts/01-load.md .DS_Store Logs/.gitkeep \
           __pycache__/m.cpython-312.pyc .ipynb_checkpoints/q-checkpoint.ipynb "~\$draft.docx" 202608A-PROJ-51.md; do
    if printf '%s\n' "$listed" | grep -Fxq -- "$f"; then
      echo "BUG [ticket-files-entry]: $f is listed, but it is owned elsewhere or housekeeping:"; tf_block "$md"; exit 1
    fi
  done
  grep -qFx -- '- [Ticket knowledge index](AI-Knowledge/_index.md) — links each knowledge note.' "$md" \
    && grep -qFx -- '- Prompts, outputs and reviews: linked under Iterations.' "$md" \
    || { echo "BUG [ticket-files-entry]: the block does not route notes through the index and the" \
           "ledger through Iterations:"; tf_block "$md"; exit 1; }
  printf '%s\n' "$out" | grep -q '^Ticket files refreshed: ' \
    || { echo "BUG [ticket-files-entry]: the helper did not report the refresh:"; printf '%s\n' "$out"; exit 1; }
  [ "$(awk '/^## Session Log/ { on = 1 } on' "$md" | head -n "$(printf '%s\n' "$before" | wc -l | tr -d ' ')")" = "$before" ] \
    && [ "$(awk '/^## Current State/,/^## Background/' "$md")" = "$cs" ] \
    && [ "$(awk '/^## Ticket files/ { getline; print }' "$md")" = "$intro" ] \
    || { echo "BUG [ticket-files-entry]: the refresh changed an older entry, Current State or the" \
           "text outside the markers"; exit 1; }
  [ "$(grep -n '^## Ticket files$' "$md" | cut -d: -f1)" -lt "$(grep -n '^## Session Log$' "$md" | cut -d: -f1)" ] \
    || { echo "BUG [ticket-files-entry]: the section is not above the Session Log"; exit 1; }
  set +e; out=$(bash estate/_harness/scripts/check-ticket-log.sh 2>&1); set -e
  printf '%s\n' "$out" | grep -q 'OK: 202608A-PROJ-51 validated' \
    || { echo "BUG [ticket-files-entry]: the validator refused the ticket:"; printf '%s\n' "$out" | grep 202608A; exit 1; }
  [ -z "$(find "$TF1" -name '.append-session-entry.*' -o -name '.ticket-files.*' -o -name '.iteration-links.*')" ] \
    || { echo "BUG [ticket-files-entry]: a helper temp file was left behind"; exit 1; }

  # A second entry with nothing new leaves the block byte-identical and says nothing about it.
  before=$(tf_block "$md"); sleep 1
  set +e; out=$(printf -- '- nothing new\n' | bash "$helper" "$md" "second probe" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] && [ "$(tf_block "$md")" = "$before" ] && ! printf '%s\n' "$out" | grep -q 'Ticket files refreshed' \
    || { echo "BUG [ticket-files-entry]: an entry with no file change rewrote the block:"; printf '%s\n' "$out"; exit 1; }

  # Added, removed and renamed files follow at the next entry; the older entry that linked run.sh
  # keeps its words (history is never rewritten), and only the generated link goes.
  printf 'x\n' > "$TF1/Logs/04-rerun.txt"; rm "$TF1/run.sh"; mv "$TF1/SQL/q.sql" "$TF1/SQL/query v2.sql"
  sleep 1
  set +e; out=$(printf -- '- reran the load\n' | bash "$helper" "$md" "third probe" 2>&1); rc=$?; set -e
  listed=$(tf_resolves "$md") || { echo "BUG [ticket-files-entry]: a stale link survived: $listed"; exit 1; }
  printf '%s\n' "$listed" | grep -Fxq 'Logs/04-rerun.txt' && printf '%s\n' "$listed" | grep -Fxq 'SQL/query v2.sql' \
    && ! printf '%s\n' "$listed" | grep -Fxq 'run.sh' && ! printf '%s\n' "$listed" | grep -Fxq 'SQL/q.sql' \
    || { echo "BUG [ticket-files-entry]: an added, removed or renamed file did not follow:"; tf_block "$md"; exit 1; }
  grep -qF 'script [run.sh](run.sh).' "$md" \
    || { echo "BUG [ticket-files-entry]: the older entry's link to a deleted file was rewritten"; exit 1; }
  echo "  ok [ticket-files-entry] — an entry links every retained file (Logs and Dump included) by" \
    "folder, leaves housekeeping and owned files out, keeps history, and follows adds, removals and renames"
  rm -rf "$TF1"
}

# [ticket-files-encoding] Names a Markdown reader or Obsidian could trip on. The proof does not use
#   ticket-files.py's own encoder: each destination is read back by check-work-map.py's parser and
#   decoded, and must land on the file; the checker must then count every file reachable.
#   REVERT-PROVABLE: write destinations unencoded and the parenthesis and space names red.
tf_encoding() {
  echo "--- ticket-files: awkward file names link to the right file ---"
  local root md out listed name want=0
  root=$(mktemp -d); mkdir -p "$root/Tickets/202608B-PROJ-52/Dump" "$root/_harness"
  cp -R estate/_harness/scripts "$root/_harness/"
  md="$root/Tickets/202608B-PROJ-52/202608B-PROJ-52.md"
  printf '# PROJ-52 — Names\n\n## Current State\n- Now: active.\n\n## Session Log\n\n## 20260101000000 - Start\n- x\n' > "$md"
  for name in "a b.txt" "p(1).csv" "pct%20.txt" "amp & co, ltd.txt" "ünï ✓.txt" "[br].txt" "_under_.txt" \
              "tick\`.txt" "hash#1.log" "q?.txt" "colon:x.txt"; do
    # A platform that refuses a name (Windows: ? and :) simply does not get that case.
    printf 'x\n' > "$root/Tickets/202608B-PROJ-52/Dump/$name" 2>/dev/null && want=$((want + 1))
  done
  out=$(python3 "$root/_harness/scripts/ticket-files.py" --write "$md" 2>&1) \
    || { echo "BUG [ticket-files-encoding]: the helper failed:"; printf '%s\n' "$out"; rm -rf "$root"; exit 1; }
  listed=$(tf_resolves "$md") \
    || { echo "BUG [ticket-files-encoding]: a link does not resolve to its file: $listed"; tf_block "$md"; rm -rf "$root"; exit 1; }
  [ "$(printf '%s\n' "$listed" | grep -c .)" -eq "$want" ] \
    || { echo "BUG [ticket-files-encoding]: $want files, but the links resolve to:"; printf '%s\n' "$listed"; rm -rf "$root"; exit 1; }
  if [ -f "$root/Tickets/202608B-PROJ-52/Dump/hash#1.log" ]; then
    printf '%s\n' "$out" | grep -q 'NOTE: .*hash#1.log — Obsidian cannot open' \
      || { echo "BUG [ticket-files-encoding]: no NOTE for a name Obsidian cannot link:"; printf '%s\n' "$out"; rm -rf "$root"; exit 1; }
  fi
  out=$(python3 "$root/_harness/scripts/check-work-map.py" --root "$root" --json)
  python3 -c 'import json,sys; c=json.loads(sys.argv[1])["coverage"]; sys.exit(not (c["ticket_files"] == c["ticket_files_linked"] == int(sys.argv[2])))' \
    "$out" "$want" \
    || { echo "BUG [ticket-files-encoding]: the checker does not count every file reachable:"; printf '%s\n' "$out"; rm -rf "$root"; exit 1; }
  out=$(python3 "$root/_harness/scripts/ticket-files.py" --write "$md" 2>&1)
  printf '%s\n' "$out" | grep -q '^UP TO DATE: ' \
    || { echo "BUG [ticket-files-encoding]: a second write was not a no-op:"; printf '%s\n' "$out"; rm -rf "$root"; exit 1; }
  echo "  ok [ticket-files-encoding] — spaces, parentheses, brackets, %, &, commas, backticks, #, ?," \
    "colons and Unicode resolve through the checker's parser; a second write changes nothing"
  rm -rf "$root"
}

# [ticket-files-atomic] What must never be written over: broken markers and an unreadable folder
#   refuse the entry with the ticket byte-identical; a symlink and another checkout are named and
#   never followed.
#   REVERT-PROVABLE: make split_section accept repeated markers and the first refusal reds.
tf_atomic() {
  echo "--- ticket-files: refusals leave the ticket unchanged; links are never followed ---"
  TF3="estate/Tickets/202608C-PROJ-53"; local md="$TF3/202608C-PROJ-53.md" helper h out rc outside
  helper="estate/_harness/scripts/append-session-entry.sh"
  r09_make "$TF3"; sleep 1
  awk '{ print } /^<!-- ticket-files:end/ { print "<!-- ticket-files:begin -->" }' "$md" > "$md.tmp" && mv "$md.tmp" "$md"
  printf '\n## %s - hand fix\n- x\n' "$(date +%Y%m%d%H%M%S)" >> "$md"; sleep 1
  h=$(tf_hash "$md")
  set +e; out=$(printf -- '- y\n' | bash "$helper" "$md" "marker probe" 2>&1); rc=$?; set -e
  [ "$rc" -eq 2 ] && [ "$(tf_hash "$md")" = "$h" ] && printf '%s\n' "$out" | grep -q 'ticket-files markers' \
    || { echo "BUG [ticket-files-atomic]: broken markers did not refuse the entry unchanged (rc $rc):"; \
         printf '%s\n' "$out"; exit 1; }
  r09_make "$TF3"; sleep 1
  mkdir -p "$TF3/Dump/locked"; printf 'x\n' > "$TF3/Dump/locked/a.csv"; chmod 000 "$TF3/Dump/locked"
  if ls "$TF3/Dump/locked" >/dev/null 2>&1; then
    echo "  SKIP [ticket-files-atomic-unreadable]: this user can still list a mode-000 folder (root, or Windows)"
  else
    h=$(tf_hash "$md")
    set +e; out=$(printf -- '- y\n' | bash "$helper" "$md" "unreadable probe" 2>&1); rc=$?; set -e
    [ "$rc" -eq 2 ] && [ "$(tf_hash "$md")" = "$h" ] && printf '%s\n' "$out" | grep -q 'cannot list Dump/locked' \
      || { chmod 755 "$TF3/Dump/locked"; echo "BUG [ticket-files-atomic]: an unreadable folder did not refuse" \
           "the entry unchanged (rc $rc):"; printf '%s\n' "$out"; exit 1; }
  fi
  chmod 755 "$TF3/Dump/locked"; rm -rf "$TF3/Dump/locked"
  mkdir -p "$TF3/vendor/checkout/.git"; printf 'x\n' > "$TF3/vendor/checkout/code.py"
  outside=$(mktemp -d); printf 'x\n' > "$outside/secret.csv"
  if ln -s "$outside" "$TF3/Dump/elsewhere" 2>/dev/null && ln -s "$outside/secret.csv" "$TF3/Dump/link.csv" 2>/dev/null \
     && [ -L "$TF3/Dump/elsewhere" ]; then
    set +e; out=$(printf -- '- z\n' | bash "$helper" "$md" "link probe" 2>&1); rc=$?; set -e
    [ "$rc" -eq 0 ] && ! tf_block "$md" | grep -qE 'secret\.csv|elsewhere|link\.csv|code\.py' \
      && printf '%s\n' "$out" | grep -q 'SKIPPED: .*Dump/elsewhere — symlink, not followed' \
      && printf '%s\n' "$out" | grep -q 'SKIPPED: .*vendor/checkout/ — another checkout' \
      || { rm -rf "$outside"; echo "BUG [ticket-files-atomic]: a symlink or another checkout was followed" \
           "or not reported (rc $rc):"; printf '%s\n' "$out"; tf_block "$md"; exit 1; }
  else
    echo "  SKIP [ticket-files-atomic-symlink]: this platform cannot create symlinks; the Linux/macOS CI lanes run it"
  fi
  rm -rf "$outside"
  echo "  ok [ticket-files-atomic] — broken markers and an unreadable folder refuse with the ticket" \
    "byte-identical; symlinks and another checkout are reported, never followed"
  rm -rf "$TF3"
}

# tf_make ROOT NAME — a ticket from the shipped template in another estate root, with one entry:
# r09_make's recipe, for a temporary estate that can hold its own General AI-Knowledge.
tf_make() {
  local dir="$1/Tickets/$2"
  cp -R estate/Tickets/999912Z-PROJ-99999 "$dir"; mv "$dir/999912Z-PROJ-99999.md" "$dir/$2.md"
  printf '\n## %s - probe\n- x\n' "$(date +%Y%m%d%H%M%S)" >> "$dir/$2.md"
}

# [ticket-files-backfill] An older ticket, closed, with a bare index entry, a tombstone, an unlinked
#   prompt and loose files; one already in shape; one whose log cannot take an entry. In a temporary
#   estate, so the promoted topic it needs never lands in this repository's shipped tree.
#   REVERT-PROVABLE: delete estate/_harness/scripts/backfill-ticket-files.sh and this reds at once.
tf_backfill() {
  echo "--- ticket-files: the backfill links older tickets once, by one entry each ---"
  local root tool out rc h4 h5 h6 i6 old cs n t md4 md5 md6 TF4 TF5 TF6
  root=$(mktemp -d); mkdir -p "$root/Tickets" "$root/_harness" "$root/General AI-Knowledge/Probe Topic"
  cp -R estate/_harness/scripts "$root/_harness/"; tool="$root/_harness/scripts/backfill-ticket-files.sh"
  printf '# Topic\n' > "$root/General AI-Knowledge/Probe Topic/Probe Topic.md"
  TF4="$root/Tickets/202608D-PROJ-54"; TF5="$root/Tickets/202608E-PROJ-55"; TF6="$root/Tickets/202608F-PROJ-56"
  md4="$TF4/202608D-PROJ-54.md"; md5="$TF5/202608E-PROJ-55.md"; md6="$TF6/202608F-PROJ-56.md"
  for t in 202608D-PROJ-54 202608E-PROJ-55 202608F-PROJ-56; do
    tf_make "$root" "$t"
    # An older ticket: no Ticket files section yet, as before #397.
    awk '/^## Ticket files/ { skip = 1; next } skip && /^## / { skip = 0 } !skip' "$root/Tickets/$t/$t.md" > "$root/x.tmp" \
      && mv "$root/x.tmp" "$root/Tickets/$t/$t.md"
  done
  # A real, closed ticket: a heading with no placeholder (so the checker reads it) and a closed Now.
  awk '{ if ($0 ~ /^- Now:/) print "- Now: Closed — delivered 2026-01-02, tracker Done";
         else if ($0 ~ /^# PROJ-99999/) print "# PROJ-54 — Backfill probe"; else print }' "$md4" > "$root/x.tmp" && mv "$root/x.tmp" "$md4"
  printf 'x\n' > "$TF4/AI-Knowledge/old-note.md"; printf 'x\n' > "$TF4/Logs/run.log"
  printf '# PROJ-54 — Prompt 01: Load\n' > "$TF4/Agent-Prompts/01-load.md"
  printf -- '- old-note.md — what it covers — when to read it\n- gone.md (promoted -> General AI-Knowledge/Probe Topic)\n' \
    >> "$TF4/AI-Knowledge/_index.md"
  python3 "$root/_harness/scripts/ticket-files.py" --write "$md5" >/dev/null
  printf 'x\n' > "$TF6/AI-Knowledge/n.md"; printf -- '- n.md — covers — when\n' >> "$TF6/AI-Knowledge/_index.md"
  # A newest entry dated ahead of the clock: the helper refuses to append behind it.
  printf '\n## 29991231235959 - dated ahead of the clock\n- x\n' >> "$md6"
  sleep 1
  h4=$(tf_hash "$md4"); h5=$(tf_hash "$md5"); h6=$(tf_hash "$md6"); i6=$(tf_hash "$TF6/AI-Knowledge/_index.md")
  old=$(awk '/^## Session Log/ { on = 1 } on' "$md4"); cs=$(awk '/^## Current State/,/^## Background/' "$md4")
  n=$(grep -cE '^## [0-9]{14} - ' "$md4")

  set +e; out=$(bash "$tool" --dry-run 2>&1); rc=$?; set -e
  printf '%s\n' "$out" | grep -q 'WOULD LINK: 202608D-PROJ-54 — .*index: 2 entr(ies); iterations: 1 file(s)' \
    && [ "$(tf_hash "$md4")" = "$h4" ] \
    || { echo "BUG [ticket-files-backfill]: the dry run did not list the work, or wrote (rc $rc):"; printf '%s\n' "$out"; rm -rf "$root"; exit 1; }

  set +e; out=$(bash "$tool" 2>&1); rc=$?; set -e
  printf '%s\n' "$out" | grep -q 'LINKED: 202608D-PROJ-54' && printf '%s\n' "$out" | grep -q 'SKIPPED: 202608F-PROJ-56' \
    && [ "$rc" -ne 0 ] \
    || { echo "BUG [ticket-files-backfill]: the run did not link one ticket and report the other (rc $rc):"; printf '%s\n' "$out"; rm -rf "$root"; exit 1; }
  tf_resolves "$md4" | grep -Fxq 'Logs/run.log' \
    && grep -qF '[prompt](Agent-Prompts/01-load.md)' "$md4" \
    && grep -qFx -- '- old-note.md — [Read note](old-note.md) — what it covers — when to read it' "$TF4/AI-Knowledge/_index.md" \
    && grep -qF '(promoted -> General AI-Knowledge/Probe Topic) — [Read promoted note](../../../General%20AI-Knowledge/Probe%20Topic/Probe%20Topic.md)' "$TF4/AI-Knowledge/_index.md" \
    || { echo "BUG [ticket-files-backfill]: the section, Iterations or index links are missing:"; \
         cat "$TF4/AI-Knowledge/_index.md"; tf_block "$md4"; rm -rf "$root"; exit 1; }
  [ "$(grep -cE '^## [0-9]{14} - ' "$md4")" -eq $((n + 1)) ] \
    && [ "$(awk '/^## Session Log/ { on = 1 } on' "$md4" | head -n "$(printf '%s\n' "$old" | wc -l | tr -d ' ')")" = "$old" ] \
    && [ "$(awk '/^## Current State/,/^## Background/' "$md4")" = "$cs" ] \
    || { echo "BUG [ticket-files-backfill]: not exactly one new entry, an older entry changed, or the" \
           "closed Current State moved"; rm -rf "$root"; exit 1; }
  [ "$(tf_hash "$md5")" = "$h5" ] && [ "$(tf_hash "$md6")" = "$h6" ] && [ "$(tf_hash "$TF6/AI-Knowledge/_index.md")" = "$i6" ] \
    || { echo "BUG [ticket-files-backfill]: a ticket in shape was written, or a refused ticket's index" \
           "was not put back"; rm -rf "$root"; exit 1; }
  # The backfill's own entry names files only as links, so the checker has nothing to note on it.
  out=$(python3 "$root/_harness/scripts/check-work-map.py" --root "$root" --json)
  if printf '%s\n' "$out" | python3 -c 'import json,sys; sys.exit(any(f["code"] == "UNLINKED_FILE" and "202608D" in f["path"] for f in json.load(sys.stdin)["findings"]))'; then :; else
    echo "BUG [ticket-files-backfill]: the backfill entry names a file without linking it (UNLINKED_FILE)"; rm -rf "$root"; exit 1
  fi
  set +e; out=$(bash "$root/_harness/scripts/check-ticket-log.sh" 2>&1); set -e
  if printf '%s\n' "$out" | grep -q 'FAIL: 202608D-PROJ-54'; then
    echo "BUG [ticket-files-backfill]: the validator refuses the backfilled ticket:"; printf '%s\n' "$out" | grep 202608D; rm -rf "$root"; exit 1
  fi
  h4=$(tf_hash "$md4")
  set +e; out=$(bash "$tool" --only 202608D-PROJ-54 --only 202608E-PROJ-55 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] && [ "$(tf_hash "$md4")" = "$h4" ] && printf '%s\n' "$out" | grep -q 'DONE: 0 ticket(s) changed, 2 already current' \
    || { echo "BUG [ticket-files-backfill]: a second run was not a no-op (rc $rc):"; printf '%s\n' "$out"; rm -rf "$root"; exit 1; }
  echo "  ok [ticket-files-backfill] — one entry links an older closed ticket's files, prompt and index" \
    "(entry and tombstone), keeps it closed and its history intact; a refused ticket's index is put back;" \
    "a second run does nothing"
  rm -rf "$root"
}

# [ticket-files-template] An estate customises its template (a renamed notebook, an extra SQL
#   folder) and refreshes it; init-ticket.sh copies it. Every link of the new ticket's block lands in
#   the new ticket, the knowledge index is linked one way only, and the copy is already in sync.
#   REVERT-PROVABLE: drop the Ticket files section from the shipped template and this reds.
tf_template() {
  echo "--- ticket-files: a new ticket inherits working links from its template ---"
  local root tpl out new md listed
  grep -q '^## Ticket files$' estate/Tickets/999912Z-PROJ-99999/999912Z-PROJ-99999.md \
    && grep -qF '](AI-Knowledge/_index.md)' estate/Tickets/999912Z-PROJ-99999/999912Z-PROJ-99999.md \
    || { echo "BUG [ticket-files-template]: the shipped template has no Ticket files section linking its index"; exit 1; }
  root=$(mktemp -d); mkdir -p "$root/Tickets" "$root/_harness"; cp -R estate/_harness/scripts "$root/_harness/"
  tpl="$root/Tickets/999912Z-TPL-99999"
  cp -R estate/Tickets/999912Z-PROJ-99999 "$tpl"; mv "$tpl/999912Z-PROJ-99999.md" "$tpl/999912Z-TPL-99999.md"
  mv "$tpl/Checks/checks_master.ipynb" "$tpl/Checks/team checks.ipynb"
  mkdir -p "$tpl/SQL/Warehouse"; printf '{}\n' > "$tpl/SQL/Warehouse/warehouse_examples.ipynb"
  python3 "$root/_harness/scripts/ticket-files.py" --write "$tpl/999912Z-TPL-99999.md" >/dev/null
  out=$(bash "$root/_harness/scripts/init-ticket.sh" --root "$root" --template "$tpl" --identity PROJ-57 2>&1) \
    || { echo "BUG [ticket-files-template]: init-ticket.sh failed:"; printf '%s\n' "$out"; rm -rf "$root"; exit 1; }
  new=$(find "$root/Tickets" -maxdepth 1 -name '*-PROJ-57' | head -1); md="$new/$(basename "$new").md"
  listed=$(tf_resolves "$md") \
    || { echo "BUG [ticket-files-template]: a link in the new ticket does not resolve: $listed"; rm -rf "$root"; exit 1; }
  printf '%s\n' "$listed" | grep -Fxq 'Checks/team checks.ipynb' \
    && printf '%s\n' "$listed" | grep -Fxq 'SQL/Warehouse/warehouse_examples.ipynb' \
    && printf '%s\n' "$listed" | grep -Fxq 'AI-Knowledge/_index.md' \
    || { echo "BUG [ticket-files-template]: the customised notebooks or the index are not linked:"; tf_block "$md"; rm -rf "$root"; exit 1; }
  python3 "$root/_harness/scripts/ticket-files.py" "$md" | grep -q '^UP TO DATE: ' \
    || { echo "BUG [ticket-files-template]: the copy is not already in sync with its files"; rm -rf "$root"; exit 1; }
  if grep -q '](\.\./' "$new/AI-Knowledge/_index.md"; then
    echo "BUG [ticket-files-template]: the knowledge index links back to the ticket; links are one way"; rm -rf "$root"; exit 1
  fi
  echo "  ok [ticket-files-template] — init-ticket.sh copies working one-way links: the index, and" \
    "notebooks under their customised names"
  rm -rf "$root"
}

case_ticket_files() {
  tf_entry
  tf_encoding
  tf_atomic
  tf_backfill
  tf_template
}
