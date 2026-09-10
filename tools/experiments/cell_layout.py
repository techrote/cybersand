"""Issue 16 L1: isolated preparation, explicit timing hold, retained pair evidence."""
from __future__ import annotations
import argparse
import csv
import gzip
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import statistics
import struct
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = Path("C:/kybersand")
OUT = ROOT / "validation/local/issue-16"
BUILD = ROOT / "build/issue-16"
SEEDS = [(0, 0, 0), (1, -129, -65), (2, 127, 63), (3, -257, 129), (4, 65, -129)]
CORE = [f"native/src/{s}.cpp" for s in ("world", "material_rules", "scheduler_geometry", "render_snapshot", "c_api")]


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def environment():
    # Reuse exact configured tools, never call dev.main()/dev.run() whose default
    # cwd/output paths refer to the shared baseline checkout.
    spec = importlib.util.spec_from_file_location("workspace_dev", WORKSPACE / "tools/dev.py")
    dev = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dev)
    return dev.ENV, dev.LLVM / "bin/clang++.exe"


def identity():
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()
    files = sorted([*ROOT.glob("native/src/*"), *ROOT.glob("native/include/cybersand/*"),
                    ROOT / "native/bench/cell_layout.cpp", ROOT / "native/tests/test_world.cpp",
                    Path(__file__), ROOT / "docs/operations/cell-layout-experiment.md"])
    return dict(head=git("rev-parse", "HEAD"), branch=git("branch", "--show-current"),
                status=git("status", "--short"), files={str(p.relative_to(ROOT)): digest(p) for p in files if p.is_file()})


def execute(name, command, directory, env, timeout=1800):
    command = list(map(str, command))
    log = directory / (name + ".log")
    print(name, flush=True)
    metadata = dict(command=command, cwd=str(ROOT), timeout_seconds=timeout)
    with log.open("w", encoding="utf-8") as stream:
        try:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=timeout)
            metadata["exit_code"] = result.returncode
        except subprocess.TimeoutExpired:
            metadata["exit_code"] = 124
            write(directory / (name + ".execution.json"), metadata)
            raise
    write(directory / (name + ".execution.json"), metadata)
    if result.returncode:
        raise RuntimeError(f"{name} failed: {log}")
    return log


def equal_files(left, right):
    with left.open("rb") as a, right.open("rb") as b:
        while True:
            x, y = a.read(1024 * 1024), b.read(1024 * 1024)
            if x != y:
                raise RuntimeError(f"Exact comparison failed: {left} / {right}")
            if not x:
                return


def without_events(path):
    """Parse every frame losslessly; omit only diagnostic entries for off/on checks."""
    with path.open("rb") as stream:
        while size := stream.read(8):
            if len(size) != 8:
                raise ValueError("truncated frame")
            count = struct.unpack("<Q", size)[0]
            cells = stream.read(count)
            work = stream.read(16 * 8)  # 15 TickStats integers plus state_hash
            entries = stream.read(8)
            if len(cells) != count or len(work) != 128 or len(entries) != 8:
                raise ValueError("truncated record")
            event_bytes = struct.unpack("<Q", entries)[0] * 16
            if len(stream.read(event_bytes)) != event_bytes:
                raise ValueError("truncated events")
            yield size + cells + work


def compress(path):
    # Raw generated record, retained losslessly; never affects source or another run.
    import shutil
    target = path.with_suffix(path.suffix + ".gz")
    with path.open("rb") as source, gzip.open(target, "wb", compresslevel=1) as dest:
        shutil.copyfileobj(source, dest)
    path.unlink()


