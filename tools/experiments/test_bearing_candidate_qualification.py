"""Qualification prerequisites must block otherwise attractive efficacy."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from bearing_candidate_qualification import conserved_counts, custody, paired, latency, metric_bodies, physical_gaps_complete


def seal_fixture(root):
    """Synthetic custody fixture; it is not a physical experiment receipt."""
    def write(name, value):
        (root/name).write_text(json.dumps(value), encoding="utf-8")
    def sha(name):
        return hashlib.sha256((root/name).read_bytes()).hexdigest()
    write("capsules-000.json", {"capsules": [{"synthetic_unit_only": True}]})
    part_sha = sha("capsules-000.json")
    write("replay-000.json", {"ok": True, "mutation_failures": 0, "matched": 1,
                            "input_sha256": part_sha, "source_revision": "unit", "candidate": "B0"})
    write("population-manifest.json", {"attempts": 1, "parts": [
        {"path": "capsules-000.json", "sha256": part_sha, "capsules": 1}]})
    write("acquisition.json", {"complete": True, "native_counters": {
        "dropped": 0, "relocation_refused": 0, "attempts": 1},
        "fixture": {"name": "water", "bank_material": 3}})
    write("trajectory.json", {"frames": [{"tick": i, "stored_counts": [64, 5, 0, 10],
          "stored_water_mass": 12, "pre_water_mass": 12, "post_water_mass": 12} for i in range(600)]})
    receipt = {"ok": True, "attempts": 1, "replay_matches": 1, "source": "unit", "candidate": "B0",
               "artifact_sha256": {p.name: sha(p.name) for p in root.iterdir()}}
    write("receipt.json", receipt)
    return write, sha, receipt


class QualificationTests(unittest.TestCase):
    def test_water_carrier_growth_is_not_matter_growth(self):
        self.assertTrue(conserved_counts([64, 5, 0, 10, 0], [62, 5, 0, 12, 0], 3))

    def test_water_cannot_hide_wall_loss(self):
        self.assertFalse(conserved_counts([64, 5, 0, 10, 0], [63, 4, 0, 12, 0], 3))

    def test_water_cannot_create_another_material(self):
        self.assertFalse(conserved_counts([64, 5, 0, 10, 0], [61, 5, 1, 12, 0], 3))

    def test_nonwater_retains_exact_carriers(self):
        self.assertFalse(conserved_counts([64, 5, 10, 0], [63, 5, 11, 0]))
        self.assertTrue(conserved_counts([64, 5, 10, 0], [64, 5, 10, 0]))

    def test_missing_off_run_blocks_interpretation(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError, "on/off pair missing"):
                paired(root, "Y1", "speed30")

    def test_different_count_schema_is_refused(self):
        self.assertFalse(conserved_counts([1, 2, 3], [1, 2], 3))

    def test_no_bearing_latency_is_explicit(self):
        self.assertEqual(latency([]), {"count": 0, "p50": None, "p95": None, "max": None})

    def test_sealed_fixture_is_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seal_fixture(root)
            self.assertTrue(custody(root)[0]["ok"])

    def test_tampered_capsule_cannot_reuse_old_replay(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write, _, _ = seal_fixture(root)
            write("capsules-000.json", {"capsules": [{"changed": True}]})
            with self.assertRaisesRegex(ValueError, "artifact changed"):
                custody(root)

    def test_resealed_mutation_failure_still_blocks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write, sha, receipt = seal_fixture(root)
            replay = json.loads((root/"replay-000.json").read_text())
            replay["mutation_failures"] = 1
            write("replay-000.json", replay)
            receipt["artifact_sha256"]["replay-000.json"] = sha("replay-000.json")
            write("receipt.json", receipt)
            with self.assertRaisesRegex(ValueError, "unqualified replay"):
                custody(root)

    def test_missing_part_seal_blocks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write, _, receipt = seal_fixture(root)
            del receipt["artifact_sha256"]["capsules-000.json"]
            write("receipt.json", receipt)
            with self.assertRaisesRegex(ValueError, "unsealed required"):
                custody(root)

    def test_metric_guard_detects_threshold_change(self):
        self.assertNotEqual(metric_bodies("def gate(v): return v >= .25\n"),
                            metric_bodies("def gate(v): return v >= .24\n"))
        self.assertEqual(metric_bodies("def gate(v): return v >= .25\n"),
                         metric_bodies("# added evidence link\ndef gate(v):\n    return v >= .25\n"))

    def test_unknown_predicted_gap_blocks_even_mixed_support(self):
        frame = {"candidate_metrics": {"current_support": 1, "predicted_only": 1},
                 "bearing": {"admissions": [{"selected": 1, "steps": [[0, 0, 0], [0, 1, .5]], "geometric_lower": None}]}}
        with self.assertRaisesRegex(ValueError, "unknown physical gap"):
            physical_gaps_complete(frame)
        frame["bearing"]["admissions"][0]["geometric_lower"] = .4
        physical_gaps_complete(frame)


if __name__ == "__main__":
    unittest.main()
