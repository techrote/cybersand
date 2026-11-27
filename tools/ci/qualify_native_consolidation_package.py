"""Exercise native consolidation features in a fresh, byte-verified Windows package."""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import signal
import struct
import subprocess
import sys
import time
import zipfile

import mainline_evaluator as delivery


GRAPHICAL = ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle"]
ENGINE_ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|(?m:^ERROR:)|GDExtension library not found|Failed to load script|ObjectDB instances leaked")


def isolated_environment(output: Path, source: str) -> dict:
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("CYBERSAND_", "SWARM004_", "WB_ACTOR_"))}
    env["CYBERSAND_SOURCE_REVISION"] = source
    for variable, relative in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("XDG_DATA_HOME", "data"),
                               ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
        folder = output / "profile" / relative
        folder.mkdir(parents=True, exist_ok=True)
        env[variable] = str(folder)
    return env


def execute(base: list[str], flags: list[str], env: dict, log: Path, timeout: int) -> tuple[dict, str]:
    """The graphical binary is the engine PID observed by Godot, including on Windows."""
    command = base + flags
    started = time.monotonic()
    timed_out = False
    with log.open("xb") as stream:
        process = subprocess.Popen(command, cwd=Path(base[0]).parent, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=os.name != "nt")
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
        finally:
            if process.poll() is None:
                try:
                    if os.name == "nt":
                        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                       stdout=subprocess.DEVNULL, check=True, timeout=20)
                    else:
                        os.killpg(process.pid, signal.SIGKILL)
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.wait(timeout=20)
    content = log.read_text(encoding="utf-8", errors="replace")
    receipt = {"command": command, "pid": process.pid, "returncode": process.returncode,
               "timed_out": timed_out, "timeout_seconds": timeout,
               "wall_seconds": round(time.monotonic() - started, 3), "log_sha256": delivery.sha(log)}
    delivery.write(log.with_suffix(".process.json"), receipt)
    delivery.require(not timed_out, f"Extracted process exceeded its {timeout}s watchdog. See {log}")
    delivery.require(process.returncode == 0 and not ENGINE_ERRORS.search(content), f"Extracted process failed. See {log}")
    return receipt, content


def assertions(content: str, prefix: str = "", *, schema: str = "") -> dict:
    rows = [json.loads(line[len(prefix):]) for line in content.splitlines()
            if line.startswith(prefix if prefix else "{")]
    if schema:
        rows = [row for row in rows if isinstance(row, dict) and row.get("schema") == schema]
    delivery.require(len(rows) == 1, "Missing or duplicate assertion receipt for " + (prefix or schema))
    row = rows[0]
    delivery.require(isinstance(row, dict) and type(row.get("checks")) is int and row["checks"] > 0
                     and row.get("failures") == [], "Incomplete fixture assertions for " + (prefix or schema))
    return row


def require_distinct(first: dict, second: dict) -> None:
    delivery.require(first["pid"] != second["pid"], "Fresh reopening must use a distinct engine process")


class Extraction:
    def __init__(self, package: Path, output: Path, manifest: dict, product: Path):
        self.package, self.output, self.manifest, self.product = package, output, manifest, product
        payload = package / "workbench"
        self.project = payload / "godot"
        self.engine = payload / "Godot_v4.7-stable_win64.exe"
        self.base = [str(self.engine), "--audio-driver", "Dummy", "--path", str(self.project)]
        self.processes = {}
        self.policy = delivery.read(self.project / "tests/support/ci_execution_policy.json")["watchdogs"]

    def environment(self, name: str) -> tuple[Path, dict]:
        output = self.output / name
        output.mkdir()
        return output, isolated_environment(output, self.manifest["source_commit"])

    def fixture(self, output: Path, phase: str, script: str, env: dict, timeout: int,
                arguments: tuple[str, ...] = (), *, graphics: list[str] = GRAPHICAL) -> tuple[dict, str]:
        name = "workbench/godot/tests/" + script + ".gd"
        delivery.require(name in self.manifest["files_sha256"], "Fixture is absent from the delivered source inventory: " + name)
        flags = [*graphics, "--script", "res://tests/" + script + ".gd"]
        if arguments:
            flags.extend(("--", *arguments))
        process, content = execute(self.base, flags, env, output / (phase + ".log"), timeout)
        self.processes[output.name + "/" + phase] = process
        return process, content

    def load_validator(self, directory: str, module: str):
        # Each checkout is clean and source-bound before it supplies a receipt validator.
        sys.path.insert(0, str(self.product / directory))
        validator = importlib.import_module(module)
        delivery.require(Path(validator.__file__).resolve() == (self.product / directory / (module + ".py")).resolve(),
                         "Qualification validator resolved outside the admitted product checkout")
        return validator

    def complex_seconds(self) -> int:
        return sum(self.policy[key] for key in ("complex_fixture_seconds", "operation_seconds",
                                                "diagnostic_capture_seconds", "terminate_grace_seconds"))


