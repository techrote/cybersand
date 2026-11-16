"""Challenge evidence admission rather than reproducing rendering implementation."""
import copy
from pathlib import Path
import unittest

import dispatch_broad
import package_windows
import run_campaign
import run_regressions


class QualificationTests(unittest.TestCase):
    def test_preparation_requires_real_mounted_hybrid_and_visible_setup_cost(self):
        prepared = {"prepared": True, "error": "", "runs": 1,
                    "initialization_usec": 10000, "total_initialization_usec": 10000}
        data = {"cohort": "mounted_native_workbench", "strategy": "hybrid", "setup_ms": 20,
                "shader_preparation": prepared, "shader_preparation_at_measurement": prepared}
        run_campaign.verify_shader_preparation(data)
        run_campaign.verify_shader_preparation(dict(data, strategy="full", shader_preparation={}, shader_preparation_at_measurement={}))
        run_campaign.verify_shader_preparation(dict(data, cohort="deterministic_renderer_seam", shader_preparation={}, shader_preparation_at_measurement={}))
        for bad in [dict(data, shader_preparation={}), dict(data, strategy="full"),
                    dict(data, setup_ms=9), dict(data, cohort="deterministic_renderer_seam"),
                    dict(data, shader_preparation_at_measurement={})]:
            with self.assertRaises(ValueError):
                run_campaign.verify_shader_preparation(bad)

    def test_only_exact_intentional_refusal_diagnostics_are_allowed(self):
        expected = run_regressions.REFUSAL_ERRORS
        log = "\n".join(expected)
        run_campaign.validate_process_errors(log, expected)
        run_campaign.validate_process_errors("ordinary output")
        bad_logs = [log + "\nERROR: extra driver failure", "\n".join(expected[:-1]),
                    log + "\n" + expected[0], log + "\nSCRIPT ERROR: unrelated",
                    log + "\nParse Error: invalid fixture", log + "\nFailed loading resource: absent"]
        for bad in bad_logs:
            with self.assertRaises(ValueError):
                run_campaign.validate_process_errors(bad, expected)
        with self.assertRaises(ValueError):
            run_campaign.validate_process_errors(log)

    def test_missing_duplicate_or_wrong_arms_refuse(self):
        cases = [run_campaign.CASES[0]]
        arms = [{"case": cases[0], "round": 0, "phase": index, "strategy": strategy}
                for index, strategy in enumerate(run_campaign.ORDER)]
        run_campaign.validate_complete_pairs(arms, cases, 1)
        for bad in [arms[:-1], arms + [arms[0]], [dict(a, strategy="full") for a in arms]]:
            with self.assertRaises(ValueError):
                run_campaign.validate_complete_pairs(bad, cases, 1)

    def test_empty_is_valid_only_for_correctness_only(self):
        run_campaign.validate_complete_pairs([], [], 2)
        with self.assertRaises(ValueError):
            run_campaign.validate_complete_pairs([], [run_campaign.CASES[0]], 2)

    def test_nearest_rank_and_nonfinite_refusal(self):
        data = run_campaign.summary(list(range(1, 101)))
        self.assertEqual((data["p50"], data["p95"], data["p99"], data["max"]), (50, 95, 99, 100))
        for value in [float("nan"), float("inf")]:
            with self.assertRaises(ValueError):
                run_campaign.summary([1, value])

    def test_full_and_reused_staging_submission_costs_are_included(self):
        full = {"texture_submit_usec": 1517, "source_create_usec": 0,
                "source_update_usec": 0, "blit_submit_usec": 0}
        reused = {"texture_submit_usec": 19, "source_create_usec": 7,
                  "source_update_usec": 43, "blit_submit_usec": 19}
        self.assertEqual(run_campaign.expected_submit_usec(full), 1517)
        self.assertEqual(run_campaign.expected_submit_usec(reused), 69)
        self.assertEqual(run_campaign.expected_submit_usec({"texture_update_usec": 200}), 200)
        for bad in [{}, {"texture_submit_usec": -1}, {"texture_submit_usec": float("nan")}]:
            with self.assertRaises(ValueError):
                run_campaign.expected_submit_usec(bad)
        sample = {"accepted": True, "metrics": full, "submit_ms": 1.517,
                  "render_serial": 4, "generation": 2, "transport_full_refresh": True}
        data = {"uploads": [sample, sample], "transport_full_publications": 1}
        run_campaign.verify_upload_accounting(data)
        for broken in [dict(data, transport_full_publications=2),
                       dict(data, uploads=[dict(sample, submit_ms=0)])]:
            with self.assertRaises(ValueError):
                run_campaign.verify_upload_accounting(broken)

    def test_source_inventory_does_not_hide_new_script(self):
        tracked = ["godot/scripts/main.gd"]
        paths, untracked = run_campaign.source_inventory(tracked, ["godot/scripts/main.gd.uid", "godot/scripts/new.gd"])
        self.assertIn("godot/scripts/new.gd", paths)
        self.assertEqual(untracked, ["godot/scripts/new.gd"])

    def test_native_capture_counts_are_derived_from_original_adapter_calls(self):
        totals = {"calls": 2, "forced_full_requests": 1, "nonempty_packets": 2,
                  "full_packets": 1, "logical_bytes": 2049, "capture_usec": 20}
        samples = [{"forced_full": True, "nonempty": True, "full_refresh": True,
                    "logical_bytes": 2048, "capture_usec": 11, "start_usec": 20, "end_usec": 31},
                   {"forced_full": False, "nonempty": True, "full_refresh": False,
                    "logical_bytes": 1, "capture_usec": 9, "start_usec": 40, "end_usec": 49}]
        data = {"cohort": "mounted_native_workbench", "native_full_refreshes": 1,
                "native_capture": {"before": {k: 0 for k in totals}, "after": totals,
                                   "delta": totals, "samples": samples, "dropped_samples": 0}}
        run_campaign.verify_native_capture_accounting(data)
        for key, value in [("native_full_refreshes", 2), ("native_capture", {})]:
            with self.assertRaises(ValueError):
                run_campaign.verify_native_capture_accounting(dict(data, **{key: value}))
        truncated = copy.deepcopy(data)
        truncated["native_capture"]["samples"].pop()
        with self.assertRaises(ValueError):
            run_campaign.verify_native_capture_accounting(truncated)

    def test_actor_tape_is_bound_to_completed_physics_steps(self):
        sample = {"tape_index": 60, "completed_step": 63, "accepted": True,
                  "move": [0, 0], "trim": 0, "effort": 0}
        data = {"workload": "actor", "initial_rapier_step": 3, "actor_input_samples": [sample]}
        run_campaign.verify_actor_input_tape(data)
        for broken in [dict(sample, completed_step=60), dict(sample, move=[0.2, -0.6]),
                       dict(sample, accepted=False)]:
            with self.assertRaises(ValueError):
                run_campaign.verify_actor_input_tape(dict(data, actor_input_samples=[broken]))

    def test_ack_faults_preserve_delay_and_require_recovery(self):
        request = {"serial": 9, "requested_usec": 100, "delivered_usec": 150100, "observed_usec": 150200}
        data = {"cohort": "mounted_native_workbench", "config": {"ack": "delayed150"},
                "ack_during_timing": {"mode": "delayed150", "requests": [request]},
                "ack_recovery_outside_timing": {"converged": True, "accepted_revision": 8,
                    "authoritative_revision": 8, "accepted_material_serial": 9,
                    "final": {"observed_serial": 9, "requests": [request]}}}
        run_campaign.verify_ack_observations(data)
        early = copy.deepcopy(data)
        early["ack_during_timing"]["requests"][0]["delivered_usec"] = 149999
        with self.assertRaises(ValueError):
            run_campaign.verify_ack_observations(early)
        missing = copy.deepcopy(data)
        missing["config"]["ack"] = "withheld"
        missing["ack_during_timing"] = {"mode": "withheld", "requests": [dict(request, delivered_usec=0, observed_usec=0)]}
        run_campaign.verify_ack_observations(missing)
        for bad in [dict(missing, ack_recovery_outside_timing={}),
                    dict(missing, ack_during_timing={"mode": "withheld", "requests": [request]})]:
            with self.assertRaises(ValueError):
                run_campaign.verify_ack_observations(bad)

    def test_declared_cases_unique_and_required_profiles_present(self):
        ids = [case["id"] for case in run_campaign.CASES]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue({512, 1024, 2048} <= {case["size"] for case in run_campaign.CASES})
        self.assertTrue({"pressure_flow_v1", "freemass_v1", "inertial_cellular_v1"}
                        <= {case["family"] for case in run_campaign.CASES})
        for item in run_campaign.CASES:
            self.assertTrue(item["channels"] == 2 or item["workload"] in run_campaign.SYNTHETIC_WORKLOADS)

    def test_windows_package_paths_refuse_traversal_and_reserved(self):
        package_windows.safe_path("godot/scripts/main.gd")
        for bad in ["../outside", "/absolute", "a\\b", "CON", "a./b", "a//b", "C:/file"]:
            with self.assertRaises(ValueError, msg=bad):
                package_windows.safe_path(bad)

    def test_dispatch_fenced_to_owned_branch_source_and_explicit_request(self):
        source = "a" * 40
        env = {"GITHUB_SHA": source, "GITHUB_REPOSITORY": dispatch_broad.REPOSITORY,
               "GITHUB_REF": "refs/heads/" + dispatch_broad.BRANCH, "GITHUB_EVENT_NAME": "push"}
        request = {"schema": 1, "branch": dispatch_broad.BRANCH, "dispatch_broad": True}
        dispatch_broad.request_admission(source, env, request)
        variants = [dict(env, GITHUB_SHA="b" * 40), dict(env, GITHUB_REF="refs/heads/main"),
                    dict(env, GITHUB_EVENT_NAME="pull_request"), dict(env, GITHUB_REPOSITORY="other/repo")]
        for variant in variants:
            with self.assertRaises(ValueError):
                dispatch_broad.request_admission(source, variant, request)
        with self.assertRaises(ValueError):
            dispatch_broad.request_admission(source, env, dict(request, dispatch_broad=False))


if __name__ == "__main__":
    unittest.main()
