#!/usr/bin/env bash
# estate-key.case.sh — #60: commit-bearing hooks no-op outside a genuine estate. SOURCED by the
# runner; see dev/scripts/run-demo.sh.
#
# The hook cwd is "." (the workspace root), so if a session's effective repo is a NESTED FOREIGN
# project (e.g. under Github/), a naive auto-commit would commit into THAT repo. The fix: both
# commit-bearing hooks refuse to commit unless .git/config holds harness.estate=true — a positive
# identity the worktree can neither reach nor forge (install.sh writes it). This family proves
# containment IN ISOLATION (it sets/unsets the key itself; no dependency on install.sh), across
# EVERY commit-bearing hook PARSED from the one schema home (a future third commit-hook inherits
# coverage), against DIRTY fixtures (a clean repo false-greens — nothing to commit either way), and
# the non-estate set INCLUDES a REMOTED repo (the remote-protection OUTCOME stays proven even
# though the mechanism is now the key, not remote-refusal). REVERT-PROOF: strip the guard prefix
# from hooks.example.json -> the remoted + local-only fixtures auto-commit -> this reds, for BOTH
# hooks.

# g60_make_repo — one DIRTY fixture per class: a base commit, an identity so a commit CAN happen,
# then an uncommitted edit the hook could pick up.
g60_make_repo() {  # <dir> [remote-url] [set-estate-key]
  local d="$1"; mkdir -p "$d"; git -C "$d" init -q
  git -C "$d" config user.email t@t.local; git -C "$d" config user.name t
  [ -n "${2:-}" ] && git -C "$d" remote add origin "$2"
  [ -n "${3:-}" ] && git -C "$d" config harness.estate true
  echo seed > "$d/f"; git -C "$d" add -A; git -C "$d" commit -q -m seed
  echo dirty >> "$d/f"   # DIRTY: uncommitted change present
}

g60_commits() { git -C "$1" rev-list --count HEAD 2>/dev/null || echo 0; }