def gentek(extraction: Extraction) -> dict:
    output, env = extraction.environment("gentek_2048")
    env.update(CYBERSAND_ARCHITECTURE_OUTPUT=str(output), CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS="1")
    processes = []
    for phase in ("author", "reopen"):
        process, content = extraction.fixture(output, phase, "fixtures/gentek2048_workbench",
                                              dict(env, CYBERSAND_GENTEK2048_PHASE=phase), 1800)
        processes.append(process)
        delivery.require(re.search(rf"^GENTEK2048_RESULTS phase={phase} checks=[1-9][0-9]* failures=0 complete=true$", content, re.M),
                         f"Missing completion marker for {phase}")
    require_distinct(*processes)
    summary = {}
    cases = {}
    for phase in ("author", "reopen"):
        detail = delivery.read(output / f"gentek2048-{phase}.json")
        rows = [row for row in detail["cases"] if row.get("case", "").startswith("gentek2048-")]
        delivery.require(detail["phase"] == phase and detail["failures"] == 0 and detail["complete"] is True
                         and detail["native_runtime"] is True and detail["display"] == "Windows"
                         and len(rows) == 2 and {row["case"] for row in rows} == {"gentek2048-cathedral", "gentek2048-mixed"},
                         f"Incomplete native or display receipts for {phase}")
        for row in rows:
            delivery.require(row["phase"] == phase and row["material_bytes"] == 2048**2 and row["native_chunks"] == 256
                             and row["zones"] == 256 and row["edits"] >= 2, "Incomplete map, chunk, planning or edit proof")
        cases[phase] = {row["case"]: {key: row[key] for key in ("origin", "seed", "modules", "zones", "native_chunks",
                        "native_material_sha256", "recipe_sha256", "material_bytes", "edits")} for row in rows}
    delivery.require(cases["author"] == cases["reopen"], "Fresh process did not restore both authored maps")
    summary["gentek2048"] = cases
    summary["framebuffers_sha256"] = {}
    for kind in ("cathedral", "mixed"):
        for phase in ("author", "zones", "reopen"):
            path = output / f"gentek2048-{kind}-{phase}.png"
            delivery.require(path.is_file() and path.stat().st_size > 0, "Missing graphical evidence " + path.name)
            summary["framebuffers_sha256"][path.name] = delivery.sha(path)
    return summary


