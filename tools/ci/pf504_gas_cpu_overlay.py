#!/usr/bin/env python3
"""Apply identical PF504 CPU-accounting overlays to two PINNED worktree copies.

Nothing from this overlay is merged into protected production native sources.
The original source revisions and pre-overlay LF hashes are recorded separately.
On Linux, std::clock measures process CPU (all threads), NOT exclusively CPU
of the gas operator's worker threads. Stage timestamps bound attribution.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

SOURCES = {
    "baseline": "24a8bbe8ccf0d17196ebbab580b924930a964584",
    "candidate": "186452b9f035961325ad71917a76ba8834e30bcf",
}
PRESSURE = {
    "baseline": "71723fa32bbd29aafe93f1a8dd233cece1eec7ed295da81c1e021f635085c17a",
    "candidate": "899ada71b89d30ba063e047bdd5b02346948008f1b7c0bec9fa0f2272e4d86ec",
}


def replace_once(content: str, before: str, after: str, label: str) -> str:
    count = content.count(before)
    if count != 1:
        raise AssertionError(f"{label}: expected one original anchor; got {count}: {before[:120]!r}")
    return content.replace(before, after)


def sha(content: bytes) -> str:
    return hashlib.sha256(content.replace(b"\r\n", b"\n")).hexdigest()


def patch(root: Path, path: str, edits: list[tuple[str, str]]) -> dict:
    file = root / path
    old = file.read_bytes()
    content = old.decode("utf-8")
    for before, after in edits:
        content = replace_once(content, before, after, path)
    if content.encode("utf-8") == old:
        raise AssertionError(f"{path}: no change")
    file.write_text(content, encoding="utf-8", newline="\n")
    return {"path": path, "before_lf_sha256": sha(old),
            "after_lf_sha256": sha(content.encode("utf-8"))}


def apply(root: Path, label: str) -> dict:
    original = (root / "native/src/world_pressure.inc").read_bytes()
    if sha(original) != PRESSURE[label]:
        raise AssertionError(f"{label}: protected native pressure original hash changed")
    old_world = (root / "native/src/world.cpp").read_bytes()
    old_bridge = (root / "godot/native_extension/cyber_native_cell_world.cpp").read_bytes()

    entries = []
    entries.append(patch(root, "native/include/cybersand/pressure_optimization.hpp", [
        (
            "    std::uint64_t gas_nanoseconds = 0;\n",
            "    std::uint64_t gas_nanoseconds = 0;\n"
            "    // PF504 test-only process-CPU clocks, summed over the whole process.\n"
            "    std::uint64_t pf504_gas_process_cpu_ns = 0;\n"
            "    std::uint64_t pf504_head_process_cpu_ns = 0;\n",
        ),
    ]))
    entries.append(patch(root, "native/src/world.cpp", [
        ("#include <chrono>\n", "#include <chrono>\n#include <ctime> // PF504 test-only process CPU profile\n"),
    ]))
    entries.append(patch(root, "native/src/world_pressure.inc", [
        (
            "    const auto gas_start = Clock::now();\n",
            "    const auto gas_start = Clock::now();\n"
            "    const auto pf504_gas_cpu_start = std::clock();\n",
        ),
        (
            "    const auto head_start = Clock::now();\n",
            "    const auto pf504_gas_cpu_finish = std::clock();\n"
            "    const auto head_start = Clock::now();\n"
            "    const auto pf504_head_cpu_start = std::clock();\n",
        ),
        (
            "    const auto end = Clock::now();\n",
            "    const auto pf504_head_cpu_finish = std::clock();\n"
            "    const auto end = Clock::now();\n",
        ),
        (
            "    state.optimization.gas_nanoseconds += nanos(head_start - gas_start);\n",
            "    state.optimization.gas_nanoseconds += nanos(head_start - gas_start);\n"
            "    if (pf504_gas_cpu_start != std::clock_t{-1} &&\n"
            "        pf504_gas_cpu_finish != std::clock_t{-1} && pf504_gas_cpu_finish >= pf504_gas_cpu_start) {\n"
            "        state.optimization.pf504_gas_process_cpu_ns += static_cast<std::uint64_t>(\n"
            "            static_cast<double>(pf504_gas_cpu_finish - pf504_gas_cpu_start) * 1.0e9 /\n"
            "            static_cast<double>(CLOCKS_PER_SEC));\n"
            "    }\n"
            "    if (pf504_head_cpu_start != std::clock_t{-1} &&\n"
            "        pf504_head_cpu_finish != std::clock_t{-1} && pf504_head_cpu_finish >= pf504_head_cpu_start) {\n"
            "        state.optimization.pf504_head_process_cpu_ns += static_cast<std::uint64_t>(\n"
            "            static_cast<double>(pf504_head_cpu_finish - pf504_head_cpu_start) * 1.0e9 /\n"
            "            static_cast<double>(CLOCKS_PER_SEC));\n"
            "    }\n",
        ),
    ]))
    entries.append(patch(root, "godot/native_extension/cyber_native_cell_world.hpp", [
        (
            "    cybersand::TickStats last_stats_{};\n",
            "    cybersand::TickStats last_stats_{};\n"
            "    std::uint64_t pf504_native_tick_process_cpu_ns_ = 0;\n"
            "    std::uint64_t pf504_native_cpu_cumulative_ns_ = 0;\n"
            "    std::uint64_t pf504_native_tick_samples_ = 0;\n",
        ),
    ]))
    entries.append(patch(root, "godot/native_extension/cyber_native_cell_world.cpp", [
        (
            '#include "cyber_native_cell_world.hpp"\n',
            '#include "cyber_native_cell_world.hpp"\n#include <ctime> // PF504 test-only process CPU profile\n',
        ),
        (
            "    const auto start = std::chrono::steady_clock::now();\n    bool succeeded = false;\n",
            "    const auto start = std::chrono::steady_clock::now();\n"
            "    const auto pf504_cpu_start = std::clock();\n"
            "    bool succeeded = false;\n",
        ),
        (
            "    simulation_time_ms_ = std::chrono::duration<double, std::milli>(\n",
            "    const auto pf504_cpu_finish = std::clock();\n"
            "    if (pf504_cpu_start != std::clock_t{-1} &&\n"
            "        pf504_cpu_finish != std::clock_t{-1} && pf504_cpu_finish >= pf504_cpu_start) {\n"
            "        pf504_native_tick_process_cpu_ns_ = static_cast<std::uint64_t>(\n"
            "            static_cast<double>(pf504_cpu_finish - pf504_cpu_start) * 1.0e9 /\n"
            "            static_cast<double>(CLOCKS_PER_SEC));\n"
            "        pf504_native_cpu_cumulative_ns_ += pf504_native_tick_process_cpu_ns_;\n"
            "        ++pf504_native_tick_samples_;\n"
            "    }\n"
            "    simulation_time_ms_ = std::chrono::duration<double, std::milli>(\n",
        ),
    ]))
    entries.append(patch(root, "godot/native_extension/pressure_optimization_inspection.inc", [
        (
            '    out["schema_version"] = 1;\n',
            '    out["schema_version"] = 1;\n'
            '    out["pf504_native_tick_process_cpu_ns"] = pressure_optimization_unsigned(pf504_native_tick_process_cpu_ns_);\n'
            '    out["pf504_native_cpu_cumulative_ns"] = pressure_optimization_unsigned(pf504_native_cpu_cumulative_ns_);\n'
            '    out["pf504_native_tick_samples"] = pressure_optimization_unsigned(pf504_native_tick_samples_);\n'
            '    out["pf504_worker_threads_observed"] = static_cast<std::int64_t>(last_stats_.worker_threads_observed);\n'
            '    out["pf504_worker_capacity"] = static_cast<std::int64_t>(worker_threads_);\n',
        ),
        (
            '    CYBERSAND_PRESSURE_COUNT(gas_nanoseconds);\n',
            '    CYBERSAND_PRESSURE_COUNT(gas_nanoseconds);\n'
            '    CYBERSAND_PRESSURE_COUNT(pf504_gas_process_cpu_ns);\n'
            '    CYBERSAND_PRESSURE_COUNT(pf504_head_process_cpu_ns);\n',
        ),
    ]))
    # Only the accepted baseline hosts the Godot script, and BOTH native
    # candidates are loaded into this identical patched host in sequence.
    if label == "baseline":
        entries.append(patch(root, "godot/scripts/simulation_worker.gd", [
            (
                '\t\tsnapshot.lab_context["workbench_gcr"] = _workbench_result\n',
                '\t\tsnapshot.lab_context["workbench_gcr"] = _workbench_result\n'
                '\t\t# PF504 experiment: owner-thread copied-only counters, not mutable state.\n'
                '\t\tif OS.get_environment("PF504_STAGE_PROFILE") == "1" and _world.has_method(&"inspect_pressure_optimization"):\n'
                '\t\t\tvar pf504_observed: Dictionary = _world.inspect_pressure_optimization()\n'
                '\t\t\tif bool(pf504_observed.get("available", false)):\n'
                '\t\t\t\tvar pf504_counters: Dictionary = pf504_observed.get("counters", {})\n'
                '\t\t\t\tvar pf504_stats: Dictionary = {\n'
                '\t\t\t\t\t"native_tick_cpu_ns": str(pf504_observed.get("pf504_native_tick_process_cpu_ns", "")),\n'
                '\t\t\t\t\t"native_cumulative_cpu_ns": str(pf504_observed.get("pf504_native_cpu_cumulative_ns", "")),\n'
                '\t\t\t\t\t"native_cpu_sample_count": str(pf504_observed.get("pf504_native_tick_samples", "")),\n'
                '\t\t\t\t\t"workers_observed": int(pf504_observed.get("pf504_worker_threads_observed", -1)),\n'
                '\t\t\t\t\t"worker_capacity": int(pf504_observed.get("pf504_worker_capacity", -1)),\n'
                '\t\t\t\t}\n'
                '\t\t\t\tfor pf504_key: String in ["gas_nanoseconds", "head_nanoseconds", "preparation_nanoseconds",\n'
                '\t\t\t\t\t"pf504_gas_process_cpu_ns", "pf504_head_process_cpu_ns",\n'
                '\t\t\t\t\t"gas_reference_passes", "gas_reuses", "gas_seed_cells", "gas_seed_probes",\n'
                '\t\t\t\t\t"gas_bfs_cells", "gas_bfs_probes", "gas_bfs_nodes",\n'
                '\t\t\t\t\t"gas_relabel_cells", "gas_member_validations", "gas_component_reuses",\n'
                '\t\t\t\t\t"gas_cache_build_cells", "gas_cache_builds", "gas_capacity_fallbacks",\n'
                '\t\t\t\t\t"gas_budget_fallbacks", "gas_restart_fallbacks", "water_material_calls",\n'
                '\t\t\t\t\t"water_motion_calls", "reference_fallbacks", "columns_recomputed",\n'
                '\t\t\t\t\t"head_nanoseconds"]:\n'
                '\t\t\t\t\tpf504_stats[pf504_key] = str(pf504_counters.get(pf504_key, ""))\n'
                '\t\t\t\tsnapshot.lab_context["pf504_stage_profile"] = pf504_stats\n'
            ),
        ]))
    if (root / "native/src/world_pressure.inc").stat().st_size == 0:
        raise AssertionError("pressure vanished")
    return {"arm": label, "source": SOURCES[label], "protected_before": PRESSURE[label],
            "changes": entries}


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: pf504_gas_cpu_overlay.py <baseline-dir> <candidate-dir>")
    roots = [Path(sys.argv[1]), Path(sys.argv[2])]
    outcome = [apply(roots[i], arm) for i, arm in enumerate(("baseline", "candidate"))]
    print(json.dumps({"schema": "pf504-gas-cpu-ephemeral-overlay-v1", "arms": outcome}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
