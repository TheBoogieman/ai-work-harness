#!/usr/bin/env bash
# Allocate a folder and copy the operator's actual template; the agent still owns every fact.
# Staging keeps failed copies out of the ticket roster under the single-active-operator contract.
set -euo pipefail
export LC_ALL=C

init_fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

init_usage() {
  printf '%s\n' 'Usage: bash init-ticket.sh [--root PATH] --template PATH (--identity BOARD-123 | --pending) [--dry-run] [--resume PATH]' \
    '--resume requires --identity and --dry-run; it only previews pending completion.'
}

# Arguments never infer an identity or a template, even when the estate contains only one.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
root_arg="$script_dir/../.."
template_arg=''
identity=''
resume_arg=''
resume=''
pending=0
dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root|--template|--identity|--resume)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || init_fail "Missing value for $1"
      case "$1" in
        --root) root_arg="$2" ;;
        --template) [[ -z "$template_arg" ]] || init_fail 'Repeated --template'; template_arg="$2" ;;
        --identity) [[ -z "$identity" ]] || init_fail 'Repeated --identity'; identity="$2" ;;
        --resume) [[ -z "$resume_arg" ]] || init_fail 'Repeated --resume'; resume_arg="$2" ;;
      esac
      shift 2 ;;
    --pending) pending=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --help) init_usage; exit 0 ;;
    *) init_usage >&2; init_fail "Unknown argument: $1" ;;
  esac
done
[[ -n "$template_arg" ]] || init_fail '--template must name the actual customized template'
if [[ "$pending" -eq 1 ]]; then
  [[ -z "$identity" ]] || init_fail 'Use --identity OR --pending, not both'
else
  [[ -n "$identity" ]] || init_fail 'Supply --identity or explicitly choose --pending'
fi
# Resuming never reaches the write path: lifecycle completion requires a separate human act.
if [[ -n "$resume_arg" ]]; then
  [[ -n "$identity" && "$pending" -eq 0 && "$dry_run" -eq 1 ]] \
    || init_fail '--resume requires --identity and --dry-run, never --pending'
fi

