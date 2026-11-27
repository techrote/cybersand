"""Artificial archive transport controls; no gameplay or Windows qualification."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import package_evaluator as package
import seal_evaluator as seal


class SealControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="goblin-synthetic-seal-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.extracted = self.root / "extracted"
        self.extracted.mkdir()
        self.base = self.root / "base.zip"
        self.output = self.root / "final.zip"
        self.receipt = self.root / "receipt.json"
        self.report_path = self.root / "qualification.json"
        self.manifest = {"schema": package.SCHEMA, "successor_contract_version": 2,
            "source_commit": "1" * 40, "source_tree": "2" * 40,
            "provenance": {"godot_sha256": "3" * 64, "native_sha256": "4" * 64, "rapier_sha256": "5" * 64},
            "files_sha256": {}}
        for name, data in {"godot/project.godot": b"synthetic project",
                           "replay-corpus/case-000.json": b'{"synthetic":true}'}.items():
            self.write(name, data)
            self.manifest["files_sha256"][name] = package.sha(self.extracted / name)
        self.write(package.MANIFEST, seal.encoded(self.manifest))
        with zipfile.ZipFile(self.base, "x") as archive:
            for name in [*self.manifest["files_sha256"], package.MANIFEST]:
                archive.write(self.extracted / name, seal.ROOT_NAME + "/" + name)
        def evidence(name, data=b"synthetic retained observation"):
            path = "test-output/unit/" + name
            self.write(path, data)
            return path, package.sha(self.extracted / path)
        import_path, import_sha = evidence("import.log")
        case_log, case_log_sha = evidence("case.log")
        case_tape, case_tape_sha = evidence("tape.json")
        replay_log, replay_log_sha = evidence("replay.log")
        replay_tape, replay_tape_sha = evidence("replayed.json")
        graphics_log, graphics_sha = evidence("graphic.log")
        png, png_sha = evidence("interactive.png", b"\x89PNG\r\n\x1a\nsynthetic")
        first, first_sha = evidence("first-corpus.json")
        latest, latest_sha = evidence("source-corpus.json", b"synthetic latest")
        staged, staged_sha = evidence("import/goblin-corpus.json", b"synthetic latest")
        admission, admission_sha = evidence("admission.log")
        archive, archive_sha = evidence("run-000.json")
        self.report = {"schema": "synthetic-transport-control", "import_log": import_path,
            "import_log_sha256": import_sha,
            "cases": [{"fixture": "synthetic", "policy": "CONTROL", "attempted_actions": 1,
                       "completed_actions": 1, "elapsed_seconds": 0.1, "log": case_log, "log_sha256": case_log_sha,
                       "transcript": case_tape, "transcript_sha256": case_tape_sha}],
            "portable_replay": {"original": "replay-corpus/case-000.json",
                "original_sha256": self.manifest["files_sha256"]["replay-corpus/case-000.json"],
                "transcript": replay_tape, "transcript_sha256": replay_tape_sha, "log": replay_log, "log_sha256": replay_log_sha},
            "graphical_smoke": {"log": graphics_log, "log_sha256": graphics_sha, "screenshots": [{"path": png, "sha256": png_sha}]},
            "memory_roundtrip": {"first_corpus": first, "first_corpus_sha256": first_sha,
                "source_corpus": latest, "source_corpus_sha256": latest_sha,
                "fresh_profile_import": {"staged_corpus": staged, "staged_sha256": staged_sha,
                                        "admission_log": admission, "admission_log_sha256": admission_sha},
                "archive_checks": [{"path": archive, "sha256": archive_sha}]}}
        self.report_path.write_bytes(seal.encoded(self.report))

    def write(self, name, data):
        path = self.extracted / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def perform(self):
        return seal.seal(self.base, self.extracted, self.report_path, self.output, self.receipt)

    def test_unqualified_candidate_cannot_be_sealed(self):
        with patch.object(package, "verify_extracted", return_value={"qualified": False}):
            with self.assertRaises(ValueError):
                self.perform()
        self.assertFalse(self.output.exists())

    def test_transport_preserves_original_bytes_and_reextracts(self):
        original_sha = package.sha(self.base)
        with patch.object(package, "verify_extracted", return_value={"qualified": True, "scope": "synthetic only"}) as verify:
            result = self.perform()
        self.assertEqual(verify.call_count, 2)
        self.assertEqual(result["base_zip_sha256"], original_sha)
        self.assertEqual(package.sha(self.base), original_sha)
        self.assertNotEqual(result["base_zip_sha256"], result["final_zip_sha256"])
        self.assertFalse(result["original_payload_changed"])
        with zipfile.ZipFile(self.base) as before, zipfile.ZipFile(self.output) as after:
            for name in before.namelist():
                self.assertEqual(before.read(name), after.read(name), name)
            record = json.loads(after.read(seal.ROOT_NAME + "/" + seal.RECORD))
            for name, digest in record["supplementary_files_sha256"].items():
                self.assertEqual(hashlib.sha256(after.read(seal.ROOT_NAME + "/" + name)).hexdigest(), digest)
            self.assertEqual(after.read(seal.ROOT_NAME + "/" + seal.REPORT), self.report_path.read_bytes())

    def test_changed_evidence_cannot_be_sealed(self):
        self.write(self.report["cases"][0]["log"], b"tampered")
        with patch.object(package, "verify_extracted", return_value={"qualified": True}):
            with self.assertRaises(ValueError):
                self.perform()
        self.assertFalse(self.output.exists())

    def test_v3_preserves_the_actual_lineage_report_and_log(self):
        self.manifest["successor_contract_version"] = 3
        self.write(package.MANIFEST, seal.encoded(self.manifest))
        with zipfile.ZipFile(self.base, "w") as archive:
            for name in [*self.manifest["files_sha256"], package.MANIFEST]:
                archive.write(self.extracted / name, seal.ROOT_NAME + "/" + name)
        lineage = {}
        for key, name, content in (("report", "authored-lineage-test.json", b'{"synthetic_transport_only":true}'),
                                   ("log", "authored-lineage.log", b"synthetic transport marker\n")):
            path = "test-output/unit/" + name
            self.write(path, content)
            lineage[key], lineage[key + "_sha256"] = path, package.sha(self.extracted / path)
        self.report["authored_lineage"] = lineage
        self.report_path.write_bytes(seal.encoded(self.report))
        # This isolates archive transport, not the separately tested native
        # lineage acceptance; no synthetic tape becomes gameplay evidence.
        with patch.object(package, "verify_extracted", return_value={"qualified": True, "scope": "synthetic only"}):
            self.perform()
        with zipfile.ZipFile(self.output) as archive:
            record = json.loads(archive.read(seal.ROOT_NAME + "/" + seal.RECORD))
            for key in ("report", "log"):
                path = lineage[key]
                self.assertEqual(record["supplementary_files_sha256"][path], lineage[key + "_sha256"])
                self.assertEqual(archive.read(seal.ROOT_NAME + "/" + path), (self.extracted / path).read_bytes())

    def test_base_extra_member_and_case_alias_are_rejected(self):
        for name in ("CyberSand-goblin/untracked", "CyberSand-goblin/GODOT/project.godot", "../escape"):
            with self.subTest(name=name):
                candidate = self.root / ("bad-" + str(len(name)) + ".zip")
                with zipfile.ZipFile(self.base) as source, zipfile.ZipFile(candidate, "w") as target:
                    for item in source.infolist():
                        target.writestr(item, source.read(item))
                    target.writestr(name, b"synthetic")
                with self.assertRaises(ValueError):
                    seal.verify_base(candidate, self.extracted, self.manifest)

    def test_mutable_memory_cannot_seed_owner_default(self):
        current = "test-output/goblin-memory.json"
        self.write(current, b"synthetic mutable memory")
        report = copy.deepcopy(self.report)
        report["memory_roundtrip"]["source_corpus"] = current
        report["memory_roundtrip"]["source_corpus_sha256"] = package.sha(self.extracted / current)
        with self.assertRaises(ValueError):
            seal.referenced_evidence(self.extracted, report, self.manifest)

    def test_receipt_cannot_overwrite_final_zip(self):
        with patch.object(package, "verify_extracted", return_value={"qualified": True}):
            with self.assertRaises(ValueError):
                seal.seal(self.base, self.extracted, self.report_path, self.output, self.output)
        self.assertFalse(self.output.exists())

    def test_windows_case_alias_cannot_seed_mutable_memory(self):
        current = "test-output/GOBLIN-memory.json"
        self.write(current, b"synthetic mutable memory alias")
        report = copy.deepcopy(self.report)
        report["memory_roundtrip"]["source_corpus"] = current
        report["memory_roundtrip"]["source_corpus_sha256"] = package.sha(self.extracted / current)
        with self.assertRaises(ValueError):
            seal.referenced_evidence(self.extracted, report, self.manifest)

    def test_memory_pass_label_without_actual_roundtrip_is_rejected(self):
        with self.assertRaises(ValueError):
            package.verify_memory_roundtrip(self.extracted, {"status": "pass"}, self.manifest)


if __name__ == "__main__":
    unittest.main()
