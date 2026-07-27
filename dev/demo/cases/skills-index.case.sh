#!/usr/bin/env bash
# skills-index.case.sh — [skills-index]: Skills tree <-> _index.md correspondence, both directions,
# plus the frozen module shape. SOURCED by the runner; see _harness/scripts/run_demo.sh.
#
# The worker tier discovers craft modules INDEX-FIRST: it matches its task against
# Skills/_index.md and reads only the matching SKILL.md, never crawling the tree. That only holds
# if the index and the folders stay in exact correspondence — a folder missing from the index is a
# SILENT absence (invisible under index-first discovery), and an index line for a deleted folder
# sends an agent looking for nothing. So this dumb, revert-provable case checks BOTH directions,
# plus the frozen module shape. SKILL-TEMPLATE.md at the root is the blank template, not a skill,
# and is exempt by name.

# si_setup — the paths and the skill NAMES the index lists: every non-comment line starting "- "
# has the folder name as its first whitespace-delimited token (line format
# "- <Name> — triggers: ... — tools: ...").
si_setup() {
  echo "--- [skills-index]: index <-> Skills/ tree correspondence + frozen module shape ---"
  SKILLS_DIR="General AI-Knowledge/Skills"
  SKILLS_INDEX="$SKILLS_DIR/_index.md"
  indexed_skills=$(grep -E '^- ' "$SKILLS_INDEX" | sed -E 's/^- ([^ ]+).*/\1/')
}

# Direction 1: every skill folder (a subdirectory of Skills/) MUST have a line in the index.
si_folders_indexed() {
  local d name
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    name=$(basename "$d")
    printf '%s\n' "$indexed_skills" | grep -qx "$name" \
      || { echo "BUG [skills-index]: skill folder '$name' has no line in _index.md — invisible" \
             "under index-first discovery"; exit 1; }
  done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d)
}

# Direction 2: every indexed skill line MUST name a folder that exists.
si_index_lines_real() {
  local name
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    [ -d "$SKILLS_DIR/$name" ] \
      || { echo "BUG [skills-index]: _index.md lists skill '$name' but no such folder exists —" \
             "sends an agent looking for nothing"; exit 1; }
  done < <(printf '%s\n' "$indexed_skills")
}

# Shape: every skill's SKILL.md (mindepth 2 skips the root SKILL-TEMPLATE.md by name) carries all
# four frozen section headings and the required tool-availability line.
si_module_shape() {
  local sk h
  while IFS= read -r sk; do
    [ -z "$sk" ] && continue
    for h in "WHEN TO USE" "CRAFT GUIDANCE" "NAMED TOOLS" "Last reviewed:"; do
      grep -qF "$h" "$sk" \
        || { echo "BUG [skills-index]: $sk is missing the frozen section heading '$h'"; exit 1; }
    done
    grep -qF "degrade gracefully to guidance-only" "$sk" \
      || { echo "BUG [skills-index]: $sk is missing the required tool-availability line (check" \
             "the tool exists, degrade gracefully to guidance-only if absent)"; exit 1; }
  done < <(find "$SKILLS_DIR" -mindepth 2 -name SKILL.md)
}

case_skills_index() {
  si_setup
  si_folders_indexed
  si_index_lines_real
  si_module_shape
  echo "  ok [skills-index] — every skill folder indexed, every index line has a folder, every" \
    "SKILL.md carries the four frozen sections + availability line"
}
