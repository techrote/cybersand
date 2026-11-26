"""Synthetic adverse controls; these are not graphical/performance evidence."""
import copy
import hashlib
import json
import unittest

import strata3_shader_cost as cost


def observation():
    hashes = {name: hashlib.sha256(name.encode()).hexdigest() for name in cost.shared.PLANES}
    owner = {"world_generation": 3, "physical_epoch": 2, "worker_id": "-9223371952498932018",
             "actor_session_id": "412132320454", "actor_body_ids": ["412249760973"], "native_tick": 0, "rapier_tick": 0}
    camera = {"origin": [0, 0], "view_size": [1024, 768], "world_rect": [0, 0, 192, 64],
              "window_size": [1600, 1000], "content_scale_factor": 1.0}
    actor = {"position": [10, 10], "linear_velocity": [0, 0], "rotation": 0, "rapier_tick": 0}
    rows = []
    for repeat in range(3):
        for case_id, profile, variant in (cost.CASES[::-1] if repeat % 2 else cost.CASES):
            shader = cost.ORIGINAL if variant == "original" else cost.CANDIDATE
            tag = case_id + "-" + str(repeat)
            config = {"profile": profile, "enabled": profile != "classic", "planes": {"play": {"participates": False}}}
            canonical = json.dumps(config, separators=(",", ":"), sort_keys=True)
            elapsed = 900001
            ticks = [{"rapier_tick": index+1, "completed_usec": 1010000+index*10000} for index in range(90)]
            publications = [{"native_tick": index, "observed_usec": 1010000+index*10000,
                             "published_usec": 1009990+index*10000, "serial": index+1,
                             "world_revision": 4, "render_revision": 4, "worker_step_ms": .1} for index in range(90)]
            before = dict(owner, world_generation=3+len(rows))
            after = dict(before, native_tick=89, rapier_tick=90)
            stats = {"shader_sha256": shader, "profile": profile, "quality": "balanced", "play_processed": False,
                     "material_count": 0 if profile == "classic" else 3, "uniform_writes": 0 if profile == "classic" else 100,
                     "active": profile != "classic", "active_planes": [] if profile == "classic" else ["background", "effects", "scripted"],
                     "inspection": {"bypass": False, "clarity": False, "wipe": 1.0, "focus_override": ""}, "transitioning": False,
                     **{name: 0 for name in ("additional_worlds", "additional_viewports", "additional_textures",
                                             "native_captures", "native_writes", "texture_uploads")}}
            capture = {"tag": tag, "filename": tag+".png", "sha256": "f"*64,
                       "physical_paused": True, "outside_timed_window": True, "captured_usec": 1000000,
                       "shader_sha256": shader, "camera": copy.deepcopy(camera), "actor": copy.deepcopy(actor),
                       "plane_native_hashes": dict(hashes), "configuration": config, "configuration_json": canonical,
                       "configuration_sha256": hashlib.sha256(canonical.encode()).hexdigest(), "actual_image_size": [192, 64]}
            rows.append({"case_id": case_id, "profile": profile, "variant": variant, "repeat": repeat, "quality": "balanced",
                         "shader_sha256": shader, "callbacks": 90, "elapsed_usec": elapsed,
                         "physical_gpu_acceptance": False, "native_capture_delta": 0, "decorative_upload_delta": 0,
                         "paused_capture": capture, "configuration": config, "initial_native_play_sha256": hashes["play"],
                         "before": before, "after": after, "completed_physical_steps": ticks,
                         "physical_intervals_usec": [10000]*89, "physical_distribution_usec": cost.distribution([10000]*89),
                         "callback_intervals_usec": [10000]*90, "callback_distribution_usec": cost.distribution([10000]*90),
                         "godot_process_ms": [10.0]*90, "native_publications": publications,
                         "native_publication_interval_distribution_usec": cost.distribution([10000]*89),
                         "native_ticks_per_second": 89e6/elapsed, "rapier_ticks_per_second": 90e6/elapsed,
                         "actor_position_before": [10, 10], "actor_position_after": [20, 10], "actor_distance_cells": 10,
                         "scene_admission_elapsed_ms": 46000, "scene_admission_target_met": False,
                         "optical_statistics": stats, "resource_count": 100, "godot_tracked_memory_bytes": 1000000})
    pairs = [{"original": prefix+"-original-"+str(repeat), "candidate": prefix+"-empty-coverage-"+str(repeat),
              "repeat": repeat, "exact_equal": True, "changed_pixels": 0, "max_channel_difference_u8": 0,
              "pixels": 192*64, "world_rect": [0, 0, 192, 64]}
             for repeat in range(3) for prefix in ("architectural", "clarity")]
    return {"schema": "strata3-shader-cost-observation-v1", "phase": "progression", "scene": "optics-readability-challenge",
            "completed": True, "failures": [], "checks": 100, "source_revision": cost.APPLICATION,
            "observer_sha256": "a"*64, "observer_source_revision": "b"*40, "diagnostic_headless": False,
            "ordinary_workbench": True, "display_server": "X11", "rendering_method": "gl_compatibility",
            "rendering_adapter": "synthetic-adverse-control", "process_id": 123,
            "original_shader_sha256": cost.ORIGINAL, "candidate_shader_sha256": cost.CANDIDATE,
            "original_shader_restored": True, "world_count": {"play_borrowed": 1, "decorative_owned": 3}, "extent": [1024, 768],
            "teardown": {"native_world_count": 0, "pending_native_world_count": 0},
            "admission_target_ms": 45000, "admission_elapsed_ms": 50000, "admission_target_met": False,
            "probe_registration": {"cases": [list(row) for row in cost.CASES], "repeats": 3, "callbacks_per_sample": 90,
                                   "order": "forward/reverse/forward", "quality": "balanced", "geometry_reset_between_samples": True,
                                   "per_sample_watchdog_usec": 90000000, "shader_compilation_and_captures_before_timing": True,
                                   "minimum_native_rate_ratio_to_classic": .9, "minimum_rapier_rate_ratio_to_classic": .9,
                                   "p95_ratio": 1.2, "p95_allowance_usec": 10000},
            "probe_samples": rows, "pixel_equivalence": pairs}


