#!/usr/bin/env python3
"""Source-bound recovery of the existing Art/Architecture Windows qualification.

The requested application and this orchestration harness are separate checkouts.
Existing source-owned fixtures, watchdogs, storage faults and package builders
remain authoritative. This adapter adds no application or native mutation path.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from dataclasses import replace
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
import zipfile

SCHEMA = "cybersand-mergedown-art-qualification-v1"
REQUEST_SCHEMA = "cybersand-mergedown-art-request-v1"
MODES = (
    "retained-core-0", "retained-core-1", "retained-core-2",
    "retained-headless", "retained-displayed", "storage",
    "integration-displayed", "collaborative-headless", "collaborative-displayed",
)
# Exact retained Art core inventory from the existing art-session-logging job.
CORE = (
    "test_art_session_log", "test_art_manual_audit", "test_art_lazy_traffic",
    "test_art_traffic_panel_safety", "test_art_history_durability", "test_art_panel_ui",
    "test_art_model_roster", "test_art_invalid_local_model_close",
    "test_art_traffic_integrity", "test_art_history_receipt_identity",
    "test_art_provider_failure_lifecycle", "test_art_redaction_equivalence",
    "test_art_response_preparation", "test_art_request_preparation",
    "test_art_request_admission", "test_art_conversation_paging",
    "test_art_conversation_clipboard", "test_art_owner_evaluator",
    "test_art_batch_native", "test_art_provider", "test_art_deferred_manual",
    "test_art_stored_material", "test_art_undo",
)
GROUPS = ("network", "preparation", "request-preparation", "lifecycle", "conversation-apply")
STORAGE = ("test_workbench_file_transaction", "test_art_storage_integrity",
           "test_art_conversation_apply_preparation", "test_art_architecture_workbench")
DISPLAYED = ("test_art_panel_ui", "test_art_owner_evaluator", "test_art_conversation_clipboard",
             "test_art_batch_native_render")
INTEGRATION = ("test_ambient_default_off_integration", "test_art_architecture_workbench",
               "test_workbench_combined_authoring", "test_workbench_combined_authoring")
STORAGE_ROWS = (
    ("export", "none"), ("export", "locked-target"), ("new-event", "none"),
    ("append", "none"), ("append", "locked-target"), ("settings", "none"),
    ("settings", "locked-target"), ("pending-history", "none"),
    ("pending-history", "existing-receipt"),
)
MAX_JOB_SECONDS = 360 * 60
SHA40 = re.compile(r"[0-9a-f]{40}")
SHA64 = re.compile(r"[0-9a-f]{64}")
HARNESS_PATHS = frozenset((
    "tools/ci/mergedown_art_qualification.py", "tools/ci/test_mergedown_art_qualification.py",
    "tools/fixtures/mergedown-art-windows-request.json",
    ".github/workflows/mergedown-art-windows.yml", ".github/workflows/art-session-logging.yml",
))
SOURCE_CONTRACTS = frozenset((
    "tools/ci/run_godot_regressions.py", "tools/ci/run_windows_godot_regressions.py",
    "tools/ci/_architecture_campaign_context.py",
    "tools/ci/godot_timeout_diagnostics.py", "tools/ci/godot_process_monitor.py",
    "tools/ci/execution_policy.py", "tools/ci/execution_telemetry.py", "tools/ci/godot_scheduling.py",
    "tools/ci/run_art_storage_qualification.py", "tools/ci/windows_file_lock.py",
    "tools/ci/run_art_local_close.py", "tools/ci/run_art_collaborative_gates.py",
    "tools/ci/run_art_workbench_final.py", "tools/ci/art_evaluator_qualification_scope.py",
    "tools/package_art_collaborative.py", "tools/package_art_workbench_final.py",
    "tools/package_explore001_candidate.py", "tools/ci/materialize_lfs.py", "tools/ci/lfs_runtime_artifact.py",
    "godot/tests/art_storage_fault_child.gd", "godot/tests/test_workbench_file_transaction.gd",
    "godot/tests/test_art_storage_integrity.gd", "godot/tests/test_art_architecture_workbench.gd",
    "godot/tests/test_workbench_combined_authoring.gd", "godot/scripts/workbench_file_transaction.gd",
    ".github/workflows/art-session-logging.yml", "docs/operations/art-workbench-collaborative-evaluation.md",
))
RETAINED_MARKERS = {
    "test_art_session_log": "ART_SESSION_RESULT ",
    "test_art_owner_evaluator": "ART_EVALUATOR_INPUT_RESULT ",
    "test_art_batch_native": "ART_STAGE1_RESULT ",
    "test_art_batch_native_render": "ART_STAGE1_RESULT ",
    "test_art_stored_material": "ART_STORED_RESULT ",
    "test_art_undo": "ART_UNDO_RESULT ",
}
_METADATA_DEADLINE = None


def metadata_remaining() -> float:
    remaining = 900.0 if _METADATA_DEADLINE is None else _METADATA_DEADLINE - time.monotonic()
    require(remaining > 0, "Aggregate source/readback metadata allowance exhausted")
    return remaining


def metadata_timeout(maximum: float = 60) -> float:
    return min(maximum, metadata_remaining())


class MetadataEnvelope:
    """One cumulative source-derived allowance, paused during application cases."""
    def __init__(self, seconds: float):
        require(seconds > 0, "Metadata envelope must be positive")
        self.remaining = seconds

    @contextmanager
    def phase(self):
        global _METADATA_DEADLINE
        require(self.remaining > 0, "Aggregate source/readback metadata allowance exhausted")
        previous, began = _METADATA_DEADLINE, time.monotonic()
        _METADATA_DEADLINE = min(began + self.remaining, previous) if previous is not None else began + self.remaining
        try:
            yield
            metadata_remaining()
        finally:
            self.remaining -= time.monotonic() - began
            _METADATA_DEADLINE = previous


def verified_runtime(product: Path, windows) -> dict:
    # Admit the complete source-owned operation allowance, never a shortened
    # runtime check. Its own helper shares this allowance across all Git calls.
    allowance = windows.execution_policy.watchdog_seconds("operation_seconds")
    require(metadata_remaining() >= allowance, "Insufficient metadata allowance for complete runtime proof")
    with windows.metadata_budget():
        result = windows.verify_retained_runtime(product)
    metadata_remaining()
    return result


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def sha(path: Path) -> str:
    metadata_remaining()
    with path.open("rb") as stream:
        result = hashlib.file_digest(stream, "sha256").hexdigest()
    metadata_remaining()
    return result


def read(path: Path) -> dict:
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key")
            result[key] = value
        return result
    value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique)
    require(isinstance(value, dict), "Expected an object document")
    return value


def write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True, timeout=metadata_timeout()).strip()


def request(path: Path) -> dict:
    value = read(path)
    require(value.get("schema") == REQUEST_SCHEMA and value.get("repository") == "techrote/cybersand",
            "Unsupported request identity")
    require(value.get("status") == "admitted", "Request is not admitted")
    for key in ("source_commit", "source_tree", "accepted_main_baseline", "art_parent", "architecture_parent"):
        require(type(value.get(key)) is str and SHA40.fullmatch(value[key]) is not None,
                "Request must pin full source identities: " + key)
    require(value.get("modes") == list(MODES), "Missing, duplicate or changed campaign mode inventory")
    require(value.get("native_inputs") == 105 and value.get("rapier_inputs") == 4,
            "Changed native/Rapier source contract requires separate runtime qualification")
    require(value.get("owner_accepted") is False and value.get("public_release") is False,
            "This delivery cannot grant owner acceptance or release authority")
    contracts = value.get("source_contracts_sha256")
    require(type(contracts) is dict and set(contracts) == SOURCE_CONTRACTS and all(
        type(k) is str and not k.startswith("/") and ".." not in Path(k).parts
        and type(v) is str and SHA64.fullmatch(v) for k, v in contracts.items()),
        "Missing exact source-owned qualification contracts")
    return value


def module(product: Path, name: str):
    directory = (product / "tools/ci").resolve()
    sys.path.insert(0, str(directory))
    loaded = importlib.import_module(name)
    require(Path(loaded.__file__).resolve() == directory / (name + ".py"),
            "Source helper loaded from another checkout: " + name)
    return loaded


def context() -> dict:
    values = {"harness_commit": os.environ.get("GITHUB_SHA", ""),
              "run_id": os.environ.get("GITHUB_RUN_ID", ""),
              "attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "")}
    require(SHA40.fullmatch(values["harness_commit"]) is not None
            and values["run_id"].isdigit() and int(values["run_id"]) > 0
            and values["attempt"].isdigit() and int(values["attempt"]) > 0,
            "Actual source/run/attempt custody is required")
    values["attempt"] = int(values["attempt"])
    return values


def recovery_route(root: Path, request_path: Path) -> dict:
    """Route only this exact frozen application plus reviewed harness changes.

    A later application edit returns to ordinary Art qualification. This routing
    decision is never an application pass: the separate push campaign must run.
    """
    if not request_path.is_file():
        return {"recovery": False, "reason": "No registered frozen recovery request"}
    value = request(request_path)
    ancestor = subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor",
                               value["source_commit"], "HEAD"], timeout=60, check=False)
    if ancestor.returncode:
        return {"recovery": False, "reason": "Requested product is not this head's ancestor"}
    changed = git(root, "diff", "--name-only", value["source_commit"], "HEAD").splitlines()
    protected = [name for name in changed if name not in HARNESS_PATHS
                 and not name.startswith("docs/audits/2026-11-25-mergedown-renaissance/")]
    return {"recovery": not protected, "source_commit": value["source_commit"],
            "protected_changes": protected,
            "reason": "Separate source-bound Windows campaign required; this is not qualification"}


def selected_names(mode: str) -> tuple[str, ...]:
    require(mode in MODES, "Unknown qualification mode")
    if mode.startswith("retained-core-"):
        index = int(mode[-1])
        return CORE[index * 8:(index + 1) * 8]
    if mode == "storage":
        return STORAGE
    if mode == "retained-displayed":
        return DISPLAYED
    if mode == "integration-displayed":
        return INTEGRATION
    if mode == "retained-headless":
        return ("test_art_local_close",)
    return ()


def plan(product: Path, mode: str) -> dict:
    runner = module(product, "run_godot_regressions")
    policy = module(product, "execution_policy")
    discovered = {case.name: case for case in runner.discover_cases(product)}
    names = selected_names(mode)
    cases = [discovered[name] for name in names]
    cleanup = policy.godot_process_cleanup_seconds()
    phases = [{"name": "hosted checkout and pinned dependency setup", "seconds": 4200},
              {"name": "source-owned editor import and cleanup", "seconds": 1200 + cleanup},
              {"name": "canonical source-owned cases and cleanup",
               "seconds": sum(case.timeout + cleanup for case in cases)},
              {"name": "source and receipt readback", "seconds": policy.watchdog_seconds("godot_metadata_seconds")},
              {"name": "complete evidence upload", "seconds": 600},
              {"name": "aggregate headroom", "seconds": 600}]
    if mode in ("retained-headless", "retained-displayed"):
        legacy = module(product, "run_art_workbench_final")
        graphical = mode == "retained-displayed"
        groups = list(GROUPS) + ([] if graphical else ["preparation-exit", "request-preparation-exit"])
        phases.append({"name": "retained complete lifecycle/transport groups and cleanup",
                       "seconds": sum(legacy.process_watchdog(group, graphical, None)["seconds"] + 60
                                      for group in groups)})
    if mode == "storage":
        # Unchanged actual Windows OS runner: 9 rows * (40 observation+5 join+2 reader),
        # 15 version lookup and 30 outer owned cleanup. This is not Linux's 13 rows.
        phases.append({"name": "nine actual Windows storage rows", "seconds": 9 * 47 + 15 + 30})
    if mode.startswith("collaborative-"):
        collaborative = module(product, "run_art_collaborative_gates")
        require(len(collaborative.TESTS) == 9, "Collaborative inventory changed")
        phases.append({"name": "nine original collaborative cases and owned cleanup",
                       "seconds": 8 * 600 + 1800 + 9 * 60})
    total = sum(item["seconds"] for item in phases)
    require(total <= MAX_JOB_SECONDS, "Complete source-derived plan exceeds hosted six-hour boundary")
    return {"mode": mode, "cases": [runner.case_dict(case) for case in cases], "phases": phases,
            "total_seconds": total, "job_minutes": math.ceil(total / 60)}


def admit(request_path: Path, product: Path, harness: Path) -> dict:
    value = request(request_path)
    require(git(product, "rev-parse", "HEAD") == value["source_commit"]
            and git(product, "rev-parse", "HEAD^{tree}") == value["source_tree"], "Product source mismatch")
    require(not git(product, "status", "--porcelain=v1", "--untracked-files=all"), "Product is not clean committed source")
    for name in ("accepted_main_baseline", "art_parent", "architecture_parent"):
        git(product, "merge-base", "--is-ancestor", value[name], value["source_commit"])
    for relative, digest in value["source_contracts_sha256"].items():
        require(sha(product / relative) == digest, "Changed qualification contract: " + relative)
    require(git(harness, "rev-parse", "HEAD") == os.environ.get("GITHUB_SHA"), "Harness differs from workflow source")
    require(not git(harness, "status", "--porcelain=v1", "--untracked-files=all"), "Harness is not clean committed source")
    return {"schema": SCHEMA + "-admission", "status": "passed", **context(),
            "source_commit": value["source_commit"], "source_tree": value["source_tree"],
            "accepted_main_baseline": value["accepted_main_baseline"],
            "request_sha256": sha(request_path), "adapter_sha256": sha(Path(__file__)),
            "source_contracts_sha256": value["source_contracts_sha256"],
            "plans": [plan(product, mode) for mode in MODES],
            "scope": "Unmerged Art/Architecture integration; no physical or genuine-model acceptance"}


def command(argv: list[str], cwd: Path, output: Path, timeout: float, env: dict | None = None) -> dict:
    """Bound only the invoked original complete allowance; preserve every failure."""
    began = time.monotonic()
    with output.open("w", encoding="utf-8") as stream:
        process = subprocess.Popen(argv, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT)
        timed_out = False
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               stdout=stream, stderr=subprocess.STDOUT, timeout=30, check=False)
            else:
                process.kill()
            code = process.wait(timeout=30)
    result = {"command": argv, "exit_code": code, "timed_out": timed_out,
              "natural_completion": not timed_out, "seconds": time.monotonic() - began,
              "watchdog_seconds": timeout, "log_sha256": sha(output), "log": output.name,
              "status": "passed" if not timed_out and code == 0 else "failed"}
    write(output.with_suffix(output.suffix + ".process.json"), result)
    require(result["status"] == "passed", "Original process failed; retained log " + str(output))
    return result


def inventory(directory: Path) -> dict:
    files = {}
    for path in sorted(directory.rglob("*")):
        require(not path.is_symlink(), "Evidence contains a symlink")
        if path.is_file() and path != directory / "receipt.json":
            files[path.relative_to(directory).as_posix()] = {"sha256": sha(path), "bytes": path.stat().st_size}
    return files


def capture_source_state(product: Path, output: Path) -> None:
    # Keep observed paths and original diff bytes, including failed admission.
    output.mkdir(parents=True, exist_ok=True)
    for name, extra in (("source-status.txt", []), ("source-status-nul.bin", ["-z"])):
        (output / name).write_bytes(subprocess.check_output(
            ["git", "-C", str(product), "status", "--porcelain=v1", "--untracked-files=all", *extra], timeout=metadata_timeout()))
    for name, flags in (("unstaged", ()), ("staged", ("--cached",))):
        data = subprocess.check_output(["git", "-C", str(product), "diff", *flags,
                                        "--no-ext-diff", "--binary"], timeout=metadata_timeout())
        (output / (name + ".diff")).write_bytes(data)
    config = subprocess.run(["git", "-C", str(product), "config", "--show-origin", "--get-regexp",
        r"^(core\.(autocrlf|eol|filemode|ignorecase|symlinks)|filter\.lfs\.(clean|smudge|process|required)|extensions\..*)$"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=metadata_timeout(), check=False)
    (output / "source-relevant-config.txt").write_bytes(config.stdout)
    changed = set()
    for extra in ([], ["--cached"]):
        changed.update(name for name in subprocess.check_output(
            ["git", "-C", str(product), "diff", *extra, "--name-only", "-z"], timeout=metadata_timeout()
            ).decode("utf-8").split("\0") if name)
    # Git can report LFS size/stat dirt while the filtered diff is empty.
    for row in (output / "source-status-nul.bin").read_bytes().decode("utf-8").split("\0"):
        if row and not row.startswith("?? "):
            changed.add(row[3:])
    details = {"head": git(product, "rev-parse", "HEAD"), "head_tree": git(product, "rev-parse", "HEAD^{tree}"),
               "index_tree": git(product, "write-tree"), "changed_files": {}}
    for relative in sorted(changed):
        path = product / relative
        item = {"exists": path.exists(), "symlink": path.is_symlink()}
        if path.is_file() and not path.is_symlink():
            item.update(bytes=path.stat().st_size, sha256=sha(path))
            original = subprocess.run(["git", "-C", str(product), "show", "HEAD:" + relative],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=metadata_timeout(), check=False)
            if original.returncode == 0:
                item.update(head_bytes=len(original.stdout), head_sha256=hashlib.sha256(original.stdout).hexdigest(),
                            head_blob=git(product, "rev-parse", "HEAD:" + relative),
                            filtered_blob=git(product, "hash-object", "--path=" + relative, relative))
                pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", original.stdout)
                if pointer:
                    item["committed_lfs_object"] = {"sha256": pointer[1].decode(), "bytes": int(pointer[2])}
        details["changed_files"][relative] = item
    write(output / "source-state.json", details)


def admit_engine(product: Path, archive: Path, binary: Path) -> dict:
    windows = module(product, "run_windows_godot_regressions")
    digest = hashlib.sha512(archive.read_bytes()).hexdigest()
    require(digest == windows.GODOT_SHA512, "Engine archive differs from source pin")
    expected_names = {"Godot_v4.7-stable_win64_console.exe", "Godot_v4.7-stable_win64.exe"}
    payloads = {}
    with zipfile.ZipFile(archive) as bundle:
        for item in bundle.infolist():
            require(item.orig_filename == item.filename and "\\" not in item.orig_filename
                    and "\0" not in item.orig_filename and item.filename in expected_names
                    and item.filename not in payloads, "Unexpected engine archive identity")
            payloads[item.filename] = hashlib.sha256(bundle.read(item)).hexdigest()
    require(set(payloads) == expected_names and binary.name == "Godot_v4.7-stable_win64_console.exe",
            "Incomplete exact engine archive")
    for name, digest in payloads.items():
        require(sha(binary.with_name(name)) == digest, "Engine executable differs from verified archive")
    version = subprocess.check_output([str(binary), "--version"], text=True, timeout=30).strip()
    require(version == windows.GODOT_VERSION, "Engine version changed")
    return {"sha256": sha(binary), "version": version, "archive_sha512": windows.GODOT_SHA512,
            "payloads_sha256": payloads}


def refresh_verified_runtime_index(product: Path, output: Path, expected: dict) -> dict:
    """Refresh only stat metadata for two proven committed LFS objects.

    Source-owned 105/4 runtime verification, original pointer/raw-byte identity,
    filtered Git object identity, and identical HEAD/index trees are all required.
    Unknown paths and staged/actual source changes remain strict refusals.
    """
    paths = ("godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
             "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")
    receipt = {"status": "failed", "platform": sys.platform, "refreshed": False,
               "scope": "same-tree index stat refresh, not application execution", "runtime_paths": list(paths)}
    try:
        head, tree = git(product, "rev-parse", "HEAD"), git(product, "rev-parse", "HEAD^{tree}")
        require(head == expected["source_commit"] and tree == expected["source_tree"], "Runtime checkout source differs")
        receipt.update(source_commit=head, source_tree=tree, index_before=git(product, "write-tree"))
        require(receipt["index_before"] == tree, "Staged source cannot be refreshed")
        windows = module(product, "run_windows_godot_regressions")
        runtime = verified_runtime(product, windows)
        require(len(runtime["native_source_inputs"]) == 105, "Changed native input contract")
        rapier_path = "godot/addons/godot-rapier2d/runtime-provenance.windows.json"
        rapier = read(product / rapier_path)
        require(len(rapier.get("source_inputs", {})) == 4, "Changed Rapier input contract")
        require((product / rapier_path).read_bytes() == subprocess.check_output(
            ["git", "-C", str(product), "show", "HEAD:" + rapier_path], timeout=metadata_timeout()), "Rapier provenance changed")
        receipt["runtime"] = runtime
        receipt["objects"] = {}
        for relative in paths:
            original = subprocess.check_output(["git", "-C", str(product), "show", "HEAD:" + relative], timeout=metadata_timeout())
            pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", original)
            require(pointer is not None, "Runtime is not a canonical committed pointer")
            path = product / relative
            require(path.is_file() and not path.is_symlink() and path.stat().st_size == int(pointer[2])
                    and sha(path) == pointer[1].decode(), "Runtime bytes differ from the committed LFS object")
            head_blob = git(product, "rev-parse", "HEAD:" + relative)
            filtered = git(product, "hash-object", "--path=" + relative, relative)
            require(filtered == head_blob, "Runtime clean filter would change its committed Git object")
            receipt["objects"][relative] = {"sha256": pointer[1].decode(), "bytes": int(pointer[2]),
                                            "head_blob": head_blob, "filtered_blob": filtered}
        raw = subprocess.check_output(["git", "-C", str(product), "status", "--porcelain=v1", "-z",
                                        "--untracked-files=all"], timeout=metadata_timeout())
        rows = [row for row in raw.decode("utf-8").split("\0") if row]
        receipt["status_before"] = rows
        require(all(row in {" M " + path for path in paths} for row in rows),
                "Unknown or actual source changes cannot be hidden by runtime index refresh")
        if rows:
            subprocess.run(["git", "-C", str(product), "add", "--", *paths], check=True, timeout=metadata_timeout())
            receipt["refreshed"] = True
        receipt["index_after"] = git(product, "write-tree")
        require(receipt["index_after"] == tree and git(product, "rev-parse", "HEAD") == head,
                "Runtime index refresh changed committed source")
        require(not git(product, "status", "--porcelain=v1", "--untracked-files=all"),
                "Source remains dirty after exact-runtime stat refresh")
        require(verified_runtime(product, windows) == runtime, "Runtime moved during stat refresh")
        receipt["status"] = "passed"
        return runtime
    except Exception as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        write(output, receipt)


def verify_storage(value: dict, expected: dict) -> None:
    require(value.get("passed") is True and value.get("status") == "passed"
            and value.get("completed") is True and value.get("platform") == "win32"
            and value.get("source_head") == expected["source_commit"]
            and value.get("inputs_unchanged") is True
            and [(row.get("operation"), row.get("fault")) for row in value.get("cases", [])] == list(STORAGE_ROWS)
            and all(row.get("passed") is True and row.get("natural_completion") is True
                    and row.get("exit_code") == 0 for row in value["cases"]),
            "Actual Windows storage inventory failed")


def original_marker(log: Path, marker: str) -> dict:
    rows = [line[len(marker):] for line in log.read_text(encoding="utf-8", errors="replace").splitlines()
            if line.startswith(marker)]
    require(len(rows) == 1, "Missing or duplicate original result marker")
    value = json.loads(rows[0])
    require(type(value) is dict, "Original result is not an object")
    return value


def verify_retained_case_log(name: str, log: Path, graphical: bool) -> None:
    """Keep the existing workflow's explicit footer and native clipboard guards."""
    marker = RETAINED_MARKERS.get(name)
    if graphical and name == "test_art_conversation_clipboard":
        marker = "ART_CONVERSATION_CLIPBOARD_RESULT "
    if marker is None:
        return
    result = original_marker(log, marker)
    require(type(result.get("checks")) is int and result["checks"] > 0
            and (result.get("failures") == [] or type(result.get("failures")) is int and result["failures"] == 0),
            "Original retained footer did not prove completed assertions")
    if graphical and name == "test_art_conversation_clipboard":
        require(result.get("native_clipboard_differential") is True,
                "Displayed native clipboard differential did not execute")


