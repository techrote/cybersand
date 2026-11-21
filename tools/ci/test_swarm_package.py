"""Post-publication LFS regression for the ordinary Windows evaluator packager."""
import hashlib
import io
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_explore001_candidate as package


class SwarmPackageTests(unittest.TestCase):
    def test_windows_package_materializes_only_its_bound_cli(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            cli = root / "godot/tools/gentek_reciprocal.exe"
            cli.parent.mkdir(parents=True)
            original = b"fixture Windows executable bytes; not execution evidence"
            cli.write_bytes(original)
            pointer = ("version https://git-lfs.github.com/spec/v1\noid sha256:"
                       + hashlib.sha256(original).hexdigest() + "\nsize " + str(len(original)) + "\n").encode()
            candidate = root / "candidate"
            candidate.mkdir()
            (candidate / Path(package.native.NATIVE).name).write_bytes(b"source-built adapter fixture")
            archived = {
                "godot/project.godot": b"committed project",
                package.native.NATIVE: b"retained adapter replaced from source candidate",
                "godot/tools/gentek_reciprocal": pointer,
                "godot/tools/swarm004-runtime.linux.json": b"Linux binding",
                "godot/tools/gentek_reciprocal.exe": pointer,
                "godot/tools/swarm004-runtime.windows.json": b"Windows binding",
            }
            stream = io.BytesIO()
            with tarfile.open(fileobj=stream, mode="w") as archive:
                for name, data in archived.items():
                    item = tarfile.TarInfo(name)
                    item.size = len(data)
                    archive.addfile(item, io.BytesIO(data))
            destination = root / "delivered"
            package.stage_project_archive(stream.getvalue(), candidate, destination, root)
            self.assertEqual((destination / "godot/tools/gentek_reciprocal.exe").read_bytes(), original)
            self.assertEqual((destination / package.native.NATIVE).read_bytes(), b"source-built adapter fixture")
            self.assertEqual((destination / "godot/project.godot").read_bytes(), b"committed project")
            self.assertTrue((destination / "godot/tools/swarm004-runtime.windows.json").is_file())
            self.assertFalse((destination / "godot/tools/gentek_reciprocal").exists())
            self.assertFalse((destination / "godot/tools/swarm004-runtime.linux.json").exists())
            # A present pointer or changed Windows executable must never ship.
            for invalid in (pointer, original + b"changed"):
                cli.write_bytes(invalid)
                with self.assertRaisesRegex(ValueError, "Unmaterialized or changed LFS"):
                    package.stage_project_archive(stream.getvalue(), candidate, root / "rejected", root)


if __name__ == "__main__":
    unittest.main()
