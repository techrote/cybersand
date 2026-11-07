#!/usr/bin/env python3
"""Independent, standard-library-only verifier for #527's preregistered native control.

Manifest/preflight proves recipe authorization. The separate native C++ program
must supply actual completed World ticks and authoritative material counts.
Neither this checker nor a sample text fixture is native execution evidence.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import shlex

TOTAL_BUDGET = 480
EXPECTED_SAND = 32
VARIANTS = ("normal", "revised")
WORKERS = (1, 4)


def require(test: bool, message: str) -> None:
    if not test:
        raise ValueError(message)


def parse_recipe(path: Path) -> list[tuple[str, str, str, int, int, int, int]]:
    result = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        words = shlex.split(line)
        require(len(words) == 7, f"line {lineno}: expected seven fields")
        variant, phase, shape = words[:3]
        require(variant in ("both", *VARIANTS), f"line {lineno}: unknown variant")
        require(phase in ("manual_wall", "initial_sand", "protected_wall",
                          "agent_wall", "agent_empty", "target"),
                f"line {lineno}: unknown phase")
        require(shape in ("rect", "wedge_left", "wedge_right"),
                f"line {lineno}: unknown shape")
        numbers = tuple(int(v) for v in words[3:])
        require(0 < numbers[3] <= 128, f"line {lineno}: invalid height")
        if shape == "rect":
            require(0 < numbers[2] <= 128, f"line {lineno}: invalid width")
        result.append((variant, phase, shape, *numbers))
    require(bool(result), "empty manifest")
    return result


def expand(operation: tuple) -> set[tuple[int, int]]:
    _, _, shape, a, b, c, d = operation
    if shape == "rect":
        return {(x, y) for y in range(b, b + d) for x in range(a, a + c)}
    if shape == "wedge_right":
        return {(x, b + row) for row in range(d) for x in range(a, c + row + 1)}
    return {(x, b + row) for row in range(d) for x in range(c - row, a + 1)}


def preflight(recipe: list[tuple]) -> None:
    targets = {}
    for variant in VARIANTS:
        initial: dict[tuple[int, int], str] = {}
        protected: set[tuple[int, int]] = set()
        authored_sand: set[tuple[int, int]] = set()
        selected = [op for op in recipe if op[0] in ("both", variant)]
        for phase in ("manual_wall", "protected_wall", "initial_sand"):
            for op in selected:
                if op[1] != phase:
                    continue
                require(op[2] == "rect", "authored start must use literal rectangles")
                for cell in expand(op):
                    require(initial.get(cell) != "Sand", "manual phase overwrote Sand")
                    initial[cell] = "Sand" if phase == "initial_sand" else "Hard Wall"
                    if phase == "initial_sand":
                        require(cell not in authored_sand, "duplicate initial Sand")
                        authored_sand.add(cell)
                    if phase == "protected_wall":
                        protected.add(cell)
        require(len(authored_sand) == EXPECTED_SAND,
                f"{variant}: exactly 32 literal native Sand cells required")
        require(bool(protected), "protected motif absent")
        for phase in ("agent_wall", "agent_empty"):
            for op in selected:
                if op[1] != phase:
                    continue
                for cell in expand(op):
                    require(cell not in protected, f"{variant}: agent touches protected wall")
                    require(initial.get(cell) != "Sand", f"{variant}: agent replaces Sand")
                    if phase == "agent_empty":
                        require(initial.get(cell) == "Hard Wall",
                                f"{variant}: opening must remove a pre-existing wall")
                    initial[cell] = "Hard Wall" if phase == "agent_wall" else "Empty"
        require({c for c, m in initial.items() if m == "Sand"} == authored_sand,
                f"{variant}: agent altered authored Sand")
        catchments = [expand(op) for op in selected if op[1] == "target"]
        require(len(catchments) == 1, f"{variant}: expected one catchment")
        target = catchments[0]
        require(target.isdisjoint(authored_sand) and target.isdisjoint(protected),
                f"{variant}: target overlaps authored/protected region")
        require(all(-96 <= x < 96 and -24 <= y < 72
                    for op in selected for x, y in expand(op)),
                f"{variant}: geometry outside recorded native readback bounds")
        targets[variant] = target
    require(targets["normal"].isdisjoint(targets["revised"]),
            "revised catchment must be genuinely offset from normal")
    print("WB_AGENT_527_MANIFEST preflight=PASS"
          f" initial_sand={EXPECTED_SAND} variants=normal,revised"
          f" total_trial_ticks={TOTAL_BUDGET} max_per_step_call=120")


def fields(line: str) -> dict[str, str]:
    result = {}
    for pair in line.split()[1:]:
        require("=" in pair, "malformed native receipt token")
        name, value = pair.split("=", 1)
        require(name not in result, "duplicate native receipt key")
        result[name] = value
    return result


def verify_native(path: Path) -> None:
    results: dict[tuple[str, int], dict[str, str]] = {}
    samples: defaultdict[tuple[str, int], dict[int, dict[str, str]]] = defaultdict(dict)
    terminal = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw.startswith("SAMPLE "):
            record = fields(raw)
            key = (record["variant"], int(record["configured_workers"]))
            tick = int(record["tick"])
            require(tick not in samples[key], f"duplicate native sample {key} {tick}")
            samples[key][tick] = record
        elif raw.startswith("RESULT "):
            record = fields(raw)
            key = (record["variant"], int(record["configured_workers"]))
            require(key not in results, f"duplicate native result {key}")
            results[key] = record
        elif raw.startswith("WB_AGENT_527_NATIVE_CONTROL "):
            require(terminal is None, "duplicate native terminal record")
            terminal = fields(raw)
    require(terminal is not None and terminal.get("failures") == "0",
            "native executable reported failures or did not complete")
    expected = {(v, w) for v in VARIANTS for w in WORKERS}
    require(set(results) == expected, "missing or extra native source-matched arms")
    require(set(samples) == expected, "missing or extra native samples")
    for key, r in results.items():
        require(r.get("outcome") == "PASS", f"{key}: native control HOLD")
        for field, expected_value in {
            "total_budget": TOTAL_BUDGET, "completed": TOTAL_BUDGET,
            "initial": EXPECTED_SAND, "after_author": EXPECTED_SAND,
            "total": EXPECTED_SAND, "catchment": EXPECTED_SAND,
        }.items():
            require(int(r[field]) == expected_value,
                    f"{key}: invalid {field} (observed {r.get(field)})")
        require(int(r["protected"]) > 0, f"{key}: no protected motif readback")
        require(int(r["agent_wall_empty_writes"]) > 0,
                f"{key}: no Hard Wall/Empty authoring")
        require(int(r["actual_worker_max"]) >= 0,
                f"{key}: malformed observed worker participation")
        require(set(samples[key]) == set(range(40, TOTAL_BUDGET + 1, 40)),
                f"{key}: expected every 40th completed tick")
        for tick, record in samples[key].items():
            require(int(record["total"]) == EXPECTED_SAND,
                    f"{key}: nonconserved Sand at tick {tick}")
            require(0 <= int(record["catchment"]) <= EXPECTED_SAND,
                    f"{key}: invalid catchment count at tick {tick}")
    print("WB_AGENT_527_NATIVE_VERIFIER native_real_world=PASS"
          " normal=32 revised=32 initial_sand=32"
          f" total_ticks_each={TOTAL_BUDGET} arms=4")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path,
                        default=Path("native/tests/fixtures/wb_agent_sand_hopper_v1.tsv"))
    parser.add_argument("--native-log", type=Path)
    args = parser.parse_args()
    recipe = parse_recipe(args.manifest)
    preflight(recipe)
    if args.native_log:
        verify_native(args.native_log)
    else:
        print("WB_AGENT_527_NATIVE_VERIFIER status=NOT_EXECUTED"
              " reason=no_actual_native_log")


if __name__ == "__main__":
    main()
