import json
from pathlib import Path
import tempfile
import unittest

from analyze_pose_trace import analyze, compare_trajectories, main, read_trace


def body(source, x, gap=10, residual=0):
    return {"slot": 0, "source": source, "selected_screen": [x, 100],
            "screen_selected": {"residual_magnitude_px": residual},
            "live_screen": [x + gap, 100], "bound_screen": [x, 100],
            "guard_reason": "empty_swept_mask" if source == "live" else "material_in_swept_mask"}


def frame(n, source, x, phase=None, residual=0):
    return {"type": "frame", "process_frame": n, "time_usec": 10000*n,
            "camera_mode": 1, "camera_presented": [n, 40],
            "camera_screen_phase_px": phase or [0, 0],
            "bodies": [body(source, x, residual=residual)]}


def moving_frame(n, selected_world, live_world, camera):
    """1px/cell intended screen map; static terrain origin pans with camera."""
    row = frame(n, "mask_bound" if selected_world != live_world else "live", selected_world-camera)
    row.update(shader_world_zero_screen_px=[-camera, 0],
               shader_basis_x=[1, 0], shader_basis_y=[0, 1])
    b = row["bodies"][0]
    b.update(selected={"xy": [selected_world, 100]},
             live_screen=[live_world-camera, 100], bound_screen=[selected_world-camera, 100])
    return row


def step_event(step, time, x=None):
    return {"type": "event", "event": "rapier_step", "step": step,
            "time_usec": time, "start_usec": time-100,
            "simulation_time_sec": step/60, "fixed_delta": 1/60,
            "bodies": [{"slot": 0, "xy": [step if x is None else x, 100],
                        "velocity": [60, 0], "angle": 0}]}


def contract_frame(n, step, x, source="live", held=False, reset=False, generation=1):
    row = moving_frame(n, x, x, 0)
    row["presentation"] = {"policy": "coherent", "session": 1, "epoch": 1,
                           "world_generation": 1, "resolve_usec": 100 + n,
                           "follow_instance_id": 7, "follow_position": [x, 100]}
    row["bodies"][0].update(presentation_step=step, desired_step=step+3,
                             source=source, intentional_hold=held, timeline_reset=reset,
                             source_reason="safe_hold" if held else "safe_advance",
                             instance_id=7, generation=generation)
    return row


def write_trace(path, frames, events=(), **footer):
    lines = [{"type": "header", "schema": "cybersand-pose-trace-v1", "settings": {"test": True}},
             *frames, *events, {"type": "summary", "frames": len(frames), "dropped": 0, **footer}]
    path.write_text("\n".join(map(json.dumps, lines))+"\n")


