"""Adversarial A01 tests for the #361 exact source-admission guard."""
from __future__ import annotations

import copy
import importlib.util
import shutil
import subprocess
import tempfile
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools/lcb/in_tools_361_source_admission.py"
SPEC = importlib.util.spec_from_file_location("in_tools_361_source_admission", MODULE_PATH)
subject = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(subject)


class AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.record = subject.parse_json(subject.RECORD.read_text(encoding="utf-8"))

    def test_current_checkout_and_exact_code_pinned_authority(self) -> None:
        result = subject.check()
        self.assertEqual(result["status"], "admitted")
        self.assertEqual(result["implementation_base"], subject.IMPLEMENTATION_BASE)
        self.assertEqual(result["authority_count"], len(subject.AUTHORITY_ROLES))
        self.assertEqual(
            {row["path"] for row in result["authority"]},
            set(subject.AUTHORITY_ROLES),
        )

    def test_duplicate_json_key_refuses(self) -> None:
        with self.assertRaisesRegex(subject.AdmissionError, "duplicate JSON key"):
            subject.parse_json('{"schema":"a","schema":"b"}')

    def _substitute(self, protected: str, replacement: str) -> dict:
        record = copy.deepcopy(self.record)
        row = next(row for row in record["authority"] if row["path"] == protected)
        row["path"] = replacement
        row["role"] = "unrelated accepted-main path"
        return record

    def test_same_count_world_cpp_substitution_refuses(self) -> None:
        record = self._substitute("native/src/world.cpp", "README.md")
        self.assertEqual(len(record["authority"]), len(self.record["authority"]))
        with self.assertRaisesRegex(subject.AdmissionError, "authority path set differs"):
            subject.validate_record(record)

    def test_same_count_second_protected_path_substitution_refuses(self) -> None:
        record = self._substitute(
            "godot/scripts/simulation_worker.gd", "CONTRIBUTING.md"
        )
        self.assertEqual(len(record["authority"]), len(self.record["authority"]))
        with self.assertRaisesRegex(subject.AdmissionError, "authority path set differs"):
            subject.validate_record(record)

    def test_wrong_accepted_base_blob_refuses(self) -> None:
        record = copy.deepcopy(self.record)
        row = next(row for row in record["authority"] if row["path"] == "native/src/world.cpp")
        row["base_blob"] = "0" * 40
        with self.assertRaisesRegex(subject.AdmissionError, "base blob mismatch"):
            subject.check(record=record)

    def test_wrong_admitted_blob_refuses(self) -> None:
        record = copy.deepcopy(self.record)
        row = next(row for row in record["authority"] if row["path"] == "native/src/world.cpp")
        row["admitted_blob"] = "0" * 40
        with self.assertRaisesRegex(subject.AdmissionError, "admission anchor blob mismatch"):
            subject.check(record=record)

    def test_working_copy_mutation_refuses_and_is_restored(self) -> None:
        target = ROOT / "native/src/world.cpp"
        original = target.read_bytes()
        try:
            target.write_bytes(original + b"\n// A01 dirty-working-copy control\n")
            with self.assertRaisesRegex(subject.AdmissionError, "working source changed"):
                subject.check()
        finally:
            target.write_bytes(original)
        self.assertEqual(subject.check()["status"], "admitted")

    def test_omitted_path_then_descendant_mutation_still_fails_closed(self) -> None:
        # This is the exact exploit class from #404's review. Even if an attacker
        # mutates the omitted production path in a descendant checkout, the
        # record cannot omit/replace it because the immutable code set is checked
        # before record-provided identities are trusted.
        substituted = self._substitute("native/src/world.cpp", "README.md")
        with self.assertRaisesRegex(subject.AdmissionError, "authority path set differs"):
            subject.validate_record(substituted)

        temp_root = Path(tempfile.mkdtemp(prefix="in-tools-a01-"))
        try:
            subprocess.run(
                ["git", "-C", str(ROOT), "worktree", "add", "--detach", str(temp_root), "HEAD"],
                check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            subprocess.run(["git", "-C", str(temp_root), "config", "user.name", "A01 Control"], check=True)
            subprocess.run(["git", "-C", str(temp_root), "config", "user.email", "a01@example.invalid"], check=True)
            target = temp_root / "native/src/world.cpp"
            target.write_bytes(target.read_bytes() + b"\n// committed descendant mutation\n")
            subprocess.run(["git", "-C", str(temp_root), "add", "native/src/world.cpp"], check=True)
            subprocess.run(
                ["git", "-C", str(temp_root), "commit", "-m", "A01 descendant mutation control"],
                check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            with self.assertRaisesRegex(
                subject.AdmissionError, "descendant modifies admitted authority path"
            ):
                subject.check(record=self.record, root=temp_root)
        finally:
            subprocess.run(
                ["git", "-C", str(ROOT), "worktree", "remove", "--force", str(temp_root)],
                check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            shutil.rmtree(temp_root, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
