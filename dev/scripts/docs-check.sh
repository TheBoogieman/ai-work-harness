#!/usr/bin/env bash
# docs-check.sh — CI-side documentation governance (#42). It gates MERGES; the demo gates the
# PRODUCT — two truths, two instruments (cond 3). DEV infrastructure: it lives under .github/ and
# NEVER ships to a user estate (#43); no PRODUCT script references it. Pure greps, zero judgment,
# each detector's failure names its exact fix (addition-D). The demo carries ZERO README knowledge
# (cond 2); all documentation-state checks live here, in ONE home.
#
# SHAPE (#129): every detector is a FUNCTION and dc_main at the foot calls them in the order their
# output has to appear. Only the shared inputs and the registries live at file scope, which is what
# brings this file inside the four limits the code-shape gate sets. No detector was added, removed,
# re-pointed or reworded by that pass: each still reads the same files, prints the same lines in
# the same order, and sets the same `fail`.
#
# Inputs (so the detectors are testable locally AND in CI):
#   PR_BODY               the pull-request body text (for the [diagrams-unaffected] token)
#   DOCS_CHANGED_FILES    newline list of files changed in the PR; if unset, computed from git
#   DOCS_BASE_REF         base ref for the diff when DOCS_CHANGED_FILES is unset
#                         (default origin/main)
set -uo pipefail
fail=0            # a COUNT of failures printed so far, never a boolean — see dc_fail below (#252)
README=README.md
DESIGN="estate/General AI-Knowledge/AI Harness/DESIGN.md"
# The two documents the front page handed work to in #146: the estate structure it used to carry,
# and the install manual it used to be. Named here because four detectors below now read them.
MAP=estate/folder-map.md
INSTALL_DOC=estate/installing.md

# dc_fail / dc_ok — the two output shapes every detector prints, in ONE home each. A message is
# passed as SEVERAL arguments and joined with a single space, which is what lets a long message be
# wrapped across source lines without changing a byte of what is printed. dc_fail also records the
# failure, so no detector has to remember to record it next to its own message. IFS is pinned to
# a space for the join because a caller may be inside a `while IFS= read` loop.
#
# dc_fail COUNTS, IT DOES NOT SET A FLAG (#252), and that is the whole of this file's success-line
# honesty. Every detector decides whether to print its ok-line by comparing $fail against the value
# it saved before it started. Under a set-once flag that comparison DEGENERATES: after the first
# failure anywhere in the run the flag is already 1, so every later detector compares 1 against 1,
# reads "unchanged", and prints its success line — including the detector that has just printed its
# own FAIL two lines above. Counting makes each comparison about that detector's OWN failures
# again, which is what the comparison was always written to mean. It repairs BOTH spellings of the
# idiom at once — `[ "$fail" -ne "$X_before" ] || dc_ok X` and `[ "$fail" -eq "$X_before" ] ||
# return 0` are the same statement, and both were defeated by the same degenerate compare.
# The gate's verdict is unchanged: the exit test at the foot still reads 0 as "nothing failed".
dc_fail() {
  local tag=$1 IFS=' '; shift
  printf 'FAIL [docs %s]: %s\n' "$tag" "$*"
  fail=$((fail+1))
}
dc_ok() { local tag=$1 IFS=' '; shift; printf '  ok [docs %s] — %s\n' "$tag" "$*"; }

# ================================================================================================
# THE SUBJECT ASSERTION (#269) — EVERY DETECTOR EITHER READS WHAT IT CLAIMS TO READ, OR FAILS
# SAYING IT COULD NOT. A detector whose subject was absent used to conclude CLEAN, by three routes
# that all end in the same place: a grep over a path that is not there finds nothing; a loop over a
# list that could not be built runs zero times, so there is no iteration left to fail; and an error
# sent to /dev/null feeding an emptiness test makes "the tool broke" and "there was nothing" the
# same value. None of the three is distinguishable from a subject that is genuinely clean, so the
# gate printed a success line about a document nothing had opened.
#
# THE REMEDY WAS ALREADY IN THIS FILE, and is CITED here rather than reinvented: dc_ih_documents
# (install-home) and dc_adr_spec (the SPEC.md half of adr-shape) each test their own subject's
# existence before concluding anything, and fail BY NAME when it is gone. Those two survive every
# absence probe. The helpers below are that same test in one home so any detector can make it.
#
# EACH DETECTOR MUST MAKE THE ASSERTION UNDER ITS OWN TAG. A red raised by a sibling that happens to
# read the same file is that SIBLING reporting; this detector's own blindness is untouched, and
# reordering the run list would make it live again with nothing having changed. So these helpers
# take the caller's tag, and one absence can legitimately produce one message per reader. That
# duplication is the deliberate price of every detector answering for itself.

# dc_have — the PATH form. Returns non-zero when the subject is not a readable file, so the caller
# can skip reads that would now prove nothing instead of drawing a verdict from an empty one.
dc_have() {
  local hv_tag=$1 hv_path=$2 hv_what=$3
  { [ -f "$hv_path" ] && [ -r "$hv_path" ]; } && return 0
  dc_fail "$hv_tag" \
    "'$hv_path' is absent or unreadable, so $hv_what was NOT checked. This detector reads that" \
    "path; skipping it in silence would print a success line about a file nothing opened. Restore" \
    "it, or re-point this detector at whatever replaced it."
  return 1
}

# dc_present — the SET form for a scan set built from the git index. A COUNT IN A MESSAGE IS NOT AN
# ASSERTION: the set can shrink to a fraction of itself and the success line simply prints the
# smaller number, which is how one ok-line here reported on three surfaces while naming the sixteen
# it used to read. Every path arriving on stdin must be a readable file. THE COUNT IS THE
# ASSERTION AND THE NAMES ARE ONLY A LEAD, so at most three are printed and the message says "first"
# rather than trailing an ellipsis — an ellipsis after the only missing path claims a truncation
# that did not happen, which is the same species of small untruth this whole item is about.
# Returns non-zero when anything was missing, so a caller may skip as well as report.
dc_present() {
  local pr_tag=$1 pr_f pr_gone="" pr_n=0
  while IFS= read -r pr_f; do
    [ -n "$pr_f" ] || continue          # an EMPTY set arrives as one blank line; it is not a path
    { [ -f "$pr_f" ] && [ -r "$pr_f" ]; } && continue
    pr_n=$((pr_n+1))
    [ "$pr_n" -le 3 ] && pr_gone="$pr_gone $pr_f"
  done
  [ "$pr_n" -eq 0 ] && return 0
  dc_fail "$pr_tag" \
    "$pr_n path(s) in this detector's scan set are not readable files (first: ${pr_gone# }) — it" \
    "takes its surface from the git index and used to drop a missing member without a word, so" \
    "its verdict covered fewer files than its message names. Restore them, or record the removal."
  return 1
}

# dc_have_min — the SET form for a set the detector assembles itself, where the floor is a property
# of the question rather than of the index: below it there is nothing left to answer with. It reds
# naming both numbers, because "found 0" and "looked at 0" read identically in a success line.
dc_have_min() {
  local hm_tag=$1 hm_got=$2 hm_min=$3 hm_what=$4
  [ "$hm_got" -ge "$hm_min" ] && return 0
  dc_fail "$hm_tag" \
    "this detector assembled $hm_got $hm_what where at least $hm_min is expected — its scan set" \
    "is too small to answer with, so any verdict from it would be a statement about a set that is" \
    "not there. Restore the missing members, or lower the floor here if the set really did shrink."
  return 1
}

