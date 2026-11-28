#!/usr/bin/env python3
"""Adversarial tests for offline source custody and dependency receipt replay."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock
import zipfile

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

    def test_files_only_archive_preserves_exact_portable_history(self):
        anchor = self.destination / ".git" / package.PORTABLE_SOURCE_REF
        self.assertEqual(anchor.read_bytes(), (self.source + "\n").encode())
        self.assertEqual((self.destination / ".git/HEAD").read_bytes(), (self.source + "\n").encode())
        self.assertFalse((self.destination / ".git/logs" / package.PORTABLE_SOURCE_REF).exists())
        self.assertEqual(package.git(self.destination, "for-each-ref", "--format=%(refname) %(objectname)").strip(),
                         (package.PORTABLE_SOURCE_REF + " " + self.source).encode())
        before = {path.relative_to(self.destination).as_posix(): path.read_bytes()
                  for path in self.destination.rglob("*") if path.is_file()}
        archive = self.root / "actual-files-only.zip"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
            for path in sorted(self.destination.rglob("*")):
                if path.is_file():
                    bundle.write(path, "source/" + path.relative_to(self.destination).as_posix())
        extracted = self.root / "fresh extracted package"
        with zipfile.ZipFile(archive) as bundle:
            self.assertIsNone(bundle.testzip())
            self.assertTrue(all(not item.is_dir() for item in bundle.infolist()))
            self.assertIn("source/.git/" + package.PORTABLE_SOURCE_REF, bundle.namelist())
            bundle.extractall(extracted)
        self.destination = extracted / "source"
        self.assertEqual({path.relative_to(self.destination).as_posix(): path.read_bytes()
                          for path in self.destination.rglob("*") if path.is_file()}, before)
        verified = self.verify()
        self.assertEqual(verified["source_commit"], self.source)
        self.assertEqual(verified["source_tree"], self.tree)
        self.assertEqual(verified["remote_count"], 0)

    def test_anchor_is_the_only_git_metadata_change_and_adds_no_excluded_history(self):
        self.git("checkout", "-qb", "excluded-objectshard")
        self.write("excluded.txt", b"unaccepted branch content\n")
        self.git("add", "excluded.txt")
        self.git("commit", "-qm", "excluded branch")
        excluded = self.git("rev-parse", "HEAD").decode().strip()
        self.git("checkout", "--detach", self.source)
        self.git("remote", "add", "private", "https://example.invalid/private")
        unrelated = self.root / "unreachable-object"
        unrelated.write_bytes(b"unreachable donor object")
        unreachable = self.git("hash-object", "-w", str(unrelated)).decode().strip()
        original_clean = package.lab.clean_source_repository
        original_metadata = {}

        def capture_clean_repository(*args):
            history = original_clean(*args)
            dotgit = args[2] / ".git"
            original_metadata.update({path.relative_to(dotgit).as_posix(): path.read_bytes()
                                      for path in dotgit.rglob("*") if path.is_file()})
            return history

        self.destination = self.root / "bounded-metadata/source"
        with mock.patch.object(package.lab, "clean_source_repository", side_effect=capture_clean_repository):
            self.record = package.stage_source(self.donor, self.source, self.destination)
        dotgit = self.destination / ".git"
        self.assertEqual({path.relative_to(dotgit).as_posix(): path.read_bytes()
                          for path in dotgit.rglob("*") if path.is_file()},
                         {**original_metadata, package.PORTABLE_SOURCE_REF: (self.source + "\n").encode()})
        self.verify()
        for oid in (excluded, unreachable):
            with self.subTest(excluded_oid=oid):
                with self.assertRaisesRegex(RuntimeError, "Git command failed"):
                    package.git(self.destination, "cat-file", "-e", oid)

    def test_portable_reference_must_be_present_and_exact(self):
        anchor = self.destination / ".git" / package.PORTABLE_SOURCE_REF
        anchor.unlink()
        with self.assertRaisesRegex(RuntimeError, "needs its exact loose reference"):
            self.verify()
        for contents in (b"", b"malformed\n", ("0" * 40 + "\n").encode(),
                         (self.source + "\r\n").encode(), (self.source + "\nextra\n").encode()):
            with self.subTest(contents=contents):
                anchor.write_bytes(contents)
                with self.assertRaisesRegex(RuntimeError, "loose reference differs"):
                    self.verify()

    def test_portable_reference_cannot_move_to_an_otherwise_valid_ancestor(self):
        accepted_ancestor = self.source
        self.git("commit", "--allow-empty", "-qm", "accepted successor")
        self.source = self.git("rev-parse", "HEAD").decode().strip()
        self.tree = self.git("rev-parse", "HEAD^{tree}").decode().strip()
        self.destination = self.root / "successor/source"
        self.record = package.stage_source(self.donor, self.source, self.destination)
        self.verify()
        package.git(self.destination, "merge-base", "--is-ancestor", accepted_ancestor, "HEAD")
        package.git(self.destination, "-c", "core.logAllRefUpdates=false", "update-ref",
                    package.PORTABLE_SOURCE_REF, accepted_ancestor)
        with self.assertRaisesRegex(RuntimeError, "loose reference differs"):
            self.verify()

    def test_portable_head_must_stay_detached(self):
        (self.destination / ".git/HEAD").write_text("ref: " + package.PORTABLE_SOURCE_REF + "\n")
        self.assertEqual(package.git(self.destination, "rev-parse", "HEAD").decode().strip(), self.source)
        with self.assertRaisesRegex(RuntimeError, "HEAD must remain detached"):
            self.verify()

    def test_portable_reference_cannot_be_a_symbolic_link(self):
        anchor = self.destination / ".git" / package.PORTABLE_SOURCE_REF
        external = self.root / "external-reference"
        external.write_bytes(anchor.read_bytes())
        anchor.unlink()
        try:
            anchor.symlink_to(external)
        except (OSError, NotImplementedError) as error:
            self.skipTest("Host cannot create the actual symlink control: " + str(error))
        with self.assertRaisesRegex(RuntimeError, "contains a symbolic link"):
            self.verify()

    def test_failed_git_queries_retain_bounded_original_stderr(self):
        with self.assertRaisesRegex(RuntimeError, "Portable source Git command failed.*rev-parse.*fatal:"):
            package.git(self.destination, "rev-parse", "--verify", "refs/heads/missing-reference")
        failure = subprocess.CalledProcessError(128, ["git", "remote"], stderr=b"original failure\n" + b"x" * 5000)
        with mock.patch.object(package.subprocess, "check_output", side_effect=failure):
            with self.assertRaises(RuntimeError) as caught:
                package.git(self.destination, "remote")
        message = str(caught.exception)
        self.assertIn("exit 128, remote", message)
        self.assertIn("original failure", message)
        self.assertTrue(message.endswith(" [stderr truncated]"))
        self.assertLess(len(message), 4300)

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
    def _make_dependencies(self, directory: Path, *, compiler_receipt: bytes | None = None,
                           lld_receipt: bytes | None = None) -> Path:
        destination = directory / "dependencies"
        files = [*package.TOOL_PATHS.values(), "python/LICENSE.txt", "git/LICENSE.txt",
                 "git/ucrt64/bin/git.exe", "git/ucrt64/share/licenses/runtime/LICENSE", "cxx/licenses/COPYING"]
        for name in files:
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(("fixture " + name).encode())
        for name in ("python/Lib/json", "python/DLLs"):
            (destination / name).mkdir(parents=True)
        if compiler_receipt is not None:
            receipt = destination / "cxx" / package.portable_compiler_utf8.RECEIPT_NAME
            receipt.write_bytes(compiler_receipt)
        if lld_receipt is not None:
            receipt = destination / "cxx" / package.portable_lld.RECEIPT_NAME
            receipt.write_bytes(lld_receipt)
        return destination

    def _static_compiler_proof(self, compiler_root: Path, *, execute: bool) -> dict:
        # Keep this test at the package identity boundary. The Windows PE
        # verifier owns binary/resource validation; here we model its static
        # readback while binding the result to the actual staged receipt bytes.
        self.assertFalse(execute)
        receipt = compiler_root / package.portable_compiler_utf8.RECEIPT_NAME
        return {
            "schema": package.portable_compiler_utf8.SCHEMA,
            "status": "verified",
            "binaries": {
                "bin/g++.exe": {"sha256": package.sha(compiler_root / "bin/g++.exe")},
            },
            "receipt_sha256": package.sha(receipt),
        }

    def _static_lld_proof(self, compiler_root: Path, *, execute: bool) -> dict:
        # Keep package replay tests independent of the large pinned PE closure.
        # portable_lld.verify owns file/license/hash validation; this boundary
        # fixture returns its stable proof shape while binding it to exact marker
        # bytes so mutation and cross-package replay remain observable here.
        self.assertFalse(execute)
        receipt = compiler_root / package.portable_lld.RECEIPT_NAME
        marker = json.loads(receipt.read_bytes())
        return {
            "schema": package.portable_lld.SCHEMA,
            "status": "verified",
            "source": marker.get("source", {}),
            "files": marker.get("files", {}),
            "gnu_compiler_binding": marker.get("gnu_compiler_binding", {}),
            "receipt_sha256": package.sha(receipt),
        }

    def test_dependency_bytes_and_notices_are_replayed_without_execution(self):
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-dependencies-") as directory:
            destination = self._make_dependencies(Path(directory))
            with mock.patch.object(package.portable_compiler_utf8, "verify") as compiler_verify, \
                    mock.patch.object(package.portable_lld, "verify") as lld_verify:
                record = package.dependency_identity(destination, execute=False)
                package.verify_dependencies(destination, record, execute=False)
                compiler_verify.assert_not_called()
                lld_verify.assert_not_called()
            self.assertNotIn("compiler_utf8", record)
            self.assertNotIn("portable_lld", record)
            (destination / "python/python.exe").write_bytes(b"changed interpreter")
            with self.assertRaisesRegex(RuntimeError, "dependency identity changed"):
                package.verify_dependencies(destination, record, execute=False)
            (destination / "cxx/licenses/COPYING").unlink()
            with self.assertRaisesRegex(RuntimeError, "license notices"):
                package.dependency_identity(destination, execute=False)

    def test_nested_compiler_receipt_is_replayed_in_static_identity(self):
        receipt_bytes = b'{"schema":"cybersand.portable-compiler-utf8-v1","status":"prepared-candidate"}\n'
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-compiler-proof-") as directory:
            destination = self._make_dependencies(Path(directory), compiler_receipt=receipt_bytes)
            with mock.patch.object(package.portable_compiler_utf8, "verify", side_effect=self._static_compiler_proof) as verifier:
                record = package.dependency_identity(destination, execute=False)
                replayed = package.verify_dependencies(destination, record, execute=False)
            self.assertEqual(verifier.call_count, 2)
            self.assertEqual(record["compiler_utf8"]["status"], "verified")
            self.assertEqual(record["compiler_utf8"]["receipt_sha256"],
                             hashlib.sha256(receipt_bytes).hexdigest())
            self.assertEqual(replayed, record)

    def test_modified_nested_compiler_receipt_refuses_replay(self):
        original = b'{"proof":"prepared compiler A"}\n'
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-mutated-compiler-proof-") as directory:
            destination = self._make_dependencies(Path(directory), compiler_receipt=original)
            receipt = destination / "cxx" / package.portable_compiler_utf8.RECEIPT_NAME
            with mock.patch.object(package.portable_compiler_utf8, "verify", side_effect=self._static_compiler_proof):
                record = package.dependency_identity(destination, execute=False)
                receipt.write_bytes(b'{"proof":"mutated compiler receipt"}\n')
                with self.assertRaisesRegex(RuntimeError, "dependency identity changed"):
                    package.verify_dependencies(destination, record, execute=False)

    def test_foreign_nested_compiler_proof_refuses_replay(self):
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-foreign-compiler-proof-") as directory:
            root = Path(directory)
            local = self._make_dependencies(root / "local", compiler_receipt=b'{"proof":"local"}\n')
            foreign = self._make_dependencies(root / "foreign", compiler_receipt=b'{"proof":"foreign"}\n')
            with mock.patch.object(package.portable_compiler_utf8, "verify", side_effect=self._static_compiler_proof):
                local_record = package.dependency_identity(local, execute=False)
                foreign_record = package.dependency_identity(foreign, execute=False)
                self.assertNotEqual(local_record["compiler_utf8"], foreign_record["compiler_utf8"])
                self.assertEqual({key: value for key, value in local_record.items() if key != "compiler_utf8"},
                                 {key: value for key, value in foreign_record.items() if key != "compiler_utf8"})
                with self.assertRaisesRegex(RuntimeError, "dependency identity changed"):
                    package.verify_dependencies(local, foreign_record, execute=False)

    def test_nested_lld_receipt_is_replayed_in_static_identity(self):
        compiler_receipt = b'{"schema":"cybersand.portable-compiler-utf8-v1","status":"prepared-candidate"}\n'
        lld_receipt = (
            b'{"schema":"cybersand.portable-linker-v1","status":"staged",'
            b'"source":{"lld_version":"LLD 23.1.0"},"files":{"bin/ld.lld.exe":{"sha256":"pinned"}}}\n'
        )
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-lld-proof-") as directory:
            destination = self._make_dependencies(
                Path(directory), compiler_receipt=compiler_receipt, lld_receipt=lld_receipt)
            with mock.patch.object(package.portable_compiler_utf8, "verify",
                                   side_effect=self._static_compiler_proof) as compiler_verify, \
                    mock.patch.object(package.portable_lld, "verify",
                                      side_effect=self._static_lld_proof) as lld_verify:
                record = package.dependency_identity(destination, execute=False)
                replayed = package.verify_dependencies(destination, record, execute=False)
            self.assertEqual(compiler_verify.call_count, 2)
            self.assertEqual(lld_verify.call_count, 2)
            self.assertEqual(record["portable_lld"]["schema"], package.portable_lld.SCHEMA)
            self.assertEqual(record["portable_lld"]["status"], "verified")
            self.assertEqual(record["portable_lld"]["receipt_sha256"],
                             hashlib.sha256(lld_receipt).hexdigest())
            self.assertEqual(replayed, record)

    def test_modified_nested_lld_receipt_refuses_replay(self):
        compiler_receipt = b'{"proof":"same admitted compiler"}\n'
        original = b'{"proof":"staged pinned LLD A"}\n'
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-mutated-lld-proof-") as directory:
            destination = self._make_dependencies(
                Path(directory), compiler_receipt=compiler_receipt, lld_receipt=original)
            receipt = destination / "cxx" / package.portable_lld.RECEIPT_NAME
            with mock.patch.object(package.portable_compiler_utf8, "verify",
                                   side_effect=self._static_compiler_proof), \
                    mock.patch.object(package.portable_lld, "verify",
                                      side_effect=self._static_lld_proof):
                record = package.dependency_identity(destination, execute=False)
                receipt.write_bytes(b'{"proof":"mutated LLD receipt"}\n')
                with self.assertRaisesRegex(RuntimeError, "dependency identity changed"):
                    package.verify_dependencies(destination, record, execute=False)

    def test_foreign_nested_lld_proof_refuses_replay(self):
        compiler_receipt = b'{"proof":"same admitted compiler"}\n'
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-foreign-lld-proof-") as directory:
            root = Path(directory)
            local = self._make_dependencies(
                root / "local", compiler_receipt=compiler_receipt,
                lld_receipt=b'{"proof":"local staged LLD"}\n')
            foreign = self._make_dependencies(
                root / "foreign", compiler_receipt=compiler_receipt,
                lld_receipt=b'{"proof":"foreign staged LLD"}\n')
            with mock.patch.object(package.portable_compiler_utf8, "verify",
                                   side_effect=self._static_compiler_proof), \
                    mock.patch.object(package.portable_lld, "verify",
                                      side_effect=self._static_lld_proof):
                local_record = package.dependency_identity(local, execute=False)
                foreign_record = package.dependency_identity(foreign, execute=False)
                self.assertNotEqual(local_record["portable_lld"], foreign_record["portable_lld"])
                self.assertEqual({key: value for key, value in local_record.items() if key != "portable_lld"},
                                 {key: value for key, value in foreign_record.items() if key != "portable_lld"})
                with self.assertRaisesRegex(RuntimeError, "dependency identity changed"):
                    package.verify_dependencies(local, foreign_record, execute=False)


if __name__ == "__main__":
    unittest.main()