def material_profile_evidence(output: Path, report: dict) -> dict:
    frames = output / "frames"
    delivery.require(delivery.read(frames / "native-readback.json") == report and report.get("display") == "Windows",
                     "Material readback differs from the graphical Windows process")
    expected = {"current-scene-density", "current-scene-1000x650", "current-scene-1280x720",
                "density-sorter", "viscosity-channel", "reaction-contact", "industrial-loop"}
    rows = report.get("frames", [])
    delivery.require(len(rows) == len(expected) and {row["name"] for row in rows} == expected,
                     "Missing or duplicated graphical material captures")
    hashes = {}
    for row in rows:
        filename = row["name"] + ".png"
        path = frames / filename
        delivery.require(row["file"] == filename and delivery.sha(path) == row["sha256"],
                         "Material capture differs from its native receipt")
        with path.open("rb") as stream:
            header = stream.read(24)
        delivery.require(len(header) == 24 and header[:16] == b"\x89PNG\r\n\x1a\n\0\0\0\rIHDR",
                         "Material capture is not a PNG with an IHDR")
        width, height = struct.unpack(">II", header[16:24])
        delivery.require((width, height) == (row["width"], row["height"]) and width >= 400 and height >= 300,
                         "Material framebuffer dimensions differ from the native receipt")
        hashes[filename] = row["sha256"]
    witnesses = report["native_witnesses"]
    kinds = {row["kind"] for row in witnesses}
    delivery.require({"density", "viscosity", "reaction", "owner-adversaries", "ordinary-demo"} <= kinds
                     and any(row["kind"] == "ordinary-workbench" and all(row.get(key) is True for key in
                             ("native_apply_while_running", "configuration_revert_preserves_cells",
                              "ordinary_paint_save_reopen", "separate_profile_saved_and_reloaded", "graphical"))
                             for row in witnesses), "Missing native or mounted Workbench material witnesses")
    return {"checks": report["checks"], "framebuffers_sha256": hashes, "native_witnesses": witnesses,
            "readback_sha256": delivery.sha(frames / "native-readback.json")}


def material(extraction: Extraction) -> dict:
    output, env = extraction.environment("material_audition")
    _, content = extraction.fixture(output, "mixed-actors", "test_material_audition_ambient_integration",
                                     env, extraction.complex_seconds())
    result = assertions(content, "MATERIAL_AMBIENT_INTEGRATION ")
    delivery.require(any(phase["native_ticks"] >= 24 and phase["physical_ticks"] >= 24
                         for phase in result.get("phases", [])), "Missing coupled material/actor progression")
    delivery.write(output / "mixed-actors.json", result)
    validator = extraction.load_validator("tools/ci", "run_material_audition_qualification")
    profile_env = dict(env, MAT_AUDITION_EVIDENCE_DIR=str(output / "frames"))
    for key in ("MATERIAL_LAB_CACHED_ONLY", "MATERIAL_LAB_SKIP_COMPILE"):
        profile_env.pop(key, None)
    _, content = extraction.fixture(output, "named-profile", "test_material_audition", profile_env, 1200,
                                    graphics=[*GRAPHICAL, "--max-fps", "30"])
    report = validator.completion(content, "MATERIAL_AUDITION_RESULT")
    profiles = material_profile_evidence(output, report)
    return {"checks": result["checks"], "phases": result["phases"], "named_profile": profiles}


def actors(extraction: Extraction) -> dict:
    output, env = extraction.environment("actor_compose")
    validator = extraction.load_validator("tools/ci", "run_workbench_actor_qualification")
    capacity_path = output / "capacity.json"
    _, content = extraction.fixture(output, "capacity", "test_workbench_actor_capacity",
                                     dict(env, CYBERSAND_ACTOR_CAPACITY_REPORT=str(capacity_path)), extraction.complex_seconds())
    capacity = assertions(content, "WB_ACTOR_CAPACITY ")
    delivery.require(delivery.read(capacity_path) == capacity and capacity.get("display_server") == "Windows",
                     "Capacity report differs from the actual graphical engine receipt")
    rows = validator.sandbox_capacity(capacity)
    _, content = extraction.fixture(output, "manipulation", "test_workbench_actor_manipulation",
                                     env, extraction.policy["ordinary_case_seconds"])
    manipulation = assertions(content, "WB_ACTOR_MANIPULATION_RESULT ")
    measured = manipulation["measurements"]
    delivery.require(measured["barrel"]["rapier_ticks"] > 0 and measured["articulated"]["connection_ok"] is True
                     and all(measured[name]["rapier_ticks"] > 0 and measured[name]["finite"] is True
                             for name in ("stuntbuggy_wheel", "trialsbike_wheel")),
                     "Missing mounted body, joint or physical wheel manipulation")
    delivery.write(output / "manipulation.json", manipulation)
    return {"capacity_checks": capacity["checks"], "workloads": len(rows),
            "capacity_report_sha256": delivery.sha(capacity_path), "manipulation_checks": manipulation["checks"]}