def prepare():
    env, cxx = environment()
    directory = OUT / ("prepare-" + time.strftime("%Y%m%d-%H%M%S"))
    directory.mkdir(parents=True, exist_ok=False)
    BUILD.mkdir(parents=True, exist_ok=True)
    write(directory / "source-before.json", identity())
    execute("compiler", [cxx, "--version"], directory, env)
    common = [cxx, "-std=c++20", "-Wall", "-Wextra", "-Wpedantic", "-Wconversion", "-Wshadow",
              "-pthread", "-static", "-Inative/include"]
    artifacts = {}
    for width in (4, 8):
        variant_dir = BUILD / directory.name / str(width)
        variant_dir.mkdir(parents=True, exist_ok=False)
        define = f"-DCYBERSAND_CELL_LAYOUT_EXPERIMENT={width}"
        exe, tests = variant_dir / "cell_layout.exe", variant_dir / "tests.exe"
        execute(f"build-{width}", [*common, "-O3", "-DNDEBUG", "-flto", define,
                *CORE, "native/bench/cell_layout.cpp", "-lpsapi", "-o", exe], directory, env, 1200)
        # Control suite uses truly unselected production source; candidate suite padded.
        execute(f"build-tests-{width}", [*common, "-O0", "-g3", *([define] if width == 8 else []),
                *CORE, "native/tests/test_world.cpp", "-o", tests], directory, env, 1200)
        execute(f"native-tests-{width}", [tests], directory, env, 1800)
        assembly = variant_dir / "world.s"
        execute(f"assembly-{width}", [*common, "-O3", "-DNDEBUG", define, "-S",
                "native/src/world.cpp", "-o", assembly], directory, env, 1200)
        artifacts[str(width)] = dict(exe=str(exe), sha256=digest(exe), tests=str(tests),
                                    tests_sha256=digest(tests), assembly=str(assembly))
    execute("c-header", [cxx.parent / "clang.exe", "-std=c11", "-Wall", "-Wextra", "-Wpedantic",
                          "-Inative/include", "-fsyntax-only", "native/tests/test_c_header.c"], directory, env, 120)
    comparisons = []
    for seed, x, y in SEEDS:
        reference = None
        current = []
        for width in (4, 8):
            for workers in (1, 4):
                for repeat in (0, 1):
                    name = f"behavior-{seed}-{width}-{workers}-{repeat}"
                    prefix = directory / name
                    execute(name, [artifacts[str(width)]["exe"], "correctness", "behavior", 512,
                                  workers, 1800, seed, x, y, 1, prefix], directory, env)
                    record = prefix.with_suffix(".records")
                    if reference is None:
                        reference = record
                    else:
                        equal_files(reference, record)
                    comparisons.append(dict(case=name, exact_bytes=record.stat().st_size, sha256=digest(record)))
                    current.append(record)
        # Observer-off check includes identical full cells/work/state, omits only events.
        if seed == 0:
            import itertools
            for width in (4, 8):
                for workers in (1, 4):
                    name = f"observer-off-{width}-{workers}"
                    prefix = directory / name
                    execute(name, [artifacts[str(width)]["exe"], "correctness", "behavior", 512,
                                  workers, 1800, seed, x, y, 0, prefix], directory, env)
                    record = prefix.with_suffix(".records")
                    for a, b in itertools.zip_longest(without_events(reference), without_events(record)):
                        if a != b:
                            raise RuntimeError("observer-off semantic/work mismatch")
                    comparisons.append(dict(case=name, observer_neutral=True, sha256=digest(record)))
                    current.append(record)
        for record in current:
            compress(record)
        print(f"seed {seed}: exact layout/worker/repeat parity", flush=True)
    write(directory / "comparisons.json", comparisons)
    manifest = dict(stage="L1-prepared", performance_measured=False, source=identity(),
                    artifacts=artifacts, comparisons=str(directory / "comparisons.json"),
                    toolchain=dict(compiler=str(cxx), sha256=digest(cxx)), output=str(directory))
    write(directory / "prepared.json", manifest)
    print(f"READY, performance hold remains: {directory / 'prepared.json'}", flush=True)


