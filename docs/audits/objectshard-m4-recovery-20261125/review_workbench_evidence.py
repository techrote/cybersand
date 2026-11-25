#!/usr/bin/env python3
"""Independent, offline original-byte review of an M4 Workbench artifact.

This does not execute the product or convert a failed campaign into a pass.
It joins externally pinned artifact bytes, Git inputs, process logs and report
receipts. A local equivalent commit is allowed only with the exact tested tree.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def need(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def safe(name: str) -> str:
    path = PurePosixPath(name)
    need(bool(name) and not path.is_absolute() and not any(x in name for x in ("\\", "\x00", "\r", "\n", ":"))
         and all(x not in (".", "..") for x in name.split("/")), "Unsafe evidence path: " + repr(name))
    return name


def git_bytes(repo: Path, ref: str, paths: set[str]) -> dict[str, bytes]:
    ordered = sorted(safe(p) for p in paths)
    response = subprocess.run(["git", "-C", str(repo), "cat-file", "--batch"],
                              input="".join(ref + ":" + p + "\n" for p in ordered).encode(),
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=120).stdout
    offset, result = 0, {}
    for path in ordered:
        stop = response.index(b"\n", offset)
        header = response[offset:stop].split()
        need(len(header) == 3 and header[1] == b"blob", "Missing Git input: " + path)
        size = int(header[2]); offset = stop + 1
        result[path] = response[offset:offset + size]
        offset += size
        need(response[offset:offset + 1] == b"\n", "Malformed Git batch boundary")
        offset += 1
    need(offset == len(response), "Unexpected Git batch output")
    return result


def successful_footer(value: dict) -> bool:
    failures = value.get("failures")
    return (type(value.get("checks")) is int and value["checks"] > 0
            and ((type(failures) is int and failures == 0) or failures == []))


def registered_inputs(repo: Path, ref: str) -> tuple[set[str], set[str]]:
    names = subprocess.check_output(["git", "-C", str(repo), "ls-tree", "-r", "--name-only", "-z", ref],
                                    timeout=60).decode().split("\0")
    native_suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
    script_suffixes = {".gd", ".tscn", ".godot", ".py", ".json", ".gdextension", ".gdshader"}
    native = {p for p in names if p.startswith(("native/include/", "native/src/", "godot/native_extension/"))
              and Path(p).suffix in native_suffixes}
    scripts = {p for p in names if p.startswith(("godot/", "tools/objectshard/", "tools/ci/", "materials/catalogue/"))
               and "/bin/" not in p and "/.godot/" not in p and Path(p).suffix in script_suffixes}
    return native, scripts


def registered_footers(source: bytes) -> dict[str, str]:
    tree = ast.parse(source)
    result = None
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "FOCUSED" for t in node.targets):
            result = dict(ast.literal_eval(node.value))
    need(result is not None, "Test source lacks its explicit focused inventory")
    profile_schemas = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Tuple) or len(node.elts) != 2:
            continue
        case, schema = node.elts
        if not (isinstance(case, ast.Call) and isinstance(case.func, ast.Attribute)
                and case.func.attr == "Case" and case.args
                and isinstance(schema, ast.Constant) and isinstance(schema.value, str)):
            continue
        name = case.args[0]
        if isinstance(name, ast.Constant) and isinstance(name.value, str):
            need(name.value not in result or result[name.value] == schema.value,
                 "Conflicting registered footer schema: " + name.value)
            result[name.value] = schema.value
        elif isinstance(name, ast.Name) and name.id in ("name", "recorded_name"):
            profile_schemas.add(schema.value)
    need(len(profile_schemas) == 1, "Missing or ambiguous Workbench profile schema")
    result["m4_workbench_*"] = profile_schemas.pop()
    return result


def review(args: argparse.Namespace) -> dict:
    metadata = json.loads(args.metadata.read_text())
    artifacts = metadata.get("artifacts", [])
    artifact = next(x for x in artifacts if x["id"] == args.artifact_id)
    data = args.archive.read_bytes()
    digest = sha(data)
    need(len(data) == artifact["size_in_bytes"] and "sha256:" + digest == artifact["digest"],
         "Archive differs from externally pinned GitHub artifact")
    need(artifact["workflow_run"]["head_sha"] == args.source_sha, "Artifact belongs to another source")
    git_tree = subprocess.check_output(["git", "-C", str(args.repo), "rev-parse", args.git_ref + "^{tree}"],
                                       timeout=30).decode().strip()
    inventory = json.loads(args.inventory.read_text()) if args.inventory else {}
    expected_native, expected_scripts = registered_inputs(args.repo, args.git_ref)
    expected_footers = registered_footers(git_bytes(args.repo, args.git_ref,
                                        {"tools/objectshard/qualify_workbench.py"})["tools/objectshard/qualify_workbench.py"])
    result = {"schema": "objectshard-m4-independent-workbench-artifact-review-v1",
              "artifact_id": args.artifact_id, "artifact_size": len(data), "artifact_sha256": digest,
              "workflow_run": artifact["workflow_run"], "source_commit": args.source_sha,
              "reviewed_git_ref": args.git_ref, "source_tree": git_tree, "reports": [],
              "integrity_status": "incomplete", "application_qualification": "incomplete",
              "physical_owner_acceptance": "HOLD: no physical Windows/NVIDIA observation"}
    with zipfile.ZipFile(args.archive) as archive:
        names = [i.filename for i in archive.infolist() if not i.is_dir()]
        need(len(names) == len(set(names)), "Duplicate archive members")
        for name in names:
            safe(name)
        result["archive_members"] = len(names)
        reports = {}
        for folder in ("headless", "graphical", "package-replay"):
            name = folder + "/qualification.json"
            if name in names:
                reports[folder] = json.loads(archive.read(name))
        paths = set()
        for report in reports.values():
            paths.update(report.get("native_source_inputs", {}))
            paths.update(report.get("executed_script_inputs", {}))
        committed = git_bytes(args.repo, args.git_ref, paths)
        for folder, report in reports.items():
            need(report.get("source_commit") == args.source_sha and report.get("source_tree") == git_tree,
                 folder + " source/tree differs")
            need(report.get("schema") == "objectshard-m4-workbench-qualification-v1", "Unexpected report schema")
            for field, normalize in (("native_source_inputs", True), ("executed_script_inputs", False)):
                inputs = report.get(field, {})
                expected_paths = expected_native if normalize else expected_scripts
                need(set(inputs) == expected_paths, folder + " incomplete registered " + field)
                for path, expected in inputs.items():
                    source = committed[path].replace(b"\r\n", b"\n") if normalize else committed[path]
                    need(sha(source) == expected, folder + " Git input mismatch: " + path)
            rows = []
            cases = report.get("cases", [])
            case_names = [c["name"] for c in cases]
            need(len(case_names) == len(set(case_names)), folder + " duplicate process case")
            if folder in inventory and report.get("status") == "passed":
                need(case_names == inventory[folder], folder + " registered inventory differs")
            for case in cases:
                log_name = folder + "/" + safe(case["log"])
                log = archive.read(log_name)
                need(sha(log) == case["log_sha256"], "Original process log hash differs: " + log_name)
                if case.get("status") == "passed":
                    need(case.get("returncode") == 0 and case.get("natural_completion") is True
                         and not case.get("skip_messages") and not case.get("timeout_kind")
                         and not case.get("launch_error"), "Invalid successful process: " + log_name)
                command = case.get("command", [])
                displayed = case.get("requires_display") is True
                need(("--headless" in command) != displayed, "Process render scope differs: " + log_name)
                receipt = case.get("receipt")
                registered_schema = expected_footers.get(case["name"])
                if case["name"].startswith("m4_workbench_") and case["name"] != "m4_workbench_import":
                    registered_schema = expected_footers["m4_workbench_*"]
                for suffix in ("_cli", "_render", "_graphical"):
                    if case["name"].endswith(suffix):
                        registered_schema = registered_schema or expected_footers.get(case["name"][:-len(suffix)])
                requires_receipt = bool(registered_schema) or case["name"] == "retained_lab_profile" \
                    or (case["name"].startswith("m4_") and case["name"] != "m4_workbench_import")
                if case.get("status") == "passed" and requires_receipt:
                    need(isinstance(receipt, dict), "Missing registered process footer: " + log_name)
                if registered_schema and receipt is not None:
                    need(receipt.get("schema") == registered_schema, "Wrong registered footer schema: " + log_name)
                footer_hash = None
                if receipt is not None:
                    footers = []
                    for line in log.decode("utf-8", errors="replace").splitlines():
                        try:
                            candidate = json.loads(line)
                        except ValueError:
                            continue
                        if isinstance(candidate, dict) and candidate.get("schema") == receipt.get("schema"):
                            footers.append(candidate)
                    need(len(footers) == 1 and footers[0] == receipt,
                         "Report does not match unique original process footer: " + log_name)
                    if case.get("status") == "passed":
                        need(successful_footer(receipt), "Empty/failed process footer: " + log_name)
                    if "source_commit" in receipt:
                        need(receipt["source_commit"] == args.source_sha, "Footer source differs: " + log_name)
                    if "render_submissions" in receipt:
                        need((receipt["render_submissions"] > 0) == displayed,
                             "Profile has mislabeled rendered evidence: " + log_name)
                    footer_hash = sha(json.dumps(receipt, sort_keys=True, separators=(",", ":")).encode())
                rows.append({"name": case["name"], "status": case.get("status"),
                             "returncode": case.get("returncode"), "seconds": case.get("seconds"),
                             "rendered": displayed, "log": log_name, "log_sha256": sha(log),
                             "receipt_schema": receipt.get("schema") if receipt else None,
                             "checks": receipt.get("checks") if receipt else None,
                             "canonical_receipt_sha256": footer_hash})
            passed = report.get("status") == "passed"
            need(not passed or (cases and not report.get("failures") and all(c["status"] == "passed" for c in cases)),
                 folder + " claims success without complete successful cases")
            result["reports"].append({"path": folder + "/qualification.json",
                "sha256": sha(archive.read(folder + "/qualification.json")), "status": report.get("status"),
                "failures": report.get("failures"), "case_count": len(cases),
                "rendered_case_count": sum(c["rendered"] for c in rows),
                "native_inputs": len(report["native_source_inputs"]),
                "script_inputs": len(report["executed_script_inputs"]), "runtime": report.get("runtime"), "cases": rows})
        launcher_name = "launcher/result.json"
        if launcher_name in names:
            launcher = json.loads(archive.read(launcher_name))
            launcher_rows = launcher.get("cases", [])
            need([r["case"] for r in launcher_rows] == ["spaces", "parentheses", "unicode", "nested"],
                 "Incomplete actual extraction path inventory")
            for row in launcher_rows:
                need(row.get("source_commit") == args.source_sha, "Launcher source differs")
                receipt = row["launch_receipt"]
                raw_name = "launcher/" + row["case"] + "-launch.json"
                need(json.loads(archive.read(raw_name)) == receipt, "Launcher raw receipt differs")
                need(successful_footer(receipt) and receipt.get("source_commit") == args.source_sha,
                     "Launcher lacks successful exact-source completion")
                need(receipt.get("host") == "ordinary-workbench" and receipt.get("rendering_driver") == "opengl3_angle"
                     and receipt.get("startup_scene") == "res://feature_launcher.tscn", "Wrong shipped entry path")
                coherence = receipt["display_coherence"]
                need(coherence["incoherent_observations"] == 0 and coherence["draw_observations"] > 0,
                     "Launcher has incoherent or unrendered display")
                need([x["script"] for x in row["commands"]] == ["Verify Workbench.cmd", "Open Workbench.cmd"]
                     and all(x["exit_code"] == 0 for x in row["commands"]), "Actual shipped CMD did not succeed")
                if row["case"] == "spaces":
                    need(row.get("tamper_refused") is True and row.get("unlisted_input_refused") is True,
                         "Missing shipped tamper refusal")
                    refusals = row.get("provenance_refusals", [])
                    if args.require_provenance_refusals:
                        expected = ["missing-candidate", "tampered-candidate", "incorrect-candidate-kind",
                                    "stale-candidate-source", "stale-candidate-build", "wrong-candidate-runtime",
                                    "missing-retained-reference", "active-retained-provenance"]
                        need([r["case"] for r in refusals] == expected, "Missing provenance refusal inventory")
                        for refusal in refusals:
                            log = archive.read("launcher/" + safe(refusal["log"]))
                            need(refusal["exit_code"] != 0 and refusal["expected_refusal"].encode() in log,
                                 "Missing specific shipped provenance refusal")
            result["launcher"] = {"status": launcher["status"], "report_sha256": sha(archive.read(launcher_name)),
                "zip_sha256": launcher["zip_sha256"], "paths": [r["case"] for r in launcher_rows],
                "provenance_refusals": sum(len(r.get("provenance_refusals", [])) for r in launcher_rows),
                "all_observed_display_publications_coherent": True}
        required = ["headless", "graphical"] + (["package-replay"] if args.platform == "windows" else [])
        complete = all(r in reports and reports[r]["status"] == "passed" for r in required)
        if args.platform == "windows":
            complete = complete and result.get("launcher", {}).get("status") == "passed"
        inventory_verified = all(r in inventory for r in required)
        result["registered_inventory_verified"] = inventory_verified
        result["application_qualification"] = ("passed" if inventory_verified else "reported-passes-inventory-unverified") \
            if complete else "failed-or-incomplete"
        result["integrity_status"] = "passed"
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("archive", "metadata", "repo", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--artifact-id", type=int, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--git-ref", required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--inventory", type=Path)
    parser.add_argument("--require-provenance-refusals", action="store_true")
    parser.add_argument("--expect-complete", action="store_true")
    args = parser.parse_args()
    if args.expect_complete and not args.inventory:
        parser.error("--expect-complete requires an independently reviewed --inventory")
    result = review(args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: result[k] for k in ("artifact_id", "integrity_status", "application_qualification")}))
    if args.expect_complete:
        need(result["application_qualification"] == "passed", "Required application qualification is incomplete")


if __name__ == "__main__":
    main()
