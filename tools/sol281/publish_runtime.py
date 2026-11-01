#!/usr/bin/env python3
"""Prepare a bounded, exact-source SOL-281 runtime publication; never commit/push.

Run on the GitHub-hosted publication job after all six actual-host cohorts pass.
The workflow stages ``publication_paths`` from the output receipt, then invokes
this helper again with --verify-staged before its own fast-forward publication.
"""
from __future__ import annotations

import argparse
from contextlib import redirect_stdout
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile

import run_qualification as qualification

sys.path.insert(0, str(qualification.ROOT / "tools/ci"))
import lcb001_shared_contract_runtime_publication as commonengine
from run_windows_godot_regressions import native_input_paths

ROOT = qualification.ROOT
BRANCH = "sol-detach-001-current-main"
REPOSITORY = "techrote/cybersand"
BINDINGS_REVISION = "101ae38034304346a46ea9ea84ae156d3e860496"
EVIDENCE = "docs/audits/sol281-20261101/hosted"
NATIVE_COUNT = 86
MAX_FILES = 2048
MAX_FILE_BYTES = 128 * 1024 * 1024
MAX_EVIDENCE_BYTES = 256 * 1024 * 1024
RUNTIMES = commonengine.RUNTIMES
MANIFESTS = commonengine.MANIFESTS
SCOPE = ("All three SOL-281 actual-host cohorts on this target OS, including workers 1 and 4, "
         "native structural ownership, lifecycle, compound response, conservative replay, populated material "
         "conservation and ordinary compatibility controls. Dense-contact physical quality, general "
         "restoration/fracture/gameplay, full repository CI and representative GPU pacing remain separate gates.")


