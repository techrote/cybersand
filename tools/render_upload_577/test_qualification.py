"""Challenge evidence admission rather than reproducing rendering implementation."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import dispatch_broad
import package_windows
import run_campaign
import run_regressions
from health_validation_cases import validation_cases
from health_qualification import HEALTH_ERROR, NATIVE_ERROR, verify_failure_control


class QualificationTests(unittest.TestCase):
    def test_all_five_gpu_fixtures_remain_in_the_dedicated_graphical_gate(self):
        scripts = [case[1] for case in run_regressions.CASES]
        for script in ("test_material_upload_hybrid.gd", "test_render_upload_577_ack_graphical.gd",
                       "test_render_upload_577_preparation_lifecycle.gd",
                       "test_render_upload_577_queued_history.gd", "test_render_upload_577_refusal.gd"):
            self.assertEqual(scripts.count(script), 1)

    def test_helper_history_requires_both_complete_temporal_corpora_and_original_copy_shader(self):
        digest = "a" * 64
        records = []
        for label in run_regressions.helper_history_record_labels():
            if label.endswith((" current", " previous", "source remains immutable")):
                records.append({"case": label, "equal": True,
                                "actual_sha256": digest, "expected_sha256": digest})
            else:
                records.append({"case": label, "metrics": {"mode": "compact_full"}})
        shader_digest = run_campaign.sha(run_campaign.ROOT / "godot/shaders/material_upload_copy.gdshader")
        data = {"schema": "material-upload-hybrid-correctness-v1", "ok": True, "checks": 1514,
                "failures": [], "records": records, "context": {"shader": {
                    "source_bound": True, "source_file_bound": True,
                    "source_path": "res://shaders/material_upload_copy.gdshader",
                    "source_file_sha256": shader_digest, "source_sha256": shader_digest,
                    "variant_sha256": shader_digest}}}
        run_regressions.verify_helper_history(data)
        mutations = [lambda d: d.update(checks=1513), lambda d: d["records"].pop(),
                     lambda d: d["records"].append(copy.deepcopy(d["records"][-1])),
                     lambda d: d["records"].reverse(),
                     lambda d: d.update(records=[r for r in d["records"] if r["case"].startswith("R8 ")]),
                     lambda d: d["records"][0].update(equal=False),
                     lambda d: d["records"][0].update(actual_sha256="b" * 64),
                     lambda d: d["records"][0].update(actual_sha256="", expected_sha256=""),
                     lambda d: d["records"].__setitem__(0, {"case": d["records"][0]["case"], "metrics": {"mode": "compact_full"}}),
                     lambda d: d["records"][0].update(metrics={"mode": "compact_full"}),
                     lambda d: d["records"][4].update(metrics=[]),
                     lambda d: d["records"][4]["metrics"].update(mode="unknown"),
                     lambda d: d["context"]["shader"].update(source_bound=False),
                     lambda d: d["context"]["shader"].update(source_sha256="b" * 64)]
        for mutation in mutations:
            bad = copy.deepcopy(data)
            mutation(bad)
            with self.assertRaises(ValueError):
                run_regressions.verify_helper_history(bad)

    def test_original_native_health_rejects_failures_even_when_outer_success_is_forged(self):
        for case in validation_cases():
            with self.subTest(case=case["name"]):
                def verify():
                    if "expected_case" in case:
                        run_campaign.verify_requested_case(case["receipt"], case["expected_case"], case["expected_strategy"])
                    run_campaign.verify_native_health(case["receipt"])
                if case["accepted"]:
                    verify()
                else:
                    with self.assertRaises(ValueError):
                        verify()

    def test_executable_legacy_negative_requires_original_native_failure_identity(self):
        receipt = copy.deepcopy(validation_cases()[0]["receipt"])
        receipt.update(ok=False, failures=[HEALTH_ERROR], config={"frames": 400})
        failed = receipt["frames"][-1]["native_health"]
        failed.update(healthy=False, worker_has_failed=True, reasons=["worker_has_failed"])
        failed["worker_snapshot"].update(simulation_failed=True, failed_tick_index=24, tick_failure_count=1,
                                         last_tick_error=NATIVE_ERROR, tick_index=23)
        receipt["native_health"].update(first_failure=copy.deepcopy(failed), failure_observations=3,
                                        final=copy.deepcopy(failed))
        verify_failure_control(receipt)
        for key, value in [("failed_tick_index", 25), ("tick_failure_count", 0),
                           ("last_tick_error", "another failure"), ("tick_index", 24)]:
            broken = copy.deepcopy(receipt)
            broken["native_health"]["first_failure"]["worker_snapshot"][key] = value
            with self.subTest(field=key), self.assertRaises(ValueError):
                verify_failure_control(broken)
        with self.assertRaises(ValueError):
            verify_failure_control(dict(receipt, ok=True))

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
        data = {"workload": "actor", "initial_rapier_step": 3, "actor_input_samples": [sample],
                "frames": [{"rapier_step": 3}, {"rapier_step": 63}]}
        run_campaign.verify_actor_input_tape(data)
        for broken in [dict(sample, completed_step=60), dict(sample, move=[0.2, -0.6]),
                       dict(sample, accepted=False)]:
            with self.assertRaises(ValueError):
                run_campaign.verify_actor_input_tape(dict(data, actor_input_samples=[broken]))
        with self.assertRaises(ValueError):
            run_campaign.verify_actor_input_tape(dict(data, frames=[{"rapier_step": 3}]))

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
        self.assertTrue(all(case["fixture"] == "pressure_dam_v1" for case in run_campaign.CASES
                            if case["family"] == "pressure_flow_v1"))
        self.assertFalse(any(case["fixture"] == "legacy_scatter_v1" for case in run_campaign.CASES))
        for item in run_campaign.CASES:
            self.assertTrue(item["channels"] == 2 or item["workload"] in run_campaign.SYNTHETIC_WORKLOADS)

    def test_windows_package_paths_refuse_traversal_and_reserved(self):
        package_windows.safe_path("godot/scripts/main.gd")
        for bad in ["../outside", "/absolute", "a\\b", "CON", "a./b", "a//b", "C:/file"]:
            with self.assertRaises(ValueError, msg=bad):
                package_windows.safe_path(bad)

    def test_fresh_source_archive_ships_and_requires_installed_health_validator(self):
        # Exercise real Git archive staging into an isolated mini repository.
        # An internally consistent manifest must still reject a missing runtime
        # dependency of the installed PowerShell entry.
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            repo = base / "source"
            repo.mkdir()
            files = {path: b"\n" for path in package_windows.BOOTSTRAP}
            for path in ("examples/worldgen/gen007-deepworks.json", "examples/worldgen/gen007-qualification.json",
                         "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
                         "third_party/rapier-bvh-build.lock.json"):
                files[path] = b"{}\n"
            files.update({"THIRD_PARTY_NOTICES.md": b"Test only\n", "LICENSE_STATUS.md": b"Test only\n",
                          package_windows.NATIVE: b"unit-test native bytes", package_windows.RAPIER: b"unit-test Rapier bytes"})
            for name in ("Test-It.ps1", "Validate-Health.ps1"):
                files["tools/render_upload_577/" + name] = (package_windows.ROOT / "tools/render_upload_577" / name).read_bytes()
            for name, value in files.items():
                path = repo / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(value)
            def git(*args):
                return subprocess.check_output(["git", "-C", str(repo), "-c", "core.autocrlf=false", *args], stderr=subprocess.PIPE)
            git("init", "-q")
            git("add", ".")
            git("-c", "user.name=Qualification", "-c", "user.email=qualification@example.invalid", "commit", "-qm", "fixture")
            source = git("rev-parse", "HEAD").decode().strip()
            identity = {"source_commit": source,
                        "native": {"source_inputs": {}, "artifact": package_windows.NATIVE,
                                   "sha256": package_windows.digest(repo / package_windows.NATIVE)},
                        "rapier": {"source_inputs": {}, "artifact": package_windows.RAPIER,
                                   "sha256": package_windows.digest(repo / package_windows.RAPIER)}}
            output = base / "installed"
            output.mkdir()
            with patch.object(package_windows, "ROOT", repo):
                package_windows.stage_source(output, identity)
                for name in ("Test-It.ps1", "Validate-Health.ps1"):
                    self.assertTrue((output / "tools/render_upload_577" / name).is_file())
                manifest = dict(identity, schema="render-upload-577-windows-v1", files_sha256=package_windows.files_map(output))
                manifest_path = output / package_windows.MANIFEST
                manifest_path.write_text(json.dumps(manifest))
                package_windows.verify(output, source)
                (output / "tools/render_upload_577/Validate-Health.ps1").unlink()
                manifest["files_sha256"] = package_windows.files_map(output)
                manifest_path.write_text(json.dumps(manifest))
                with self.assertRaisesRegex(ValueError, "health validator"):
                    package_windows.verify(output, source)

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
