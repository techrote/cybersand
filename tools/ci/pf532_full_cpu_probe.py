#!/usr/bin/env python3
"""Apply the SAME temporary read-only CPU probe to two isolated Linux sources.

Requires unmodified pinned accepted-main and #504 source worktrees. This DOES
NOT commit changed World/protected bytes or publish production runtime assets.
Every edit is instrument-only; benchmark evidence lists these exact delta hashes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

BASE = "81bbd5ff5cf366159e2b8a630609359c13560080"
CANDIDATE_BUILD = os.environ.get("CANDIDATE_SOURCE", "")
CANDIDATE_PR = CANDIDATE_BUILD

def digest(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()

def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args],
                                   text=True, timeout=45).strip()

def replace_one(source: str, before: str, after: str, path: str) -> str:
    count = source.count(before)
    if count != 1:
        raise ValueError(f"{path}: anchor count {count} (wanted one): {before[:110]!r}")
    return source.replace(before, after, 1)

def patch(path: str, code: str) -> str:
    if path == "native/include/cybersand/pressure_optimization.hpp":
        code = replace_one(code, "#pragma once\n",
            "#pragma once\n\n// TEMPORARY CPU DIAGNOSTIC: never committed or shipped in a production runtime.\n"
            "#if !defined(__linux__)\n#error CYBERSAND_PF_GAS_CPU_PROBE requires Linux\n#endif\n"
            "#define CYBERSAND_PF_GAS_CPU_PROBE 1\n", path)
        code = replace_one(code, "    std::uint64_t gas_nanoseconds = 0;\n",
            "    std::uint64_t gas_nanoseconds = 0;\n"
            "    // CPU spent by ALL process threads during the gas window (not gas-exclusive).\n"
            "    std::uint64_t pf_probe_gas_process_cpu_ns = 0;\n"
            "    // CPU executed by the gas-stage owning thread, excluding pool tasks.\n"
            "    std::uint64_t pf_probe_gas_owner_cpu_ns = 0;\n"
            "    std::uint64_t pf_probe_head_process_cpu_ns = 0;\n"
            "    // Inclusive gas discovery (seed prefilter + BFS + masks/cache), identity and relabel windows.\n"
            "    std::uint64_t pf_probe_discovery_process_cpu_ns = 0;\n"
            "    std::uint64_t pf_probe_identity_process_cpu_ns = 0;\n"
            "    std::uint64_t pf_probe_relabel_process_cpu_ns = 0;\n", path)
    elif path == "native/src/world.cpp":
        code = replace_one(code, "#include <utility>\n",
            "#include <utility>\n"
            "#include <time.h>\n", path)
    elif path == "native/src/world_pressure.inc":
        code = replace_one(code, "void World::prepare_pressure_tick() {",
            """// Diagnostic Linux CPU clocks. These are observational only.
#ifdef CYBERSAND_PF_GAS_CPU_PROBE
namespace {
[[nodiscard]] std::uint64_t pf_probe_clock_ns(clockid_t kind) noexcept {
    timespec ts{};
    if (clock_gettime(kind, &ts) != 0) return 0U;
    return static_cast<std::uint64_t>(ts.tv_sec) * 1000000000ULL +
           static_cast<std::uint64_t>(ts.tv_nsec);
}
[[nodiscard]] std::uint64_t pf_probe_process_cpu_ns() noexcept {
    return pf_probe_clock_ns(CLOCK_PROCESS_CPUTIME_ID);
}
[[nodiscard]] std::uint64_t pf_probe_owner_cpu_ns() noexcept {
    return pf_probe_clock_ns(CLOCK_THREAD_CPUTIME_ID);
}
[[nodiscard]] std::uint64_t pf_probe_delta(std::uint64_t end, std::uint64_t begin) noexcept {
    return end >= begin ? end - begin : 0U;
}
}
#endif