def storage_case_directory(operation: str, fault: str) -> str:
    # Preserve the original runner's public-caller and private-panel labels.
    suffix = "normal" if fault == "none" and operation in ("export", "new-event", "append") else fault
    return operation + "-" + suffix


def readback_storage(root: Path, expected: dict, product: Path) -> None:
    value = read(root / "report.json")
    verify_storage(value, expected)
    storage = module(product, "run_art_storage_qualification")
    for row in value["cases"]:
        operation, fault, result = row["operation"], row["fault"], row["result"]
        log = root / storage_case_directory(operation, fault) / "child.log"
        require(sha(log) == row["log_sha256"]
                and original_marker(log, "ART_STORAGE_READY ") == row["ready"]
                and original_marker(log, "ART_STORAGE_RESULT ") == result
                and not storage.ENGINE_ERRORS.search(log.read_text(encoding="utf-8")),
                "Original Windows storage result differs")
        require(not result["partial_files"], "Storage left partial files")
        if fault == "locked-target":
            require(row.get("windows_lock") == {"desired_access": 0x80000000, "share_mode": 1,
                    "delete_access_probe_error": 32}, "Actual Windows DELETE sharing refusal is absent")
        if operation in ("settings", "pending-history"):
            first, retry = result["first"], result["retry"]
            require(first["success"] is (fault == "none") and retry["success"] is True
                    and retry["loadable"] is True and result["guards_preserved"] and result["stale_preserved"],
                    "Private storage acknowledgement or recovery differs")
            if operation == "settings":
                require(retry["value"] == 8 and retry["roundtrip"] and not retry["message"]
                        and result["settings_cache_guard"], "Settings retry did not persist the intended value")
                if fault != "none":
                    require(first["old_preserved"] and first["loadable"] and first["value"] == 7
                            and "did not replace the previous file" in first["message"]
                            and first["cached_revert_success"] and first["cached_revert_cleared_owned_error"],
                            "Failed settings write lost valid destination or acknowledged success")
            else:
                require(first["old_preserved"] and retry["old_preserved"] and retry["values"] == [7, 8]
                        and retry["schema"] == 2 and retry["frozen_projection"]
                        and retry["item_has_file"] and retry["item_has_order"], "Pending history retry differs")
                if fault != "none":
                    require(first["loadable"] and first["values"] == [7] and first["message"]
                            and not first["item_has_file"] and not first["item_has_order"] and first["clock_unchanged"],
                            "Pending history refusal changed receipt custody")
        elif fault == "none":
            require(result["success"] and result["source_unchanged"] and result["replay_ok"]
                    and result["recovered_count"] == (2 if operation == "append" else 1)
                    and (operation != "export" or result["expected_export_equal"]), "Normal public storage failed")
        else:
            require(not result["success"] and bool(result["message"]) and result["source_unchanged"],
                    "Failed public storage falsely acknowledged success")
            require(result["old_preserved"] if operation == "export" else
                    result["old_prefix_preserved"] and not result["last_event_stored"]
                    and result["replay_ok"] and result["recovered_count"] == 1,
                    "Failed public storage destroyed valid retained data")