# --- map-inventory — every shipped script + the two root surfaces named in the folder map --------
# (the #34 docs-inventory guard, MIGRATED out of run_demo.sh; it gates merges now, not the demo.)
# RE-POINTED, NOT REWRITTEN (#146): the folder map left README for its own document, and this check
# followed it there. Same assertion over the same fact — only the document obliged to carry the
# names changed. It is also WHY the map had to leave: this check makes the map grow every time the
# machinery grows, so whichever document holds the map cannot stay short.
dc_map_inventory() {
  # mi_before snapshots the failure count so this ok-line answers for THIS detector only. It used
  # to test `$fail -ne 0`, which asks "has anything failed anywhere?" — latent here because this
  # detector runs first, but latent is not correct, and reordering dc_main would have made it live
  # without anyone touching this line (#252).
  local s base mi_body ri_total=0 mi_before=$fail
  # THE MAP IS ASSERTED BEFORE IT IS READ (#269). `cat` on a path that is not there returns an empty
  # body, and every row below then fails for the wrong reason — sixteen messages saying the map does
  # not name a script, when the truth is that there is no map. One honest red replaces them.
  dc_have map-inventory "$MAP" "the shipped surfaces the folder map has to name" || return 0
  mi_body=$(cat "$MAP")
  for s in estate/_harness/scripts/* estate/install.sh estate/setup.md; do
    # THE SCAN SET IS ASSERTED, MEMBER BY MEMBER (#269). An unmatched glob leaves the pattern itself
    # in $s, so deleting the shipped-scripts directory used to take this loop from sixteen surfaces
    # to three — and the ok-line simply printed the three. The test is EXISTENCE, not readability as
    # a file: a directory added under the shipped-scripts path is still a surface the map has to
    # name, and redding on it with an "unreadable" message would be a false statement about it.
    [ -e "$s" ] || { dc_fail map-inventory \
      "'$s' is in this detector's scan set but is not there — an unmatched glob leaves the" \
      "pattern itself in the list, so the loop shrinks in silence and the count in the success" \
      "line measures only what survived. Restore the shipped surface, or narrow the scan set" \
      "here if it genuinely no longer ships."; continue; }
    base=$(basename "$s"); ri_total=$((ri_total+1))
    grep -Fq -- "$base" <<<"$mi_body" && continue
    dc_fail map-inventory "$base ships but is not named in the folder map ($MAP)" \
                         "— add its tree line."
  done
  [ "$fail" -ne "$mi_before" ] || dc_ok map-inventory \
    "$ri_total shipped surfaces, each one present and named in $MAP"
}

# --- dev-loop — DEVELOPMENT.md + dev/dev-loop/ starter kit: three method-doc invariants
# (#68) ------------------------------------------------------------------------------------
# This lane ships a method doc plus empty adopt-and-fill templates. Three things must hold or the
# artifact lies. (1) Templates stay EMPTY: a filled field is instance material leaking into the
# repo.
# (2) The method files name NO AI vendor: the method is assistant-agnostic, so a product name breaks
# that claim. (3) DEVELOPMENT.md actually carries the four role names and five working laws it
# claims
# to teach. Scoped to THIS lane's own files (dev/DEVELOPMENT.md + dev/dev-loop/**) so README's
# legitimate
# vendor mention elsewhere is never touched. dl_fail_before snapshots $fail so the ok-line prints
# only when all three invariants held this run.

# dc_dl_pairs — invariant 3's rows, each pinned as its own named assertion (the same style as the
# doc-sweep's) so a dropped role or law reds by name rather than vanishing silently. Format:
# "LABEL<TAB>literal string in DEVELOPMENT.md". This is ALSO exclusion 3's second source in the
# one-home detector below, which is why it is a named surface rather than an inline list.
dc_dl_pairs() {
  printf '%s\n' \
    "role-architect	ARCHITECT" \
    "role-reviewer	REVIEWER/PRODUCT-OWNER" \
    "role-implementer	IMPLEMENTER" \
    "role-operator	OPERATOR" \
    "law1-verbatim-specs	verbatim issue bodies" \
    "law2-audit-confirms	confirms or reopens" \
    "law3-regression-guard	provably fails on pre-fix code" \
    "law4-attack-cycle	attack cycle" \
    "law5-claims-at-head	live at HEAD"
}

# 1. TEMPLATES KEEP A <FILL> BLANK — every dev/dev-loop/*.template.md must retain AT LEAST ONE
# literal
# <FILL> token. The check is presence-of-one, so it fires only when NONE is left (a FULLY-filled
# template), not on a partial fill — the message and ok-line say exactly that, no stronger (#82).
dc_dl_templates() {
  local dl_t dl_n=0
  for dl_t in dev/dev-loop/*.template.md; do
    # THE TEMPLATE SET IS COUNTED (#269). With the directory gone the glob does not expand, so $dl_t
    # held the pattern itself and this loop redded once about a file named "*.template.md" — a true
    # red with a false subject. Skipping the non-file and counting instead reds about the SET, which
    # is what actually went missing, and covers the case the old shape could not see at all: a
    # directory that is there and holds no templates.
    [ -f "$dl_t" ] || continue
    dl_n=$((dl_n+1))
    grep -Fq -- '<FILL>' "$dl_t" && continue
    dc_fail dev-loop \
      "$dl_t has no <FILL> token left — a template must keep at least one <FILL> blank as proof" \
      "it ships as a skeleton; restore a <FILL> blank."
  done
  dc_have_min dev-loop "$dl_n" 1 "adopt-and-fill template(s) matching dev/dev-loop/*.template.md"
}

# 2. VENDOR-NEUTRAL — no AI product name appears in DEVELOPMENT.md or dev/dev-loop/**. It is
# word-anchored (-w)
# and case-insensitive (-i) so the method-level prose stays product-free; scoped by git ls-files to
# this lane's files only, never README.
dc_dl_vendor_neutral() {
  local dl_vendors dl_f dl_hit dl_files
  dl_vendors='claude|copilot|chatgpt|gpt|anthropic|openai|gemini|cursor'
  # THE SCANNED LIST IS ASSERTED TO CONTAIN THE FILE THE CLAIM NAMES (#269). This list comes from
  # the git index, and the ok-line above says the method doc is vendor-neutral — so with that doc
  # untracked the loop ran over the other files, found nothing, and the success line vouched for a
  # document it had not opened. The named assertion is the point: a bare count would still pass
  # with the one file that matters missing and four others present in its place.
  dl_files=$(git ls-files dev/DEVELOPMENT.md 'dev/dev-loop/*')
  printf '%s\n' "$dl_files" | grep -qxF dev/DEVELOPMENT.md || dc_fail dev-loop \
    "dev/DEVELOPMENT.md is not in this detector's scanned list (git ls-files) — the" \
    "vendor-neutral claim names that document, and a list without it makes the claim about" \
    "everything except its subject. Track the file, or re-point this detector at the method doc" \
    "that replaced it."
  dc_present dev-loop <<<"$dl_files"
  while IFS= read -r dl_f; do
    [ -f "$dl_f" ] || continue                # absent members are already reported by name, above
    dl_hit=$(grep -niwE -- "$dl_vendors" "$dl_f" | head -1 || true)
    [ -z "$dl_hit" ] && continue
    dc_fail dev-loop \
      "$dl_f names an AI vendor ($dl_hit) — dev/DEVELOPMENT.md and dev/dev-loop/** are" \
      "vendor-neutral;" \
      "remove the product name."
  done <<<"$dl_files"
}

# 3. ROLES AND LAWS PRESENT — DEVELOPMENT.md carries the four role words and one needle per working
# law, read from dc_dl_pairs above.
dc_dl_roles_laws() {
  local dl_pair dl_label dl_needle
  while IFS= read -r dl_pair; do
    dl_label=${dl_pair%%	*}; dl_needle=${dl_pair#*	}
    grep -Fq -- "$dl_needle" dev/DEVELOPMENT.md && continue
    dc_fail "dev-loop:$dl_label" \
      "dev/DEVELOPMENT.md no longer states this (missing \"$dl_needle\") — restore it."
  done < <(dc_dl_pairs)
}

dc_dev_loop() {
  local dl_fail_before=$fail
  dc_dl_templates
  dc_dl_vendor_neutral
  dc_dl_roles_laws
  [ "$fail" -ne "$dl_fail_before" ] || dc_ok dev-loop \
    "each template keeps a <FILL> blank, vendor-neutral, 4 roles + 5 laws present in" \
    "DEVELOPMENT.md"
}

# --- de-number (#82 / #85) — no NUMERIC agent-count claim survives #85's de-numbering conversion --
# #85 turned the roster count into role-named prose because the agent set GROWS (six → ten over the
# sprint); a re-introduced "six agents" would be false the next time an agent lands. TWO
# word-anchored,
# case-insensitive patterns over the de-numbered doc surfaces (README, the constitution, DESIGN.md):
#   (a) a number-word IMMEDIATELY before "agent(s)"  — e.g. "six agents" (README's "six-rule
#       contract" says "rule", not "agent", so it is correctly out of this pattern's reach).
#   (b) a number-word plus "file(s)" on any line naming a ".agent.md" — the agent-file-count shape
#       that pattern (a) cannot see.
# EXEMPTION is PARAGRAPH-scoped: DESIGN.md's honest-lag notes legitimately carry the stale sheet
# counts ("SIX AGENTS"), so lines from one that BEGINS "**Diagram currency" until the next blank
# line
# are skipped. Paragraph-scoped, NOT heading-scoped — a heading scope would also swallow the live
# claims below the notes, the exact regression caught pre-spec and forbidden here.

# dc_dn_line — the two patterns, applied to ONE non-exempt line. It is its own function so the two
# `if`s sit at the shallowest depth the file's nesting budget allows; $dn_num is the shared
# number-word alternation, set by the caller.
dc_dn_line() {
  local dn_f=$1 dn_lineno=$2 dn_line=$3 dn_hit
  # (a) number-word directly before agent(s)
  if printf '%s' "$dn_line" | grep -qiE "\b(${dn_num})[[:space:]]+agents?\b"; then
    dn_hit=$(printf '%s' "$dn_line" | grep -oiE "\b(${dn_num})[[:space:]]+agents?\b" | head -1)
    dc_fail de-number:agent-count \
      "$dn_f:$dn_lineno states a numeric agent count (\"$dn_hit\") — #85 de-numbered the roster" \
      "because it grows; name the agents by role, not by a count that goes stale."
  fi
  # (b) number-word + file(s) on a line that names a .agent.md
  if printf '%s' "$dn_line" | grep -qF '.agent.md' \
     && printf '%s' "$dn_line" | grep -qiE "\b(${dn_num})\b" \
     && printf '%s' "$dn_line" | grep -qiE '\bfiles?\b'; then
    dc_fail de-number:file-count \
      "$dn_f:$dn_lineno pairs a number with '.agent.md file(s)' — the agent-file count is not" \
      "fixed; describe the set without a count."
  fi
}

dc_de_number() {
  local dn_fail_before=$fail dn_f dn_exempt dn_lineno dn_line
  dn_num='one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|[0-9]+'
  for dn_f in "$README" estate/folder-structure.md "$DESIGN"; do
    # EACH DOCUMENT IS ASSERTED BEFORE IT IS READ (#269). `done < "$dn_f"` on a path that is not
    # there fails the redirect and the loop body never runs, so there is no iteration left to fail —
    # and this detector's ok-line NAMES all three documents, which made it the loudest instance of
    # the class: a success line reciting three titles, printed by a run that had opened two.
    dc_have de-number "$dn_f" "its numeric agent-count claims" || continue
    dn_exempt=0; dn_lineno=0
    while IFS= read -r dn_line || [ -n "$dn_line" ]; do
      dn_lineno=$((dn_lineno+1))
      # a currency paragraph opens on its "**Diagram currency" line and closes at the next
      # blank line.
      printf '%s' "$dn_line" | grep -q '^\*\*Diagram currency' && dn_exempt=1
      [ -z "${dn_line//[[:space:]]/}" ] && dn_exempt=0
      [ "$dn_exempt" -eq 1 ] && continue           # skip the exempt honest-lag lines
      dc_dn_line "$dn_f" "$dn_lineno" "$dn_line"
    done < "$dn_f"
  done
  [ "$fail" -ne "$dn_fail_before" ] || dc_ok de-number \
    "no numeric agent-count claim outside the DESIGN.md currency notes (README, constitution," \
    "DESIGN.md)"
}

# ================================================================================================
# ONE-HOME FAMILY (#121, #122) — an EXTENSION of the de-number detector above, not a second
# detector stood beside it. Shared conventions, and every later member joins them: each registry is
# DATA inside this script (a bash array of TAB-delimited rows, so it cannot drift from the check
# that reads it), the census surface is ONE function (oh_surface) with ONE drawing exclusion, and
# every miss names its locations and its exact fix.

# oh_surface — the files every detector in this family reads. DRAWINGS ARE EXCLUDED BY
# CONSTRUCTION, not by an exemption list that every future sheet must be added to: a drawing is a
# picture of a fact, so a rendered label inside an .svg is not a telling of it. The sheets are
# operator-owned and no wave may edit one, so counting their labels would make every new sheet a
# gate liability. Binary blobs carry no prose and are dropped with them.
oh_surface() { git ls-files | grep -vEi '\.(svg|png|jpe?g|gif|zip)$'; }

# --- one-home — ONE TELLING PER REGISTERED PHRASE (#121) -----------------------------------------
# The assertion is NARROW and the narrowness is the deliverable: no REGISTERED PHRASE appears in
# more than one document. It is NOT "each fact is told once" — phrase matching cannot decide that.
# Each fact may register several phrasings so that known restatements are caught and not only exact
# copies; it catches verbatim re-telling and the reintroduction of a registered phrasing, and it
# NEVER catches paraphrase. That limit is printed in this detector's own ok-line, because a green
# build read as "this fact has one home" would make the instrument built to enforce claims-truth
# ship a false claim about itself.
#
# THE FOUR EXCLUSIONS ARE NOT FOUR OF A KIND. A later reader who collapses them into one rule
# about "things that look like duplicates" will delete the last two and break the repository:
#   (1) paths, filenames and manifest rows — a FALSE POSITIVE. The row merely LOOKS like a telling;
#       the manifest naming a file correctly must never red. Dropped at scan time (oh_pathre /
#       oh_extre blank every path-ish and filename-ish token before the phrase count).
#   (2) rendered labels inside drawings    — a FALSE POSITIVE. A drawing is a picture of a fact, not
#       a rival home. Dropped at scan time, by construction (oh_surface).
#   (3) strings that are also IDENTIFIERS  — NOT a false positive, and it drops nothing at scan
#       time. It refuses the REGISTRATION, because for these strings repetition is REQUIRED: a
#       continuous-integration check name appears in the document explaining it, in the workflow
#       declaring it and in the script reporting it, and all three must match character for
#       character because that name is the contract with branch protection. Register one and this
#       detector reds on a CORRECT repository — and the obvious way to make it green again is to
#       break the checks. So an alias that a machine matches on is rejected as a registration
#       error, loudly and by name, before any counting happens. TWO SOURCES feed it: the workflow
#       files, and the literal strings the dev-loop detector above REQUIRES DEVELOPMENT.md to
#       carry. The second is the same exclusion arriving as a REQUIRED NEEDLE rather than as a
#       check name — that file is obliged by a detector in this very script to state those laws,
#       so the sentence carrying one is a contract, not a rival telling.
#   (4) decision records (dev/decisions/**)    — NOT a false positive either, and NOT a matching
#       accident at all: it is a RULING about what those documents ARE. A record must state what
#       was decided. Its DECISION SECTION is the primary text of the ruling, and a record whose
#       Decision section pointed elsewhere for its own decision would not be a record. So a record
#       restating the rule it recorded is not a rival home, and the directory is dropped when the
#       census file list is built (below). THE GROUND IS THE DECISION SECTION AND NOTHING ELSE —
#       it is emphatically NOT "a title states its decision by construction", which is false: a
#       title need only IDENTIFY its record, and a wrong reason left in doctrine outlasts the
#       ruling it was invented to justify. The rest of the file rides along with the section
#       because the only way to green a census over a record is to retitle and reword it, which
#       makes the document worse in order to serve a gate. SCOPED TO THIS DETECTOR: the
#       no-lookup detector below still reads decision records in full, and must — a retired tag
#       inside a record is exactly the defect it hunts.
#
# THE REGISTRY — one row per registered FACT: "DISPLAY-NAME<TAB>HOME<TAB>alias|alias|...". The
# display name is for the human reading a failure; it is never a key, because naming a fact the way
# a human names it is the worst possible key for it. Matching is lowercase and whitespace-flattened,
# so aliases are written lowercase. WORDS INSIDE AN ALIAS ARE JOINED WITH "~", NOT A SPACE: this
# file is itself on the census surface, so a contiguous alias here would make the registry a second
# telling of every fact it registers (the same self-match the dead-pointer needle avoids). The
# loader restores the spaces and reds on a literal space, so the rule cannot be forgotten. This
# registry is expected to GROW as drift is found — add a row, never a second census.
#
# THE SECOND ROW REGISTERS THE RULE'S STATEMENT, NOT ITS EXEMPTION LIST (#189). The first row keys
# on the three exempt-class phrases, so a document that states the rule WITHOUT qualifying it
# carries none of them and passes unseen — which is precisely the defect that kept recurring, and
# precisely what the first row cannot see. The alias list is the deliverable: a detector's reach is
# the sum of what has actually been FOUND, so every alias is one known carrier's own words, taken
# from that carrier rather than invented. Alias one is the wording the HOME uses and must never be
# dropped — without it the row reports zero the day the other carriers are corrected, and reds as
# ROTTED, retiring a row nobody meant to retire. Alias two is the guard-per-bug record's title and
# opening sentence. Alias three is the enforcement record's former Consequences wording, deleted by
# #167 and registered here so that phrasing cannot quietly come back. The last two sit inside
# exclusion 4 today and are kept deliberately: their job is to stop those exact phrasings
# reappearing OUTSIDE the records, which is where they would be a second home.
#
# WHAT THIS ROW DOES NOT REACH, said plainly so nobody reads a green census as a clean repository:
# DEVELOPMENT.md's third working law states this rule unqualified, and NO alias here is keyed on
# its wording. That is exclusion 3 above, arriving as a required needle — the dev-loop detector
# obliges that file to carry a literal string, and the sentence carrying it is the law's statement.
# Key an alias on it and one detector here demands you break another. The refusal is MECHANICAL
# rather than remembered: those needles feed the registration check below, so the trap reds at the
# moment somebody registers into it instead of after they have edited the document.
# AN ALIAS LIST IS BUILT INTO A NAMED VARIABLE FIRST and the row then interpolates it. That is not
# decoration: a row long enough to state its aliases inline is longer than a source line may be, and
# the alternative — gluing quoted fragments together inside the array — is the "A"B"C" shape a
# linter rightly refuses. The rows themselves stay TAB-delimited data, unchanged.
oh_alias_exempt='documentation~and~prose|comment-only~passes|pure~renames~and~moves'
oh_alias_rule='regression~guard~that~provably~fails~on~the~pre-fix~code'
oh_alias_rule+='|every~bug~fix~ships~with~a~regression~guard'
oh_alias_rule+='|every~bug~still~ships~a~guard'
oh_registry=(
  "guard-per-bug exempt classes	CLAUDE.md	$oh_alias_exempt"
  "guard-per-bug rule statement	CLAUDE.md	$oh_alias_rule"
)
# oh_ptr_max — "pointer" has to be MECHANICAL or the detector is unarguable. A paragraph at or under
# this many characters that NAMES the fact's home file is a pointer and is skipped; anything longer,
# or anything that does not name the home, is a telling and is counted.
oh_ptr_max=200
# EXCLUSION 1's two shapes: any token carrying a slash, and any token ending in a known file
# extension. Passed to awk as strings, and written with BRACKET EXPRESSIONS rather than backslash
# escapes on purpose: awk's -v processes escape sequences before the regex is compiled, so a
# backslash here is consumed once and then re-read, which silently turned an earlier draft of the
# path shape into a pattern that swallowed whole paragraphs. No backslash, no second reading.
oh_pathre='[^ ]*[/][^ ]*'
oh_extre='[^ ]*[.](md|sh|py|txt|json|ya?ml|svg|ipynb)([^a-z0-9]|$)'

# dc_oh_census — THE CENSUS, in one awk pass over the whole surface. RS="" reads a PARAGRAPH at a
# time and the gsub squeezes its newlines to single spaces, which is what makes the match
# WHITESPACE-INSENSITIVE — and that is not a nicety: prose wraps, so a registered phrase can sit
# across a line break, and a line-oriented census then returns ZERO for it, which is the wrong
# answer rather than a near miss. tolower() matters for the same reason: a doctrine written as a
# capitalised banner is the same telling as the same words in a sentence. One file counts once.
# Arguments: the row's alias alternation, and the row's home file lowercased.
dc_oh_census() {
  awk -v aliases="$1" -v home="$2" -v ptrmax="$oh_ptr_max" \
      -v pathre="$oh_pathre" -v extre="$oh_extre" '
    BEGIN { RS=""; n = split(aliases, A, "|") }
    {
      if (FILENAME in hit) next
      p = tolower($0); gsub(/[[:space:]]+/, " ", p); sub(/^ /, "", p)
      if (index(p, home) > 0 && length(p) <= ptrmax) next   # short + names the home = a POINTER
      b = p; gsub(pathre, " ", b); gsub(extre, " ", b)      # EXCLUSION 1
      for (i = 1; i <= n; i++) if (index(b, A[i]) > 0) { hit[FILENAME] = A[i]; break }
    }
    END { for (f in hit) print f " (matched: \"" hit[f] "\")" }
  ' "${oh_files[@]}" | sort
}

# dc_oh_reject_identifier — EXCLUSION 3, enforced at REGISTRATION time (see the note above), never
# at scan time. Returns TRUE (0) when at least one of the row's aliases is machine-matched, and the
# caller then skips the census for that row: the registration is the defect, and one cause gets one
# message. Arguments: the row's display name, and its alias alternation with spaces restored.
dc_oh_reject_identifier() {
  local oh_name=$1 oh_al=$2 oh_a oh_rejected=1
  while [ -n "$oh_al" ]; do
    oh_a=${oh_al%%|*}; [ "$oh_al" = "$oh_a" ] && oh_al="" || oh_al=${oh_al#*|}
    grep -Fqi -- "$oh_a" <<<"$oh_machined" || continue
    dc_fail "one-home:$oh_name" \
      "the registered phrase \"$oh_a\" is also matched literally by a machine — it appears in" \
      ".github/workflows/, or among the strings the dev-loop detector requires DEVELOPMENT.md" \
      "to carry. That makes it an IDENTIFIER, and an identifier's repetition is the contract, not" \
      "a duplication: registering it would red this detector on a CORRECT repository, and the" \
      "obvious way to green it again is to break the other check. Delete the alias from the" \
      "registry; never register a string that a machine matches."
    oh_rejected=0
  done
  return "$oh_rejected"
}

# dc_oh_row — one registry row, from split to verdict.
dc_oh_row() {
  local oh_row=$1 oh_name oh_tail oh_home oh_alias_field oh_home_lc oh_homes oh_count
  oh_name=${oh_row%%	*}; oh_tail=${oh_row#*	}
  oh_home=${oh_tail%%	*}; oh_alias_field=${oh_tail#*	}
  oh_home_lc=$(printf '%s' "$oh_home" | tr 'A-Z' 'a-z')
  case "$oh_alias_field" in
    *\ *) dc_fail "one-home:$oh_name" \
            "an alias in this row contains a literal space — join an alias's words with '~' so" \
            "this script's own source never carries the contiguous phrase it hunts for, or the" \
            "registry becomes a second telling of the fact." ;;
  esac
  oh_alias_field=${oh_alias_field//\~/ }
  dc_oh_reject_identifier "$oh_name" "$oh_alias_field" && return 0
  oh_homes=$(dc_oh_census "$oh_alias_field" "$oh_home_lc")
  oh_count=$(printf '%s' "$oh_homes" | grep -c . || true)
  if [ "$oh_count" -gt 1 ]; then
    dc_fail "one-home:$oh_name" \
      "this registered fact is told in $oh_count documents — a registered fact has exactly ONE" \
      "home ($oh_home). Delete the other telling(s) and leave a pointer to the home, or drop the" \
      "alias if the second occurrence is not a telling. Locations:"
    printf '%s\n' "$oh_homes" | sed 's/^/    /'
  elif [ "$oh_count" -eq 0 ]; then
    dc_fail "one-home:$oh_name" \
      "no registered phrase for this fact matches anything tracked — the registry has rotted (the" \
      "telling was reworded, so the row now guards nothing). Re-key the row to the wording" \
      "that is live at HEAD, or delete the row."
  fi
}

# dc_oh_census_files — THIS detector's census surface: oh_surface minus the decision records.
# EXCLUSION 4 applies HERE and only here — the records are dropped from THIS detector's census while
# oh_surface, which the no-lookup detector below reads, keeps them. The test is on the records'
# DIRECTORY PREFIX, not on the first path segment: the records live inside the development tree
# (#136), so a first-segment test would match "dev" — which is every development file — or nothing,
# and either way the exclusion would stop meaning what it says.
# IT IS A FUNCTION SO THE LIST IS BUILT ONCE AND READ TWICE (#269): the presence assertion below and
# the census itself must be looking at the same surface, or the assertion vouches for a set the
# census never used.
dc_oh_census_files() {
  local oc_f
  while IFS= read -r oc_f; do
    case "$oc_f" in dev/decisions/*) continue ;; esac
    printf '%s\n' "$oc_f"
  done < <(oh_surface)
}

dc_one_home() {
  local oh_fail_before=$fail oh_row
  # EXCLUSION 3's haystack — every string in this repository that a MACHINE matches literally, so a
  # registration can be tested against all of them at once: the workflow files, plus the dev-loop
  # needles declared above (a required needle is an identifier for this purpose).
  oh_machined=$(cat .github/workflows/*.yml 2>/dev/null || true; dc_dl_pairs)
  # THE CENSUS SURFACE IS ASSERTED PRESENT BEFORE IT IS COUNTED OVER (#269). The `[ -f ]` test
  # below is a FILTER, and a filter drops what it rejects without a word: a tracked file missing
  # from the working tree simply left the census, the phrase count came back smaller, and "told in
  # exactly ONE document" was printed over a surface with holes in it. The assertion is what makes
  # the hole audible; the filter still runs, because the files that ARE there are still worth
  # counting.
  dc_present one-home < <(dc_oh_census_files)
  oh_files=()
  while IFS= read -r oh_f; do
    [ -f "$oh_f" ] && oh_files+=("$oh_f")
  done < <(dc_oh_census_files)
  for oh_row in "${oh_registry[@]}"; do
    dc_oh_row "$oh_row"
  done
  [ "$fail" -ne "$oh_fail_before" ] || dc_ok one-home \
    "${#oh_registry[@]} registered fact(s), each told in exactly ONE document. LIMIT: green means" \
    "no REGISTERED phrase reached a second document — verbatim re-telling and reintroduced" \
    "registered phrasings only, NEVER paraphrase; the registry grows as drift is found."
}

# --- no-lookup — NO IDENTIFIER THAT NEEDS A LOOKUP OUTSIDE THE FILE (#122) -----------------------
# Same family, same census surface (oh_surface), same registry-as-data shape. What cannot be
# automated is the rule's real test — that a sentence still makes sense with every reference
# deleted. What CAN be automated is the token SHAPES, and shapes are what catch REINTRODUCTION,
# which is the durable value: once a token family has been purged, this stops it coming back.
#
# THE SINGLE EXEMPTION is the history decoder — the one document that names the retired families so
# that a reader doing archaeology on the commit history has a dictionary. It is exempt because the
# git log CANNOT be purged: the tags are in commit messages and issue text forever, so something
# tracked has to decode them, and this detector must not red on the dictionary itself. There is no
# second exemption; a new legal home for a retired tag is a change to which file IS the decoder.
id_decoder='CLAUDE.md'   # the public-text rule there is the retired-family dictionary
#
# NEVER BANNED, and the reasons matter more than the list:
#   * the layer labels (the estate's L1..L5) — each is DEFINED IN THE PARAGRAPH THAT USES IT, so it
#     needs no lookup anywhere; that is precisely the property this detector tests for.
#   * the ticket-pattern variable (TICKET_RE) — already plain English: it reads as "the ticket
#     regular expression" to anyone who meets it.
#   * the estate configuration key (harness.estate) — also plain English, and renaming it would
#     SILENTLY DE-ARM every installed estate, because the commit-bearing hooks refuse to commit
#     unless that exact key is set. A cosmetic gain is not worth disarming a live safety net.
# These three are asserted below rather than merely promised: if a future shape starts matching one
# of them, the assertion reds and names it.
id_never=('L1' 'L5' 'TICKET_RE' 'harness.estate')
#
# THE SHAPES — one row per retired token family: "LABEL<TAB>ERE<TAB>what a reader would have to look
# up". Add a row as each family is purged; this is a registry, not a fixed list. Both shapes below
# require a non-identifier character on each side and forbid a leading "$" or a trailing "=", which
# is how they see a PROSE REFERENCE and not a shell variable. That is deliberate: the
# ordinal-prefixed variable names inside the acceptance suite are OUT OF SCOPE here — the suite
# split deletes them, so renaming them in this phase would be work thrown away.
# Each shape is named first and the row then interpolates it, so a row states its three fields on
# one source line. The regexes are SINGLE-quoted here and were double-quoted when they sat inline,
# so the backslashes that escaped the two "$" characters there are simply absent here: the value
# handed to grep is the same string either way.
id_re_wave='(^|[^$A-Za-z0-9_])[MW][0-9]{1,2}($|[^A-Za-z0-9_=])'
id_re_ordinal='(^|[^A-Za-z0-9_.-])0[0-9]{2}[a-z]($|[^A-Za-z0-9_-])'
id_shapes=(
  "wave-milestone-tag	$id_re_wave	a wave or milestone tag"
  "ordinal-wave-tag	$id_re_ordinal	a zero-padded ordinal wave tag"
)

# dc_id_scan_file — one shape against one tracked file, hits capped at three so a swamped file
# still reads. Arguments: the file, the shape's label, its ERE, and what a reader would look up.
dc_id_scan_file() {
  local id_f=$1 id_label=$2 id_re=$3 id_why=$4 id_hits
  [ "$id_f" = "$id_decoder" ] && return 0          # THE single exemption — the history decoder
  [ -f "$id_f" ] || return 0
  id_hits=$(grep -nE -- "$id_re" "$id_f" | head -3)
  [ -z "$id_hits" ] && return 0
  dc_fail "no-lookup:$id_label" \
    "$id_f cites $id_why — a reader cannot decode it without leaving the file, and this family is" \
    "retired. Cite the GitHub issue number instead, or delete the reference; the ONLY tracked" \
    "place these are legal is the history decoder ($id_decoder)."
  printf '%s\n' "$id_hits" | sed 's/^/    /'
}

# dc_id_shape — one registry row: the never-banned assertion first, then the sweep of the surface.
dc_id_shape() {
  local id_row=$1 id_label id_tail id_re id_why id_n id_f
  id_label=${id_row%%	*}; id_tail=${id_row#*	}
  id_re=${id_tail%%	*}; id_why=${id_tail#*	}
  # The never-banned assertion, run against each string in the context it appears in (delimited by
  # spaces), so a shape that grew too greedy is caught here rather than by a red on a correct file.
  for id_n in "${id_never[@]}"; do
    printf ' %s ' "$id_n" | grep -qE -- "$id_re" || continue
    dc_fail "no-lookup:$id_label" \
      "this shape now matches '$id_n', which is ruled EXEMPT — a layer label is defined where it" \
      "is used, and the ticket pattern and the estate config key are plain English (and renaming" \
      "the config key de-arms every installed estate). Narrow the shape."
  done
  while IFS= read -r id_f; do
    dc_id_scan_file "$id_f" "$id_label" "$id_re" "$id_why"
  done < <(oh_surface)
}

dc_no_lookup() {
  local id_fail_before=$fail id_row
  # THE SWEPT SURFACE IS ASSERTED PRESENT (#269). dc_id_scan_file skips a path that is not a file —
  # an EXPLICIT silent skip, the plainest shape of this defect — and a retired tag inside a tracked
  # file that had left the working tree was therefore unreachable while this printed "zero
  # occurrences". Asserted ONCE here rather than per shape: the two shapes sweep the same surface,
  # so one message answers for both instead of doubling the same absence.
  dc_present no-lookup < <(oh_surface)
  for id_row in "${id_shapes[@]}"; do
    dc_id_shape "$id_row"
  done
  [ "$fail" -ne "$id_fail_before" ] || dc_ok no-lookup \
    "${#id_shapes[@]} retired token shape(s), zero occurrences outside the history decoder" \
    "($id_decoder). LIMIT: this catches SHAPES, so it stops a retired family coming back; it" \
    "cannot judge whether a live identifier is decodable."
}

# --- doc-sweep — the frozen sweep set, pinned as ONE named grep per swept surface ----------------
# Each swept user-facing surface = one assertion with its own prescriptive miss, so coverage of a
# surface cannot silently regress (cond 3 "cannot regress"). Extend this list when a NEW surface is
# swept; never blob it. Format: "LABEL<TAB>DOCUMENT<TAB>literal string that must appear in it".
# THE DOCUMENT IS A COLUMN RATHER THAN ONE CONSTANT (#146), because the surfaces this sweeps no
# longer all live on the front page: the folder map took three of them with it when it moved out.
# Pinning each row to its OWN document is what keeps the assertion exact — a telling that lands in
# the wrong document still reds, which is precisely what widening the haystack to "any front-door
# document" would stop seeing. Hence the rename off "readme-": the set is no longer README's alone.
dc_sweep_pairs() {
  printf '%s\n' \
    "ticket-naming	$MAP	YYYYMM" \
    "ticket-state-pending	$MAP	.ticket-pending" \
    "ticket-state-silenced	$MAP	.not-a-ticket" \
    "ticket-init-agent	$README	ticket-init" \
    "branch-workflow-anchor	$README	Fixes #" \
    "governance-checks	$README	governance.yml" \
    "ship-dev-manifest	$README	ship-manifest" \
    "venv-prerequisite	$README	venv_global" \
    "contributor-guide	$README	CONTRIBUTING"
}

dc_doc_sweep() {
  local pair label doc needle rest
  while IFS= read -r pair; do
    label=${pair%%	*}; rest=${pair#*	}
    doc=${rest%%	*}; needle=${rest#*	}
    grep -Fq -- "$needle" "$doc" && continue
    dc_fail "doc-sweep:$label" \
      "$doc no longer documents this surface (missing \"$needle\") — restore its telling."
  done < <(dc_sweep_pairs)
}

# --- grammar-drift — the branch regex's one home (branch-grammar.sh) quoted verbatim in its doc ---
# homes. Also documentation-state, so it lives here now (out of the demo). Revert-provable per home.
dc_grammar_drift() {
  local gd_re gd_home
  gd_re=$(grep -oE "BRANCH_RE='[^']+'" dev/scripts/branch-grammar.sh \
          | sed "s/^BRANCH_RE='//; s/'\$//")
  if [ -z "$gd_re" ]; then
    dc_fail grammar-drift "could not read BRANCH_RE from branch-grammar.sh"
    return 0
  fi
  for gd_home in CLAUDE.md README.md .github/CONTRIBUTING.md; do
    grep -Fq -- "$gd_re" "$gd_home" && continue
    dc_fail grammar-drift \
      "$gd_home does not quote the branch regex verbatim ($gd_re) — sync it to branch-grammar.sh."
  done
}

# --- ci-name-contract (#168) — the demo workflow still DECLARES the shape two required checks are
# built from. Two of this repository's required check names are written nowhere as literal strings:
# ONE job declares a name TEMPLATE over a two-value operating-system matrix, and the forge renders
# one check name per matrix value. Copy the template wrongly, or drop an operating system from the
# matrix, and those two checks stop reporting — which leaves every pull request PENDING FOREVER
# instead of failing visibly, the one failure mode a merge gate cannot survive because there is
# nothing red to read.
#
# WHY HERE AND NOT IN THE ACCEPTANCE DEMO: the demo is the truth-teller for the SHIPPED product;
# .github/workflows/** is development configuration that never reaches an installed estate (#43).
# Asserting a development fact from inside the product's own prover is precisely the classification
# confusion this gate exists to hold apart — and it is the obvious implementation, which is why the
# reason is written down here rather than left to be rediscovered.
#
# IT ASSERTS THE DECLARED SHAPE, NEVER A RENDERED NAME. The two reported names are a PRODUCT of the
# template and the matrix, so pinning a rendered string would assert a derived value — and would go
# green on a repository whose matrix had silently lost an operating system, because the surviving
# name still renders. The two declared parts are therefore read out of the job block and compared
# SEPARATELY, so a red names which half moved. The matrix is compared as a SORTED SET, so rewriting
# the flow list as a block list is not a false red while narrowing it is a true one.
#
# THE LIMIT, WHICH A GREEN HERE IS EASY TO OVER-READ: branch protection is the authority for WHICH
# check names are required, and that setting is NOT readable from the repository. This can only
# assert that the workflow still declares what it declared; it cannot see whether the names this
# shape renders are the names branch protection is waiting for. Nor does it assert that the job
# always REPORTS — a `paths:` filter or a job-level `if:` would break the same contract by a route
# this detector does not watch. Both are named in the ok-line rather than left implied.
#
# FOR A LATER READER OF THE one-home DETECTOR: the strings below are DELIBERATELY a second
# copy of strings living in the workflow file. That is exclusion 3 in action — a check name is an
# IDENTIFIER, and an identifier's repetition IS the contract, not a duplicated telling.

# dc_ci_block — the job's own block: from its key line at the jobs-child indent, down to the next
# key at that same indent. Reading the block (rather than the whole file) is what keeps the two
# extractions below pointed at THIS job when a second job is added to the workflow later.
dc_ci_block() {
  awk -v job="$ci_job" '
    $0 ~ "^  " job ":[[:space:]]*$" { inblk=1; next }
    inblk && /^  [^[:space:]#]/     { inblk=0 }
    inblk                           { print }
  ' "$ci_wf"
}

# dc_ci_name — the job's own name: line. A step is written "- name:", so anchoring on `name:` after
# whitespace only ever sees the job's. Surrounding quotes are stripped because either spelling is
# the same declaration (docs.yml quotes its job name, demo.yml does not).
dc_ci_name() {
  printf '%s\n' "$ci_block" | sed -n -E 's/^[[:space:]]*name:[[:space:]]*//p' | head -1 \
    | tr -d "\"'" | sed -E 's/[[:space:]]+$//'
}

