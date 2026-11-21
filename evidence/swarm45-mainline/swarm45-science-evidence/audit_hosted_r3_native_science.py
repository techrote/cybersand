#!/usr/bin/env python3
"""Independent read-only hosted R2 scientific/native audit."""
from pathlib import Path, PurePosixPath
import ast
from concurrent.futures import ProcessPoolExecutor, as_completed
import collections
import gzip
import hashlib
import itertools
import json
import posixpath
import re
import struct
import subprocess
import sys
from zipfile import ZipFile

REPO = Path("/workspace/scratch/038267c40e11/cybersand-swarm45-mainline")
ROOT = Path("/workspace/scratch/038267c40e11/swarm45-hosted-r3")
OUT = Path("/workspace/scratch/038267c40e11/swarm45-science-evidence")
EXE = "96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f"
FROZEN = "79b8a0a4a1c2ace435d709b35114ee7065c935e6"
MAIN = "846fe0533b3170e7b01f690518da49fc40cc24d1"
OLD_EXE = "10fe808ac7f6a4b9c07f7d168763b41957359e57"
DEFINITION = "217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7"
OLD_DEFINITION = DEFINITION
KNOWN = ROOT / "linux-evidence/known-controls"
LOCAL = Path("/workspace/scratch/038267c40e11/swarm45-hosted-r2/linux-evidence/known-controls")
RUNTIME = ROOT / "linux-runtime"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(path, ref=EXE):
    return subprocess.check_output(["git", "show", ref + ":" + path], cwd=REPO)


def get_functions():
    source = blob("tools/swarm45/replay_known_controls.py")
    assert sha(source) == "9ef1bcdbb3bdfad734453a8457acfd95eb5847a9e16a1a73d0acbd8cea1bc1be"
    nodes = []
    for node in ast.parse(source.decode()).body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id in
            {"FIXTURES", "PROFILES", "SEEDS", "POLICIES", "CASES", "NORMALIZATION"} for t in node.targets):
            nodes.append(node)
        if isinstance(node, ast.FunctionDef) and node.name in {"sha", "normalized", "behavior_hash", "metrics"}:
            nodes.append(node)
    ns = dict(hashlib=hashlib, json=json, itertools=itertools, re=re)
    exec(compile(ast.Module(body=nodes, type_ignores=[]), "<frozen-existing-normalizer>", "exec"), ns)
    return ns


FUN = get_functions()
CASES = FUN["CASES"]


def expected_options(policy):
    values = dict(rounds=2, vocabulary=True, hierarchy=True, shared_ownership=True,
                  frame_adaptation=True, mosaic_adaptation=True, optional_negotiation=True,
                  final_validation=True, native_mosaic_bearing=True, supported_native_receptors=False,
                  compact_native_termination=False, shared_extent=13, orientation_preference=-1)
    if policy == "compact_only":
        values["compact_native_termination"] = True
    elif policy == "receptor_only":
        values["supported_native_receptors"] = True
    elif policy.startswith("both"):
        values["supported_native_receptors"] = values["compact_native_termination"] = True
        changes = {"both_round1": ("rounds", 1), "both_round0": ("rounds", 0),
                   "both_frame_frozen": ("frame_adaptation", False),
                   "both_mosaic_frozen": ("mosaic_adaptation", False),
                   "both_hard_only": ("optional_negotiation", False),
                   "both_fixed_territory": ("shared_ownership", False)}
        if policy in changes:
            key, value = changes[policy]
            values[key] = value
    return values


