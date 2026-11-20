#!/usr/bin/env python3
"""Summarise benchmark CSVs without combining different campaigns or hiding failures.

Each input is reported separately, with its source/machine metadata when present.
Each table cell is the median over repeats of a per-process measurement. Failed,
incomplete and non-finite rows are listed explicitly and yield a nonzero exit.
"""
from __future__ import annotations

import csv
import json
import math
import pathlib
import statistics
import sys
from collections import defaultdict

NAMES = {"1:0": "FreeMass", "2:0": "Cellular Yield", "4:0": "Inertial", "3:0": "Pressure reference",
         "3:1": "Pressure cached", "3:2": "Pressure cached+dormant", "5:0": "wave_flow_v1"}


def main() -> int:
    failed = False
    for filename in sys.argv[1:]:
        path = pathlib.Path(filename)
        rows, failures = [], []
        with path.open(newline="") as handle:
            reader = csv.DictReader(handle)
            for row in reader:
                try:
                    if None in row or any(value is None for value in row.values()):
                        raise ValueError("incomplete/overlong CSV row")
                    if row.get("status", "PASS") != "PASS":
                        raise ValueError(f"{row['status']}: {row.get('error', '')}")
                    for key in ("size", "tick_p50_ms", "tick_p95_ms", "native_ticks_per_s", "peak_rss_bytes"):
                        number = float(row[key])
                        if not math.isfinite(number) or number < 0:
                            raise ValueError(f"invalid {key}")
                    rows.append(row)
                except (ValueError, TypeError, KeyError) as error:
                    failures.append((row, str(error)))
        print(f"\n## {path.name}\n")
        metadata_path = path.with_suffix(".metadata.json")
        if metadata_path.exists():
            metadata = json.loads(metadata_path.read_text())
            source, machine = metadata["source"], metadata["machine"]
            dirty = " with recorded local changes" if source["working_tree_status"] else " (clean checkout)"
            print(f"Source `{source['head']}`{dirty}; native source digest `{source['source_sha256']}`.")
            print(f"\n{machine['platform']}; {machine.get('cpu_model') or machine.get('processor') or machine['machine']}; "
                  f"{machine['logical_cpus']} logical CPUs. Build: {metadata['arguments']['build_label']}.")
            retained_count = len(rows) + len(failures)
            if (metadata.get("completed_rows") != metadata.get("planned_rows") or
                    metadata.get("completed_rows") != retained_count or
                    metadata.get("failed_rows") != len(failures)):
                print("\n**Campaign coverage is incomplete or disagrees with its retained CSV.**")
                failed = True
            if metadata.get("source_changed_during_run"):
                print("\n**Source changed during this campaign; source custody needs review.**")
                failed = True
            if metadata.get("executable_changed_during_run"):
                print("\n**Executable changed during this campaign; build custody needs review.**")
                failed = True
        else:
            print("Source and machine metadata were not supplied with this historical CSV.")

        groups: dict[tuple, list[dict]] = defaultdict(list)
        for row in rows:
            solver = f"{row['family']}:{row['variant']}"
            substeps = row.get("wave_substeps", "1") or "1"
            name = NAMES.get(solver, solver) + (f" ×{substeps}" if solver == "5:0" and substeps != "1" else "")
            # A measurement-window change is a separate comparison group.
            groups[(int(row["size"]), row["scene"], row["warm_ticks"], row["measured_ticks"], name,
                    row["workers_requested"])].append(row)

        def median(items: list[dict], key: str) -> float:
            return statistics.median(float(item[key]) for item in items)

        panels = sorted({key[:4] for key in groups})
        for size, scene, warm, ticks in panels:
            keys = [key for key in groups if key[:4] == (size, scene, warm, ticks)]
            print(f"\n**{size}² {scene}** — {warm} warm-up and {ticks} measured ticks per process\n")
            print("| Solver | Workers (observed) | Repeats | Tick p50 ms | Tick p95 ms | Native ticks/s | Peak RSS MiB |")
            print("|---|---:|---:|---:|---:|---:|---:|")
            order = {"1": 0, "2": 1, "4": 2, "6": 3, "auto": 4}
            for key in sorted(keys, key=lambda k: (k[4], order.get(k[5], 9))):
                items = groups[key]
                observed = max(int(item["workers_observed"]) for item in items)
                print(f"| {key[4]} | {key[5]} ({observed}) | {len(items)} | {median(items, 'tick_p50_ms'):.3f} | "
                      f"{median(items, 'tick_p95_ms'):.3f} | {median(items, 'native_ticks_per_s'):.1f} | "
                      f"{median(items, 'peak_rss_bytes') / 1048576:.1f} |")
            measured = [key for key in keys if "tick_allocations_total" in groups[key][0]]
            if measured:
                print("\n| Solver | Workers | Allocations/tick | Requested bytes/tick | Wave storage MiB | Solved chunks/tick |\n"
                      "|---|---:|---:|---:|---:|---:|")
                for key in sorted(measured, key=lambda k: (k[4], order.get(k[5], 9))):
                    items = groups[key]
                    print(f"| {key[4]} | {key[5]} | {median(items, 'tick_allocations_total') / int(ticks):.3f} | "
                          f"{median(items, 'tick_allocated_bytes_total') / int(ticks):.1f} | "
                          f"{median(items, 'wave_storage_bytes') / 1048576:.2f} | "
                          f"{median(items, 'wave_solved_chunks_per_tick'):.2f} |")
        if failures:
            failed = True
            print("\n**Failed or incomplete rows**\n")
            for row, error in failures:
                print(f"- {error}: `{json.dumps(row, sort_keys=True)}`")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
