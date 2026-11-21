#!/usr/bin/env python3
"""Build immutable controls and retain SWARM-006 comparisons without filtering failures.

This is a native laboratory, never a reproduction of the owner's existing World
or physical Windows/NVIDIA acceptance. No unseen corpus is selected by this file.
"""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import gzip
import hashlib
import itertools
import json
import os
from pathlib import Path
import platform
import re
import signal
import statistics
import struct
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
CORE = ("common", "fixtures", "meshing", "io", "frameweaver", "mosaic", "receptor",
        "negotiated", "mosaic_admission", "resilience_solver", "assembly", "reciprocal_mosaic",
        "reciprocal", "generation_spatial", "reciprocal_io")
RECOVERY_CORE = ("mosaic_recovery", "recovery_admission")
FROZEN = {"swarm004": "2c4b8061ef5315de6a31df933e9f84c31865284e",
          "swarm005": "c178feeb39899fd155b7deb9d5bde3f50ee28548"}
EXPRESSIONS = ("industrial", "viaduct_like", "irregular_megastructure")
REVEALED_005_SEEDS = (707861, 414855, 959922, 681376)
REVEALED_005_POLICIES = (("off", 2), ("terminal_only", 2), ("receptor_only", 2), ("both", 2),
    ("both", 1), ("both", 0), ("both+frame_frozen", 2), ("both+mosaic_frozen", 2),
    ("both+hard_only", 2), ("both+fixed", 2))
FRESH_EXCLUDED_SEEDS = frozenset((*REVEALED_005_SEEDS, 605, 4099, 19457))
REGISTERED_FIXTURES = frozenset(("stepped_diagonal", "concave_intrusion", "protected_corridor",
    "foreign_solid", "island", "narrow_neck", "free", "owner_left_right_192x112", "owner_left_right_128x128",
    "maximum_left_right_256x128"))
REGISTERED_PROFILES = frozenset((*EXPRESSIONS, "industrial_gui", "sparse_regular", "dense_cohesive", "branching_irregular", "damaged_derivative"))
REGISTERED_LIMITS = {"frame_work": 2_000_000, "mosaic_work": 2_000_000, "solver_work": 4_000_000,
    "shared_work": 2_000_000, "memory_bytes": 16 * 1024 * 1024, "max_reservations": 8, "max_rounds": 4}


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def canonical(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def atomic_json(path: Path, value) -> None:
    temporary = path.with_name(path.name + ".partial")
    temporary.write_bytes(json.dumps(value, indent=2, allow_nan=False).encode() + b"\n")
    temporary.replace(path)


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def source_inputs(root: Path) -> dict:
    native = root / "native/experiments/gentek_swarm"
    paths = list(native.glob("*.cpp")) + list(native.glob("*.hpp")) + list(native.glob("Makefile*"))
    paths += list((root / "native/include/cybersand").rglob("*.hpp"))
    paths += [root / "native/src/generation_spatial.cpp"]
    return {p.relative_to(root).as_posix(): sha(p) for p in sorted(set(paths))}


def definition(root: Path) -> str:
    """Exactly the historical Makefile.reciprocal input spelling and ordering."""
    native = root / "native/experiments/gentek_swarm"
    names = sorted(p.name for p in native.glob("*.cpp")) + sorted(p.name for p in native.glob("*.hpp"))
    names += ["../../../native/src/generation_spatial.cpp", "../../../native/include/cybersand/material.hpp",
              "../../../native/include/cybersand/generation_spatial.hpp", "../../../native/include/cybersand/generation_numeric.hpp"]
    h = hashlib.sha256()
    for name in names:
        h.update(name.encode() + b"\0" + (native / name).read_bytes())
    return h.hexdigest()


def execute(command: list[str], log: Path, timeout: int, cwd: Path | None = None) -> dict:
    record = {"argv": command, "cwd": str(cwd) if cwd else None, "started_utc": now(),
              "timeout_seconds": timeout, "timed_out": False, "cancelled": False}
    started = time.monotonic()
    with log.open("xb") as stream:
        process = subprocess.Popen(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=os.name != "nt")
        record["pid"] = process.pid
        try:
            record["returncode"] = process.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            record["timed_out"] = isinstance(error, subprocess.TimeoutExpired)
            record["cancelled"] = isinstance(error, KeyboardInterrupt)
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], check=False,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                os.killpg(process.pid, signal.SIGKILL)
            record["returncode"] = process.wait(timeout=20)
    record.update({"elapsed_seconds": time.monotonic() - started, "ended_utc": now(),
                   "log_sha256": sha(log), "child_reaped": process.poll() is not None})
    return record


def fresh_directory(path: Path) -> None:
    if path.exists():
        raise ValueError(f"Refusing existing evidence/build directory: {path}")
    path.mkdir(parents=True)


