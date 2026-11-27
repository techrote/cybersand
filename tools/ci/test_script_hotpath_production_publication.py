#!/usr/bin/env python3
"""Adversarial admission tests for the SCRIPT-HOTPATH-001 production publisher."""
import inspect
import json
import os
from pathlib import Path
import re
import unittest
from unittest.mock import patch

import lcb001_shared_contract_runtime_publication as shared
import script_hotpath_production_publication as profile

ROOT = Path(__file__).resolve().parents[2]
BRANCH = "exp/script-hotpath-001-native-fill"


class ScriptHotpathProductionTests(unittest.TestCase):
    def test_exact_branch_and_pinned_input_contract(self):
        engine = profile.engine
        self.assertIsNot(engine, shared)
        self.assertEqual(engine.BRANCH, BRANCH)
        self.assertEqual(engine.WORKFLOW, ".github/workflows/script-hotpath-production.yml")
        self.assertEqual(engine.REQUEST, "tools/ci/script_hotpath_production_publish_request.json")
        self.assertIn("test_script_hotpath_native_fill", engine.CASE_MARKERS)
        self.assertIn("test_paint_editor_workbench", engine.CASE_MARKERS)
        self.assertIn("test_liquid_pressure_rapier", engine.CASE_MARKERS)
        self.assertEqual(set(engine.RUNTIMES), {"linux", "windows"})
        self.assertEqual(set(engine.MANIFESTS), {"linux", "windows"})
        for name in (engine.REQUEST, engine.WORKFLOW, engine.EVIDENCE,
                     "tools/ci/script_hotpath_production_publication.py",
                     "tools/ci/test_script_hotpath_production_publication.py"):
            self.assertIn(name, engine.BUILD_EXACT)

    def test_inherited_source_input_lfs_and_target_os_guards_unchanged(self):
        for name in ("context", "require_publication_request", "check_source",
                     "check_index", "input_ledgers", "runtime_identity",
                     "verify_bundle", "record_build", "execute", "stage"):
            with self.subTest(guard=name):
                self.assertEqual(inspect.getsource(getattr(profile.engine, name)),
                                 inspect.getsource(getattr(shared, name)))

    def test_foreign_workflow_branch_event_and_commit_fail_closed(self):
        engine = profile.engine
        sha = "1" * 40
        env = {
            "GITHUB_REPOSITORY": "techrote/cybersand",
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + BRANCH,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + engine.WORKFLOW
                                   + "@refs/heads/" + BRANCH,
            "GITHUB_SHA": sha,
            "GITHUB_RUN_ID": "123",
            "GITHUB_RUN_ATTEMPT": "1",
        }

        def mocked_git(*args):
            if args == ("rev-parse", "HEAD"): return (sha + "\n").encode()
            if args == ("rev-parse", sha + "^{tree}"): return ("2" * 40 + "\n").encode()
            raise AssertionError("unexpected Git operation: " + repr(args))

        with patch.object(engine, "git", side_effect=mocked_git), patch.dict(os.environ, env):
            self.assertEqual(engine.context(sha)["source_commit"], sha)
            for key, changed in {
                "GITHUB_REPOSITORY": "attacker/cybersand",
                "GITHUB_EVENT_NAME": "pull_request",
                "GITHUB_REF": "refs/heads/main",
                "GITHUB_WORKFLOW_REF": env["GITHUB_WORKFLOW_REF"].replace(BRANCH, "main"),
                "GITHUB_SHA": "3" * 40,
                "GITHUB_RUN_ATTEMPT": "0",
            }.items():
                with self.subTest(key=key), patch.dict(os.environ, {key: changed}):
                    with self.assertRaises(RuntimeError):
                        engine.context(sha)

    def test_required_exact_feature_receipts_reject_zero_checks_and_failures(self):
        examples = {
            "test_script_hotpath_native_fill":
                'SCRIPT_HOTPATH_RESULT {"checks":819,"failures":[],"backend_version":1}',
            "test_paint_editor_shapes":
                'PAINT_EDITOR_SHAPES {"checks":165,"failures":0,"actual_native_readback":true}',
            "test_paint_editor_executor":
                'PAINT_EXECUTOR {"checks":21,"failures":[]}',
            "test_paint_editor_workbench":
                'PAINT_EDITOR_WORKBENCH {"checks":64,"failures":[],"frame_samples":270}',
            "test_liquid_pressure_rapier":
                'LIQUID_PRESSURE_RAPIER: 45 assertions; 0 failures',
        }
        for name, valid in examples.items():
            pattern = profile.engine.CASE_MARKERS[name]
            with self.subTest(case=name):
                self.assertIsNotNone(re.search(pattern, valid + "\n"))
                self.assertIsNone(re.search(pattern, valid.replace("0 failures", "1 failures")
                    .replace('"failures":[]', '"failures":["bad"]')
                    .replace('"failures":0', '"failures":1') + "\n"))
                self.assertIsNone(re.search(pattern, valid.replace('"checks":819', '"checks":0')
                    .replace('"checks":165', '"checks":0')
                    .replace('"checks":64', '"checks":0')
                    .replace('"checks":21', '"checks":0')
                    .replace("45 assertions", "0 assertions") + "\n"))

    def test_explicit_request_and_run_isolation(self):
        engine = profile.engine
        workflow = (ROOT / engine.WORKFLOW).read_text(encoding="utf-8")
        self.assertIn("cancel-in-progress: false", workflow)
        self.assertIn("github.run_id", workflow)
        self.assertIn("needs.admission.outputs.armed == 'true'", workflow)
        self.assertIn("python3 tools/ci/script_hotpath_production_publication.py check-index", workflow)
        self.assertIn('--force-with-lease="refs/heads/' + BRANCH + ':$GITHUB_SHA"', workflow)
        self.assertIn("git lfs install --local", workflow)
        self.assertIn("git diff --check --cached", workflow)
        self.assertIn("contents: write", workflow)
        self.assertIn("if: needs.admission.outputs.armed == 'true'", workflow)
        request = ROOT / engine.REQUEST
        if request.exists():
            payload = json.loads(request.read_text(encoding="utf-8"))
            self.assertEqual(payload.pop("request_sequence"), 1)
            self.assertEqual(payload, engine.REQUEST_VALUE)
        else:
            self.assertFalse(request.exists())

    def test_no_source_mutation_or_forged_runtime_via_profile(self):
        source = (ROOT / "tools/ci/script_hotpath_production_publication.py").read_text()
        for forbidden in ("git push", "git checkout main", "git commit"):
            self.assertNotIn(forbidden, source)
        # Each platform must independently pass before the publisher owns four paths.
        self.assertEqual(set(profile.engine.MANIFESTS.values()), {
            "godot/addons/cybersand_native/runtime-provenance.linux.json",
            "godot/addons/cybersand_native/runtime-provenance.json",
        })


if __name__ == "__main__":
    unittest.main()
