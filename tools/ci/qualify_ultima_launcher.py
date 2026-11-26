#!/usr/bin/env python3
"""Execute the shipped Windows .cmd in a verified disposable evaluator copy.

This is package/launcher qualification, not manual GUI or physical GPU acceptance.
The original extraction and every manifest-bound payload byte must stay intact.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

import execution_policy
import package_ultima_evaluator as package
import run_godot_regressions as regression

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "res://tests/test_paint_editor_history.gd"
HISTORY_LABEL = "paint001-history-regression"
SAVE_NAMES = {"setup-" + HISTORY_LABEL + suffix + ".json"
              for suffix in ("", "-generated", "-dense", "-dense-generated")}
FATAL = re.compile(r"SCRIPT ERROR:|ERROR:|Parse Error:|\bskipped\b|^\s*SKIP\b|"
                   r"Press any key to continue", re.IGNORECASE | re.MULTILINE)
BANNER = re.compile(r"^Godot Engine v([^\s]+)", re.MULTILINE)
RESULT = re.compile(r"^PAINT_EDITOR_HISTORY checks=(\d+) failures=(\d+) reopened=(true|false)\s*$",
                    re.MULTILINE)


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_json(path, document):
    path.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def command_line(launcher: Path, arguments: list[str], comspec: str) -> str:
    # cmd's /s /c strips the outer pair; the launcher path keeps its own quotes.
    # No caller-supplied shell expression is admitted, including percent expansion.
    for value in [str(launcher), comspec, *arguments]:
        require(not any(character in value for character in '\r\n"%&|<>^!'),
                "Unsupported cmd metacharacter in a qualification path/argument")
    return '"' + comspec + '" /d /s /c ""' + str(launcher) + '" ' + subprocess.list2cmdline(arguments) + '"'


def run_process(command, cwd: Path, env: dict, directory: Path, allowance: float,
                cleanup_seconds: float, *, windows: bool) -> dict:
    """Preserve original streams; an early engine error or forced exit cannot pass."""
    directory.mkdir()
    stdout_path, stderr_path = directory / "stdout.log", directory / "stderr.log"
    record = {"command": command, "allowance_seconds": allowance, "status": "failed",
              "natural_completion": False, "termination_requested": False,
              "timeout": False, "engine_error_detected": False, "exit_code": None}
    started = time.monotonic()
    process = None
    readers = []
    tails = [b"", b""]
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        try:
            options = ({"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if windows
                       else {"start_new_session": True})
            process = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                       stdout=stdout, stderr=stderr, **options)
            record["pid"] = process.pid
            readers = [stdout_path.open("rb"), stderr_path.open("rb")]
            while True:
                for index, reader in enumerate(readers):
                    fresh = reader.read(262144)
                    if fresh:
                        observed = tails[index] + fresh
                        tails[index] = observed[-1024:]
                        if FATAL.search(observed.decode("utf-8", errors="replace")):
                            record["engine_error_detected"] = True
                if record["engine_error_detected"]:
                    if process.poll() is None:
                        record["termination_requested"] = True
                    break
                if process.poll() is not None:
                    break
                if time.monotonic() - started >= allowance:
                    record["timeout"] = True
                    record["termination_requested"] = True
                    break
                try:
                    process.wait(timeout=min(0.2, max(0.001, allowance - (time.monotonic() - started))))
                except subprocess.TimeoutExpired:
                    pass
        except OSError as error:
            record["launch_error"] = str(error)
        finally:
            if process is not None:
                if record["termination_requested"] or process.poll() is None:
                    record["termination_requested"] = True
                    regression._kill_process_tree(process, wait_seconds=cleanup_seconds)
                record["exit_code"] = process.poll()
                record["natural_completion"] = (not record["termination_requested"]
                                                 and record["exit_code"] is not None)
            for reader in readers:
                reader.close()
    record["elapsed_seconds"] = time.monotonic() - started
    for label, path in (("stdout", stdout_path), ("stderr", stderr_path)):
        raw = path.read_bytes()
        record[label] = {"path": path.name, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
        if FATAL.search(raw.decode("utf-8", errors="replace")):
            record["engine_error_detected"] = True
    if (record["natural_completion"] and record["exit_code"] == 0
            and not record["engine_error_detected"] and not record.get("launch_error")):
        record["status"] = "passed"
    return record


def validate_output(record: dict, stdout: str, expected_version: str,
                    *, reopened: bool | None, graphical: bool) -> dict:
    require(record["status"] == "passed", "Launcher process did not finish naturally without errors")
    versions = BANNER.findall(stdout)
    require(versions == [expected_version, expected_version],
            "The shipped launcher must execute its pinned import and runtime")
    result = {"engine_starts": versions}
    if reopened is not None:
        matches = RESULT.findall(stdout)
        require(len(matches) == 1, "Missing or duplicate authored workflow terminal result")
        checks, failures, actual_reopen = matches[0]
        require(int(checks) > 0 and int(failures) == 0 and actual_reopen == str(reopened).lower(),
                "Authored workflow result contradicts the requested author/reopen process")
        result["authored_workflow"] = {"checks": int(checks), "failures": int(failures),
                                      "reopened": reopened}
    if graphical:
        renderer_lines = [line for line in stdout.splitlines() if "OpenGL API" in line]
        require(renderer_lines, "Graphical startup did not identify its compatibility renderer")
        result["renderer_lines"] = renderer_lines
    return result


def saved_files(copy: Path) -> dict:
    userdata = copy / "userdata"
    require(userdata.is_dir() and not userdata.is_symlink(), "Launcher did not create its own isolated userdata")
    found = {}
    for path in userdata.rglob("setup-" + HISTORY_LABEL + "*.json"):
        require(path.name in SAVE_NAMES and path.name not in found and not path.is_symlink()
                and path.resolve().is_relative_to(userdata.resolve()), "Unexpected or redirected authored save")
        document = package.read_json(path)
        generated = "-generated" in path.name
        if generated:
            require(document.get("version") == 1 and document.get("format") == "cybersand-generated-start-v1",
                    "Wrong generated start format")
        setup = document.get("starting_setup", {}) if generated else document
        require(setup.get("version") == 2 and setup.get("extent") == [512, 512]
                and setup.get("selected") == 1 and len(setup.get("actors", [])) == 1,
                "Authored fixture values did not survive the launcher data path")
        count = len(setup.get("edits", []))
        require(count > 4096 if "-dense" in path.name else count > 0,
                "Missing authored fixture material edits")
        found[path.name] = {"path": path.relative_to(copy).as_posix(), "bytes": path.stat().st_size,
                            "sha256": sha(path), "generated": generated, "edit_count": count}
    require(set(found) == SAVE_NAMES, "The four authored saves are not in the launcher's isolated userdata")
    return found


def prepare_copy(original: Path, output: Path, expected_digest: str) -> tuple[Path, dict]:
    manifest = package.verify(original, expected_digest)
    copy = output / "launcher copy with spaces"
    copy.mkdir()
    for relative in [*manifest["files_sha256"], "candidate-manifest.json"]:
        source, destination = original / relative, copy / relative
        require(source.is_file() and not source.is_symlink(), "Refused redirected package input")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    package.verify(copy, expected_digest)
    require(not (copy / "userdata").exists(), "Evaluator payload must not contain a prior user profile")
    return copy, manifest


def qualify(args) -> dict:
    original, output = args.package.resolve(strict=True), args.output.resolve()
    require(not output.exists() and not output.is_relative_to(original),
            "Evidence must be a new directory outside the extracted package")
    output.mkdir(parents=True)
    report = {"schema": "ultima-launcher-qualification-v1", "status": "failed", "completed": False,
              "platform": sys.platform, "original_package": str(original), "cases": [], "errors": [],
              "expected_manifest_sha256": args.expected_manifest_sha256,
              "tool_sha256": sha(Path(__file__)), "graphical_requested": args.graphical,
              "scope": "Actual shipped .cmd and existing authored-save/reopen fixture; no manual UI or physical GPU acceptance"}
    manifest = None
    copy = None
    try:
        require(sys.platform == "win32", "Windows cmd.exe execution is unavailable on this host; no launcher run performed")
        copy, manifest = prepare_copy(original, output, args.expected_manifest_sha256)
        report.update(source_head=manifest["source_commit"], source_tree=manifest["source_tree"],
                      launcher_sha256=sha(copy / "Open Workbench.cmd"), package_copy=str(copy))
        policy_path = copy / "godot/tests/support/ci_execution_policy.json"
        policy = execution_policy.validate_policy(package.read_json(policy_path),
                                                  os.environ.get(execution_policy.SCALE_ENV, ""))
        report["execution_policy"] = {**policy, "sha256": sha(policy_path)}
        values = policy["watchdogs"]
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith("CYBERSAND_") or key == execution_policy.SCALE_ENV}
        # The batch file must override these disposable paths; no owner profile is exposed.
        outside = output / "unexpected parent userdata"
        for key, suffix in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("XDG_DATA_HOME", "xdg")):
            environment[key] = str(outside / suffix)
        common = ["--headless", "--audio-driver", "Dummy"]
        plan = [("ordinary-headless-startup", common + ["--quit-after", "30"], None, False),
                ("authored-save", common + ["--script", SCRIPT], False, False),
                ("authored-reopen", common + ["--script", SCRIPT], True, False)]
        if args.graphical:
            plan.append(("ordinary-graphical-startup", ["--audio-driver", "Dummy", "--rendering-method",
                         "gl_compatibility", "--resolution", "1366x768", "--quit-after", "120"], None, True))
        authored = None
        for name, flags, reopened, graphical in plan:
            case_directory = output / name
            env = environment.copy()
            if reopened:
                env["CYBERSAND_PAINT_HISTORY_REOPEN"] = "1"
            case_allowance = values["graphical_case_seconds" if graphical else "ordinary_case_seconds"]
            command = command_line(copy / "Open Workbench.cmd", flags, os.environ.get("COMSPEC", "cmd.exe"))
            record = run_process(command, copy, env, case_directory,
                                 values["godot_import_seconds"] + case_allowance,
                                 values["terminate_grace_seconds"], windows=True)
            record.update(name=name, arguments=flags, import_allowance_seconds=values["godot_import_seconds"],
                          case_allowance_seconds=case_allowance, graphical=graphical)
            report["cases"].append(record)
            try:
                record.update(validate_output(record, (case_directory / "stdout.log").read_text(encoding="utf-8", errors="replace"),
                                              manifest["engine"]["version"], reopened=reopened, graphical=graphical))
                require(not outside.exists(), "The shipped launcher leaked into the parent data path")
                if reopened is not None:
                    current = saved_files(copy)
                    record["saved_files"] = current
                    if reopened:
                        require(current == authored, "Fresh-process reopen changed or lost authored file bytes")
                    else:
                        authored = current
                package.verify(copy, args.expected_manifest_sha256)
            except (OSError, ValueError) as error:
                record["status"] = "failed"
                record["validation_error"] = str(error)
                raise
        report.update(status="passed", completed=True)
    except (OSError, ValueError) as error:
        report["errors"].append(str(error))
    finally:
        if manifest is not None:
            for label, folder in (("original", original), ("copy", copy)):
                try:
                    package.verify(folder, args.expected_manifest_sha256)
                    report[label + "_payload_unchanged"] = True
                except (OSError, ValueError) as error:
                    report[label + "_payload_unchanged"] = False
                    report.update(status="failed", completed=False)
                    report["errors"].append(label + " verification: " + str(error))
        write_json(output / "launcher-qualification.json", report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--expected-manifest-sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--graphical", action="store_true",
                        help="Also execute an ordinary compatibility-renderer window; not a manual playtest")
    report = qualify(parser.parse_args())
    print(json.dumps({"status": report["status"], "completed": report["completed"], "errors": report["errors"]}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
