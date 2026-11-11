"""Standalone GEN-007 payload: real canonical profiles, no checkout dependency."""
import hashlib
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from package_explore001_candidate import stage_generator_profiles


class Profiles(unittest.TestCase):
    def test_canonical_payload_and_missing_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary)
            with self.assertRaisesRegex(ValueError, "missing required"):
                stage_generator_profiles(package)
            shutil.copytree(ROOT / "examples/worldgen", package / "examples/worldgen")
            inventory = stage_generator_profiles(package)
            canonical = sorted((ROOT / "examples/worldgen").glob("*.json"))
            self.assertEqual(set(inventory), {p.name for p in canonical})
            self.assertGreaterEqual(len(inventory), 2)
            shutil.rmtree(package / "examples")
            self.assertFalse((package / ".git").exists())
            for profile in canonical:
                installed = package / "godot/authoring/worldgen" / profile.name
                self.assertEqual(profile.read_bytes(), installed.read_bytes())
                self.assertEqual(inventory[profile.name], hashlib.sha256(installed.read_bytes()).hexdigest())

    def test_broken_required_recipe_fails_packaging(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary)
            shutil.copytree(ROOT / "examples/worldgen", package / "examples/worldgen")
            (package / "examples/worldgen/gen007-deepworks.json").write_text("[]")
            with self.assertRaisesRegex(ValueError, "Invalid or oversized"):
                stage_generator_profiles(package)


if __name__ == "__main__":
    unittest.main()
