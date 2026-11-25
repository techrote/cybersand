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
    def source_boundary(self):
        receipt = {"armed": False, "burst_queued": False, "stream_enabled": False, "origin": [0, 0],
                   "material": 0, "attempted": 0, "inserted": 0, "blocked": 0, "stream_ticks": 0}
        observed = {"actor_ids": [], "actors": [], "paused": True,
                    "native": {"generation": 3, "revision": 4, "tick": 0, "paused": True, "failed": False},
                    "source": {"authored": [], "pending_commands": 1, "receipt": receipt}}
        proof = {"phase": "initial", "index": -1, "bounded_copy_complete": True, "command_count": 1,
                 "owner_generation": 3, "commands": [{"command": "stop", "origin": [0, 0], "material": 0}],
                 "before": deepcopy(observed), "after": deepcopy(observed), "current_source_receipt": deepcopy(receipt)}
        return observed, proof

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

    def test_pending_stop_needs_actual_bound_queue_and_disarmed_owner(self):
        observed, proof = self.source_boundary()
        self.assertTrue(diagnostic.actor_free(observed, proof, "initial", -1))
        self.assertFalse(diagnostic.actor_free(observed, {}, "initial", -1))
        for kind in ("configure", "burst", "stream", "unknown"):
            with self.subTest(command=kind):
                altered = deepcopy(proof)
                altered["commands"][0]["command"] = kind
                self.assertFalse(diagnostic.actor_free(observed, altered, "initial", -1))
        for field, value in (("origin", [1, 0]), ("material", 2)):
            with self.subTest(argument=field):
                altered = deepcopy(proof)
                altered["commands"][0][field] = value
                self.assertFalse(diagnostic.actor_free(observed, altered, "initial", -1))
        for field, value in (("armed", True), ("burst_queued", True), ("stream_enabled", True),
                             ("material", 2), ("inserted", 1), ("attempted", 1)):
            with self.subTest(owner=field):
                altered = deepcopy(proof)
                altered["current_source_receipt"][field] = value
                self.assertFalse(diagnostic.actor_free(observed, altered, "initial", -1))

    def test_pending_stop_rejects_stale_phase_source_and_count(self):
        observed, proof = self.source_boundary()
        for field, value in (("owner_generation", 2), ("index", 0), ("phase", "after_action"),
                             ("command_count", 0), ("bounded_copy_complete", False), ("commands", [])):
            with self.subTest(field=field):
                altered = deepcopy(proof)
                altered[field] = value
                self.assertFalse(diagnostic.actor_free(observed, altered, "initial", -1))
        for side in ("before", "after"):
            for field in ("generation", "revision", "tick"):
                with self.subTest(side=side, native=field):
                    altered = deepcopy(proof)
                    altered[side]["native"][field] += 1
                    self.assertFalse(diagnostic.actor_free(observed, altered, "initial", -1))

    def test_zero_queue_still_requires_current_disarmed_owner_and_phase(self):
        observed, proof = self.source_boundary()
        observed["source"]["pending_commands"] = 0
        proof["command_count"] = 0
        proof["commands"] = []
        for side in ("before", "after"):
            proof[side]["source"]["pending_commands"] = 0
        self.assertTrue(diagnostic.actor_free(observed, proof, "initial", -1))
        self.assertFalse(diagnostic.actor_free(observed, {}, "initial", -1))
        for field, value in (("phase", "after_action"), ("index", 0), ("owner_generation", 2)):
            altered = deepcopy(proof)
            altered[field] = value
            self.assertFalse(diagnostic.actor_free(observed, altered, "initial", -1))
        altered = deepcopy(proof)
        altered["current_source_receipt"]["armed"] = True
        altered["current_source_receipt"]["material"] = 2
        self.assertFalse(diagnostic.actor_free(observed, altered, "initial", -1))
        # Real running zero-queue observations may advance clocks; source
        # generation and actual disarmed owner proof are still required.
        observed["paused"] = observed["native"]["paused"] = False
        for offset, side in enumerate(("before", "after"), 1):
            proof[side]["paused"] = proof[side]["native"]["paused"] = False
            proof[side]["native"]["tick"] += offset
            proof[side]["native"]["revision"] += offset
        self.assertTrue(diagnostic.actor_free(observed, proof, "initial", -1))


if __name__ == "__main__":
    unittest.main()
