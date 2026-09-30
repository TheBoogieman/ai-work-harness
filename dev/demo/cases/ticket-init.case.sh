#!/usr/bin/env bash
# Exercise allocation and complete template copies in disposable roots, without an install.
# Standalone: source dev/demo/cases/ticket-init.case.sh; case_ticket_init

# Name each failed contract so the same guard can demonstrate a reverted helper going red.
ti_assert() {
  local guard="$1"; shift
  "$@" && return 0
  printf 'BUG [%s]: ticket-init contract failed\n' "$guard" >&2
  return 1
}

# Capture failures as data so the outer case can always remove its own temporary fixtures.
ti_run() {
  ti_output=$(bash "$ti_helper" --root "$ti_root" --template "$ti_template" "$@" 2>&1) && return 0
  printf 'BUG [init-command]: %s\n' "$ti_output" >&2
  return 1
}

# Compare links as links, not their referents: BSD diff follows them and can report false loops.
ti_same_tree() {
  local expected="$1" actual="$2" entry counterpart
  [[ -d "$actual" && ! -L "$actual" ]] || return 1
  for entry in "$expected"/.[!.]* "$expected"/..?* "$expected"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    counterpart="$actual/${entry##*/}"
    if [[ -L "$entry" ]]; then
      [[ -L "$counterpart" && "$(readlink "$entry")" == "$(readlink "$counterpart")" ]] || return 1
    elif [[ -d "$entry" ]]; then
      ti_same_tree "$entry" "$counterpart" || return 1
    else
      [[ -f "$counterpart" && ! -L "$counterpart" ]] || return 1
      cmp "$entry" "$counterpart" || return 1
    fi
  done
  for entry in "$actual"/.[!.]* "$actual"/..?* "$actual"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    counterpart="$expected/${entry##*/}"
    [[ -e "$counterpart" || -L "$counterpart" ]] || return 1
  done
}

# Expected refusals must leave the whole Tickets tree alone, including all pre-existing files.
ti_refuse() {
  local guard="$1"; shift
  local snapshot
  snapshot=$(mktemp -d "$ti_scratch/snapshot.XXXXXXXX") || return 1
  cp -R -P "$ti_root/Tickets" "$snapshot/Tickets" || return 1
  if ti_output=$(bash "$ti_helper" "$@" 2>&1); then
    printf 'BUG [%s]: unexpected success: %s\n' "$guard" "$ti_output" >&2
    return 1
  fi
  ti_assert "$guard-no-writes" ti_same_tree "$snapshot/Tickets" "$ti_root/Tickets" || return 1
  rm -rf "$snapshot"
}