def readback_group(root: Path, group: str, graphical: bool, expected: dict, product: Path) -> None:
    legacy = module(product, "run_art_workbench_final")
    execution, report, provenance = read(root / "execution.json"), read(root / "report.json"), read(root / "provenance.json")
    require(execution.get("timed_out") is False and execution.get("exit_code") == 0
            and execution.get("watchdog_seconds") == legacy.process_watchdog(group, graphical, None)["seconds"],
            "Retained lifecycle process did not naturally finish its original allowance")
    require(provenance.get("source", {}).get("head") == expected["source_commit"]
            and provenance["source"].get("tree") == expected["source_tree"], "Retained lifecycle source differs")
    log = root / "godot.log"
    raw = original_marker(log, legacy.MARKER)
    require(not legacy.ERRORS.search(log.read_text(encoding="utf-8"))
            and all(report.get(key) == value for key, value in raw.items()) and not report.get("failures"),
            "Original retained lifecycle result differs")
    minimums = {"preparation-exit": (0, 6), "request-preparation-exit": (0, 6),
                "lifecycle": (2, 60), "conversation-apply": (1, 20),
                "request-preparation": (4, 60), "preparation": (3, 60), "network": (22, 60)}
    cases, checks = minimums[group]
    require(type(report.get("checks")) is int and report["checks"] >= checks
            and len(report.get("cases", [])) >= cases, "Retained lifecycle arms are incomplete")
    fixture = json.loads((root / "fixture-receipts.json").read_text(encoding="utf-8"))
    require(legacy.verify_complete_audit(root / "isolated-profile", report["cases"], fixture)
            == read(root / "audit-verification.json"), "Independent complete audit replay differs")
    if graphical:
        require(report.get("display") not in (None, "", "headless")
                and (root / "art-window.png").is_file(), "Missing actual displayed lifecycle framebuffer")
        if group == "conversation-apply":
            require((root / "conversation-before-apply.png").is_file()
                    and (root / "conversation-before-apply.png").stat().st_size > 0,
                    "Missing displayed conversation Apply frame")


