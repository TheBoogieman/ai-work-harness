#!/usr/bin/env bash
# Exercise navigation observation in generic temporary estates, never an operator's records.
# Standalone: source dev/demo/cases/work-map.case.sh; case_work_map
case_work_map() {
  local wm_repo wm_python
  wm_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)" || return 1
  wm_python="${HARNESS_TEST_PYTHON:-python3}"
  # The override lets a caller prove this guard goes red against an absent or broken temp copy.
    "$wm_python" - "$wm_repo" "${HARNESS_WORK_MAP_HELPER:-$wm_repo/estate/_harness/scripts/check-work-map.py}" <<'PY'
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


HELPER = Path(sys.argv.pop()).resolve()
REPO = Path(sys.argv.pop()).resolve()
GAK = "General AI-Knowledge"
GHK = "General Human Knowledge"
MAP = f"{GAK}/Work Map"
TICKET = "Tickets/custom-case/custom-case.md"
WALKTHROUGH = "Tickets/custom-case/TASK-1-walkthrough.md"
# The repos property every fixture document carries, in the block-list form Obsidian writes. The
# fixture ticket's header lists the same repo, so the frontmatter checks find nothing to report.
FM_ORDERS = "---\nrepos:\n  - orders\n---\n"
TICKET_BODY = "# TASK-1 - Orders\n\nRepos:\n- Work/GitHub/orders\n\n## Current State\n- Now: active.\n"
CARD_BODY = "[Ticket](../../../Tickets/custom-case/custom-case.md)\n[Knowledge](../../Topic/_index.md)\n"


# Ask the platform once whether it can make a REAL symlink. Stock Windows refuses without
# Developer Mode (WinError 1314), and these fixtures cannot be faked with copies. A CI runner
# must always be able to link: there these tests are the only coverage, so failing beats skipping.
def can_symlink():
    with tempfile.TemporaryDirectory(prefix="harness-link-probe-") as probe:
        target = Path(probe) / "target"
        target.write_text("probe\n", encoding="utf-8")
        link = Path(probe) / "link"
        try:
            link.symlink_to(target)
        except (OSError, NotImplementedError):
            return False
        return link.is_symlink()


CAN_SYMLINK = can_symlink()
if not CAN_SYMLINK and os.environ.get("CI"):
    print("BUG [work-map-symlink-probe]: this CI runner cannot create symlinks, so the symlink"
          " tests would be skipped where they are the only coverage", file=sys.stderr)
    sys.exit(1)


