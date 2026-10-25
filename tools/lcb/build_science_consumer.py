#!/usr/bin/env python3
"""Bounded Linux-host Release build of the five-TU science apparatus only.

The Windows target uses the existing locked Linux-host LLVM-MinGW archive.
Its compiler.bin artifact is Linux-host compiler/driver identity data on Windows,
never a compiler executed on Windows. A selected driver file hash alone does not
identify all transitive compiler dependencies; the cross archive is bound too.
No Native library, runtime provenance, fixture or publication is modified.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import time
import traceback

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ("native/src/world.cpp", "native/src/material_rules.cpp",
           "native/src/scheduler_geometry.cpp", "native/src/settled_world_discovery.cpp",
           "native/bench/lcb_science.cpp")
FLAGS = ("-std=c++20", "-Wall", "-Wextra", "-Wpedantic", "-Wconversion", "-Wshadow",
         "-Inative/include", "-O3", "-DNDEBUG", "-flto", "-pthread")
COMPILE_TIMEOUT = 180
LINK_TIMEOUT = 180


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def save(path: Path, value: object) -> None:
    with path.open("x", encoding="utf8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write("\n")


def command(argv: list[str], out: Path, name: str, timeout: int) -> dict:
    start = time.monotonic()
    code = None
    timed_out = False
    launch_error = None
    with (out / (name + ".stdout")).open("xb") as stdout, (out / (name + ".stderr")).open("xb") as stderr:
        try:
            process = subprocess.Popen(argv, cwd=ROOT, stdout=stdout, stderr=stderr,
                                       start_new_session=sys.platform.startswith("linux"),
                                       env={**os.environ, "LC_ALL": "C", "TZ": "UTC", "SOURCE_DATE_EPOCH": "0"})
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                # The actual build host is Linux: stop the entire compiler/
                # linker tree, not only a driver which may have spawned cc1/ld.
                if sys.platform.startswith("linux"):
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                else:  # Portable tiny pure-test child; never an actual build.
                    process.kill()
                process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            timed_out = True
        except OSError as error:
            launch_error = str(error)
    record = {"command": argv, "timeout_seconds": timeout, "seconds": time.monotonic() - start,
              "returncode": code, "timed_out": timed_out, "launch_error": launch_error,
              "stdout_sha256": sha(out / (name + ".stdout")), "stderr_sha256": sha(out / (name + ".stderr"))}
    save(out / (name + ".json"), record)
    require(code == 0 and not timed_out and launch_error is None, "build command failed: " + name)
    return record


def dep_paths(text: str, root: Path) -> list[str]:
    """Decode compiler Make depfiles, including continuations/space/#/$ escapes.

    Build hosts are Linux, so Windows drive-colon syntax is deliberately absent.
    Dependencies must be existing regular repository files. No shell is used.
    """
    text = text.replace("\\\r\n", "").replace("\\\n", "")
    escaped = False
    separator = None
    for index, char in enumerate(text):
        if char == ":" and not escaped:
            separator = index
            break
        escaped = char == "\\" and not escaped
    require(separator is not None, "depfile target separator missing")
    words = []
    token = ""
    tail = text[separator + 1:]
    index = 0
    while index < len(tail):
        char = tail[index]
        if char == "\\":
            index += 1
            require(index < len(tail), "truncated depfile escape")
            token += tail[index]
        elif char == "$" and index + 1 < len(tail) and tail[index + 1] == "$":
            token += "$"
            index += 1
        elif char.isspace():
            if token:
                words.append(token)
                token = ""
        else:
            require(char != "#", "unescaped depfile comment")
            token += char
        index += 1
    if token:
        words.append(token)
    require(words, "empty dependency map")
    result = set()
    for word in words:
        path = Path(word)
        path = (root / path).resolve() if not path.is_absolute() else path.resolve()
        require(path.is_relative_to(root.resolve()) and path.is_file(), "depfile escapes/misses source repository")
        result.add(path.relative_to(root.resolve()).as_posix())
    return sorted(result)


def source_fence() -> dict[str, str]:
    names = set(SOURCES) | {"tools/lcb/build_science_consumer.py", "third_party/native-toolchain.lock.json"}
    for directory in ("native/include", "native/src"):
        names.update(p.relative_to(ROOT).as_posix() for p in (ROOT / directory).rglob("*")
                     if p.is_file() and p.suffix in {".h", ".hpp", ".cpp", ".inc"})
    return {name: sha(ROOT / name) for name in sorted(names)}


def selected_toolchain(args: argparse.Namespace, out: Path) -> dict:
    lock = json.loads((ROOT / "third_party/native-toolchain.lock.json").read_text(encoding="utf8"))
    compiler = args.compiler.absolute()  # Preserve the cross-driver argv[0].
    require(compiler.is_file(), "actual compiler file missing")
    version_record = command([str(compiler), "--version"], out, "compiler-version", 30)
    version = (out / "compiler-version.stdout").read_text(encoding="utf8")
    machine_record = command([str(compiler), "-dumpmachine"], out, "compiler-machine", 30)
    machine = (out / "compiler-machine.stdout").read_text(encoding="utf8").strip()
    binding = {"compiler_path": str(compiler), "compiler_sha256": sha(compiler), "compiler_version": version,
               "compiler_machine": machine, "build_host": "linux-x86_64", "target": args.target,
               "compiler_execution_in_target_job": args.target == "linux", "identity_commands": [version_record, machine_record]}
    if args.target == "linux":
        require(args.toolchain_archive is None and args.toolchain_root is None, "Linux build uses actual pinned host GNU compiler")
        pin = next(v for v in lock["artifacts"] if v["name"] == "GNU C++")
        require(pin["version"].split()[0] in version and "x86_64" in machine and "linux" in machine,
                "GNU compiler version/target differs from existing pin")
        command([str(compiler), "-print-prog-name=ld"], out, "linker-path", 30)
        linker_name = (out / "linker-path.stdout").read_text(encoding="utf8").strip()
        linker = Path(shutil.which(linker_name) or linker_name).resolve()
        require(linker.is_file(), "actual GNU linker missing")
        command([str(linker), "--version"], out, "linker-version", 30)
        linker_version = (out / "linker-version.stdout").read_text(encoding="utf8")
        require("2.42" in linker_version, "GNU linker differs from existing pin")
        binding["host_pin"] = pin
        binding["linker"] = {"path": str(linker), "sha256": sha(linker), "version": linker_version}
        return binding
    require(args.toolchain_archive is not None and args.toolchain_root is not None, "Windows target requires existing pinned cross archive/root")
    pin = next(v for v in lock["artifacts"] if v["name"] == "llvm-mingw")
    require(args.toolchain_archive.stat().st_size == pin["size"] and sha(args.toolchain_archive) == pin["sha256"], "cross archive differs from existing lock")
    require("23.1.0" in version and "x86_64" in machine and ("mingw" in machine or "windows" in machine), "cross compiler version/target mismatch")
    real = compiler.resolve()
    require(real.is_relative_to(args.toolchain_root.resolve()), "cross compiler outside pinned extraction")
    relative = real.relative_to(args.toolchain_root.resolve()).as_posix()
    with tarfile.open(args.toolchain_archive, "r:xz") as archive:
        matching = [m for m in archive.getmembers() if m.isfile() and m.name.endswith("/" + relative)]
        require(len(matching) == 1, "compiler archive member not unique")
        stream = archive.extractfile(matching[0])
        require(stream is not None and hashlib.sha256(stream.read()).hexdigest() == sha(real), "extracted compiler differs from pinned archive member")
    binding.update(archive_sha256=pin["sha256"], archive_size=pin["size"], compiler_archive_member=matching[0].name)
    return binding


def windows_libraries(args: argparse.Namespace, out: Path, executable: Path) -> dict:
    reader = args.toolchain_root / "bin/llvm-readobj"
    require(reader.is_file(), "cross PE inspection tool missing")
    command([str(reader), "--file-headers", "--coff-imports", str(executable)], out, "pe-imports", 30)
    imports = (out / "pe-imports.stdout").read_text(encoding="utf8")
    require("IMAGE_FILE_MACHINE_AMD64" in imports, "consumer is not actual Windows AMD64 PE")
    names = {n.lower() for n in re.findall(r"Name: ([^\r\n]+\.dll)", imports, re.IGNORECASE)}
    libraries = {}
    directory = out / "libraries"
    directory.mkdir()
    with tarfile.open(args.toolchain_archive, "r:xz") as archive:
        for member in archive.getmembers():
            if not member.isfile() or not member.name.lower().endswith(".dll") or "x86_64-w64-mingw32/" not in member.name:
                continue
            name = PurePosixPath(member.name).name
            require(name.lower() not in libraries, "ambiguous target DLL basename in pinned archive")
            stream = archive.extractfile(member)
            require(stream is not None, "target DLL archive read failed")
            data = stream.read()
            require(data.startswith(b"MZ"), "target DLL is not PE")
            target = directory / name
            with target.open("xb") as handle:
                handle.write(data)
            libraries[name.lower()] = {"path": target.relative_to(out).as_posix(), "sha256": sha(target), "archive_member": member.name}
    system = {"kernel32.dll", "advapi32.dll", "shell32.dll", "user32.dll", "ole32.dll", "ws2_32.dll", "ntdll.dll", "msvcrt.dll", "ucrtbase.dll", "bcrypt.dll"}
    require(all(name in libraries or name in system or name.startswith(("api-ms-win-", "ext-ms-win-")) for name in names), "unbound non-system PE dependency")
    return {"imports": sorted(names), "files": libraries, "scope": "Pinned target DLL file identities, not verified mapped modules"}


def linux_library_paths(text: str) -> list[Path]:
    """Read the actual trusted consumer's loader listing; never infer a pin."""
    paths = set()
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("linux-vdso.so."):
            continue
        require("not found" not in line, "unresolved Linux consumer dependency")
        value = line.split("=>", 1)[-1].strip().split(" (", 1)[0]
        path = Path(value)
        require(path.is_absolute() and path.is_file(), "unrecognized Linux loader dependency")
        paths.add(path.resolve())
    require(paths, "Linux consumer dependency listing empty")
    return sorted(paths)


