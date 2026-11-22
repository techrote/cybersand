#!/usr/bin/env python3
"""Sequential, exact-source PUBPRES-003 development captures on real graphics.

No historical M/I rebuild is required to diagnose one source. The frozen v3
oracles still validate every graphical arm; the additive causal trace is a
separate diagnostic channel. All outcomes remain Draft/HOLD.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability"))
sys.path.insert(0, str(ROOT / "tools/pubpres_playability_build"))
from build_runtime import committed_inputs  # noqa: E402
import dependency_custody  # noqa: E402
from run_campaign import (copy_project, execute, git, physical_outcome_parity,
                          source_identity, verify_experimental_runtime)  # noqa: E402
from results_same_frame import reduce_receipt  # noqa: E402
from results import canonical, digest, need  # noqa: E402

ENGINE_SHA256 = {
    "linux": "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75",
    "windows": "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8",
}
FROZEN_REGISTRATION = "42b0fa3569e3df3cb4f06330c2f24f0c913ef8d1196e494900f59ae1134220ef"
OBSERVER_TARGET = "tests/pubpres003_causal_gameplay.gd"
PREDECESSOR_DRIVER_INPUTS = (
    "tools/pubpres_playability/results.py", "tools/pubpres_playability/results_same_frame.py",
    "tools/pubpres_playability/run_campaign.py", "tools/pubpres_playability/campaign.json",
    "tools/pubpres_playability_build/build_runtime.py", "tools/pubpres_playability_build/dependency_custody.py",
    "tools/pubpres_playability_build/process_owner.py", "godot/tests/pubpres_same_frame_gameplay.gd",
    "godot/tests/pubpres_playability_profile.gd", "godot/tests/pubpres_playability_compatibility.gd",
)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def verify_driver(root=ROOT):
    """Bind the actual measurement program, even when the tested app is older."""
    commit, tree = git(root, "rev-parse", "HEAD"), git(root, "rev-parse", "HEAD^{tree}")
    directory = root / "tools/pubpres003"
    tracked = {name for name in git(root, "ls-tree", "-r", "--name-only", commit, "--", "tools/pubpres003").splitlines()
               if Path(name).parent.as_posix() == "tools/pubpres003" and Path(name).suffix in (".py", ".gd")}
    actual = {p.relative_to(root).as_posix() for p in directory.iterdir() if p.is_file() and p.suffix in (".py", ".gd")}
    need(tracked and tracked == actual, "Measurement driver has missing or untracked Python/GDScript inputs")
    inputs = {}
    for relative in sorted(tracked | set(PREDECESSOR_DRIVER_INPUTS)):
        committed = subprocess.check_output(["git", "-C", str(root), "show", commit + ":" + relative])
        current = (root / relative).read_bytes()
        need(current == committed, "Measurement driver differs from committed bytes: " + relative)
        inputs[relative] = hashlib.sha256(current).hexdigest()
    return {"source_commit": commit, "source_tree": tree, "files_sha256": inputs,
            "scope": "Actual committed measurement code and frozen imported oracle/runner/build-driver closure; distinct from tested application source."}


def validate_runtime(root, source, folder, allow_drift):
    record = json.loads((folder / "PUBPRES-RUNTIME.json").read_text())
    if not record.get("toolchain_drift_allowed"):
        return verify_experimental_runtime(root, source, folder)
    need(allow_drift, "Local toolchain drift requires explicit development opt-in")
    # This is an explicit development-only branch, not a rewritten receipt or
    # a relaxation of the frozen final-qualification validator.
    platform = "windows" if os.name == "nt" else "linux"
    binary_name = "cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so"
    build_script = "tools/build_native_extension_windows.sh" if os.name == "nt" else "tools/build_native_extension.sh"
    need(record.get("schema") == "pubpres-playability-native-build-v1" and record.get("returncode") == 0
         and record.get("production_runtime_promotion") is False, "Native build failed or claims promotion")
    need(record.get("source_commit") == source["source_commit"] and record.get("source_tree") == source["source_tree"]
         and record.get("platform") == platform, "Development runtime source/platform differs")
    need(record.get("source_inputs_sha256") == committed_inputs(root, source["source_commit"]), "Development native input closure differs")
    need(record.get("runtime_file") == binary_name and record.get("build_script") == build_script, "Unexpected runtime/build script")
    binary = folder / binary_name
    need(binary.is_file() and digest(binary) == record.get("runtime_sha256")
         and binary.stat().st_size == record.get("runtime_bytes"), "Development binary hash/size differs")
    need(hashlib.sha256((root / build_script).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
         == record.get("build_script_sha256"), "Development build script differs")
    need(digest(folder / "build.log") == record.get("log_sha256"), "Development build log differs")
    dependency = dependency_custody.verify(folder, record)
    dependency_custody.verify_driver(ROOT / "tools/pubpres_playability_build", record)
    return {"manifest_path": str(folder / "PUBPRES-RUNTIME.json"),
            "manifest_sha256": digest(folder / "PUBPRES-RUNTIME.json"),
            "binary_path": str(binary), "binary_sha256": digest(binary),
            "staged_relative_path": "addons/cybersand_native/bin/" + binary_name,
            "build_commit": record["source_commit"], "checked_source_files": len(record["source_inputs_sha256"]),
            "source_inputs_sha256": hashlib.sha256(canonical(record["source_inputs_sha256"]).encode()).hexdigest(),
            "dependency_builder_commit": dependency["builder_commit"],
            "toolchain": {k: record[k] for k in ("godot_cpp_commit", "godot_cpp_library_sha256",
                "godot_cpp_dependency_sha256", "compiler_command", "compiler_version", "toolchain_drift_allowed")},
            "experimental_build": True, "qualification": "DEVELOPMENT_TOOLCHAIN_DRIFT"}


def stage_committed_project(root, source, folder):
    """Canonical committed source; no substitution of a mutable working tree."""
    project = folder / "project"
    with tempfile.TemporaryFile() as stream:
        subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "core.eol=lf", "-C", str(root),
                        "archive", "--format=tar", source, "--", "godot", "examples/worldgen"],
                       check=True, stdout=stream, timeout=120)
        stream.seek(0)
        with tarfile.open(fileobj=stream) as archive:
            for member in archive:
                if member.isdir():
                    continue
                name = Path(member.name)
                need(member.isfile() and not name.is_absolute() and ".." not in name.parts,
                     "Unexpected source archive member")
                target = project.joinpath(*name.parts[1:]) if name.parts[0] == "godot" else folder / name
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as incoming, target.open("wb") as outgoing:
                    shutil.copyfileobj(incoming, outgoing)
    return project


def planned_arms(mode):
    if mode == "baseline":
        return [{"same_frame_continuation": False, "wave_column_probe": False, "causal": False}]
    if mode == "causal":
        return [{"same_frame_continuation": False, "wave_column_probe": True, "causal": True}]
    if mode == "causal-overhead-abba":
        return [{"same_frame_continuation": False, "wave_column_probe": False, "causal": value}
                for value in (False, True, True, False)]
    key = "wave_column_probe" if mode == "native-probe-abba" else "same_frame_continuation"
    return [{"same_frame_continuation": False, "wave_column_probe": False, "causal": False, key: value}
            for value in (False, True, True, False)]


def selectors(arm, nonce):
    return {"CYBERSAND_MATERIAL_PUBLICATION": "blit", "CYBERSAND_DIAG_PHYSICS_PUBLICATION": "early",
            "CYBERSAND_DIAG_PRESENTATION": "coherent", "CYBERSAND_DIAG_MATERIAL_TIMING": "measured",
            "CYBERSAND_DIAG_RENDER_CADENCE": "repaired", "CYBERSAND_DIAG_NATIVE_RENDEZVOUS": "0",
            "CYBERSAND_DIAG_COMMON_OBSERVER": "0", "CYBERSAND_PLAYABILITY_RENDER_THREAD": "safe",
            "CYBERSAND_DIAG_MATERIAL_POOL_POLICY": "eager", "CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES": "0",
            "CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE": "1" if arm["wave_column_probe"] else "0",
            "CYBERSAND_DIAG_SAME_FRAME_CONTINUATION": "1" if arm["same_frame_continuation"] else "0",
            "CYBERSAND_DIAG_PUBPRES_CAUSAL": "1" if arm["causal"] else "0",
            "CYBERSAND_SHADER_NONCE": nonce, "CYBERSAND_SHADER_CACHE_STATE": "isolated-project-and-profile"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "runtime", "engine", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--rapier-runtime", type=Path, help="Optional materialized binary; must match committed source receipt")
    parser.add_argument("--display-wrapper", type=Path)
    parser.add_argument("--case", action="append", required=True)
    parser.add_argument("--mode", choices=("baseline", "causal", "native-probe-abba", "same-frame-abba", "causal-overhead-abba"), default="baseline")
    parser.add_argument("--allow-development-toolchain-drift", action="store_true")
    args = parser.parse_args()
    driver_identity = verify_driver()
    root, runtime, output, engine = (getattr(args, name).resolve() for name in ("source", "runtime", "output", "engine"))
    need(not output.exists(), "Output exists; retain old evidence and choose a new path")
    source = source_identity(root)
    source["native_runtime"] = validate_runtime(root, source, runtime, args.allow_development_toolchain_drift)
    platform = "windows" if os.name == "nt" else "linux"
    need(digest(engine) == ENGINE_SHA256[platform], "Engine is not the pinned official platform executable")
    campaign_path = ROOT / "tools/pubpres_playability/campaign.json"
    need(digest(campaign_path) == FROZEN_REGISTRATION, "Frozen predecessor registration changed")
    campaign = json.loads(campaign_path.read_text())
    choices = {c["id"]: c for c in campaign["cases"]}
    need(len(set(args.case)) == len(args.case) and set(args.case) <= set(choices), "Unknown or repeated workload")
    need(not args.mode.startswith("native-probe") or all(choices[c]["water_law"] == "wave_flow_v1" for c in args.case),
         "Native Wave-stage probe requires Wave workloads")
    rapier_receipt = "godot/addons/godot-rapier2d/runtime-provenance." + platform + ".json"
    rapier = json.loads(subprocess.check_output(["git", "-C", str(root), "show", source["source_commit"] + ":" + rapier_receipt]))
    rapier_binary = args.rapier_runtime.resolve() if args.rapier_runtime else root / rapier["artifact"]
    need(digest(rapier_binary) == rapier["sha256"], "Rapier binary differs from its committed source receipt")
    for relative, wanted in rapier.get("source_inputs", {}).items():
        need(hashlib.sha256(subprocess.check_output(["git", "-C", str(root), "show", source["source_commit"] + ":" + relative])).hexdigest()
             == wanted, "Rapier source closure differs: " + relative)
    observer = HERE / "pubpres_causal_gameplay.gd"
    campaign["overlay_sha256"][OBSERVER_TARGET] = digest(observer)
    campaign["observer_entrypoint"] = OBSERVER_TARGET
    campaign["pubpres003_extension"] = {"schema": "pubpres003-development-campaign-v1", "mode": args.mode,
        "frozen_predecessor_sha256": FROZEN_REGISTRATION, "observer_sha256": digest(observer),
        "scope": "Explicit development comparison. Original v3 native/actor/terrain/input/Water/GPU/callback oracles unchanged; separate bounded causal sidecar."}
    treatment_order = planned_arms(args.mode)
    output.mkdir(parents=True)
    write_json(output / "campaign.json", campaign)
    request = {"schema": "pubpres003-focused-request-v1", "source": source, "engine_sha256": digest(engine),
               "rapier_sha256": digest(rapier_binary), "mode": args.mode, "cases": [choices[c] for c in args.case],
               "order": treatment_order, "physical_acceptance": "HOLD", "development": True,
               "toolchain_drift_opt_in": args.allow_development_toolchain_drift,
               "runner_sha256": digest(__file__), "observer_sha256": digest(observer),
               "measurement_driver": driver_identity,
               "baseline_comparison_scope": "Same-source selector pairs only; separate source captures are whole-source comparisons."}
    write_json(output / "request.json", request)
    results, failures = [], []
    template = stage_committed_project(root, source["source_commit"], output / "template")
    # Each arm can move independently of the checkout's ../examples layout.
    # These are exact committed JSON bytes, as in the owner package projection.
    recipes = template.parent / "examples/worldgen"
    if recipes.is_dir():
        shutil.copytree(recipes, template / "authoring/worldgen", dirs_exist_ok=True)
    native_target = template / source["native_runtime"]["staged_relative_path"]
    native_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source["native_runtime"]["binary_path"], native_target)
    rapier_target = template / Path(rapier["artifact"]).relative_to("godot")
    rapier_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(rapier_binary, rapier_target)
    for relative, expected in campaign["overlay_sha256"].items():
        original = observer if relative == OBSERVER_TARGET else ROOT / "godot" / relative
        need(digest(original) == expected, "Registered observer dependency changed: " + relative)
        target = template / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, target)
    execute(engine, ["--headless", "--audio-driver", "Dummy", "--path", str(template), "--editor", "--import"],
            output / "import", source["source_commit"], {}, 300)
    driver = "opengl3_angle" if os.name == "nt" else "opengl3"
    for case_name in args.case:
        case = choices[case_name]
        arms = []
        for index, treatment in enumerate(treatment_order):
            folder = output / case_name / f"{index}-C"
            project = output / "projects" / f"{case_name}-{index}"
            project.parent.mkdir(parents=True, exist_ok=True)
            copy_project(template, project, imported=True)
            folder.mkdir(parents=True)
            receipt = folder / "receipt.json"
            nonce = uuid.uuid4().hex
            setting = selectors(treatment, nonce)
            arm = {**campaign["arms"]["C"], **{k: v for k, v in treatment.items() if k != "causal"}}
            arguments = ["--path", str(project), "--rendering-method", "gl_compatibility", "--rendering-driver", driver,
                "--render-thread", "safe", "--audio-driver", "Dummy", "--log-file", str(folder / "godot.log"),
                "--script", "res://" + OBSERVER_TARGET, "--", "--receipt=" + str(receipt),
                "--fixture=" + case["fixture"], "--camera=" + case["camera"], "--workers=" + str(case["workers"]),
                "--water-law=" + case["water_law"], "--water-variant=" + case.get("water_variant", "reference"),
                "--water-profile=" + case.get("water_profile", campaign["measurement"]["water_profile"]),
                "--input-mode=" + case.get("input_mode", "tape"), "--command-mode=repeated_callback", "--observer-mode=full"]
            write_json(folder / "arm.json", {"source": source, "scenario": case, "arm": arm, "causal": treatment["causal"],
                       "order_index": index, "nonce": nonce, "selectors": setting, "arguments": arguments})
            print(case_name, index, treatment, flush=True)
            try:
                process = execute(engine, arguments, folder, source["source_commit"], setting, 420, args.display_wrapper)
                data = json.loads(receipt.read_text())
                need(data["source_identity"]["source_sha"] == source["source_commit"] and data["case_nonce"] == nonce,
                     "Captured source/nonce differs")
                need(data["camera"] == case["camera"] and data["workers"] == case["workers"]
                     and data["water_law"] == case["water_law"]
                     and data["water_profile"] == case.get("water_profile", campaign["measurement"]["water_profile"]),
                     "Captured workload differs")
                effective = copy.deepcopy(campaign)
                effective["arms"]["C"] = arm
                analysis = reduce_receipt(receipt, effective, project=project, engine=engine, arm_letter="C")
                from causal_trace import reduce_causal
                causal = reduce_causal(receipt, expected_enabled=treatment["causal"])
                write_json(folder / "analysis.json", analysis)
                write_json(folder / "causal-analysis.json", causal)
                process["app_sampler_pid_matched"] = process["observed_application_pid"] == data["process_id"]
                if not process["app_sampler_pid_matched"]:
                    process["sampled_peak_rss_bytes"] = None
                write_json(folder / "process.json", process)
                arms.append({"arm": "C", "index": index, "statistics": analysis,
                             "causal": causal, "process": process, "receipt_sha256": digest(receipt)})
                shutil.rmtree(project)
            except Exception as error:
                failures.append({"case": case_name, "index": index, "reason": str(error)})
                print("Retained failed arm:", str(error), flush=True)
            write_json(output / "progress.json", {"complete": False, "cases": results, "current_case": case_name,
                       "collected_arms": len(arms), "failures": failures, "physical_acceptance": "HOLD"})
        parity = physical_outcome_parity(arms)
        if parity["same_source_pairs_equal"] is False:
            failures.append({"case": case_name, "reason": "Same-source physical outcome parity failed; causal attribution refused"})
        results.append({"case": case_name, "arms": arms, "physical_outcome_parity": parity})
    summary = {"schema": "pubpres003-focused-result-v1", "complete": not failures,
               "source": source, "mode": args.mode, "cases": results, "failures": failures,
               "physical_acceptance": "HOLD", "development": True}
    write_json(output / "summary.json", summary)
    print(json.dumps({"output": str(output), "complete": not failures, "failures": failures, "physical_acceptance": "HOLD"}))
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
