#!/usr/bin/env bash
# Experimental #472 source-matched native 1024x1024 host-scale proxy.
# This is NOT my-canvas, bench-canvas, stress-canvas or a Godot/Rapier benchmark.
# Usage: bash tools/lcb/pf_run_repair_compare.sh BASE_CHECKOUT CANDIDATE_CHECKOUT OUT_DIR [g++-13]
set -euo pipefail
if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: $0 BASE_CHECKOUT CANDIDATE_CHECKOUT OUT_DIR [CXX]" >&2
  exit 2
fi
base="$(cd "$1" && pwd -P)"
candidate="$(cd "$2" && pwd -P)"
mkdir -p "$3"
out="$(cd "$3" && pwd -P)"
compiler="${4:-g++-13}"
if [[ "$out" == "$base" || "$out" == "$candidate" || "$out" == "$base/"* || "$out" == "$candidate/"* ]]; then
  echo "output must be outside both checkouts" >&2; exit 2
fi
command -v "$compiler" >/dev/null || { echo "compiler unavailable: $compiler" >&2; exit 2; }
"$compiler" --version | head -n 1 > "$out/compiler.txt"
uname -a > "$out/host.txt"
for arm in base candidate; do
  if [[ "$arm" == base ]]; then root="$base"; else root="$candidate"; fi
  mkdir -p "$out/$arm"
  git -C "$root" rev-parse HEAD > "$out/$arm/source-sha.txt"
  git -C "$root" status --porcelain=v1 > "$out/$arm/worktree-status.txt"
  if [[ -s "$out/$arm/worktree-status.txt" ]]; then
    echo "$arm checkout not clean; refusing timed comparison" >&2; exit 2
  fi
  (
    cd "$root"
    "$compiler" -std=c++20 -O3 -DNDEBUG -pthread -Wall -Wextra -Wpedantic -Wconversion -Wshadow \
      -Inative/include native/src/world.cpp native/src/material_rules.cpp \
      native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp \
      native/src/render_snapshot.cpp native/src/c_api.cpp \
      native/bench/lcb201_pressure_idle_cost.cpp -o "$out/$arm/lcb201"
  ) > "$out/$arm/build.stdout" 2> "$out/$arm/build.stderr"
  sha256sum "$out/$arm/lcb201" > "$out/$arm/binary.sha256"
  # Registered complete 1024x1024 native fixture; same 4-arm executable,
  # 3 warm rotated repeats at worker counts 1 and 4, full JSONL retained.
  for profile in pool-vented pool-sealed pool-sealed-remote-gas pool-vented-moving-mask pool-vented-boundary-churn; do
    for workers in 1 4; do
      for rep in 0 1 2; do
        case_name="${profile}-w${workers}-r${rep}"
        "$out/$arm/lcb201" "$profile" "$workers" "$rep" \
          > "$out/$arm/${case_name}.jsonl" 2> "$out/$arm/${case_name}.stderr"
      done
    done
  done
  if [[ "$(git -C "$root" rev-parse HEAD)" != "$(cat "$out/$arm/source-sha.txt")" ]]; then
    echo "source moved during $arm measurement" >&2; exit 2
  fi
done
python3 - "$out" <<'PY'
import json, pathlib, statistics, sys
out = pathlib.Path(sys.argv[1])
profiles = ("pool-vented", "pool-sealed", "pool-sealed-remote-gas",
            "pool-vented-moving-mask", "pool-vented-boundary-churn")
records = []
for profile in profiles:
    for workers in (1,4):
        for variant in ("reference", "cached", "dormant"):
            measures = {}
            for arm in ("base", "candidate"):
                samples = []
                for rep in (0,1,2):
                    p = out / arm / f"{profile}-w{workers}-r{rep}.jsonl"
                    rows = [json.loads(line) for line in p.read_text().splitlines()]
                    sample = [r for r in rows if r.get("event")=="tick"
                              and r.get("arm")==variant and r.get("phase")=="tail"]
                    # Keep the full sample vector; the mean reported is only
                    # the host-scale proxy's late steady phase.
                    if not sample:
                        raise SystemExit(f"no tail ticks: {p}")
                    samples.append(statistics.mean(r["tick_ns"] for r in sample)/1e6)
                measures[arm] = samples
            records.append({"profile":profile,"workers":workers,"variant":variant,
                "base_ms_repeats":measures["base"],"candidate_ms_repeats":measures["candidate"],
                "base_median_ms":statistics.median(measures["base"]),
                "candidate_median_ms":statistics.median(measures["candidate"]),
                "candidate_over_base":statistics.median(measures["candidate"])/
                                      statistics.median(measures["base"])})
(out/"summary.json").write_text(json.dumps({
    "schema":"pf-run-repair-native-1024-proxy-v1",
    "scope":"Not the named canvas scenes, no Rapier or live Godot; do not use as a stress-canvas claim",
    "base_sha":(out/"base/source-sha.txt").read_text().strip(),
    "candidate_sha":(out/"candidate/source-sha.txt").read_text().strip(),
    "records":records},indent=2)+"\n")
print(out/"summary.json")
PY
