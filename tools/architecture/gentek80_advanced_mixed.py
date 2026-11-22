#!/usr/bin/env python3
"""Qualify two real five-advanced-Gentek Workbench compositions and fresh-process persistence.

This is a supplemental acceptance test, never a production feature or substitute
for owner Windows 11/NVIDIA judgments. Uses the actual Godot project, registered
native generator, Shared Workbench and native material host.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

import qualify

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "res://tools/qualify_gentek80_advanced_mixed.gd"
LABELS = ("gentek-advanced-five-a", "gentek-advanced-five-b-negative-origin")
MODULES = (
    ("cathedral_megaframe", "megatruss_station", "seeded_typology_megablock", "interlaced_viaduct", "suspended_arcology"),
    ("metabolist_spine", "rosework_gatehouse", "interlock_brutalism", "cathedral_megaframe", "megatruss_station"),
)
MARKER = r"ARCHITECTURE_RESULTS phase=multistyle-(?:author|reopen) checks=[1-9][0-9]* failures=0 complete=true"


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(2 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def processes_using_engine(exe: Path) -> dict:
    """Windows process-path inspection; never kill or change unrelated processes."""
    if os.name != "nt":
        return {"supported": False, "reason": "Windows process-path inspection unavailable"}
    script = (
        "$e=[IO.Path]::GetFullPath($args[0]);"
        "$p=@(Get-CimInstance Win32_Process | Where-Object "
        "{ $_.ExecutablePath -and [string]::Equals($_.ExecutablePath,$e,"
        "[StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { $_.ProcessId });"
        "ConvertTo-Json -Compress -InputObject $p"
    )
    run = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive",
                          "-Command", script, str(exe)], text=True,
                         capture_output=True, timeout=90)
    if run.returncode:
        return {"supported": False, "error": run.stderr.strip()}
    try:
        return {"supported": True, "pids": json.loads(run.stdout.strip())}
    except (json.JSONDecodeError, ValueError) as exc:
        return {"supported": False, "error": str(exc), "stdout": run.stdout.strip()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--timeout", type=int, default=2700)
    args = parser.parse_args()
    output, project, engine = args.output.resolve(), args.project.resolve(), args.godot.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip() != qualify.VERSION:
        raise RuntimeError("Bundled Godot version not pinned to Godot 4.7")
    if not (project / "tools/qualify_gentek80_advanced_mixed.gd").is_file():
        raise RuntimeError("Mixed qualification script absent from the executed project")
    initial = qualify.source_identity(project)
    package_identity = None
    if args.package:
        package = args.package.resolve()
        manifest = json.loads((package / "candidate-manifest.json").read_text(encoding="utf8"))
        if manifest.get("source_commit") != initial["source_commit"] or manifest.get("native_sha256") != initial["runtime_sha256"]:
            raise RuntimeError("Delivered package source/native does not match executed Godot")
        for relative, expected in manifest["files_sha256"].items():
            if sha(package / relative) != expected:
                raise RuntimeError("Delivered package file tampered: " + relative)
        package_identity = {"path": str(package), "manifest_sha256": sha(package / "candidate-manifest.json"),
                            "payload_files": len(manifest["files_sha256"])}
    env = os.environ.copy()
    for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                        ("XDG_CACHE_HOME", "cache"), ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
        p = output / "profile" / suffix
        p.mkdir(parents=True, exist_ok=True)
        env[key] = str(p)
    env.update(CYBERSAND_SOURCE_REVISION=initial["source_commit"],
               CYBERSAND_ARCHITECTURE_OUTPUT=str(output),
               CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS="1" if args.graphical else "0")
    display = ["--headless"]
    if args.graphical:
        display = ["--rendering-method", "gl_compatibility"]
        display += (["--rendering-driver", "opengl3_angle"] if os.name == "nt"
                    else ["--display-driver", "x11"])
    base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    results = [qualify.run("import", [*base, "--headless", "--editor", "--quit"], env, output, args.timeout)]
    phases: dict[str, dict] = {}
    process_checks: list[dict] = []
    if results[0]["passed"]:
        for phase in ("author", "reopen"):
            environment_phase = f"multistyle-{phase}"
            before = processes_using_engine(engine)
            process_checks.append({"phase": environment_phase, "boundary": "before", **before})
            if before.get("supported") and before.get("pids"):
                raise RuntimeError("Packaged engine process already running at fresh-process boundary")
            env["CYBERSAND_ARCHITECTURE_PHASE"] = environment_phase
            r = qualify.run(environment_phase, [*base, *display, "--script", SCRIPT],
                            env, output, args.timeout, MARKER)
            phases[phase] = json.loads((output / f"architecture-{environment_phase}.json").read_text(encoding="utf8")) if (
                output / f"architecture-{environment_phase}.json").is_file() else {}
            record = phases[phase]
            actual = [row for row in record.get("cases", []) if row.get("case") == f"advanced-five-{phase}"]
            r["passed"] = r["passed"] and record.get("failures") == 0 and len(actual) == 2
            r["scenario_identity"] = {
                row["scenario"]: {key: row[key] for key in ("source_sha256", "recipe_sha256", "process_id")}
                for row in actual
            }
            results.append(r)
            after = processes_using_engine(engine)
            process_checks.append({"phase": environment_phase, "boundary": "after", **after})
            if after.get("supported") and after.get("pids"):
                results.append({"case": f"{environment_phase}-process-cleanup", "passed": False,
                                "pids": after.get("pids")})
            if not r["passed"]:
                break
    good = len(phases) == 2
    original = {}
    replay = {}
    if good:
        for stage, out in (("author", original), ("reopen", replay)):
            for row in phases[stage].get("cases", []):
                if row.get("case") == f"advanced-five-{stage}":
                    out[row["scenario"]] = row
        good = set(original) == set(replay) == set(LABELS)
        for index, label in enumerate(LABELS):
            if label not in original or label not in replay:
                continue
            first, second = original[label], replay[label]
            good &= (first["modules"] == second["modules"] == list(MODULES[index])
                     and first["seed"] == second["seed"]
                     and first["origin"] == second["origin"]
                     and first["recipe_sha256"] == second["recipe_sha256"]
                     and first["source_sha256"] == second["source_sha256"]
                     and first["edits"] == second["edits"]
                     and first["process_id"] != second["process_id"])
            for suffix in (".project.json", ".start.json"):
                good &= (output / (label + suffix)).is_file()
            if args.graphical:
                for name in (label + "-zone-overlay.png", label + "-painted-map.png", label + "-reopened-map.png"):
                    good &= (output / name).is_file() and (output / name).stat().st_size > 1000
    after = qualify.source_identity(project)
    stable = all(initial[key] == after[key] for key in
                 ("runtime_sha256", "source_inputs_sha256", "project_scripts_sha256"))
    good &= stable and all(r["passed"] for r in results)
    report = {"schema": "gentek80-advanced-five-fresh-process-v1", "source": initial,
              "platform": sys.platform, "godot_sha256": sha(engine),
              "exact_package": package_identity, "graphical_requested": args.graphical,
              "original": original, "reopen": replay, "phase_reports": phases,
              "phase_executions": results, "process_boundaries": process_checks,
              "fresh_process_and_material_replay": good, "source_stable": stable, "passed": bool(good)}
    (output / "qualification.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf8")
    print(json.dumps({"passed": bool(good), "scenarios": len(original),
                      "fresh_source": initial["source_commit"], "graphical": args.graphical}))
    return 0 if good else 1


if __name__ == "__main__":
    raise SystemExit(main())