def require(value, message):
    qualification.require(value, message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def load(path):
    return json.loads(path.read_bytes(), object_pairs_hook=unique_object,
                      parse_constant=lambda value: require(False, "Nonfinite JSON: " + value))


def safe_relative(value):
    require(isinstance(value, str) and value and "\\" not in value and "\n" not in value
            and "\r" not in value and not value.startswith("/")
            and all(part not in ("", ".", "..") for part in value.split("/")), "Unsafe path: " + str(value))
    require(PurePosixPath(value).as_posix() == value, "Noncanonical path: " + value)
    return value


def context():
    require(os.environ.get("GITHUB_ACTIONS") == "true"
            and os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted"
            and os.environ.get("RUNNER_OS") == "Linux", "Publication requires a GitHub-hosted Linux job")
    require(os.environ.get("GITHUB_REPOSITORY") == REPOSITORY
            and os.environ.get("GITHUB_REF") == "refs/heads/" + BRANCH
            and os.environ.get("GITHUB_SERVER_URL") == "https://github.com", "Wrong publication repository/ref/server")
    require(os.environ.get("GITHUB_EVENT_NAME") in ("push", "workflow_dispatch"), "Unexpected publication event")
    source = qualification.source_identity()
    require(re.fullmatch(r"[0-9a-f]{40}", source["sha"]) is not None
            and os.environ.get("GITHUB_SHA") == source["sha"], "Publication HEAD differs from workflow source")
    require(os.environ.get("GITHUB_WORKFLOW_SHA") == source["sha"]
            and os.environ.get("GITHUB_WORKFLOW_REF") == REPOSITORY
                + "/.github/workflows/sol281-current-main.yml@refs/heads/" + BRANCH,
            "Publication workflow source/ref differs")
    require(qualification.git("rev-parse", "--is-shallow-repository").strip() == b"false", "Full Git history required")
    run = os.environ.get("GITHUB_RUN_ID", "")
    attempt = os.environ.get("GITHUB_RUN_ATTEMPT", "")
    require(re.fullmatch(r"[1-9][0-9]*", run) and re.fullmatch(r"[1-9][0-9]*", attempt), "Missing run/attempt identity")
    return {"source": source, "repository": REPOSITORY, "ref": "refs/heads/" + BRANCH,
            "run_id": run, "run_attempt": attempt,
            "workflow_run": "https://github.com/" + REPOSITORY + "/actions/runs/" + run}


def artifact_roots(root, names):
    require(root.is_dir() and not root.is_symlink(), "Missing/linked artifact root")
    require({p.name for p in root.iterdir()} == set(names), "Unexpected artifact directory inventory")
    for name in names:
        path = root / safe_relative(name)
        require(path.is_dir() and not path.is_symlink(), "Artifact must be a real directory: " + name)
    return {name: root / name for name in names}


def files_in(root, omitted=()):
    files = {}
    for directory, directories, filenames in os.walk(root, followlinks=False):
        directory = Path(directory)
        for name in list(directories):
            child = directory / name
            require(not child.is_symlink(), "Linked artifact directory: " + str(child))
            relative = child.relative_to(root).as_posix()
            if relative in omitted:
                directories.remove(name)
        for name in filenames:
            path = directory / name
            relative = safe_relative(path.relative_to(root).as_posix())
            require(path.is_file() and not path.is_symlink(), "Non-file artifact: " + relative)
            require(path.stat().st_size <= MAX_FILE_BYTES, "Artifact exceeds bounded file capacity")
            files[relative] = path
            require(len(files) <= MAX_FILES, "Artifact exceeds bounded file inventory")
    return files


def verify_command(directory, ctx):
    record = load(directory / "receipt.json")
    require(record.get("schema") == "execution-command-v1" and record.get("status") == "passed"
            and record.get("returncode") == 0 and record.get("complete") is True
            and record.get("natural_completion") is True and record.get("timed_out") is False,
            "Build/preparation command did not complete: " + str(directory))
    require(record.get("log") == "command.log"
            and qualification.digest(directory / "command.log") == record.get("log_sha256"), "Original command log changed")
    source = record.get("source", {})
    require(source.get("commit") == ctx["source"]["sha"] and source.get("tree") == ctx["source"]["tree"]
            and source.get("run_id") == ctx["run_id"] and source.get("run_attempt") == ctx["run_attempt"],
            "Build/preparation command belongs to another source/run/attempt")


def verify_build(directory, target, ctx, inputs):
    files = files_in(directory)
    runtime_name = Path(RUNTIMES[target]).name
    commands = {"prepare", "bindings", "extension", "native-regressions" if target == "linux" else "compiler"}
    expected = {"build.json", "before.json", runtime_name}
    if target == "linux":
        expected |= {"source.tar.gz", "source.tar.gz.sha256"}
    for command in commands:
        expected |= {command + "/" + name for name in ("command.log", "receipt.json", "performance.jsonl")}
    optional = {command + "/approaching-watchdog.json" for command in commands}
    require(expected <= set(files) and set(files) <= expected | optional, "Unexpected/incomplete build artifact inventory: " + target)
    build = load(files["build.json"])
    before = load(files["before.json"])
    for record in (build, before):
        require(record.get("schema") == "cybersand.sol281.source-build.v1"
                and record.get("source") == ctx["source"] and record.get("inputs") == inputs,
                "Build source/input identity differs: " + target)
        require(isinstance(record.get("checkout_inputs"), dict)
                and set(record["checkout_inputs"]) == set(inputs)
                and all(re.fullmatch(r"[0-9a-f]{64}", value) for value in record["checkout_inputs"].values()),
                "Missing full raw build checkout inventory")
    require(build["checkout_inputs"] == before["checkout_inputs"], "Build raw checkout changed")
    require(build.get("before_manifest_sha256") == qualification.digest(files["before.json"]), "Build preflight manifest changed")
    identity = commonengine.runtime_identity(files[runtime_name], target)
    require(identity["size"] > 4096 and build.get("runtime") == {
        "filename": runtime_name, "sha256": identity["sha256"], "size": identity["size"]}, "Runtime identity differs from build")
    bindings = build.get("bindings", {})
    require(bindings.get("revision") == BINDINGS_REVISION
            and bindings.get("filename") == f"libgodot-cpp.{target}.template_debug.x86_64.a"
            and re.fullmatch(r"[0-9a-f]{64}", bindings.get("sha256", ""))
            and isinstance(build.get("compiler"), str) and build["compiler"].strip(), "Missing pinned bindings/compiler identity")
    for command in commands:
        verify_command(directory / command, ctx)
    if target == "linux":
        checksum = files["source.tar.gz.sha256"].read_text().strip().split()
        require(len(checksum) == 2 and checksum[0] == qualification.digest(files["source.tar.gz"])
                and Path(checksum[1]).name == "source.tar.gz", "Source archive checksum mismatch")
    return build, identity, files


def verify_host(directory, target, cohort, ctx, build, build_hash):
    # Linux uploads a multi-directory artifact; Windows uploads the host root.
    host = directory / "host" if target == "linux" else directory
    files = files_in(directory, ("host/host-state",) if target == "linux" else ("host-state",))
    prefix = "host/" if target == "linux" else ""
    names = {"report.json", "inputs-before.json", "inputs-after.json", "performance.jsonl", "import.log",
             "checkout-inputs-before.json", "checkout-inputs-after.json"}
    specs = qualification.inventory(cohort)
    names |= {spec.name + ".log" for spec in specs}
    names |= {spec.name + ".json" for spec in specs if spec.script in qualification.RESULT_FILES}
    expected = {prefix + name for name in names}
    optional = set()
    if target == "linux":
        for preparation in ("prepare-rapier", "prepare-engine"):
            expected |= {preparation + "/" + name for name in ("command.log", "receipt.json", "performance.jsonl")}
            optional.add(preparation + "/approaching-watchdog.json")
            verify_command(directory / preparation, ctx)
    require(expected <= set(files) and set(files) <= expected | optional, "Unexpected/incomplete host artifact inventory: " + target + "/" + cohort)
    report = load(host / "report.json")
    require(report.get("platform") == target.title() and report.get("cohort") == cohort
            and report.get("build_manifest_sha256") == build_hash and report.get("runtime") == build["runtime"],
            "Cohort build/runtime/platform attribution mismatch")
    for record in [report.get("import", {})] + report.get("records", []):
        require(record.get("status") == "passed" and record.get("returncode") == 0
                and record.get("natural_completion") is True and record.get("skip_messages") == []
                and not any(record.get(k) for k in ("diagnostic_error", "launch_error", "capture_error", "timeout_kind")),
                "Host import/case did not complete naturally")
        require(record.get("log") == record.get("name", "") + ".log", "Unexpected original log path")
        log = host / safe_relative(record["log"])
        require(qualification.digest(log) == record.get("log_sha256"), "Original import/case log changed")
        text = log.read_text(encoding="utf-8", errors="replace")
        require("SCRIPT ERROR:" not in text and "ERROR:" not in text and "FAIL SOL281" not in text, "Original host log contains failure")
    performance = [json.loads(line, object_pairs_hook=unique_object) for line in (host / "performance.jsonl").read_text().splitlines()]
    require([row.get("fixture") for row in performance] == ["import"] + [spec.name for spec in specs], "Unexpected performance execution inventory")
    for row in performance:
        source, actual_host = row.get("source", {}), row.get("host", {})
        require(source.get("commit") == ctx["source"]["sha"] and source.get("tree") == ctx["source"]["tree"]
                and source.get("run_id") == ctx["run_id"] and source.get("run_attempt") == ctx["run_attempt"]
                and actual_host.get("platform") == target.title() and actual_host.get("runner_class") == "github-hosted"
                and row.get("result") == "passed" and row.get("natural_completion") is True
                and row.get("watchdog_reached") is False, "Host execution source/run/attempt/OS witness mismatch")
    engine = report.get("engine", {})
    lock = load(ROOT / "third_party/godot-runtime.lock.json")
    require(engine.get("version") == qualification.GODOT_VERSION
            and engine.get("archive_algorithm") == ("sha256" if target == "linux" else "sha512")
            and engine.get("archive_hash") == (lock["editor"]["sha256"] if target == "linux" else qualification.GODOT_SHA512),
            "Host engine pin differs")
    executable_names = ({"Godot_v4.7-stable_linux.x86_64"} if target == "linux" else
                        {"Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe"})
    require(set(engine.get("executables", {})) == executable_names
            and all(re.fullmatch(r"[0-9a-f]{64}", value) for value in engine["executables"].values()), "Missing actual engine executable identity")
    _, rapier = qualification.runner.runtime_paths("linux" if target == "linux" else "win32")
    relative = rapier.relative_to(ROOT).as_posix()
    pointer = qualification.git("show", "HEAD:" + relative)
    match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", pointer)
    require(match is not None and report.get("rapier") == {"path": relative, "sha256": match[1].decode(),
            "size": int(match[2]), "lock_sha256": qualification.digest(ROOT / "godot/third_party/rapier2d.lock.json")},
            "Host Rapier source pin differs")
    return report, files


def native_ledger(inputs):
    paths = native_input_paths(ROOT)
    require(len(paths) == NATIVE_COUNT and paths <= set(inputs), "Native input inventory is incomplete/unexpected")
    return {path: inputs[path] for path in sorted(paths)}


def checked_destination(relative):
    path = ROOT / safe_relative(relative)
    require(path.resolve().is_relative_to(ROOT.resolve()), "Publication destination escapes checkout")
    current = path
    while current != ROOT:
        require(not current.is_symlink(), "Publication destination contains a symlink")
        current = current.parent
    return path


def make_manifest(target, ctx, inputs, native, identity, build, build_bytes, base, cohorts):
    validation = {"schema": "cybersand.sol281.platform-publication.v1", "status": "passed", "completed": True,
                  **ctx, "platform": target, "runtime": identity, "cohorts": cohorts,
                  "qualification": base + "/qualification.json", "scope": SCOPE}
    validation_path = base + "/" + target + "-validation.json"
    validation_bytes = encoded(validation)
    manifest = {"schema_version": 1, "platform": target, "status": "validated-development-runtime",
                "source_commit": ctx["source"]["sha"], "build_commit": ctx["source"]["sha"],
                "source_tree": ctx["source"]["tree"], "source_inputs": native,
                "build_inputs": {path: value for path, value in inputs.items() if path not in native},
                "source_input_hash_kind": "SHA-256 of canonical Git blob bytes; checkout bytes independently authenticated",
                **identity, "build_attempt": ctx["run_attempt"], "workflow_attempt": ctx["run_attempt"],
                "workflow_run": ctx["workflow_run"], "evidence": "docs/audits/2026-11-01-sol281-current-main.md",
                "toolchain": "GitHub-hosted Linux build; target " + target + "; godot-cpp=" + BINDINGS_REVISION
                    + "; bindings SHA-256=" + build["bindings"]["sha256"] + "\n" + build["compiler"],
                "bindings": build["bindings"], "compiler": build["compiler"],
                "build_manifest": base + "/build/" + target + "/build.json",
                "build_manifest_sha256": sha(build_bytes),
                "validated_platform": target.title() + " x86_64 Godot 4.7 (actual GitHub-hosted headless execution)",
                "acceptance": SCOPE, "other_platforms": "No graphical/GPU, browser/WebAssembly or full milestone acceptance claimed.",
                "validation_output": validation_path, "validation_sha256": sha(validation_bytes)}
    return {validation_path: validation_bytes, MANIFESTS[target]: encoded(manifest)}


def clean_source_verification(evidence):
    """Re-run the unchanged reducer at HEAD after authorized metadata writes.

    A temporary detached worktree shares Git objects and suppresses LFS smudge.
    This never exempts publication paths from the qualification reader itself.
    """
    allowance = qualification.policy.watchdog_seconds("operation_seconds")
    with tempfile.TemporaryDirectory(prefix="sol281-publish-readback-") as temporary:
        temporary = Path(temporary)
        checkout = temporary / "source"
        env = {**os.environ, "GIT_LFS_SKIP_SMUDGE": "1"}
        def run(command):
            subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           timeout=allowance, env=env)
        added = False
        try:
            run(["git", "-C", str(ROOT), "worktree", "add", "--detach", "--no-checkout", str(checkout), "HEAD"])
            added = True
            run(["git", "-C", str(checkout), "-c", "filter.lfs.process=", "-c", "filter.lfs.smudge=",
                 "-c", "filter.lfs.required=false", "checkout", "--force", "HEAD"])
            reader = checkout / "tools/sol281/run_qualification.py"
            manifest = temporary / "source.json"
            summary = temporary / "qualification.json"
            run([sys.executable, str(reader), "manifest", "--output", str(manifest)])
            run([sys.executable, str(reader), "summarize", "--input", str(evidence.resolve()), "--output", str(summary)])
            return load(manifest)["inputs"], summary.read_bytes()
        finally:
            if added:
                run(["git", "-C", str(ROOT), "worktree", "remove", "--force", str(checkout)])