def validate(value):
    return cost.validate_observation(value, observer_sha256="a"*64, observer_source_revision="b"*40)


class ShaderCostReader(unittest.TestCase):
    def test_complete_population_keeps_admission_misses(self):
        summary = validate(observation())
        self.assertFalse(summary["initial_admission_target_met"])
        self.assertEqual(len(summary["comparisons"]), 5)
        self.assertEqual(len(summary["comparisons"]["architectural-original"]["repeats"]), 3)
        self.assertFalse(summary["comparisons"]["architectural-original"]["repeats"][0]["scene_admission_target_met"])
        self.assertTrue(summary["adjudication"].startswith("PENDING"))

    def test_headless_wrong_source_or_unregistered_shader_rejected(self):
        for key, value in (("diagnostic_headless", True), ("source_revision", "c"*40),
                           ("candidate_shader_sha256", "c"*64), ("original_shader_restored", False)):
            record = observation(); record[key] = value
            with self.assertRaises(RuntimeError): validate(record)

    def test_every_callback_and_completed_step_required(self):
        for mutate in (lambda row: row["completed_physical_steps"].pop(),
                       lambda row: row["completed_physical_steps"][1].update(rapier_tick=4),
                       lambda row: row.update(physical_intervals_usec=[1]*89),
                       lambda row: row["callback_intervals_usec"].pop(),
                       lambda row: row.update(native_ticks_per_second=1000)):
            record = observation(); mutate(record["probe_samples"][0])
            with self.assertRaises(RuntimeError): validate(record)

    def test_camera_geometry_configuration_and_actor_match(self):
        for mutate in (lambda row: row["paused_capture"]["camera"].update(origin=[1, 0]),
                       lambda row: row["paused_capture"]["plane_native_hashes"].update(background="c"*64),
                       lambda row: row["paused_capture"].update(configuration_json="{}"),
                       lambda row: row["paused_capture"]["actor"].update(position=[11, 10])):
            record = observation(); mutate(record["probe_samples"][2])
            with self.assertRaises(RuntimeError): validate(record)

    def test_native_owner_capture_and_actual_material_shader(self):
        for mutate in (lambda row: row["after"].update(worker_id="999"),
                       lambda row: row.update(native_capture_delta=1),
                       lambda row: row["optical_statistics"].update(shader_sha256=cost.ORIGINAL),
                       lambda row: row["optical_statistics"].update(profile="noir"),
                       lambda row: row["optical_statistics"]["inspection"].update(bypass=True)):
            record = observation(); mutate(record["probe_samples"][2])
            with self.assertRaises(RuntimeError): validate(record)

    def test_readback_cannot_enter_physical_population(self):
        record = observation()
        record["probe_samples"][0]["paused_capture"]["captured_usec"] = record["probe_samples"][0]["completed_physical_steps"][0]["completed_usec"]
        with self.assertRaises(RuntimeError): validate(record)

    def test_native_publication_is_not_nominal_frame_rate(self):
        for mutate in (lambda row: row["native_publications"].clear(),
                       lambda row: row["native_publications"][1].update(native_tick=0),
                       lambda row: row["native_publications"][1].update(published_usec=999999999),
                       lambda row: row.update(native_publication_interval_distribution_usec=cost.distribution([1]*89))):
            record = observation(); mutate(record["probe_samples"][0])
            with self.assertRaises(RuntimeError): validate(record)

    def test_order_population_and_registration_cannot_be_weakened(self):
        for mutate in (lambda value: value["probe_samples"].pop(),
                       lambda value: value["probe_samples"].reverse(),
                       lambda value: value["probe_registration"].update(minimum_native_rate_ratio_to_classic=.5),
                       lambda value: value["pixel_equivalence"].pop()):
            record = observation(); mutate(record)
            with self.assertRaises(RuntimeError): validate(record)

    def test_alpha_only_pixel_change_fails_exact_equivalence(self):
        first = (1, 1, bytes([20, 30, 40, 128]))
        self.assertEqual(cost.equal_rgba(first, first, "control")["changed_channels"], 0)
        with self.assertRaises(RuntimeError): cost.equal_rgba(first, (1, 1, bytes([20, 30, 40, 127])), "alpha-change")
        with self.assertRaises(RuntimeError): cost.equal_rgba(first, (1, 2, first[2]), "wrong-extent")

    def test_command_paths_must_bind_retained_external_files(self):
        base = "/tmp/source-bound-cost"
        paths = {"driver": base+"/observer/"+cost.Path(cost.DRIVER).name,
                 "wrapper": base+"/observer/"+cost.Path(cost.WRAPPER).name,
                 "shader": base+"/observer/"+cost.Path(cost.SHADER).name,
                 "shader-original": base+"/shader-original", "shader-candidate": base+"/shader-candidate"}
        cost.validate_execution_paths(base, paths)
        paths["shader"] = "/tmp/unretained-shader.gdshader"
        with self.assertRaises(RuntimeError): cost.validate_execution_paths(base, paths)

    def test_slow_candidate_remains_valid_negative_research(self):
        record = observation()
        for row in record["probe_samples"]:
            if row["variant"] != "empty-coverage": continue
            row["elapsed_usec"] *= 2
            row["native_ticks_per_second"] /= 2
            row["rapier_ticks_per_second"] /= 2
        summary = validate(record)
        candidate = summary["comparisons"]["architectural-empty-coverage"]
        self.assertEqual(candidate["median_native_rate_ratio_to_classic"], .5)
        self.assertFalse(candidate["observed_native_rate_target_met"])
        self.assertEqual(candidate["comparison_to_same_profile_original"]["median_native_rate_ratio"], .5)
        self.assertEqual(len(candidate["comparison_to_same_profile_original"]["per_repeat_rate_ratios"]), 3)
        self.assertTrue(summary["adjudication"].startswith("PENDING"))


if __name__ == "__main__":
    unittest.main()
