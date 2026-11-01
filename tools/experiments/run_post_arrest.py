"""Frozen-source four-arm acquisition, exact prefix gate and bounded full replay."""
from __future__ import annotations

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

import ejection_a2 as a2
from post_arrest_accounting import CAMPAIGN, ROOT, sha, write
from run_bearing_candidates import INPUTS as PARENT_INPUTS

PROTOCOL = "docs/audits/y1-post-arrest-2026-11-01/protocol.json"
INPUTS = (*PARENT_INPUTS, "godot/tests/test_post_arrest_clearance.gd",
          "tools/experiments/run_post_arrest.py", "tools/experiments/post_arrest_analysis.py",
          "tools/experiments/post_arrest_accounting.py", PROTOCOL)
VOLATILE = {"owner", "instance_id", "capture_instance_id", "consumer_usec", "coupling_usec", "producer_usec", "step_start_usec"}
ADDED_EVENT_KEYS = {"topology_hash", "structural_hash"}


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=30).decode().strip()


def stable(value, events=False):
    if isinstance(value, dict):
        return {k: stable(v, events) for k, v in value.items()
                if k not in VOLATILE and not (events and k in ADDED_EVENT_KEYS)}
    if isinstance(value, list):
        return [stable(v, events) for v in value]
    return value


def prefix_gate(directory, candidate, arm):
    """Exact all-channel comparison, excluding only named volatile custody/time fields."""
    reference = CAMPAIGN / f"{candidate}-{arm}-on"
    old = read(reference / "trajectory.json")["frames"]
    new = read(directory / "trajectory.json")["frames"]
    if len(old) != 600 or len(new) != 1800:
        raise ValueError("complete600/1800 records required")
    for index, (a, b) in enumerate(zip(old, new)):
        if stable(a) != stable(b):
            keys = [k for k in set(a) | set(b) if stable(a.get(k)) != stable(b.get(k))]
            raise ValueError(f"prefix drift at{index}: {keys}")
    # Verify every original event value, not only a count/hash projection.
    expected = (c for p in read(reference / "population-manifest.json")["parts"]
                for c in read(reference / p["path"])["capsules"])
    count = 0
    with (directory / "events.jsonl").open(encoding="utf-8") as stream:
        for line in stream:
            c = json.loads(line)
            if c["tick"] >= 600:
                break
            original = next(expected, None)
            if original is None or stable(original, True) != stable(c, True):
                raise ValueError(f"prefix capsule drift at{count+1}")
            count += 1
    if next(expected, None) is not None:
        raise ValueError("prefix event population truncated")
    old_acq = read(reference / "acquisition.json")
    new_acq = read(directory / "acquisition.json")
    if stable(old_acq["segments"]) != stable(new_acq["segments"][:10]):
        raise ValueError("prefix segment/capacity/outcome drift")
    fixture_keys = set(old_acq["fixture"]) - {"ticks", "raw_unresolved", "raw_displaced"}
    if any(old_acq["fixture"][k] != new_acq["fixture"][k] for k in fixture_keys):
        raise ValueError("fixture drift")
    result = {"pass": True, "frames_exact": 600, "capsules_exact": count,
              "segments_exact": 10, "comparison": "All frame keys recursively and all parsed capsule values; exact numeric equality",
              "excluded_volatile_fields": sorted(VOLATILE), "excluded_added_event_hashes": sorted(ADDED_EVENT_KEYS),
              "reference_trajectory_sha256": sha(reference / "trajectory.json"),
              "reference_receipt_sha256": sha(reference / "receipt.json")}
    write(directory / "prefix.json", result)
    return result


