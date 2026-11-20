"""Fail closed if the successor targets a parent branch or loses a spill test section."""
import json
from pathlib import Path
import re
import unittest

import wave_water_face_004_runtime_publication as profile

ROOT = Path(__file__).resolve().parents[2]


class WaterFace004PublicationTests(unittest.TestCase):
    def test_branch_request(self):
        engine = profile.engine
        self.assertEqual(engine.BRANCH, "codex/wave-water-face-004")
        request = json.loads((ROOT / engine.REQUEST).read_text())
        self.assertGreater(request.pop("request_sequence"), 21)
        self.assertEqual(request, engine.REQUEST_VALUE)
        workflow = (ROOT / engine.WORKFLOW).read_text()
        self.assertIn("HEAD:refs/heads/" + engine.BRANCH, workflow)
        self.assertNotIn("HEAD:refs/heads/claude/", workflow)
        for name in (engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE):
            self.assertIn(name, engine.BUILD_EXACT)

    def test_spill_sections_match_workbench(self):
        test = (ROOT / "godot/tests/test_workbench_wave_spill.gd").read_text()
        names = set(re.findall(r'^\s*sections\.(\w+)\s*=\s*failures\.size\(\) == start', test, re.M))
        self.assertEqual(names, profile.parent.parent.parent.SPILL_SECTIONS)


if __name__ == "__main__":
    unittest.main()
