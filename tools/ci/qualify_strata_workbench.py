#!/usr/bin/env python3
"""Source-bound ordinary Workbench Strata graphical and fresh-process campaign.

Retained native provenance is verified without rewriting its build identity.
Every invocation has a new output directory and original process/log/result
receipts. This is scoped Draft qualification, not a replacement for release CI.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import qualify_workbench_landscapes as custody
import strata_process_metrics as process_metrics

SCENES = ("industrial-assembly", "arcology", "cavern")
HARNESS = "res://tools/qualify_workbench_strata.gd"
MAXIMUM_HARNESS = "res://tools/qualify_workbench_strata_maximum.gd"
EXTRA_INPUTS = (
    "tools/ci/qualify_strata_workbench.py", "tools/ci/test_strata_qualification.py",
    "tools/ci/test_strata_campaign_custody.py", "tools/ci/strata_process_metrics.py",
    "tools/ci/test_strata_process_metrics.py",
    "tools/package_strata_workbench.py", ".github/workflows/strata-theatre-workbench.yml",
)
GODOT_SHA256 = {
    "linux": "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75",
    "win32": "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
}
GODOT_GUI_SHA256 = "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"
require, sha, write_json = custody.require, custody.sha, custody.write_json


def identity(allow_delta: bool = False) -> dict:
    result = custody.source_identity(allow_delta)
    for name in EXTRA_INPUTS:
        path = ROOT / name
        require(path.is_file() and not path.is_symlink(), "Missing qualification input: " + name)
        data = path.read_bytes().replace(b"\r\n", b"\n")
        digest = hashlib.sha256(data).hexdigest()
        result["source_inputs_sha256"][name] = digest
        try:
            committed = custody.git("show", "HEAD:" + name)
        except subprocess.CalledProcessError:
            committed = b""
        if data != committed and name not in result["local_delta"]:
            result["local_delta"].append(name)
    result["local_delta"].sort()
    require(allow_delta or not result["local_delta"], "Commit qualification source changes before frozen execution")
    return result



def instance_id(value) -> bool:
    # RefCounted IDs set the high bit and appear as signed int64 in GDScript.
    # Decimal strings preserve all64bits across JSON consumers.
    return (isinstance(value, str) and re.fullmatch(r"-?[1-9][0-9]{0,18}", value) is not None
            and -(1 << 63) <= int(value) < (1 << 63))

def validate_result(result: dict, scene: str, phase: str, source: str) -> None:
    """Read actual witnesses independently of the GDScript assertions."""
    require(result.get("schema") == "strata-workbench-execution-v1", "Wrong Strata execution schema")
    require(result.get("completed") is True and result.get("failures") == []
            and isinstance(result.get("checks"), int) and result["checks"] > 0,
            "Incomplete or failing Strata execution")
    require(result.get("scene") == scene and result.get("phase") == phase
            and result.get("source_revision") == source, "Strata execution identity mismatch")
    require(result.get("display_server") in ("X11", "Wayland", "Windows")
            and result.get("rendering_method") == "gl_compatibility", "Actual graphical rendering was not established")
    require(result.get("ordinary_workbench") is True, "Standalone depth is not ordinary Workbench qualification")
    require(set(result.get("plane_native_hashes", {})) == {"play", "scripted", "effects", "background"},
            "Missing a native material plane readback")
    for digest in result["plane_native_hashes"].values():
        require(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest), "Invalid native plane digest")
    require(result.get("world_count") == {"play_borrowed": 1, "decorative_owned": 3},
            "Wrong native ownership cardinality")
    require(re.fullmatch(r"[0-9a-f]{64}", str(result.get("save", {}).get("sha256", "")))
            and isinstance(result["save"].get("path"), str) and result["save"]["path"], "No authored composition save identity")
    if phase == "install":
        transitions = result.get("transitions", [])
        require(len(transitions) >= 12, "Insufficient mode/lifecycle transitions")
        for entry in transitions:
            before, after = entry.get("before", {}), entry.get("after", {})
            for key in ("world_generation", "physical_epoch", "worker_id", "actor_session_id", "actor_body_ids"):
                require(key in before and before[key] == after.get(key), "Presentation replaced play authority: " + key)
                if key in ("world_generation", "physical_epoch"):
                    require(type(before[key]) is int and before[key] > 0, "Invalid actual play identity: " + key)
                elif key != "actor_body_ids":
                    require(instance_id(before[key]), "Invalid exact actual instance identity: " + key)
            require(isinstance(before.get("actor_body_ids"), list) and before["actor_body_ids"]
                    and all(instance_id(value) for value in before["actor_body_ids"]), "Identity witness has no exact actual actor body")
        require(type(result.get("edit_readback", {}).get("material")) is int
                and 0 < result["edit_readback"]["material"] <= 255
                and re.fullmatch(r"[0-9a-f]{64}", str(result["edit_readback"].get("play_hash_before", "")))
                and result["edit_readback"].get("target_after") == result["edit_readback"].get("material")
                and result["edit_readback"].get("play_hash_before") == result["edit_readback"].get("play_hash_after"),
                "Decorative edit lacks actual target/read-only play witnesses")
        guards = result.get("refusals", {})
        for key in ("locked", "hidden", "outside", "invalid_document", "stale_generation"):
            require(guards.get(key) is True, "Missing reason-specific refusal: " + key)
        require(result.get("undo_redo", {}).get("undo_native") is True
                and result["undo_redo"].get("redo_native") is True, "Per-plane history lacks native readback")
        transforms = result.get("transforms", {})
        require(transforms.get("samples", 0) >= 24 and 0 <= transforms.get("max_error", -1) < 0.01,
                "Coordinate coverage/roundtrip failed")
        require(len(result.get("cost_samples", [])) >= 3, "Missing matched disabled/flat/stack observation")
    else:
        require(result.get("fresh_process_reopen") is True, "Reopen did not use the authored composition loader")


def validate_maximum(result: dict, source: str) -> None:
    require(result.get("schema") == "strata-maximum-execution-v1" and result.get("completed") is True
            and result.get("failures") == [] and result.get("checks", 0) > 0 and result.get("source_revision") == source,
            "Maximum extent execution is incomplete, failed or unbound")
    require(type(result.get("process_id")) is int and result["process_id"] > 0, "Maximum lacks actual engine PID")
    require(result.get("ordinary_workbench") is True and result.get("extent") == [2048,2048]
            and result.get("display_server") in ("X11", "Wayland", "Windows")
            and result.get("rendering_method") == "gl_compatibility", "Maximum extent was not actually rendered in ordinary Workbench")
    require(result.get("world_count") == {"play_borrowed":1, "decorative_owned":3}, "Maximum extent has wrong native ownership")
    before, after = (result.get("identity", {}).get(key, {}) for key in ("before", "after"))
    for key in ("world_generation", "physical_epoch", "worker_id", "actor_session_id", "actor_body_ids"):
        require(key in before and before[key] == after.get(key), "Maximum extent changed live play identity")
    require(all(type(before[k]) is int and before[k] > 0 for k in ("world_generation", "physical_epoch"))
            and all(instance_id(before[k]) for k in ("worker_id", "actor_session_id"))
            and isinstance(before["actor_body_ids"], list) and before["actor_body_ids"]
            and all(instance_id(x) for x in before["actor_body_ids"]),
            "Maximum extent lacks exact actual World and actor instance IDs")
    require(re.fullmatch(r"[0-9a-f]{64}", str(result.get("play_hash_before", "")))
            and result.get("play_hash_after") == result["play_hash_before"], "Maximum extent edits changed Play materials")
    planes = result.get("planes", {})
    require(set(planes) == {"scripted", "effects", "background"}, "Maximum extent omits a native plane")
    for plane in planes.values():
        require(plane.get("extent") == [2048,2048] and plane.get("native_material") == 131
                and type(plane.get("pixel_delta")) in (int, float) and math.isfinite(plane["pixel_delta"])
                and plane["pixel_delta"] > 0.025 and instance_id(plane.get("owner")),
                "Maximum plane dimensions, native material or actual pixel witness is absent")
    require(result.get("teardown", {}).get("native_world_count") == 0
            and result.get("teardown", {}).get("pending_native_world_count") == 0, "Maximum owners did not retire")


def verify_resource_receipt(folder: Path, case: dict, engine_pid: int | None = None) -> None:
    path = folder / case["label"] / "resources.json"
    require(sha(path) == case.get("resources_sha256"), "Original resource samples changed")
    raw = json.loads(path.read_text(encoding="utf-8"))
    require(raw.get("schema") == "strata-process-resources-v1" and raw.get("root_pid") == case["pid"]
            and {k:v for k,v in raw.items() if k != "samples"} == case.get("resources"), "Resource receipt differs from original samples")
    latest, sampled_pids = {}, set()
    peak_rss = 0
    samples = raw.get("samples", [])
    require(isinstance(samples, list) and len(samples) == raw.get("sample_count"), "Resource sample count differs from original rows")
    for sample in samples:
        rss = 0
        for row in sample.get("processes", []):
            require(type(row.get("pid")) is int and row["pid"] > 0 and type(row.get("start_id")) is int
                    and row["start_id"] > 0 and type(row.get("rss_bytes")) is int and row["rss_bytes"] >= 0
                    and type(row.get("cpu_seconds")) in (int, float) and math.isfinite(row["cpu_seconds"])
                    and row["cpu_seconds"] >= 0, "Malformed observed process counter")
            key = (row["pid"], row["start_id"])
            require(row["cpu_seconds"] >= latest.get(key, 0), "Observed process CPU counter regressed")
            latest[key] = row["cpu_seconds"]
            sampled_pids.add(row["pid"])
            rss += row["rss_bytes"]
        require(sample.get("tree_rss_bytes") == rss and math.isclose(sample.get("tree_cpu_seconds_observed", -1),
                sum(latest.values()), rel_tol=1e-9, abs_tol=1e-9), "Resource sample aggregate differs from actual process rows")
        peak_rss = max(peak_rss, rss)
    require(raw.get("process_identities") == [list(key) for key in sorted(latest)]
            and raw.get("peak_observed_tree_rss_bytes") == peak_rss
            and type(raw.get("observed_cpu_seconds")) in (int, float) and math.isfinite(raw["observed_cpu_seconds"])
            and math.isclose(raw["observed_cpu_seconds"], sum(latest.values()), rel_tol=1e-9, abs_tol=1e-9),
            "Resource summary differs from actual sampled counters")
    if engine_pid is not None:
        require(raw.get("available") is True and len(samples) >= 2 and engine_pid in sampled_pids and peak_rss > 0,
                "CPU/memory observation did not include the actual Godot engine")


REGRESSIONS = {
    "test_depth_compositor": "Depth compositor regression passed",
    "test_workbench_strata_layers": "STRATA_LAYER_REGRESSION ",
    "test_workbench_strata_document": "STRATA_DOCUMENT ",
    "test_depth_dimensions_render": "Depth dimension pixels:",
}


def retained_runtime_manifest(platform: str) -> dict:
    """Read the exact committed retained identity on either packaging platform."""
    require(platform in GODOT_SHA256, "Unknown execution platform")
    name = "godot/addons/cybersand_native/runtime-provenance" + (".linux" if platform == "linux" else "") + ".json"
    raw = custody.git("show", "HEAD:" + name)
    manifest = json.loads(raw)
    native = {"path": manifest["artifact"], "sha256": manifest["sha256"], "size": manifest["size"]}
    rapier_path = ("godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
                   if platform == "linux" else custody.windows.RAPIER)
    pointer = custody.git("show", "HEAD:" + rapier_path).decode()
    match = re.fullmatch(r"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize (\d+)\n", pointer)
    require(match is not None, "Retained Rapier is not an exact committed LFS identity")
    native_pointer = custody.git("show", "HEAD:" + native["path"]).decode()
    require(native_pointer == "version https://git-lfs.github.com/spec/v1\noid sha256:" + native["sha256"] +
            "\nsize " + str(native["size"]) + "\n", "Native provenance differs from committed runtime pointer")
    return {"runtime_source_commit": manifest["source_commit"], "runtime_build_commit": manifest["build_commit"],
            "runtime_provenance": {"path": name, "sha256": hashlib.sha256(raw).hexdigest()},
            "native_source_inputs": manifest["source_inputs"], "cybersand_runtime": native,
            "rapier_runtime": {"path": rapier_path, "sha256": match[1], "size": int(match[2])}}


def verify_campaign(folder: Path, expected: dict | None = None, *, full: bool = True) -> dict:
    report = json.loads((folder / "qualification.json").read_text(encoding="utf-8"))
    require(report.get("schema") == "strata-workbench-qualification-v1" and report.get("status") == "passed"
            and report.get("completed") is True and report.get("input_custody") == "passed"
            and report.get("local_delta") == [], "Campaign is incomplete, failed, or contains local changes")
    if expected is None:
        expected = identity()
    for key in ("source_commit", "source_tree", "source_inputs_sha256"):
        require(report.get(key) == expected[key], "Campaign differs from current source: " + key)
    platform = report.get("platform")
    require(platform in GODOT_SHA256, "Unknown campaign platform")
    engine = report.get("godot", {})
    require(engine.get("version") == custody.windows.GODOT_VERSION
            and engine.get("sha256") == GODOT_SHA256[platform] and isinstance(engine.get("path"), str)
            and engine["path"], "Missing exact official Godot receipt")
    runtime = retained_runtime_manifest(platform)
    require(report.get("runtime") == runtime, "Runtime receipt differs from retained source-bound identity")
    for name, digest in runtime["native_source_inputs"].items():
        require(expected["source_inputs_sha256"].get(name) == digest, "Runtime no longer matches native source input: " + name)
    project = report.get("project", {})
    project_inputs = {k.removeprefix("godot/"):v for k,v in expected["source_inputs_sha256"].items() if k.startswith("godot/")}
    for kind in ("cybersand_runtime", "rapier_runtime"):
        item = runtime[kind]; project_inputs[item["path"].removeprefix("godot/")] = item["sha256"]
    require(isinstance(project.get("path"), str) and project["path"]
            and project.get("inputs_sha256") == project_inputs and project_inputs,
            "Loaded project lacks complete source/runtime custody")
    scenes = report.get("scenes", [])
    requested = list(SCENES) if full else report.get("selected_scenes", [])
    require(requested and set(requested) <= set(SCENES) and len(requested) == len(set(requested))
            and set(report.get("selected_scenes", [])) == set(requested)
            and {r["name"] for r in scenes} == set(requested)
            and len(scenes) == len(requested), "Wrong/duplicate scene coverage")
    expected_labels = {"import", "maximum", *REGRESSIONS, *(scene + "/" + phase for scene in requested for phase in ("install", "reopen"))}
    cases = report.get("cases", [])
    require(len(cases) == len(expected_labels) and {r.get("label") for r in cases} == expected_labels,
            "Missing or duplicate import/regression/execution cases")
    cases_by_label = {r["label"]:r for r in cases}
    base = [engine["path"], "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
            "--rendering-driver", "opengl3", "--path", project["path"]]
    for label, embedded in cases_by_label.items():
        path = folder / label / "process.json"
        raw = json.loads(path.read_text(encoding="utf-8"))
        require(raw == {k:v for k,v in embedded.items() if k != "label"}, "Embedded process differs from original process: " + label)
        require(raw.get("status") == "passed" and raw.get("exit_code") == 0 and type(raw.get("pid")) is int
                and raw["pid"] > 0 and type(raw.get("timeout_seconds")) in (int, float)
                and math.isfinite(raw["timeout_seconds"]) and 0 < raw["timeout_seconds"] <= 600
                and type(raw.get("seconds")) in (int, float) and math.isfinite(raw["seconds"])
                and 0 < raw["seconds"] <= raw["timeout_seconds"] + 5,
                "Original bounded Godot process did not succeed: " + label)
        flags = (["--headless", "--editor", "--quit"] if label == "import" else
                 ["--script", "res://tests/" + label + ".gd"] if label in REGRESSIONS else
                 ["--script", MAXIMUM_HARNESS if label == "maximum" else HARNESS])
        require(raw.get("command") == base + flags, "Wrong actual Godot command: " + label)
        log = path.with_name("process.log")
        text = log.read_text(encoding="utf-8")
        require(sha(log) == raw["log_sha256"] and not custody.ERRORS.search(text)
                and "Godot Engine v" + custody.windows.GODOT_VERSION in text,
                "Original Godot log changed, lacks engine identity, or contains an error: " + label)
        marker = REGRESSIONS.get(label, "STRATA_MAXIMUM " if label == "maximum" else "STRATA_WORKBENCH " if label != "import" else "Godot Engine v")
        require(marker in text, "Required actual execution marker absent: " + label)
        verify_resource_receipt(folder, embedded)
    maximum = report.get("maximum", {})
    maximum_path = folder / "maximum" / "maximum.json"
    require(sha(maximum_path) == maximum.get("report_sha256"), "Maximum original result changed")
    maximum_result = json.loads(maximum_path.read_text(encoding="utf-8"))
    require(maximum_result == maximum.get("result") and maximum.get("process") == cases_by_label["maximum"],
            "Maximum embedded receipt differs from its original process/result")
    validate_maximum(maximum_result, report["source_commit"])
    require(maximum_result["display_server"] in (("Windows",) if platform == "win32" else ("X11", "Wayland")),
            "Maximum display differs from its platform")
    if platform == "linux":
        require(maximum_result["process_id"] == cases_by_label["maximum"]["pid"], "Maximum Linux engine PID differs from process owner")
    verify_resource_receipt(folder, cases_by_label["maximum"], maximum_result.get("process_id"))
    for entry in scenes:
        require(entry.get("status") == "passed" and set(entry["phases"]) == {"install", "reopen"}, "Incomplete scene phases")
        for phase, receipt in entry["phases"].items():
            path = folder / entry["name"] / (phase + ".json")
            require(sha(path) == receipt["report_sha256"], "Original scene result changed")
            result = json.loads(path.read_text(encoding="utf-8"))
            require(result == receipt["result"], "Embedded receipt differs from original execution")
            validate_result(result, entry["name"], phase, report["source_commit"])
            require(result["display_server"] in (("Windows",) if platform == "win32" else ("X11", "Wayland")),
                    "Graphical display differs from claimed platform")
            process = cases_by_label[entry["name"] + "/" + phase]
            require(receipt["process"] == process, "Scene process differs from campaign case")
            verify_resource_receipt(folder, process, result.get("process_id"))
            require(type(result.get("process_id")) is int and result["process_id"] > 0,
                    "Missing actual Godot process identity")
            if platform == "linux":
                require(result["process_id"] == process["pid"], "Linux Godot PID differs from process owner")
        before, after = (entry["phases"][p] for p in ("install", "reopen"))
        require(before["process"]["pid"] != after["process"]["pid"] and
                before["result"]["process_id"] != after["result"]["process_id"], "Reopen reused an existing process")
        require(before["result"]["save"]["sha256"] == after["result"]["save"]["sha256"], "Save identity differs across fresh processes")
        require(before["result"]["plane_native_hashes"] == after["result"]["plane_native_hashes"], "Native material planes differ across fresh processes")
    ledger = report.get("evidence_sha256", {})
    files = {p.relative_to(folder).as_posix():p for p in folder.rglob("*") if p.is_file()
             and p.name != "qualification.json" and "userdata" not in p.parts and "bootstrap-userdata" not in p.parts}
    require(ledger and set(ledger) == set(files), "Evidence ledger is absent, incomplete or contains unlisted files")
    for name, digest in ledger.items():
        require(not files[name].is_symlink() and sha(files[name]) == digest, "Original evidence changed: " + name)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--scene", action="append", choices=SCENES)
    parser.add_argument("--allow-source-delta", action="store_true", help="Local diagnostics only; never package")
    parser.add_argument("--process-timeout", type=int, default=420)
    parser.add_argument("--campaign-timeout", type=int, default=2400)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "strata-workbench-qualification-v1", "status": "running", "platform": sys.platform,
              "cases": [], "scenes": [], "selected_scenes": args.scene or list(SCENES), "completed": False}
    source = runtime = loaded = None
    started = time.monotonic()
    deadline = started + args.campaign_timeout
    try:
        require(60 <= args.process_timeout <= 600 and 120 <= args.campaign_timeout <= 3600, "Invalid campaign budget")
        source = identity(args.allow_source_delta)
        runtime = custody.verify_runtime_identity()
        project = args.project.resolve(strict=True)
        loaded = custody.project_identity(project, source, runtime)
        report.update(source)
        report.update(runtime=runtime, project={"path": str(project), "inputs_sha256": loaded})
        godot = args.godot.resolve(strict=True)
        require(sys.platform in GODOT_SHA256, "Unsupported execution platform")
        version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
        require(version == custody.windows.GODOT_VERSION and sha(godot) == GODOT_SHA256[sys.platform],
                "Godot executable differs from exact official pin")
        if sys.platform == "win32":
            require(sha(godot.with_name("Godot_v4.7-stable_win64.exe")) == GODOT_GUI_SHA256, "Godot GUI pin mismatch")
        report["godot"] = {"path": str(godot), "version": version, "sha256": sha(godot)}
        base = [str(godot), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                "--rendering-driver", "opengl3", "--path", str(project)]
        def run(label: str, flags: list[str], environment: dict) -> dict:
            remaining = deadline - time.monotonic()
            require(remaining > 1, "Campaign deadline exhausted")
            record = process_metrics.execute(base + flags, output / label, environment, min(args.process_timeout, remaining))
            record["label"] = label
            report["cases"].append(record)
            write_json(output / "qualification.json", report)
            require(record["status"] == "passed", record.get("error", "Godot process failed"))
            return record
        env = custody.case_environment(output / "bootstrap-userdata")
        env["CYBERSAND_SOURCE_REVISION"] = source["source_commit"]
        run("import", ["--headless", "--editor", "--quit"], env)
        for script, marker in REGRESSIONS.items():
            row = run(script, ["--script", "res://tests/" + script + ".gd"], env)
            require(marker in (output / script / "process.log").read_text(encoding="utf-8"), "Missing retained depth regression marker")
        maximum_path = output / "maximum" / "maximum.json"
        maximum_env = custody.case_environment(output / "maximum-userdata" / "userdata")
        maximum_env.update(CYBERSAND_SOURCE_REVISION=source["source_commit"], STRATA_EVIDENCE=str(output / "maximum"),
                           STRATA_REPORT=str(maximum_path))
        report["maximum"] = {"status":"running"}
        try:
            maximum_process = run("maximum", ["--script", MAXIMUM_HARNESS], maximum_env)
            maximum_result = json.loads(maximum_path.read_text(encoding="utf-8"))
            validate_maximum(maximum_result, source["source_commit"])
            verify_resource_receipt(output, maximum_process, maximum_result.get("process_id"))
            report["maximum"] = {"status":"passed", "report_sha256":sha(maximum_path), "result":maximum_result, "process":maximum_process}
        except Exception as error:
            report["maximum"].update(status="failed", error=str(error))
            print("STRATA_MAXIMUM_FAIL", str(error), flush=True)
        write_json(output / "qualification.json", report)
        for scene in report["selected_scenes"]:
            entry = {"name": scene, "status": "running", "phases": {}}
            report["scenes"].append(entry)
            userdata = output / scene / "userdata"
            environment = custody.case_environment(userdata)
            environment.update(CYBERSAND_SOURCE_REVISION=source["source_commit"], STRATA_SCENE=scene,
                               STRATA_EVIDENCE=str(output / scene))
            try:
                for phase in ("install", "reopen"):
                    path = output / scene / (phase + ".json")
                    row = run(scene + "/" + phase, ["--script", HARNESS],
                              dict(environment, STRATA_PHASE=phase, STRATA_REPORT=str(path)))
                    result = json.loads(path.read_text(encoding="utf-8"))
                    validate_result(result, scene, phase, source["source_commit"])
                    verify_resource_receipt(output, row, result.get("process_id"))
                    saved = Path(result["save"]["path"]).resolve()
                    require(saved.is_relative_to(userdata.resolve()) and sha(saved) == result["save"]["sha256"],
                            "Saved composition is absent, changed, or outside isolated user data")
                    entry["phases"][phase] = {"report_sha256": sha(path), "process": row, "result": result}
                require(entry["phases"]["install"]["process"]["pid"] != entry["phases"]["reopen"]["process"]["pid"],
                        "Reopen requires a distinct process")
                require(entry["phases"]["install"]["result"]["save"]["sha256"] ==
                        entry["phases"]["reopen"]["result"]["save"]["sha256"], "Fresh process lost saved identity")
                require(entry["phases"]["install"]["result"]["plane_native_hashes"] ==
                        entry["phases"]["reopen"]["result"]["plane_native_hashes"], "Fresh process lost a native material plane")
                entry["status"] = "passed"
                print("STRATA_PASS", scene, flush=True)
            except Exception as error:
                entry.update(status="failed", error=str(error))
                print("STRATA_FAIL", scene, str(error), flush=True)
            finally:
                write_json(output / "qualification.json", report)
        require(report["maximum"]["status"] == "passed", "Maximum extent qualification failed")
        require(all(row["status"] == "passed" for row in report["scenes"]), "One or more scenes failed")
        report["status"] = "passed"
    except Exception as error:
        report.update(status="failed", error=str(error))
        print("STRATA_QUALIFICATION_FAILED", error, file=sys.stderr, flush=True)
    finally:
        if source is not None:
            try:
                require(identity(args.allow_source_delta) == source, "Source changed during campaign")
                require(custody.verify_runtime_identity() == runtime, "Runtime changed during campaign")
                if loaded is not None:
                    require(custody.project_identity(project, source, runtime) == loaded, "Loaded project changed during campaign")
                report["input_custody"] = "passed"
            except Exception as error:
                report.update(status="failed", input_custody="failed", custody_error=str(error))
        report.update(completed=True, elapsed_seconds=round(time.monotonic() - started, 3))
        report["evidence_sha256"] = {p.relative_to(output).as_posix(): sha(p) for p in sorted(output.rglob("*"))
            if p.is_file() and p.name != "qualification.json" and "userdata" not in p.parts and "bootstrap-userdata" not in p.parts}
        write_json(output / "qualification.json", report)
    print(json.dumps({"status": report["status"], "source": report.get("source_commit"), "platform": sys.platform}))
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
