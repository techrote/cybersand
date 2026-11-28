"""Independent missing-case and byte-tamper controls for the unified lane."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import native_checks
import publication_candidate as publication
import runtime_custody as custody
import shared


class UnifiedInventory(unittest.TestCase):
    def test_all_eight_reciprocal_suites_have_complete_native_markers(self):
        expected = {
            "test_assembly", "test_reciprocal_mosaic", "test_reciprocal", "test_swarm005",
            "test_swarm006_source", "test_swarm006_admission", "test_custody_hash", "test_swarm006_recovery",
        }
        self.assertEqual(set(custody.RECIPROCAL_TESTS), expected)
        self.assertEqual(set(native_checks.MARKERS), expected | {"test_workbench_authoring_patch"})
        texts = {"test_swarm006_source": "SWARM006_SOURCE_OPPORTUNITIES: PASS tests=4/4 assertions=12",
                 "test_swarm006_admission": "recovery admission tests: 4 passed, 0 failed, 12 assertions",
                 "test_custody_hash": "custody hash: 12 assertions PASS",
                 "test_swarm006_recovery": "SWARM006 recovery: 4 groups passed, 0 failed; 12 assertions"}
        for name, text in texts.items():
            self.assertTrue(native_checks.marker_valid(name, text))
            self.assertFalse(native_checks.marker_valid(name, text + "\n" + text))
            self.assertFalse(native_checks.marker_valid(name, text + "\nAddressSanitizer: failure"))

    def test_all_nine_graphical_cases_and_native_conditional_reopen_are_required(self):
        self.assertEqual(set(shared.legacy.EXAMPLES), {"transaction", "reciprocal", "swarm005_irregular", "swarm005_viaduct",
            "swarm006_industrial_off", "swarm006_industrial_on", "swarm006_viaduct_on", "swarm006_irregular_on", "swarm006_irregular_square_on"})
        examples = {name: {"native_outcome": {"native_can_apply": False}} for name in shared.legacy.EXAMPLES}
        expected = shared.graphical_processes(examples)
        self.assertEqual(len(expected), 20)
        self.assertIn(("input-integrity", None), expected)
        self.assertIn(("controls-native", None), expected)
        examples["swarm006_industrial_on"]["native_outcome"]["native_can_apply"] = True
        self.assertEqual(len(shared.graphical_processes(examples)), 21)
        self.assertIn(("reopen", "swarm006_industrial_on"), shared.graphical_processes(examples))
        del examples["swarm006_industrial_on"]["native_outcome"]["native_can_apply"]
        with self.assertRaisesRegex(ValueError, "Apply authority"):
            shared.graphical_processes(examples)

    def test_native_reducer_rejects_missing_006_suite_or_transport(self):
        from test_reduce_evidence import native_fixture
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            receipt, value = native_fixture(root)
            results = value["results"]
            publication.report(root, "native.json", receipt, "native")
            for missing in ("strict-test_swarm006_recovery", "sanitized-test_custody_hash", "v1-v2-request", "v4-request"):
                altered = {**value, "results": [row for row in results if row["case"] != missing]}
                custody.write_json(root / "native.json", altered)
                with self.subTest(missing=missing), self.assertRaisesRegex(ValueError, "incomplete"):
                    publication.report(root, "native.json", receipt, "native")

    def test_typed_gesture_and_persistent_historical_latch_cannot_be_omitted(self):
        base = {"platform": "Windows", "display": "Windows", "historical_only": True,
                "controller_phase": "historical", "apply_disabled": True, "undo_disabled": True,
                "integration_refusals": {name: True for name in (
                    "historical_cancel_latched", "historical_edit_latched", "historical_failed_generation_latched",
                    "historical_fresh_generation", "historical_files_unchanged")}}
        with patch.object(shared.legacy, "ui_report_errors", return_value=[]):
            def check(report):
                return shared.ui_report_errors(report, "reopen", "transaction", "a" * 40, "b" * 64, "c" * 64, "windows")
            self.assertEqual(check(base), [])
            for field in ("historical_only", "apply_disabled", "undo_disabled"):
                self.assertTrue(check({**base, field: False}))
            for field in base["integration_refusals"]:
                altered = copy.deepcopy(base)
                del altered["integration_refusals"][field]
                self.assertTrue(check(altered))


class RawLayout(unittest.TestCase):
    def test_raw_import_asset_tracked_uid_and_unknown_file_changes_are_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = root / "godot"
            files = {"godot/project.godot": b"[application]\n", "godot/asset.svg.import": b"canonical import\n",
                     "godot/asset.svg": b"exact asset\n", "godot/script.gd.uid": b"uid://tracked\n"}
            for name, data in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            custody.write_json(root / "source-stage.json", {"files_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}})
            initial = shared.layout_identity(project)
            (project / "generated.gd.uid").write_text("uid://new-generated-sidecar\n")
            self.assertEqual(shared.layout_identity(project), initial)
            for name, original in files.items():
                (root / name).write_bytes(original + b"changed")
                with self.subTest(name=name), self.assertRaisesRegex(ValueError, "Changed evidence"):
                    shared.layout_identity(project)
                (root / name).write_bytes(original)
            (project / "unlisted-scene.tscn").write_bytes(b"unexpected source")
            with self.assertRaisesRegex(ValueError, "unlisted"):
                shared.layout_identity(project)


if __name__ == "__main__":
    unittest.main()