def execute(args) -> None:
    require(sys.platform == "win32", "Windows execution cannot be claimed on another host")
    product, output = args.product.resolve(), args.output.resolve()
    require(not output.exists(), "Retain previous evidence; use a new output path")
    output.mkdir(parents=True)
    metadata = MetadataEnvelope(module(product, "execution_policy").watchdog_seconds("godot_metadata_seconds"))
    try:
        with metadata.phase():
            capture_source_state(product, output / "admission-product")
            capture_source_state(args.harness.resolve(), output / "admission-harness")
            runtime = refresh_verified_runtime_index(product, output / "runtime-index-admission.json", request(args.request))
            admission = admit(args.request, product, args.harness.resolve())
    except Exception as error:
        write(output / "receipt.json", {"schema": SCHEMA, "status": "failed", "completed": False,
            "phase": "pre-import source admission", "mode": args.mode, **context(),
            "error": f"{type(error).__name__}: {error}", "files": inventory(output)})
        raise
    write(output / "admission.json", admission)
    runner = module(product, "run_godot_regressions")
    windows = module(product, "run_windows_godot_regressions")
    selected = plan(product, args.mode)
    receipt = {"schema": SCHEMA, "status": "running", "mode": args.mode, **context(),
               "source_commit": admission["source_commit"], "source_tree": admission["source_tree"],
               "request_sha256": admission["request_sha256"], "adapter_sha256": admission["adapter_sha256"],
               "plan": selected, "cases": [], "commands": [], "platform": sys.platform,
               "model_calls": 0, "physical_owner_accepted": False, "completed": False}
    before = None
    try:
        with metadata.phase():
            receipt["runtime"] = runtime
            receipt["engine"] = admit_engine(product, args.godot_archive, args.godot)
            require(metadata_remaining() >= windows.execution_policy.watchdog_seconds("operation_seconds"),
                    "Insufficient metadata allowance for complete input inventory")
            with windows.metadata_budget():
                before = windows.tested_inputs(product)
            write(output / "inputs-before.json", before)
        env = dict(os.environ, APPDATA=str(output / "import-profile"), XDG_DATA_HOME=str(output / "import-profile"),
                   CYBERSAND_SOURCE_REVISION=admission["source_commit"])
        receipt["commands"].append(command([str(args.godot), "--headless", "--audio-driver", "Dummy",
            "--path", str(product / "godot"), "--editor", "--import"], product, output / "import.log", 1200, env))
        require(not runner.case_diagnostic_error("source-import", (output / "import.log").read_text(encoding="utf-8"), 0),
                "Early parser admission failed")
        discovered = {case.name: case for case in runner.discover_cases(product)}
        for index, name in enumerate(selected_names(args.mode)):
            case = discovered[name]
            graphical = args.mode.endswith("displayed")
            if graphical:
                # Canonical case, unchanged watchdog; explicitly exercise ANGLE.
                case = replace(case, requires_display=True, flags=("--rendering-driver", "opengl3_angle", *case.flags))
            case_out = output / f"{index:02d}-{name}"
            case_out.mkdir()
            profile = output / ("authored-profile" if name == "test_workbench_combined_authoring" else f"profile-{index}")
            case_env = dict(os.environ, APPDATA=str(profile), XDG_DATA_HOME=str(profile),
                            CYBERSAND_SOURCE_REVISION=admission["source_commit"])
            if graphical:
                case_env["WB_COMBINED_REQUIRE_GRAPHICS"] = "1"
                case_env["CYBERSAND_TEST_OWNED_CLIPBOARD"] = "1"
            if name == "test_workbench_combined_authoring" and index == 3:
                case_env["WB_COMBINED_REOPEN"] = "1"
            record, failed = runner.run_case(str(args.godot), case, case_out, args.mode, env=case_env)
            receipt["cases"].append(record)
            write(output / "receipt.json", receipt)
            require(not failed, "Canonical source case failed: " + name)
            verify_retained_case_log(name, case_out / record["log"], graphical)
        if args.mode in ("retained-headless", "retained-displayed"):
            graphical = args.mode == "retained-displayed"
            legacy = module(product, "run_art_workbench_final")
            for group in list(GROUPS) + ([] if graphical else ["preparation-exit", "request-preparation-exit"]):
                argv = [sys.executable, str(product / "tools/ci/run_art_workbench_final.py"), "--godot", str(args.godot),
                        "--project", str(product / "godot"), "--output", str(output / ("group-" + group)), "--group", group]
                if graphical:
                    argv.append("--graphical")
                allowance = legacy.process_watchdog(group, graphical, None)["seconds"] + 60
                receipt["commands"].append(command(argv, product, output / ("group-" + group + ".log"), allowance))
        if args.mode == "storage":
            receipt["commands"].append(command([sys.executable, str(product / "tools/ci/run_art_storage_qualification.py"),
                "--godot", str(args.godot), "--project", str(product / "godot"), "--evidence", str(output / "os-storage")],
                product, output / "os-storage.log", 468))
            verify_storage(read(output / "os-storage/report.json"), admission)
        if args.mode.startswith("collaborative-"):
            argv = [sys.executable, str(product / "tools/ci/run_art_collaborative_gates.py"),
                    "--godot", str(args.godot), "--project", str(product / "godot"), "--output", str(output / "collaborative")]
            if args.mode.endswith("displayed"):
                argv.append("--graphical")
            receipt["commands"].append(command(argv, product, output / "collaborative.log", 8 * 600 + 1800 + 9 * 60))
            collaborative = module(product, "run_art_collaborative_gates")
            collaborative.validate_receipt(read(output / "collaborative/summary.json"), commit=admission["source_commit"],
                tree=admission["source_tree"], platform_name="windows", graphical=args.mode.endswith("displayed"))
        receipt.update(status="passed", completed=True)
    except Exception as error:
        receipt.update(status="failed", error=f"{type(error).__name__}: {error}")
        raise
    finally:
        try:
            with metadata.phase():
                capture_source_state(product, output)
                if before is not None:
                    require(metadata_remaining() >= windows.execution_policy.watchdog_seconds("operation_seconds"),
                            "Insufficient metadata allowance for complete input readback")
                    with windows.metadata_budget():
                        after = windows.tested_inputs(product)
                    write(output / "inputs-after.json", after)
                    receipt["inputs_unchanged"] = before == after
                    if not receipt["inputs_unchanged"]:
                        receipt.update(status="failed", error="Application/source/runtime input changed")
                receipt["files"] = inventory(output)
        except Exception as error:
            receipt.update(status="failed", readback_error=f"{type(error).__name__}: {error}")
        receipt["metadata_seconds_remaining"] = metadata.remaining
        write(output / "receipt.json", receipt)
    require(receipt["status"] == "passed", "Final source/runtime custody failed")


