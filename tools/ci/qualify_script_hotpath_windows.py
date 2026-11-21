#!/usr/bin/env python3
"""Exact-source Windows native-fill qualification; headless CI or rendered owner A/B.

Requires the cross-built candidate artifact, official pinned Godot 4.7 Windows
ZIP and pinned Windows Rapier DLL. Never substitutes a committed stale native
runtime for the candidate under test.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
GODOT_ARCHIVE_SHA512 = (
    "41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e"
    "6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9"
)
RAPIER_SHA256 = "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"
NATIVE = Path("godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll")
RAPIER = Path("godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")
SCRIPTS = {
    "differential": "res://tests/test_script_hotpath_native_fill.gd",
    "benchmark": "res://tests/bench_script_hotpath_native_fill.gd",
    "shapes": "res://tests/test_paint_editor_shapes.gd",
    "executor": "res://tests/test_paint_editor_executor.gd",
    "workbench": "res://tests/test_paint_editor_workbench.gd",
}
MARKERS = {
    "differential": "SCRIPT_HOTPATH_RESULT ",
    "benchmark": "SCRIPT_HOTPATH_BENCH_RESULT ",
    "shapes": "PAINT_EDITOR_SHAPES ",
    "executor": "PAINT_EXECUTOR ",
    "workbench": "PAINT_EDITOR_WORKBENCH ",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def record(result: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def check(condition: bool, reason: str) -> None:
    if not condition:
        raise RuntimeError(reason)


def read_marker(text: str, marker: str) -> dict:
    found = [line[len(marker):] for line in text.splitlines() if line.startswith(marker)]
    check(bool(found), "Required output marker missing: " + marker)
    return json.loads(found[-1])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--rendered", action="store_true",
                        help="Owner's real Windows desktop, not headless CI; enforces p95 acceptance")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = {
        "schema": "script-hotpath-windows-qualification-v1",
        "status": "incomplete", "source_sha": args.source_sha,
        "rendered": args.rendered, "platform": platform.platform(),
        "runs": [], "gpu_nonregression_certified": False,
    }
    try:
        os.chdir(ROOT)
        check(os.name == "nt", "Windows engine validation requires a Windows host")
        source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
        check(source_sha == args.source_sha, "Candidate source SHA differs from checkout HEAD")
        archive = args.archive.resolve()
        candidate = args.candidate.resolve()
        check(archive.is_file(), "Pinned Windows Godot archive is missing")
        check(hashlib.sha512(archive.read_bytes()).hexdigest() == GODOT_ARCHIVE_SHA512,
              "Official Godot 4.7 Windows ZIP SHA-512 mismatch")
        subprocess.run([sys.executable, "tools/ci/native_candidate_identity.py", str(candidate)],
                       check=True, timeout=120)
        dll = ROOT / NATIVE
        rapier = ROOT / RAPIER
        check(dll.is_file() and (dll.read_bytes()[:2] == b"MZ"), "Native Windows DLL missing or not PE")
        check(sha256(dll) == sha256(candidate / dll.name), "Installed native DLL differs from candidate")
        check(rapier.is_file() and sha256(rapier) == RAPIER_SHA256,
              "Required source-matched Rapier Windows dependency absent/mismatched")
        report["native_dll_sha256"] = sha256(dll)
        report["rapier_sha256"] = sha256(rapier)
        report["godot_archive_sha512"] = GODOT_ARCHIVE_SHA512
        root = output / "godot-4.7"
        if not root.exists():
            with zipfile.ZipFile(archive) as zip_file:
                check(zip_file.testzip() is None, "Godot archive corrupt")
                zip_file.extractall(root)
        godot = root / "Godot_v4.7-stable_win64_console.exe"
        check(godot.is_file(), "Official Godot Windows console executable missing")
        version = subprocess.check_output([str(godot), "--version"], text=True, timeout=90).strip()
        check(version == GODOT_VERSION, "Unexpected Godot version: " + version)
        report["godot_version"] = version
        report["godot_console_sha256"] = sha256(godot)

        def execute(label: str, mode: str, script: str | None, timeout: int) -> dict:
            environment = os.environ.copy()
            environment.pop("CYBERSAND_NATIVE_PAINT_FILL", None)
            if mode == "script":
                environment["CYBERSAND_NATIVE_PAINT_FILL"] = "script"
            data_root = output / "userdata" / label
            data_root.mkdir(parents=True, exist_ok=True)
            environment["APPDATA"] = str(data_root)
            environment["LOCALAPPDATA"] = str(data_root)
            command = [str(godot)]
            # Render Workbench only for owner-machine acceptance: hosted Windows
            # headless execution does not establish physical GPU frame delivery.
            if script != SCRIPTS["workbench"] or not args.rendered:
                command.append("--headless")
            command += ["--path", str(ROOT / "godot")]
            command += ["-s", script] if script is not None else ["--editor", "--import", "--quit"]
            started = time.monotonic()
            print("RUN", label, mode, " ".join(command), flush=True)
            try:
                completed = subprocess.run(command, env=environment, capture_output=True,
                                           text=True, errors="replace", timeout=timeout)
                output_text = completed.stdout + "\n" + completed.stderr
                exit_code = completed.returncode
            except subprocess.TimeoutExpired as exc:
                output_text = str(exc)
                exit_code = 124
            log = output / (label + ".log")
            log.write_text(output_text, encoding="utf-8")
            entry = {"label": label, "mode": mode, "script": script,
                     "seconds": round(time.monotonic() - started, 3),
                     "exit_code": exit_code, "log": log.name,
                     "log_sha256": sha256(log)}
            report["runs"].append(entry)
            record(report, output / "qualification.json")
            check(exit_code == 0, label + ": Godot returned " + str(exit_code))
            if script is not None:
                marker = MARKERS[next(key for key, val in SCRIPTS.items() if val == script)]
                if script == SCRIPTS["benchmark"]:
                    check("SCRIPT_HOTPATH_BENCH_RESULT PASS" in output_text,
                          label + ": compiled native benchmark failed")
                else:
                    payload = read_marker(output_text, marker)
                    check(isinstance(payload, dict), label + ": invalid JSON receipt")
                    check(payload.get("failures", []) == [] or payload.get("failures") == 0,
                          label + ": functional assertion failures")
                    check(int(payload.get("checks", 0)) > 0, label + ": no assertions executed")
                    entry["result"] = payload
            return entry

        execute("import", "native", None, 300)
        execute("differential-native", "native", SCRIPTS["differential"], 420)
        execute("differential-script", "script", SCRIPTS["differential"], 420)
        execute("benchmark-native", "native", SCRIPTS["benchmark"], 480)
        for mode in ["native", "script"]:
            for test in ["shapes", "executor"]:
                execute(test + "-" + mode, mode, SCRIPTS[test], 420)

        # ABBA + BAAB: 4 independent Workbench authoring runs per mode.
        # Report the actual observed p95/p99 and max without substituting the
        # p95 of eight maxima for the per-frame p95.
        order = ["native", "script", "script", "native",
                 "script", "native", "native", "script"]
        gaps: dict[str, list[int]] = {"native": [], "script": []}
        p99s: dict[str, list[int]] = {"native": [], "script": []}
        for index, mode in enumerate(order):
            entry = execute("workbench-%02d-%s" % (index + 1, mode), mode,
                            SCRIPTS["workbench"], 600)
            result = entry["result"]
            check(int(result.get("checks", 0)) >= 60, "Insufficient mounted Workbench checks")
            check(int(result.get("frame_samples", 0)) >= 10, "No useful frame sampling")
            gaps[mode].append(int(result["frame_gap_p95_usec"]))
            p99s[mode].append(int(result["frame_gap_p99_usec"]))
        native_p95 = statistics.median(gaps["native"])
        script_p95 = statistics.median(gaps["script"])
        ratio = (native_p95 / script_p95) if script_p95 > 0 else float("inf")
        report["pacing"] = {
            "status": "measured", "mode": "rendered-owner" if args.rendered else "headless-ci",
            "order": order, "p95_gap_usec": gaps, "p99_gap_usec": p99s,
            "median_of_workbench_frame_p95_native_usec": native_p95,
            "median_of_workbench_frame_p95_script_usec": script_p95,
            "native_over_script_p95_ratio": round(ratio, 5),
            "interpretation": "System-wide Workbench frame gaps; not a pure fill-planning latency or FPS metric",
        }
        report["status"] = "passed"
        # Rendered runs alone do not prove an actual discrete GPU was used.
        # Owner must inspect report + device identity and acceptance threshold.
        report["gpu_nonregression_certified"] = False
        if args.rendered:
            report["pacing"]["p95_advisory_within_10_percent"] = ratio <= 1.10
            report["status"] = "review-required" if ratio > 1.10 else "passed"
            report["pacing"]["gpu_adapter_confirmation_required"] = True
        record(report, output / "qualification.json")
        print("SCRIPT_HOTPATH_WINDOWS_RESULT ", json.dumps({
            "status": report["status"], "rendered": args.rendered,
            "source_sha": source_sha, "p95_ratio": ratio,
            "gpu_nonregression_certified": False,
        }), flush=True)
        return 0 if report["status"] == "passed" else 1
    except (RuntimeError, subprocess.CalledProcessError, OSError, ValueError, KeyError, zipfile.BadZipFile) as exc:
        report["status"] = "failed"
        report["error"] = "%s: %s" % (type(exc).__name__, exc)
        record(report, output / "qualification.json")
        print("SCRIPT_HOTPATH_WINDOWS_RESULT FAIL", report["error"], file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
