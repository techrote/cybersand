"""Adversarial tests for the #361 current-main successor source admission."""
from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools/lcb/in_tools_current_main_admission.py"
SPEC = importlib.util.spec_from_file_location("in_tools_current_main_admission", MODULE_PATH)
subject = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(subject)


class AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.record = subject.parse_json(subject.RECORD.read_text(encoding="utf-8"))

    def test_current_checkout_and_minimal_authority(self) -> None:
        result = subject.check()
        self.assertEqual(result["status"], "admitted")
        self.assertEqual(result["adopted_main"], "ba9cbc89029be88b812af59b19e5c59829bbcd90")
        self.assertEqual(result["authority_count"], 13)
        self.assertEqual(result["planned_count"], 6)
        self.assertEqual(result["planned_execution"], "NOT_RUN")
        self.assertFalse(result["gameplay_qualified"])
        self.assertFalse(result["runtime_qualified"])

    def test_duplicate_json_key_refuses(self) -> None:
        with self.assertRaisesRegex(subject.AdmissionError, "duplicate JSON key"):
            subject.parse_json('{"schema":"a","schema":"b"}')

    def test_stale_registered_blob_refuses(self) -> None:
        record = copy.deepcopy(self.record)
        record["authority"][0]["git_blob"] = "0" * 40
        with self.assertRaisesRegex(subject.AdmissionError, "registered blob is stale"):
            subject.check(record=record)

    def test_missing_or_extra_authority_refuses(self) -> None:
        record = copy.deepcopy(self.record)
        record["authority"].pop()
        with self.assertRaisesRegex(subject.AdmissionError, "authority count"):
            subject.validate_record(record)

    def test_fixture_cannot_be_relabelled_current_or_passed(self) -> None:
        record = copy.deepcopy(self.record)
        record["planned"][0]["status"] = "Current"
        record["planned"][0]["execution"] = "PASS"
        with self.assertRaisesRegex(subject.AdmissionError, "Planned/NOT_RUN"):
            subject.validate_record(record)

    def test_qualification_flags_cannot_be_predeclared(self) -> None:
        for field in ("gameplay_qualified", "runtime_qualified"):
            record = copy.deepcopy(self.record)
            record[field] = True
            with self.subTest(field=field), self.assertRaisesRegex(
                subject.AdmissionError, "cannot claim"
            ):
                subject.validate_record(record)

    def test_working_copy_mutation_refuses_and_is_restored(self) -> None:
        target = ROOT / self.record["authority"][0]["path"]
        original = target.read_bytes()
        try:
            target.write_bytes(original + b"\n# admission-negative-control\n")
            with self.assertRaisesRegex(subject.AdmissionError, "working source changed"):
                subject.check()
        finally:
            target.write_bytes(original)
        self.assertEqual(subject.check()["status"], "admitted")


    # A01 controls: the record must not choose its own 13 protected paths.
    def test_authority_allowlist_exactly_matches_reviewed_paths(self) -> None:
        registered = [row["path"] for row in self.record["authority"]]
        self.assertEqual(subject.EXPECTED_AUTHORITY_COUNT, 13)
        self.assertEqual(len(subject.EXPECTED_AUTHORITY_PATHS), 13)
        self.assertEqual(len(registered), len(set(registered)))
        self.assertEqual(set(registered), subject.EXPECTED_AUTHORITY_PATHS)

    def _substitute_world(self, record: dict, foreign_path: str) -> None:
        base = record["adopted_main"]
        foreign_blob = subject._git(ROOT, "rev-parse", f"{base}:{foreign_path}")
        world = next(row for row in record["authority"] if row["path"] == "native/src/world.cpp")
        world.update({
            "path": foreign_path,
            "git_blob": foreign_blob,
            "role": "unrelated accepted-main source (negative control)",
        })

    def test_same_count_world_substitution_refuses(self) -> None:
        record = copy.deepcopy(self.record)
        self._substitute_world(record, "README.md")
        self.assertEqual(len(record["authority"]), 13)
        self.assertEqual(len({row["path"] for row in record["authority"]}), 13)
        with self.assertRaisesRegex(subject.AdmissionError, "authority path set differs"):
            subject.validate_record(record)
        with self.assertRaisesRegex(subject.AdmissionError, "authority path set differs"):
            subject.check(record=record)

    def test_foreign_accepted_main_makefile_refuses(self) -> None:
        record = copy.deepcopy(self.record)
        self._substitute_world(record, "Makefile")
        with self.assertRaisesRegex(subject.AdmissionError, "authority path set differs"):
            subject.validate_record(record)

    def test_duplicate_path_and_world_omission_refuse(self) -> None:
        duplicated = copy.deepcopy(self.record)
        world = next(row for row in duplicated["authority"] if row["path"] == "native/src/world.cpp")
        world["path"] = duplicated["authority"][0]["path"]
        with self.assertRaisesRegex(subject.AdmissionError, "duplicated"):
            subject.validate_record(duplicated)
        omitted = copy.deepcopy(self.record)
        omitted["authority"] = [row for row in omitted["authority"] if row["path"] != "native/src/world.cpp"]
        with self.assertRaisesRegex(subject.AdmissionError, "authority count"):
            subject.validate_record(omitted)

    def test_malformed_authority_and_stale_identity_refuse(self) -> None:
        for bad_row in (
            ["malformed-row"],
            {"path": ["native/src/world.cpp"], "git_blob": "0" * 40, "role": "bad"},
            {"path": "native/src/world.cpp", "git_blob": [], "role": "bad"},
        ):
            record = copy.deepcopy(self.record)
            record["authority"][10] = bad_row
            with self.subTest(row=repr(bad_row)), self.assertRaises(subject.AdmissionError):
                subject.validate_record(record)
        for field, value, expected_error in (
            ("assignment_pin", "0" * 40, "assignment pin changed"),
            ("adopted_main", "0" * 40, "adopted main differs"),
        ):
            record = copy.deepcopy(self.record)
            record[field] = value
            with self.subTest(field=field), self.assertRaisesRegex(subject.AdmissionError, expected_error):
                subject.validate_record(record)
        record = copy.deepcopy(self.record)
        record["predecessor"]["head"] = "0" * 40
        with self.assertRaisesRegex(subject.AdmissionError, "historical predecessor identity changed"):
            subject.validate_record(record)

    def test_world_working_copy_mutation_refuses_and_restores(self) -> None:
        target = ROOT / "native/src/world.cpp"
        original = target.read_bytes()
        try:
            target.write_bytes(original + b"\n// A01 working-tree negative control\n")
            with self.assertRaisesRegex(subject.AdmissionError, "working source changed for native/src/world.cpp"):
                subject.check()
        finally:
            target.write_bytes(original)
        self.assertEqual(subject.check()["status"], "admitted")

    def test_real_descendant_world_commit_cannot_hide_behind_restored_worktree(self) -> None:
        # An actual descendant commit mutates World, then the worktree is restored
        # to the admitted base blob. HEAD and worktree must be checked separately.
        with tempfile.TemporaryDirectory(prefix="in-tools-a01-") as temp:
            worktree = Path(temp) / "descendant"
            command = ["git", "-C", str(ROOT), "worktree", "add", "--detach", "--no-checkout", str(worktree), "HEAD"]
            subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                # With --no-checkout, seed the index with HEAD without materialising
                # the entire repository (including large LFS runtime artifacts).
                subprocess.run(["git", "-C", str(worktree), "read-tree", "HEAD"], check=True)
                for path in subject.EXPECTED_AUTHORITY_PATHS:
                    target = worktree / path
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(ROOT / path, target)
                shutil.copyfile(ROOT / "README.md", worktree / "README.md")
                world = worktree / "native/src/world.cpp"
                original = world.read_bytes()
                world.write_bytes(original + b"\n// A01 descendant committed negative control\n")
                subprocess.run(["git", "-C", str(worktree), "add", "--", "native/src/world.cpp"], check=True)
                subprocess.run([
                    "git", "-C", str(worktree),
                    "-c", "user.name=CyberSand Test", "-c", "user.email=cybersand-test@invalid.example",
                    "commit", "--quiet", "-m", "A01 descendant negative control",
                ], check=True)
                world.write_bytes(original)
                self.assertNotEqual(subject._git(worktree, "rev-parse", "HEAD"), subject._git(ROOT, "rev-parse", "HEAD"))
                with self.assertRaisesRegex(subject.AdmissionError, "successor modifies production authority path: native/src/world.cpp"):
                    subject.check(root=worktree)
                substituted = copy.deepcopy(self.record)
                self._substitute_world(substituted, "README.md")
                with self.assertRaisesRegex(subject.AdmissionError, "authority path set differs"):
                    subject.check(record=substituted, root=worktree)
            finally:
                subprocess.run(["git", "-C", str(ROOT), "worktree", "remove", "--force", str(worktree)], check=True)

if __name__ == "__main__":
    unittest.main()
