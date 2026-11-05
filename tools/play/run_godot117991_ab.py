#!/usr/bin/env python3
"""Diagnostic-only Godot #117991 Windows A/B experiment for CyberSand PR #379.

This harness never changes CyberSand production source or the accepted runtime pin.
It consumes a frozen CyberSand project template, two isolated Godot source checkouts,
and the already source-qualified PR379 crash broker built by the official-reference
campaign. Experimental engine identities are recorded truthfully and separately.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import ntpath
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time

APP_SHA = "e7e404b696fb9fc48cdadc95a69baf3a6f5fc6d1"
APP_TREE = "3b5acd41fd7fb49ac8b06c94719fa1a700d8fd57"
GODOT_SHA = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
UPSTREAM_PATCH_COMMIT = "0dd6299f7146362d36b130ac1dc42406cfb3ede6"
FIXTURE = "test_liquid_desktop_default_host"
PATCH_STANZA = "#ifdef TOOLS_ENABLED\n\tbase_cache = Ref<GDScript>();\n#endif\n\tbase = Ref<GDScript>();"
ENGINE_BASENAME = "Godot_v4.7-stable_win64.exe"
BUILT_ENGINE = "godot.windows.editor.x86_64.llvm.exe"
BUILD_ARGS = [
    "platform=windows", "target=editor", "arch=x86_64", "use_llvm=yes",
    "windows_subsystem=console", "production=yes", "debug_symbols=yes",
    "lto=none", "-j2",
]
PILOT = ["A", "B", "B", "A", "A", "B"]
EXPANSION = ["B", "A", "A", "B", "B", "A", "A", "B", "B", "A", "A", "B", "B", "A"]
HISTORICAL_RVA = 0x03E1E7C1
ACCESS_VIOLATION = 0xC0000005


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def identity(path: Path) -> dict:
    require(path.is_file(), f"Missing evidence input: {path}")
    return {"path": str(path.resolve()), "sha256": sha256(path), "bytes": path.stat().st_size}


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def git(root: Path, *args: str, check: bool = True) -> str:
    result = subprocess.run(["git", "-C", str(root), *args], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                            errors="replace", check=False)
    if check and result.returncode:
        raise RuntimeError(f"git {' '.join(args)} failed in {root}:\n{result.stdout}")
    return result.stdout.strip()


def clean_source(root: Path, expected: str, *, allow_patch: bool = False) -> dict:
    head = git(root, "rev-parse", "HEAD")
    require(head == expected, f"Wrong source commit in {root}: {head}")
    status = git(root, "status", "--porcelain=v1", "--untracked-files=all")
    if allow_patch:
        names = [line for line in git(root, "diff", "--name-only").splitlines() if line]
        require(names == ["modules/gdscript/gdscript.cpp"], f"Counterfactual source scope differs: {names}")
        numstat = git(root, "diff", "--numstat", "--", "modules/gdscript/gdscript.cpp").split()
        require(numstat[:2] == ["5", "0"], f"Counterfactual patch is not exactly +5/-0: {numstat}")
        require(git(root, "diff", "--check") == "", "Counterfactual patch fails git diff --check")
        text = (root / "modules/gdscript/gdscript.cpp").read_text(encoding="utf-8")
        require(text.count(PATCH_STANZA) == 1, "Reviewed #117991 stanza missing or duplicated")
        require("??" not in status, "Counterfactual checkout contains untracked inputs")
    else:
        require(status == "", f"Control source is not clean:\n{status}")
        text = (root / "modules/gdscript/gdscript.cpp").read_text(encoding="utf-8")
        require(PATCH_STANZA not in text, "Unmodified control already contains #117991 stanza")
    return {"commit": head, "tree": git(root, "rev-parse", "HEAD^{tree}"), "status": status}


def apply_counterfactual(root: Path, patch: Path) -> dict:
    require(git(root, "status", "--porcelain=v1", "--untracked-files=all") == "",
            "Counterfactual checkout must be pristine before patching")
    checked = subprocess.run(["git", "-C", str(root), "apply", "--check", str(patch.resolve())],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             encoding="utf-8", errors="replace", check=False)
    require(checked.returncode == 0, "Reviewed #117991 patch does not apply exactly:\n" + checked.stdout)
    applied = subprocess.run(["git", "-C", str(root), "apply", str(patch.resolve())],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             encoding="utf-8", errors="replace", check=False)
    require(applied.returncode == 0, "Applying reviewed #117991 patch failed:\n" + applied.stdout)
    source = clean_source(root, GODOT_SHA, allow_patch=True)
    diff = git(root, "diff", "--no-ext-diff", "--no-color", "--", "modules/gdscript/gdscript.cpp")
    source.update({"patch": identity(patch), "upstream_patch_commit": UPSTREAM_PATCH_COMMIT,
                   "effective_diff_sha256": hashlib.sha256((diff + "\n").encode()).hexdigest(),
                   "effective_diff": diff})
    return source


def build_variant(label: str, source: Path, evidence: Path, scons: str) -> dict:
    directory = evidence / "builds" / label.lower()
    directory.mkdir(parents=True, exist_ok=False)
    log = directory / "build.log"
    command = [scons, *BUILD_ARGS]
    began = time.perf_counter()
    with log.open("wb") as stream:
        process = subprocess.run(command, cwd=source, stdout=stream, stderr=subprocess.STDOUT,
                                 check=False, timeout=7200)
    elapsed = time.perf_counter() - began
    record = {"variant": label, "command": command, "cwd": str(source.resolve()),
              "exit_code": process.returncode, "seconds": elapsed, "log": identity(log)}
    write_json(directory / "build.json", record)
    require(process.returncode == 0, f"Godot {label} build failed with exit {process.returncode}")
    engine = source / "bin" / BUILT_ENGINE
    require(engine.is_file() and engine.stat().st_size > 0, f"Godot {label} engine output missing")
    pdbs = sorted((source / "bin").glob("*.pdb"))
    require(pdbs, f"Godot {label} debug-symbol PDB was not produced")
    preferred = [p for p in pdbs if p.stem in (Path(BUILT_ENGINE).stem, "godot.windows.editor.x86_64.llvm")]
    pdb = preferred[0] if preferred else pdbs[0]
    version = subprocess.run([str(engine), "--version"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, encoding="utf-8", errors="replace", timeout=60, check=False)
    record.update({"engine": identity(engine), "pdb": identity(pdb),
                   "version_exit": version.returncode, "version_output": version.stdout.strip()})
    write_json(directory / "build.json", record)
    require(version.returncode == 0 and version.stdout.strip().startswith("4.7"),
            f"Godot {label} produced an unexpected version: {version.stdout!r}")
    return record | {"engine_path": str(engine.resolve()), "pdb_path": str(pdb.resolve())}


def import_apparatus(app: Path):
    sys.path.insert(0, str((app / "tools/play").resolve()))
    import run_windows_crash_capture as apparatus  # type: ignore
    import windows_crash_contract as contract  # type: ignore
    return apparatus, contract


def module_rva(capture: dict, engine: Path) -> int | None:
    target = ntpath.normcase(ntpath.normpath(str(engine.resolve())))
    rip = capture["identity"]["rip"]
    rows = [row for row in capture["identity"]["modules"]
            if ntpath.normcase(ntpath.normpath(row["path"])) == target]
    if len(rows) != 1:
        return None
    row = rows[0]
    return rip - row["base"] if row["base"] <= rip < row["base"] + row["bytes"] else None


def symbolize(symbolizer: Path, engine: Path, pdb: Path, rva: int | None) -> dict | None:
    if rva is None or not symbolizer.is_file():
        return None
    command = [str(symbolizer), "--obj", str(engine), "--pdb", str(pdb),
               "--functions=linkage", "--inlining", "--pretty-print", hex(rva)]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace", timeout=30, check=False)
    return {"command": command, "exit_code": result.returncode, "output": result.stdout.strip()}


def runtime_bindings(project: Path) -> dict:
    paths = [
        project / "addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
        project / "addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
    ]
    return {str(path.resolve()): {"sha256": sha256(path), "bytes": path.stat().st_size} for path in paths}


def snapshot_project(project: Path) -> dict:
    fixture = project / "tests" / f"{FIXTURE}.gd"
    runtimes = runtime_bindings(project)
    return {"fixture": identity(fixture), "runtimes": runtimes}


def classify_fixture(result: dict, log: str) -> str:
    footer = "LIQUID_DESKTOP_DEFAULT_HOST: 86 assertions; 0 failures" in log
    strict_error = re.search(r"SCRIPT ERROR:|ERROR:|\bskipped\b|^\s*SKIP\b", log, re.M | re.I) is not None
    if result.get("effective_exit") == 0 and not result.get("timed_out") and footer and not strict_error:
        return "pass"
    if result.get("effective_exit") == ACCESS_VIOLATION and not result.get("timed_out") and footer:
        return "post_footer_access_violation"
    if result.get("timed_out"):
        return "timeout"
    return "failure"


def run_trial(index: int, variant: str, template: Path, work: Path, evidence: Path,
              engine: Path, pdb: Path, broker: Path, environment: dict,
              apparatus, symbolizer: Path) -> dict:
    name = f"{index:02d}-{variant.lower()}"
    trial_work = work / name
    project = trial_work / "project"
    trial_out = evidence / "trials" / name
    require(not trial_work.exists() and not trial_out.exists(), f"Trial {name} already exists")
    trial_work.mkdir(parents=True)
    shutil.copytree(template, project)
    trial_out.mkdir(parents=True)
    source = snapshot_project(project)
    engines = {str(engine.resolve()): {"sha256": sha256(engine), "bytes": engine.stat().st_size,
                                      "requires_runtime": True}}
    runtimes = runtime_bindings(project)
    import_environment = {k: v for k, v in environment.items() if k.upper() != "JAVA_HOME"}
    report = {"schema": "pr379-godot117991-ab-trial-v1", "trial": index, "variant": variant,
              "source": source, "engine": identity(engine), "pdb": identity(pdb),
              "import_java_home_removed": not any(k.upper() == "JAVA_HOME" for k in import_environment),
              "status": "incomplete"}
    write_json(trial_out / "trial.json", report)
    try:
        imported = apparatus.execute(
            broker,
            [str(engine), "--headless", "--path", str(project), "--editor", "--quit"],
            trial_out / "import", apparatus.policy.IMPORT_MS, import_environment, engines, runtimes)
        report["import"] = {"effective_exit": imported["effective_exit"], "timed_out": imported["timed_out"],
                            "elapsed_ms": imported["elapsed_ms"], "captures": len(imported["captures"])}
        if imported["effective_exit"] != 0 or imported["timed_out"]:
            report.update(status="import_failure", completed=True)
            return report
        fixture = apparatus.execute(
            broker,
            [str(engine), "--headless", "--path", str(project), "--script", f"res://tests/{FIXTURE}.gd"],
            trial_out / "fixture", apparatus.policy.FIXTURE_MS, environment, engines, runtimes)
        log_path = trial_out / "fixture" / "engine.log"
        log = log_path.read_text(encoding="utf-8", errors="replace")
        footer = "LIQUID_DESKTOP_DEFAULT_HOST: 86 assertions; 0 failures" in log
        captures = []
        for capture in fixture["captures"]:
            rva = module_rva(capture, engine)
            sym = symbolize(symbolizer, engine, pdb, rva)
            captures.append({"event_id": capture["event_id"], "first_chance": capture["first_chance"],
                             "code": capture["identity"]["code"], "address": capture["identity"]["address"],
                             "rip": capture["identity"]["rip"], "engine_rva": rva,
                             "historical_rva_equal": rva == HISTORICAL_RVA,
                             "parameters": capture["identity"]["parameters"], "symbolization": sym,
                             "dump": {"path": capture["dump"], "sha256": capture["sha256"], "bytes": capture["bytes"]}})
        outcome = classify_fixture(fixture, log)
        report.update({"fixture": {"outcome": outcome, "effective_exit": fixture["effective_exit"],
                                   "timed_out": fixture["timed_out"], "elapsed_ms": fixture["elapsed_ms"],
                                   "assertion_footer_present": footer, "captures": captures,
                                   "engine_log": identity(log_path)},
                       "status": outcome, "completed": True})
        return report
    except Exception as error:
        report.update(status="apparatus_failure", completed=False, error=f"{type(error).__name__}: {error}")
        return report
    finally:
        write_json(trial_out / "trial.json", report)
        shutil.rmtree(trial_work, ignore_errors=True)


def summarize_reference(path: Path) -> dict:
    campaign = path / "campaign.json"
    if not campaign.is_file():
        return {"available": False, "reason": "campaign.json missing"}
    record = json.loads(campaign.read_text(encoding="utf-8"))
    fixture = record.get("fixture", {})
    captures = fixture.get("captures", []) if isinstance(fixture, dict) else []
    return {"available": True, "campaign": identity(campaign), "status": record.get("status"),
            "completed": record.get("completed"), "errors": record.get("errors"),
            "fixture_attempts": record.get("fixture_attempts"),
            "assertion_footer_present": record.get("assertion_footer_present"),
            "effective_exit": fixture.get("effective_exit") if isinstance(fixture, dict) else None,
            "captured_exception_count": len(captures)}


def counts(trials: list[dict]) -> dict:
    result = {}
    for variant in ("A", "B"):
        rows = [row for row in trials if row["variant"] == variant]
        result[variant] = {"trials": len(rows),
                           "pass": sum(row.get("status") == "pass" for row in rows),
                           "post_footer_access_violation": sum(row.get("status") == "post_footer_access_violation" for row in rows),
                           "other": sum(row.get("status") not in ("pass", "post_footer_access_violation") for row in rows)}
    return result


def should_expand(pilot: list[dict]) -> tuple[bool, str]:
    c = counts(pilot)
    a, b = c["A"]["post_footer_access_violation"], c["B"]["post_footer_access_violation"]
    total = a + b
    if a > 0 and b == 0:
        return True, "control-A reproduced post-footer access violation while counterfactual-B did not"
    if total == 1:
        return True, "one isolated post-footer access violation requires a larger sample before interpretation"
    return False, "pilot did not meet the predeclared expansion rule"


def provisional_classification(reference: dict, trials: list[dict], expanded: bool) -> str:
    c = counts(trials)
    a, b = c["A"], c["B"]
    if a["post_footer_access_violation"] and b["post_footer_access_violation"]:
        return "COUNTERFACTUAL INSUFFICIENT"
    if any(row.get("status") in ("apparatus_failure", "import_failure", "timeout", "failure") for row in trials):
        return "INCONCLUSIVE — RETAIN HOLD"
    if a["post_footer_access_violation"] and b["post_footer_access_violation"] == 0 and expanded and a["trials"] >= 10 and b["trials"] >= 10:
        # A clean 10/10 B arm is strong counterfactual evidence, but this automated
        # runner does not self-award independent causal acceptance.
        return "INCONCLUSIVE — RETAIN HOLD"
    if reference.get("status") == "observed_process_failure" and not a["post_footer_access_violation"] and not b["post_footer_access_violation"]:
        return "INCONCLUSIVE — RETAIN HOLD"
    return "INCONCLUSIVE — RETAIN HOLD"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--project-template", type=Path, required=True)
    parser.add_argument("--engine-a-source", type=Path, required=True)
    parser.add_argument("--engine-b-source", type=Path, required=True)
    parser.add_argument("--patch", type=Path, required=True)
    parser.add_argument("--broker", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    args = parser.parse_args()

    require(sys.platform == "win32" and platform.machine().lower() == "amd64", "Actual x86_64 Windows required")
    app = args.app.resolve()
    template = args.project_template.resolve()
    engine_a_source = args.engine_a_source.resolve()
    engine_b_source = args.engine_b_source.resolve()
    patch = args.patch.resolve()
    broker = args.broker.resolve()
    evidence = args.evidence.resolve()
    work = args.work.resolve()
    require(not evidence.exists(), "Evidence directory already exists; never replace an earlier campaign")
    evidence.mkdir(parents=True)
    work.mkdir(parents=True, exist_ok=False)
    report = {"schema": "pr379-godot117991-windows-ab-v1", "status": "incomplete", "errors": [],
              "scope": "Diagnostic only; no CyberSand production integration or runtime-pin change.",
              "host": {"platform": platform.platform(), "machine": platform.machine(), "processor": platform.processor(),
                       "runner_os": os.environ.get("RUNNER_OS"), "runner_arch": os.environ.get("RUNNER_ARCH"),
                       "github_run_id": os.environ.get("GITHUB_RUN_ID"), "github_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT")},
              "constants": {"cybersand_commit": APP_SHA, "cybersand_tree": APP_TREE, "godot_commit": GODOT_SHA,
                            "upstream_patch_commit": UPSTREAM_PATCH_COMMIT, "fixture": FIXTURE,
                            "pilot_order": PILOT, "expansion_order": EXPANSION},
              "reference": summarize_reference(args.reference.resolve()), "trials": []}
    write_json(evidence / "experiment.json", report)
    try:
        require(git(app, "rev-parse", "HEAD") == APP_SHA, "Frozen CyberSand checkout moved")
        require(git(app, "rev-parse", "HEAD^{tree}") == APP_TREE, "Frozen CyberSand tree differs")
        require(template.is_dir(), "Frozen project template missing")
        require(broker.is_file(), "Source-qualified crash broker from Reference O is missing")
        report["broker"] = identity(broker)
        report["patch"] = identity(patch)
        report["sources"] = {"A": clean_source(engine_a_source, GODOT_SHA),
                             "B": apply_counterfactual(engine_b_source, patch)}
        scons = shutil.which("scons")
        require(scons is not None, "Pinned SCons executable unavailable")
        scons_version = subprocess.run([scons, "--version"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, encoding="utf-8", errors="replace", timeout=30, check=False)
        require(scons_version.returncode == 0, "SCons version probe failed")
        clang = Path(r"C:\Program Files\LLVM\bin\clang-cl.exe")
        lld = Path(r"C:\Program Files\LLVM\bin\lld-link.exe")
        clang_version = subprocess.run([str(clang), "--version"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, encoding="utf-8", errors="replace", timeout=30, check=False)
        lld_version = subprocess.run([str(lld), "--version"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     text=True, encoding="utf-8", errors="replace", timeout=30, check=False)
        require(clang_version.returncode == 0 and lld_version.returncode == 0, "Compiler/linker version probe failed")
        report["build_environment"] = {"scons": {"path": scons, "version_output": scons_version.stdout.strip()},
                                       "build_args": BUILD_ARGS,
                                       "clang": identity(clang) | {"version_output": clang_version.stdout.strip()},
                                       "lld": identity(lld) | {"version_output": lld_version.stdout.strip()}}
        write_json(evidence / "experiment.json", report)
        build_a = build_variant("A", engine_a_source, evidence, scons)
        build_b = build_variant("B", engine_b_source, evidence, scons)
        report["builds"] = {"A": {k: v for k, v in build_a.items() if not k.endswith("_path")},
                            "B": {k: v for k, v in build_b.items() if not k.endswith("_path")}}
        write_json(evidence / "experiment.json", report)

        aliases = {}
        for label, build in (("A", build_a), ("B", build_b)):
            directory = work / "engines" / label.lower()
            directory.mkdir(parents=True)
            alias = directory / ENGINE_BASENAME
            shutil.copy2(Path(build["engine_path"]), alias)
            require(sha256(alias) == build["engine"]["sha256"], "Experimental engine alias changed bytes")
            aliases[label] = {"engine": alias, "pdb": Path(build["pdb_path"])}

        apparatus, contract = import_apparatus(app)
        environment, removed = contract.child_environment(dict(os.environ))
        environment["CYBERSAND_SOURCE_REVISION"] = APP_SHA
        report["sanitized_environment"] = {"removed_names": removed,
                                           "sha256": apparatus.environment_sha256(environment)}
        symbolizer = Path(r"C:\Program Files\LLVM\bin\llvm-symbolizer.exe")
        report["symbolizer"] = identity(symbolizer) if symbolizer.is_file() else {"missing": True, "path": str(symbolizer)}
        write_json(evidence / "experiment.json", report)

        for index, variant in enumerate(PILOT, 1):
            row = run_trial(index, variant, template, work, evidence, aliases[variant]["engine"], aliases[variant]["pdb"],
                            broker, environment, apparatus, symbolizer)
            report["trials"].append(row)
            write_json(evidence / "experiment.json", report)
        expand, reason = should_expand(report["trials"])
        report["expansion"] = {"executed": expand, "reason": reason}
        write_json(evidence / "experiment.json", report)
        if expand:
            start = len(report["trials"]) + 1
            for offset, variant in enumerate(EXPANSION):
                row = run_trial(start + offset, variant, template, work, evidence, aliases[variant]["engine"], aliases[variant]["pdb"],
                                broker, environment, apparatus, symbolizer)
                report["trials"].append(row)
                write_json(evidence / "experiment.json", report)

        report["comparison"] = counts(report["trials"])
        report["classification"] = provisional_classification(report["reference"], report["trials"], expand)
        report["independent_review"] = "NOT_PERFORMED_BY_THIS AUTHORING JOB"
        report["status"] = "completed"
        write_json(evidence / "experiment.json", report)
        return 0
    except Exception as error:
        report["status"] = "failed"
        report["errors"].append(f"{type(error).__name__}: {error}")
        report["classification"] = "INCONCLUSIVE — RETAIN HOLD"
        report["independent_review"] = "NOT_PERFORMED_BY_THIS AUTHORING JOB"
        write_json(evidence / "experiment.json", report)
        return 1
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
