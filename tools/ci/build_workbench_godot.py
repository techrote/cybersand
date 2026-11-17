#!/usr/bin/env python3
"""Build the explicitly patched, source-qualified Windows Workbench engine.

This is a build/provenance gate, not application or physical GPU acceptance.
All dependencies are pinned before extraction. Every failure keeps its logs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import stat
import struct
import subprocess
import sys
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
# ComBase is the inbox Windows Runtime implementation (Windows 8 / Server 2012+):
# https://learn.microsoft.com/windows/win32/api/roapi/nf-roapi-rogetactivationfactory
SYSTEM_DLLS = set("""advapi32 avrt bcrypt bcryptprimitives cfgmgr32 combase comctl32 comdlg32
crypt32 d3d9 d3d11 d3dcompiler_47 dcomp dbghelp dnsapi dsound dwmapi dwrite dxgi dxguid
gdi32 hid imm32 iphlpapi kernel32 mincore mpr msimg32 msvcrt ncrypt netapi32 normaliz
ntdll ole32 oleacc oleaut32 opengl32 powrprof propsys psapi rpcrt4 runtimeobject sapi
secur32 setupapi shcore shell32 shlwapi ucrtbase uiautomationcore user32 userenv usp10
version wbemuuid winhttp wininet winmm winspool wintrust ws2_32 wsock32 wtsapi32
xinput1_4""".split())


def require(value: object, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def digest(path: Path, algorithm: str = "sha256") -> str:
    h = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def file_record(path: Path) -> dict:
    require(path.is_file() and not path.is_symlink(), f"Not a regular file: {path}")
    return {"bytes": path.stat().st_size, "sha256": digest(path)}


def run(command: list[str], cwd: Path, evidence: Path, label: str,
        timeout: int = 180, env: dict | None = None) -> str:
    started = time.monotonic()
    log = evidence / (label + ".log")
    receipt = {"command": command, "cwd": str(cwd), "timeout_seconds": timeout}
    print(f"{label}: starting (timeout {timeout}s)", flush=True)
    try:
        with log.open("w", encoding="utf-8", newline="\n") as output:
            process = subprocess.Popen(command, cwd=cwd, env=env, stdout=output,
                                       stderr=subprocess.STDOUT, text=True)
            try:
                receipt["returncode"] = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                # SCons owns compiler children; terminating only its Python parent
                # could leave active writers after the failed build receipt.
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               stdout=output, stderr=subprocess.STDOUT, timeout=30,
                               check=False)
                process.wait(timeout=30)
                receipt["timed_out"] = True
                raise
        require(receipt["returncode"] == 0, f"{label} failed; see {log}")
        return log.read_text(encoding="utf-8", errors="replace")
    finally:
        receipt["elapsed_seconds"] = time.monotonic() - started
        if log.exists():
            receipt["log"] = file_record(log)
        write_json(evidence / (label + ".json"), receipt)
        print(f"{label}: {receipt.get('returncode', 'incomplete')} ({receipt['elapsed_seconds']:.1f}s)", flush=True)


def git(source: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(source), *args], text=True).strip()


def download(spec: dict, directory: Path) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / spec["filename"]
    require(not path.exists(), f"Download output already exists: {path}")
    request = urllib.request.Request(spec["url"], headers={"User-Agent": "CyberSand-pinned-engine-build"})
    with urllib.request.urlopen(request, timeout=180) as response, path.open("xb") as output:
        shutil.copyfileobj(response, output, length=1024 * 1024)
    if "bytes" in spec:
        require(path.stat().st_size == spec["bytes"], f"Dependency size drift: {path.name}")
    algorithm = "sha256" if "sha256" in spec else "sha512"
    require(digest(path, algorithm) == spec[algorithm], f"Dependency digest drift: {path.name}")
    write_json(path.with_name(path.name + ".receipt.json"), {"url": spec["url"],
               "verified_algorithm": algorithm, "verified_digest": spec[algorithm], **file_record(path)})
    return path


def extract(archive: Path, target: Path) -> list[dict]:
    require(not target.exists(), f"Extraction target already exists: {target}")
    target.mkdir(parents=True)
    rows, seen = [], set()
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            name = member.filename
            path = PurePosixPath(name)
            require(name and "\\" not in name and ":" not in name and not path.is_absolute()
                    and ".." not in path.parts and name.casefold() not in seen,
                    f"Unsafe or duplicate ZIP path: {name}")
            seen.add(name.casefold())
            mode = member.external_attr >> 16
            require(not stat.S_ISLNK(mode), f"ZIP symlink: {name}")
            if member.is_dir():
                (target / path).mkdir(parents=True, exist_ok=True)
                continue
            require(member.file_size <= 1024 * 1024 * 1024, f"Unexpected large ZIP member: {name}")
            data = bundle.read(member)  # Also verifies the member's CRC.
            destination = target / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
            rows.append({"path": name, **file_record(destination)})
    return rows


def pe_imports(path: Path) -> dict:
    data = path.read_bytes()
    require(data[:2] == b"MZ", f"Missing DOS PE header: {path}")
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    require(data[pe:pe + 4] == b"PE\0\0", f"Missing PE header: {path}")
    machine, count, _, _, _, optional_size, _ = struct.unpack_from("<HHIIIHH", data, pe + 4)
    optional = pe + 24
    require(machine == 0x8664 and struct.unpack_from("<H", data, optional)[0] == 0x20B,
            f"Not Windows x64 PE32+: {path}")
    sections = []
    for i in range(count):
        start = optional + optional_size + i * 40
        virtual_size, rva, raw_size, raw = struct.unpack_from("<IIII", data, start + 8)
        sections.append((rva, max(virtual_size, raw_size), raw, raw_size))
    headers_size = struct.unpack_from("<I", data, optional + 60)[0]

    def offset(rva: int) -> int:
        if rva < headers_size:
            return rva
        for first, size, raw, raw_size in sections:
            if first <= rva < first + size:
                require(rva - first < raw_size, "PE RVA points outside stored bytes")
                return raw + rva - first
        raise RuntimeError(f"Unmapped PE RVA: {rva}")

    def dll_name(rva: int) -> str:
        start = offset(rva)
        return data[start:data.index(b"\0", start, start + 512)].decode("ascii").lower()

    def directory(index: int) -> tuple[int, int]:
        entries = struct.unpack_from("<I", data, optional + 108)[0]
        return struct.unpack_from("<II", data, optional + 112 + index * 8) if entries > index else (0, 0)

    imports, delays = [], []
    rva, size = directory(1)
    if rva:
        start = offset(rva)
        for n in range(min(size // 20 + 1, 4096)):
            descriptor = struct.unpack_from("<IIIII", data, start + n * 20)
            if not any(descriptor):
                break
            imports.append(dll_name(descriptor[3]))
    rva, size = directory(13)
    if rva:
        start = offset(rva)
        image_base = struct.unpack_from("<Q", data, optional + 24)[0]
        for n in range(min(size // 32 + 1, 4096)):
            descriptor = struct.unpack_from("<IIIIIIII", data, start + n * 32)
            if not any(descriptor):
                break
            delays.append(dll_name(descriptor[1] if descriptor[0] & 1 else descriptor[1] - image_base))
    all_imports = sorted(set(imports + delays))
    unknown = [name for name in all_imports if not name.startswith(("api-ms-", "ext-ms-"))
               and name.removesuffix(".dll") not in SYSTEM_DLLS]
    return {"machine": "x86_64", "subsystem": struct.unpack_from("<H", data, optional + 68)[0],
            "imports": sorted(set(imports)), "delay_imports": sorted(set(delays)),
            "unresolved_non_system_imports": unknown,
            "certificate_table_bytes": directory(4)[1],
            "scope": "Static import closure only; runtime LoadLibrary paths require actual Windows execution."}


def normalize_api(value: dict) -> dict:
    result = json.loads(json.dumps(value))
    for key in ("version_build", "version_full_name"):
        require(key in result["header"], f"Missing API identity header {key}")
        del result["header"][key]
    return result


def api_dump(engine: Path, directory: Path, evidence: Path, label: str) -> dict:
    directory.mkdir(parents=True)
    for option in ("dump-extension-api", "dump-gdextension-interface", "dump-gdextension-interface-json"):
        run([str(engine), "--headless", "--" + option], directory, evidence, label + "-" + option)
    return {name: file_record(directory / name) for name in
            ("extension_api.json", "gdextension_interface.h", "gdextension_interface.json")}


def build(args: argparse.Namespace) -> None:
    require(os.name == "nt" and platform.machine().lower() in ("amd64", "x86_64"), "Windows x64 build host required")
    require(sys.version_info[:2] == (3, 12), "Use the pinned Python 3.12 workflow")
    require(1 <= args.workers <= 4, "Worker count must be bounded to 1..4")
    source, output, evidence = args.source_dir.resolve(), args.output.resolve(), args.evidence.resolve()
    require(not output.exists() and not evidence.exists(), "Output and evidence directories must be fresh")
    output.mkdir(parents=True)
    evidence.mkdir(parents=True)
    lock_path = ROOT / "third_party/workbench-godot.lock.json"
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    provenance = {"schema": "workbench-godot-build-provenance-v1", "complete": False,
                  "custom_engine": True, "scope": lock["scope"], "lock": file_record(lock_path),
                  "builder": file_record(Path(__file__)), "python": sys.version,
                  "platform": platform.platform(), "workers": args.workers,
                  "application_source": git(ROOT, "rev-parse", "HEAD"),
                  "workflow_run": os.getenv("GITHUB_RUN_ID"), "workflow_attempt": os.getenv("GITHUB_RUN_ATTEMPT")}
    try:
        require(git(source, "rev-parse", "HEAD") == lock["source_commit"], "Wrong Godot source commit")
        require(not git(source, "status", "--porcelain", "--untracked-files=normal"), "Godot checkout is not clean")
        # Git for Windows may have expanded canonical LF blobs to CRLF. Restore
        # only this verified clean disposable engine checkout before byte checks.
        initial_autocrlf = subprocess.run(["git", "-C", str(source), "config", "--get", "core.autocrlf"],
                                         stdout=subprocess.PIPE, text=True, check=False)
        require(initial_autocrlf.returncode in (0, 1), "Cannot inspect checkout EOL configuration")
        provenance["initial_core_autocrlf"] = initial_autocrlf.stdout.strip() if initial_autocrlf.returncode == 0 else None
        run(["git", "config", "core.autocrlf", "false"], source, evidence, "canonical-checkout-config")
        run(["git", "checkout-index", "--force", "--all"], source, evidence, "canonical-checkout-files")
        require(not git(source, "status", "--porcelain", "--untracked-files=normal"), "Canonical checkout changed tracked content")
        provenance["upstream_commit"] = lock["source_commit"]
        provenance["upstream_tree"] = git(source, "rev-parse", "HEAD^{tree}")
        changed = set()
        provenance["patches"] = []
        for i, patch in enumerate(lock["patches"]):
            path = ROOT / patch["path"]
            require(digest(path) == patch["sha256"], "Patch digest drift")
            for name, hashes in patch["files"].items():
                require(digest(source / name) == hashes["before_sha256"], f"Patch input drift: {name}")
            run(["git", "apply", "--check", str(path)], source, evidence, f"patch-{i}-check")
            run(["git", "apply", str(path)], source, evidence, f"patch-{i}-apply")
            for name, hashes in patch["files"].items():
                require(digest(source / name) == hashes["after_sha256"], f"Patch output drift: {name}")
                changed.add(name)
            provenance["patches"].append(patch)
        require(set(git(source, "diff", "--name-only").splitlines()) == changed, "Unexpected engine source delta")
        combined = subprocess.check_output(["git", "-C", str(source), "diff", "--binary", "--no-ext-diff"])
        (evidence / "engine-source.patch").write_bytes(combined)
        provenance["combined_patch"] = file_record(evidence / "engine-source.patch")
        provenance["patched_sources"] = {name: file_record(source / name) for name in sorted(changed)}
        downloads, deps = evidence / "downloads", evidence / "dependencies"
        archives = {name: download(lock[name], downloads) for name in ("scons", "angle", "accesskit", "official_reference")}
        provenance["dependency_archives"] = {name: file_record(path) for name, path in archives.items()}
        for name in ("angle", "accesskit", "official_reference"):
            rows = extract(archives[name], deps / name)
            write_json(evidence / (name + "-extraction.json"), {"all_member_crc_checked": True, "files": rows})
        angle = deps / "angle"
        for name in ("libANGLE.windows.x86_64.lib", "libEGL.windows.x86_64.lib", "libGLES.windows.x86_64.lib"):
            require((angle / name).is_file(), f"Missing MSVC static ANGLE library: {name}")
        accesskit = deps / "accesskit" / "accesskit-c-0.21.2"
        require((accesskit / "lib/windows/x86_64/msvc/static/accesskit.lib").is_file(), "Missing static AccessKit library")
        run([sys.executable, "-m", "pip", "install", "--no-index", "--no-deps", "--force-reinstall", str(archives["scons"])],
            source, evidence, "install-pinned-scons", 180)
        run([sys.executable, "-m", "SCons", "--version"], source, evidence, "scons-version")
        # The workflow's hosted image is recorded rather than claimed bitwise
        # reproducible; SCons selects the supported VS2022 MSVC and Windows SDK.
        vswhere = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Microsoft Visual Studio/Installer/vswhere.exe"
        require(vswhere.is_file(), "Visual Studio installer discovery is missing")
        run([str(vswhere), "-products", "*", "-format", "json", "-utf8"], source, evidence, "visual-studio-installed")
        env = os.environ.copy()
        env["BUILD_NAME"] = lock["build_name"]
        env["PYTHONIOENCODING"] = "utf-8"
        env["SCONS_CACHE_MSVC_CONFIG"] = "true"
        for key in ("GODOT_VERSION_STATUS", "GODOT_VERSION_TIMESTAMP", "SCONSFLAGS", "CCFLAGS", "CXXFLAGS", "LDFLAGS", "CL", "_CL_"):
            env.pop(key, None)
        flags = lock["scons_flags"] + ["angle_libs=" + str(angle), "accesskit_sdk_path=" + str(accesskit)]
        provenance["scons_flags"] = flags
        provenance["build_name"] = env["BUILD_NAME"]
        run([sys.executable, "-m", "SCons", *flags, "-j" + str(args.workers)], source,
            evidence, "compile", 7200, env)
        for relative in ("compile_commands.json", "platform/windows/msvc_capture.log"):
            path = source / relative
            if path.is_file():
                destination = evidence / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, destination)
        require(set(git(source, "diff", "--name-only").splitlines()) == changed, "Build changed engine source")
        require(subprocess.check_output(["git", "-C", str(source), "diff", "--binary", "--no-ext-diff"]) == combined,
                "Engine source drifted during compilation")
        (output / "bin").mkdir()
        for name in (lock["output_gui"], lock["output_console"]):
            shutil.copy2(source / "bin" / name, output / "bin" / name)
        gui, console = output / "bin" / lock["output_gui"], output / "bin" / lock["output_console"]
        provenance["gui_executable"] = gui.relative_to(output).as_posix()
        provenance["console_executable"] = console.relative_to(output).as_posix()
        provenance["executables"] = {p.name: {**file_record(p), "pe": pe_imports(p)} for p in (gui, console)}
        require(provenance["executables"][gui.name]["pe"]["subsystem"] == 2, "GUI subsystem mismatch")
        require(provenance["executables"][console.name]["pe"]["subsystem"] == 3, "Console subsystem mismatch")
        unresolved = {name: row["pe"]["unresolved_non_system_imports"]
                      for name, row in provenance["executables"].items()
                      if row["pe"]["unresolved_non_system_imports"]}
        require(not unresolved, f"Unexpected dynamic dependencies; static import closure failed: {unresolved}")
        version = run([str(console), "--version"], output, evidence, "custom-version").strip()
        require(version == lock["version"], f"Custom version mismatch: {version!r}")
        provenance["version"] = version
        reference = lock["official_reference"]
        official_gui, official_console = deps / "official_reference" / reference["gui"], deps / "official_reference" / reference["console"]
        require(digest(official_gui) == reference["gui_sha256"] and digest(official_console) == reference["console_sha256"], "Official executable digest mismatch")
        require(run([str(official_console), "--version"], evidence, evidence, "official-version").strip() == reference["version"], "Official version mismatch")
        provenance["api_dumps"] = {"official": api_dump(official_console, evidence / "api-official", evidence, "official"),
                                   "custom": api_dump(console, evidence / "api-custom", evidence, "custom")}
        old_api = json.loads((evidence / "api-official/extension_api.json").read_text(encoding="utf-8"))
        new_api = json.loads((evidence / "api-custom/extension_api.json").read_text(encoding="utf-8"))
        same = normalize_api(old_api) == normalize_api(new_api)
        interface_same = all((evidence / "api-official" / name).read_bytes() == (evidence / "api-custom" / name).read_bytes()
                             for name in ("gdextension_interface.h", "gdextension_interface.json"))
        write_json(evidence / "api-equivalence.json", {"api_equal_except_declared_build_labels": same,
                   "interface_bytes_equal": interface_same,
                   "ignored_header_fields": ["version_build", "version_full_name"],
                   "official_header": old_api["header"], "custom_header": new_api["header"]})
        require(same and interface_same, "Public GDExtension API differs; inspect retained complete dumps")
        run([str(console), "--headless", "--validate-extension-api", str(evidence / "api-official/extension_api.json")],
            evidence, evidence, "custom-validates-official-api")
        provenance["public_api_equivalent"] = True
        provenance["application_and_graphical_qualification"] = "Pending separate exact-source Windows gates; not implied by this build."
        notices = output / "notices"
        notices.mkdir()
        for name in ("LICENSE.txt", "COPYRIGHT.txt"):
            shutil.copy2(source / name, notices / name)
        for dependency in ("angle", "accesskit"):
            for path in sorted((deps / dependency).rglob("*")):
                if path.is_file() and path.name.lower().startswith(("license", "copying", "copyright", "notice")):
                    destination = notices / dependency / path.relative_to(deps / dependency)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
        shutil.copy2(lock_path, output / "workbench-godot.lock.json")
        shutil.copy2(evidence / "engine-source.patch", output / "engine-source.patch")
        shutil.copy2(evidence / "api-equivalence.json", output / "api-equivalence.json")
        for path in (source / "core/version_generated.gen.h", source / "core/version_hash.gen.cpp"):
            require(path.is_file(), f"Missing generated identity: {path}")
            shutil.copy2(path, evidence / path.name)
        provenance["complete"] = True
        provenance["payload_files"] = {p.relative_to(output).as_posix(): file_record(p)
                                       for p in sorted(output.rglob("*")) if p.is_file()}
    except Exception as error:
        provenance["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        write_json(evidence / "build-provenance.json", provenance)
        write_json(output / "build-provenance.json", provenance)
    if args.archive:
        require(not args.archive.exists(), "Archive output already exists")
        with zipfile.ZipFile(args.archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
            for path in sorted(output.rglob("*")):
                if path.is_file():
                    bundle.write(path, path.relative_to(output).as_posix())
        write_json(args.archive.with_suffix(args.archive.suffix + ".json"), file_record(args.archive))
    print("WORKBENCH_GODOT_BUILD PASS: source, dependency, public API and payload provenance verified", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--archive", type=Path)
    build(parser.parse_args())


if __name__ == "__main__":
    main()