def linux_libraries(out: Path, executable: Path) -> dict:
    command(["ldd", str(executable)], out, "elf-libraries", 30)
    paths = linux_library_paths((out / "elf-libraries.stdout").read_text(encoding="utf8"))
    return {"files": {str(path): {"sha256": sha(path), "size": path.stat().st_size} for path in paths},
            "scope": "Actual Linux host loader dependency file identities; not pinned or verified mapped modules"}


def build(args: argparse.Namespace) -> None:
    out = args.out.resolve()
    require(not out.exists() and not out.is_relative_to(ROOT), "new external build output required")
    out.mkdir(parents=True)
    stage = "host admission"
    try:
        require(sys.platform.startswith("linux"), "build host must be actual Linux; Windows stage only executes the PE consumer")
        before = source_fence()
        save(out / "PROSPECTIVE-BUILD.json", {"schema": "lcb-science-consumer-build-plan-v1", "target": args.target,
             "sources": list(SOURCES), "source_fence": before, "flags": list(FLAGS),
             "compile_timeout_seconds": COMPILE_TIMEOUT, "link_timeout_seconds": LINK_TIMEOUT,
             "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
             "scope": "Five-TU Release apparatus build only; no engine/Godot execution or publication"})
        stage = "toolchain identity"
        toolchain = selected_toolchain(args, out)
        objects = out / "objects"
        objects.mkdir()
        records = {}
        complete = {}
        object_paths = []
        for index, source in enumerate(SOURCES):
            stage = "compile " + source
            obj = objects / (str(index) + ".o")
            dep = objects / (str(index) + ".d")
            argv = [str(args.compiler.absolute()), *FLAGS, "-MMD", "-MF", str(dep), "-c", source, "-o", str(obj)]
            record = command(argv, out, "compile-" + str(index), COMPILE_TIMEOUT)
            require(obj.is_file() and dep.is_file(), "successful compiler omitted object/depfile")
            paths = dep_paths(dep.read_text(encoding="utf8"), ROOT)
            require(source in paths, "depfile omits actual TU")
            current = {path: sha(ROOT / path) for path in paths}
            require(all(path in before and before[path] == digest for path, digest in current.items()), "new/changed dependency during build")
            complete.update(current)
            records[source] = {**record, "compiled_inputs": current, "object_sha256": sha(obj), "dep_sha256": sha(dep)}
            object_paths.append(str(obj))
            require(source_fence() == before, "source changed during compiler process")
        stage = "link"
        executable = out / ("lcb_science.exe" if args.target == "windows" else "lcb_science")
        link = command([str(args.compiler.absolute()), *FLAGS, *object_paths, "-o", str(executable)], out, "link", LINK_TIMEOUT)
        require(executable.is_file(), "successful linker omitted executable")
        library_binding = windows_libraries(args, out, executable) if args.target == "windows" else linux_libraries(out, executable)
        require(source_fence() == before, "final source changed")
        shutil.copyfile(args.compiler.resolve(), out / "compiler.bin")
        require(sha(out / "compiler.bin") == toolchain["compiler_sha256"], "compiler artifact copy mismatch")
        save(out / "source-map.json", complete)
        save(out / "libraries.json", library_binding)
        save(out / "build-receipt.json", {"schema": "lcb-science-consumer-build-v1", "exe_sha256": sha(executable), "exe_size": executable.stat().st_size,
              "compiler_sha256": toolchain["compiler_sha256"], "flags": list(FLAGS), "source_inputs": complete,
              "compile_records": records, "link": link, "toolchain": toolchain, "libraries": library_binding,
              "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
              "build_source_sha256": sha(Path(__file__)), "complete_source_fences_held": True,
              "scope": "Build only. compiler.bin is Linux-host compiler/driver identity data in actual Windows execution; its file hash alone does not bind every transitive compiler dependency. The pinned cross archive is separately authenticated. No Windows compiler execution or published runtime claim."})
        save(out / "bundle-sha256.json", {p.relative_to(out).as_posix(): sha(p) for p in out.rglob("*") if p.is_file()})
        print(json.dumps({"status": "built", "target": args.target, "sources": len(SOURCES), "compiler_inputs": len(complete), "exe_sha256": sha(executable)}))
    except Exception as error:
        save(out / "FAILURE.json", {"stage": stage, "error": str(error), "traceback": traceback.format_exc(), "partial_outputs_retained": True, "retry": False})
        raise


