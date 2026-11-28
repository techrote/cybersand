"""Run the unchanged five-minute owner workload with the selected PUBPRES flags.

The historical observer, actions, duration, reducer and CPU/RSS process observer
remain unchanged. This additive entry binds the three positively evaluated owner
selectors and refuses startup readback that did not actually enable them.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_final_recovery"))
import run_sustained_owner as original

CASES = ("wave512", "mixed2048")
OWNER_FLAGS = {
    "CYBERSAND_WORKBENCH_FLIGHT_PACING": "1",
    "CYBERSAND_WORKBENCH_COUPLING_CLOCK": "1",
    "CYBERSAND_WORKBENCH_EMPTY_EFFECTS": "1",
}
READY_FLAGS = ("flight_pacing", "coupling_clock", "empty_effects")


def driver_identity():
    identity = original.driver_identity()
    relative = Path(__file__).resolve().relative_to(ROOT).as_posix()
    committed = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + relative])
    original.need(Path(__file__).read_bytes() == committed,
                  "Mainline sustained driver differs from committed source")
    identity["files_sha256"][relative] = original.digest(Path(__file__))
    return identity


def reduce_session(folder, case, source, project, engine, selected, process):
    ready = json.loads((folder / "startup.json").read_bytes())
    original.need(all(ready.get(name + "_requested") == "1"
                      and ready.get(name + "_enabled") is True for name in READY_FLAGS),
                  "Actual startup did not enable all three selected owner policies")
    material = ready.get("material_publication", {})
    original.need(ready.get("platform") == ready.get("display_server") == "Windows"
                  and material.get("backend") == "full" and material.get("full_image_slots") == 2,
                  "Actual startup differs from Windows full two-slot publication")
    row = original.reduce_session(folder, case, source, project, engine, selected, process)
    row["selected_owner_readback"] = {
        name: {"requested": ready[name + "_requested"], "enabled": ready[name + "_enabled"]}
        for name in READY_FLAGS
    }
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("runtime", "stock-engine", "output"):
        parser.add_argument("--" + option, type=Path, required=True)
    parser.add_argument("--case", choices=CASES, action="append")
    args = parser.parse_args()
    original.need(os.name == "nt", "Sustained owner qualification requires actual Windows execution")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = original.source_identity(ROOT)
    source["native_runtime"] = original.validate_runtime(ROOT, source, args.runtime, False)
    # The existing custody reader either admits a fresh exact-source build or
    # independently verifies every native/build input in an explicit retained
    # binding. Keep that original build identity in source.native_runtime;
    # a script-only application change must not be relabelled as a native build.
    choice = original.recovery_policy.selection()
    selected = original.recovery_policy.configuration(choice)
    original.need(selected == {"architecture": "stock_safe", "engine": "stock",
                               "render_thread": "safe", "actual_submission": 0, "render_lookahead": 0}
                  and choice["water_composition"] == 1 and choice["task_completion"] == 0,
                  "This mission retains Stock Safe, Water composition and all-worker completion")
    engine = args.stock_engine.resolve()
    original.need(original.digest(engine) == original.ENGINE_SHA256["windows"],
                  "Official pinned Godot 4.7 engine bytes differ")
    cases = args.case or list(CASES)
    original.need(len(cases) == len(set(cases)), "Repeated scene names would overwrite evidence")
    launchers = {case: original.launcher_settings(case, selected) for case in cases}
    override = output / "override.cfg"
    override.write_bytes(launchers[cases[0]]["config"].encode("utf-8"))
    program = "tests/pubpres_sustained_owner.gd"
    overlays = {
        "tests/pubpres_playability_owner_start.gd": original.WINDOWS / "owner_start.gd",
        program: original.HERE / "sustained_owner.gd",
        "override.cfg": override,
    }
    campaign = {"overlay_sha256": {name: original.digest(path) for name, path in overlays.items()}}
    identity = driver_identity()
    original.need(identity["source_commit"] == source["source_commit"],
                  "Application and sustained driver sources differ")
    project = original.prepare(ROOT, source, output / "template", campaign, engine, None,
                               overlay_sources=overlays)
    original.strict_logs(output / "template/import")
    result = {
        "schema": "pubpres-mainline-sustained-v1",
        "platform": "Windows hosted ANGLE", "source": source, "driver": identity,
        "policy": choice, "selected_owner_flags": OWNER_FLAGS,
        "unchanged_observer_sha256": original.digest(original.HERE / "sustained_owner.gd"),
        "unchanged_reducer_sha256": original.digest(ROOT / "tools/pubpres_final_recovery/run_sustained_owner.py"),
        "rows": [], "failures": [], "physical_acceptance": "HOLD",
        "scope": "Original 300-second gameplay, authoring, camera, pause/manual-step/resume and ambient ownership workload. "
                 "Original raw traces, completion-gap reducer and process CPU/RSS observer. Selected owner policies "
                 "are verified in actual startup. Hosted ANGLE is not physical NVIDIA presentation acceptance.",
    }
    for case in cases:
        folder = output / case
        settings = {**launchers[case]["settings"], **OWNER_FLAGS,
                    "CYBERSAND_PLAYABILITY_OWNER_RECEIPT": str(folder / "startup.json")}
        command = ["--path", str(project), "--rendering-method", "gl_compatibility",
                   "--rendering-driver", "opengl3_angle", "--render-thread", "safe",
                   "--audio-driver", "Dummy", "--script", "res://" + program]
        try:
            original.need(launchers[case]["config"].encode("utf-8") == override.read_bytes(),
                          "Owner override differs between scenes")
            print("Selected five-minute owner scene", case, flush=True)
            process = original.execute_with_resources(engine, command, folder, source["source_commit"], settings, 660)
            original.strict_logs(folder)
            row = reduce_session(folder, case, source, project, engine,
                                 {**selected, "water": choice["water_composition"]}, process)
            result["rows"].append(row)
        except Exception as exc:
            result["failures"].append({"case": case, "reason": str(exc)})
        original.write_json(output / "SUMMARY.json", result)
    return int(bool(result["failures"]))


if __name__ == "__main__":
    raise SystemExit(main())
