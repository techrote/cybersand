"""The combined desktop launcher must not replace the Web export entry point."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("feature_build_web", Path(__file__).resolve().parents[1] / "build_web.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FeatureWebStaging(unittest.TestCase):
    def test_staging_preserves_source_and_web_entry(self):
        for scene in ("main.tscn", "feature_launcher.tscn"):
            with self.subTest(scene=scene), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                project = root / "godot/project.godot"
                project.parent.mkdir()
                original = f'run/main_scene="res://{scene}"\n[autoload]\nFeatureNavigation="*res://scripts/feature_navigation.gd"\n[cybersand]\nnative_worker_threads=0\n'
                project.write_text(original)
                (root / "godot/addons/cybersand_native/bin").mkdir(parents=True)
                (root / "godot/addons/godot-rapier2d").mkdir()
                library = root / "test.wasm"
                library.write_bytes(b"test staging input")
                with patch.object(MODULE, "ROOT", root):
                    stage = MODULE.stage_project(library, None, True, False)
                staged = (stage / "project.godot").read_text()
                self.assertIn('run/main_scene="res://web_main.tscn"', staged)
                self.assertNotIn('FeatureNavigation=', staged)
                self.assertIn('native_worker_threads=1\nweb_demo=true', staged)
                self.assertEqual(project.read_text(), original)


if __name__ == "__main__":
    unittest.main()