def bundle_inputs(folder: Path, expected_source: str, target: str) -> tuple[dict, dict]:
    folder = folder.resolve()
    manifest = json.loads((folder / "bundle-sha256.json").read_text(encoding="utf8"))
    require(type(manifest) is dict and manifest, "complete bundle manifest required")
    actual = {p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file()
              and p != folder / "bundle-sha256.json"}
    require(set(manifest) == actual, "bundle file set changed")
    for name, digest in manifest.items():
        path = PurePosixPath(name)
        require(not path.is_absolute() and ".." not in path.parts and "\\" not in name, "unsafe bundle path")
        require(type(digest) is str and re.fullmatch("[0-9a-f]{64}", digest) is not None
                and sha(folder / name) == digest, "bundle byte mismatch: " + name)
    receipt = json.loads((folder / "build-receipt.json").read_text(encoding="utf8"))
    require(receipt["schema"] == "lcb-science-consumer-build-v1" and receipt["source_commit"] == expected_source
            and receipt["toolchain"]["target"] == target and receipt["complete_source_fences_held"] is True,
            "bundle source/target/completion mismatch")
    sources = json.loads((folder / "source-map.json").read_text(encoding="utf8"))
    require(sources == receipt["source_inputs"] and set(SOURCES) <= sources.keys(), "complete bundle source map mismatch")
    return receipt, sources


