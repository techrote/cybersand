"""Fail closed if the successor targets a parent branch or loses a spill test section."""
import json
from pathlib import Path
import re
import unittest

from wave_waterwall_runtime_publication import SPILL_SECTIONS
import wave_oil_buoyancy_runtime_publication as profile

ROOT = Path(__file__).resolve().parents[2]


class WaveOilBuoyancyPublicationTests(unittest.TestCase):
    def test_branch_request(self):
        engine = profile.engine
        self.assertEqual(engine.BRANCH, "codex/wave-oil-buoyancy")
        request = json.loads((ROOT / engine.REQUEST).read_text())
        self.assertGreater(request.pop("request_sequence"), 22)
        self.assertEqual(request, engine.REQUEST_VALUE)
        workflow = (ROOT / engine.WORKFLOW).read_text()
        self.assertIn("github.base_ref == 'codex/wave-water-face-004'", workflow)
        self.assertEqual(re.findall(r"HEAD:refs/heads/(\S+)", workflow), [engine.BRANCH])
        self.assertIn(f'--force-with-lease="refs/heads/{engine.BRANCH}:$GITHUB_SHA"', workflow)
        for name in (engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE):
            self.assertIn(name, engine.BUILD_EXACT)

    def test_spill_sections_match_workbench(self):
        test = (ROOT / "godot/tests/test_workbench_wave_spill.gd").read_text()
        names = set(re.findall(r'^\s*sections\.(\w+)\s*=\s*failures\.size\(\) == start', test, re.M))
        self.assertEqual(names, SPILL_SECTIONS)


if __name__ == "__main__":
    unittest.main()
