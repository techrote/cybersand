#!/usr/bin/env python3
"""Join five successful final-head executions without changing their receipts."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil

from package_retained_gentek80 import require, sha, write_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--downloads", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8"))
    files = list(args.downloads.rglob("admission.json"))
    expected = {("linux", "checkout-workbench"), ("windows", "checkout-workbench"),
                ("windows", "owner"), ("windows", "flatten"), ("windows", "package-workbench")}
    executions = {}
    for path in files:
        value = json.loads(path.read_text(encoding="utf-8"))
        key = value.get("platform"), value.get("mode")
        require(key in expected and key not in executions, "Missing, duplicate or unexpected execution receipt")
        require(value.get("schema") == "gentek80-final-execution-v1" and value.get("status") == "passed" and
                value.get("application_source_commit") == value.get("executed_source_commit") == config["published_source"] and
                value.get("application_source_tree") == value.get("executed_source_tree") == config["published_tree"] and
                value.get("native_build_commit") == config["built_source"] and
                value.get("native_sha256") == config["runtimes"][key[0]]["sha256"] and
                value.get("configuration_sha256") == sha(args.config) and
                value.get("orchestration_commit") == os.environ["GITHUB_SHA"] and
                value.get("orchestration_run") == os.environ["GITHUB_RUN_ID"] and
                value.get("orchestration_attempt") == os.environ["GITHUB_RUN_ATTEMPT"],
                "Execution is stale, unsuccessful or not bound to this final candidate")
        for when in ("before", "after"):
            custody = value[when]
            require(custody.get("status") == "passed" and
                    custody["built"]["source_commit"] == config["built_source"] and
                    custody["published"]["source_commit"] == config["published_source"] and
                    custody["published"]["source_tree"] == config["published_tree"] and
                    custody["runtime"]["sha256"] == config["runtimes"][key[0]]["sha256"],
                    "Execution custody did not remain source/runtime matched")
        if key[1] in ("checkout-workbench", "package-workbench"):
            fresh = value["after"]["final_workbench"]
            require(fresh["status"] == "passed" and fresh["styles"] == 80 and
                    fresh["source_commit"] == config["published_source"] and
                    len(fresh["original_output_matches"]) == 2 and
                    all(row["matches"] is True and row["styles"] == 80 for row in fresh["original_output_matches"]),
                    "Final all-80 execution did not match original native/recipe output")
        execution = path.parent / "execution"
        for name, digest in value["original_execution_receipts_sha256"].items():
            require(sha(execution / name) == digest, "Original execution evidence changed in artifact transport")
        require(bool(value.get("framebuffer_png_sha256")), "Execution lacks actual framebuffer evidence")
        for name, digest in value["framebuffer_png_sha256"].items():
            require(sha(execution / name) == digest, "Original framebuffer PNG changed in artifact transport")
        executions[key] = {"path": path.relative_to(args.downloads).as_posix(), "sha256": sha(path), "receipt": value}
    require(set(executions) == expected, "Not all five final-head executions completed")
    assemblies = list(args.downloads.rglob("assembly.json"))
    require(len(assemblies) == 1, "Missing or ambiguous package assembly receipt")
    assembly_path = assemblies[0]
    assembly = json.loads(assembly_path.read_text(encoding="utf-8"))
    archive = assembly_path.parent / assembly["archive"]
    require(archive.is_file() and sha(archive) == assembly["archive_sha256"] and
            archive.stat().st_size == assembly["archive_bytes"], "Admitted original ZIP differs from the executed package")
    for key in ("owner", "flatten", "package-workbench"):
        value = executions[("windows", key)]["receipt"]
        require(value["archive_sha256"] == assembly["archive_sha256"] and
                value["assembly_receipt_sha256"] == sha(assembly_path), "Pristine package executions used different ZIPs")
    require(not args.output.exists(), "Final delivery directory must be new")
    args.output.mkdir(parents=True)
    shutil.copyfile(archive, args.output / archive.name)
    (args.output / (archive.name + ".sha256")).write_text(assembly["archive_sha256"] + "  " + archive.name + "\n", encoding="utf-8")
    result = {"schema": "gentek80-final-admission-join-v1", "status": "passed",
              "application_source_commit": config["published_source"], "application_source_tree": config["published_tree"],
              "native_build_commit": config["built_source"], "runtimes": config["runtimes"],
              "orchestration_commit": os.environ["GITHUB_SHA"], "orchestration_run": os.environ["GITHUB_RUN_ID"],
              "orchestration_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
              "configuration_sha256": sha(args.config), "archive": archive.name,
              "archive_sha256": assembly["archive_sha256"], "archive_bytes": archive.stat().st_size,
              "assembly_receipt_sha256": sha(assembly_path),
              "executions": {platform + "/" + mode: value for (platform, mode), value in sorted(executions.items())},
              "scope": "Actual retained-runtime final-head Linux/Windows all80 Workbench plus three pristine Windows package executions; normal final-head CI gates remain separately reported."}
    write_json(args.output / "final-admission.json", result)
    shutil.copyfile(args.config, args.output / "admission-inputs.json")
    print(json.dumps({"status": "passed", "source": config["published_source"], "executions": len(executions),
                      "archive_sha256": assembly["archive_sha256"]}))


if __name__ == "__main__":
    main()
