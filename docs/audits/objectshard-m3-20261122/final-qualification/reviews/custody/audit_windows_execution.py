"""Independent read-only final-source Windows process and performance review."""
import argparse
import datetime
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import zipfile
import audit_navigation

SOURCE = "e034f2294663e0485cfb9adcc8ada46a6e977cee"
TREE = "246e7324ca618d98c43a0ed54fe19bc86a155877"
NATIVE = "05cc1f55d812b93462e73e7bc79f82d3f892d9f5b8fececc6a4753b705b3c651"
RAPIER = "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--zip", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = {"schema": "objectshard-independent-windows-execution-review-v1", "source_commit": SOURCE,
              "source_tree": TREE, "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "failures": []}
    evidence_hashes = {}
    def expect(condition, message):
        if not condition:
            report["failures"].append(message)
    def read(relative):
        data = (args.evidence / relative).read_bytes()
        evidence_hashes[relative] = sha(data)
        return data
    def document(relative):
        return json.loads(read(relative))
    def committed(path):
        return subprocess.check_output(["git", "-C", str(args.repo), "show", SOURCE + ":" + path])
    with zipfile.ZipFile(args.zip) as archive:
        manifest_bytes = archive.read("objectshard-lab-manifest.json")
        manifest = json.loads(manifest_bytes)
    base_cases = {"objectshard_import", "test_rapier_manual_step", "test_material_lab_experiment"}
    base_cases |= {"objectshard_" + name for name in (
        "bridge", "lab", "capture", "motion_segments", "rest_contacts", "boundary", "playability", "action_replay",
        "rest_erode", "rest_replace_identical", "rest_mass_only", "owner_d", "incremental_motion", "native_worker",
        "workbench_contract", "worker_rehearsal", "worker_adverse", "worker_recovery", "worker_replay_admission",
        "worker_resources", "worker_commands", "physics_identity", "worker_input_fences", "continuous_play",
        "continuous_replay", "continuous_physics", "worker_scene", "worker_replay", "worker_navigation")}
    rendered_cases = {"objectshard_" + name for name in (
        "render", "finisher_render", "continuous_play_rendered", "continuous_rendered_replay", "worker_render",
        "profile_headless", "profile_rendered", "worker_profile_0", "worker_profile_4000")}
    inventories = {}
    report["navigation"] = {}
    for scope in ("windows-lab", "package-replay"):
        q = document(scope + "/qualification.json")
        expect(q.get("status") == "passed" and q.get("failures") == [], scope + " unsuccessful qualification")
        expect(q.get("source_commit") == SOURCE and q.get("source_tree") == TREE, scope + " source identity")
        expect(q.get("runtime", {}).get("native_sha256") == NATIVE and q.get("runtime", {}).get("rapier_sha256") == RAPIER,
               scope + " native/Rapier identity")
        expect(q.get("runtime", {}).get("platform") == "win32", scope + " actual Windows platform")
        expect(q.get("runtime", {}).get("godot_version") == "4.7.stable.official.5b4e0cb0f"
               and q.get("runtime", {}).get("godot_sha256") == manifest["godot"]["console_sha256"], scope + " engine identity")
        expect(q.get("native_source_inputs") == manifest["native"]["source_inputs"], scope + " complete native inputs")
        for field in ("lab_source_inputs", "qualification_tool_inputs"):
            expect(bool(q.get(field)), scope + " missing " + field)
            for path, digest in q.get(field, {}).items():
                expect(sha(committed(path)) == digest, scope + " committed input: " + path)
        if scope == "package-replay":
            expect(q.get("package_manifest_sha256") == sha(manifest_bytes), "Replay is not bound to delivered manifest")
        names = [case["name"] for case in q["cases"]]
        expect(len(names) == len(set(names)) and set(names) == base_cases | (rendered_cases if scope == "windows-lab" else set()),
               scope + " complete exact test inventory")
        rows = []
        for case in q["cases"]:
            name = case["name"]
            expect(case.get("status") == "passed" and case.get("natural_completion") is True and case.get("returncode") == 0,
                   scope + " case incomplete/failed: " + name)
            expect(not any(case.get(key) for key in ("diagnostic_error", "launch_error", "capture_error", "skip_messages", "timeout_kind")),
                   scope + " case had errors/skips/deadline: " + name)
            log = read(scope + "/" + case["log"])
            expect(sha(log) == case["log_sha256"], scope + " process log hash: " + name)
            expect(case["execution_policy"]["sha256"] == sha(committed(case["execution_policy"]["path"]))
                   and case["execution_policy"]["scale"] == 1, scope + " case execution policy: " + name)
            receipt = case.get("completion_receipt")
            if receipt:
                matches = []
                for line in log.decode("utf-8", errors="replace").splitlines():
                    try:
                        value = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if isinstance(value, dict) and value.get("schema") == receipt.get("schema"):
                        matches.append(value)
                expect(matches == [receipt] and type(receipt.get("failures")) is int and receipt["failures"] == 0,
                       scope + " completion differs from actual process footer: " + name)
            rows.append({"name": name, "seconds": case["seconds"], "checks": receipt.get("checks") if receipt else None,
                         "log_sha256": case["log_sha256"], "requires_display": case["requires_display"]})
        inventories[scope] = rows
        navigation = audit_navigation.audit(lambda relative: read(scope + "/" + relative), SOURCE)
        report["navigation"][scope] = navigation
        expect(navigation["status"] == "passed", scope + " maintained actual navigation evidence: " + repr(navigation["failures"]))
    report["process_cases"] = inventories
    matrix = document("launcher-matrix/result.json")
    with args.zip.open("rb") as stream:
        zip_sha = hashlib.file_digest(stream, "sha256").hexdigest()
    expect(matrix.get("status") == "passed" and matrix.get("failures") == [] and matrix.get("zip_sha256") == zip_sha,
           "Actual launched ZIP identity/status")
    paths = [row["case"] for row in matrix["cases"]]
    expect(len(paths) == 4 and set(paths) == {"spaces", "parentheses", "nested", "unicode"}, "Four path inventory")
    for row in matrix["cases"]:
        name = row["case"]
        expect(row.get("source_commit") == SOURCE, name + " launch source")
        expect(len(row["commands"]) == 3 and {c["script"] for c in row["commands"]} == {
            "Verify ObjectShard Lab.cmd", "Open ObjectShard Lab.cmd", "Open ObjectShard M3 Preflight.cmd"}
            and all(c["exit_code"] == 0 for c in row["commands"]), name + " verifier and both actual launchers")
        for kind, field, minimum, schema in (
            ("launch", "launch_receipt", 6, "objectshard-package-launch-v1"),
            ("preflight", "preflight_launch_receipt", 15, "objectshard-worker-package-launch-v1")):
            receipt = document("launcher-matrix/" + name + "-" + kind + ".json")
            expect(receipt == row[field] and receipt["schema"] == schema and receipt["source_commit"] == SOURCE
                   and receipt["failures"] == 0 and receipt["checks"] >= minimum, name + " actual " + kind + " receipt")
            read("launcher-matrix/" + name + "-" + kind + ".log")
        expect(row["preflight_launch_receipt"].get("host") == "standalone-exclusive-worker-rehearsal"
               and row["preflight_launch_receipt"].get("production_workbench") is False, name + " honest preflight host identity")
        read("launcher-matrix/" + name + "-verify.log")
    adversary = next(row["verifier_adversaries"] for row in matrix["cases"] if row["case"] == "spaces")
    tamper = read("launcher-matrix/verifier-tamper-refusal.log")
    read("launcher-matrix/verifier-without-get-file-hash.log")
    expect(adversary.get("tamper_exit_code") != 0 and re.search(rb"Package file changed:\s*READ-ME\.md", tamper) is not None,
           "Specific changed README SHA refusal, not unrelated launcher error")
    expect(adversary.get("get_file_hash_shadow_exit_code") == 0 and adversary.get("after_restoration_inventory_verified") is True
           and adversary.get("restored_sha256") == manifest["files_sha256"]["READ-ME.md"], "Streaming hash and exact tamper restoration")
    report["launcher_matrix"] = {"zip_sha256": zip_sha, "paths": paths, "commands": 12, "adversary": adversary}
    report["source_bound_evidence_sha256"] = evidence_hashes
    report["status"] = "passed" if not report["failures"] else "failed"
    report["scope"] = "Actual hosted Windows source and extracted-package process custody; separate performance analysis and physical owner acceptance remain necessary."
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "failures": report["failures"],
                      "process_case_counts": {key: len(value) for key, value in inventories.items()},
                      "zip_sha256": zip_sha, "evidence_files_checked": len(evidence_hashes)}, indent=2))
    raise SystemExit(bool(report["failures"]))


if __name__ == "__main__":
    main()
