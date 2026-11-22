#!/usr/bin/env python3
"""Prepare eight reviewed runtime publication files after complete scoped gates.

No branch update, Git mutation, LFS upload, PR promotion or merge occurs here.
The original producer commit stays recorded, including after a later strictly
runtime-only publication commit. Full admission and physical owner gates stay
explicitly outside this bounded qualification.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil

import runtime_custody as custody
import run_request
from accepted_main_smokes import REQUIRED
from shared import legacy

RUNTIMES = {platform: "godot/addons/cybersand_native/bin/" + name for platform, name in custody.EXTENSIONS.items()}
PROVENANCE = {"linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
              "windows": "godot/addons/cybersand_native/runtime-provenance.json"}
CLIS = {platform: "godot/tools/" + custody.names(platform)["cli"] for platform in RUNTIMES}
BINDINGS = {platform: "godot/tools/swarm004-runtime." + platform + ".json" for platform in RUNTIMES}
PATHS = sorted([*RUNTIMES.values(), *PROVENANCE.values(), *CLIS.values(), *BINDINGS.values()])


def report(directory: Path, filename: str, receipt: dict, kind: str, package: bool = False) -> dict:
    value = legacy.read_report(directory / filename)
    custody.require(value.get("schema") == 1 and value.get("programme") == custody.PROGRAMME
                    and value.get("passed") is True, "Missing/failed " + kind + " qualification")
    for key in ("source_commit", "source_tree", "platform", "build_context"):
        custody.require(value.get(key) == receipt[key], "Qualification source/platform/run changed: " + key)
    encoded = json.dumps(receipt, indent=2, sort_keys=True) + "\n"
    import hashlib
    custody.require(value.get("runtime_manifest_sha256") == hashlib.sha256(encoded.encode()).hexdigest(),
                    "Qualification used a different runtime manifest")
    custody.verify_inventory(directory, value.get("files_sha256"))
    results = value.get("results", [])
    custody.require(isinstance(results, list) and bool(results), "Qualification has no completed child processes")
    if kind == "native":
        if receipt["platform"] == "linux":
            custody.require(value.get("linux_runtime_floor", {}).get("passed") is True,
                            "Linux adapter/CLI runtime floor was not qualified")
        expected = {(mode, name) for mode in (("strict", "sanitized") if receipt["platform"] == "linux" else ("strict",))
                    for name in custody.NATIVE_TESTS}
        actual = {(row.get("mode"), row.get("case", "").removeprefix(row.get("mode", "") + "-"))
                  for row in results if row.get("case") != "v3-request"}
        custody.require(actual == expected and len(results) == len(expected) + 1
                        and results[-1].get("case") == "v3-request" and all(row.get("passed") is True for row in results),
                        "Native strict/sanitizer/request gate is incomplete")
    elif kind == "graphical":
        custody.require(value.get("package") is package and value.get("graphical_required") is True
                        and value.get("lifecycle_passed") is True and value.get("owner_visual_acceptance") == "pending"
                        and value.get("reciprocal_programme_acceptance") is False,
                        "Graphical/owner/extracted qualification claim changed")
        custody.require(set(value.get("examples", {})) == set(legacy.EXAMPLES)
                        and all(row.get("passed") is True for row in value["examples"].values())
                        and len(results) == 14 and all(row.get("passed") is True for row in results),
                        "Required SWARM004/V3/lifecycle graphical scope is incomplete")
        if package:
            custody.require(bool(legacy.SHA256.fullmatch(value.get("package_zip_sha256", ""))), "Actual evaluator ZIP custody absent")
    else:
        custody.require(value.get("package") is package and value.get("required_cases") == list(REQUIRED)
                        and [row.get("label") for row in results] == list(REQUIRED)
                        and all(row.get("status") == "passed" for row in results),
                        "Accepted-main Paint/Water/Art/Flatten/actor smoke is incomplete")
    return value


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--linux-runtime", type=Path, required=True)
    parser.add_argument("--windows-runtime", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    custody.build_context()
    custody.require(custody.git(custody.ROOT, "rev-parse", "HEAD") == custody.source()["source_commit"], "Source checkout changed")
    runtimes = {"linux": args.linux_runtime.resolve(), "windows": args.windows_runtime.resolve()}
    receipts = {platform: custody.verify(directory) for platform, directory in runtimes.items()}
    for key in ("source_commit", "source_tree", "source_inputs_sha256", "build_inputs_sha256", "build_context"):
        custody.require(receipts["linux"][key] == receipts["windows"][key], "Linux/Windows source or producer run differ")
    execution = receipts["linux"]["source_commit"]
    custody.require(run_request.ancestor(custody.ROOT, run_request.ACCEPTED_MAIN, execution)
                    and run_request.ancestor(custody.ROOT, run_request.DONORS["700"], execution), "Candidate left authorized integration ancestry")
    evidence = args.evidence.resolve()
    qualifications = {}
    for platform, receipt in receipts.items():
        folders = {"native": platform + "-native", "graphical": platform + "-source", "smokes": platform + "-smokes"}
        filenames = {"native": "native-qualification.json", "graphical": "qualification.json", "smokes": "accepted-main-smokes.json"}
        qualifications[platform] = {}
        for kind, folder in folders.items():
            report(evidence / folder, filenames[kind], receipt, kind)
            qualifications[platform][kind] = {"report": folder + "/" + filenames[kind],
                                              "sha256": custody.sha(evidence / folder / filenames[kind])}
        if platform == "windows":
            for kind, folder in (("graphical", "windows-package"), ("smokes", "windows-package-smokes")):
                report(evidence / folder, filenames[kind], receipt, kind, True)
                qualifications[platform]["extracted_" + kind] = {"report": folder + "/" + filenames[kind],
                                                                 "sha256": custody.sha(evidence / folder / filenames[kind])}
    replay = legacy.read_report(evidence / "known-controls/manifest.json")
    custody.require(replay.get("result") == "PASS" and replay.get("expected_cases") == 360
                    and replay.get("qualifying_source") is True and replay.get("unseen") is False
                    and replay.get("source") == custody.source() and replay.get("errors") == []
                    and len(replay.get("records", [])) == 360,
                    "The required revealed360-case regression replay is incomplete")
    custody.require(replay.get("executable_sha256") == receipts["linux"]["files"]["replay_swarm005_known"]["sha256"],
                    "Known-control replay executable custody changed")
    for row in replay["records"]:
        custody.verify_inventory(evidence / "known-controls/candidate", {row["file"]: row["gzip_sha256"]})
    output = args.output.resolve()
    custody.require(not output.exists(), "Publication staging destination must be new")
    prepared = {}
    for platform, receipt in receipts.items():
        previous = legacy.read_report(custody.ROOT / PROVENANCE[platform])
        binary = receipt["files"][receipt["extension"]]
        prepared[platform] = {
            "schema_version": 1, "kind": "source-matched-swarm45-mainline-evaluation-candidate",
            "artifact": RUNTIMES[platform], "sha256": binary["sha256"], "size": binary["bytes"],
            "source_commit": execution, "build_commit": receipt["build_commit"], "source_tree": receipt["source_tree"],
            "platform": platform + " x86_64", "status": "evaluation-candidate-scoped-qualified",
            "source_input_hash_kind": "sha256-canonical-lf", "source_inputs": receipt["extension_inputs_sha256"],
            "build_inputs": receipt["build_inputs_sha256"], "native_definition_sha256": receipt["native_definition_sha256"],
            "godot_version": legacy.VERSION, "godot_cpp_commit": custody.GODOT_CPP,
            "toolchain": (runtimes[platform] / "toolchain.txt").read_text(encoding="utf-8"),
            "workflow_run": receipt["build_context"]["workflow_run"], "build_attempt": receipt["build_context"]["run_attempt"],
            "qualification": qualifications[platform], "owner_visual_acceptance": "pending",
            "reciprocal_programme_acceptance": False,
            "acceptance": "Draft/HOLD: exact-source scoped native, graphical authoring and accepted-main smoke passed. Full ordinary admission and physical original-user-map/NVIDIA owner acceptance remain mandatory.",
            "supersedes": {"build_commit": previous.get("build_commit"), "sha256": previous.get("sha256")},
        }
    output.mkdir(parents=True)
    for platform in receipts:
        target = output / RUNTIMES[platform]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(runtimes[platform] / receipts[platform]["extension"], target)
        custody.write_json(output / PROVENANCE[platform], prepared[platform])
        cli = output / CLIS[platform]
        cli.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(runtimes[platform] / receipts[platform]["cli"], cli)
        custody.write_json(output / BINDINGS[platform], custody.cli_binding(receipts[platform]))
    custody.write_json(output / "publication-plan.json", {
        "schema": 1, "programme": custody.PROGRAMME, "source_commit": execution,
        "source_tree": receipts["linux"]["source_tree"], "build_context": receipts["linux"]["build_context"],
        "branch": custody.BRANCH, "permitted_tracked_paths": PATHS,
        "files_sha256": custody.inventory(output), "request": "Root may review and publish these exact eight paths using a current branch lease; original build identity must remain unchanged.",
        "ready_or_merge_authorized": False, "owner_visual_acceptance": "pending",
        "full_admission_required": ["Native C++ validation", "GDExtension build and current Godot regression"]})
    print(output / "publication-plan.json")


if __name__ == "__main__":
    main()
