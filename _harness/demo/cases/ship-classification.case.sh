#!/usr/bin/env bash
# ship-classification.case.sh — #43 [ship-classification]: every tracked file is PRODUCT or DEV,
# exactly once. SOURCED by the runner; see _harness/scripts/run_demo.sh.
#
# The ship-manifest is the ONE home for ship/dev classification. Assert every tracked file is
# classified EXACTLY once and every manifest entry names a real tracked file (both directions, #43
# cond 6c) — so a new file can't be born unclassified and a manifest line can't outlive its file.
# This is a SELF-CONTAINED case: #42 absorbs this exact logic later (do not fork it into a second
# live copy). Manifest is TAB-delimited "CLASS<TAB>path"; the here-string matches (grep <<<) avoid
# the pipefail SIGPIPE trap the docs-inventory note explains.

case_ship_classification() {
  local CLASS_MANIFEST class_fail=0 class_paths class_dupe class_total f m
  echo "--- ship/dev classification: every tracked file is PRODUCT or DEV, exactly once ---"
  CLASS_MANIFEST=.github/ship-manifest.txt
  # The classified paths (skip # comments and any line without a TAB-separated path).
  class_paths=$(awk -F'\t' '/^#/ || NF < 2 { next } { print $2 }' "$CLASS_MANIFEST")
  # (a) no path classified more than once.
  class_dupe=$(printf '%s\n' "$class_paths" | LC_ALL=C sort | uniq -d)
  [ -z "$class_dupe" ] \
    || { echo "BUG [ship-classification]: path(s) classified more than once in $CLASS_MANIFEST:"; \
         printf '  %s\n' "$class_dupe"; exit 1; }
  # (b) every tracked file appears in the manifest — prescriptive on a miss (name the line to add).
  while IFS= read -r f; do
    grep -Fqx -- "$f" <<<"$class_paths" \
      || { echo "BUG [ship-classification]: tracked file not classified — add 'PRODUCT<TAB>$f' or" \
             "'DEV<TAB>$f' to $CLASS_MANIFEST:"; echo "    $f"; class_fail=1; }
  done < <(git ls-files)
  # (c) every manifest entry is a real tracked file (no stale line for a deleted/renamed file).
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    git ls-files --error-unmatch -- "$m" >/dev/null 2>&1 \
      || { echo "BUG [ship-classification]: $CLASS_MANIFEST lists a path that is not a tracked" \
             "file: $m"; class_fail=1; }
  done <<<"$class_paths"
  [ "$class_fail" -eq 0 ] || exit 1
  class_total=$(printf '%s\n' "$class_paths" | grep -c .)
  echo "  ok [ship-classification] — all $class_total tracked files classified exactly once" \
    "(PRODUCT/DEV), both directions"
}