def build(args) -> int:
    root, output = args.source_root.resolve(), args.build.resolve()
    if output.is_relative_to(root):
        raise ValueError("Build output must be outside the source repository")
    source = git(root, "rev-parse", "HEAD")
    dirty = git(root, "status", "--porcelain")
    if args.variant in FROZEN and (source != FROZEN[args.variant] or dirty):
        raise ValueError("Frozen controls require their exact committed clean source")
    if dirty and not args.allow_dirty:
        raise ValueError("Dirty candidate requires explicit --allow-dirty development labeling")
    inputs = source_inputs(root)
    fresh_directory(output)
    native = root / "native/experiments/gentek_swarm"
    # Compile a retained harness snapshot outside its own checkout. Quoted C++
    # includes must resolve to the selected frozen source, not this script's
    # newer sibling headers. This also prevents concurrent harness edits from
    # silently changing the source represented by the build receipt.
    harness_copy = output / "swarm006_experiment_main.cpp"
    harness_copy.write_bytes((HERE / "swarm006_experiment_main.cpp").read_bytes())
    receipt = {"schema": 1, "scope": "native comparison harness; no Workbench or owner qualification",
        "variant": args.variant, "source_root": str(root), "source_commit": source,
        "source_tree": git(root, "rev-parse", "HEAD^{tree}"), "source_dirty": dirty,
        "allow_dirty_requested": args.allow_dirty,
        "source_inputs": inputs, "definition_sha256": definition(root), "platform": platform.platform(),
        "harness": str(harness_copy), "harness_sha256": sha(harness_copy),
        "runner_sha256": sha(Path(__file__)), "started_utc": now(), "commands": [], "result": "RUNNING"}
    atomic_json(output / "build.json", receipt)
    target = str(output / "gentek_reciprocal")
    command = ["make", "-j2", "-f", "Makefile.reciprocal", "BUILD=" + str(output), "CXX=" + args.cxx, target]
    if args.sanitize: command += ["SANITIZE=1"]
    receipt["commands"].append(execute(command, output / "build-core.log", args.timeout, native))
    if receipt["commands"][-1]["returncode"] == 0:
        binary = output / ("swarm006_experiment.exe" if os.name == "nt" else "swarm006_experiment")
        mode = ["-O1", "-g", "-fno-omit-frame-pointer", "-fsanitize=address,undefined"] if args.sanitize else ["-O2"]
        flags = ["-DGENTEK_SWARM005=1"] if args.variant == "swarm005" else []
        if args.variant == "swarm006": flags = ["-DGENTEK_SWARM005=1", "-DGENTEK_SWARM006_RECOVERY=1"]
        core = CORE + (tuple(name for name in RECOVERY_CORE if (native / (name + ".cpp")).exists())
                       if args.variant == "swarm006" else ())
        command = [args.cxx, "-std=c++20", "-Wall", "-Wextra", "-Wpedantic", "-Werror", *mode,
            "-I" + str(native), "-I" + str(root / "native/include"), *flags,
            '-DGENTEK_DEFINITION_SHA256="' + receipt["definition_sha256"] + '"',
            str(harness_copy), *(str(output / (name + ".o")) for name in core),
            "-o", str(binary)]
        receipt["commands"].append(execute(command, output / "build-driver.log", args.timeout))
        if receipt["commands"][-1]["returncode"] == 0:
            receipt["binary"] = str(binary)
            receipt["binary_sha256"] = sha(binary)
            receipt["capabilities"] = json.loads(subprocess.check_output([str(binary), "describe"], text=True))
    receipt["source_custody_revalidated"] = source_inputs(root) == inputs and git(root, "rev-parse", "HEAD") == source
    receipt["result"] = "PASS" if receipt.get("binary") and receipt["source_custody_revalidated"] else "FAIL"
    receipt["ended_utc"] = now()
    atomic_json(output / "build.json", receipt)
    print(json.dumps({k: receipt.get(k) for k in ("result", "variant", "source_commit", "binary", "binary_sha256")}))
    return 0 if receipt["result"] == "PASS" else 1


def cases(suite: str) -> list[dict]:
    if suite == "revealed005":
        return [{"fixture": f, "profile": p, "seed": s} for f, p, s in itertools.product(
            ("island", "concave_intrusion", "foreign_solid"), EXPRESSIONS, REVEALED_005_SEEDS)]
    owner = [{"fixture": "owner_left_right_192x112", "profile": p, "seed": 605}
             for p in (*EXPRESSIONS, "industrial_gui")]
    owner += [{"fixture": "owner_left_right_128x128", "profile": "irregular_megastructure", "seed": 605},
              {"fixture": "fixed4099", "profile": "viaduct_like", "seed": 4099}]
    if suite == "owner": return owner
    if suite == "stress":
        return [{"fixture": "maximum_left_right_256x128", "profile": p, "seed": 605} for p in EXPRESSIONS]
    if suite != "development": raise ValueError("Unknown suite")
    return owner + [{"fixture": f, "profile": p, "seed": s} for f, p, s in itertools.product(
        ("protected_corridor", "narrow_neck"), ("sparse_regular", "dense_cohesive", "branching_irregular"), (605, 19457))]


