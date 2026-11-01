#!/usr/bin/env python3
"""Exact-source, read-only SOL-DETACH-001 host qualification (no publication)."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import execution_policy as policy
import run_godot_regressions as runner
from run_windows_godot_regressions import GODOT_SHA512, GODOT_VERSION

COHORTS = ("core", "contact-w1", "contact-w4")
SCOPES = ("native", "godot", "tools", "third_party", "Makefile", "AGENTS.md", ".gitattributes",
          ".github/workflows/sol281-current-main.yml", ".github/workflows/rapier-bvh-build.yml")
RESULT_FILES = frozenset({"test_solid_detachment", "test_solid_detachment_coupling",
                          "test_solid_detachment_populated", "test_solid_detachment_displacement"})


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args],
                                   timeout=policy.watchdog_seconds("operation_seconds"))


def source_identity():
    return {"sha": git("rev-parse", "HEAD").decode().strip(),
            "tree": git("rev-parse", "HEAD^{tree}").decode().strip()}


def committed_crlf_paths(paths):
    # Git stores canonical LF but intentionally checks PS1/BAT out as CRLF on
    # both platforms. Only committed attributes may authorize that conversion.
    attributes = git("show", "HEAD:.gitattributes")
    require((ROOT / ".gitattributes").read_bytes() == attributes, "Checkout .gitattributes differs from Git")
    info_path = Path(git("rev-parse", "--git-path", "info/attributes").decode().strip())
    if not info_path.is_absolute():
        info_path = ROOT / info_path
    require(not info_path.is_file() or not info_path.read_bytes(), "Unversioned Git attributes cannot authorize qualification")
    output = subprocess.check_output(["git", "-C", str(ROOT), "-c", "core.attributesFile=" + os.devnull,
        "check-attr", "--source=HEAD", "-z", "--stdin", "eol"], input=("\0".join(paths) + "\0").encode(),
        timeout=policy.watchdog_seconds("operation_seconds"),
        env={**os.environ, "GIT_ATTR_NOSYSTEM": "1"}).decode().split("\0")
    require(output[-1] == "" and len(output) == 3 * len(paths) + 1, "Incomplete committed attribute inventory")
    permitted = set()
    for index, path in enumerate(paths):
        name, attribute, value = output[index * 3:index * 3 + 3]
        require(name == path and attribute == "eol", "Mismatched committed attribute result")
        if value == "crlf":
            permitted.add(path)
    return permitted


def source_inputs():
    """Authenticate all tracked execution/build inputs against exact Git blobs.

    Runtime binaries have independent identities. Godot-generated import/cache
    files are not source inputs; canonical scenes, scripts, shader/source assets,
    native code/tests, tools, fixtures and dependency locks all remain covered.
    """
    names = git("ls-files", "-z", "--", *SCOPES).decode().split("\0")
    paths = sorted(p for p in names if p and "/.godot/" not in p
                   and not (p.startswith("godot/addons/") and "/bin/" in p)
                   and not p.endswith(".import"))
    require(paths and all("\n" not in p for p in paths), "Invalid source inventory")
    crlf_paths = committed_crlf_paths(paths)
    objects = subprocess.check_output(["git", "-C", str(ROOT), "cat-file", "--batch"],
        input="".join("HEAD:" + p + "\n" for p in paths).encode(),
        timeout=policy.watchdog_seconds("operation_seconds"))
    offset = 0
    inputs = {}
    for path in paths:
        end = objects.index(b"\n", offset)
        header = objects[offset:end].split()
        require(len(header) == 3 and header[1] == b"blob", "Missing Git blob: " + path)
        size = int(header[2])
        raw = objects[end + 1:end + 1 + size]
        actual = (ROOT / path).read_bytes()
        converted = path in crlf_paths and b"\r\n" not in raw and actual == raw.replace(b"\n", b"\r\n")
        require(actual == raw or converted, "Checkout source differs from Git: " + path)
        inputs[path] = hashlib.sha256(raw).hexdigest()
        offset = end + size + 2
    require(offset == len(objects), "Unconsumed source blob data")
    return inputs


def checkout_inputs(canonical_inputs):
    """Raw host bytes, recorded separately from the cross-platform Git identity."""
    return {path: digest(ROOT / path) for path in canonical_inputs}


def write_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def manifest(args):
    document = {"schema": "cybersand.sol281.source-build.v1", "source": source_identity(),
                "inputs": source_inputs(), "scope": "scoped qualification; not runtime publication"}
    document["checkout_inputs"] = checkout_inputs(document["inputs"])
    if args.before:
        before = json.loads(args.before.read_text(encoding="utf-8"))
        require(before["source"] == document["source"] and before["inputs"] == document["inputs"],
                "Build changed its authenticated source inputs")
        require(before["checkout_inputs"] == document["checkout_inputs"], "Build changed its raw checkout source bytes")
        document["before_manifest_sha256"] = digest(args.before)
    if args.runtime:
        require(args.runtime.is_file() and args.runtime.stat().st_size > 4096, "Runtime build absent")
        document["runtime"] = {"filename": args.runtime.name, "sha256": digest(args.runtime),
                               "size": args.runtime.stat().st_size}
    if args.bindings:
        document["bindings"] = {"filename": args.bindings.name, "sha256": digest(args.bindings),
                                "revision": "101ae38034304346a46ea9ea84ae156d3e860496"}
    if args.compiler:
        document["compiler"] = subprocess.check_output([str(args.compiler), "--version"],
            timeout=policy.watchdog_seconds("operation_seconds")).decode().strip()
    write_json(args.output, document)
    print(f"Authenticated {len(document['inputs'])} execution/build inputs at {document['source']['sha']}")
    return 0


@dataclass(frozen=True)
class Spec:
    name: str
    script: str
    footer: str
    checks: int | None = None
    flags: tuple[str, ...] = ()
    workers: int | None = None
    structured: bool = True


def inventory(cohort):
    if cohort == "core":
        return [
            *(Spec(f"motion-w{w}", "test_solid_detachment", "SOL281_ACTUAL_RAPIER", 22,
                   (f"--workers={w}",), w) for w in (1, 4)),
            *(Spec(f"failure-w{w}", "test_solid_detachment_failures", "SOL281_HOST_FAILURES", 40,
                   (f"--workers={w}",), w) for w in (1, 4)),
            Spec("lifecycle", "test_solid_detachment_lifecycle", "SOL281_LIFECYCLE", 328),
            Spec("compound-response", "test_solid_detachment_compound_response", "SOL281_COMPOUND_RESPONSE", 33),
            Spec("material-image", "test_solid_detachment_render_ack", "SOL281_RENDER_ACK_UNIT", 17),
            Spec("ordinary-observer", "test_physics_instrumentation",
                 "Physics observer, worker, duplicate, barrier and stored-mass checks passed", structured=False),
            Spec("ordinary-rapier", "test_rapier_manual_step", "Rapier2D manual-step coupling fixture passed", structured=False),
            Spec("ordinary-failure", "test_tick_failure_regression", "Tick failure regression: passed", structured=False),
            Spec("ordinary-capacity", "test_act004_body_capacity", "ACT-004 body capacity fixtures passed", structured=False),
        ]
    workers = int(cohort[-1])
    return [
        Spec(f"coupling-w{workers}", "test_solid_detachment_coupling", "SOL281_COMPOUND_COUPLING", 33,
             (f"--workers={workers}",), workers),
        Spec(f"displacement-w{workers}", "test_solid_detachment_displacement", "SOL281_CONSERVATIVE_DISPLACEMENT", None,
             (f"--workers={workers}",), workers),
        Spec(f"terrain-w{workers}", "test_solid_detachment_terrain_refresh", "SOL281_TERRAIN_REFRESH", 8,
             (f"--workers={workers}",), workers),
        *(Spec(f"{kind}-{mode}-w{workers}", "test_solid_detachment_populated", "SOL281_POPULATED", 14,
               (f"--workers={workers}", f"--surroundings={kind}", *(("--baseline",) if mode == "baseline" else ())), workers)
          for kind in ("packed_sand", "embedded_sand", "mixed") for mode in ("candidate", "baseline")),
    ]


def verify_footer(spec, text, expected_platform):
    if not spec.structured:
        require(text.count(spec.footer) == 1, "Missing/duplicate ordinary completion footer: " + spec.name)
        return None
    matches = re.findall(r"^" + re.escape(spec.footer) + r" (\{.+\})$", text, re.MULTILINE)
    require(len(matches) == 1, "Missing/duplicate structured footer: " + spec.name)
    result = json.loads(matches[0])
    require(result.get("failures") == [] and result.get("platform") == expected_platform,
            "Wrong platform or failed assertions: " + spec.name)
    if spec.script == "test_solid_detachment_displacement":
        require(result.get("checks") == 292 and result.get("cases") == 17,
                "Incomplete displacement replay: " + spec.name)
    elif spec.checks is not None:
        require(result.get("checks") == spec.checks, "Incomplete assertion inventory: " + spec.name)
    if spec.workers:
        require(result.get("workers", result.get("configured_workers")) == spec.workers,
                "Worker count differs from cohort: " + spec.name)
    if spec.name == "lifecycle":
        require(result.get("actual_host_replacement_cycles") == 20, "Incomplete actual-owner lifecycle inventory")
    if spec.script == "test_solid_detachment_populated":
        require(result.get("conservative_displacement") == ("--baseline" not in spec.flags), "Wrong contact policy")
        require(result.get("surroundings") == next(x.split("=", 1)[1] for x in spec.flags if x.startswith("--surroundings=")),
                "Wrong populated fixture")
    return result


def verify_result_file(spec, output, footer):
    if spec.script not in RESULT_FILES:
        return None
    path = output / (spec.name + ".json")
    require(path.is_file(), "Missing original structured result: " + spec.name)
    result = json.loads(path.read_text(encoding="utf-8"))
    for key, expected in footer.items():
        if key == "cases" and spec.script == "test_solid_detachment_displacement":
            require(isinstance(result.get(key), list) and len(result[key]) == expected,
                    "Original replay case inventory differs from footer")
        else:
            require(result.get(key) == expected, "Original result differs from footer: " + spec.name + ":" + key)
    if spec.script == "test_solid_detachment_displacement":
        fixture_path = ROOT / "godot/tests/fixtures/sol281/conservative_contacts.json"
        fixtures = json.loads(fixture_path.read_text(encoding="utf-8"))["fixtures"]
        cases = result["cases"]
        require(result.get("schema") == "cybersand.sol281.conservative-displacement-replay.v1"
                and result.get("fixture_sha256") == digest(fixture_path),
                "Replay does not identify the exact source fixture")
        require(len(fixtures) == 17 and sum(x["expected_accepted"] is True for x in fixtures) == 4
                and all(isinstance(x, dict) for x in cases)
                and [x.get("id") for x in cases] == [x["id"] for x in fixtures],
                "Original replay fixture IDs are missing, duplicated or reordered")
        for case, fixture in zip(cases, fixtures):
            accepted = fixture["expected_accepted"]
            require(type(case.get("failure_count")) is int and case["failure_count"] == 0,
                    "Original replay case failed or omitted its assertions: " + fixture["id"])
            require(case.get("expected_accepted") is accepted
                    and (case.get("outcome") == "Applied") is accepted
                    and case.get("outcome") not in (None, "", "Quarantined")
                    and case.get("moved_cells") == fixture["expected_minimum_moves"]
                    and case.get("path") == fixture.get("expected_path", [])
                    and case.get("geometry_clear") is accepted,
                    "Original replay case disposition differs from fixture: " + fixture["id"])
            if not accepted:
                require(isinstance(case.get("before_sha256"), str)
                        and re.fullmatch(r"[0-9a-f]{64}", case["before_sha256"]) is not None
                        and case.get("after_sha256") == case["before_sha256"],
                        "Refused replay changed its original material payload: " + fixture["id"])
    return {"path": path.name, "sha256": digest(path)}


def verify_engine(executable, archive, target):
    lock = json.loads((ROOT / "third_party/godot-runtime.lock.json").read_text(encoding="utf-8"))
    algorithm = "sha512" if target == "windows" else "sha256"
    expected = GODOT_SHA512 if target == "windows" else lock["editor"]["sha256"]
    actual = hashlib.new(algorithm, archive.read_bytes()).hexdigest()
    require(actual == expected, "Unpinned Godot archive")
    with zipfile.ZipFile(archive) as package:
        require(package.testzip() is None, "Corrupt Godot archive")
        required = (["Godot_v4.7-stable_win64_console.exe", "Godot_v4.7-stable_win64.exe"]
                    if target == "windows" else ["Godot_v4.7-stable_linux.x86_64"])
        require(executable.name == required[0], "Unexpected engine executable")
        hashes = {}
        for filename in required:
            path = executable.parent / filename
            require(path.read_bytes() == package.read(filename), "Executable differs from pinned archive: " + filename)
            hashes[filename] = digest(path)
    version = subprocess.check_output([str(executable), "--version"],
        timeout=policy.watchdog_seconds("operation_seconds")).decode().strip()
    require(version == GODOT_VERSION, "Unpinned actual Godot version")
    return {"version": version, "archive_algorithm": algorithm, "archive_hash": actual, "executables": hashes}


def verify_rapier(target):
    native, rapier = runner.runtime_paths("win32" if target == "windows" else "linux")
    relative = rapier.relative_to(ROOT).as_posix()
    pointer = git("show", "HEAD:" + relative)
    match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", pointer)
    require(match is not None, "Missing canonical Rapier LFS identity")
    require(digest(rapier) == match[1].decode() and rapier.stat().st_size == int(match[2]), "Rapier bytes differ from current pin")
    from check_repository import verify_rapier_overrides
    lock = json.loads((ROOT / "godot/third_party/rapier2d.lock.json").read_text(encoding="utf-8"))
    require(not verify_rapier_overrides(ROOT, lock), "Rapier override provenance failed")
    return native, {"path": relative, "sha256": digest(rapier), "size": rapier.stat().st_size,
                    "lock_sha256": digest(ROOT / "godot/third_party/rapier2d.lock.json")}


def run(args):
    args.output.mkdir(parents=True, exist_ok=True)
    expected_platform = "Windows" if args.platform == "windows" else "Linux"
    report = {"schema": "cybersand.sol281.qualification.v1", "status": "incomplete", "platform": expected_platform,
              "cohort": args.cohort, "records": [], "errors": [], "execution_policy": policy.identity(),
              "scope": "actual source-matched headless native/Rapier; GPU frame pacing and milestone completion not established"}
    output_report = args.output / "report.json"
    write_json(output_report, report)
    try:
        require(platform.system() == expected_platform, "Actual host platform does not match cohort")
        build = json.loads(args.manifest.read_text(encoding="utf-8"))
        require(build.get("schema") == "cybersand.sol281.source-build.v1", "Unknown build manifest")
        report["source"] = source_identity()
        require(report["source"] == build["source"], "Execution commit/tree differs from build")
        require(not os.environ.get("GITHUB_SHA") or os.environ["GITHUB_SHA"] == build["source"]["sha"], "Workflow SHA differs from source")
        before = source_inputs()
        require(before == build["inputs"], "Execution input set differs from build input set")
        checkout_before = checkout_inputs(before)
        write_json(args.output / "inputs-before.json", before)
        write_json(args.output / "checkout-inputs-before.json", checkout_before)
        report["build_manifest_sha256"] = digest(args.manifest)
        require(args.runtime.name == build["runtime"]["filename"] and digest(args.runtime) == build["runtime"]["sha256"],
                "Runtime differs from built artifact")
        report["engine"] = verify_engine(args.godot, args.godot_archive, args.platform)
        native, report["rapier"] = verify_rapier(args.platform)
        if args.runtime.resolve() != native.resolve():
            shutil.copyfile(args.runtime, native)
        require(digest(native) == build["runtime"]["sha256"], "Installed runtime hash differs")
        report["runtime"] = build["runtime"]
        specs = inventory(args.cohort)
        report["expected_cases"] = [x.name for x in specs]
        timeouts = [policy.case_seconds(x.script) for x in specs]
        # Shared command bounds plus all cleanup and setup paths must fit the
        # fixed hosted ceiling; this never truncates an individual case deadline.
        allowance = (policy.aggregate_seconds(timeouts)
                     + (len(specs) + 1) * policy.godot_process_cleanup_seconds()
                     + policy.watchdog_seconds("godot_metadata_seconds")
                     + 2 * policy.watchdog_seconds("dependency_prepare_seconds"))
        require(allowance <= policy.identity()["watchdogs"]["godot_job_minutes"] * 60,
                "Cohort allowances exceed complete hosted job budget")
        report["maximum_allowance_seconds"] = allowance
        process_env = dict(os.environ)
        process_env["CYBERSAND_SOURCE_REVISION"] = build["source"]["sha"]
        process_env["GODOT_SILENCE_ROOT_WARNING"] = "1"
        for key, subdir in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
            directory = args.output / "host-state" / subdir
            directory.mkdir(parents=True, exist_ok=True)
            process_env[key] = str(directory.resolve())
        imported, failed = runner.run_case(str(args.godot), runner.Case("import", ("--editor", "--import", "--quit"),
            policy.watchdog_seconds("godot_import_seconds"), 1), args.output, "import", env=process_env)
        report["import"] = imported
        write_json(output_report, report)
        require(not failed, "Godot import failed; no host case accepted")
        for spec, timeout in zip(specs, timeouts):
            flags = ("--script", "res://tests/" + spec.script + ".gd", "--", str((args.output / (spec.name + ".json")).resolve()), *spec.flags)
            record, failed = runner.run_case(str(args.godot), runner.Case(spec.name, flags, timeout, 1),
                                             args.output, "qualification", env=process_env)
            try:
                require(not failed, "Execution failed: " + spec.name)
                text = (args.output / record["log"]).read_text(encoding="utf-8", errors="replace")
                require("FAIL SOL281" not in text, "Failure marker in apparently successful process")
                record["readback"] = verify_footer(spec, text, expected_platform)
                record["result"] = verify_result_file(spec, args.output, record["readback"])
            except Exception as error:
                record["status"] = "failed"
                record["readback_error"] = str(error)
                report["errors"].append(str(error))
            report["records"].append(record)
            write_json(output_report, report)
        require([x["name"] for x in report["records"]] == report["expected_cases"], "Incomplete or reordered case inventory")
        after = source_inputs()
        write_json(args.output / "inputs-after.json", after)
        checkout_after = checkout_inputs(after)
        write_json(args.output / "checkout-inputs-after.json", checkout_after)
        require(after == before and source_identity() == build["source"], "Execution changed source inputs")
        require(checkout_after == checkout_before, "Execution changed raw checkout source bytes")
        require(digest(native) == build["runtime"]["sha256"], "Execution changed native runtime")
        _, after_rapier = verify_rapier(args.platform)
        require(after_rapier == report["rapier"], "Execution changed Rapier runtime")
        report["source_unchanged"] = True
        report["checkout_inputs_unchanged"] = True
        report["status"] = "failed" if report["errors"] else "passed"
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
        report["status"] = "failed"
    finally:
        write_json(output_report, report)
    print(json.dumps({key: report.get(key) for key in ("status", "source", "platform", "cohort", "errors")}, indent=2))
    return 0 if report["status"] == "passed" else 1


def summarize(args):
    """Reopen all original cohort logs/results; never infer missing acceptance."""
    source = source_identity()
    result = {"schema": "cybersand.sol281.complete-qualification.v1", "source": source,
              "status": "failed", "cohorts": [], "errors": [],
              "scope": "source-matched headless qualification; no graphical frame-rate or milestone completion claim"}
    try:
        reports = sorted(args.input.rglob("report.json"))
        require(len(reports) == 2 * len(COHORTS), "Missing or extra platform/cohort report")
        seen = set()
        runtimes = {}
        input_identity = source_inputs()
        for path in reports:
            report = json.loads(path.read_text(encoding="utf-8"))
            key = (report.get("platform"), report.get("cohort"))
            require(key[0] in ("Linux", "Windows") and key[1] in COHORTS and key not in seen,
                    "Duplicate or unexpected cohort: " + str(key))
            seen.add(key)
            require(report.get("schema") == "cybersand.sol281.qualification.v1" and report.get("status") == "passed"
                    and report.get("errors") == [] and report.get("source") == source
                    and report.get("source_unchanged") is True, "Failed or mismatched cohort: " + str(key))
            inputs = json.loads((path.parent / "inputs-before.json").read_text(encoding="utf-8"))
            require(inputs == json.loads((path.parent / "inputs-after.json").read_text(encoding="utf-8")),
                    "Cohort source changed")
            checkout_before = json.loads((path.parent / "checkout-inputs-before.json").read_text(encoding="utf-8"))
            checkout_after = json.loads((path.parent / "checkout-inputs-after.json").read_text(encoding="utf-8"))
            require(set(checkout_before) == set(inputs) and checkout_before == checkout_after
                    and report.get("checkout_inputs_unchanged") is True, "Cohort raw checkout bytes changed or inventory incomplete")
            require(input_identity == inputs, "Cohort execution inputs differ from reducer Git source")
            runtime = report["runtime"]
            require(key[0] not in runtimes or runtimes[key[0]] == runtime, "Platform cohorts used different native runtimes")
            runtimes[key[0]] = runtime
            specs = inventory(key[1])
            require(report["expected_cases"] == [x.name for x in specs]
                    and [x["name"] for x in report["records"]] == report["expected_cases"], "Incomplete cohort inventory")
            for spec, record in zip(specs, report["records"]):
                require(record.get("status") == "passed" and record.get("returncode") == 0
                        and record.get("natural_completion") is True and not record.get("skip_messages"),
                        "Case did not complete: " + spec.name)
                log = path.parent / record["log"]
                require(digest(log) == record["log_sha256"], "Original log hash changed: " + spec.name)
                footer = verify_footer(spec, log.read_text(encoding="utf-8", errors="replace"), key[0])
                require(record.get("readback") == footer, "Stored readback differs from original log")
                require(verify_result_file(spec, path.parent, footer) == record.get("result"), "Original result hash changed")
            result["cohorts"].append({"platform": key[0], "cohort": key[1], "cases": len(specs),
                                     "report_sha256": digest(path), "runtime": runtime})
        result["status"] = "passed"
    except Exception as error:
        result["errors"].append(f"{type(error).__name__}: {error}")
    write_json(args.output, result)
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "passed" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("manifest")
    create.add_argument("--output", type=Path, required=True)
    create.add_argument("--before", type=Path)
    create.add_argument("--runtime", type=Path)
    create.add_argument("--bindings", type=Path)
    create.add_argument("--compiler", type=Path)
    execute = commands.add_parser("run")
    execute.add_argument("--manifest", type=Path, required=True)
    execute.add_argument("--runtime", type=Path, required=True)
    execute.add_argument("--godot", type=Path, required=True)
    execute.add_argument("--godot-archive", type=Path, required=True)
    execute.add_argument("--platform", choices=("linux", "windows"), required=True)
    execute.add_argument("--cohort", choices=COHORTS, required=True)
    execute.add_argument("--output", type=Path, required=True)
    aggregate = commands.add_parser("summarize")
    aggregate.add_argument("--input", type=Path, required=True)
    aggregate.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    return {"manifest": manifest, "run": run, "summarize": summarize}[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())
