#!/usr/bin/env python3
"""Actual Shared Workbench: two advanced five-style editable projects and maps.

Author/reopen use distinct Godot processes and a shared isolated user profile.
Hosted Windows/ANGLE does NOT qualify physical Windows 11/NVIDIA acceptance.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import subprocess

import qualify

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "res://tools/qualify_gentek80_compositions.gd"
SHARES = [[30.0, 25.0, 20.0, 15.0, 10.0], [20.0] * 5]
COMPOSITIONS = [
    ["cathedral_megaframe", "seeded_typology_megablock", "megatruss_station",
     "interlaced_viaduct", "suspended_arcology"],
    ["metabolist_spine", "rosework_gatehouse", "interlock_brutalism",
     "cathedral_megaframe", "megatruss_station"],
]


def validate(phase: dict, label: str) -> dict[str, tuple]:
    if phase.get("schema") != "gentek80-five-showcase-workbench-v1" or phase.get("phase") != label:
        raise ValueError("Wrong composition receipt schema/phase")
    if phase.get("complete") is not True or phase.get("failures") != 0 or phase.get("projects") != 2:
        raise ValueError("Both compositions were not completed")
    cases = [case for case in phase.get("cases", []) if case.get("case") == f"five-showcase-{label}"]
    if len(cases) != 2:
        raise ValueError("Two original composition receipts missing")
    identity = {}
    for i, case in enumerate(cases):
        if case.get("modules") != COMPOSITIONS[i] or case.get("active_slots") != 5:
            raise ValueError("Not five exact active showcase modules")
        if case.get("shares") != SHARES[i]:
            raise ValueError("Equal/unequal requested shares not restored exactly")
        controls = case.get("configurations", [])
        if len(controls) != 5:
            raise ValueError("Five style geometry/material/aperture/deterioration receipts missing")
        edited = controls[0] if i == 0 else controls[2]
        if i == 0 and not (
            int(edited["geometry"]["room_size"]) == 88
            and int(edited["geometry"]["floor_height"]) == 112
            and edited["materials"] == {"wall": 130, "floor": 114, "window": 120}
            and edited["apertures"]["automatic_doors"] is True
            and edited["apertures"]["automatic_windows"] is True
            and float(edited["deterioration"]) == 0.05
        ):
            raise ValueError("First showcase lacks nondefault geometry/material and deterioration")
        if i == 1 and not (
            int(edited["geometry"]["floor_height"]) == 80
            and int(edited["materials"]["wall"]) == 58
            and edited["apertures"]["automatic_doors"] is False
            and edited["apertures"]["automatic_windows"] is False
            and float(edited["deterioration"]) == 0.1
        ):
            raise ValueError("Second showcase lacks nondefault apertures/material/deterioration")
        if case.get("display") == "headless" or case.get("native_receipts", 0) < 1:
            raise ValueError("Native/graphical evidence is absent")
        if i == 1 and not all(float(x) < 0 for x in case.get("origin", [])):
            raise ValueError("Negative-origin second project missing")
        name = case["name"]
        if name in identity or case.get("named_map") != name or not case.get("editable_project"):
            raise ValueError("Duplicate/missing named maps or editable projects")
        identity[name] = tuple(case[k] for k in ("project_file_sha256", "project_sha256",
                                                "source_sha256", "recipe_sha256"))
    if len(identity) != 2 or len(set(identity.values())) != 2:
        raise ValueError("Two source/project/material identities not distinct")
    return identity


def inventory_packaged_godot(engine: Path) -> dict:
    """Non-invasive process-path inventory for both Godot binaries.

    Windows PowerShell 5.1 does not reliably accept trailing script arguments
    after -Command. Encode each exact path separately as UTF-8/base64 and
    decode within the script. Only inspect matching ExecutablePath: never kill.
    """
    if os.name != "nt":
        return {"supported": False, "reason": "Windows pathname process check not applicable"}
    paths = [str(engine), str(engine.with_name(engine.name.replace("_console.exe", ".exe")))]
    console_encoded, gui_encoded = [
        base64.b64encode(path.encode("utf-8")).decode("ascii") for path in paths
    ]
    script = (
        "$ErrorActionPreference='Stop';"
        "$console=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" + console_encoded + "'));"
        "$gui=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" + gui_encoded + "'));"
        "$targets=@($console,$gui);"
        "if($targets.Count -ne 2 -or !$console -or !$gui){throw 'Two Godot paths required'};"
        "$ids=@(Get-CimInstance Win32_Process | Where-Object "
        "{ $_.ExecutablePath -and ($targets -contains $_.ExecutablePath) }"
        " | ForEach-Object { $_.ProcessId });"
        "[PSCustomObject]@{paths=$targets;pids=$ids} | ConvertTo-Json -Compress -Depth 4"
    )
    result = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive",
                             "-Command", script], capture_output=True, text=True, timeout=90)
    if result.returncode:
        return {"supported": False, "error": result.stderr.strip(), "exit": result.returncode}
    try:
        value = json.loads(result.stdout.strip())
        if not isinstance(value, dict) or not isinstance(value.get("pids"), list):
            raise ValueError("Process inventory must contain a list of PIDs")
        return {"supported": True, "pids": value["pids"], "paths": value.get("paths"),
                "checked_console_and_gui": True}
    except (ValueError, json.JSONDecodeError) as exc:
        return {"supported": False, "error": str(exc), "stdout": result.stdout.strip()}



def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--package", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--timeout", type=int, default=1800)
    args = parser.parse_args()
    engine, project, output = args.godot.resolve(), args.project.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
    if version != qualify.VERSION:
        raise ValueError("Wrong Godot version: " + version)
    before = qualify.source_identity(project)
    if args.package:
        package = args.package.resolve()
        manifest = json.loads((package / "candidate-manifest.json").read_text(encoding="utf8"))
        if manifest["source_commit"] != before["source_commit"] or manifest["native_sha256"] != before["runtime_sha256"]:
            raise ValueError("Package source/native identity mismatch")
        for name, digest in manifest["files_sha256"].items():
            if qualify.sha(package / name) != digest:
                raise ValueError("Changed packaged component: " + name)
    env = os.environ.copy()
    for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                        ("XDG_CACHE_HOME", "cache"), ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
        directory = output / "profile" / suffix
        directory.mkdir(parents=True, exist_ok=True)
        env[key] = str(directory)
    env.update({"CYBERSAND_SOURCE_REVISION": before["source_commit"],
                "CYBERSAND_ARCHITECTURE_OUTPUT": str(output),
                "CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS": "1" if args.graphical else "0"})
    command = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    results = [qualify.run("import", [*command, "--headless", "--editor", "--quit"], env, output, args.timeout)]
    phases = {}
    process_boundaries = []
    if results[0]["passed"]:
        for phase in ("author", "reopen"):
            pre = inventory_packaged_godot(engine)
            process_boundaries.append({"phase": phase, "when": "before", **pre})
            if os.name == "nt" and (not pre.get("supported") or pre.get("pids")):
                results.append({"case": f"{phase}-preexisting-process", "passed": False,
                                "inventory": pre})
                break
            env["CYBERSAND_GENTEK80_COMPOSITION_PHASE"] = phase
            display = ["--headless"]
            if args.graphical:
                display = ["--rendering-method", "gl_compatibility"] + (
                    ["--rendering-driver", "opengl3_angle"] if os.name == "nt" else ["--display-driver", "x11"])
            result = qualify.run(phase, [*command, *display, "--script", SCRIPT], env, output, args.timeout,
                                 rf"GENTEK80_FIVE_SHOWCASE phase={phase} projects=2 checks=[1-9][0-9]* failures=0 complete=true")
            receipt = output / f"gentek80-five-showcase-{phase}.json"
            if receipt.is_file():
                phases[phase] = json.loads(receipt.read_text(encoding="utf8"))
            results.append(result)
            post = inventory_packaged_godot(engine)
            process_boundaries.append({"phase": phase, "when": "after", **post})
            if os.name == "nt" and (not post.get("supported") or post.get("pids")):
                results.append({"case": f"{phase}-surviving-process", "passed": False,
                                "inventory": post})
                break
            if not result["passed"]:
                break
    comparable = separate = False
    contract_errors = []
    try:
        authored = validate(phases["author"], "author")
        reopened = validate(phases["reopen"], "reopen")
        comparable = authored == reopened
        separate = phases["author"]["process_id"] != phases["reopen"]["process_id"]
        if not comparable:
            contract_errors.append("Editable project, native recipe, or material changed on fresh-process reopen")
        if not separate:
            contract_errors.append("Author and reopen did not use distinct OS process identifiers")
    except (KeyError, TypeError, ValueError) as exc:
        contract_errors.append(str(exc))
    stable = before == qualify.source_identity(project)
    if not stable:
        contract_errors.append("Source/runtime modified during qualification")
    frames = sorted(output.glob("*.png"))
    if args.graphical and len(frames) < 4:
        contract_errors.append("Missing original author/reopen graphical frames")
    passed = all(row["passed"] for row in results) and comparable and separate and stable and not contract_errors
    receipt = {"schema": "gentek80-five-showcase-source-exact-v1", "passed": passed,
               "source_commit": before["source_commit"], "source_tree": before["source_tree"],
               "runtime_sha256": before["runtime_sha256"], "graphical": args.graphical,
               "independent_processes": separate, "matching_engine_process_boundaries": process_boundaries, "matched_project_material_recipe": comparable,
               "original_frames": [{"name": p.name, "sha256": qualify.sha(p)} for p in frames],
               "results": results, "contract_errors": contract_errors, **phases}
    (output / "qualification.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf8")
    print(json.dumps({"passed": passed, "distinct_five_style_compositions": comparable,
                      "independent_processes": separate, "original_frames": len(frames)}), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
