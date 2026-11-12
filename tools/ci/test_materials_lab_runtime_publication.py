#!/usr/bin/env python3
"""Adverse evidence and branch-lease controls for the Materials Lab publisher."""
import argparse
import copy
import inspect
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import materials_lab_runtime_publication as subject
import lcb001_shared_contract_runtime_publication as baseline

engine = subject.engine


class PublicationTests(unittest.TestCase):
    def test_existing_four_path_engine_is_private_and_unchanged(self):
        self.assertIsNot(engine, baseline)
        self.assertEqual(engine.BRANCH, "codex/materials-lab-v1-20261111")
        for name in ("context", "require_publication_request", "check_source", "check_index", "input_ledgers",
                     "runtime_identity", "record_build", "execute", "stage", "verify_bundle"):
            self.assertEqual(inspect.getsource(getattr(engine, name)), inspect.getsource(getattr(baseline, name)))
        self.assertNotIn(baseline.WORKFLOW, engine.BUILD_EXACT)
        self.assertNotIn(baseline.REQUEST, engine.BUILD_EXACT)

    def test_scope_includes_real_authoring_diagnostics_and_graphical_source(self):
        self.assertEqual(set(engine.CASE_MARKERS), {
            "test_material_lab_catalogue", "test_material_lab_experiment", "test_material_lab_diagnostics",
            "test_material_lab_service", "test_material_lab_ui", "test_material_lab_world", "test_workbench_canvas"})
        for path in (engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
                     "tools/ci/materials_lab_runtime_publication.py", "tools/ci/test_materials_lab_runtime_publication.py",
                     "tools/package_materials_lab_candidate.py", "tools/ci/test_materials_lab_package.py"):
            self.assertIn(path, engine.BUILD_EXACT)
        self.assertIn("tools/material_catalogue/world_candidate.py", engine.BUILD_EXACT)
        self.assertIn("materials/catalogue/compatibility-lock.json", engine.BUILD_EXACT)

    @staticmethod
    def suite(platform="linux"):
        names = [*subject.WINDOWS_SKIPS, *sorted(subject.PROCESS_OWNER_CASES),
                 *("fixture.test_%03d" % i for i in range(199))]
        return {"inventory": names, "tests_run": len(names), "failures": [], "errors": [],
                "expected_failures": [], "unexpected_successes": [],
                "skipped": dict(subject.WINDOWS_SKIPS) if platform == "windows" else {}}

    def test_complete_suite_and_only_explicit_platform_skips(self):
        for platform in ("linux", "windows"):
            subject.verify_suite_record(self.suite(platform), platform)
        for mutation in ("short", "duplicate", "failed", "skip", "partial", "owner_omitted"):
            value = self.suite()
            if mutation == "short": value["inventory"].pop(); value["tests_run"] -= 1
            if mutation == "duplicate": value["inventory"][-1] = value["inventory"][0]
            if mutation == "failed": value["failures"] = [value["inventory"][0]]
            if mutation == "skip": value["skipped"] = {value["inventory"][0]: "compiler unavailable"}
            if mutation == "partial": value["tests_run"] -= 1
            if mutation == "owner_omitted":
                value["inventory"][value["inventory"].index(sorted(subject.PROCESS_OWNER_CASES)[0])] = "fixture.unrelated_test"
            with self.subTest(mutation=mutation), self.assertRaises(RuntimeError):
                subject.verify_suite_record(value, "linux")

    def fixture(self, directory):
        source = {"digest": "1" * 64, "lf_sha256": {"native/source.cpp": "2" * 64}}
        report = {"platform": "windows", "status": "passed", "completed": True, "native_sha256": "a" * 64,
                  "results": [], "files_sha256": {}}
        for name, (manifest_name, image_name, receipt_name) in subject.GRAPHICAL_CASES.items():
            capture = directory / "graphical" / name
            capture.mkdir(parents=True)
            image = capture / image_name
            image.write_bytes(b"\x89PNG\r\n\x1a\nfixture")
            manifest = {"platform": "Windows", "display": "windows", "failures": 0, "runtime_active": False,
                        "native_library_sha256": "a" * 64, "image_sha256": engine.runner.sha256(image),
                        "native_source_identity": source, "candidate_digest": "c" * 64, "source_sha256": {}}
            scripts = {"scripts/material_lab_" + leaf + ".gd" for leaf in
                       ("screen", "panel", "world_panel", "service", "catalogue", "experiment")}
            scripts.add("tests/" + name + ".gd")
            if name == "test_material_lab_ui": scripts.add("scripts/shared_workbench.gd")
            manifest["source_sha256"] = {p: engine.runner.sha256(engine.ROOT / "godot" / p) for p in scripts}
            receipt = {"schema_id": "cybersand.material-lab.world-receipt", "runtime_active": False,
                       "source_identity": source, "candidate_digest": "c" * 64,
                       "checks": {key: True for key in ("source_unchanged", "candidate_qualification", "reference_qualification")},
                       "candidate": {"world_simulation": True, "checks": dict.fromkeys(subject.WORLD_CHECKS, True)},
                       "reference": {"checks": dict.fromkeys(subject.WORLD_CHECKS, True)}}
            engine.write_json(capture / manifest_name, manifest)
            engine.write_json(capture / receipt_name, receipt)
            log = directory / "graphical" / (name + ".log")
            log.write_text("MATERIAL_LAB_UI: 189 assertions; 0 failures; artifacts=fixture\n" if name.endswith("_ui")
                           else "Materials Lab World UI: 100 checks, 0 failures\n")
            report["results"].append({"name": name, "status": "passed", "returncode": 0,
                "natural_completion": True, "requires_display": True, "skip_messages": [],
                "diagnostic_error": False, "launch_error": None, "log_sha256": engine.runner.sha256(log),
                "command": ["godot", "--rendering-driver", "opengl3_angle", "--max-fps", "15", "--script", name]})
        self.refresh_map(directory, report)
        return report, source

    @staticmethod
    def refresh_map(directory, report):
        report["files_sha256"] = {p.relative_to(directory).as_posix(): engine.runner.sha256(p)
                                  for p in (directory / "graphical").rglob("*") if p.is_file()}
        engine.write_json(directory / "graphical.json", report)

    def test_graphical_evidence_requires_native_world_source_backend_and_every_oracle(self):
        modes = ("positive", "headless", "driver", "missing_driver_value", "missing_case", "no_worker_check", "failed_quantity", "source", "image", "omitted_inventory",
                 "missing_fps", "unbounded_fps", "changed_fps", "duplicate_fps", "user_argument_fps", "alternate_fps", "omitted_workbench_source")
        for mode in modes:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                report, source = self.fixture(directory)
                capture = directory / "graphical/test_material_lab_ui"
                path = capture / "effects-ui-world-receipt.json"
                receipt = subject.read_json(path)
                if mode == "headless": report["results"][0]["command"].append("--headless")
                if mode == "driver": report["results"][0]["command"][2] = "opengl3"
                if mode == "missing_driver_value": report["results"][0]["command"] = ["godot", "--rendering-driver"]
                if mode == "missing_case": report["results"].pop()
                if mode == "no_worker_check": receipt["candidate"]["checks"].pop("worker_1_4_equal")
                if mode == "failed_quantity": receipt["candidate"]["checks"]["quantity_balanced"] = False
                if mode == "source": source = {"digest": "3" * 64, "lf_sha256": {}}
                command = report["results"][0]["command"]
                if mode == "missing_fps": del command[3:5]
                if mode == "unbounded_fps": command[4] = "0"
                if mode == "changed_fps": command[4] = "60"
                if mode == "duplicate_fps": command.extend(("--max-fps", "0"))
                if mode == "user_argument_fps": command.insert(3, "--")
                if mode == "alternate_fps": command.append("--max-fps=0")
                if mode == "omitted_workbench_source":
                    manifest_path = capture / "effects-ui-capture-manifest.json"
                    manifest = subject.read_json(manifest_path)
                    manifest["source_sha256"].pop("scripts/shared_workbench.gd")
                    engine.write_json(manifest_path, manifest)
                engine.write_json(path, receipt)
                self.refresh_map(directory, report)
                if mode == "image": (capture / "08-kept-salt-world.png").write_bytes(b"different")
                if mode == "omitted_inventory":
                    report["files_sha256"].pop(next(iter(report["files_sha256"])))
                    engine.write_json(directory / "graphical.json", report)
                with patch.object(subject, "current_world_source", return_value=source):
                    if mode == "positive": subject.verify_capture(directory, "windows", "a" * 64)
                    else:
                        with self.assertRaises(RuntimeError): subject.verify_capture(directory, "windows", "a" * 64)

    def test_capture_commands_bound_only_graphical_redraws_without_changing_budgets(self):
        for platform, driver, system in (("windows", "opengl3_angle", "win32"), ("linux", "opengl3", "linux")):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as temporary:
                capture = Path(temporary) / "capture"
                case = subject.graphical_case("test_material_lab_world", capture, platform)
                command = engine.runner.case_command("qualified-godot", case, system)
                self.assertTrue(case.requires_display)
                self.assertNotIn("--headless", command)
                self.assertEqual(command.count("--max-fps"), 1)
                self.assertEqual(command[command.index("--max-fps") + 1], "15")
                self.assertLess(command.index("--max-fps"), command.index("--"))
                self.assertEqual(command[command.index("--rendering-driver") + 1], driver)
                self.assertEqual(case.timeout, subject.execution_policy.watchdog_seconds("graphical_case_seconds"))
                self.assertIn("--capture-output=" + str(capture.resolve()), command)
                self.assertFalse(capture.exists())
        self.assertEqual(engine.CASE_TIMEOUTS, {})

    def test_profile_permissions_and_trigger_scope_are_bounded(self):
        workflow = (engine.ROOT / engine.WORKFLOW).read_text()
        self.assertEqual(workflow.count("actions: write"), 1)
        self.assertEqual(workflow.count("contents: write"), 1)
        self.assertIn("needs: [linux, windows-execution, windows-package]", workflow)
        self.assertIn("refs/heads/" + engine.BRANCH, workflow)
        self.assertIn('git push --force-with-lease="refs/heads/' + engine.BRANCH + ':$GITHUB_SHA"', workflow)
        self.assertNotIn("pull_request_target", workflow)
        self.assertNotIn("schedule:", workflow)
        self.assertNotIn("ready_for_review]", workflow)
        self.assertEqual(subject.DISPATCH_WORKFLOWS,
                         ("documentation.yml", "native.yml", "gdextension.yml", "palette-shader-qualification.yml"))

    @staticmethod
    def dispatch_environment(source):
        return {"GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
                "GITHUB_REF": "refs/heads/" + engine.BRANCH, "GITHUB_SHA": source,
                "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + engine.WORKFLOW + "@refs/heads/" + engine.BRANCH,
                "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "1", "GITHUB_TOKEN": "fixture-token"}

    def test_dispatch_refuses_nonpublication_parent_before_any_api_call(self):
        source, published = "1" * 40, "2" * 40
        environment = self.dispatch_environment(source)
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, environment), \
             patch.object(engine, "git", side_effect=[published.encode(), (published + " " + "3" * 40).encode()]), \
             patch.object(subject.urllib.request, "urlopen") as request:
            with self.assertRaisesRegex(RuntimeError, "single-parent"):
                subject.dispatch_existing(argparse.Namespace(source_sha=source, published_sha=published,
                                                              output=Path(temporary) / "receipt.json"))
            request.assert_not_called()

    def test_dispatch_requires_leased_four_path_child_and_records_requests_without_claiming_success(self):
        source, published = "1" * 40, "2" * 40
        for mode in ("positive", "extra_path", "missing_manifest", "unarmed", "no_token", "wrong_run",
                     "stale_before", "stale_after", "rejected", "existing_receipt"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                environment = self.dispatch_environment(source)
                if mode == "no_token": environment["GITHUB_TOKEN"] = ""
                if mode == "wrong_run": environment["GITHUB_RUN_ID"] = ""
                output = Path(temporary) / "receipt.json"
                if mode == "existing_receipt": output.write_bytes(b"retain original receipt")
                changed = set(engine.RUNTIMES.values()) | set(engine.MANIFESTS.values())
                if mode == "extra_path": changed.add("native/src/World.cpp")
                if mode == "missing_manifest": changed.remove(engine.MANIFESTS["windows"])
                lease_reads = []
                def git(*arguments):
                    if arguments == ("rev-parse", "HEAD"): return published.encode()
                    if arguments == ("rev-list", "--parents", "-n", "1", "HEAD"):
                        return (published + " " + source).encode()
                    if arguments == ("diff", "--name-only", "-z", source, published):
                        return "\0".join(sorted(changed)).encode()
                    self.assertEqual(arguments, ("ls-remote", "--exit-code", "origin", "refs/heads/" + engine.BRANCH))
                    lease_reads.append(arguments)
                    head = "3" * 40 if mode == "stale_before" or (mode == "stale_after" and len(lease_reads) > 1) else published
                    return (head + "\trefs/heads/" + engine.BRANCH).encode()
                with patch.dict(os.environ, environment), patch.object(engine, "git", side_effect=git), \
                     patch.object(engine, "require_publication_request") as admission, \
                     patch.object(subject.urllib.request, "urlopen") as request:
                    if mode == "unarmed": admission.side_effect = RuntimeError("unarmed request")
                    request.return_value.__enter__.return_value.status = 200 if mode == "rejected" else 204
                    args = argparse.Namespace(source_sha=source, published_sha=published, output=output)
                    if mode == "positive":
                        result = subject.dispatch_existing(args)
                        self.assertEqual(result, subject.read_json(output))
                        self.assertEqual(result["status"], "requested")
                        self.assertTrue(result["completed"])
                        self.assertEqual(len(lease_reads), 8)
                        self.assertEqual([row["workflow"] for row in result["requests"]], list(subject.DISPATCH_WORKFLOWS))
                        self.assertNotIn("fixture-token", output.read_text())
                        for call, workflow in zip(request.call_args_list, subject.DISPATCH_WORKFLOWS):
                            sent = call.args[0]
                            self.assertEqual(sent.method, "POST")
                            self.assertEqual(sent.full_url, "https://api.github.com/repos/techrote/cybersand/actions/workflows/" + workflow + "/dispatches")
                            self.assertEqual(json.loads(sent.data), {"ref": engine.BRANCH})
                    else:
                        with self.assertRaises(RuntimeError): subject.dispatch_existing(args)
                        self.assertEqual(request.call_count, 1 if mode in ("stale_after", "rejected") else 0)
                        if mode == "existing_receipt":
                            self.assertEqual(output.read_bytes(), b"retain original receipt")
                        elif output.exists():
                            self.assertFalse(subject.read_json(output)["completed"])


if __name__ == "__main__":
    unittest.main()
