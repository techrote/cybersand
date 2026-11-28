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
    if mode == "renderer-abba":
        return [{"same_frame_continuation": False, "wave_column_probe": False, "causal": False, "material": value}
                for value in ("full", "blit", "blit", "full")]
    key = "wave_column_probe" if mode == "native-probe-abba" else "same_frame_continuation"
    return [{"same_frame_continuation": False, "wave_column_probe": False, "causal": False, key: value}
            for value in (False, True, True, False)]


def selectors(arm, nonce, retirement_source="stage"):
    material = arm.get("material", "blit")
    return {"CYBERSAND_MATERIAL_PUBLICATION": material, "CYBERSAND_DIAG_PHYSICS_PUBLICATION": "early",
            "CYBERSAND_DIAG_PRESENTATION": "coherent", "CYBERSAND_DIAG_MATERIAL_TIMING": "measured",
            "CYBERSAND_DIAG_RENDER_CADENCE": "repaired", "CYBERSAND_DIAG_NATIVE_RENDEZVOUS": "0",
            "CYBERSAND_DIAG_COMMON_OBSERVER": "0", "CYBERSAND_PLAYABILITY_RENDER_THREAD": "safe",
            "CYBERSAND_DIAG_MATERIAL_POOL_POLICY": "eager" if material == "blit" else "",
            "CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES": "0",
            "CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE": "1" if arm["wave_column_probe"] else "0",
            "CYBERSAND_DIAG_SAME_FRAME_CONTINUATION": "1" if arm["same_frame_continuation"] else "0",
            "CYBERSAND_DIAG_PUBPRES_CAUSAL": "1" if arm["causal"] else "0",
            "CYBERSAND_DIAG_PHYSICS_CAUSAL_TRACE": "1" if arm["causal"] else "0",
            "CYBERSAND_DIAG_MATERIAL_RETIREMENT_SOURCE": retirement_source,
            "CYBERSAND_SHADER_NONCE": nonce, "CYBERSAND_SHADER_CACHE_STATE": "isolated-project-and-profile"}


def validate_requested_capture(data, case, campaign, source_commit, nonce, driver, retirement_source="stage"):
    """A valid registered receipt must also be the particular requested arm."""
    need(data["source_identity"]["source_sha"] == source_commit and data["case_nonce"] == nonce,
         "Captured source/nonce differs")
    expected = {"renderer": driver, "render_thread": {"requested": "safe", "runtime": "safe"},
                "camera": case["camera"], "workers": case["workers"], "water_law": case["water_law"],
                "water_profile": case.get("water_profile", campaign["measurement"]["water_profile"]),
                "water_variant": case.get("water_variant", "reference"),
                "input_mode": case.get("input_mode", "tape"),
                "command_mode": "repeated_callback", "observer_mode": "full"}
    need(data["fixture"]["name"] == case["fixture"], "Requested fixture differs")
    for key, wanted in expected.items():
        need(data[key] == wanted, "Requested capture differs: " + key)
    if retirement_source == "target":
        for phase in ("selectors_before", "selectors_after"):
            need(data[phase]["requested"].get("CYBERSAND_DIAG_MATERIAL_RETIREMENT_SOURCE") == "target",
                 "Requested retirement source differs")
        need(data["selectors_after"]["material"].get("retirement_source") == "target",
             "Target retirement did not reach the live material publisher")


def validate_complete_comparison(arms, count):
    """Retain the predecessor's complete hardware/workload matching contract."""
    need(len(arms) == count and [arm["index"] for arm in arms] == list(range(count)),
         "Incomplete or reordered registered comparison")
    matches = [arm["statistics"]["match"] for arm in arms]
    need(all(canonical(match) == canonical(matches[0]) for match in matches),
         "Unmatched hardware, rendering owner, fixture or workload")


