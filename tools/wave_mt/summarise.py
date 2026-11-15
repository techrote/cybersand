#!/usr/bin/env python3
"""WAVE-MT-001: summarise run_matrix.py CSVs as Markdown tables.

    python tools/wave_mt/summarise.py existing.csv wave.csv

Each cell is the median over repeats of the per-run value. Failed or timed-out
rows are listed separately and never dropped silently.
"""
from __future__ import annotations

import csv
import statistics
import sys
from collections import defaultdict

NAMES = {"1:0": "FreeMass", "2:0": "Cellular Yield", "4:0": "Inertial", "3:2": "Pressure cached+dormant",
         "5:0": "wave_flow_v1"}


def main() -> int:
    rows, failures = [], []
    for path in sys.argv[1:]:
        with open(path, newline="") as handle:
            reader = csv.reader(handle)
            header = next(reader)
            for line in reader:
                if len(line) < len(header) or not line[10].replace(".", "", 1).isdigit():
                    failures.append((path, ",".join(line)))
                    continue
                rows.append(dict(zip(header, line)))

    groups: dict[tuple, list[dict]] = defaultdict(list)
    for row in rows:
        solver = f"{row['family']}:{row['variant']}"
        substeps = row.get("wave_substeps", "1") or "1"
        name = NAMES.get(solver, solver) + (f" ×{substeps}" if solver == "5:0" and substeps != "1" else "")
        groups[(int(row["size"]), row["scene"], name, row["workers_requested"])].append(row)

    def median(items: list[dict], key: str) -> float:
        return statistics.median(float(item[key]) for item in items)

    sizes = sorted({key[0] for key in groups})
    scenes = ["dam", "wave", "sparse", "idle"]
    for size in sizes:
        for scene in scenes:
            keys = [key for key in groups if key[0] == size and key[1] == scene]
            if not keys:
                continue
            print(f"\n**{size}² {scene}** — median of {max(len(groups[k]) for k in keys)} runs\n")
            print("| Solver | Workers (observed) | Tick p50 ms | Tick p95 ms | Native ticks/s | Scheduled cores | Peak RSS MB |")
            print("|---|---:|---:|---:|---:|---:|---:|")
            order = {"1": 0, "2": 1, "4": 2, "6": 3, "auto": 4}
            for key in sorted(keys, key=lambda k: (k[2], order.get(k[3], 9))):
                items = groups[key]
                observed = max(int(item["workers_observed"]) for item in items)
                print(f"| {key[2]} | {key[3]} ({observed}) | {median(items, 'tick_p50_ms'):.2f} | "
                      f"{median(items, 'tick_p95_ms'):.2f} | {median(items, 'native_ticks_per_s'):.1f} | "
                      f"{median(items, 'scheduled_cores_per_tick'):.0f} | {median(items, 'peak_rss_bytes') / 1048576:.0f} |")
    if failures:
        print("\n**Failed or incomplete rows**\n")
        for path, line in failures:
            print(f"- `{path}`: `{line}`")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
