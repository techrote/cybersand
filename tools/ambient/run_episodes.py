#!/usr/bin/env python3
"""Run the frozen physical experiment in isolated, source-bound Godot processes.

Failed attempts remain original evidence. Resume requires matching committed
inputs, console, terminal, report and execution receipt. Registry generation
executes zero physical episodes. Source/runtime custody reuses the ordinary
Workbench evaluator's pinned and complete project checks.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import analyze_episodes as analysis

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/"tools"))
import qualify_ambient_living as qualification

SCRIPT = "res://tests/test_ambient2_episodes.gd"
TOOL_INPUTS = ("tools/ambient/run_episodes.py", "tools/ambient/analyze_episodes.py",
              "tools/ambient/test_episode_tools.py")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix+".partial")
    temporary.write_text(json.dumps(value, indent=2)+"\n", encoding="utf-8")
    temporary.replace(path)


def head(root):
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()


def identity_key(source):
    return {key: source[key] for key in
            ("source_revision", "godot_executable_sha256", "platform", "sha256", "runtime_sha256")}


def full_custody(args):
    analysis.require(args.root == ROOT == qualification.ROOT, "Run tools from the checkout being qualified")
    analysis.require(args.source_sha == head(args.root), "Requested source must be actual checkout HEAD")
    source = qualification.source_identity()
    analysis.require(source["source_commit"] == args.source_sha and not source["local_delta"],
                     "Full project must match clean committed source")
    engine = qualification.engine_identity(args.godot)
    runtime = qualification.verify_runtime_identity()
    project = qualification.project_identity(args.root/"godot", source, runtime)
    tool_hashes = {}
    for path in TOOL_INPUTS:
        saved = subprocess.check_output(["git", "show", args.source_sha+":"+path], cwd=args.root)
        tool_hashes[path] = sha(args.root/path)
        analysis.require(hashlib.sha256(saved).hexdigest() == tool_hashes[path],
                         "Uncommitted experiment tool: "+path)
    return {"source": source, "engine": engine, "runtime": runtime,
            "loaded_project_sha256": project, "experiment_tools_sha256": tool_hashes}


def verify_committed(root, source, expected_sha):
    analysis.require(expected_sha == head(root) == source["source_revision"],
                     "Current HEAD, requested and observed source must agree")
    for path, digest in source["sha256"].items():
        saved = subprocess.check_output(["git", "show", expected_sha+":godot/"+path], cwd=root)
        analysis.require(hashlib.sha256(saved).hexdigest() == digest,
                         "Runtime source differs from committed input: "+path)
        analysis.require(sha(root/"godot"/path) == digest, "Source bytes changed: "+path)
    for path, digest in source["runtime_sha256"].items():
        analysis.require(sha(root/"godot"/path) == digest, "Runtime bytes changed: "+path)
    for path in TOOL_INPUTS:
        saved = subprocess.check_output(["git", "show", expected_sha+":"+path], cwd=root)
        analysis.require(hashlib.sha256(saved).hexdigest() == sha(root/path),
                         "Uncommitted experiment tool: "+path)


def check_terminal(console, report, receipt, case_id, expected_source, mode):
    text = re.sub(r"\x1b\[[0-9;]*m", "", console.read_text(encoding="utf-8", errors="replace"))
    analysis.require("SCRIPT ERROR:" not in text and "ERROR:" not in text,
                     "Engine error in successful process: "+str(console))
    marker = "AMBIENT2_REGISTRY " if mode == "registry" else "AMBIENT2_EPISODES "
    terminals = [line[len(marker):] for line in text.splitlines() if line.startswith(marker)]
    analysis.require(len(terminals) == 1, "Missing or duplicate completion marker")
    terminal = json.loads(terminals[0])
    analysis.require(receipt["returncode"] == 0 and not receipt.get("timed_out"), "Incomplete receipt")
    analysis.require(receipt["mode"] == mode and receipt["case_id"] == case_id
                     and receipt["source_revision"] == expected_source
                     and terminal["source_revision"] == expected_source
                     and report["source_identity"]["source_revision"] == expected_source,
                     "Process, terminal and report source/case identity differ")
    if mode == "registry":
        analysis.require(report.get("case") == "AMBIENT-002 physical campaign registry"
                         and report["actual_episodes_executed"] == terminal["actual_episodes_executed"] == 0
                         and terminal["campaigns"] == len(report["registration"]),
                         "Registry terminal differs from original report")
    else:
        analysis.require(terminal.get("case_id") == case_id and terminal.get("complete") is True
                         and terminal.get("failures") == []
                         and terminal.get("mode") == report["mode"]
                         and terminal.get("checks") == report["checks"]
                         and terminal.get("checks", 0) > 0
                         and terminal.get("campaigns") == report["completed_campaigns"]
                         and terminal.get("episodes") == report["completed_actor_episodes"]
                         and terminal.get("expected_episodes") == report["expected_actor_episodes"],
                         "Physical terminal differs from original report")


def run_process(args, mode, case_id, destination, custody_sha):
    destination.mkdir(parents=True, exist_ok=False)
    report_path = destination/"report.json"
    console = destination/"console.log"
    env = os.environ.copy()
    env.update({"CYBERSAND_SOURCE_REVISION": args.source_sha,
                "CYBERSAND_AMBIENT2_EPISODES_MODE": mode,
                "CYBERSAND_AMBIENT2_EPISODES_REPORT": str(report_path),
                "CYBERSAND_AMBIENT2_EPISODES_CASE": case_id,
                "XDG_DATA_HOME": str(destination/"userdata")})
    if os.name == "nt":
        env["APPDATA"] = str(destination/"userdata"/"roaming")
        env["LOCALAPPDATA"] = str(destination/"userdata"/"local")
    command = [str(args.godot), "--headless", "--audio-driver", "Dummy",
               "--path", str(args.root/"godot"), "--script", SCRIPT]
    begun = time.monotonic()
    receipt = {"command": command, "mode": mode, "case_id": case_id,
               "source_revision": args.source_sha, "custody_sha256": custody_sha,
               "timeout_seconds": args.case_timeout,
               "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    try:
        with console.open("wb") as stream:
            result = subprocess.run(command, cwd=args.root, env=env, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=args.case_timeout, check=False)
        receipt["returncode"] = result.returncode
    except subprocess.TimeoutExpired:
        receipt.update(returncode=None, timed_out=True)
    receipt["elapsed_seconds"] = time.monotonic()-begun
    receipt["console_sha256"] = sha(console)
    if report_path.is_file():
        receipt["report_sha256"] = sha(report_path)
    write(destination/"execution.json", receipt)
    analysis.require(receipt.get("returncode") == 0, "Godot failed: "+str(destination/"execution.json"))
    analysis.require(report_path.is_file(), "Missing physical report")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    check_terminal(console, report, receipt, case_id, args.source_sha, mode)
    return report, receipt, report_path


def next_attempt(directory):
    directory.mkdir(parents=True, exist_ok=True)
    numbers = [int(p.name.split("-")[1]) for p in directory.glob("attempt-*")
               if p.is_dir() and re.fullmatch(r"attempt-\d+", p.name)]
    return directory/f"attempt-{max(numbers, default=0)+1:03d}"


def find_valid_shard(directory, item, expected_identity, args, custody_sha):
    if not args.resume or not directory.is_dir():
        return None
    retained = args.retained_receipts.get(item["id"])
    if retained is None:
        return None
    for report_path in sorted(directory.glob("attempt-*/report.json"), reverse=True):
        receipt_path = report_path.parent/"execution.json"
        console = report_path.parent/"console.log"
        try:
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            report = json.loads(report_path.read_text(encoding="utf-8"))
            analysis.require(str(report_path.relative_to(args.output)) == retained["report"]
                             and sha(receipt_path) == retained["execution_receipt_sha256"]
                             and sha(report_path) == retained["report_sha256"]
                             and sha(console) == retained["console_sha256"], "Saved aggregate custody changed")
            analysis.require(receipt["report_sha256"] == sha(report_path)
                             and receipt["console_sha256"] == sha(console)
                             and receipt["custody_sha256"] == custody_sha, "Saved evidence changed")
            analysis.require(identity_key(report["source_identity"]) == expected_identity,
                             "Saved source/runtime differs")
            analysis.require(report.get("registration") == [item], "Saved registration differs")
            check_terminal(console, report, receipt, item["id"], args.source_sha, "full")
            analysis.validate(report, source_root=args.root)
            return report, receipt, report_path
        except (ValueError, KeyError, TypeError, FileNotFoundError, json.JSONDecodeError):
            continue
    return None


def aggregate(registry, shards, receipts):
    registration = registry["registration"]
    campaigns = [c for shard in shards for c in shard["campaigns"]]
    base = shards[0].copy() if shards else {}
    base.update({"case": "AMBIENT-002 matched physical actor episodes", "mode": "full",
        "source_identity": registry["source_identity"], "registration": registration,
        "complete_registration": registration, "expected_campaigns": len(registration),
        "expected_actor_episodes": sum(item["actor_count"] for item in registration),
        "completed_campaigns": len(campaigns), "completed_actor_episodes": sum(c["actor_count"] for c in campaigns),
        "complete": len(campaigns) == len(registration), "checks": sum(s["checks"] for s in shards),
        "failures": [failure for s in shards for failure in s.get("failures", [])],
        "campaigns": campaigns,
        "execution": "one fresh Godot process and new native/Rapier World per registered campaign",
        "shard_receipts": receipts})
    if base["failures"]:
        base["complete"] = False
    return base


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-sha")
    parser.add_argument("--case-timeout", type=int, default=1800)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()
    args.root = args.root.resolve(); args.output = args.output.resolve(); args.godot = args.godot.resolve()
    analysis.require(args.godot.is_file(), "Godot executable missing")
    args.source_sha = args.source_sha or head(args.root)
    analysis.require(analysis.hexadecimal(args.source_sha, 40), "Full source SHA required")
    analysis.require(args.case_timeout >= 120, "Watchdog must allow native setup and sustained episodes")
    custody = full_custody(args)
    args.output.mkdir(parents=True, exist_ok=True)
    custody_path = args.output/"custody.json"
    if custody_path.exists():
        analysis.require(json.loads(custody_path.read_text(encoding="utf-8")) == custody,
                         "Output belongs to different source/runtime custody")
    else:
        write(custody_path, custody)
    custody_sha = sha(custody_path)
    registry, registration_receipt, registry_path = run_process(
        args, "registry", "", next_attempt(args.output/"registration"), custody_sha)
    verify_committed(args.root, registry["source_identity"], args.source_sha)
    engine_sha = custody["engine"].get("gui_sha256", custody["engine"]["sha256"])
    analysis.require(registry["source_identity"]["godot_executable_sha256"] == engine_sha,
                     "Observed engine differs from independently authenticated pin")
    expected_identity = identity_key(registry["source_identity"])
    for kind in ("cybersand_runtime", "rapier_runtime"):
        entry = custody["runtime"][kind]
        analysis.require(registry["source_identity"]["runtime_sha256"][entry["path"].removeprefix("godot/")] == entry["sha256"],
                         "Observed native/Rapier differs from verified provenance")
    registration = registry["registration"]
    analysis.require(len({r["id"] for r in registration}) == len(registration), "Duplicate registered campaign")
    analysis.require(len(registration) == 122 and sum(r["actor_count"] for r in registration) == 194,
                     "Registry differs from frozen122 campaigns /194 actors")
    args.retained_receipts = {}
    aggregate_path = args.output/"episodes.json"
    if args.resume and aggregate_path.is_file():
        saved = json.loads(aggregate_path.read_text(encoding="utf-8"))
        analysis.require(identity_key(saved["source_identity"]) == expected_identity
                         and saved["registration"] == registration, "Saved aggregate source or registry differs")
        analysis.validate(saved, allow_partial=True, source_root=args.root)
        args.retained_receipts = {r["case_id"]: r for r in saved["shard_receipts"]}
    shards, receipts = [], []
    for index, item in enumerate(registration):
        verify_committed(args.root, registry["source_identity"], args.source_sha)
        analysis.require(qualification.engine_identity(args.godot) == custody["engine"], "Engine changed")
        directory = args.output/"shards"/item["id"]
        retained = find_valid_shard(directory, item, expected_identity, args, custody_sha)
        reused = retained is not None
        if retained:
            report, receipt, report_path = retained
        else:
            report, receipt, report_path = run_process(args, "full", item["id"], next_attempt(directory), custody_sha)
            analysis.require(identity_key(report["source_identity"]) == expected_identity,
                             "Runtime/source changed between Worlds")
            analysis.require(report.get("registration") == [item], "Executed case differs from registration")
            analysis.validate(report, source_root=args.root)
        shards.append(report)
        verify_committed(args.root, registry["source_identity"], args.source_sha)
        receipt_path = report_path.parent/"execution.json"
        receipts.append({"case_id": item["id"], "report": str(report_path.relative_to(args.output)),
            "report_sha256": sha(report_path), "execution_receipt": str(receipt_path.relative_to(args.output)),
            "execution_receipt_sha256": sha(receipt_path),
            "console": str(report_path.parent.joinpath("console.log").relative_to(args.output)),
            "console_sha256": receipt["console_sha256"], "elapsed_seconds": receipt["elapsed_seconds"], "reused": reused})
        combined = aggregate(registry, shards, receipts)
        analysis.validate(combined, allow_partial=True, source_root=args.root)
        write(aggregate_path, combined)
        print(f"AMBIENT2_ISOLATED_PROGRESS {index+1}/{len(registration)} "
              f"actors={combined['completed_actor_episodes']} reused={reused} {item['id']}", flush=True)
    combined = aggregate(registry, shards, receipts)
    analysis.require(full_custody(args) == custody, "Complete source/project/runtime custody changed")
    analysis.validate(combined, source_root=args.root)
    write(aggregate_path, combined)
    write(args.output/"runner-receipt.json", {
        "source_revision": args.source_sha, "custody_sha256": custody_sha,
        "source_tree": custody["source"]["source_tree"], "godot_sha256": sha(args.godot),
        "runner_sha256": sha(__file__), "analyzer_sha256": sha(Path(analysis.__file__)),
        "registry": str(registry_path.relative_to(args.output)), "registry_sha256": sha(registry_path),
        "registration_receipt_sha256": sha(registry_path.parent/"execution.json"),
        "registration_receipt": registration_receipt, "report_sha256": sha(aggregate_path),
        "campaigns": len(registration), "actual_actor_episodes": combined["completed_actor_episodes"], "complete": True})
    print("AMBIENT2_ISOLATED "+json.dumps({"complete": True, "campaigns": len(registration),
        "episodes": combined["completed_actor_episodes"], "source_revision": args.source_sha,
        "report": str(aggregate_path)}), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, RuntimeError, subprocess.CalledProcessError) as error:
        print("AMBIENT2_ISOLATED_REFUSED: "+str(error), file=sys.stderr)
        raise SystemExit(1)

