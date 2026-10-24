#!/usr/bin/env python3
"""Alternate independent control/candidate cases on one host; preserve failures."""

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import platform
import shutil
import socket
import subprocess
import sys

import run_godot_regressions as runner
from stress_physical_actors import SUSPECTS, current_host, progress_phase
from rapier_candidate_identity import verify


def hardware():
    info = {"logical_processors": os.cpu_count(), "processor": platform.processor()}
    if sys.platform == "win32":
        command = "Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | ConvertTo-Json -Compress"
        raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", command], text=True, timeout=15)
        processors = json.loads(raw)
        if isinstance(processors, dict):
            processors = [processors]
        info.update(processors=processors, physical_cores=sum(p["NumberOfCores"] for p in processors))
    else:
        processors = [dict(line.split(":", 1) for line in block.splitlines() if ":" in line)
                      for block in Path("/proc/cpuinfo").read_text().split("\n\n") if block.strip()]
        processors = [{k.strip(): v.strip() for k, v in p.items()} for p in processors]
        cores = {(p.get("physical id"), p.get("core id")) for p in processors}
        info.update(physical_cores=len(cores), processor=processors[0].get("model name"),
                    affinity=sorted(os.sched_getaffinity(0)))
    if info["physical_cores"] < 2:
        raise RuntimeError("The paired host must expose at least two physical cores to exercise the parallel join")
    return info


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--control-build", type=Path, required=True)
    parser.add_argument("--patched-build", type=Path, required=True)
    parser.add_argument("--batch", type=int, required=True)
    parser.add_argument("--host", choices=("windows", "linux"), required=True)
    args = parser.parse_args()
    if args.host != current_host() or args.batch not in range(5):
        parser.error("host must match this OS and batch must be between 0 and 4")
    root, output = runner.ROOT, args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    host = hardware()
    print("Pair host hardware:", json.dumps(host), flush=True)
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    files = subprocess.check_output(["git", "ls-files", "-z"], cwd=root, text=True).split("\0")
    fixture_files = [p for p in files if p and not p.startswith("godot/.godot/")
                     and Path(p).suffix in (".gd", ".godot", ".tscn", ".tres", ".gdextension", ".json")]

    def fixture_inputs(project):
        return {p: runner.sha256(project / p) for p in fixture_files}
    projects, reports = {}, {}
    if sys.platform == "win32":
        from run_windows_godot_regressions import verify_retained_runtime
        verify_retained_runtime(root)
    godot_version = subprocess.check_output([args.godot, "--version"], text=True, timeout=30).strip()
    for variant, build in (("control", args.control_build), ("patched", args.patched_build)):
        project = output / (variant + "-source")
        project.mkdir()
        # Include repository-level recipes too: a project-only copy is not a
        # complete fixture snapshot. Never copy ignored caches or build output.
        for relative in filter(None, files):
            target = project / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / relative, target)
        manifest = build / "rapier-build.json"
        data = json.loads(manifest.read_text(encoding="utf-8"))
        filename = "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if sys.platform == "win32" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
        shutil.copy2(build / filename, project / "godot/addons/godot-rapier2d/bin" / filename)
        if sys.platform == "win32":
            shutil.copy2(build / "godot_rapier.pdb", project / "godot/addons/godot-rapier2d/bin/godot_rapier.pdb")
        verified = verify(project, manifest)
        if verified["variant"] != variant:
            raise RuntimeError("Swapped pair variants")
        runner.ROOT = project
        native, rapier = runner.runtime_paths()
        identity = {"source_sha": source, "platform": platform.platform(), "python": platform.python_version(),
                    "host": args.host, "batch": args.batch, "variant": variant,
                    "godot_version": godot_version, "native_sha256": runner.sha256(native), "rapier_sha256": runner.sha256(rapier),
                    "rapier_build": data, "run_id": os.environ.get("GITHUB_RUN_ID"), "attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
                    "paired_protocol": "same-host-alternating-v1", "pair_host_id": socket.gethostname(),
                    "pair_batch": args.batch, "hardware": host, "fixture_inputs": fixture_inputs(project)}
        reports[variant] = {"identity": identity, "iterations_requested": 10, "completed": False,
                            "input_verification_complete": False, "preflight_passed": False, "results": []}
        projects[variant] = project
        (output / variant).mkdir()

    def save(variant):
        report = reports[variant]
        results = report["results"]
        report["counts"] = {name: dict(Counter(r["status"] for r in results if r["name"] == name)) for name in SUSPECTS}
        report["timeouts_by_phase"] = dict(Counter(r["name"] + "/" + progress_phase(r)
                                                  for r in results if r["status"] == "timeout"))
        report["completed"] = (report["input_verification_complete"] and report["preflight_passed"]
                               and len(results) == 10 * len(SUSPECTS) and not report.get("input_drift"))
        runner.write_json(output / variant / "stress.json", report)

    preflight_failed = False
    for variant in ("control", "patched"):
        runner.ROOT = projects[variant]
        record, failed = runner.run_case(args.godot, runner.Case("import", ("--editor", "--quit"), 240, 3), output / variant, "preflight")
        runner.write_json(output / variant / "preflight.json", record)
        reports[variant]["preflight_passed"] = not failed
        save(variant)
        preflight_failed |= failed
    if preflight_failed:
        return 1
    cases = {c.name: c for c in runner.discover_cases(root)}
    for iteration in range(10):
        order = ("control", "patched") if (iteration + args.batch) % 2 == 0 else ("patched", "control")
        for name in SUSPECTS:
            for position, variant in enumerate(order):
                runner.ROOT = projects[variant]
                directory = output / variant / f"iteration-{iteration:03d}"
                directory.mkdir(exist_ok=True)
                record, _ = runner.run_case(args.godot, cases[name], directory, "case")
                record.update(iteration=iteration, pair_position=position)
                reports[variant]["results"].append(record)
                save(variant)
        print("Pair", args.batch, iteration, {v: reports[v]["counts"] for v in reports}, flush=True)
    for variant in ("control", "patched"):
        runner.ROOT = projects[variant]
        native, rapier = runner.runtime_paths()
        identity = reports[variant]["identity"]
        after = fixture_inputs(projects[variant])
        reports[variant]["input_drift"] = [p for p in fixture_files if identity["fixture_inputs"][p] != after[p]]
        if runner.sha256(native) != identity["native_sha256"] or runner.sha256(rapier) != identity["rapier_sha256"]:
            reports[variant]["input_drift"].append("runtime")
        reports[variant]["input_verification_complete"] = True
        save(variant)
    return int(any(not report["completed"] or any(r["status"] != "passed" for r in report["results"]) for report in reports.values()))


if __name__ == "__main__":
    raise SystemExit(main())
