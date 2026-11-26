"""Adverse controls for the external five-minute native-play evidence reader."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import strata3_sustained as sustained


def observation():
    owner = {"world_generation": 3, "physical_epoch": 1, "worker_id": "-9223371953052580148",
             "actor_session_id": "313364849859", "actor_body_ids": ["313482290378"], "native_tick": 0, "rapier_tick": 0}
    decorations = {key: {"owner_id": "6cb46451e301c6a66750feec8a6cb50a:1:" + key, "native_instance_id": str(index+20), "native_tick": 0, "native_revision": 1}
                   for index, key in enumerate(("scripted", "effects", "background"))}
    hashes = {key: hashlib.sha256(key.encode()).hexdigest() for key in sustained.PLANES}
    optics = {"play_processed": False, "material_count": 3,
              **{key: 0 for key in ("additional_worlds", "additional_viewports", "additional_textures", "native_captures", "native_writes", "texture_uploads")}}
    resources = {"tracked_memory_bytes": 1000000, "resource_count": 100, "node_count": 100, "object_count": 500,
                 "observer_retained_completed_steps": 0, "optics": optics}
    camera = {"origin": [290, 530], "view_size": [240, 135], "world_rect": [400, 130, 750, 420], "window_size": [1600, 1000]}
    visible = {"slider_rect": [40, 250, 500, 20], "viewport_rect": [0, 0, 800, 600],
               "window_visible": True, "slider_visible": True, "fully_enclosed": True, "scroll_vertical": 500}

    def pose(tick):
        return {"position": [400+tick, 600], "rotation": 0, "linear_velocity": [1, 0], "rapier_tick": tick}

    rows = []
    first = 1000000
    for index in range(12):
        start = first + index*25000000
        before, after = dict(owner, native_tick=index*2, rapier_tick=index*2), dict(owner, native_tick=index*2+2, rapier_tick=index*2+2)
        config = {"profile": sustained.PROFILES[index % 4], "enabled": index % 4 != 0, "tonal": .5, "planes": {"play": {"participates": False}}}
        final = dict(config, tonal=.67)
        steps = [{"completed_usec": start+1000000, "rapier_tick": index*2+1}, {"completed_usec": start+24000000, "rapier_tick": index*2+2}]
        sliders = []
        for offset, micros in enumerate((2000000, 6000000, 10000000, 14000000, 18000000, 22000000)):
            target = .31 if offset % 2 == 0 else .67
            sliders.append({"requested": target, "authored": target, "callback_entry_usec": start+micros,
                            "authored_observed_usec": start+micros+50, "draw_completed_usec": start+micros+1000,
                            "callback_to_authored_usec": 50, "callback_to_next_completed_draw_usec": 1000,
                            "original_callback_invocations": 1, "native_edit_target": "play", "physical_paused": False,
                            "callback_visibility": copy.deepcopy(visible), "draw_visibility": copy.deepcopy(visible)})
        row = {"index": index, "selected_profile": sustained.PROFILES[index % 4], "quality": "balanced",
               "start_usec": start, "end_usec": start+25000000, "elapsed_usec": 25000000, "before": before, "after": after,
               "actor_before": pose(index*2), "actor_after": pose(index*2+2), "native_edit_target": "play",
               "decorative_identity": copy.deepcopy(decorations),
               "resources_before": copy.deepcopy(dict(resources, observer_retained_completed_steps=index*2)),
               "resources_after": copy.deepcopy(dict(resources, observer_retained_completed_steps=index*2+2)),
               "configuration_before": config, "configuration_after": final,
               "completed_physical_steps": steps, "physical_intervals_usec": [23000000],
               "native_publications": [{"native_tick": step["rapier_tick"], "observed_usec": step["completed_usec"],
                                        "published_usec": step["completed_usec"]-10, "serial": step["rapier_tick"],
                                        "world_revision": 1, "render_revision": 1, "worker_step_ms": 1} for step in steps],
               "callbacks": [{"observed_usec": start+1000000, "interval_usec": 1000000, "process_ms": 1},
                             {"observed_usec": start+25000000, "interval_usec": 24000000, "process_ms": 1}],
               "slider_responses": sliders, "camera_events": [
                   {"observed_usec": start+offset*5000000, "ordinary_set_view": True, "picking_error": 0,
                    "camera": dict(camera, view_size=[240, 135] if (index+offset) % 2 == 0 else [480, 270]),
                    "actor_state": pose(index*2), "submitted_action": {"move": [.1, -.5], "primary": True, "effort": 1}} for offset in range(5)],
               "paused_callbacks": 0, "observer_overflow": False, "native_capture_delta": 0, "decorative_upload_delta": 0,
               "slider_visibility_checks": 2, "slider_visibility_failures": 0}
        for when, value in (("before", config), ("after", final)):
            canonical = json.dumps(value, sort_keys=True, separators=(",", ":"))
            row["configuration_"+when+"_json"] = canonical
            row["configuration_"+when+"_sha256"] = hashlib.sha256(canonical.encode()).hexdigest()
        rows.append(row)
    return {"schema": "strata3-sustained-observation-v2", "scene": "optics-readability-challenge", "phase": "sustained-session",
            "source_revision": sustained.APPLICATION, "observer_sha256": "a"*64, "observer_source_revision": "b"*40,
            "completed": True, "failures": [], "checks": 100, "display_server": "X11", "rendering_method": "gl_compatibility",
            "rendering_adapter": "synthetic-reader-control", "ordinary_workbench": True, "diagnostic_headless": False,
            "process_id": 123, "admission_target_ms": 45000, "admission_elapsed_ms": 50000, "admission_target_met": False,
            "extent": [1024, 768], "world_count": {"play_borrowed": 1, "decorative_owned": 3},
            "teardown": {"native_world_count": 0, "pending_native_world_count": 0},
            "plane_native_hashes_before": hashes, "plane_native_hashes_after": dict(hashes, play="c"*64),
            "registration": {"window_count": 12, "window_usec": 25000000, "total_minimum_usec": 300000000,
                             "profiles": list(sustained.PROFILES), "quality": "balanced", "per_window_observer_cap": 8192,
                             "resource_and_node_range_bound_after_first_cycle": 16,
                             "slider_offsets_usec": [2000000, 6000000, 10000000, 14000000, 18000000, 22000000],
                             "camera_offsets_usec": [0, 5000000, 10000000, 15000000, 20000000],
                             **{key: 0 for key in ("image_readbacks_during_windows", "native_material_readbacks_during_windows",
                                                  "geometry_resets_during_windows", "pose_injections", "extra_native_turns", "extra_worlds")}},
            "session": {"start_usec": first, "end_usec": first+300000000, "elapsed_usec": 300000000,
                        "before": owner, "after": rows[-1]["after"], "completed_step_count": 24,
                        "decorative_before": decorations, "decorative_after": copy.deepcopy(decorations),
                        "native_capture_delta": 0, "decorative_upload_delta": 0, "native_edit_target": "play"},
            "owner_after_pause": rows[-1]["after"], "windows": rows, "live_ui_before": visible}


def validate(record):
    return sustained.validate_observation(record, observer_sha256="a"*64, observer_source_revision="b"*40)


class SustainedReader(unittest.TestCase):
    def test_five_minutes_and_original_admission_miss_remain_distinct(self):
        result = validate(observation())
        self.assertEqual(result["elapsed_usec"], 300000000)
        self.assertEqual(result["completed_physical_steps"], 24)
        self.assertEqual(result["slider_callback_to_authored_usec"]["count"], 72)
        self.assertEqual(result["physical_intervals_usec_including_boundaries"]["count"], 23)

    def test_headless_or_wrong_application_cannot_satisfy_graphics(self):
        for key, value in (("diagnostic_headless", True), ("source_revision", "d"*40), ("observer_source_revision", sustained.APPLICATION)):
            row = observation(); row[key] = value
            with self.assertRaises(RuntimeError): validate(row)

    def test_incomplete_window_or_short_duration_is_rejected(self):
        for mutate in (lambda row: row["windows"].pop(), lambda row: row["session"].update(elapsed_usec=290000000),
                       lambda row: row["registration"].update(total_minimum_usec=200000000)):
            row = observation(); mutate(row)
            with self.assertRaises(RuntimeError): validate(row)

    def test_hidden_pause_and_boundary_reset_are_rejected(self):
        for mutate in (lambda row: row["windows"][3].update(paused_callbacks=1),
                       lambda row: row["windows"][3]["before"].update(rapier_tick=0),
                       lambda row: row["windows"][3].update(start_usec=76000001),
                       lambda row: row["windows"][3]["after"].update(world_generation=4)):
            row = observation(); mutate(row)
            with self.assertRaises(RuntimeError): validate(row)

    def test_completed_step_population_cannot_be_replaced_with_nominal_rate(self):
        for mutate in (lambda row: row["windows"][0]["completed_physical_steps"].clear(),
                       lambda row: row["windows"][0]["completed_physical_steps"][1].update(rapier_tick=3),
                       lambda row: row["windows"][0].update(physical_intervals_usec=[1]),
                       lambda row: row["windows"][0].update(observer_overflow=True)):
            row = observation(); mutate(row)
            with self.assertRaises(RuntimeError): validate(row)

    def test_native_publications_are_bounded_monotonic_and_actual(self):
        for mutate in (lambda row: row["windows"][0]["native_publications"].clear(),
                       lambda row: row["windows"][0]["native_publications"][1].update(native_tick=1),
                       lambda row: row["windows"][0]["native_publications"][1].update(observed_usec=999999999)):
            row = observation(); mutate(row)
            with self.assertRaises(RuntimeError): validate(row)

    def test_actual_slider_callback_draw_and_authored_value_are_separate(self):
        for key, value in (("authored", .1), ("draw_completed_usec", 0), ("callback_to_next_completed_draw_usec", 50),
                           ("original_callback_invocations", 2), ("physical_paused", True)):
            row = observation(); row["windows"][0]["slider_responses"][0][key] = value
            with self.assertRaises(RuntimeError): validate(row)

    def test_scene_tree_visibility_cannot_hide_a_clipped_slider(self):
        for mutate in (lambda row: row["live_ui_before"].update(slider_rect=[40, 850, 500, 20]),
                       lambda row: row["windows"][0]["slider_responses"][0]["draw_visibility"].update(window_visible=False),
                       lambda row: row["windows"][0].update(slider_visibility_failures=1),
                       lambda row: row["windows"][0].update(slider_visibility_checks=1)):
            row = observation(); mutate(row)
            with self.assertRaises(RuntimeError): validate(row)

    def test_missing_slider_and_camera_events_are_rejected(self):
        for field in ("slider_responses", "camera_events"):
            row = observation(); row["windows"][0][field].pop()
            with self.assertRaises(RuntimeError): validate(row)

    def test_camera_mapping_and_actual_actor_tick_are_checked(self):
        for mutate in (lambda row: row["windows"][0]["camera_events"][0].update(picking_error=.2),
                       lambda row: row["windows"][0]["camera_events"][0]["camera"].update(view_size=[1024, 768]),
                       lambda row: row["windows"][0]["actor_after"].update(rapier_tick=0)):
            row = observation(); mutate(row)
            with self.assertRaises(RuntimeError): validate(row)

    def test_static_decorative_bytes_immutable_while_play_may_evolve(self):
        validate(observation())
        row = observation(); row["plane_native_hashes_after"]["background"] = "d"*64
        with self.assertRaises(RuntimeError): validate(row)

    def test_resource_accumulation_or_native_recapture_is_rejected(self):
        for mutate in (lambda row: row["windows"][9]["resources_after"].update(resource_count=117),
                       lambda row: row["windows"][9]["resources_after"]["optics"].update(material_count=4),
                       lambda row: row["windows"][9].update(native_capture_delta=1),
                       lambda row: row["session"]["decorative_after"]["effects"].update(native_revision=2)):
            row = observation(); mutate(row)
            with self.assertRaises(RuntimeError): validate(row)

    def test_opaque_plane_owner_fence_is_distinct_from_numeric_native_instance(self):
        validate(observation())
        for field, value in (("owner_id", ""), ("owner_id", "12345"), ("owner_id", "doc:1:effects"),
                             ("native_instance_id", "doc:1:scripted")):
            row = observation()
            row["session"]["decorative_before"]["scripted"][field] = value
            row["session"]["decorative_after"]["scripted"][field] = value
            with self.assertRaises(RuntimeError): validate(row)

    def test_recorded_configuration_hash_is_independent_of_float_serialization(self):
        row = observation(); row["windows"][0]["configuration_before_json"] += " "
        with self.assertRaises(RuntimeError): validate(row)

    def test_portable_evidence_paths_reject_all_root_and_parent_forms(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); (root / "valid.png").write_bytes(b"x")
            self.assertEqual(sustained.path_in(root, "valid.png"), root / "valid.png")
            for name in ("/outside.png", "C:outside.png", "C:/outside.png", "../outside.png", "a//b", "./valid.png", "a\\b", "a\nb"):
                with self.assertRaises(RuntimeError): sustained.path_in(root, name)

    def test_linked_evidence_ancestor_is_rejected_even_with_regular_leaf(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "session").mkdir()
            (root / "session/report.json").write_text("{}")
            # This branch is portable on Windows hosts without symlink rights.
            with mock.patch.object(Path, "is_symlink", lambda path: path == root / "session"):
                with self.assertRaisesRegex(RuntimeError, "ancestor"):
                    sustained.path_in(root, "session/report.json")
            with tempfile.TemporaryDirectory() as outside:
                (Path(outside) / "report.json").write_text("{}")
                try:
                    (root / "linked").symlink_to(outside, target_is_directory=True)
                except OSError:
                    return
                with self.assertRaisesRegex(RuntimeError, "ancestor"):
                    sustained.path_in(root, "linked/report.json")


if __name__ == "__main__":
    unittest.main()
