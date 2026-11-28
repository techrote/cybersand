#!/usr/bin/env python3
"""Run source-bound large-landscape admission in real, fresh Godot processes.

Retained native build provenance is verified, never rewritten as a new build.
Each map owns isolated user data shared only by its install/reopen process pair.
Original logs, reports and saves survive a failed or timed-out case.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/ci"))
import run_windows_godot_regressions as windows
from check_repository import verify_rapier_overrides, verify_runtime
from stress_physical_godot import case_environment

MANIFEST = ROOT / "tools/fixtures/workbench_host_claim_landscapes.json"
HARNESS = "res://tools/qualify_workbench_landscape.gd"
ERRORS = re.compile(r"(?:SCRIPT ERROR:|Parse Error:|Failed to load script|^ERROR:)", re.MULTILINE)
HEX64 = re.compile(r"[0-9a-f]{64}")
HEX40 = re.compile(r"[0-9a-f]{40}")
SOURCE_SUFFIXES = {".gd", ".gdshader", ".tscn", ".tres", ".gdextension", ".json", ".py",
                   ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=60)


def source_identity(allow_delta=False) -> dict:
    scopes = ["godot", "native/include", "native/src", "tools/ci", "tools/fixtures/workbench_host_claim_landscapes.json",
              "tools/qualify_workbench_landscapes.py", "tools/package_workbench_landscape_review.py",
              "tools/package_explore001_candidate.py", "tools/package_wave_flow_candidate.py",
              "third_party", ".github/workflows/workbench-host-claims.yml"]
    tree = git("ls-tree", "-rz", "HEAD", "--", *scopes)
    committed = {}
    for entry in tree.split(b"\0"):
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        path = name.decode()
        if Path(path).suffix in SOURCE_SUFFIXES or path.endswith(("project.godot", "workbench-host-claims.yml")):
            committed[path] = metadata.split()[2].decode()
    paths = set(committed)
    # Record new harness/runner files during an explicitly labelled local delta.
    paths.update(str(p.relative_to(ROOT)).replace("\\", "/") for p in (ROOT / "godot").rglob("*.gd"))
    paths.update(p for p in scopes if (ROOT / p).is_file())
    inputs, delta = {}, []
    for relative in sorted(paths):
        path = ROOT / relative
        require(path.is_file() and not path.is_symlink(), "Missing or linked execution input: " + relative)
        data = path.read_bytes().replace(b"\r\n", b"\n")
        inputs[relative] = hashlib.sha256(data).hexdigest()
        blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        if committed.get(relative) != blob:
            delta.append(relative)
    require(allow_delta or not delta, "Commit execution input changes before qualification: " + ", ".join(delta))
    return {"source_commit": git("rev-parse", "HEAD").decode().strip(),
            "source_tree": git("rev-parse", "HEAD^{tree}").decode().strip(),
            "source_inputs_sha256": inputs, "local_delta": delta}


def verify_runtime_identity() -> dict:
    if sys.platform == "win32":
        return windows.verify_retained_runtime(ROOT)
    require(sys.platform.startswith("linux"), "Only actual Linux and Windows execution are supported")
    relative = "godot/addons/cybersand_native/runtime-provenance.linux.json"
    raw = (ROOT / relative).read_bytes()
    require(raw == git("show", "HEAD:" + relative), "Linux runtime provenance differs from committed bytes")
    manifest = json.loads(raw)
    require(set(manifest["source_inputs"]) == windows.native_input_paths(ROOT),
            "Linux runtime manifest must cover every current native input")
    errors = verify_runtime(ROOT, manifest)
    errors += verify_rapier_overrides(ROOT, json.loads((ROOT / "godot/third_party/rapier2d.lock.json").read_text()))
    require(not errors, "; ".join(errors))
    native = ROOT / manifest["artifact"]
    rapier_manifest = json.loads((ROOT / "godot/addons/godot-rapier2d/runtime-provenance.linux.json").read_text())
    rapier = ROOT / rapier_manifest["artifact"]
    for path, record in ((native, manifest), (rapier, rapier_manifest)):
        require(path.read_bytes().startswith(b"\x7fELF") and sha(path) == record["sha256"]
                and path.stat().st_size == record["size"], "Unmaterialized or changed runtime: " + str(path))
        pointer = git("show", "HEAD:" + path.relative_to(ROOT).as_posix())
        require(f"oid sha256:{record['sha256']}\nsize {record['size']}\n".encode() in pointer,
                "Runtime differs from the committed LFS identity")
    return {"runtime_source_commit": manifest["source_commit"], "runtime_build_commit": manifest["build_commit"],
            "native_source_inputs": manifest["source_inputs"],
            "runtime_provenance": {"path": relative, "sha256": hashlib.sha256(raw).hexdigest()},
            "cybersand_runtime": {"path": manifest["artifact"], "sha256": sha(native), "size": native.stat().st_size},
            "rapier_runtime": {"path": rapier_manifest["artifact"], "sha256": sha(rapier), "size": rapier.stat().st_size}}


def project_identity(project: Path, identity: dict, runtime: dict) -> dict:
    """Bind the actual loaded project, including an extracted evaluation copy."""
    expected = {name.removeprefix("godot/"): digest for name, digest in identity["source_inputs_sha256"].items()
                if name.startswith("godot/")}
    extracted = project.resolve() != (ROOT / "godot").resolve()
    windows_runtime = runtime["cybersand_runtime"]["path"].endswith(".dll")
    platform, other_platform = ("windows", "linux") if windows_runtime else ("linux", "windows")
    host_binding = f"tools/swarm004-runtime.{platform}.json"
    other_binding = f"tools/swarm004-runtime.{other_platform}.json"
    if extracted and not (project / other_binding).exists():
        # Only the other platform's CLI binding is optional in a portable package.
        expected.pop(other_binding, None)
    inputs = {}
    for name, digest in expected.items():
        path = project / name
        require(path.is_file() and not path.is_symlink(), "Missing execution project input: " + name)
        inputs[name] = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        require(inputs[name] == digest, "Loaded project differs from recorded source: " + name)
    if extracted and host_binding in expected:
        native_cli = "tools/gentek_reciprocal.exe" if windows_runtime else "tools/gentek_reciprocal"
        binding = json.loads((project / host_binding).read_bytes())
        path = project / native_cli
        require(binding.get("artifact") == "godot/" + native_cli and binding.get("platform") == platform
                and path.is_file() and not path.is_symlink() and path.stat().st_size == binding.get("bytes"),
                "Missing or inconsistent installed reciprocal generator: " + native_cli)
        inputs[native_cli] = sha(path)
        require(inputs[native_cli] == binding.get("sha256"), "Installed reciprocal generator differs from source binding")
    require({p.relative_to(project).as_posix() for p in project.rglob("*.gd")} ==
            {name for name in expected if name.endswith(".gd")}, "Loaded project has an unrecorded GDScript")
    for kind in ("cybersand_runtime", "rapier_runtime"):
        entry = runtime[kind]
        name = entry["path"].removeprefix("godot/")
        require(sha(project / name) == entry["sha256"], "Loaded project runtime differs from retained identity")
        inputs[name] = entry["sha256"]
    return inputs


def load_maps(manifest_path: Path) -> tuple[dict, list[dict]]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    maps = manifest.get("maps", [])
    require(manifest.get("schema_version") == 1 and 1 <= len(maps) <= 10, "Invalid landscape manifest")
    names = set()
    for item in maps:
        name = item.get("name", "")
        require(re.fullmatch(r"[A-Za-z0-9_-]{1,48}", name) and name not in names, "Invalid/duplicate map name")
        names.add(name)
        require(HEX40.fullmatch(item["head_sha"]) and HEX64.fullmatch(item["sha256"])
                and HEX64.fullmatch(item["grid_sha256"]), "Map identities must be complete digests")
        require(item["dimensions"] == [2048, 1024], "Admission corpus must retain its authored 2048x1024 scope")
        require(item["raw_url"] == f"https://raw.githubusercontent.com/{manifest['repository']}/{item['head_sha']}/{item['path']}",
                "Map download URL is not its exact committed source")
        require(Path(item["fixture_file"]).name == item["fixture_file"], "Fixture filename must be a basename")
    return manifest, maps


def materialize_maps(manifest_path: Path, destination: Path, existing: Path | None = None) -> tuple[dict, list[dict]]:
    manifest, maps = load_maps(manifest_path)
    destination.mkdir(parents=True, exist_ok=True)
    for item in maps:
        target = destination / item["fixture_file"]
        if target.exists():
            data = target.read_bytes()
        elif existing is not None:
            data = (existing / item["fixture_file"]).read_bytes()
        else:
            with urllib.request.urlopen(item["raw_url"], timeout=60) as response:
                data = response.read(1024 * 1024 + 1)
        require(len(data) == item["source_bytes"] <= 1024 * 1024 and hashlib.sha256(data).hexdigest() == item["sha256"],
                "Authored map size/hash mismatch: " + item["name"])
        require(json.loads(data)["extent"] == item["dimensions"], "Authored map dimensions changed")
        if not target.exists():
            target.write_bytes(data)
    return manifest, maps


def execute(command: list[str], location: Path, environment: dict, timeout: float) -> dict:
    location.mkdir(parents=True, exist_ok=False)
    log = location / "process.log"
    record = {"command": command, "timeout_seconds": timeout, "status": "running"}
    start = time.monotonic()
    process = None
    try:
        with log.open("w", encoding="utf-8") as output:
            process = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=output, stderr=subprocess.STDOUT,
                                       start_new_session=(sys.platform != "win32"))
            record["pid"] = process.pid
            try:
                record["exit_code"] = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                if sys.platform == "win32":
                    # Godot's pinned console wrapper owns a kill-on-close job.
                    process.kill()
                else:
                    os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=15)
                record["status"] = "timeout"
                raise RuntimeError("Godot process exceeded its recorded timeout")
        text = log.read_text(encoding="utf-8", errors="replace")
        require(record["exit_code"] == 0 and not ERRORS.search(text), "Godot process failed; inspect " + str(log))
        record["status"] = "passed"
    except Exception as error:
        record["error"] = str(error)
        if record["status"] == "running":
            record["status"] = "failed"
    finally:
        record["seconds"] = round(time.monotonic() - start, 3)
        record["log_sha256"] = sha(log) if log.exists() else None
        write_json(location / "process.json", record)
    return record


def independent_grid(path: Path) -> dict:
    """Replay authored boxes/discs without calling the GDScript under test."""
    setup = json.loads(path.read_text(encoding="utf-8"))
    require(setup.get("version") == 2 and setup.get("extent") == [2048, 1024], "Unsupported saved-start grid")
    width, height = setup["extent"]
    cells = bytearray(width * height)
    for edit in setup["edits"]:
        require(len(edit) in (4, 5) and all(isinstance(x, (int, float)) and not isinstance(x, bool)
                and math.isfinite(x) and int(x) == x for x in edit), "Malformed saved paint geometry")
        stamp = [int(x) for x in edit]
        x, y = stamp[:2]
        material = stamp[-1]
        require(0 <= x < width and 0 <= y < height and 0 <= material <= 255, "Saved paint bounds/material invalid")
        if len(stamp) == 5:
            w, h = stamp[2:4]
            require(w > 0 and h > 0 and x + w <= width and y + h <= height, "Saved rectangle exceeds extent")
            for row in range(y, y + h):
                cells[row * width + x:row * width + x + w] = bytes([material]) * w
        else:
            radius = stamp[2]
            require(2 <= radius <= 24, "Saved disc radius invalid")
            for row in range(max(0, y - radius), min(height, y + radius + 1)):
                half = math.isqrt(radius * radius - (row - y) ** 2)
                left, right = max(0, x - half), min(width, x + half + 1)
                cells[row * width + left:row * width + right] = bytes([material]) * (right - left)
    stored = bytearray(2 * len(cells))
    stored[::2] = cells
    return {"grid_sha256": hashlib.sha256(cells).hexdigest(), "native_le16_sha256": hashlib.sha256(stored).hexdigest(),
            "edits": len(setup["edits"])}


def validate_map_report(path: Path, item: dict, phase: str, source: str, userdata: Path, source_path: Path) -> dict:
    result = json.loads(path.read_text(encoding="utf-8"))
    require(result.get("completed") is True and result.get("failures") == [] and result.get("checks", 0) > 0,
            "Missing, incomplete or failing native landscape report")
    require(result.get("map_name") == item["name"] and result.get("phase") == phase
            and result.get("source_revision") == source and result.get("source_setup_sha256") == item["sha256"],
            "Landscape execution identity mismatch")
    require(result.get("construction_rectangles") == item["construction_rectangle_count"]
            and result.get("source_edits") == item["source_rectangle_count"]
            and result.get("native_rectangle_capacity") == 32768, "Source count or installed native capacity mismatch")
    saved = result.get("save", {})
    saved_path = Path(saved.get("path", "")).resolve()
    require(saved_path.is_relative_to(userdata.resolve()) and saved_path.is_file()
            and sha(saved_path) == saved.get("sha256"), "Saved start is absent, changed or outside isolated user data")
    saved_grid = independent_grid(saved_path)
    require(saved_grid["grid_sha256"] == saved.get("grid_sha256") and saved_grid["edits"] == saved.get("edits"),
            "Saved authored bytes differ from the independently replayed full grid")
    initial = independent_grid(source_path) if phase == "install" else saved_grid
    require(result.get("source_grid_sha256") == item["grid_sha256"], "Authored source grid identity mismatch")
    grid = result.get("grid_initial", {})
    require(grid.get("mismatches") == 0 and grid.get("cells") == 2048 * 1024
            and grid.get("actual_sha256") == grid.get("expected_sha256") == initial["grid_sha256"]
            and grid.get("native_stored_materials_le16_sha256") == initial["native_le16_sha256"],
            "Installed complete material grid differs from the independent authored identity")
    progress = result.get("progression", {})
    require(progress.get("native_ticks_after", 0) > progress.get("native_ticks_before", 0)
            and progress.get("rapier_ticks_after", 0) > progress.get("rapier_ticks_before", 0)
            and progress.get("distance", 0) > 0 and progress.get("peak_applied_force", 0) > 0,
            "Missing actual native/Rapier/actor progression")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--project", type=Path, default=ROOT / "godot", help="Optional extracted package project; must match exact source")
    parser.add_argument("--map", action="append", dest="selected_maps", help="Explicit subset for extracted-package requalification")
    parser.add_argument("--fixture-dir", type=Path)
    parser.add_argument("--allow-source-delta", action="store_true", help="Local debugging only; record every changed source input")
    parser.add_argument("--process-timeout", type=int, default=240)
    parser.add_argument("--campaign-timeout", type=int, default=1200)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema_version": 1, "status": "running", "platform": sys.platform, "cases": [], "maps": []}
    deadline = time.monotonic() + args.campaign_timeout
    identity = runtime = loaded_project = None
    try:
        require(30 <= args.process_timeout <= 600 and 120 <= args.campaign_timeout <= 1500, "Invalid bounded execution allowance")
        identity = source_identity(args.allow_source_delta)
        runtime = verify_runtime_identity()
        project = args.project.resolve(strict=True)
        loaded_project = project_identity(project, identity, runtime)
        report.update(identity)
        report["runtime"] = runtime
        report["project"] = {"path": str(project), "inputs_sha256": loaded_project}
        godot = args.godot.resolve(strict=True)
        version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
        require(version == windows.GODOT_VERSION, "Qualification requires repository-pinned Godot 4.7")
        report["godot"] = {"path": str(godot), "version": version, "sha256": sha(godot)}
        if sys.platform == "win32":
            report["godot"]["gui_sha256"] = sha(godot.with_name("Godot_v4.7-stable_win64.exe"))
        manifest, maps = materialize_maps(args.manifest.resolve(), output / "fixtures", args.fixture_dir)
        if args.selected_maps:
            require(set(args.selected_maps) <= {m["name"] for m in maps}, "Unknown requested map subset")
            maps = [m for m in maps if m["name"] in args.selected_maps]
            report["explicit_map_subset"] = args.selected_maps
        write_json(output / "landscape-manifest.json", manifest)
        report["fixture_manifest_sha256"] = sha(args.manifest)
        command = [str(godot), "--headless", "--audio-driver", "Dummy", "--path", str(project)]

        def run(label, flags, environment):
            remaining = deadline - time.monotonic()
            require(remaining > 1, "Landscape campaign exhausted its overall allowance")
            record = execute(command + flags, output / label, environment, min(args.process_timeout, remaining))
            record["label"] = label
            report["cases"].append(record)
            write_json(output / "qualification.json", report)
            require(record["status"] == "passed", record.get("error", "Godot process failed"))
            return record

        environment = case_environment(output / "bootstrap-userdata")
        environment["CYBERSAND_SOURCE_REVISION"] = identity["source_commit"]
        run("import", ["--editor", "--quit"], environment)
        for filename, marker in (("test_workbench_host_claim_capacity", "WORKBENCH_HOST_CLAIMS"),
                                 ("test_workbench_host_claim_native", "WORKBENCH_HOST_CLAIMS_NATIVE")):
            native_report = output / (filename + ".json")
            env = dict(environment, WB_HOST_NATIVE_REPORT=str(native_report))
            record = run(filename, ["--script", "res://tests/" + filename + ".gd"], env)
            text = (output / filename / "process.log").read_text(encoding="utf-8")
            matches = re.findall(re.escape(marker) + r": (\d+) assertions, (\d+) failures", text)
            require(len(matches) == 1 and int(matches[0][0]) > 0 and int(matches[0][1]) == 0,
                    "Capacity case exited without its unique successful assertion receipt: " + filename)
            record["assertions"] = int(matches[0][0])
        for item in maps:
            entry = {"name": item["name"], "source": item, "status": "running", "phases": {}}
            report["maps"].append(entry)
            userdata = output / item["name"] / "userdata"
            env = case_environment(userdata)
            env.update(CYBERSAND_SOURCE_REVISION=identity["source_commit"], WB_LANDSCAPE_NAME=item["name"],
                       WB_LANDSCAPE_SETUP=str(output / "fixtures" / item["fixture_file"]),
                       WB_LANDSCAPE_EXPECTED_SHA256=item["sha256"], WB_LANDSCAPE_EXPECTED_GRID_SHA256=item["grid_sha256"])
            try:
                for phase in ("install", "reopen"):
                    result_path = output / item["name"] / (phase + ".json")
                    require(sha(output / "fixtures" / item["fixture_file"]) == item["sha256"], "Fixture changed before execution")
                    record = run(item["name"] + "/" + phase, ["--script", HARNESS],
                                 dict(env, WB_LANDSCAPE_PHASE=phase, WB_LANDSCAPE_REPORT=str(result_path)))
                    result = validate_map_report(result_path, item, phase, identity["source_commit"], userdata,
                                                 output / "fixtures" / item["fixture_file"])
                    entry["phases"][phase] = {"report_sha256": sha(result_path), "process": record, "result": result}
                install, reopen = entry["phases"]["install"], entry["phases"]["reopen"]
                require(install["process"]["pid"] != reopen["process"]["pid"], "Reopen must execute in a fresh process")
                require(install["result"]["save"]["sha256"] == reopen["result"]["save"]["sha256"],
                        "Fresh process did not retain the saved authored-start identity")
                entry["status"] = "passed"
                print("PASS", item["name"], item["construction_rectangle_count"], "rectangles: native + Rapier + fresh reopen", flush=True)
            except Exception as error:
                entry.update(status="failed", error=str(error))
                print("FAIL", item["name"], str(error), flush=True)
            finally:
                write_json(output / "qualification.json", report)
        require(all(item["status"] == "passed" for item in report["maps"]), "One or more maps failed; independent statuses retained")
        report["status"] = "passed"
    except Exception as error:
        report.update(status="failed", error=str(error))
        print("LANDSCAPE_QUALIFICATION_FAILED:", error, file=sys.stderr, flush=True)
    finally:
        if identity is not None:
            try:
                require(source_identity(args.allow_source_delta) == identity, "Execution source changed during qualification")
                require(verify_runtime_identity() == runtime, "Native runtime identity changed during qualification")
                if loaded_project is not None:
                    require(project_identity(project, identity, runtime) == loaded_project, "Loaded project changed during qualification")
                report["input_custody"] = "passed"
            except Exception as error:
                report.update(status="failed", custody_error=str(error), input_custody="failed")
        report["completed"] = True
        write_json(output / "qualification.json", report)
    print(json.dumps({"status": report["status"], "maps": [{"name": m["name"], "status": m["status"]} for m in report["maps"]]}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
