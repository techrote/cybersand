#!/usr/bin/env python3
"""PAINT-END2END-002 physical Windows/NVIDIA full-Fill evaluator.

Runs the real mounted Workbench and verifies the first changed post-draw
framebuffer. Source and candidate DLL must match the disposable checkout.
No headless GPU claims, no production LFS DLL publication, no auto-promotion.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SCENARIOS = {"16k": 128 * 128, "65k": 256 * 256, "262k": 512 * 512}
ORDER = ("control", "bulk4", "bulk4", "control",
         "bulk4", "control", "control", "bulk4")
MARKER = "PAINT_END2END_OWNER "
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
NATIVE_NAME = "cybersand_native.windows.x86_64.dll"
NATIVE = ROOT / "godot/addons/cybersand_native/bin" / NATIVE_NAME
RAPIER = ROOT / "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
RAPIER_SHA256 = "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise RuntimeError(reason)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def record(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, default=str) + "\n",
                    encoding="utf-8")


def parse_receipt(output: str) -> dict:
    lines = [line[len(MARKER):] for line in output.splitlines()
             if line.startswith(MARKER + "{")]
    require(len(lines) == 1, f"Exactly one full-Fill receipt required; found {len(lines)}")
    result = json.loads(lines[0])
    require(isinstance(result, dict), "Receipt is not a JSON object")
    return result


def validate_receipt(result: dict, scenario: str, mode: str) -> None:
    require(result.get("schema") == "paint-end2end-002-owner-visible-v1",
            "Unexpected receipt schema")
    require(result.get("scenario") == scenario and result.get("mode") == mode,
            "Fixture or requested variant mismatch")
    require(result.get("status") == "passed" and result.get("failures") == [],
            "Full-Fill fixture reported failure")
    require(result.get("rendered") is True and result.get("source_native") is True,
            "Only a real rendered native Workbench is admissible")
    require(result.get("display_server", "").lower() == "windows",
            "Not a physical Windows display server")
    require("nvidia" in result.get("active_graphics_adapter", "").lower(),
            "Actual Godot rendering adapter is not NVIDIA; GPU acceptance refused")
    require(result.get("bulk_capture_enabled") is (mode == "bulk4"),
            "Bulk capture environment mismatch")
    require(result.get("max_slices_per_cycle") == (4 if mode == "bulk4" else 1),
            "Worker step limit environment mismatch")
    require(result.get("requested_cells") == SCENARIOS[scenario]
            and result.get("applied") == SCENARIOS[scenario],
            "Expected connected material cell set not completely applied")
    require(result.get("image_pixel_changed") is True
            and result.get("raw_material_pixel_changed") is True,
            "Changed material and actual first drawn framebuffer both required")
    require(result.get("changed_world_screen_samples", 0) >= 32
            and result.get("world_screen_sample_count", 0) >= 256,
            "Insufficient independent visible pixel samples")
    require(result.get("render_attempts", 0) >= 1
            and result.get("first_visible_post_draw_usec", -1) >=
                result.get("first_post_draw_usec", 0),
            "No confirmed post-draw visible frame")
    require(result.get("frame_samples", 0) >= 3, "Rendered frame pacing not captured")
    for key in ("request_to_draw_usec", "request_to_receipt_usec",
                "frame_gap_p95_usec", "frame_gap_p99_usec", "frame_gap_max_usec",
                "edit_native_executor_usec"):
        require(type(result.get(key)) is int and result[key] > 0,
                "Missing positive measured duration: " + key)
    require(result["request_to_draw_usec"] >= result["request_to_receipt_usec"],
            "First visibly changed frame predates completion acknowledgement")


def summarize(rows: list[dict]) -> dict:
    control = [x["receipt"] for x in rows if x["mode"] == "control"]
    candidate = [x["receipt"] for x in rows if x["mode"] == "bulk4"]
    require(len(control) == len(candidate) == 4, "Balanced four-by-four A/B required")
    metrics = {}
    for field in ("request_to_draw_usec", "request_to_receipt_usec",
                  "edit_native_executor_usec", "frame_gap_p95_usec",
                  "frame_gap_p99_usec", "frame_gap_max_usec"):
        a = statistics.median(x[field] for x in control)
        b = statistics.median(x[field] for x in candidate)
        metrics[field] = {"control_median": a, "candidate_median": b,
                          "candidate_over_control": round(b / a, 6) if a else None}
    latency = metrics["request_to_draw_usec"]
    p95 = metrics["frame_gap_p95_usec"]
    p99 = metrics["frame_gap_p99_usec"]
    goal = (latency["candidate_median"] <= latency["control_median"] * .75
            and p95["candidate_median"] <= p95["control_median"] * 1.1
            and p99["candidate_median"] <= p99["control_median"] * 1.1)
    return {"metrics": metrics,
            "full_fill_latency_gain_fraction": round(
                1 - latency["candidate_median"] / latency["control_median"], 6),
            "preliminary_performance_goal_met": goal,
            "acceptance": "human-review-required-even-if-goal-met",
            "cautions": ["One rendered owner host is not a general gameplay/FPS result",
                         "Post-draw framebuffer readback is not physical scanout",
                         "Runs are independent, sequential, restored fresh canvases",
                         "Reported stage latencies are not assumed additive",
                         "Compare p99 and max tails, not just the median speedup"]}


def verify_setup(args: argparse.Namespace) -> dict:
    require(sys.platform == "win32", "A physical Windows owner workstation is required")
    require(os.environ.get("SESSIONNAME", "").lower() not in ("", "services"),
            "An interactive Windows desktop session is required")
    require(args.godot.is_file(), "Pinned Godot 4.7 console executable not found")
    version = subprocess.check_output([str(args.godot), "--version"],
                                      text=True, timeout=60).strip()
    require(version == GODOT_VERSION, "Godot version mismatch: " + version)
    source = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                                     text=True, timeout=30).strip()
    require(source == args.source_sha, "Source checkout commit mismatch")
    marker = ROOT / ".paint-end2end-002-disposable"
    require(marker.is_file() and marker.read_text(encoding="utf-8").strip() == source,
            "Refusing to install a test DLL outside the marked disposable checkout")
    dirty = subprocess.check_output(
        ["git", "-C", str(ROOT), "status", "--porcelain", "--untracked-files=no", "--",
         "godot/scripts", "godot/tests", "godot/native_extension", "native"],
        text=True, timeout=60).strip()
    require(not dirty, "Source/test/native inputs have tracked modifications: " + dirty)
    require(RAPIER.is_file() and sha256(RAPIER) == RAPIER_SHA256,
            "Pinned Windows Rapier DLL not restored from Git LFS")
    subprocess.run([sys.executable, str(ROOT / "tools/ci/native_candidate_identity.py"),
                    str(args.candidate)], cwd=ROOT, check=True, timeout=120)
    dll = args.candidate / NATIVE_NAME
    require(dll.is_file() and dll.read_bytes()[:2] == b"MZ",
            "Cross-built experimental Windows native DLL not found")
    expected_hash = sha256(dll)
    NATIVE.parent.mkdir(parents=True, exist_ok=True)
    # This writes ONLY inside the marked temporary clone, not the user's actual
    # Workbench folder or the repository's retained production LFS object.
    shutil.copy2(dll, NATIVE)
    require(sha256(NATIVE) == expected_hash, "Installed temporary DLL digest mismatch")
    return {"source_sha": source, "godot_version": version,
            "godot_sha256": sha256(args.godot),
            "candidate_dll_sha256": expected_hash, "rapier_sha256": RAPIER_SHA256,
            "host": platform.platform()}


def run(args: argparse.Namespace) -> int:
    args.candidate = args.candidate.resolve()
    args.godot = args.godot.resolve()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    scenarios = tuple(SCENARIOS) if args.scenario == "all" else (args.scenario,)
    report = {"schema": "paint-end2end-002-windows-owner-v1",
              "status": "incomplete", "runner": "physical-windows-nvidia",
              "source_sha": args.source_sha, "order": list(ORDER),
              "scenarios": list(scenarios), "runs": [], "results": {},
              "no_production_publication": True}
    report_path = args.output / "qualification.json"
    try:
        report["custody"] = verify_setup(args)
        record(report_path, report)
        # A fresh immutable source checkout has no Godot import/class cache.
        # Build it from the same exact-source DLL before running any fixture.
        import_root = args.output / "userdata" / "import"
        (import_root / "Roaming").mkdir(parents=True, exist_ok=True)
        (import_root / "Local").mkdir(parents=True, exist_ok=True)
        import_env = os.environ.copy()
        import_env["APPDATA"] = str(import_root / "Roaming")
        import_env["LOCALAPPDATA"] = str(import_root / "Local")
        import_env.pop("CYBERSAND_PAINT_BURST_SLICES", None)
        import_env.pop("CYBERSAND_PAINT_BULK_CAPTURE", None)
        imported = subprocess.run(
            [str(args.godot), "--headless", "--editor", "--path", str(ROOT / "godot"), "--import"],
            env=import_env, cwd=ROOT, capture_output=True, text=True,
            errors="replace", timeout=300)
        import_log = args.output / "godot-import.log"
        import_log.write_text(imported.stdout + "\n" + imported.stderr, encoding="utf-8")
        report["import"] = {"exit_code": imported.returncode,
                            "log_sha256": sha256(import_log), "log": import_log.name}
        record(report_path, report)
        require(imported.returncode == 0, "Godot exact-source editor import failed")
        for scenario in scenarios:
            completed = []
            for index, mode in enumerate(ORDER, start=1):
                label = f"{scenario}-{index:02d}-{mode}"
                log_path = args.output / (label + ".log")
                env = os.environ.copy()
                env.pop("CYBERSAND_NATIVE_PAINT_FILL", None)
                env.pop("CYBERSAND_PAINT_TEST_GATES", None)
                env["FILL_TOTAL_CASE"] = scenario
                env["FILL_TOTAL_CAPTURE_DIR"] = str(args.output / ("failed-" + label))
                env["CYBERSAND_PAINT_BULK_CAPTURE"] = "1" if mode == "bulk4" else "0"
                env["CYBERSAND_PAINT_BURST_SLICES"] = "4" if mode == "bulk4" else "1"
                env["CYBERSAND_PAINT_BURST_BUDGET_USEC"] = "6000"
                env["CYBERSAND_PAINT_BURST_PROFILE"] = "1"
                data = args.output / "userdata" / label
                (data / "Roaming").mkdir(parents=True, exist_ok=True)
                (data / "Local").mkdir(parents=True, exist_ok=True)
                env["APPDATA"] = str(data / "Roaming")
                env["LOCALAPPDATA"] = str(data / "Local")
                command = [str(args.godot), "--rendering-method", "gl_compatibility",
                           "--audio-driver", "Dummy", "--path", str(ROOT / "godot"),
                           "-s", "res://tests/bench_paint_end2end_002_owner.gd"]
                started = time.monotonic()
                print("PAINT_END2END_OWNER_RUN", label, flush=True)
                try:
                    proc = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                                          text=True, errors="replace", timeout=600)
                    captured = proc.stdout + "\n" + proc.stderr
                    exit_code = proc.returncode
                except subprocess.TimeoutExpired as exc:
                    captured = str(exc)
                    exit_code = 124
                log_path.write_text(captured, encoding="utf-8")
                item = {"scenario": scenario, "mode": mode, "index": index,
                        "label": label, "duration_seconds": round(time.monotonic()-started, 3),
                        "exit_code": exit_code, "log": log_path.name,
                        "log_sha256": sha256(log_path)}
                try:
                    require(exit_code == 0, f"{label} exited with {exit_code}")
                    receipt = parse_receipt(captured)
                    validate_receipt(receipt, scenario, mode)
                    item["receipt"] = receipt
                    print("PAINT_END2END_OWNER_CASE_PASS", label,
                          round(receipt["request_to_draw_usec"]/1000, 3), "ms", flush=True)
                except (RuntimeError, KeyError, ValueError) as exc:
                    item["error"] = str(exc)
                    report["runs"].append(item)
                    report["status"] = "failed"
                    record(report_path, report)
                    raise
                report["runs"].append(item)
                completed.append(item)
                record(report_path, report)
            report["results"][scenario] = summarize(completed)
            record(report_path, report)
        report["status"] = "evidence-captured"
        report["disposition"] = "HOLD pending independent assessment and owner acceptance"
        record(report_path, report)
        print("PAINT_END2END_OWNER_RESULT", json.dumps({
            "status": report["status"], "source_sha": args.source_sha,
            "scenarios": report["results"]}, sort_keys=True), flush=True)
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        report["status"] = "failed"
        report["error"] = f"{type(exc).__name__}: {exc}"
        record(report_path, report)
        print("PAINT_END2END_OWNER_RESULT FAIL", report["error"], file=sys.stderr, flush=True)
        return 1
    finally:
        # Preserve negative results too, including raw failure logs and screenshots.
        archive = args.output.parent / (args.output.name + "-evidence.zip")
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as out:
            for path in sorted(args.output.rglob("*")):
                if path.is_file() and "userdata" not in path.relative_to(args.output).parts:
                    out.write(path, path.relative_to(args.output))


def self_test() -> None:
    fixture = {"schema":"paint-end2end-002-owner-visible-v1",
               "scenario":"262k","mode":"control", "status":"passed",
               "rendered":True,"source_native":True,
               "display_server":"windows","active_graphics_adapter":"NVIDIA TEST",
               "bulk_capture_enabled":False,"max_slices_per_cycle":1,
               "requested_cells":262144,"applied":262144,"image_pixel_changed":True,
               "raw_material_pixel_changed":True,"changed_world_screen_samples":64,
               "world_screen_sample_count":256,"render_attempts":1,
               "first_visible_post_draw_usec":20,"first_post_draw_usec":10,
               "frame_samples":20,"request_to_draw_usec":2000000,
               "request_to_receipt_usec":1500000,"frame_gap_p95_usec":16000,
               "frame_gap_p99_usec":18000,"frame_gap_max_usec":20000,
               "edit_native_executor_usec":1500000,"failures":[]}
    validate_receipt(fixture,"262k","control")
    trials=[]
    for mode in ORDER:
        row=dict(fixture,mode=mode,bulk_capture_enabled=mode=="bulk4",
                 max_slices_per_cycle=4 if mode=="bulk4" else 1,
                 request_to_draw_usec=1400000 if mode=="bulk4" else 2000000)
        validate_receipt(row,"262k",mode)
        trials.append({"mode":mode,"receipt":row})
    assert summarize(trials)["preliminary_performance_goal_met"]
    malformed=dict(fixture,active_graphics_adapter="Microsoft Basic Render")
    try:
        validate_receipt(malformed,"262k","control")
    except RuntimeError:
        pass
    else:
        raise AssertionError("Software renderer unexpectedly accepted")
    assert parse_receipt(MARKER+json.dumps(fixture))["requested_cells"] == 262144
    print("PAINT_END2END_002_OWNER_RUNNER_SELFTEST_PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--source-sha")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--scenario", choices=(*SCENARIOS, "all"), default="262k")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    else:
        for key in ("godot", "candidate", "source_sha", "output"):
            require(getattr(args, key) is not None, "Required argument missing: " + key)
        raise SystemExit(run(args))
