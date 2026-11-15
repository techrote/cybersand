#!/usr/bin/env python3
"""WAVE-MT-001: run the source-matched complete-native-tick matrix.

Each row is a fresh process of build/wave_mt_matrix(.exe). Raw rows, including
failures, are appended to the output CSV unchanged; nothing is filtered.

    python tools/wave_mt/run_matrix.py --out results.csv \
        --sizes 1024 2048 --scenes dam wave idle sparse \
        --solvers 1:0 2:0 4:0 3:2 5:0 5:0:3 --workers 1 2 4 6 0 --repeats 2
"""
from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", default=str(ROOT / "build" / ("wave_mt_matrix.exe" if sys.platform == "win32" else "wave_mt_matrix")))
    parser.add_argument("--out", required=True)
    parser.add_argument("--sizes", nargs="+", type=int, default=[1024])
    parser.add_argument("--scenes", nargs="+", default=["dam"])
    parser.add_argument("--solvers", nargs="+", default=["1:0"], help="family:variant[:substeps]; family 5 is wave_flow_v1")
    parser.add_argument("--workers", nargs="+", type=int, default=[1, 4], help="0 = Auto")
    parser.add_argument("--repeats", type=int, default=2)
    parser.add_argument("--warm", type=int, default=30)
    parser.add_argument("--ticks", type=int, default=120)
    parser.add_argument("--idle-warm", type=int, default=240)
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()

    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    header = subprocess.run([args.exe, "--header"], capture_output=True, text=True, check=True).stdout
    with out.open("w", newline="") as handle:
        handle.write("repeat," + header)
        # Repeats are the outer loop so slow drift affects every case alike.
        for repeat in range(args.repeats):
            for size in args.sizes:
                for scene in args.scenes:
                    for solver in args.solvers:
                        family, variant, *rest = solver.split(":")
                        substeps = rest[0] if rest else "1"
                        for workers in args.workers:
                            warm = args.idle_warm if scene == "idle" else args.warm
                            command = [args.exe, str(size), scene, family, variant, str(workers), str(warm), str(args.ticks), substeps]
                            try:
                                done = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
                                row = done.stdout.strip()
                                if done.returncode != 0 or not row:
                                    row = f"{size},{scene},{family},{variant},{workers},FAILED rc={done.returncode} {done.stderr.strip()!r}"
                            except subprocess.TimeoutExpired:
                                row = f"{size},{scene},{family},{variant},{workers},TIMEOUT {args.timeout}s"
                            handle.write(f"{repeat},{row}\n")
                            handle.flush()
                            print(f"{repeat},{row}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
