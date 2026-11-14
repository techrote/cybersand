#!/usr/bin/env python3
"""Apply the SAME temporary read-only CPU probe to two isolated Windows sources.

Requires unmodified pinned accepted-main and #504 source worktrees. This DOES
NOT commit changed World/protected bytes or publish production runtime assets.
Every edit is instrument-only; benchmark evidence lists these exact delta hashes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

BASE = "24a8bbe8ccf0d17196ebbab580b924930a964584"
CANDIDATE_BUILD = "b7f151f85676ffc6b2ea87f3e5c6165b890727e0"
CANDIDATE_PR = "186452b9f035961325ad71917a76ba8834e30bcf"

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
            "#if !defined(_WIN32)\n#error CYBERSAND_PF_GAS_CPU_PROBE requires Windows\n#endif\n"
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
            "#include <utility>\n\n#if defined(CYBERSAND_PF_GAS_CPU_PROBE)\n"
            "#ifndef NOMINMAX\n#define NOMINMAX\n#endif\n"
            "#ifndef WIN32_LEAN_AND_MEAN\n#define WIN32_LEAN_AND_MEAN\n#endif\n"
            "#include <windows.h>\n#endif\n", path)
    elif path == "native/src/world_pressure.inc":
        code = replace_one(code, "void World::prepare_pressure_tick() {",
            """// The following clock helpers are diagnostic-only and not used by simulation.
#ifdef CYBERSAND_PF_GAS_CPU_PROBE
namespace {
[[nodiscard]] std::uint64_t pf_probe_filetime_ns(FILETIME f) noexcept {
    const auto ticks100 = (static_cast<std::uint64_t>(f.dwHighDateTime) << 32U) |
                          static_cast<std::uint64_t>(f.dwLowDateTime);
    return ticks100 * 100U;
}
[[nodiscard]] std::uint64_t pf_probe_process_cpu_ns() noexcept {
    FILETIME create{}, exit{}, kernel{}, user{};
    if (!::GetProcessTimes(::GetCurrentProcess(), &create, &exit, &kernel, &user)) return 0U;
    return pf_probe_filetime_ns(kernel) + pf_probe_filetime_ns(user);
}
[[nodiscard]] std::uint64_t pf_probe_owner_cpu_ns() noexcept {
    FILETIME create{}, exit{}, kernel{}, user{};
    if (!::GetThreadTimes(::GetCurrentThread(), &create, &exit, &kernel, &user)) return 0U;
    return pf_probe_filetime_ns(kernel) + pf_probe_filetime_ns(user);
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
            "probe_kind":"Windows GetProcessTimes/GetThreadTimes; process-window inclusive, owner thread exclusive",
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
    if base_diff!={"native/src/world_pressure.inc"}:
        raise RuntimeError("Only production delta must be source-locked gas operator: "+repr(base_diff))
    a=instrument(base,BASE)
    b=instrument(cand,CANDIDATE_BUILD)
    for path in PATHS:
        # Baseline and candidate are intentionally different only in the
        # optimized gas source; all other diagnostic bytes must be equal.
        if path!="native/src/world_pressure.inc" and a["paths"][path]["instrumented_sha256"]!=b["paths"][path]["instrumented_sha256"]:
            raise RuntimeError("Inconsistent diagnostic instrumented file "+path)
    out=Path(args.out)
    out.mkdir(parents=True,exist_ok=True)
    (out/"probe-patch-identities.json").write_text(json.dumps({"baseline":a,"candidate":b},
                                  indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("PF_GAS_DIAGNOSTIC_PATCH_IDENTICAL_PASS C2048 baseline and #504 candidate")

if __name__=="__main__":
    main()