# dc_ci_os — the matrix's operating systems, from EITHER YAML list spelling: a flow list on the
# `os:` line itself, or block-list "- item" lines under it. Sorted so the comparison is set-wise,
# not order-wise — reordering the list changes no check name and must not red.
dc_ci_os() {
  printf '%s\n' "$ci_block" | awk '
    /^[[:space:]]*os:/ {
      v = $0; sub(/^[[:space:]]*os:[[:space:]]*/, "", v)
      gsub(/[][,]/, " ", v)                                  # a flow list becomes bare words
      n = split(v, W, " "); for (i = 1; i <= n; i++) if (W[i] != "") print W[i]
      inos = 1; next
    }
    inos && /^[[:space:]]*-[[:space:]]*[^[:space:]]/ {       # a block-list item under os:
      v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v); sub(/[[:space:]]*$/, "", v); print v; next
    }
    inos { inos = 0 }
  ' | tr -d "\"'" | sort | tr '\n' ' ' | sed -E 's/[[:space:]]+$//'
}

# dc_ci_assert — the two declared parts, compared SEPARATELY so a red names which half moved.
dc_ci_assert() {
  [ "$ci_name" = "$ci_name_expect" ] || dc_fail "ci-name-contract:template" \
    "the '$ci_job' job in $ci_wf declares its name as \"$ci_name\", not \"$ci_name_expect\" —" \
    "that template, rendered once per matrix value, IS the required-check contract, and a check" \
    "that reports under a new name leaves every pull request pending rather than red. Restore the" \
    "template; if the rename is intended, change branch protection's required names FIRST, then" \
    "update this line."
  [ "$ci_os" = "$ci_os_expect" ] || dc_fail "ci-name-contract:matrix" \
    "the '$ci_job' job in $ci_wf declares the operating-system matrix as \"$ci_os\", not" \
    "\"$ci_os_expect\" — narrowing the matrix silently stops one required check reporting at all," \
    "which is worse than a red because nothing fails, the pull request simply never becomes" \
    "mergeable. Restore both operating systems; if the drop is intended, change branch" \
    "protection's required names FIRST, then update this line."
}

