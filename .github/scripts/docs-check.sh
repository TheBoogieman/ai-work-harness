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
