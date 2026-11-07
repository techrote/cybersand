#!/usr/bin/env python3
"""GEN-006 real native cross-process persistence acceptance (opt-in prototype).

Three independent OS processes execute the compiled CyberSand native World.
No fake World, mocks, memory carry-over, or source changes between processes.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys

CELL = re.compile(
    r"CELL chunk=\((-?\d+),(-?\d+)\) local=\((\d+),(\d+)\)"
    r" material=(\d+) liquid=(\d+) temp=(-?\d+) intent=(\d+)"
)
CHUNK = re.compile(
    r"chunk=\((-?\d+),(-?\d+)\) gen=(\d+) physical_hash=(\d+) ticks=(\d+)"
)


def require(test: bool, why: str) -> None:
    if not test:
        raise AssertionError(why)


def run(executable: pathlib.Path, root: pathlib.Path, workers: int,
        label: str, commands: str, logdir: pathlib.Path) -> str:
    proc = subprocess.run(
        [str(executable), "--interactive", str(root), str(workers)],
        input=commands + "\nquit\n",
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        timeout=45,
        check=False,
    )
    (logdir / f"{label}.stdout.log").write_text(proc.stdout, encoding="utf-8")
    (logdir / f"{label}.stderr.log").write_text(proc.stderr, encoding="utf-8")
    require(proc.returncode == 0,
            f"{label} native process failed: {proc.returncode}\n{proc.stderr}")
    require("REFUSED " not in proc.stderr, f"{label} unexpected native refusal")
    require("SAVE_ALL resident=" in proc.stdout,
            f"{label} did not close and save native World")
    return proc.stdout


def cells(text: str, local_x: int, local_y: int) -> list[tuple[int, ...]]:
    return [
        tuple(map(int, result.groups()))
        for result in CELL.finditer(text)
        if result.group(1) == "-1" and result.group(2) == "-3"
        and int(result.group(3)) == local_x and int(result.group(4)) == local_y
    ]


def chunk_status(text: str) -> list[tuple[int, ...]]:
    return [
        tuple(map(int, m.groups())) for m in CHUNK.finditer(text)
        if m.group(1) == "-1" and m.group(2) == "-3"
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", required=True, type=pathlib.Path)
    parser.add_argument("--root", required=True, type=pathlib.Path)
    parser.add_argument("--workers", required=True, type=int, choices=[1, 4])
    parser.add_argument("--logs", required=True, type=pathlib.Path)
    args = parser.parse_args()
    executable = args.exe.resolve(strict=True)
    root = args.root.resolve()
    logs = args.logs.resolve()
    logs.mkdir(parents=True, exist_ok=True)
    require(not root.exists(), "GEN006_RESTART_REQUIRES_FRESH_ROOT")

    # A real World is generated, simulated, then edited. The blocked Water cell
    # is not stepped after the edit, so mass and temperature must be exact.
    initial = run(
        executable, root, args.workers, "01-create",
        "\n".join([
            "wall 18 31", "wall 17 30", "wall 19 30",
            "tick 2", "water 18 30 17", "dig 5 5",
            "inspect 18 30", "inspect 5 5", "status",
        ]), logs,
    )
    require("GENERATE x=-1 y=-3" in initial, "initial chunk not generated")
    water1 = cells(initial, 18, 30)
    tomb1 = cells(initial, 5, 5)
    hashes1 = chunk_status(initial)
    require(len(water1) == len(tomb1) == len(hashes1) == 1,
            "missing native phase-one material/state/World receipts")
    require(water1[0][5:] == (17, 417, 1),
            f"original Water17 temperature/edit intent incorrect: {water1}")
    require(tomb1[0][4] == 0 and tomb1[0][7] == 1,
            f"Empty tombstone did not persist in native World: {tomb1}")
    original_hash = hashes1[0][3]
    original_ticks = hashes1[0][4]

    # Different process and World instance: restore the actual CYPS record,
    # then exceed a two-shard budget, evict native World, return/reload it.
    resumed = run(
        executable, root, args.workers, "02-restart-evict-return",
        "\n".join([
            "inspect 18 30", "inspect 5 5", "status",
            "focus 0 -3", "focus 24 -3", "focus -1 -3",
            "inspect 18 30", "inspect 5 5", "status",
        ]), logs,
    )
    require("RELOAD x=-1 y=-3" in resumed, "process did not load native save")
    require("EVICT x=-1 y=-3" in resumed, "process did not evict native World")
    require("GENERATE x=24 y=-3" in resumed, "distant demand not generated")
    water2 = cells(resumed, 18, 30)
    tomb2 = cells(resumed, 5, 5)
    hashes2 = chunk_status(resumed)
    require(len(water2) == len(tomb2) == len(hashes2) == 2,
            "missing both before/after eviction native receipts")
    require(all(row == water1[0] for row in water2),
            f"cross-process native Water17 state drift: {water1} -> {water2}")
    require(all(row == tomb1[0] for row in tomb2),
            f"cross-process native Empty-intent state drift: {tomb1} -> {tomb2}")
    require(all(row[3] == original_hash and row[4] == original_ticks
                for row in hashes2),
            "cross-process native physical hash or tick index drift")

    # A third process must still see the latest synchronously saved record.
    third = run(
        executable, root, args.workers, "03-second-restart",
        "inspect 18 30\ninspect 5 5\nstatus", logs,
    )
    require("RELOAD x=-1 y=-3" in third, "third process failed native restore")
    require(cells(third, 18, 30) == water1 and
            cells(third, 5, 5) == tomb1,
            "native state changed after second process closed")
    require(chunk_status(third) == hashes1,
            "third process native physical hash/tick generation changed")
    print(f"GEN006_CROSS_PROCESS_RESTART_PASS configured_workers={args.workers}"
          f" process_count=3 resident_budget=2"
          f" water17=17 temperature417=417 explicit_empty=1"
          f" native_hash={original_hash} ticks={original_ticks}"
          f" evicted_and_reloaded=1 far_pixel_x=1536")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print("GEN006_CROSS_PROCESS_RESTART_FAIL", error, file=sys.stderr)
        sys.exit(1)
