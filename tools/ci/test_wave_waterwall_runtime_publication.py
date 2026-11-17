#!/usr/bin/env python3
"""Guards for the WAVE-WATERWALL-001 publisher profile: branch binding, request
shape, inherited publication guards and refusal of forged spill evidence."""
import inspect
import json
from pathlib import Path
import tempfile
import unittest

import lcb001_shared_contract_runtime_publication as shared
import wave_waterwall_runtime_publication as profile

ROOT = Path(__file__).resolve().parents[2]


class WaterwallPublicationTests(unittest.TestCase):
    def test_branch_request_and_workflow_are_bound_to_this_lane(self):
        engine = profile.engine
        self.assertEqual(engine.BRANCH, "claude/wave-waterwall-001")
        self.assertEqual(engine.WORKFLOW, ".github/workflows/wave-waterwall-runtime-publication.yml")
        request = json.loads((ROOT / engine.REQUEST).read_text(encoding="utf-8"))
        self.assertEqual({k: v for k, v in request.items() if k != "request_sequence"}, engine.REQUEST_VALUE)
        self.assertIsInstance(request["request_sequence"], int)
        workflow = (ROOT / engine.WORKFLOW).read_text(encoding="utf-8")
        self.assertNotIn("astra/wave-mt-001-669-finisher", workflow)
        self.assertIn("refs/heads/claude/wave-waterwall-001", workflow)
        for target in ("wave-spill-test", "wave-spill-sanitize", "wave-spill-thread-sanitize"):
            self.assertIn(target, workflow)
        for path in (engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE, "native/bench/wave_waterwall.cpp"):
            self.assertIn(path, engine.BUILD_EXACT)

    def test_inherited_source_and_publication_guards_are_unchanged(self):
        for name in ("context", "require_publication_request", "check_source", "check_index",
                     "input_ledgers", "runtime_identity", "verify_bundle", "record_build", "execute", "stage"):
            with self.subTest(name=name):
                self.assertEqual(inspect.getsource(getattr(profile.engine, name)), inspect.getsource(getattr(shared, name)))
        self.assertIn("test_workbench_wave", profile.engine.CASE_MARKERS)
        self.assertIn("test_workbench_wave_spill", profile.engine.CASE_MARKERS)

    def test_forged_or_incomplete_spill_summaries_are_refused(self):
        good = {"checks": 40, "failures": [], "sections": {name: True for name in profile.SPILL_SECTIONS}}
        profile.verify_spill_summary("WORKBENCH_WAVE_SPILL " + json.dumps(good))
        for bad in ["", "WORKBENCH_WAVE_SPILL {", "WORKBENCH_WAVE_SPILL " + json.dumps(good) + "\nWORKBENCH_WAVE_SPILL " + json.dumps(good),
                    "WORKBENCH_WAVE_SPILL " + json.dumps(good | {"failures": ["x"]}),
                    "WORKBENCH_WAVE_SPILL " + json.dumps(good | {"checks": 0}),
                    "WORKBENCH_WAVE_SPILL " + json.dumps(good | {"sections": {"native_admission": True}}),
                    "WORKBENCH_WAVE_SPILL " + json.dumps(good | {"sections": {**good["sections"], "workbench_apply": False}})]:
            with self.subTest(bad=bad[:60]):
                with self.assertRaises(RuntimeError):
                    profile.verify_spill_summary(bad)


if __name__ == "__main__":
    unittest.main()