# Build from the shipped template, then customize it: a stock allowlist would lose these files.
ti_core() {
  mkdir -p "$ti_root/Tickets" "$ti_root/_harness/scripts" || return 1
  cp "$ti_repo/estate/_harness/scripts/ticket-grammar.sh" "$ti_root/_harness/scripts/" || return 1
  cp -R "$ti_repo/estate/Tickets/999912Z-PROJ-99999" "$ti_template" || return 1
  mv "$ti_template/999912Z-PROJ-99999.md" "$ti_template/$ti_template_name.md" || return 1
  mkdir -p "$ti_template/SQL/custom examples/nested" "$ti_template/.settings" || return 1
  printf 'custom query example\n' > "$ti_template/SQL/custom examples/nested/example.sql"
  printf 'hidden setting\n' > "$ti_template/.settings/.hidden"
  printf 'keep the template filename here\n' > "$ti_template/SQL/$ti_template_name.md"
  printf 'unchanged root dotfile\n' > "$ti_template/.custom"
  ti_assert init-helper-present test -f "$ti_helper" || return 1

  # Derive the previous month without GNU date flags; its huge sequence must not affect today.
  local prior_year prior_month prior_stamp
  prior_year=${ti_month:0:4}; prior_month=$((10#${ti_month:4:2} - 1))
  if [[ "$prior_month" -eq 0 ]]; then prior_month=12; prior_year=$((prior_year - 1)); fi
  printf -v prior_stamp '%04d%02d' "$prior_year" "$prior_month"
  mkdir "$ti_root/Tickets/${prior_stamp}ZZZZ-OTHER-1" || return 1
  ti_run --identity PROJ-1 --dry-run || return 1
  ti_assert init-local-month test "${ti_output%%$'\n'*}" = "$ti_root/Tickets/${ti_month}A-PROJ-1" || return 1
  ti_assert init-dry-run-status grep -qi 'unfinished scaffold' <<< "$ti_output" || return 1
  ti_assert init-dry-run-empty test ! -e "$ti_root/Tickets/${ti_month}A-PROJ-1" || return 1
  ti_run --identity PROJ-1 || return 1
  ti_assert init-unfinished-status grep -qi 'unfinished scaffold' <<< "$ti_output" || return 1
  local destination="$ti_root/Tickets/${ti_month}A-PROJ-1"
  ti_assert init-primary-bytes cmp "$ti_template/$ti_template_name.md" "$destination/${ti_month}A-PROJ-1.md" || return 1
  ti_assert init-primary-renamed test ! -e "$destination/$ti_template_name.md" || return 1
  # Reverse only the primary rename in a comparison copy; diff then checks every path and byte.
  cp -R "$destination" "$ti_scratch/expected-copy" || return 1
  mv "$ti_scratch/expected-copy/${ti_month}A-PROJ-1.md" "$ti_scratch/expected-copy/$ti_template_name.md" || return 1
  ti_assert init-entire-template diff -r "$ti_template" "$ti_scratch/expected-copy" || return 1

  # Gaps stay unused, other boards share the counter, and length outranks lexical ordering.
  ti_run --identity PROJ-2 --dry-run || return 1
  ti_assert init-after-a test "${ti_output%%$'\n'*}" = "$ti_root/Tickets/${ti_month}B-PROJ-2" || return 1
  mkdir "$ti_root/Tickets/${ti_month}Z-OTHER-3" || return 1
  ti_run --identity PROJ-2 --dry-run || return 1
  ti_assert init-after-z test "${ti_output%%$'\n'*}" = "$ti_root/Tickets/${ti_month}AA-PROJ-2" || return 1
  mkdir "$ti_root/Tickets/${ti_month}AA-OTHER-4" || return 1
  ti_run --identity PROJ-2 --dry-run || return 1
  ti_assert init-after-aa test "${ti_output%%$'\n'*}" = "$ti_root/Tickets/${ti_month}AB-PROJ-2" || return 1
  mkdir "$ti_root/Tickets/${ti_month}AZ-OTHER-5" || return 1
  ti_run --identity PROJ-2 --dry-run || return 1
  ti_assert init-after-az test "${ti_output%%$'\n'*}" = "$ti_root/Tickets/${ti_month}BA-PROJ-2" || return 1
  printf '  ok [init-month-sequence-copy] local month, cross-board rollover, complete unchanged template\n'
}

# Duplicate identities are a resume operation, even across months; pending bodies are not a roster.
ti_identities() {
  local duplicate_one="$ti_root/Tickets/200001A-PROJ-88"
  local duplicate_two="$ti_root/Tickets/200002AB-PROJ-88"
  local common=(--root "$ti_root" --template "$ti_template")
  mkdir "$duplicate_one" "$duplicate_two" || return 1
  ti_refuse init-duplicate "${common[@]}" --identity PROJ-88 --dry-run || return 1
  ti_assert init-duplicate-first grep -Fqx "$duplicate_one" <<< "$ti_output" || return 1
  ti_assert init-duplicate-second grep -Fqx "$duplicate_two" <<< "$ti_output" || return 1
  ti_refuse init-duplicate-write "${common[@]}" --identity PROJ-88 || return 1

  # Freeze only the timestamp so back-to-back pending creation exercises same-second collisions.
  mkdir -p "$ti_scratch/clock" || return 1
  printf '%s\n' '#!/usr/bin/env bash' 'if [[ "$*" == +%Y%m%d%H%M%S ]]; then' \
    '  printf "%s\n" 20310301000102' 'else' '  command -p date "$@"' 'fi' > "$ti_scratch/clock/date"
  chmod +x "$ti_scratch/clock/date" || return 1
  PATH="$ti_scratch/clock:$PATH" ti_run --pending || return 1
  local pending_one="${ti_output%%$'\n'*}"
  PATH="$ti_scratch/clock:$PATH" ti_run --pending || return 1
  local pending_two="${ti_output%%$'\n'*}"
  ti_assert init-pending-unique test "$pending_one" != "$pending_two" || return 1
  ti_assert init-pending-timestamp test "$pending_one" = "$ti_root/Tickets/pending-20310301000102" || return 1
  ti_assert init-pending-marker test -f "$pending_one/.ticket-pending" || return 1
  ti_assert init-pending-marker-second test -f "$pending_two/.ticket-pending" || return 1
  ti_assert init-pending-primary cmp "$ti_template/$ti_template_name.md" "$pending_one/${pending_one##*/}.md" || return 1
  # An unknown marker carries no identity, and a mention in the payload does not establish one.
  printf '# Unknown ticket\n\nA related issue is PROJ-201.\n' > "$pending_two/${pending_two##*/}.md"
  ti_run --identity PROJ-201 --dry-run || return 1
  printf '# PROJ-201 - supplied identity\n' > "$pending_two/${pending_two##*/}.md"
  ti_refuse init-evident-pending "${common[@]}" --identity PROJ-201 || return 1
  ti_assert init-pending-resume grep -Fqx "$pending_two" <<< "$ti_output" || return 1
  printf '  ok [init-identities-pending] duplicates report resume paths; pending identity is never invented\n'
}

# Completion previews exclude only the confirmed source, keep the shared month counter,
# and preserve every byte until the operator explicitly completes the pending lifecycle.
ti_resume() {
  local resume="$ti_root/Tickets/pending-known identity"
  local record="$resume/${resume##*/}.md"
  local common=(--root "$ti_root" --template "$ti_template" --identity PROJ-202 --dry-run)
  local snapshot="$ti_scratch/resume-before" duplicate
  mkdir "$resume" || return 1
  printf '# PROJ-202 - supplied identity\n\nKeep this pending record.\n' > "$record"
  printf 'pending lifecycle\000keep marker bytes\n' > "$resume/.ticket-pending"
  cp -R -P "$ti_root/Tickets" "$snapshot" || return 1
  ti_assert init-resume-preview ti_run --identity PROJ-202 --resume "$resume" --dry-run || return 1
  ti_assert init-resume-sequence test "${ti_output%%$'\n'*}" = "$ti_root/Tickets/${ti_month}BA-PROJ-202" || return 1
  ti_assert init-resume-status grep -q '^PREVIEW:' <<< "$ti_output" || return 1
  ti_assert init-resume-confirmation grep -q 'explicit lifecycle completion' <<< "$ti_output" || return 1
  ti_assert init-resume-primary-instructions grep -Fq "${resume##*/}.md" <<< "$ti_output" || return 1
  ti_assert init-resume-marker-instructions grep -Fq '.ticket-pending' <<< "$ti_output" || return 1
  ti_assert init-resume-no-writes ti_same_tree "$snapshot" "$ti_root/Tickets" || return 1
  ti_assert init-resume-record-bytes cmp "$snapshot/${resume##*/}/${resume##*/}.md" "$record" || return 1
  ti_assert init-resume-marker-bytes cmp "$snapshot/${resume##*/}/.ticket-pending" "$resume/.ticket-pending" || return 1

  # A prior conforming rename is still pending; its own sequence must not advance the preview.
  local renamed="$ti_root/Tickets/${ti_month}ZZ-PROJ-202"
  mv "$resume" "$renamed" || return 1
  mv "$renamed/${resume##*/}.md" "$renamed/${renamed##*/}.md" || return 1
  ti_run --identity PROJ-202 --resume "$renamed" --dry-run || return 1
  ti_assert init-resume-excludes-own-sequence test "${ti_output%%$'\n'*}" = "$ti_root/Tickets/${ti_month}BA-PROJ-202" || return 1
  # An already-correct name is not a collision with another owner; its marker still survives.
  local completion="$ti_root/Tickets/${ti_month}BA-PROJ-202"
  mv "$renamed" "$completion" || return 1
  mv "$completion/${renamed##*/}.md" "$completion/${completion##*/}.md" || return 1
  ti_run --identity PROJ-202 --resume "$completion" --dry-run || return 1
  ti_assert init-resume-existing-name test "${ti_output%%$'\n'*}" = "$completion" || return 1
  ti_assert init-resume-existing-name-status grep -q 'already have the proposed name' <<< "$ti_output" || return 1
  mv "$completion/${completion##*/}.md" "$completion/${resume##*/}.md" || return 1
  mv "$completion" "$resume" || return 1
  ti_assert init-resume-renamed-no-writes ti_same_tree "$snapshot" "$ti_root/Tickets" || return 1

  # Other pending headings and conforming names still reserve the identity across all months.
  for duplicate in "$ti_root/Tickets/pending-second" "$ti_root/Tickets/200001A-PROJ-202" \
      "$ti_root/Tickets/200001A-OTHER-202"; do
    mkdir "$duplicate" || return 1
    printf '# PROJ-202 - another owner\n' > "$duplicate/${duplicate##*/}.md"
    if [[ "$duplicate" != */200001A-PROJ-202 ]]; then touch "$duplicate/.ticket-pending"; fi
    ti_refuse init-resume-other-duplicate "${common[@]}" --resume "$resume" || return 1
    ti_assert init-resume-other-path grep -Fqx "$duplicate" <<< "$ti_output" || return 1
    rm -rf "$duplicate"
  done
  printf '  ok [init-resume-preview] current month/sequence, explicit completion, unchanged source, other duplicates blocked\n'
}

# A resume path cannot grant write access or excuse an unsafe or unconfirmed pending record.
ti_resume_safety() {
  local resume="$ti_root/Tickets/pending-known identity" invalid
  local record="$resume/${resume##*/}.md"
  local common=(--root "$ti_root" --template "$ti_template")
  ti_refuse init-resume-needs-dry-run "${common[@]}" --identity PROJ-202 --resume "$resume" || return 1
  ti_refuse init-resume-needs-identity "${common[@]}" --resume "$resume" --dry-run || return 1
  ti_refuse init-resume-not-pending "${common[@]}" --pending --resume "$resume" --dry-run || return 1
  ti_refuse init-resume-missing-value "${common[@]}" --identity PROJ-202 --dry-run --resume || return 1
  ti_refuse init-resume-repeated "${common[@]}" --identity PROJ-202 --dry-run --resume "$resume" --resume "$resume" || return 1
  common+=(--identity PROJ-202 --dry-run)
  # Completion must protect the pending source's supporting markdown, not just the template.
  printf 'keep supporting document\n' > "$resume/${ti_month}BA-PROJ-202.md"
  ti_refuse init-resume-primary-collision "${common[@]}" --resume "$resume" || return 1
  rm "$resume/${ti_month}BA-PROJ-202.md"
  cp -R "$resume" "$ti_scratch/${resume##*/}" || return 1
  mkdir "$resume/nested" || return 1
  ln -s "$resume" "$ti_root/Tickets/resume-link" || return 1
  ln -s "$ti_root" "$ti_scratch/resume-root-link" || return 1
  for invalid in "$ti_scratch/${resume##*/}" "$ti_template" "$resume/nested" \
      "$ti_root/Tickets/missing" "$ti_root/Tickets/../Tickets/${resume##*/}" \
      "$ti_root/Tickets/resume-link/" "$ti_scratch/resume-root-link/Tickets/${resume##*/}"; do
    ti_refuse init-resume-unsafe-path "${common[@]}" --resume "$invalid" || return 1
  done
  rmdir "$resume/nested" || return 1
  ti_assert init-resume-outside-unchanged ti_same_tree "$resume" "$ti_scratch/${resume##*/}" || return 1
  rm "$ti_root/Tickets/resume-link" "$ti_scratch/resume-root-link"

  # Missing, directory, and symlink markers cannot stand in for the source's own regular file.
  mv "$resume/.ticket-pending" "$ti_scratch/resume-marker" || return 1
  ti_refuse init-resume-no-marker "${common[@]}" --resume "$resume" || return 1
  mkdir "$resume/.ticket-pending" || return 1
  ti_refuse init-resume-marker-directory "${common[@]}" --resume "$resume" || return 1
  rmdir "$resume/.ticket-pending" || return 1
  ln -s "$ti_scratch/resume-marker" "$resume/.ticket-pending" || return 1
  ti_refuse init-resume-marker-link "${common[@]}" --resume "$resume" || return 1
  rm "$resume/.ticket-pending"
  mv "$ti_scratch/resume-marker" "$resume/.ticket-pending" || return 1
  mv "$record" "$ti_scratch/resume-record" || return 1
  ti_refuse init-resume-no-primary "${common[@]}" --resume "$resume" || return 1
  ln -s "$ti_scratch/resume-record" "$record" || return 1
  ti_refuse init-resume-primary-link "${common[@]}" --resume "$resume" || return 1
  rm "$record"
  printf '# PROJ-2020 - not the same identity\n\n# PROJ-202 - later mention\n' > "$record"
  ti_refuse init-resume-identity-mismatch "${common[@]}" --resume "$resume" || return 1
  mv "$ti_scratch/resume-record" "$record" || return 1
  printf '  ok [init-resume-safety] preview-only mode, contained real source, regular marker and exact primary heading required\n'
}

# Reject missing inputs, unsafe sources, and existing targets before writing any scaffold.
ti_safety() {
  local common=(--root "$ti_root" --template "$ti_template")
  local invalid_identity
  for invalid_identity in 'PROJ' 'PROJ-x' 'proj-1' 'PROJ-1/../../escape' $'PROJ-1\n'; do
    ti_refuse init-invalid-identity "${common[@]}" --identity "$invalid_identity" || return 1
  done
  ti_refuse init-missing-identity "${common[@]}" || return 1
  ti_refuse init-conflicting-modes "${common[@]}" --identity PROJ-2 --pending || return 1
  ti_refuse init-missing-option-value "${common[@]}" --identity || return 1
  ti_refuse init-unknown-option "${common[@]}" --identity PROJ-2 --unknown || return 1
  ti_refuse init-no-template --root "$ti_root" --identity PROJ-2 || return 1
  ti_refuse init-missing-template --root "$ti_root" --template "$ti_root/Tickets/missing" --pending || return 1
  ti_refuse init-missing-root --root "$ti_scratch/missing" --template "$ti_template" --pending || return 1
  mkdir "$ti_scratch/no-tickets" || return 1
  ti_refuse init-missing-tickets --root "$ti_scratch/no-tickets" --template "$ti_template" --pending || return 1
  mkdir "$ti_root/Tickets/no-markdown" || return 1
  ti_refuse init-missing-markdown --root "$ti_root" --template "$ti_root/Tickets/no-markdown" --pending || return 1
  ti_refuse init-root-as-template --root "$ti_root" --template "$ti_root/Tickets" --pending || return 1
  cp -R "$ti_template" "$ti_scratch/outside" || return 1
  ti_refuse init-outside-template --root "$ti_root" --template "$ti_scratch/outside" --pending || return 1
  ti_refuse init-traversal --root "$ti_root" --template "$ti_root/Tickets/../Tickets/$ti_template_name" --pending || return 1

  # Test both dangling links and links to safe-looking internal directories: neither is a source.
  ln -s "$ti_template" "$ti_root/Tickets/template-link" || return 1
  ti_refuse init-source-link --root "$ti_root" --template "$ti_root/Tickets/template-link/" --pending || return 1
  ln -s "$ti_scratch/outside" "$ti_template/escape" || return 1
  ti_refuse init-nested-link "${common[@]}" --pending || return 1
  rm "$ti_template/escape"
  ln -s "$ti_scratch/missing" "$ti_template/dangling" || return 1
  ti_refuse init-dangling-source "${common[@]}" --pending || return 1
  rm "$ti_template/dangling"
  ln -s "$ti_root" "$ti_scratch/root-link" || return 1
  ti_refuse init-root-link --root "$ti_scratch/root-link/" --template "$ti_template" --pending || return 1
  mkdir "$ti_scratch/linked-tickets-root" || return 1
  ln -s "$ti_root/Tickets" "$ti_scratch/linked-tickets-root/Tickets" || return 1
  ti_refuse init-tickets-link --root "$ti_scratch/linked-tickets-root" --template "$ti_template" --pending || return 1

  local collision="$ti_root/Tickets/${ti_month}BA-PROJ-2"
  ln -s "$ti_scratch/missing" "$collision" || return 1
  ti_refuse init-dangling-destination "${common[@]}" --identity PROJ-2 || return 1
  rm "$collision"
  printf 'existing file\n' > "$collision"
  ti_refuse init-file-destination "${common[@]}" --identity PROJ-2 || return 1
  rm "$collision"
  printf 'custom supporting document\n' > "$ti_template/${ti_month}BA-PROJ-2.md"
  ti_refuse init-primary-collision "${common[@]}" --identity PROJ-2 || return 1
  rm "$ti_template/${ti_month}BA-PROJ-2.md"
  # A pending marker must be a file; touch on a directory succeeds without making a marker.
  mkdir "$ti_template/.ticket-pending" || return 1
  ti_refuse init-marker-directory "${common[@]}" --pending || return 1
  rmdir "$ti_template/.ticket-pending" || return 1
  printf '  ok [init-safety] invalid inputs, escapes, symlinks, missing sources, and collisions refused\n'
}

# Compare the whole tree, not just the prospective ticket, to catch hidden staging leaks in preview.
ti_preview() {
  cp -R "$ti_root/Tickets" "$ti_scratch/preview-before" || return 1
  ti_run --identity PROJ-2 --dry-run || return 1
  ti_run --pending --dry-run || return 1
  ti_assert init-preview-no-writes ti_same_tree "$ti_scratch/preview-before" "$ti_root/Tickets" || return 1
  printf '  ok [init-dry-run] identity and pending previews make no filesystem changes\n'
}

# Fail cp after it has written data, then inject a destination after copying; neither may publish
# a partial ticket or delete a pre-existing stage. Only this case's mktemp fixtures are changed.
ti_atomic_copy() {
  local common=(--root "$ti_root" --template "$ti_template")
  mkdir -p "$ti_scratch/faults" "$ti_root/Tickets/.ticket-init.keep" || return 1
  printf 'must survive\n' > "$ti_root/Tickets/.ticket-init.keep/sentinel"
  printf '%s\n' '#!/usr/bin/env bash' 'command -p cp "$@" || exit' \
    'if [[ "${TI_COPY_MODE:-}" == collision ]]; then' \
    '  mkdir "$TI_COPY_TARGET" || exit' \
    '  printf "existing owner\n" > "$TI_COPY_TARGET/sentinel"' \
    'else' '  exit 73' 'fi' > "$ti_scratch/faults/cp"
  chmod +x "$ti_scratch/faults/cp" || return 1
  cp -R "$ti_root/Tickets" "$ti_scratch/copy-before" || return 1
  if ti_output=$(PATH="$ti_scratch/faults:$PATH" bash "$ti_helper" "${common[@]}" --identity PROJ-2 2>&1); then
    ti_assert init-copy-failure false || return 1
  fi
  ti_assert init-copy-failure-cleanup ti_same_tree "$ti_scratch/copy-before" "$ti_root/Tickets" || return 1
  local collision="$ti_root/Tickets/${ti_month}BA-PROJ-2"
  if ti_output=$(PATH="$ti_scratch/faults:$PATH" TI_COPY_MODE=collision TI_COPY_TARGET="$collision" \
      bash "$ti_helper" "${common[@]}" --identity PROJ-2 2>&1); then
    ti_assert init-publish-collision false || return 1
  fi
  ti_assert init-collision-owner grep -qx 'existing owner' "$collision/sentinel" || return 1
  rm -rf "$collision"
  ti_assert init-collision-cleanup ti_same_tree "$ti_scratch/copy-before" "$ti_root/Tickets" || return 1
  printf '  ok [init-atomic-copy] copy failure and late collision remove only the owned stage\n'
}

# Widen only a disposable grammar to prove the helper sources the editable authority. Running
# a copied helper from another cwd also proves its default root follows its own script location.
ti_custom_grammar() {
  local grammar="$ti_root/_harness/scripts/ticket-grammar.sh"
  cp "$grammar" "$ti_scratch/original-grammar" || return 1
  sed 's/\[A-Z0-9\]/[A-Z0-9-]/g' "$ti_scratch/original-grammar" > "$grammar"
  mkdir "$ti_root/Tickets/${ti_month}BZ-DATA-ENG-10" || return 1
  ti_run --identity DATA-ENG-11 --dry-run || return 1
  ti_assert init-custom-board test "${ti_output%%$'\n'*}" = "$ti_root/Tickets/${ti_month}CA-DATA-ENG-11" || return 1
  cp "$ti_helper" "$ti_root/_harness/scripts/init-ticket.sh" || return 1
  ti_output=$(cd "$ti_scratch" && bash "$ti_root/_harness/scripts/init-ticket.sh" \
    --template "$ti_template" --identity DATA-ENG-11 --dry-run 2>&1) || return 1
  ti_assert init-default-root test "${ti_output%%$'\n'*}" = "$ti_root/Tickets/${ti_month}CA-DATA-ENG-11" || return 1
  printf '  ok [init-shared-grammar-root] custom hyphenated boards and script-relative default root\n'
}

# Explicit teardown preserves the runner's sole EXIT trap, including on expected red runs.
case_ticket_init() {
  local ti_repo="$PWD" ti_scratch ti_root ti_template ti_template_name ti_month ti_helper ti_output
  local case_result=0
  ti_scratch=$(mktemp -d) || return 1
  ti_scratch=$(cd "$ti_scratch" && pwd -P) || return 1
  ti_root="$ti_scratch/root with spaces"
  ti_month=$(date +%Y%m) || { rm -rf "$ti_scratch"; return 1; }
  ti_template_name="${ti_month}ZZZ-TPL-99999"
  ti_template="$ti_root/Tickets/$ti_template_name"
  ti_helper="${TICKET_INIT_TEST_HELPER:-$ti_repo/estate/_harness/scripts/init-ticket.sh}"
  ti_core && ti_identities && ti_resume && ti_resume_safety && ti_safety && ti_preview && ti_atomic_copy && ti_custom_grammar || case_result=$?
  rm -rf "$ti_scratch"
  return "$case_result"
}