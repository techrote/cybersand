"""Strict source-bound round trips for actual candidate World recipes."""
import copy
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import compiler
import lab
import world_case
import world_candidate


class WorldCaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cybersand-world-case-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.path = self.directory / "case.json"
        self.candidate = lab.create_candidate(2)
        self.candidate["descriptor"]["density"] = 500
        self.scenario = {"first": 2, "second": 3, "seed": 2, "ticks": 120, "workers": 4}

    def saved(self):
        world_case.export_case(self.candidate, self.scenario, self.path)
        return json.loads(self.path.read_text())

    def rewrite(self, document):
        document["digest"] = lab.digest({k: v for k, v in document.items() if k != "digest"})
        self.path.write_bytes(lab.canonical(document))

    def test_exact_roundtrip_has_no_tested_receipt_or_runtime_claim(self):
        first = world_case.export_case(self.candidate, self.scenario, self.path)
        other = self.directory / "second.json"
        second = lab.request({"op": "export_world_case", "candidate": self.candidate,
                              "scenario": self.scenario, "path": str(other)})
        self.assertEqual(self.path.read_bytes(), other.read_bytes())
        restored = lab.request({"op": "import_world_case", "path": str(self.path)})
        self.assertEqual(restored["candidate"], first["candidate"])
        self.assertEqual(restored["scenario"], self.scenario)
        self.assertEqual(restored["case_digest"], second["case_digest"])
        self.assertEqual(restored["state"], "validated_candidate")
        self.assertFalse(restored["runtime_active"])
        self.assertNotIn("receipt", restored)

    def test_recipe_is_part_of_digest(self):
        first = world_case.export_case(self.candidate, self.scenario, self.path)
        self.scenario["seed"] = 3
        second = world_case.export_case(self.candidate, self.scenario, self.path)
        self.assertNotEqual(first["case_digest"], second["case_digest"])
        self.assertEqual(first["digest"], second["digest"])
        self.assertEqual(world_case.import_case(self.path)["scenario"]["seed"], 3)

    def test_tampered_recipe_or_material_is_not_requalified(self):
        document = self.saved()
        document["scenario"]["ticks"] = 121
        self.path.write_bytes(lab.canonical(document))
        with self.assertRaisesRegex(lab.LabError, "/case/digest"):
            world_case.import_case(self.path)
        document = self.saved()
        document["candidate"]["descriptor"]["density"] = 501
        self.rewrite(document)
        with self.assertRaisesRegex(lab.LabError, "/case/candidate_digest"):
            world_case.import_case(self.path)

    def test_rehashed_unsafe_material_and_recipe_are_rejected(self):
        original = self.saved()
        for key, value in (("first", 10), ("second", 132), ("ticks", 601),
                           ("seed", True), ("workers", 2), ("ticks", 1.0)):
            with self.subTest(field=key, value=value):
                document = copy.deepcopy(original)
                document["scenario"][key] = value
                self.rewrite(document)
                with self.assertRaisesRegex(lab.LabError, "/scenario"):
                    world_case.import_case(self.path)
        document = copy.deepcopy(original)
        document["candidate"]["descriptor"]["kernel"] = 0
        document["candidate_digest"] = lab.digest(document["candidate"])
        self.rewrite(document)
        with self.assertRaisesRegex(lab.LabError, "/descriptor/kernel"):
            world_case.import_case(self.path)

    def test_source_drift_cannot_replay_old_case(self):
        self.saved()
        altered = copy.deepcopy(world_case._identity())
        altered["lf_sha256"]["native/src/world.cpp"] = "0" * 64
        altered["digest"] = lab.digest(altered["lf_sha256"])
        original_bytes = self.path.read_bytes()
        with mock.patch.object(world_case, "_identity", return_value=altered):
            with self.assertRaisesRegex(lab.LabError, "different executable inputs.*native/src/world.cpp"):
                world_case.import_case(self.path)
        self.assertEqual(self.path.read_bytes(), original_bytes)

    def test_saved_recipe_cannot_select_implicit_compile_defaults(self):
        self.scenario = {"first": 2, "second": 23, "seed": 99, "ticks": 321, "workers": 4}
        original = self.saved()
        incomplete = copy.deepcopy(self.scenario)
        del incomplete["ticks"]
        for scenario in (None, [], {}, incomplete):
            with self.subTest(scenario=scenario):
                document = copy.deepcopy(original)
                document["scenario"] = scenario
                self.rewrite(document)
                bytes_before = self.path.read_bytes()
                with self.assertRaisesRegex(lab.LabError, "/scenario"):
                    world_case.import_case(self.path)
                self.assertEqual(self.path.read_bytes(), bytes_before)
                with self.assertRaisesRegex(lab.LabError, "/scenario"):
                    world_case.export_case(self.candidate, scenario, self.path)
                self.assertEqual(self.path.read_bytes(), bytes_before)
        document = copy.deepcopy(original)
        del document["scenario"]
        self.rewrite(document)
        with self.assertRaisesRegex(lab.LabError, "/case"):
            world_case.import_case(self.path)

    def test_source_hash_map_and_envelope_are_strict(self):
        original = self.saved()
        for update, pointer in (({"schema_version": True}, "/case/schema_version"),
                                ({"runtime_active": True}, "/case")):
            document = copy.deepcopy(original)
            document.update(update)
            self.rewrite(document)
            with self.assertRaisesRegex(lab.LabError, pointer):
                world_case.import_case(self.path)
        document = copy.deepcopy(original)
        document["source_identity"]["lf_sha256"]["native/src/world.cpp"] = "0" * 64
        self.rewrite(document)
        with self.assertRaisesRegex(lab.LabError, "/case/source_identity/digest"):
            world_case.import_case(self.path)
        self.path.write_text('{"schema_version":1,"schema_version":1}')
        with self.assertRaises(compiler.CatalogueError):
            world_case.import_case(self.path)

    def test_source_change_during_export_keeps_previous_case(self):
        self.saved()
        old_bytes = self.path.read_bytes()
        before = world_case._identity()
        after = copy.deepcopy(before)
        after["digest"] = "0" * 64
        with mock.patch.object(world_case, "_identity", side_effect=[before, after]):
            with self.assertRaisesRegex(lab.LabError, "source changed during"):
                world_case.export_case(self.candidate, self.scenario, self.path)
        self.assertEqual(self.path.read_bytes(), old_bytes)

    def test_git_metadata_change_does_not_invalidate_source(self):
        self.saved()
        source, raw = world_candidate._source_snapshot()
        source["git_head"] = "1" * 40
        with mock.patch.object(world_candidate, "_source_snapshot", return_value=(source, raw)):
            self.assertTrue(world_case.import_case(self.path)["ok"])

    def test_protocol_cannot_overwrite_case_with_response_or_request(self):
        self.saved()
        old_bytes = self.path.read_bytes()
        request_path = self.directory / "request.json"
        request_path.write_bytes(lab.canonical({"op": "import_world_case", "path": str(self.path)}))
        with redirect_stdout(io.StringIO()):
            self.assertEqual(lab.main(["--request", str(request_path), "--response", str(self.path)]), 2)
        self.assertEqual(self.path.read_bytes(), old_bytes)
        request_path.write_bytes(lab.canonical({"op": "export_world_case", "candidate": self.candidate,
                                                "scenario": self.scenario, "path": str(request_path)}))
        request_bytes = request_path.read_bytes()
        with redirect_stdout(io.StringIO()):
            self.assertEqual(lab.main(["--request", str(request_path)]), 1)
        self.assertEqual(request_path.read_bytes(), request_bytes)


if __name__ == "__main__":
    unittest.main()
