#!/usr/bin/env bash
# worked-example.case.sh — [worked-example] (#149): the worked-example document is EXECUTED, not
# read. SOURCED by the runner; see dev/scripts/run_demo.sh.
#
# WHAT IT DOES: builds a brand-new estate with install.sh, reads every fenced console block out of
# dev/a-day-with-the-harness.md, runs each block's commands inside that estate IN DOCUMENT ORDER,
# and compares what they printed against what the document says they printed.
#
# WHY THE COMPARISON IS ON OUTPUT AND NOT ON EXIT CODES. A check that only asserts the commands
# RAN proves the document's commands exist; it proves nothing about a single claim the document
# makes. That is the failure this case is built to avoid, and it is a QUIET one — nothing fails,
# the ok-line still prints, and the guarantee is gone. So the document states expected output
# verbatim and this compares it LITERALLY, line for line, and then on the block's line COUNT:
# output the document does not show is as much a difference as output it shows wrongly.
#
# THE SIX NORMALISED SPANS, and why normalising is not skipping. Six things in that output
# genuinely differ between machines and runs — where the estate is, how long ago the last commit
# was, two repository sizes, a session timestamp, and a context pack's own name. The document
# writes each as an angle-bracket span and says so out loud; we_normalise below rewrites exactly
# those spans in the ACTUAL output, one tight pattern per span, and every other character is
# compared as-is. A span is rewritten only where its pattern matches, so a line that lost its
# timestamp altogether still reds.
#   The template ticket's session stamp is a CONSTANT of the shipped template rather than a
#   machine-dependent span, so the document prints it literally and it is protected from the
#   timestamp rule (WE_TEMPLATE_TS below). If that stamp ever changes in the template this case
#   reds — correctly: the document would then print a stamp no estate carries.
#
# REVERT-PROOF: change ONE line of expected output in the document and this reds, naming the
# document, the block, the document's own line number, and both versions of the line.
#
# THE ENVIRONMENT IS A USER'S, NOT THE SUITE'S. The day's commands run with HARNESS_DEMO REMOVED
# (we_env), because that variable makes harness-status.sh treat two conditions more gently than a
# user's machine would, and a document checked under it would promise output no user ever sees.
# The four path overrides are the reverse: they keep this case's estate, agent deploy directory,
# validation stamps and context pack inside throwaway directories, so nothing here touches $HOME.
#
# WHAT THIS CASE DOES NOT PROVE, said plainly so a green is not over-read: that the document makes
# SENSE. It proves every command works and every printed line is true. Whether the prose around
# them explains anything is a human's judgement, and no assertion here reaches it.

# WE_DOC — the document under test. WE_TEMPLATE_TS — the session-log stamp the shipped template
# ticket carries; the normalisation note above says why it is named here.
WE_DOC=dev/a-day-with-the-harness.md
WE_TEMPLATE_TS=20260101000000

# we_esc — make a literal string safe to paste into an ERE. The two temp paths below go into sed
# expressions, and a mktemp path carries "." which would otherwise match any character.
we_esc() { printf '%s' "$1" | sed -E 's/[][\.*+?^$(){}|/]/\\&/g'; }

# we_line — line $2 of file $1, for the literal comparison and for the failure messages.
we_line() { awk -v n="$2" 'NR==n' "$1"; }

# we_count — how many lines a file holds, with the padding BSD wc prints removed.
we_count() { local n; n=$(wc -l < "$1"); printf '%s' "${n// /}"; }

# we_env — run a command as a USER's machine would run it: no HARNESS_DEMO, and every path the
# harness may write to pointed at this case's own throwaway directories.
we_env() {
  env -u HARNESS_DEMO \
    HARNESS_AGENT_DEPLOY_DIR="$WE_DEPLOY" HARNESS_STATE_DIR="$WE_STATE" \
    PACK_OUT_DIR="$WE_PACK" HARNESS_WARN_STATE_FILE="$WE_ROOT/warn-aging.tsv" "$@"
}

# we_fixture — the fresh installation the document assumes, plus the git identity it assumes. Both
# are stated in the document's own "What the day assumes" section; a real user already has an
# identity, so supplying one here is fixture, not a hidden step of the day.
we_fixture() {
  echo "--- #149 worked example: every command in $WE_DOC, run against a fresh estate ---"
  WE_ROOT=$(mktemp -d); WE_EST="$WE_ROOT/Work"
  WE_DEPLOY=$(mktemp -d); WE_STATE=$(mktemp -d); WE_PACK=$(mktemp -d)
  WE_TMP="$WE_ROOT/blocks"; mkdir -p "$WE_TMP"
  we_env bash estate/install.sh --yes "$WE_EST" >"$WE_ROOT/install.out" 2>&1 || we_no_estate
  # THE SUBJECT IS ASSERTED, never assumed: install.sh could exit 0 having laid nothing down, and
  # every block below would then fail for a reason that has nothing to do with the document.
  [ -f "$WE_EST/_harness/scripts/harness-status.sh" ] || we_no_estate
  git -C "$WE_EST" config user.email harness@localhost
  git -C "$WE_EST" config user.name "harness worked example"
}