def verify_checkout(inputs, generated):
    """Every original input matches HEAD; only two exact generated outputs differ."""
    paths = sorted(inputs)
    permitted = qualification.committed_crlf_paths(paths)
    output = subprocess.check_output(["git", "-C", str(ROOT), "cat-file", "--batch"],
        input="".join("HEAD:" + path + "\n" for path in paths).encode(),
        timeout=qualification.policy.watchdog_seconds("operation_seconds"))
    offset = 0
    for path in paths:
        end = output.index(b"\n", offset)
        header = output[offset:end].split()
        require(len(header) == 3 and header[1] == b"blob", "Missing canonical qualified source")
        size = int(header[2])
        raw = output[end + 1:end + 1 + size]
        offset = end + size + 2
        require(sha(raw) == inputs[path], "Canonical qualified source hash differs")
        actual = checked_destination(path).read_bytes()
        if path in MANIFESTS.values():
            require(actual == generated[path], "Generated provenance differs from trusted original artifacts")
        else:
            converted = path in permitted and b"\r\n" not in raw and actual == raw.replace(b"\n", b"\r\n")
            require(actual == raw or converted, "Qualified source changed after publication preparation: " + path)
    require(offset == len(output), "Unconsumed canonical source bytes")


def prepare(args):
    ctx = context()
    require(not args.output.exists(), "Publication receipt already exists")
    require(not qualification.git("diff", "--cached", "--name-only").strip(), "Publication requires an empty index")
    inputs = qualification.source_inputs()
    native = native_ledger(inputs)
    checkout = {path: qualification.digest(ROOT / path) for path in inputs}
    suffix = ctx["run_id"] + "-" + ctx["run_attempt"]
    build_names = {target: f"sol281-build-{target}-{suffix}" for target in RUNTIMES}
    host_names = {(target, cohort): f"sol281-host-{target}-{cohort}-{suffix}"
                  for target in RUNTIMES for cohort in qualification.COHORTS}
    builds = artifact_roots(args.build_root, build_names.values())
    hosts = artifact_roots(args.evidence_root, host_names.values())
    base = EVIDENCE + "/" + ctx["source"]["sha"]
    require(not checked_destination(base).exists(), "Durable source evidence already exists; do not overwrite history")
    plan = {}
    originals = {}
    build_records = {}
    identities = {}
    cohorts = {target: [] for target in RUNTIMES}
    for target, name in build_names.items():
        build, identity, files = verify_build(builds[name], target, ctx, inputs)
        build_records[target], identities[target] = build, identity
        for relative, path in files.items():
            originals["builds/" + name + "/" + relative] = {"sha256": qualification.digest(path), "size": path.stat().st_size}
        plan[RUNTIMES[target]] = files[Path(RUNTIMES[target]).name].read_bytes()
        for name in ("build.json", "before.json"):
            plan[base + "/build/" + target + "/" + name] = files[name].read_bytes()
    for (target, cohort), name in host_names.items():
        report, files = verify_host(hosts[name], target, cohort, ctx, build_records[target],
                                    qualification.digest(builds[build_names[target]] / "build.json"))
        destination = base + "/cohorts/" + target + "/" + cohort
        for relative, path in files.items():
            data = path.read_bytes()
            originals["hosts/" + name + "/" + relative] = {"sha256": sha(data), "size": len(data)}
            plan[destination + "/" + relative] = data
        report_relative = destination + ("/host" if target == "linux" else "") + "/report.json"
        cohorts[target].append({"cohort": cohort, "report": report_relative,
                                "report_sha256": sha(plan[report_relative]), "cases": len(report["records"])})
    # This existing reducer reopens every original log, structured result and
    # source inventory before any repository publication path is changed.
    with tempfile.TemporaryDirectory(prefix="sol281-publication-") as temporary:
        summary_path = Path(temporary) / "qualification.json"
        with redirect_stdout(io.StringIO()):
            result = qualification.summarize(argparse.Namespace(input=args.evidence_root, output=summary_path))
        require(result == 0, "Original six-cohort qualification failed: " + str(load(summary_path).get("errors")))
        plan[base + "/qualification.json"] = summary_path.read_bytes()
    plan[base + "/publication-checkout-before.json"] = encoded(checkout)
    for target in RUNTIMES:
        plan.update(make_manifest(target, ctx, inputs, native, identities[target], build_records[target],
            plan[base + "/build/" + target + "/build.json"], base, cohorts[target]))
    require(sum(len(data) for data in plan.values()) <= MAX_EVIDENCE_BYTES, "Publication exceeds bounded evidence capacity")
    for relative in plan:
        checked_destination(relative)
    receipt = {"schema": "cybersand.sol281.runtime-publication.v1", **ctx, "status": "prepared",
               "publication_paths": sorted(plan), "files": {path: {"sha256": sha(data), "size": len(data)} for path, data in sorted(plan.items())},
               "original_artifacts": originals, "native_inputs": native,
               "checkout_before": base + "/publication-checkout-before.json", "scope": SCOPE}
    install_plan(plan, receipt, args, base)
    return receipt


