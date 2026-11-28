#!/usr/bin/env python3
"""Adversarial tests for offline source custody and dependency receipt replay."""
from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

import ramcache_strata_lab_package as package


class SourcePackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ramcache-strata-portability-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.donor = self.root / "donor"
        self.donor.mkdir()
        self.git("init")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.write(".gitattributes", b"* text=auto\n*.ps1 text eol=crlf\n*.dll -text\n")
        self.write("Launch.ps1", b"Write-Output 'portable'\n")
        self.write("godot/project.godot", b"config_version=5\n")
        self.write("godot/scripts/main.gd", b"extends Node\n")
        self.write("godot/scripts/authored.gd.uid", b"uid://authored\n")
        self.write("godot/addons/cybersand_native/runtime-provenance.windows.json", b'{"retained":true}\n')
        self.runtime_name = sorted(package.WINDOWS_LFS)[0]
        self.runtime_bytes = b"fixture Windows binary bytes\0"
        self.runtime_identity = {"sha256": hashlib.sha256(self.runtime_bytes).hexdigest(), "size": len(self.runtime_bytes)}
        self.write(self.runtime_name, ("version https://git-lfs.github.com/spec/v1\noid sha256:"
                   + self.runtime_identity["sha256"] + "\nsize " + str(self.runtime_identity["size"]) + "\n").encode())
        self.import_name = next(iter(package.REGENERATED_RAPIER_IMPORTS))
        fixture_source = Path(package.__file__).resolve().parents[2] / self.import_name
        self.write(self.import_name, fixture_source.read_bytes())
        self.write(self.import_name.removesuffix(".import"), b"fixture source image")
        self.git("add", ".")
        self.git("commit", "-qm", "accepted source")
        self.source = self.git("rev-parse", "HEAD").decode().strip()
        self.tree = self.git("rev-parse", "HEAD^{tree}").decode().strip()
        self.destination = self.root / "portable/source"
        self.record = package.stage_source(self.donor, self.source, self.destination)

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.donor), *args],
                                       env=package.lab.clean_git_environment(), stderr=subprocess.PIPE)

    def write(self, name, data):
        target = self.donor / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    def verify(self, **kwargs):
        return package.verify_source(self.destination, self.record, expected_source=self.source,
                                     expected_tree=self.tree, materialized_lfs=kwargs.pop("materialized_lfs", {}), **kwargs)

    def test_canonical_source_and_generated_imports(self):
        self.assertEqual((self.destination / "Launch.ps1").read_bytes(), b"Write-Output 'portable'\n")
        self.assertEqual(self.verify()["tracked_files"], len(self.record["original_files"]))
        generated = self.destination / "godot/scripts/main.gd.uid"
        generated.write_text("uid://generated\n")
        self.verify()
        # The generated exemption never covers an authored tracked UID.
        (self.destination / "godot/scripts/authored.gd.uid").write_text("uid://changed\n")
        with self.assertRaisesRegex(RuntimeError, "Committed portable source changed"):
            self.verify()

    def test_lfs_materialization_is_exact_and_does_not_exempt_manifests(self):
        target = self.destination / self.runtime_name
        target.write_bytes(self.runtime_bytes)
        admitted = {self.runtime_name: self.runtime_identity}
        self.assertEqual(self.verify(materialized_lfs=admitted)["materialized_lfs"], 1)
        target.write_bytes(self.runtime_bytes + b"changed")
        with self.assertRaisesRegex(RuntimeError, "Materialized runtime differs"):
            self.verify(materialized_lfs=admitted)
        target.write_bytes(self.runtime_bytes)
        (self.destination / "godot/addons/cybersand_native/runtime-provenance.windows.json").write_text("{}")
        with self.assertRaisesRegex(RuntimeError, "Committed portable source changed"):
            self.verify(materialized_lfs=admitted)
        with self.assertRaisesRegex(RuntimeError, "Unreviewed source materialization"):
            self.verify(materialized_lfs={"godot/project.godot": self.runtime_identity})

    def test_only_reviewed_import_sidecars_may_regenerate(self):
        omitted = {self.import_name: package.REGENERATED_RAPIER_IMPORTS[self.import_name]}
        target = self.destination / self.import_name
        target.unlink()
        self.assertEqual(self.verify(omitted_files=omitted)["regenerated_imports"], 1)
        target.write_text("regenerated by pinned engine\n")
        self.verify(omitted_files=omitted)
        with self.assertRaisesRegex(RuntimeError, "Unreviewed committed-source omission"):
            self.verify(omitted_files={"godot/scripts/main.gd": "0" * 64})

    def test_history_has_no_external_configuration_or_unreachable_objects(self):
        package.git(self.destination, "remote", "add", "private", "https://example.invalid/private")
        with self.assertRaisesRegex(RuntimeError, "retained a remote"):
            self.verify()
        package.git(self.destination, "remote", "remove", "private")
        object_file = self.root / "excluded-object"
        object_file.write_bytes(b"excluded branch must not appear in delivered source")
        package.git(self.destination, "hash-object", "-w", str(object_file))
        with self.assertRaisesRegex(RuntimeError, "unreachable objects"):
            self.verify()


class CompilerCopyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ramcache-strata-compiler-copy-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.donor = self.root / "runner-compiler"
        self.destination = self.root / "portable-compiler"
        self.modules = {
            "opt/lib/python3.12/_weakrefset.py": b"class WeakSet: pass\n",
            "share/gdb/python/gdb/__init__.py": b"# retained GDB module\n",
        }
        self.caches = {
            "opt/lib/python3.12/__pycache__/_weakrefset.cpython-312.pyc": b"runner bytecode",
            "opt/lib/python3.12/__pycache__/_weakrefset.cpython-312.opt-1.pyc": b"optimized runner bytecode",
            "share/gdb/python/gdb/__pycache__/__init__.cpython-312.pyc": b"runner GDB bytecode",
        }
        self.retained = {
            **self.modules,
            "bin/g++.exe": b"retained compiler executable\0",
            "bin/libstdc++-6.dll": b"retained compiler dependency\0",
            "licenses/COPYING": b"retained compiler license\n",
            "share/gdb/python/LICENSE.txt": b"retained module license\n",
            "opt/lib/python3.12/module.pyc": b"unrelated sourceless module must not be dropped",
            "share/unrelated.cache": b"unrelated cache name",
            "share/__pycache__-notes.txt": b"similar name is not an omission",
            "userdata/prior-profile.json": b"must remain for archive refusal",
            ".godot/prior-import.bin": b"must remain for archive refusal",
        }
        for name, data in {**self.retained, **self.caches}.items():
            self.write(name, data)

    def write(self, name, data):
        path = self.donor / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def files(self, root):
        return {path.relative_to(root).as_posix(): path.read_bytes()
                for path in root.rglob("*") if path.is_file()}

    def copy(self):
        package.lab.copy_portable_tree(self.donor, self.destination,
                                      ignore=package._ignore_compiler_python_cache)

    def test_real_copy_omits_only_reproducible_caches_and_preserves_donor(self):
        before = self.files(self.donor)
        self.copy()
        self.assertEqual(self.files(self.destination), self.retained)
        self.assertEqual(self.files(self.donor), before)
        self.assertFalse(any(path.name == "__pycache__" for path in self.destination.rglob("*")))

    def test_cache_contents_cannot_hide_unexpected_files_or_nested_directories(self):
        for name in ("LICENSE.txt", "module.py", "module.cpython-312.pyc.exe", "nested/other.pyc"):
            with self.subTest(name=name):
                target = self.donor / "opt/lib/python3.12/__pycache__" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b"must refuse, never silently remove")
                with self.assertRaisesRegex(RuntimeError, "Unexpected compiler Python cache entry"):
                    self.copy()
                self.assertEqual(target.read_bytes(), b"must refuse, never silently remove")
                target.unlink()
                if name.startswith("nested/"):
                    target.parent.rmdir()
                # shutil.copytree can create the root before a later subtree
                # refuses. Each attempt gets its own untouched destination.
                self.destination = self.root / ("next-copy-" + name.replace("/", "-"))

    def test_malformed_or_sourceless_cache_is_refused(self):
        for name, message in (("module.pyc", "Unrecognized compiler Python cache"),
                              ("absent.cpython-312.pyc", "lacks its retained module")):
            with self.subTest(name=name):
                target = self.donor / "opt/lib/python3.12/__pycache__" / name
                target.write_bytes(b"unrecognized or irreplaceable bytecode")
                with self.assertRaisesRegex(RuntimeError, message):
                    self.copy()
                self.assertTrue(target.is_file())
                target.unlink()
                self.destination = self.root / ("next-copy-" + name)

    def test_cache_name_must_be_a_real_directory(self):
        self.write("share/__pycache__", b"file with reserved cache name")
        with self.assertRaisesRegex(RuntimeError, "not a real directory"):
            self.copy()

    def test_symlink_refusal_precedes_cache_omission(self):
        target = self.donor / "opt/lib/python3.12/__pycache__/_weakrefset.cpython-312.pyc"
        target.unlink()
        try:
            target.symlink_to(self.donor / "opt/lib/python3.12/_weakrefset.py")
        except (OSError, NotImplementedError) as error:
            self.skipTest("Host cannot create the actual symlink control: " + str(error))
        with self.assertRaisesRegex(RuntimeError, "contains a symlink"):
            self.copy()
        self.assertFalse(self.destination.exists())
        self.assertTrue(target.is_symlink())


class DependencyReceiptTests(unittest.TestCase):
    def test_dependency_bytes_and_notices_are_replayed_without_execution(self):
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-dependencies-") as directory:
            destination = Path(directory) / "dependencies"
            files = [*package.TOOL_PATHS.values(), "python/LICENSE.txt", "git/LICENSE.txt",
                     "git/ucrt64/bin/git.exe", "git/ucrt64/share/licenses/runtime/LICENSE", "cxx/licenses/COPYING"]
            for name in files:
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(("fixture " + name).encode())
            for name in ("python/Lib/json", "python/DLLs"):
                (destination / name).mkdir(parents=True)
            record = package.dependency_identity(destination, execute=False)
            package.verify_dependencies(destination, record, execute=False)
            (destination / "python/python.exe").write_bytes(b"changed interpreter")
            with self.assertRaisesRegex(RuntimeError, "dependency identity changed"):
                package.verify_dependencies(destination, record, execute=False)
            (destination / "cxx/licenses/COPYING").unlink()
            with self.assertRaisesRegex(RuntimeError, "license notices"):
                package.dependency_identity(destination, execute=False)


if __name__ == "__main__":
    unittest.main()
