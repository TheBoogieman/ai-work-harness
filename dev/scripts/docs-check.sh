#!/usr/bin/env bash
# docs-check.sh — the documentation integrity check. FOUR DETECTORS, and they are the four that
# catch something a READER hits: a broken intra-repo link, an unclosed code fence, a carriage
# return in a document that ships LF-only, and a pointer to a file that no longer exists.
#
# IT USED TO CARRY TWENTY-ONE (#281). The other seventeen policed internal project doctrine —
# vocabulary rules, identifier grammar, one-home registries, decision-record shape, diagram
# currency notes — none of which a person outside this project ever reads, and all of which cost
# an implementer more attention than the defects they caught were worth. The four kept here are
# kept AS A SET: each guards a different way a document breaks for its reader, and none of them
# implies any of the others.
#
# DEV infrastructure: it never ships to a user estate, and no PRODUCT script references it. Pure
# greps, zero judgment, each detector's failure names its exact fix. The demo (dev/scripts/
# run-demo.sh) is what gates the product; this gates the prose. Two truths, two instruments.
#
# Run it from the repository root:  bash dev/scripts/docs-check.sh
set -uo pipefail
fail=0            # a COUNT of failures printed so far, never a boolean — see dc_fail below (#252)
# The document that owns the install steps. The dead-pointer detector sends a stale pointer here.
INSTALL_DOC=estate/INSTALL-INSTRUCTIONS.md

# dc_fail — the one output shape a detector prints when it finds something, in ONE home. A message
# is passed as SEVERAL arguments and joined with a single space, which is what lets a long message
# be wrapped across source lines without changing a byte of what is printed. IFS is pinned to a
# space for the join because a caller may be inside a `while IFS= read` loop.
#
# IT COUNTS, IT DOES NOT SET A FLAG (#252). A detector decides whether it found anything by
# comparing $fail against the value it saved before starting; under a set-once flag every such
# comparison degenerates to 1-against-1 after the first failure anywhere in the run. The gate's
# verdict is unchanged: the exit test at the foot still reads 0 as "nothing failed".
dc_fail() {
  local tag=$1 IFS=' '; shift
  printf 'FAIL [docs %s]: %s\n' "$tag" "$*"
  fail=$((fail+1))
}

# ================================================================================================
# THE SUBJECT ASSERTION (#269) — A DETECTOR EITHER READS WHAT IT CLAIMS TO READ, OR FAILS SAYING
# IT COULD NOT. A detector whose subject was absent used to conclude CLEAN, by three routes that
# all end in the same place: a grep over a path that is not there finds nothing; a loop over a list
# that could not be built runs zero times, so there is no iteration left to fail; and an error sent
# to /dev/null feeding an emptiness test makes "the tool broke" and "there was nothing" the same
# value. None of the three is distinguishable from a subject that is genuinely clean.
#
# All four surviving detectors scan the same set — every tracked *.md — so ONE helper makes the
# assertion for all of them. It still takes the caller's TAG: a red raised by a sibling that reads
# the same set is that sibling reporting, and each detector has to answer for its own blindness.
# dc_present — the SET form for a scan set built from the git index. A COUNT IN A MESSAGE IS NOT AN
# ASSERTION: the set can shrink to a fraction of itself and the success line simply prints the
# smaller number, which is how one ok-line here reported on three surfaces while naming the sixteen
# it used to read. Every path arriving on stdin must be a readable file. THE COUNT IS THE
# ASSERTION AND THE NAMES ARE ONLY A LEAD, so at most three are printed and the message says "first"
# rather than trailing an ellipsis — an ellipsis after the only missing path claims a truncation
# that did not happen, which is the same species of small untruth this whole item is about.
# Returns non-zero when anything was missing, so a caller may skip as well as report.
dc_present() {
  local pr_tag=$1 pr_f pr_gone="" pr_n=0 pr_seen=0
  while IFS= read -r pr_f; do
    [ -n "$pr_f" ] || continue          # an EMPTY set arrives as one blank line; it is not a path
    pr_seen=$((pr_seen+1))
    { [ -f "$pr_f" ] && [ -r "$pr_f" ]; } && continue
    pr_n=$((pr_n+1))
    [ "$pr_n" -le 3 ] && pr_gone="$pr_gone $pr_f"
  done
  # AN EMPTY SET IS THE SAME DEFECT ONE LEVEL UP, and it was found by watching this helper's own
  # reds: with the git index unreadable, `git ls-files` returns NOTHING rather than failing loudly,
  # so there was no member left to be missing and this assertion passed on a set that had never
  # been built. Every caller's surface is non-empty in any checkout of this repository, so zero is
  # never the real answer here — it is the answer a list gives when it could not be assembled.
  if [ "$pr_seen" -eq 0 ]; then
    dc_fail "$pr_tag" \
      "this detector's scan set came back EMPTY — it is built from the git index, and a list that" \
      "could not be assembled looks exactly like a subject with nothing wrong in it. Run this in" \
      "a checkout with a readable index; if the set is legitimately empty, this detector has no" \
      "subject left and belongs deleted rather than green."
    return 1
  fi
  [ "$pr_n" -eq 0 ] && return 0
  dc_fail "$pr_tag" \
    "$pr_n path(s) in this detector's scan set are not readable files (first: ${pr_gone# }) — it" \
    "takes its surface from the git index and used to drop a missing member without a word, so" \
    "its verdict covered fewer files than its message names. Restore them, or record the removal."
  return 1
}

