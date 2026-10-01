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
        self.put(f"{GHK}/Repo Workflows/guide.md", "[Report](../Reports/report.md)\n")
        self.put(f"{GHK}/Reports/report.md", "# Authored report\n")
        self.put(f"{MAP}/_index.md", "[Orders](Repos/orders.md)\n")
        self.put(f"{MAP}/Repos/orders.md",
                 "[Ticket](../../..//Tickets/custom-case/custom-case.md)\n"
                 "[Knowledge](../../Topic/_index.md)\n")
        self.put(TICKET, "# TASK-1 - Orders\n\n## Current State\n- Now: active.\n")
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
        self.assertEqual(set(report), {"files_scanned", "links_checked", "findings", "coverage"})
        for finding in report["findings"]:
            self.assertTrue({"code", "path", "line", "message"} <= set(finding))
        return result.returncode, report

    def codes(self, report):
        return {finding["code"] for finding in report["findings"]}

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
        self.put(f"{MAP}/Repos/orders.md", "[Knowledge](../../Topic/_index.md)\n")
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
        original = '      { "type": "command", "bash": "bash _harness/scripts/check-ticket-log.sh", "cwd": ".", "timeoutSec": 60 }\n'
        self.assertIn(original, hook_text)
        self.assertEqual(starts[0], {"type": "command", "bash": "bash _harness/scripts/check-ticket-log.sh",
                                    "cwd": ".", "timeoutSec": 60})
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
        alias.symlink_to(self.root, target_is_directory=True)
        self.put(f"{MAP}/Repos/orders.md", f"[Ticket](<{alias / TICKET}>)\n"
                 "[Knowledge](../../Topic/_index.md)\n")
        self.put(f"{GAK}/Topic/_index.md", "[Note](Note%20One.md)\n"
                 "[Paren](note(1).md \"Title\")\n[Angle](<note two.md>)\n")
        self.put(f"{GAK}/Topic/note(1).md", "# Parentheses\n")
        self.put(f"{GAK}/Topic/note two.md", "# Spaces\n")
        self.assertEqual(self.run_check("--strict")[0], 0)

    def test_unreadable_markdown_and_symlinked_scope_are_incomplete(self):
        # Invalid UTF-8 deterministically exercises unavailable content even under privileged users.
        damaged = self.put(f"{GAK}/Topic/damaged.md", "")
        damaged.write_bytes(b"\xff")
        outside = Path(self.scratch.name) / "outside"
        outside.mkdir()
        (outside / "secret.md").write_text("[do-not-read](absent.md)\n", encoding="utf-8")
        (self.root / GAK / "linked-directory").symlink_to(outside, target_is_directory=True)
        exit_code, report = self.run_check()
        self.assertEqual(exit_code, 0)
        self.assertIn("UNAVAILABLE", self.codes(report))
        self.assertIn("OUTSIDE_ESTATE", self.codes(report))
        self.assertNotIn("MISSING_LINK", self.codes(report))
        self.assertFalse(report["coverage"]["complete"])


unittest.main(verbosity=2)
PY
}