def plan(manifest_path):
    manifest = json.loads(manifest_path.read_text())
    rows = []
    cases = [(n, e, w) for n in ("dense", "sparse") for e in (512, 1024) for w in (1, 4)]
    cases += [("sleeping", 4096, w) for w in (1, 4)]
    for name, extent, workers in cases:
        for pair in range(7):
            for width in ((4, 8) if pair % 2 == 0 else (8, 4)):
                rows.append(dict(comparison="width", fixture=name, extent=extent, workers=workers,
                                 pair=pair, width=width, observer=0, ticks=1920))
    # Representative neutrality screen, declared separately from all width pairs.
    for width in (4, 8):
        for workers in (1, 4):
            for pair in range(7):
                for observer in ((0, 1) if pair % 2 == 0 else (1, 0)):
                    rows.append(dict(comparison="observer", fixture="sparse", extent=1024, workers=workers,
                                     pair=pair, width=width, observer=observer, ticks=1920))
    return manifest, rows


def measure(manifest_path, owner_released):
    if not owner_released:
        raise RuntimeError("Owner hold: arrange an uncontended run before --owner-released")
    manifest, rows = plan(manifest_path)
    if manifest["source"]["files"] != identity()["files"]:
        raise RuntimeError("source changed after preparation; rebuild/revalidate first")
    for value in manifest["artifacts"].values():
        if digest(value["exe"]) != value["sha256"]:
            raise RuntimeError("prepared binary changed")
    env, cxx = environment()
    if digest(cxx) != manifest["toolchain"]["sha256"]:
        raise RuntimeError("compiler changed")
    directory = OUT / ("timing-" + time.strftime("%Y%m%d-%H%M%S"))
    directory.mkdir(parents=True, exist_ok=False)
    write(directory / "plan.json", rows)
    write(directory / "identity.json", manifest)
    results, pairs = [], {}
    for index, row in enumerate(rows):
        prefix = directory / f"{index:03d}"
        log = execute(prefix.name, [manifest["artifacts"][str(row["width"])]["exe"], "timing",
                      row["fixture"], row["extent"], row["workers"], row["ticks"], 0, 0, 0,
                      row["observer"], prefix], directory, env)
        with prefix.with_suffix(".ticks.csv").open() as stream:
            ticks = list(csv.DictReader(stream))
        def summarize(part):
            ns = sorted(int(t["ns"]) for t in part)
            visited = sum(int(t["visited"]) for t in part)
            return dict(**{f"p{p}": ns[math.ceil(len(ns)*p/100)-1] for p in (50,95,99)},
                        maximum=max(ns), total=sum(ns), visited=visited,
                        ns_per_visited=sum(ns)/visited if visited else None)
        result = dict(**row, prefix=str(prefix), startup_and_memory=json.loads(log.read_text()),
                      warmup=summarize(ticks[:120]), steady=summarize(ticks[120:]))
        results.append(result)
        if row["comparison"] == "width":
            key = (row["fixture"],row["extent"],row["workers"],row["pair"])
            if key in pairs:
                other = pairs[key]
                equal_files(Path(other["prefix"]).with_suffix(".records"), prefix.with_suffix(".records"))
                control, candidate = (other,result) if row["width"] == 8 else (result,other)
                result["paired_p95_ratio"] = candidate["steady"]["p95"]/control["steady"]["p95"]
                result["review_gt_15_percent"] = result["paired_p95_ratio"] > 1.15
            else:
                pairs[key] = result
        write(directory / "results.json", results) # Partial results survive failure.
    print(f"L1 timing complete; review before L2: {directory}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("prepare", "plan", "measure"))
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--owner-released", action="store_true")
    args = parser.parse_args()
    if ROOT.parent != WORKSPACE / "worktrees" or ROOT.name != "issue-16-cell-layout":
        raise RuntimeError("This driver is restricted to the issue16 worktree")
    if args.action == "prepare":
        prepare()
    elif args.manifest is None:
        parser.error("--manifest is required")
    elif args.action == "plan":
        _, rows = plan(args.manifest)
        target = args.manifest.parent / "timing-plan.json"
        write(target, rows)
        print(f"{len(rows)} processes planned; none executed: {target}")
    else:
        measure(args.manifest, args.owner_released)


if __name__ == "__main__":
    main()
