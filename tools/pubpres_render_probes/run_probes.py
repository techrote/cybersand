#!/usr/bin/env python3
"""Run finite native-independent renderer diagnostics; never qualify a package."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability_build"))
from process_owner import OwnedProcess, bounded_process

VERSION = "4.7.stable.official.5b4e0cb0f"
ENGINE_COMMIT = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
FROZEN_SOURCE = "a7074ab1bb4fede30d75a7924b4a5bfb7ea963d1"
CHILD_SECONDS = 60
OUTER_SECONDS = 180  # 30s display startup + 60s child + owned cleanup margins.
PREFIX = "tools/pubpres_render_probes"
PROJECT_FILES = {
    "font": ("project.godot", "font_probe.gd"),
    "material": ("project.godot", "copied-source-manifest.json",
        "scripts/blit_material_publisher.gd", "shaders/material_publication_blit.gdshader",
        "tests/test_material_staging_reachability.gd", "tests/diagnose_queued_material.gd"),
}
FROZEN_INPUTS = {
    "scripts/blit_material_publisher.gd": "b3f046b691328d7991eb3d275f26c22d47f3bb368b5a8a9fe1ca46860870719b",
    "shaders/material_publication_blit.gdshader": "ab174f03cf0d129c15a8af64d5223e5608cc5c10a7b7bb81855b17c7f0586abd",
    "tests/test_material_staging_reachability.gd": "a1efcb382325ff8630249b401abf67202400b7485178397670d0093882912f94",
}
# Same official archive pins as the repository downloader. No CI/build import.
ARCHIVES = {
    "linux": ("Godot_v4.7-stable_linux.x86_64.zip", "sha256",
        "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c",
        ("Godot_v4.7-stable_linux.x86_64",)),
    "windows": ("Godot_v4.7-stable_win64.exe.zip", "sha512",
        "41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9",
        ("Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe")),
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def digest(path: Path, algorithm="sha256") -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=root, text=True, timeout=30).strip()


def matrix(platform: str) -> list[dict]:
    if platform not in ARCHIVES:
        raise ValueError("Unsupported diagnostic platform")
    font = [("safe", "text", False), ("separate", "text", False),
            ("separate", "text", True), ("separate", "empty", False)] if platform == "linux" else [
            ("safe", "empty", False), ("separate", "empty", False)]
    arms = [{"id": "font-" + thread + "-" + mode + ("-mipmaps" if mipmaps else ""),
             "project": "font", "thread": thread, "mode": mode, "mipmaps": mipmaps,
             "script": "font_probe.gd"} for thread, mode, mipmaps in font]
    arms.extend({"id": f"material-{thread}-r8-slots{slots}-reachable",
                 "project": "material", "thread": thread, "channels": 1, "slots": slots,
                 "policy": "reachable", "script": "tests/diagnose_queued_material.gd"}
                for thread, slots in (("safe", 2), ("safe", 3), ("separate", 2), ("separate", 1)))
    return arms


def verify_engine(engine: Path, platform: str) -> dict:
    name, algorithm, expected, members = ARCHIVES[platform]
    if engine.name != members[0]:
        raise ValueError("Use the direct pinned engine executable; the Windows console launcher has a different PID/hash")
    manifest_path = engine.parent / "ENGINE.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if (manifest.get("version") != VERSION or manifest.get("archive") != name
            or manifest.get("algorithm") != algorithm or manifest.get("digest") != expected
            or set(manifest.get("files_sha256", {})) != set(members)):
        raise ValueError("Engine download receipt differs from exact official pin")
    archive_path = engine.parent / name
    if digest(archive_path, algorithm) != expected:
        raise ValueError("Official engine archive digest differs")
    with zipfile.ZipFile(archive_path) as archive:
        if set(archive.namelist()) != set(members):
            raise ValueError("Official engine archive members differ")
        for member in members:
            with archive.open(member) as incoming:
                archived = hashlib.file_digest(incoming, "sha256").hexdigest()
            if archived != manifest["files_sha256"][member] or digest(engine.parent / member) != archived:
                raise ValueError("Extracted engine differs from the pinned archive")
    return {"version": VERSION, "source_commit": ENGINE_COMMIT, "executable": str(engine),
            "sha256": digest(engine), "download_receipt_sha256": digest(manifest_path),
            "archive": name, "archive_algorithm": algorithm, "archive_digest": expected}


def committed_bundle(root: Path, source: str, wrapper: Path | None) -> tuple[dict, dict]:
    if not re.fullmatch(r"[0-9a-f]{40}", source) or git(root, "rev-parse", "HEAD") != source:
        raise ValueError("Full exact checkout HEAD is required")
    if Path(__file__).resolve() != root / PREFIX / "run_probes.py":
        raise ValueError("Runner must belong to the exact source checkout")
    names = {f"{PREFIX}/projects/{project}/{name}" for project, files in PROJECT_FILES.items() for name in files}
    tracked = set(git(root, "ls-tree", "-r", "--name-only", source, "--", PREFIX + "/projects").splitlines())
    if tracked != names:
        raise ValueError("Isolated project input set differs; no native extensions or extra inputs admitted")
    drivers = {PREFIX + "/run_probes.py", "tools/pubpres_playability_build/process_owner.py"}
    if wrapper is not None:
        if wrapper != root / "tools/pubpres_playability_build/owned_xvfb.py":
            raise ValueError("Linux requires the reviewed in-checkout owned_xvfb.py helper")
        drivers.add(wrapper.relative_to(root).as_posix())
    blobs, inputs = {}, {}
    for name in sorted(names | drivers):
        blob = subprocess.check_output(["git", "show", source + ":" + name], cwd=root, timeout=30)
        actual = (root / name).read_bytes()
        if actual.replace(b"\r\n", b"\n") != blob.replace(b"\r\n", b"\n"):
            raise ValueError("Driver/project differs from exact source: " + name)
        blobs[name] = blob
        inputs[name] = {"committed_sha256": sha(blob), "working_sha256": sha(actual)}
    for name, expected in FROZEN_INPUTS.items():
        if sha(blobs[f"{PREFIX}/projects/material/{name}"]) != expected:
            raise ValueError("Frozen a707 publisher/fixture/shader differs: " + name)
    manifest = json.loads(blobs[f"{PREFIX}/projects/material/copied-source-manifest.json"])
    if ({item["path"]: item["sha256"] for item in manifest} != FROZEN_INPUTS
            or any(item.get("source_commit") != FROZEN_SOURCE for item in manifest)):
        raise ValueError("Frozen source manifest differs")
    return blobs, {"source_commit": source, "source_tree": git(root, "rev-parse", source + "^{tree}"),
                   "inputs": inputs, "frozen_application_source_commit": FROZEN_SOURCE,
                   "native_independent": True, "native_runtime_required": False}


def stage_project(blobs: dict, arm: dict, folder: Path) -> dict[str, str]:
    project = folder / "project"
    hashes = {}
    for name in PROJECT_FILES[arm["project"]]:
        data = blobs[f"{PREFIX}/projects/{arm['project']}/{name}"]
        target = project / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)  # Exact Git bytes, independent of Windows checkout line endings.
        hashes[name] = sha(data)
    return hashes


def expected_history_hashes(slots: int) -> tuple[str, str]:
    """Independent R8 reconstruction of the frozen final dense/sparse tape."""
    dense_value = 20 + 6 * (slots * 2 + 1) - 3
    def patched(value):
        data = bytearray([dense_value]) * (1152 * 768)
        for index in range(4):
            data[63 * 1152 + index * 64 + 63] = value
        return sha(data)
    return patched(dense_value + 2), patched(dense_value + 1)


def run_child(request_path: Path) -> int:
    request = json.loads(request_path.read_text(encoding="utf-8"))
    folder = request_path.parent
    started = time.monotonic()
    outcome = {"schema": "pubpres-render-probe-process-v1", "command": request["command"],
               "source_commit": request["source_commit"], "nonce": request["nonce"],
               "engine_sha256": request["engine_sha256"], "timeout_seconds": CHILD_SECONDS,
               "pid": None, "returncode": None, "timed_out": False,
               "surviving_children_at_exit": False, "cleanup_complete": False,
               "terminal_interruption": None, "error": None}
    owner = None
    terminal = None
    try:
        with (folder / "stdout.log").open("w", encoding="utf-8") as out, (folder / "stderr.log").open("w", encoding="utf-8") as err:
            with OwnedProcess(request["command"], cwd=folder, stdout=out, stderr=err) as owner:
                outcome["pid"] = owner.process.pid
                try:
                    owner.process.wait(timeout=CHILD_SECONDS)
                except subprocess.TimeoutExpired:
                    outcome["timed_out"] = True
                outcome["surviving_children_at_exit"] = owner.close()
                outcome["cleanup_complete"] = True
                outcome["returncode"] = owner.process.returncode
    except Exception as error:
        outcome["error"] = type(error).__name__ + ": " + str(error)
    except BaseException as error:
        terminal = error
        outcome["terminal_interruption"] = type(error).__name__ + ": " + str(error)
    finally:
        if owner is not None and outcome["returncode"] is None:
            outcome["returncode"] = owner.process.returncode
        outcome["elapsed_seconds"] = time.monotonic() - started
        for name in ("stdout.log", "stderr.log", "godot.log"):
            if (folder / name).exists():
                outcome[name + "_sha256"] = digest(folder / name)
        write_json(folder / "process.json", outcome)
    if terminal is not None:
        raise terminal
    return int(bool(outcome["timed_out"] or outcome["surviving_children_at_exit"]
                    or not outcome["cleanup_complete"] or outcome["returncode"] != 0 or outcome["error"]))


def receipt_errors(receipt: dict, process: dict, arm: dict, source: str, nonce: str,
                   engine_sha: str, hashes: dict, platform: str) -> list[str]:
    errors = []
    def require(condition, message):
        if not condition:
            errors.append(message)
    require(type(receipt.get("pid")) is int and receipt["pid"] == process.get("pid"), "Receipt/application PID mismatch")
    require(receipt.get("source_commit") == source and receipt.get("nonce") == nonce, "Receipt source/nonce mismatch")
    require(receipt.get("engine_sha256") == engine_sha and receipt.get("engine", {}).get("hash") == ENGINE_COMMIT,
            "Receipt pinned engine mismatch")
    require(receipt.get("platform") == ("Linux" if platform == "linux" else "Windows"), "Receipt platform mismatch")
    require(receipt.get("display") not in (None, "", "headless"), "Real graphical display missing")
    require(receipt.get("driver") == ("opengl3" if platform == "linux" else "opengl3_angle"), "Driver mismatch")
    require(receipt.get("render_thread_inline") is (arm["thread"] == "safe"), "Rendering owner mismatch")
    require(receipt.get("native_independent") is True and receipt.get("loaded_extensions") == [],
            "Native-independent runtime assertion missing or extensions loaded")
    require(receipt.get("project_sha256") == hashes["project.godot"], "Project hash mismatch")
    if arm["project"] == "font":
        require(receipt.get("schema") == "pubpres-isolated-font-probe-v1", "Font receipt schema mismatch")
        require(receipt.get("script_sha256") == hashes[arm["script"]], "Font script hash mismatch")
        require(receipt.get("mode") == arm["mode"] and receipt.get("font_mipmaps") is arm["mipmaps"],
                "Font mode/mipmap selector mismatch")
        require(receipt.get("requested_thread") == arm["thread"], "Font thread selector mismatch")
        require(receipt.get("draws") == 64 and receipt.get("glyph_calls") == (6016 if arm["mode"] == "text" else 0),
                "Bounded draw/glyph completion missing")
        require(receipt.get("errors") == [], "Font fixture assertions failed")
        require(receipt.get("framebuffer_size") == [1024, 640]
                and bool(re.fullmatch(r"[0-9a-f]{64}", receipt.get("framebuffer_sha256", ""))),
                "Completed viewport readback missing")
    else:
        require(receipt.get("schema") == "pubpres-queued-material-diagnostic-v1", "Material receipt schema mismatch")
        expected = {"publisher": hashes["scripts/blit_material_publisher.gd"],
                    "shader": hashes["shaders/material_publication_blit.gdshader"],
                    "original_fixture": hashes["tests/test_material_staging_reachability.gd"],
                    "diagnostic": hashes[arm["script"]]}
        require(receipt.get("source_files") == expected, "Material source hash mismatch")
        require(type(receipt.get("checks")) is int and receipt["checks"] > 0 and receipt.get("failures") == [],
                "Material fixture assertions failed or absent")
        queued, diagnostics = receipt.get("queued_observations", []), receipt.get("diagnostics", [])
        require(len(queued) == len(diagnostics) == 1, "Selected material case missing or repeated")
        if len(queued) == len(diagnostics) == 1:
            q, d = queued[0], diagnostics[0]
            independent_current, independent_previous = expected_history_hashes(arm["slots"])
            require(q.get("expected_current_sha256") == independent_current
                    and q.get("expected_previous_sha256") == independent_previous,
                    "Frozen expected histories differ from independent CPU reconstruction")
            require(q.get("channels") == arm["channels"] and q.get("slots") == arm["slots"]
                    and q.get("policy") == arm["policy"], "Material case selectors mismatch")
            require(q.get("queued_publications") == 6 * (arm["slots"] * 2 + 1), "Original publication burst differs")
            require(q.get("verified") is True and q.get("current_sha256") == q.get("expected_current_sha256")
                    and q.get("previous_sha256") == q.get("expected_previous_sha256"),
                    "Original first-read current/previous byte oracle failed")
            require(q.get("separate") is (arm["thread"] == "separate")
                    and q.get("render_gate_completed") is (arm["thread"] == "separate"), "Queue gate outcome differs")
            require(d.get("first_current", {}).get("sha256") == q.get("current_sha256")
                    and d.get("first_previous", {}).get("sha256") == q.get("previous_sha256"),
                    "Original first-read diagnostic join differs")
    return errors


def validate_display(display: dict, helper_code: int) -> bool:
    return (display.get("schema") == "pubpres-owned-display-v1"
            and display.get("server_reaped") is True and display.get("server_tree_closed") is True
            and display.get("forced_server_kill") is False and display.get("unexpected_server_members") is False
            and display.get("server_returncode") in (0, -15)
            and display.get("server_alive_before_requested_shutdown") is True
            and display.get("application_timeout") is False and display.get("failure") is None
            and display.get("application_returncode") == helper_code and display.get("returncode") == helper_code)


def run_arm(root: Path, output: Path, engine: dict, source: str, blobs: dict,
            arm: dict, platform: str, wrapper: Path | None) -> dict:
    folder = output / arm["id"]
    folder.mkdir()
    hashes = stage_project(blobs, arm, folder)
    nonce = uuid.uuid4().hex
    environment = {k: v for k, v in os.environ.items() if not k.startswith(("CYBERSAND_", "PUBPRES_"))}
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        location = folder / "profile" / key
        location.mkdir(parents=True)
        environment[key] = str(location)
    environment.update(PUBPRES_PROBE_SOURCE=source, PUBPRES_PROBE_NONCE=nonce,
                       CYBERSAND_MATERIAL_QUEUE_THREAD=arm["thread"])
    if arm["project"] == "font":
        environment.update(PUBPRES_FONT_PROBE_MODE=arm["mode"], PUBPRES_FONT_PROBE_MIPMAPS=str(int(arm["mipmaps"])),
                           PUBPRES_FONT_PROBE_OUTPUT=str(folder / "receipt.json"))
    else:
        environment.update(PUBPRES_QUEUED_CHANNELS=str(arm["channels"]), PUBPRES_QUEUED_SLOTS=str(arm["slots"]),
                           PUBPRES_QUEUED_POLICY=arm["policy"], PUBPRES_QUEUED_DIAGNOSTIC_OUTPUT=str(folder / "receipt.json"))
    driver = "opengl3" if platform == "linux" else "opengl3_angle"
    command = [engine["executable"], "--path", str(folder / "project"), "--rendering-method", "gl_compatibility",
               "--rendering-driver", driver, "--render-thread", arm["thread"], "--audio-driver", "Dummy",
               "--log-file", str(folder / "godot.log"), "--script", "res://" + arm["script"]]
    request = {"command": command, "source_commit": source, "nonce": nonce, "engine_sha256": engine["sha256"]}
    write_json(folder / "request.json", request)
    write_json(folder / "arm.json", {**arm, "source_commit": source, "nonce": nonce, "project_inputs_sha256": hashes,
                                   "native_independent": True, "child_timeout_seconds": CHILD_SECONDS})
    outer = [sys.executable, str(root / PREFIX / "run_probes.py"), "--child", str(folder / "request.json")]
    if wrapper is not None:
        outer = [sys.executable, str(wrapper), *outer]
        environment["PUBPRES_DISPLAY_RECEIPT"] = str(folder / "display-owner.json")
    outcome = {"id": arm["id"], "attempted": True, "passed": False, "errors": [], "terminal": None}
    started = time.monotonic()
    wrapper_code, wrapper_timeout = None, False
    try:
        with (folder / "wrapper.log").open("w", encoding="utf-8") as log:
            wrapper_code, wrapper_timeout = bounded_process(outer, env=environment, stdout=log, timeout=OUTER_SECONDS)
    except BaseException as error:
        outcome["terminal"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        write_json(folder / "outer-process.json", {"command": outer, "returncode": wrapper_code,
            "timed_out": wrapper_timeout, "timeout_seconds": OUTER_SECONDS,
            "elapsed_seconds": time.monotonic() - started, "terminal": outcome["terminal"]})
    errors = outcome["errors"]
    if wrapper_code != 0 or wrapper_timeout:
        errors.append("Bounded wrapper/child returned nonzero or timed out")
    process = {}
    try:
        process = json.loads((folder / "process.json").read_text(encoding="utf-8"))
        outcome["process"] = process
        if process.get("terminal_interruption"):
            outcome["terminal"] = process["terminal_interruption"]
        if (process.get("returncode") != 0 or process.get("timed_out") is not False
                or process.get("cleanup_complete") is not True or process.get("surviving_children_at_exit") is not False
                or process.get("error") or process.get("terminal_interruption")):
            errors.append("Actual Godot process did not complete cleanly")
        if process.get("source_commit") != source or process.get("nonce") != nonce or process.get("engine_sha256") != engine["sha256"]:
            errors.append("Actual Godot process identity differs")
    except (OSError, ValueError, TypeError) as error:
        errors.append("Missing or invalid actual process receipt: " + str(error))
    if wrapper is not None:
        try:
            display = json.loads((folder / "display-owner.json").read_text(encoding="utf-8"))
            outcome["display_lifecycle_valid"] = validate_display(display, 0 if not process or (
                process.get("returncode") == 0 and not process.get("timed_out")
                and not process.get("surviving_children_at_exit") and process.get("cleanup_complete")) else 1)
            if not outcome["display_lifecycle_valid"]:
                errors.append("Owned display lifecycle did not verify")
        except (OSError, ValueError, TypeError) as error:
            errors.append("Missing or invalid display-owner receipt: " + str(error))
    try:
        receipt = json.loads((folder / "receipt.json").read_text(encoding="utf-8"))
        errors.extend(receipt_errors(receipt, process, arm, source, nonce, engine["sha256"], hashes, platform))
        outcome["receipt_sha256"] = digest(folder / "receipt.json")
    except (OSError, ValueError, TypeError, KeyError) as error:
        errors.append("Missing or invalid script receipt: " + str(error))
    for name in ("stdout.log", "stderr.log", "godot.log"):
        path = folder / name
        if path.exists() and re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)|Parse Error:|Failed to load script|Failed loading resource:", path.read_text(encoding="utf-8", errors="replace")):
            errors.append("Strict Godot diagnostic in " + name)
    for name, expected in hashes.items():
        if digest(folder / "project" / name) != expected:
            errors.append("Staged source changed during execution: " + name)
    outcome["passed"] = not errors and outcome["terminal"] is None
    outcome["artifacts"] = {p.relative_to(folder).as_posix(): {"sha256": digest(p), "bytes": p.stat().st_size}
                            for p in sorted(folder.rglob("*")) if p.is_file()
                            and p.relative_to(folder).parts[0] not in ("profile", "project")}
    write_json(folder / "analysis.json", outcome)
    return outcome


def run_matrix(arms: list[dict], invoke, summary_path: Path, header: dict) -> dict:
    results = []
    terminal = None
    record = {}
    try:
        for arm in arms:
            if terminal:
                results.append({"id": arm["id"], "attempted": False, "passed": False,
                                "errors": ["Not run after terminal ownership/cancellation failure"], "terminal": terminal})
                continue
            try:
                item = invoke(arm)
            except Exception as error:
                item = {"id": arm["id"], "attempted": True, "passed": False,
                        "errors": [type(error).__name__ + ": " + str(error)], "terminal": None}
            except BaseException as error:
                terminal = type(error).__name__ + ": " + str(error)
                item = {"id": arm["id"], "attempted": True, "passed": False, "errors": [terminal], "terminal": terminal}
            results.append(item)
            terminal = terminal or item.get("terminal")
            write_json(summary_path, {**header, "matrix_finished": False, "all_passed": False, "arms": results})
    finally:
        record = {**header, "matrix_finished": len(results) == len(arms), "all_arms_attempted": all(
                  r["attempted"] for r in results) and len(results) == len(arms),
                  "all_passed": len(results) == len(arms) and all(r["passed"] for r in results),
                  "terminal": terminal, "arms": results}
        write_json(summary_path, record)
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=ROOT)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--platform", choices=tuple(ARCHIVES), required=True)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--display-wrapper", type=Path)
    args = parser.parse_args()
    actual_platform = "windows" if os.name == "nt" else "linux" if sys.platform.startswith("linux") else ""
    if args.platform != actual_platform:
        raise ValueError("Requested platform must match the executing host")
    root, output, executable = args.source_root.resolve(), args.output.resolve(), args.engine.resolve()
    wrapper = args.display_wrapper.resolve() if args.display_wrapper else None
    if (args.platform == "linux") != (wrapper is not None):
        raise ValueError("Linux requires owned display; Windows must use its own desktop without a wrapper")
    if output.exists():
        raise ValueError("Refusing to reuse or overwrite diagnostic evidence")
    blobs, identity = committed_bundle(root, args.source_sha, wrapper)
    engine = verify_engine(executable, args.platform)
    output.mkdir(parents=True)
    arms = matrix(args.platform)
    header = {"schema": "pubpres-render-probes-v1", **identity, "engine": engine, "platform": args.platform,
              "registered_arms": arms, "child_timeout_seconds": CHILD_SECONDS, "outer_timeout_seconds": OUTER_SECONDS,
              "acceptance": "NONE_DIAGNOSTIC_ONLY_DRAFT_HOLD",
              "scope": "No native build, gameplay, pacing, performance, package or physical GPU acceptance. Expected negative arms still fail."}
    write_json(output / "INPUTS.json", header)
    result = run_matrix(arms, lambda arm: run_arm(root, output, engine, args.source_sha, blobs, arm, args.platform, wrapper),
                        output / "SUMMARY.json", header)
    try:
        _, after = committed_bundle(root, args.source_sha, wrapper)
        if after != identity or digest(executable) != engine["sha256"]:
            raise ValueError("Runner/project/engine inputs changed during the matrix")
    except Exception as error:
        result.update(all_passed=False, postflight_error=str(error))
        write_json(output / "SUMMARY.json", result)
    print(json.dumps({"matrix_finished": result["matrix_finished"], "all_passed": result["all_passed"],
                      "arms": len(result["arms"]), "acceptance": header["acceptance"]}))
    return 0 if result["all_passed"] else 1


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--child":
        raise SystemExit(run_child(Path(sys.argv[2]).resolve()))
    raise SystemExit(main())
