"""Exercise the installed Linux layout after ordinary CLI LFS publication."""
from __future__ import annotations

import hashlib
import io
from pathlib import Path
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from accepted_main_smokes import Runner
import run_workbench_qualification as stage


class LinuxInstalledLayout(unittest.TestCase):
    def test_only_linux_cli_is_materialized_and_execute_mode_survives_archive(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            native = "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
            rapier = "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
            linux = "godot/tools/gentek_reciprocal"
            windows = linux + ".exe"
            payload = b"\x7fELFfixture-only-never-executed"
            sha = hashlib.sha256(payload).hexdigest()
            pointer = f"version https://git-lfs.github.com/spec/v1\noid sha256:{sha}\nsize {len(payload)}\n".encode()
            for name in (native, rapier, linux):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(payload)
            files = {native: pointer, rapier: pointer, linux: pointer, windows: pointer,
                     "godot/tools/swarm004-runtime.linux.json": b'{"platform":"linux"}',
                     "godot/tools/swarm004-runtime.windows.json": b'{"platform":"windows"}',
                     "godot/project.godot": b"committed project"}
            stream = io.BytesIO()
            with tarfile.open(fileobj=stream, mode="w") as archive:
                for name, value in files.items():
                    entry = tarfile.TarInfo(name)
                    entry.size, entry.mode = len(value), 0o755 if name == linux else 0o644
                    archive.addfile(entry, io.BytesIO(value))
            destination = root / "installed"
            with patch.object(stage, "ROOT", root), patch.object(stage.native_candidate_identity, "source", return_value=("a" * 40, "b" * 40, {})), \
                 patch.object(stage, "committed_lfs_pins", return_value={name: (sha, len(payload)) for name in (native, rapier, linux, windows)}), \
                 patch.object(stage.subprocess, "run"), patch.object(stage.subprocess, "check_output", return_value=stream.getvalue()), \
                 patch.object(stage, "stage_generator_profiles", return_value={}):
                stage.stage_linux(SimpleNamespace(output=destination, reciprocal_candidate=None))
            self.assertEqual((destination / linux).read_bytes(), payload)
            self.assertEqual((destination / linux).stat().st_mode & 0o777, 0o755)
            self.assertTrue((destination / "godot/tools/swarm004-runtime.linux.json").is_file())
            self.assertFalse((destination / windows).exists())
            self.assertFalse((destination / "godot/tools/swarm004-runtime.windows.json").exists())


if __name__ == "__main__":
    unittest.main()
