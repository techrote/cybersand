"""Adverse reader controls, not engine execution or graphical qualification."""
from copy import deepcopy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import execution_policy as policy
import play_execution_contract as subject
import verify_play_input011 as input011
import verify_play_life010 as life010
import verify_play_life011 as life011


def godot_identity():
    expected = policy.identity()
    return {"ok": True, "path": "res://tests/support/ci_execution_policy.json",
            **{key: expected[key] for key in ("schema_version", "sha256", "scale")},
            "watchdogs": {key: expected["watchdogs"][key] for key in subject.GODOT_KEYS}}


class PolicyIdentityControls(unittest.TestCase):
    def test_python_identity_cannot_choose_larger_budget(self):
        self.assertTrue(subject.policy_matches(policy.identity()))
        for change in (
            lambda value: value["watchdogs"].update(operation_seconds=900),
            lambda value: value.update(sha256="0" * 64),
            lambda value: value.update(scale=True),
            lambda value: value.update(schema_version=True),
            lambda value: value.update(scale=2),
            lambda value: value.update(path="elsewhere.json"),
        ):
            value = policy.identity()
            change(value)
            with self.subTest(value=value):
                self.assertFalse(subject.policy_matches(value))

    def test_scale_is_chosen_by_execution_environment_not_receipt(self):
        original = policy.identity()
        with mock.patch.dict(os.environ, {policy.SCALE_ENV: str(original["scale"] * 2)}):
            self.assertFalse(subject.policy_matches(original))
            self.assertTrue(subject.policy_matches(policy.identity()))

    def test_godot_identity_requires_exact_registered_fields(self):
        def verify(value):
            return subject.verify_log_policy(subject.MARKER + json.dumps(value), "1" * 40)
        with mock.patch.object(subject, "verify_source_policy", return_value=policy.identity()):
            verify(godot_identity())
            for change in (
                lambda value: value.update(ok=False),
                lambda value: value.update(path=subject.POLICY_PATH),
                lambda value: value.update(sha256="0" * 64),
                lambda value: value.update(scale=True),
                lambda value: value.update(schema_version=True),
                lambda value: value["watchdogs"].update(operation_seconds=15),
                lambda value: value["watchdogs"].update(main_ack_seconds=900),
                lambda value: value["watchdogs"].pop("terminate_grace_seconds"),
            ):
                value = godot_identity()
                change(value)
                with self.subTest(value=value), self.assertRaisesRegex(ValueError, "log_mismatch"):
                    verify(value)

    def test_missing_duplicate_or_malformed_marker_is_not_evidence(self):
        marker = subject.MARKER + json.dumps(godot_identity())
        with mock.patch.object(subject, "verify_source_policy", return_value=policy.identity()):
            for log in ("", marker + "\n" + marker, subject.MARKER + "{"):
                with self.subTest(log=log), self.assertRaises(ValueError):
                    subject.verify_log_policy(log, "1" * 40)

    def test_source_policy_is_read_from_exact_git_revision(self):
        # A real local Git object proves a changed checkout cannot relabel old
        # source evidence. This does not require engine/runtime materialization.
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / subject.POLICY_PATH
            path.parent.mkdir(parents=True)
            path.write_bytes(policy.POLICY_PATH.read_bytes())
            def git(*args):
                return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.DEVNULL).decode().strip()
            git("init", "-q")
            git("add", ".")
            git("-c", "user.name=Verifier test", "-c", "user.email=test@example.invalid",
                "commit", "-qm", "Synthetic policy identity fixture")
            original = git("rev-parse", "HEAD")
            path.write_bytes(path.read_bytes() + b"\n")
            git("add", ".")
            git("-c", "user.name=Verifier test", "-c", "user.email=test@example.invalid",
                "commit", "-qm", "Different policy bytes")
            changed = git("rev-parse", "HEAD")
            with mock.patch.object(subject, "ROOT", root):
                self.assertEqual(subject.verify_source_policy(original), policy.identity())
                with self.assertRaisesRegex(ValueError, "source_mismatch"):
                    subject.verify_source_policy(changed)
                with self.assertRaisesRegex(ValueError, "source_identity"):
                    subject.verify_source_policy("HEAD")


class ProcessControls(unittest.TestCase):
    def receipt(self, family):
        name = "test_play_" + family + "_acrobat"
        return {"name": name, "status": "passed", "returncode": 0,
                "timeout_seconds": policy.case_seconds(name), "seconds": 181,
                "requires_display": False, "execution_policy": policy.identity(),
                "natural_completion": True, "timed_out": False,
                "command": ["godot", "--headless", "--path", "/fixture/godot", "--script",
                            "res://tests/" + name + ".gd"]}

    def check(self, family, receipt):
        if family == "life011":
            life011.check_process(receipt, "test_play_life011_acrobat")
        else:
            {"life010": life010, "input011": input011}[family].check_process(receipt, "acrobat")

    def test_slow_natural_success_is_accepted_for_all_three_readers(self):
        for family in ("life010", "life011", "input011"):
            with self.subTest(family=family):
                self.check(family, self.receipt(family))

    def test_crash_timeout_partial_capture_or_receipt_override_cannot_pass(self):
        for family in ("life010", "life011", "input011"):
            original = self.receipt(family)
            for key, value in (
                ("returncode", -1073741819), ("returncode", True), ("status", "failed"),
                ("timed_out", True), ("timeout_kind", "wall"), ("natural_completion", False),
                ("capture_error", "missing output"), ("timeout_diagnostic_error", "capture failed"),
                ("skip_messages", ["SKIP"]), ("execution_policy", {}),
                ("timeout_seconds", 180), ("timeout_seconds", original["timeout_seconds"] + 1),
                ("seconds", original["timeout_seconds"] + .01),
                ("seconds", float("nan")), ("seconds", float("inf")), ("seconds", True),
                ("command", ["godot", "--quit"]),
            ):
                with self.subTest(family=family, field=key), self.assertRaises((ValueError, IndexError)):
                    self.check(family, original | {key: value})

    def test_local_receipt_requires_policy_and_natural_completion(self):
        original = self.receipt("life010")
        local = {key: original[key] for key in (
            "command", "timeout_seconds", "returncode", "timed_out", "execution_policy", "natural_completion")}
        local["elapsed_seconds"] = 181
        life010.check_process(local, "acrobat", True)
        for key in ("execution_policy", "natural_completion"):
            altered = deepcopy(local)
            altered.pop(key)
            with self.assertRaisesRegex(ValueError, "local_process_schema"):
                life010.check_process(altered, "acrobat", True)


if __name__ == "__main__":
    unittest.main()
