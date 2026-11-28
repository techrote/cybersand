#!/usr/bin/env python3
"""Prepare eight reviewed runtime publication files after complete scoped gates.

No branch update, Git mutation, LFS upload, PR promotion or merge occurs here.
The original producer commit stays recorded, including after a later strictly
runtime-only publication commit. Full admission and physical owner gates stay
explicitly outside this bounded qualification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

import runtime_custody as custody
import run_request
from accepted_main_smokes import REQUIRED
from shared import graphical_processes, legacy, load
from reduce_evidence import validate_graphical, validate_native

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
    actual_files = {path.relative_to(directory).as_posix() for path in directory.rglob("*") if path.is_file()}
    custody.require(set(value["files_sha256"]) == actual_files - {filename},
                    "Qualification inventory omits original evidence or contains its own summary")
    results = value.get("results", [])
    custody.require(isinstance(results, list) and bool(results), "Qualification has no completed child processes")
    if kind == "native":
        if receipt["platform"] == "linux":
            custody.require(value.get("linux_runtime_floor", {}).get("passed") is True,
                            "Linux adapter/CLI runtime floor was not qualified")
        expected = {(mode, name) for mode in (("strict", "sanitized") if receipt["platform"] == "linux" else ("strict",))
                    for name in custody.NATIVE_TESTS}
        transport = ("v1-v2-request", "v3-request", "v4-request")
        actual = {(row.get("mode"), row.get("case", "").removeprefix(row.get("mode", "") + "-"))
                  for row in results if row.get("case") not in transport}
        custody.require(actual == expected and len(results) == len(expected) + len(transport)
                        and [row.get("case") for row in results[-len(transport):]] == list(transport)
                        and all(row.get("passed") is True for row in results),
                        "Native strict/sanitizer/request gate is incomplete")
        validate_native(directory, value, receipt)
    elif kind == "graphical":
        custody.require(value.get("package") is package and value.get("graphical_required") is True
                        and value.get("lifecycle_passed") is True and value.get("owner_visual_acceptance") == "pending"
                        and value.get("qualification_programme") == custody.QUALIFICATION_PROGRAMME
                        and value.get("input_integrity_passed") is True and value.get("terminal_identity_revalidated") is True
                        and value.get("reciprocal_programme_acceptance") is False,
                        "Graphical/owner/extracted qualification claim changed")
        custody.require(set(value.get("examples", {})) == set(legacy.EXAMPLES)
                        and all(row.get("passed") is True for row in value["examples"].values())
                        and [(row.get("case"), row.get("example")) for row in results] == graphical_processes(value["examples"])
                        and all(row.get("passed") is True for row in results),
                        "Required SWARM004/V3/V4/input/inspector/lifecycle graphical scope is incomplete")
        if package:
            custody.require(bool(legacy.SHA256.fullmatch(value.get("package_zip_sha256", ""))), "Actual evaluator ZIP custody absent")
        validate_graphical(directory, value, receipt)
    else:
        custody.require(value.get("package") is package and value.get("required_cases") == list(REQUIRED)
                        and [row.get("label") for row in results] == list(REQUIRED)
                        and all(row.get("status") == "passed" for row in results),
                        "Accepted-main Paint/Water/Art/Flatten/actor smoke is incomplete")
        from reduce_auxiliary import validate_smokes
        validate_smokes(directory, value, receipt)
    return value


def preservation(evidence: Path, label: str, receipt: dict) -> dict:
    """Check raw source custody and every original preservation child independently."""
    directory, final = evidence / (label + "-preservation"), evidence / (label + "-final")
    owner = load("swarm456_preservation_inventory", "tools/swarm006/qualify_preserved_workbench.py")
    identity = legacy.read_report(directory / "identity.json")
    value = legacy.read_report(directory / "qualification.json")
    integrity = legacy.read_report(directory / "qualification-integrity.json")
    completed = legacy.read_report(final / "identity-recheck.json")
    custody.require(identity.get("source") == receipt["source_commit"] and identity.get("tree") == receipt["source_tree"]
                    and identity.get("platform") == {"linux": "linux", "windows": "win32"}[receipt["platform"]]
                    and identity.get("qualification_programme") == custody.QUALIFICATION_PROGRAMME
                    and identity.get("build_context") == receipt["build_context"]
                    and identity.get("development") is False and identity.get("source_delta") == ""
                    and bool(identity.get("execution_inputs")) and ".gitattributes" in identity.get("inputs", {}),
                    "Preservation source/platform/raw-input identity is incomplete: " + label)
    import hashlib
    encoded = (json.dumps(receipt, indent=2, sort_keys=True) + "\n").encode()
    custody.require(identity.get("runtime_manifest_sha256") == hashlib.sha256(encoded).hexdigest()
                    and value.get("identity") == identity and value.get("passed") is True
                    and value.get("inputs_unchanged") is True and value.get("identity_errors") == [],
                    "Preservation runtime changed or suite failed: " + label)
    source_inputs = owner.source_inputs()
    custody.require(set(identity.get("inputs", {})) == set(source_inputs), "Preservation original source inventory differs")
    attributes = custody.git(custody.ROOT, "check-attr", "-z", "eol", "--", *source_inputs).split("\0")
    eol = {attributes[index]: attributes[index + 2] for index in range(0, len(attributes) - 1, 3)}
    for name, digest in source_inputs.items():
        data = (custody.ROOT / name).read_bytes()
        admitted = {digest}
        pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize [0-9]+\n", data)
        if pointer:
            # A clean checkout may hold its exact committed pointer or the
            # corresponding materialized object; neither is a changed input.
            admitted.add(pointer[1].decode())
        elif receipt["platform"] == "windows" and eol.get(name) == "unspecified" and b"\0" not in data[:8192]:
            # Only unspecified checkout EOL follows Windows autocrlf. Explicit
            # LF imports/scripts stay exact; no retained byte is rewritten.
            admitted.add(hashlib.sha256(data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")).hexdigest())
        custody.require(identity["inputs"][name] in admitted, "Preservation original source hash differs: " + name)
    custody.require(identity.get("native_sha256") == receipt["files"][receipt["extension"]]["sha256"]
                    and identity.get("cli_sha256") == receipt["files"][receipt["cli"]]["sha256"],
                    "Preservation native/CLI identity differs from the actual qualified runtime")
    graphical_identity = legacy.read_report(evidence / label / "source-runtime-identity.json")
    custody.require(graphical_identity.get("source_commit") == receipt["source_commit"]
                    and graphical_identity.get("build_context") == receipt["build_context"]
                    and graphical_identity.get("godot_sha256") == identity.get("engine_sha256"),
                    "Preservation and graphical engine/source identities differ")
    installed = {name.removeprefix("godot/"): digest for name, digest in graphical_identity.get("execution_layout", {}).get("files_sha256", {}).items()
                 if name.startswith("godot/")}
    actual = identity.get("execution_inputs", {})
    custody.require(bool(installed) and all(actual.get(name) == digest for name, digest in installed.items())
                    and all(name in installed or name.endswith(".uid") for name in actual),
                    "Preservation raw installed source/runtime differs from graphical layout")
    for name in ("identity", "qualification"):
        custody.require(integrity.get(name + "_sha256") == custody.sha(directory / (name + ".json")),
                        "Preservation evidence changed: " + name)
    expected = [("import", ""), *((name, script) for name, script, _marker, _environment, _timeout in owner.CASES)]
    results = value.get("results", [])
    custody.require([(row.get("name"), row.get("script")) for row in results] == expected,
                    "Preservation case inventory is incomplete: " + label)
    cases = (("import", "", "", {}, 180), *owner.CASES)
    for row, (name, script, marker, _environment, timeout) in zip(results, cases):
        original = legacy.read_report(directory / (name + "-process.json"))
        text = (directory / (name + ".log")).read_text(encoding="utf-8", errors="replace")
        custody.require(row.get("passed") is True and row.get("errors") == [] and row.get("returncode") == 0
                        and type(row.get("returncode")) is int and original == row
                        and row.get("timed_out") is False and row.get("child_reaped") is True
                        and row.get("cancelled") is False and row.get("timeout_seconds") == timeout
                        and row.get("log_sha256") == custody.sha(directory / (name + ".log"))
                        and not owner.ERRORS.search(text), "Preservation original child/log failed: " + name)
        command = row.get("argv", [])
        custody.require(isinstance(command, list) and "--headless" in command
                        and (command[-2:] == ["--script", "res://tests/" + script] if script else command[-2:] == ["--editor", "--quit"]),
                        "Preservation executed another original fixture: " + name)
        if marker:
            custody.require(owner.completion(text, marker, name) == row.get("assertions"),
                            "Preservation original completion differs from summary: " + name)
        if name == "input-integrity":
            from reduce_evidence import script_hash
            errors = legacy.input_integrity_errors(directory / name, row["assertions"], receipt["source_commit"],
                        receipt["files"][receipt["cli"]]["sha256"], script_hash(receipt, "godot/" + legacy.INPUT_SCRIPT),
                        require_graphics=False)
            custody.require(not errors, "Preservation original input evidence failed: " + "; ".join(errors))
    custody.require(completed.get("passed") is True and completed.get("errors") == []
                    and completed.get("prior_source") == receipt["source_commit"]
                    and completed.get("prior_identity_sha256") == integrity["identity_sha256"]
                    and completed.get("prior_qualification_sha256") == integrity["qualification_sha256"],
                    "Terminal source/runtime recheck is absent or different: " + label)
    return {"report": label + "-preservation/qualification.json", "sha256": integrity["qualification_sha256"],
            "final_report": label + "-final/identity-recheck.json", "final_sha256": custody.sha(final / "identity-recheck.json")}


def recovery_replay(directory: Path, receipt: dict) -> dict:
    replay = load("swarm456_complete_replay_reader", "tools/swarm006/replay_finisher.py")
    runner, plan = replay.frozen_runner(), replay.registered_plan()
    wrapper = legacy.read_report(directory / "unified-replay.json")
    value = legacy.read_report(directory / "manifest.json")
    custody.require(wrapper.get("passed") is True and wrapper.get("source") == custody.source()
                    and wrapper.get("build_context") == receipt["build_context"]
                    and wrapper.get("qualification_programme") == custody.QUALIFICATION_PROGRAMME,
                    "Unified revealed recovery replay source/attempt differs")
    custody.verify_inventory(directory, wrapper.get("files_sha256"))
    build = legacy.read_report(directory / "native-build.json")
    custody.require(value.get("result") == "PASS" and value.get("classification") == replay.CLASSIFICATION
                    and value.get("source") == receipt["source_commit"] and value.get("build_receipt") == build
                    and build.get("definition_sha256") == receipt["native_definition_sha256"]
                    and value.get("build_receipt_sha256") == custody.sha(directory / "native-build.json")
                    and value.get("cases") == plan["cases"]
                    and value.get("policies") == [[p["name"], p["rounds"]] for p in plan["policies"]]
                    and value.get("limits") == plan["limits"] and value.get("child_timeout_seconds") == 90
                    and value.get("expected_executions") == 1920 and value.get("retained_executions") == 1920
                    and value.get("retained_reference_executions") == 0 and value.get("errors") == []
                    and value.get("source_custody_revalidated") is True and value.get("binary_custody_revalidated") is True,
                    "The revealed 006 complete fixed corpus was changed or incomplete")
    from reduce_recovery import validate_recovery_records
    validate_recovery_records(directory, value, build, receipt, replay, runner, plan)
    return {"report": "recovery/unified-replay.json", "sha256": custody.sha(directory / "unified-replay.json"), "executions": 1920}


def owner_launcher(evidence: Path, graphical: dict, receipt: dict) -> dict:
    from reduce_auxiliary import validate_owner_launcher
    return validate_owner_launcher(evidence, graphical, receipt)


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
    for key in ("source_commit", "source_tree", "source_inputs_sha256", "build_inputs_sha256", "build_context",
                "native_definition_sha256", "native_definition_inputs_sha256"):
        custody.require(receipts["linux"][key] == receipts["windows"][key], "Linux/Windows source or producer run differ")
    execution = receipts["linux"]["source_commit"]
    custody.require(run_request.ancestor(custody.ROOT, run_request.ACCEPTED_MAIN, execution)
                    and all(run_request.ancestor(custody.ROOT, donor, execution) for donor in run_request.DONORS.values()),
                    "Candidate left authorized integration ancestry")
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
        qualifications[platform]["preservation"] = preservation(evidence, platform + "-source", receipt)
        if platform == "windows":
            for kind, folder in (("graphical", "windows-package"), ("smokes", "windows-package-smokes")):
                checked = report(evidence / folder, filenames[kind], receipt, kind, True)
                if kind == "graphical":
                    qualifications[platform]["owner_launcher"] = owner_launcher(evidence, checked, receipt)
                qualifications[platform]["extracted_" + kind] = {"report": folder + "/" + filenames[kind],
                                                                 "sha256": custody.sha(evidence / folder / filenames[kind])}
            qualifications[platform]["extracted_preservation"] = preservation(evidence, "windows-package", receipt)
    from reduce_known_controls import validate_known_controls
    qualifications["linux"]["known_controls"] = validate_known_controls(evidence / "known-controls", receipts["linux"])
    qualifications["linux"]["recovery_replay"] = recovery_replay(evidence / "recovery", receipts["linux"])
    output = args.output.resolve()
    custody.require(not output.exists(), "Publication staging destination must be new")
    prepared = {}
    for platform, receipt in receipts.items():
        previous = legacy.read_report(custody.ROOT / PROVENANCE[platform])
        binary = receipt["files"][receipt["extension"]]
        prepared[platform] = {
            "schema_version": 1, "kind": "source-matched-swarm45-mainline-evaluation-candidate",
            "qualification_programme": custody.QUALIFICATION_PROGRAMME,
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
        "schema": 1, "programme": custody.PROGRAMME, "qualification_programme": custody.QUALIFICATION_PROGRAMME, "source_commit": execution,
        "source_tree": receipts["linux"]["source_tree"], "build_context": receipts["linux"]["build_context"],
        "branch": custody.BRANCH, "permitted_tracked_paths": PATHS,
        "files_sha256": custody.inventory(output), "request": "Root may review and publish these exact eight paths using a current branch lease; original build identity must remain unchanged.",
        "ready_or_merge_authorized": False, "owner_visual_acceptance": "pending",
        "full_admission_required": ["Native C++ validation", "GDExtension build and current Godot regression"]})
    print(output / "publication-plan.json")


if __name__ == "__main__":
    main()
