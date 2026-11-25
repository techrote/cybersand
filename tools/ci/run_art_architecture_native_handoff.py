#!/usr/bin/env python3
"""Run the separate source-pinned Art/Architecture native Workbench experiment.

This runs the actual qualified Architecture Workbench with the exact current Art
provider closure overlaid. It does not qualify or modify either principal branch
or evaluator. All requests are explicit deterministic loopback fixtures.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
ARCHITECTURE = "17c6b5b35049b7b2541c2deeea23c02fd1e2fc5d"
ART = "2743f89a0df6f6afcf7484e859c10790d521e74b"
FIXTURE = "tools/fixtures/art_architecture_native_handoff.gd"
OVERLAYS = (
    "godot/scripts/art_provider.gd", "godot/scripts/art_response_preparation.gd",
    "godot/scripts/art_redaction.gd", "godot/scripts/art_traffic_archive.gd",
    "godot/scripts/art_proposal_transport.gd",
)
NATIVE = "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
GODOT_SHA = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
MARKER = "ART_ARCHITECTURE_NATIVE_RESULT "


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=60)


def sha(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def source_identity() -> dict:
    commit = git("rev-parse", "HEAD").decode().strip()
    tree = git("rev-parse", "HEAD^{tree}").decode().strip()
    runtime = {}
    for name in (NATIVE, RAPIER):
        pointer = git("show", "HEAD:" + name).decode()
        match = re.search(r"oid sha256:([0-9a-f]{64})", pointer)
        actual = sha(ROOT / name)
        if not match or match[1] != actual:
            raise ValueError("Native runtime differs from its committed LFS identity: " + name)
        runtime[name] = actual
    changed = set(git("diff", "--name-only", "HEAD").decode().splitlines())
    if changed - {NATIVE, RAPIER}:
        raise ValueError("Uncommitted tracked source: " + repr(sorted(changed)))
    untracked = git("ls-files", "--others", "--exclude-standard").decode().splitlines()
    if any(not name.endswith(".gd.uid") for name in untracked):
        raise ValueError("Untracked source is outside the committed experiment: " + repr(untracked))
    expected = set(OVERLAYS) | {FIXTURE, "tools/ci/run_art_architecture_native_handoff.py",
                               "docs/audits/2026-11-25-art-architecture-native-handoff/README.md"}
    delta = set(git("diff", "--name-only", ARCHITECTURE, "HEAD").decode().splitlines())
    if delta != expected:
        raise ValueError("Combined candidate differs from the declared five-file Art overlay and three apparatus records: " + repr(sorted(delta)))
    unchanged = (
        "godot/scripts/batch_lab/architecture_stage_session.gd",
        "godot/scripts/batch_lab/architecture_workflow.gd",
        "godot/scripts/batch_lab/architecture_proposal_bridge.gd",
        "godot/scripts/batch_lab/architecture_planning_adapter.gd",
        "godot/scripts/batch_lab/architecture_campaign.gd",
        "godot/scripts/batch_lab/architecture_stage_plan.gd",
        "godot/scripts/shared_workbench.gd", "godot/scripts/art_batch_panel.gd",
        "godot/scripts/art_batch_executor.gd", "godot/scripts/simulation_worker.gd",
    )
    for name in unchanged:
        if (ROOT / name).read_bytes() != git("show", ARCHITECTURE + ":" + name):
            raise ValueError("Qualified Architecture/native host was modified: " + name)
    files = {name: sha(ROOT / name) for name in (*OVERLAYS, *unchanged, FIXTURE,
                                                "tools/ci/run_art_architecture_native_handoff.py")}
    return {"commit": commit, "tree": tree, "architecture_application": ARCHITECTURE,
            "art_overlay_source": ART, "files_sha256": files, "runtime_sha256": runtime}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.godot = args.godot.resolve()
    if args.output.exists() or sha(args.godot) != GODOT_SHA:
        parser.error("Fresh output directory and exact pinned Linux Godot 4.7 required")
    source = source_identity()
    args.output.mkdir(parents=True)
    profile = args.output / "profile"
    profile.mkdir()
    evidence = args.output / "native-artifacts"
    evidence.mkdir()
    env = os.environ.copy()
    env.update(XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile),
               CYBERSAND_SOURCE_REVISION=source["commit"],
               ART_ARCHITECTURE_NATIVE_EVIDENCE=str(evidence))
    command = [str(args.godot), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
               "--path", str(ROOT / "godot"), "--script", str(ROOT / FIXTURE)]
    if not args.graphical:
        command.insert(1, "--headless")
    inputs = {"format": "cybersand-art-architecture-native-handoff-inputs-v1", "source": source,
              "godot_sha256": sha(args.godot), "command": command, "graphical": args.graphical,
              "model_calls": 0, "fresh_profile": True,
              "scope": "Separate combined fixture experiment; no principal evaluator or physical owner acceptance."}
    write_json(args.output / "inputs.json", inputs)
    result = {"source": source, "timeout": False, "returncode": None, "passed": False}
    began = time.monotonic()
    log = args.output / "process.log"
    with log.open("wb") as stream:
        try:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, timeout=args.timeout)
            result["returncode"] = process.returncode
        except subprocess.TimeoutExpired:
            result["timeout"] = True
    result.update(elapsed_seconds=time.monotonic() - began, log_sha256=sha(log),
                  inputs_sha256=sha(args.output / "inputs.json"), artifacts_sha256={
                      path.relative_to(evidence).as_posix(): sha(path)
                      for path in sorted(evidence.rglob("*")) if path.is_file()})
    text = log.read_text(encoding="utf-8", errors="replace")
    lines = [line[len(MARKER):] for line in text.splitlines() if line.startswith(MARKER)]
    if len(lines) == 1:
        result["fixture"] = json.loads(lines[0])
    fixture = result.get("fixture", {})
    try:
        result["source_unchanged"] = source_identity() == source
    except (ValueError, subprocess.SubprocessError) as error:
        result["source_error"] = str(error)
        result["source_unchanged"] = False
    result["passed"] = (result["returncode"] == 0 and not result["timeout"] and result["source_unchanged"]
                        and len(lines) == 1 and type(fixture.get("checks")) is int and fixture["checks"] >= 80
                        and fixture.get("failures") == [] and fixture.get("native_stages_completed") == 3
                        and fixture.get("actual_http_exchanges") == 2 and fixture.get("ordinary_completions") == 0
                        and fixture.get("model_calls") == 0 and fixture.get("source_revision") == source["commit"]
                        and fixture.get("provider_sha256") == source["files_sha256"][OVERLAYS[0]]
                        and fixture.get("adapter_sha256") == source["files_sha256"][OVERLAYS[-1]]
                        and not any(token in text for token in ("ERROR:", "Parse Error:", "Failed to load script")))
    write_json(args.output / "result.json", result)
    print(json.dumps({"passed": result["passed"], "source": source["commit"],
                      "returncode": result["returncode"], "checks": fixture.get("checks"),
                      "failures": fixture.get("failures"), "output": str(args.output)}))
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
