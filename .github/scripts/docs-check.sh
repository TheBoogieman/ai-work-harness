#!/usr/bin/env bash
# docs-check.sh — CI-side documentation governance (#42). It gates MERGES; the demo gates the
# PRODUCT — two truths, two instruments (cond 3). DEV infrastructure: it lives under .github/ and
# NEVER ships to a user estate (#43); no PRODUCT script references it. Pure greps, zero judgment,
# each detector's failure names its exact fix (addition-D). The demo carries ZERO README knowledge
# (cond 2); all documentation-state checks live here, in ONE home.
#
# Inputs (so the detectors are testable locally AND in CI):
#   PR_BODY               the pull-request body text (for the [diagrams-unaffected] token)
#   DOCS_CHANGED_FILES    newline list of files changed in the PR; if unset, computed from git
#   DOCS_BASE_REF         base ref for the diff when DOCS_CHANGED_FILES is unset (default origin/main)
set -uo pipefail
fail=0
README=README.md
DESIGN="General AI-Knowledge/AI Harness/DESIGN.md"
readme_body=$(cat "$README")

# --- B1 INVENTORY — every shipped script + the two root surfaces named in README's folder map ---
# (the #34 docs-inventory guard, MIGRATED out of run_demo.sh; it gates merges now, not the demo.)
b1_total=0
for s in _harness/scripts/* install.sh setup.md; do
  base=$(basename "$s"); b1_total=$((b1_total+1))
  grep -Fq -- "$base" <<<"$readme_body" \
    || { echo "FAIL [docs B1-inventory]: $base ships but is not named in README's folder map — add its tree line."; fail=1; }
done
[ "$fail" -ne 0 ] || echo "  ok [docs B1-inventory] — $b1_total shipped surfaces named in README"

# --- #68 DEV-LOOP — DEVELOPMENT.md + dev-loop/ starter kit: three method-doc invariants -----------
# This lane ships a method doc plus empty adopt-and-fill templates. Three things must hold or the
# artifact lies. (1) Templates stay EMPTY: a filled field is instance material leaking into the repo.
# (2) The method files name NO AI vendor: the method is assistant-agnostic, so a product name breaks
# that claim. (3) DEVELOPMENT.md actually carries the four role names and five working laws it claims
# to teach. Scoped to THIS lane's own files (DEVELOPMENT.md + dev-loop/**) so README's legitimate
# vendor mention elsewhere is never touched. dl_fail_before snapshots $fail so the ok-line prints
# only when all three invariants held this run.
dl_fail_before=$fail

# 1. TEMPLATES KEEP A <FILL> BLANK — every dev-loop/*.template.md must retain AT LEAST ONE literal
# <FILL> token. The check is presence-of-one, so it fires only when NONE is left (a FULLY-filled
# template), not on a partial fill — the message and ok-line say exactly that, no stronger (#82).
for dl_t in dev-loop/*.template.md; do
  grep -Fq -- '<FILL>' "$dl_t" \
    || { echo "FAIL [docs #68 dev-loop]: $dl_t has no <FILL> token left — a template must keep at least one <FILL> blank as proof it ships as a skeleton; restore a <FILL> blank."; fail=1; }
done

# 2. VENDOR-NEUTRAL — no AI product name appears in DEVELOPMENT.md or dev-loop/**. Word-anchored (-w)
# and case-insensitive (-i) so the method-level prose stays product-free; scoped by git ls-files to
# this lane's files only, never README.
dl_vendors='claude|copilot|chatgpt|gpt|anthropic|openai|gemini|cursor'
while IFS= read -r dl_f; do
  dl_hit=$(grep -niwE -- "$dl_vendors" "$dl_f" | head -1 || true)
  [ -z "$dl_hit" ] \
    || { echo "FAIL [docs #68 dev-loop]: $dl_f names an AI vendor ($dl_hit) — DEVELOPMENT.md and dev-loop/** are vendor-neutral; remove the product name."; fail=1; }
done < <(git ls-files DEVELOPMENT.md 'dev-loop/*')

# 3. ROLES AND LAWS PRESENT — DEVELOPMENT.md carries the four role words and one needle per working
# law, each pinned as its own named assertion (the b2_pairs style above) so a dropped role or law
# reds by name rather than vanishing silently. Format: "LABEL<TAB>literal string in DEVELOPMENT.md".
dl_pairs=(
  "role-architect	ARCHITECT"
  "role-reviewer	REVIEWER/PRODUCT-OWNER"
  "role-implementer	IMPLEMENTER"
  "role-operator	OPERATOR"
  "law1-verbatim-specs	verbatim issue bodies"
  "law2-audit-confirms	confirms or reopens"
  "law3-regression-guard	provably fails on pre-fix code"
  "law4-attack-cycle	attack cycle"
  "law5-claims-at-head	live at HEAD"
)
for dl_pair in "${dl_pairs[@]}"; do
  dl_label=${dl_pair%%	*}; dl_needle=${dl_pair#*	}
  grep -Fq -- "$dl_needle" DEVELOPMENT.md \
    || { echo "FAIL [docs #68 dev-loop:$dl_label]: DEVELOPMENT.md no longer states this (missing \"$dl_needle\") — restore it."; fail=1; }
done

[ "$fail" -ne "$dl_fail_before" ] || echo "  ok [docs #68 dev-loop] — each template keeps a <FILL> blank, vendor-neutral, 4 roles + 5 laws present in DEVELOPMENT.md"

# --- de-number (#82 / #85) — no NUMERIC agent-count claim survives #85's de-numbering conversion --
# #85 turned the roster count into role-named prose because the agent set GROWS (six → ten over the
# sprint); a re-introduced "six agents" would be false the next time an agent lands. TWO word-anchored,
# case-insensitive patterns over the de-numbered doc surfaces (README, the constitution, DESIGN.md):
#   (a) a number-word IMMEDIATELY before "agent(s)"  — e.g. "six agents" (README's "six-rule contract"
#       says "rule", not "agent", so it is correctly out of this pattern's reach).
#   (b) a number-word plus "file(s)" on any line naming a ".agent.md" — the agent-file-count shape that
#       pattern (a) cannot see.
# EXEMPTION is PARAGRAPH-scoped: DESIGN.md's honest-lag notes legitimately carry the stale sheet
# counts ("SIX AGENTS"), so lines from one that BEGINS "**Diagram currency" until the next blank line
# are skipped. Paragraph-scoped, NOT heading-scoped — a heading scope would also swallow the live
# claims below the notes, the exact regression caught pre-spec and forbidden here.
dn_fail_before=$fail
dn_num='one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|[0-9]+'
for dn_f in "$README" folder-structure.md "$DESIGN"; do
  dn_exempt=0; dn_lineno=0
  while IFS= read -r dn_line || [ -n "$dn_line" ]; do
    dn_lineno=$((dn_lineno+1))
    # a currency paragraph opens on its "**Diagram currency" line and closes at the next blank line.
    printf '%s' "$dn_line" | grep -q '^\*\*Diagram currency' && dn_exempt=1
    [ -z "${dn_line//[[:space:]]/}" ] && dn_exempt=0
    [ "$dn_exempt" -eq 1 ] && continue           # skip the exempt honest-lag lines
    # (a) number-word directly before agent(s)
    if printf '%s' "$dn_line" | grep -qiE "\b(${dn_num})[[:space:]]+agents?\b"; then
      dn_hit=$(printf '%s' "$dn_line" | grep -oiE "\b(${dn_num})[[:space:]]+agents?\b" | head -1)
      echo "FAIL [docs de-number:a]: $dn_f:$dn_lineno states a numeric agent count (\"$dn_hit\") — #85 de-numbered the roster because it grows; name the agents by role, not by a count that goes stale."; fail=1
    fi
    # (b) number-word + file(s) on a line that names a .agent.md
    if printf '%s' "$dn_line" | grep -qF '.agent.md' \
       && printf '%s' "$dn_line" | grep -qiE "\b(${dn_num})\b" \
       && printf '%s' "$dn_line" | grep -qiE '\bfiles?\b'; then
      echo "FAIL [docs de-number:b]: $dn_f:$dn_lineno pairs a number with '.agent.md file(s)' — the agent-file count is not fixed; describe the set without a count."; fail=1
    fi
  done < "$dn_f"
done
[ "$fail" -ne "$dn_fail_before" ] || echo "  ok [docs de-number] — no numeric agent-count claim outside the DESIGN.md currency notes (README, constitution, DESIGN.md)"

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

# --- #121 ONE TELLING PER REGISTERED PHRASE ------------------------------------------------------
# The assertion is NARROW and the narrowness is the deliverable: no REGISTERED PHRASE appears in
# more than one document. It is NOT "each fact is told once" — phrase matching cannot decide that.
# Each fact may register several phrasings so that known restatements are caught and not only exact
# copies; it catches verbatim re-telling and the reintroduction of a registered phrasing, and it
# NEVER catches paraphrase. That limit is printed in this detector's own ok-line, because a green
# build read as "this fact has one home" would make the instrument built to enforce claims-truth
# ship a false claim about itself.
#
# THE THREE EXCLUSIONS ARE NOT THREE OF A KIND. A later reader who collapses them into one rule
# about "things that look like duplicates" will delete the third and break the repository:
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
#       break the checks. So an alias that also appears in a workflow file is rejected as a
#       registration error, loudly and by name, before any counting happens.
#
# THE REGISTRY — one row per registered FACT: "DISPLAY-NAME<TAB>HOME<TAB>alias|alias|...". The
# display name is for the human reading a failure; it is never a key, because naming a fact the way
# a human names it is the worst possible key for it. Matching is lowercase and whitespace-flattened,
# so aliases are written lowercase. WORDS INSIDE AN ALIAS ARE JOINED WITH "~", NOT A SPACE: this
# file is itself on the census surface, so a contiguous alias here would make the registry a second
# telling of every fact it registers (the same self-match the C7d needle is split to avoid). The
# loader restores the spaces and reds on a literal space, so the rule cannot be forgotten. This
# registry is expected to GROW as drift is found — add a row, never a second census.
oh_registry=(
  "guard-per-bug exempt classes	CLAUDE.md	documentation~and~prose|comment-only~passes|pure~renames~and~moves"
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
oh_fail_before=$fail
oh_workflows=$(cat .github/workflows/*.yml 2>/dev/null || true)
oh_files=()
while IFS= read -r oh_f; do [ -f "$oh_f" ] && oh_files+=("$oh_f"); done < <(oh_surface)
for oh_row in "${oh_registry[@]}"; do
  oh_name=${oh_row%%	*}; oh_tail=${oh_row#*	}
  oh_home=${oh_tail%%	*}; oh_alias_field=${oh_tail#*	}
  oh_home_lc=$(printf '%s' "$oh_home" | tr 'A-Z' 'a-z')
  case "$oh_alias_field" in
    *\ *) echo "FAIL [docs one-home:$oh_name]: an alias in this row contains a literal space — join an alias's words with '~' so this script's own source never carries the contiguous phrase it hunts for, or the registry becomes a second telling of the fact."; fail=1 ;;
  esac
  oh_alias_field=${oh_alias_field//\~/ }
  # EXCLUSION 3, enforced at REGISTRATION time (see the note above) — never at scan time. A rejected
  # row is not then counted: the registration is the defect, and one cause gets one message.
  oh_al=$oh_alias_field; oh_rejected=0
  while [ -n "$oh_al" ]; do
    oh_a=${oh_al%%|*}; [ "$oh_al" = "$oh_a" ] && oh_al="" || oh_al=${oh_al#*|}
    grep -Fqi -- "$oh_a" <<<"$oh_workflows" \
      && { echo "FAIL [docs one-home:$oh_name]: the registered phrase \"$oh_a\" also appears in .github/workflows/ — that makes it an IDENTIFIER, and an identifier's repetition is the contract, not a duplication. Delete the alias from the registry; never register a string that a machine matches."; fail=1; oh_rejected=1; }
  done
  [ "$oh_rejected" -eq 0 ] || continue
  # THE CENSUS, in one awk pass over the whole surface. RS="" reads a PARAGRAPH at a time and the
  # gsub squeezes its newlines to single spaces, which is what makes the match
  # WHITESPACE-INSENSITIVE — and that is not a nicety: prose wraps, so a registered phrase can sit
  # across a line break, and a line-oriented census then returns ZERO for it, which is the wrong
  # answer rather than a near miss. tolower() matters for the same reason: a doctrine written as a
  # capitalised banner is the same telling as the same words in a sentence. One file counts once.
  oh_homes=$(awk -v aliases="$oh_alias_field" -v home="$oh_home_lc" -v ptrmax="$oh_ptr_max" \
                 -v pathre="$oh_pathre" -v extre="$oh_extre" '
    BEGIN { RS=""; n = split(aliases, A, "|") }
    {
      if (FILENAME in hit) next
      p = tolower($0); gsub(/[[:space:]]+/, " ", p); sub(/^ /, "", p)
      if (index(p, home) > 0 && length(p) <= ptrmax) next          # a short paragraph naming the home is a POINTER
      b = p; gsub(pathre, " ", b); gsub(extre, " ", b)             # EXCLUSION 1
      for (i = 1; i <= n; i++) if (index(b, A[i]) > 0) { hit[FILENAME] = A[i]; break }
    }
    END { for (f in hit) print f " (matched: \"" hit[f] "\")" }
  ' "${oh_files[@]}" | sort)
  oh_count=$(printf '%s' "$oh_homes" | grep -c . || true)
  if [ "$oh_count" -gt 1 ]; then
    echo "FAIL [docs one-home:$oh_name]: this registered fact is told in $oh_count documents — a registered fact has exactly ONE home ($oh_home). Delete the other telling(s) and leave a pointer to the home, or drop the alias if the second occurrence is not a telling. Locations:"
    printf '%s\n' "$oh_homes" | sed 's/^/    /'
    fail=1
  elif [ "$oh_count" -eq 0 ]; then
    echo "FAIL [docs one-home:$oh_name]: no registered phrase for this fact matches anything tracked — the registry has rotted (the telling was reworded, so the row now guards nothing). Re-key the row to the wording that is live at HEAD, or delete the row."; fail=1
  fi
done
[ "$fail" -ne "$oh_fail_before" ] || echo "  ok [docs one-home] — ${#oh_registry[@]} registered fact(s), each told in exactly ONE document. LIMIT: green means no REGISTERED phrase reached a second document — verbatim re-telling and reintroduced registered phrasings only, NEVER paraphrase; the registry grows as drift is found."

# --- #122 NO IDENTIFIER THAT NEEDS A LOOKUP OUTSIDE THE FILE --------------------------------------
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
id_shapes=(
  "wave-milestone-tag	(^|[^\$A-Za-z0-9_])[MW][0-9]{1,2}(\$|[^A-Za-z0-9_=])	a wave or milestone tag"
  "ordinal-wave-tag	(^|[^A-Za-z0-9_.-])0[0-9]{2}[a-z](\$|[^A-Za-z0-9_-])	a zero-padded ordinal wave tag"
)
id_fail_before=$fail
for id_row in "${id_shapes[@]}"; do
  id_label=${id_row%%	*}; id_tail=${id_row#*	}
  id_re=${id_tail%%	*}; id_why=${id_tail#*	}
  # The never-banned assertion, run against each string in the context it appears in (delimited by
  # spaces), so a shape that grew too greedy is caught here rather than by a red on a correct file.
  for id_n in "${id_never[@]}"; do
    printf ' %s ' "$id_n" | grep -qE -- "$id_re" \
      && { echo "FAIL [docs no-lookup:$id_label]: this shape now matches '$id_n', which is ruled EXEMPT — a layer label is defined where it is used, and the ticket pattern and the estate config key are plain English (and renaming the config key de-arms every installed estate). Narrow the shape."; fail=1; }
  done
  while IFS= read -r id_f; do
    [ "$id_f" = "$id_decoder" ] && continue          # THE single exemption — the history decoder
    [ -f "$id_f" ] || continue
    id_hits=$(grep -nE -- "$id_re" "$id_f" | head -3)
    [ -z "$id_hits" ] && continue
    echo "FAIL [docs no-lookup:$id_label]: $id_f cites $id_why — a reader cannot decode it without leaving the file, and this family is retired. Cite the GitHub issue number instead, or delete the reference; the ONLY tracked place these are legal is the history decoder ($id_decoder)."
    printf '%s\n' "$id_hits" | sed 's/^/    /'
    fail=1
  done < <(oh_surface)
done
[ "$fail" -ne "$id_fail_before" ] || echo "  ok [docs no-lookup] — ${#id_shapes[@]} retired token shape(s), zero occurrences outside the history decoder ($id_decoder). LIMIT: this catches SHAPES, so it stops a retired family coming back; it cannot judge whether a live identifier is decodable."

# --- B2 FROZEN SWEEP SET — the cond-1 zero-gap matrix, pinned as ONE named grep per surface -----
# Each swept user-facing surface = one assertion with its own prescriptive miss, so coverage of a
# surface cannot silently regress (cond 3 "cannot regress"). Extend this list when a NEW surface is
# swept; never blob it. Format: "LABEL<TAB>literal string that must appear in README".
b2_pairs=(
  "ticket-naming	YYYYMM"
  "ticket-state-pending	.ticket-pending"
  "ticket-state-silenced	.not-a-ticket"
  "ticket-init-agent	ticket-init"
  "branch-workflow-anchor	Fixes #"
  "governance-checks	governance.yml"
  "ship-dev-manifest	ship-manifest"
  "venv-prerequisite	venv_global"
  "contributor-guide	CONTRIBUTING"
)
for pair in "${b2_pairs[@]}"; do
  label=${pair%%	*}; needle=${pair#*	}
  grep -Fq -- "$needle" <<<"$readme_body" \
    || { echo "FAIL [docs B2-sweep:$label]: README no longer documents this surface (missing \"$needle\") — restore its telling."; fail=1; }
done

# --- grammar-drift — the branch regex's one home (branch-grammar.sh) quoted verbatim in its doc ---
# homes. Also documentation-state, so it lives here now (out of the demo). Revert-provable per home.
gd_re=$(grep -oE "BRANCH_RE='[^']+'" .github/scripts/branch-grammar.sh | sed "s/^BRANCH_RE='//; s/'\$//")
if [ -z "$gd_re" ]; then
  echo "FAIL [docs grammar-drift]: could not read BRANCH_RE from branch-grammar.sh"; fail=1
else
  for gd_home in CLAUDE.md README.md .github/CONTRIBUTING.md; do
    grep -Fq -- "$gd_re" "$gd_home" \
      || { echo "FAIL [docs grammar-drift]: $gd_home does not quote the branch regex verbatim ($gd_re) — sync it to branch-grammar.sh."; fail=1; }
  done
fi

# --- #168 CI NAME CONTRACT — the demo workflow still DECLARES the shape two required checks are
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
# FOR A LATER READER OF THE #121 ONE-HOME DETECTOR: the strings below are DELIBERATELY a second
# copy of strings living in the workflow file. That is exclusion 3 in action — a check name is an
# IDENTIFIER, and an identifier's repetition IS the contract, not a duplicated telling.
ci_fail_before=$fail
ci_wf=.github/workflows/demo.yml
ci_job=demo                                # the job KEY as declared under `jobs:` in that file
ci_name_expect='demo (${{ matrix.os }})'   # the name TEMPLATE, verbatim (single-quoted so bash never reads it)
ci_os_expect='macos-latest ubuntu-latest'  # the matrix's operating systems, as a SORTED set
# The job's own block: from its key line at the jobs-child indent, down to the next key at that
# same indent. Reading the block (rather than the whole file) is what keeps the two extractions
# below pointed at THIS job when a second job is added to the workflow later.
ci_block=$(awk -v job="$ci_job" '
  $0 ~ "^  " job ":[[:space:]]*$" { inblk=1; next }
  inblk && /^  [^[:space:]#]/     { inblk=0 }
  inblk                           { print }
' "$ci_wf")
# The job's own name: line — a step is written "- name:", so anchoring on `name:` after whitespace
# only ever sees the job's. Surrounding quotes are stripped because either spelling is the same
# declaration (docs.yml quotes its job name, demo.yml does not).
ci_name=$(printf '%s\n' "$ci_block" | sed -n -E 's/^[[:space:]]*name:[[:space:]]*//p' | head -1 \
          | tr -d "\"'" | sed -E 's/[[:space:]]+$//')
