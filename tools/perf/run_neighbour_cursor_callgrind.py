#!/usr/bin/env python3
"""Paired original/cursor instruction-level line/function attribution with Callgrind.

No privileged perf access required. Sampling is 16 early ticks (or explicit
--ticks 1..40), never a substitute for the 600/1800-tick wall-time campaign.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess

BASELINE = "4a80af2a891332176a3912a235582d77d076a185"
BASELINE_HASH = "5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d"
CANDIDATE_HASH = "bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868"
SOURCES = [
    "native/src/world.cpp", "native/src/material_rules.cpp",
    "native/src/scheduler_geometry.cpp", "native/src/settled_world_discovery.cpp"
]


def command(args, cwd, log, timeout=1500):
    args = [str(a) for a in args]
    run = subprocess.run(args, cwd=cwd, text=True, errors="replace",
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         timeout=timeout)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text("$ " + shlex.join(args) + "\n" + run.stdout +
                   "\nEXIT=" + str(run.returncode) + "\n", encoding="utf-8")
    if run.returncode:
        raise RuntimeError(f"exit {run.returncode}: {log}")
    return run.stdout


def sha_lf(file):
    return hashlib.sha256(file.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def save(file, content):
    file.write_text(json.dumps(content, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path("."))
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--candidate", default="HEAD")
    parser.add_argument("--ticks", type=int, default=16)
    opts = parser.parse_args()
    if not 1 <= opts.ticks <= 40:
        parser.error("profile ticks must be 1..40")
    root, out = opts.repo.resolve(), opts.out.resolve()
    out.mkdir(parents=True, exist_ok=True)

    if not shutil.which("valgrind") or not shutil.which("callgrind_annotate"):
        parser.error("Valgrind/Callgrind not installed (do not pretend profiling passed)")
    info = {"ticks": opts.ticks, "workload": "stress-canvas original 129 rectangles",
            "workers": 1, "benchmark_kind": "instrumented instructions, not wall time"}
    info["valgrind"] = command(["valgrind", "--version"], root, out / "valgrind-version.log").strip()
    info["compiler"] = command(["g++-13", "--version"], root, out / "compiler.log").splitlines()[0]
    harness = root / "tools/perf/callgrind_neighbour_cursor.cpp"
    fixture = root / "native/bench/data/neighbour_stress_rectangles.txt"
    info["apparatus_sha256"] = sha_lf(harness)
    info["fixture_sha256"] = sha_lf(fixture)
    source_summaries = {}

    for kind, commit in (("baseline", BASELINE), ("candidate", opts.candidate)):
        sha = command(["git", "rev-parse", f"{commit}^{{commit}}"], root,
                      out / (kind + "-revision.log")).strip()
        tree = out / ("src_" + kind)
        if tree.exists():
            raise RuntimeError(f"refuse to overwrite {tree}")
        command(["git", "worktree", "add", "--detach", tree, sha],
                root, out / (kind + "-worktree.log"))
        world_sha = sha_lf(tree / "native/src/world.cpp")
        expected_sha = BASELINE_HASH if kind == "baseline" else CANDIDATE_HASH
        if world_sha != expected_sha:
            raise RuntimeError(f"protected world.cpp identity unexpectedly changed: {world_sha}")
        binary = out / ("callgrind_" + kind)
        compilation = ["g++-13", "-std=c++20", "-O2", "-g",
                       "-fno-omit-frame-pointer", "-pthread",
                       "-I", tree / "native/include",
                       *[tree / p for p in SOURCES], harness, "-o", binary]
        command(compilation, tree, out / (kind + "-build.log"), timeout=1200)
        profile_file = out / ("profile_" + kind + ".callgrind")
        profile_command = ["valgrind", "--tool=callgrind", "--instr-atstart=no",
                           "--collect-jumps=no", "--cache-sim=no",
                           "--callgrind-out-file=" + str(profile_file),
                           "--", binary, fixture, opts.ticks]
        runlog = command(profile_command, tree, out / (kind + "-valgrind.log"), timeout=1500)
        receipt = next((json.loads(line) for line in runlog.splitlines()
                        if line.startswith('{"ticks":') and '"state_hash"' in line), None)
        if receipt is None:
            raise RuntimeError(f"missing profile run receipt: {kind}")
        annotation = command(["callgrind_annotate", "--auto=yes", "--show=Ir",
                              "--threshold=0.25", profile_file],
                             tree, out / (kind + "-annotation.log"), timeout=180)
        # Callgrind's "summary: 0" describes the no-instrumentation startup.
        # Actual instructions after CALLGRIND_START_INSTRUMENTATION live
        # in the final "totals: <Ir>" record, not the header summary.
        output = profile_file.read_text(encoding="utf-8", errors="replace")
        event = re.search(r"(?m)^events:\s+(\w+)", output)
        result = re.search(r"(?m)^totals:\s+(\d+)", output)
        if not event or event.group(1) != "Ir" or not result or int(result.group(1)) <= 0:
            raise RuntimeError(f"invalid Callgrind instruction event record for {kind}")
        source_summaries[kind] = {
            "source_commit": sha, "world_lf_sha256": world_sha,
            "receipt": receipt,
            "instruction_count_Ir": int(result.group(1)),
            "annotate_log": kind + "-annotation.log",
            "raw_profile": profile_file.name,
        }
        save(out / "partial.json", source_summaries)

    a, b = source_summaries["baseline"], source_summaries["candidate"]
    if a["receipt"] != b["receipt"]:
        raise RuntimeError("baseline/candidate profile-sample result mismatch")
    instruction_delta = a["instruction_count_Ir"] - b["instruction_count_Ir"]
    result = {
        "source": source_summaries,
        "sample_exact_hash_and_work_parity": True,
        "saved_instructions": instruction_delta,
        "fractional_instruction_reduction_percent":
            100.0 * instruction_delta / a["instruction_count_Ir"],
        "qualification_note":
            "Early-tick single-worker instruction-level diagnostic only; "
            "not perf sampling and not evidence of 5-10% runtime gain"
    }
    save(out / "summary.json", result)
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
