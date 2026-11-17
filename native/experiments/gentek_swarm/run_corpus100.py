#!/usr/bin/env python3
"""Execute the immutable registered CORPUS-100 without changing SWARM behaviour.

Every case has a separate bounded process and retained command receipt. Failed
cases keep their identity. The exact same requests replay byte-for-byte; both
ASan and UBSan are available for the focused suite and all hundred cases. This
runner never selects aesthetically favourable results or invokes a gallery.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PARENT = "267f522222a1eb59b44e92f60a5a06f018af0ad3"
PREFIX = "native/experiments/gentek_swarm/"
GROUP_COUNTS = {
    "frameweaver_solo": 20, "mosaic_solo": 15, "receptor_solo": 10,
    "frameweaver_mosaic": 25, "frameweaver_receptor": 15,
    "mosaic_receptor": 10, "pathological": 5,
}
GROUP_KINDS = {
    "frameweaver_solo": ("FRAMEWEAVER", None),
    "mosaic_solo": ("MOSAIC", None), "receptor_solo": ("RECEPTOR", None),
    "frameweaver_mosaic": ("FRAMEWEAVER", "MOSAIC"),
    "frameweaver_receptor": ("FRAMEWEAVER", "RECEPTOR"),
    "mosaic_receptor": ("MOSAIC", "RECEPTOR"),
}
KINDS = {"FRAMEWEAVER", "MOSAIC", "RECEPTOR"}
FIXTURES = {"free", "stepped_diagonal", "concave_intrusion", "protected_corridor", "foreign_solid", "island", "narrow_neck"}
PROFILES = {"sparse_regular", "branching_irregular", "dense_cohesive", "damaged_derivative"}
COMPILED = ["common.cpp", "fixtures.cpp", "meshing.cpp", "io.cpp", "frameweaver.cpp", "mosaic.cpp", "receptor.cpp"]
DONORS = ["native/src/generation_spatial.cpp", "native/include/cybersand/material.hpp", "native/include/cybersand/generation_spatial.hpp", "native/include/cybersand/generation_numeric.hpp"]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args, binary=False):
    data = subprocess.check_output(["git", "-C", str(ROOT), *args])
    return data if binary else data.decode().strip()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def frozen_inputs():
    """Match the frozen Makefile's definition order and path spelling exactly."""
    names = git("ls-tree", "--name-only", PARENT, PREFIX).splitlines()
    native_names = sorted(Path(name).name for name in names if name.endswith(".cpp"))
    relative = native_names + ["swarm.hpp"] + ["../../../" + p for p in DONORS]
    payload = b"".join(p.encode() + b"\0" + (HERE / p).read_bytes() for p in relative)
    frozen = [PREFIX + p for p in native_names + ["swarm.hpp", "Makefile"]] + DONORS
    # Record the entire possible native header closure as well as actual sources.
    frozen += [p.as_posix() for p in sorted(Path("native/include/cybersand").glob("*.hpp"))]
    frozen = sorted(set(frozen))
    inputs = {}
    for path in frozen:
        actual = (ROOT / path).read_bytes()
        expected = git("show", f"{PARENT}:{path}", binary=True)
        if actual != expected:
            raise RuntimeError(f"Frozen generator/donor input changed: {path}")
        inputs[path] = sha(actual)
    return sha(payload), inputs


