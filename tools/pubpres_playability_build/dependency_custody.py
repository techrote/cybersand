#!/usr/bin/env python3
"""Bind actual generated godot-cpp inputs and the retained dependency build."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess

FILES = ("GODOT-CPP-DEPENDENCY.json", "GODOT-CPP-BUILD.log", "GODOT-CPP-BUILD.sh", "GODOT-CPP-CXX.sh")
REVISION = "101ae38034304346a46ea9ea84ae156d3e860496"
REQUIRED = {"SConstruct", "binding_generator.py", "include/godot_cpp/core/class_db.hpp",
            "gen/include/godot_cpp/classes/node.hpp", "gen/include/gdextension_interface.h",
            "gdextension/gdextension_interface.json", "gdextension/extension_api-4-7.json",
            "src/core/class_db.cpp"}
DRIVER_FILES = ("build_runtime.py", "process_owner.py", "dependency_custody.py")


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(root, *arguments):
    return subprocess.check_output(["git", *arguments], cwd=root, text=True, timeout=120).strip()


def inputs(root):
    paths = [root / "SConstruct", root / "binding_generator.py"]
    suffixes = {".h", ".hpp", ".inc", ".inl", ".cpp", ".c", ".py", ".json"}
    paths += [p for name in ("include", "gen", "gdextension", "src", "tools")
              for p in (root / name).rglob("*") if p.is_file() and p.suffix in suffixes]
    result = {p.relative_to(root).as_posix(): digest(p) for p in sorted(set(paths))}
    if not REQUIRED <= set(result):
        raise ValueError("Incomplete actual godot-cpp generated/source input closure")
    return result


def capture(cpp_root, library, platform, output, driver_root):
    if git(cpp_root, "rev-parse", "HEAD") != REVISION:
        raise ValueError("Dependency source pin differs")
    git(cpp_root, "diff", "--exit-code", "HEAD", "--")
    build_script = driver_root / "tools/build_pinned_godot_cpp.sh"
    builder_inputs = {}
    for name in ("tools/build_pinned_godot_cpp.sh", "tools/toolchains/g++"):
        committed = subprocess.check_output(["git", "show", "HEAD:" + name], cwd=driver_root, timeout=120)
        if committed.replace(b"\r\n", b"\n") != (driver_root / name).read_bytes().replace(b"\r\n", b"\n"):
            raise ValueError("Dependency builder/helper differs from candidate source: " + name)
        builder_inputs[name] = digest(driver_root / name)
    log = Path(os.environ["PUBPRES_GODOT_CPP_BUILD_LOG"]).resolve()
    lines = log.read_text(encoding="utf-8", errors="strict").splitlines()
    commands = [line for line in lines if line.startswith(f"Pinned godot-cpp {platform} build command:")]
    if len(commands) != 1 or not lines or Path(lines[-1]).resolve() != library:
        raise ValueError("Dependency build log lacks its command and completed library")
    record = {"schema": "pubpres-godot-cpp-dependency-v1", "platform": platform,
              "source_commit": REVISION, "source_tree": git(cpp_root, "rev-parse", "HEAD^{tree}"),
              "source_inputs_sha256": inputs(cpp_root), "library_sha256": digest(library),
              "builder_commit": git(driver_root, "rev-parse", "HEAD"),
              "builder_inputs_sha256": builder_inputs,
              "build_script_sha256": digest(build_script), "build_log_sha256": digest(log),
              "command": commands[0], "configuration": {name: os.environ.get(name) for name in
                  ("SCONS_PYTHON", "SCONS_JOBS", "CYBERSAND_REAL_CXX", "LLVM_MINGW_ROOT",
                   "LINUX_CXX", "WINDOWS_CXX", "CYBERSAND_ALLOW_TOOLCHAIN_DRIFT")}}
    shutil.copyfile(log, output / FILES[1])
    shutil.copyfile(build_script, output / FILES[2])
    shutil.copyfile(driver_root / "tools/toolchains/g++", output / FILES[3])
    (output / FILES[0]).write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return record


def verify(directory, runtime):
    directory = Path(directory)
    if digest(directory / FILES[0]) != runtime.get("godot_cpp_dependency_sha256"):
        raise ValueError("Dependency custody receipt missing or changed")
    record = json.loads((directory / FILES[0]).read_text(encoding="utf-8"))
    if (record.get("schema") != "pubpres-godot-cpp-dependency-v1" or record.get("platform") != runtime["platform"]
            or record.get("source_commit") != runtime["godot_cpp_commit"] or record["source_commit"] != REVISION
            or record.get("library_sha256") != runtime["godot_cpp_library_sha256"]
            or not re.fullmatch(r"[0-9a-f]{40}", record.get("source_tree", ""))
            or not re.fullmatch(r"[0-9a-f]{40}", record.get("builder_commit", ""))
            or digest(directory / FILES[1]) != record.get("build_log_sha256")
            or digest(directory / FILES[2]) != record.get("build_script_sha256")
            or not record.get("command", "").startswith(f"Pinned godot-cpp {runtime['platform']} build command:")):
        raise ValueError("Dependency source, generated inputs or build identity differs")
    entries = record.get("source_inputs_sha256", {})
    if record.get("builder_inputs_sha256") != {
            "tools/build_pinned_godot_cpp.sh": digest(directory / FILES[2]),
            "tools/toolchains/g++": digest(directory / FILES[3])}:
        raise ValueError("Dependency builder/helper closure differs")
    if not REQUIRED <= set(entries):
        raise ValueError("Dependency closure omits required authored/generated inputs")
    for name, value in entries.items():
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or "\\" in name or not re.fullmatch(r"[0-9a-f]{64}", value):
            raise ValueError("Invalid dependency input identity")
    return record


def verify_driver(directory, runtime):
    actual = {name: hashlib.sha256((Path(directory) / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
              for name in DRIVER_FILES}
    if actual != runtime.get("driver_inputs_sha256") or actual["build_runtime.py"] != runtime["driver_sha256"]:
        raise ValueError("Native build driver module closure differs")
