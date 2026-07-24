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

# 1. TEMPLATES STAY EMPTY — every dev-loop/*.template.md keeps at least one literal <FILL> token, so
# a template whose blanks were filled in (content instead of skeleton) reds by name.
for dl_t in dev-loop/*.template.md; do
  grep -Fq -- '<FILL>' "$dl_t" \
    || { echo "FAIL [docs #68 dev-loop]: $dl_t has no <FILL> token — a template field was filled in; templates ship EMPTY, restore the <FILL> blanks."; fail=1; }
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

[ "$fail" -ne "$dl_fail_before" ] || echo "  ok [docs #68 dev-loop] — templates empty, vendor-neutral, 4 roles + 5 laws present in DEVELOPMENT.md"

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
# keeps its glossary + decoder. Pure greps, each miss naming its exact fix — the demo owns behaviour,
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
# 4. SPEC.md must name every glossary term and carry the decoder, so the tracker shorthand stays
#    legible to a newcomer. Each needle is checked case-insensitively with its own prescriptive miss.
if [ -f SPEC.md ]; then
  spec_body=$(cat SPEC.md)
  for term in 'estate' 'guard' 'red/yellow' 'one-home' 'dumb inspector' 'decoder'; do
    grep -Fiq -- "$term" <<<"$spec_body" \
      || { echo "FAIL [docs #69 ADR]: SPEC.md does not name '$term' — its glossary+decoder must cover estate, guard, red/yellow, one-home, dumb inspector, and the decoder; add it."; fail=1; }
  done
else
  echo "FAIL [docs #69 ADR]: SPEC.md is missing — the project spec (glossary + decoder) must exist at the repo root; restore it."; fail=1
fi
[ "$fail" -ne 0 ] || echo "  ok [docs #69 ADR] — SPEC.md glossary+decoder present and every decisions/ ADR well-formed"

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