def verify_evidence(root: Path, value: dict, expected: dict, mode: str) -> None:
    require(value.get("schema") == SCHEMA and value.get("status") == "passed" and value.get("completed") is True
            and value.get("platform") == "win32" and value.get("inputs_unchanged") is True
            and value.get("mode") == mode and value.get("model_calls") == 0
            and value.get("physical_owner_accepted") is False, "Incomplete or mislabeled Windows mode: " + mode)
    for key in ("harness_commit", "run_id", "attempt", "source_commit", "source_tree", "request_sha256", "adapter_sha256"):
        require(type(value.get(key)) is type(expected[key]) and value.get(key) == expected[key], "Mismatched campaign binding: " + key)
    require(value.get("files") == inventory(root), "Original evidence inventory changed: " + mode)
    require([case.get("name") for case in value.get("cases", [])] == list(selected_names(mode)), "Mode case inventory differs")
    require(all(case.get("status") == "passed" and case.get("natural_completion") is True
                and case.get("returncode") == 0 and not case.get("diagnostic_error")
                and not case.get("skip_messages") and not case.get("launch_error")
                and not case.get("capture_error") for case in value["cases"]),
            "Unqualified canonical case in mode " + mode)
    require(all(item.get("status") == "passed" and item.get("natural_completion") is True
                and item.get("exit_code") == 0 and item.get("timed_out") is False
                for item in value.get("commands", [])), "Failed source-owned helper in mode " + mode)
    expected_commands = 1 + (7 if mode == "retained-headless" else 5 if mode == "retained-displayed"
                             else 1 if mode == "storage" or mode.startswith("collaborative-") else 0)
    require(len(value.get("commands", [])) == expected_commands, "Missing original helper execution")
    for index, case in enumerate(value["cases"]):
        log = root / f"{index:02d}-{case['name']}" / case["log"]
        require(log.is_file() and sha(log) == case["log_sha256"], "Original case log differs")
        verify_retained_case_log(case["name"], log, mode.endswith("displayed"))
    for command_record in value["commands"]:
        log = root / command_record["log"]
        require(log.is_file() and sha(log) == command_record["log_sha256"], "Original helper log differs")
    if mode == "storage":
        verify_storage(read(root / "os-storage/report.json"), expected)


