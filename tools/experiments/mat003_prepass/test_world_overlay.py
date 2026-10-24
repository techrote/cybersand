"""Source-isolation and refusal tests; these are not World execution evidence."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from world_overlay import EXPERIMENT, _replace, prepare_overlay

ROOT = Path(__file__).resolve().parents[3]


class WorldOverlayContracts(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="mat003-overlay-")
        self.addCleanup(self.temporary.cleanup)
        self.workspace = Path(self.temporary.name)
        self.source = self.workspace / "source"
        self.registration = json.loads((ROOT / EXPERIMENT / "world_registration.json").read_text())
        inputs = set(self.registration["baseline_control_sha256"])
        inputs.update((EXPERIMENT / name).as_posix() for name in
                      ("world_registration.json", "world_adapter.hpp", "world_overlay.py", "carriers.hpp"))
        for name in inputs:
            destination = self.source / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, destination)

    def arm(self, identifier: str) -> dict:
        return next(a for a in self.registration["arms"] if a["id"] == identifier)

    def test_all_registered_arms_preserve_inputs_and_reconstruct_exactly(self) -> None:
        original = {name: (self.source / name).read_bytes()
                    for name in self.registration["baseline_control_sha256"]}
        for arm in self.registration["arms"]:
            with self.subTest(arm=arm["id"]):
                destination = self.workspace / arm["id"]
                receipt = prepare_overlay(self.source, destination, arm)
                generated = dict(original)
                for patch in receipt["patches"]:
                    before, after = patch["before"].encode(), patch["after"].encode()
                    self.assertEqual(generated[patch["path"]].count(before), 1)
                    generated[patch["path"]] = generated[patch["path"]].replace(before, after, 1)
                for entry in receipt["files"]:
                    path = entry["path"]
                    self.assertEqual((destination / path).read_bytes(), generated[path])
                    self.assertEqual(entry["input_sha256"], hashlib.sha256(original[path]).hexdigest())
                    self.assertEqual(entry["output_sha256"], hashlib.sha256(generated[path]).hexdigest())
                    self.assertEqual((self.source / path).read_bytes(), original[path])
                if arm["representation"] == "source":
                    self.assertEqual(receipt["patches"], [])
                    self.assertFalse(receipt["dispatch_observed"])
                    self.assertTrue(receipt["source_control_unchanged"])
                else:
                    self.assertTrue(receipt["dispatch_observed"])
                    self.assertFalse(receipt["source_control_unchanged"])
                    header = generated["native/include/cybersand/world.hpp"].decode()
                    implementation = generated["native/src/world.cpp"].decode()
                    self.assertIn("mat003_world::Epoch update_epoch_ = 0;", header)
                    self.assertNotIn("std::uint8_t update_epoch_", header)
                    self.assertIn("static_cast<mat003_world::Epoch>(update_epoch_ + 1U)", implementation)
                    self.assertNotIn("static_cast<std::uint8_t>(update_epoch_ + 1U)", implementation)

    def test_existing_output_is_refused_and_not_modified(self) -> None:
        destination = self.workspace / "existing"
        destination.mkdir()
        sentinel = destination / "preserve-me"
        sentinel.write_text("actual prior evidence")
        with self.assertRaisesRegex(ValueError, "existing overlay"):
            prepare_overlay(self.source, destination, self.arm("C64-E8-source"))
        self.assertEqual(sentinel.read_text(), "actual prior evidence")
        self.assertEqual(list(destination.iterdir()), [sentinel])

    def test_output_inside_snapshot_is_refused(self) -> None:
        destination = self.source / "new-overlay"
        with self.assertRaisesRegex(ValueError, "outside the immutable input"):
            prepare_overlay(self.source, destination, self.arm("C64-E16-word"))
        self.assertFalse(destination.exists())

    def test_source_drift_is_refused_before_creating_overlay(self) -> None:
        path = self.source / "native/src/world.cpp"
        path.write_bytes(path.read_bytes() + b"\n// unregistered source change\n")
        destination = self.workspace / "changed-source"
        with self.assertRaisesRegex(ValueError, "frozen production source drift"):
            prepare_overlay(self.source, destination, self.arm("C64-E16-word"))
        self.assertFalse(destination.exists())

    def test_modified_or_unknown_arm_is_refused(self) -> None:
        candidate = copy.deepcopy(self.arm("C72-E16-split"))
        candidate["epoch_bits"] = 8
        with self.assertRaisesRegex(ValueError, "exactly match"):
            prepare_overlay(self.source, self.workspace / "changed-arm", candidate)
        candidate["id"] = "not-registered"
        with self.assertRaisesRegex(ValueError, "exactly match"):
            prepare_overlay(self.source, self.workspace / "unknown-arm", candidate)

    def test_missing_internal_dependency_registration_is_refused(self) -> None:
        registration = copy.deepcopy(self.registration)
        del registration["baseline_control_sha256"]["native/src/render_snapshot_internal.hpp"]
        (self.source / EXPERIMENT / "world_registration.json").write_text(json.dumps(registration))
        destination = self.workspace / "missing-header"
        with self.assertRaisesRegex(ValueError, "omits compiled render_snapshot_internal"):
            prepare_overlay(self.source, destination, self.arm("C64-E8-source"))
        self.assertFalse(destination.exists())

    def test_missing_or_duplicate_patch_anchor_is_refused(self) -> None:
        for source in ("no matching fragment", "target target"):
            with self.subTest(source=source):
                patches = []
                with self.assertRaisesRegex(ValueError, "expected one frozen fragment"):
                    _replace(source, "target", "replacement", "test anchor", patches, "test.cpp")
                self.assertEqual(patches, [])


if __name__ == "__main__":
    unittest.main()
