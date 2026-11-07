#!/usr/bin/env python3
"""Adversarial C2048 runtime-publication profile/guard acceptance; shared engine's full suite remains mandatory."""
import inspect
import json
import os
from pathlib import Path
import re
import unittest
from unittest.mock import patch

import pf504_post405_runtime_publication as profile
import lcb001_shared_contract_runtime_publication as baseline

engine=profile.engine
ROOT=Path(__file__).resolve().parents[2]
BRANCH="integration/pf504-after-405-20261107"

class ProfileTests(unittest.TestCase):
    def test_publication_is_only_explicitly_armed_branch(self):
        self.assertIsNot(engine,baseline)
        self.assertEqual(engine.BRANCH,BRANCH)
        self.assertEqual(engine.WORKFLOW,".github/workflows/pf504-post405-runtime-publication.yml")
        self.assertEqual(engine.REQUEST,"tools/ci/pf504_post405_runtime_publish_request.json")
        self.assertEqual(engine.REQUEST_VALUE["intent"],"publish-source-matched-runtimes")
        self.assertEqual(engine.REQUEST_VALUE["variant"],
                         "C2048-optimized-gas-hotpath-plus-accepted-camera-retention")
        with patch.dict(os.environ,{"GITHUB_REPOSITORY":"wrong/repo","GITHUB_EVENT_NAME":"push",
                                    "GITHUB_REF":"refs/heads/"+BRANCH}):
            with self.assertRaises(RuntimeError):
                engine.context("f"*40)
        with patch.dict(os.environ,{"GITHUB_REPOSITORY":"techrote/cybersand",
                                    "GITHUB_EVENT_NAME":"pull_request",
                                    "GITHUB_REF":"refs/heads/"+BRANCH}):
            with self.assertRaises(RuntimeError):
                engine.context("f"*40)
    def test_full_source_and_lfs_hardening_is_inherited_unchanged(self):
        for function in ("context","require_publication_request","check_source",
                         "check_index","input_ledgers","runtime_identity",
                         "record_build","execute","stage"):
            with self.subTest(function=function):
                self.assertEqual(inspect.getsource(getattr(engine,function)),
                                 inspect.getsource(getattr(baseline,function)))
        self.assertEqual(inspect.getsource(profile._verify_bundle),
                         inspect.getsource(baseline.verify_bundle))
        self.assertEqual(inspect.getsource(profile._verify_shared),
                         inspect.getsource(baseline.verify_case_results))
    def test_required_execution_and_source_inputs(self):
        self.assertEqual(set(engine.CASE_MARKERS),
            {"test_pf_c2048_prepared","test_lcb_pressure_optimization",
             "test_lcb_pressure_reference","test_liquid_pressure_rapier",
             "test_simulation_worker_interest_ownership","test_workbench_canvas"})
        for path in (
            engine.WORKFLOW,engine.REQUEST,engine.EVIDENCE,
            "tools/ci/pf504_post405_runtime_publication.py",
            "tools/ci/test_pf504_post405_runtime_publication.py",
            "godot/tests/test_pf_c2048_prepared.gd",
            "godot/tests/test_workbench_canvas.gd"):
            with self.subTest(path=path):
                self.assertIn(path,engine.BUILD_EXACT)
                self.assertTrue((ROOT/path).is_file())
        self.assertNotIn(baseline.WORKFLOW,engine.BUILD_EXACT)
        self.assertNotIn(baseline.REQUEST,engine.BUILD_EXACT)
        self.assertNotIn("wbh406",engine.BUNDLE_PREFIX)
        self.assertIn("pf504-post405-runtime-attempt-",engine.BUNDLE_PREFIX)
    def test_real_success_log_markers_and_refusals(self):
        samples={
            "test_pf_c2048_prepared":"PF_C2048_PREPARED: 18 checks; 0 failures",
            "test_lcb_pressure_optimization":
                'LCB_PRESSURE_OPTIMIZATION: 4152 assertions; 0 failures; completed={"native_variants":true,"readback_encoding":true,"exact_parity":true,"gas_invalidation":true,"cold_restore":true,"default_preservation":true}',
            "test_lcb_pressure_reference":
                'LCB_PRESSURE_REFERENCE: 1934 assertions; 0 failures; completed={"native_dispatch":true,"no_fallback":true,"gas_identity":true,"gas_merge_split":true,"vent_reseal":true,"empty_only_gas":true,"quantity_ledger":true,"physical_state_hash":true,"save_roundtrip":true,"refusal_isolation":true,"default_goldens":true,"worker_parity":true}',
            "test_liquid_pressure_rapier":"LIQUID_PRESSURE_RAPIER: 120 assertions; 0 failures",
            "test_simulation_worker_interest_ownership":"SIMULATION_WORKER_INTEREST_OWNERSHIP: 57 assertions; 0 failures",
            "test_workbench_canvas":"WORKBENCH_CANVAS 131 checks, 0 failures"
        }
        for key,match in samples.items():
            with self.subTest(key=key):
                self.assertIsNotNone(re.search(engine.CASE_MARKERS[key],match+"\n"))
                self.assertIsNone(re.search(engine.CASE_MARKERS[key],
                                            match.replace("0 failures","1 failures")+"\n"))
    def test_publish_request_exact_schema_and_workflow_lease(self):
        p=json.loads((ROOT/engine.REQUEST).read_text(encoding="utf-8"))
        self.assertEqual({k: v for k, v in p.items() if k != "request_sequence"}, engine.REQUEST_VALUE)
        self.assertIs(type(p.get("request_sequence")), int)
        self.assertGreater(p["request_sequence"], 0)
        wf=(ROOT/engine.WORKFLOW).read_text(encoding="utf-8")
        self.assertIn("contents: write",wf)
        self.assertIn("python3 tools/ci/pf504_post405_runtime_publication.py check-index",wf)
        self.assertIn("git push --force-with-lease=",wf)
        self.assertIn("refs/heads/"+BRANCH,wf)
        self.assertIn("needs: [linux, windows-execution]",wf)
        self.assertNotIn("refs/heads/claude/water-ballistic-hybrid",wf)

    def test_optimized_gas_native_regression_is_required(self):
        self.assertIn("LCB-002 #201 moving region keeps exact warm pressure caches",
                      profile.NATIVE_REQUIRED["LCB-002"])
        self.assertEqual(profile.NATIVE_REQUIRED["LCB-001 gas exact hotpath"],
                         ("LCB-001 gas exact hotpath seams, masks and worker parity",))
        wf=(ROOT/engine.WORKFLOW).read_text(encoding="utf-8")
        self.assertIn("for group in 'Workbench parallel' 'Pair reaction' 'LCB-001 gas exact hotpath'; do",wf)
        self.assertIn("git push --force-with-lease=",wf)
        self.assertIn("POST-405 INTEGRATED #504 still requires independent physical replay and full CI",wf)

if __name__=="__main__":
    unittest.main()