def restore_compiled_checkout(folder: Path, expected_source: str, target: str, out: Path) -> None:
    """Restore only complete compiled Native text paths from the exact Git index.

    This is checkout repair, never hash normalization or admission of changed
    source. The normal exact bundle/source verifier still runs afterward.
    """
    out = out.resolve()
    require(not out.exists() and not out.is_relative_to(ROOT) and not out.is_relative_to(folder.resolve()),
            "new external checkout-repair output required")
    require(target == "windows", "checkout restoration is only for actual Windows transfer")
    _, sources = bundle_inputs(folder, expected_source, target)
    require(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, timeout=30).decode().strip() == expected_source,
            "checkout Git head differs from build")
    before = {}
    for name, digest in sources.items():
        path = PurePosixPath(name)
        require(not path.is_absolute() and ".." not in path.parts and "\\" not in name
                and name == path.as_posix() and name.startswith(("native/include/", "native/src/", "native/bench/"))
                and path.suffix in {".h", ".hpp", ".cpp", ".inc"} and (ROOT / name).is_file(),
                "checkout repair admits only compiled Native text paths")
        data = subprocess.check_output(["git", "show", "HEAD:" + name], cwd=ROOT, timeout=30)
        require(hashlib.sha256(data).hexdigest() == digest, "compiled source differs from actual Git blob")
        actual = (ROOT / name).read_bytes()
        before[name] = {"raw_sha256": hashlib.sha256(actual).hexdigest(),
                        "canonical_lf_sha256": hashlib.sha256(actual.replace(b"\r\n", b"\n")).hexdigest(),
                        "git_blob_content_sha256": digest,
                        "git_blob": subprocess.check_output(["git", "rev-parse", "HEAD:" + name], cwd=ROOT, timeout=30).decode().strip()}
    subprocess.run(["git", "diff", "--cached", "--quiet", "--", *sources], cwd=ROOT, check=True, timeout=30)
    out.mkdir(parents=True)
    save(out / "PROSPECTIVE-CHECKOUT.json", {"head": expected_source, "paths": before,
         "scope": "Git index checkout of only compiled Native text; no LFS or parser/source-map normalization"})
    try:
        subprocess.run(["git", "config", "--local", "core.autocrlf", "false"], cwd=ROOT, check=True, timeout=30)
        data = b"".join(name.encode("utf8") + b"\0" for name in sources)
        # --force alone can retain a stat-cached CRLF working file after a
        # config change. --temp always materializes the actual index content.
        # text=auto also observes core.eol=native on Windows, independently
        # of autocrlf=false. Scope an explicit LF checkout to this command.
        args = ["git", "-c", "core.eol=lf", "checkout-index", "--temp", "--stdin", "-z"]
        result = subprocess.run(args, cwd=ROOT, input=data, capture_output=True, timeout=30)
        (out / "checkout.stdout").write_bytes(result.stdout)
        (out / "checkout.stderr").write_bytes(result.stderr)
        require(result.returncode == 0, "compiled text checkout failed")
        extracted = {}
        for item in result.stdout.split(b"\0"):
            if not item:
                continue
            temporary, name = item.decode("utf8").split("\t", 1)
            temp_path = (ROOT / temporary).resolve()
            require(name in sources and name not in extracted and temp_path.parent == ROOT.resolve()
                    and temp_path.name.startswith(".merge_file_") and temp_path.is_file()
                    and sha(temp_path) == sources[name], "Git temporary checkout differs from complete source map")
            extracted[name] = temp_path
        require(set(extracted) == set(sources), "Git temporary checkout omitted/duplicated source")
        for name, temp_path in extracted.items():
            os.replace(temp_path, ROOT / name)
        after = {name: sha(ROOT / name) for name in sources}
        require(after == sources, "restored checkout still differs from complete compiled input map")
        save(out / "CHECKOUT-RECEIPT.json", {"head": expected_source, "before": before, "after_raw_sha256": after,
             "command": args, "returncode": result.returncode, "timeout_seconds": 30,
             "local_core_autocrlf": "false", "complete_raw_equality": True,
             "scope": "Actual Git-index LF restoration; canonical hashes are diagnostic only"})
    except Exception as error:
        save(out / "FAILURE.json", {"error": str(error), "partial_outputs_retained": True})
        raise