def policies(variant: str, suite: str, requested: list[str] | None) -> list[tuple[str, int]]:
    if requested:
        result = []
        for value in requested:
            policy, sep, rounds = value.rpartition("@")
            if not sep or not rounds.isdecimal() or not 0 <= int(rounds) <= 4:
                raise ValueError("Policy must be NAME@ROUNDS with rounds 0..4")
            result.append((policy, int(rounds)))
        if len(set(result)) != len(result): raise ValueError("Duplicate policy execution")
        return result
    if suite == "revealed005" and variant != "swarm004": return list(REVEALED_005_POLICIES)
    if suite == "stress":
        base = "recovery" if variant == "swarm006" else "both" if variant == "swarm005" else "off"
        return [(base + suffix, 4) for suffix in ("", "+cancel", "+frame_budget", "+mosaic_budget", "+solver_budget", "+memory_budget")]
    result = [("off", 2)]
    if variant != "swarm004": result += [(p, 2) for p in ("terminal_only", "receptor_only", "both")]
    if variant == "swarm006":
        result += [("recovery", r) for r in range(5)]
        result += [("recovery" + suffix, 2) for suffix in ("+fixed", "+hard_only", "+frame_frozen", "+mosaic_frozen", "+no_offers", "+reverse")]
    return result


def validate_registration(value: dict, receipt: dict, runner_sha256: str) -> tuple[list[dict], list[tuple[str, int]]]:
    """Validate a future preregistration without selecting any new corpus."""
    required = {"schema", "programme", "classification", "registration_id", "candidate", "limits",
                "cases", "policies", "case_count", "execution_count", "controls", "timeout_seconds"}
    if not isinstance(value, dict) or set(value) != required:
        raise ValueError("Registration fields must match the declared schema exactly")
    if type(value["schema"]) is not int or value["schema"] != 1 or value["programme"] != "GENTEK-SWARM-006" or value["classification"] != "preregistered_unseen":
        raise ValueError("Not a SWARM-006 unseen preregistration")
    if not isinstance(value["registration_id"], str) or not 1 <= len(value["registration_id"]) <= 96:
        raise ValueError("Invalid registration identity")
    if receipt.get("result") != "PASS" or receipt.get("variant") != "swarm006" or receipt.get("source_dirty") != "" or receipt.get("allow_dirty_requested") is not False or not receipt.get("source_custody_revalidated"):
        raise ValueError("A preregistered campaign requires an exact clean source build")
    candidate = value["candidate"]
    keys = {"git_sha", "definition_sha256", "harness_sha256", "runner_sha256"}
    if not isinstance(candidate, dict) or set(candidate) != keys:
        raise ValueError("Registration must bind source, native definition, harness and runner")
    for key, count in (("git_sha", 40), ("definition_sha256", 64), ("harness_sha256", 64), ("runner_sha256", 64)):
        if not isinstance(candidate[key], str) or re.fullmatch("[0-9a-f]{" + str(count) + "}", candidate[key]) is None:
            raise ValueError("Invalid registration source or SHA-256 identity")
    expected = {"git_sha": receipt["source_commit"], "definition_sha256": receipt["definition_sha256"],
                "harness_sha256": receipt["harness_sha256"], "runner_sha256": runner_sha256}
    if candidate != expected or receipt["runner_sha256"] != runner_sha256:
        raise ValueError("Registration does not match the exact built source/harness/runner")
    if value["limits"] != REGISTERED_LIMITS or any(type(v) is not int for v in value["limits"].values()):
        raise ValueError("Registration changed the initial equal-budget comparison envelope")
    selected_cases = value["cases"]
    if not isinstance(selected_cases, list) or not 1 <= len(selected_cases) <= 1024:
        raise ValueError("Registration needs 1..1024 explicit cases")
    identities = set()
    for case in selected_cases:
        if not isinstance(case, dict) or set(case) != {"fixture", "profile", "seed"}:
            raise ValueError("Registered cases require exact fixture/profile/seed fields")
        if not isinstance(case["fixture"], str) or not isinstance(case["profile"], str) or case["fixture"] not in REGISTERED_FIXTURES or case["profile"] not in REGISTERED_PROFILES:
            raise ValueError("Unknown registered fixture or profile")
        seed = case["seed"]
        if type(seed) is not int or not 0 <= seed <= (1 << 64) - 1 or seed in FRESH_EXCLUDED_SEEDS:
            raise ValueError("Fresh holdout seed is invalid or already revealed development evidence")
        identity = (case["fixture"], case["profile"], seed)
        if identity in identities: raise ValueError("Duplicate registered case")
        identities.add(identity)
    declared_policies = value["policies"]
    if not isinstance(declared_policies, list) or not 2 <= len(declared_policies) <= 64:
        raise ValueError("Registration needs 2..64 explicit policies")
    selected_policies, primary = [], set()
    suffixes = {"fixed", "hard_only", "frame_frozen", "mosaic_frozen", "no_offers", "reverse", "cancel",
                "frame_budget", "mosaic_budget", "solver_budget", "memory_budget"}
    treatments = {"off", "terminal_only", "receptor_only", "both", "recovery", "recovery_without_005"}
    for policy in declared_policies:
        if not isinstance(policy, dict) or set(policy) != {"name", "rounds", "role"}:
            raise ValueError("Registered policies require exact name/rounds/role fields")
        if not isinstance(policy["name"], str) or type(policy["rounds"]) is not int or not 0 <= policy["rounds"] <= 4 or policy["role"] not in ("primary", "secondary"):
            raise ValueError("Invalid registered policy")
        parts = policy["name"].split("+")
        if parts[0] not in treatments or any(s not in suffixes for s in parts[1:]) or len(set(parts[1:])) != len(parts[1:]):
            raise ValueError("Unknown or repeated registered policy modifier")
        if "no_offers" in parts[1:] and parts[0] not in ("recovery", "recovery_without_005"):
            raise ValueError("Registered no-offer modifier requires recovery")
        pair = (policy["name"], policy["rounds"])
        if pair in selected_policies: raise ValueError("Duplicate registered policy execution")
        selected_policies.append(pair)
        if policy["role"] == "primary": primary.add(pair)
    if primary != {("both", 2), ("recovery", 2)}:
        raise ValueError("Primary comparison must be SWARM-005 both versus SWARM-006 recovery at two rounds")
    if type(value["case_count"]) is not int or value["case_count"] != len(selected_cases) or type(value["execution_count"]) is not int or value["execution_count"] != len(selected_cases) * len(selected_policies):
        raise ValueError("Registered denominator does not match every declared case and policy")
    if type(value["controls"]) is not bool or type(value["timeout_seconds"]) is not int or not 1 <= value["timeout_seconds"] <= 3600:
        raise ValueError("Invalid registered controls or child timeout")
    return selected_cases, selected_policies