void World::prepare_pressure_tick() {""", path)
        code = replace_one(code, "    const auto gas_start = Clock::now();\n",
            "    const auto gas_start = Clock::now();\n"
            "#ifdef CYBERSAND_PF_GAS_CPU_PROBE\n"
            "    const auto pf_probe_gas_process_start = pf_probe_process_cpu_ns();\n"
            "    const auto pf_probe_gas_owner_start = pf_probe_owner_cpu_ns();\n"
            "#endif\n", path)
        code = replace_one(code, "    const auto head_start = Clock::now();\n",
            "    const auto head_start = Clock::now();\n"
            "#ifdef CYBERSAND_PF_GAS_CPU_PROBE\n"
            "    const auto pf_probe_gas_process_end = pf_probe_process_cpu_ns();\n"
            "    const auto pf_probe_gas_owner_end = pf_probe_owner_cpu_ns();\n"
            "    state.optimization.pf_probe_gas_process_cpu_ns += pf_probe_delta("
            "pf_probe_gas_process_end, pf_probe_gas_process_start);\n"
            "    state.optimization.pf_probe_gas_owner_cpu_ns += pf_probe_delta("
            "pf_probe_gas_owner_end, pf_probe_gas_owner_start);\n"
            "#endif\n", path)
        code = replace_one(code, "    const auto end = Clock::now();\n",
            "    const auto end = Clock::now();\n"
            "#ifdef CYBERSAND_PF_GAS_CPU_PROBE\n"
            "    state.optimization.pf_probe_head_process_cpu_ns += pf_probe_delta("
            "pf_probe_process_cpu_ns(), pf_probe_gas_process_end);\n"
            "#endif\n", path)
        code = replace_one(code, "void World::resolve_gas_topology(bool allow_cache) {\n",
            "void World::resolve_gas_topology(bool allow_cache) {\n"
            "#ifdef CYBERSAND_PF_GAS_CPU_PROBE\n"
            "    const auto pf_probe_discovery_cpu_start = pf_probe_process_cpu_ns();\n"
            "#endif\n", path)
        code = replace_one(code, "        state.diagnostics = discovery_diagnostics;\n        resolve_gas_topology(false);\n",
            "#ifdef CYBERSAND_PF_GAS_CPU_PROBE\n"
            "        state.optimization.pf_probe_discovery_process_cpu_ns += pf_probe_delta("
            "pf_probe_process_cpu_ns(), pf_probe_discovery_cpu_start);\n"
            "#endif\n"
            "        state.diagnostics = discovery_diagnostics;\n        resolve_gas_topology(false);\n", path)
        code = replace_one(code, "    // Identity: union compartments with the regions they overlap.\n",
            "#ifdef CYBERSAND_PF_GAS_CPU_PROBE\n"
            "    state.optimization.pf_probe_discovery_process_cpu_ns += pf_probe_delta("
            "pf_probe_process_cpu_ns(), pf_probe_discovery_cpu_start);\n"
            "    const auto pf_probe_identity_cpu_start = pf_probe_process_cpu_ns();\n"
            "#endif\n"
            "    // Identity: union compartments with the regions they overlap.\n", path)
        code = replace_one(code, "    // A sealed region that includes an unallocated chunk makes it resident, so\n",
            "#ifdef CYBERSAND_PF_GAS_CPU_PROBE\n"
            "    state.optimization.pf_probe_identity_process_cpu_ns += pf_probe_delta("
            "pf_probe_process_cpu_ns(), pf_probe_identity_cpu_start);\n"
            "    const auto pf_probe_relabel_cpu_start = pf_probe_process_cpu_ns();\n"
            "#endif\n"
            "    // A sealed region that includes an unallocated chunk makes it resident, so\n", path)
        code = replace_one(code, "    rebuild_pressure_gas_cache(stamp);\n",
            "    rebuild_pressure_gas_cache(stamp);\n"
            "#ifdef CYBERSAND_PF_GAS_CPU_PROBE\n"
            "    state.optimization.pf_probe_relabel_process_cpu_ns += pf_probe_delta("
            "pf_probe_process_cpu_ns(), pf_probe_relabel_cpu_start);\n"
            "#endif\n", path)
    elif path == "godot/native_extension/cyber_native_cell_world.cpp":
        # read-only native quantity ledger at exclusive World owner, not a new physics law
        marker = '    out["last_tick"] = diagnostics;\n    return out;\n}'
        addition = """    out["last_tick"] = diagnostics;
#ifdef CYBERSAND_PF_GAS_CPU_PROBE
    if (world_ != nullptr && !world_->has_failed()) {
        const auto q = world_->quantity_ledger();
        Dictionary quantity;
        quantity["schema_version"] = static_cast<std::int64_t>(q.schema_version);
        quantity["mass_bits"] = static_cast<std::int64_t>(q.mass_bits);
        quantity["baseline_water"] = static_cast<std::int64_t>(q.baseline_water);
        quantity["visible"] = static_cast<std::int64_t>(q.water_visible);
        quantity["overfill"] = static_cast<std::int64_t>(q.water_overfill);
        quantity["ballistic"] = static_cast<std::int64_t>(q.water_ballistic);
        std::uint64_t produced = q.baseline_water;
        std::uint64_t consumed = 0;
        Array flows;
        for (const auto& flow : q.kinds) {
            Dictionary one;
            one["produced"] = static_cast<std::int64_t>(flow.produced);
            one["consumed"] = static_cast<std::int64_t>(flow.consumed);
            flows.push_back(one);
            produced += flow.produced;
            consumed += flow.consumed;
        }
        quantity["kinds"] = flows;
        quantity["produced"] = static_cast<std::int64_t>(produced);
        quantity["consumed"] = static_cast<std::int64_t>(consumed);
        quantity["actual"] = static_cast<std::int64_t>(
            q.water_visible + q.water_overfill + q.water_ballistic);
        quantity["closed"] = produced >= consumed &&
            (q.water_visible + q.water_overfill + q.water_ballistic) == produced - consumed;
        out["pf_probe_quantity"] = quantity;
    }
#endif
    return out;
}"""
        code = replace_one(code, marker, addition, path)
    elif path == "godot/native_extension/pressure_optimization_inspection.inc":
        code = replace_one(code, "    CYBERSAND_PRESSURE_COUNT(gas_nanoseconds);\n",
            "    CYBERSAND_PRESSURE_COUNT(gas_nanoseconds);\n"
            "    CYBERSAND_PRESSURE_COUNT(pf_probe_gas_process_cpu_ns);\n"
            "    CYBERSAND_PRESSURE_COUNT(pf_probe_gas_owner_cpu_ns);\n"
            "    CYBERSAND_PRESSURE_COUNT(pf_probe_head_process_cpu_ns);\n"
            "    CYBERSAND_PRESSURE_COUNT(pf_probe_discovery_process_cpu_ns);\n"
            "    CYBERSAND_PRESSURE_COUNT(pf_probe_identity_process_cpu_ns);\n"
            "    CYBERSAND_PRESSURE_COUNT(pf_probe_relabel_process_cpu_ns);\n", path)
    else:
        raise ValueError("Unrecognized diagnostic patch path: "+path)
    return code

PATHS = (
    "native/include/cybersand/pressure_optimization.hpp",
    "native/src/world.cpp",
    "native/src/world_pressure.inc",
    "godot/native_extension/pressure_optimization_inspection.inc",
    "godot/native_extension/cyber_native_cell_world.cpp",
)

def instrument(root: Path, source: str) -> dict:
    root = root.resolve()
    if git(root, "rev-parse", "HEAD") != source:
        raise RuntimeError("Source worktree was moved: "+str(root))
    if git(root,"status","--porcelain=v1","--untracked-files=no"):
        raise RuntimeError("Source worktree is dirty before profiling instrumentation")
    records={}
    for path in PATHS:
        dest=root/path
        original=dest.read_bytes()
        if b"\r\n" in original:
            raise ValueError("Expected byte-identical LF source: "+path)
        after=patch(path,original.decode("utf-8")).encode("utf-8")
        if after==original: raise RuntimeError("Inert diagnostic patch "+path)
        dest.write_bytes(after)
        records[path]={"original_sha256":digest(original),
                       "instrumented_sha256":digest(after),
                       "instrumentation_only":True}
    # This tool modifies only these exact paths, only within detached build worktrees.
    changed=set(filter(None,git(root,"diff","--name-only").splitlines()))
    if changed!=set(PATHS):
        raise RuntimeError("Unexpected source modification: "+repr(changed))
    return {"original_source_commit":source, "instrumented":True,
            "probe_kind":"Linux CLOCK_PROCESS_CPUTIME_ID/CLOCK_THREAD_CPUTIME_ID; process-window inclusive, owner exclusive",
            "patch_source_sha256":digest(Path(__file__).read_bytes()),
            "paths":records}

def main() -> None:
    parser=argparse.ArgumentParser()
    parser.add_argument("--baseline",required=True)
    parser.add_argument("--candidate",required=True)
    parser.add_argument("--out",required=True)
    args=parser.parse_args()
    base=Path(args.baseline)
    cand=Path(args.candidate)
    if git(base,"rev-parse","HEAD")!=BASE or git(cand,"rev-parse","HEAD")!=CANDIDATE_BUILD:
        raise RuntimeError("Actual baseline/candidate source commits do not match pinned selection")
    base_diff=set(filter(None,git(base,"diff","--name-only",BASE,CANDIDATE_BUILD,"--",
                                    "native/src","native/include","godot/native_extension","godot/scripts").splitlines()))
    expected_delta={
        "native/include/cybersand/pressure_optimization.hpp",
        "native/src/world_pressure.inc",
        "native/src/world_pressure_cache.inc",
        "native/src/world_pressure_cache_state.inc",
        "native/src/world_pressure_gas_cache.inc",
        "native/src/world_pressure_state.inc",
    }
    if base_diff!=expected_delta:
        raise RuntimeError("Unexpected production delta for PR532 gas-cache candidate: "+repr(base_diff))
    a=instrument(base,BASE)
    b=instrument(cand,CANDIDATE_BUILD)
    for path in PATHS:
        # Baseline and candidate are intentionally different only in the
        # optimized gas source; all other diagnostic bytes must be equal.
        if path not in {"native/src/world_pressure.inc","native/include/cybersand/pressure_optimization.hpp"} and a["paths"][path]["instrumented_sha256"]!=b["paths"][path]["instrumented_sha256"]:
            raise RuntimeError("Inconsistent diagnostic instrumented file "+path)
    out=Path(args.out)
    out.mkdir(parents=True,exist_ok=True)
    (out/"probe-patch-identities.json").write_text(json.dumps({"baseline":a,"candidate":b},
                                  indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("PF_GAS_DIAGNOSTIC_PATCH_IDENTICAL_PASS current-main baseline and #532 candidate")

if __name__=="__main__":
    main()