def verify_bundle(folder: Path, expected_source: str, target: str) -> dict:
    receipt, sources = bundle_inputs(folder, expected_source, target)
    for name, digest in sources.items():
        path = PurePosixPath(name)
        require(not path.is_absolute() and ".." not in path.parts and "\\" not in name
                and name == path.as_posix() and (ROOT / name).is_file()
                and sha(ROOT / name) == digest, "actual target checkout source mismatch: " + name)
    executable = folder / ("lcb_science.exe" if target == "windows" else "lcb_science")
    require(sha(executable) == receipt["exe_sha256"] and sha(folder / "compiler.bin") == receipt["compiler_sha256"], "bundle consumer/compiler mismatch")
    return {"status": "verified", "source": expected_source, "target": target,
            "compiler_inputs": len(sources), "consumer_sha256": receipt["exe_sha256"],
            "scope": "Exact file/source identities only; Windows does not execute the Linux compiler artifact"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path)
    parser.add_argument("--target", choices=["linux", "windows"], required=True)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--toolchain-root", type=Path)
    parser.add_argument("--toolchain-archive", type=Path)
    parser.add_argument("--verify-bundle", type=Path)
    parser.add_argument("--expected-source")
    parser.add_argument("--restore-compiled-checkout", type=Path)
    args = parser.parse_args()
    try:
        if args.verify_bundle is not None:
            require(args.expected_source is not None and args.compiler is None and args.out is None
                    and args.toolchain_root is None and args.toolchain_archive is None, "exclusive bundle verification arguments required")
            if args.restore_compiled_checkout is not None:
                restore_compiled_checkout(args.verify_bundle, args.expected_source, args.target, args.restore_compiled_checkout)
            print(json.dumps(verify_bundle(args.verify_bundle, args.expected_source, args.target)))
        else:
            require(args.compiler is not None and args.out is not None and args.expected_source is None
                    and args.restore_compiled_checkout is None, "build compiler/output required")
            build(args)
    except (ValueError, KeyError, OSError, subprocess.SubprocessError, tarfile.TarError) as error:
        print("LCB science build refused: " + str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
