"""Adversarial receipt checks; synthetic custody fixtures, not runtime evidence."""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import native_receipt
import qualify_lab


class CompletionReceipts(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.log = Path(self.directory.name) / "run.log"
        self.schema = "objectshard-lab-integration-test-v1"
        self.good = {"schema": self.schema, "checks": 359, "failures": 0}

    def test_one_actual_completion_after_diagnostics(self) -> None:
        self.log.write_text("Godot diagnostic line\n" + json.dumps(self.good) + "\n")
        self.assertEqual(qualify_lab.footer(self.log, self.schema), self.good)

    def test_duplicate_completion_is_not_accepted(self) -> None:
        self.log.write_text((json.dumps(self.good) + "\n") * 2)
        with self.assertRaises(ValueError):
            qualify_lab.footer(self.log, self.schema)

    def test_missing_failed_and_false_typed_completion(self) -> None:
        for value in ({"schema": "wrong", "failures": 0},
                      {**self.good, "failures": 1}, {**self.good, "failures": False}):
            with self.subTest(value=value):
                self.log.write_text(json.dumps(value))
                with self.assertRaises(ValueError):
                    qualify_lab.footer(self.log, self.schema)


class NativeBuildReceipts(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.receipt = self.root / "receipt.json"
        self.binary = self.root / "candidate.so"
        # An ELF header is only a custody fixture. No executable claim follows.
        self.binary.write_bytes(b"\x7fELF\x02\x01" + bytes(12) + b"\x3e\x00" + b"fixture")
        self.source = {"source_commit": "a" * 40, "source_tree": "b" * 40,
                       "source_inputs": {"native/src/world.cpp": "c" * 64},
                       "build_contract_inputs": {"build.sh": "d" * 64}}

    def command(self, action: str, source: dict | None = None) -> None:
        argv = ["native_receipt.py", action, "--receipt", str(self.receipt),
                "--runtime", str(self.binary), "--expected-source-sha", "a" * 40]
        with patch("sys.argv", argv), patch.object(native_receipt, "identity", return_value=source or self.source), \
                contextlib.redirect_stdout(io.StringIO()):
            native_receipt.main()

    def test_capture_then_build_seal_and_verify(self) -> None:
        self.command("snapshot")
        self.command("seal")
        self.command("verify")
        self.assertEqual(json.loads(self.receipt.read_text())["phase"], "sealed")

    def test_snapshot_cannot_overwrite_previous_build_identity(self) -> None:
        self.command("snapshot")
        with self.assertRaises(ValueError):
            self.command("snapshot")

    def test_source_change_during_build_refuses_seal(self) -> None:
        self.command("snapshot")
        changed = {**self.source, "source_inputs": {"native/src/world.cpp": "e" * 64}}
        with self.assertRaises(ValueError):
            self.command("seal", changed)
        self.assertEqual(json.loads(self.receipt.read_text())["phase"], "captured")

    def test_compiler_contract_change_during_build_refuses_seal(self) -> None:
        self.command("snapshot")
        changed = {**self.source, "build_contract_inputs": {"build.sh": "e" * 64}}
        with self.assertRaises(ValueError):
            self.command("seal", changed)

    def test_altered_binary_after_seal_is_refused(self) -> None:
        self.command("snapshot")
        self.command("seal")
        self.binary.write_bytes(self.binary.read_bytes() + b"alteration")
        with self.assertRaises(ValueError):
            self.command("verify")

    def test_stale_or_unsealed_receipt_is_refused(self) -> None:
        self.command("snapshot")
        with self.assertRaises(ValueError):
            self.command("verify")
        self.command("seal")
        with self.assertRaises(ValueError):
            self.command("verify", {**self.source, "source_commit": "e" * 40})

    def test_wrong_platform_header_is_refused(self) -> None:
        self.command("snapshot")
        self.binary.write_bytes(b"MZ" + bytes(80))
        with self.assertRaises(ValueError):
            self.command("seal")


class ExecutedSourceCustody(unittest.TestCase):
    def test_missing_windows_candidate_does_not_trust_installed_dll(self) -> None:
        with self.assertRaises(ValueError):
            qualify_lab.require_custody("win32", None, None, None)

    def test_ambiguous_windows_custody_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            qualify_lab.require_custody("win32", Path("candidate"), Path("package"), None)

    def test_linux_cannot_use_windows_receipt_or_unbound_runtime(self) -> None:
        for candidate, package, receipt in ((None, None, None), (Path("candidate"), None, Path("receipt"))):
            with self.subTest(candidate=candidate, package=package, receipt=receipt):
                with self.assertRaises(ValueError):
                    qualify_lab.require_custody("linux", candidate, package, receipt)

    def test_explicit_platform_custody_is_admitted(self) -> None:
        qualify_lab.require_custody("win32", Path("candidate"), None, None)
        qualify_lab.require_custody("win32", None, Path("package"), None)
        qualify_lab.require_custody("linux", None, None, Path("receipt"))

    def test_modified_delivered_lab_script_is_not_covered_by_root_hash(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            script = root / "godot/scripts/object_shard_lab_session.gd"
            script.parent.mkdir(parents=True)
            script.write_bytes(b"committed Lab source\n")
            expected = {script.relative_to(root).as_posix(): hashlib.sha256(script.read_bytes()).hexdigest()}
            self.assertEqual(qualify_lab.verify_scripts(root, expected), expected)
            script.write_bytes(b"altered delivered Lab source\n")
            with self.assertRaises(ValueError):
                qualify_lab.verify_scripts(root, expected)


if __name__ == "__main__":
    unittest.main()