class FrameTraceAnalysisTests(unittest.TestCase):
    def test_pose_switch_and_projection_error_have_distinct_attribution(self):
        frames = [frame(1, "mask_bound", 100), frame(2, "live", 113),
                  frame(3, "live", 130, residual=3)]
        result = analyze(frames, 8.0)
        self.assertEqual(result["event_causes"]["live_vs_bound_source_switch"], 1)
        self.assertEqual(result["event_causes"]["spatial_projection_mismatch"], 1)
        self.assertEqual(result["projection_residual_over_1px"], 1)

    def test_stationary_bound_screen_jumps_detect_staleness(self):
        result = analyze([frame(1, "mask_bound", 100), frame(2, "mask_bound", 120)], 8)
        self.assertEqual(result["event_causes"]["stale_mask_bound_pose"], 1)

    def test_reject_incomplete_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "trace.jsonl"
            path.write_text('{"type":"header","schema":"cybersand-pose-trace-v1"}\n')
            with self.assertRaises(ValueError):
                read_trace(path)

    def test_complete_file_and_counts(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "trace.jsonl"
            write_trace(path, [frame(1,"mask_bound",100)])
            header, frames, footer = read_trace(path)
            self.assertEqual(len(frames),1)
            self.assertEqual(footer["dropped"],0)

    def test_completion_events_use_actual_time_and_preserve_fixed_step_meaning(self):
        frames = [frame(1, "live", 100), frame(2, "live", 100)]
        events = [step_event(1, 100000), step_event(2, 108333), step_event(3, 116666)]
        events += [{"type": "event", "event": "native_tick", "tick_index": i,
                    "start_usec": i*100000-5000, "completed_usec": i*100000}
                   for i in range(1,4)]
        result = analyze(frames, events=events)
        self.assertAlmostEqual(result["rates"]["rapier_completed"]["hz"], 120, delta=.01)
        self.assertEqual(result["rates"]["native_completed"]["hz"], 10)
        self.assertEqual(result["rates"]["main_submissions"]["hz"], 100)
        self.assertAlmostEqual(result["rates"]["rapier_simulated_seconds_per_wall_second"], 2, delta=.001)
        self.assertEqual(result["native_tick_wall_ms"]["maximum"], 5)
        self.assertIsNone(result["rates"]["physical_gpu_present"])

    def test_live_visual_source_does_not_hide_physics_freeze(self):
        frames = [contract_frame(n, 1, 100) for n in range(1, 13)]
        for row in frames:
            row["rapier_step"] = 1
        events = [step_event(1, 10000), step_event(2, 130000),
                  {"event": "rapier_hold", "time_usec": 20000,
                   "reason": "terrain_installation", "pending_hard_chunks": 400},
                  {"event": "rapier_hold", "time_usec": 110000,
                   "reason": "terrain_installation", "pending_hard_chunks": 100}]
        events[1].update(solver_usec=60, flush_usec=10)
        result = analyze(frames, events=events)
        self.assertEqual(result["presentation_contract"]["intentional_hold_frames"], 0)
        progress = result["physics_progress"]
        self.assertEqual(progress["active_completed_step_gap_ms"]["maximum"], 120)
        self.assertEqual(progress["active_gaps_at_least_100ms"], 1)
        self.assertEqual(progress["main_intervals_without_physics_progress"], 11)
        witness = progress["largest_active_gaps"][0]
        self.assertEqual(witness["hold_reasons"], {"terrain_installation": 2})
        self.assertEqual(witness["step_work_ms"], .1)
        self.assertEqual(witness["solver_ms"], .06)

    def test_pause_and_missing_steps_are_not_reported_as_measured_active_freezes(self):
        events = [step_event(1, 10000), step_event(2, 1010000),
                  step_event(5, 2010000),
                  {"event": "rapier_hold", "time_usec": 500000, "reason": "paused"}]
        progress = analyze([], events=events)["physics_progress"]
        self.assertEqual(progress["pause_spanning_intervals"], 1)
        self.assertEqual(progress["unmeasured_intervals_with_missing_completions"], 1)
        self.assertEqual(progress["active_gaps_at_least_100ms"], 0)
        self.assertIsNone(progress["active_completed_step_gap_ms"]["maximum"])

    def test_frame_only_capture_cannot_certify_physics_step_continuity(self):
        progress = analyze([frame(1, "live", 100), frame(2, "live", 101)])["physics_progress"]
        self.assertEqual(progress["consecutive_step_intervals"], 0)
        self.assertIsNone(progress["active_completed_step_gap_ms"]["maximum"])
        self.assertEqual(progress["observed_main_intervals"], 0)

    def test_camera_translation_cancels_in_actor_terrain_relative_measurements(self):
        result = analyze([moving_frame(1, 100, 100, 0), moving_frame(2, 101, 101, 1),
                          moving_frame(3, 102, 102, 2)])
        # Screen actor is stationary under Follow, but moves normally relative to terrain.
        self.assertEqual(result["actor_relative_to_static_world_step_px"]["maximum"], 1)
        self.assertEqual(result["presentation_error_change_px"]["maximum"], 0)
        self.assertEqual(result["selected_holds_while_live_moves"], 0)

    def test_stale_world_pose_is_detected_even_when_camera_moves_actor_on_screen(self):
        result = analyze([moving_frame(1,100,100,0), moving_frame(2,100,101,1),
                          moving_frame(3,100,102,2), moving_frame(4,103,103,3)])
        self.assertEqual(result["selected_holds_while_live_moves"], 2)
        self.assertEqual(result["selected_hold_duration_ms"]["maximum"], 20)
        self.assertEqual(result["presentation_error_change_px"]["maximum"], 2)
        self.assertEqual(result["actor_relative_to_static_world_step_px"]["maximum"], 3)

    def test_independent_projection_catches_wrong_recorded_screen_even_if_residual_claims_zero(self):
        row = moving_frame(1,100,100,0)
        row["bodies"][0]["selected_screen"][0] += 7
        result = analyze([row])
        self.assertEqual(result["independently_recomputed_projection_residual_px"]["maximum"], 7)
        self.assertEqual(result["projection_residual_over_1px"], 1)

    def test_acks_match_their_render_serial_instead_of_latest_upload(self):
        events = [{"type":"event", "event":"texture_upload", "render_serial":1,
                   "start_usec":90, "completed_usec":100},
                  {"type":"event", "event":"texture_upload", "render_serial":2,
                   "start_usec":190, "completed_usec":200},
                  {"type":"event", "event":"render_ack", "render_serial":1, "time_usec":250}]
        result = analyze([], events=events)
        self.assertEqual(result["upload_to_ack_issue_ms"]["maximum"], .15)
        self.assertEqual(result["upload_to_ack_issue_ms"]["count"], 1)

    def test_identical_trajectory_at_different_wall_rates_compares_equal_completed_steps(self):
        a = [step_event(i, i*16667) for i in range(1,5)]
        b = [step_event(i, i*8333) for i in range(1,5)]
        result = compare_trajectories(a,b)
        self.assertEqual(result["matching_completed_step_bodies"],4)
        self.assertEqual(result["position_delta_world_cells"]["maximum"],0)
        self.assertEqual(result["simulation_time_delta_seconds"]["maximum"],0)
        self.assertEqual(result["incompatible_fixed_step_rows"],0)
        b[-1]["bodies"][0]["xy"][0] += .5
        self.assertEqual(compare_trajectories(a,b)["position_delta_world_cells"]["maximum"],.5)

    def test_missing_completion_rows_are_explicit_and_achieved_rate_uses_counter_advance(self):
        result = analyze([], events=[step_event(1,100000), step_event(4,150000)])
        self.assertEqual(result["rates"]["rapier_completed"]["unrecorded_completions"],2)
        self.assertEqual(result["rates"]["rapier_completed"]["hz"],60)

    def test_read_trace_keeps_original_events_and_reports_dropped_event_buffers(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, report = Path(tmp)/"trace.jsonl", Path(tmp)/"report.json"
            original = step_event(1,10000)
            write_trace(path,[frame(1,"live",100)], [original], events_dropped=3)
            _, _, footer = read_trace(path)
            self.assertEqual(footer["_events"],[original])
            self.assertEqual(main([str(path),"--output",str(report)]),0)
            result = json.loads(report.read_text())
            self.assertFalse(result["complete_recording"])
            self.assertEqual(result["dropped_events"],3)

    def test_out_of_order_frame_times_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/"trace.jsonl"
            rows = [frame(1,"live",100),frame(2,"live",101)]
            rows[1]["time_usec"] = rows[0]["time_usec"]-1
            write_trace(path,rows)
            with self.assertRaisesRegex(ValueError,"timestamps"):
                read_trace(path)

    def test_free_camera_actor_outside_view_is_explicit(self):
        row = moving_frame(1, 200, 200, 0)
        row.update(screen_transform_origin=[0,0], screen_basis_x=[1,0], screen_basis_y=[0,1],
                   content_rect=[0,0,240,135])
        row["bodies"][0]["selected_screen"][1] = 200
        result = analyze([row])
        self.assertEqual(result["submitted_actor_centre_visibility"], {"outside":1})

    def test_deliberate_camera_mode_change_is_distinguished_from_judder(self):
        a, b = frame(1,"live",100), frame(2,"live",140)
        a["camera_mode"] = 0
        result = analyze([a,b])
        self.assertEqual(result["event_causes"], {"camera_mode_change":1})

    def test_scheduler_lateness_is_not_mislabelled_queue_depth(self):
        row = frame(1,"live",100)
        row["native_scheduler_lateness_usec"] = 1234
        result = analyze([row])
        self.assertEqual(result["native_scheduler_lateness_ms"]["maximum"],1.234)
        self.assertNotIn("native_backlog_ms",result)

    def test_mixed_world_lifetimes_are_rejected_before_deduplication(self):
        events = [step_event(1,10000),step_event(1,20000)]
        events[0]["world_generation"] = 1
        events[1]["world_generation"] = 2
        with self.assertRaisesRegex(ValueError,"Mixed.*generation"):
            analyze([],events=events)
        with self.assertRaisesRegex(ValueError,"Mixed.*generation"):
            compare_trajectories(events,events)

    def test_cumulative_ack_covers_earlier_serials_but_exact_match_coverage_is_explicit(self):
        events = [{"type":"event","event":"texture_upload","render_serial":1,"completed_usec":100},
                  {"type":"event","event":"texture_upload","render_serial":2,"completed_usec":200},
                  {"type":"event","event":"render_ack","render_serial":2,"time_usec":300}]
        result = analyze([],events=events)
        self.assertEqual(result["upload_to_ack_issue_ms"]["matched_before_observations"],1)
        self.assertEqual(result["upload_to_ack_issue_ms"]["unpaired_before_observations"],1)
        self.assertEqual(result["upload_to_cumulative_ack_issue_ms"]["matched_before_observations"],2)
        self.assertEqual(result["upload_to_cumulative_ack_issue_ms"]["maximum"],.2)

    def test_completed_before_start_is_rejected(self):
        event = step_event(1,10000)
        event["start_usec"] = 10001
        with self.assertRaisesRegex(ValueError,"precedes"):
            analyze([],events=[event])

    def test_recorded_source_time_rewind_is_detected_without_camera_or_motion_heuristics(self):
        rows = [contract_frame(1, 20, 100), contract_frame(2, 12, 95, "mask_bound"),
                contract_frame(3, 21, 101)]
        result = analyze(rows)["presentation_contract"]
        self.assertEqual(result["source_time_rewind_count"], 1)
        self.assertEqual(result["source_time_rewinds"][0]["backward_steps"], 8)
        self.assertEqual(result["source_changes"], {"live->mask_bound": 1, "mask_bound->live": 1})

    def test_legitimate_physical_reversal_is_not_a_timeline_rewind(self):
        result = analyze([contract_frame(1, 20, 100), contract_frame(2, 21, 90),
                          contract_frame(3, 22, 70)])["presentation_contract"]
        self.assertEqual(result["source_time_rewind_count"], 0)
        self.assertEqual(result["selected_step_observations"], 3)

    def test_intentional_holds_have_distinct_duration_and_no_rewind(self):
        rows = [contract_frame(1, 20, 100), contract_frame(2, 20, 100, "held", True),
                contract_frame(3, 20, 100, "held", True), contract_frame(4, 21, 101)]
        result = analyze(rows)["presentation_contract"]
        self.assertEqual(result["intentional_hold_frames"], 2)
        self.assertEqual(result["intentional_hold_duration_ms"]["maximum"], 20)
        self.assertEqual(result["source_time_rewind_count"], 0)
        self.assertEqual(result["source_reasons"]["safe_hold"], 2)

    def test_follow_tracks_selected_pose_not_desired_live_pose(self):
        rows = [contract_frame(1, 20, 100), contract_frame(2, 20, 100, "held", True)]
        rows[1]["bodies"][0]["live_screen"] = [120,100]
        good = analyze(rows)["presentation_contract"]
        self.assertEqual(good["follow_target_minus_selected_px"]["maximum"], 0)
        rows[1]["presentation"]["follow_position"] = [120, 100]
        bad = analyze(rows)["presentation_contract"]
        self.assertEqual(bad["follow_target_minus_selected_px"]["maximum"], 20)

    def test_actor_replacement_and_explicit_reset_start_new_timelines(self):
        rows = [contract_frame(1, 20, 100), contract_frame(2, 1, 0, generation=2),
                contract_frame(3, 0, 400, generation=2, reset=True)]
        result = analyze(rows)
        self.assertEqual(result["presentation_contract"]["source_time_rewind_count"], 0)
        self.assertEqual(result["presentation_contract"]["timeline_resets"], 2)
        self.assertEqual(result["events"], 0)

    def test_withheld_actor_is_explicit_and_preserves_source_time_continuity(self):
        rows = [contract_frame(1, 20, 100), contract_frame(2, 20, 100, "hidden"),
                contract_frame(3, 21, 200)]
        rows[1]["bodies"][0].update(selected=None, selected_screen=None, source_reason="stale_generation")
        result = analyze(rows)["presentation_contract"]
        self.assertEqual(result["withheld_body_frames"], 1)
        self.assertEqual(result["source_reasons"]["stale_generation"], 1)
        self.assertEqual(result["source_time_rewind_count"], 0)

    def test_negative_source_step_is_unknown_and_does_not_erase_last_known_step(self):
        rows = [contract_frame(1, 20, 100), contract_frame(2, -1, 100),
                contract_frame(3, 12, 90)]
        result = analyze(rows)["presentation_contract"]
        self.assertEqual(result["selected_step_observations"], 2)
        self.assertEqual(result["selected_step_unknown_visible_frames"], 1)
        self.assertEqual(result["desired_minus_selected_steps"]["count"], 2)
        self.assertEqual(result["source_time_rewind_count"], 1)
        self.assertEqual(result["source_time_rewinds"][0]["prior_step"], 20)
        self.assertEqual(result["source_time_rewinds"][0]["selected_step"], 12)

    def test_hidden_gap_cannot_hide_source_time_rewind(self):
        rows = [contract_frame(1, 20, 100), contract_frame(2, -1, 100, "hidden"),
                contract_frame(3, 12, 90)]
        rows[1]["bodies"][0].update(selected=None, selected_screen=None)
        result = analyze(rows)["presentation_contract"]
        self.assertEqual(result["withheld_body_frames"], 1)
        self.assertEqual(result["source_time_rewind_count"], 1)
        self.assertEqual(result["source_time_rewinds"][0]["backward_steps"], 8)

    def test_actor_replacement_during_hidden_gap_does_reset_source_time(self):
        for reset in (False, True):
            with self.subTest(explicit_reset=reset):
                rows = [contract_frame(1, 20, 100),
                        contract_frame(2, -1, 100, "hidden", reset=reset, generation=1 if reset else 2),
                        contract_frame(3, 1, 90, generation=1 if reset else 2)]
                rows[1]["bodies"][0].update(selected=None, selected_screen=None)
                result = analyze(rows)["presentation_contract"]
                self.assertEqual(result["source_time_rewind_count"], 0)
                self.assertEqual(result["timeline_resets"], 1)

    def test_legacy_trace_does_not_claim_unrecorded_source_time_or_stage_cost(self):
        result = analyze([moving_frame(1,100,100,0),moving_frame(2,80,110,0)])["presentation_contract"]
        self.assertEqual(result["selected_step_observations"], 0)
        self.assertEqual(result["source_time_rewind_count"], 0)
        self.assertEqual(result["resolve_cpu_ms"]["count"], 0)

    def test_main_submission_intervals_and_missing_callback_indices_are_independent(self):
        result = analyze([contract_frame(1,20,100),contract_frame(4,21,101)])["presentation_contract"]
        self.assertEqual(result["main_submission_interval_ms"]["maximum"], 30)
        self.assertEqual(result["callbacks_without_observed_submission"], 2)
        self.assertEqual(result["resolve_cpu_ms"]["maximum"], .104)


if __name__=="__main__":
    unittest.main()