# dc_ci_ok — render the names from the two declared parts and print them, so the log shows what
# this shape produces today WITHOUT any assertion above resting on a rendered string.
dc_ci_ok() {
  local ci_os_arr ci_rendered="" ci_o ci_one
  read -ra ci_os_arr <<<"$ci_os"
  for ci_o in "${ci_os_arr[@]}"; do
    ci_one=$(printf '%s' "$ci_name_expect" | sed "s/\${{ matrix.os }}/$ci_o/")
    ci_rendered="$ci_rendered${ci_rendered:+, }$ci_one"
  done
  dc_ok "ci-name-contract" \
    "$ci_wf still declares the name template and both matrix operating systems; that shape" \
    "reports as: $ci_rendered. LIMIT: branch protection is the authority for WHICH names are" \
    "required and that setting is not readable from the repository, so this asserts only that the" \
    "workflow still declares what it declared — and it does not assert that the job always reports."
}

dc_ci_name_contract() {
  local ci_fail_before=$fail
  ci_wf=.github/workflows/demo.yml
  ci_job=demo                                # the job KEY as declared under `jobs:` in that file
  ci_name_expect='demo (${{ matrix.os }})'   # the name TEMPLATE, verbatim (single-quoted so bash
                                             # never reads it)
  ci_os_expect='macos-latest ubuntu-latest'  # the matrix's operating systems, as a SORTED set
  ci_block=$(dc_ci_block)
  ci_name=$(dc_ci_name)
  ci_os=$(dc_ci_os)
  if [ -z "$ci_block" ]; then
    dc_fail "ci-name-contract:job" \
      "$ci_wf declares no '$ci_job:' job under jobs: — that job is what generates the two" \
      "matrix-built required check names. Restore the job key; if it was renamed deliberately," \
      "change branch protection's required names FIRST, then re-point this detector."
  else
    dc_ci_assert
  fi
  [ "$fail" -eq "$ci_fail_before" ] || return 0
  dc_ci_ok
}

