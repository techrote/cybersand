#!/usr/bin/env python3
"""Fail-closed tests for the staged BS-001 publication profile."""
import inspect
import json
import os
from pathlib import Path
import re
import unittest
from unittest.mock import patch
import bs001_runtime_publication as profile
import lcb001_shared_contract_runtime_publication as baseline

ROOT=Path(__file__).resolve().parents[2]
engine=profile.engine

class PublisherGuards(unittest.TestCase):
    def test_scope_and_immutable_shared_engine(self):
        self.assertIsNot(engine,baseline)
        self.assertEqual(engine.BRANCH,"feat/ballistic-solids-20261110")
        self.assertEqual(engine.WORKFLOW,".github/workflows/bs001-runtime-publication.yml")
        self.assertEqual(engine.REQUEST,"tools/ci/bs001_publish_request.json")
        self.assertEqual(engine.REQUEST_VALUE["intent"],"publish-source-matched-runtimes")
        for method in ("context","require_publication_request","check_source",
                       "check_index","input_ledgers","runtime_identity","record_build",
                       "execute","stage","verify_bundle"):
            self.assertEqual(inspect.getsource(getattr(engine,method)),
                             inspect.getsource(getattr(baseline,method)))
        with patch.dict(os.environ,{"GITHUB_REPOSITORY":"wrong/repo",
                                    "GITHUB_EVENT_NAME":"push",
                                    "GITHUB_REF":"refs/heads/"+engine.BRANCH}):
            with self.assertRaises(RuntimeError): engine.context("f"*40)

    def test_explicit_owned_source_and_receipt(self):
        for path in (engine.WORKFLOW,engine.EVIDENCE,engine.PRESSURE_CASE,
                     "tools/ci/bs001_runtime_publication.py",
                     "tools/ci/test_bs001_runtime_publication.py",
                     "godot/scripts/workbench_liquid_equipment.gd",
                     "godot/tests/test_workbench_reservoir_lab.gd"):
            with self.subTest(path=path):
                self.assertTrue((ROOT/path).is_file())
                self.assertIn(path,engine.BUILD_EXACT)
        self.assertNotIn(baseline.WORKFLOW,engine.BUILD_EXACT)
        self.assertNotIn(baseline.REQUEST,engine.BUILD_EXACT)

    def test_truthful_complete_real_host_results(self):
        samples={
            "test_workbench_solids_lab": "SOLIDS_LAB 31 checks, 0 failures",
            "test_workbench_liquid_equipment": "LIQUID_EQUIPMENT 103 checks, 0 failures",
            "test_workbench_reservoir_lab": "RESERVOIR_LAB 81 checks, 0 failures",
            "test_workbench_canvas": "WORKBENCH_CANVAS 164 checks, 0 failures",
            "test_workbench_kinetic_lab": "KINETIC_LAB 55 checks, 0 failures",
        }
        self.assertEqual(set(samples),set(engine.CASE_MARKERS))
        for key,line in samples.items():
            rx=engine.CASE_MARKERS[key]
            self.assertIsNotNone(re.search(rx,line+"\n"))
            bad=line.replace("0 failures","1 failures")
            self.assertIsNone(re.search(rx,bad+"\n"))
        self.assertEqual(set(profile.NATIVE_FILTERS),
                         {"BS-001","BW-001"})

    def test_request_is_absent_or_exact_explicit_sequence(self):
        p=ROOT/engine.REQUEST
        if not p.exists(): return
        data=json.loads(p.read_text(encoding="utf-8"))
        self.assertEqual(set(data),set(engine.REQUEST_VALUE)|{"request_sequence"})
        self.assertEqual({k:v for k,v in data.items() if k!="request_sequence"},
                         engine.REQUEST_VALUE)
        self.assertIs(type(data["request_sequence"]),int)
        self.assertGreater(data["request_sequence"],0)

    def test_only_four_path_publish_with_branch_lease(self):
        s=(ROOT/engine.WORKFLOW).read_text(encoding="utf-8")
        self.assertIn("contents: write",s)
        self.assertIn("git push --force-with-lease=",s)
        self.assertIn("bs001_runtime_publication.py check-index",s)
        self.assertIn("refs/heads/"+engine.BRANCH,s)
        self.assertIn("needs: [linux, windows-execution]",s)
        self.assertIn("test_bs001_runtime_publication.py",s)
        self.assertNotIn("refs/heads/fix/native-copy-extreme-coordinate-preflight-292-20261107",s)

if __name__=="__main__":
    unittest.main()