def swarm(extraction: Extraction) -> dict:
    output, env = extraction.environment("swarm")
    validator = extraction.load_validator("tools/swarm45", "shared")
    script = validator.legacy.UI_SCRIPT
    generator = delivery.read(extraction.project / "tools/swarm004-runtime.windows.json")
    cli = extraction.project / "tools/gentek_reciprocal.exe"
    delivery.require(generator["artifact"] == "godot/tools/gentek_reciprocal.exe"
                     and delivery.sha(cli) == generator["sha256"]
                     and (extraction.product / generator["artifact"]).is_file()
                     and delivery.source_contract_sha(extraction.project / "tools/swarm004-runtime.windows.json")
                     == delivery.source_contract_sha(extraction.product / "godot/tools/swarm004-runtime.windows.json"),
                     "Delivered reciprocal generator differs from the source-bound Windows runtime")
    delivery.require(delivery.source_contract_sha(extraction.project / script) ==
                     delivery.source_contract_sha(extraction.product / "godot" / script), "Wrong reciprocal UI fixture")
    script_sha = delivery.sha(extraction.project / script)
    env = validator.legacy.isolated_environment(env, output, "reciprocal")
    reports = {}
    for phase in ("create", "reopen"):
        process, _ = extraction.fixture(output, phase, script.removeprefix("tests/").removesuffix(".gd"),
                                        dict(env, SWARM004_UI_MODE=phase), 420, graphics=[*GRAPHICAL, "--max-fps", "60"])
        report = delivery.read(output / (phase + ".json"))
        errors = validator.ui_report_errors(report, phase, "reciprocal", generator["source"],
                                             generator["sha256"], script_sha, "windows")
        delivery.require(report.get("process_id") == process["pid"] and not errors,
                         "Reciprocal UI receipt has incorrect owner or invalid observations: " + str(errors))
        reports[phase] = report
    proof = validator.legacy.example_evidence(output, reports)
    delivery.require(proof["passed"] is True, "Reciprocal reopening: " + str(proof["validation_errors"]))
    return {"generator_source": generator["source"], "generator_sha256": generator["sha256"],
            "fixture_sha256": script_sha, "checks": {phase: row["checks"] for phase, row in reports.items()},
            "persistence": proof}


def areas(extraction: Extraction) -> dict:
    output, env = extraction.environment("persistent_areas")
    validator = extraction.load_validator("tools/ci", "run_persistent_area_ramcache_qualification")
    processes, results = [], {}
    for phase in ("write", "reopen"):
        args = ("--persistent-require-graphics", "--persistent-start-paused", "--persistent-test-workers=1",
                "--ramcache-hot-samples=30", "--ramcache-warm-samples=30", "--persistent-test-mode=" + phase,
                "--persistent-profile=" + str(output / "area-store"), "--persistent-evidence=" + str(output))
        process, content = extraction.fixture(output, phase, "test_persistent_area_ramcache", env, 1800, args,
                                             graphics=["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"])
        processes.append(process)
        item = {}
        for name, marker in (("ramcache", "GEN006_RAMCACHE "), ("workbench", "PERSISTENT_AREAS_WORKBENCH ")):
            logged = assertions(content, marker)
            report = delivery.read(output / (name + "-" + phase + ".json"))
            delivery.require(logged["pid"] == report["process_id"] == process["pid"] and
                             logged["mode"] == report["mode"] == phase and logged["graphical"] is report["graphical"] is True
                             and report["failures"] == [] and report.get("checks", report.get("assertions", 0)) > 0,
                             "Area receipt has incorrect process, phase or graphical observations")
            item[name + "_checks"] = logged["checks"]
            if name == "ramcache" and phase == "write":
                for kind in ("hot_samples", "warm_samples"):
                    delivery.require(len(report[kind]) == logged[kind] == 30, "Missing resident return samples")
                    item[kind] = validator.statistics(report[kind])
        results[phase] = item
    require_distinct(*processes)
    expected = delivery.read(output / "expected-reopen.json")
    delivery.require(set(expected["areas"]) == {"a", "b", "c"}
                     and all(delivery.exact_hash(row["native_sha256"], 64) and delivery.exact_hash(row["authored_source_sha256"], 64)
                             for row in expected["areas"].values()),
                     "Missing three-area durable native and authored identities")
    results["durable_frontiers"] = expected
    return results


