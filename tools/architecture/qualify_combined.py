#!/usr/bin/env python3
"""Qualify the extracted #673 Windows package through the existing Workbench.

Actual graphical hosted Windows execution is evidence for this package, not a
claim of physical Windows 11 or manual owner acceptance. No source is patched in
the extracted package. Each phase finishes before the next process is launched.
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
import uuid

ROOT = Path(__file__).resolve().parents[2]
VERSION = "4.7.stable.official.5b4e0cb0f"
MODULES = ["megatruss_station", "cathedral_megaframe", "seeded_typology_megablock",
           "metabolist_spine", "interlaced_viaduct", "rosework_gatehouse",
           "interlock_brutalism", "suspended_arcology"]
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|GDExtension library not found|Can't open (?:GDExtension )?dynamic library|Error loading extension")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def package_identity(package: Path, project: Path, engine: Path) -> dict:
    manifest = json.loads((package / "candidate-manifest.json").read_text(encoding="utf-8-sig"))
    provenance = json.loads((package / "source-built-candidate-provenance.json").read_text(encoding="utf-8-sig"))
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True).strip()
    if manifest["source_commit"] != head or provenance["source_commit"] != head or provenance["source_tree"] != tree:
        raise ValueError("Package, native build and executing harness must identify the same exact source")
    if project != package / "godot" or engine.parent != package:
        raise ValueError("Campaign must run the extracted package project and packaged engine")
    inventory = manifest["files_sha256"]
    for name, expected in inventory.items():
        path = (package / name).resolve()
        if not path.is_relative_to(package) or not path.is_file() or sha(path) != expected:
            raise ValueError("Extracted package inventory mismatch: " + name)
    actual = {p.relative_to(package).as_posix() for p in package.rglob("*") if p.is_file()}
    if actual != set(inventory) | {"candidate-manifest.json"}:
        raise ValueError("Extracted package has unlisted or missing payload files")
    for relative in ("godot/tests/test_gentek_combined_workbench.gd", "godot/tests/test_architectural_generator.gd"):
        committed = subprocess.check_output(["git", "show", f"HEAD:{relative}"], cwd=ROOT)
        if (package / relative).read_bytes() != committed:
            raise ValueError("Executed campaign script differs from committed source: " + relative)
    native = project / "addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
    if sha(native) != manifest["native_sha256"] or sha(native) != provenance["sha256"]:
        raise ValueError("Packaged native runtime differs from same-source build")
    return {"source_commit": head, "source_tree": tree, "native_sha256": sha(native),
            "manifest_sha256": sha(package / "candidate-manifest.json"),
            "payload_file_count": len(inventory), "inventory_verified": True,
            "engine_sha256": sha(engine), "native_input_count": len(provenance["source_inputs"])}


def windows_processes(engine: Path) -> list[dict]:
    if os.name != "nt":
        return []
    names = [str(engine), str(engine.with_name(engine.name.replace("_console.exe", ".exe")))]
    literals = ",".join("'" + name.replace("'", "''") + "'" for name in names)
    command = (f"$paths=@({literals}); @((Get-CimInstance Win32_Process | "
               "Where-Object { $paths -contains $_.ExecutablePath }) | "
               "Select-Object ProcessId,ParentProcessId,ExecutablePath,CommandLine) | ConvertTo-Json -Compress")
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command],
                                  text=True, timeout=30).strip()
    parsed = json.loads(raw) if raw else []
    return parsed if isinstance(parsed, list) else [parsed]


def stop_process_tree(child: subprocess.Popen, engine: Path) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(child.pid), "/T", "/F"], capture_output=True, timeout=30)
        # The console wrapper can already have exited. Only this isolated
        # package's exact executable paths are eligible for fallback cleanup.
        for process in windows_processes(engine):
            subprocess.run(["taskkill", "/PID", str(process["ProcessId"]), "/T", "/F"],
                           capture_output=True, timeout=30)
    elif child.poll() is None:
        os.killpg(child.pid, 9)
    if child.poll() is None:
        child.kill()
    child.wait(timeout=30)


def execute(name: str, command: list[str], env: dict[str, str], output: Path,
            engine: Path, timeout: int, marker: str | None) -> dict:
    before = windows_processes(engine)
    if before:
        raise ValueError("Previous packaged application still running before " + name)
    log = output / f"{name}.log"
    started = time.time()
    monotonic = time.monotonic()
    timed_out = False
    with log.open("w", encoding="utf-8") as stream:
        child = subprocess.Popen(command, cwd=engine.parent, env=env, stdout=stream,
                                 stderr=subprocess.STDOUT, start_new_session=os.name != "nt")
        try:
            code = child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            stop_process_tree(child, engine)
            code = child.returncode
        finally:
            if child.poll() is None:
                stop_process_tree(child, engine)
    survivors = windows_processes(engine)
    if survivors:
        stop_process_tree(child, engine)
    text = log.read_text(encoding="utf-8", errors="replace")
    completion = re.findall(marker, text) if marker else []
    passed = code == 0 and not timed_out and not survivors and not ERRORS.search(text) and (bool(completion) if marker else True)
    result = {"case": name, "passed": bool(passed), "command": command,
              "launcher_pid": child.pid, "started_unix": started, "finished_unix": time.time(),
              "wall_seconds": time.monotonic() - monotonic, "returncode": code, "timed_out": timed_out,
              "previous_package_processes": before, "surviving_package_processes": survivors,
              "fresh_process_boundary_verified": not before and not survivors,
              "completion": completion, "log_sha256": sha(log)}
    save(output / f"{name}-process.json", result)
    print(json.dumps(result), flush=True)
    if not passed:
        print("\n".join(text.splitlines()[-100:]), file=sys.stderr)
    return result


def stable_payload(project: Path, engine: Path) -> dict:
    paths = [p for p in project.rglob("*.gd") if ".godot" not in p.parts]
    paths.extend(p for p in project.rglob("*.dll") if ".godot" not in p.parts)
    paths.extend([engine, engine.with_name(engine.name.replace("_console.exe", ".exe"))])
    return {str(p): sha(p) for p in sorted(set(paths)) if p.is_file()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--timeout", type=int, default=1800)
    args = parser.parse_args()
    engine, project, package, output = (p.resolve() for p in (args.godot, args.project, args.package, args.output))
    if output.exists():
        raise ValueError("Use a fresh evidence directory; prior process receipts cannot be reused")
    output.mkdir(parents=True)
    identity = package_identity(package, project, engine)
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
    if version != VERSION:
        raise ValueError("Godot pin mismatch: " + version)
    campaign = str(uuid.uuid4())
    identity.update({"godot_version": version, "platform": platform.platform(), "windows_version": platform.win32_ver(),
                     "campaign_id": campaign, "graphical_requested": args.graphical,
                     "physical_windows11_acceptance": "NOT RUN: no physical Windows 11 desktop attached",
                     "runner_os": os.environ.get("RUNNER_OS"), "runner_image": os.environ.get("ImageOS"),
                     "runner_image_version": os.environ.get("ImageVersion"),
                     "workflow_run": os.environ.get("GITHUB_RUN_ID"), "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT")})
    save(output / "source-runtime-identity.json", identity)
    before = stable_payload(project, engine)
    env = os.environ.copy()
    for key, suffix in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("XDG_DATA_HOME", "data"),
                        ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
        folder = output / "profile" / suffix
        folder.mkdir(parents=True)
        env[key] = str(folder)
    env.update({"CYBERSAND_ARCHITECTURE_OUTPUT": str(output), "CYBERSAND_COMBINED_CAMPAIGN": campaign,
                "CYBERSAND_SOURCE_REVISION": identity["source_commit"],
                "CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS": "1" if args.graphical else "0"})
    base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    display = ["--headless"]
    if args.graphical:
        display = ["--rendering-method", "gl_compatibility"]
        display += ["--rendering-driver", "opengl3_angle"] if os.name == "nt" else ["--display-driver", "x11"]
    results = [execute("import", [*base, "--headless", "--editor", "--quit"], env, output, engine, args.timeout, None)]
    if results[-1]["passed"]:
        # Same --workbench application entry point used by Open Workbench.cmd,
        # no --script/test scene. Hosted Windows needs ANGLE; the owner launcher
        # retains the project's normal renderer selection unchanged.
        results.append(execute("workbench-launch", [*base, *display, "--quit-after", "180", "--", "--workbench"],
                               env, output, engine, args.timeout, None))
    for phase in ("singles", "author", "reopen"):
        if not results[-1]["passed"]:
            break
        env["CYBERSAND_COMBINED_PHASE"] = phase
        marker = rf"GENTEK_COMBINED_RESULTS phase={phase} checks=([1-9][0-9]*) failures=0 complete=true"
        result = execute(phase, [*base, *display, "--script", "res://tests/test_gentek_combined_workbench.gd"],
                         env, output, engine, args.timeout, marker)
        results.append(result)
    reports = {}
    for phase in ("singles", "author", "reopen"):
        path = output / f"combined-{phase}.json"
        if path.exists():
            reports[phase] = json.loads(path.read_text(encoding="utf-8"))
    complete = set(reports) == {"singles", "author", "reopen"}
    if complete:
        singles = [case for case in reports["singles"]["cases"] if case.get("case") == "individual-showcase"]
        authors = [case for case in reports["author"]["cases"] if case.get("case") == "mixed-author"]
        reopened = [case for case in reports["reopen"]["cases"] if case.get("case") == "mixed-reopen"]
        complete = (len(singles) == 8 and {case["module"] for case in singles} == set(MODULES)
                    and len(authors) == len(reopened) == 2
                    and all(report["complete"] and report["failures"] == 0 and report["campaign_id"] == campaign
                            and report["source_commit"] == identity["source_commit"] for report in reports.values()))
        for author, reopen in zip(authors, reopened):
            complete = complete and all(author[key] == reopen[key] for key in
                                       ("selection", "modules", "project_sha256", "recipe_sha256", "native_sha256"))
        if args.graphical:
            complete = complete and all(report["display"] != "headless" for report in reports.values())
    stable = before == stable_payload(project, engine)
    results += [{"case": "complete-advanced-campaign", "passed": bool(complete)},
                {"case": "executed-code-and-runtime-stable", "passed": stable}]
    passed = all(case["passed"] for case in results)
    gallery = {p.name: sha(p) for p in sorted(output.glob("*.png"))}
    summary = {"schema": 1, "passed": passed, "cases": results, "identity": identity,
               "checks_by_phase": {name: report["checks"] for name, report in reports.items()},
               "png_sha256": gallery, "physical_windows11_acceptance": False,
               "disposition": "Hosted package qualification complete; physical Windows 11 gate outstanding" if passed else "NOT READY: campaign failure"}
    save(output / "qualification.json", summary)
    links = ["# Combined Workbench gallery", "", "Actual package output on " + platform.platform() + ".",
             "Automated graphical execution; physical Windows 11 and owner aesthetic acceptance are not claimed.", ""]
    for name in gallery:
        links += [f"## {Path(name).stem.replace('-', ' ')}", "", f"![{name}]({name})", ""]
    (output / "GALLERY.md").write_text("\n".join(links), encoding="utf-8")
    print(json.dumps({"passed": passed, "checks_by_phase": summary["checks_by_phase"], "png_count": len(gallery)}), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