def case_check(task):
    index, current, previous = task
    case = CASES[index]
    assert current["case_id"] == previous["case_id"] == index
    for record in (current, previous):
        assert tuple(record[key] for key in ("fixture", "profile", "seed", "policy")) == case
        assert record["exitcode"] == 0 and "error" not in record
        assert record["file"] == f"case-{index:03}.json.gz"
    raw_values = {}
    gzip_values = {}
    for label, directory, record in (("r3", KNOWN, current), ("r2", LOCAL, previous)):
        compressed = (directory / "candidate" / record["file"]).read_bytes()
        assert sha(compressed) == record["gzip_sha256"] and len(compressed) == record["gzip_bytes"]
        raw = gzip.decompress(compressed)
        assert sha(raw) == record["raw_sha256"] and len(raw) == record["raw_bytes"]
        raw_values[label] = raw
        gzip_values[label] = compressed
    assert gzip_values["r3"] == gzip_values["r2"], index
    assert raw_values["r3"] == raw_values["r2"], index
    data = json.loads(raw_values["r3"])
    assert data["schema"] == 5 and data["type"] == "reciprocal_assembly"
    assert data["input"]["options"] == expected_options(case[3])
    for gentek, prefix in (("frame", "frameweaver.frontier-growth-v0."), ("mosaic", "mosaic.prepared-regions-v0.")):
        request = data["input"][gentek]
        assert request["definition"] == prefix + DEFINITION
        assert request["source"] == "swarm005-unseen-holdout-v1"
        assert request["fixture"] == case[0] and request["seed"] == case[2]
        assert request["profile"]["destruction"] == 0
    measured = FUN["metrics"](data)
    assert all(current[key] == value and previous[key] == value for key, value in measured.items())
    assert current["behavior_sha256"] == previous["behavior_sha256"]
    expected_apply = data["status"] == "complete" and measured["closure_evaluated"] and measured["still_required"] == 0
    assert data["can_apply"] == expected_apply
    if expected_apply:
        assert all(item["state"] != "STILL_REQUIRED" for item in data["obligations"])
        expected_cells = data["input"]["frame"]["width"] * data["input"]["frame"]["height"]
        assert len(data["cells"]) == len(data["ledger"]) == expected_cells
    if not measured["closure_evaluated"]:
        assert all(measured[key] is None for key in ("original_required", "foreign_joined_required", "still_required"))
    assert not any(data["metrics"].get(key, 0) for key in ("hard_violations", "protected_violations"))
    return {"case_id": index, "case": case, "metrics": measured, "raw_equal": True,
            "gzip_equal": True, "raw_bytes": len(raw_values["r3"]), "raw_sha256": current["raw_sha256"],
            "gzip_bytes": len(gzip_values["r3"]), "gzip_sha256": current["gzip_sha256"],
            "behavior_sha256": current["behavior_sha256"]}


def check_ledger(ledger, ref):
    for name, digest in ledger.items():
        assert sha(blob(name, ref).replace(b"\r\n", b"\n")) == digest, name
    return len(ledger)