# we_no_estate — one message for both ways the fixture can fail, because the consequence is the
# same: there is nothing for the document's commands to run against.
we_no_estate() {
  echo "BUG [worked-example]: could not build the fresh estate $WE_DOC is written against, so not"
  echo "  one of its commands was checked. install.sh's last words were:"
  tail -5 "$WE_ROOT/install.out" | sed 's/^/    /'
  exit 1
}

# we_parse — split the document into one command file, one expected-output file and one
# document-line-number file per console block. awk emits ONE tagged stream and the shell writes the
# files: awk writing them directly would hold three handles per block open at once, which some awks
# cap at a number this document would exceed.
we_parse() {
  local we_k we_n we_l we_t
  awk '
    /^```console$/ { n++; inb = 1; next }
    inb && /^```$/ { inb = 0; next }
    inb && substr($0, 1, 2) == "$ " { printf "C\t%d\t%d\t%s\n", n, NR, substr($0, 3); next }
    inb { printf "E\t%d\t%d\t%s\n", n, NR, $0; next }
    END { printf "N\t%d\n", n + 0 }
  ' "$WE_DOC" > "$WE_TMP/stream"
  WE_BLOCKS=0
  while IFS=$'\t' read -r we_k we_n we_l we_t; do
    case "$we_k" in
      C) printf '%s\n' "$we_t" >> "$WE_TMP/b$we_n.cmd" ;;
      E) printf '%s\n' "$we_t" >> "$WE_TMP/b$we_n.exp"
         printf '%s\n' "$we_l" >> "$WE_TMP/b$we_n.lno" ;;
      N) WE_BLOCKS=$we_n ;;
    esac
  done < "$WE_TMP/stream"
  we_parse_fill
}

# we_parse_fill — give every block all three files, empty where the block has none. A block that
# prints nothing (the commit block) writes no expected-output file, and every read below would then
# have to guess whether an absent file meant "no output" or "no such block".
we_parse_fill() {
  local we_b=1 we_x
  while [ "$we_b" -le "$WE_BLOCKS" ]; do
    for we_x in cmd exp lno; do
      [ -f "$WE_TMP/b$we_b.$we_x" ] || : > "$WE_TMP/b$we_b.$we_x"
    done
    we_b=$((we_b + 1))
  done
}

# we_floor — a FLOOR, not an expected count. A document that had lost its blocks, or whose fences
# had been renamed, would parse to nothing, and every comparison below would then pass by having
# nothing to compare — the one failure a green cannot show you. These numbers say "there is still a
# document here"; they sit far below what it holds, so ordinary edits never touch them.
# THE BLOCK COUNT IS TESTED FIRST, and the order is load-bearing: with no blocks parsed there are
# no per-block files for the glob below to match, so counting lines first died on cat's own error
# message instead of on this case's — a guard whose message never prints is not a guard.
we_floor() {
  [ "$WE_BLOCKS" -ge 6 ] || we_too_small "$WE_BLOCKS" 6 "console block(s)"
  WE_EXPLINES=$(cat "$WE_TMP"/b*.exp | wc -l | tr -d ' ')
  [ "$WE_EXPLINES" -ge 20 ] || we_too_small "$WE_EXPLINES" 20 "line(s) of expected output"
}

we_too_small() {  # $1 = what was found, $2 = the floor, $3 = what is being counted
  echo "BUG [worked-example]: $WE_DOC parsed to $1 $3, below the floor of $2 — there is not enough"
  echo "  of it left to check, and a comparison with nothing in it passes without proving anything."
  echo "  Restore the document's console blocks, or lower the floor here if it really did shrink."
  exit 1
}