def observed_gap_counts(trace: Path, windows: dict, thresholds: list[int]) -> dict:
    with trace.open(encoding="utf-8") as stream:
        rows = (json.loads(line) for line in stream)
        times = sorted(row["time_usec"] for row in rows if row["event"] == "rapier_step")
    result = {}
    for name, window in windows.items():
        selected = [time for time in times if window["start_usec"] <= time <= window["end_usec"]]
        gaps = [b - a for a, b in zip(selected, selected[1:])]
        result[name] = {str(ms): sum(gap > ms * 1000 for gap in gaps) for ms in thresholds}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "runtime", "engine", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--rapier-runtime", type=Path, help="Optional materialized binary; must match committed source receipt")
    parser.add_argument("--display-wrapper", type=Path)
    parser.add_argument("--case", action="append", required=True)
    parser.add_argument("--mode", choices=("baseline", "causal", "native-probe-abba", "same-frame-abba", "causal-overhead-abba", "renderer-abba"), default="baseline")
    parser.add_argument("--allow-development-toolchain-drift", action="store_true")
    parser.add_argument("--completion-role", choices=("C", "D"),
                        help="Bind to the registered Completion candidate or exact frozen donor")
    parser.add_argument("--retirement-source", choices=("stage", "target"), default="stage")
    parser.add_argument("--material", choices=("blit", "full"), default="blit")
    parser.add_argument("--sustained", action="store_true", help="Require a separate 60-second C gameplay capture")
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
    registration = None
    if args.completion_role:
        relative = "tools/pubpres_completion/registration.json"
        registration_path = ROOT / relative
        actual = registration_path.read_bytes()
        committed = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + relative])
        need(committed == actual, "Completion registration differs from the driver commit")
        registration = json.loads(actual)
        need(registration["schema"] == "pubpres-completion-campaign-v1"
             and set(args.case) <= set(registration["final_cases"]), "Case absent from Completion registration")
        for definition in registration["additional_cases"]:
            inherited = choices[definition["base"]]
            additions = {key: value for key, value in definition.items() if key != "base"}
            need(set(additions) <= {"id", "camera", "workers", "fixture"}
                 and additions["id"] not in choices, "Unexpected new workload registration")
            choices[additions["id"]] = {**inherited, **additions}
        campaign["cases"] = list(choices.values())
        campaign["fixtures"]["basin1024"] = {"extent": [1024, 1024], "kind": "authored_setup_v2"}
        expected_source = registration["reference_sources"]["D"] if args.completion_role == "D" else {
            "source_commit": driver_identity["source_commit"], "source_tree": driver_identity["source_tree"]}
        need(all(source[field] == expected for field, expected in expected_source.items()),
             "Workload is bound to a different registered Completion source")
        need(args.completion_role == "C" or args.retirement_source == "stage",
             "Frozen donor cannot use a candidate renderer mode")
        driver_identity["files_sha256"][relative] = digest(registration_path)
    need(len(set(args.case)) == len(args.case) and set(args.case) <= set(choices), "Unknown or repeated workload")
    if args.sustained:
        need(registration and registration["sustained_minimum_usec"] == 60000000
             and args.completion_role == "C" and args.mode == "baseline" and args.material == "full"
             and args.case == registration["development_cases"], "Sustained capture requires the registered C gameplay workload")
        campaign["measurement"]["minimum_capture_usec"] = registration["sustained_minimum_usec"]
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
    if registration and args.mode == "same-frame-abba":
        need(["on" if arm["same_frame_continuation"] else "off" for arm in treatment_order]
             == registration["continuation_order"], "Continuation order differs from the registration")
    if registration and args.mode == "renderer-abba":
        need([arm["material"] for arm in treatment_order] == registration["renderer_order"],
             "Renderer order differs from the registration")
    output.mkdir(parents=True)
    write_json(output / "campaign.json", campaign)
    request = {"schema": "pubpres003-focused-request-v1", "source": source, "engine_sha256": digest(engine),
               "rapier_sha256": digest(rapier_binary), "mode": args.mode, "cases": [choices[c] for c in args.case],
               "order": treatment_order, "physical_acceptance": "HOLD", "development": True,
               "completion_role": args.completion_role, "material": args.material,
               "material_retirement_source": args.retirement_source,
               "sustained_minimum_usec": campaign["measurement"]["minimum_capture_usec"] if args.sustained else None,
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
            treatment = {"material": args.material, **treatment}
            folder = output / case_name / f"{index}-C"
            project = output / "projects" / f"{case_name}-{index}"
            project.parent.mkdir(parents=True, exist_ok=True)
            copy_project(template, project, imported=True)
            folder.mkdir(parents=True)
            receipt = folder / "receipt.json"
            nonce = uuid.uuid4().hex
            retirement = args.retirement_source if treatment["material"] == "blit" else "stage"
            setting = selectors(treatment, nonce, retirement)
            arm = {**campaign["arms"]["C"], **{k: v for k, v in treatment.items() if k != "causal"}}
            if treatment["material"] == "full":
                arm["material_pool_policy"] = None
            arguments = ["--path", str(project), "--rendering-method", "gl_compatibility", "--rendering-driver", driver,
                "--render-thread", "safe", "--audio-driver", "Dummy", "--log-file", str(folder / "godot.log"),
                "--script", "res://" + OBSERVER_TARGET, "--", "--receipt=" + str(receipt),
                "--fixture=" + case["fixture"], "--camera=" + case["camera"], "--workers=" + str(case["workers"]),
                "--water-law=" + case["water_law"], "--water-variant=" + case.get("water_variant", "reference"),
                "--water-profile=" + case.get("water_profile", campaign["measurement"]["water_profile"]),
                "--input-mode=" + case.get("input_mode", "tape"), "--command-mode=repeated_callback", "--observer-mode=full"]
            if args.sustained:
                arguments.append("--sustained")
            write_json(folder / "arm.json", {"source": source, "scenario": case, "arm": arm, "causal": treatment["causal"],
                       "order_index": index, "nonce": nonce, "selectors": setting, "arguments": arguments})
            print(case_name, index, treatment, flush=True)
            try:
                process = execute(engine, arguments, folder, source["source_commit"], setting, 420, args.display_wrapper)
                data = json.loads(receipt.read_text())
                validate_requested_capture(data, case, campaign, source["source_commit"], nonce, driver, retirement)
                effective = copy.deepcopy(campaign)
                effective["arms"]["C"] = arm
                analysis = reduce_receipt(receipt, effective, project=project, engine=engine, arm_letter="C")
                if registration:
                    if case["fixture"] == "basin1024":
                        need(data["fixture"]["extent"] == [1024, 1024]
                             and analysis["water_quantity_before"] == analysis["water_quantity_after"],
                             "Closed 1024-square basin did not preserve registered extent and Water conservation")
                    analysis["physical_gap_counts_above_ms"] = observed_gap_counts(
                        receipt.with_name(receipt.stem + "-events.jsonl"), analysis["windows"],
                        registration["source_gain_criteria"]["reported_gap_thresholds_ms"])
                from causal_trace import reduce_causal
                causal = reduce_causal(receipt, expected_enabled=treatment["causal"])
                if args.completion_role == "C" and treatment["causal"]:
                    completed = analysis["windows"]["whole_capture"]["completed_rapier_steps"]
                    need(causal["actual_completed_rapier_steps"] == completed
                         and causal["exact_application_and_exit_joins"] == completed,
                         "Completion causal capture requires a versioned exact application and exit for every real step")
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
        try:
            validate_complete_comparison(arms, len(treatment_order))
        except ValueError as error:
            failures.append({"case": case_name, "reason": str(error)})
        results.append({"case": case_name, "arms": arms, "physical_outcome_parity": parity})
    summary = {"schema": "pubpres003-focused-result-v1", "complete": not failures,
               "source": source, "mode": args.mode, "cases": results, "failures": failures,
               "completion_role": args.completion_role, "material": args.material,
               "material_retirement_source": args.retirement_source,
               "sustained_minimum_usec": campaign["measurement"]["minimum_capture_usec"] if args.sustained else None,
               "physical_acceptance": "HOLD", "development": True}
    write_json(output / "summary.json", summary)
    print(json.dumps({"output": str(output), "complete": not failures, "failures": failures, "physical_acceptance": "HOLD"}))
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
