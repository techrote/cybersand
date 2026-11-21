"""Source/toolchain-bound private native exporter builds.

These small gallery programs deliberately compile every translation unit afresh.
They never consume Make's shared worldgen object paths. A cached executable is
usable only with the identical requested compiler, effective toolchain, flags,
source inputs and executable bytes; --no-build is validation, not an override.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

CACHE_SCHEMA = "cybersand.architecture-exporter-cache-v1"
FLAGS = ["-std=c++20", "-O2", "-g0", "-Wall", "-Wextra", "-Wpedantic",
         "-Wconversion", "-Wshadow", "-Werror", "-Inative/include"]
TOOLCHAIN_ENVIRONMENT = ("PATH", "LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH",
                         "COMPILER_PATH", "GCC_EXEC_PREFIX", "CPATH",
                         "CPLUS_INCLUDE_PATH", "C_INCLUDE_PATH", "LIBRARY_PATH",
                         "SDKROOT", "MACOSX_DEPLOYMENT_TARGET")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def digest(value: object) -> str:
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())


def _resolve_program(program: str, root: Path) -> Path | None:
    candidate = Path(program)
    if not candidate.is_absolute() and ("/" in program or "\\" in program):
        candidate = root / candidate
    if candidate.is_file():
        return candidate.absolute()
    resolved = shutil.which(program)
    return Path(resolved).absolute() if resolved else None


def _file_identity(path: Path) -> dict:
    return {"path": str(path), "realpath": str(path.resolve()),
            "sha256": sha(path.read_bytes())}


def compiler_identity(compiler: str, root: Path) -> dict:
    # A full Windows path is a single program, not a POSIX shell expression.
    argv = [compiler] if Path(compiler).is_file() else shlex.split(compiler)
    if not argv:
        raise RuntimeError("a compiler command is required")
    driver = _resolve_program(argv[0], root)
    if driver is None:
        raise RuntimeError("requested compiler is unavailable: " + argv[0])
    # Preserve the executable's invocation name: clang++ can be a symlink whose
    # argv[0] selects the C++ driver even though its realpath is clang.
    argv[0] = str(driver)

    def probe(option: str) -> str:
        result = subprocess.run([*argv, option], cwd=root, capture_output=True,
                                text=True, check=False, timeout=30)
        if result.returncode:
            raise RuntimeError("compiler identity probe failed: " + option + "\n" + result.stderr)
        return result.stdout.strip()

    tools = {}
    for name in ("cc1plus", "as", "ld"):
        reported = probe("-print-prog-name=" + name)
        path = _resolve_program(reported, root)
        # Clang has an integrated front end, so a missing external cc1plus is
        # valid and recorded explicitly. The driver binary is always hashed.
        tools[name] = {"reported": reported,
                       "file": _file_identity(path) if path is not None else None}
    return {"requested_command": compiler, "argv": argv,
            "driver": _file_identity(driver), "version": probe("--version"),
            "target": probe("-dumpmachine"), "tools": tools,
            "environment": {key: os.environ.get(key, "") for key in TOOLCHAIN_ENVIRONMENT}}


def _require_inputs(root: Path, ledger: dict[str, str]) -> None:
    changed = [path for path, expected in ledger.items()
               if not (root / path).is_file() or sha((root / path).read_bytes()) != expected]
    if changed:
        raise RuntimeError("exporter source inputs changed: " + ", ".join(changed))


def build_exporter(*, root: Path, output: Path, ledger: dict[str, str],
                   compiler: str, skip: bool, generation_sources: list[str],
                   exporter: str) -> tuple[Path, dict]:
    """Build all sources directly, or strictly validate a private cached build."""
    _require_inputs(root, ledger)
    identity = compiler_identity(compiler, root)
    sources = ["native/src/" + name for name in generation_sources] + [exporter]
    if any(source not in ledger for source in sources):
        raise RuntimeError("exporter compile input is absent from the source ledger")
    request = {"schema": CACHE_SCHEMA, "compiler_identity": identity,
               "flags": FLAGS, "compile_sources": sources,
               "builder_sha256": sha(Path(__file__).read_bytes()),
               "source_input_sha256": digest(ledger)}
    build_key = digest(request)
    build = root / "build/architecture-exporters" / Path(exporter).stem / build_key
    executable = build / (Path(exporter).stem + (".exe" if os.name == "nt" else ""))
    marker = build / "build-identity.json"
    native_inputs = {path: value for path, value in ledger.items()
                     if path.startswith("native/") or path == exporter}
    if skip:
        try:
            record = json.loads(marker.read_text())
            if any(record.get(key) != value for key, value in request.items()) or \
                    record.get("build_key") != build_key or \
                    record.get("inputs") != ledger or \
                    record.get("native_input_sha256") != digest(native_inputs) or \
                    record.get("executable_sha256") != sha(executable.read_bytes()):
                raise ValueError("cache identity mismatch")
        except (OSError, ValueError, TypeError) as error:
            raise RuntimeError("--no-build requires an exporter matching the requested compiler identity, "
                               "current source inputs and executable hash; rebuild without --no-build") from error
        _require_inputs(root, ledger)
        if compiler_identity(compiler, root) != identity:
            raise RuntimeError("compiler identity changed during cache validation")
        return executable, record

    build.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    # A failed compile cannot replace a valid binary or its success marker.
    with tempfile.TemporaryDirectory(prefix="fresh-build-", dir=build) as temporary:
        staged = Path(temporary) / executable.name
        command = [*identity["argv"], *FLAGS, *sources, "-o", str(staged)]
        print("Building fresh native exporter: " + Path(exporter).stem, flush=True)
        process = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=1800)
        log = output / "exporter-build.log"
        log.write_text(process.stdout + process.stderr)
        if process.returncode:
            raise RuntimeError("native exporter compilation failed:\n" + process.stderr)
        _require_inputs(root, ledger)
        if compiler_identity(compiler, root) != identity:
            raise RuntimeError("compiler identity changed during exporter compilation")
        record = {**request, "build_key": build_key, "inputs": ledger,
                  "native_input_sha256": digest(native_inputs),
                  "compiler": identity["version"].splitlines()[0],
                  "command": command, "build_mode": "fresh direct compilation; no shared object reuse",
                  "executable_sha256": sha(staged.read_bytes()),
                  "build_log_sha256": sha(log.read_bytes())}
        staged.replace(executable)
        staged_marker = Path(temporary) / "build-identity.json"
        staged_marker.write_text(json.dumps(record, indent=2) + "\n")
        staged_marker.replace(marker)
    return executable, record
