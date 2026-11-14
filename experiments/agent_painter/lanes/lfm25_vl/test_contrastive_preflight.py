"""Model-free adversarial LFM contrast research fixtures; no native or model calls."""
import copy
import json
from pathlib import Path
import unittest

import contrastive_preflight as subject


class ContrastPreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = json.loads(subject.FILE.read_text(encoding="utf-8"))
        cls.items = {item["family"]: item for item in cls.document["proposals"]}

    def test_fixed_model_and_native_claims(self):
        self.assertEqual(subject.MANIFEST, self.document["original_manifest_sha256"])
        self.assertEqual(subject.SOURCE, self.document["original_native_source"])
        self.assertEqual(self.document["status"], "PROPOSED_NOT_TRAIN_NOT_NATIVE_ADMITTED")
        self.assertEqual(self.document["host_seeds"], [104729, 130363])

    def test_all_three_full_compiler_only_seed_witnesses(self):
        for family, item in self.items.items():
            with self.subTest(family=family):
                proof = subject.preflight(item)
                self.assertEqual(len(proof), 2)
                self.assertTrue(all(v["native_qualified"] is False for v in proof))
                self.assertTrue(all(v["compiler_structure_pass"] for v in proof))

    def test_architecture_room_field_leak_is_refused(self):
        bad = copy.deepcopy(self.items["greebles"])
        bad["program"]["components"][0]["openings"] = []
        with self.assertRaises(Exception):
            subject.preflight(bad)

    def test_bad_pipework_requirements_refused_not_repaired(self):
        bad = copy.deepcopy(self.items["pipework"])
        bad["program"]["requirements"] = {"closed": True, "region": [0, 0, 96, 96]}
        with self.assertRaises(Exception):
            subject.preflight(bad)

    def test_invalid_five_endpoint_witness_refused(self):
        bad = copy.deepcopy(self.items["pipework"])
        bad["program"]["components"][0]["edges"].pop()
        with self.assertRaises(Exception):
            subject.preflight(bad)

    def test_semantic_diameter_drift_refused(self):
        bad = copy.deepcopy(self.items["pipework"])
        bad["program"]["components"][0]["diameter"] = 5
        with self.assertRaisesRegex(ValueError, "five-terminal"):
            subject.preflight(bad)

    def test_architecture_missing_route_refused(self):
        bad = copy.deepcopy(self.items["architecture"])
        bad["program"]["requirements"]["route"] = []
        with self.assertRaisesRegex(ValueError, "architecture hall"):
            subject.preflight(bad)

    def test_greeble_no_chase_refused(self):
        bad = copy.deepcopy(self.items["greebles"])
        bad["program"]["components"][0]["box"][0] = 40
        with self.assertRaises(ValueError):
            subject.preflight(bad)

    def test_structural_signature_ignores_only_style_for_pipe(self):
        p = self.items["pipework"]["program"]
        q = copy.deepcopy(p)
        q["components"][0]["diameter"] = 5
        self.assertEqual(subject.signature(p), subject.signature(q))

    def test_no_final_file_in_visible_split_function(self):
        import inspect
        src = inspect.getsource(subject.original_visible_splits)
        self.assertIn('for split in ("TRAIN", "DEVELOPMENT"):', src)
        self.assertNotIn('m["split_files"]["FINAL"]', src)


if __name__ == "__main__":
    unittest.main()