# --- DOC-INTEGRITY (#51) — mechanical "no mangled doc" guards over every tracked *.md ------------
# The simplify pass rewrites prose into lists; lists are where half-closed fences and orphaned
# links are born. These detectors catch that mechanically instead of leaving it to a human
# eyeball. SCOPE: intra-repo only — external URLs and template placeholders are skipped, so this
# never reds on the network. Written for GNU grep (the dev seat is Cygwin); it is not run on
# macOS/BSD, which is the demo's territory.

# dc_md_files — the markdown scan set the three doc-integrity detectors below share, in ONE home so
# the set each asserts present is exactly the set each then reads (#269).
dc_md_files() { git ls-files '*.md'; }

# fence-balance — every *.md has an EVEN number of ``` markers (no code block left unclosed).
dc_fence_balance() {
  local f fences
  # THE MARKDOWN SET IS ASSERTED PRESENT (#269). `grep -c` on a path that is not there prints
  # nothing, the `|| true` turns its error into success, and an empty count is EVEN — so a document
  # this detector could not open was counted as balanced. That is all three failure shapes stacked
  # in one line, and it is the detector a four-line "assert the file exists, else do nothing"
  # repair was written for: such a repair passes an absence probe while seeing no unclosed fence at
  # all, which is why the assertion is added AROUND the existing read rather than in place of it.
  dc_present fence-balance < <(dc_md_files)
  while IFS= read -r f; do
    [ -f "$f" ] || continue          # already reported BY NAME above; reading it again only adds
                                     # a bare grep error to the log next to an honest message
    fences=$(grep -cE '^[[:space:]]*```' "$f" || true)   # fence lines, indented ones included
    [ $(( fences % 2 )) -eq 0 ] && continue
    dc_fail fence-balance \
      "$f has $fences code-fence markers (odd) — a \`\`\` block is unclosed; balance the fences."
  done < <(dc_md_files)
}

# doc-crlf — no *.md carries a carriage-return byte (the #40 CRLF class, extended to docs). -U
# keeps
# grep in binary mode so a lone CR inside a CRLF line is still seen.
dc_doc_crlf() {
  local f
  # THE MARKDOWN SET IS ASSERTED PRESENT (#269). The read below sends grep's error to /dev/null and
  # then treats a non-zero status as "no carriage return", so a file that could not be opened and a
  # file that is clean produce the identical verdict. The assertion is what tells those two apart;
  # the swallow itself stays, because it is what keeps a genuinely absent CR quiet.
  dc_present doc-crlf < <(dc_md_files)
  while IFS= read -r f; do
    [ -f "$f" ] || continue          # already reported BY NAME above
    grep -qU $'\r' -- "$f" 2>/dev/null || continue
    dc_fail doc-crlf "$f contains carriage-return byte(s) — normalise to LF (docs ship LF-only)."
  done < <(dc_md_files)
}

# link-target / link-anchor — an intra-repo relative link points at a real path; a #fragment matches
# heading in its target file. ONE slugify convention (GitHub-style), pure bash — no python
# dependency
# added to a required gate. md_slugs() turns each ATX heading into its anchor slug.
md_slugs() {
  grep -E '^#{1,6}[[:space:]]+' "$1" \
    | sed -E 's/^#{1,6}[[:space:]]+//' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9 _-]//g; s/ /-/g'
}

