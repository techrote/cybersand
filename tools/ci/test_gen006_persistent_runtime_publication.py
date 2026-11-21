#!/usr/bin/env python3
"""Adversarial GEN-006 publication guards; no native build or network needed."""
from __future__ import annotations

import copy
import inspect
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import gen006_persistent_runtime_publication as profile
import lcb001_shared_contract_runtime_publication as baseline

engine = profile.engine
ROOT = Path(__file__).resolve().parents[2]
SOURCE, TREE, DIGEST = "a" * 40, "b" * 40, "c" * 64


class PublisherGuards(unittest.TestCase):
    def test_reuses_unmodified_source_staging_and_branch_fences(self):
        self.assertIsNot(engine, baseline)
        self.assertEqual(engine.BRANCH, "exp/gen006-persistent-areas-001-20261121")
        self.assertEqual(engine.REQUEST_VALUE["intent"], "publish-source-matched-runtimes")
        for method in ("context", "require_publication_request", "check_source", "check_index",
                       "input_ledgers", "runtime_identity", "record_build", "stage", "verify_bundle"):
            self.assertEqual(inspect.getsource(getattr(engine, method)), inspect.getsource(getattr(baseline, method)))
        self.assertIs(engine.verify_case_results, profile.verify_case_results)
        with patch.object(engine, "git", return_value=SOURCE.encode()), patch.dict(os.environ, {
                "GITHUB_REPOSITORY": "wrong/repo", "GITHUB_EVENT_NAME": "push",
                "GITHUB_REF": "refs/heads/" + engine.BRANCH}):
            with self.assertRaises(RuntimeError): engine.context(SOURCE)

    def test_request_is_exact_and_explicit(self):
        request = json.loads((ROOT / engine.REQUEST).read_text())
        self.assertEqual(set(request), set(engine.REQUEST_VALUE) | {"request_sequence"})
        self.assertEqual({k: v for k, v in request.items() if k != "request_sequence"}, engine.REQUEST_VALUE)
        self.assertIs(type(request["request_sequence"]), int)
        self.assertGreater(request["request_sequence"], 0)
        self.assertNotIn(baseline.WORKFLOW, engine.BUILD_EXACT)
        self.assertNotIn(baseline.REQUEST, engine.BUILD_EXACT)
        for path in (engine.WORKFLOW, engine.REQUEST, engine.PRESSURE_CASE,
                     "tools/ci/run_persistent_areas_qualification.py",
                     "tools/package_gen006_persistent_areas.py"):
            self.assertIn(path, engine.BUILD_EXACT)
            self.assertTrue((ROOT / path).is_file(), path)

    def test_scoped_native_markers_reject_optimistic_or_skipped_time(self):
        good = (
            "GEN006_NATIVE_CONTINUATION_PASS initial_tick=37 completed_tick=325 slice_sizes=1,8,32 configured_workers=1,4 observed_workers=4 physical=8f295356db4b2698 checkpoint_bytes=1943273 resident_cell_bytes=2461696 native_ticks=288 native_step_us=462627\n"
            "GEN006_NATIVE_REFUSAL_ATOMICITY_PASS corrupt truncated wrong_tick wrong_hash oversized_slice body_mask partial_region private_tick_failure wave_refusal\n"
            "GEN006_COARSE_SKIP_REFUSED_PASS sleeping_tick=20 reaction_tick=21 epoch_wrap_tick=256 requested_ticks=36000 credited_ticks=0 remaining_debt=36000\n"
            "GEN006_NATIVE_THREE_AREAS_PASS sequence=A,B,C,A,B retained_checkpoint_bytes=5993596\n")
        for pattern in profile.NATIVE_MARKERS:
            self.assertEqual(len(re.findall(pattern, good)), 1)
        self.assertFalse(all(re.search(pattern, good.replace("credited_ticks=0", "credited_ticks=36000"))
                             for pattern in profile.NATIVE_MARKERS))
        self.assertFalse(all(re.search(pattern, good.replace("observed_workers=4", "observed_workers=1"))
                             for pattern in profile.NATIVE_MARKERS))

    def test_only_explicit_trigger_standard_hosts_and_four_path_publication(self):
        text = (ROOT / engine.WORKFLOW).read_text()
        self.assertNotIn("workflow_dispatch:", text)
        self.assertNotIn("pull_request_target:", text)
        self.assertIn("needs: [linux, windows-execution]", text)
        self.assertIn("git push --force-with-lease=\"refs/heads/" + engine.BRANCH + ":$GITHUB_SHA\"", text)
        self.assertIn('test "$(git rev-list --parents -n 1 HEAD)" = "$(git rev-parse HEAD) $GITHUB_SHA"', text)
        self.assertIn("gen006_persistent_runtime_publication.py check-index", text)
        self.assertEqual(text.count("contents: write"), 1)
        labels = re.findall(r"(?m)^\s+runs-on:\s*(\S+)", text)
        self.assertTrue(labels)
        self.assertTrue(set(labels) <= {"ubuntu-24.04", "windows-2022"})
        push = text.split("  push:", 1)[1].split("\npermissions:", 1)[0]
        self.assertNotIn("godot/addons", push)
        self.assertNotIn("native/**", push)
        self.assertNotIn("run_gentek80", text)
        self.assertNotIn("gh pr ready", text)
        self.assertNotIn("gh pr merge", text)
        self.assertIn("Run Automated Smoke.ps1", text)
        self.assertIn("package_gen006_persistent_areas.py verify", text)


