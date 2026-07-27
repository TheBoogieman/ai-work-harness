#!/usr/bin/env bash
# scrub-case-agree.case.sh — [scrub-case-agree]: the pack's SCRUB rules and its self-AUDIT must
# agree on case. SOURCED by the runner; see dev/scripts/run_demo.sh.
#
# The SCRUB rules once matched case-SENSITIVELY while the self-audit matched case-INSENSITIVELY
# (grep -qiE), so a lowercase placeholder in an ordinary prose file survived the scrub and then
# tripped the audit that exists to catch what the scrub missed: an honest edit red-blocked the pack
# build. The fixture is a staged ticket file carrying a scrub-table token in the case that used to
# escape. Own throwaway pack dir, like [space-named-pack] and [pack-without-zip], so the shared
# PACK_OUT_DIR keeps one archive.
#
# TWO assertions, because there are two ways to make the halves agree and only one is safe: exit 0
# proves the audit no longer fires, and the scrubbed text proves the fix WIDENED the scrub instead
# of NARROWING the audit — narrowing it also yields exit 0, while shipping the raw token in
# the pack.
#
# THE TOKEN IS ASSEMBLED AT RUNTIME, never written contiguously in this file. When this case lived
# in the single-file suite that was load-bearing: make_context_pack stages the estate's own
# `_harness/scripts/*`, so
# the suite's own source rode into every pack it built, and a literal token here would have redded
# the FIRST pack build ([space-named-pack], far earlier) with that case's message instead of this
# one. After the split this file sits under dev/demo/, which the pack builder does not stage,
# so its bytes no longer travel — the runtime assembly is now belt-and-braces rather than the thing
# that makes the red land here. It stays: it costs one line, it keeps the FIXTURE the only carrier
# of the token, and it is what would still hold if the staging set ever widened to all of _harness/.
# Keep it split if you edit this block.

case_scrub_case_agree() {
  local G169_TOKEN G169_TICKET G169_OUT_DIR G169_OUT G169_RC g169zip G169_TXT
  G169_TOKEN=$(printf '<your-org-%s>' domain)
  G169_TICKET="999911Z-PROJ-99169"
  G169_OUT_DIR=$(mktemp -d)
  mkdir -p "estate/Tickets/$G169_TICKET"
  printf '# case fixture\nReach us at %s for access.\n' "$G169_TOKEN" \
    > "estate/Tickets/$G169_TICKET/$G169_TICKET.md"
  set +e
  G169_OUT=$(PACK_OUT_DIR="$G169_OUT_DIR" bash estate/_harness/scripts/make_context_pack.sh \
    --ticket "$G169_TICKET" 2>&1); G169_RC=$?
  set -e
  # A no-match must not trip set -e / pipefail, hence the `|| true`.
  g169zip=$(ls "$G169_OUT_DIR"/harness-pack-*.zip 2>/dev/null | head -1 || true)
  G169_TXT=""
  [ -n "$g169zip" ] \
    && G169_TXT=$(unzip -p "$g169zip" "Tickets/$G169_TICKET/$G169_TICKET.md" 2>/dev/null || true)
  # fixture is scratch: gone before anything else sees it
  rm -rf "estate/Tickets/$G169_TICKET" "$G169_OUT_DIR"
  [ "$G169_RC" -eq 0 ] \
    || { echo "BUG [scrub-case-agree]: a lowercase scrub-table token failed the pack build" \
           "(rc=$G169_RC) — the scrub missed what the audit caught:"; \
         printf '%s\n' "$G169_OUT"; exit 1; }
  printf '%s\n' "$G169_TXT" | grep -q '<org>' \
    || { echo "BUG [scrub-case-agree]: the lowercase token was not replaced by its scrub-table" \
           "substitute:"; printf '%s\n' "$G169_TXT"; exit 1; }
  printf '%s\n' "$G169_TXT" | grep -qiF -- "$G169_TOKEN" \
    && { echo "BUG [scrub-case-agree]: a scrub-table token survived into the pack — the audit was" \
           "narrowed instead of the scrub widened:"; printf '%s\n' "$G169_TXT"; exit 1; }
  echo "  ok [scrub-case-agree] — a lowercase token is scrubbed out, not merely tolerated"
}