# we_normalise — rewrite the six machine-dependent spans in ACTUAL output into the tokens the
# document prints for them. Each rule is as narrow as the span it stands for; anything a rule does
# not match survives into the literal comparison untouched.
we_normalise() {
  sed -E -e "s|$(we_esc "$WE_EST")|<ESTATE>|g" \
    -e "s|$(we_esc "$WE_PACK")|<PACK-DIR>|g" \
    -e 's/[0-9]+ (second|minute|hour)s? ago/<HOW-LONG-AGO>/g' \
    -e 's/[0-9]+\.[0-9] MiB/<SIZE> MiB/g' \
    -e "s/$WE_TEMPLATE_TS/@TEMPLATE-STAMP@/g" \
    -e 's/[0-9]{14}/<TIMESTAMP>/g' \
    -e "s/@TEMPLATE-STAMP@/$WE_TEMPLATE_TS/g" \
    -e 's/harness-pack-[0-9]{8}-[0-9]{4}\.zip/harness-pack-<PACK-STAMP>.zip/g'
}

# we_block_run — one block: its commands run as ONE shell session from the top of the estate, so
# that `echo $?` in the document reports the status of the command printed above it, exactly as a
# person at a terminal would see. `|| true` is load-bearing: one block's commands end non-zero on
# purpose (the document shows the validator refusing), and the runner's `set -e` would otherwise
# kill this case at the very line it exists to demonstrate.
we_block_run() {  # $1 = block number
  local we_b=$1
  ( cd "$WE_EST" && we_env bash "$WE_TMP/b$we_b.cmd" ) > "$WE_TMP/b$we_b.raw" 2>&1 || true
  we_normalise < "$WE_TMP/b$we_b.raw" > "$WE_TMP/b$we_b.act"
  we_block_compare "$we_b"
}

# we_block_compare — the literal comparison, line by line and then on the count.
we_block_compare() {  # $1 = block number
  local we_b=$1 we_i=1 we_ne we_na
  we_ne=$(we_count "$WE_TMP/b$we_b.exp"); we_na=$(we_count "$WE_TMP/b$we_b.act")
  while [ "$we_i" -le "$we_ne" ] && [ "$we_i" -le "$we_na" ]; do
    [ "$(we_line "$WE_TMP/b$we_b.exp" "$we_i")" = "$(we_line "$WE_TMP/b$we_b.act" "$we_i")" ] \
      || we_mismatch "$we_b" "$we_i"
    we_i=$((we_i + 1))
  done
  [ "$we_ne" -eq "$we_na" ] || we_count_off "$we_b" "$we_ne" "$we_na"
}

# we_where — the two lines that locate a failure for its reader: which document, which block, and
# the block's own first command. One home, because both failure messages below need it.
we_where() {  # $1 = block number
  echo "  Block $1 of $WE_DOC, whose first command is:"
  head -1 "$WE_TMP/b$1.cmd" | sed 's/^/    $ /'
}

we_mismatch() {  # $1 = block number, $2 = the differing line's position in the block
  echo "BUG [worked-example]: $WE_DOC no longer prints what the machinery prints."
  we_where "$1"
  echo "  $WE_DOC line $(we_line "$WE_TMP/b$1.lno" "$2") says the output is:"
  we_line "$WE_TMP/b$1.exp" "$2" | sed 's/^/    /'
  echo "  Running it actually produced:"
  we_line "$WE_TMP/b$1.act" "$2" | sed 's/^/    /'
  echo "  Fix ONE of the two: bring $WE_DOC into line with what the machinery now prints, or put"
  echo "  the machinery back. The document is EXECUTED, which is why a reworded message, a renamed"
  echo "  script or a moved version stamp reaches you here instead of rotting unread."
  exit 1
}

we_count_off() {  # $1 = block number, $2 = lines the document shows, $3 = lines actually printed
  echo "BUG [worked-example]: $WE_DOC shows $2 line(s) of output where $3 were printed."
  we_where "$1"
  echo "  A line the document does not show is a claim it is not making — an added WARN, a new"
  echo "  NOTE, a dropped line all land here. What was printed, in full:"
  sed 's/^/    /' "$WE_TMP/b$1.act"
  echo "  Bring $WE_DOC into line with it, or put the machinery back."
  exit 1
}

case_worked_example() {
  local we_b=1
  we_fixture
  we_parse
  we_floor
  while [ "$we_b" -le "$WE_BLOCKS" ]; do
    we_block_run "$we_b"
    we_b=$((we_b + 1))
  done
  rm -rf "$WE_ROOT" "$WE_DEPLOY" "$WE_STATE" "$WE_PACK"
  echo "  ok [worked-example] — every command in $WE_DOC ran in document order against a fresh" \
    "estate, and each printed EXACTLY what the document prints ($WE_BLOCKS blocks," \
    "$WE_EXPLINES output lines, compared literally apart from six named spans)"
}