# --- map-complete (#82, operator ruling) — every top-level directory shipping PRODUCT files
# appears in the folder map. #85 shipped estate/General Human Knowledge/ as PRODUCT but no wave
# added
# it to the map; the rule closes that class of gap. MANIFEST-KEYED, not a hardcoded list: the
# directory set is derived from the PRODUCT paths in ship-manifest.txt, so a newly-shipped top-level
# dir is caught automatically. Directory names contain spaces, so match the literal path string —
# and ONLY inside the map's own fenced tree block (a prose mention elsewhere is NOT the map: the map
# is estate STRUCTURE). Revert-proof: remove a map line and this reds naming the directory.
# RE-POINTED WITH THE MAP (#146): it reads $MAP now, and the heading pattern admits any depth of
# "#" because the map's own document titles the section rather than sub-heading it.

# dc_mc_product_dirs — the top-level dir of each PRODUCT manifest path that lives under a directory
# (path contains a "/"). Lifted out of the loop below so the set can be COUNTED before it is walked
# (#269) — a set that is walked straight out of a process substitution can only be measured by the
# number of times the loop happened to run, which is exactly the number an absent registry makes
# zero.
# THE MAP IS THE ESTATE'S STRUCTURE, so the directories compared against it must be ESTATE-RELATIVE.
# A manifest row is repository-relative and the shipped tree now sits under estate/ (#136), so that
# prefix is stripped BEFORE the top directory is taken — without the strip every PRODUCT row reduces
# to the one directory "estate", which the map correctly does not draw, and this detector would
# demand a line that must never exist. A root-pinned PRODUCT file has no prefix and no directory,
# and drops out on the remaining slash test as before.
dc_mc_product_dirs() {
  awk -F'\t' '$1=="PRODUCT" { sub(/^estate\//, "", $2)
                if ($2 ~ /\//) { sub(/\/.*/, "", $2); print $2 } }' \
    dev/ship-manifest.txt | sort -u
}

dc_map_complete() {
  local mc_fail_before=$fail mc_map mc_dir mc_dirs mc_n
  # BOTH SUBJECTS ARE ASSERTED BEFORE EITHER IS USED (#269). This detector compares a REGISTRY
  # against a MAP, and the registry was the plainest instance of the whole class: delete
  # dev/ship-manifest.txt and the awk that derives the directory set printed nothing, the loop ran
  # zero times, nothing failed, and the ok-line announced that every PRODUCT top-level directory
  # appears in the folder map — printed by a detector that had opened no registry at all.
  dc_have map-complete "$MAP" "the folder map's tree block" || return 0
  dc_have map-complete dev/ship-manifest.txt "the PRODUCT top-level directory set" || return 0
  # the fenced tree block under the "The folder map" heading (between its first pair of ``` fences).
  mc_map=$(awk '
    /^#+ The folder map/ {seen=1; next}
    seen && /^```/ {fence++; if(fence==2) exit; next}
    seen && fence==1 {print}
  ' "$MAP")
  # AND THE DERIVED SET IS COUNTED, because a registry that exists but yields nothing leaves this
  # detector exactly as blind as a registry that is gone — same zero iterations, same success line.
  mc_dirs=$(dc_mc_product_dirs)
  mc_n=$(printf '%s\n' "$mc_dirs" | grep -c . || true)
  dc_have_min map-complete "$mc_n" 1 "PRODUCT top-level director(ies) in dev/ship-manifest.txt" \
    || return 0
  while IFS= read -r mc_dir; do
    grep -Fq -- "$mc_dir/" <<<"$mc_map" && continue
    dc_fail map-complete \
      "top-level directory '$mc_dir/' ships PRODUCT files (per dev/ship-manifest.txt) but is" \
      "absent from the folder map ($MAP) — add its tree line."
  done <<<"$mc_dirs"
  [ "$fail" -ne "$mc_fail_before" ] || dc_ok map-complete \
    "all $mc_n PRODUCT top-level directories appear in the folder map ($MAP)"
}

# --- install-home (#146) — THE INSTALL COMMANDS ARE TOLD ONCE ------------------------------------
# This is the SAFETY PROPERTY of splitting the install manual off the front page, not paperwork.
# An earlier collapse deleted the standalone install document and made the front page the only
# install home FOR A REASON: two install documents drift apart, and the one that drifts is the one
# somebody is reading when their install fails. Splitting the manual back off without this check
# would recreate exactly that defect — while looking like tidying.
#
# So the guarantee is RELOCATED, not dropped. It used to rest on there being only one document to
# tell it in; it now rests on an assertion, because there are deliberately two. Each registered
# command must appear in the manual and must NOT appear in README. BOTH directions are asserted:
# a command missing from the manual means the registry has rotted, and a rotted registry is green
# for the wrong reason — the failure mode that makes a gate worse than no gate.
#
# WHY NOT A ROW IN THE one-home REGISTRY ABOVE: that census blanks every token carrying a slash or
# a known file extension before it counts (its exclusion 1, which stops a manifest row reading as a
# telling). An install command is very nearly nothing but such tokens, so a row there would match
# nothing and report a rot that is not there. The commands are registered here instead, against the
# two documents by name.
#
# THE REGISTRY — one row per command: "LABEL<TAB>the literal command text". Substring rather than
# whole line, so a command keeps matching when the sentence around it is reworded. Unlike the
# one-home census this greps ONLY the two install documents, so this script's own source carrying
# the literals is not a third telling and needs no obfuscation. run_demo.sh is deliberately NOT
# registered: README names it in the development section for a different job, and registering it
# would red on a correct repository.
dc_ih_commands() {
  printf '%s\n' \
    "clone	git clone https://github.com/TheBoogieman/ai-work-harness.git" \
    "venv-create	python3.12 -m venv" \
    "nbformat	pip install nbformat" \
    "installer	bash estate/install.sh ~/Work" \
    "reconfigure	cd ~/Work && bash install.sh" \
    "arming	git -C <estate> config harness.estate true"
}

# REACHABILITY — the two documents must EXIST before a single row is grepped, and this is the check
# that says so. The two directions below fail in OPPOSITE ways when their document is gone: the rot
# direction reds on every row (grep finds nothing in a file that is not there), but the duplication
# direction is `grep … && dc_fail`, so a missing README makes the grep fail, the && short-circuits,
# and NOTHING is recorded — every row then passes on the manual alone and the detector announces a
# property it never checked. That is not hypothetical here: README is a document this programme is
# actively moving, and a safety check that goes quiet the moment its subject moves is worse than no
# check. So the existence of BOTH is asserted once, before the loop, naming whichever is missing;
# the caller skips the rows, because grepping a document that is not there proves nothing.
dc_ih_documents() {
  local ih_doc ih_gone=0
  for ih_doc in "$README" "$INSTALL_DOC"; do
    [ -f "$ih_doc" ] && continue
    ih_gone=1
    dc_fail install-home \
      "$ih_doc does not exist, so the install commands cannot be checked against it. This check" \
      "reads exactly two documents — $README and $INSTALL_DOC — and a missing one would let its" \
      "rows pass without being checked. Restore $ih_doc, or re-point this detector at the" \
      "document that replaced it (README= / INSTALL_DOC= at the head of this script)."
  done
  [ "$ih_gone" -eq 0 ]
}

dc_install_home() {
  local ih_before=$fail ih_row ih_label ih_cmd
  dc_ih_documents || return 0
  while IFS= read -r ih_row; do
    ih_label=${ih_row%%	*}; ih_cmd=${ih_row#*	}
    grep -Fq -- "$ih_cmd" "$README" && dc_fail "install-home:$ih_label" \
      "the install command \"$ih_cmd\" appears in $README as well as in $INSTALL_DOC. Install" \
      "commands have ONE home ($INSTALL_DOC) because two install documents drift apart — delete" \
      "the copy from $README and leave the pointer that sends the reader to the manual."
    grep -Fq -- "$ih_cmd" "$INSTALL_DOC" && continue
    dc_fail "install-home:$ih_label" \
      "$INSTALL_DOC no longer carries the install command \"$ih_cmd\" — this registry has rotted," \
      "and a rotted row is green for the wrong reason. Restore the command to $INSTALL_DOC, or" \
      "delete its row if the install genuinely no longer uses it."
  done < <(dc_ih_commands)
  [ "$fail" -ne "$ih_before" ] || dc_ok install-home \
    "$(dc_ih_commands | grep -c .) install command(s) told once, in $INSTALL_DOC and not in" \
    "$README. LIMIT: this pins the REGISTERED commands only — a command nobody registered can" \
    "still be told twice, so a new install command earns a row here."
}

# --- readme-no-diagrams — diagrams have EXITED README: zero .svg references (#42) ----------------
dc_readme_no_diagrams() {
  local svg_refs
  svg_refs=$(grep -c '\.svg' "$README" || true)
  [ "$svg_refs" -eq 0 ] && return 0
  dc_fail readme-no-diagrams \
    "README references a diagram ($svg_refs .svg mention(s)) — README must not embed diagrams;" \
    "keep only the pointer to estate/General AI-Knowledge/AI Harness/."
}

# --- adr-shape — estate/SPEC.md + the dev/decisions/ ADR backfill are well-formed
# (#69) -----------------------------------------------------------------------------------
# The project's decisions must stay readable: each ADR carries the four canonical headings, every
# real ADR cites at least one clickable evidence link, the shipped template stays empty, and SPEC.md
# keeps its glossary. Pure greps, each miss naming its exact fix — the demo owns behaviour,
# this owns doc-shape (cond 2/3). An evidence link is an issue ref (#NN) or a git commit sha
# (7+ hex).

# 1. every ADR (template included) must carry all four canonical section headings verbatim, so the
#    guard — and a human — can read any ADR the same way.
dc_adr_headings() {
  local adr=$1 h
  for h in '## Context' '## Decision' '## Consequences' '## Status'; do
    grep -Fqx -- "$h" "$adr" && continue
    dc_fail adr-shape \
      "$adr is missing the heading '$h' — every ADR carries Context/Decision/Consequences/Status" \
      "verbatim; add it."
  done
}

# 3. the template is an empty starter: it must carry <FILL> and must NOT carry a real evidence
#    link — a filled-in template is a defect (a copy that forgot to become its own ADR).
dc_adr_template() {
  local adr=$1
  grep -Fq -- '<FILL>' "$adr" || dc_fail adr-shape \
    "$adr is the template but has no <FILL> placeholder — restore the empty <FILL> sections."
  grep -qE -- "$adr_ev_re" "$adr" || return 0
  dc_fail adr-shape \
    "$adr is the template but carries a real evidence link (#NN or a sha) — a filled template is" \
    "a defect; keep it empty."
}

# 2. every real ADR must cite at least one evidence link so a stranger can click through to the
#    issue or commit that motivated the decision.
dc_adr_real() {
  local adr=$1
  grep -qE -- "$adr_ev_re" "$adr" && return 0
  dc_fail adr-shape \
    "$adr cites no evidence link — every backfilled ADR must reference at least one issue (#NN)" \
    "or commit sha; add one."
}

# 4. SPEC.md must name every glossary term, so the product's own vocabulary stays legible to a
#    newcomer. Each needle is checked case-insensitively with its own prescriptive miss.
#    THE DECODER TERM WAS REMOVED FROM THIS LIST (#123), and the reason is worth keeping: SPEC.md is
#    classified PRODUCT, so it installs onto a user's estate, while the shorthand the decoder
#    explained was the DEVELOPMENT rule numbering — content a user who will never develop the
#    harness cannot use. Those rules now live in full, under descriptive names, in the development
#    instructions (CLAUDE.md, DEV, never shipped). Requiring the word here would have forced the
#    shipped file to keep carrying development material to stay green.
#    The UNOWNED note that stood here — README's catalogue row still calling SPEC.md "glossary +
#    decoder" — is DISCHARGED: 703bb9b (#154) rewrote that row to describe what the file is for its
#    reader, so it no longer names a section that was deleted. The routing worked; the note is gone
#    rather than kept as a memorial: a discharged warning read later is itself a false claim.
dc_adr_spec() {
  local spec_body term
  if [ ! -f estate/SPEC.md ]; then
    dc_fail adr-shape \
      "estate/SPEC.md is missing — the project spec (the guarantees + the glossary) must" \
      "exist in the estate tree; restore it."
    return 0
  fi
  spec_body=$(cat estate/SPEC.md)
  for term in 'estate' 'guard' 'red/yellow' 'one-home' 'dumb inspector'; do
    grep -Fiq -- "$term" <<<"$spec_body" && continue
    dc_fail adr-shape \
      "estate/SPEC.md does not name '$term' — its glossary must cover estate, guard, red/yellow," \
      "one-home and dumb inspector; add it."
  done
}

dc_adr() {
  # adr_before snapshots the failure count so this ok-line answers for the ADRs only. It used to
  # test `$fail -ne 0`, and dc_main runs this detector well down the list: ANY earlier detector's
  # failure silenced it even when every record was well-formed, so the one run where a reader most
  # needs to know the decision records are still readable was the run that never said so (#252).
  local adr adr_before=$fail adr_set adr_n
  adr_ev_re='#[0-9]+|\b[0-9a-f]{7,40}\b'   # what counts as a clickable evidence link in an ADR
  # THE RECORD SET IS ASSERTED, NOT ASSUMED (#269). The loop below used to walk a list straight out
  # of a process substitution: with no records to list it ran zero times, nothing could fail, and
  # the ok-line reported every record well-formed on the strength of having read none. The SPEC.md
  # half of this detector never had that hole — dc_adr_spec tests its file exists and fails by name
  # — and it is the model these two lines copy rather than replace.
  adr_set=$(git ls-files 'dev/decisions/[0-9][0-9][0-9]-*.md')
  adr_n=$(printf '%s\n' "$adr_set" | grep -c . || true)
  dc_present adr-shape <<<"$adr_set"
  # The floor is TWO because it is a property of the question, not a number picked to pass today:
  # the case below has a template branch and a real-record branch, and a set that cannot exercise
  # both cannot answer for either.
  dc_have_min adr-shape "$adr_n" 2 "decision record(s) under dev/decisions/" || return 0
  while IFS= read -r adr; do
    [ -f "$adr" ] || continue                 # already reported by name, above
    dc_adr_headings "$adr"
    case "$(basename "$adr")" in
      000-adr-template.md) dc_adr_template "$adr" ;;
      *) dc_adr_real "$adr" ;;
    esac
  done <<<"$adr_set"
  dc_adr_spec
  [ "$fail" -ne "$adr_before" ] || dc_ok adr-shape \
    "estate/SPEC.md glossary present and all $adr_n dev/decisions/ ADRs well-formed"
}

# --- reader-agent (#82 / dev/decisions/018) — the reader spine, asserted PER-NAME not
# blanket --------------------------------------------------------------------------------
# The estate's four readers narrate the record with NO validator behind them, so the fabrication
# clause IS their whole safety story and must be present in each. The three EPHEMERAL readers write
# nothing, so they must hold no `edit` tool. The `retrospective` reader is the single-door WRITER
# (dev/decisions/018): it legitimately holds `edit`, so in place of a no-edit assert it must state
# its one
# write door AND its append-only discipline. Per-name so relaxing any one contract reds by name; a
# fifth reader is added to the loop when it ships. Basis: dev/decisions/018.
dc_reader_ephemeral() {
  local ra=$1 ra_f ra_tools
  ra_f="estate/_agents/$ra.agent.md"
  grep -Fq -- 'FABRICATED RECORD' "$ra_f" || dc_fail "reader-agent:$ra" \
    "$ra_f dropped the fabrication clause (no 'FABRICATED RECORD') — every reader carries it" \
    "verbatim; a reader that invents is caught by nothing else. Restore it."
  ra_tools=$(grep -iE '^tools:' "$ra_f" | head -1)
  printf '%s' "$ra_tools" | grep -qiwE 'edit' || return 0
  dc_fail "reader-agent:$ra" \
    "$ra_f lists an 'edit' tool — an ephemeral reader writes NOTHING; remove edit from its" \
    "frontmatter tools."
}

dc_reader_retrospective() {
  local ra_r=estate/_agents/retrospective.agent.md
  grep -Fq -- 'FABRICATED RECORD' "$ra_r" || dc_fail reader-agent:retrospective \
    "$ra_r dropped the fabrication clause (no 'FABRICATED RECORD') — restore it verbatim."
  grep -Fq -- 'EXACTLY ONE DOOR' "$ra_r" || dc_fail reader-agent:retrospective \
    "$ra_r no longer states its single write door ('EXACTLY ONE DOOR') — one output surface is" \
    "its whole safety story; restore it."
  grep -Fiq -- 'append-only' "$ra_r" || dc_fail reader-agent:retrospective \
    "$ra_r no longer states its append-only discipline ('append-only') — a retrospective is never" \
    "rewritten; restore it."
}

dc_reader_agent() {
  local ra_fail_before=$fail ra
  for ra in ticket-recall weekly-digest harness-recall; do
    dc_reader_ephemeral "$ra"
  done
  dc_reader_retrospective
  [ "$fail" -ne "$ra_fail_before" ] || dc_ok reader-agent \
    "4 readers carry the fabrication clause; 3 ephemeral readers hold no edit tool; retrospective" \
    "states single-door + append-only (edit permitted)"
}

# --- currency-note — DESIGN.md carries a dated diagram-currency note section (#42) ---------------
dc_currency_note() {
  grep -qiE 'Diagram currency \([0-9]{4}-[0-9]{2}-[0-9]{2}\)' "$DESIGN" && return 0
  dc_fail currency-note \
    "$DESIGN is missing its dated 'Diagram currency (YYYY-MM-DD)' note section — add/restore it."
}

# --- DEPICTED SET (#211) — the watched set is DERIVED FROM THE SHEETS, never listed here ---------
# The currency trigger below protects one claim: that the sheets are current with the machinery they
# draw. A change to machinery they do NOT draw cannot falsify that claim, so the watched set has to
# be what the drawings actually name. It used to be three path prefixes — _harness/scripts/,
# _agents/, _harness/hooks/ as they were spelled then, 26 tracked files against the 7 scripts
# the sheets depict — and the
# other nineteen fired a trigger their changes could not answer. Deriving it (rather than keeping a
# list here) means a redraw moves the watched set on the day it lands, with nothing to maintain.

# dc_design_depicted — every script basename the two sheets render, one per line, sorted. The sheet
# folder is $DESIGN's own directory, so the location stays in one home. SUBSTRING extraction is
# deliberate: two depicted names sit INSIDE a sentence rather than alone in a text node, and a
# whole-text-node reader silently returns five of the seven — a relaxation wearing the shape of a
# correction. Neither sheet uses <tspan>, so splitting is not the hazard; embedding is. -h keeps the
# filename off the matches when the glob expands to more than one sheet.
dc_design_depicted() {
  local sheet
  for sheet in "${DESIGN%/*}"/*.svg; do
    grep -ohE '[A-Za-z0-9_-]+\.(sh|py)' "$sheet" || true
  done | sort -u
}

# dc_design_sentinels — the basis that PROVES the extraction above still reads the sheets. It is a
# set of PROPERTIES, not a list of favourite names: each entry is here because it is the name that
# dies first when one property of the pattern is lost, and the set has to span every axis on which
# the pattern can degrade. A fourth name earns its place only by covering an axis these do not.
#   check_ticket_log.sh      EMBEDDED TEXT. Drawn inside a sentence ("check_ticket_log.sh audits
#                            state left by the PAST"), so a pattern narrowed to whole text nodes
#                            loses it while the five stand-alone names survive.
#   append_notebook_cell.py  EMBEDDED TEXT, second witness ("*via append_notebook_cell.py"), and
#                            the .py side of the extension alternation — a pattern reduced to .sh
#                            drops it and nothing else.
#   harness-status.sh        HYPHENATED NAME: the character class still admits "-". This axis is
#                            invisible to everything else here, because losing the hyphen does not
#                            delete names, it TRUNCATES them — harness-status.sh reads as
#                            status.sh, harness-housekeeping.sh as housekeeping.sh,
#                            ticket-grammar.sh as grammar.sh. The count is still 7, the two
#                            underscore-only sentinels above are untouched, and three depicted
#                            scripts go unwatched with every check green. Only a by-name check on
#                            a hyphenated name sees it.
dc_design_sentinels() {
  printf '%s\n' check_ticket_log.sh append_notebook_cell.py harness-status.sh
}

# dc_design_derive — validate the pattern against every sentinel name, THEN publish the count. A
# count from an unvalidated pattern is unmeasured, not a result, so the assertion comes first. It is
# made against NAMES THE SHEETS CARRY, never against the literal 7: seven is today's number and a
# redraw is meant to move it, whereas "the pattern can still see an embedded name" must keep holding
# through any redraw. Runs on every invocation, not only when machinery changed, so an extraction
# that has quietly stopped seeing part of the sheets reds the build instead of shrinking the watched
# set where nothing is looking.
dc_design_derive() {
  local depicted name derive_before=$fail
  depicted=$(dc_design_depicted)
  while IFS= read -r name; do
    printf '%s\n' "$depicted" | grep -qxF "$name" && continue
    dc_fail DESIGN-derive \
      "the sheets depict $name but the script-name extraction no longer finds it — the pattern" \
      "under-counts and the currency trigger's watched set has silently shrunk; fix the pattern."
  done < <(dc_design_sentinels)
  [ "$fail" -eq "$derive_before" ] || return 0
  dc_ok DESIGN-derive "$(printf '%s\n' "$depicted" | grep -c .) scripts depicted by the sheets —" \
    "the currency trigger's watched set, derived from the drawings, validated on embedded and" \
    "hyphenated names"
}

# --- DESIGN.md TRIGGER — depicted machinery changed without a currency-note disposition ----------
# (addition-C): if this PR touches a script the sheets DEPICT (the derived set above) and does NOT
# touch DESIGN.md, the note's honesty is an unanswered question -> RED, UNLESS the PR body carries
# [diagrams-unaffected: <non-empty reason>]. The machine can't judge whether prose reflects reality,
# but it can refuse to merge the unanswered question.
dc_design_trigger() {
  local changed reason dt_rc dt_depicted dt_n
  # BOTH SUBJECTS ARE ASSERTED UNDER THIS DETECTOR'S OWN TAG (#269), and the second one is why the
  # note that stood here is deleted rather than kept. It said an empty derived set was covered
  # "because dc_design_derive reds separately" — but that is a SIBLING's red, raised one detector
  # earlier over the same absence, and it leaves this detector just as blind as before. Reorder
  # dc_main and the blindness is live with nothing about this code having changed. A wall somebody
  # else is holding up is not this detector answering for itself.
  dt_depicted=$(dc_design_depicted)
  dt_n=$(printf '%s\n' "$dt_depicted" | grep -c . || true)
  dc_have_min DESIGN-trigger "$dt_n" 1 "script name(s) depicted by the sheets" || return 0
  if [ "${DOCS_CHANGED_FILES+x}" = x ]; then
    changed="$DOCS_CHANGED_FILES"
  else
    # THE CHANGE LIST IS THE OTHER SUBJECT, and its failure was swallowed: `2>/dev/null || true`
    # turned "there is no base ref to diff against" into an empty list, and an empty list matches no
    # depicted script, so a run that could not see the change set returned the same silent pass as a
    # run whose change set touched nothing drawn.
    changed=$(git diff --name-only "${DOCS_BASE_REF:-origin/main}...HEAD" 2>/dev/null); dt_rc=$?
    [ "$dt_rc" -eq 0 ] || { dc_fail DESIGN-trigger \
      "the changed-file list could not be read (git diff against" \
      "'${DOCS_BASE_REF:-origin/main}...HEAD' exited $dt_rc), so whether depicted machinery moved" \
      "is unknown — an empty list reads as 'nothing drawn changed' and would pass in silence." \
      "Fetch the base ref, set DOCS_BASE_REF, or pass DOCS_CHANGED_FILES directly."; return 0; }
  fi
  # Compare BASENAMES: the sheets name scripts, not paths. sed strips any directory; a changed path
  # with no slash is left alone.
  printf '%s\n' "$changed" | sed 's#.*/##' \
    | grep -qxFf <(printf '%s\n' "$dt_depicted") || return 0
  printf '%s\n' "$changed" | grep -qxF "$DESIGN" && return 0
  reason=$(printf '%s' "${PR_BODY:-}" | grep -oE '\[diagrams-unaffected:[^]]*\]' | head -1 \
           | sed -E 's/^\[diagrams-unaffected:[[:space:]]*//; s/[[:space:]]*\]$//')
  [ -n "$reason" ] && return 0
  dc_fail DESIGN-trigger \
    "machinery changed without a DESIGN.md currency-note update — update the note, or add" \
    "[diagrams-unaffected: reason] to the PR body."
}

# --- label-citation (#229) — every gate label a DOCUMENT cites is one this gate EMITS ------------
# Rename a failure label and leave a document naming the old one, and the reference breaks SILENTLY.
# That is not hypothetical. #196 renamed this gate's failure labels; the reviewer then executed the
# rename as a SABOTAGE — a label renamed in the gate at every occurrence, its citation in a shipped
# document left stale — and the gate PASSED, every detector green. A document naming a detector that
# no longer exists was invisible to every check this repository had.
# This is the SAME TECHNIQUE the DESIGN-derive detector above uses — derive the authority, then
# check the copy against it — pointed at the gate's own labels instead of at the drawings.
#
# BOTH SIDES ARE DERIVED, and that is the deliverable rather than a nicety. The EMITTED side is read
# out of this script's own dc_fail/dc_ok calls; the CITED side is found by scanning documents for
# the shapes a citation takes. A hand-written list of either would be a THIRD copy of the labels,
# stale on the first rename — the defect itself, not a smaller version of it. It was tried the human
# way in the same wave: two seats derived the citation set independently, agreed, and issued the
# agreed set as binding. It was ONE SITE OF SIX.
lc_gate=dev/scripts/docs-check.sh          # THIS file: the authority for what the gate emits
lc_name=$(basename "$lc_gate" .sh)             # how a document names the gate; derived, not typed
lc_tok='[A-Za-z0-9]+(-[A-Za-z0-9]+)+'          # a label's shape: hyphen-joined alphanumeric words
lc_hard='#69 ADR'                              # the hard validation instance (see dc_lc_validate)

# dc_lc_emitted — the EMITTED set, from a gate source arriving on STDIN (so the real file and the
# validation fixture below go through one code path). Comment lines are dropped first: this file's
# own prose names dc_fail and dc_ok where it explains them, and a comment is not a call.
# A label may be bare or double-quoted, and a quoted one may contain SPACES and a leading "#" — the
# alternation matches the whole quoted run rather than stopping at the first space, and no character
# class here excludes "#". Those are the exact two axes on which the earlier hand-rolled patterns
# failed, so dc_lc_validate pins both rather than trusting that they still hold.
# NORMALISATION, two steps, each for a stated reason:
#   * a label ending in an interpolated variable ("one-home:$oh_name") names a FAMILY, not a label —
#     truncate at the "$" and keep the stable prefix, which is the part a document can cite at all.
#   * a label carrying a ":" ALSO registers its prefix, because documents cite by prefix as well as
#     by full name. Without this a document citing "doc-sweep" reds against a gate that only ever
#     prints "doc-sweep:<row>" — a false red on a correct repository.
dc_lc_emitted() {
  grep -vE '^[[:space:]]*#' \
    | grep -oE 'dc_(fail|ok)[[:space:]]+("[^"]*"|[^[:space:]]+)' \
    | sed -E 's/^dc_(fail|ok)[[:space:]]+//; s/^"//; s/"$//' \
    | awk '{ sub(/\$.*$/, ""); sub(/:$/, ""); if ($0 == "") next
             print; if (index($0, ":") > 0) { p = $0; sub(/:.*/, "", p); print p } }' \
    | sort -u
}

# dc_lc_validate — THE VALIDATION BASIS, and it is a CONSTRUCTED FIXTURE rather than a live label on
# purpose. THE INSTANCE IS "#69 ADR": the label this gate printed for its ADR-shape detector until
# 8934f44 (#196) renamed it. It is quoted, TWO WORDS, and "#"-prefixed — the three properties on
# which the two earlier extractions silently failed (one character class excluded the leading "#";
# the other handled "#" but could not match past an opening quote), and which NO label live at HEAD
# still carries. A live sentinel would therefore be a basis with an expiry date, which is the second
# way this check has already been got wrong: a derivation was validated against a label set captured
# BEFORE a merge that deliberately deleted it — the pattern was sound and the BASIS was stale. A
# fixture cannot be removed by a merge, and it asserts the property that must keep holding rather
# than a name the repository may change. A pattern whose class drops "#" returns nothing here; one
# that cannot read past the opening quote returns "#69"; the same compare catches both.
# The fixture line is assembled by printf from two arguments so that this source line carries no
# literal call for dc_lc_emitted to extract when it reads this file for real.
dc_lc_validate() {
  local lc_got
  lc_got=$(printf '%s "%s" \\\n' dc_fail "$lc_hard" | dc_lc_emitted)
  [ "$lc_got" = "$lc_hard" ] && return 0
  dc_fail label-citation:extraction \
    "the label extraction reads the fixture \"$lc_hard\" as \"$lc_got\" — that fixture is quoted," \
    "two words and \"#\"-prefixed because those are the three properties this pattern has lost" \
    "silently before, and a pattern's gaps do not announce themselves. Fix the pattern; never" \
    "weaken the fixture to match it."
  return 1
}

# dc_lc_scope — the documents held to citing correctly, from TWO derived sources, because either one
# alone leaves the hole this detector exists to close.
#   (a) every tracked file that NAMES the gate. That is most citation sites, README's document
#       catalogue among them.
#   (b) every tracked file the GATE ITSELF names by a CONCRETE path. Source (a) cannot see
#       dev/decisions/018, which cites reader-agent without ever naming the gate. Scoping instead on
#       "names a label we emit" would be CIRCULAR: rename a label and the file leaves the scope on
#       the same commit that made its citation stale — silence at exactly the moment the red is
#       owed. What the gate POINTS AT does not move when a label is renamed, so (b) survives the
#       rename. A globbed reference is not a concrete path and is skipped by the character class,
#       which is why "dev/decisions/**" does not drag every record into scope.

# dc_lc_named_by_gate — source (b) for ONE file: true when some concrete path the gate names is a
# prefix of it. Its own function so the prefix loop is not a third nesting level inside the sweep.
# $lc_paths is those concrete paths, built once by the caller below.
dc_lc_named_by_gate() {
  local lc_t
  while IFS= read -r lc_t; do
    case "$1" in "$lc_t"*) return 0 ;; esac
  done <<<"$lc_paths"
  return 1
}

dc_lc_scope() {
  local lc_f
  # A token ending in a separator is dropped, because it names a DIRECTORY and this source is the
  # one that has to stay CONCRETE — "a globbed reference is not a concrete path", as the comment
  # above already says. That used to fall out of the character class for free: the decision
  # records sat at "decisions/", where the class finds no X/Y pair before the glob that follows.
  # They now sit one level down (#136), so "dev/decisions/" IS such a pair, and every record would
  # join this scope purely because a path was rewritten — a move widening a detector's reach,
  # which is not something a move may do. Saying it as the rule rather than leaving it to depend
  # on where a directory happens to sit is what stops it moving again.
  lc_paths=$(grep -ohE '[A-Za-z0-9_.][A-Za-z0-9_./-]*/[A-Za-z0-9_.][A-Za-z0-9_./-]*' "$lc_gate" \
             | grep -v '/$' | sort -u)
  while IFS= read -r lc_f; do
    { [ -f "$lc_f" ] && [ "$lc_f" != "$lc_gate" ]; } || continue
    grep -Fq -- "$lc_name" "$lc_f" 2>/dev/null || dc_lc_named_by_gate "$lc_f" || continue
    printf '%s\n' "$lc_f"
  done < <(oh_surface)
}

# dc_lc_cited — the CITED set as "<label> <file>" rows, from the two shapes a citation actually
# takes here. Both were READ OFF THE REAL SITES, never imagined: a detector's reach is the sum of
# what has been found.
#   S1  a parenthesised label on a line that names the gate — README's catalogue column, which
#       writes `docs-check` (adr-shape) and `docs-check` (adr-shape: the glossary check). The label
#       must OPEN the parenthesis, so "(the honest-lag record)" on those same rows stays prose.
#   S2  a label immediately before the word "detector" — how the decision records cite it, as in
#       "the docs-check grammar-drift detector" and "reader-agent detector checks the spine".
# REQUIRING A HYPHEN is what keeps "the reader detector" — a concept, not a label — out of S2.
# A label never contains a space, so a space is a safe field separator for the rows.
# $lc_tok is braced at both sites because a bracket expression follows it, and an unbraced name
# followed by "[" reads as an array subscript to a linter rather than as the regex it is.
dc_lc_cited() {
  local lc_f
  while IFS= read -r lc_f; do
    grep -hE -- "$lc_name" "$lc_f" 2>/dev/null | grep -oE "\(${lc_tok}[):;,]" \
      | sed -E 's/^\(//; s/[):;,]$//' | awk -v f="$lc_f" '{ print $0 " " f }'
    grep -ohE -- "${lc_tok}[[:space:]]+detectors?\b" "$lc_f" 2>/dev/null \
      | sed -E 's/[[:space:]]+detectors?$//' | awk -v f="$lc_f" '{ print $0 " " f }'
  done < <(dc_lc_scope)
}

# dc_label_citation — the comparison. Matching is case-insensitive: a citation differing from the
# printed label only in case still resolves for the reader who follows it, and redding on that would
# be pedantry rather than a broken reference.
dc_label_citation() {
  local lc_before=$fail lc_emitted lc_rows lc_row lc_label
  dc_lc_validate || return 0
  # THE CITATION SCOPE'S SOURCE IS ASSERTED PRESENT (#269). dc_lc_scope keeps a candidate only if
  # `[ -f ]` holds, so a tracked document missing from the working tree never entered the scope at
  # all and its stale citation was never compared against anything — this printed a citation count
  # and a green verdict over a document set with holes in it. The assertion is made on oh_surface,
  # the set the scope is DERIVED FROM, because a file that never entered the scope is exactly what
  # a check on the scope cannot see.
  dc_present label-citation < <(oh_surface)
  lc_emitted=$(dc_lc_emitted < "$lc_gate")
  if [ -z "$lc_emitted" ]; then
    dc_fail label-citation:emitted \
      "no label could be read out of $lc_gate — an EMPTY emitted set would make every citation" \
      "below wrong at once, so this reds instead of comparing against nothing."
    return 0
  fi
  lc_rows=$(dc_lc_cited | sort -u)
  while IFS= read -r lc_row; do
    [ -n "$lc_row" ] || continue
    lc_label=${lc_row%% *}
    printf '%s\n' "$lc_emitted" | grep -qxFi -- "$lc_label" && continue
    dc_fail label-citation \
      "${lc_row#* } cites the gate label \"$lc_label\", which this gate does not emit — a renamed" \
      "label leaves its citation resolving to nothing, and no other check in this repository sees" \
      "that. Re-point the citation at the label the gate prints today, or delete it."
  done <<<"$lc_rows"
  [ "$fail" -eq "$lc_before" ] || return 0
  dc_ok label-citation \
    "$(printf '%s' "$lc_rows" | grep -c .) (label, document) citation(s) across the documents" \
    "coupled to this gate, each label one the gate emits; the extraction is validated on a" \
    "quoted, multi-word," \
    "\"#\"-prefixed fixture (\"$lc_hard\", retired by 8934f44). LIMIT: it reads the TWO citation" \
    "shapes found in this repository — a parenthesised label beside a mention of the gate, and a" \
    "label before the word \"detector\" — so a citation written a third way is not seen."
}

# --- DOC-INTEGRITY (#51) — mechanical "no mangled doc" guards over every tracked *.md ------------
# The simplify pass rewrites prose into lists; lists are where half-closed fences and orphaned links
# are born. These three detectors gate #51's OWN delivery PR (mechanical, revert-provable per
# detector) instead of leaving mangling to a human eyeball. SCOPE: intra-repo only — external URLs
# and template placeholders are skipped, so a required check never reds on the network. Runs on GNU
# grep only (docs.yml is ubuntu; the dev seat is Cygwin), never on macOS/BSD — the demo owns that.

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

# dead-pointer (#51 collapse) — the standalone flat-pack install doc was folded into README
# Setup and DELETED. No tracked file may still name it: a dead pointer to a removed file ships dead
# on a user estate. That file stays deleted; what has changed since (#146) is that "one install
# home" is no longer a consequence of there being one document — the install-home detector above
# asserts it directly, and $INSTALL_DOC is where a stale pointer should now be sent. The needle is
# assembled from two string
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

# UNOWNED — found while reading this file end to end for the #129 shape pass, which was scoped to
# SHAPE ONLY, so it is recorded rather than fixed; other items are queued against this file.
#   * THE OK-LINES ARE NOT THE DETECTOR SET. The closing line of dc_main points a reader at them
#     for "the detector set at HEAD", but only nine detectors emit one: doc-sweep,
#     grammar-drift, readme-no-diagrams, currency-note, DESIGN-trigger and the four
#     doc-integrity detectors (fence-balance, doc-crlf, link-target/link-anchor, dead-pointer)
#     print nothing when they pass. A green log therefore names half the instrument while
#     reading as if it named all of it.
# The note that stood beneath it — two ok-lines testing the global flag "where the other seven
# compare against the value their own detector saved before starting" — is DELETED rather than
# corrected (#252). Neither half survives: no ok-line tests the shared record directly any more,
# and the "other seven" was itself a miscount of the snapshot sites, which were ten in two
# spellings. A discharged warning read later is a false claim in its own right, so it goes; the
# behaviour it described is now guarded by [docs-gate-ok-lines] in the acceptance suite.

# dc_main — the detectors, in the order their output has to appear. This list IS the running order;
# nothing else in the file decides it.
dc_main() {
  dc_map_inventory
  dc_dev_loop
  dc_de_number
  dc_one_home
  dc_no_lookup
  dc_doc_sweep
  dc_grammar_drift
  dc_ci_name_contract
  dc_map_complete
  dc_install_home
  dc_readme_no_diagrams
  dc_adr
  dc_reader_agent
  dc_currency_note
  dc_design_derive
  dc_design_trigger
  dc_label_citation
  dc_fence_balance
  dc_doc_crlf
  dc_link_targets
  dc_dead_pointer
  [ "$fail" -eq 0 ] || { echo "docs-check: FAILED — each line above names its fix."; exit 1; }
  echo "docs-check: all detectors pass — see the ok-lines above for the detector set at HEAD."
}

dc_main
