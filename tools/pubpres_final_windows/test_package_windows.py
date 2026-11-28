#!/usr/bin/env python3
"""Adversarial manifest tests. Synthetic PE bytes never qualify a runtime."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

import package_windows as package

spec = importlib.util.spec_from_file_location("frozen_package_tests", package.ROOT / package.LEGACY / "test_package_windows.py")
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)


class FinalPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.record = fixtures.fixture(self.root)
        self.candidate = self.record["candidate_commit"]
        self.record["sources"] = {"C": self.record["sources"]["C"]}
        for key in ("M", "I"):
            shutil.rmtree(self.root / "sources" / key)
        self.record.update(schema=package.SCHEMA, mission=package.MISSION, defaults=copy.deepcopy(package.DEFAULTS),
                           package_filename=f"CyberSand-{package.MISSION}-{self.candidate[:12]}-Windows.zip",
                           patched_engine=None, owner_launcher=package.TOOLS + "/Start-PUBPRES-Final.ps1",
                           owner_observer=package.TOOLS + "/owner_start.gd",
                           owner_results_collector=package.TOOLS + "/Collect-Results.ps1",
                           owner_commands={"Open Workbench.cmd": "ordinary", "Open Wave 512.cmd": "wave512",
                                           "Open Wave 1024.cmd": "wave1024", "Open Wave 2048.cmd": "wave2048",
                                           "Open Mixed 2048.cmd": "mixed2048"})
        for name, scene in self.record["owner_commands"].items():
            fixtures.put(self.root, name, package.command(self.candidate, scene))
        fixtures.put(self.root, "Collect Results.cmd", package.command(self.candidate, collector=True))
        for name in ("Start-PUBPRES-Final.ps1", "owner_start.gd", "Collect-Results.ps1", "ACCEPTANCE.md"):
            fixtures.put(self.root, package.TOOLS + "/" + name, "synthetic source-only " + name + "\n")
        fixtures.put(self.root, "ACCEPTANCE.md", (self.root / package.TOOLS / "ACCEPTANCE.md").read_bytes())
        fixtures.put(self.root, "tools/pubpres_final/registration.json", json.dumps({
            "schema": "pubpres-playability-final-registration-v1", "predecessor": {"source": package.DONOR}}))
        self.pins = mock.patch.dict(package.base.GODOT_EXECUTABLE_SHA256,
            {entry["path"]: entry["sha256"] for entry in (self.record["engine"]["gui"], self.record["engine"]["console"])}, clear=True)
        self.pins.start()
        self.save()

    def tearDown(self):
        self.pins.stop()
        self.temp.cleanup()

    def save(self):
        fixtures.save(self.root, self.record)

    def verify(self):
        return package.verify(self.root, self.candidate)

    def test_source_and_dependency_closure_admitted_with_test_only_pins(self):
        self.assertEqual(set(self.verify()["sources"]), {"C"})

    def test_self_consistent_changed_defaults_remain_refused(self):
        for key, value in (("engine", "egl"), ("render_thread", "separate"), ("full_image_slots", 3),
                           ("material", "blit"), ("same_frame_continuation", "on")):
            with self.subTest(key=key):
                original = self.record["defaults"][key]
                self.record["defaults"][key] = value
                self.save()
                with self.assertRaisesRegex(ValueError, "identity/default/HOLD"):
                    self.verify()
                self.record["defaults"][key] = original

    def test_source_substitution_fails_even_after_inventory_rehash(self):
        source = self.record["sources"]["C"]
        receipt = self.root / source["native"]["receipt"]
        native = json.loads(receipt.read_text())
        native["source_commit"] = "f" * 40
        package.write_json(receipt, native)
        source["native"]["receipt_sha256"] = package.digest(receipt)
        self.save()
        with self.assertRaisesRegex(ValueError, "native receipt substitution"):
            self.verify()

    def test_extra_compiled_input_not_in_native_closure_is_rejected(self):
        fixtures.put(self.root, "sources/C/native/src/undeclared.cpp", "unregistered native input\n")
        self.save()
        with self.assertRaisesRegex(ValueError, "closure set"):
            self.verify()

    def test_source_binary_and_command_corruption_are_rejected(self):
        for relative in (self.record["sources"]["C"]["native"]["path"], "Open Workbench.cmd"):
            with self.subTest(path=relative):
                path = self.root / relative
                original = path.read_bytes()
                path.write_bytes(original + b"changed")
                with self.assertRaisesRegex(ValueError, "missing, changed or unexpected"):
                    self.verify()
                path.write_bytes(original)

    def test_rehashed_default_launcher_cannot_select_experiment(self):
        path = self.root / "Open Workbench.cmd"
        path.write_bytes(path.read_bytes().replace(b" -Action Open", b" -FullImageSlots 3 -Action Open"))
        self.save()
        with self.assertRaisesRegex(ValueError, "Owner command differs"):
            self.verify()

    def test_new_candidate_cannot_masquerade_as_frozen_donor(self):
        self.record["sources"]["D"] = copy.deepcopy(self.record["sources"]["C"])
        self.save()
        with self.assertRaisesRegex(ValueError, "Frozen donor"):
            self.verify()

    def test_patched_engine_requires_exact_original_artifact(self):
        self.record["patched_engine"] = {"root": "engines/egl", "gui": {"path": package.PATCHED_GUI, "sha256": "0" * 64}, "default": False}
        self.save()
        with self.assertRaisesRegex(ValueError, "Patched engine role"):
            self.verify()

    def test_held_artifact_cannot_claim_acceptance(self):
        self.record["physical_acceptance"] = "PASS"
        self.save()
        with self.assertRaisesRegex(ValueError, "HOLD"):
            self.verify()

    def test_default_commands_are_explicit_source_and_never_experimental(self):
        for scene in package.SCENES:
            text = package.command(self.candidate, scene).decode("ascii")
            self.assertIn("-ExpectedCandidate " + self.candidate, text)
            self.assertIn("-Scene " + scene, text)
            self.assertNotIn("-FullImageSlots 3", text)
            self.assertNotIn("-Engine Egl", text)
        with self.assertRaises(ValueError):
            package.command(self.candidate, "unknown")


if __name__ == "__main__":
    unittest.main()