def verify_native_input(request: dict, value: dict) -> str:
    """Match the full request, or the native bounded preflight-refusal header.

    A refusal may omit only the vectors that assemble() deliberately avoids
    copying before input admission. It never supplies material or authorization.
    All scalar identity, profile, option and limit fields remain exact.
    """
    flag = value.get("metrics", {}).get("input_header_only")
    if flag is not None and (type(flag) is not int or flag not in (0, 1)):
        raise ValueError("Invalid native input-header receipt")
    if flag != 1:
        if canonical(request) != canonical(value["input"]): raise ValueError("Native input changed during execution")
        return "full_exact"
    if value.get("status") not in ("exhausted", "invalid") or value.get("can_apply") is not False:
        raise ValueError("Header-only input is not a nonauthorizing preflight refusal")
    if value.get("source") != request["frame"]["source"] or value.get("digest") != "0000000000000000":
        raise ValueError("Header refusal changed source or supplied a composition digest")
    if canonical(value.get("metrics")) != canonical({"frame_work": 0, "input_header_only": 1, "total_charged_work": 0}):
        raise ValueError("Header refusal supplied work or extra outcome receipts")
    for key in ("rounds", "cells", "ledger", "rules", "obligations", "joints", "rejections"):
        if value.get(key) != []: raise ValueError("Header refusal supplied native output or history")
    if value.get("damage_derivative") is not None:
        raise ValueError("Header refusal supplied damage output")
    empty_result = {"gentek": "FRAMEWEAVER", "implementation": "", "definition": "", "source": "",
        "seed": 0, "status": "complete", "termination": "complete", "request_digest": "0000000000000000",
        "material_digest": "0000000000000000", "digest": "0000000000000000", "width": 0, "height": 0,
        "work": 0, "candidates": 0, "solver_work": 0, "backtracks": -1, "protected_violations": 0,
        "illegal_overlaps": 0, "unresolved_joints": 0, "metrics": {}, "rejected": {}, "notes": [],
        "cells": [], "roles": [], "provenance": [], "instances": [], "connectors": [], "attachments": [],
        "boundary": {key: [] for key in ("hard", "soft", "protected", "transition")}}
    empty_frame = {"core": empty_result, "result": empty_result, "slots": [], "reservation_rejections": []}
    if "source_feasibility" in value.get("original_frame", {}): empty_frame["source_feasibility"] = []
    if canonical(value.get("original_frame")) != canonical(empty_frame):
        raise ValueError("Header refusal supplied a native plan or changed its empty-state receipt")
    expected = copy.deepcopy(request)
    expected["shared_zone"] = []
    for owner in ("frame", "mosaic"):
        for key in ("activation", "eligible", "protected", "transition", "context", "neighbor_cells"):
            expected[owner][key] = []
        expected[owner]["neighbors"] = {key: [] for key in ("hard", "soft", "protected", "transition")}
    if canonical(expected) != canonical(value["input"]):
        raise ValueError("Native refusal header changed identity/limits or omitted unexpected data")
    return "bounded_header_refusal"


def cell_sha(cells: list) -> str:
    if any(type(cell) is not int or not 0 <= cell <= 65535 for cell in cells):
        raise ValueError("Invalid material plane")
    return hashlib.sha256(struct.pack("<" + "H" * len(cells), *cells)).hexdigest()