# dc_link_target — one link target from one markdown file: resolve or skip per scope, then check the
# path exists and the anchor resolves. It is a function so each per-target skip is a `return` — the
# same control flow the inline `continue`s had, one nesting level shallower.
# Arguments: the linking file, its directory, and the raw target text from [text](target).
dc_link_target() {
  local f=$1 dir=$2 tgt=$3 frag="" path target_file cand
  case "$tgt" in
    *://*|mailto:*|tel:*) return 0 ;;         # external — out of scope (never red on the network)
    *[[:space:]]*|*'<'*|*'>'*) return 0 ;;    # placeholder like <PR URL> — not intra-repo
  esac
  path="$tgt"
  case "$tgt" in
    \#*)  frag=${tgt#\#}; path="" ;;          # same-file anchor
    *\#*) path=${tgt%%#*}; frag=${tgt#*#} ;;  # path + anchor
  esac
  target_file="$f"
  if [ -n "$path" ]; then
    cand="$dir/$path"; [ "$dir" = "." ] && cand="$path"   # resolve relative to the linking file
    if [ ! -e "$cand" ]; then
      dc_fail link-target "$f links to '$tgt' but '$cand' does not exist — fix or remove the link."
      return 0
    fi
    target_file="$cand"
  fi
  [ -n "$frag" ] || return 0                  # anchor is checkable only against a .md target
  case "$target_file" in
    *.md) [ -f "$target_file" ] && ! md_slugs "$target_file" | grep -Fxq -- "$frag" \
            && dc_fail link-anchor "$f links to '$tgt' but no heading in $target_file" \
                       "slugifies to '#$frag' — fix the anchor." ;;
  esac
}

dc_link_targets() {
  local f dir tgt
  # THE MARKDOWN SET IS ASSERTED PRESENT (#269). Extracting link targets from a document that is not
  # there yields no targets, the inner loop runs zero times, and a file full of dead links reads
  # exactly like a file with none — no iteration is left for either verdict to come from.
  dc_present link-target < <(dc_md_files)
  while IFS= read -r f; do
    [ -f "$f" ] || continue          # already reported BY NAME above
    dir=$(dirname "$f")
    # each link target from [text](target); dc_link_target resolves/skips per scope
    while IFS= read -r tgt; do
      dc_link_target "$f" "$dir" "$tgt"
    done < <(grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
  done < <(dc_md_files)
}

# dead-pointer (#51 collapse) — the standalone flat-pack install doc was folded away and DELETED.
# No tracked file may still name it: a dead pointer to a removed file ships dead on a user estate.
# That file stays deleted, and the install steps now live in $INSTALL_DOC, which is where this
# detector sends a stale pointer. NOTHING ASSERTS "one install home" MECHANICALLY any more: the
# detector that did was cut with the other sixteen (#281), so that separation is kept by review.
# The needle is assembled from two string
# pieces so THIS detector's own source never contains the contiguous name it hunts for — a literal
# here would make the detector match itself forever. Its own detector (not folded into the link
# check) because it hunts a bare name in ANY tracked text, not just markdown links.
dc_dead_pointer() {
  local collapse_needle collapse_hits collapse_rc
  collapse_needle='INSTALL''.md'
  # THE SEARCH IS ASSERTED TO HAVE HAPPENED (#269), and this detector is the one the determination
  # could not measure: its error went to /dev/null and fed an EMPTINESS TEST, so "no dead pointer
  # anywhere" and "the search never ran" were the same empty string, and no probe made the search
  # itself fail. git grep exits 0 when it matched, 1 when it looked and found nothing, and ABOVE 1
  # when it could not look at all — so the status separates the two answers the old read could not.
  # It is read into its own variable on the same line, before anything else can overwrite it.
  collapse_hits=$(git grep -l -F -- "$collapse_needle" 2>/dev/null); collapse_rc=$?
  if [ "$collapse_rc" -gt 1 ]; then
    dc_fail dead-pointer \
      "the tracked-text search for '$collapse_needle' could not run (git grep exited" \
      "$collapse_rc) — this detector proves a removed file is named NOWHERE, and a search that" \
      "did not happen returns exactly what a clean repository returns. Run this inside a working" \
      "git checkout with a readable index."
    return 0
  fi
  [ -n "$collapse_hits" ] || return 0
  dc_fail dead-pointer \
    "'$collapse_needle' was folded away and removed, but these tracked files still name it —" \
    "re-point them to $INSTALL_DOC, which owns the install steps and the hook-activation caveat:"
  printf '  %s\n' $collapse_hits
}

# dc_main — the detectors, in the order their output has to appear. This list IS the running order;
# nothing else in the file decides it.
#
# NONE OF THE FOUR PRINTS AN OK-LINE, and the closing message says so rather than pointing a reader
# at success lines that do not exist. Silence here means every document scanned clean; the failures
# are what have to be readable, and they are.
dc_main() {
  dc_fence_balance
  dc_doc_crlf
  dc_link_targets
  dc_dead_pointer
  [ "$fail" -eq 0 ] || { echo "docs-check: FAILED — each line above names its fix."; exit 1; }
  echo "docs-check: all 4 detectors pass (fence-balance, doc-crlf, link-target, dead-pointer)."
}

dc_main
