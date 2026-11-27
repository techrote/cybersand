"""Artificial package-evidence guards; no Godot or Windows execution is claimed.

The underlying transcript reader is stubbed here to isolate the independent
package relationship/custody gate. Its native semantics have separate controls.
"""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import package_evaluator as package


class AuthoredLineagePackageControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="goblin-synthetic-lineage-package-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.profile = "test-output/" + "a" * 32
        self.manifest = {"required_authored_lineage": deepcopy(package.LINEAGE_CONTRACT),
                         "files_sha256": {package.LINEAGE_SCRIPT: "6" * 64},
                         "provenance": {"source_commit": "1" * 40, "source_tree": "2" * 40,
                                        "source_dirty": False, "platform": "windows",
                                        "godot_sha256": "3" * 64, "native_sha256": "4" * 64, "rapier_sha256": "5" * 64}}
        self.raw = {"schema": package.LINEAGE_SCHEMA, "status": "pass", "failures": [],
                    "provenance": deepcopy(self.manifest["provenance"]), "checks": {"synthetic_transport_control": True},
                    "actual_actions": {"attempted": 20, "completed": 20}, "native_cases": []}
        for identity, (actions, equality) in package.LINEAGE_CASES.items():
            rows = []
            for index, action in enumerate(actions):
                native = {"generation": 10, "revision": index, "tick": 16 if action["id"] in ("play", "pause") else 0,
                          "paused": True, "failed": False}
                observation = {"adapter_version": 3, "native": native}
                rows.append({"index": index, "action": deepcopy(action), "before": deepcopy(observation),
                             "after": deepcopy(observation), "status": "completed", "admission": {"accepted": True},
                             "classification": "game_observation", "assertions": []})
            saved, reopened = rows[-2:]
            first, last = ("f" * 64 if equality else "e" * 64), "f" * 64
            lineage = {"schema": "cybersand-goblin-material-lineage-v1", "state": "authored_compatible" if equality else "simulation_exposed",
                       "source": {key: saved["after"]["native"][key] for key in ("generation", "revision", "tick")}}
            reason = "available" if equality else "simulation_exposed_lineage"
            saved["persistence_capture"] = self.capture(saved["after"], first)
            reopened["persistence_capture"] = self.capture(reopened["after"], last)
            saved["persistence"] = {"saved_material_lineage": deepcopy(lineage), "material_sha256": first,
                                    "saved_native_tick": 0, "native_material_equality_applicable": equality,
                                    "native_material_equality_reason": reason}
            reopened["persistence"] = {"saved_material_lineage": deepcopy(lineage),
                                       "saved_capture": deepcopy(saved["persistence_capture"]),
                                       "saved_material_sha256": first, "reopened_material_sha256": last,
                                       "saved_native_tick": 0, "native_material_equality_applicable": equality,
                                       "native_material_equality_reason": reason}
            reopened["assertions"] = [{"id": "authored_reopen_materials", "status": "pass" if equality else "not_applicable"}]
            tape = {"header": {"fixture_id": "conservation_cell", "policy": "CONTROL", "seed": 13,
                                "budget": len(actions), "pacing_ms": 0, "evidence_kind": "packaged_evaluator",
                                "provenance": deepcopy(self.manifest["provenance"])}, "steps": rows,
                    "summary": {"termination": "budget_complete", "attempted_actions": len(actions),
                                "completed_actions": len(actions), "failures": []}}
            self.raw["native_cases"].append({"id": identity, "status": "pass", "checks": {"synthetic_relationship": True},
                                             "transcript": tape, "save_index": len(actions) - 2, "reopen_index": len(actions) - 1,
                                             "expected_equality_applicable": equality})
        self.receipt = {"status": "pass", "script": package.LINEAGE_CONTRACT["script"], "script_sha256": "6" * 64,
                        "wall_limit_seconds": 300, "native_case_count": 4, "attempted_actions": 20, "completed_actions": 20,
                        "profile": self.profile, "checks": 1, "log": self.profile + "/authored-lineage.log",
                        "report": self.profile + "/appdata/Godot/app_userdata/Cyber Sand Reference Sandbox/goblin/authored-lineage-test.json"}
        self.sync()

    def capture(self, observation, checksum):
        source = deepcopy(observation["native"])
        return {"source_matches": True, "region": [0, 0, 512, 512], "count": 262144,
                "material_sha256": checksum, "source_before": source, "source_after": deepcopy(source),
                "admission": {"status": "queued", "operation_id": 7},
                "native_receipt": {**source, "status": "completed", "kind": "capture", "backend": "CyberNativeCellWorld",
                                   "operation_id": 7, "observed_generation": source["generation"], "region": [0, 0, 512, 512]}}

    def sync(self, marker=None):
        marker = marker or {"status": "pass", "failures": [], "actual_actions": self.raw["actual_actions"]}
        for key, content in (("report", json.dumps(self.raw)), ("log", package.LINEAGE_MARKER + json.dumps(marker) + "\n")):
            path = self.root / self.receipt[key]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content.encode())
            self.receipt[key + "_sha256"] = package.sha(path)

    def verify(self, reader=None):
        reader = reader or {"valid": True, "summary": {"failures": []}, "independent_failures": [], "unreported_failures": []}
        with patch.object(package, "verify_tape", return_value=reader):
            package.verify_authored_lineage(self.root, self.receipt, self.manifest)

    def test_four_distinct_cases_and_actual_relationships_are_required(self):
        self.verify()
        original = deepcopy(self.raw)
        for mutation in ("missing", "duplicate", "partial", "wrong_actions"):
            with self.subTest(mutation=mutation):
                self.raw = deepcopy(original)
                if mutation == "missing": self.raw["native_cases"].pop()
                elif mutation == "duplicate": self.raw["native_cases"][1] = deepcopy(self.raw["native_cases"][0])
                elif mutation == "partial": self.raw["native_cases"][1]["transcript"]["steps"][-1]["status"] = "partial"
                else: self.raw["native_cases"][1]["transcript"]["steps"][0]["action"]["args"]["ticks"] = 1
                self.sync()
                with self.assertRaises(ValueError): self.verify()

    def test_pass_label_cannot_replace_actual_source_or_independent_evidence(self):
        original = deepcopy(self.raw)
        for key in ("source_commit", "native_sha256"):
            with self.subTest(key=key):
                self.raw = deepcopy(original)
                self.raw["provenance"][key] = "0" * len(self.raw["provenance"][key])
                self.sync()
                with self.assertRaises(ValueError): self.verify()
        self.raw = original
        self.sync()
        self.receipt["script_sha256"] = "0" * 64
        with self.assertRaises(ValueError): self.verify()
        self.receipt["script_sha256"] = "6" * 64
        with self.assertRaises(ValueError):
            self.verify({"valid": True, "summary": {"failures": []}, "independent_failures": ["synthetic independent rejection"]})

    def test_suppressing_equality_without_real_retained_difference_is_rejected(self):
        case = self.raw["native_cases"][1]
        saved, reopened = case["transcript"]["steps"][-2:]
        checksum = reopened["persistence_capture"]["material_sha256"]
        saved["persistence_capture"]["material_sha256"] = checksum
        saved["persistence"]["material_sha256"] = checksum
        reopened["persistence"]["saved_material_sha256"] = checksum
        reopened["persistence"]["saved_capture"]["material_sha256"] = checksum
        self.sync()
        with self.assertRaisesRegex(ValueError, "relationship differs"):
            self.verify()

    def test_fresh_positive_equality_cannot_be_downgraded_to_not_applicable(self):
        case = self.raw["native_cases"][0]
        case["transcript"]["steps"][-1]["assertions"][0]["status"] = "not_applicable"
        self.sync()
        with self.assertRaisesRegex(ValueError, "positive equality"):
            self.verify()

    def test_stale_capture_or_rewritten_saved_lineage_is_rejected(self):
        original = deepcopy(self.raw)
        for mutation in ("stale", "lineage", "reason", "empty_checks"):
            with self.subTest(mutation=mutation):
                self.raw = deepcopy(original)
                case = self.raw["native_cases"][3]
                if mutation == "stale": case["transcript"]["steps"][-1]["persistence_capture"]["native_receipt"]["generation"] += 1
                elif mutation == "lineage": case["transcript"]["steps"][-1]["persistence"]["saved_material_lineage"]["state"] = "unknown"
                elif mutation == "reason": case["transcript"]["steps"][-1]["persistence"]["native_material_equality_reason"] = "unknown_material_lineage"
                else: case["checks"] = {}
                self.sync()
                with self.assertRaises(ValueError): self.verify()

    def test_tampered_report_or_success_marker_is_rejected(self):
        (self.root / self.receipt["report"]).write_bytes(b"{}")
        with self.assertRaisesRegex(ValueError, "changed"): self.verify()
        self.sync(marker={"status": "pass", "failures": [], "actual_actions": {"attempted": 1, "completed": 1}})
        with self.assertRaisesRegex(ValueError, "completion differs"): self.verify()
        self.sync()
        path = self.root / self.receipt["log"]
        path.write_bytes(path.read_bytes() * 2)
        self.receipt["log_sha256"] = package.sha(path)
        with self.assertRaisesRegex(ValueError, "unique clean"): self.verify()


if __name__ == "__main__":
    unittest.main()