def reduce_result(value: dict) -> dict:
    status = value["status"]
    metrics = value.get("metrics", {})
    closure = status in ("complete", "blocked") and "still_required" in metrics
    obligations = value.get("obligations", [])
    still = sum(o["state"] == "STILL_REQUIRED" for o in obligations) if closure else None
    if closure and still != metrics["still_required"]: raise ValueError("Native ledger disagrees with unresolved metric")
    apply = value["can_apply"]
    if type(apply) is not bool: raise ValueError("Native Apply receipt is not boolean")
    if apply and not (status == "complete" and closure and still == 0):
        raise ValueError("Apply authorized without complete authoritative closure")
    counts = Counter(o.get("origin", "original_frame") + "/" + o["state"] for o in obligations)
    row = {"status": status, "can_apply": apply, "closure_evaluated": closure,
        "still_required": still, "qualified_joints": len(value.get("joints", [])),
        "foreign_joined": sum(o["state"] == "FOREIGN_JOINED" for o in obligations) if closure else None,
        "obligation_counts": dict(counts), "native_material_cells": sum(cell != 0 for cell in value.get("cells", [])),
        "material_plane_sha256": cell_sha(value.get("cells", [])), "stop_reason": value.get("stop_reason"),
        "reason": value.get("reason"), "metrics": metrics, "round_count": len(value.get("rounds", []))}
    frames = value.get("rounds", [])
    if frames:
        row["initial_frame_sha256"] = cell_sha(frames[0]["frame"]["result"]["cells"])
        row["initial_mosaic_sha256"] = cell_sha(frames[0]["mosaic"]["result"]["cells"])
        row["final_frame_sha256"] = cell_sha(frames[-1]["frame"]["result"]["cells"])
        row["final_mosaic_sha256"] = cell_sha(frames[-1]["mosaic"]["result"]["cells"])
    row["original_frame_sha256"] = cell_sha(value.get("original_frame", {}).get("result", {}).get("cells", []))
    attempts = [attempt for round_value in frames for attempt in round_value.get("recovery_attempts", [])]
    row["recovery_attempt_outcomes"] = dict(Counter(attempt["outcome"] for attempt in attempts))
    row["recovery_rejection_reasons"] = dict(Counter(attempt["reason"] for attempt in attempts if attempt["outcome"] == "rejected"))
    row["peak_active_recovery_reservations"] = max((len(round_value.get("mosaic_recovery_receipts", [])) for round_value in frames), default=0)
    row["remaining_obligation_reasons"] = dict(Counter(o.get("reason", "unreported") for o in obligations if o["state"] == "STILL_REQUIRED")) if closure else None
    return row


