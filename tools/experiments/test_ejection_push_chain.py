"""Adversarial gates for the copied-state conservative push-chain oracle."""
import copy
import json
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ejection_push_chain as oracle
from ejection_topology import Grid, canonical_hash


class EjectionPushChainTests(unittest.TestCase):
    def setUp(self):
        self.cases = oracle.synthetic_cases()

    def test_sand_direct_and_two_parcels(self):
        self.assertEqual(oracle.solve(self.cases["direct_sand"], "forward", 1)["minimum_chain_length"], 1)
        self.assertFalse(oracle.solve(self.cases["two_sand"], "forward", 1)["legal"])
        self.assertEqual(oracle.solve(self.cases["two_sand"], "forward", 2)["minimum_chain_length"], 2)

    def test_water_quantity_complete_state_temperature_and_spare_bits(self):
        capsule = self.cases["water"]
        result = oracle.solve(capsule, "forward", 1)
        after, checks = oracle.apply_chain(capsule, result["path"], "forward", 1)
        self.assertEqual(Grid(after).row((4, 5)), tuple(capsule["cells"][5 * 11 + 3][:4] + [0] + capsule["cells"][5 * 11 + 3][5:]))
        self.assertEqual(Grid(after).row((4, 5))[7], 73)
        self.assertEqual(Grid(after).row((4, 5))[3], 777)
        self.assertEqual(Grid(after).row((3, 5))[3], 200)
        self.assertTrue(checks["parcel_conservation"])
        self.assertTrue(checks["quantity_conservation"])

    def test_mixed_chain_is_tail_first_and_conservative(self):
        capsule = self.cases["mixed"]
        before = canonical_hash(capsule)
        result = oracle.solve(capsule, "forward", 4)
        self.assertEqual(result["minimum_chain_length"], 3)
        self.assertEqual(result["material_sequence"], [2, 3, 16])
        self.assertEqual(canonical_hash(capsule), before)
        self.assertTrue(all(result["checks"][key] for key in ("parcel_conservation", "quantity_conservation", "body_masks_unchanged", "source_overlap_removed")))

    def test_hard_foreign_own_and_immovable_barriers(self):
        for name in ("hard_barrier", "foreign_body", "own_body", "immovable"):
            for policy in oracle.POLICIES:
                with self.subTest(name=name, policy=policy):
                    self.assertFalse(oracle.solve(self.cases[name], policy, 4)["legal"])
                    with self.assertRaises(ValueError):
                        oracle.apply_chain(self.cases[name], [(3, 5), (4, 5), (5, 5)], policy, 2)

    def test_no_terminal_and_chain_beyond_hard_cap(self):
        self.assertFalse(oracle.solve(self.cases["jammed"], "forward_lateral", 4)["legal"])
        result = oracle.solve(self.cases["cap_overflow"], "forward", 4)
        self.assertFalse(result["legal"])
        self.assertGreater(result["encountered_refusals"].get("chain_cap_frontier", 0), 0)
        with self.assertRaises(ValueError):
            oracle.solve(self.cases["cap_overflow"], "forward", 5)

    def test_each_of_four_caps_has_its_own_result(self):
        capsule = self.cases["four_parcels"]
        self.assertEqual([oracle.solve(capsule, "forward", cap)["legal"] for cap in oracle.CAPS], [False, False, False, True])
        self.assertEqual(oracle.solve(capsule, "forward", 4)["minimum_chain_length"], 4)

    def test_rear_only_is_refused_by_both_policies(self):
        for policy in oracle.POLICIES:
            self.assertFalse(oracle.solve(self.cases["rear_only"], policy, 4)["legal"])

    def test_masked_empty_terminal_is_refused(self):
        capsule = self.cases["direct_sand"]
        capsule["cells"][5 * 11 + 4][4] = 1
        self.assertFalse(oracle.solve(capsule, "forward_lateral", 4)["legal"])
        with self.assertRaises(ValueError):
            oracle.apply_chain(capsule, [(3, 5), (4, 5)], "forward_lateral", 1)

    def test_outer_ring_cannot_supply_a_terminal(self):
        original = self.cases["direct_sand"]
        capsule = copy.deepcopy(original)
        capsule["bounds"] = [2, 4, 3, 3]
        capsule["cells"] = [list(Grid(original).row((x, y))) for y in range(4, 7) for x in range(2, 5)]
        self.assertFalse(oracle.solve(capsule, "forward_lateral", 4)["legal"])
        with self.assertRaises(ValueError):
            oracle.apply_chain(capsule, [(3, 5), (4, 5)], "forward_lateral", 1)

    def test_exact_lateral_permission_and_no_epsilon(self):
        capsule = self.cases["lateral"]
        self.assertFalse(oracle.solve(capsule, "forward", 4)["legal"])
        result = oracle.solve(capsule, "forward_lateral", 1)
        self.assertTrue(result["legal"])
        self.assertEqual(result["zero_dot_hops"], 1)
        self.assertFalse(oracle.hop_allowed((1., 1e-30), (0, -1), "forward_lateral"))
        self.assertTrue(oracle.hop_allowed((1., 1e-30), (0, 1), "forward"))

    def test_overlapping_paths_are_independent_and_deterministic(self):
        capsule = self.cases["overlapping_paths"]
        before = copy.deepcopy(capsule)
        first = oracle.solve(capsule, "forward_lateral", 3)
        second = oracle.solve(capsule, "forward_lateral", 3)
        self.assertGreaterEqual(first["chain_count"], 2)
        self.assertTrue(first["multiple_valid_chains"])
        self.assertEqual(first, second)
        self.assertEqual(capsule, before)
        chains, _ = oracle.enumerate_chains(capsule, "forward_lateral", 3)
        self.assertGreaterEqual(len(chains), 2)
        for path in chains:
            _, checks = oracle.apply_chain(capsule, path, "forward_lateral", 3)
            self.assertEqual(checks["new_body_overlaps"], 0)
            self.assertEqual(checks["barrier_violations"], 0)

    def test_invalid_path_and_sidecar_policy_are_refused(self):
        capsule = self.cases["direct_sand"]
        for path in ([(3, 5), (5, 5)], [(3, 5), (4, 5), (3, 5)], [(3, 5), (4, 5), (5, 5)]):
            with self.assertRaises(ValueError):
                oracle.apply_chain(capsule, path, "forward", 3)
        capsule = copy.deepcopy(capsule)
        capsule["storage_policy"] = "pressure_flow_v1"
        with self.assertRaises(ValueError):
            oracle.solve(capsule, "forward", 1)

    def test_all_synthetic_legal_chains_preserve_parcels(self):
        checked = 0
        for capsule in self.cases.values():
            before = canonical_hash(capsule)
            for policy in oracle.POLICIES:
                for cap in oracle.CAPS:
                    chains, _ = oracle.enumerate_chains(capsule, policy, cap)
                    for path in chains:
                        _, checks = oracle.apply_chain(capsule, path, policy, cap)
                        self.assertTrue(checks["parcel_conservation"])
                        self.assertTrue(checks["source_overlap_removed"])
                        checked += 1
            self.assertEqual(canonical_hash(capsule), before)
        self.assertGreater(checked, 30)

    def test_frozen_real_corpus_and_native_case_export(self):
        root = Path(__file__).resolve().parents[2]
        corpus = json.loads((root / "docs/audits/physical-detachment-2026-10-31/stage-a-corpus.json").read_text())
        before = canonical_hash(corpus)
        result = oracle.analyze_corpus(corpus)
        self.assertEqual(result["baseline_direct"], {"recovered": 16, "total": 80, "fraction": .2, "unresolved": 64})
        self.assertTrue(result["input_nonmutation"])
        self.assertEqual(result["invariants"]["conservation_failures"], 0)
        self.assertEqual(result["invariants"]["barrier_violations"], 0)
        self.assertEqual(result["invariants"]["new_body_overlaps"], 0)
        self.assertEqual(canonical_hash(corpus), before)
        for policy in oracle.POLICIES:
            recovered = [result["policies"][policy][str(cap)]["unresolved_recovered"] for cap in oracle.CAPS]
            self.assertEqual(recovered, sorted(recovered))
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "native-cases.txt"
            count = oracle.export_native_cases(corpus, output)
            self.assertGreater(count, 0)
            self.assertEqual(output.read_text().splitlines()[0], f"EJECTION_CHAINS_V1 {count}")

    def test_cli_rejects_aliases_and_preserves_input_file(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source, output, native = base / "corpus.json", base / "result.json", base / "cases.txt"
            original = json.dumps({"capsules": [self.cases["direct_sand"]]}).encode()
            source.write_bytes(original)
            command = [sys.executable, str(Path(oracle.__file__)), "--input", str(source)]
            for arguments in (["--output", str(source)],
                              ["--output", str(output), "--native-cases", str(source)],
                              ["--output", str(output), "--native-cases", str(output)]):
                process = subprocess.run(command + arguments, capture_output=True, text=True, timeout=10)
                self.assertNotEqual(process.returncode, 0)
                self.assertIn("must be distinct", process.stderr)
                self.assertEqual(source.read_bytes(), original)
                self.assertFalse(output.exists())
            process = subprocess.run(command + ["--output", str(output), "--native-cases", str(native)],
                                     capture_output=True, text=True, timeout=10)
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertEqual(source.read_bytes(), original)
            self.assertTrue(json.loads(output.read_text())["input_file_nonmutation"])
            self.assertTrue(native.read_text().startswith("EJECTION_CHAINS_V1 "))


if __name__ == "__main__":
    unittest.main()