def reduce(args) -> None:
    metadata = MetadataEnvelope(module(args.product.resolve(), "execution_policy").watchdog_seconds("godot_metadata_seconds"))
    with metadata.phase():
        reduce_within_metadata(args)


def reduce_within_metadata(args) -> None:
    args.output.mkdir(parents=True, exist_ok=True)
    capture_source_state(args.product.resolve(), args.output / "admission-product")
    refresh_verified_runtime_index(args.product.resolve(), args.output / "runtime-index-admission.json", request(args.request))
    admission = admit(args.request, args.product.resolve(), args.harness.resolve())
    outputs = {}
    runtime = None
    engine = None
    for mode in MODES:
        root = args.evidence / mode
        value = read(root / "receipt.json")
        verify_evidence(root, value, admission, mode)
        require(value.get("plan") == plan(args.product.resolve(), mode), "Source-derived plan changed")
        if mode.startswith("collaborative-"):
            sys.path.insert(0, str(args.product.resolve() / "tools"))
            package = importlib.import_module("package_art_collaborative")
            original = package.receipt(root / "collaborative/summary.json", admission["source_commit"],
                admission["source_tree"], mode.endswith("displayed"), check_logs=True)
            require(original["runtime"]["godot_sha256"] == value["engine"]["sha256"],
                    "Collaborative engine differs from the admitted engine")
        if mode in ("retained-headless", "retained-displayed"):
            graphical = mode == "retained-displayed"
            for group in list(GROUPS) + ([] if graphical else ["preparation-exit", "request-preparation-exit"]):
                readback_group(root / ("group-" + group), group, graphical, admission, args.product.resolve())
        if mode == "storage":
            readback_storage(root / "os-storage", admission, args.product.resolve())
        if runtime is None:
            runtime = value["runtime"]
        require(value["runtime"] == runtime, "Distinct Windows runtime selections across campaign")
        if engine is None:
            engine = value["engine"]
        require(value["engine"] == engine and engine["archive_sha512"] == module(
            args.product.resolve(), "run_windows_godot_regressions").GODOT_SHA512,
            "Distinct or unpinned engine selections across campaign")
        outputs[mode] = {"receipt_sha256": sha(root / "receipt.json"), "files": len(value["files"])}
    # Use the source-owned fresh qualification decision; no predecessor reuse.
    scope = module(args.product.resolve(), "art_evaluator_qualification_scope")
    decision = scope.inspect_scope(args.product.resolve())
    require(decision.get("mode") == "full_required" and decision.get("reuse") is False,
            "Recovered product must receive fresh qualification")
    scope.validate_completed_decision(decision, admission["source_commit"], admission["source_tree"])
    write(args.output / "application-qualification.json", decision)
    write(args.output / "combined-windows-qualification.json", {
        "schema": SCHEMA + "-reduction", "status": "passed", **context(),
        "source_commit": admission["source_commit"], "source_tree": admission["source_tree"],
        "modes": outputs, "runtime": runtime, "engine": engine, "physical_owner_accepted": False, "model_calls": 0,
        "scope": "Complete retained Art, fresh collaboration, combined native/graphical authoring and Windows storage; full Ready/native regression remains separate"})


