"""Stage and verify the pinned offline LLD closure used by portable Materials Lab.

The admitted GNU 14.2 compiler and its UTF-8 manifest receipt remain unchanged.
Only ``g++ -fuse-ld=lld`` selects this source-pinned linker.  This helper never
downloads files and never searches outside the supplied archive or staged C++
root; the workflow supplies the verified upstream release archive.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
import zipfile

_COMPILER_MODULE_PATH = Path(__file__).with_name("portable_compiler_utf8.py").resolve(strict=True)
_cached_compiler_module = sys.modules.get("portable_compiler_utf8")
if (getattr(_cached_compiler_module, "__file__", None)
        and Path(_cached_compiler_module.__file__).resolve() == _COMPILER_MODULE_PATH):
    portable_compiler_utf8 = _cached_compiler_module
else:
    _compiler_spec = importlib.util.spec_from_file_location(
        "_cybersand_portable_compiler_utf8_exact", _COMPILER_MODULE_PATH)
    if _compiler_spec is None or _compiler_spec.loader is None:
        raise ImportError("Unable to load the sibling portable_compiler_utf8.py source")
    portable_compiler_utf8 = importlib.util.module_from_spec(_compiler_spec)
    sys.modules[_compiler_spec.name] = portable_compiler_utf8
    _compiler_spec.loader.exec_module(portable_compiler_utf8)
    if Path(portable_compiler_utf8.__file__).resolve() != _COMPILER_MODULE_PATH:
        raise ImportError("Loaded portable compiler verifier does not match the sibling source")

SCHEMA = "cybersand.portable-linker-v1"
RECEIPT_NAME = "CYBERSAND-PORTABLE-LINKER.json"
ARCHIVE_NAME = "llvm-mingw-20260826-ucrt-x86_64.zip"
ARCHIVE_BYTES = 190721391
ARCHIVE_SHA256 = "ae601f4e0f72bbdf441ad2df8bb16f037e2e9251559ea6b37b4057aef39c06c3"
ARCHIVE_URL = (
    "https://github.com/mstorsjo/llvm-mingw/releases/download/20260826/"
    "llvm-mingw-20260826-ucrt-x86_64.zip"
)
ARCHIVE_PREFIX = "llvm-mingw-20260826-ucrt-x86_64/"
RELEASE_TAG = "20260826"
LLD_VERSION = "LLD 23.1.0"
LLD_GIT_COMMIT = "ea7d852a70e8bdfaf601d6626a760f9771b2c4b4"
BIN_ALIASES = ("bin", "x86_64-w64-mingw32/bin")

# All values are independently pinned to the admitted official release ZIP.
BINARY_MEMBERS = {
    "ld.lld.exe": {
        "member": ARCHIVE_PREFIX + "bin/ld.lld.exe",
        "bytes": 5184512,
        "sha256": "284daba5d41833c41d164d3b8b4715a41a11f0c8fd22c19eabc0929cbf081db8",
    },
    "libLLVM-23.dll": {
        "member": ARCHIVE_PREFIX + "bin/libLLVM-23.dll",
        "bytes": 77647360,
        "sha256": "54fc3fec74719abc7ee3f49a6cf95a446d5c8efbcf3613de422126a79256ad60",
    },
    "libc++.dll": {
        "member": ARCHIVE_PREFIX + "bin/libc++.dll",
        "bytes": 2009088,
        "sha256": "ead28c39ac69358c29e3cdfb309051c4d1848242b0e2dee81a3fa7bff00bdeb9",
    },
    "libunwind.dll": {
        "member": ARCHIVE_PREFIX + "bin/libunwind.dll",
        "bytes": 190976,
        "sha256": "f45604a12e8bcd839fd86f667c1be1cc7c4f9da2b3c69ff381ac708f0e1ae7d4",
    },
}
LICENSE_MEMBERS = {
    "licenses/llvm-mingw/LICENSE.TXT": {
        "member": ARCHIVE_PREFIX + "LICENSE.TXT",
        "bytes": 15141,
        "sha256": "8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee",
    },
    "licenses/llvm-mingw/x86_64-w64-mingw32/share/mingw32/COPYING": {
        "member": ARCHIVE_PREFIX + "x86_64-w64-mingw32/share/mingw32/COPYING",
        "bytes": 2326,
        "sha256": "99a69660981156c21336fdb5661f89341b013c94e4bf9e1c7467b4745718397f",
    },
    "licenses/llvm-mingw/x86_64-w64-mingw32/share/mingw32/COPYING.MinGW-w64.txt": {
        "member": ARCHIVE_PREFIX + "x86_64-w64-mingw32/share/mingw32/COPYING.MinGW-w64.txt",
        "bytes": 5905,
        "sha256": "f38e6194bd3bfa1b654f118e5acefe0aead437bbe669eee43957ccc65a7127f1",
    },
    "licenses/llvm-mingw/x86_64-w64-mingw32/share/mingw32/COPYING.MinGW-w64-runtime.txt": {
        "member": ARCHIVE_PREFIX + "x86_64-w64-mingw32/share/mingw32/COPYING.MinGW-w64-runtime.txt",
        "bytes": 12155,
        "sha256": "1db8da07b436c68833c0673ffee3d9fcb2526047f3820b81661865dfedc79a1f",
    },
    "licenses/llvm-mingw/x86_64-w64-mingw32/share/mingw32/COPYING.winpthreads.txt": {
        "member": ARCHIVE_PREFIX + "x86_64-w64-mingw32/share/mingw32/COPYING.winpthreads.txt",
        "bytes": 2883,
        "sha256": "63263614cdd29f2f93cba85e992f041b31f9fc7b4033692f31269489a8a1b177",
    },
    "licenses/llvm-mingw/x86_64-w64-mingw32/share/mingw32/COPYING.winstorecompat.txt": {
        "member": ARCHIVE_PREFIX + "x86_64-w64-mingw32/share/mingw32/COPYING.winstorecompat.txt",
        "bytes": 1099,
        "sha256": "fa7368d1f93d890c173177475d8ec7aff265a7d08f1f364d66f74d138978ce36",
    },
}


class PortableLLDError(RuntimeError):
    """The archive or staged LLD dependency closure differs from its pin."""


def _need(condition: bool, message: str) -> None:
    if not condition:
        raise PortableLLDError(message)


def _sha_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _canonical(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def _write_atomic(path: Path, data: bytes) -> None:
    temporary = path.with_name(path.name + ".tmp")
    _need(not temporary.exists() and not temporary.is_symlink(), "LLD receipt temporary path already exists")
    try:
        with temporary.open("xb") as stream:
            stream.write(data)
        os.replace(temporary, path)
    except BaseException:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass
        raise


def _expected_files() -> dict[str, dict]:
    files: dict[str, dict] = {}
    for alias in BIN_ALIASES:
        for name, record in BINARY_MEMBERS.items():
            relative = f"{alias}/{name}"
            files[relative] = {"archive_member": record["member"], "bytes": record["bytes"],
                               "sha256": record["sha256"]}
    for relative, record in LICENSE_MEMBERS.items():
        files[relative] = {"archive_member": record["member"], "bytes": record["bytes"],
                           "sha256": record["sha256"]}
    return files


def _gnu_binding(root: Path) -> dict:
    """Bind LLD selection to the verified admitted GNU driver and source receipt."""
    proof = portable_compiler_utf8.verify(root, execute=False)
    driver = proof.get("binaries", {}).get("bin/g++.exe", {})
    _need(proof.get("schema") == portable_compiler_utf8.SCHEMA
          and proof.get("status") == "verified"
          and proof.get("receipt_sha256")
          and driver.get("sha256"),
          "Pinned LLD requires a verified admitted GNU 14.2 UTF-8 receipt")
    return {
        "compiler_schema": portable_compiler_utf8.SCHEMA,
        "compiler_receipt_sha256": proof["receipt_sha256"],
        "driver_relative_path": "bin/g++.exe",
        "driver_original_sha256": portable_compiler_utf8.CORE_EXECUTABLE_SHA256["bin/g++.exe"],
        "driver_prepared_sha256": driver["sha256"],
        "source_commit": portable_compiler_utf8.REFERENCE_SOURCE["source_commit"],
        "source_tree": portable_compiler_utf8.REFERENCE_SOURCE["source_tree"],
    }


def _expected_receipt(gnu_binding: dict) -> dict:
    return {
        "schema": SCHEMA,
        "status": "staged",
        "source": {
            "project": "mstorsjo/llvm-mingw",
            "release_tag": RELEASE_TAG,
            "release_url": ARCHIVE_URL,
            "archive_name": ARCHIVE_NAME,
            "archive_bytes": ARCHIVE_BYTES,
            "archive_sha256": ARCHIVE_SHA256,
            "lld_version": LLD_VERSION,
            "lld_git_commit": LLD_GIT_COMMIT,
        },
        "gnu_compiler_binding": gnu_binding,
        "files": _expected_files(),
    }


def _validate_relative(relative: str) -> PurePosixPath:
    path = PurePosixPath(relative)
    _need(not path.is_absolute() and path.parts and all(part not in ("", ".", "..") for part in path.parts),
          "Pinned LLD file has an unsafe relative path")
    return path


def _safe_destination(root: Path, relative: str, *, create_parents: bool) -> Path:
    rel = _validate_relative(relative)
    target = root.joinpath(*rel.parts)
    cursor = root
    for component in rel.parts[:-1]:
        cursor = cursor / component
        if cursor.exists() or cursor.is_symlink():
            _need(cursor.is_dir() and not cursor.is_symlink(), "LLD target parent is not a real directory: " + relative)
        elif create_parents:
            cursor.mkdir()
        else:
            raise PortableLLDError("LLD target parent is missing: " + relative)
    if target.exists() or target.is_symlink():
        _need(target.is_file() and not target.is_symlink(), "LLD target is not a regular file: " + relative)
    return target


def _load_receipt(root: Path, receipt: dict | None) -> tuple[dict, Path]:
    receipt_path = root / RECEIPT_NAME
    _need(not receipt_path.is_symlink(), "LLD receipt must not be a symbolic link")
    if receipt is None:
        _need(receipt_path.is_file(), "Pinned LLD receipt is missing")
        try:
            receipt = json.loads(receipt_path.read_bytes())
        except (OSError, json.JSONDecodeError) as error:
            raise PortableLLDError("Pinned LLD receipt is unreadable") from error
    _need(type(receipt) is dict and receipt.get("gnu_compiler_binding") == _gnu_binding(root)
          and receipt == _expected_receipt(receipt["gnu_compiler_binding"]),
          "Pinned LLD receipt is malformed or belongs to another linker package")
    return receipt, receipt_path


def _static_verify(root: Path, receipt: dict | None = None) -> dict:
    receipt, receipt_path = _load_receipt(root, receipt)
    observed = {}
    for relative, expected in receipt["files"].items():
        path = _safe_destination(root, relative, create_parents=False)
        _need(path.is_file(), "Pinned LLD file is missing: " + relative)
        observed_hash = _sha_file(path)
        _need(path.stat().st_size == expected["bytes"] and observed_hash == expected["sha256"],
              "Pinned LLD file differs from archive receipt: " + relative)
        observed[relative] = {"bytes": expected["bytes"], "sha256": observed_hash}
    # Preserve one simple, stable record: every path, license, and selected
    # closure member is pinned, and the receipt digest binds the archive source.
    return {"schema": SCHEMA, "status": "verified", "source": receipt["source"],
            "gnu_compiler_binding": receipt["gnu_compiler_binding"],
            "files": observed,
            "receipt_sha256": _sha_file(receipt_path) if receipt_path.is_file() else _sha_bytes(_canonical(receipt))}


def _verify_execution(root: Path) -> None:
    _need(os.name == "nt", "LLD execution verification is Windows-only")
    linker = root / "bin/ld.lld.exe"
    system_root = Path(os.environ.get("SystemRoot", r"C:\Windows"))
    env = {key: os.environ[key] for key in ("SystemRoot", "TEMP", "TMP") if key in os.environ}
    env["PATH"] = os.pathsep.join((str(linker.parent), str(system_root / "System32"), str(system_root)))
    try:
        process = subprocess.run([str(linker), "--version"], cwd=linker.parent, env=env,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 timeout=30, check=False,
                                 creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except (OSError, subprocess.TimeoutExpired) as error:
        raise PortableLLDError("Bundled pinned LLD did not execute: " + str(error)) from error
    _need(process.returncode == 0, "Bundled pinned LLD returned a failure from --version")
    try:
        output = process.stdout.decode("utf-8", errors="strict").strip()
    except UnicodeDecodeError as error:
        raise PortableLLDError("Bundled pinned LLD version output is not UTF-8") from error
    _need(output.startswith(LLD_VERSION) and len(output) < 4096,
          "Bundled linker version readback does not match the pinned LLD 23.1.0")


def verify(compiler_root: str | os.PathLike[str], receipt: dict | None = None, *, execute: bool = False) -> dict:
    """Verify exact staged bytes and licenses; optional Windows execution is read-only.

    The returned identity has no absolute paths and is independent of the
    ``execute`` option, so build and extracted-package dependency receipts match.
    """
    root_arg = Path(compiler_root)
    _need(not root_arg.is_symlink(), "LLD compiler root must not be a symbolic link")
    try:
        root = root_arg.resolve(strict=True)
    except OSError as error:
        raise PortableLLDError("LLD compiler root is missing") from error
    _need(root.is_dir(), "LLD compiler root is not a directory")
    result = _static_verify(root, receipt)
    if execute:
        _verify_execution(root)
    return result


def _read_pinned_members(archive: Path) -> dict[str, bytes]:
    _need(not archive.is_symlink() and archive.is_file(), "Pinned LLVM-MinGW archive is missing or not a regular file")
    _need(archive.stat().st_size == ARCHIVE_BYTES and _sha_file(archive) == ARCHIVE_SHA256,
          "LLVM-MinGW archive size or SHA-256 differs from the registered release")
    expected = _expected_files()
    source_members = {record["archive_member"] for record in expected.values()}
    try:
        with zipfile.ZipFile(archive, "r") as bundle:
            rows = [item for item in bundle.infolist() if item.filename in source_members]
            names = [item.filename for item in rows]
            _need(set(names) == source_members and len(names) == len(source_members),
                  "LLVM-MinGW archive has missing or duplicate pinned members")
            infos = {item.filename: item for item in rows}
            contents: dict[str, bytes] = {}
            for member in sorted(source_members):
                info = infos[member]
                _need(not info.is_dir() and not (info.flag_bits & 0x1),
                      "Pinned LLVM-MinGW member is not a regular unencrypted file: " + member)
                mode = info.external_attr >> 16
                _need(not (mode and (mode & 0o170000) == 0o120000),
                      "Pinned LLVM-MinGW member is a symbolic link: " + member)
                content = bundle.read(info)
                expected_record = next(value for value in expected.values()
                                       if value["archive_member"] == member)
                _need(len(content) == expected_record["bytes"]
                      and _sha_bytes(content) == expected_record["sha256"],
                      "Pinned LLVM-MinGW member differs from its registered digest: " + member)
                contents[member] = content
            return contents
    except (OSError, zipfile.BadZipFile, RuntimeError) as error:
        if isinstance(error, PortableLLDError):
            raise
        raise PortableLLDError("Pinned LLVM-MinGW archive could not be read") from error


def stage(compiler_root: str | os.PathLike[str], archive: str | os.PathLike[str]) -> dict:
    """Stage only the authenticated LLD runtime closure and license notices.

    ``compiler_root`` must be an already-copied ``dependencies/cxx`` directory.
    Existing staged receipts are idempotently verified; conflicting existing
    paths are refused instead of overwritten.
    """
    root_arg = Path(compiler_root)
    _need(not root_arg.is_symlink(), "LLD compiler root must not be a symbolic link")
    try:
        root = root_arg.resolve(strict=True)
    except OSError as error:
        raise PortableLLDError("LLD compiler root is missing") from error
    _need(root.is_dir(), "LLD compiler root is not a directory")
    archive_path = Path(archive)
    contents = _read_pinned_members(archive_path)
    receipt = _expected_receipt(_gnu_binding(root))
    receipt_path = root / RECEIPT_NAME
    if receipt_path.exists() or receipt_path.is_symlink():
        return verify(root, execute=False)

    for relative, record in receipt["files"].items():
        target = _safe_destination(root, relative, create_parents=True)
        if target.exists():
            _need(_sha_file(target) == record["sha256"] and target.stat().st_size == record["bytes"],
                  "Refuse to overwrite an unrelated existing LLD dependency: " + relative)
            continue
        content = contents[record["archive_member"]]
        temporary = target.with_name(target.name + ".portable-lld.tmp")
        _need(not temporary.exists() and not temporary.is_symlink(),
              "LLD staging temporary path already exists: " + relative)
        try:
            with temporary.open("xb") as stream:
                stream.write(content)
            _need(_sha_file(temporary) == record["sha256"] and temporary.stat().st_size == record["bytes"],
                  "Staged LLD file failed readback: " + relative)
            os.replace(temporary, target)
        except BaseException:
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass
            raise

    _static_verify(root, receipt)
    _write_atomic(receipt_path, _canonical(receipt))
    return verify(root, execute=False)


__all__ = ["SCHEMA", "RECEIPT_NAME", "ARCHIVE_NAME", "ARCHIVE_BYTES", "ARCHIVE_SHA256",
           "ARCHIVE_URL", "LLD_VERSION", "BINARY_MEMBERS", "LICENSE_MEMBERS",
           "PortableLLDError", "stage", "verify"]
