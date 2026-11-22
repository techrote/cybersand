#!/usr/bin/env python3
"""Exercise real isolated Git histories for the explicit Windows run guard."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import run_request as guard


class Repository:
    def __init__(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="swarm004-run-request-")
        self.root = Path(self.temporary.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "Isolated run-request fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.frozen = self.write_commit({"app.cpp": "int main() { return 0; }\n"})

    def close(self) -> None:
        self.temporary.cleanup()

    def git(self, *args: str) -> str:
        return guard.git(self.root, *args).decode().strip()

    def write_commit(self, files: dict[str, str | None], message: str = "fixture") -> str:
        for name, content in files.items():
            path = self.root / name
            if content is None:
                path.unlink()
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
        self.git("add", "--all")
        self.git("commit", "--quiet", "--no-gpg-sign", "-m", message)
        return self.git("rev-parse", "HEAD")

    def request(self, **changes: object) -> dict:
        value = {"schema": 1, "programme": "GENTEK-SWARM-004", "action": "qualify-windows",
                 "source_sha": self.frozen, "request_id": "known605-owner-evaluation-001"}
        value.update(changes)
        return value

    def execute(self, value: dict | None = None, **other_files: str) -> tuple[str, dict]:
        before = self.git("rev-parse", "HEAD")
        execution = self.write_commit({guard.REQUEST: json.dumps(self.request() if value is None else value), **other_files})
        event = {"ref": guard.BRANCH, "before": before, "after": execution,
                 "created": False, "deleted": False, "forced": False}
        return execution, event

    def validate(self, execution: str, event: dict) -> dict:
        return guard.validate(self.root, "push", guard.BRANCH, execution, execution, event)


class RequestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Repository()
        self.addCleanup(self.repo.close)

    def test_manual_exact_head_needs_no_request(self) -> None:
        result = guard.validate(self.repo.root, "workflow_dispatch", guard.BRANCH,
                                self.repo.frozen, self.repo.frozen)
        self.assertEqual(result["execution_source_sha"], self.repo.frozen)
        self.assertIsNone(result["request_id"])
        self.assertFalse((self.repo.root / guard.REQUEST).exists())

    def test_new_request_qualifies_execution_head_and_records_frozen_parent(self) -> None:
        execution, event = self.repo.execute()
        result = self.repo.validate(execution, event)
        self.assertTrue(result["passed"])
        self.assertEqual(result["execution_source_sha"], execution)
        self.assertEqual(result["frozen_source_sha"], self.repo.frozen)
        self.assertEqual(result["request_only_commits"], [execution])
        self.assertEqual(len(result["request_sha256"]), 64)

    def test_ancestor_with_only_explicit_request_updates(self) -> None:
        first, _ = self.repo.execute()
        execution, event = self.repo.execute(self.repo.request(request_id="second-explicit-request"))
        result = self.repo.validate(execution, event)
        self.assertEqual(result["request_only_commits"], [execution, first])
        self.assertEqual(result["frozen_source_sha"], self.repo.frozen)

    def test_ordinary_source_push_has_no_request(self) -> None:
        execution = self.repo.write_commit({"app.cpp": "changed source\n"})
        event = {"ref": guard.BRANCH, "before": self.repo.frozen, "after": execution,
                 "created": False, "deleted": False, "forced": False}
        with self.assertRaisesRegex(ValueError, "committed regular request"):
            self.repo.validate(execution, event)

    def test_request_cannot_accompany_source_edits(self) -> None:
        execution, event = self.repo.execute(**{"app.cpp": "changed source\n"})
        with self.assertRaisesRegex(ValueError, "change only the request"):
            self.repo.validate(execution, event)

    def test_net_source_revert_does_not_hide_intervening_edits(self) -> None:
        self.repo.write_commit({"app.cpp": "changed source\n"})
        self.repo.write_commit({"app.cpp": "int main() { return 0; }\n"})
        execution, event = self.repo.execute()
        self.assertEqual(guard.changed(self.repo.root, self.repo.frozen, execution), [guard.REQUEST])
        with self.assertRaisesRegex(ValueError, "change only the request"):
            self.repo.validate(execution, event)

    def test_frozen_source_must_be_published_before_execution_push(self) -> None:
        previous = self.repo.frozen
        self.repo.frozen = self.repo.write_commit({"app.cpp": "new frozen source\n"})
        execution, event = self.repo.execute()
        event["before"] = previous
        with self.assertRaisesRegex(ValueError, "Publish the frozen source"):
            self.repo.validate(execution, event)

    def test_wrong_branch_event_or_target(self) -> None:
        for event_name, ref, target in [("pull_request", guard.BRANCH, self.repo.frozen),
                                       ("workflow_dispatch", "refs/heads/main", self.repo.frozen),
                                       ("workflow_dispatch", guard.BRANCH, "0" * 40)]:
            with self.subTest(event=event_name, ref=ref), self.assertRaises(ValueError):
                guard.validate(self.repo.root, event_name, ref, self.repo.frozen, target)

    def test_malformed_request_fields(self) -> None:
        variants = [dict(schema=True), dict(schema=2), dict(programme="another-programme"),
                    dict(action="publish"), dict(source_sha="HEAD"), dict(source_sha="f" * 40),
                    dict(request_id=""), dict(request_id="x" * 81), dict(request_id="$(command)"),
                    dict(extra="unexpected")]
        for fields in variants:
            with self.subTest(fields=fields):
                self.repo.git("reset", "--hard", self.repo.frozen)
                execution, event = self.repo.execute(self.repo.request(**fields))
                with self.assertRaises(ValueError):
                    self.repo.validate(execution, event)

    def test_missing_field_duplicate_key_and_oversized_payload(self) -> None:
        missing = self.repo.request(); del missing["action"]
        payloads = [json.dumps(missing), json.dumps(self.repo.request())[:-1] + ',"schema":1}',
                    json.dumps(self.repo.request()) + " " * guard.MAX_REQUEST_BYTES]
        for payload in payloads:
            with self.subTest(length=len(payload)):
                self.repo.git("reset", "--hard", self.repo.frozen)
                execution = self.repo.write_commit({guard.REQUEST: payload})
                event = {"ref": guard.BRANCH, "before": self.repo.frozen, "after": execution,
                         "created": False, "deleted": False, "forced": False}
                with self.assertRaises(ValueError):
                    self.repo.validate(execution, event)

    def test_changed_or_abnormal_push_metadata(self) -> None:
        execution, event = self.repo.execute()
        for key, value in [("created", True), ("deleted", True), ("forced", True),
                           ("after", self.repo.frozen), ("ref", "refs/heads/main"),
                           ("before", "0" * 40), ("before", execution)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.repo.validate(execution, {**event, key: value})

    def test_deleted_request_is_not_an_execution_command(self) -> None:
        previous, _ = self.repo.execute()
        execution = self.repo.write_commit({guard.REQUEST: None})
        event = {"ref": guard.BRANCH, "before": previous, "after": execution,
                 "created": False, "deleted": False, "forced": False}
        with self.assertRaisesRegex(ValueError, "committed regular request"):
            self.repo.validate(execution, event)

    def test_symlink_request_is_refused(self) -> None:
        payload = self.repo.git("hash-object", "-w", "app.cpp")
        self.repo.git("update-index", "--add", "--cacheinfo", f"120000,{payload},{guard.REQUEST}")
        self.repo.git("commit", "--quiet", "--no-gpg-sign", "-m", "symlink fixture")
        execution = self.repo.git("rev-parse", "HEAD")
        event = {"ref": guard.BRANCH, "before": self.repo.frozen, "after": execution,
                 "created": False, "deleted": False, "forced": False}
        with self.assertRaisesRegex(ValueError, "committed regular request"):
            self.repo.validate(execution, event)

    def test_unrelated_source_commit_is_refused(self) -> None:
        tree = self.repo.git("rev-parse", "HEAD^{tree}")
        unrelated = self.repo.git("commit-tree", tree, "-m", "unrelated source")
        execution, event = self.repo.execute(self.repo.request(source_sha=unrelated))
        with self.assertRaisesRegex(ValueError, "proper ancestor"):
            self.repo.validate(execution, event)

    def test_merge_or_empty_commit_in_request_ancestry_is_refused(self) -> None:
        first, _ = self.repo.execute()
        tree = self.repo.git("rev-parse", "HEAD^{tree}")
        merged = self.repo.git("commit-tree", tree, "-p", first, "-p", self.repo.frozen, "-m", "merge fixture")
        self.repo.git("reset", "--hard", merged)
        event = {"ref": guard.BRANCH, "before": first, "after": merged,
                 "created": False, "deleted": False, "forced": False}
        with self.assertRaisesRegex(ValueError, "merge commits"):
            self.repo.validate(merged, event)
        self.repo.git("reset", "--hard", first)
        self.repo.git("commit", "--quiet", "--allow-empty", "--no-gpg-sign", "-m", "empty fixture")
        empty = self.repo.git("rev-parse", "HEAD")
        event["after"] = empty
        with self.assertRaisesRegex(ValueError, "change only the request"):
            self.repo.validate(empty, event)

    def test_history_is_bounded(self) -> None:
        for index in range(guard.MAX_REQUEST_COMMITS + 1):
            execution, event = self.repo.execute(self.repo.request(request_id=f"explicit-request-{index}"))
        with self.assertRaisesRegex(ValueError, "bounded history"):
            self.repo.validate(execution, event)

    def test_cli_emits_same_source_bound_receipt(self) -> None:
        execution, event = self.repo.execute()
        event_file = self.repo.root / "event.json"
        event_file.write_text(json.dumps(event), encoding="utf-8")
        output = self.repo.root / "evidence/validation.json"
        command = [sys.executable, str(Path(guard.__file__).resolve()), "--root", str(self.repo.root),
                   "--event-name", "push", "--ref", guard.BRANCH, "--execution", execution,
                   "--target", execution, "--event-file", str(event_file), "--output", str(output)]
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(output.read_text()), self.repo.validate(execution, event))
        expected = self.repo.root / "producer.json"
        expected.write_bytes(output.read_bytes().replace(b"\n", b"\r\n"))
        result = subprocess.run([*command, "--expected-receipt", str(expected)],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        changed = json.loads(expected.read_text()); changed["request_sha256"] = "0" * 64
        expected.write_text(json.dumps(changed), encoding="utf-8")
        result = subprocess.run([*command, "--expected-receipt", str(expected)],
                                capture_output=True, text=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Producer and consumer run-request validation differ", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
