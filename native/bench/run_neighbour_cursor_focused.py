#!/usr/bin/env python3
"""Source-pinned exactness-only test. Never modifies the reference/candidate trees.

Runs the SAME focused fixture against native #406 and #471 sources, both worker
counts, covering signed seams, masked contact and reentry, chunk preparation,
non-power-of-two geometry and the 8-bit update epoch wrapping past tick 256.
Never interprets these executions as performance measurements.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

REFERENCE = "4a80af2a891332176a3912a235582d77d076a185"
BASELINE_LF = "5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d"
CANDIDATE_LF = "bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868"
SOURCES = ["native/src/world.cpp", "native/src/material_rules.cpp",
           "native/src/scheduler_geometry.cpp", "native/src/settled_world_discovery.cpp"]
CASES = ["seams128", "seams192", "masked128", "epochs192"]
WORKERS = (1, 6)


def run(cmd, root, logfile, timeout=1200, env=None, allow_failure=False):
    logfile.parent.mkdir(parents=True, exist_ok=True)
    command = [str(arg) for arg in cmd]
    proc = subprocess.run(command, cwd=root, env=env, text=True, errors="replace",
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    logfile.write_text("$ " + shlex.join(command) + "\n" + proc.stdout +
                       "\nEXIT=" + str(proc.returncode) + "\n", encoding="utf-8")
    if proc.returncode and not allow_failure:
        raise RuntimeError(f"{command[0]} exited {proc.returncode}; see {logfile}")
    return proc


def sha_lf(path):
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def compile_case(root, tree, source, output, flags, label, verify):
    output.parent.mkdir(parents=True, exist_ok=True)
    command = ["g++-13", "-std=c++20", "-pthread", "-Wall", "-Wextra",
               "-g", "-fno-omit-frame-pointer", *flags]
    if verify:
        command.append("-DCYBERSAND_VERIFY_LOCAL_NEIGHBOUR")
    command += ["-I", tree / "native/include", *[tree / p for p in SOURCES],
                source, "-o", output]
    run(command, tree, root / ("compile_" + label + ".log"), timeout=1200)


def replay(binary, tree, resultdir, scenario, workers, ticks, suffix):
    name = f"{suffix}_{scenario}_{workers}w_{ticks}ticks"
    proc = run([binary, scenario, workers, ticks], tree,
               resultdir / (name + ".log"), timeout=360)
    try:
        outcome = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"{name}: not a valid JSON replay") from exc
    if (outcome.get("scenario"), outcome.get("workers"), outcome.get("ticks")) != (
            scenario, workers, ticks):
        raise AssertionError(f"{name}: fixture identity mismatch")
    expected_ticks = [1, 2, 16, 31, 32, 33, 63, 64, 65, 127, 128, 129,
                      150, 255, 256, 257, 300]
    if ticks == 520:
        expected_ticks += [383, 384, 385, 450, 511, 512, 513, 520]
    if [cp["tick"] for cp in outcome["checkpoints"]] != expected_ticks:
        raise AssertionError(f"{name}: missing exact state checkpoints")
    if len(outcome["work_per_tick"]) != ticks:
        raise AssertionError(f"{name}: incomplete per-tick counters")
    dump(resultdir / (name + ".json"), outcome)
    return outcome


def exactness_label(expected, received):
    keys = ("checkpoints", "work_per_tick", "visited_total", "moved_total", "cores_total")
    unequal = [key for key in keys if expected[key] != received[key]]
    return unequal


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", type=Path, default=Path("."))
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--baseline", default=REFERENCE)
    ap.add_argument("--candidate", default="HEAD")
    ap.add_argument("--asan", action="store_true")
    ap.add_argument("--tsan", action="store_true")
    args = ap.parse_args()
    root, out = args.repo.resolve(), args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source = root / "native/bench/neighbour_cursor_focused.cpp"
    if not source.is_file():
        ap.error("source fixture missing from current checkout")
    heads = {}
    trees = {}
    for label, rev in (("baseline", args.baseline), ("candidate", args.candidate)):
        resolved = run(["git", "rev-parse", f"{rev}^{{commit}}"],
                       root, out / ("rev_" + label + ".log")).stdout.strip()
        heads[label] = resolved
        target = out / ("tree_" + label)
        if target.exists():
            raise RuntimeError(f"refusing to overwrite worktree {target}")
        run(["git", "worktree", "add", "--detach", target, resolved],
            root, out / ("tree_" + label + ".log"))
        trees[label] = target

    observed = {name: sha_lf(trees[name] / "native/src/world.cpp") for name in trees}
    if observed != {"baseline": BASELINE_LF, "candidate": CANDIDATE_LF}:
        raise RuntimeError(f"unexpected protected-source identities {observed}")
    machine = {
        "heads": heads, "world_lf_sha256": observed,
        "fixture_sha256": sha_lf(source),
        "compiler": run(["g++-13", "--version"], root,
                        out / "compiler.log").stdout.splitlines()[0],
        "logical_processors": os.cpu_count(),
        "flags": ["-O2", "-g", "-fno-omit-frame-pointer"],
        "cases": CASES, "workers": WORKERS,
        "cycles": 520, "scope": "exactness only, no speedup inference"
    }
    dump(out / "machine.json", machine)

    binaries = {}
    for label in ("baseline", "candidate"):
        binary = out / ("focused_" + label)
        compile_case(out, trees[label], source, binary, ["-O2"], label,
                     label == "candidate")
        binaries[label] = binary

    all_rows = {}
    problems = []
    for case in CASES:
        for label in ("baseline", "candidate"):
            for workers in WORKERS:
                record = replay(binaries[label], trees[label], out / "replay",
                                case, workers, 520, label)
                all_rows[(case, label, workers)] = record
        expected = all_rows[(case, "baseline", 1)]
        for label in ("baseline", "candidate"):
            for workers in WORKERS:
                other = all_rows[(case, label, workers)]
                mismatch = exactness_label(expected, other)
                if mismatch:
                    problems.append({"case": case, "label": label, "workers": workers,
                                     "mismatched_fields": mismatch})
        dump(out / "parity.json", {"source_heads": heads, "problems": problems,
                                   "finished_cases": case})
    if problems:
        raise RuntimeError(f"cross-build / cross-worker exactness failure: {problems}")

    sanitizer = []
    for kind, enabled, flags in (
            ("asan_ubsan", args.asan, ["-O1", "-fsanitize=address,undefined"]),
            ("tsan", args.tsan, ["-O1", "-fsanitize=thread"])):
        if not enabled:
            continue
        binary = out / ("focused_" + kind)
        compile_case(out, trees["candidate"], source, binary, flags, kind, True)
        cases = CASES if kind == "asan_ubsan" else ["seams192", "masked128"]
        worker_options = WORKERS if kind == "asan_ubsan" else (6,)
        for case in cases:
            for workers in worker_options:
                env = os.environ.copy()
                if kind == "asan_ubsan":
                    env["ASAN_OPTIONS"] = "detect_leaks=1:halt_on_error=1"
                    env["UBSAN_OPTIONS"] = "halt_on_error=1"
                result = replay(binary, trees["candidate"], out / "sanitizers",
                                case, workers, 520, kind)
                mismatch = exactness_label(all_rows[(case, "candidate", workers)], result)
                sanitizer.append({"kind": kind, "case": case, "workers": workers,
                                  "mismatched_fields": mismatch})
                dump(out / "sanitizers.json", sanitizer)
                if mismatch:
                    raise RuntimeError(f"{kind} changed deterministic result: {mismatch}")

    summary = {
        "decision": "focused exactness pass only; performance gate separate",
        "source_heads": heads, "case_count": len(CASES),
        "full_replays": len(all_rows), "each_replay_ticks": 520,
        "worker_parity_pass": True, "candidate_baseline_parity_pass": True,
        "sanitizer_runs": sanitizer, "problems": problems
    }
    dump(out / "summary.json", summary)
    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
