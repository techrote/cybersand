"""Run an isolated six-worker waterwall comparison and reduce exact mass traces.

Example: python3 tools/wave_mt/waterwall_discharge.py build/wave_waterwall     /path/to/terrain-1024.bin /path/to/stamps.txt /tmp/discharge
"""
import argparse
import csv
import hashlib
import re
import statistics
import subprocess
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("binary", "terrain", "stamps", "output"):
        parser.add_argument(key, type=Path)
    parser.add_argument("--ticks", type=int, default=1500)
    parser.add_argument("--bundle", nargs="*", default=[], help="key=value settings for the recommended bundle")
    args = parser.parse_args()
    if digest(args.terrain) != "9b8b4ef6339c4d922c499dd3240198209a8a3cfcca9f9fd49cf1b6fa918f91f5":
        parser.error("Terrain differs from the saved map")
    rows = args.stamps.read_bytes().replace(b"\r\n", b"\n").splitlines()
    if len(rows) != 166 or digest(args.stamps) != "c2dee3e3562b1369fdab0f3874716539704e5eae5a29951f262a0efc599b2a4e":
        parser.error("Expected the 166 saved stamps used for the comparison")
    options = {
        "original": ["spill=0", "ballistic=0"],
        "hybrid": [], "draw128": ["stream_draw=128"],
        "sheet": ["sheet_rate=64"], "coyote": ["coyote_ticks=4"],
        "bundle": args.bundle,
    }
    if args.bundle:
        sloshy = ["gain=32", "deep_gain=16", "flux_smoothing=16", "damp_shift=16", "coast=64",
                  "level_shift=3", "calm_damp_shift=8", "calm=128", "stick=128", "sleep_after=90"]
        options.update(bundle_nograce=[*args.bundle, "coyote_ticks=0"],
                       feed_only=[*args.bundle, "coyote_ticks=0", "sheet_rate=0"],
                       combined=[*args.bundle, *sloshy],
                       two_rounds=[*args.bundle, "substeps=2"])
    out = args.output
    out.mkdir(parents=True, exist_ok=False)
    with (out / "summary.csv").open("w", newline="") as f:
        fields = ("scene", "mode", "peak_net_units", "mean_first300", "half_tick",
                  "grid_cells_t900", "mean_dry_rows_60_300", "mean_air_only_rows_60_300",
                  "worst_gap_60_300", "launched_units", "max_live", "launch_refusals",
                  "launch_deferrals", "launch_capacity_skips", "overall_median_us", "p95_us")
        writer = csv.DictWriter(f, fields)
        writer.writeheader()
        for scene, source, stream in (("map", "440,540,192,102", "627,644,24,24"),
                                      ("falls", "0,0,220,200", "220,204,24,24")):
            for name, opts in options.items():
                if name == "bundle" and not opts:
                    continue
                prefix = f"{scene}-{name}"
                command = [str(args.binary.resolve()), scene, f"terrain={args.terrain.resolve()}",
                           f"stamps={args.stamps.resolve()}", f"ticks={args.ticks}", "every=300",
                           "workers=6", "spill=1", "ballistic=1", f"probe0={source}", *opts]
                # Timing has its own process and does no per-tick tracing.
                def run(extra, suffix):
                    result = subprocess.run(command + extra, encoding="utf-8", stdout=subprocess.PIPE,
                                            stderr=subprocess.STDOUT, timeout=600, check=True)
                    (out / (prefix + suffix)).write_text(result.stdout)
                    if any(int(m) for m in re.findall(r"^\d+,(-?\d+),", result.stdout, re.M)):
                        raise RuntimeError(f"Water drift: {prefix}")
                    return result.stdout
                timing = run([], "-timing.txt")
                trace = out / (prefix + ".csv")
                run([f"hydrograph={trace}", f"source_box={source}", f"stream_box={stream}"], "-trace.txt")
                with trace.open() as handle:
                    data = [{k: int(v) for k, v in row.items()} for row in csv.DictReader(handle)]
                net = [r["net_out_units"] for r in data]
                window = data[60:301]
                half = next((r["tick"] for r in data if 2*(r["source_grid_units"]+r["source_flight_units"])
                             <= data[0]["source_grid_units"]), "")
                result = dict(scene=scene, mode=name, peak_net_units=max(net), half_tick=half,
                              mean_first300=round(statistics.mean(net[1:301]), 1),
                              grid_cells_t900=round(data[900]["source_grid_units"]/255, 1) if len(data)>900 else "",
                              mean_dry_rows_60_300=round(statistics.mean(r["grid_dry_rows"] for r in window), 2),
                              mean_air_only_rows_60_300=round(statistics.mean(r["air_only_rows"] for r in window), 2),
                              worst_gap_60_300=max(r["max_grid_gap"] for r in window))
                result.update({key: int(re.search(r"\b"+key+r"=(\d+)", timing)[1])
                               for key in fields if key not in result})
                writer.writerow(result)
                f.flush()
                print(prefix, result, flush=True)


if __name__ == "__main__":
    main()
