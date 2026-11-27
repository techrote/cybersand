"""Exercise exact source staging without granting generated-source exceptions."""
from __future__ import annotations

import hashlib
import io
from pathlib import Path
import struct
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import runtime_custody as custody
import stage_source as stage


def binary(platform, payload=b""):
    value = bytearray(128)
    if platform == "windows":
        value[:2] = b"MZ"
        struct.pack_into("<I", value, 0x3c, 64)
        value[64:70] = b"PE\0\0\x64\x86"
    else:
        value[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<H", value, 18, 62)
    return bytes(value) + payload


class PlatformSourceStage(unittest.TestCase):
    def check_layout(self, platform):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "source"
            root.mkdir()
            runtime = Path(temporary) / "runtime"
            runtime.mkdir()
            destination = Path(temporary) / "installed"
            native, cli, rapier = (binary(platform, payload) for payload in (b"native", b"cli", b"rapier"))
            names = custody.names(platform)
            rapier_name = stage.RAPIERS[platform]
            for name, payload in ((names["extension"], native), (names["cli"], cli), (custody.NAME, b"exact runtime manifest")):
                (runtime / name).write_bytes(payload)
            retained = root / rapier_name
            retained.parent.mkdir(parents=True)
            retained.write_bytes(rapier)
            source = {"godot/project.godot": b"committed project\n", "godot/scripts/example.gd": b"extends Node\n"}
            for name, payload in source.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(payload)
            pointer = ("version https://git-lfs.github.com/spec/v1\noid sha256:" + hashlib.sha256(rapier).hexdigest()
                       + "\nsize " + str(len(rapier)) + "\n").encode()
            archived = {**source, rapier_name: pointer,
                        "godot/tools/gentek_reciprocal": b"unmaterialized other-platform pointer",
                        "godot/tools/gentek_reciprocal.exe": b"unmaterialized stale retained CLI",
                        "godot/tools/swarm004-runtime.linux.json": b"stale foreign binding",
                        "godot/tools/swarm004-runtime.windows.json": b"stale Windows binding"}
            payload = io.BytesIO()
            with tarfile.open(fileobj=payload, mode="w") as archive:
                for name, data in archived.items():
                    item = tarfile.TarInfo(name)
                    item.size, item.mode = len(data), 0o644
                    archive.addfile(item, io.BytesIO(data))
            receipt = {"source_commit": "a" * 40, "build_commit": "a" * 40, "source_tree": "b" * 40,
                       "platform": platform, **names, "build_context": {"run_id": "123", "run_attempt": "1"},
                       "build_inputs_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in source.items()},
                       "native_definition_sha256": "c" * 64, "native_definition_inputs_sha256": {"native/input.cpp": "d" * 64},
                       "files": {names["extension"]: {"sha256": hashlib.sha256(native).hexdigest(), "bytes": len(native)},
                                 names["cli"]: {"sha256": hashlib.sha256(cli).hexdigest(), "bytes": len(cli)}}}
            with patch.object(custody, "ROOT", root), patch.object(custody, "verify", return_value=receipt) as guard, \
                 patch.object(stage.generic, "committed_lfs_pins", return_value={rapier_name: (hashlib.sha256(rapier).hexdigest(), len(rapier))}), \
                 patch.object(stage, "committed_archive", return_value=payload.getvalue()), \
                 patch.object(stage.generic, "stage_generator_profiles", return_value={}):
                result = stage.stage(runtime, destination)
                self.assertEqual(guard.call_count, 3)
            self.assertTrue(result["source_checkout_untouched"])
            installed_cli = destination / "godot/tools" / names["cli"]
            self.assertEqual(installed_cli.read_bytes(), cli)
            foreign = "linux" if platform == "windows" else "windows"
            self.assertFalse((destination / "godot/tools" / custody.names(foreign)["cli"]).exists())
            self.assertFalse((destination / ("godot/tools/swarm004-runtime." + foreign + ".json")).exists())
            self.assertTrue((destination / ("godot/tools/swarm004-runtime." + platform + ".json")).is_file())
            if platform == "linux":
                self.assertEqual(installed_cli.stat().st_mode & 0o777, 0o755)
            for name, data in source.items():
                self.assertEqual((destination / name).read_bytes(), data)
                self.assertEqual((root / name).read_bytes(), data)
            uid = destination / "godot/scripts/example.gd.uid"
            uid.write_text("uid://generated-by-godot\n")
            self.assertFalse((root / "godot/scripts/example.gd.uid").exists())
            self.assertEqual((root / "godot/scripts/example.gd").read_bytes(), source["godot/scripts/example.gd"])

    def test_source_is_exact_and_generated_uid_remains_outside_checkout(self):
        for platform in ("linux", "windows"):
            with self.subTest(platform=platform):
                self.check_layout(platform)

    def test_source_checkout_and_existing_destinations_are_refused_before_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            existing = root.parent / root.name / "already-exists"
            existing.mkdir()
            with patch.object(custody, "ROOT", root), patch.object(custody, "verify") as guard:
                for destination in (root / "inside-source", existing):
                    with self.subTest(destination=destination), self.assertRaisesRegex(ValueError, "outside the source checkout"):
                        stage.stage(root / "runtime", destination)
                guard.assert_not_called()


if __name__ == "__main__":
    unittest.main()
