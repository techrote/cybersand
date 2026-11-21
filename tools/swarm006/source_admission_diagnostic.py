#!/usr/bin/env python3
"""Frozen SWARM006 Windows source-mutation diagnostic; NEVER owner qualification.

Lives outside the frozen subject checkout. Retains every source admission delta
without cleaning, restoring, exempting paths, or changing any qualification rule.
Stops at the first effective source delta or failed child. No package publication.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

SOURCE = "8cf93e48bc23370c6ef7b835978689ca3aa3e9f8"
TREE = "5044696ce46cd16623a6b12c08b13c15d1fd28c2"
CLI_SHA = "9ae1e49f04e57ed6a42b29a9d811b192f4f66d4aa6fd47d1daedbe48754b007c"
DLL_SHA = "e43502cd39a9ae705bd2e4dfe3a8432f2f41d1124412b8519a634ec6bf40bcb0"
RAPIER_SHA = "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"
VERSION = "4.7.stable.official.5b4e0cb0f"
MAX_PATHS = 4096
MAX_SMALL_TEXT = 128 * 1024
MAX_RETAINED_TEXT = 4 * 1024 * 1024
MAX_LOG_BYTES = 16 * 1024 * 1024
MAX_STAGE_SECONDS = 600


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def save(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=root, timeout=30)


def changes(raw: bytes) -> list[dict]:
    """Parse porcelain-v1 -z without losing spaces, quoting or rename sources."""
    parts = raw.split(b"\0")
    result = []
    index = 0
    while index < len(parts) and parts[index]:
        entry = parts[index]
        index += 1
        if len(entry) < 4 or entry[2:3] != b" ":
            raise ValueError("Malformed Git porcelain record")
        record = {"status": entry[:2].decode("ascii"), "path": entry[3:].decode("utf-8", "surrogateescape")}
        if b"R" in entry[:2] or b"C" in entry[:2]:
            if index >= len(parts) or not parts[index]:
                raise ValueError("Incomplete Git rename record")
            record["original_path"] = parts[index].decode("utf-8", "surrogateescape")
            index += 1
        result.append(record)
    if len(result) > MAX_PATHS:
        raise ValueError("Diagnostic changed-path capacity exceeded")
    return result


def snapshot(root: Path, output: Path, stage: str, preserve) -> dict:
    directory = output / "snapshots" / stage
    directory.mkdir(parents=True)
    full = git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all")
    (directory / "git-status.porcelain-v1-z").write_bytes(full)
    status_text = git(root, "status", "--porcelain=v1", "--untracked-files=all").decode("utf-8", "replace")
    (directory / "git-status.txt").write_text(status_text, encoding="utf-8")
    effective = preserve.source_delta(preserve.SOURCE_PATHS)
    (directory / "effective-source-delta.txt").write_text(effective + "\n", encoding="utf-8")
    rows = changes(full)
    retained = 0
    for row in rows:
        relative = Path(row["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("Unsafe Git status path")
        path = root / relative
        if path.is_symlink():
            row["symlink"] = os.readlink(path)
        elif path.is_file():
            row.update(bytes=path.stat().st_size, sha256=digest(path))
            if path.stat().st_size <= MAX_SMALL_TEXT:
                data = path.read_bytes()
                try:
                    data.decode("utf-8")
                    text = b"\0" not in data
                except UnicodeDecodeError:
                    text = False
                if text and retained + len(data) <= MAX_RETAINED_TEXT:
                    target = directory / "working-text" / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(data)
                    row["retained_working_text"] = target.relative_to(output).as_posix()
                    retained += len(data)
        else:
            row["missing_or_not_regular_file"] = True
        if row["status"] != "??":
            original = row.get("original_path", row["path"])
            blob = subprocess.run(["git", "show", "HEAD:" + original], cwd=root,
                                  capture_output=True, timeout=15)
            if blob.returncode == 0:
                row["git_blob_sha256"] = hashlib.sha256(blob.stdout).hexdigest()
                if len(blob.stdout) <= MAX_SMALL_TEXT and b"\0" not in blob.stdout and retained + len(blob.stdout) <= MAX_RETAINED_TEXT:
                    target = directory / "committed-small-files" / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(blob.stdout)
                    row["retained_committed_small_file"] = target.relative_to(output).as_posix()
                    retained += len(blob.stdout)
    inventory_error = None
    try:
        tracked_inputs = preserve.source_inputs()
    except Exception as error:
        # A tracked deletion must remain an observed dirty state, with its raw
        # status and path evidence, even when the frozen inventory cannot hash it.
        tracked_inputs = None
        inventory_error = type(error).__name__ + ": " + str(error)
    result = {"stage": stage, "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "source": git(root, "rev-parse", "HEAD").decode().strip(),
              "tree": git(root, "rev-parse", "HEAD^{tree}").decode().strip(),
              "effective_source_delta": effective, "full_git_status": status_text,
              "changed_paths": rows, "tracked_source_inputs": tracked_inputs,
              "source_input_inventory_error": inventory_error,
              "small_file_bytes_retained": retained,
              "source_guard_is_unmodified_frozen_helper": True}
    save(directory / "snapshot.json", result)
    print(json.dumps({"stage": stage, "effective_source_delta": effective,
                      "full_status_records": len(rows)}), flush=True)
    return result


def execute_diagnostic(name, command, environment, output, work, timeout, root, graphics):
    """Bound diagnostic log retention; reuse frozen owned-tree termination only."""
    output.mkdir(parents=True)
    raw_log = work / (name + ".log")
    began = time.monotonic()
    timed_out = False
    log_limit_reached = False
    with raw_log.open("xb") as stream:
        child = subprocess.Popen(command, env=environment, cwd=root,
                                 stdout=stream, stderr=subprocess.STDOUT,
                                 start_new_session=os.name != "nt")
        try:
            while child.poll() is None:
                timed_out = time.monotonic() - began > timeout
                log_limit_reached = raw_log.stat().st_size > MAX_LOG_BYTES
                if timed_out or log_limit_reached:
                    graphics.terminate_tree(child)
                    break
                time.sleep(0.05)
            code = child.wait(timeout=20)
        finally:
            if child.poll() is None:
                graphics.terminate_tree(child)
    raw_size = raw_log.stat().st_size
    truncated = raw_size > MAX_LOG_BYTES
    with raw_log.open("rb") as stream:
        if truncated:
            marker = b"\n[DIAGNOSTIC LOG CAP: MIDDLE OMITTED; THIS STAGE FAILS]\n"
            side = (MAX_LOG_BYTES - len(marker)) // 2
            retained = stream.read(side) + marker
            stream.seek(-side, os.SEEK_END)
            retained += stream.read(side)
        else:
            retained = stream.read(MAX_LOG_BYTES)
    log = output / (name + ".log")
    log.write_bytes(retained)
    result = {"case": name, "command": command, "process_id": child.pid,
              "returncode": code, "timed_out": timed_out,
              "log_limit_reached": log_limit_reached or truncated,
              "wall_seconds": time.monotonic() - began,
              "original_log_bytes": raw_size, "original_log_sha256": digest(raw_log),
              "log_sha256": digest(log), "log_bytes_retained": len(retained),
              "log_truncated": truncated,
              "passed": code == 0 and not timed_out and not (log_limit_reached or truncated)
                        and not graphics.ERRORS.search(retained.decode("utf-8", "replace"))}
    save(output / (name + "-process.json"), result)
    print(json.dumps({key: result[key] for key in ("case", "returncode", "timed_out", "log_truncated", "passed")}), flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    args = parser.parse_args()
    root, runtime, engine, output, work = (p.resolve() for p in (args.root, args.runtime, args.godot, args.output, args.work))
    if os.name != "nt":
        parser.error("Diagnostic requires the genuine Windows runner")
    if output.exists() or work.exists() or root == output or root in output.parents or root in work.parents:
        raise ValueError("Diagnostic output/work must be fresh and outside the frozen checkout")
    output.mkdir(parents=True)
    work.mkdir(parents=True)
    report = {"diagnostic_only": True, "owner_qualification": False, "draft_hold": True,
              "expected_source": SOURCE, "expected_tree": TREE,
              "driver_sha256": digest(Path(__file__)), "driver_commit": os.environ.get("GITHUB_SHA"),
              "subject": str(root), "commands": [], "snapshots": [], "errors": [],
              "first_dirty_stage": None, "diagnostic_complete": False}
    began = time.monotonic()
    try:
        if git(root, "rev-parse", "HEAD").decode().strip() != SOURCE or git(root, "rev-parse", "HEAD^{tree}").decode().strip() != TREE:
            raise ValueError("Frozen diagnostic subject mismatch")
        sys.path.insert(0, str(root / "tools/swarm006"))
        import runtime_custody as custody
        import qualify_preserved_workbench as preserve
        import qualify_workbench as graphics
        receipt = custody.verify(runtime, root)
        if receipt["files"][custody.CLI]["sha256"] != CLI_SHA or receipt["extension_sha256"] != DLL_SHA:
            raise ValueError("Wrong archived diagnostic runtime")
        rapier = root / "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
        if digest(rapier) != RAPIER_SHA:
            raise ValueError("Rapier pin mismatch")
        if subprocess.check_output([str(engine), "--version"], text=True, timeout=20).strip() != VERSION:
            raise ValueError("Godot pin mismatch")
        report["runtime"] = {"receipt": receipt, "engine_sha256": digest(engine), "rapier_sha256": digest(rapier),
                             "preservation_helper_sha256": digest(root / "tools/swarm006/qualify_preserved_workbench.py")}
        def observe(stage):
            result = snapshot(root, output, stage, preserve)
            report["snapshots"].append(stage)
            if result["effective_source_delta"]:
                report["first_dirty_stage"] = stage
                report["diagnostic_complete"] = True
                return False
            if result["source_input_inventory_error"]:
                report["errors"].append("Source inventory error at " + stage + ": " + result["source_input_inventory_error"])
                report["diagnostic_complete"] = True
                return False
            return True
        if not observe("00-checkout-before-runtime-install"):
            return 1
        destination = root / custody.native.NATIVE
        shutil.copyfile(runtime / destination.name, destination)
        if digest(destination) != DLL_SHA:
            raise ValueError("Installed diagnostic DLL mismatch")
        if not observe("01-runtime-installed-before-import"):
            return 1
        env = os.environ.copy()
        env.update(CYBERSAND_SWARM004_CLI=str(runtime / custody.CLI), CYBERSAND_SWARM004_SOURCE=SOURCE,
                   CYBERSAND_SWARM004_SHA256=CLI_SHA, CYBERSAND_SOURCE_REVISION=SOURCE)
        base = [str(engine), "--audio-driver", "Dummy", "--path", str(root / "godot")]
        common = graphics.isolated_environment(env, work / "headless", "transaction")
        stages = [
            ("02-editor-import", [*base, "--headless", "--editor", "--quit"], common, 90),
            ("03-native-adapter", [*base, "--headless", "--script", "res://tests/test_workbench_authoring_patch.gd"],
             dict(common, WB_AUTHORING_PATCH_REPORT=str(work / "native-adapter.json")), 60),
            ("04-protocol", [*base, "--headless", "--script", "res://tests/test_workbench_reciprocal_protocol.gd"], common, 45),
            ("05-controller", [*base, "--headless", "--script", "res://tests/test_workbench_reciprocal_controller.gd"], common, 60),
            ("06-controls", [*base, "--headless", "--script", "res://tests/test_workbench_reciprocal_controls.gd"], common, 90),
            ("07-one-source-graphical-create", [*base, "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle",
             "--script", "res://tests/test_workbench_swarm006_ui.gd"],
             dict(graphics.isolated_environment(env, work / "one-graphical-case", "transaction"), SWARM004_UI_MODE="create"), 180),
        ]
        for name, command, environment, timeout in stages:
            remaining = MAX_STAGE_SECONDS - int(time.monotonic() - began)
            if remaining < 20:
                raise TimeoutError("Diagnostic total stage budget reached")
            stage_output = output / "stages" / name
            report["commands"].append({"case": name, "command": command, "started": True})
            try:
                result = execute_diagnostic(name, command, environment, stage_output, work,
                                            min(timeout, remaining), root, graphics)
            except Exception as error:
                report["commands"][-1]["error"] = type(error).__name__ + ": " + str(error)
                observe(name + "-after-exception")
                raise
            report["commands"].pop()
            report["commands"].append(result)
            clean = observe(name + "-after")
            if not clean or not result["passed"]:
                if not result["passed"]:
                    report["errors"].append("Child failure at " + name)
                break
        report["diagnostic_complete"] = True
        return int(bool(report["first_dirty_stage"] or report["errors"]))
    except Exception as error:
        report["errors"].append(type(error).__name__ + ": " + str(error))
        raise
    finally:
        report["elapsed_seconds"] = time.monotonic() - began
        save(output / "diagnostic-result.json", report)
        print(json.dumps({k: report[k] for k in ("diagnostic_only", "owner_qualification", "first_dirty_stage", "errors", "diagnostic_complete")}), flush=True)


if __name__ == "__main__":
    sys.exit(main())