def objectshard(extraction: Extraction) -> dict:
    output, env = extraction.environment("objectshard_m4")
    seconds = extraction.policy["graphical_case_seconds"]
    flags = ("--objectshard-m4-workbench",)
    author, content = extraction.fixture(output, "author", "test_object_shard_m4_workbench_completion", env, seconds, flags)
    first = assertions(content, schema="objectshard-m4-workbench-completion-v1")
    witness = first["observations"]["authored_reopen"]
    delivery.require(first["source_commit"] == extraction.manifest["source_commit"] and witness["process_id"] == author["pid"]
                     and all(delivery.exact_hash(witness[key], 64) for key in ("file_sha256", "installed_sha256")),
                     "Missing ObjectShard authored save identity")
    reopen_env = dict(env, CYBERSAND_M4_AUTHOR_PID=str(author["pid"]),
                      CYBERSAND_M4_AUTHORED_FILE=witness["file_sha256"], CYBERSAND_M4_INSTALLED_SETUP=witness["installed_sha256"])
    reopen, content = extraction.fixture(output, "reopen", "fixtures/object_shard_m4_authored_reopen", reopen_env, seconds, flags)
    second = assertions(content, schema="objectshard-m4-fresh-authored-reopen-v1")
    require_distinct(author, reopen)
    delivery.require(second["process_id"] == reopen["pid"], "ObjectShard reopen receipt has the wrong process owner")
    launcher = "Open Structural Workbench.cmd"
    launch_receipt = output / "launcher.json"
    delivery.require(launcher in extraction.manifest["files_sha256"], "Structural launcher missing from the package")
    process, _ = execute([os.environ["COMSPEC"], "/d", "/c", "call"],
                         [str(extraction.package / launcher), "--audio-driver", "Dummy", "--script",
                          "res://tests/probe_object_shard_workbench_package.gd"],
                         dict(env, OBJECTSHARD_LAUNCH_RECEIPT=str(launch_receipt)), output / "launcher.log",
                         extraction.manifest["execution_budget"]["launcher_watchdogs"]["workbench"])
    extraction.processes[output.name + "/launcher"] = process
    launched = delivery.read(launch_receipt)
    delivery.require(launched.get("schema") == "objectshard-m4-workbench-package-launch-v1"
                     and launched.get("source_commit") == extraction.manifest["source_commit"]
                     and launched.get("failures") == 0 and launched.get("checks", 0) >= 8
                     and launched.get("rendering_driver") == "opengl3_angle" and launched.get("scene_id") == "tower"
                     and launched.get("host") == "ordinary-workbench" and launched.get("startup_scene") == "res://feature_launcher.tscn"
                     and {"--shared-workbench", "--objectshard-m4-workbench", "--object-shard-scene=tower"}
                     <= set(launched.get("launch_arguments", [])), "Shipped structural launcher failed native tower admission")
    return {"author_checks": first["checks"], "reopen_checks": second["checks"], "authored_reopen": witness,
            "launcher_checks": launched["checks"], "launch_receipt_sha256": delivery.sha(launch_receipt)}


FEATURES = {"gentek_2048": gentek, "material_audition": material, "actor_compose": actors,
            "swarm": swarm, "persistent_areas": areas, "objectshard_m4": objectshard}
LANES = {"authoring": ("gentek_2048", "material_audition", "swarm"),
         "worlds": ("actor_compose", "objectshard_m4", "persistent_areas")}
PHASES = {"gentek_2048": ("author", "reopen"), "material_audition": ("mixed-actors", "named-profile"),
          "actor_compose": ("capacity", "manipulation"), "swarm": ("create", "reopen"),
          "persistent_areas": ("write", "reopen"), "objectshard_m4": ("author", "reopen", "launcher")}


