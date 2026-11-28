"""Closed package input controls, without pretending synthetic runtimes qualify."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import unittest

from verify_workbench_package import ENTRY, MANIFEST, RENDERING_DRIVER, REQUIRED, verify_inventory
from package_windows_workbench import launchers


class PackageInputTests(unittest.TestCase):
    def test_portable_verifier_matches_the_manifest_entry_and_required_inputs(self):
        # Both independently shipped verifiers must admit the same exact entry
        # and require the same files, even on hosts without a PowerShell runtime.
        source = Path(__file__).with_name("verify_workbench_package.ps1").read_text()
        scenarios = re.search(r"\(\$manifest\.entry\.scenario_ids -join ','\) -ne '([^']+)'", source)
        self.assertIsNotNone(scenarios)
        self.assertEqual(scenarios.group(1).split(","), ENTRY["scenario_ids"])
        variables = dict(re.findall(r"^\$(\w+) = '([^']+)'$", source, re.MULTILINE))
        required = re.search(r"^\$required = @\((.*?)\)\n", source, re.MULTILINE | re.DOTALL)
        self.assertIsNotNone(required)
        entries = re.findall(r"'([^']+)'|\$(\w+)", required.group(1))
        portable_required = {literal or variables[variable] for literal, variable in entries}
        self.assertEqual(portable_required, REQUIRED)

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

    @unittest.skipUnless(shutil.which("powershell.exe") or shutil.which("pwsh"), "Requires a PowerShell runtime")
    def test_portable_verifier_binds_the_generator_even_after_a_generic_inventory_rehash(self):
        shell = shutil.which("powershell.exe") or shutil.which("pwsh")
        script = Path(__file__).with_name("verify_workbench_package.ps1")
        generator = "godot/tools/gentek_reciprocal.exe"
        binding = "godot/tools/swarm004-runtime.windows.json"
        reopen = "godot/tests/fixtures/object_shard_m4_authored_reopen.gd"
        data = b"synthetic executable stand-in, never run"
        configuration = {"platform": "windows", "artifact": generator, "bytes": len(data),
                         "sha256": hashlib.sha256(data).hexdigest()}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            inventory = {}
            stand_ins = {generator: data, binding: json.dumps(configuration).encode()}
            for name in REQUIRED | {generator, binding, reopen}:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                raw = stand_ins.get(name, b"fixture")
                path.write_bytes(raw)
                inventory[name] = hashlib.sha256(raw).hexdigest()
            manifest = {"schema": "objectshard-m4-workbench-package-v1", "source_commit": "1" * 40,
                        "source_tree": "2" * 40, "entry": ENTRY, "ordinary_production_defaults_changed": False,
                        "native": {"source_inputs": {}}, "files_sha256": inventory}

            def refusal(expected):
                (root / MANIFEST).write_text(json.dumps(manifest), encoding="utf-8")
                result = subprocess.run([shell, "-NoProfile", "-NonInteractive", "-File", str(script), "-Package", str(root)],
                                        capture_output=True, text=True, timeout=30)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(expected, result.stdout + result.stderr)

            # The synthetic native/engine package is intentionally incomplete.
            # A consistent generator reaches the independent native-runtime check.
            refusal("Unexpected runtime paths")
            manifest["entry"] = dict(ENTRY, scenario_ids=ENTRY["scenario_ids"][:-1])
            refusal("Incomplete ordinary Workbench entry contract")
            manifest["entry"] = ENTRY
            (root / generator).write_bytes(data[::-1])
            inventory[generator] = hashlib.sha256(data[::-1]).hexdigest()
            refusal("Windows reciprocal generator differs")
            foreign = root / "godot/tools/swarm004-runtime.linux.json"
            foreign.write_text("{}")
            inventory[foreign.relative_to(root).as_posix()] = hashlib.sha256(b"{}").hexdigest()
            refusal("Foreign reciprocal generator input")
            del inventory[reopen]
            refusal("Missing inventory")
            for name in (generator, binding, reopen, foreign.relative_to(root).as_posix()):
                inventory.pop(name, None)
                (root / name).unlink()
            # A pre-SWARM evaluator reaches its own ordinary native checks.
            refusal("Unexpected runtime paths")
            manifest["native"]["source_inputs"]["native/include/cybersand/workbench_authoring_patch.hpp"] = "a" * 64
            refusal("Missing inventory")
            manifest["native"]["source_inputs"].clear()
            inventory["godot/scripts/workbench_reciprocal_panel.gd"] = "a" * 64
            refusal("Missing inventory")


if __name__ == "__main__":
    unittest.main()
