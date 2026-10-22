"""Parallel parameter grid over the water lab scenarios (scratch only)."""
import itertools, json, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

probe = sys.argv[1]
grid = json.loads(sys.argv[2])          # {"WTH":[6,10], ...}
fixed = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
import os as _os
scenarios = [tuple((x.split(":")[0], int(x.split(":")[1]))) for x in _os.environ.get("GRID_SCEN", "pool:2400,column:2400,utube:4000,basin:2400,cloud:1500,rain:800").split(",")]
keys = list(grid)
combos = [dict(zip(keys, v)) for v in itertools.product(*grid.values())]

def run(job):
    combo, (scen, ticks) = job
    env = dict(os.environ, LAB_QUIET="1", **{k: str(v) for k, v in {**fixed, **combo}.items()})
    out = subprocess.run([probe, scen, str(ticks), "1"], env=env, capture_output=True, text=True).stdout
    d = json.loads(out.strip().splitlines()[-1])
    return json.dumps(combo, sort_keys=True), scen, ticks, d

jobs = [(c, s) for c in combos for s in scenarios]
results = {}
with ThreadPoolExecutor(max_workers=11) as ex:
    for key, scen, ticks, d in ex.map(run, jobs):
        results.setdefault(key, {})[scen] = (ticks, d)

rows = []
for key, per in results.items():
    score = 0
    cells = []
    for scen, ticks in scenarios:
        t, d = per[scen]
        assert d["mass0"] == d["mass"], (key, scen)
        lvl = d["level_tick"] or 2 * t
        slp = d["sleep_tick"] or 2 * t
        score += lvl / t + slp / t
        cells.append(f"{scen[:4]}:{d['level_tick']}/{d['sleep_tick']}/{d['final_spread']}")
    rows.append((score, key, cells))
rows.sort()
for score, key, cells in rows:
    print(f"{score:6.2f} {key} {' '.join(cells)}")
