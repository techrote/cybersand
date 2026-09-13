"""Validate completed issue #9 evidence without converting symptoms into passes.

Checks measurement integrity, conservation controls and exact matching-profile
comparisons. Physics targets such as half-depth embedding are reported separately.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path


def verify(raw: Path):
    checks = 0
    errors = []
    native = []
    coupled = []

    def require(condition, message):
        nonlocal checks
        checks += 1
        if not condition:
            errors.append(message)

    for group in ("native-expanded", "native-controls", "native-finalists"):
        folder = raw / group
        for spec in json.loads((folder / "cases.json").read_text()):
            path = folder / (spec["id"] + ".jsonl")
            require(path.exists(), f"missing {path}")
            if not path.exists():
                continue
            data = [json.loads(line) for line in path.read_text().splitlines()]
            result = data[-1]
            require(result.get("completed_ticks") == spec["ticks"], f"incomplete {path}")
            require(result.get("overflow", 0) == 0, f"overflow {path}")
            if result.get("type") != "result":
                continue
            # Salt chemistry, phase changes and the excavated ROI are separate
            # accounting cases. Nonreactive closed Sand/Water must conserve mass.
            if {spec["top"], spec["bottom"]} == {2, 3}:
                require(all(d["water_mass"] == data[0]["water_mass"] for d in data[:-1]), f"Water mass {path}")
            if spec["layout"] == "packed" and spec["top"] in (2, 14, 29, 33) and spec["bottom"] in (2, 14, 29, 33):
                require(data[0]["counts"][1:] == data[-2]["counts"][1:], f"closed counts {path}")
            if spec["variant"] == "exchange_off":
                require(not any(k >> 24 == 2 for k, _ in result["histogram"]), f"exchange disabled {path}")
            native.append((group, spec, data))
    for group, spec, data in native:
        if group != "native-controls" or not (spec.get("workers") == 4 or spec.get("telemetry") is False or spec["variant"].startswith("viscosity_")):
            continue
        candidates = [d for g, s, d in native if g == group and s["top"] == spec["top"] and s["bottom"] == spec["bottom"]
                      and s["seed"] == spec["seed"] and s["layout"] == spec["layout"] and s["width"] == spec["width"]
                      and s["variant"] == ("viscosity_96" if spec["width"] == 1 else "baseline")
                      and s.get("workers", 1) == 1 and s.get("telemetry", True) and not s.get("serial", False)]
        require(len(candidates) == 1, f"comparison partner {spec['id']}")
        if candidates:
            require([d["hash"] for d in data[:-1]] == [d["hash"] for d in candidates[0][:-1]], f"native parity {spec['id']}")
    for group in ("godot-controls-final", "godot-expanded", "godot-creep"):
        folder = raw / group
        for spec in json.loads((folder / "cases.json").read_text()):
            path = folder / (spec["id"] + ".json")
            require(path.exists(), f"missing {path}")
            if not path.exists():
                continue
            d = json.loads(path.read_text())
            require(d["ok"] and d["completed_ticks"] == spec["ticks"] == d["final"]["completed_ticks"], f"incomplete {path}")
            require(d["final"].get("overflow", 0) in (0, -1), f"overflow {path}")
            require(d["floor_contact_tick"] < 0 or d["late_creep"] is None, f"floor censor {path}")
            if spec["material"] == 3 and not spec.get("fallback"):
                if spec["mode"] == "barrel":
                    accounting_path = raw / "water-accounting" / f"water-s{spec['seed']:02d}.json"
                    require(accounting_path.exists(), f"missing global accounting {accounting_path}")
                    if accounting_path.exists():
                        accounting = json.loads(accounting_path.read_text())
                        initial, final = accounting["initial"], accounting["final"]
                        require(accounting["ok"] and accounting["completed_ticks"] == spec["ticks"], f"accounting completion {path}")
                        require(final["overflow"] == 0 and initial["global_water_mass"] == final["global_water_mass"], f"global Water mass {path}")
                        require(final["global_water_mass"] - final["water_mass"] == final["water_below_floor"] and final["water_above_crop"] == 0, f"Water escaped ROI explanation {path}")
                        require(d["final"]["hash"] == final["hash"] and d["rows"] == accounting["rows"], f"global observer parity {path}")
                else:
                    require(d["initial"]["water_mass"] == d["final"]["water_mass"], f"Water mass {path}")
            if spec["layout"] == "hard":
                require(d["peak_depth"] <= 2, f"hard control {path}")
            coupled.append((group, spec, d))
    for group, spec, d in coupled:
        if group != "godot-controls-final" or not (spec.get("workers") == 4 or spec.get("telemetry") is False or spec.get("duplicate")):
            continue
        partners = [b for g, s, b in coupled if g == group and s["id"] == f"009-barrel-Sand-flat-s{spec['seed']:02d}"]
        require(len(partners) == 1, f"body partner {spec['id']}")
        if partners:
            require(d["final"]["hash"] == partners[0]["final"]["hash"], f"body cells {spec['id']}")
            keys = ("tick", "x", "y", "vx", "vy", "rotation")
            require([[r[k] for k in keys] for r in d["rows"]] == [[r[k] for k in keys] for r in partners[0]["rows"]], f"body trajectory {spec['id']}")
    browsers = []
    for profile in ("compat", "threaded"):
        d = json.loads((raw / f"browser-{profile}/browser-result.json").read_text())
        runs = d["result"]["results"]
        require(d["result"]["ok"] and len(runs) == 25, f"browser {profile} count")
        for r in runs:
            require(r["ok"] and r["completed_ticks"] == 1800 and r["final"]["overflow"] == 0, f"browser {profile} {r['spec']}")
        browsers.append(runs)
    require(all(a["rows"] == b["rows"] and a["final"]["hash"] == b["final"]["hash"] for a, b in zip(*browsers)), "real Web profile equality")
    async_runs = sorted((raw / "desktop-async-final").glob("async-s*.json"))
    require(len(async_runs) == 5, "desktop async five seeds")
    for path in async_runs:
        d = json.loads(path.read_text())
        require(d["ok"] and d["completed_ticks"] == 1800 and d["final"]["overflow"] == 0, f"async completion {path}")
    accounting_runs = list((raw / "water-accounting").glob("water-s*.json"))
    require(len(accounting_runs) == 5, "five-seed global Water accounting")
    return {"ok": not errors, "checks": checks, "errors": errors, "native_runs": len(native), "coupled_runs": len(coupled),
            "water_accounting_runs": len(accounting_runs), "browser_runs": 50, "async_runs": len(async_runs),
            "completed_ticks": sum(d[-1]["completed_ticks"] for _, _, d in native) + sum(d["completed_ticks"] for _, _, d in coupled)
            + (50 + len(async_runs) + len(accounting_runs)) * 1800}


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("raw", type=Path)
    p.add_argument("--output", type=Path)
    args = p.parse_args()
    result = verify(args.raw)
    output = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(output, encoding="utf-8")
    print(output, end="")
    raise SystemExit(not result["ok"])
