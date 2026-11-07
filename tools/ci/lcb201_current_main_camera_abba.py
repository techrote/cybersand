#!/usr/bin/env python3
"""Exact-current-main LCB201 camera-only native B-C-C-B screen (no production edits).

Runs independent baseline and two-line camera invalidation deletion builds.
Outputs complete source/runtime hashes, 1-worker PressureFlow camera and
FreeMass/IN/gas-free negative-control counters. This is an exploratory
native qualification, not full #405, Godot or final performance acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

COLD = ("    if (pressure_ != nullptr && pressure_->cache != nullptr && selected_core_region_ != previous_selected)\n"
        "        pressure_->cache->cold();\n")
SOURCES = ("native/src/material_rules.cpp", "native/src/scheduler_geometry.cpp",
           "native/src/settled_world_discovery.cpp")
CASES = [("camera", "quiet"), ("surge", "freemass"), ("surge", "inertial"),
         ("surge", "pressure_dormant_nogas")]
ORDER = ("base", "camera", "camera", "base")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run(argv, cwd, env=None, timeout=1800):
    result = subprocess.run(argv, cwd=cwd, env=env, text=True,
                            capture_output=True, timeout=timeout, check=False)
    if result.returncode:
        raise RuntimeError(f"{argv}: exit={result.returncode}\n"
                           f"stdout={result.stdout[-3000:]}\n"
                           f"stderr={result.stderr[-3000:]}")
    return result


def instrument(kind, text):
    if text.count("std::fflush(stdout);") != 1:
        raise ValueError(f"{kind}: unsupported benchmark source")
    if kind == "camera":
        target = "for (const int speed : {0, 1, 4, 16, 64})"
        if text.count(target) != 1:
            raise ValueError("moving camera fixture changed")
        text = text.replace(target, "for (const int speed : {0, 16})")
        receipt = ('std::fprintf(stderr, "LCB201_CHECK speed=%d arm=%d eq=%llu water=%llu\\n", '
                   'speed, arm, static_cast<unsigned long long>(a.world->liquid_comparison_hash('
                   'LiquidStateProjection::PressureVariantEquivalenceV1)), '
                   'static_cast<unsigned long long>(a.world->water_quantity({0, 0, 1024, 1024})));')
    else:
        receipt = ('std::fprintf(stderr, "WCX_CHECK arm=%s hash=%llu water=%llu\\n", '
                   'arm.name, static_cast<unsigned long long>(world.physical_state_hash()), '
                   'static_cast<unsigned long long>(world.water_quantity({0, 0, W, H})));')
    return text.replace("std::fflush(stdout);", "std::fflush(stdout);\n            " + receipt)


def receipts(kind, stderr):
    result = {}
    for line in stderr.splitlines():
        if kind == "camera" and line.startswith("LCB201_CHECK "):
            match = re.fullmatch(r"LCB201_CHECK speed=(\d+) arm=(\d+) eq=(\d+) water=(\d+)", line)
            if match is None:
                raise ValueError("bad camera receipt: " + line)
            key = f"{match[1]}:{match[2]}"
            value = (int(match[3]), int(match[4]))
        elif kind == "surge" and line.startswith("WCX_CHECK "):
            match = re.fullmatch(r"WCX_CHECK arm=(\w+) hash=(\d+) water=(\d+)", line)
            if match is None:
                raise ValueError("bad surge receipt: " + line)
            key = match[1]
            value = (int(match[2]), int(match[3]))
        else:
            continue
        if key in result:
            raise ValueError("duplicate receipt " + key)
        result[key] = value
    if kind == "camera" and set(result) != {f"{s}:{a}" for s in (0, 16) for a in range(3)}:
        raise ValueError("missing camera variant receipts")
    if kind == "surge" and len(result) != 1:
        raise ValueError("missing surge receipt")
    return result


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("--main-worktree", required=True, type=Path)
    cli.add_argument("--output", required=True, type=Path)
    args = cli.parse_args()
    root = Path(__file__).resolve().parents[2]
    base = args.main_worktree.resolve()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    base_sha = run(["git", "rev-parse", "HEAD"], base).stdout.strip()
    trial_sha = run(["git", "rev-parse", "HEAD"], root).stdout.strip()
    original = (base / "native/src/world.cpp").read_text()
    if original.count(COLD) != 1:
        raise ValueError("current-main region cold() expression changed; no patch allowed")
    changed = original.replace(COLD, "", 1)
    (out / "camera_world.cpp").write_text(changed)
    benchmark = {
        "camera": instrument("camera", (root / "native/bench/lcb201_moving_camera.cpp").read_text()),
        "surge": instrument("surge", (base / "native/bench/wcx_surge_assessment.cpp").read_text()),
    }
    for kind, content in benchmark.items():
        (out / f"{kind}_instrumented.cpp").write_text(content)
    hashes = {"main_sha": base_sha, "benchmark_branch_sha": trial_sha,
              "main_world_sha256": digest(original.encode()),
              "camera_only_world_sha256": digest(changed.encode()),
              "camera_benchmark_sha256": digest(benchmark["camera"].encode()),
              "surge_benchmark_sha256": digest(benchmark["surge"].encode())}
    (out / "source.json").write_text(json.dumps(hashes, indent=2) + "\n")
    compiler = run(["g++-13", "--version"], root).stdout.splitlines()[0]
    binaries = {}
    for variant, world in (("base", base / "native/src/world.cpp"),
                           ("camera", out / "camera_world.cpp")):
        binaries[variant] = {}
        for kind in ("camera", "surge"):
            binary = out / f"{variant}-{kind}"
            cmd = ["g++-13", "-std=c++20", "-O2", "-DNDEBUG",
                   "-I" + str(base / "native/include"), "-I" + str(base / "native/src"),
                   str(world), *(str(base / item) for item in SOURCES),
                   str(out / f"{kind}_instrumented.cpp"), "-pthread", "-o", str(binary)]
            run(cmd, root, timeout=900)
            binaries[variant][kind] = binary
            hashes[f"{variant}-{kind}_exe_sha256"] = digest(binary.read_bytes())
    log = []
    first_receipts = {}
    for phase, variant in enumerate(ORDER):
        for kind, name in CASES:
            env = os.environ.copy()
            if kind == "surge":
                env["WCX_SURGE_ARM"] = name
                argv = [str(binaries[variant][kind]), "96", "1"]
            else:
                argv = [str(binaries[variant][kind]), "48", "1", "quiet"]
            start = time.monotonic()
            proc = run(argv, root, env)
            seconds = time.monotonic() - start
            prefix = f"{phase}-{variant}-{kind}-{name}"
            (out / f"{prefix}.jsonl").write_text(proc.stdout)
            (out / f"{prefix}.stderr").write_text(proc.stderr)
            rows = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
            seen = receipts(kind, proc.stderr)
            if len(rows) != (6 if kind == "camera" else 1):
                raise ValueError(f"{prefix}: wrong row count {len(rows)}")
            key = kind + "-" + name
            if key in first_receipts and seen != first_receipts[key]:
                raise ValueError(f"{prefix}: physical/equivalence hash or Water quantity diverged: {seen}")
            first_receipts.setdefault(key, seen)
            log.append({"phase": phase, "variant": variant, "case": key,
                        "elapsed_s": round(seconds, 3), "rows": rows, "receipts": seen})
            print(f"PASS {prefix}: {len(rows)} rows, {len(seen)} source-parity receipts", flush=True)
    summary = []
    for kind, name in CASES:
        case = kind + "-" + name
        selected = [r for r in log if r["case"] == case]
        if len(selected) != 4 or tuple(r["variant"] for r in selected) != ORDER:
            raise ValueError("incomplete counterbalanced case " + case)
        keys = [(0, 1), (16, 1), (16, 2)] if kind == "camera" else [None]
        for key in keys:
            values = []
            for row in selected:
                record = (next(x for x in row["rows"] if
                               int(x["speed"]) == key[0] and int(x["arm"]) == key[1])
                          if key is not None else row["rows"][0])
                values.append(float(record["p50_ms" if key is not None else "tick_p50_ms"]))
            old = (values[0] + values[3]) / 2
            new = (values[1] + values[2]) / 2
            summary.append({"case": case, "speed_arm": key,
                            "abba_p50_ms": values,
                            "mean_baseline_ms": old, "mean_camera_ms": new,
                            "improvement_pct": 100 * (old-new)/old})
    report = {"identity": hashes, "compiler": compiler, "order": ORDER,
              "correctness": "all normalized camera hashes, surge full hashes and Water quantities match across source variants",
              "scope": "one current-main camera cold() call removed; no TLS, chemistry, production changes or real Godot",
              "limits": ["Native 1-worker screen only", "No source-matched Windows or Godot coverage",
                         "No final #405 merge admission", "Timing deltas advisory, order-controlled but noisy"],
              "summaries": summary, "runs": log}
    (out / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("LCB201_CURRENT_MAIN_CAMERA_ABBA_PASS main=" + base_sha +
          " diagnostic=" + trial_sha + " case_runs=" + str(len(log)))
    for item in summary:
        print(item["case"], item["speed_arm"], f"{item['improvement_pct']:+.2f}% advisory p50")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"LCB201_CURRENT_MAIN_CAMERA_ABBA_FAIL: {exc}", file=sys.stderr)
        raise
