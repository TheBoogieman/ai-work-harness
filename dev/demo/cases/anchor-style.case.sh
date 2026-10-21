#!/usr/bin/env bash
# anchor-style.case.sh — [anchor-style]: the section-link converter rewrites only what it can
# resolve, round-trips byte for byte, and never touches code. SOURCED by the runner; see
# dev/scripts/run-demo.sh.
#
# GitHub and VS Code resolve a #fragment only as a GitHub slug; Obsidian only as the heading text.
# anchor-style.py converts between the two. A converter that rewrote a link it could not resolve,
# or one inside code, would silently break documents, so each of those is a labelled red here.
# Everything runs in a throwaway folder; cleanup is an explicit rm (the runner owns the trap).

as_fixture() {
  echo "--- [anchor-style]: section links convert both ways, round-trip, and leave code alone ---"
  AS_ROOT=$(mktemp -d)
  AS_PY="${HARNESS_TEST_PYTHON:-python3}"
  AS_HELPER="${HARNESS_ANCHOR_STYLE:-$PWD/estate/_harness/scripts/anchor-style.py}"
  [ -f "$AS_HELPER" ] || { echo "BUG [anchor-style-present]: the helper is absent ($AS_HELPER)"; exit 1; }
  printf '# Rules\n\n## Contents\n\n## 4.2 Durable Evidence Gate\n\ntext\n' > "$AS_ROOT/rules.md"
  # One link per rule: a numbered heading, a plain one, a renumbered link whose old number is gone,
  # an inline-code span and a fenced block that must both stay untouched.
  cat > "$AS_ROOT/pointer.md" <<'ASMD'
# Pointer

- [gate](rules.md#42-durable-evidence-gate)
- [contents](rules.md#contents)
- [renumbered](rules.md#7-durable-evidence-gate)
- code: `[gate](rules.md#42-durable-evidence-gate)`

```text
[gate](rules.md#42-durable-evidence-gate)
```
ASMD
  cp "$AS_ROOT/pointer.md" "$AS_ROOT/pointer.orig"
}

# 1. --to obsidian rewrites resolvable prose links to the heading text, follows a renumbered
#    section by its words, and leaves the inline-code span and the fenced block byte-identical.
as_to_obsidian() {
  local out
  "$AS_PY" "$AS_HELPER" --to obsidian "$AS_ROOT/pointer.md" >/dev/null \
    || { echo "BUG [anchor-style-obsidian]: conversion to Obsidian form failed"; exit 1; }
  out=$(cat "$AS_ROOT/pointer.md")
  printf '%s\n' "$out" | grep -qF -- '- [gate](rules.md#4.2%20Durable%20Evidence%20Gate)' \
    && printf '%s\n' "$out" | grep -qF -- '- [contents](rules.md#Contents)' \
    || { echo "BUG [anchor-style-obsidian]: prose links were not rewritten to heading text:"; \
         echo "$out"; exit 1; }
  printf '%s\n' "$out" | grep -qF -- '- [renumbered](rules.md#4.2%20Durable%20Evidence%20Gate)' \
    || { echo "BUG [anchor-style-renumbered]: a link to a renumbered section was not followed by" \
           "its words:"; echo "$out"; exit 1; }
  [ "$(printf '%s\n' "$out" | grep -cF 'rules.md#42-durable-evidence-gate')" -eq 2 ] \
    || { echo "BUG [anchor-style-code]: a link inside inline code or a fenced block was" \
           "rewritten:"; echo "$out"; exit 1; }
  echo "  ok [anchor-style-obsidian] — prose links to heading text, renumbered link followed," \
    "code untouched"
}

# 2. --to github restores the GitHub slugs; apart from the renumbered link (now the true number)
#    the file is byte-identical to the original.
as_round_trip() {
  "$AS_PY" "$AS_HELPER" --to github "$AS_ROOT/pointer.md" >/dev/null \
    || { echo "BUG [anchor-style-round-trip]: conversion back to GitHub slugs failed"; exit 1; }
  sed 's|rules.md#7-durable-evidence-gate|rules.md#42-durable-evidence-gate|' \
    "$AS_ROOT/pointer.orig" > "$AS_ROOT/pointer.want"
  cmp -s "$AS_ROOT/pointer.want" "$AS_ROOT/pointer.md" \
    || { echo "BUG [anchor-style-round-trip]: Obsidian -> GitHub did not restore the original:"; \
         diff "$AS_ROOT/pointer.want" "$AS_ROOT/pointer.md"; exit 1; }
  echo "  ok [anchor-style-round-trip] — GitHub -> Obsidian -> GitHub is byte-identical (the" \
    "renumbered link now carries its true number)"
}

# 3. --check on a fragment no heading matches lists it as UNRESOLVED, exits 1 and writes nothing.
as_check_unresolved() {
  local out rc before
  printf -- '- [lost](rules.md#no-such-heading)\n' >> "$AS_ROOT/pointer.md"
  before=$(cksum < "$AS_ROOT/pointer.md")
  set +e; out=$("$AS_PY" "$AS_HELPER" --to obsidian --check "$AS_ROOT/pointer.md" 2>&1); rc=$?; set -e
  [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'UNRESOLVED .*#no-such-heading' \
    || { echo "BUG [anchor-style-unresolved]: an unmatched fragment was not reported (rc=$rc):"; \
         echo "$out"; exit 1; }
  [ "$(cksum < "$AS_ROOT/pointer.md")" = "$before" ] \
    || { echo "BUG [anchor-style-check-read-only]: --check wrote to the file"; exit 1; }
  echo "  ok [anchor-style-unresolved] — an unmatched fragment is listed, rc=1, --check writes nothing"
}

case_anchor_style() {
  as_fixture
  as_to_obsidian
  as_round_trip
  as_check_unresolved
  rm -rf "$AS_ROOT"
}
