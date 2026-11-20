#!/usr/bin/env python3
"""Execute actual graphical reciprocal authoring and independent-process reopen.

The source checkout and a pristine extracted owner ZIP are separate runs. A
successful child exit alone never passes: completed UI assertions, exact native
material readback, original screenshots and source custody are all required.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

import runtime_custody as custody

VERSION = "4.7.stable.official.5b4e0cb0f"
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|(?m:^ERROR:)|Failed to load script|GDExtension library not found|ObjectDB instances leaked")
CAPTURES = ("native-preview.png", "native-applied.png", "native-undone.png", "native-saved.png", "native-reopened.png")


def package_identity(directory: Path, source: str) -> dict:
    manifest = json.loads((directory / "candidate-manifest.json").read_text(encoding="utf-8"))
    if manifest.get("source_commit") != source or manifest.get("programme") != "GENTEK-SWARM-004" or manifest.get("draft_hold") is not True:
        raise ValueError("Owner package is not the exact experimental source")
    for name, expected in manifest["files_sha256"].items():
        path = (directory / name).resolve()
        if not path.is_relative_to(directory.resolve()) or custody.native.sha(path) != expected:
            raise ValueError("Pristine package hash mismatch: " + name)
    return manifest


def terminate_tree(child: subprocess.Popen) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(child.pid), "/T", "/F"], check=False, capture_output=True, timeout=20)
    else:
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    child.wait(timeout=20)


def execute(name: str, command: list[str], env: dict[str, str], output: Path, timeout: int) -> dict:
    began = time.monotonic()
    log = output / (name + ".log")
    timed_out = False
    with log.open("w", encoding="utf-8") as stream:
        child = subprocess.Popen(command, env=env, cwd=custody.ROOT, stdout=stream,
                                 stderr=subprocess.STDOUT, start_new_session=os.name != "nt")
        try:
            while child.poll() is None:
                if time.monotonic() - began > timeout:
                    timed_out = True
                    terminate_tree(child)
                    break
                time.sleep(0.05)
            code = child.wait(timeout=20)
        finally:
            if child.poll() is None:
                terminate_tree(child)
    text = log.read_text(encoding="utf-8", errors="replace")
    result = {"case": name, "command": command, "process_id": child.pid, "returncode": code,
              "timed_out": timed_out, "wall_seconds": time.monotonic() - began,
              "log_sha256": custody.native.sha(log), "passed": code == 0 and not timed_out and not ERRORS.search(text)}
    (output / (name + "-process.json")).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if not result["passed"]:
        print("\n".join(text.splitlines()[-100:]), file=sys.stderr)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--native-candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seed", type=int, default=605, help="predeclared known authoring seed; never search for a passing seed")
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("This owner acceptance runner requires actual Windows graphical execution")
    project, output, engine = args.project.resolve(), args.output.resolve(), args.godot.resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError("Qualification evidence destination must be empty")
    output.mkdir(parents=True, exist_ok=True)
    receipt = custody.verify(args.native_candidate)
    subprocess.run(["git", "diff", "--exit-code", "HEAD", "--", "godot/scripts", "godot/tests"],
                   cwd=custody.ROOT, check=True, timeout=60)
    script_names = subprocess.check_output(["git", "ls-files", "--", "godot/scripts", "godot/tests"],
                                          cwd=custody.ROOT, text=True, timeout=60).splitlines()
    for name in script_names:
        if Path(name).suffix == ".gd":
            candidate = project / Path(name).relative_to("godot")
            if candidate.read_bytes().replace(b"\r\n", b"\n") != (custody.ROOT / name).read_bytes().replace(b"\r\n", b"\n"):
                raise ValueError("Interactive script differs from the exact source checkout: " + name)
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
    if version != VERSION:
        raise ValueError("Godot pin mismatch: " + version)
    runtime_path = project / "addons/cybersand_native/bin" / ("cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so")
    if os.name == "nt" and custody.native.sha(runtime_path) != receipt["extension_sha256"]:
        raise ValueError("Interactive project does not use the attested native adapter")
    package = package_identity(args.package.resolve(), receipt["source_commit"]) if args.package else None
    if package and custody.native.sha(project / "tools" / custody.CLI) != receipt["files"][custody.CLI]["sha256"]:
        raise ValueError("Packaged reciprocal generator differs from the source-built candidate")
    identity = {"schema": 1, "source_commit": receipt["source_commit"], "source_tree": receipt["source_tree"],
                "platform": sys.platform, "godot_version": version, "godot_sha256": custody.native.sha(engine),
                "native_adapter_sha256": custody.native.sha(runtime_path), "reciprocal": receipt,
                "graphical_required": True, "package": bool(package), "seed": args.seed,
                "scripts_sha256": {path.relative_to(project).as_posix(): custody.native.sha(path)
                                   for path in sorted(project.rglob("*.gd")) if ".godot" not in path.parts}}
    (output / "source-runtime-identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    env = os.environ.copy()
    for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"),
                        ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
        target = output / "profile" / suffix
        target.mkdir(parents=True)
        env[key] = str(target)
    env.update(CYBERSAND_SOURCE_REVISION=receipt["source_commit"], SWARM004_UI_EVIDENCE=str(output),
               SWARM004_UI_SEED=str(args.seed), SWARM004_REQUIRE_GRAPHICS="1")
    for key in ("CYBERSAND_SWARM004_CLI", "CYBERSAND_SWARM004_SOURCE", "CYBERSAND_SWARM004_SHA256"):
        env.pop(key, None)
    if not package:
        env.update(CYBERSAND_SWARM004_CLI=str((args.native_candidate / custody.CLI).resolve()),
                   CYBERSAND_SWARM004_SOURCE=receipt["source_commit"],
                   CYBERSAND_SWARM004_SHA256=receipt["files"][custody.CLI]["sha256"])
    base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    display = ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle"]
    results = [execute("import", [*base, "--headless", "--editor", "--quit"], env, output, 180)]
    reports = []
    if results[-1]["passed"]:
        adapter_env = env.copy()
        adapter_env["WB_AUTHORING_PATCH_REPORT"] = str(output / "native-adapter.json")
        result = execute("native-adapter", [*base, "--headless", "--script", "res://tests/test_workbench_authoring_patch.gd"], adapter_env, output, 180)
        path = output / "native-adapter.json"
        report = json.loads(path.read_text(encoding="utf-8")) if path.is_file() else {}
        result["passed"] = bool(result["passed"] and report.get("completed") is True and report.get("passed") is True
                                and report.get("failures") == [] and report.get("checks", 0) > 0)
        results.append(result)
    if results[-1]["passed"]:
        result = execute("protocol", [*base, "--headless", "--script", "res://tests/test_workbench_reciprocal_protocol.gd"], env, output, 60)
        text = (output / "protocol.log").read_text(encoding="utf-8", errors="replace")
        markers = [json.loads(line.partition("SWARM004_PROTOCOL ")[2]) for line in text.splitlines() if line.startswith("SWARM004_PROTOCOL ")]
        result["passed"] = bool(result["passed"] and len(markers) == 1 and markers[0].get("completed") is True
                                and markers[0].get("failures") == [] and markers[0].get("checks", 0) > 0)
        results.append(result)
    if results[-1]["passed"]:
        result = execute("controller-mechanical", [*base, "--headless", "--script", "res://tests/test_workbench_reciprocal_controller.gd"], env, output, 90)
        text = (output / "controller-mechanical.log").read_text(encoding="utf-8", errors="replace")
        markers = [json.loads(line.partition("SWARM004_CONTROLLER ")[2]) for line in text.splitlines() if line.startswith("SWARM004_CONTROLLER ")]
        result["passed"] = bool(result["passed"] and len(markers) == 1 and markers[0].get("completed") is True
                                and markers[0].get("failures") == [] and markers[0].get("checks", 0) > 0
                                and markers[0].get("reciprocal_acceptance") is False)
        results.append(result)
    if results[-1]["passed"]:
        for mode in ("create", "reopen", "lifecycle"):
            mode_env = env.copy()
            mode_env["SWARM004_UI_MODE"] = mode
            if mode == "lifecycle":
                mode_env.update(CYBERSAND_SWARM004_CLI=str((args.native_candidate / custody.FIXTURE).resolve()),
                                CYBERSAND_SWARM004_SOURCE="lifecycle-fixture-no-assembly",
                                CYBERSAND_SWARM004_SHA256=receipt["files"][custody.FIXTURE]["sha256"])
            result = execute(mode, [*base, *display, "--script", "res://tests/test_workbench_reciprocal_ui.gd"], mode_env, output, 180)
            report_path = output / (mode + ".json")
            report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.is_file() else {}
            result["passed"] = bool(result["passed"] and report.get("completed") is True and report.get("failures") == []
                                    and report.get("checks", 0) > 0 and report.get("mode") == mode
                                    and report.get("display") not in (None, "headless"))
            if mode == "create":
                result["passed"] = bool(result["passed"] and report.get("native_receipt", {}).get("changed_cells", 0) > 0
                                        and report.get("native_status") == "complete")
            results.append(result)
            reports.append(report)
            if not result["passed"]:
                break
    complete = len(reports) == 3 and all(result["passed"] for result in results)
    if complete:
        complete = reports[0]["process_id"] != reports[1]["process_id"]
    screenshots = {}
    for name in CAPTURES:
        path = output / name
        if path.is_file() and path.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n":
            screenshots[name] = custody.native.sha(path)
    complete = complete and len(screenshots) == len(CAPTURES)
    plane = output / "expected-native.le16"
    complete = complete and plane.is_file() and plane.stat().st_size == 512 * 512 * 2
    summary = {"schema": 1, "source_commit": receipt["source_commit"], "platform": sys.platform,
               "graphical": True, "package": bool(package), "passed": bool(complete),
               "graphical_scope": "actual Main create/reopen/lifecycle; separate mechanical, transport and native adapter fixtures run headless",
               "windows_owner_authoring_acceptance": bool(complete),
               "reciprocal_programme_acceptance": False,
               "example_scope": "known605 centred FRAME territory, viaduct-like, rounds2, clear border4, decoration0.15; zero-joint transaction example",
               "native_plane_sha256": custody.native.sha(plane) if plane.is_file() else None,
               "screenshots_sha256": screenshots, "results": results}
    (output / "qualification.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: summary[key] for key in ("source_commit", "platform", "graphical", "package", "passed", "windows_owner_authoring_acceptance")}))
    return 0 if complete else 1


if __name__ == "__main__":
    raise SystemExit(main())
