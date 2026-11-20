#!/usr/bin/env python3
"""Tiny-file adverse controls for final package custody, never runtime claims."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import stat
import struct
import tempfile
import unittest
import warnings
import zipfile

import package_retained_gentek80 as package
import run_final_admission as execution


class PackageBoundaryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="gentek80-final-package-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def archive(self, entries):
        archive = self.root / "fixture.zip"
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(archive, "w") as output:
                for name, data in entries:
                    output.writestr(name, data)
        return archive

    def unpack(self, archive, name="extracted"):
        destination = self.root / name
        package.extract_pristine(archive, destination, package.sha(archive))
        return destination

    def inventory(self):
        directory = self.root / "package"
        directory.mkdir()
        files = {"godot/project.godot": b"application source\n",
                 "godot/scripts/main.gd": b"extends Node\n",
                 package.NATIVE: b"synthetic retained DLL bytes\n",
                 package.CONSOLE: b"synthetic pinned Godot bytes\n",
                 "godot/icon.svg.import": b"initial import metadata\n",
                 "godot/scripts/main.gd.uid": b"initial UID metadata\n",
                 "TEST-IT.md": b"owner usage instructions\n"}
        for name, data in files.items():
            path = directory / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        manifest = {"files_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}}
        package.write_json(directory / package.MANIFEST, manifest)
        return directory, manifest

    def test_pristine_zip_extracts_exact_original_bytes(self):
        archive = self.archive([("godot/project.godot", b"source\n"), ("Godot.exe", b"tiny fixture\0")])
        destination = self.unpack(archive)
        self.assertEqual((destination / "godot/project.godot").read_bytes(), b"source\n")
        self.assertEqual((destination / "Godot.exe").read_bytes(), b"tiny fixture\0")

    def test_digest_mismatch_and_existing_destination_refuse_without_overwrite(self):
        archive = self.archive([("data.txt", b"archive payload")])
        destination = self.root / "destination"
        with self.assertRaisesRegex(ValueError, "digest mismatch"):
            package.extract_pristine(archive, destination, "0" * 64)
        self.assertFalse(destination.exists())
        destination.mkdir()
        sentinel = destination / "keep.txt"
        sentinel.write_bytes(b"existing owner data")
        with self.assertRaisesRegex(ValueError, "new directory"):
            package.extract_pristine(archive, destination, package.sha(archive))
        self.assertEqual(sentinel.read_bytes(), b"existing owner data")

    def test_absolute_traversal_backslash_drive_and_noncanonical_members_are_rejected(self):
        bad_names = ["../escape", "godot/../../escape", "/absolute", "C:/drive.txt",
                     "godot\\escape", "godot/./main.gd", "godot//main.gd"]
        for index, name in enumerate(bad_names):
            with self.subTest(name=name):
                archive = self.archive([(name, b"invalid member")])
                with self.assertRaises(ValueError):
                    self.unpack(archive, "bad-" + str(index))
        self.assertFalse((self.root / "escape").exists())

    def test_duplicate_and_case_colliding_members_are_rejected(self):
        for index, names in enumerate((("same.txt", "same.txt"), ("Godot.exe", "godot.exe"))):
            with self.subTest(names=names):
                archive = self.archive([(name, b"fixture") for name in names])
                with self.assertRaisesRegex(ValueError, "Duplicate package member"):
                    self.unpack(archive, "duplicates-" + str(index))

    def test_zip_symlink_is_rejected(self):
        entry = zipfile.ZipInfo("godot/link")
        entry.create_system = 3
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        archive = self.archive([(entry, b"../../outside")])
        with self.assertRaisesRegex(ValueError, "symlinks are forbidden"):
            self.unpack(archive)

    def test_advertised_oversize_member_is_refused_before_extraction(self):
        archive = self.archive([("huge.bin", b"tiny actual payload")])
        data = bytearray(archive.read_bytes())
        central = data.index(b"PK\x01\x02")
        struct.pack_into("<I", data, central + 24, 512 * 1024 * 1024 + 1)
        archive.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "bounded payload"):
            self.unpack(archive)
        self.assertFalse((self.root / "extracted/huge.bin").exists())

    def test_pristine_inventory_rejects_missing_changed_extra_or_linked_files(self):
        directory, manifest = self.inventory()
        package.verify_inventory(directory, manifest)
        path = directory / "godot/scripts/main.gd"
        original = path.read_bytes()
        path.write_bytes(b"changed script")
        with self.assertRaisesRegex(ValueError, "Missing or altered"):
            package.verify_inventory(directory, manifest)
        path.unlink()
        with self.assertRaisesRegex(ValueError, "Missing or altered"):
            package.verify_inventory(directory, manifest)
        path.write_bytes(original)
        extra = directory / "extra.txt"
        extra.write_bytes(b"unrecorded")
        with self.assertRaisesRegex(ValueError, "missing or extra"):
            package.verify_inventory(directory, manifest)
        extra.unlink()
        link = directory / "unrecorded-link"
        link.symlink_to(path)
        with self.assertRaisesRegex(ValueError, "symlink"):
            package.verify_inventory(directory, manifest)

    def test_package_identity_distinguishes_built_and_published_sources(self):
        final, tree, built, native = "a" * 40, "b" * 40, "c" * 40, "d" * 64
        baseline = {"schema": 1, "kind": "gentek80-retained-runtime-evaluation", "source_commit": final,
                    "source_tree": tree, "native_build_commit": built, "native_sha256": native}
        package.identity_fields(baseline, final, tree, built, native)
        mutations = [dict(source_commit=built), dict(source_tree="e" * 40),
                     dict(native_build_commit=final), dict(native_sha256="e" * 64),
                     dict(build_commit=final), dict(kind="source-built-candidate"), dict(schema=True)]
        for change in mutations:
            with self.subTest(change=change), self.assertRaises(ValueError):
                package.identity_fields(dict(baseline, **change), final, tree, built, native)
        with self.assertRaisesRegex(ValueError, "must not fabricate"):
            package.identity_fields(dict(baseline, source_commit=built), built, tree, built, native)

    def test_post_import_allows_only_documented_editor_uid_and_import_metadata(self):
        directory, manifest = self.inventory()
        for name in ("godot/icon.svg.import", "godot/scripts/main.gd.uid"):
            (directory / name).write_bytes(b"regenerated metadata")
        for name in ("godot/.godot/editor/project_metadata.cfg", "godot/new.svg.import", "godot/new.gd.uid"):
            path = directory / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"new editor metadata")
        result = execution.protected_after(directory, manifest)
        self.assertEqual(len(result["permitted_metadata_changes"]), 2)
        self.assertEqual(len(result["generated_metadata_sha256"]), 3)
        self.assertEqual(result["protected_files"], len(manifest["files_sha256"]))

    def test_post_import_rejects_source_runtime_engine_guide_changes_and_deletion(self):
        directory, manifest = self.inventory()
        for name in ("godot/scripts/main.gd", package.NATIVE, package.CONSOLE, "TEST-IT.md"):
            with self.subTest(name=name):
                path = directory / name
                original = path.read_bytes()
                path.write_bytes(original + b"modified")
                with self.assertRaisesRegex(ValueError, "Protected package file changed"):
                    execution.protected_after(directory, manifest)
                path.write_bytes(original)
        (directory / "godot/scripts/main.gd.uid").unlink()
        with self.assertRaisesRegex(ValueError, "Package file removed"):
            execution.protected_after(directory, manifest)

    def test_post_import_rejects_unexpected_source_or_user_payloads(self):
        directory, manifest = self.inventory()
        for name in ("godot/scripts/new.gd", "godot/authoring/new.json", "other.txt"):
            with self.subTest(name=name):
                path = directory / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"not metadata")
                with self.assertRaisesRegex(ValueError, "Unexpected file added"):
                    execution.protected_after(directory, manifest)
                path.unlink()

    def test_post_import_rejects_dangling_and_directory_symlinks(self):
        directory, manifest = self.inventory()
        metadata = directory / "godot/.godot"
        metadata.mkdir()
        outside = self.root / "outside"
        outside.mkdir()
        for name, target in (("dangling", outside / "absent"), ("directory", outside)):
            with self.subTest(name=name):
                link = metadata / name
                link.symlink_to(target, target_is_directory=name == "directory")
                with self.assertRaisesRegex(ValueError, "symlink"):
                    execution.protected_after(directory, manifest)
                link.unlink()

    def process_fixture(self, flatten=False):
        output = self.root / "execution"
        output.mkdir(exist_ok=True)
        project = self.root / "godot"
        project.mkdir(exist_ok=True)
        engine = self.root / "Godot.exe"
        engine.write_bytes(b"tiny pinned engine fixture")
        name = "flatten-import" if flatten else "author"
        log = output / (name + ".log")
        log.write_bytes(b"original native-runner log fixture")
        row = {"label" if flatten else "case": name,
               "command": [str(engine), "--path", str(project)], "status": "passed"}
        if flatten:
            row.update(engine_executable=str(engine), engine_executable_sha256=package.sha(engine))
        else:
            row["log_sha256"] = package.sha(log)
            package.write_json(output / (name + "-process.json"), row)
        return row, output, project, engine

    def test_process_binding_preserves_original_receipt_and_log_hashes(self):
        row, output, project, engine = self.process_fixture()
        result = execution.process_binding([row, {"case": "source-stability"}], output, project, engine)
        self.assertEqual(result, {name: package.sha(output / name) for name in ("author-process.json", "author.log")})

    def test_process_binding_rejects_other_engine_project_and_duplicate_path_flags(self):
        row, output, project, engine = self.process_fixture()
        commands = [[str(engine.with_name("another.exe")), "--path", str(project)],
                    [str(engine), "--path", str(project.with_name("another-project"))],
                    [str(engine), "--path", str(project), "--path", str(project)]]
        for command in commands:
            with self.subTest(command=command), self.assertRaisesRegex(ValueError, "another engine or project"):
                execution.process_binding([dict(row, command=command)], output, project, engine)

    def test_process_binding_rejects_changed_original_receipt_and_log(self):
        row, output, project, engine = self.process_fixture()
        process = output / "author-process.json"
        package.write_json(process, dict(row, status="failed"))
        with self.assertRaisesRegex(ValueError, "receipt differs"):
            execution.process_binding([row], output, project, engine)
        package.write_json(process, row)
        (output / "author.log").write_bytes(b"changed native log")
        with self.assertRaisesRegex(ValueError, "log hash mismatch"):
            execution.process_binding([row], output, project, engine)

    def test_flatten_process_binding_requires_the_measured_engine_identity(self):
        row, output, project, engine = self.process_fixture(flatten=True)
        self.assertEqual(execution.process_binding([row], output, project, engine, flatten=True),
                         {"flatten-import.log": package.sha(output / "flatten-import.log")})
        for change in (dict(engine_executable=str(engine.with_name("wrong.exe"))),
                       dict(engine_executable_sha256="e" * 64)):
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, "measured another engine"):
                execution.process_binding([dict(row, **change)], output, project, engine, flatten=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