def validate_registration(document):
    if document.get("source_parent") != PARENT:
        raise ValueError("Registration names a different frozen source parent")
    cases = document.get("cases")
    if not isinstance(cases, list) or len(cases) != 100:
        raise ValueError("Registration must contain exactly 100 cases")
    counts = Counter(c.get("group") for c in cases)
    if counts != GROUP_COUNTS:
        raise ValueError(f"Registered allocation mismatch: {dict(counts)}")
    ids = set()
    identities = set()
    for case in cases:
        cid = case.get("case_id", "")
        if not isinstance(cid, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,96}", cid) or cid in ids:
            raise ValueError(f"Invalid or duplicate registered ID: {cid!r}")
        ids.add(cid)
        pair = (case.get("kind"), case.get("right_kind"))
        if pair[0] not in KINDS or (pair[1] is not None and pair[1] not in KINDS):
            raise ValueError(f"Unknown kind in {cid}")
        expected = GROUP_KINDS.get(case["group"])
        if expected is not None and pair != expected:
            raise ValueError(f"Wrong pairing for group in {cid}")
        if case.get("fixture") not in FIXTURES or case.get("profile") not in PROFILES:
            raise ValueError(f"Unknown frozen fixture/profile in {cid}")
        seed = case.get("seed")
        if type(seed) is not int or not 0 <= seed < 2**64:
            raise ValueError(f"Invalid seed in {cid}")
        side = case.get("side", 0 if pair[1] else -1)
        if type(side) is not int or side not in (-1, 0, 1) or (pair[1] and side != 0):
            raise ValueError(f"Invalid side in {cid}")
        if case.get("dimensions", [192, 112]) not in ([192, 112], {"width": 192, "height": 112}):
            raise ValueError(f"Changed frozen fixture dimensions in {cid}")
        if case.get("origin", [-96, -56]) != [-96, -56]:
            raise ValueError(f"Changed frozen fixture origin in {cid}")
        overrides = case.get("overrides", {})
        if not isinstance(overrides, dict) or set(overrides) - {"max_work", "max_bytes", "max_instances", "empty_eligible", "environment_affinity"}:
            raise ValueError(f"Unsupported request override in {cid}")
        if pair[1] and overrides:
            raise ValueError(f"Frozen pair API does not accept overrides: {cid}")
        for name, limit in (("max_work", 64_000_000), ("max_bytes", 64 * 1024 * 1024), ("max_instances", 256)):
            if name in overrides and (type(overrides[name]) is not int or not 0 <= overrides[name] <= limit):
                raise ValueError(f"Invalid {name} override in {cid}")
        if "empty_eligible" in overrides and type(overrides["empty_eligible"]) is not bool:
            raise ValueError(f"Invalid empty_eligible override in {cid}")
        if "environment_affinity" in overrides:
            value = overrides["environment_affinity"]
            if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 1:
                raise ValueError(f"Invalid affinity override in {cid}")
        identity = json.dumps([*pair, case["fixture"], case["profile"], seed, side, overrides], sort_keys=True)
        if identity in identities:
            raise ValueError(f"Duplicate request identity despite distinct ID: {cid}")
        identities.add(identity)
    return cases


def argv_for(binary, destination, source, case, reverse=False):
    overrides = case.get("overrides", {})
    return [binary, destination, source, case["case_id"], case["kind"], case.get("right_kind") or "-",
            case["fixture"], case["profile"], case["seed"], case.get("side", 0 if case.get("right_kind") else -1),
            overrides.get("max_work", "-"), overrides.get("max_bytes", "-"), overrides.get("max_instances", "-"),
            int(overrides.get("empty_eligible", False)), overrides.get("environment_affinity", "-"), int(reverse)]


def expected_profile(case):
    """Frozen common.cpp profile values, checked independently of dispatch."""
    profile = {"name": case["profile"], "variation": 0.65, "irregularity": 0.75,
               "clutter": 0.25, "destruction": 0.0, "branching": 0.8,
               "environment_affinity": 0.7, "cohesion": 0.15}
    if case["profile"] == "sparse_regular":
        profile.update(variation=0.15, irregularity=0.05, clutter=0.05,
                       branching=0.15, environment_affinity=0.25, cohesion=0.0)
    elif case["profile"] == "dense_cohesive":
        profile.update(variation=0.65, irregularity=0.45, clutter=0.8,
                       branching=0.8, environment_affinity=1.0, cohesion=0.85)
    elif case["profile"] == "damaged_derivative":
        profile["destruction"] = 0.65
    overrides = case.get("overrides", {})
    if "environment_affinity" in overrides:
        profile["environment_affinity"] = overrides["environment_affinity"]
    return profile


def expected_limits(kind, case):
    limits = {"instances": 192 if kind == "MOSAIC" else 64, "frontier": 256,
              "candidates": 8192, "connectors_per_instance": 8, "affordances": 256,
              "cohesion_patches": 8, "cohesion_cells_per_patch": 512,
              "work": 2_000_000, "solver_work": 4_000_000, "bytes": 16 * 1024 * 1024}
    for override, field in (("max_instances", "instances"), ("max_work", "work"), ("max_bytes", "bytes")):
        if override in case.get("overrides", {}):
            limits[field] = case["overrides"][override]
    return limits