def custody():
    manifests = {}
    for name, path in {
        "known": KNOWN / "manifest.json",
        "runtime": RUNTIME / "swarm45-runtime-provenance.json",
        "build": ROOT / "linux-evidence/linux-build/build.json",
        "request": ROOT / "linux-evidence/linux-build/request.json",
        "native": ROOT / "linux-evidence/linux-native/native-qualification.json",
    }.items():
        raw = path.read_bytes()
        manifests[name] = {"sha256": sha(raw), "value": json.loads(raw)}
    k, r, b, q, n = (manifests[x]["value"] for x in ("known", "runtime", "build", "request", "native"))
    source = k["source"]
    assert source["source_commit"] == EXE and source["native_definition_sha256"] == DEFINITION
    assert source["source_tree"] == subprocess.check_output(["git", "rev-parse", EXE + "^{tree}"], cwd=REPO, text=True).strip()
    assert source == b["source"] and all(r[key] == value for key, value in source.items())
    assert r["source_commit"] == r["build_commit"] == n["source_commit"] == EXE
    assert r["qualification_kind"] == "hosted-source-bound" and r["platform"] == "linux"
    assert r["build_context"] == n["build_context"]
    assert r["build_context"]["run_id"] == "44953582341" and r["build_context"]["run_attempt"] == "1"
    assert r["build_context"]["repository"] == "techrote/cybersand"
    assert r["build_context"]["workflow"] == ".github/workflows/swarm45-mainline-qualification.yml"
    assert b["runtime_manifest_sha256"] == n["runtime_manifest_sha256"] == manifests["runtime"]["sha256"]
    assert q["passed"] and q["execution_source_sha"] == EXE and q["frozen_source_sha"] == FROZEN
    assert q["accepted_main"] == MAIN and q["request_only_commits"] == [EXE]
    assert q["native_definition_sha256"] == DEFINITION
    assert sha(blob(".github/swarm45-mainline-request.json")) == q["request_sha256"]
    assert subprocess.check_output(["git", "diff", "--name-only", FROZEN, EXE], cwd=REPO, text=True).splitlines() == [".github/swarm45-mainline-request.json"]
    for prior in [FROZEN, MAIN, *q["frozen_donors"].values()]:
        subprocess.run(["git", "merge-base", "--is-ancestor", prior, EXE], cwd=REPO, check=True)
    counts = {}
    for key in ("build_inputs_sha256", "source_inputs_sha256", "extension_inputs_sha256", "native_definition_inputs_sha256"):
        counts[key] = check_ledger(source[key], EXE)
    prefix = "native/experiments/gentek_swarm/"
    names = subprocess.check_output(["git", "ls-tree", "--name-only", EXE + ":" + prefix.rstrip("/")], cwd=REPO, text=True).splitlines()
    ordered = sorted(x for x in names if x.endswith(".cpp")) + sorted(x for x in names if x.endswith(".hpp"))
    ordered += ["../../../native/src/generation_spatial.cpp", "../../../native/include/cybersand/material.hpp",
                "../../../native/include/cybersand/generation_spatial.hpp", "../../../native/include/cybersand/generation_numeric.hpp"]
    digest = hashlib.sha256()
    differences = []
    for name in ordered:
        path = posixpath.normpath(prefix + name)
        data = blob(path)
        digest.update(name.encode() + b"\0" + data)
        if data != blob(path, OLD_EXE):
            differences.append(path)
    assert digest.hexdigest() == DEFINITION
    assert differences == []
    for path in [prefix + "RECIPROCAL_REGISTRATION.json", prefix + "SELECTION-RECIPROCAL.json",
                 "tools/swarm45/replay_known_control.cpp", "tools/swarm45/replay_known_controls.py",
                 "tools/swarm45/runtime_custody.py"]:
        assert blob(path) == blob(path, OLD_EXE), path
    payload = {}
    for name, record in r["files"].items():
        path = RUNTIME / name
        assert path.is_file() and not path.is_symlink()
        data = path.read_bytes()
        assert sha(data) == record["sha256"] and len(data) == record["bytes"]
        if name != "toolchain.txt":
            assert data[:6] == b"\x7fELF\x02\x01" and struct.unpack_from("<H", data, 18)[0] == 62
        payload[name] = record
    assert len(payload) == 15
    assert payload["replay_swarm005_known"]["sha256"] == k["executable_sha256"]
    assert k["driver_sha256"] == sha(blob("tools/swarm45/replay_known_control.cpp"))
    assert k["runner_sha256"] == sha(blob("tools/swarm45/replay_known_controls.py"))
    assert b["passed"] and b["platform"] == "linux" and len(b["commands"]) == 8
    for command in b["commands"]:
        assert command["returncode"] == 0
        log = ROOT / "linux-evidence/linux-build" / (command["label"] + ".log")
        assert sha(log.read_bytes()) == command["log_sha256"]
    assert b["commands"] == json.loads((ROOT / "linux-evidence/linux-build/commands.json").read_bytes())
    assert n["passed"] and n["platform"] == "linux"
    for name, digest in n["files_sha256"].items():
        path = ROOT / "linux-evidence/linux-native" / name
        assert sha(path.read_bytes()) == digest, name
    for result in n["results"]:
        assert result["passed"] and result["returncode"] == 0 and not result["timed_out"]
        assert not result.get("validation_errors", [])
        process = ROOT / "linux-evidence/linux-native" / (result["case"] + "-process.json")
        assert json.loads(process.read_bytes()) == result
        assert sha((ROOT / "linux-evidence/linux-native" / (result["case"] + ".log")).read_bytes()) == result["log_sha256"]
        if "binary_sha256" in result:
            basename = PurePosixPath(result["command"][0]).name
            relative = "sanitized/" + basename if result["mode"] == "sanitized" else basename
            assert payload[relative]["sha256"] == result["binary_sha256"]
    assert len(n["results"]) == 11
    assert n["sanitizers"] == ["address", "undefined"]
    archives = {}
    for name, expected, size in [
        ("linux-evidence.zip", "4de8f1a18fb95d508a073945c4d2c28a47b7a00d1f7c3ea60fbc050e8503353b", 79930037),
        ("linux-runtime.zip", "5bb7b48ce0156e359c1c1394d32e45a68e4badef6154191300a2c254face4302", 77157548)]:
        path = ROOT / name
        data = path.read_bytes()
        assert len(data) == size and sha(data) == expected
        archives[name] = dict(bytes=size, sha256=expected)
    return {"manifest_hashes": {key: value["sha256"] for key, value in manifests.items()},
            "source": source["source_commit"], "source_tree": source["source_tree"], "frozen_source": FROZEN,
            "accepted_main": MAIN, "native_definition": DEFINITION, "source_ledger_counts": counts,
            "definition_changed_inputs_since_local": differences, "payload": payload,
            "build_commands_verified": 8, "native_processes_verified": 11,
            "native_evidence_files_verified": len(n["files_sha256"]), "build_context": r["build_context"],
            "archives": archives, "toolchain": (RUNTIME / "toolchain.txt").read_text()}


