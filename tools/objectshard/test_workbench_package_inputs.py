"""Closed package input controls, without pretending synthetic runtimes qualify."""
from pathlib import Path
import tempfile
import unittest

from verify_workbench_package import ENTRY, RENDERING_DRIVER, verify_inventory
from package_windows_workbench import launchers


class PackageInputTests(unittest.TestCase):
    def test_unlisted_loadable_files_are_refused_even_under_generated_cache(self):
        for name in ("godot/extra.gdextension", "godot/extra.gd", "godot/extra.tscn", "extra.dll", "godot/.godot/extra.dll"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture, never executed")
                with self.assertRaisesRegex(ValueError, "Unlisted package input"):
                    verify_inventory(root, {})

    def test_generated_cache_and_known_source_uid_are_the_only_extras(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("godot/test.gd", "godot/test.gd.uid", "godot/.godot/uid_cache.bin", "godot/icon.svg", "godot/icon.svg.import"):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture")
            verify_inventory(root, {"godot/test.gd": "hash", "godot/icon.svg": "hash"})
            (root / "godot/unknown.gd.uid").write_text("uid://unlisted")
            with self.assertRaisesRegex(ValueError, "Unlisted package input"):
                verify_inventory(root, {"godot/test.gd": "hash", "godot/icon.svg": "hash"})

    def test_normal_launcher_uses_the_project_entry_that_consumes_workbench_flags(self):
        source = launchers("a" * 40)["Open Workbench.cmd"]
        normal = next(line for line in source.splitlines() if line.startswith('start "CyberSand Workbench"'))
        self.assertNotIn("res://main.tscn", normal)
        self.assertIn("-- --shared-workbench --objectshard-m4-workbench --object-shard-scene=tower", normal)

    def test_normal_and_actual_selftest_share_manifest_bound_renderer_and_scene_arguments(self):
        lines = launchers("a" * 40)["Open Workbench.cmd"].splitlines()
        normal = next(line for line in lines if line.startswith('start "CyberSand Workbench"'))
        probe = next(line for line in lines if line.startswith('start "Workbench launch qualification"'))
        engine = '"%OBJECTSHARD_PACKAGE_ROOT%\\Godot_v4.7-stable_win64.exe"'
        normal_args = normal[normal.index(engine):]
        probe_args = probe[probe.index(engine):].replace(' --script res://tests/probe_object_shard_workbench_package.gd', '')
        self.assertEqual(normal_args, probe_args)
        self.assertEqual(ENTRY["rendering_driver"], RENDERING_DRIVER)
        self.assertEqual(normal_args.count("--rendering-driver"), 1)
        self.assertIn("--rendering-driver " + RENDERING_DRIVER, normal_args)


if __name__ == "__main__":
    unittest.main()