def verify_output(raw, case, source, definition):
    """Check identities, actual parameter values and all controls' hard gates.

    Registered UNSAT/blocked/exhausted/damaged outcomes remain valid evidence.
    Invalid requests or internal-invalid output are correctness defects, never a
    successful registered negative example; their raw evidence remains retained.
    """
    data = json.loads(raw.read_text())
    expected_type = "pair" if case.get("right_kind") else "single"
    if data.get("type") != expected_type:
        raise ValueError("native output type differs from registration")
    kinds = [case["kind"]] if expected_type == "single" else [case["kind"], case["right_kind"]]
    results = [data["result"]] if expected_type == "single" else [data[k] for k in ("left", "right", "initial_left", "initial_right", "clipped_left", "clipped_right")]
    requests = [data["request"]] if expected_type == "single" else [data["left_request"], data["right_request"]]
    result_kinds = kinds if expected_type == "single" else kinds * 3
    profile = expected_profile(case)
    dimensions = case.get("dimensions", [192, 112])
    if isinstance(dimensions, dict):
        dimensions = [dimensions["width"], dimensions["height"]]
    origin = case.get("origin", [-96, -56])
    prefixes = {"FRAMEWEAVER": "frameweaver.frontier-growth-v0.",
                "MOSAIC": "mosaic.prepared-regions-v0.",
                "RECEPTOR": "receptor.surface-field-v0."}
    for request, kind in zip(requests, kinds, strict=True):
        if request["source"] != source or request["seed"] != case["seed"] or request["fixture"] != case["fixture"]:
            raise ValueError("native request identity differs from registration")
        if request["gentek"] != kind or request["version"] != 0 or request["definition"] != prefixes[kind] + definition:
            raise ValueError("native request kind/version/definition differs from registration")
        if [request["width"], request["height"]] != dimensions or request["origin"] != origin:
            raise ValueError("native fixture dimensions/origin differ from registration")
        if request["profile"] != profile:
            raise ValueError("native profile values differ from registered frozen profile/overrides")
        if request["limits"] != expected_limits(kind, case):
            raise ValueError("native limit values differ from registered frozen limits/overrides")
        if case.get("overrides", {}).get("empty_eligible", False) and (len(request["eligible"]) != dimensions[0] * dimensions[1] or any(request["eligible"])):
            raise ValueError("registered empty eligible mask was not applied")
    hard = data.get("conflicts", 0) + data.get("protected_violations", 0)
    for result, kind in zip(results, result_kinds, strict=True):
        if result["source"] != source or result["definition"] != prefixes[kind] + definition or result["gentek"] != kind:
            raise ValueError("native result source/kind/definition identity drift")
        if result["seed"] != case["seed"] or [result["width"], result["height"]] != dimensions:
            raise ValueError("native result seed/dimensions drift")
        if result["status"] == "invalid":
            raise ValueError("INVALID native result: correctness defect; affected comparison fails and raw evidence is retained")
        if result["status"] not in {"complete", "blocked", "exhausted", "unsat", "damaged"}:
            raise ValueError("unrecognised native outcome")
        hard += result["protected_violations"] + result["illegal_overlaps"]
        if result["cells"] and len(result["cells"]) != dimensions[0] * dimensions[1]:
            raise ValueError("material array dimensions differ from fixture")
    if hard:
        raise ValueError(f"hard geometry violation count: {hard}")
    return {"raw_sha256": sha(raw.read_bytes()), "type": expected_type,
            "statuses": [r["status"] for r in results], "hard_geometry_violations": hard,
            "material_digests": [r["material_digest"] for r in results],
            "semantic_digests": [r["digest"] for r in results]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registration", type=Path, default=HERE / "corpus100-registration.json")
    parser.add_argument("--registration-commit", required=True, help="Published preregistration commit; registration bytes must still match")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--build", type=Path, default=Path("/tmp/gentek-corpus100-build"))
    parser.add_argument("--sanitize", action="store_true")
    parser.add_argument("--case-timeout", type=int, default=120)
    args = parser.parse_args()
    os.chdir(ROOT)
    out, build_root, registration = args.out.resolve(), args.build.resolve(), args.registration.resolve()
    if out.is_relative_to(ROOT) or build_root.is_relative_to(ROOT):
        parser.error("Keep evidence/build output outside the repository")
    if out.exists() and any(out.iterdir()):
        parser.error("Use a fresh evidence destination; retained failures cannot be overwritten")
    if args.case_timeout <= 0 or args.case_timeout > 600:
        parser.error("Case timeout must be 1..600 seconds")
    if not re.fullmatch(r"[0-9a-f]{40}", args.registration_commit):
        parser.error("Preregistration commit must be an exact forty-character SHA")
    source = git("rev-parse", "HEAD")
    if git("status", "--porcelain"):
        parser.error("Qualification requires a clean committed checkout")
    for ancestor in (PARENT, args.registration_commit):
        subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", ancestor, source], check=True)
    registration_relative = registration.relative_to(ROOT).as_posix()
    registered_bytes = registration.read_bytes()
    if registered_bytes != git("show", f"{args.registration_commit}:{registration_relative}", binary=True):
        parser.error("Case registration changed after its declared publication")
    cases = validate_registration(json.loads(registered_bytes))
    definition, frozen = frozen_inputs()
    source_inputs = dict(frozen)
    for path in (HERE / "corpus100.cpp", Path(__file__).resolve(), registration):
        source_inputs[path.relative_to(ROOT).as_posix()] = sha(path.read_bytes())
    fingerprint = sha(json.dumps(source_inputs, sort_keys=True).encode())
    build_root.mkdir(parents=True, exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix=fingerprint[:16] + "-", dir=build_root))
    out.mkdir(parents=True, exist_ok=True)
    (out / "logs").mkdir()
    (out / "registration.json").write_bytes(registered_bytes)
    manifest = {
        "programme": "GENTEK-SWARM-CORPUS-100", "scope": "Phase A evidence only; Draft/HOLD",
        "source_commit": source, "source_tree": git("rev-parse", "HEAD^{tree}"), "exact_parent": PARENT,
        "branch": git("branch", "--show-current"), "clean_source": True,
        "registration_commit": args.registration_commit, "registration_sha256": sha(registered_bytes),
        "source_input_fingerprint": fingerprint, "compiled_definition_fingerprint": definition,
        "source_inputs": source_inputs, "frozen_inputs_unchanged": True,
        "started_utc": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(),
        "python": sys.version, "compiler": subprocess.check_output([os.environ.get("CXX", "g++"), "--version"], text=True).splitlines()[0],
        "fresh_build_directory": str(build), "group_counts": dict(Counter(c["group"] for c in cases)),
        "sanitizers_requested": args.sanitize, "leak_sanitizer": "disabled under host instrumentation; no leak-check claim",
        "commands": [], "cases": [], "result": "RUNNING",
    }
    active = None

    def save():
        write_json(out / "manifest.json", manifest)

    def stop_child():
        nonlocal active
        if active is None:
            return
        try:
            os.killpg(active.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            active.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(active.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            active.wait(timeout=5)
        # Always kill the exact process group, even if its parent exited first.
        try:
            os.killpg(active.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def interrupted(signum, _frame):
        stop_child()
        raise KeyboardInterrupt(f"received signal {signum}")

    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, interrupted)

    def execute(label, argv, timeout, required=True):
        nonlocal active
        argv = list(map(str, argv)); started = time.monotonic()
        log = out / "logs" / (label + ".log")
        receipt = {"label": label, "argv": argv, "timeout_seconds": timeout, "log": log.relative_to(out).as_posix()}
        env = os.environ.copy()
        env["ASAN_OPTIONS"] = "detect_leaks=0:halt_on_error=1"
        env["UBSAN_OPTIONS"] = "halt_on_error=1"
        try:
            with log.open("w") as stream:
                active = subprocess.Popen(argv, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, env=env, start_new_session=True)
                try:
                    receipt["exit_code"] = active.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    receipt["timed_out"] = True
                    stop_child()
                    receipt["exit_code"] = active.returncode
        finally:
            if active is not None:
                stop_child()
            active = None
            receipt["elapsed_seconds"] = round(time.monotonic() - started, 3)
            receipt["log_sha256"] = sha(log.read_bytes())
            manifest["commands"].append(receipt)
            save()
        ok = receipt.get("exit_code") == 0 and not receipt.get("timed_out")
        if required and not ok:
            raise RuntimeError(f"{label} failed; retained receipt {receipt['log']}")
        return ok

    def build_program(name, main_cpp, sanitized=False):
        compiler = os.environ.get("CXX", "g++")
        command = [compiler, "-std=c++20", "-Wall", "-Wextra", "-Wpedantic", "-Werror",
                   "-I" + str(ROOT / "native/include"), '-DGENTEK_DEFINITION_SHA256="' + definition + '"']
        command += ["-O1", "-g", "-fno-omit-frame-pointer", "-fsanitize=address,undefined"] if sanitized else ["-O2"]
        command += [str(HERE / p) for p in COMPILED] + [str(ROOT / DONORS[0]), str(HERE / main_cpp), "-o", str(build / name)]
        execute("build-" + name, command, 600)
        return build / name

    try:
        save()
        native = build_program("corpus100", "corpus100.cpp")
        tests = build_program("test_gentek_swarm", "tests.cpp")
        execute("native-tests", [tests], 300)
        modes = [("native", native), ("replay", native)]
        if args.sanitize:
            sanitized = build_program("corpus100_sanitized", "corpus100.cpp", True)
            sanitized_tests = build_program("test_gentek_swarm_sanitized", "tests.cpp", True)
            execute("sanitizer-tests", [sanitized_tests], 300)
            modes.append(("sanitized", sanitized))
        case_receipts = {case["case_id"]: {"case_id": case["case_id"], "registered_request": case, "executions": {}} for case in cases}
        manifest["cases"] = list(case_receipts.values())
        failures = []
        for mode, binary in modes:
            directory = out / mode; directory.mkdir()
            for case in cases:
                cid = case["case_id"]; raw = directory / (cid + ".json")
                ok = execute(mode + "-" + cid, argv_for(binary, raw, source, case), args.case_timeout, required=False)
                receipt = {"raw": raw.relative_to(out).as_posix(), "process_pass": ok}
                if raw.exists():
                    try:
                        receipt.update(verify_output(raw, case, source, definition))
                        if mode != "native":
                            original = out / "native" / raw.name
                            receipt["byte_identical_to_native"] = original.exists() and raw.read_bytes() == original.read_bytes()
                            if not receipt["byte_identical_to_native"]:
                                raise ValueError("deterministic raw JSON replay mismatch")
                    except Exception as error:
                        receipt["validation_error"] = str(error); ok = False
                else:
                    receipt["validation_error"] = "Native case produced no raw JSON; identity and failure retained"; ok = False
                receipt["result"] = "PASS" if ok else "FAIL"
                case_receipts[cid]["executions"][mode] = receipt
                if not ok:
                    failures.append({"case_id": cid, "mode": mode, "receipt": receipt})
                save()
            print(f"[{mode}] registered cases executed=100 failures={sum(r['executions'][mode]['result'] != 'PASS' for r in case_receipts.values())}", flush=True)
        manifest["failed_cases"] = failures
        manifest["retained_case_count"] = 100
        manifest["native_raw_count"] = len(list((out / "native").glob("*.json")))
        manifest["replay_raw_count"] = len(list((out / "replay").glob("*.json")))
        manifest["sanitized_raw_count"] = len(list((out / "sanitized").glob("*.json"))) if args.sanitize else 0
        if failures:
            raise RuntimeError(f"{len(failures)} failed case executions retained; none replaced")
        if git("rev-parse", "HEAD") != source or git("status", "--porcelain"):
            raise RuntimeError("Source checkout changed during qualification")
        if any(sha((ROOT / path).read_bytes()) != digest for path, digest in source_inputs.items()):
            raise RuntimeError("Source input changed during qualification")
        manifest["result"] = "PASS"
    except BaseException as error:
        manifest["result"] = "FAIL"
        manifest["error"] = str(error)
        raise
    finally:
        stop_child()
        manifest["finished_utc"] = datetime.now(timezone.utc).isoformat()
        manifest["binaries"] = {p.name: sha(p.read_bytes()) for p in sorted(build.iterdir()) if p.is_file()}
        save()
    print(f"CORPUS-100 PASS: {out / 'manifest.json'}", flush=True)


if __name__ == "__main__":
    main()
