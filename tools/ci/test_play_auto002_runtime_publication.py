#!/usr/bin/env python3
"""Adversarial source/request, PLAY receipt and repeated-campaign publication gates."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import lcb001_shared_contract_runtime_publication as historical
import play_auto002_runtime_publication as profile
from test_lcb001_shared_contract_runtime_publication import SUCCESS_LOGS

subject = profile.engine
REPOSITORY = subject.ROOT
BRANCH = "play-266-worker-matrix-20261027"
WORKFLOW = ".github/workflows/play-auto002-runtime-publication.yml"


def matrix():
    return {"assertions": 100, "failures": 0, "rows": 10,
            "requested_counts": [1, 2, 4, 6, 0], "distinct_actual_counts": [1, 2, 4],
            "logical_threads": 4, "auto_workers": 4, "parallel_participation_rows": 6,
            "participating_request": 0, "participating_actual_workers": 4,
            "maximum_workers_observed": 3, "worker_participation_ticks": 4,
            "participating_parallel_ticks": 5, "global_setting_before": 0,
            "global_setting_after": 0, "fixed_input_parity": True,
            "rendered_gameplay_fps_measured": False, "causal_speedup_claimed": False,
            "per_worker_utilization_measured": False, "player_world_reconfigured": False}


def auto_host():
    return {"assertions": 15, "failures": 0, "requested_setting": 0,
            "logical_processors": 4, "auto_policy_workers": 4, "actual_worker_capacity": 4,
            "native_ticks_observed": 30, "last_native_tick": 50, "rapier_tick": 40,
            "maximum_scheduler_jobs": 1, "maximum_parallel_phases": 0,
            "backend": "native-phased", "terrain_ready": True,
            "native_auto_source": "CyberNativeCellWorld::create_world",
            "route": "existing-CyberSimulationWorker+main-Rapier",
            "parallel_speedup_proven": False, "rendered_fps_measured": False,
            "gamepad_qualified": False}


def course():
    return {"assertions": 126, "failures": 0, "mechanical_presets": 5,
            "route": "existing-CyberSimulationWorker+main-Rapier", "swarm_qualified": False,
            "gamepad_qualified": False, "frame_pacing_measured": False,
            "parallel_speedup_proven": False}


def course_liquid():
    return {"policy_hash": "a" * 64, "native_receipt": "b" * 64,
            "recipe_hash": "c" * 64, "initial_generation": 8,
            "applied_generation": 9, "reset_generation": 10,
            "switched_actor": "acrobat", "selected_water_family": "pressure_flow_v1",
            "real_frame_pacing_measured": False}


def line(prefix, value):
    return prefix + " " + json.dumps(value) + "\n"


def course_log(value=None, liquid=None, rigs=None):
    if rigs is None:
        rigs = [{"rig": name, "physics_tick": 40, "native_tick": 30,
                 "resolved_native_workers": 4, "terrain_ready": True}
                for name in ("stuntbuggy", "trialsbike", "acrobat", "arcadelander", "jetbarrel")]
    return ("".join(line("PLAY_COMP002_RIG", row) for row in rigs)
            + line("PLAY_COMP002_LIQUID", course_liquid() if liquid is None else liquid)
            + line("PLAY_COMP002_RESULT", course() if value is None else value))


def success_logs():
    return {"import": "import complete\n",
            "test_worker_benchmark": line("PLAY_AUTO002_RESULT", matrix()),
            "test_microscenario_native_observation": SUCCESS_LOGS["test_microscenario_native_observation"],
            "test_play_auto001_shared_course": line("PLAY_AUTO001_RESULT", auto_host()),
            "test_play_comp002_five_rig_course": course_log(),
            "test_liquid_solver_policy": SUCCESS_LOGS["test_liquid_solver_policy"],
            "test_liquid_policy_worker": SUCCESS_LOGS["test_liquid_policy_worker"]}


class ProfileTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "PLAY publication fixture")
        self.git("config", "user.email", "play-fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        for relative in (subject.REQUEST, subject.EVIDENCE, *(
                "godot/tests/" + name + ".gd" for name in subject.CASE_MARKERS)):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1))
                            if relative == subject.REQUEST else "fixture\n", encoding="utf-8")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Fixture")
        self.source = self.git("rev-parse", "HEAD").strip()
        patch = mock.patch.object(subject, "ROOT", self.root)
        patch.start(); self.addCleanup(patch.stop)
        patch = mock.patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + BRANCH,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + WORKFLOW + "@refs/heads/" + BRANCH,
            "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1",
        })
        patch.start(); self.addCleanup(patch.stop)
        self.report = {"results": [], "log_sha256": {}}
        for name, output in success_logs().items():
            self.log(name, output)
            self.report["results"].append({"name": name, "status": "passed", "returncode": 0,
                "diagnostic_error": False, "launch_error": None, "skip_messages": []})

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True,
                                       stderr=subprocess.PIPE)

    def log(self, name, output):
        path = self.root / (name + ".log")
        path.write_bytes(output.encode())
        self.report["log_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()

    def test_profile_does_not_repurpose_historical_lcb_request_or_engine(self):
        self.assertEqual(historical.BRANCH, "codex/lcb001-shared-contract")
        self.assertEqual(historical.BUNDLE_PREFIX, "lcb001-shared-contract-runtime")
        self.assertEqual(set(historical.CASE_MARKERS), set(SUCCESS_LOGS))
        self.assertEqual(subject.BRANCH, BRANCH)
        self.assertEqual(subject.WORKFLOW, WORKFLOW)
        self.assertEqual(subject.BUNDLE_PREFIX, "play-auto002-runtime")
        self.assertNotIn(historical.REQUEST, subject.BUILD_EXACT)

    def test_exact_context_and_fresh_committed_request_pass(self):
        self.assertEqual(subject.context(self.source)["source_commit"], self.source)
        subject.require_publication_request(self.source)

    def test_other_repository_branch_workflow_event_head_or_attempt_refuse(self):
        for key, value in {"GITHUB_REPOSITORY": "other/cybersand", "GITHUB_REF": "refs/heads/main",
                           "GITHUB_WORKFLOW_REF": "techrote/cybersand/other.yml@refs/heads/" + BRANCH,
                           "GITHUB_EVENT_NAME": "pull_request", "GITHUB_SHA": "f" * 40,
                           "GITHUB_RUN_ATTEMPT": "0"}.items():
            with self.subTest(key=key), mock.patch.dict(os.environ, {key: value}):
                with self.assertRaises(RuntimeError): subject.context(self.source)

    def test_unarmed_request_refuses_before_remote_lease_or_expensive_work(self):
        (self.root / subject.REQUEST).unlink()
        with mock.patch.object(subject, "git", wraps=subject.git) as git:
            with self.assertRaisesRegex(RuntimeError, "Missing explicit"):
                subject.check_source(argparse.Namespace(source_sha=self.source))
            self.assertFalse(any(call.args[0] == "ls-remote" for call in git.call_args_list))

    def test_historical_incomplete_typed_or_zero_requests_cannot_arm(self):
        requests = [dict(historical.REQUEST_VALUE, request_sequence=1),
                    dict(subject.REQUEST_VALUE, scope="worker-count-only", request_sequence=1),
                    dict(subject.REQUEST_VALUE, request_sequence=True),
                    dict(subject.REQUEST_VALUE, request_sequence=0),
                    dict(subject.REQUEST_VALUE, request_sequence=1, extra=True)]
        for request in requests:
            path = self.root / subject.REQUEST
            path.write_text(json.dumps(request), encoding="utf-8")
            self.git("add", "."); self.git("commit", "--quiet", "--allow-empty", "-m", "Wrong request")
            with self.assertRaisesRegex(RuntimeError, "Invalid shared-contract publish request"):
                subject.require_publication_request(self.git("rev-parse", "HEAD").strip())

    def test_missing_native_or_host_control_cannot_arm(self):
        for name in subject.CASE_MARKERS:
            path = self.root / "godot/tests" / (name + ".gd")
            path.unlink()
            with self.assertRaisesRegex(RuntimeError, "regression is not implemented"):
                subject.require_publication_request(self.source)
            path.write_text("fixture\n", encoding="utf-8")

    def test_all_six_complete_cases_and_actual_host_receipts_pass(self):
        self.assertEqual(list(subject.CASE_MARKERS), list(success_logs())[1:])
        subject.verify_case_results(self.root, self.report)

    def test_each_missing_or_duplicate_case_refuses(self):
        original = self.report["results"]
        for row in original:
            for rows in ([r for r in original if r is not row], [*original, row]):
                self.report["results"] = rows
                with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
                    subject.verify_case_results(self.root, self.report)
        self.report["results"] = original

    def test_digest_crash_skip_error_zero_or_duplicate_summary_refuses(self):
        for name, original in success_logs().items():
            if name == "import": continue
            for text in (original + "ERROR: native fault\n", original + "SKIP required arm\n",
                         original + original, original.replace('"assertions": 100', '"assertions": 0'),
                         original.replace("100 assertions", "0 assertions")):
                if text == original: continue
                self.log(name, text)
                with self.subTest(name=name), self.assertRaises(RuntimeError):
                    subject.verify_case_results(self.root, self.report)
            self.log(name, original)
            path = self.root / (name + ".log"); path.write_text("tampered\n", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "Execution log digest mismatch"):
                subject.verify_case_results(self.root, self.report)
            self.log(name, original)
        row = self.report["results"][1]; row["returncode"] = 0xC0000005
        with self.assertRaisesRegex(RuntimeError, "Non-passing execution record"):
            subject.verify_case_results(self.root, self.report)

    def test_worker_matrix_rejects_config_only_missing_parity_and_overclaims(self):
        mutations = {"rows": 9, "requested_counts": [1, 2, 4, 6], "distinct_actual_counts": [1, True, 4],
                     "logical_threads": 0, "auto_workers": False, "global_setting_after": 1,
                     "parallel_participation_rows": 0, "participating_request": 1,
                     "participating_actual_workers": 1, "maximum_workers_observed": 1,
                     "worker_participation_ticks": 0, "participating_parallel_ticks": 0,
                     "fixed_input_parity": None, "rendered_gameplay_fps_measured": True,
                     "causal_speedup_claimed": True, "per_worker_utilization_measured": 0,
                     "player_world_reconfigured": True}
        for key, replacement in mutations.items():
            value = matrix(); value[key] = replacement
            self.log("test_worker_benchmark", line("PLAY_AUTO002_RESULT", value))
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)
        value = matrix(); value["maximum_workers_observed"] = 5
        with self.assertRaises(RuntimeError): profile.verify_worker_matrix(value)

    def test_single_actual_count_discloses_unavailable_parity(self):
        value = matrix()
        value.update(distinct_actual_counts=[1], fixed_input_parity=None, parallel_participation_rows=0,
                     participating_request=None, participating_actual_workers=None,
                     maximum_workers_observed=0, worker_participation_ticks=0, participating_parallel_ticks=0)
        profile.verify_worker_matrix(value)
        for key, replacement in (("fixed_input_parity", True), ("parallel_participation_rows", 1),
                                 ("maximum_workers_observed", 2)):
            changed = dict(value); changed[key] = replacement
            with self.assertRaises(RuntimeError): profile.verify_worker_matrix(changed)

    def test_actual_auto_host_not_capacity_only_or_fallback(self):
        for key, replacement in (("requested_setting", 1), ("actual_worker_capacity", 1),
                                 ("native_ticks_observed", 0), ("rapier_tick", 0),
                                 ("terrain_ready", 1), ("backend", "gdscript-serial-fallback"),
                                 ("route", "model-only"), ("parallel_speedup_proven", True)):
            value = auto_host(); value[key] = replacement
            with self.subTest(key=key), self.assertRaises(RuntimeError): profile.verify_auto_host(value)

    def test_all_five_real_rigs_and_constructor_reset_receipts_required(self):
        original = success_logs()["test_play_comp002_five_rig_course"]
        for key, replacement in (("policy_hash", ""), ("recipe_hash", "bad"),
                                 ("applied_generation", 8), ("reset_generation", 9),
                                 ("switched_actor", "stuntbuggy"), ("selected_water_family", "freemass_v1"),
                                 ("real_frame_pacing_measured", True)):
            liquid = course_liquid(); liquid[key] = replacement
            self.log("test_play_comp002_five_rig_course", course_log(liquid=liquid))
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)
        self.log("test_play_comp002_five_rig_course", original.replace('"rig": "acrobat"', '"rig": "model"'))
        with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_duplicate_json_fields_or_malformed_object_refuse(self):
        original = success_logs()["test_worker_benchmark"]
        for output in (original.replace('"rows": 10', '"rows": 0, "rows": 10'),
                       "PLAY_AUTO002_RESULT {broken}\n", "PLAY_AUTO002_RESULT []\n"):
            self.log("test_worker_benchmark", output)
            with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_scoped_cases_preserve_flags_and_original_180_second_bounds(self):
        discovered = {name: subject.runner.Case(name, ("--script", "res://tests/" + name + ".gd"), 180, 5.0)
                      for name in subject.CASE_MARKERS}
        cases = subject.focused_cases(discovered)
        self.assertEqual(cases[0].timeout, 240)
        for case in cases[1:]:
            self.assertEqual(case.timeout, 180)
            self.assertEqual(case.flags, discovered[case.name].flags)

    def test_campaign_digest_target_runtime_source_and_inputs_are_bound(self):
        path = self.root / "campaign/campaign.json"; path.parent.mkdir()
        path.write_bytes(b"{}\n")
        manifest = {"campaign_report": "campaign/campaign.json",
                    "campaign_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "artifact": subject.RUNTIMES["linux"], "sha256": "a" * 64, "size": 1234,
                    "source_tree": "b" * 40, "source_inputs": {"native/src/world.cpp": "c" * 64},
                    "build_inputs": {"tools/play/run_auto_campaign.py": "d" * 64}}
        report = {"platform": "linux", "source_tree": manifest["source_tree"],
                  "native_runtime": {"path": manifest["artifact"], "sha256": manifest["sha256"], "size": 1234},
                  "native_inputs": manifest["source_inputs"],
                  "tested_inputs": {"tools/play/run_auto_campaign.py": "d" * 64}}
        module = mock.Mock(); module.verify_directory.return_value = report
        with mock.patch.object(profile, "campaign_module", return_value=module):
            profile.verify_campaign(self.root, "linux", self.source, manifest)
            module.verify_directory.assert_called_with(path.parent, expected_source_sha=self.source)
            for key, value in (("platform", "windows"), ("source_tree", "f" * 40),
                               ("native_inputs", {}), ("tested_inputs", {"unbound": "d" * 64}),
                               ("native_runtime", dict(report["native_runtime"], sha256="f" * 64))):
                changed = copy.deepcopy(report); changed[key] = value
                module.verify_directory.return_value = changed
                with self.subTest(key=key), self.assertRaises(RuntimeError):
                    profile.verify_campaign(self.root, "linux", self.source, manifest)
        changed = dict(manifest, campaign_sha256="f" * 64)
        with self.assertRaisesRegex(RuntimeError, "digest mismatch"):
            profile.verify_campaign(self.root, "linux", self.source, changed)

    def test_failed_campaign_preserves_failure_manifest_and_cannot_publish(self):
        path = subject.manifest_path(self.root, "linux")
        path.write_text(json.dumps({"status": "validated-development-runtime"}), encoding="utf-8")
        args = argparse.Namespace(platform="linux", bundle=self.root, source_sha=self.source,
                                  godot_archive=self.root / "godot-linux.zip")
        with mock.patch.object(profile, "_execute"), mock.patch.object(profile.subprocess, "run", side_effect=RuntimeError("fixture campaign failure")):
            with self.assertRaisesRegex(RuntimeError, "fixture campaign failure"): profile.execute(args)
        failed = json.loads(path.read_text())
        self.assertEqual(failed["status"], "campaign-failed")
        self.assertIn("fixture campaign failure", failed["campaign_error"])
        self.assertFalse(profile._collecting_campaign)


class WorkflowTests(unittest.TestCase):
    def test_only_explicit_branch_request_can_build_and_only_four_paths_can_append(self):
        text = (REPOSITORY / WORKFLOW).read_text(encoding="utf-8")
        self.assertIn("branches: [" + BRANCH + "]", text)
        self.assertIn("echo 'armed=false'", text)
        self.assertNotIn("workflow_dispatch:", text)
        self.assertIn("needs.admission.outputs.armed == 'true'", text)
        self.assertIn("runs-on: windows-2022", text)
        self.assertIn("runs-on: ubuntu-24.04", text)
        self.assertEqual(text.count("contents: write"), 1)
        self.assertIn('test "$(git rev-list --parents -n 1 HEAD)" = "$(git rev-parse HEAD) $GITHUB_SHA"', text)
        self.assertIn('git push --force-with-lease="refs/heads/' + BRANCH + ':$GITHUB_SHA" origin HEAD:refs/heads/' + BRANCH, text)
        self.assertIn("check-index --source-sha", text)
        self.assertIn("git add -- " + " ".join([*subject.RUNTIMES.values(), *subject.MANIFESTS.values()]), text)
        self.assertIn("tools/ci/test_lcb001_shared_contract_runtime_publication.py", text)

    def test_publication_ledger_binds_campaign_and_profile_implementation(self):
        for path in (WORKFLOW, subject.REQUEST, "tools/ci/play_auto002_runtime_publication.py",
                     "tools/ci/test_play_auto002_runtime_publication.py", "tools/play/run_auto_campaign.py",
                     "tools/play/test_run_auto_campaign.py"):
            self.assertIn(path, subject.BUILD_EXACT)


if __name__ == "__main__":
    unittest.main()
