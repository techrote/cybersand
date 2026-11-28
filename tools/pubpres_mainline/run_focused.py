#!/usr/bin/env python3
"""Production-path spawn/profile and rendered retained-endpoint regression gates."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import common

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_final_recovery"))
from identity import driver_identity
from run_campaign import source_identity
from retained_runtime import validate_runtime
from run_regressions import stage_source, run, terminal_json
from run_focus import ENGINE_SHA256

CASES = (
    ("test_transport_profiles", "TRANSPORT_PROFILES: preset/roundtrip/inheritance/pair/minimum/extreme/invalid-preservation passed", False),
    ("test_transport_profile_reuse", "PUBPRES_TRANSPORT_REUSE_RESULT ", False),
    ("test_microscenarios", "MICROSCENARIOS:", False),
    ("verify_pubpres_owner_gameplay_rotation", "PUBPRES_OWNER_GAMEPLAY_ROTATION_OK", False),
    ("test_workbench_retained_water_hold", "PUBPRES_RETAINED_WATER_HOLD_RESULT ", False),
    ("test_workbench_retained_water_hold_native", "PUBPRES_RETAINED_WATER_NATIVE_RESULT ", True),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("runtime", "engine", "output"):
        parser.add_argument("--" + key, required=True, type=Path)
    parser.add_argument("--source", type=Path, default=ROOT)
    args = parser.parse_args()
    root, engine, output = args.source.resolve(), args.engine.resolve(), args.output.resolve()
    common.require(root == ROOT and not output.exists(), "Use the exact committed helper and fresh evidence")
    source = source_identity(root)
    native = validate_runtime(root, source, args.runtime.resolve(), False)
    platform = common.platform_name()
    common.require(common.digest(engine) == ENGINE_SHA256[platform], "Official4.7 engine bytes differ")
    output.mkdir(parents=True)
    project = stage_source(root, source["source_commit"], output)
    common.install_runtime(root, args.runtime.resolve(), project, platform)
    shutil.copyfile(root / common.RAPIER[platform], project / common.RAPIER[platform].removeprefix("godot/"))
    loaded = common.observed_runtime(root, args.runtime.resolve(), project, platform)
    authored = {path.relative_to(project).as_posix(): common.digest(path) for path in project.rglob("*") if path.is_file()}
    report = {"schema": "pubpres-mainline-focused-v1", "source": source, "driver": driver_identity(),
              "native": native, "loaded_runtime": loaded, "engine_sha256": common.digest(engine),
              "selectors": common.SELECTORS, "outcomes": [], "complete": False,
              "physical_acceptance": "HOLD", "staged_input_files_sha256": authored,
              "scope": "Original transport/native semantics, mutation/concurrency controls, actual bounded recorder and graphical retained endpoint; no physical monitor claim."}
    def save(): common.write_json(output / "SUMMARY.json", report)
    save()
    clean = {key: value for key, value in os.environ.items() if not key.startswith(("CYBERSAND_", "WB_COMBINED_"))}
    for test, marker, graphical in (("import", "", False), *CASES):
        folder = output / test
        profile = output / (test + "-profile")
        profile.mkdir()
        env = common.selected_environment(dict(clean, APPDATA=str(profile), LOCALAPPDATA=str(profile),
            XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile), XDG_CACHE_HOME=str(profile),
            CYBERSAND_SOURCE_REVISION=source["source_commit"], CYBERSAND_RETAINED_WATER_NATIVE_OUTPUT=str(folder / "receipt.json")))
        command = [str(engine), "--path", str(project), "--audio-driver", "Dummy", "--render-thread", "safe"]
        if graphical:
            command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle" if platform == "windows" else "opengl3"]
        else:
            command += ["--headless"]
        command += ["--editor", "--import", "--quit"] if test == "import" else ["--script", "res://tests/" + test + ".gd"]
        row = run(command, env, folder, 600)
        row.update(test=test, graphical=graphical, valid=False)
        report["outcomes"].append(row)
        text = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace")
        try:
            common.require(row["returncode"] == 0 and not row["timed_out"] and "ERROR:" not in text, "Owned fixture process failed")
            if "RESULT " in marker:
                row["result"] = terminal_json(text, marker)
            elif marker:
                common.require(text.count(marker) == 1, "Original completion marker absent or repeated")
                if test == "test_microscenarios":
                    match = re.search(r"MICROSCENARIOS: (\d+) assertions; (\d+) failures", text)
                    common.require(match is not None and int(match[1]) > 0 and int(match[2]) == 0, "MicroScenario original assertions failed")
            if graphical:
                receipt = json.loads((folder / "receipt.json").read_bytes())
                common.require(receipt.get("schema") == "pubpres-retained-water-native-v1"
                               and receipt.get("source_revision") == source["source_commit"]
                               and receipt.get("engine_sha256") == common.digest(engine)
                               and receipt.get("failures") == [] and receipt.get("checks", 0) >= 45
                               and receipt.get("display") in ("Windows", "X11")
                               and receipt.get("selected_owner_readback") == {"flight_pacing": True, "coupling_clock": True, "empty_effects": True},
                               "Mounted retained endpoint receipt differs")
                for name, expected in receipt["input_hashes"].items():
                    common.require(name.startswith("res://") and common.digest(project / name.removeprefix("res://")) == expected,
                                   "Mounted retained endpoint source input differs")
                images = receipt.get("framebuffer_files_sha256", {})
                common.require(set(images) == {"held.png", "expired.png", "hidden-control.png", "restored.png"},
                               "Mounted retained endpoint framebuffer controls are incomplete")
                for name, expected in images.items():
                    common.require(common.digest(folder / name) == expected, "Mounted framebuffer control changed: " + name)
                probes = receipt.get("probes", [])
                common.require(len(probes) == 2 and [value.get("label") for value in probes] == ["held", "expired"]
                               and probes[0].get("selected") is True and probes[0].get("source") == "held"
                               and probes[1].get("selected") is False and probes[1].get("hold_age_usec", 0) >= 100000
                               and str(probes[1].get("reason", "")).startswith("hold_expired:"),
                               "Both unexpired and nonrenewable expired graphical probes must execute")
                row.update(receipt=receipt, receipt_sha256=common.digest(folder / "receipt.json"))
            row["valid"] = True
        except Exception as error:
            row["failure"] = str(error)
        save()
        if test == "import" and not row["valid"]:
            break
    report["source_mutations"] = [name for name, expected in authored.items()
        if name not in {".godot/global_script_class_cache.cfg", ".godot/extension_list.cfg"}
        and (not (project / name).is_file() or common.digest(project / name) != expected)]
    report["complete"] = len(report["outcomes"]) == len(CASES) + 1 and all(row["valid"] for row in report["outcomes"]) and not report["source_mutations"]
    save()
    print(json.dumps({"complete": report["complete"], "failed": [r["test"] for r in report["outcomes"] if not r["valid"]]}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