def compress_json(path: Path) -> dict:
    original_sha, size = sha(path), path.stat().st_size
    packed = path.with_name(path.name + ".gz")
    with path.open("rb") as source, packed.open("xb") as destination:
        with gzip.GzipFile(filename="", mode="wb", fileobj=destination, compresslevel=6, mtime=0) as compressed:
            for block in iter(lambda: source.read(1024 * 1024), b""): compressed.write(block)
    restored = hashlib.sha256()
    with gzip.open(packed, "rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""): restored.update(block)
    if restored.hexdigest() != original_sha: raise ValueError("Evidence compression changed bytes")
    record = {"raw_sha256": original_sha, "raw_bytes": size, "file": packed.name,
              "compressed_sha256": sha(packed), "compressed_bytes": packed.stat().st_size}
    path.unlink()
    return record


def normalized_composition(document: dict, source: str, compiled_definition: str) -> dict:
    """Only declared identity fields and absent OFF schema extensions differ.

    Material digests, complete geometry/provenance, obligations, semantic states,
    work, failures and prose remain exact. There is no recursive key stripping.
    """
    if document.get("schema") != 5 or document.get("type") != "reciprocal_assembly":
        raise ValueError("Compatibility comparison requires the historical schema 5 composition")
    result = copy.deepcopy(document)
    if result["source"] != source: raise ValueError("Unexpected composition source identity")
    result["source"] = "<declared-source>"

    def item(value: dict, is_result=False) -> None:
        if value.get("source") == "" and value.get("definition") == "" and value.get("width") == 0 and value.get("height") == 0:
            return  # preserve every field of the untouched native empty result
        if value["source"] != source: raise ValueError("Unexpected nested native source identity")
        prefix, separator, suffix = value["definition"].rpartition(".")
        if not separator or suffix != compiled_definition: raise ValueError("Unexpected native compiled definition")
        value["source"] = "<declared-source>"
        value["definition"] = prefix + ".<compiled-input-sha256>"
        if is_result:
            value["request_digest"] = "<source-bound-request-digest>"
            value["digest"] = "<source-bound-result-digest>"

    for name in ("frame", "mosaic"): item(result["input"][name])
    # SWARM-004 omits these later SWARM-005 fields. Only their exact disabled
    # representations are supplied; nonzero work or nonempty receipts survive.
    result["input"]["options"].setdefault("compact_native_termination", False)
    result["input"]["options"].setdefault("supported_native_receptors", False)
    for name in ("core", "result"): item(result["original_frame"][name], True)
    for round_value in result["rounds"]:
        item(round_value["mosaic_request"])
        for name in ("proposed_frame", "proposed_mosaic"): item(round_value[name], True)
        for name in ("frame", "mosaic"): item(round_value[name]["result"], True)
        round_value.setdefault("mosaic_supported_receptor_work", 0)
        round_value.setdefault("mosaic_supported_receptors", [])
    if result.get("damage_derivative"):
        for name in ("frame", "mosaic"): item(result["damage_derivative"][name]["result"], True)
    return result


def retained_document(directory: Path, row: dict) -> dict:
    storage = row["storage"]["response-native.json"]
    path = directory / row["id"] / storage["file"]
    if sha(path) != storage["compressed_sha256"]: raise ValueError("Retained compressed evidence changed")
    raw = gzip.decompress(path.read_bytes())
    if hashlib.sha256(raw).hexdigest() != storage["raw_sha256"]: raise ValueError("Retained native response changed")
    return json.loads(raw)


def verify_recovery_controls(candidate: dict, directory: Path, metadata: dict) -> None:
    """Cross-check claimed matched causality from complete native JSON planes."""
    if not candidate.get("input", {}).get("options", {}).get("negotiated_recovery") or not metadata.get("available"):
        return
    controls = []
    for filename, changed_option in (("no-offer-native.json", "recovery_offers"), ("frozen-peer-native.json", "mosaic_adaptation")):
        control = json.loads((directory / filename).read_text())
        expected_input = copy.deepcopy(candidate["input"])
        expected_input["options"][changed_option] = False
        if control["input"] != expected_input: raise ValueError("Matched recovery control changed unrelated native input")
        if control["status"] not in ("complete", "blocked") or not control["rounds"]:
            raise ValueError("Unavailable recovery control claimed observed causality")
        for key in ("frame", "mosaic", "mosaic_request"):
            if candidate["rounds"][0][key] != control["rounds"][0][key]:
                raise ValueError("Matched recovery control changed an initial native plan or donor grant")
        controls.append(control)
    no_offer, frozen = controls
    initial_mosaic = candidate["rounds"][0]["mosaic"]
    if any(round_value["mosaic"] != initial_mosaic for round_value in frozen["rounds"]):
        raise ValueError("Frozen peer changed native geometry, provenance or categorical assignment")
    def footprint(left, right):
        if len(left) != len(right): raise ValueError("Matched control plane length changed")
        return sum((a == 0) != (b == 0) for a, b in zip(left, right))
    final = candidate["rounds"][-1]
    mosaic_effect = footprint(final["mosaic"]["result"]["cells"], no_offer["rounds"][-1]["mosaic"]["result"]["cells"])
    frame_effect = footprint(final["frame"]["result"]["cells"], frozen["rounds"][-1]["frame"]["result"]["cells"])
    expected = {"mosaic_offer_causal_footprint": mosaic_effect, "frame_offer_causal_footprint": frame_effect,
        "causal_both_with_joint": mosaic_effect > 0 and frame_effect > 0 and bool(candidate["joints"]),
        "causal_complete": mosaic_effect > 0 and frame_effect > 0 and bool(candidate["joints"]) and candidate["can_apply"]}
    if any(metadata[key] != value for key, value in expected.items()):
        raise ValueError("Causality receipt disagrees with complete native counterfactual results")
    metadata["full_native_control_validation"] = "PASS"


def compare(args) -> int:
    if args.out.exists(): raise ValueError("Refusing existing comparison receipt")
    before = json.loads((args.before / "manifest.json").read_text())
    after = json.loads((args.after / "manifest.json").read_text())
    selected = [policies("swarm006", "development", [choice])[0]
                for choice in (args.before_policy, args.after_policy)]
    report = {"schema": 1, "scope": "full native behavior compatibility; no owner qualification",
        "before_manifest_sha256": sha(args.before / "manifest.json"), "after_manifest_sha256": sha(args.after / "manifest.json"),
        "before_policy": args.before_policy, "after_policy": args.after_policy,
        "normalization": "None; exact canonical native JSON" if args.exact else "Enumerated source identity, request/result digests and exact compiled-definition suffix; absent SWARM-005 OFF options/zero receptor work/empty receipts only. All other fields remain exact.",
        "started_utc": now(), "cases": [], "errors": []}
    def keyed(manifest: dict, choice: tuple) -> dict:
        rows = [r for r in manifest["records"] if (r["policy"], r["rounds"]) == tuple(choice)]
        result = {(r["fixture"], r["profile"], r["seed"]): r for r in rows}
        if len(result) != len(rows) or not rows: raise ValueError("Missing or duplicate comparison cases")
        return result
    old, new = keyed(before, selected[0]), keyed(after, selected[1])
    if old.keys() != new.keys(): report["errors"].append("Comparison case sets differ")
    if before["result"] != "PASS" or after["result"] != "PASS": report["errors"].append("An evidence campaign did not pass integrity checks")
    for identity in sorted(old.keys() & new.keys()):
        row = {"case": identity}
        try:
            values = []
            for directory, manifest, record in ((args.before, before, old[identity]), (args.after, after, new[identity])):
                value = retained_document(directory, record)
                normalized = value if args.exact else normalized_composition(value, manifest["source"], manifest["build_receipt"]["definition_sha256"])
                values.append(hashlib.sha256(canonical(normalized)).hexdigest())
            row.update({"before_behavior_sha256": values[0], "after_behavior_sha256": values[1], "equal": values[0] == values[1]})
        except (ValueError, KeyError, TypeError, OSError) as error:
            row.update({"equal": False, "error": str(error)})
        if not row["equal"]: report["errors"].append({"case": identity, "error": row.get("error", "Native behavioral fields differ")})
        report["cases"].append(row)
    report.update({"compared": len(report["cases"]), "exact_matches": sum(r["equal"] for r in report["cases"]),
                   "ended_utc": now(), "result": "FAIL" if report["errors"] else "PASS"})
    atomic_json(args.out, report)
    print(json.dumps({k: report[k] for k in ("result", "compared", "exact_matches", "errors")}))
    return 0 if report["result"] == "PASS" else 1


def distribution(rows: list[dict]) -> dict:
    def numeric(values: list) -> dict:
        return {"count": len(values), "min": min(values), "median": statistics.median(values),
                "max": max(values), "sum": sum(values)} if values else {"count": 0}
    rejection_reasons, attempt_outcomes = Counter(), Counter()
    for row in rows:
        rejection_reasons.update(row.get("recovery_rejection_reasons", {}))
        attempt_outcomes.update(row.get("recovery_attempt_outcomes", {}))
    phases = ("frame_work", "mosaic_work", "solver_work", "shared_work", "recovery_work", "recovery_validation_work", "total_charged_work")
    return {"statuses": dict(Counter(r["status"] for r in rows)),
        "apply_valid": sum(r["can_apply"] for r in rows), "joints": sum(r.get("qualified_joints", 0) for r in rows),
        "closure_unknown": sum(not r.get("closure_evaluated", False) for r in rows),
        "stops": dict(Counter(r.get("stop_reason") or "unavailable" for r in rows)),
        "failures": dict(Counter(r.get("reason", "unreported") for r in rows if not r["can_apply"])),
        "remaining_requirements": dict(Counter(str(r.get("still_required")) for r in rows)),
        "charged_work": sum(r.get("metrics", {}).get("total_charged_work", 0) for r in rows),
        "work": {phase: numeric([r["metrics"][phase] for r in rows if phase in r.get("metrics", {})]) for phase in phases},
        "memory_bound_bytes": numeric([r["metrics"]["conservative_memory_bound_bytes"] for r in rows if "conservative_memory_bound_bytes" in r.get("metrics", {})]),
        "recovery_attempt_outcomes": dict(attempt_outcomes), "recovery_rejection_reasons": dict(rejection_reasons),
        "causal_complete": sum(r.get("controls", {}).get("causal_complete", False) for r in rows)}


def run(args) -> int:
    build_path = args.build.resolve()
    build_receipt = json.loads((build_path / "build.json").read_text())
    if build_receipt["result"] != "PASS": raise ValueError("Native driver build did not pass")
    binary = Path(build_receipt["binary"])
    if sha(binary) != build_receipt["binary_sha256"]: raise ValueError("Native driver binary changed")
    variant = build_receipt["variant"]
    output = args.out.resolve()
    root = Path(build_receipt["source_root"])
    if output.is_relative_to(root) or output.is_relative_to(build_path):
        raise ValueError("Evidence directory must be separate from source and build")
    registration = None
    registration_raw = None
    if args.registration:
        if args.policy or args.suite is not None or args.controls or args.timeout is not None:
            raise ValueError("A registration cannot be overridden by suite, policy, controls or timeout arguments")
        registration_raw = args.registration.read_bytes()
        registration = json.loads(registration_raw)
        selected_cases, selected_policies = validate_registration(registration, build_receipt, sha(Path(__file__)))
        if git(root, "rev-parse", "HEAD") != build_receipt["source_commit"] or git(root, "status", "--porcelain") or source_inputs(root) != build_receipt["source_inputs"]:
            raise ValueError("Preregistered source is no longer the exact clean frozen checkout")
        suite, with_controls, child_timeout = "registered_unseen", registration["controls"], registration["timeout_seconds"]
    else:
        suite, with_controls, child_timeout = args.suite or "development", args.controls, args.timeout or 90
        selected_cases = cases(suite)
        selected_policies = policies(variant, suite, args.policy)
    fresh_directory(output)
    source = build_receipt["source_commit"]
    if build_receipt["source_dirty"]: source += "+dev-" + build_receipt["definition_sha256"][:12]
    manifest = {"schema": 1, "programme": "GENTEK-SWARM-006", "scope": "native synthetic development; not original owner World or NVIDIA acceptance",
        "suite": suite, "revealed005_is_unseen": False, "variant": variant, "source": source,
        "build_receipt": build_receipt, "build_receipt_sha256": sha(build_path / "build.json"),
        "runner_sha256": sha(Path(__file__)), "cases": selected_cases, "policies": selected_policies,
        "expected_executions": len(selected_cases) * len(selected_policies), "started_utc": now(),
        "result": "RUNNING", "records": []}
    if registration is not None:
        (output / "registration.json").write_bytes(registration_raw)
        manifest.update({"scope": "preregistered native synthetic holdout; not original owner World or NVIDIA acceptance",
            "classification": "preregistered_unseen", "registration": registration,
            "registration_sha256": hashlib.sha256(registration_raw).hexdigest()})
    atomic_json(output / "manifest.json", manifest)
    for case, (policy, rounds) in itertools.product(selected_cases, selected_policies):
        effective_policy = policy
        if case["fixture"] == "fixed4099" and "+fixed" not in policy: effective_policy += "+fixed"
        identity = f'{case["fixture"]}--{case["profile"]}--s{case["seed"]}--{policy}--r{rounds}'
        destination = output / identity
        command = [str(binary), "run", str(destination), source, case["fixture"], case["profile"],
                   str(case["seed"]), effective_policy, str(rounds)]
        if with_controls and rounds >= 1: command.append("controls")
        execution = execute(command, output / (identity + ".log"), child_timeout)
        row = {**case, "id": identity, "policy": policy, "effective_policy": effective_policy,
               "rounds": rounds, "execution": execution, "status": "execution_failed", "can_apply": False}
        try:
            raw = destination / "response-native.json"
            if raw.exists():
                envelope = json.loads((destination / "request-envelope.json").read_text())
                atomic_json(destination / "request.json", envelope["input"])
                row["request_sha256"] = hashlib.sha256(canonical(envelope["input"])).hexdigest()
                value = json.loads(raw.read_text())
                row.update(reduce_result(value))
                row["input_representation"] = verify_native_input(envelope["input"], value)
                # Nonzero exits never become success because a child left plausible JSON.
                if execution["returncode"] != 0 and row["can_apply"]:
                    raise ValueError("Failed child left an authorizing result")
                if (destination / "controls.json").exists():
                    row["controls"] = json.loads((destination / "controls.json").read_text())
                    verify_recovery_controls(value, destination, row["controls"])
        except (ValueError, KeyError, TypeError, OSError) as error:
            row["evidence_error"] = str(error)
            row["can_apply"] = False
        # A malformed or rejected response still keeps the original request and
        # every response byte with hashes. Failed validation never erases data.
        row["storage"] = {}
        try:
            if destination.exists():
                for path in sorted(destination.glob("*.json")):
                    row["storage"][path.name] = compress_json(path)
                atomic_json(destination / "storage.json", row["storage"])
        except (ValueError, KeyError, TypeError, OSError) as error:
            row["evidence_error"] = str(error)
            row["can_apply"] = False
        manifest["records"].append(row)
        atomic_json(output / "manifest.json", manifest)
        print(json.dumps({k: row.get(k) for k in ("id", "status", "can_apply", "qualified_joints", "still_required", "evidence_error")}), flush=True)
        if execution["cancelled"]: break
    manifest["source_custody_revalidated"] = source_inputs(root) == build_receipt["source_inputs"]
    if registration is not None:
        manifest["source_custody_revalidated"] = manifest["source_custody_revalidated"] and git(root, "rev-parse", "HEAD") == build_receipt["source_commit"] and git(root, "status", "--porcelain") == ""
        try:
            manifest["registration_custody_revalidated"] = args.registration.read_bytes() == registration_raw
        except OSError:
            manifest["registration_custody_revalidated"] = False
    manifest["binary_custody_revalidated"] = sha(binary) == build_receipt["binary_sha256"]
    manifest["retained_executions"] = len(manifest["records"])
    manifest["distributions"] = {}
    for policy, rounds in selected_policies:
        rows = [r for r in manifest["records"] if r["policy"] == policy and r["rounds"] == rounds]
        manifest["distributions"][f"{policy}@{rounds}"] = distribution(rows)
    good = manifest["retained_executions"] == manifest["expected_executions"] and manifest["source_custody_revalidated"] and manifest["binary_custody_revalidated"]
    good = good and manifest.get("registration_custody_revalidated", True)
    good = good and all(r["execution"]["returncode"] == 0 and not r.get("evidence_error") for r in manifest["records"])
    manifest["result"] = "PASS" if good else "FAIL"
    manifest["ended_utc"] = now()
    atomic_json(output / "manifest.json", manifest)
    print(json.dumps({"result": manifest["result"], "retained_executions": manifest["retained_executions"], "distributions": manifest["distributions"]}))
    return 0 if good else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    compile_parser = commands.add_parser("build")
    compile_parser.add_argument("--source-root", type=Path, required=True)
    compile_parser.add_argument("--build", type=Path, required=True)
    compile_parser.add_argument("--variant", choices=("swarm004", "swarm005", "swarm006"), required=True)
    compile_parser.add_argument("--cxx", default="g++")
    compile_parser.add_argument("--timeout", type=int, default=900)
    compile_parser.add_argument("--allow-dirty", action="store_true")
    compile_parser.add_argument("--sanitize", action="store_true")
    runner = commands.add_parser("run")
    runner.add_argument("--build", type=Path, required=True)
    runner.add_argument("--out", type=Path, required=True)
    runner.add_argument("--suite", choices=("owner", "development", "revealed005", "stress"))
    runner.add_argument("--policy", action="append", help="Exact named treatment@rounds; repeat for more policies")
    runner.add_argument("--controls", action="store_true")
    runner.add_argument("--timeout", type=int, help="Child timeout; default 90 seconds outside preregistration")
    runner.add_argument("--registration", type=Path, help="Immutable preregistered source/cases/policies JSON; overrides are forbidden")
    comparison = commands.add_parser("compare")
    comparison.add_argument("--before", type=Path, required=True)
    comparison.add_argument("--after", type=Path, required=True)
    comparison.add_argument("--before-policy", default="off@2")
    comparison.add_argument("--after-policy", default="off@2")
    comparison.add_argument("--out", type=Path, required=True)
    comparison.add_argument("--exact", action="store_true", help="Require exact native JSON, including source identities; use for replay/reversal")
    args = parser.parse_args()
    if args.command != "compare" and args.timeout is not None and (args.timeout < 1 or args.timeout > 3600): parser.error("Timeout must be 1..3600 seconds")
    try:
        return build(args) if args.command == "build" else compare(args) if args.command == "compare" else run(args)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f"SWARM006_RUNNER: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
