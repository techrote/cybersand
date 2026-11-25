#!/usr/bin/env python3
"""Observe Windows startup phases without changing the pinned application.

This is separate diagnostic apparatus. It does not qualify a portable package,
alter production scheduling or contact a provider. Every process/profile/cache
state and exact source/runtime identity is retained, including failed attempts.
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
import time

from run_art_collaborative_gates import source_identity

ROOT = Path(__file__).resolve().parents[2]
APP = "bcc92927ce3894a16d5544923cfbf7b1d0339fda"
APP_TREE = "517164084860a19f18b36cb94f77597eb3220578"
FIXTURE = "tools/fixtures/art_startup_phase_probe.gd"
APPARATUS = {
    FIXTURE,
    "tools/ci/run_art_startup_phase_probe.py",
    "docs/audits/2026-11-25-art-startup-phase-probe/windows-bcc.md",
    ".github/workflows/art-startup-phase-windows.yml",
}
ENGINES = {
    "Godot_v4.7-stable_win64_console.exe": "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
    "Godot_v4.7-stable_win64.exe": "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8",
}
RUNTIMES = (
    "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
    "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
)


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=60).strip()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def identity(diagnostic: Path) -> dict:
    source = source_identity(diagnostic)
    if git("rev-parse", APP + "^{tree}") != APP_TREE:
        raise ValueError("Application tree pin differs")
    delta = set(git("diff", "--name-only", APP, "HEAD").splitlines())
    if delta != APPARATUS:
        raise ValueError("Only the four declared diagnostic files may differ: " + repr(sorted(delta)))
    runtime = {}
    for name in RUNTIMES:
        pointer = git("show", APP + ":" + name)
        match = re.search(r"oid sha256:([0-9a-f]{64})", pointer)
        path = ROOT / name
        if not match or path.is_symlink() or sha(path) != match[1]:
            raise ValueError("Runtime does not match application source: " + name)
        runtime[name] = match[1]
    return {**source, "application_source": APP, "application_tree": APP_TREE,
            "runtime_sha256": runtime,
            "apparatus_sha256": {name: sha(ROOT / name) for name in sorted(APPARATUS)}}


def cache() -> dict:
    base = ROOT / "godot/.godot"
    return {p.relative_to(base).as_posix(): {"bytes": p.stat().st_size, "sha256": sha(p)}
            for p in sorted(base.rglob("*")) if p.is_file()}


def profile_cache(profile: Path) -> dict:
    return {p.relative_to(profile).as_posix(): {"bytes": p.stat().st_size, "sha256": sha(p)}
            for p in sorted(profile.rglob("*")) if p.is_file() and "shader_cache" in p.parts}


def host() -> dict:
    value = {"platform": platform.platform(), "logical_cpus": os.cpu_count(),
             "processor_identifier": os.environ.get("PROCESSOR_IDENTIFIER", "unavailable"),
             "runner_image_os": os.environ.get("ImageOS", "unavailable"),
             "runner_image_version": os.environ.get("ImageVersion", "unavailable")}
    command = ("$v = @{cpu=@(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors);"
               "memory=@(Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory);"
               "video=@(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM)};"
               "$v | ConvertTo-Json -Depth 5 -Compress")
    try:
        value["hardware"] = json.loads(subprocess.check_output(
            ["pwsh", "-NoProfile", "-Command", command], text=True, timeout=30))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        value["hardware_error"] = type(error).__name__
    return value


def run_process(command: list[str], env: dict, log: Path, timeout: int) -> dict:
    began = time.monotonic()
    timed_out = False
    with log.open("wb") as output:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            # Only this owned console process and its actual Godot child tree.
            killed = subprocess.run(["taskkill.exe", "/PID", str(process.pid), "/T", "/F"],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
            (log.parent / (log.stem + "-timeout-cleanup.log")).write_bytes(killed.stdout)
            process.wait(timeout=30)
            code = process.returncode
    return {"returncode": code, "timeout": timed_out, "wall_seconds": time.monotonic() - began,
            "log_sha256": sha(log), "command": command}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--import-before", action="store_true")
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--profile-from", type=Path,
                        help="Reuse only a passed sibling arm's owned diagnostic profile")
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("This apparatus requires actual Windows execution")
    output, godot = args.output.resolve(), args.godot.resolve()
    if output.exists() or godot.name != "Godot_v4.7-stable_win64_console.exe":
        parser.error("Use a fresh output and the pinned console executable")
    for name, expected in ENGINES.items():
        if sha(godot.parent / name) != expected:
            parser.error("Pinned Godot payload differs: " + name)
    output.mkdir(parents=True)
    source = identity(output / "source-admission-failure.json")
    if args.profile_from:
        previous = args.profile_from.resolve()
        prior = json.loads((previous / "result.json").read_text(encoding="utf-8"))
        if previous.parent != output.parent or not prior.get("passed") or prior.get("source") != source:
            raise ValueError("Profile reuse requires a passed same-source sibling diagnostic arm")
        profile = previous / "profile"
        if not profile.is_dir() or profile.is_symlink():
            raise ValueError("Owned prior profile is unavailable")
    else:
        profile = output / "profile"
        profile.mkdir()
    env = dict(os.environ, XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile),
               APPDATA=str(profile), LOCALAPPDATA=str(profile / "local"),
               CYBERSAND_SOURCE_REVISION=source["commit"], ART_STARTUP_PHASE_OUTPUT=str(output / "phases.json"))
    inputs = {"schema": "art-windows-startup-inputs-v1", "source": source, "label": args.label,
              "fresh_profile": not bool(args.profile_from), "profile_from": str(args.profile_from or ""),
              "profile_shader_cache_before": profile_cache(profile), "explicit_import_before": args.import_before,
              "graphical": args.graphical, "cache_before": cache(), "host_before": host(),
              "engine_payloads": ENGINES,
              "os_page_cache": "Not cleared or controlled; this is not an OS-cold claim."}
    write(output / "inputs.json", inputs)
    result = {"schema": "art-windows-startup-result-v1", "source": source,
              "label": args.label, "passed": False, "model_calls": 0}
    try:
        if args.import_before:
            result["import"] = run_process(
                [str(godot), "--headless", "--audio-driver", "Dummy", "--path", str(ROOT / "godot"), "--editor", "--import"],
                env, output / "import.log", 240)
            if result["import"]["returncode"] != 0 or result["import"]["timeout"]:
                raise ValueError("Explicit import did not complete")
        result["cache_before_runtime"] = cache()
        command = [str(godot), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                   "--path", str(ROOT / "godot"), "--script", str(ROOT / FIXTURE)]
        if args.graphical:
            command += ["--rendering-driver", "opengl3_angle"]
        else:
            command.insert(1, "--headless")
        result["process"] = run_process(command, env, output / "process.log", 240)
        log = (output / "process.log").read_text(encoding="utf-8", errors="replace")
        rows = [line.removeprefix("ART_STARTUP_PHASE_RESULT ") for line in log.splitlines()
                if line.startswith("ART_STARTUP_PHASE_RESULT ")]
        if len(rows) == 1:
            result["fixture"] = json.loads(rows[0])
        value = result.get("fixture", {})
        result["passed"] = (result["process"]["returncode"] == 0 and not result["process"]["timeout"]
                            and len(rows) == 1 and value.get("checks", 0) >= 27
                            and value.get("failures") == [] and value.get("model_calls") == 0
                            and value.get("provider_requests") == 0 and len(value.get("captures", [])) == 3
                            and value.get("application_source") == APP and value.get("source_revision") == source["commit"]
                            and value.get("platform") == "Windows"
                            and not any(token in log for token in ("ERROR:", "Parse Error:", "Failed to load script")))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        result["error"] = str(error)
    result.update(cache_after=cache(), profile_shader_cache_after=profile_cache(profile), host_after=host())
    result["source_after"] = identity(output / "source-after-failure.json")
    result["source_unchanged"] = result["source_after"] == source
    result["passed"] = result["passed"] and result["source_unchanged"]
    write(output / "result.json", result)
    print(json.dumps({"passed": result["passed"], "label": args.label,
                      "checks": result.get("fixture", {}).get("checks"),
                      "phases": result.get("fixture", {}).get("phases"), "source": source["commit"]}))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
