"""Adversarial reader checks; fixtures below are explicitly synthetic CPU data."""
import copy
import json
from pathlib import Path
import unittest

from native_mask_applicability import COHORTS, CPU_SCOPE, ORDER, reduce_receipts, sha256


def fixture():
    original = json.loads((Path(__file__).resolve().parents[2] / "docs/audits/2026-11-24-pubpres-playability-final/native-empty-derived-abba-receipts.json").read_bytes())
    builds = copy.deepcopy(original["manifest"]["builds"])
    builds["C"] = copy.deepcopy(builds["B"])
    builds["C"]["source_commit"] = "c" * 40
    builds["C"]["source_tree"] = "d" * 40
    for build in builds.values():
        build["binary_path"] = "synthetic-binary"
    manifest = {"schema": "pubpres-native-mask-applicability-screen-v1", "order": list(ORDER),
                "cohorts": [list(row) for row in COHORTS], "ticks": 72, "workers": 4,
                "builds": builds, "runs": [], "runner_source_sha256": sha256("synthetic fixture")}
    receipt = {"schema": "pubpres-native-mask-applicability-receipts-v1", "manifest": manifest,
               "raw_runs": {}, "runner_source": "synthetic fixture", "failures": []}
    total_cpu = 10.0
    for label, size, bodies, profile in COHORTS:
        for index, arm in enumerate(ORDER, 1):
            # Preserve original files untouched. Both A fixture rows use the
            # original first A process, which observed the required workers.
            old_name = f"{label}-{'1-A' if arm == 'A' else '2-B'}"
            raw = copy.deepcopy(original["raw_runs"][old_name])
            data = json.loads(raw["stdout"])
            elapsed = sum(data["tick_nanoseconds"])
            name = f"{label}-{index}-{arm}"
            before = {"user_seconds": total_cpu, "system_seconds": 1.0}
            total_cpu += 3.0
            row = {"name": name, "arm": arm, "exit_code": 0,
                   "argv": ["synthetic-binary", str(size), str(bodies), "4", "72", str(profile)],
                   "binary_sha256": builds[arm]["binary_sha256"], "pid": 1000 + len(manifest["runs"]),
                   "cpu_scope": CPU_SCOPE, "children_cpu_before": before,
                   "children_cpu_after": {"user_seconds": total_cpu, "system_seconds": 1.0},
                   "whole_process_wall_nanoseconds": elapsed + 2_000_000_000}
            manifest["runs"].append(row)
            receipt["raw_runs"][name] = raw
    return receipt


class ApplicabilityReaderTests(unittest.TestCase):
    def test_complete_fixed_registration(self):
        result = reduce_receipts(fixture())
        self.assertEqual(result["physical_acceptance"], "HOLD")
        self.assertEqual(len(result["cohorts"]), 3)
        self.assertTrue(all(len(row["measurements_in_order"]) == 6 for row in result["cohorts"]))

    def test_custody_and_cpu_tampering_refused(self):
        for mutate in (
            lambda r: r["manifest"]["runs"].pop(),
            lambda r: r["manifest"]["order"].__setitem__(0, "C"),
            lambda r: r["manifest"]["runs"][1].update(arm="C"),
            lambda r: r["manifest"]["runs"][0].update(exit_code=False),
            lambda r: r["manifest"]["runs"][0]["argv"].__setitem__(0, "other-binary"),
            lambda r: r["manifest"]["runs"][0].update(pid=True),
            lambda r: r["manifest"]["runs"][0].update(whole_process_wall_nanoseconds=1),
            lambda r: r["manifest"]["runs"][0].update(cpu_scope="tick-window"),
            lambda r: r["manifest"]["runs"][0]["children_cpu_after"].update(user_seconds=False),
            lambda r: r["manifest"]["runs"][0]["children_cpu_after"].update(user_seconds=0.0),
            lambda r: r["manifest"]["runs"][0]["children_cpu_after"].update(user_seconds=float("nan")),
            lambda r: r["manifest"]["runs"][1]["children_cpu_before"].update(user_seconds=14.0),
            lambda r: r["manifest"]["builds"]["C"].update(source_commit=r["manifest"]["builds"]["B"]["source_commit"]),
            lambda r: r["manifest"]["builds"]["C"]["source_inputs_sha256"].pop("native/bench/pubpres_empty_derived.cpp"),
            lambda r: r["manifest"]["builds"]["C"].update(benchmark_sha256="e" * 64),
            lambda r: r.update(failures=[{"reason": "retained failure"}]),
            lambda r: r.update(runner_source="changed"),
        ):
            data = fixture()
            mutate(data)
            with self.assertRaises((ValueError, AssertionError, RuntimeError)):
                reduce_receipts(data)

    def test_worker_refusal_preserved_even_with_valid_cpu(self):
        receipt = fixture()
        raw = receipt["raw_runs"]["current512-one-6-A"]
        data = json.loads(raw["stdout"])
        data["workers_observed"] = 3
        raw["stdout"] = json.dumps(data) + "\n"
        raw["stdout_sha256"] = sha256(raw["stdout"])
        with self.assertRaisesRegex((ValueError, AssertionError, RuntimeError), "participation"):
            reduce_receipts(receipt)


if __name__ == "__main__":
    unittest.main()
