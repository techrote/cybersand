import copy
import json
from pathlib import Path
import tempfile
import unittest

from stress_physical_actors import SUSPECTS
from summarize_rapier_pair import compare


class PairTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.lock = {"base_join_source_sha256": "original", "patched_join_source_sha256": "patched", "upstream_cargo_lock_sha256": "upstream"}
        for variant in ("control", "patched"):
            for host in ("windows", "linux"):
                for batch in range(5):
                    filename = "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if host == "windows" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
                    build = {"variant": variant, "platform": host, "source_sha": "source", "build_inputs": self.lock,
                             "join_source_sha256": "original" if variant == "control" else "patched",
                             "join_regression_exit": 124 if variant == "control" else 0,
                             "artifacts": {filename: host + variant}, "godot_version": "4.7", "rustc": "exact",
                             "upstream_cargo_lock_sha256": "upstream", "resolved_cargo_lock_sha256": "resolved", "build_lock_sha256": "build-lock"}
                    report = {"identity": {"source_sha": "source", "native_sha256": host + "native", "rapier_sha256": host + variant,
                                           "godot_version": "4.7", "rapier_build": build, "host": host, "batch": batch, "variant": variant, "run_id": "1234", "attempt": "1",
                                           "paired_protocol": "same-host-alternating-v1", "pair_batch": batch,
                                           "pair_host_id": f"host-{host}-{batch}", "hardware": {"physical_cores": 2},
                                           "fixture_inputs": {"fixture": "same"}},
                              "completed": True, "input_verification_complete": True, "input_drift": [], "preflight_passed": True, "iterations_requested": 10,
                              "results": [{"iteration": i, "name": name, "status": "passed"} for i in range(10) for name in SUSPECTS]}
                    if variant == "control" and host == "windows" and batch == 0:
                        report["results"][0].update(status="timeout", last_progress={"phase": "step"})
                    for result in report["results"]:
                        first = "control" if (result["iteration"] + batch) % 2 == 0 else "patched"
                        result["pair_position"] = int(variant != first)
                    path = self.root / variant / f"{host}-{batch}" / "stress.json"
                    path.parent.mkdir(parents=True)
                    path.write_text(json.dumps(report))

    def mutate(self, variant, function):
        path = self.root / variant / "windows-0/stress.json"
        report = json.loads(path.read_text())
        function(report)
        path.write_text(json.dumps(report))

    def test_complete_pair_with_reproduced_control_qualifies(self):
        self.assertTrue(compare(self.root, self.lock)["qualified"])

    def test_paired_explicit_host_batch_and_variant_are_required(self):
        path = self.root / "patched/windows-0/stress.json"
        original = path.read_text()
        for field in ("host", "batch", "variant"):
            with self.subTest(field=field):
                report = json.loads(original)
                report["identity"].pop(field)
                path.write_text(json.dumps(report))
                self.assertFalse(compare(self.root, self.lock)["qualified"])
        path.write_text(original)
        self.mutate("patched", lambda r: r["identity"].update(variant="control"))
        self.assertFalse(compare(self.root, self.lock)["qualified"])

    def test_paired_copied_zero_renamed_four_rejects_even_complete_counts(self):
        zero = self.root / "patched/windows-0/stress.json"
        four = self.root / "patched/windows-4/stress.json"
        four.write_bytes(zero.read_bytes())
        result = compare(self.root, self.lock)
        self.assertFalse(result["qualified"])
        self.assertTrue(any("differs from artifact path" in error for error in result["errors"]))

    def test_omitting_all_pair_protocol_fields_cannot_qualify(self):
        for path in self.root.glob("*/*/stress.json"):
            report = json.loads(path.read_text())
            report["identity"].pop("paired_protocol")
            path.write_text(json.dumps(report))
        result = compare(self.root, self.lock)
        self.assertFalse(result["qualified"])
        self.assertTrue(any("pairing protocol" in error for error in result["errors"]))

    def test_one_missing_protocol_or_mislabeled_batch_cannot_qualify(self):
        self.mutate("patched", lambda r: r["identity"].pop("paired_protocol"))
        self.assertFalse(compare(self.root, self.lock)["qualified"])
        self.mutate("patched", lambda r: r["identity"].update(paired_protocol="same-host-alternating-v1", pair_batch=1))
        result = compare(self.root, self.lock)
        self.assertFalse(result["qualified"])
        self.assertTrue(any("batch identity" in error for error in result["errors"]))

    def test_final_input_receipt_is_required_even_with_all_trials(self):
        self.mutate("patched", lambda r: r.pop("input_verification_complete"))
        result = compare(self.root, self.lock)
        self.assertFalse(result["qualified"])
        self.assertTrue(any("final input verification" in error for error in result["errors"]))

    def test_failed_preflight_or_mixed_campaign_cannot_qualify(self):
        for field, value in (("run_id", "9999"), ("attempt", "2")):
            with self.subTest(field=field):
                path = self.root / "patched/windows-0/stress.json"
                original = path.read_text()
                self.mutate("patched", lambda r: r["identity"].update({field: value}))
                self.assertFalse(compare(self.root, self.lock)["qualified"])
                path.write_text(original)
        self.mutate("patched", lambda r: r.update(preflight_passed=False))
        result = compare(self.root, self.lock)
        self.assertFalse(result["qualified"])
        self.assertTrue(any("preflight receipt" in error for error in result["errors"]))

    def test_no_control_reproduction_does_not_prove_repair(self):
        self.mutate("control", lambda r: r["results"][0].update(status="passed"))
        self.assertFalse(compare(self.root, self.lock)["qualified"])

    def test_missing_trials_or_candidate_timeout_fail(self):
        for status in ("timeout", "failed"):
            with self.subTest(status=status):
                self.mutate("patched", lambda r: r["results"][0].update(status=status))
                self.assertFalse(compare(self.root, self.lock)["qualified"])
        (self.root / "patched/linux-4/stress.json").unlink()
        self.assertFalse(compare(self.root, self.lock)["qualified"])

    def test_non_timeout_control_failure_is_not_expected_reproduction(self):
        self.mutate("control", lambda r: r["results"][0].update(status="failed"))
        self.assertFalse(compare(self.root, self.lock)["qualified"])

    def test_mixed_build_or_source_is_rejected(self):
        for field in ("source_sha", "resolved_cargo_lock_sha256", "rustc", "join_source_sha256"):
            with self.subTest(field=field):
                path = self.root / "patched/windows-0/stress.json"
                original = path.read_text()
                self.mutate("patched", lambda r: r["identity"]["rapier_build"].update({field: "drift"}))
                self.assertFalse(compare(self.root, self.lock)["qualified"])
                path.write_text(original)

    def test_same_host_protocol_requires_matching_hardware_fixtures_and_alternation(self):
        for variant in ("control", "patched"):
            for host in ("windows", "linux"):
                for batch in range(5):
                    path = self.root / variant / f"{host}-{batch}/stress.json"
                    report = json.loads(path.read_text())
                    report["identity"].update(paired_protocol="same-host-alternating-v1", pair_batch=batch,
                                              pair_host_id=f"host-{host}-{batch}", hardware={"physical_cores": 2},
                                              fixture_inputs={"fixture": "same"})
                    for result in report["results"]:
                        first = "control" if (result["iteration"] + batch) % 2 == 0 else "patched"
                        result["pair_position"] = int(variant != first)
                    path.write_text(json.dumps(report))
        self.assertTrue(compare(self.root, self.lock)["qualified"])
        self.mutate("patched", lambda r: r["identity"].update(pair_host_id="different-host"))
        self.assertFalse(compare(self.root, self.lock)["qualified"])


if __name__ == "__main__":
    unittest.main()