def bind_features(manifest: dict, request: dict) -> list[str]:
    features = manifest.get("integrated_features")
    delivery.require(isinstance(features, list) and all(type(key) is str and key in FEATURES for key in features)
                     and features == sorted(set(features)) and features == request.get("integrated_features")
                     and all(manifest.get(key) == request[key] for key in ("source_commit", "source_tree")),
                     "Manifest feature inventory or source differs from the admitted request")
    return features


def run(package: Path, output: Path, request: dict, product: Path, lane: str) -> dict:
    delivery.require(os.name == "nt", "Extracted native qualification requires Windows")
    manifest = delivery.verify(package, pristine=True)
    features = [name for name in bind_features(manifest, request) if name in LANES[lane]]
    delivery.require(delivery.git(product, "rev-parse", "HEAD") == manifest["source_commit"]
                     and delivery.git(product, "rev-parse", "HEAD^{tree}") == manifest["source_tree"]
                     and not delivery.git(product, "status", "--porcelain", "--", "tools/ci", "tools/swarm45", "tools/swarm006"),
                     "Qualification validators must come from the clean admitted product source")
    output.mkdir(parents=True, exist_ok=False)
    extraction = Extraction(package, output, manifest, product)
    env = isolated_environment(output, manifest["source_commit"])
    extraction.processes["import"], _ = execute(extraction.base, ["--headless", "--editor", "--quit"],
                                               env, output / "import.log", extraction.policy["godot_import_seconds"])
    results = {feature: FEATURES[feature](extraction) for feature in features}
    delivery.verify(package)
    return {"status": "passed", "lane": lane, "source_commit": manifest["source_commit"], "source_tree": manifest["source_tree"],
            "integrated_features": features, "feature_results": results, "processes": extraction.processes,
            "package_manifest_sha256": delivery.sha(package / delivery.MANIFEST)}


def bind_delivery(archive: Path, receipt: dict, request: dict) -> dict:
    delivery.require(receipt["status"] == "passed" and receipt["archive"] == archive.name
                     and receipt["archive_size"] == archive.stat().st_size and receipt["archive_sha256"] == delivery.sha(archive)
                     and all(receipt[key] == request[key] for key in ("source_commit", "source_tree"))
                     and receipt["run_id"] == os.environ["GITHUB_RUN_ID"] and receipt["run_attempt"] == os.environ["GITHUB_RUN_ATTEMPT"],
                     "Delivery receipt does not match this source, archive or job attempt")
    with zipfile.ZipFile(archive) as bundle:
        entries = [item for item in bundle.infolist() if item.filename == delivery.MANIFEST]
        delivery.require(len(entries) == 1, "Archive lacks a unique delivery manifest")
        raw = bundle.read(entries[0])
    delivery.require(hashlib.sha256(raw).hexdigest() == receipt["manifest_sha256"], "Wrong package manifest")
    manifest = json.loads(raw)
    bind_features(manifest, request)
    return manifest


def verify_persistent_launcher(proof: dict | None, receipt: dict, features: list[str]) -> None:
    if "persistent_areas" not in features:
        delivery.require(proof is None, "Unrequested Persistent Areas launcher receipt")
        return
    delivery.require(isinstance(proof, dict)
                     and proof.get("schema") == "cybersand-mainline-persistent-launcher-v1"
                     and proof.get("status") == "passed" and proof.get("launcher") == "Open Persistent Areas.cmd"
                     and proof.get("renderer") == "ANGLE" and type(proof.get("exit_code")) is int and proof["exit_code"] == 0
                     and type(proof.get("durable_areas")) is int and proof["durable_areas"] == 3
                     and isinstance(proof.get("session_id"), str) and bool(proof["session_id"].strip())
                     and type(proof.get("revision")) is int and proof["revision"] > 0
                     and all(proof.get(key) == receipt[key] for key in
                             ("source_commit", "archive_sha256", "manifest_sha256", "run_id", "run_attempt")),
                     "Integrated areas require a matching durable three-area launcher receipt from this run")