# ek_parse_hooks — the commit-bearing commands (bash contains 'git commit') read from the SHIPPED
# schema: the real strings, never re-typed. While-read (not mapfile) for the macOS runner's
# bash 3.2.
ek_parse_hooks() {
  local g60_line
  echo "--- #60 estate-key guard: commit-bearing hooks commit ONLY in a genuine estate ---"
  G60_TMP=$(mktemp -d)
  G60_CMDS=()
  while IFS= read -r g60_line; do
    [ -n "$g60_line" ] && G60_CMDS+=("$g60_line")
  done < <(python3 -c "
import json
d = json.load(open('estate/_harness/hooks/hooks.example.json'))
for entries in d['hooks'].values():
    for e in entries:
        if 'git commit' in e.get('bash', ''):
            print(e['bash'])
")
  [ "${#G60_CMDS[@]}" -ge 2 ] \
    || { echo "BUG [commit-hooks-parsed]: expected >=2 commit-bearing hooks parsed from" \
           "hooks.example.json, got ${#G60_CMDS[@]}"; exit 1; }
}

ek_fixtures() {
  G60_REMOTED="$G60_TMP/remoted"; g60_make_repo "$G60_REMOTED" "https://example.invalid/x.git"
  G60_LOCAL="$G60_TMP/local";     g60_make_repo "$G60_LOCAL"
  G60_ESTATE="$G60_TMP/estate";   g60_make_repo "$G60_ESTATE" "" true
  # not a repo at all
  G60_NONREPO="$G60_TMP/nonrepo"; mkdir -p "$G60_NONREPO"; echo x > "$G60_NONREPO/f"
}

# ek_one_command — run ONE parsed hook command against all four fixtures and assert containment.
# Re-dirtying per command matters twice over: a clean fixture false-greens (nothing to commit
# either way), AND without it the first parsed hook consumes the dirty state so a second hook's
# miss would hide in the revert-proof — it must RED for BOTH hooks.
ek_one_command() {
  local g60_cmd="$1" g60_fx g60_b g60_a
  for g60_fx in "$G60_REMOTED" "$G60_LOCAL" "$G60_ESTATE"; do echo change >> "$g60_fx/f"; done
  # non-estate repos (remoted + local-only) must NOT gain a commit
  for g60_fx in "$G60_REMOTED" "$G60_LOCAL"; do
    g60_b=$(g60_commits "$g60_fx")
    ( cd "$g60_fx" && bash -c "$g60_cmd" ) >/dev/null 2>&1 || true
    g60_a=$(g60_commits "$g60_fx")
    [ "$g60_b" = "$g60_a" ] \
      || { echo "BUG [estate-key-containment]: a commit-bearing hook committed in non-estate repo" \
             "($g60_fx: $g60_b->$g60_a)"; g60_fail=1; }
  done
  # non-repo dir: the guard's git config errors -> empty -> != true -> exit; no repo/commit created
  ( cd "$G60_NONREPO" && bash -c "$g60_cmd" ) >/dev/null 2>&1 || true
  [ ! -e "$G60_NONREPO/.git" ] \
    || { echo "BUG [estate-key-containment]: a hook initialised a repo in a non-repo dir"; \
         g60_fail=1; }
  # estate (key=true, dirty): the happy path is unchanged -> this one commit lands
  g60_b=$(g60_commits "$G60_ESTATE")
  ( cd "$G60_ESTATE" && bash -c "$g60_cmd" ) >/dev/null 2>&1 || true
  g60_a=$(g60_commits "$G60_ESTATE")
  [ "$g60_a" -gt "$g60_b" ] \
    || { echo "BUG [estate-key-commits]: the guard blocked a commit in a genuine estate" \
           "($g60_b->$g60_a)"; g60_fail=1; }
}

ek_containment() {
  local g60_cmd
  g60_fail=0
  for g60_cmd in "${G60_CMDS[@]}"; do ek_one_command "$g60_cmd"; done
  [ "$g60_fail" -eq 0 ] || exit 1
  echo "  ok [estate-key-containment] — ${#G60_CMDS[@]} commit-bearing hook(s): commit in estate," \
    "no-op in remoted/local-only/non-repo (dirty fixtures)"
}

# install.sh ARMS the key UNCONDITIONALLY — including an EXISTING repo (NEED_GIT=0), the migration
# path. REVERT-PROOF for the "unconditional, not init-nested" trap: nest the key-set inside the
# NEED_GIT init block and this existing-repo install leaves the key unset -> reds.
ek_armed_by_install() {
  local G60_EST G60_DEPLOY g60_key
  G60_EST="$G60_TMP/preexisting"; mkdir -p "$G60_EST"
  git -C "$G60_EST" init -q   # a repo BEFORE install => NEED_GIT=0
  G60_DEPLOY=$(mktemp -d)
  set +e
  HARNESS_AGENT_DEPLOY_DIR="$G60_DEPLOY" bash estate/install.sh --yes "$G60_EST" >/dev/null 2>&1
  set -e
  g60_key=$(git -C "$G60_EST" config --local harness.estate 2>/dev/null || true)
  [ "$g60_key" = "true" ] \
    || { echo "BUG [estate-key-armed]: install.sh did not set harness.estate=true on a" \
           "pre-existing (NEED_GIT=0) repo — the key-set must be UNCONDITIONAL, not nested in" \
           "the git-init block (got '$g60_key')"; exit 1; }
  echo "  ok [estate-key-armed] — install.sh sets harness.estate=true unconditionally, incl. an" \
    "existing repo (migration path)"
  rm -rf "$G60_DEPLOY"
}

case_estate_key() {
  ek_parse_hooks
  ek_fixtures
  ek_containment
  ek_armed_by_install
  rm -rf "$G60_TMP"
}