def collect(directory, acquisition):
    counters = acquisition["native_counters"]
    if not acquisition["complete"] or acquisition["fixture"]["ticks"] != 1800 or len(acquisition["segments"]) != 30:
        raise ValueError("incomplete1800/30segment capture")
    if counters["dropped"] or counters["relocation_refused"]:
        raise ValueError("loss/refusal blocks interpretation")
    deadline = time.monotonic() + 180
    fence = counters["capture_instance_id"], counters["capture_reset_generation"]
    parts, batch, events = [], [], []
    ordinals = Counter()
    no_target = 0
    def flush():
        if not batch:
            return
        name = f"capsules-{len(parts):03d}.json"
        # Compact local parts retain every value and serve the unchanged replay API.
        (directory / name).write_text(json.dumps({"schema_version": 1, "capsules": batch}, separators=(",", ":")) + "\n", encoding="utf-8")
        parts.append({"path": name, "sha256": sha(directory/name), "capsules": len(batch)})
        batch.clear()
    with (directory/"events.jsonl").open(encoding="utf-8") as stream:
        for ordinal, line in enumerate(stream, 1):
            if time.monotonic() > deadline:
                raise TimeoutError("180s collection guard")
            if ordinal > 245760:
                raise ValueError("global event ceiling")
            c = json.loads(line)
            segment = c["capture_segment"]
            if c["candidate"] != acquisition["candidate"] or c["event_ordinal"] != ordinal or not 0 <= segment < 30:
                raise ValueError("candidate/ordinal/segment drift")
            if (c["instance_id"], c["reset_generation"]) != fence or c["tick"] // 60 != segment:
                raise ValueError("owner/segment fence drift")
            ordinals[segment] += 1
            if c["event_ordinal_native"] != ordinals[segment]:
                raise ValueError("native ordinal drift")
            actual, target, trace, _ = a2.production_identity(c)
            if (actual, target, trace) != (c["replay_hash"], c["target"], c["trace"]):
                raise ValueError("Python production replay drift")
            no_target += target[0] < 0
            events.append({k: c[k] for k in ("tick", "event_ordinal", "capture_segment", "event_ordinal_native", "source", "target", "current_body", "replay_hash")})
            batch.append(c)
            if len(batch) == 500:
                flush()
    flush()
    if len(events) != counters["attempts"] or no_target != counters["searched_no_target"] or len(events)-no_target != counters["target_found"]:
        raise ValueError("population accounting failure")
    for i, segment in enumerate(acquisition["segments"]):
        if segment["attempts"] != ordinals[i] or segment["dropped"] or not segment["owner_current"] or segment["stream_total_limit"] != 8192 or segment["stream_pending_limit"] != 256:
            raise ValueError("segment completeness/bounds failure")
    result = {"schema": 1, "attempts": len(events), "no_target": no_target, "parts": parts, "events": events,
              "stream_drops": 0, "high_water": {"pending": counters["maximum_pending_seen"],
                "segment_events": max(ordinals.values(), default=0), "total_events": len(events), "frames": 1800,
                "segments": 30, "replay_part": max((p["capsules"] for p in parts), default=0)}}
    write(directory / "population-manifest.json", result)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--project", type=Path, required=True)
    p.add_argument("--build-receipt", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--candidate", choices=("B0", "Y1"), required=True)
    p.add_argument("--arm", choices=("speed30", "speed90"), required=True)
    args = p.parse_args()
    if git("status", "--porcelain", "--untracked-files=no"):
        p.error("committed frozen source required")
    protocol = read(ROOT / PROTOCOL)
    if git("show", "HEAD:"+PROTOCOL) != (ROOT/PROTOCOL).read_text().strip():
        p.error("committed protocol required")
    for path, expected in protocol["registered_inputs"].items():
        if sha(ROOT/path) != expected:
            p.error("registered input changed: "+path)
    if not (ROOT/"docs/audits/y1-post-arrest-2026-11-01/stage-a.json").is_file():
        p.error("committed StageA receipt required")
    if not read(ROOT / "docs/audits/y1-post-arrest-2026-11-01/stage-a.json")["pass"]:
        p.error("StageA must close first")
    built = read(args.build_receipt)
    for path, expected in built["source_inputs"].items():
        if sha(ROOT/path) != expected:
            p.error("changed compiled input: "+path)
    for path in INPUTS:
        if path.startswith("godot/") and sha(ROOT/path) != sha(args.project/path[6:]):
            p.error("isolated project source mismatch: "+path)
    godot = Path("C:/Godot47/Godot_v4.7-stable_win64_console.exe")
    runtime = {"console_launcher": sha(godot), "engine": sha(godot.with_name(godot.name.replace("_console", ""))),
               "native": sha(args.project/"addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"),
               "rapier": sha(args.project/"addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")}
    if runtime != protocol["runtime"] or runtime["native"] != built["native_sha256"]:
        p.error("registered runtime mismatch")
    directory = args.output.resolve()
    if directory.exists():
        p.error("preserve existing output; fresh path required")
    directory.mkdir(parents=True)
    source = git("rev-parse", "HEAD")
    env = os.environ.copy()
    env["CYBERSAND_SOURCE_REVISION"] = source
    command = [str(godot), "--headless", "--path", str(args.project.resolve()), "--script", "res://tests/test_post_arrest_clearance.gd", "--",
               "--candidate="+args.candidate, "--arm="+args.arm, "--details=on", "--output="+directory.as_posix()]
    receipt = {"schema": 1, "source": source, "tree": git("show", "-s", "--format=%T", "HEAD"),
               "candidate": args.candidate, "arm": args.arm, "runtime": runtime, "platform": platform.platform(), "python": sys.version,
               "command": command, "protocol_sha256": sha(ROOT/PROTOCOL), "compiled_inputs": built["source_inputs"],
               "source_inputs": {s: sha(ROOT/s) for s in INPUTS}, "build_receipt_sha256": sha(args.build_receipt),
               "guards_seconds": {"capture_outer": 150, "internal": 120, "collection": 180, "replay_part_outer": 150}, "ok": False}
    write(directory/"pre-execution.json", receipt)
    try:
        with (directory/"capture.log").open("wb") as log:
            r = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=150)
        receipt["capture_exit"] = r.returncode
        if r.returncode or "ERROR:" in (directory/"capture.log").read_text(errors="replace"):
            raise ValueError("capture failed; original log retained")
        receipt["prefix"] = prefix_gate(directory, args.candidate, args.arm)
        population = collect(directory, read(directory/"acquisition.json"))
        replays = []
        for part in population["parts"]:
            report = directory/part["path"].replace("capsules-", "replay-")
            cmd = command[:command.index("--")+1] + ["--mode=replay", "--capsule-input="+str(directory/part["path"]), "--replay-report="+str(report)]
            with report.with_suffix(".log").open("wb") as log:
                replay = subprocess.run(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=150)
            result = read(report)
            if replay.returncode or not result["ok"] or result["mutation_failures"] or result["matched"] != part["capsules"] or result["input_sha256"] != part["sha256"] or result["source_revision"] != source:
                raise ValueError("native/fallback replay or mutation failure")
            replays.append({**result, "command": cmd})
        receipt["replays"] = replays
        receipt["replay_matches"] = sum(r["matched"] for r in replays)
        receipt["attempts"] = population["attempts"]
        receipt["ok"] = True
        receipt["artifact_sha256"] = {f.name: sha(f) for f in directory.iterdir() if f.suffix == ".json"}
    except Exception as error:
        receipt["error"] = str(error)
        raise
    finally:
        write(directory/"receipt.json", receipt)
    print(json.dumps({"ok": True, "candidate": args.candidate, "arm": args.arm, "prefix": True, "events": population["attempts"]}))


if __name__ == "__main__":
    main()