def join(lanes: dict, receipt: dict, request: dict, persistent_launcher: dict | None = None) -> dict:
    delivery.require(set(lanes) == set(LANES), "Both extracted qualification lane receipts are required")
    expected = request["integrated_features"]
    verify_persistent_launcher(persistent_launcher, receipt, expected)
    results = {}
    for name, gate in lanes.items():
        assigned = [feature for feature in expected if feature in LANES[name]]
        processes = gate.get("processes", {})
        roster = {"import", *(feature + "/" + phase for feature in assigned for phase in PHASES[feature])}
        delivery.require(gate.get("status") == "passed" and gate.get("lane") == name
                         and all(gate.get(key) == receipt[key] for key in
                                 ("source_commit", "source_tree", "archive_sha256", "run_id", "run_attempt"))
                         and gate.get("package_manifest_sha256") == receipt["manifest_sha256"],
                         "Extracted lane is not a passing receipt for this archive, source and run attempt: " + name)
        details = gate.get("feature_results", {})
        delivery.require(gate.get("integrated_features") == assigned and set(details) == set(assigned)
                         and all(isinstance(value, dict) and value for value in details.values())
                         and set(processes) == roster and not set(assigned).intersection(results),
                         "Extracted lane has missing, duplicated or unexpected programmes or processes: " + name)
        for process in processes.values():
            delivery.require(type(process.get("pid")) is int and process["pid"] > 0 and type(process.get("returncode")) is int
                             and process["returncode"] == 0 and process.get("timed_out") is False
                             and delivery.exact_hash(process.get("log_sha256"), 64),
                             "Extracted qualification has an incomplete process receipt")
        results.update(gate["feature_results"])
    delivery.require(set(results) == set(expected), "Extracted programmes do not cover the admitted feature inventory")
    return {"status": "passed", "integrated_features": expected, "feature_results": results,
            "lanes": {name: {"integrated_features": gate["integrated_features"], "processes": gate["processes"]}
                      for name, gate in lanes.items()},
            "package_manifest_sha256": receipt["manifest_sha256"],
            **{key: receipt[key] for key in ("source_commit", "source_tree", "archive_sha256", "run_id", "run_attempt")}}


def main(argv: list[str]) -> None:
    joining = argv[:1] == ["join"]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--delivery-receipt", type=Path, required=True)
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    if joining:
        for lane in LANES:
            parser.add_argument("--" + lane, type=Path, required=True)
        parser.add_argument("--persistent-launcher", type=Path)
    else:
        parser.add_argument("--extracted", type=Path, required=True)
        parser.add_argument("--product-root", type=Path, required=True)
        parser.add_argument("--lane", choices=LANES, required=True)
    args = parser.parse_args(argv[1:] if joining else argv)
    request = delivery.request(args.request)
    receipt = delivery.read(args.delivery_receipt)
    bind_delivery(args.archive, receipt, request)
    if joining:
        records = {lane: delivery.read(getattr(args, lane)) for lane in LANES}
        launcher = delivery.read(args.persistent_launcher) if args.persistent_launcher else None
        result = join(records, receipt, request, launcher)
        if launcher is not None:
            result["persistent_launcher"] = launcher
            result["persistent_launcher_sha256"] = delivery.sha(args.persistent_launcher)
        result["qualification_receipts_sha256"] = {lane: delivery.sha(getattr(args, lane)) for lane in LANES}
        delivery.write(args.output, result)
        return
    delivery.extract(args.archive, args.extracted)
    delivery.require(delivery.sha(args.extracted / delivery.MANIFEST) == receipt["manifest_sha256"],
                     "Wrong extracted package manifest")
    result = run(args.extracted.resolve(), args.output.resolve(), request, args.product_root.resolve(), args.lane)
    result.update(archive_sha256=receipt["archive_sha256"], run_id=receipt["run_id"], run_attempt=receipt["run_attempt"])
    delivery.write(args.output / "qualification.json", result)


if __name__ == "__main__":
    main(sys.argv[1:])
