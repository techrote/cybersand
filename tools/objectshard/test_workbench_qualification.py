"""Adversarial evaluator receipts. Synthetic values are not gameplay evidence."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import qualify_workbench


class SourceCustodyTests(unittest.TestCase):
    def test_large_windows_tree_uses_bounded_git_arguments_and_rejects_dirty_source(self) -> None:
        paths = [f"godot/tests/qualification_source_{index:04d}_with_a_long_name.gd" for index in range(1400)]
        listing = ("\0".join(paths) + "\0").encode()
        with patch.object(qualify_workbench.subprocess, "check_output", side_effect=[listing, b""]) as command, \
                patch.object(qualify_workbench.runner, "sha256", return_value="a" * 64):
            self.assertEqual(len(qualify_workbench.committed_inputs()), len(paths))
            self.assertTrue(all(sum(len(arg) + 1 for arg in call.args[0]) < 1024 for call in command.call_args_list))
        with patch.object(qualify_workbench.subprocess, "check_output", side_effect=[listing, (paths[-1] + "\0").encode()]):
            with self.assertRaisesRegex(ValueError, "not committed"):
                qualify_workbench.committed_inputs()


class WorkbenchCompletionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.log = Path(self.directory.name) / "run.log"
        self.schema = "objectshard-m4-workbench-completion-v1"
        self.good = {"schema": self.schema, "checks": 70, "failures": []}

    def test_actual_footer_after_diagnostics_and_both_failure_encodings(self) -> None:
        for failures in ([], 0):
            receipt = {**self.good, "failures": failures}
            self.log.write_text("Diagnostic output\n" + json.dumps(receipt))
            self.assertEqual(qualify_workbench.completion(self.log, self.schema), receipt)

    def test_missing_duplicate_empty_failed_and_boolean_receipts_are_refused(self) -> None:
        mutations = ({"schema": "other"}, {"checks": 0}, {"checks": True}, {"failures": False},
                     {"failures": ["held native owner"]}, {"failures": 1})
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                self.log.write_text(json.dumps({**self.good, **mutation}))
                with self.assertRaises(ValueError):
                    qualify_workbench.completion(self.log, self.schema)
        self.log.write_text((json.dumps(self.good) + "\n") * 2)
        with self.assertRaises(ValueError):
            qualify_workbench.completion(self.log, self.schema)


class ActualWorkloadTests(unittest.TestCase):
    def profile(self, rendered: bool = False) -> dict:
        return {"source_commit": "a" * 40, "scene": "tower", "camera": "overview",
                "sampling": "cohorts", "recording_enabled": True,
                "latency": {"enabled": True, "events_retained": 10, "cadence": {"native_progress_delivery": [{"units_observed": 180}]}},
                "completed_semantic_ticks": 180, "actual_physics_steps": 720,
                "native_pose_acknowledgements": 720, "active_body_count_max": 1,
                "native_pose_echo_checks": 720,
                "completed_physical_intervals": 180, "simulated_physical_seconds": 3.0,
                "before_cut_supports": {"material_bodies_before_cut": 0, "missing_support_cells": 0, "support_cells": 800},
                "elapsed_usec": 10_000_000, "semantic_ticks_per_wall_second": 18.0,
                "shard_dimensions": [{"width": 48, "height": 64}],
                "active_body_cohorts": {"1": {"wall_usec": 1_000_000}},
                "display_driver": "windows" if rendered else "headless",
                "render_submissions": 120 if rendered else 0}

    def test_headless_and_graphical_custody_are_separate(self) -> None:
        for rendered in (False, True):
            qualify_workbench.validate_profile(self.profile(rendered), "a" * 40, rendered)

    def test_nonprogress_empty_physics_and_wrong_identity_are_refused(self) -> None:
        for mutation in ({"source_commit": "b" * 40}, {"scene": "lab"}, {"camera": "unknown"},
                         {"completed_semantic_ticks": 179}, {"actual_physics_steps": 0},
                         {"native_pose_acknowledgements": 0}, {"active_body_count_max": 0},
                         {"native_pose_echo_checks": 719}, {"native_pose_echo_checks": True},
                         {"completed_physical_intervals": 182}, {"simulated_physical_seconds": 10.0},
                         {"before_cut_supports": {"material_bodies_before_cut": 1, "missing_support_cells": 0, "support_cells": 800}},
                         {"elapsed_usec": True}, {"semantic_ticks_per_wall_second": float("nan")},
                         {"shard_dimensions": []}, {"active_body_cohorts": {}}):
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                qualify_workbench.validate_profile({**self.profile(), **mutation}, "a" * 40, False)

    def test_recording_is_independent_of_callback_sampling_and_cannot_be_empty(self) -> None:
        for sampling in ("cohorts", "light"):
            value = {**self.profile(), "sampling": sampling}
            qualify_workbench.validate_profile(value, "a" * 40, False)
            value.update(recording_enabled=False, latency={"enabled": False})
            qualify_workbench.validate_profile(value, "a" * 40, False)
        for mutation in ({"sampling": "unknown"}, {"recording_enabled": 1}, {"latency": {"enabled": False}},
                         {"latency": {"enabled": True, "events_retained": 0}},
                         {"latency": {"enabled": True, "events_retained": 2, "cadence": {}}}):
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                qualify_workbench.validate_profile({**self.profile(), **mutation}, "a" * 40, False)

    def test_headless_callbacks_cannot_be_relabelled_as_rendered_frames(self) -> None:
        value = self.profile()
        with self.assertRaises(ValueError):
            qualify_workbench.validate_profile(value, "a" * 40, True)
        value["render_submissions"] = 120
        with self.assertRaises(ValueError):
            qualify_workbench.validate_profile(value, "a" * 40, False)
        value = self.profile(True)
        value["render_submissions"] = 0
        with self.assertRaises(ValueError):
            qualify_workbench.validate_profile(value, "a" * 40, True)

    def test_fluid_profile_requires_committed_carrier_events(self) -> None:
        value = {**self.profile(), "scene": "mixed", "material_contact_deltas": {"relocated_water_cells": 4, "relocated_sand_cells": 2}}
        qualify_workbench.validate_profile(value, "a" * 40, False)
        value["material_contact_deltas"] = {"relocation_probes": 10000}
        with self.assertRaisesRegex(ValueError, "committed native"):
            qualify_workbench.validate_profile(value, "a" * 40, False)
        for malformed in (True, float("nan"), 1.0):
            value["material_contact_deltas"] = {"relocated_water_cells": malformed, "relocated_sand_cells": 2}
            with self.assertRaisesRegex(ValueError, "committed native"):
                qualify_workbench.validate_profile(value, "a" * 40, False)


class LightThroughputTests(unittest.TestCase):
    def profile(self, rendered: bool = False) -> dict:
        return {"source_commit": "a" * 40, "workload": "tower", "process_fps_cap": 60,
                "canvas_extent": [512, 512], "authored_rectangles_sha256": "b" * 64,
                "elapsed_usec": 6_000_000, "semantic_ticks": 240, "rapier_segments": 960,
                "semantic_ticks_per_second": 40.0, "renderer_callbacks": 360 if rendered else 0,
                "display_driver": "windows" if rendered else "headless", "recording_enabled": False,
                "latency": {"enabled": False}, "cohorts": {"1/1": {"wall_usec": 6_000_000, "callbacks": 360}},
                "after": {"native_pose_acknowledgements": 960, "native_pose_echo_checks": 960},
                "runtime_counter_deltas": {"physical_intervals": 240}}

    def test_source_clocks_cohorts_and_recording_are_bound(self) -> None:
        for rendered in (False, True):
            qualify_workbench.validate_throughput(self.profile(rendered), "a" * 40, rendered)
        for mutation in ({"source_commit": "b" * 40}, {"process_fps_cap": 0}, {"elapsed_usec": 0},
                         {"semantic_ticks_per_second": 60.0}, {"cohorts": {}}, {"workload": "stress"},
                         {"runtime_counter_deltas": {"physical_intervals": 242}},
                         {"after": {"native_pose_acknowledgements": 960, "native_pose_echo_checks": 959}},
                         {"recording_enabled": True}, {"renderer_callbacks": 360}):
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                qualify_workbench.validate_throughput({**self.profile(), **mutation}, "a" * 40, False)

    def test_sleeping_claim_cannot_include_an_awake_cohort(self) -> None:
        value = {**self.profile(), "workload": "sleeping",
                 "cohorts": {"1/0": {"wall_usec": 6_000_000, "callbacks": 360}}}
        qualify_workbench.validate_throughput(value, "a" * 40, False)
        value["cohorts"]["1/1"] = {"wall_usec": 1, "callbacks": 1}
        with self.assertRaisesRegex(ValueError, "body cohort"):
            qualify_workbench.validate_throughput(value, "a" * 40, False)


class RenderControlTests(unittest.TestCase):
    def disabled(self, rendered: bool) -> dict:
        return {"source_commit": "a" * 40, "scene": "tower", "camera": "overview",
                "canvas_extent": [512, 512], "authored_rectangles_sha256": "b" * 64,
                "display_driver": "windows" if rendered else "headless",
                "windows": [{"label": "disabled_intact_" + state, "elapsed_usec": 12_100_000,
                             "objectshard_enabled": False, "objectshard_native_attached": False,
                             "material_body_count": 0, "ordinary_actor_count": 1, "worker_snapshot_calls": 0,
                             "render_submissions": 40 if rendered else 0,
                             "semantic_ticks": 0 if state == "paused" else 10,
                             "actual_physics_steps": 0 if state == "paused" else 40}
                            for state in ("paused", "playing")]}

    def test_disabled_controls_require_absent_attachment_and_real_ordinary_progress(self):
        for rendered in (False, True):
            value = self.disabled(rendered)
            qualify_workbench.validate_disabled_control(value, "a" * 40, rendered)
            for change in ({"objectshard_enabled": True}, {"objectshard_native_attached": True},
                           {"worker_snapshot_calls": 1}, {"material_body_count": 1}, {"ordinary_actor_count": 0},
                           {"elapsed_usec": 11_000_000}, {"semantic_ticks": 0}, {"actual_physics_steps": 0}):
                bad = copy.deepcopy(value)
                bad["windows"][1].update(change)
                with self.subTest(change=change), self.assertRaises(ValueError):
                    qualify_workbench.validate_disabled_control(bad, "a" * 40, rendered)

    def test_actual_graphical_pause_play_controls_reject_missing_progress(self):
        rows = []
        for label in ("intact_paused", "intact_playing", "detached_paused", "detached_playing"):
            paused = label.endswith("paused")
            rows.append({"label": label, "elapsed_usec": 12_100_000, "render_submissions": 42,
                         "semantic_ticks": 0 if paused else 10, "actual_physics_steps": 0 if paused else 40,
                         "native_pose_echo_checks": 0 if paused else 40, "native_pose_acknowledgements": 0 if paused else 40,
                         "awake_bodies_before": 1 if label.startswith("detached") else 0})
        value = {"source_commit": "a" * 40, "display_driver": "windows", "windows": rows}
        qualify_workbench.validate_render_control(value, "a" * 40)
        for changed in ({**value, "display_driver": "headless"}, {**value, "windows": rows[:3]}):
            with self.assertRaises(ValueError):
                qualify_workbench.validate_render_control(changed, "a" * 40)
        rows[1]["semantic_ticks"] = 0
        with self.assertRaisesRegex(ValueError, "did not progress"):
            qualify_workbench.validate_render_control(value, "a" * 40)


if __name__ == "__main__":
    unittest.main()
