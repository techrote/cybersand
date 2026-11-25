"""Artificial evidence controls only; these tests never launch Godot."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import qualify_retained_clock as diagnostic


class RetainedClockEvidenceTests(unittest.TestCase):
    def capture(self):
        cells = [58 if x < 2 or x >= 46 or y < 2 or y >= 46 else
                 2 if 16 <= x < 24 and 8 <= y < 16 else 0 for y in range(48) for x in range(48)]
        source = {"generation": 3, "revision": 4, "tick": 16, "paused": True, "failed": False}
        value = {"region": [48, 48, 48, 48], "count": 2304, "materials": cells,
                 "material_sha256": hashlib.sha256(struct.pack("<2304i", *cells)).hexdigest(),
                 "source_matches": True, "source_before": source, "source_after": dict(source),
                 "admission": {"operation_id": 8, "status": "queued"},
                 "native_receipt": {"operation_id": 8, "status": "completed", "kind": "capture",
                                    "backend": "CyberNativeCellWorld", "region": [48, 48, 48, 48],
                                    "generation": 3, "observed_generation": 3, "revision": 4, "tick": 16}}
        return value, {"native": dict(source)}

    def test_exact_source_and_raw_bytes_are_required(self):
        value, observation = self.capture()
        self.assertEqual(len(diagnostic.capture_cells(value, observation)), 2304)
        for field in ("generation", "revision", "tick"):
            with self.subTest(field=field):
                stale = deepcopy(observation)
                stale["native"][field] += 1
                with self.assertRaises(ValueError):
                    diagnostic.capture_cells(value, stale)
        changed = deepcopy(value)
        changed["materials"][60] = 0
        with self.assertRaises(ValueError):
            diagnostic.capture_cells(changed, observation)

    def test_receipt_and_region_tampering_fail_closed(self):
        value, observation = self.capture()
        for field, replacement in (("operation_id", 9), ("observed_generation", 4), ("status", "refused"),
                                   ("region", [0, 0, 48, 48]), ("backend", "test_substitute")):
            with self.subTest(field=field):
                bad = deepcopy(value)
                bad["native_receipt"][field] = replacement
                with self.assertRaises(ValueError):
                    diagnostic.capture_cells(bad, observation)
        for field in ("source_before", "source_after", "native_receipt", "admission"):
            with self.subTest(shape=field):
                bad = deepcopy(value)
                bad[field] = None
                with self.assertRaises(ValueError):
                    diagnostic.capture_cells(bad, observation)

    def test_boolean_and_noninteger_materials_are_not_native_cells(self):
        value, observation = self.capture()
        for replacement in (True, 2.0, None, -1, 132):
            with self.subTest(material=replacement):
                bad = deepcopy(value)
                bad["materials"][0] = replacement
                with self.assertRaises(ValueError):
                    diagnostic.capture_cells(bad, observation)

    def test_automatic_capture_requires_exact_original_bytes_and_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            profile = Path(temporary)
            candidate = profile / "candidate-002.json"
            tape, provenance = {"synthetic": "not a gameplay tape"}, {"synthetic_source": "a"}
            raw = {"cases": [{}, {"hypothesis_reproduced": True, "transcript": tape,
                                  "automatic_candidate_bundle": {"path": "user://goblin/candidate-002.json", "exists": True}}],
                   "actual_source_provenance": provenance}
            bundle = {"schema": "cybersand-goblin-reproduction-bundle-v1", "captured_automatically": True,
                      "gameplay_defect_confirmed": False, "original_tape": tape,
                      "exact_provenance": provenance, "reduced_tape": {}, "classification": "unresolved_observation"}
            candidate.write_bytes(json.dumps(bundle).encode())
            raw["cases"][1]["automatic_candidate_bundle"]["sha256"] = diagnostic.runner.sha_file(candidate)
            self.assertTrue(diagnostic.automatic_bundle(profile, raw)["original_tape_exact"])
            bad = deepcopy(raw)
            bad["cases"][1]["transcript"] = {"synthetic": "different"}
            with self.assertRaises(ValueError):
                diagnostic.automatic_bundle(profile, bad)
            bad = deepcopy(raw)
            bad["cases"][1]["automatic_candidate_bundle"]["sha256"] = "0" * 64
            with self.assertRaises(ValueError):
                diagnostic.automatic_bundle(profile, bad)
            candidate.unlink()
            with self.assertRaises(ValueError):
                diagnostic.automatic_bundle(profile, raw)

    def test_retention_failure_preserves_explicit_interruption(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            runtime = root / "pinned-runtime"
            runtime.write_bytes(b"artificial file; no execution")
            output = root / "output"
            custody = {"source_commit": "a" * 40}
            provenance = {"platform": "linux", "source_commit": "a" * 40}
            process = {"status": "cancelled", "interrupted": True, "surviving_owned_pids": [], "exit_code": -15}

            def stage_project(project, reuse_import_cache=False):
                project.mkdir()
                return {"project_files_sha256": "b" * 64, "files": {}}

            with patch.object(diagnostic, "clean_source", return_value=custody), \
                    patch.object(diagnostic.runner, "sha_file", return_value=diagnostic.GODOT_SHA256), \
                    patch.object(diagnostic.runner, "runtime_identity", return_value=provenance), \
                    patch.object(diagnostic.runner, "stage_project", side_effect=stage_project), \
                    patch.object(diagnostic.runner, "make_profile", return_value={}), \
                    patch.object(diagnostic.replay_identity, "build", return_value={}), \
                    patch.object(diagnostic, "check_stage"), \
                    patch.object(diagnostic.runner, "execute", return_value=process) as execute, \
                    patch.object(diagnostic.runner, "retain_source_and_remove_project", side_effect=OSError("artificial archive failure")):
                code = diagnostic.main(["--godot", str(runtime), "--out", str(output), "--reuse-import-cache"])
            self.assertEqual(code, 130)
            self.assertEqual(execute.call_count, 1)
            report = json.loads((output / "retained-clock-qualification.json").read_bytes())
            self.assertEqual(report["status"], "cancelled")
            self.assertTrue(report["operator_cancelled"])
            self.assertEqual(report["retention_error"], "artificial archive failure")
            self.assertEqual(report["stages"][0]["process"], process)


if __name__ == "__main__":
    unittest.main()
