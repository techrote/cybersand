from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

import portable_lld
import portable_compiler_utf8


class PortableLLDTests(unittest.TestCase):
    def setUp(self):
        self.payloads = {
            "fixture/bin/ld.lld.exe": b"fixture lld executable bytes",
            "fixture/bin/libLLVM-23.dll": b"fixture llvm runtime bytes",
            "fixture/bin/libc++.dll": b"fixture libc++ runtime bytes",
            "fixture/bin/libunwind.dll": b"fixture unwind runtime bytes",
            "fixture/LICENSE.TXT": b"fixture LLVM-MinGW license\n",
            "fixture/target/share/mingw32/COPYING": b"fixture runtime license\n",
        }
        self.binaries = {
            name: {"member": member, "bytes": len(self.payloads[member]),
                   "sha256": hashlib.sha256(self.payloads[member]).hexdigest()}
            for name, member in {
                "ld.lld.exe": "fixture/bin/ld.lld.exe",
                "libLLVM-23.dll": "fixture/bin/libLLVM-23.dll",
                "libc++.dll": "fixture/bin/libc++.dll",
                "libunwind.dll": "fixture/bin/libunwind.dll",
            }.items()
        }
        self.licenses = {
            "licenses/llvm-mingw/LICENSE.TXT": {
                "member": "fixture/LICENSE.TXT", "bytes": len(self.payloads["fixture/LICENSE.TXT"]),
                "sha256": hashlib.sha256(self.payloads["fixture/LICENSE.TXT"]).hexdigest()},
            "licenses/llvm-mingw/target/share/mingw32/COPYING": {
                "member": "fixture/target/share/mingw32/COPYING",
                "bytes": len(self.payloads["fixture/target/share/mingw32/COPYING"]),
                "sha256": hashlib.sha256(self.payloads["fixture/target/share/mingw32/COPYING"]).hexdigest()},
        }
        self.temporary = tempfile.TemporaryDirectory(prefix="portable-lld-")
        self.root = Path(self.temporary.name) / "compiler"
        self.root.mkdir()
        self.archive = Path(self.temporary.name) / "llvm-mingw.zip"
        self._write_archive()
        self.compiler_proof = {
            "schema": portable_compiler_utf8.SCHEMA,
            "status": "verified",
            "receipt_sha256": "1" * 64,
            "binaries": {"bin/g++.exe": {"sha256": "2" * 64}},
        }

    def tearDown(self):
        self.temporary.cleanup()

    def _write_archive(self, *, duplicate: str | None = None):
        with zipfile.ZipFile(self.archive, "w", compression=zipfile.ZIP_STORED) as bundle:
            for member, content in self.payloads.items():
                bundle.writestr(member, content)
                if member == duplicate:
                    bundle.writestr(member, content)

    def _pinned(self):
        pins = mock.patch.multiple(
            portable_lld,
            ARCHIVE_NAME="fixture.zip",
            ARCHIVE_BYTES=self.archive.stat().st_size,
            ARCHIVE_SHA256=hashlib.sha256(self.archive.read_bytes()).hexdigest(),
            ARCHIVE_URL="https://example.invalid/fixture.zip",
            ARCHIVE_PREFIX="fixture/",
            RELEASE_TAG="fixture",
            LLD_VERSION="LLD 23.1.0",
            LLD_GIT_COMMIT="f" * 40,
            BIN_ALIASES=("bin", "x86_64-w64-mingw32/bin"),
            BINARY_MEMBERS=self.binaries,
            LICENSE_MEMBERS=self.licenses,
        )
        return pins

    def _compiler(self):
        return mock.patch.object(portable_lld.portable_compiler_utf8, "verify",
                                 return_value=self.compiler_proof)

    def _stage(self):
        with self._pinned(), self._compiler():
            return portable_lld.stage(self.root, self.archive)

    def test_stages_exact_closure_into_both_linker_directories_and_is_location_independent(self):
        first = self._stage()
        with self._pinned(), self._compiler():
            replayed = portable_lld.verify(self.root, execute=False)
            idempotent_stage = portable_lld.stage(self.root, self.archive)
        self.assertEqual(first, replayed)
        self.assertEqual(first, idempotent_stage)
        for alias in portable_lld.BIN_ALIASES:
            for name, record in self.binaries.items():
                target = self.root / alias / name
                self.assertEqual(target.stat().st_size, record["bytes"])
                self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(), record["sha256"])
        self.assertEqual(first["schema"], "cybersand.portable-linker-v1")
        self.assertNotIn(str(self.root), json.dumps(first))
        self.assertEqual(first["source"]["lld_git_commit"], "f" * 40)
        self.assertEqual(first["gnu_compiler_binding"]["driver_prepared_sha256"], "2" * 64)

    def test_refuses_archive_hash_mismatch_before_writing_anything(self):
        with self._pinned(), self._compiler():
            self.archive.write_bytes(b"not the pinned archive")
            with self.assertRaisesRegex(portable_lld.PortableLLDError, "size or SHA-256"):
                portable_lld.stage(self.root, self.archive)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_refuses_duplicate_or_missing_pinned_zip_members(self):
        self._write_archive(duplicate="fixture/bin/ld.lld.exe")
        with self._pinned(), self._compiler():
            with self.assertRaisesRegex(portable_lld.PortableLLDError, "duplicate"):
                portable_lld.stage(self.root, self.archive)
        self._write_archive()
        original = self.payloads.pop("fixture/bin/libunwind.dll")
        self._write_archive()
        with self._pinned(), self._compiler():
            with self.assertRaisesRegex(portable_lld.PortableLLDError, "missing or duplicate"):
                portable_lld.stage(self.root, self.archive)
        self.payloads["fixture/bin/libunwind.dll"] = original

    def test_refuses_existing_conflicting_destination_without_overwriting(self):
        target = self.root / "bin/ld.lld.exe"
        target.parent.mkdir()
        target.write_bytes(b"foreign linker")
        with self._pinned(), self._compiler():
            with self.assertRaisesRegex(portable_lld.PortableLLDError, "Refuse to overwrite"):
                portable_lld.stage(self.root, self.archive)
        self.assertEqual(target.read_bytes(), b"foreign linker")
        self.assertFalse((self.root / portable_lld.RECEIPT_NAME).exists())

    def test_refuses_changed_alias_runtime_license_and_marker(self):
        self._stage()
        checks = [
            (self.root / "x86_64-w64-mingw32/bin/ld.lld.exe", b"changed linker"),
            (self.root / "bin/libLLVM-23.dll", b"changed runtime"),
            (self.root / "licenses/llvm-mingw/LICENSE.TXT", b"changed notice"),
        ]
        for path, changed in checks:
            original = path.read_bytes()
            path.write_bytes(changed)
            with self._pinned(), self._compiler():
                with self.assertRaises(portable_lld.PortableLLDError):
                    portable_lld.verify(self.root, execute=False)
            path.write_bytes(original)
        receipt = self.root / portable_lld.RECEIPT_NAME
        original = receipt.read_bytes()
        receipt.write_bytes(b'{"schema":"foreign"}\n')
        with self._pinned(), self._compiler():
            with self.assertRaisesRegex(portable_lld.PortableLLDError, "malformed"):
                portable_lld.verify(self.root, execute=False)
        receipt.write_bytes(original)

    def test_refuses_marker_bound_to_a_different_gnu_driver_receipt(self):
        self._stage()
        foreign = {**self.compiler_proof, "receipt_sha256": "3" * 64}
        with self._pinned(), mock.patch.object(portable_lld.portable_compiler_utf8, "verify",
                                               return_value=foreign):
            with self.assertRaisesRegex(portable_lld.PortableLLDError, "malformed or belongs"):
                portable_lld.verify(self.root, execute=False)

    @unittest.skipUnless(os.name == "nt", "LLD process receipt is Windows-only")
    def test_execution_mode_validates_version_and_keeps_identity_shape(self):
        staged = self._stage()
        with self._pinned(), self._compiler(), mock.patch.object(
                portable_lld.subprocess, "run",
                return_value=subprocess_result(0, b"LLD 23.1.0 (fixture)\n")) as run:
            executed = portable_lld.verify(self.root, execute=True)
        self.assertEqual(staged, executed)
        self.assertEqual(Path(run.call_args.args[0][0]), self.root / "bin/ld.lld.exe")
        with self._pinned(), self._compiler(), mock.patch.object(
                portable_lld.subprocess, "run",
                return_value=subprocess_result(0, b"LLD 99.0.0\n")):
            with self.assertRaisesRegex(portable_lld.PortableLLDError, "version readback"):
                portable_lld.verify(self.root, execute=True)


def subprocess_result(returncode: int, stdout: bytes):
    class Result:
        pass
    result = Result()
    result.returncode = returncode
    result.stdout = stdout
    return result


if __name__ == "__main__":
    unittest.main()