# Anchor writes to a real Tickets directory. Resolve OS-level aliases above the selected root,
# but reject links at the root, Tickets, and every source component below Tickets.
[[ -d "$root_arg" ]] || init_fail "Missing root: $root_arg"
logical_root=$(cd -L -- "$root_arg" && pwd -L)
[[ ! -L "$logical_root" ]] || init_fail "Symlink root refused: $logical_root"
root=$(cd -- "$logical_root" && pwd -P)
tickets="$root/Tickets"
[[ -d "$tickets" && ! -L "$tickets" ]] || init_fail "Missing or symlink Tickets directory: $tickets"
[[ "/$template_arg/" != */../* ]] || init_fail 'Template traversal (..) refused'
[[ -d "$template_arg" ]] || init_fail "Missing template: $template_arg"
source_walk=$(cd -L -- "$template_arg" && pwd -L)
template=$(cd -- "$template_arg" && pwd -P)
[[ "$template" == "$tickets/"* ]] || init_fail "Template must be inside $tickets"
while :; do
  [[ ! -L "$source_walk" ]] || init_fail "Symlink source refused: $source_walk"
  source_physical=$(cd -- "$source_walk" && pwd -P)
  [[ "$source_physical" == "$tickets" ]] && break
  [[ "$source_physical" == "$tickets/"* ]] || init_fail "Source escapes Tickets: $source_walk"
  source_walk=$(dirname -- "$source_walk")
done
template_name=${template##*/}
primary="$template_name.md"
[[ -f "$template/$primary" && ! -L "$template/$primary" ]] || init_fail "Missing primary template markdown: $template/$primary"
unsupported=$(find "$template" ! -type d ! -type f -print -quit) || init_fail 'Cannot inspect template'
[[ -z "$unsupported" ]] || init_fail "Symlink or special template entry refused: $unsupported"

# The selected estate's editable grammar is the authority, including customized board keys.
grammar="$root/_harness/scripts/ticket-grammar.sh"
[[ -f "$grammar" && ! -L "$grammar" && ! -L "$root/_harness" && ! -L "$root/_harness/scripts" ]] \
  || init_fail "Missing or symlink ticket grammar: $grammar"
# shellcheck source=estate/_harness/scripts/ticket-grammar.sh
source "$grammar"
# A same-named directory cannot serve as the lifecycle marker, even though touch accepts it.
if [[ "$pending" -eq 1 && -e "$template/$TICKET_PENDING_MARKER" && ! -f "$template/$TICKET_PENDING_MARKER" ]]; then
  init_fail "Pending marker must be a regular file: $template/$TICKET_PENDING_MARKER"
fi
month=$(date +%Y%m)
if [[ "$pending" -eq 0 ]]; then
  [[ "$identity" != *[/$'\n\r\\']* ]] || init_fail 'Identity contains a path separator or newline'
  proposed="${month}A-$identity"
  [[ "$proposed" =~ $TICKET_RE ]] || init_fail "Identity does not match the shared ticket grammar: $identity"
fi

# Confirm the exact pending source before exempting it from the roster. Physical containment
# and a logical walk through the root reject traversal and aliases to otherwise valid tickets.
if [[ -n "$resume_arg" ]]; then
  [[ "/$resume_arg/" != */../* ]] || init_fail 'Resume traversal (..) refused'
  [[ -d "$resume_arg" ]] || init_fail "Missing resume directory: $resume_arg"
  resume_walk=$(cd -L -- "$resume_arg" && pwd -L)
  resume=$(cd -- "$resume_arg" && pwd -P)
  [[ "${resume%/*}" == "$tickets" && "$resume" != "$template" ]] \
    || init_fail "Resume must be a direct child of $tickets distinct from the template"
  while :; do
    [[ ! -L "$resume_walk" ]] || init_fail "Symlink resume path refused: $resume_walk"
    resume_physical=$(cd -- "$resume_walk" && pwd -P)
    [[ "$resume_physical" == "$root" ]] && break
    [[ "$resume_physical" == "$tickets" || "$resume_physical" == "$resume" ]] \
      || init_fail "Resume path escapes selected root: $resume_walk"
    resume_walk=$(dirname -- "$resume_walk")
  done
  [[ -f "$resume/$TICKET_PENDING_MARKER" && ! -L "$resume/$TICKET_PENDING_MARKER" ]] \
    || init_fail "Resume requires a regular pending marker: $resume/$TICKET_PENDING_MARKER"
  resume_primary="${resume##*/}.md"
  [[ -f "$resume/$resume_primary" && ! -L "$resume/$resume_primary" ]] \
    || init_fail "Missing or symlink primary pending markdown: $resume/$resume_primary"
  heading=''
  IFS= read -r heading < "$resume/$resume_primary" || true
  [[ "$heading" == "# $identity" || "$heading" == "# $identity "* || "$heading" == "# $identity"$'\t'* ]] \
    || init_fail "Primary pending heading must match exact identity: $identity"
fi

# Inspect names across every board/month, excluding only the template and confirmed source.
# A conforming rename does not override a pending heading; never search the record's payload.
shopt -s nullglob dotglob
maximum=''
duplicates=()
for existing in "$tickets"/*; do
  [[ "$existing" != "$template" && "$existing" != "$resume" ]] || continue
  existing_name=${existing##*/}
  if [[ "$existing_name" =~ $TICKET_RE ]]; then
    if [[ "$pending" -eq 0 && "${existing_name#*-}" == "$identity" ]]; then
      duplicates+=("$existing")
      continue
    fi
    if [[ -d "$existing" && ! -L "$existing" && "$existing_name" == "$month"* ]]; then
      sequence=${existing_name%%-*}
      sequence=${sequence:6}
      [[ -n "$sequence" && "$sequence" != *[!A-Z]* ]] || init_fail "Unsupported sequence: $existing_name"
      if [[ ${#sequence} -gt ${#maximum} || ( ${#sequence} -eq ${#maximum} && "$sequence" > "$maximum" ) ]]; then
        maximum="$sequence"
      fi
    fi
  fi
  if [[ "$pending" -eq 0 && -d "$existing" && ! -L "$existing" ]] && ticket_pending "$existing"; then
    record="$existing/$existing_name.md"
    if [[ -f "$record" && ! -L "$record" ]]; then
      heading=''
      IFS= read -r heading < "$record" || true
      if [[ "$heading" == "# $identity" || "$heading" == "# $identity "* || "$heading" == "# $identity"$'\t'* ]]; then
        duplicates+=("$existing")
      fi
    fi
  fi
done
if [[ ${#duplicates[@]} -gt 0 ]]; then
  printf 'ERROR: Identity already exists; resume an existing ticket:\n' >&2
  printf '%s\n' "${duplicates[@]}" >&2
  exit 1
fi

# Carry alphabetic digits without integer conversion, so sequence size is not machine-limited.
if [[ "$pending" -eq 0 ]]; then
  next_sequence=''
  carry=1
  alphabet=ABCDEFGHIJKLMNOPQRSTUVWXYZ
  for ((position=${#maximum}-1; position>=0; position--)); do
    letter=${maximum:position:1}
    if [[ "$carry" -eq 1 ]]; then
      if [[ "$letter" == Z ]]; then
        letter=A
      else
        following=${alphabet#*"$letter"}
        letter=${following:0:1}
        carry=0
      fi
    fi
    next_sequence="$letter$next_sequence"
  done
  [[ "$carry" -eq 0 ]] || next_sequence="A$next_sequence"
  name="${month}${next_sequence}-$identity"
  [[ "$name" =~ $TICKET_RE ]] || init_fail "Allocated name does not match the shared ticket grammar: $name"
else
  # A same-second retry gets a suffix, never a guessed tracker identity or a reused directory.
  pending_base="pending-$(date +%Y%m%d%H%M%S)"
  name="$pending_base"
  suffix=0
  while [[ -e "$tickets/$name" || -L "$tickets/$name" ]]; do
    suffix=$((suffix + 1))
    name="$pending_base-$suffix"
  done
  [[ ! "$name" =~ $TICKET_RE ]] || init_fail 'Shared grammar recognizes the pending placeholder; cannot create a pending name safely'
fi
destination="$tickets/$name"
# A source already named correctly needs only marker completion; otherwise protect its
# supporting files from the proposed primary rename, not files in a template we will not copy.
[[ "$destination" == "$resume" || ( ! -e "$destination" && ! -L "$destination" ) ]] \
  || init_fail "Destination already exists: $destination"
if [[ -n "$resume" ]]; then
  [[ "$name.md" == "$resume_primary" || ( ! -e "$resume/$name.md" && ! -L "$resume/$name.md" ) ]] \
    || init_fail "Primary rename would overwrite a pending file: $name.md"
else
  [[ ! -e "$template/$name.md" && ! -L "$template/$name.md" ]] || init_fail "Primary rename would overwrite a template file: $name.md"
fi

# Preview performs the same read-only checks but allocates no staging directory or marker.
if [[ "$dry_run" -eq 1 ]]; then
  if [[ -n "$resume" ]]; then
    printf '%s\n' "$destination" 'PREVIEW: pending completion only; no files created, copied, renamed, or removed.' \
      'Only after user confirmation, perform and confirm these steps as an explicit lifecycle completion:'
    if [[ "$destination" != "$resume" ]]; then
      printf '  Rename folder: %s -> %s\n' "$resume" "$destination"
      printf '  Rename primary markdown: %s -> %s\n' "$destination/$resume_primary" "$destination/$name.md"
    else
      printf '  Folder and primary markdown already have the proposed name: %s\n' "$resume/$resume_primary"
    fi
    printf '  Then remove the pending marker: %s/%s\n' "$destination" "$TICKET_PENDING_MARKER"
    printf '%s\n' 'The pending record and marker remain unchanged by this preview.'
    exit 0
  fi
  printf '%s\n' "$destination" 'DRY RUN: unfinished scaffold only; no files written. Ticket facts and session entry still required.'
  exit 0
fi

# Own only the fresh staging directory. Failed copies, renames, or interrupts remove that
# directory, never an existing ticket; publishing is one same-filesystem directory rename.
stage=''
init_cleanup() {
  [[ -z "$stage" ]] || rm -rf -- "$stage"
}
trap init_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
stage=$(mktemp -d "$tickets/.ticket-init.XXXXXXXX") || init_fail 'Cannot create ticket staging directory'
cp -R -p "$template/." "$stage/" || init_fail 'Template copy failed; no ticket published'
mv -- "$stage/$primary" "$stage/$name.md" || init_fail 'Primary rename failed; no ticket published'
if [[ "$pending" -eq 1 ]]; then
  # touch preserves a customized marker's contents instead of silently truncating template data.
  touch "$stage/$TICKET_PENDING_MARKER" || init_fail 'Pending marker failed; no ticket published'
fi
[[ ! -e "$destination" && ! -L "$destination" ]] || init_fail "Destination appeared during copy: $destination"
mv -n -- "$stage" "$destination" || init_fail 'Cannot publish ticket scaffold'
[[ ! -d "$stage" ]] || init_fail "Destination collision; no ticket published: $destination"
stage=''
printf '%s\n' "$destination" 'UNFINISHED SCAFFOLD: template copied only; ticket facts and session entry still required.'
if [[ "$pending" -eq 1 ]]; then
  printf '%s\n' 'PENDING: supply the real identity, rename the folder and primary markdown, then remove .ticket-pending.'
fi