class QualificationGuards(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.ledgers = {"source_inputs": {"native/src/world.cpp": DIGEST},
            "build_inputs": {key: DIGEST for key in (
                "Makefile", "tools/build_native_extension.sh", "tools/build_native_extension_windows.sh",
                "tools/ci/run_persistent_areas_qualification.py", "godot/scripts/persistent_areas_main.gd")}}
        self.ledgers["build_inputs"].update({key:DIGEST for key in engine.windows.RAPIER_IMPORT_DESCRIPTORS})
        files = {}
        rows = []
        for index, label in enumerate(sorted(profile.REQUIRED_LABELS), start=1):
            path = self.root / (label + ".log")
            path.write_text("Original process evidence\n")
            files[path.name] = profile.sha(path)
            rows.append({"label": label, "status": "passed", "pid": index, "log": path.name,
                         "forced_termination": "-crash-" in label})
        for name in ("results.json", "native-scene.png"):
            path = self.root / name
            path.write_bytes(b"original-bound-evidence")
            files[name] = profile.sha(path)
        self.value = {"schema": "gen006-persistent-areas-qualification-v1", "status": "passed", "completed": True,
            "platform": "linux", "source_commit": SOURCE, "source_tree": TREE, "graphical": True,
            "input_custody": "passed", "local_delta": [], "missing_source_inputs": [], "native_sha256": DIGEST,
            "engine_sha256": DIGEST, "engine_version": engine.GODOT_VERSION,
            "rapier_sha256": engine.RAPIER["linux"][1], "native_build_ledger_sha256": DIGEST,
            "source_inputs_sha256": self.ledgers["source_inputs"] | self.ledgers["build_inputs"],
            "results": rows, "files_sha256": files,
            "workbench": {label: {"failures": [], "graphical": True} for label in profile.WORKBENCH_LABELS}}
        before = {key:self.value[key] for key in ("source_commit", "source_tree", "source_inputs_sha256",
                                                "missing_source_inputs", "local_delta")}
        binaries = {key:self.value[key] for key in ("native_sha256", "rapier_sha256", "engine_sha256")}
        self.value["custody_checks"] = [{"phase":phase, "unchanged":True, "source_after":before,
            "binaries_before":binaries, "binaries_after":binaries} for phase in ("after-import", "after-campaign")]
        custody = self.root / "source-custody.json"
        custody.write_text(json.dumps({"schema":"gen006-source-custody-v1", "source_before":before,
                                      "checks":self.value["custody_checks"]}))
        files[custody.name] = profile.sha(custody)
        self.git_patch = patch.object(engine, "git", return_value=TREE.encode())
        self.git_patch.start()

    def tearDown(self):
        self.git_patch.stop()
        self.temporary.cleanup()

    def verify(self, value=None):
        profile.verify_qualification(self.root, self.value if value is None else value, "linux", SOURCE,
                                     DIGEST, DIGEST, DIGEST, self.ledgers)

    def test_complete_scoped_contract_is_accepted(self):
        self.verify()

    def test_wrong_platform_source_binary_version_or_headless_refused(self):
        for key, bad in {"platform": "windows", "source_commit": "d" * 40, "source_tree": "d" * 40,
                "native_sha256": "d" * 64, "engine_sha256": "d" * 64, "engine_version": "4.6",
                "native_build_ledger_sha256": "d" * 64, "graphical": False, "completed": False,
                "input_custody": "pending", "local_delta": ["M changed.gd"]}.items():
            with self.subTest(key=key):
                value = copy.deepcopy(self.value)
                value[key] = bad
                with self.assertRaises(RuntimeError): self.verify(value)

    def test_missing_duplicate_skipped_and_failed_cases_refused(self):
        for mutation in ("missing", "duplicate", "skip", "failed", "no-pid", "no-log", "fake-crash"):
            with self.subTest(mutation=mutation):
                value = copy.deepcopy(self.value)
                if mutation == "missing": value["results"].pop()
                elif mutation == "duplicate": value["results"].append(value["results"][0])
                elif mutation in ("skip", "failed"): value["results"][0]["status"] = mutation
                elif mutation == "no-pid": value["results"][0].pop("pid")
                elif mutation == "no-log": value["results"][0]["log"] = "unbound.log"
                else:
                    next(row for row in value["results"] if "-crash-" in row["label"])["forced_termination"] = False
                with self.assertRaises(RuntimeError): self.verify(value)

    def test_missing_native_script_or_unknown_changed_input_refused(self):
        for mutation in ("native/src/world.cpp", "godot/scripts/persistent_areas_main.gd", "unknown.py",
                         *engine.windows.RAPIER_IMPORT_DESCRIPTORS):
            with self.subTest(mutation=mutation):
                value = copy.deepcopy(self.value)
                if mutation == "unknown.py": value["source_inputs_sha256"][mutation] = DIGEST
                else: del value["source_inputs_sha256"][mutation]
                with self.assertRaises(RuntimeError): self.verify(value)

    def test_missing_or_disagreeing_custody_observations_refused(self):
        for mutation in ("missing", "missing-original", "unchanged-claim", "source-after", "binary-after"):
            with self.subTest(mutation=mutation):
                value = copy.deepcopy(self.value)
                if mutation == "missing": del value["custody_checks"]
                elif mutation == "missing-original": del value["files_sha256"]["source-custody.json"]
                elif mutation == "unchanged-claim": value["custody_checks"][-1]["unchanged"] = False
                elif mutation == "source-after": value["custody_checks"][-1]["source_after"]["source_commit"] = "d" * 40
                else: value["custody_checks"][-1]["binaries_after"]["native_sha256"] = "d" * 64
                with self.assertRaises(RuntimeError): self.verify(value)

    def test_failed_or_nongraphical_workbench_receipt_refused(self):
        label = next(iter(profile.WORKBENCH_LABELS))
        for key, bad in (("graphical", False), ("failures", ["restored wrong area"])):
            value = copy.deepcopy(self.value)
            value["workbench"][label][key] = bad
            with self.assertRaises(RuntimeError): self.verify(value)

    def test_original_log_tampering_and_escaping_path_refused(self):
        path = self.root / self.value["results"][0]["log"]
        path.write_text("changed after success\n")
        with self.assertRaises(RuntimeError): self.verify()
        for relative in ("../outside.log", "/tmp/outside.log", "C:/outside.log", "a\\..\\outside.log"):
            with self.subTest(relative=relative), self.assertRaises(RuntimeError): profile.safe_relative(relative)

    def test_actual_build_ledger_rejects_drift_stale_input_and_output(self):
        value = {"schema": "gentek80-native-build-v1", "returncode": 0, "source_commit": SOURCE,
            "source_tree": TREE, "platform": "linux", "source_inputs_sha256": self.ledgers["source_inputs"],
            "runtime_sha256": DIGEST, "runtime_bytes": 1024,
            "compiler_version": "g++ (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0", "godot_cpp_library_sha256": DIGEST}
        path = self.root / "build.json"
        path.write_text(json.dumps(value))
        runtime = {"sha256": DIGEST, "size": 1024}
        profile.verify_build_ledger(path, "linux", SOURCE, runtime, self.ledgers["source_inputs"])
        for key, bad in (("compiler_version", "g++ 14.2.0"), ("returncode", 1),
                ("source_inputs_sha256", {}), ("runtime_sha256", "d" * 64), ("source_commit", "d" * 40)):
            with self.subTest(key=key):
                changed = copy.deepcopy(value)
                changed[key] = bad
                path.write_text(json.dumps(changed))
                with self.assertRaises(RuntimeError):
                    profile.verify_build_ledger(path, "linux", SOURCE, runtime, self.ledgers["source_inputs"])


if __name__ == "__main__":
    unittest.main()