def seal_package(args) -> None:
    admission = admit(args.request, args.product.resolve(), args.harness.resolve())
    sys.path.insert(0, str(args.product.resolve() / "tools"))
    package = importlib.import_module("package_art_collaborative")
    require(Path(package.__file__).resolve() == args.product.resolve() / "tools/package_art_collaborative.py",
            "Package builder is not source-owned")
    identity = package.verify(args.output)
    require(identity["source_commit"] == admission["source_commit"] and identity["source_tree"] == admission["source_tree"],
            "Package source differs from request")
    reduction = read(args.evidence / "combined-windows-qualification.json")
    require(reduction.get("status") == "passed" and reduction.get("modes", {}).keys() == set(MODES),
            "Incomplete combined qualification")
    for key in ("harness_commit", "run_id", "attempt", "source_commit", "source_tree"):
        require(type(reduction.get(key)) is type(admission[key]) and reduction[key] == admission[key],
                "Package evidence belongs to another campaign")
    for name, digest in reduction["engine"]["payloads_sha256"].items():
        require(sha(args.output / name) == digest, "Delivered engine differs from admitted source-pinned archive")
    relative = "qualification/mergedown-art-architecture-windows.json"
    write(args.output / relative, reduction)
    identity["mergedown_integration"] = {"status": "Draft/HOLD", "accepted_main": False,
        "source_commit": admission["source_commit"], "source_tree": admission["source_tree"],
        "accepted_main_baseline": admission["accepted_main_baseline"], **context(),
        "qualification": relative, "physical_owner_accepted": False, "genuine_model_accepted": False}
    identity["files_sha256"] = {path.relative_to(args.output).as_posix(): sha(path)
        for path in sorted(args.output.rglob("*")) if path.is_file() and path.name != package.retained.MANIFEST}
    write(args.output / package.retained.MANIFEST, identity)
    package.verify(args.output)