def main():
    destination = OUT / "swarm45-hosted-r3-native-science-audit-96b8d3f.json"
    assert not destination.exists()
    prior_path = OUT / "swarm45-hosted-r2-native-science-audit-10fe808.json"
    prior_raw = prior_path.read_bytes()
    assert sha(prior_raw) == "40764003ef42f523649c3f6c081fe36396fba96507785950de9dac5af591caac"
    prior = json.loads(prior_raw)
    assert prior["result"] == "PASS" and prior["native_outputs_verified"] == 360
    current_raw = (KNOWN / "manifest.json").read_bytes()
    previous_raw = (LOCAL / "manifest.json").read_bytes()
    assert sha(previous_raw) == prior["hosted_manifest_sha256"] == "d48348c41a745e732cf214cd4dc7ffb9a716d2f0c5060e878f86d89df3c1a4d2"
    current, previous = json.loads(current_raw), json.loads(previous_raw)
    assert current["result"] == previous["result"] == "PASS"
    assert not current["errors"] and not previous["errors"]
    assert current["unseen"] is False and current["qualifying_source"] is True
    new = {r["case_id"]: r for r in current["records"]}
    old = {r["case_id"]: r for r in previous["records"]}
    assert set(new) == set(old) == set(range(360))
    custody_record = custody()
    old_runtime_bytes = (LOCAL.parents[1] / "linux-runtime/swarm45-runtime-provenance.json").read_bytes()
    assert sha(old_runtime_bytes) == prior["custody"]["manifest_hashes"]["runtime"]
    old_runtime = json.loads(old_runtime_bytes)
    assert set(custody_record["payload"]) == set(old_runtime["files"])
    payload_changes = [name for name, record in custody_record["payload"].items() if record != old_runtime["files"][name]]
    assert payload_changes == ["toolchain.txt"]
    # Byte comparison, including the compiled binaries, closes hash-only transfer.
    for name in custody_record["payload"]:
        if name != "toolchain.txt":
            assert (RUNTIME / name).read_bytes() == (LOCAL.parents[1] / "linux-runtime" / name).read_bytes()
    root_path = REPO / "evidence/swarm45-local/frozen-source-provenance-r3.json"
    root_raw = root_path.read_bytes()
    assert sha(root_raw) == "f335475d7df31e2a370613d185ce97e354984ce09c983d0d6897ac633af75489"
    root = json.loads(root_raw)
    assert root["qualification_execution_head"] == EXE and root["frozen_source"] == FROZEN
    assert root["accepted_main"] == MAIN and root["native_definition_sha256"] == DEFINITION
    assert root["qualification_run_id"] == "44953582341" and root["qualification_run_attempt"] == "1"
    assert root["qualification_tree"] == current["source"]["source_tree"]
    assert root["frozen_tree"] == subprocess.check_output(["git", "rev-parse", FROZEN + "^{tree}"], cwd=REPO, text=True).strip()
    for key in ("build_inputs_sha256", "source_inputs_sha256", "extension_inputs_sha256", "native_definition_inputs_sha256"):
        assert root[key] == current["source"][key]
    source_file_count = 0
    for entry in root["files_changed_from_accepted_main"]:
        raw = blob(entry["path"], FROZEN)
        assert sha(raw) == entry["integrated_sha256"] and len(raw) == entry["bytes"]
        assert subprocess.check_output(["git", "rev-parse", FROZEN + ":" + entry["path"]], cwd=REPO, text=True).strip() == entry["integrated"]["git_blob_sha1"]
        source_file_count += 1
    control = subprocess.check_output(["git", "rev-parse", "395b9339"], cwd=REPO, text=True).strip()
    assert blob("evidence/swarm45-mainline/frozen-source-provenance-r3.json", control) == root_raw
    assert blob("evidence/swarm45-mainline/swarm45-science-evidence/swarm45-hosted-r2-native-science-audit-10fe808.json", control) == prior_raw
    print("PASS exact R3 source/build/native and committed-manifest custody; comparing native output bytes.", flush=True)
    outputs = []
    with ProcessPoolExecutor(max_workers=2) as pool:
        jobs = [pool.submit(case_check, (index, new[index], old[index])) for index in range(360)]
        for future in as_completed(jobs):
            outputs.append(future.result())
            if len(outputs) % 72 == 0:
                print(json.dumps({"byte_identical_outputs": len(outputs), "expected": 360}), flush=True)
    outputs.sort(key=lambda row: row["case_id"])
    statuses = {}
    unknown = collections.Counter()
    for row in outputs:
        policy = row["case"][3]
        statuses.setdefault(policy, collections.Counter())[row["metrics"]["status"]] += 1
        if not row["metrics"]["closure_evaluated"]:
            unknown[policy] += 1
    assert statuses == current["summary"] == previous["summary"]
    members = {}
    for archive, directory, prefixes in (("linux-evidence.zip", "linux-evidence", ("known-controls/", "linux-native/", "linux-build/")),
                                         ("linux-runtime.zip", "linux-runtime", ("",))):
        count = total = 0
        with ZipFile(ROOT / archive) as zipped:
            for info in zipped.infolist():
                if info.is_dir() or not info.filename.startswith(prefixes):
                    continue
                value = zipped.read(info.filename)
                assert value == (ROOT / directory / info.filename).read_bytes()
                count += 1; total += len(value)
        members[archive] = {"members": count, "bytes": total}
    v3 = []
    v3_dir = ROOT / "linux-evidence/linux-native/v3"
    summary = json.loads((v3_dir / "summary.json").read_bytes())
    for item in summary:
        name = f"{item['profile']}-cap{item['compact']}-receptor{item['supported']}.json"
        raw = (v3_dir / name).read_bytes()
        assert raw == (LOCAL.parent / "linux-native/v3" / name).read_bytes()
        value = json.loads(raw)
        assert value["status"] == item["status"] and value["can_apply"] == item["can_apply"]
        assert value["metrics"]["still_required"] == item["still_required"]
        assert len(value["joints"]) == item["joints"]
        assert sum(cell != 0 for cell in value["cells"]) == item["native_material_cells"]
        v3.append({"file": name, "sha256": sha(raw), **item})
    assert len(v3) == 8
    result = {"schema": 1, "scope": "R3 exact-source hosted Linux native/scientific delta audit only",
              "result": "PASS", "source": EXE, "frozen_source": FROZEN, "native_definition": DEFINITION,
              "prior_r2_audit_sha256": sha(prior_raw), "hosted_manifest_sha256": sha(current_raw),
              "comparison": "Exact raw and gzip byte equality; no normalization needed",
              "raw_equal_outputs": 360, "gzip_equal_outputs": 360, "raw_gzip_file_pairs_reverified": 720,
              "native_output_bytes_per_run": sum(row["raw_bytes"] for row in outputs),
              "payload_changes_from_r2": payload_changes, "binary_payloads_byte_identical": 14,
              "all_43_definition_inputs_unchanged": True,
              "root_source_manifest_sha256": sha(root_raw), "committed_control_copy": control,
              "root_frozen_file_inventory_entries_verified": source_file_count,
              "custody": custody_record, "archive_members": members, "v3_raw_cases": v3,
              "status_counts": statuses, "closure_unavailable": unknown, "records": outputs,
              "script_sha256": sha(Path(__file__).read_bytes())}
    destination.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"result": "PASS", "raw_equal": 360, "gzip_equal": 360,
                      "binary_equal": 14, "root_source_manifest_entries": source_file_count,
                      "file": str(destination), "sha256": sha(destination.read_bytes())}, indent=2), flush=True)


if __name__ == "__main__":
    main()