def install_plan(plan, receipt, args, base):
    # All admission checks finish before any output is installed. Roll back any
    # copy failure; historical evidence is never replaced by this transaction.
    previous = {path: (ROOT / path).read_bytes() for path in (*RUNTIMES.values(), *MANIFESTS.values())}
    installed = []
    try:
        for relative, data in sorted(plan.items()):
            destination = checked_destination(relative)
            destination.parent.mkdir(parents=True, exist_ok=True)
            installed.append(relative)
            destination.write_bytes(data)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(encoded(receipt))
        verify_prepared(args, staged=False)
    except BaseException:
        for relative in reversed(installed):
            path = ROOT / relative
            if relative in previous:
                path.write_bytes(previous[relative])
            else:
                path.unlink(missing_ok=True)
        if checked_destination(base).exists():
            shutil.rmtree(checked_destination(base))
        args.output.unlink(missing_ok=True)
        raise
    return receipt


def verify_prepared(args, *, staged):
    ctx = context()
    receipt = load(args.output)
    require(receipt.get("schema") == "cybersand.sol281.runtime-publication.v1" and receipt.get("status") == "prepared"
            and all(receipt.get(key) == value for key, value in ctx.items()), "Publication receipt source/context mismatch")
    paths = receipt.get("publication_paths", [])
    require(paths == sorted(set(paths)) == sorted(receipt.get("files", {})), "Publication file inventory differs")
    base = EVIDENCE + "/" + ctx["source"]["sha"]
    fixed = set(RUNTIMES.values()) | set(MANIFESTS.values())
    require(fixed <= set(paths) and all(path in fixed or path.startswith(base + "/") for path in paths), "Publication path outside bounded scope")
    for path in paths:
        value = checked_destination(path)
        require(value.is_file() and {"sha256": qualification.digest(value), "size": value.stat().st_size} == receipt["files"][path], "Prepared publication bytes changed: " + path)
    suffix = ctx["run_id"] + "-" + ctx["run_attempt"]
    build_names = {target: f"sol281-build-{target}-{suffix}" for target in RUNTIMES}
    host_names = {(target, cohort): f"sol281-host-{target}-{cohort}-{suffix}"
                  for target in RUNTIMES for cohort in qualification.COHORTS}
    build_roots = artifact_roots(args.build_root, build_names.values())
    host_roots = artifact_roots(args.evidence_root, host_names.values())
    if staged:
        inputs, summary = clean_source_verification(args.evidence_root)
        require((ROOT / base / "qualification.json").read_bytes() == summary,
                "Durable qualification differs from fresh unchanged HEAD reducer")
    else:
        inputs = load(build_roots[build_names["linux"]] / "build.json")["inputs"]
    native = native_ledger(inputs)
    require(native == receipt["native_inputs"], "Native source identity/path set changed")
    originals = {}
    generated = {}
    for target, name in build_names.items():
        directory = build_roots[name]
        build, identity, files = verify_build(directory, target, ctx, inputs)
        for relative, artifact in files.items():
            originals["builds/" + name + "/" + relative] = {
                "sha256": qualification.digest(artifact), "size": artifact.stat().st_size}
        cohorts = []
        for cohort in qualification.COHORTS:
            artifact_name = host_names[(target, cohort)]
            report, host_files = verify_host(host_roots[artifact_name], target, cohort, ctx,
                build, qualification.digest(directory / "build.json"))
            for relative, artifact in host_files.items():
                originals["hosts/" + artifact_name + "/" + relative] = {
                    "sha256": qualification.digest(artifact), "size": artifact.stat().st_size}
                published = base + "/cohorts/" + target + "/" + cohort + "/" + relative
                require(published in receipt["files"] and checked_destination(published).read_bytes() == artifact.read_bytes(),
                        "Durable original host evidence differs")
            report_relative = base + "/cohorts/" + target + "/" + cohort + ("/host" if target == "linux" else "") + "/report.json"
            cohorts.append({"cohort": cohort, "report": report_relative,
                            "report_sha256": qualification.digest(ROOT / report_relative), "cases": len(report["records"])})
        generated.update(make_manifest(target, ctx, inputs, native, identity, build,
            (directory / "build.json").read_bytes(), base, cohorts))
        for key in ("build.json", "before.json"):
            require((ROOT / base / "build" / target / key).read_bytes() == (directory / key).read_bytes(),
                    "Durable original build manifest differs")
        require(commonengine.runtime_identity(ROOT / RUNTIMES[target], target) == identity,
                "Published runtime signature/hash/size changed")
    require(originals == receipt["original_artifacts"], "Original artifact inventory/hash/size changed")
    for path, data in generated.items():
        require(checked_destination(path).read_bytes() == data, "Published metadata differs from freshly validated artifacts")
    verify_checkout(inputs, generated)
    before = load(checked_destination(receipt["checkout_before"]))
    require(set(before) == set(inputs), "Publication raw checkout inventory differs")
    for path, expected in before.items():
        if path not in MANIFESTS.values():
            require(qualification.digest(checked_destination(path)) == expected, "Raw checkout changed after preparation")
    durable = files_in(ROOT / base)
    require({base + "/" + path for path in durable} == set(paths) - fixed, "Durable evidence inventory changed")
    if staged:
        verify_index(paths, receipt["files"])
    return receipt