class WorkMapTests(unittest.TestCase):
    # Each test owns its tree and cleanup; the demo runner's EXIT trap remains untouched.
    def setUp(self):
        self.assertTrue(HELPER.is_file(), "[work-map-helper-present] helper is absent")
        self.scratch = tempfile.TemporaryDirectory(prefix="harness-work-map-")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name) / "estate"
        self.root.mkdir()
        self.put(f"{GAK}/_index.md", "[Map](Work%20Map/_index.md)\n")
        self.put(f"{GHK}/_index.md", "[Runbooks](Repo%20Workflows/_index.md)\n")
        self.put(f"{GHK}/Repo Workflows/_index.md", "[Guide](guide.md)\n")
        self.put(f"{GHK}/Repo Workflows/guide.md", FM_ORDERS + "[Report](../Reports/report.md)\n")
        self.put(f"{GHK}/Reports/report.md", "# Authored report\n")
        self.put(f"{MAP}/_index.md", "[Orders](Repos/orders.md)\n")
        self.put(f"{MAP}/Repos/orders.md", FM_ORDERS +
                 "[Ticket](../../..//Tickets/custom-case/custom-case.md)\n"
                 "[Knowledge](../../Topic/_index.md)\n")
        self.put(TICKET, FM_ORDERS + TICKET_BODY)
        self.put("Tickets/custom-case/support.md", "[Primary](custom-case.md)\n")
        self.put("Tickets/custom-case/AI-Knowledge/_index.md",
                 "- detail.md - local detail - when changing orders\n")
        self.put("Tickets/custom-case/AI-Knowledge/detail.md", "# Detail\n")
        self.put(f"{GAK}/Topic/_index.md", "[Note](Note%20One.md#heading)\n")
        self.put(f"{GAK}/Topic/Note One.md", "# Note\n")

    def put(self, name, content):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return target

    def run_check(self, *args, root=None):
        result = subprocess.run(
            [sys.executable, str(HELPER), "--root", str(root or self.root), "--json", *args],
            capture_output=True, text=True, check=False)
        self.assertEqual(result.stderr, "")
        report = json.loads(result.stdout)
        self.assertEqual(set(report), {"files_scanned", "links_checked", "history_links", "findings", "coverage"})
        for finding in report["findings"]:
            self.assertTrue({"code", "path", "line", "message"} <= set(finding))
        return result.returncode, report

    def codes(self, report):
        return {finding["code"] for finding in report["findings"]}

    # Paths of every finding with one code, so a test names exactly which documents it expects.
    def findings_for(self, report, code):
        return {finding["path"] for finding in report["findings"] if finding["code"] == code}

    # Called after every link-free assertion has passed, so a skip never hides a real failure.
    def skip_without_links(self, guard):
        if not CAN_SYMLINK:
            self.skipTest(f"SKIP [{guard}]: this platform cannot create symlinks;"
                          " the Linux/macOS CI lanes run it")

    def test_healthy_encoded_link_and_reachable_report(self):
        before = {str(path): path.read_bytes() for path in self.root.rglob("*") if path.is_file()}
        exit_code, report = self.run_check("--strict")
        self.assertEqual(exit_code, 0)
        self.assertEqual(report["findings"], [])
        self.assertEqual(report["coverage"]["tickets"], 1)
        self.assertEqual(report["coverage"]["mapped"], 1)
        self.assertGreater(report["links_checked"], 0)
        self.assertEqual(report, self.run_check()[1])
        after = {str(path): path.read_bytes() for path in self.root.rglob("*") if path.is_file()}
        self.assertEqual(before, after, "[work-map-read-only] observation changed its inputs")

    # [work-map-frozen-audits] Earlier estate audit reports are frozen (never edited), so a link in
    # one whose target was later removed is counted as history, not raised as a finding; the newest
    # report is still checked like any other note. Red on a helper without history_links.
    def test_dead_link_in_earlier_audit_counts_as_history(self):
        self.put(f"{GHK}/_index.md", "[Runbooks](Repo%20Workflows/_index.md)\n[Audits](Audits/_index.md)\n")
        self.put(f"{GHK}/Audits/_index.md",
                 "[Old](20260101-estate-audit.md)\n[New](20260201-estate-audit.md)\n")
        self.put(f"{GHK}/Audits/20260101-estate-audit.md", "# Old\n[Gone](../../gone.md)\n")
        self.put(f"{GHK}/Audits/20260201-estate-audit.md", "# New\n")
        _, report = self.run_check()
        self.assertEqual(report["history_links"], 1)
        self.assertNotIn("MISSING_LINK", self.codes(report))
        self.put(f"{GHK}/Audits/20260201-estate-audit.md", "# New\n[Gone](../../gone.md)\n")
        _, report = self.run_check()
        self.assertEqual(report["history_links"], 1)
        self.assertIn("MISSING_LINK", self.codes(report))

    def test_missing_link_warning_and_strict(self):
        self.put("Tickets/custom-case/support.md", "# Support\n[Missing](absent%20note.md)\n")
        exit_code, report = self.run_check()
        self.assertEqual(exit_code, 0)
        missing = [item for item in report["findings"] if item["code"] == "MISSING_LINK"]
        self.assertEqual(len(missing), 1)
        self.assertEqual(missing[0]["line"], 2)
        self.assertEqual(missing[0]["path"], "Tickets/custom-case/support.md")
        self.assertEqual(self.run_check("--strict")[0], 1)

    def test_unmapped_primary_not_satisfied_by_index_link(self):
        self.put(f"{MAP}/Repos/orders.md", FM_ORDERS + "[Knowledge](../../Topic/_index.md)\n")
        self.put(f"{MAP}/_index.md", "[Orders](Repos/orders.md)\n"
                 "[Ticket](../../../Tickets/custom-case/custom-case.md)\n")
        exit_code, report = self.run_check()
        self.assertEqual(exit_code, 0)
        self.assertIn("UNMAPPED_TICKET", self.codes(report))
        self.assertEqual(report["coverage"]["mapped"], 0)

    def test_missing_entity_and_orphan_not_alias_guess(self):
        self.put(f"{MAP}/_index.md", "[Orders alias](Repos/missing.md)\n")
        self.put(f"{GAK}/Topic/omitted.md", "# Omitted\n")
        _, report = self.run_check()
        self.assertIn("MISSING_ENTITY", self.codes(report))
        orphans = {item["path"] for item in report["findings"] if item["code"] == "ORPHAN_NOTE"}
        self.assertIn(f"{GAK}/Topic/omitted.md", orphans)
        self.assertIn(f"{MAP}/Repos/orders.md", orphans)
        # An orphan entity cannot make its ticket discoverable from the map index.
        self.assertEqual(report["coverage"]["mapped"], 0)
        self.assertIn("UNMAPPED_TICKET", self.codes(report))

    def test_scope_fences_comments_inline_code_and_references(self):
        self.put("Tickets/custom-case/support.md", '''# Support
```markdown
[ignored](absent-fenced.md)
```
~~~
[ignored](absent-tilde.md)
~~~
`[ignored](absent-inline.md)` and ``[ignored](absent-double.md)``
<!-- [ignored](absent-comment.md)
[ignored](absent-multiline.md) -->
[primary][record]
[record]: custom-case.md "Primary"
[anchor](#current-state)
[web](https://example.invalid/no-file)
[mail](mailto:person@example.invalid)
[editor](vscode://file/not-a-file)
[vault](obsidian://open?vault=sample)
[placeholder](<path/to/note>)
''')
        for excluded in ("Logs", "Dump", ".git", "_retired", "SQL", "Checks"):
            self.put(f"Tickets/custom-case/{excluded}/bad.md", "[ignored](absent.md)\n")
        for excluded in ("Logs", "Dump", ".git", "_retired"):
            self.put(f"{GAK}/{excluded}/bad.md", "[ignored](absent.md)\n")
        self.put(f"{GAK}/Topic/ignored.ipynb", "not a notebook; must never be parsed")
        self.put("Tickets/not-a-ticket/support.md", "[ignored](absent.md)\n")
        self.put("GitHub/project/README.md", "[ignored](absent.md)\n")
        self.assertEqual(self.run_check("--strict")[0], 0)
        self.put("Tickets/custom-case/support.md", "[record]: absent.md\n[use][record]\n")
        self.assertIn("MISSING_LINK", self.codes(self.run_check()[1]))

    def test_custom_template_and_uninitialized_primary(self):
        self.put("Tickets/999912Z-CUSTOM-99999/999912Z-CUSTOM-99999.md",
                 "# Example\n## Current State\n[ignored](absent.md)\n")
        self.put("Tickets/custom-template/custom-template.md",
                 "# <BOARD>-<num> - <Short Ticket Description>\n## Current State\n")
        self.put("Tickets/custom-template/AI-Knowledge/_index.md", "- <file>.md - inert\n")
        self.put("Tickets/marked/marked.md", "# TASK-2\n## Current State\n")
        self.put("Tickets/marked/.not-a-ticket", "")
        _, report = self.run_check()
        self.assertEqual(report["coverage"]["tickets"], 1)
        self.assertEqual(report["coverage"]["mapped"], 1)
        self.assertEqual(report["coverage"]["uninitialized"], 1)
        self.assertIn("UNINITIALIZED_TICKET", self.codes(report))
        self.assertNotIn("UNMAPPED_TICKET", self.codes(report))
        self.assertFalse(report["coverage"]["complete"])

    def test_index_routing_and_promotion_not_grammar_validation(self):
        self.put(f"{GAK}/Topic/_index.md",
                 "- Note%20One.md - detail - read before changes\n"
                 "- old.md (promoted -> General AI-Knowledge/Promoted Topic)\n"
                 "- <file>.md - inert\n# - nonexistent.md - comment\n")
        self.put(f"{GAK}/Promoted Topic/Promoted Topic.md", "# Promoted\n")
        self.assertEqual(self.run_check("--strict")[0], 0)
        self.put(f"{GAK}/Topic/hidden.md", "# Hidden\n")
        self.put(f"{GAK}/Topic/_index.md", "[Directory](.)\n")
        self.assertIn("ORPHAN_NOTE", self.codes(self.run_check()[1]))

    def test_decoded_escape_symlink_and_absolute_legacy(self):
        outside = Path(self.scratch.name) / "outside.md"
        outside.write_text("[must-not-read](absent.md)\n", encoding="utf-8")
        self.put("Tickets/custom-case/support.md", "[legacy](" +
                 (self.root / TICKET).as_posix() + ")\n[external](" + outside.as_posix() + ")\n")
        self.assertEqual(self.run_check("--strict")[0], 0)
        self.skip_without_links("work-map-symlink-escape")
        (self.root / GAK / "escape.md").symlink_to(outside)
        self.put("Tickets/custom-case/support.md",
                 "[escape](%2e%2e/%2e%2e/%2e%2e/outside.md)\n"
                 "[symlink](../../General%20AI-Knowledge/escape.md)\n")
        _, report = self.run_check()
        self.assertIn("OUTSIDE_ESTATE", self.codes(report))
        self.assertNotIn("MISSING_LINK", self.codes(report))

    def test_missing_map_and_unavailable_root_never_block_default(self):
        (self.root / MAP / "_index.md").unlink()
        exit_code, report = self.run_check()
        self.assertEqual(exit_code, 0)
        self.assertNotIn("UNMAPPED_TICKET", self.codes(report))
        self.assertFalse(report["coverage"]["map_available"])
        exit_code, report = self.run_check(root=self.root / "absent")
        self.assertEqual(exit_code, 0)
        self.assertFalse(report["coverage"]["complete"])
        self.assertIn("UNAVAILABLE", self.codes(report))

    def test_default_root_is_helper_estate(self):
        copied = self.root / "_harness/scripts/check-work-map.py"
        copied.parent.mkdir(parents=True)
        shutil.copyfile(HELPER, copied)
        result = subprocess.run([sys.executable, str(copied), "--json", "--strict"],
                                cwd=self.scratch.name, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout)["coverage"]["tickets"], 1)

    def test_separate_hook_preserves_validator_and_graceful_missing_python(self):
        # Execute the configured commands in the fixture, not the repository's real validator.
        hook_text = (REPO / "estate/_harness/hooks/hooks.example.json").read_text(encoding="utf-8")
        config = json.loads(hook_text)
        self.assertEqual(set(config), {"$comment", "version", "hooks"})
        hooks = config["hooks"]
        starts = hooks["sessionStart"]
        self.assertEqual(len(starts), 2)
        # The validator entry's own line keeps its original text up to the timeoutSec; since #339 the
        # entry continues onto a second line with its Windows ('powershell') variant, which
        # [hooks-windows] checks. Every original field is still asserted exactly.
        original = '      { "type": "command", "bash": "bash _harness/scripts/check-ticket-log.sh", "cwd": ".", "timeoutSec": 60,\n'
        self.assertIn(original, hook_text)
        self.assertEqual({k: v for k, v in starts[0].items() if k != "powershell"},
                         {"type": "command", "bash": "bash _harness/scripts/check-ticket-log.sh",
                          "cwd": ".", "timeoutSec": 60})
        self.assertEqual(set(starts[0]), {"type", "bash", "cwd", "timeoutSec", "powershell"})
        self.assertNotIn("--strict", starts[1]["bash"])
        self.assertEqual(starts[1]["cwd"], ".")
        bash = shutil.which("bash")
        self.assertIsNotNone(bash)
        no_python = self.root / "empty-bin"
        no_python.mkdir()
        result = subprocess.run([bash, "-c", starts[1]["bash"]], cwd=self.root,
                                env={**os.environ, "PATH": str(no_python)},
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0)
        self.assertIn("NOTE", result.stdout)
        self.assertIn("python3 unavailable", result.stdout)
        self.skip_without_links("work-map-hook-tools")
        tools = self.root / "test-bin"
        tools.mkdir()
        (tools / "python3").symlink_to(sys.executable)
        (tools / "bash").symlink_to(bash)
        environment = {**os.environ, "PATH": str(tools)}
        result = subprocess.run([bash, "-c", starts[1]["bash"]], cwd=self.root,
                                env=environment, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0)
        self.assertIn("helper unavailable", result.stdout)
        self.put("_harness/scripts/check-ticket-log.sh", "exit 7\n")
        self.put("_harness/scripts/check-work-map.py", "raise SystemExit(4)\n")
        validator = subprocess.run([bash, "-c", starts[0]["bash"]], cwd=self.root,
                                   env=environment, capture_output=True, check=False)
        observer = subprocess.run([bash, "-c", starts[1]["bash"]], cwd=self.root,
                                  env=environment, capture_output=True, text=True, check=False)
        self.assertEqual(validator.returncode, 7)
        self.assertEqual(observer.returncode, 0)
        self.assertIn("NOTE", observer.stdout)

    def test_absolute_estate_alias_and_parenthesized_destinations(self):
        # Legacy absolute routes identify the same loaded record, including a symlinked root alias.
        alias = Path(self.scratch.name) / "estate-alias"
        if CAN_SYMLINK:
            alias.symlink_to(self.root, target_is_directory=True)
        else:
            alias = self.root
        self.put(f"{MAP}/Repos/orders.md", FM_ORDERS + f"[Ticket](<{alias / TICKET}>)\n"
                 "[Knowledge](../../Topic/_index.md)\n")
        self.put(f"{GAK}/Topic/_index.md", "[Note](Note%20One.md)\n"
                 "[Paren](note(1).md \"Title\")\n[Angle](<note two.md>)\n")
        self.put(f"{GAK}/Topic/note(1).md", "# Parentheses\n")
        self.put(f"{GAK}/Topic/note two.md", "# Spaces\n")
        self.assertEqual(self.run_check("--strict")[0], 0)
        self.skip_without_links("work-map-root-alias")

    def test_unreadable_markdown_and_symlinked_scope_are_incomplete(self):
        # Invalid UTF-8 deterministically exercises unavailable content even under privileged users.
        damaged = self.put(f"{GAK}/Topic/damaged.md", "")
        damaged.write_bytes(b"\xff")
        outside = Path(self.scratch.name) / "outside"
        outside.mkdir()
        (outside / "secret.md").write_text("[do-not-read](absent.md)\n", encoding="utf-8")
        if CAN_SYMLINK:
            (self.root / GAK / "linked-directory").symlink_to(outside, target_is_directory=True)
        exit_code, report = self.run_check()
        self.assertEqual(exit_code, 0)
        self.assertIn("UNAVAILABLE", self.codes(report))
        self.assertNotIn("MISSING_LINK", self.codes(report))
        self.assertFalse(report["coverage"]["complete"])
        self.skip_without_links("work-map-symlinked-scope")
        self.assertIn("OUTSIDE_ESTATE", self.codes(report))

    # [work-map-frontmatter-forms] Obsidian may save a list in flow form ([a, b]), quote its items,
    # leave an optional list empty or write CRLF line endings; each is the same list. The fixture's
    # three documents of a kind that carries repos (ticket, repo card, runbook) are counted as
    # expected and present. Red on a helper without the frontmatter coverage counts.
    def test_frontmatter_block_and_flow_lists_are_equivalent(self):
        _, report = self.run_check()
        self.assertEqual(report["coverage"]["frontmatter_expected"], 3)
        self.assertEqual(report["coverage"]["frontmatter_present"], 3)
        self.put(TICKET, "---\nrepos: [orders]\npipelines: []\n---\n" + TICKET_BODY)
        self.put(f"{MAP}/Repos/orders.md", "").write_bytes(
            ("---\nrepos: [\"orders\"]\n---\n" + CARD_BODY).replace("\n", "\r\n").encode("utf-8"))
        self.put(f"{GHK}/Repo Workflows/guide.md",
                 "---\nrepos:\n  - 'orders'\npipelines:\n---\n[Report](../Reports/report.md)\n")
        exit_code, report = self.run_check("--strict")
        self.assertEqual(exit_code, 0, report["findings"])
        self.assertEqual(report["coverage"]["frontmatter_present"], 3)

    # [work-map-frontmatter-missing] A ticket, walkthrough, repo card, pipeline page or runbook with
    # no repos property is a NOTE, never red: legacy records are grandfathered until a backfill. A
    # knowledge note needs none, and frontmatter holding other keys only still lacks repos.
    # Red on a helper without FRONTMATTER_MISSING.
    def test_frontmatter_missing_on_required_kinds(self):
        self.put(f"{MAP}/_index.md", "[Orders](Repos/orders.md)\n[Load](Pipelines/orders-load.md)\n")
        self.put(f"{MAP}/Pipelines/orders-load.md", "# Orders load\n")
        self.put(WALKTHROUGH, "---\naliases: [Walkthrough]\n---\n# TASK-1 walkthrough\n")
        self.put(TICKET, TICKET_BODY)
        exit_code, report = self.run_check()
        self.assertEqual(exit_code, 0)
        self.assertEqual(self.findings_for(report, "FRONTMATTER_MISSING"),
                         {TICKET, WALKTHROUGH, f"{MAP}/Pipelines/orders-load.md"})
        self.assertEqual(report["coverage"]["frontmatter_expected"], 5)
        self.assertEqual(report["coverage"]["frontmatter_present"], 2)
        self.assertEqual(self.run_check("--strict")[0], 1)

    # [work-map-frontmatter-unknown] A repos value names a repo card (Work Map/Repos/<value>.md) and a
    # pipelines value a pipeline page (Work Map/Pipelines/<value>.md), on any scanned document that
    # carries them; the finding's target is the missing page. A wiki-link or a path is not a page
    # name, so its finding has no target. Red on a helper without UNKNOWN_REPO and UNKNOWN_PIPELINE.
    def test_frontmatter_unknown_values(self):
        self.put(f"{GAK}/Topic/Note One.md", "---\nrepos:\n  - ghost\npipelines: [nightly]\n---\n# Note\n")
        self.put(f"{GHK}/Repo Workflows/guide.md",
                 "---\nrepos: [\"[[orders]]\"]\n---\n[Report](../Reports/report.md)\n")
        _, report = self.run_check()
        unknown = sorted((item["code"], item["path"], item.get("target", "")) for item in report["findings"]
                         if item["code"] in {"UNKNOWN_REPO", "UNKNOWN_PIPELINE"})
        self.assertEqual(unknown, [
            ("UNKNOWN_PIPELINE", f"{GAK}/Topic/Note One.md", f"{MAP}/Pipelines/nightly.md"),
            ("UNKNOWN_REPO", f"{GAK}/Topic/Note One.md", f"{MAP}/Repos/ghost.md"),
            ("UNKNOWN_REPO", f"{GHK}/Repo Workflows/guide.md", "")])
        self.put(f"{MAP}/_index.md",
                 "[Orders](Repos/orders.md)\n[Ghost](Repos/ghost.md)\n[Nightly](Pipelines/nightly.md)\n")
        self.put(f"{MAP}/Repos/ghost.md", "---\nrepos: [ghost]\n---\n# Ghost\n")
        self.put(f"{MAP}/Pipelines/nightly.md", "---\nrepos: [ghost]\npipelines: [nightly]\n---\n# Nightly\n")
        self.put(f"{GHK}/Repo Workflows/guide.md", FM_ORDERS + "[Report](../Reports/report.md)\n")
        exit_code, report = self.run_check("--strict")
        self.assertEqual(exit_code, 0, report["findings"])

    # [work-map-frontmatter-ticket-match] A ticket's repos equals the GitHub/<repo> entries of its
    # header Repos list (read from the raw text, so a backticked entry counts; any other entry, such
    # as the estate itself, is prose). Its walkthrough carries at least the ticket's repos (a shared
    # walkthrough may cover more). Red on a helper without FRONTMATTER_MISMATCH.
    def test_frontmatter_ticket_and_walkthrough_match_header(self):
        header = ("# TASK-1 - Orders\n\nRepos:\n- Work/GitHub/orders\n- `Work/GitHub/billing`\n"
                  "- Work (the estate records)\n\n## Current State\n- Now: active.\n")
        self.put(f"{MAP}/_index.md", "[Orders](Repos/orders.md)\n[Billing](Repos/billing.md)\n")
        self.put(f"{MAP}/Repos/billing.md", "---\nrepos: [billing]\n---\n# Billing\n")
        self.put(TICKET, FM_ORDERS + header)
        self.put(WALKTHROUGH, "---\nrepos: []\n---\n# TASK-1 walkthrough\n")
        _, report = self.run_check()
        self.assertEqual(self.findings_for(report, "FRONTMATTER_MISMATCH"), {TICKET, WALKTHROUGH})
        self.put(TICKET, "---\nrepos: [billing, orders]\n---\n" + header)
        self.put(WALKTHROUGH, "---\nrepos:\n  - orders\n  - billing\n---\n# TASK-1 walkthrough\n")
        exit_code, report = self.run_check("--strict")
        self.assertEqual(exit_code, 0, report["findings"])

    # [work-map-frontmatter-header-label-forms] The header's Repos label is read when it is bold or
    # annotated, as hand-written headers often are: a ticket listing a repo under "**Repos:**" with
    # repos: [] is a mismatch, and one listing it under "Repos (confirmed by discovery):" with that
    # repo matches. Red on a helper that reads only the bare "Repos:" line (#331).
    def test_frontmatter_header_repos_label_forms(self):
        def ticket(label):
            return (f"# TASK-1 - Orders\n\n{label}\n- Work/GitHub/orders\n\n"
                    "## Current State\n- Now: active.\n")
        for label in ("**Repos:**", "**Repos**:", "Repos (confirmed by discovery):"):
            self.put(TICKET, "---\nrepos: []\n---\n" + ticket(label))
            _, report = self.run_check()
            self.assertEqual(self.findings_for(report, "FRONTMATTER_MISMATCH"), {TICKET}, label)
            self.put(TICKET, FM_ORDERS + ticket(label))
            exit_code, report = self.run_check("--strict")
            self.assertEqual(exit_code, 0, (label, report["findings"]))

    # [work-map-frontmatter-entity-self] A repo card lists its own name in repos; a pipeline page lists
    # its own slug in pipelines (it is that value's owner) beside the repos that host it.
    # Red on a helper without FRONTMATTER_MISMATCH for entity pages.
    def test_frontmatter_entity_pages_name_themselves(self):
        load = f"{MAP}/Pipelines/orders-load.md"
        self.put(f"{MAP}/_index.md", "[Orders](Repos/orders.md)\n[Load](Pipelines/orders-load.md)\n")
        self.put(load, "---\nrepos: [orders]\npipelines: []\n---\n# Orders load\n")
        self.put(f"{MAP}/Repos/orders.md", "---\nrepos: []\n---\n" + CARD_BODY)
        _, report = self.run_check()
        self.assertEqual(self.findings_for(report, "FRONTMATTER_MISMATCH"), {f"{MAP}/Repos/orders.md", load})
        self.put(load, "---\nrepos: [orders]\npipelines: [orders-load]\n---\n# Orders load\n")
        self.put(f"{MAP}/Repos/orders.md", FM_ORDERS + CARD_BODY)
        exit_code, report = self.run_check("--strict")
        self.assertEqual(exit_code, 0, report["findings"])

    # [work-map-frontmatter-malformed] Frontmatter is the plain subset Obsidian writes. No YAML comment
    # (other scripts read a "# ..." line as a Markdown heading, so a comment could become a ticket's
    # title), a closed block, list values for repos and pipelines, no repeated key. A "---" further
    # down a file is a thematic break, not frontmatter.
    # Red on a helper without FRONTMATTER_COMMENT and FRONTMATTER_MALFORMED.
    def test_frontmatter_malformed_and_comments(self):
        self.put(TICKET, "---\n# TODO fill in\nrepos:\n  - orders\n---\n" + TICKET_BODY)
        _, report = self.run_check()
        comments = [(item["path"], item["line"]) for item in report["findings"]
                    if item["code"] == "FRONTMATTER_COMMENT"]
        self.assertEqual(comments, [(TICKET, 2)])
        # The comment is not the ticket's title, so the ticket still counts as initialized.
        self.assertEqual(report["coverage"]["tickets"], 1)
        self.assertNotIn("UNINITIALIZED_TICKET", self.codes(report))
        self.put(TICKET, FM_ORDERS + TICKET_BODY)
        card = f"{MAP}/Repos/orders.md"
        for broken in ("---\nrepos:\n  - orders\n",                      # never closed
                       "---\nrepos: orders\n---\n",                      # a single value, not a list
                       "---\nrepos: [orders\n---\n",                     # flow list never closed
                       "---\nrepos: [orders]\nrepos: [orders]\n---\n",  # repeated key
                       # An unquoted ": " inside any value makes Obsidian drop the whole block.
                       "---\nrepos: [orders]\nsummary: Orders: nightly load\n---\n"):
            self.put(card, broken + CARD_BODY)
            _, report = self.run_check()
            self.assertEqual(self.findings_for(report, "FRONTMATTER_MALFORMED"), {card}, broken)
        # The same value quoted is plain YAML that Obsidian reads, so it is not a finding.
        self.put(card, "---\nrepos: [orders]\nsummary: \"Orders: nightly load\"\n---\n" + CARD_BODY)
        _, report = self.run_check()
        self.assertNotIn("FRONTMATTER_MALFORMED", self.codes(report))
        self.put(card, FM_ORDERS + CARD_BODY)
        self.put("Tickets/custom-case/support.md",
                 "# Support\n\n---\n\nrepos: [ghost]\n[Primary](custom-case.md)\n")
        exit_code, report = self.run_check("--strict")
        self.assertEqual(exit_code, 0, report["findings"])


unittest.main(verbosity=2)
PY
}