# The matrix's operating systems, from EITHER YAML list spelling: a flow list on the `os:` line
# itself, or block-list "- item" lines under it. Sorted so the comparison is set-wise, not
# order-wise — reordering the list changes no check name and must not red.
ci_os=$(printf '%s\n' "$ci_block" | awk '
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
' | tr -d "\"'" | sort | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
if [ -z "$ci_block" ]; then
  echo "FAIL [docs #168 ci-name-contract:job]: $ci_wf declares no '$ci_job:' job under jobs: — that job is what generates the two matrix-built required check names. Restore the job key; if it was renamed deliberately, change branch protection's required names FIRST, then re-point this detector."; fail=1
else
  [ "$ci_name" = "$ci_name_expect" ] \
    || { echo "FAIL [docs #168 ci-name-contract:template]: the '$ci_job' job in $ci_wf declares its name as \"$ci_name\", not \"$ci_name_expect\" — that template, rendered once per matrix value, IS the required-check contract, and a check that reports under a new name leaves every pull request pending rather than red. Restore the template; if the rename is intended, change branch protection's required names FIRST, then update this line."; fail=1; }
  [ "$ci_os" = "$ci_os_expect" ] \
    || { echo "FAIL [docs #168 ci-name-contract:matrix]: the '$ci_job' job in $ci_wf declares the operating-system matrix as \"$ci_os\", not \"$ci_os_expect\" — narrowing the matrix silently stops one required check reporting at all, which is worse than a red because nothing fails, the pull request simply never becomes mergeable. Restore both operating systems; if the drop is intended, change branch protection's required names FIRST, then update this line."; fail=1; }
fi
if [ "$fail" -eq "$ci_fail_before" ]; then
  # Render the names from the two declared parts and print them, so the log shows what this shape
  # produces today WITHOUT any assertion above resting on a rendered string.
  read -ra ci_os_arr <<<"$ci_os"
  ci_rendered=""
  for ci_o in "${ci_os_arr[@]}"; do
    ci_rendered="$ci_rendered${ci_rendered:+, }$(printf '%s' "$ci_name_expect" | sed "s/\${{ matrix.os }}/$ci_o/")"
  done
  echo "  ok [docs #168 ci-name-contract] — $ci_wf still declares the name template and both matrix operating systems; that shape reports as: $ci_rendered. LIMIT: branch protection is the authority for WHICH names are required and that setting is not readable from the repository, so this asserts only that the workflow still declares what it declared — and it does not assert that the job always reports."
fi

# --- map-complete (#82, operator ruling) — every top-level directory shipping PRODUCT files appears
# in README's folder map. #85 shipped General Human Knowledge/ as PRODUCT but no wave added it to the
# map; the rule closes that class of gap. MANIFEST-KEYED, not a hardcoded list: the directory set is
# derived from the PRODUCT paths in ship-manifest.txt, so a newly-shipped top-level dir is caught
# automatically. Directory names contain spaces, so match the literal path string — and ONLY inside
# the map's own fenced tree block (a prose mention elsewhere in README is NOT the map: the map is
# estate STRUCTURE). Revert-proof: remove a map line and this reds naming the directory.
mc_fail_before=$fail
# the fenced tree block under "## The folder map" (content between its first pair of ``` fences).
mc_map=$(awk '
  /^## The folder map/ {seen=1; next}
  seen && /^```/ {fence++; if(fence==2) exit; next}
  seen && fence==1 {print}
' "$README")
# top-level dir of each PRODUCT manifest path that lives under a directory (path contains a "/").
while IFS= read -r mc_dir; do
  grep -Fq -- "$mc_dir/" <<<"$mc_map" \
    || { echo "FAIL [docs map-complete]: top-level directory '$mc_dir/' ships PRODUCT files (per .github/ship-manifest.txt) but is absent from README's folder map — add its tree line."; fail=1; }
done < <(awk -F'\t' '$1=="PRODUCT" && $2 ~ /\// { sub(/\/.*/,"",$2); print $2 }' .github/ship-manifest.txt | sort -u)
[ "$fail" -ne "$mc_fail_before" ] || echo "  ok [docs map-complete] — every PRODUCT top-level directory appears in README's folder map"

# --- B3 SEPARATION — diagrams have EXITED README: zero .svg references (amendment 4-revised-a) ----
svg_refs=$(grep -c '\.svg' "$README" || true)
[ "$svg_refs" -eq 0 ] \
  || { echo "FAIL [docs B3-separation]: README references a diagram ($svg_refs .svg mention(s)) — README must not embed diagrams; keep only the pointer to General AI-Knowledge/AI Harness/."; fail=1; }

# --- [docs #69 ADR] — SPEC.md + the decisions/ ADR backfill are well-formed (#69) ----------------
# The project's decisions must stay readable: each ADR carries the four canonical headings, every
# real ADR cites at least one clickable evidence link, the shipped template stays empty, and SPEC.md
# keeps its glossary. Pure greps, each miss naming its exact fix — the demo owns behaviour,
# this owns doc-shape (cond 2/3). An evidence link is an issue ref (#NN) or a git commit sha (7+ hex).
adr_ev_re='#[0-9]+|\b[0-9a-f]{7,40}\b'   # what counts as a clickable evidence link in an ADR
while IFS= read -r adr; do
  # 1. every ADR (template included) must carry all four canonical section headings verbatim, so the
  #    guard — and a human — can read any ADR the same way.
  for h in '## Context' '## Decision' '## Consequences' '## Status'; do
    grep -Fqx -- "$h" "$adr" \
      || { echo "FAIL [docs #69 ADR]: $adr is missing the heading '$h' — every ADR carries Context/Decision/Consequences/Status verbatim; add it."; fail=1; }
  done
  case "$(basename "$adr")" in
    000-adr-template.md)
      # 3. the template is an empty starter: it must carry <FILL> and must NOT carry a real evidence
      #    link — a filled-in template is a defect (a copy that forgot to become its own ADR).
      grep -Fq -- '<FILL>' "$adr" \
        || { echo "FAIL [docs #69 ADR]: $adr is the template but has no <FILL> placeholder — restore the empty <FILL> sections."; fail=1; }
      grep -qE -- "$adr_ev_re" "$adr" \
        && { echo "FAIL [docs #69 ADR]: $adr is the template but carries a real evidence link (#NN or a sha) — a filled template is a defect; keep it empty."; fail=1; }
      ;;
    *)
      # 2. every real ADR must cite at least one evidence link so a stranger can click through to the
      #    issue or commit that motivated the decision.
      grep -qE -- "$adr_ev_re" "$adr" \
        || { echo "FAIL [docs #69 ADR]: $adr cites no evidence link — every backfilled ADR must reference at least one issue (#NN) or commit sha; add one."; fail=1; }
      ;;
  esac
done < <(git ls-files 'decisions/[0-9][0-9][0-9]-*.md')
# 4. SPEC.md must name every glossary term, so the product's own vocabulary stays legible to a
#    newcomer. Each needle is checked case-insensitively with its own prescriptive miss.
#    THE DECODER TERM WAS REMOVED FROM THIS LIST (#123), and the reason is worth keeping: SPEC.md is
#    classified PRODUCT, so it installs onto a user's estate, while the shorthand the decoder
#    explained was the DEVELOPMENT rule numbering — content a user who will never develop the
#    harness cannot use. Those rules now live in full, under descriptive names, in the development
#    instructions (CLAUDE.md, DEV, never shipped). Requiring the word here would have forced the
#    shipped file to keep carrying development material to stay green.
#    UNOWNED (#123): README's document-catalogue row for SPEC.md still calls it "glossary +
#    decoder", which the deletion above makes false. README is not this change's to edit, so the
#    row is left standing and reported rather than corrected across an ownership line. No detector
#    reds on it — that catalogue is prose, not a pinned claim — so it needs a human to route it.
if [ -f SPEC.md ]; then
  spec_body=$(cat SPEC.md)
  for term in 'estate' 'guard' 'red/yellow' 'one-home' 'dumb inspector'; do
    grep -Fiq -- "$term" <<<"$spec_body" \
      || { echo "FAIL [docs #69 ADR]: SPEC.md does not name '$term' — its glossary must cover estate, guard, red/yellow, one-home and dumb inspector; add it."; fail=1; }
  done
else
  echo "FAIL [docs #69 ADR]: SPEC.md is missing — the project spec (the guarantees + the glossary) must exist at the repo root; restore it."; fail=1
fi
[ "$fail" -ne 0 ] || echo "  ok [docs #69 ADR] — SPEC.md glossary present and every decisions/ ADR well-formed"

# --- reader-agent (#82 / decisions/018) — the reader spine, asserted PER-NAME not blanket ---------
# The estate's four readers narrate the record with NO validator behind them, so the fabrication
# clause IS their whole safety story and must be present in each. The three EPHEMERAL readers write
# nothing, so they must hold no `edit` tool. The `retrospective` reader is the single-door WRITER
# (decisions/018): it legitimately holds `edit`, so in place of a no-edit assert it must state its one
# write door AND its append-only discipline. Per-name so relaxing any one contract reds by name; a
# fifth reader is added to the loop when it ships. Basis: decisions/018.
ra_fail_before=$fail
for ra in ticket-recall weekly-digest harness-recall; do
  ra_f="_agents/$ra.agent.md"
  grep -Fq -- 'FABRICATED RECORD' "$ra_f" \
    || { echo "FAIL [docs reader-agent:$ra]: $ra_f dropped the fabrication clause (no 'FABRICATED RECORD') — every reader carries it verbatim; a reader that invents is caught by nothing else. Restore it."; fail=1; }
  ra_tools=$(grep -iE '^tools:' "$ra_f" | head -1)
  printf '%s' "$ra_tools" | grep -qiwE 'edit' \
    && { echo "FAIL [docs reader-agent:$ra]: $ra_f lists an 'edit' tool — an ephemeral reader writes NOTHING; remove edit from its frontmatter tools."; fail=1; }
done
ra_r=_agents/retrospective.agent.md
grep -Fq -- 'FABRICATED RECORD' "$ra_r" \
  || { echo "FAIL [docs reader-agent:retrospective]: $ra_r dropped the fabrication clause (no 'FABRICATED RECORD') — restore it verbatim."; fail=1; }
grep -Fq -- 'EXACTLY ONE DOOR' "$ra_r" \
  || { echo "FAIL [docs reader-agent:retrospective]: $ra_r no longer states its single write door ('EXACTLY ONE DOOR') — one output surface is its whole safety story; restore it."; fail=1; }
grep -Fiq -- 'append-only' "$ra_r" \
  || { echo "FAIL [docs reader-agent:retrospective]: $ra_r no longer states its append-only discipline ('append-only') — a retrospective is never rewritten; restore it."; fail=1; }
[ "$fail" -ne "$ra_fail_before" ] || echo "  ok [docs reader-agent] — 4 readers carry the fabrication clause; 3 ephemeral readers hold no edit tool; retrospective states single-door + append-only (edit permitted)"

# --- B4 STRUCTURE — DESIGN.md carries a dated currency-note section (cond 4 / amendment) ----------
grep -qiE 'Diagram currency \([0-9]{4}-[0-9]{2}-[0-9]{2}\)' "$DESIGN" \
  || { echo "FAIL [docs B4-structure]: $DESIGN is missing its dated 'Diagram currency (YYYY-MM-DD)' note section — add/restore it."; fail=1; }

# --- DESIGN.md TRIGGER — depicted machinery changed without a currency-note disposition ----------
# (addition-C): if this PR touches _harness/scripts/**, _agents/**, or _harness/hooks/** and does
# NOT touch DESIGN.md, the note's honesty is an unanswered question -> RED, UNLESS the PR body
# carries [diagrams-unaffected: <non-empty reason>]. The machine can't judge whether prose reflects
# reality, but it can refuse to merge the unanswered question.
if [ "${DOCS_CHANGED_FILES+x}" = x ]; then changed="$DOCS_CHANGED_FILES"; else
  changed=$(git diff --name-only "${DOCS_BASE_REF:-origin/main}...HEAD" 2>/dev/null || true)
fi
if printf '%s\n' "$changed" | grep -qE '^(_harness/scripts/|_agents/|_harness/hooks/)'; then
  if ! printf '%s\n' "$changed" | grep -qxF "$DESIGN"; then
    reason=$(printf '%s' "${PR_BODY:-}" | grep -oE '\[diagrams-unaffected:[^]]*\]' | head -1 | sed -E 's/^\[diagrams-unaffected:[[:space:]]*//; s/[[:space:]]*\]$//')
    [ -n "$reason" ] \
      || { echo "FAIL [docs DESIGN-trigger]: machinery changed without a DESIGN.md currency-note update — update the note, or add [diagrams-unaffected: reason] to the PR body."; fail=1; }
  fi
fi

# --- C7 DOC-INTEGRITY (#51) — mechanical "no mangled doc" guards over every tracked *.md ----------
# The simplify pass rewrites prose into lists; lists are where half-closed fences and orphaned links
# are born. These three detectors gate #51's OWN delivery PR (mechanical, revert-provable per
# detector) instead of leaving mangling to a human eyeball. SCOPE: intra-repo only — external URLs
# and template placeholders are skipped, so a required check never reds on the network. Runs on GNU
# grep only (docs.yml is ubuntu; the dev seat is Cygwin), never on macOS/BSD — the demo owns that.

# C7a FENCE-BALANCE — every *.md has an EVEN number of ``` markers (no code block left unclosed).
while IFS= read -r f; do
  fences=$(grep -cE '^[[:space:]]*```' "$f" || true)   # count fence lines (indented fences included)
  [ $(( fences % 2 )) -eq 0 ] \
    || { echo "FAIL [docs C7a-fence]: $f has $fences code-fence markers (odd) — a \`\`\` block is unclosed; balance the fences."; fail=1; }
done < <(git ls-files '*.md')

# C7c NO-CR — no *.md carries a carriage-return byte (the #40 CRLF class, extended to docs). -U keeps
# grep in binary mode so a lone CR inside a CRLF line is still seen.
while IFS= read -r f; do
  ! grep -qU $'\r' -- "$f" 2>/dev/null \
    || { echo "FAIL [docs C7c-cr]: $f contains carriage-return byte(s) — normalise to LF (docs ship LF-only)."; fail=1; }
done < <(git ls-files '*.md')

# C7b LINK/ANCHOR RESOLUTION — intra-repo relative links point at a real path; a #fragment matches a
# heading in its target file. ONE slugify convention (GitHub-style), pure bash — no python dependency
# added to a required gate. md_slugs() turns each ATX heading into its anchor slug.
md_slugs() {
  grep -E '^#{1,6}[[:space:]]+' "$1" \
    | sed -E 's/^#{1,6}[[:space:]]+//' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9 _-]//g; s/ /-/g'
}
while IFS= read -r f; do
  dir=$(dirname "$f")
  # each link target from [text](target); resolve/skip per scope, then check existence + anchor
  while IFS= read -r tgt; do
    case "$tgt" in
      *://*|mailto:*|tel:*) continue ;;         # external — out of scope (never red on the network)
      *[[:space:]]*|*'<'*|*'>'*) continue ;;    # placeholder like <PR URL> — not a real intra-repo link
    esac
    frag=""; path="$tgt"
    case "$tgt" in
      \#*)  frag=${tgt#\#}; path="" ;;          # same-file anchor
      *\#*) path=${tgt%%#*}; frag=${tgt#*#} ;;  # path + anchor
    esac
    target_file="$f"
    if [ -n "$path" ]; then
      cand="$dir/$path"; [ "$dir" = "." ] && cand="$path"   # resolve relative to the linking file
      if [ ! -e "$cand" ]; then
        echo "FAIL [docs C7b-link]: $f links to '$tgt' but '$cand' does not exist — fix or remove the link."; fail=1; continue
      fi
      target_file="$cand"
    fi
    if [ -n "$frag" ]; then                     # anchor is checkable only against a .md target's headings
      case "$target_file" in
        *.md) [ -f "$target_file" ] && ! md_slugs "$target_file" | grep -Fxq -- "$frag" \
                && { echo "FAIL [docs C7b-anchor]: $f links to '$tgt' but no heading in $target_file slugifies to '#$frag' — fix the anchor."; fail=1; } ;;
      esac
    fi
  done < <(grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
done < <(git ls-files '*.md')

# C7d ZERO-MENTIONS (#51 collapse) — the standalone flat-pack install doc was folded into README
# Setup and DELETED (one install home now, nothing to drift). No tracked file may still name it: a
# dead pointer to a removed file ships dead on a user estate. The needle is assembled from two string
# pieces so THIS detector's own source never contains the contiguous name it hunts for — a literal
# here would make the detector match itself forever. Its own detector (not folded into C7b's link
# check) because it hunts a bare name in ANY tracked text, not just markdown links.
collapse_needle='INSTALL''.md'
collapse_hits=$(git grep -l -F -- "$collapse_needle" 2>/dev/null || true)
if [ -n "$collapse_hits" ]; then
  echo "FAIL [docs C7d-collapse]: '$collapse_needle' was folded into README Setup and removed, but these tracked files still name it — re-point them to README Setup / the 'Hook activation caveat' section:"
  printf '  %s\n' $collapse_hits
  fail=1
fi

[ "$fail" -eq 0 ] || { echo "docs-check: FAILED — each line above names its fix."; exit 1; }
echo "docs-check: all detectors pass — see the ok-lines above for the detector set at HEAD."