def verify_index(paths, files):
    changed = set(qualification.git("diff", "--cached", "--name-only", "-z").decode().split("\0")) - {""}
    require(changed == set(paths), "Staged path set differs from exact publication inventory")
    for path in paths:
        entry = qualification.git("ls-files", "--stage", "--", path).decode().splitlines()
        require(len(entry) == 1 and entry[0].startswith("100644 ") and entry[0].endswith(" 0\t" + path), "Publication entry is not a regular stage-zero file")
        blob = qualification.git("show", ":" + path)
        if path in RUNTIMES.values():
            expected = files[path]
            pointer = ("version https://git-lfs.github.com/spec/v1\noid sha256:" + expected["sha256"]
                       + "\nsize " + str(expected["size"]) + "\n").encode()
            require(blob == pointer, "Staged runtime is not the exact canonical LFS pointer")
        else:
            require(sha(blob) == files[path]["sha256"]
                    and len(blob) == files[path]["size"], "Staged evidence/provenance bytes changed (including EOL conversion)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-root", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--verify-staged", action="store_true")
    args = parser.parse_args()
    try:
        receipt = verify_prepared(args, staged=True) if args.verify_staged else prepare(args)
        print(json.dumps({"status": "staged-verified" if args.verify_staged else "prepared", "source": receipt["source"],
                          "publication_paths": receipt["publication_paths"]}, sort_keys=True))
        return 0
    except (RuntimeError, ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print("SOL281 runtime publication refused: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
