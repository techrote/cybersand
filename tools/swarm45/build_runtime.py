#!/usr/bin/env python3
"""Build each platform's adapter, CLI, fixture and test binaries exactly once."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import runtime_custody as custody

ROOT = custody.ROOT
SIMULATION = ("world.cpp", "material_rules.cpp", "scheduler_geometry.cpp", "settled_world_discovery.cpp")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    custody.build_context()
    custody.require(os.environ.get("CYBERSAND_ALLOW_TOOLCHAIN_DRIFT", "0") == "0", "Qualification forbids compiler drift")
    before = custody.source()
    output, evidence = args.output.resolve(), args.evidence.resolve()
    custody.require(not output.exists() or not any(output.iterdir()), "Runtime destination must be empty")
    output.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=True)
    commands = []
    env = dict(os.environ, CYBERSAND_NATIVE_OUTPUT=str(output / custody.EXTENSIONS[args.platform]))

    def run(label: str, command: list[str], timeout: int = 1800) -> None:
        log = evidence / (label + ".log")
        started = time.monotonic()
        with log.open("w", encoding="utf-8") as stream:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
        commands.append({"label": label, "command": command, "returncode": process.returncode,
                         "wall_seconds": time.monotonic() - started, "log_sha256": custody.sha(log)})
        custody.write_json(evidence / "commands.json", commands)
        if process.returncode:
            print("\n".join(log.read_text(encoding="utf-8", errors="replace").splitlines()[-100:]), file=sys.stderr)
            raise RuntimeError("Build failed: " + label)

    cxx = os.environ.get("WINDOWS_CXX") if args.platform == "windows" else str(ROOT / "tools/toolchains/g++")
    custody.require(bool(cxx), "Target compiler must be explicit")
    run("godot-cpp", ["bash", "tools/build_pinned_godot_cpp.sh", args.platform])
    run("adapter", ["bash", "tools/build_native_extension_windows.sh" if args.platform == "windows" else "tools/build_native_extension.sh"])
    objects = output.parent / ("swarm45-" + args.platform + "-objects")
    make = ["make", "-C", "native/experiments/gentek_swarm", "-f", "Makefile.reciprocal", "-j2", "CXX=" + cxx]
    if args.platform == "linux":
        # This standalone process exchanges JSON/text with Godot, not C++
        # objects. Use the supported older libstdc++ string ABI for its complete
        # native/test/replay object set; the GDExtension ABI remains unchanged.
        make.append("CPPFLAGS=-D_GLIBCXX_USE_CXX11_ABI=0")
    options = ["MODE=-O2 -include cstdlib", "LDFLAGS=-static"] if args.platform == "windows" else ["MODE=-O2"]
    targets = ["tests", str(objects / "gentek_reciprocal")]
    if args.platform == "linux":
        targets.append(str(objects / "replay_swarm005_known"))
    run("reciprocal-strict", [*make, "BUILD=" + str(objects), *options, *targets])
    names = custody.names(args.platform)
    reciprocal_count = len(custody.RECIPROCAL_TESTS)
    for name in (names["cli"], *names["tests"][:reciprocal_count]):
        shutil.copyfile(objects / name, output / name)
    suffix = ["-static"] if args.platform == "windows" else []
    flags = [cxx, "-std=c++20", "-Wall", "-Wextra", "-Wpedantic", "-Wconversion", "-Wshadow", "-Inative/include"]
    run("fixture-strict", [*flags, "-Werror", "-O2", "-pthread", *suffix,
                           "native/tests/workbench_process_fixture.cpp", "-o", str(output / names["fixture"])])
    run("authoring-patch-strict", [*flags, "-Werror", "-fsyntax-only", "native/tests/test_workbench_authoring_patch.cpp"])
    simulation = ["native/src/" + name for name in SIMULATION]
    run("authoring-patch", [*flags, "-O2", "-g", "-pthread", *suffix, *simulation,
                            "native/tests/test_workbench_authoring_patch.cpp", "-o", str(output / names["tests"][-1])])
    if args.platform == "linux":
        shutil.copyfile(objects / "replay_swarm005_known", output / "replay_swarm005_known")
        sanitized = output / "sanitized"
        sanitized.mkdir()
        san_objects = output.parent / "swarm45-linux-sanitized-objects"
        run("reciprocal-sanitized", [*make, "BUILD=" + str(san_objects), "SANITIZE=1", "tests"])
        for name in names["tests"][:reciprocal_count]:
            shutil.copyfile(san_objects / name, sanitized / name)
        run("authoring-patch-sanitized", [*flags, "-O1", "-g", "-pthread", "-fno-omit-frame-pointer",
                                          "-fsanitize=address,undefined", *simulation,
                                          "native/tests/test_workbench_authoring_patch.cpp", "-o", str(sanitized / names["tests"][-1])])
    cpp = Path(os.environ["GODOT_CPP_ROOT"])
    library = cpp / "bin" / ("libgodot-cpp." + args.platform + ".template_debug.x86_64.a")
    compiler = subprocess.check_output([cxx, "--version"], text=True, timeout=30).strip()
    (output / "toolchain.txt").write_text("\n".join((
        "compiler_policy=pinned-hosted", "toolchain_drift=false", "source_commit=" + before["source_commit"],
        "godot_cpp_commit=" + custody.GODOT_CPP, "godot_cpp_archive_sha256=" + custody.sha(library),
        "native_definition_sha256=" + before["native_definition_sha256"], "scons=4.10.1",
        "reciprocal_flags=Makefile.reciprocal strict C++20 -Wall -Wextra -Wpedantic -Werror",
        "windows_compatibility=-include cstdlib; -static" if args.platform == "windows" else
        "reciprocal_cppflags=-D_GLIBCXX_USE_CXX11_ABI=0; extension ABI unchanged; native CLI ABI floor checked",
        "sanitizers=address,undefined; -fno-omit-frame-pointer" if args.platform == "linux" else "sanitizers=Linux qualification only",
        compiler, "")), encoding="utf-8")
    custody.require(before == custody.source(), "Source changed during runtime build")
    if args.platform == "linux":
        for name in custody.expected_files("linux") - {"toolchain.txt"}:
            (output / name).chmod(0o755)
    custody.create(output, args.platform)
    custody.write_json(evidence / "build.json", {"passed": True, "platform": args.platform, "source": before,
                                                "commands": commands, "runtime_manifest_sha256": custody.sha(output / custody.NAME)})


if __name__ == "__main__":
    main()
