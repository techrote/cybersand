"""Post-publication LFS regression for the ordinary Windows evaluator packager."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_explore001_candidate as package


class SwarmPackageTests(unittest.TestCase):
    def test_windows_archive_preserves_import_bytes_and_explicit_attributes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            def git(*args):
                return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.DEVNULL)

            git("init", "-q")
            git("config", "user.name", "Package archive regression")
            git("config", "user.email", "archive-regression@example.invalid")
            git("config", "core.autocrlf", "false")
            (root / ".gitattributes").write_bytes(b"* text=auto\n*.cmd text eol=crlf\n*.bin -text\n")
            folder = root / "godot/addons/godot-rapier2d"
            folder.mkdir(parents=True)
            before = b'[remap]\nimporter="texture"\n[params]\nsvg/scale=1.0\neditor/scale_with_editor_scale=true\n'
            name = "godot/addons/godot-rapier2d/Radial2D.svg.import"
            (root / name).write_bytes(before)
            (root / "godot/explicit.cmd").write_bytes(b"@echo off\necho explicit CRLF attribute\n")
            (root / "godot/payload.bin").write_bytes(b"\x00binary\r\nbytes\n")
            git("add", ".")
            git("commit", "-qm", "Exact import metadata fixture")
            git("config", "core.autocrlf", "true")
            git("config", "core.eol", "crlf")

            def contents(payload):
                with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
                    return {item.name: archive.extractfile(item).read() for item in archive if item.isfile()}

            old = contents(git("archive", "HEAD", "--", "godot"))
            self.assertNotEqual(old[name], before)
            self.assertEqual(old[name].replace(b"\r\n", b"\n"), before)
            # The pinned editor's LF rewrite has an actual different raw hash
            # in the old Windows archive. The fixed producer seals LF bytes.
            self.assertNotEqual(hashlib.sha256(old[name]).hexdigest(), hashlib.sha256(before).hexdigest())
            fixed = contents(package.committed_archive(["godot"], root))
            self.assertEqual(fixed[name], before)
            self.assertEqual(fixed["godot/explicit.cmd"], b"@echo off\r\necho explicit CRLF attribute\r\n")
            self.assertEqual(fixed["godot/payload.bin"], b"\x00binary\r\nbytes\n")
            self.assertEqual(set(fixed), set(old))
            self.assertEqual(git("config", "core.autocrlf").strip(), b"true")
            self.assertEqual(git("config", "core.eol").strip(), b"crlf")

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
                "godot/tools/swarm004-runtime.windows.json": json.dumps({
                    "platform": "windows", "artifact": "godot/tools/gentek_reciprocal.exe",
                    "sha256": hashlib.sha256(original).hexdigest(), "bytes": len(original),
                }).encode(),
            }
            def archive_bytes(files):
                stream = io.BytesIO()
                with tarfile.open(fileobj=stream, mode="w") as archive:
                    for name, data in files.items():
                        item = tarfile.TarInfo(name)
                        item.size = len(data)
                        archive.addfile(item, io.BytesIO(data))
                return stream.getvalue()

            archive = archive_bytes(archived)
            destination = root / "delivered"
            package.stage_project_archive(archive, candidate, destination, root)
            self.assertEqual((destination / "godot/tools/gentek_reciprocal.exe").read_bytes(), original)
            self.assertEqual((destination / package.native.NATIVE).read_bytes(), b"source-built adapter fixture")
            self.assertEqual((destination / "godot/project.godot").read_bytes(), b"committed project")
            self.assertTrue((destination / "godot/tools/swarm004-runtime.windows.json").is_file())
            self.assertFalse((destination / "godot/tools/gentek_reciprocal").exists())
            self.assertFalse((destination / "godot/tools/swarm004-runtime.linux.json").exists())
            # The collaborative Art evaluator uses committed native/LFS bytes.
            retained = root / package.native.NATIVE
            retained.parent.mkdir(parents=True)
            retained.write_bytes(original)
            art_inputs = {**archived, package.native.NATIVE: pointer}
            art = root / "art"
            package.stage_project_archive(archive_bytes(art_inputs), None, art, root)
            self.assertEqual((art / package.native.NATIVE).read_bytes(), original)
            self.assertFalse((art / "godot/tools/gentek_reciprocal").exists())
            self.assertEqual((art / "godot/tools/gentek_reciprocal.exe").read_bytes(), original)
            key = "godot/tools/swarm004-runtime.windows.json"
            bad_binding = json.loads(art_inputs[key])
            bad_binding["sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "differs from its Windows source binding"):
                package.stage_project_archive(archive_bytes({**art_inputs, key: json.dumps(bad_binding).encode()}),
                                              None, root / "foreign-binding", root)
            historical = {name: data for name, data in art_inputs.items() if not name.startswith("godot/tools/")}
            package.stage_project_archive(archive_bytes(historical), None, root / "historical", root)
            self.assertFalse((root / "historical/godot/tools").exists())
            with self.assertRaisesRegex(ValueError, "Missing Windows reciprocal generator or source binding"):
                package.stage_project_archive(
                    archive_bytes({**historical, "godot/scripts/workbench_reciprocal_protocol.gd": b"fixture"}),
                    None, root / "missing-reciprocal", root)
            retained.write_bytes(b"wrong retained adapter")
            with self.assertRaisesRegex(ValueError, "Unmaterialized or changed LFS"):
                package.stage_project_archive(archive_bytes(art_inputs), None, root / "corrupt-native", root)
            # A present pointer or changed Windows executable must never ship.
            for invalid in (pointer, original + b"changed"):
                cli.write_bytes(invalid)
                with self.assertRaisesRegex(ValueError, "Unmaterialized or changed LFS"):
                    package.stage_project_archive(archive, candidate, root / "rejected", root)


if __name__ == "__main__":
    unittest.main()
