#!/usr/bin/env bash
set -euo pipefail

# The native probe uses the ordinary 1 MiB Windows stack and the same pinned
# LLVM-MinGW/static-runtime contract as the repository GDExtension. A successful
# build is explicitly not execution evidence; the Windows job must run it.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 - "$project_root" <<'PY'
from pathlib import Path
import hashlib
import json
import os
import re
import shlex
import struct
import subprocess
import tempfile
import sys

root = Path(sys.argv[1])
compiler_text = os.environ.get("WINDOWS_CXX", "")
output_text = os.environ.get("CYBERSAND_AUDITION_WINDOWS_PROBE", "")
if not compiler_text or not output_text:
    raise SystemExit("Set WINDOWS_CXX and a fresh CYBERSAND_AUDITION_WINDOWS_PROBE .exe output path")
# Preserve the target-prefixed driver basename: LLVM-MinGW aliases select the
# target through argv[0], so resolving that symlink would select the host driver.
compiler = Path(os.path.abspath(compiler_text))
if not compiler.is_file() or not os.access(compiler, os.X_OK):
    raise SystemExit("WINDOWS_CXX must name an executable compiler path")
output = Path(output_text).resolve()
receipt_path = output.with_suffix(".build.json")
if output.suffix.lower() != ".exe" or output.exists() or receipt_path.exists():
    raise SystemExit("Choose a fresh .exe and adjacent .build.json output; existing evidence is immutable")
version = subprocess.check_output([str(compiler), "--version"], text=True, timeout=30).strip()
machine = subprocess.check_output([str(compiler), "-dumpmachine"], text=True, timeout=30).strip()
if not re.search(r"\b23\.1\.0\b", version) or "clang" not in version.lower():
    raise SystemExit("Windows qualification requires the pinned LLVM-MinGW Clang 23.1.0 compiler")
if not machine.startswith("x86_64-") or not ("mingw" in machine or "windows-gnu" in machine):
    raise SystemExit("Windows qualification requires the x86_64 Windows GNU compiler target")

sources = ["native/src/" + name for name in
           ("world.cpp", "material_rules.cpp", "scheduler_geometry.cpp", "settled_world_discovery.cpp")]
test = "native/tests/test_material_audition.cpp"
builder = "tools/ci/build_material_audition_windows_probe.sh"
command = [str(compiler), "-std=c++20", "-O2", "-g", "-pthread", "-static", "-Wl,--no-undefined",
           "-Wl,--stack,1048576", "-ffile-prefix-map=" + str(root) + "=.", "-I" + str(root / "native/include"),
           *(str(root / path) for path in sources), str(root / test), "-o", str(output)]
print("Pinned Windows native probe command: " + shlex.join(command), flush=True)
if os.environ.get("CYBERSAND_DRY_RUN") == "1":
    print("Dry run only: no binary, build receipt or execution claim produced")
    raise SystemExit(0)

def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def git(*args):
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull, GIT_OPTIONAL_LOCKS="0")
    return subprocess.check_output(["git", "--no-optional-locks", "-c", "diff.autoRefreshIndex=false",
                                    "-C", str(root), *args], timeout=120, env=environment)

def source_identity():
    directories = ("native/include", "native/src")
    git("diff", "--exit-code", "HEAD", "--", *directories, test, builder)
    tracked = set(git("ls-files", "-z", "--", *directories, test, builder).decode().split("\0"))
    suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
    native = {}
    for directory in directories:
        for path in sorted((root / directory).rglob("*")):
            if not path.is_file() or path.suffix not in suffixes:
                continue
            relative = path.relative_to(root).as_posix()
            if relative not in tracked:
                raise ValueError("Untracked native probe input: " + relative)
            native[relative] = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    if not native or test not in tracked or builder not in tracked:
        raise ValueError("Native probe inputs and builder must be committed")
    return {"source_commit": git("rev-parse", "HEAD").decode().strip(),
            "source_tree": git("rev-parse", "HEAD^{tree}").decode().strip(),
            "native_inputs": native,
            "test_sha256": hashlib.sha256((root / test).read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
            "builder_sha256": hashlib.sha256((root / builder).read_bytes().replace(b"\r\n", b"\n")).hexdigest()}

identity = source_identity()
output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.NamedTemporaryFile(prefix="." + output.stem + ".partial.", suffix=".exe",
                                 dir=output.parent, delete=False) as temporary:
    staged = Path(temporary.name)
try:
    actual_command = command[:-1] + [str(staged)]
    subprocess.run(actual_command, check=True,
                   env={**os.environ, "LC_ALL": "C", "TZ": "UTC", "SOURCE_DATE_EPOCH": "0"})
    if source_identity() != identity:
        raise ValueError("Source inputs changed during the Windows probe build")
    with staged.open("rb") as stream:
        header = stream.read(4096)
    if header[:2] != b"MZ":
        raise ValueError("Compiler did not produce a Windows PE probe")
    pe = struct.unpack_from("<I", header, 0x3c)[0]
    if header[pe:pe+4] != b"PE\0\0" or struct.unpack_from("<H", header, pe+4)[0] != 0x8664:
        raise ValueError("Probe is not a Windows x86_64 executable")
    optional = pe + 24
    if struct.unpack_from("<H", header, optional)[0] != 0x20b:
        raise ValueError("Probe does not have a PE32+ optional header")
    stack = struct.unpack_from("<Q", header, optional+72)[0]
    if stack != 1048576:
        raise ValueError("Probe must retain the ordinary 1 MiB Windows stack")
    receipt = {"schema": "cybersand.material-audition.windows-native-probe", "schema_version": 1,
               "status": "built-not-executed", "platform": "windows", **identity,
               "artifact": output.name, "sha256": sha(staged), "bytes": staged.stat().st_size,
               "compiler_sha256": sha(compiler), "compiler_version": version, "compiler_target": machine,
               "stack_reserve_bytes": stack, "command": command}
    staged.rename(output)
    receipt_path.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": receipt["status"], "artifact": str(output), "receipt": str(receipt_path),
                      "sha256": receipt["sha256"], "stack_reserve_bytes": stack}))
finally:
    staged.unlink(missing_ok=True)
PY
