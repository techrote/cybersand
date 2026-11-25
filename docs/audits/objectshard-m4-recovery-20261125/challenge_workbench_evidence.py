#!/usr/bin/env python3
"""Independent adversarial checks for the offline Workbench evidence reviewer.

The real original archive is read only. Negative fixtures are small synthetic
archives assembled in a temporary directory. Their metadata is deliberately
repinned to exercise inner boundaries, never represented as GitHub evidence.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import zipfile


SOURCE = "f5b7ac7e651356c9f6d5657dfb0cb9d60111be81"
ARTIFACT = 14961723648


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True) + "\n").encode()


def module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def invoke(reviewer, args: argparse.Namespace) -> dict:
    try:
        result = reviewer.review(args)
        return {"accepted_application_pass": result["application_qualification"] == "passed",
                "integrity_status": result["integrity_status"],
                "application_qualification": result["application_qualification"]}
    except (ValueError, KeyError, AssertionError) as error:
        return {"accepted_application_pass": False, "refusal": str(error)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("reviewer-before", "reviewer-after", "archive", "metadata", "repo", "scratch", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    options = parser.parse_args()
    reviewers = {name: module(path, "evidence_" + name) for name, path in
                 (("before", options.reviewer_before), ("after", options.reviewer_after))}
    metadata = json.loads(options.metadata.read_text())
    original_args = argparse.Namespace(archive=options.archive, metadata=options.metadata,
        repo=options.repo, artifact_id=ARTIFACT, source_sha=SOURCE, git_ref=SOURCE,
        platform="windows", inventory=None, require_provenance_refusals=False)
    original = {name: invoke(reviewer, original_args) for name, reviewer in reviewers.items()}
    assert all(r.get("integrity_status") == "passed" and
               r.get("application_qualification") == "failed-or-incomplete" for r in original.values())

    members: dict[str, bytes] = {}
    with zipfile.ZipFile(options.archive) as archive:
        for folder in ("headless", "graphical"):
            report_name = folder + "/qualification.json"
            members[report_name] = archive.read(report_name)
            for case in json.loads(members[report_name])["cases"]:
                name = folder + "/" + case["log"]
                members[name] = archive.read(name)
        members["launcher/result.json"] = archive.read("launcher/result.json")
        for case in ("spaces", "parentheses", "unicode", "nested"):
            name = "launcher/" + case + "-launch.json"
            members[name] = archive.read(name)
    # This synthetic success control copies headless process evidence into a
    # fabricated package-replay namespace. It is exclusively a verifier test.
    # The original package-replay failure is never edited or reclassified.
    for name, payload in list(members.items()):
        if name.startswith("headless/"):
            members["package-replay/" + name[len("headless/"):]] = payload
    inventory = {folder: [case["name"] for case in json.loads(members[folder + "/qualification.json"])["cases"]]
                 for folder in ("headless", "graphical", "package-replay")}
    mutations = ["wrong-source", "wrong-tree", "altered-log", "altered-receipt",
                 "missing-focused-receipt", "dropped-native-key", "dropped-script-key",
                 "removed-registered-case", "duplicated-footer", "wrong-focused-schema",
                 "missing-overlay-receipt", "wrong-profile-schema",
                 "altered-launcher-receipt", "partial-inventory", "absent-inventory"]
    output = {"schema": "objectshard-m4-independent-evidence-reviewer-adversity-v1",
              "reviewer_sha256": {"before": sha(options.reviewer_before.read_bytes()),
                                  "after": sha(options.reviewer_after.read_bytes())},
              "original_archive_sha256": sha(options.archive.read_bytes()),
              "original_result": original,
              "scope": "Synthetic repinned metadata challenges inner verification only; no synthetic fixture is application qualification evidence.",
              "cases": []}
    with tempfile.TemporaryDirectory(prefix="reviewer-adversity-", dir=options.scratch) as directory:
        temporary = Path(directory)
        for mutation in ["synthetic-complete-control"] + mutations:
            changed = members.copy()
            expected = copy.deepcopy(inventory)
            headless = json.loads(changed["headless/qualification.json"])
            focus_name = "m4_workbench_tower_overview_headless" if mutation == "wrong-profile-schema" else "test_object_shard_m4_latency_probe"
            focused = next(c for c in headless["cases"] if c["name"] == focus_name)
            log_name = "headless/" + focused["log"]
            if mutation == "wrong-source":
                headless["source_commit"] = "0" * 40
            elif mutation == "wrong-tree":
                headless["source_tree"] = "0" * 40
            elif mutation == "altered-log":
                changed[log_name] += b"\nSYNTHETIC TAMPER\n"
            elif mutation == "altered-receipt":
                focused["receipt"]["checks"] += 1
            elif mutation == "missing-focused-receipt":
                focused.pop("receipt")
            elif mutation == "missing-overlay-receipt":
                graphical = json.loads(changed["graphical/qualification.json"])
                overlay = next(c for c in graphical["cases"] if c["name"] == "test_object_shard_m4_overlay_identity")
                overlay.pop("receipt")
                changed["graphical/qualification.json"] = encoded(graphical)
            elif mutation == "dropped-native-key":
                del headless["native_source_inputs"][next(iter(headless["native_source_inputs"]))]
            elif mutation == "dropped-script-key":
                del headless["executed_script_inputs"]["godot/scripts/main.gd"]
            elif mutation == "removed-registered-case":
                headless["cases"].pop()
            elif mutation == "duplicated-footer":
                changed[log_name] += encoded(focused["receipt"])
                focused["log_sha256"] = sha(changed[log_name])
            elif mutation in ("wrong-focused-schema", "wrong-profile-schema"):
                old_schema = focused["receipt"]["schema"]
                focused["receipt"]["schema"] = "synthetic-unregistered-schema"
                lines = changed[log_name].decode().splitlines()
                for index, line in enumerate(lines):
                    try:
                        value = json.loads(line)
                    except ValueError:
                        continue
                    if isinstance(value, dict) and value.get("schema") == old_schema:
                        lines[index] = json.dumps(focused["receipt"])
                changed[log_name] = ("\n".join(lines) + "\n").encode()
                focused["log_sha256"] = sha(changed[log_name])
            elif mutation == "altered-launcher-receipt":
                launcher = json.loads(changed["launcher/spaces-launch.json"])
                launcher["checks"] += 1
                changed["launcher/spaces-launch.json"] = encoded(launcher)
            elif mutation == "partial-inventory":
                expected.pop("graphical")
            elif mutation == "absent-inventory":
                expected = None
            changed["headless/qualification.json"] = encoded(headless)
            archive_path = temporary / "SYNTHETIC-ONLY.zip"
            with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as archive:
                for name, payload in sorted(changed.items()):
                    info = zipfile.ZipInfo(name, date_time=(2026, 11, 25, 0, 0, 0))
                    info.compress_type = zipfile.ZIP_DEFLATED
                    archive.writestr(info, payload)
            raw = archive_path.read_bytes()
            repinned = copy.deepcopy(metadata)
            artifact = next(a for a in repinned["artifacts"] if a["id"] == ARTIFACT)
            artifact.update(size_in_bytes=len(raw), digest="sha256:" + sha(raw), synthetic_only=True)
            metadata_path = temporary / "SYNTHETIC-ONLY-metadata.json"
            metadata_path.write_bytes(encoded(repinned))
            inventory_path = temporary / "reviewed-inventory.json"
            inventory_path.write_bytes(encoded(expected))
            args = copy.copy(original_args)
            args.archive, args.metadata = archive_path, metadata_path
            args.inventory = inventory_path if expected is not None else None
            results = {name: invoke(reviewer, args) for name, reviewer in reviewers.items()}
            if mutation == "synthetic-complete-control":
                assert all(r["accepted_application_pass"] for r in results.values()), results
            output["cases"].append({"case": mutation, "synthetic_archive_sha256": sha(raw),
                                    "results": results})
    negatives = output["cases"][1:]
    output["before_false_passes"] = [c["case"] for c in negatives if c["results"]["before"]["accepted_application_pass"]]
    output["after_false_passes"] = [c["case"] for c in negatives if c["results"]["after"]["accepted_application_pass"]]
    output["negative_cases"] = len(negatives)
    output["status"] = "passed" if not output["after_false_passes"] else "failed"
    options.output.parent.mkdir(parents=True, exist_ok=True)
    options.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: output[k] for k in ("status", "negative_cases", "before_false_passes", "after_false_passes")}))
    raise SystemExit(0 if output["status"] == "passed" else 1)


if __name__ == "__main__":
    main()
