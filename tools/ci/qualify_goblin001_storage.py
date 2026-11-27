#!/usr/bin/env python3
"""Finite Windows qualification of the accepted Goblin001 writer repair.

The product and request harness have independent immutable identities. Existing
OS-fault, native transaction, controller and default-OFF tests remain their own
oracles. This adapter adds custody and complete process budgeting, not new game
behavior or a successor import.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

SCHEMA = "cybersand-goblin001-storage-request-v1"
ACCEPTED_BASE = "67c1413a2a84077b47fa542cf91d2bd6ba5520ee"
CASES = ("test_workbench_file_transaction", "test_ambient_default_off_integration")
RAPIER_IMPORT_DESCRIPTORS = frozenset({
    "godot/addons/godot-rapier2d/Radial2D.svg.import",
    "godot/addons/godot-rapier2d/icons/Fluid2D.svg.import",
    "godot/addons/godot-rapier2d/icons/StateManager2D.svg.import",
    "godot/addons/godot-rapier2d/logo_square_2d.png.import",
})
OS_INPUTS = (
    "godot/goblin/goblin_controller.gd", "godot/goblin/goblin_adapter.gd",
    "godot/goblin/goblin_transcript.gd", "godot/scripts/workbench_file_transaction.gd",
    "godot/tests/goblin_storage_fault_child.gd", "godot/native_extension/material_baseline_file.cpp",
    "tools/ci/windows_file_lock.py", "tools/ci/run_goblin_storage_qualification.py",
)
INPUTS = OS_INPUTS + (
    "godot/goblin/tests/test_controller.gd", "godot/tests/test_workbench_file_transaction.gd",
    "godot/tests/test_ambient_default_off_integration.gd", "tools/gip014/run_goblin.py",
    "tools/gip014/verify_transcript.py", "tools/gip014/minimize.py",
    "tools/ci/run_windows_godot_regressions.py", "tools/ci/run_godot_regressions.py",
    "tools/ci/execution_policy.py", "godot/tests/support/ci_execution_policy.json",
    "tools/ci/godot_timeout_diagnostics.py", "tools/ci/materialize_lfs.py",
)
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|^ERROR:|Fatal signal|Segmentation fault", re.MULTILINE)
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    def unique(pairs):
        value = {}
        for key, item in pairs:
            require(key not in value, "Duplicate JSON key: " + key)
            value[key] = item
        return value
    value = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique)
    require(isinstance(value, dict), "Expected object")
    return value


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], timeout=60).decode().strip()


def request(path):
    value = read(path)
    require(value.get("schema") == SCHEMA and value.get("status") == "admitted", "Unadmitted request")
    require(value.get("repository") == "techrote/cybersand" and value.get("accepted_base") == ACCEPTED_BASE,
            "Wrong repository or accepted base")
    for key in ("source_commit", "source_tree"):
        require(isinstance(value.get(key), str) and re.fullmatch(r"[0-9a-f]{40}", value[key])
                and value[key] != "0" * 40, "Exact source identity required")
    require(value.get("case_inventory") == ["windows_os_faults", "native_file_transaction", "goblin001_controller", "ordinary_default_off"],
            "Changed scoped case inventory")
    require(value.get("owner_playfeel_accepted") is False and value.get("public_release") is False,
            "Storage qualification grants no physical acceptance or release")
    return value


def source_inputs(root):
    result = {}
    for name in INPUTS:
        path = root / name
        require(path.is_file() and not path.is_symlink(), "Missing required source input: " + name)
        actual = path.read_bytes().replace(b"\r\n", b"\n")
        committed = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:" + name], timeout=60).replace(b"\r\n", b"\n")
        require(actual == committed, "Uncommitted execution input: " + name)
        result[name] = sha(path)
    return result


def module(root, name):
    sys.path.insert(0, str(root / "tools/ci"))
    value = importlib.import_module(name)
    require(Path(value.__file__).resolve().is_relative_to(root.resolve()), "Helper imported from another checkout")
    return value


def budget(root):
    policy = module(root, "execution_policy").identity()
    discovered = module(root, "run_godot_regressions").discover_cases(root)
    cases = {case.name: case for case in discovered if case.name in CASES}
    require(set(cases) == set(CASES), "Both canonical registered fixtures are required")
    for name, case in cases.items():
        require(case.flags == ("--script", "res://tests/" + name + ".gd") and not case.requires_display,
                "Fixture registration changed")
    limits = policy["watchdogs"]
    rows = {"setup_and_acquisition": limits["godot_setup_seconds"],
            "metadata_and_receipt_verification": limits["godot_metadata_seconds"],
            # Two metadata passes, each with14 bounded Git calls: original
            # status/diff/tree, four descriptors, HEAD/index/config, exact-path
            # index refresh, post-index/cached-diff, and final status.
            "import_metadata_custody": 2 * 14 * 60,
            "one_project_import": limits["godot_import_seconds"] + 30,
            "canonical_native_boundary": cases[CASES[0]].timeout + 30,
            "canonical_default_off": cases[CASES[1]].timeout + 30,
            # Original Windows runner executes five90-second children. Reserve
            # one extra child allowance as headroom, not an execution claim.
            # Version check and retirement are separate; controller keeps240+180.
            "original_windows_os_runner": 6 * 90 + 30 + 60,
            "original_controller_runner": 240 + 180 + 120,
            "evidence_upload": limits["aggregate_headroom_seconds"]}
    total = sum(rows.values())
    require(total <= 300 * 60 and limits["godot_job_minutes"] >= 300,
            "Complete original watchdog envelope exceeds300-minute parent")
    return {"parent_minutes": 300, "required_minutes": math.ceil(total / 60), "total_seconds": total,
            "rows": rows, "policy": policy, "fixture_seconds": {name: case.timeout for name, case in cases.items()}}


def admit(root, harness, requested):
    require(git(root, "rev-parse", "HEAD") == requested["source_commit"]
            and git(root, "rev-parse", "HEAD^{tree}") == requested["source_tree"], "Wrong product checkout")
    require(not git(root, "status", "--porcelain", "--untracked-files=all"), "Product must be clean committed source")
    git(root, "merge-base", "--is-ancestor", ACCEPTED_BASE, requested["source_commit"])
    require(not git(harness, "status", "--porcelain", "--untracked-files=all"), "Harness must be clean committed source")
    head = git(harness, "rev-parse", "HEAD")
    require(os.environ.get("GITHUB_SHA") == head, "Harness/run source mismatch")
    for key in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT"):
        require(re.fullmatch(r"[1-9][0-9]*", os.environ.get(key, "")), "Missing run/attempt binding")
    return {"source_commit": requested["source_commit"], "source_tree": requested["source_tree"],
            "harness_commit": head, "harness_tree": git(harness, "rev-parse", "HEAD^{tree}"),
            "run_id": os.environ["GITHUB_RUN_ID"], "run_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
            "input_sha256": source_inputs(root), "execution_budget": budget(root)}


def run(root, command, output, env, seconds):
    output.mkdir(parents=True, exist_ok=False)
    log = output / "process.log"
    row = {"status": "running", "command": command, "timeout_seconds": seconds}
    process = None
    started = time.monotonic()
    try:
        with log.open("w", encoding="utf-8") as stream:
            options = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if sys.platform == "win32" else {"start_new_session": True}
            process = subprocess.Popen(command, cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT, **options)
            row["pid"] = process.pid
            try:
                row["exit_code"] = process.wait(timeout=seconds)
            except subprocess.TimeoutExpired:
                row["status"] = "timeout"
                module(root, "godot_timeout_diagnostics").stop_process_tree(process, wait_seconds=10)
                raise ValueError("Owned process exceeded full registered watchdog")
        require(row["exit_code"] == 0 and not ERRORS.search(log.read_text(encoding="utf-8")), "Original process failed")
        row["status"] = "passed"
        return row
    except Exception as error:
        row.update(error=str(error), status="timeout" if row["status"] == "timeout" else "failed")
        raise
    finally:
        if process is not None and process.poll() is None:
            module(root, "godot_timeout_diagnostics").stop_process_tree(process, wait_seconds=10)
        row.update(seconds=time.monotonic() - started, retired=process is not None and process.poll() is not None,
                   log_sha256=sha(log) if log.exists() else None)
        write(output / "process.json", row)


def terminal(log, prefix):
    values = [json.loads(line[len(prefix):]) for line in log.read_text(encoding="utf-8").splitlines() if line.startswith(prefix)]
    require(len(values) == 1, "Missing or repeated original fixture completion")
    value = values[0]
    require(type(value.get("checks")) is int and value["checks"] > 0 and value.get("failures") == [], "Fixture assertions failed")
    return value


def retain_generated_uids(root, output):
    """Retain derivative metadata only for exact committed source owners.

    A fresh Windows import generates missing sidecars throughout the project,
    not merely for this repair's three new scripts. Enumerate the finite HEAD
    tree; an arbitrary new file with a .uid suffix is never an allowance.
    """
    output.mkdir(parents=True, exist_ok=True)
    status = subprocess.check_output(["git", "-C", str(root), "status", "--porcelain=v1", "--untracked-files=all"], timeout=60)
    (output / "git-status.txt").write_bytes(status)
    with (output / "git-diff.patch").open("wb") as stream:
        subprocess.run(["git", "-C", str(root), "diff", "--no-ext-diff", "--no-textconv", "HEAD", "--"],
                       stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=60)
    tree = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "-z", "HEAD", "--", "godot"], timeout=60)
    committed = {}
    for row in tree.decode("utf-8").split("\0"):
        if row:
            metadata, name = row.split("\t", 1)
            mode, kind, digest = metadata.split(" ")
            committed[name] = (mode, kind, digest)
    head_tree = git(root, "rev-parse", "HEAD^{tree}")
    index_before = git(root, "write-tree")
    require(index_before == head_tree, "Existing staged source changes cannot be refreshed")
    configuration = subprocess.check_output(["git", "-C", str(root), "config", "--show-origin", "--get-all", "core.autocrlf"], timeout=60)
    (output / "git-autocrlf.txt").write_bytes(configuration)
    owners = {name + ".uid": (name, digest) for name, (mode, kind, digest) in committed.items()
              if name.endswith((".gd", ".gdshader")) and mode in ("100644", "100755")
              and kind == "blob" and name + ".uid" not in committed}
    observed = {}
    observed_owners = {}
    for name, (owner, blob) in sorted(owners.items()):
        path = root / name
        if not path.exists() and not path.is_symlink():
            continue
        require(path.is_file() and not path.is_symlink() and re.fullmatch(rb"uid://[a-z0-9]+\r?\n?", path.read_bytes()),
                "Unexpected generated UID content or endpoint")
        source = root / owner
        require(source.is_file() and not source.is_symlink() and source.resolve().is_relative_to(root.resolve()),
                "UID has no regular committed script owner")
        require(not any((root / Path(owner).parents[index]).is_symlink() for index in range(len(Path(owner).parents))),
                "UID owner traverses a symlink directory")
        data = source.read_bytes()
        require(hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest() == blob,
                "UID owner bytes differ from exact committed source")
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(path.read_bytes())
        observed[name] = sha(target)
        observed_owners[name] = {"owner": owner, "owner_blob_sha1": blob, "owner_sha256": sha(source)}
    write(output / "retained.json", observed)
    write(output / "owners.json", observed_owners)
    for name, digest in observed.items():
        require(sha(root / name) == digest, "Generated metadata changed during retention")
        (root / name).unlink()

    # The accepted Windows runner canonically verifies only these four import
    # descriptors. Retain actual bytes and require line-ending-only equality
    # before restoring exact committed bytes; never normalize other inputs.
    descriptors = {}
    for name in sorted(RAPIER_IMPORT_DESCRIPTORS & committed.keys()):
        path = root / name
        require(committed[name][0] in ("100644", "100755") and path.is_file() and not path.is_symlink(),
                "Invalid committed Rapier import descriptor endpoint")
        original = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:" + name], timeout=60)
        actual = path.read_bytes()
        target = output / "import-descriptors" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(actual)
        require(actual.replace(b"\r\n", b"\n") == original.replace(b"\r\n", b"\n"),
                "Rapier import descriptor changed beyond accepted line endings")
        descriptors[name] = {"observed_sha256": sha(target), "committed_sha256": hashlib.sha256(original).hexdigest(),
                             "restored": actual != original}
        if actual != original:
            require(path.read_bytes() == actual, "Rapier descriptor changed during retention")
            path.write_bytes(original)
    write(output / "import-descriptors.json", descriptors)
    # Git can retain a false modified status when import writes exact HEAD LF
    # bytes over a CRLF checkout. Refresh only the independently byte-proven
    # descriptors, and prove the complete index tree is identical before/after.
    for name, record in descriptors.items():
        require(sha(root / name) == record["committed_sha256"], "Descriptor differs before exact-path index refresh")
    refresh = {"head_tree": head_tree, "index_before": index_before, "paths": sorted(descriptors)}
    if descriptors:
        result = subprocess.run(["git", "-C", str(root), "add", "--", *sorted(descriptors)],
                                capture_output=True, check=False, timeout=60)
        (output / "git-index-refresh.stdout").write_bytes(result.stdout)
        (output / "git-index-refresh.stderr").write_bytes(result.stderr)
        refresh["exit_code"] = result.returncode
        require(result.returncode == 0, "Exact descriptor index refresh failed")
    refresh["index_after"] = git(root, "write-tree")
    write(output / "git-index-refresh.json", refresh)
    require(refresh["index_after"] == head_tree, "Descriptor refresh changed a committed index mode or blob")
    result = subprocess.run(["git", "-C", str(root), "diff", "--cached", "--exit-code", "HEAD", "--"],
                            capture_output=True, check=False, timeout=60)
    (output / "git-cached-diff.patch").write_bytes(result.stdout + result.stderr)
    require(result.returncode == 0, "Descriptor refresh staged a source change")
    status = subprocess.check_output(["git", "-C", str(root), "status", "--porcelain=v1", "--untracked-files=all"], timeout=60)
    (output / "git-status-after.txt").write_bytes(status)
    # A different new file or any source mutation remains an actual refusal.
    require(not status.strip(), "Unexpected product change after import; retained exact git-status.txt and git-diff.patch")
    return observed


def verify_storage(folder, identity, engine):
    report = read(folder / "report.json")
    require(report.get("status") == "passed" and report.get("completed") is True and report.get("platform") == "win32"
            and report.get("source_head") == identity["source_commit"] and report.get("engine_sha256") == sha(engine),
            "OS report source/engine/platform or completion mismatch")
    require(report.get("input_sha256") == {name: identity["input_sha256"][name] for name in OS_INPUTS},
            "OS report omitted or changed required input set")
    require([row.get("fault") for row in report.get("cases", [])] == ["none", "locked-target"], "Incomplete actual Windows OS scenarios")
    require(len(report.get("executions", [])) == 5, "Incomplete normal/refusal/recovery execution inventory")
    for row in report["executions"]:
        require(row.get("natural_completion") is True and row.get("engine_error_detected") is False, "OS child incomplete")
        for path_key, hash_key in (("retained_bytes", "sha256"), ("log", "log_sha256")):
            name = row[path_key]
            require(Path(name).name == name and sha(folder / name) == row[hash_key], "Original OS evidence changed or escaped")
        data = read(folder / row["retained_bytes"])
        require(data.get("fixture") == "ULTIMA fixed audit writer, not a campaign transcript"
                and data.get("payload") == "Complete observed bytes. " * 64 and data.get("seed") == row.get("value")
                and row.get("complete_json") is True and (folder / row["retained_bytes"]).stat().st_size == row.get("bytes"),
                "Original retained document is incomplete or differs from observation")
        require(all(row.get("guards", {}).get(key) is True for key in
                    ("profile_verified", "wrong_path_refused", "wrong_profile_refused", "guards_preserved")),
                "Fixed path/profile guards were not exercised")
    executions = report["executions"]
    require([(row["acknowledged"], row["value"]) for row in executions] ==
            [(True, 7), (True, 8), (True, 7), (False, 7), (True, 8)], "Incorrect normal/refusal/retry outcomes")
    require(report["cases"][0]["before"] == executions[0] and report["cases"][0]["replacement"] == executions[1]
            and report["cases"][1]["before"] == executions[2] and report["cases"][1]["refusal"] == executions[3]
            and report["cases"][1]["retry"] == executions[4], "Summary differs from original observed executions")
    failed = report["cases"][1]
    require(failed["lock"].get("delete_access_probe_error") == 32 and failed["refusal"]["acknowledged"] is False
            and failed["before"]["sha256"] == failed["refusal"]["sha256"]
            and failed["retry"]["acknowledged"] is True and failed["retry"]["value"] == 8,
            "Actual sharing violation, preservation or recovery missing")
    return report


def qualify(args):
    require(sys.platform == "win32", "Actual Windows execution required")
    root, harness = args.product.resolve(), Path(__file__).resolve().parents[2]
    args.output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "cybersand-goblin001-storage-windows-v1", "status": "running", "platform": sys.platform,
              "owner_playfeel_accepted": False, "public_release": False, "cases": {}}
    try:
        requested = request(args.request)
        identity = admit(root, harness, requested)
        report.update(identity)
        report["request_sha256"] = sha(args.request)
        windows = module(root, "run_windows_godot_regressions")
        require(windows.RAPIER_IMPORT_DESCRIPTORS == RAPIER_IMPORT_DESCRIPTORS,
                "Source-owned Windows import descriptor contract changed")
        runtime = windows.verify_retained_runtime(root)
        require(len(runtime["native_source_inputs"]) == 105 and len(read(root / "godot/addons/godot-rapier2d/runtime-provenance.windows.json")["source_inputs"]) == 4,
                "Changed native105/Rapier4 contract")
        engine, engine_record = windows.prepare_godot(args.godot_archive)
        report.update(runtime=runtime, engine=engine_record)
        budget_record = identity["execution_budget"]
        env = dict(os.environ, APPDATA=str(args.output / "userdata"), LOCALAPPDATA=str(args.output / "localdata"),
                   XDG_DATA_HOME=str(args.output / "userdata"), CYBERSAND_SOURCE_REVISION=identity["source_commit"])
        env.pop("CYBERSAND_GOBLIN_PROFILE", None)
        for name in ("userdata", "localdata"):
            (args.output / name).mkdir()
        command = [str(engine), "--headless", "--audio-driver", "Dummy", "--path", str(root / "godot")]
        report["import"] = run(root, command + ["--editor", "--quit"], args.output / "import", env,
                               budget_record["policy"]["watchdogs"]["godot_import_seconds"])
        report["generated_import_metadata"] = retain_generated_uids(root, args.output / "generated-import-metadata")
        # The exact fixture has84 Linux assertions. Its two Linux-only blocks
        # contribute6 (including put()'s two checks) plus3; Windows executes75.
        for name, label, prefix, checks in ((CASES[0], "native_file_transaction", "FILE_TRANSACTION_RESULT ", 75),
                                            (CASES[1], "ordinary_default_off", "AMBIENT_DEFAULT_OFF ", 68)):
            result = run(root, command + ["--script", "res://tests/" + name + ".gd", "--", "--ci"],
                         args.output / label, env, budget_record["fixture_seconds"][name])
            result["terminal"] = terminal(args.output / label / "process.log", prefix)
            require(result["terminal"]["checks"] == checks, "Original fixture assertion inventory changed")
            report["cases"][label] = result
            write(args.output / "qualification.json", report)
        storage = args.output / "os-storage"
        report["cases"]["windows_os_faults"] = run(root, [sys.executable, str(root / "tools/ci/run_goblin_storage_qualification.py"),
            "--godot", str(engine), "--project", str(root / "godot"), "--evidence", str(storage)],
            args.output / "os-runner", env, budget_record["rows"]["original_windows_os_runner"] - 30)
        report["cases"]["windows_os_faults"]["report_sha256"] = sha(storage / "report.json")
        verify_storage(storage, identity, engine)
        report["generated_runtime_metadata"] = retain_generated_uids(root, args.output / "generated-runtime-metadata")
        controller = args.output / "controller"
        report["cases"]["goblin001_controller"] = run(root, [sys.executable, str(root / "tools/gip014/run_goblin.py"),
            "--godot", str(engine), "--out", str(controller), "--case", "controller", "--timeout-seconds", "180"],
            args.output / "controller-runner", env, budget_record["rows"]["original_controller_runner"] - 30)
        detail = read(controller / "qualification.json")
        require(detail["provenance"]["source_commit"] == identity["source_commit"]
                and detail["provenance"]["source_tree"] == identity["source_tree"] and detail["provenance"]["source_dirty"] is False,
                "Controller exercised different or dirty product")
        require(len(detail["tests"]) == 1 and detail["tests"][0]["status"] == "pass"
                and detail["tests"][0]["case"] == "goblin_controller" and detail["tests"][0]["completion_observed"] is True,
                "Controller campaign incomplete")
        report["cases"]["goblin001_controller"]["terminal"] = terminal(controller / "goblin_controller.log", "GOBLIN_CONTROLLER ")
        report["cases"]["goblin001_controller"]["report_sha256"] = sha(controller / "qualification.json")
        require(source_inputs(root) == identity["input_sha256"] and windows.verify_retained_runtime(root) == runtime,
                "Source/runtime changed during qualification")
        require(not git(root, "status", "--porcelain", "--untracked-files=all"), "Product changed during qualification")
        report.update(status="passed", input_custody="passed", completed=True)
    except Exception as error:
        report.update(status="failed", error=str(error), completed=False)
        raise
    finally:
        report["evidence_sha256"] = {p.relative_to(args.output).as_posix(): sha(p) for p in sorted(args.output.rglob("*"))
                                    if p.is_file() and p != args.output / "qualification.json"}
        write(args.output / "qualification.json", report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("read-request", "qualify"))
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--product", type=Path)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.command == "read-request":
        selected = request(args.request)
        require(args.github_output is not None, "GitHub output required")
        with args.github_output.open("a", encoding="utf-8") as stream:
            stream.write("source_commit=" + selected["source_commit"] + "\n")
    else:
        require(all(value is not None for value in (args.product, args.godot_archive, args.output)), "Qualification paths required")
        qualify(args)


if __name__ == "__main__":
    main()
