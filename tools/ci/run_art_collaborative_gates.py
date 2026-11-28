#!/usr/bin/env python3
"""Run the complete collaborative Art contract suite at one committed source.

These are deterministic loopback, copied-value and actual native fixtures, not
real-model creativity. The predecessor Art lifecycle matrix is a separate required
workflow stage. Each case uses a fresh process and a fresh package-local profile.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time

from strata_generated_imports import is_generated_strata_import

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "art-collaborative-gates-v1"
TESTS = {
    "test_art_owned_transport": "ART_OWNED_TRANSPORT_RESULT",
    "test_art_conversation_preparation": "ART_CONVERSATION_PREPARATION_RESULT",
    "test_art_conversation_apply_preparation": "ART_CONVERSATION_APPLY_RESULT",
    "test_art_authoring_proposal": "ART_PROPOSAL_RESULT",
    "test_art_creative_cohort": "ART_CREATIVE_COHORT_RESULT",
    "test_art_collaborative_native": "ART_COLLABORATIVE_NATIVE_RESULT",
    "test_art_collaboration_authority": "ART_COLLABORATION_AUTHORITY_RESULT",
    "test_art_collaboration_session": "ART_COLLABORATION_SESSION_RESULT",
    "test_art_collaboration_workspace": "ART_COLLABORATION_UI_RESULT",
}
REQUIRED_TESTS = frozenset(TESTS)
RUNTIME_PATHS = {
    "linux": (
        "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
        "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
    ),
    "windows": (
        "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
        "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
    ),
}


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=60).strip()


def untracked_source_rows(status: str) -> list[str]:
    rejected = []
    for row in status.split("\0"):
        if not row:
            continue
        if row.startswith("?? evidence/"):
            continue
        if row.startswith("?? godot/") and row.endswith((".gd.uid", ".gdshader.uid")):
            continue
        if row.startswith("?? ") and is_generated_strata_import(ROOT, row[3:]):
            continue
        if row.startswith("?? "):
            rejected.append(row)
    return rejected


def source_rejection_details(tracked: str, status: str) -> dict:
    """Keep path/status/hash evidence without copying changed source contents."""
    result = {"commit": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
              "tracked_porcelain": tracked, "all_porcelain_nul": status,
              "unstaged_paths": git("diff", "--name-only").splitlines(),
              "staged_paths": git("diff", "--cached", "--name-only").splitlines(),
              "import_descriptors": {}}
    for kind, arguments in (("unstaged", ["diff"]), ("staged", ["diff", "--cached"])):
        data = subprocess.check_output(["git", *arguments, "--no-ext-diff", "--binary"], cwd=ROOT, timeout=60)
        result[kind + "_diff_sha256"] = hashlib.sha256(data).hexdigest()
    imports = [path for path in git("ls-files", "-z", "--", "*.import").split("\0") if path]
    for relative in imports[:64]:
        path = ROOT / relative
        if path.is_file() and not path.is_symlink():
            current = path.read_bytes()
            lookup = subprocess.run(["git", "show", "HEAD:" + relative], cwd=ROOT, timeout=60,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            original = lookup.stdout if lookup.returncode == 0 else None
            result["import_descriptors"][relative] = {
                "worktree_sha256": hashlib.sha256(current).hexdigest(),
                "head_present": original is not None,
                "head_sha256": hashlib.sha256(original).hexdigest() if original is not None else None,
                "head_lookup_exit_code": lookup.returncode,
                "worktree_bytes": len(current), "head_bytes": len(original) if original is not None else None,
                "worktree_crlf": current.count(b"\r\n"), "worktree_lf": current.count(b"\n"),
                "head_crlf": original.count(b"\r\n") if original is not None else None,
                "head_lf": original.count(b"\n") if original is not None else None}
    result["omitted_import_descriptors"] = max(0, len(imports) - 64)
    return result


def source_identity(diagnostic_path: Path | None = None) -> dict:
    tracked = git("status", "--porcelain=v1", "--untracked-files=no")
    status = subprocess.check_output(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT, text=True, timeout=60)
    untracked = untracked_source_rows(status)
    if tracked or untracked:
        if diagnostic_path is not None:
            diagnostic_path.write_text(
                json.dumps(source_rejection_details(tracked, status), indent=2, sort_keys=True) + "\n",
                encoding="utf-8")
        if tracked:
            raise ValueError("Commit tracked source changes before this qualification campaign; rejected status rows:\n" + tracked)
        raise ValueError("Commit or remove untracked source before qualification; only evidence/, generated Godot UID sidecars and six hash-verified Strata texture descriptors are excluded:\n" + "\n".join(untracked))
    return {"commit": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
            "tracked_source_clean": True}


def no_failures(value: object) -> bool:
    return (type(value) is int and value == 0) or (type(value) is list and not value)


def parse_case_output(text: str, marker: str) -> dict:
    if any(signature in text for signature in ("SCRIPT ERROR:", "Parse Error:", "Failed to load script",
                                                "Failed loading resource:", "Error loading resource:")):
        raise ValueError("Original process log contains a script, parse or resource-loading failure")
    rows = [line.split(marker, 1)[1].strip() for line in text.splitlines() if line.startswith(marker + " ")]
    if len(rows) != 1:
        raise ValueError("Expected exactly one complete result marker: " + marker)
    result = json.loads(rows[0])
    if not isinstance(result, dict) or type(result.get("checks")) is not int or result["checks"] <= 0:
        raise ValueError("Missing positive assertion count: " + marker)
    if not no_failures(result.get("failures")):
        raise ValueError("Reported test failure: " + marker)
    if type(result.get("model_calls", 0)) is not int or result.get("model_calls", 0) != 0:
        raise ValueError("This fixture cohort cannot claim genuine model calls")
    return result


def validate_receipt(receipt: dict, *, commit: str, tree: str, platform_name: str,
                     graphical: bool) -> dict:
    if not isinstance(receipt, dict) or receipt.get("schema") != SCHEMA:
        raise ValueError("Unexpected collaborative qualification schema")
    if receipt.get("status") != "passed" or type(receipt.get("model_calls")) is not int or receipt.get("model_calls") != 0:
        raise ValueError("Collaborative qualification did not pass the fixture-only contract")
    if receipt.get("source") != {"commit": commit, "tree": tree, "tracked_source_clean": True} or receipt.get("source", {}).get("tracked_source_clean") is not True:
        raise ValueError("Collaborative evidence source differs from the package")
    if receipt.get("platform") != platform_name or receipt.get("graphical") is not graphical:
        raise ValueError("Collaborative evidence platform/display scope differs")
    cases = receipt.get("cases")
    if not isinstance(cases, list) or len(cases) != len(REQUIRED_TESTS):
        raise ValueError("Incomplete collaborative test matrix")
    names = [case.get("name") for case in cases if isinstance(case, dict)]
    if len(names) != len(cases) or len(set(names)) != len(names) or set(names) != REQUIRED_TESTS:
        raise ValueError("Missing, duplicate or unknown collaborative test case")
    for case in cases:
        if case.get("status") != "passed" or (type(case.get("exit_code")) is not int or case.get("exit_code") != 0) or case.get("timed_out"):
            raise ValueError("Failed or unexecuted collaborative test: " + case["name"])
        if case.get("marker") != TESTS[case["name"]]:
            raise ValueError("Case marker identity differs")
        result = case.get("result")
        if not isinstance(result, dict) or type(result.get("checks")) is not int or result["checks"] <= 0:
            raise ValueError("Case assertion proof is absent")
        if not no_failures(result.get("failures")) or type(result.get("model_calls", 0)) is not int or result.get("model_calls", 0) != 0:
            raise ValueError("Case contains a failure or a model-call claim")
        if not re.fullmatch(r"[0-9a-f]{64}", str(case.get("log_sha256", ""))):
            raise ValueError("Case log identity is absent")
    runtime = receipt.get("runtime")
    if not isinstance(runtime, dict) or set(runtime.get("payloads", {})) != set(RUNTIME_PATHS[platform_name]):
        raise ValueError("Source-matched native and Rapier runtime identities are absent")
    if not all(re.fullmatch(r"[0-9a-f]{64}", str(value)) for value in runtime["payloads"].values()):
        raise ValueError("Invalid runtime digest")
    if not re.fullmatch(r"[0-9a-f]{64}", str(runtime.get("godot_sha256", ""))):
        raise ValueError("Godot executable identity is absent")
    if runtime.get("godot_version") != "4.7.stable.official.5b4e0cb0f":
        raise ValueError("Collaborative evidence uses a different Godot pin")
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError("Use a new output directory to retain prior attempts")
    output.mkdir(parents=True)
    platform_name = "windows" if os.name == "nt" else "linux"
    source = source_identity(output / "source-admission-failure.json")
    godot = args.godot.resolve()
    project = args.project.resolve()
    if project != (ROOT / "godot").resolve():
        raise ValueError("This campaign must execute its own source tree")
    runtime = {"godot_sha256": digest(godot),
               "godot_version": subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip(),
               "payloads": {path: digest(ROOT / path) for path in RUNTIME_PATHS[platform_name]},
               "provenance_sha256": digest(ROOT / "godot/addons/cybersand_native/runtime-provenance.json")}
    receipt = {"schema": SCHEMA, "source": source, "platform": platform_name,
               "graphical": args.graphical, "runtime": runtime, "model_calls": 0,
               "evidence_kind": "deterministic loopback and native fixtures; not genuine model creativity",
               "host": {"platform": platform.platform(), "machine": platform.machine(),
                        "processor": platform.processor(), "logical_cpus": os.cpu_count()},
               "status": "running", "cases": []}
    receipt_path = output / "summary.json"
    def save() -> None:
        receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    save()
    for name, marker in TESTS.items():
        case_dir = output / name
        case_dir.mkdir()
        profile = case_dir / "profile"
        profile.mkdir()
        env = dict(os.environ, XDG_DATA_HOME=str(profile), APPDATA=str(profile),
                   LOCALAPPDATA=str(profile / "local"),
                   WB_ART_COLLAB_UI_EVIDENCE=str(case_dir),
                   WB_ART_COLLAB_EVIDENCE=str(case_dir),
                   CYBERSAND_TEST_ARTIFACT_DIR=str(case_dir),
                   CYBERSAND_SOURCE_REVISION=source["commit"])
        command = [str(godot), "--path", str(project), "--audio-driver", "Dummy"]
        if not args.graphical:
            command.append("--headless")
        else:
            command += ["--rendering-method", "gl_compatibility"]
            if os.name == "nt":
                command += ["--rendering-driver", "opengl3_angle"]
        command += ["--script", "res://tests/" + name + ".gd"]
        case_timeout = max(args.timeout, 1800) if name == "test_art_collaborative_native" else args.timeout
        began = time.monotonic()
        timed_out = False
        exit_code = None
        log = case_dir / "process.log"
        error = ""
        with log.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
            try:
                exit_code = process.wait(timeout=case_timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                if os.name == "nt":
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                   stdout=stream, stderr=subprocess.STDOUT, timeout=30, check=False)
                else:
                    process.kill()
                process.wait(timeout=30)
        text = log.read_text(encoding="utf-8", errors="replace")
        result = {}
        try:
            if timed_out or exit_code != 0 or "SCRIPT ERROR:" in text or "Parse Error:" in text:
                raise ValueError("Process failed, timed out or emitted a script error")
            result = parse_case_output(text, marker)
        except (ValueError, json.JSONDecodeError) as failure:
            error = str(failure)
        case = {"name": name, "marker": marker, "command": command,
                "exit_code": exit_code, "timed_out": timed_out, "timeout_seconds": case_timeout,
                "elapsed_seconds": round(time.monotonic() - began, 6),
                "log_sha256": digest(log), "result": result,
                "artifacts_sha256": {path.name: digest(path) for path in sorted(case_dir.iterdir())
                                    if path.is_file() and path.suffix in (".json", ".png")},
                "status": "failed" if error else "passed", "error": error}
        receipt["cases"].append(case)
        save()
        print(json.dumps({"case": name, "status": case["status"], "elapsed_seconds": case["elapsed_seconds"],
                          "checks": result.get("checks", 0), "error": error}), flush=True)
    receipt["status"] = "passed" if all(case["status"] == "passed" for case in receipt["cases"]) else "failed"
    # Detect any tracked mutation by the application before accepting source custody.
    try:
        if source_identity(output / "source-completion-failure.json") != source:
            receipt["status"] = "failed"
            receipt["source_changed_during_run"] = True
    except ValueError as error:
        receipt["status"] = "failed"
        receipt["source_changed_during_run"] = True
        receipt["source_error"] = str(error)
    save()
    if receipt["status"] == "passed":
        validate_receipt(receipt, commit=source["commit"], tree=source["tree"],
                         platform_name=platform_name, graphical=args.graphical)
    print("ART_COLLABORATIVE_GATES " + json.dumps({"status": receipt["status"], "summary": str(receipt_path)}))
    return 0 if receipt["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
