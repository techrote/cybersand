"""Synthetic fail-closed tests for source-exact Gentek owner-package examples."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import stage_gentek80_examples as stage


class OriginalExampleAdmission(unittest.TestCase):
    SOURCE = "a" * 40
    TREE = "b" * 40

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.candidate = self.root / "candidate"
        self.evidence = self.root / "evidence"
        self.candidate.mkdir()
        self.evidence.mkdir()
        (self.candidate / "registered.txt").write_text("original package content")
        (self.candidate / "candidate-manifest.json").write_text(json.dumps({
            "schema": 1, "source_commit": self.SOURCE,
            "source_tree": self.TREE, "native_sha256": "f" * 64,
            "files_sha256": {"registered.txt": stage.digest(b"original package content")}
        }))
        frames = []
        for i in range(4):
            label = f"original-windows-{i}.png"
            payload = b"\x89PNG\r\n" + bytes([i]) * 10
            (self.evidence / label).write_bytes(payload)
            frames.append({"name": label, "sha256": stage.digest(payload)})
        phases = {}
        for phase, pid in (("author", 120), ("reopen", 240)):
            cases = []
            for i, name in enumerate(stage.NAMES):
                p = {
                    "format": "cybersand.architectural-project",
                    "seed": 200 + i, "origin": [0, 0] if i == 0 else [-512, -512],
                    "styles": [{"preset": {"module": module}, "share": share}
                               for module, share in zip(stage.MODULES[i], stage.SHARES[i])]
                }
                profile = self.evidence / stage.PROFILE
                profile.mkdir(parents=True, exist_ok=True)
                project = profile / (name + ".json")
                project.write_text(json.dumps(p))
                case = {
                    "name": name, "case": "five-showcase-" + phase,
                    "source_commit": self.SOURCE, "active_slots": 5,
                    "modules": list(stage.MODULES[i]), "shares": stage.SHARES[i],
                    "native_receipts": 16,
                    "project_file_sha256": stage.file_digest(project),
                    "project_sha256": "x" * 64, "source_sha256": str(i) * 64,
                    "recipe_sha256": str(i + 2) * 64, "seed": p["seed"],
                    "origin": p["origin"], "configurations": []
                }
                if phase == "author":
                    target = profile / "workbench" / ("setup-" + name + ".json")
                    target.parent.mkdir(exist_ok=True)
                    target.write_text(json.dumps({
                        "format": "cybersand-generated-start-v1",
                        "generation": {"sha256": case["source_sha256"],
                                       "recipe_sha256": case["recipe_sha256"],
                                       "origin": case["origin"]},
                        "starting_setup": {
                            "edits": [[101, 99, 2, 58], [111, 99, 2, 0]]
                        }
                    }))
                cases.append(case)
            phases[phase] = {
                "schema": "gentek80-five-showcase-workbench-v1",
                "phase": phase, "process_id": pid, "complete": True,
                "failures": 0, "cases": cases
            }
        self.report = {
            "schema": "gentek80-five-showcase-source-exact-v1",
            "source_commit": self.SOURCE, "source_tree": self.TREE,
            "passed": True, "graphical": True, "independent_processes": True,
            "matched_project_material_recipe": True, "runtime_sha256": "e" * 64,
            "original_frames": frames, **phases
        }
        self.write_report()

    def write_report(self):
        (self.evidence / "qualification.json").write_text(json.dumps(self.report))

    def test_original_projects_maps_enter_complete_manifest(self):
        result = stage.stage(self.candidate, self.evidence, self.SOURCE)
        self.assertEqual(result["examples"], 2)
        self.assertTrue(result["verified"])
        manifest = json.loads((self.candidate / "candidate-manifest.json").read_text())
        bound_files = manifest["gentek80_acceptance_examples"]["generated_example_files_sha256"]
        self.assertEqual(len(bound_files), 5)
        for filename, expected in bound_files.items():
            self.assertEqual(stage.file_digest(self.candidate / filename), expected)
            self.assertEqual(manifest["files_sha256"][filename], expected)

    def test_wrong_source_rejected_without_partial_publication(self):
        self.report["source_commit"] = "c" * 40
        self.write_report()
        with self.assertRaisesRegex(ValueError, "qualification missing"):
            stage.stage(self.candidate, self.evidence, self.SOURCE)
        self.assertFalse((self.candidate / stage.DEST).exists())

    def test_missing_original_frame_rejected_without_publication(self):
        (self.evidence / "original-windows-2.png").unlink()
        with self.assertRaisesRegex(ValueError, "graphical evidence digest mismatch"):
            stage.stage(self.candidate, self.evidence, self.SOURCE)
        self.assertFalse((self.candidate / stage.DEST).exists())

    def test_reordered_map_edits_rejected_without_publication(self):
        p = self.evidence / stage.PROFILE / "workbench" / (
            "setup-" + stage.NAMES[0] + ".json")
        content = json.loads(p.read_text())
        content["starting_setup"]["edits"].reverse()
        p.write_text(json.dumps(content))
        with self.assertRaisesRegex(ValueError, "out-of-order"):
            stage.stage(self.candidate, self.evidence, self.SOURCE)
        self.assertFalse((self.candidate / stage.DEST).exists())

    def test_unlisted_existing_package_member_rejected(self):
        (self.candidate / "untracked.exe").write_bytes(b"MZ...")
        with self.assertRaisesRegex(ValueError, "unlisted files"):
            stage.stage(self.candidate, self.evidence, self.SOURCE)
        self.assertFalse((self.candidate / stage.DEST).exists())


if __name__ == "__main__":
    unittest.main()
