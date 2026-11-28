#!/usr/bin/env python3
"""Run the registered source comparison on Linux with an existing pinned engine.

Developer companion; the portable Windows deliverable uses PowerShell only.
Supply --display-wrapper for an existing Xvfb wrapper, or use a real DISPLAY.
Only new copies beneath --output are modified. M/I/C gameplay runs are serial.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time
import uuid

from source_results import canonical, digest, need, reduce_receipt


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def source_identity(root):
    root = Path(root).resolve()
    need((root / "godot/project.godot").is_file(), f"Missing source project: {root}")
    changed = git(root, "diff", "--name-only", "HEAD", "--", "godot", "native", "third_party").splitlines()
    generated = {"godot/.godot/global_script_class_cache.cfg", "godot/.godot/extension_list.cfg"}
    need(not (set(changed) - generated), f"Tracked application/runtime source is dirty: {root}")
    return {"root": str(root), "source_commit": git(root, "rev-parse", "HEAD"), "source_tree": git(root, "rev-parse", "HEAD^{tree}"),
            "regenerated_import_bootstrap": changed}


def copy_project(source, target, imported=False):
    def ignored(folder, names):
        if Path(folder).name == ".godot":
            if imported:
                return {name for name in names if name == "shader_cache"}
            return set(names) - {".gdignore", "extension_list.cfg", "global_script_class_cache.cfg"}
        return {name for name in names if name in {".git", "__pycache__"}}
    shutil.copytree(source, target, ignore=ignored)


def descendant_pids(pid):
    pending, seen = [pid], set()
    while pending:
        value = pending.pop()
        if value in seen:
            continue
        seen.add(value)
        yield value
        try:
            pending.extend(int(x) for x in Path(f"/proc/{value}/task/{value}/children").read_text().split())
        except (OSError, ValueError):
            pass


def memory_sample(pid, elapsed_ms):
    values = {}
    for line in Path(f"/proc/{pid}/status").read_text().splitlines():
        key, _, value = line.partition(":")
        if key in {"VmRSS", "VmHWM", "VmSize"}:
            values[key] = int(value.split()[0]) * 1024
    return {"pid": pid, "elapsed_ms": elapsed_ms, "rss_bytes": values.get("VmRSS"), "peak_rss_bytes": values.get("VmHWM"), "virtual_bytes": values.get("VmSize")}


def execute(engine, args, folder, source_sha, settings, timeout, wrapper=None):
    folder.mkdir(parents=True, exist_ok=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith("CYBERSAND_")}
    for name in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        path = folder / "profile" / name
        path.mkdir(parents=True, exist_ok=True)
        env[name] = str(path)
    env.update(settings, CYBERSAND_SOURCE_REVISION=source_sha, CYBERSAND_SOURCE_SHA=source_sha)
    command = [str(engine), *args]
    if wrapper:
        command = [sys.executable, str(wrapper), *command]
    clock = time.monotonic()
    samples, child_pid = [], None
    timed_out = False
    with (folder / "stdout.log").open("w") as out, (folder / "stderr.log").open("w") as err:
        process = subprocess.Popen(command, stdout=out, stderr=err, env=env, start_new_session=True)
        while process.poll() is None:
            if time.monotonic() - clock > timeout:
                timed_out = True
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                break
            try:
                if child_pid is None:
                    for pid in descendant_pids(process.pid):
                        executable = Path(f"/proc/{pid}/exe").resolve()
                        if executable == engine:
                            child_pid = pid
                            break
                if child_pid is not None:
                    samples.append(memory_sample(child_pid, (time.monotonic() - clock) * 1000))
            except (OSError, ValueError):
                pass
            time.sleep(0.25)
        exit_code = process.wait(timeout=10)
    result = {"command": command, "source_commit": source_sha, "elapsed_seconds": time.monotonic() - clock, "exit_code": exit_code,
              "timed_out": timed_out, "wrapper_pid": process.pid, "observed_application_pid": child_pid,
              "sampled_peak_rss_bytes": max((s["peak_rss_bytes"] or 0 for s in samples), default=None),
              "memory_scope": "250ms actual Godot child RSS samples, including setup and capture; valid only after receipt PID match"}
    write_json(folder / "process.json", result)
    write_json(folder / "process-memory.json", samples)
    logs = (folder / "stdout.log").read_text() + (folder / "stderr.log").read_text()
    need(not timed_out and exit_code == 0 and not any(x in logs for x in ("SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Failed loading resource:", "Error initializing GLAD", "MakeCurrent failed")), f"Process failed: {folder}")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--main", type=Path, required=True)
    parser.add_argument("--integration", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--campaign", type=Path, default=Path(__file__).with_name("source_campaign.json"))
    parser.add_argument("--display-wrapper", type=Path)
    parser.add_argument("--driver", choices=("opengl3", "opengl3_angle"), default="opengl3")
    parser.add_argument("--render-thread", choices=("safe", "separate"), default="safe")
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--extended", action="store_true")
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()
    campaign = json.loads(args.campaign.read_text())
    need(campaign["schema"] == "pubpres-source-campaign-v1" and campaign["order"] == list("MICCIM"), "Unknown or unbalanced campaign")
    need(not args.output.exists(), "Output already exists; preserve the original run and choose a new directory")
    need(not (args.case and args.extended), "Select cases or the extended campaign")
    sources = {"M": source_identity(args.main), "I": source_identity(args.integration), "C": source_identity(args.candidate)}
    need(sources["M"]["source_commit"] == campaign["source_commits"]["main"] and sources["I"]["source_commit"] == campaign["source_commits"]["integration"], "Registered historical source changed")
    engine = args.engine.resolve()
    need(engine.is_file(), "Pinned Godot executable missing")
    candidates = {r["id"] for r in campaign["cases"]}
    need(set(args.case) <= candidates, "Unknown registered case")
    cases = [r for r in campaign["cases"] if r["id"] in args.case or not args.case and (args.extended or r["quick"])]
    need(cases, "No registered cases")
    output = args.output.resolve()
    projects = output / "project"
    projects.mkdir(parents=True)
    overlay = args.candidate.resolve() / "godot"
    for relative, expected in campaign["overlay_sha256"].items():
        need(digest(overlay / relative) == expected, f"Identical observation overlay changed: {relative}")
    shutil.copyfile(args.campaign, output / "source_campaign.json")
    request = {"sources": sources, "engine": str(engine), "engine_sha256": digest(engine), "order": campaign["order"], "cases": cases,
               "arms": campaign["arms"], "campaign_sha256": digest(args.campaign), "overlay_sha256": campaign["overlay_sha256"],
               "rendering_driver": args.driver, "render_thread": args.render_thread, "measurement": campaign["measurement"],
               "display_wrapper": str(args.display_wrapper) if args.display_wrapper else None,
               "cache_policy": "fresh source copy, process and profile per arm; driver-global caches uncontrolled and order-balanced"}
    write_json(output / "request.json", request)
    results, failures, templates = [], [], {}
    try:
        for letter in ("M", "I", "C"):
            project = projects / ("template-" + letter)
            copy_project(Path(sources[letter]["root"]) / "godot", project)
            for relative, expected in campaign["overlay_sha256"].items():
                target = project / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(overlay / relative, target)
                need(digest(target) == expected, "Overlay copy changed")
            print(f"Importing {letter} {sources[letter]['source_commit']}", flush=True)
            execute(engine, ["--headless", "--audio-driver", "Dummy", "--path", str(project), "--editor", "--import"], output / ("import-" + letter), sources[letter]["source_commit"], {}, 300)
            templates[letter] = project
        for case in cases:
            arms = []
            for index, letter in enumerate(campaign["order"]):
                source, arm = sources[letter], campaign["arms"][letter]
                folder = output / case["id"] / f"{index}-{letter}"
                project = projects / f"{case['id']}-{index}-{letter}"
                nonce = uuid.uuid4().hex
                print(f"{case['id']} | {letter} ({index+1}/6)", flush=True)
                try:
                    copy_project(templates[letter], project, imported=True)
                    receipt = folder / "receipt.json"
                    settings = {"CYBERSAND_MATERIAL_PUBLICATION": arm["material"], "CYBERSAND_DIAG_PHYSICS_PUBLICATION": arm["physics"],
                                "CYBERSAND_DIAG_PRESENTATION": arm["presentation"], "CYBERSAND_DIAG_MATERIAL_TIMING": arm["timing"],
                                "CYBERSAND_DIAG_NATIVE_RENDEZVOUS": arm["rendezvous"], "CYBERSAND_DIAG_COMMON_OBSERVER": "0",
                                "CYBERSAND_SHADER_NONCE": nonce, "CYBERSAND_SHADER_CACHE_STATE": "isolated-project-and-profile"}
                    if arm["cadence"] != "source-default":
                        settings["CYBERSAND_DIAG_RENDER_CADENCE"] = arm["cadence"]
                    arguments = ["--path", str(project), "--rendering-method", "gl_compatibility", "--rendering-driver", args.driver,
                                 "--render-thread", args.render_thread, "--audio-driver", "Dummy", "--log-file", str(folder / "godot.log"),
                                 "--script", "res://tests/pubpres_source_gameplay.gd", "--", f"--receipt={receipt}", f"--fixture={case['fixture']}",
                                 f"--camera={case['camera']}", f"--workers={case['workers']}", f"--water-law={case['water_law']}"]
                    folder.mkdir(parents=True)
                    write_json(folder / "arm.json", {"source": source, "scenario": case, "arm": arm, "order_index": index, "nonce": nonce, "selectors": settings, "arguments": arguments})
                    process = execute(engine, arguments, folder, source["source_commit"], settings, args.timeout, args.display_wrapper)
                    data = json.loads(receipt.read_text())
                    need(data["source_identity"]["source_sha"] == source["source_commit"] and data["case_nonce"] == nonce and data["renderer"] == args.driver, "Source, nonce or driver changed")
                    need(data["fixture"]["name"] == case["fixture"] and data["camera"] == case["camera"] and data["workers"] == case["workers"] and data["water_law"] == case["water_law"], "Registered case changed")
                    stats = reduce_receipt(receipt, campaign, project, engine, letter)
                    process["app_sampler_pid_matched"] = process["observed_application_pid"] == data["process_id"]
                    if not process["app_sampler_pid_matched"]:
                        process["sampled_peak_rss_bytes"] = None
                    write_json(folder / "process.json", process)
                    write_json(folder / "analysis.json", stats)
                    arms.append({"arm": letter, "index": index, "nonce": nonce, "process": process, "statistics": stats, "receipt_sha256": digest(receipt)})
                    shutil.rmtree(project)
                except Exception as error:
                    failures.append({"scenario": case["id"], "index": index, "reason": str(error)})
                    print(f"Arm incomplete; originals retained: {error}", flush=True)
            if len(arms) != 6 or [r["arm"] for r in arms] != list("MICCIM"):
                failures.append({"scenario": case["id"], "reason": "Incomplete M-I-C-C-I-M comparison"})
            elif any(canonical(r["statistics"]["match"]) != canonical(arms[0]["statistics"]["match"]) for r in arms):
                failures.append({"scenario": case["id"], "reason": "Unmatched hardware, display, policy, source fixture or workload"})
            results.append({"scenario": case["id"], "arms": arms})
            write_json(output / "summary.json", {"complete": False, "physical_acceptance": "HOLD", "cases": results, "failures": failures})
    except Exception as error:
        failures.append({"reason": str(error)})
    finally:
        complete = not failures and len(results) == len(cases)
        write_json(output / "summary.json", {"schema": "pubpres-source-comparison-v1", "complete": complete, "physical_acceptance": "HOLD", "cases": results,
                                            "failures": failures, "sources": sources, "order": campaign["order"],
                                            "meaning": "Capture completion is not a performance win or physical Windows/NVIDIA acceptance. Review both repeats and all tail/freshness distributions."})
        lines = [f"Source comparison capture complete: {complete} | Physical acceptance: HOLD", "M=accepted main; I=prior integration; C=registered candidate treatment. Order M-I-C-C-I-M."]
        for case in results:
            for arm in case["arms"]:
                for name, stats in arm["statistics"]["windows"].items():
                    def fmt(key):
                        return "/".join(f"{stats[key][q]:.2f}" for q in ("p50", "p95", "p99", "max"))
                    lines.append(f"{case['scenario']} {arm['arm']}{arm['index']} {name}: frame {fmt('frame_ms')} ms; physical {fmt('physical_gap_ms')} ms; native-observed {fmt('native_observed_gap_ms')} ms; native {stats['native_ticks_per_second']:.2f}/s Rapier {stats['rapier_steps_per_second']:.2f}/s")
        lines.extend("Scope: " + s for s in campaign["measurement"]["limits"])
        lines.extend("INCOMPLETE " + s["reason"] for s in failures)
        (output / "READ-RESULTS.txt").write_text("\n".join(lines) + "\n")
        print(f"Results: {output}", flush=True)
    return 0 if complete else 1


if __name__ == "__main__":
    sys.exit(main())
