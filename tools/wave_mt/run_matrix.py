#!/usr/bin/env python3
"""Run complete-native-tick rows, retaining failures and exact source identity.

Each row is a fresh benchmark process. The CSV has explicit status/error fields;
raw stdout/stderr and commands are retained in a sibling .runs.jsonl file, and
machine/source/executable identity in .metadata.json. Any failed, malformed or
incomplete row makes the process exit nonzero after completing the matrix.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import os
import pathlib
import platform
import subprocess
import sys
import time
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[2]


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def git(*arguments: str) -> str:
    result = subprocess.run(["git", "-C", str(ROOT), *arguments], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else "unavailable"


def source_identity() -> dict:
    # Digest the actual bytes, including an uncommitted local implementation.
    # Git HEAD alone must never label a dirty benchmark as an exact-HEAD run.
    paths = sorted({*ROOT.glob("native/include/cybersand/*"), *ROOT.glob("native/src/*"),
                    ROOT / "native/bench/wave_mt_matrix.cpp", ROOT / "Makefile",
                    ROOT / "tools/wave_mt/run_matrix.py"})
    files = {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
             for path in paths if path.is_file() and
             (path.name == "Makefile" or path.suffix in {".cpp", ".inc", ".hpp", ".h", ".py"})}
    digest = hashlib.sha256(json.dumps(files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"head": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
            "working_tree_status": git("status", "--porcelain", "--untracked-files=all"),
            "source_sha256": digest, "source_files": files}


def validate_row(fields: list[str], row: list[str], expected: dict[str, str]) -> dict[str, str]:
    if len(row) != len(fields):
        raise ValueError(f"expected {len(fields)} columns, received {len(row)}")
    values = dict(zip(fields, row))
    for key, wanted in expected.items():
        if values.get(key) != wanted:
            raise ValueError(f"{key}: expected {wanted!r}, received {values.get(key)!r}")
    for key in ("tick_p50_ms", "tick_p95_ms", "tick_max_ms", "native_ticks_per_s"):
        value = float(values[key])
        if not math.isfinite(value) or value < 0:
            raise ValueError(f"invalid {key}: {values[key]!r}")
    if not float(values["tick_p50_ms"]) <= float(values["tick_p95_ms"]) <= float(values["tick_max_ms"]):
        raise ValueError("unordered tick percentiles")
    configured, observed = int(values["workers_configured"]), int(values["workers_observed"])
    if configured < 1 or observed < 0 or observed > configured:
        raise ValueError("invalid worker participation")
    return values


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", default=str(ROOT / "build" / ("wave_mt_matrix.exe" if sys.platform == "win32" else "wave_mt_matrix")))
    parser.add_argument("--out", required=True)
    parser.add_argument("--sizes", nargs="+", type=int, default=[1024])
    parser.add_argument("--scenes", nargs="+", choices=["dam", "pool", "sparse", "wave", "idle"], default=["dam"])
    parser.add_argument("--solvers", nargs="+", default=["1:0"], help="family:variant[:substeps]; family 5 is wave_flow_v1")
    parser.add_argument("--workers", nargs="+", type=int, default=[1, 4], help="0 = Auto")
    parser.add_argument("--repeats", type=int, default=2)
    parser.add_argument("--warm", type=int, default=30)
    parser.add_argument("--ticks", type=int, default=120)
    parser.add_argument("--idle-warm", type=int, default=240)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--build-label", default="not supplied", help="Actual compiler/version/flags used for this executable")
    args = parser.parse_args()
    if (args.repeats < 1 or args.ticks < 1 or args.warm < 0 or args.idle_warm < 0 or args.timeout < 1
            or any(n < 128 or n > 2048 for n in args.sizes)
            or any(n < 0 or n > 256 for n in args.workers)):
        parser.error("invalid measurement window, size or worker count")
    solvers = []
    for solver in args.solvers:
        try:
            parts = [int(part) for part in solver.split(":")]
            if len(parts) not in (2, 3):
                raise ValueError()
            family, variant = parts[:2]
            substeps = parts[2] if len(parts) == 3 else 1
            if not (1 <= family <= 5 and 0 <= variant <= 2 and 1 <= substeps <= 8):
                raise ValueError()
            if (family != 3 and variant != 0) or (family != 5 and substeps != 1):
                raise ValueError()
        except ValueError:
            parser.error(f"invalid solver specifier: {solver}")
        solvers.append((str(family), str(variant), str(substeps)))

    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    executable = pathlib.Path(args.exe).resolve()
    header_result = subprocess.run([str(executable), "--header"], capture_output=True, text=True, timeout=args.timeout)
    if header_result.returncode != 0:
        raise RuntimeError(f"benchmark header failed: {header_result.stderr}")
    headers = list(csv.reader(io.StringIO(header_result.stdout)))
    required = {"size", "scene", "family", "variant", "workers_requested", "workers_configured",
                "workers_observed", "warm_ticks", "measured_ticks", "wave_substeps",
                "tick_p50_ms", "tick_p95_ms", "tick_max_ms", "native_ticks_per_s"}
    if len(headers) != 1 or not required.issubset(headers[0]) or len(set(headers[0])) != len(headers[0]):
        raise ValueError("benchmark returned an invalid CSV header")
    fields = headers[0]
    planned = args.repeats * len(args.sizes) * len(args.scenes) * len(solvers) * len(args.workers)
    metadata = {"schema": 1, "started_utc": utc(), "arguments": vars(args), "planned_rows": planned,
                "source": source_identity(), "executable": str(executable),
                "executable_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
                "machine": {"platform": platform.platform(), "machine": platform.machine(),
                            "processor": platform.processor(), "logical_cpus": os.cpu_count()},
                "method": "Fresh process per row; complete synchronous World::tick(); identical allocation instrumentation for all solvers; sources/edits outside timed ticks."}
    cpuinfo = pathlib.Path("/proc/cpuinfo")
    if cpuinfo.exists():
        for line in cpuinfo.read_text().splitlines():
            if line.startswith("model name"):
                metadata["machine"]["cpu_model"] = line.split(":", 1)[1].strip()
                break
    metadata_path = out.with_suffix(".metadata.json")
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n")
    failures, completed = 0, 0
    with out.open("w", newline="") as handle, out.with_suffix(".runs.jsonl").open("w") as raw:
        writer = csv.DictWriter(handle, fieldnames=["repeat", *fields, "status", "error"])
        writer.writeheader()
        handle.flush()
        # Repeats outermost allow machine drift to affect all cases alike.
        for repeat in range(args.repeats):
            for size in args.sizes:
                for scene in args.scenes:
                    for family, variant, substeps in solvers:
                        for workers in args.workers:
                            warm = args.idle_warm if scene == "idle" else args.warm
                            command = [str(executable), str(size), scene, family, variant, str(workers), str(warm), str(args.ticks), substeps]
                            expected = {"size": str(size), "scene": scene, "family": family, "variant": variant,
                                        "workers_requested": "auto" if workers == 0 else str(workers),
                                        "warm_ticks": str(warm), "measured_ticks": str(args.ticks), "wave_substeps": substeps}
                            record = {"repeat": repeat, "command": command, "started_utc": utc()}
                            values, status, error = expected.copy(), "PASS", ""
                            started = time.monotonic()
                            try:
                                done = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
                                record.update(returncode=done.returncode, stdout=done.stdout, stderr=done.stderr)
                                if done.returncode != 0:
                                    raise RuntimeError(f"exit {done.returncode}: {done.stderr.strip()}")
                                rows = list(csv.reader(io.StringIO(done.stdout)))
                                if len(rows) != 1:
                                    raise ValueError(f"expected one CSV row, received {len(rows)}")
                                values = validate_row(fields, rows[0], expected)
                            except subprocess.TimeoutExpired as timeout:
                                status, error = "TIMEOUT", f"exceeded {args.timeout}s"
                                record.update(stdout=(timeout.stdout or b"").decode(errors="replace") if isinstance(timeout.stdout, bytes) else timeout.stdout,
                                              stderr=(timeout.stderr or b"").decode(errors="replace") if isinstance(timeout.stderr, bytes) else timeout.stderr)
                            except (OSError, RuntimeError, ValueError, KeyError) as failure:
                                status, error = "FAIL", str(failure)
                            completed += 1
                            failures += status != "PASS"
                            record.update(status=status, error=error, wall_seconds=time.monotonic() - started)
                            raw.write(json.dumps(record) + "\n")
                            raw.flush()
                            writer.writerow({"repeat": repeat, **values, "status": status, "error": error})
                            handle.flush()
                            print(f"{completed}/{planned} {size} {scene} {family}:{variant}:{substeps} workers={workers} {status} {error}", flush=True)
    metadata.update(completed_utc=utc(), completed_rows=completed, failed_rows=failures)
    # If source moved during the campaign, it cannot be presented as one frozen
    # candidate even if the executable itself remained unchanged.
    final_source = source_identity()
    metadata["source_after"] = final_source
    source_changed = final_source["source_sha256"] != metadata["source"]["source_sha256"]
    metadata["source_changed_during_run"] = source_changed
    metadata["executable_sha256_after"] = hashlib.sha256(executable.read_bytes()).hexdigest()
    executable_changed = metadata["executable_sha256_after"] != metadata["executable_sha256"]
    metadata["executable_changed_during_run"] = executable_changed
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n")
    if source_changed:
        print("Source changed during the campaign; results require source-custody review.", file=sys.stderr)
    if executable_changed:
        print("Executable changed during the campaign; rows cannot share one build identity.", file=sys.stderr)
    return 1 if failures or source_changed or executable_changed else 0


if __name__ == "__main__":
    raise SystemExit(main())