def archive_readback(args) -> None:
    """Read every original archive member and immutable byte before delivery."""
    archive = args.output.with_suffix(".zip")
    # The source-owned package module is authoritative for its manifest name.
    sys.path.insert(0, str(args.product.resolve() / "tools"))
    package = importlib.import_module("package_art_collaborative")
    identity = package.verify(args.output)
    manifest = args.output / package.retained.MANIFEST
    expected = dict(identity["files_sha256"], **{manifest.name: sha(manifest)})
    prefix = args.output.name + "/"
    observed = set()
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            original = member.orig_filename
            require(original == member.filename and "\\" not in original and "\0" not in original
                    and original.startswith(prefix), "Malformed original archive member")
            relative = original[len(prefix):]
            require(relative in expected and relative not in observed and not member.is_dir(),
                    "Unexpected or duplicate archive member")
            require(hashlib.sha256(bundle.read(member)).hexdigest() == expected[relative],
                    "Immutable archive payload differs")
            observed.add(relative)
    require(observed == set(expected), "Incomplete delivered archive inventory")
    write(args.evidence / "delivered-archive.json", {"status": "passed", **context(),
        "source_commit": identity["source_commit"], "source_tree": identity["source_tree"],
        "archive": archive.name, "bytes": archive.stat().st_size, "sha256": sha(archive),
        "manifest_sha256": sha(manifest), "immutable_payloads": len(identity["files_sha256"]),
        "archive_members": len(observed), "accepted_main": False, "physical_owner_accepted": False})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("read-request", "route", "admit", "execute", "reduce", "seal-package", "archive-readback"))
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--product", type=Path)
    parser.add_argument("--harness", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--mode", choices=MODES)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    if args.operation == "route":
        value = recovery_route(args.harness.resolve(), args.request)
        print(json.dumps(value))
        if args.github_output:
            with args.github_output.open("a", encoding="utf-8") as stream:
                stream.write("recovery=" + str(value["recovery"]).lower() + "\n")
        return
    if args.operation == "read-request":
        value = request(args.request)
        print(json.dumps({"source_commit": value["source_commit"], "source_tree": value["source_tree"]}))
        if args.github_output:
            with args.github_output.open("a", encoding="utf-8") as stream:
                stream.write("source_commit=" + value["source_commit"] + "\n")
        return
    require(args.product is not None and args.output is not None, "Product and output are required")
    if args.operation == "admit":
        write(args.output, admit(args.request, args.product.resolve(), args.harness.resolve()))
    elif args.operation == "execute":
        require(args.godot is not None and args.godot_archive is not None and args.mode is not None,
                "Execution requires the exact archive, engine and literal mode")
        execute(args)
    elif args.operation == "reduce":
        require(args.evidence is not None, "Reduction requires original same-attempt evidence")
        reduce(args)
    elif args.operation == "seal-package":
        require(args.evidence is not None, "Package seal requires the complete campaign reduction")
        seal_package(args)
    else:
        require(args.evidence is not None, "Archive readback requires an evidence output")
        archive_readback(args)


if __name__ == "__main__":
    main()
