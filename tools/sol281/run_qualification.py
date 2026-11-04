#!/usr/bin/env python3
"""Exact-source, read-only SOL-DETACH-001 host qualification (no publication)."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
import math
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

COHORTS = ("core", "contact-w1", "contact-w4", "mechanism")
SCOPES = ("native", "godot", "tools", "third_party", "Makefile", "AGENTS.md", ".gitattributes",
          ".github/workflows/sol281-current-main.yml", ".github/workflows/rapier-bvh-build.yml")
RESULT_FILES = frozenset({"test_solid_detachment", "test_solid_detachment_coupling",
                          "test_solid_detachment_populated", "test_solid_detachment_displacement",
                          "test_solid_contact_response", "test_solid_contact_observation",
                          "test_solid_detachment_contact_recovery", "test_solid_contact_synchronized"})
SYNCHRONIZED_FIXTURE = "godot/tests/fixtures/sol364/synchronized_contacts.json"
SYNCHRONIZED_INPUTS = (
    SYNCHRONIZED_FIXTURE,
    "godot/tests/test_solid_contact_synchronized.gd",
    "godot/tests/support/solid_contact_synchronized_fixture.gd",
    "godot/tests/support/solid_contact_response_749fb8b.gd",
    "godot/scripts/solid_contact_response.gd",
    "godot/scripts/rapier_physics_bridge.gd",
)
FROZEN_CONTACT_PLANNER_SHA256 = "d5bebb75d81cf5bc0dce756f7a844f19ad9f145fbd9ca96775ad8f999a061d6d"
SYNCHRONIZED_FIXTURES = (
    "embedded_stationary", "packed_impact", "offcenter_impact", "rotated_compound",
    "missed_publication", "delayed_publication", "stale_publication",
)
SYNCHRONIZED_ARMS = ("conservative_baseline", "velocity_control", "candidate")
SYNCHRONIZED_STEPS = 180


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
    if cohort == "mechanism":
        return [
            Spec("sand-contact-response", "test_solid_contact_response", "SOL281_CONTACT_RESPONSE", 101),
            Spec("sand-contact-fences", "test_solid_contact_fences", "SOL281_CONTACT_FENCES", 135),
            *(Spec(f"synchronized-contact-w{w}", "test_solid_contact_synchronized", "SOL364_SYNCHRONIZED_CONTACT",
                   8338, (f"--workers={w}",), w) for w in (1, 4)),
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
        Spec(f"contact-observation-w{workers}", "test_solid_contact_observation", "SOL281_CONTACT_OBSERVATION", 142,
             (f"--workers={workers}",), workers),
        Spec(f"contact-recovery-w{workers}", "test_solid_detachment_contact_recovery", "SOL281_CONTACT_RECOVERY", 290,
             (f"--workers={workers}",), workers),
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
    if spec.script == "test_solid_contact_synchronized":
        require(result.get("schema") == "cybersand.sol364.synchronized-contact.v1"
                and result.get("complete_replay") is True
                and type(result.get("case_count")) is int
                and result["case_count"] == len(SYNCHRONIZED_FIXTURES) * len(SYNCHRONIZED_ARMS)
                and type(result.get("steps")) is int and result["steps"] == SYNCHRONIZED_STEPS
                and type(result.get("checks")) is int and result["checks"] > 0
                and type(result.get("workers")) is int,
                "Incomplete synchronized contact execution footer")
    if spec.name == "lifecycle":
        require(result.get("actual_host_replacement_cycles") == 20, "Incomplete actual-owner lifecycle inventory")
    if spec.script == "test_solid_detachment_populated":
        require(result.get("conservative_displacement") == ("--baseline" not in spec.flags), "Wrong contact policy")
        require(result.get("surroundings") == next(x.split("=", 1)[1] for x in spec.flags if x.startswith("--surroundings=")),
                "Wrong populated fixture")
    if spec.script == "test_solid_contact_response":
        mechanical = result.get("mechanical", {})
        require(mechanical.get("steps") == 12 and mechanical.get("mass") == 520,
                "Wrong registered mechanical input")
        for gate in (mechanical, mechanical.get("off_center", {})):
            require(gate.get("gate_passed") is True and gate.get("proposed_gate_minimum_reduction") == 0.25,
                    "Mechanical gate absent, failed or redefined")
            before = gate.get("baseline_added_overlap_area_steps")
            after = gate.get("candidate_added_overlap_area_steps")
            require(type(before) in (int, float) and type(after) in (int, float)
                    and before > 0 and after >= 0 and after <= before * 0.75,
                    "Registered overlap reduction did not pass")
        require(len(mechanical.get("trajectory", [])) == 12, "Incomplete mechanical trajectory")
        transported = result.get("cases", {}).get("transported_original_segment", {})
        require(transported == {
            "current_area": 0.015625, "current_depth": 0.0625, "vertex_drift": 0.1875,
            "source_length": 0.25, "remaining_length": 0.0625, "outcome": "Accepted",
            "mixed_clearance_outcome": "Accepted", "position_work": 0,
        }, "Missing or changed transported original contact-segment counterexample")
    if spec.script == "test_solid_contact_observation":
        require([x.get("id") for x in result.get("cases", [])] ==
                ["partial_shared_edge", "float32_seam", "immutable_publication", "refusals"],
                "Incomplete native contact replay")
        immutable = result["cases"][2]
        require(all(type(immutable.get(key)) is int and immutable[key] == expected
                    for key, expected in (("attempts", 3), ("complete_attempts", 2), ("refused_attempts", 1)))
                and immutable.get("stages_accounted") is True,
                "Incomplete immutable publication or all-attempt stage accounting")
    if spec.script == "test_solid_contact_fences":
        require(result.get("readback_failure_cases") == [
            "velocity_x_nan", "velocity_y_inf", "velocity_negative_inf",
            "omega_nan", "omega_inf", "omega_negative_inf",
            "energy_nan", "energy_inf", "energy_negative_inf",
            "momentum_nan", "angular_momentum_inf", "finite_energy_increase",
        ], "Incomplete, duplicated or reordered post-application readback failures")
    if spec.script == "test_solid_detachment_contact_recovery":
        if "cases" in result:
            # Retained historical full footers remain readable. Current runs
            # publish a concise footer and authenticate the complete JSON below.
            verify_contact_recovery_result(result)
        else:
            require(result.get("schema") == "cybersand.sol281.contact-recovery.v1"
                    and type(result.get("case_count")) is int and result["case_count"] == 18,
                    "Incomplete concise asynchronous contact footer")
    return result


def verify_contact_recovery_result(result):
    """Verify the complete canonical asynchronous trace, never just its footer."""
    expected = [(kind, arm, repeat) for kind in ("packed_sand", "embedded_sand", "mixed")
                for repeat in range(3) for arm in ((False, True) if repeat % 2 == 0 else (True, False))]
    cases = result.get("cases", [])
    require([(x.get("surroundings"), x.get("candidate"), x.get("repeat")) for x in cases] == expected,
            "Incomplete, duplicated or reordered repeated fixture inventory")
    for case in cases:
        require(type(case.get("candidate")) is bool and case.get("steps") == 360
                and case.get("sand_before", -1) > 0 and case.get("sand_before") == case.get("sand_after")
                and case.get("water_before", -1) >= 0 and case.get("water_before") == case.get("water_after"),
                "Incomplete steps or failed quantity conservation")
        physical = case.get("metrics", {}).get("physical_contact", {})
        require(physical.get("observations", 0) > 0 and physical.get("energy_violations") == 0
                and physical.get("response_failures", {}) == {} and bool(case.get("trace")),
                "Missing complete geometry or failed physical readback")
        require((physical.get("response_accepts", 0) > 0 and physical.get("impulse_magnitude_sum", 0) > 0)
                if case["candidate"] else physical.get("response_accepts", 0) == 0,
                "Candidate resistance was unexercised or baseline policy changed")
        require(physical.get("worker_observation_attempts", 0) >=
                physical["observations"] + physical.get("refused_observations", 0)
                and physical.get("response_attempts", -1) ==
                physical.get("response_accepts", 0) + sum(physical.get("response_refusals", {}).values())
                + sum(physical.get("response_failures", {}).values()),
                "Contact work attempt inventory is incomplete")
        for total, accepted in (("worker_contact_ms_total", "geometry_ms_total"),
                                ("response_ms_all_attempts", "response_ms_total")):
            require(type(physical.get(total)) in (int, float) and math.isfinite(physical[total])
                    and physical[total] >= physical.get(accepted, 0) >= 0,
                    "Contact cost omitted refused or overwritten work")
        response_stages = ["response_" + stage + "_ms_all_attempts" for stage in
                           ("rid_state", "planner", "impulse_apply", "readback", "other")]
        if any(key in physical for key in response_stages):
            require(all(type(physical.get(key)) in (int, float) and math.isfinite(physical[key])
                        and physical[key] >= -1e-6 for key in response_stages)
                    and abs(sum(physical[key] for key in response_stages) - physical["response_ms_all_attempts"]) <= 1e-6,
                    "Response stage accounting differs from inclusive all-attempt work")
        for point in case["trace"]:
            require(all(key in point for key in ("revision", "physics_epoch", "token", "body_generation",
                    "source_x", "source_y", "source_angle", "current_x", "current_y", "current_angle",
                    "source_published_usec", "observed_usec")) and len(point.get("proxies", [])) == 6,
                    "Trace lacks exact source geometry or separate current pose")


def verify_synchronized_result(result, spec):
    """Authenticate complete per-step evidence; physical failures remain outcomes.

    The native observer owns exact overlap calculations. This reader independently
    verifies the retained partition and transformed reporting geometry, the receipt
    queue, every declared step and the arithmetic of published metrics. It does not
    relabel a frozen-field experiment as an asynchronous clearance qualification.
    """
    def finite(value):
        if isinstance(value, dict):
            return all(finite(item) for item in value.values())
        if isinstance(value, list):
            return all(finite(item) for item in value)
        return type(value) is not float or math.isfinite(value)

    def number(value):
        return type(value) in (int, float) and math.isfinite(value)

    def vector(value, length):
        return isinstance(value, list) and len(value) == length and all(number(x) for x in value)

    def near(actual, expected, label, tolerance=1e-7):
        require(number(actual) and math.isclose(actual, expected, rel_tol=tolerance, abs_tol=tolerance),
                "Synchronized metric differs from original steps: " + label)

    def integer(actual, expected, label):
        require(type(actual) is int and actual == expected, "Synchronized inventory differs: " + label)

    def hash256(value):
        return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None

    require(isinstance(result, dict) and finite(result), "Nonfinite synchronized evidence")
    fixture = json.loads((ROOT / SYNCHRONIZED_FIXTURE).read_text(encoding="utf-8"))
    inputs = {path.removeprefix("godot/"): digest(ROOT / path) for path in SYNCHRONIZED_INPUTS}
    require(result.get("input_hashes") == inputs, "Synchronized evidence differs from exact checked source inputs")
    for key, path in (("script_sha256", SYNCHRONIZED_INPUTS[1]), ("fixture_sha256", SYNCHRONIZED_FIXTURE),
                      ("current_planner_sha256", SYNCHRONIZED_INPUTS[4]), ("frozen_planner_sha256", SYNCHRONIZED_INPUTS[3])):
        require(result.get(key) == inputs[path.removeprefix("godot/")], "Wrong synchronized source identity: " + key)
    require(result["frozen_planner_sha256"] == FROZEN_CONTACT_PLANNER_SHA256
            and result.get("frozen_planner_source") == "749fb8b597ad866f7535f26442e904207c4f7611",
            "Frozen velocity control changed")
    require(fixture.get("schema") == "cybersand.sol364.synchronized-fixtures.v1"
            and fixture.get("steps") == SYNCHRONIZED_STEPS and fixture.get("arms") == list(SYNCHRONIZED_ARMS)
            and fixture.get("can_sleep") is False and result.get("can_sleep") is False
            and [item.get("id") for item in fixture.get("fixtures", [])] == list(SYNCHRONIZED_FIXTURES)
            and result.get("backend") == "Rapier2D" and str(result.get("engine", "")).startswith("4.7")
            and hash256(result.get("source_sha256")), "Wrong synchronized fixture, runtime or retained source")
    near(result.get("fixed_delta"), 1 / 60, "declared physics delta", 1e-12)
    require(result.get("contact_columns") == ["proxy", "face", "cell_x", "cell_y", "point_x", "point_y",
            "normal_x", "normal_y", "a_x", "a_y", "b_x", "b_y", "depth", "area", "weight"]
            and result.get("proxy_metric_columns") == ["proxy", "area", "max_depth", "overlap_cells"]
            and result.get("pose_columns") == ["x_axis_x", "x_axis_y", "y_axis_x", "y_axis_y", "origin_x", "origin_y"],
            "Synchronized geometry columns changed or omitted")
    source = result.get("source", {})
    rectangles = [44, 27, 29, 5, 44, 32, 16, 1, 61, 32, 12, 1, 44, 33, 29, 7, 50, 40, 15, 4, 50, 44, 4, 21]
    require(source.get("rectangles") == rectangles and source.get("member_count") == 520
            and source.get("shape_count") == 6, "Retained compound geometry changed")
    cells = [(x, y) for i in range(0, len(rectangles), 4)
             for y in range(rectangles[i + 1], rectangles[i + 1] + rectangles[i + 3])
             for x in range(rectangles[i], rectangles[i] + rectangles[i + 2])]
    cells.sort(key=lambda point: (point[1], point[0]))
    require(len(cells) == len(set(cells)) == 520
            and source.get("members") == [value for x, y in cells for value in (x, y, 43, 0, 0, 200)]
            and fixture.get("hole_cells") == [[60, 32], [68, 50]]
            and all(tuple(hole) not in cells for hole in fixture["hole_cells"]),
            "Original material tuples, single coverage or empty holes changed")
    center = source.get("center")
    require(vector(center, 2), "Missing source center of mass")
    expected_center = [sum(point[axis] + 0.5 for point in cells) / 520 for axis in (0, 1)]
    for axis in (0, 1):
        near(center[axis], expected_center[axis], "source center", 1e-6)
    near(source.get("mass"), 520, "source mass")
    expected_inertia = sum((x + 0.5 - expected_center[0]) ** 2 + (y + 0.5 - expected_center[1]) ** 2 + 1 / 6
                           for x, y in cells)
    near(source.get("inertia"), expected_inertia, "source inertia")

    def corners(pose, x, y, width, height):
        return [[pose[0] * (px - center[0]) + pose[2] * (py - center[1]) + pose[4],
                 pose[1] * (px - center[0]) + pose[3] * (py - center[1]) + pose[5]]
                for px, py in ((x, y), (x + width, y), (x + width, y + height), (x, y + height))]

    def polygon(actual, expected):
        require(isinstance(actual, list) and len(actual) == 4 and all(vector(point, 2) for point in actual),
                "Incomplete transformed compound or hole witness")
        require(all(math.dist(a, b) <= 2e-4 for a, b in zip(actual, expected)),
                "Reported rotated geometry differs from retained source transform")

    geometry_fields = ("overlap_cells", "overlap_area", "sand_overlap_area", "max_penetration", "max_sand_penetration")
    def geometry(value, hashed=True):
        require(isinstance(value, dict) and vector(value.get("pose"), 6)
                and (not hashed or hash256(value.get("sha256"))), "Incomplete exact geometry record")
        pose = value["pose"]
        near(pose[0] ** 2 + pose[1] ** 2, 1, "rigid x axis", 1e-5)
        near(pose[2], -pose[1], "rigid y axis", 1e-5)
        near(pose[3], pose[0], "rigid y axis", 1e-5)
        require(len(value.get("proxies", [])) == 6 and len(value.get("hole_witnesses", [])) == 2,
                "Missing compound shape or hole")
        for i, proxy in enumerate(value["proxies"]):
            polygon(proxy, corners(pose, *rectangles[i * 4:i * 4 + 4]))
        for hole, witness in zip(fixture["hole_cells"], value["hole_witnesses"]):
            require(witness.get("source_cell") == hole and witness.get("proxy_area") == 0
                    and witness.get("method") == "exact_source_partition_under_common_rigid_transform",
                    "Hole witness changed or unsupported area claim")
            polygon(witness.get("corners"), corners(pose, *hole, 1, 1))
        require(all(number(value.get(key)) and value[key] >= 0 for key in geometry_fields)
                and type(value["overlap_cells"]) is int, "Invalid geometry measures")
        metrics = value.get("proxy_metrics", [])
        require(len(metrics) == 6 and all(vector(row, 4) and row[0] == i + 1 and type(row[3]) is int
                and all(x >= 0 for x in row[1:]) for i, row in enumerate(metrics)), "Missing per-proxy measures")
        near(value["overlap_area"], sum(row[1] for row in metrics), "compound area")
        # Aggregate cells are a unique union; a rotated cell may intersect two
        # disjoint sibling proxies. Per-proxy counts may therefore duplicate it.
        require(max(row[3] for row in metrics) <= value["overlap_cells"] <= sum(row[3] for row in metrics),
                "Compound unique overlap cells exceed per-proxy union bounds")
        near(value["max_penetration"], max(row[2] for row in metrics), "compound depth")
        contacts = value.get("contacts")
        require(isinstance(contacts, list) and len(contacts) <= 256
                and all(vector(row, 15) and type(row[0]) is int and 1 <= row[0] <= 6
                        and type(row[1]) is int and 0 <= row[1] <= 3
                        and type(row[2]) is int and type(row[3]) is int
                        and all(row[i] >= 0 for i in (12, 13, 14)) for row in contacts),
                "Missing or malformed exact contact witnesses")

    geometries = result.get("geometries", [])
    require(isinstance(geometries, list) and len(geometries) > 0, "Missing synchronized geometry table")
    for value in geometries:
        geometry(value)
    require(len({value["sha256"] for value in geometries}) == len(geometries), "Duplicate geometry digest")
    fields = result.get("native_fields", {})
    require(isinstance(fields, dict) and fields, "Missing frozen native material fields")
    for key, field in fields.items():
        require(re.fullmatch(r"[0-9a-f]{1,16}", key) is not None and field.get("world_state_hash") == key
                and field.get("origin") == [0, 0] and field.get("size") == [128, 128]
                and field.get("native_ticks") == 1 and field.get("water_mass") == 0,
                "Incomplete frozen native field identity")
        counts = field.get("counts", [])
        require(isinstance(counts, list) and len(counts) > 43
                and all(type(count) is int and count >= 0 for count in counts), "Invalid native material counts")
        computed = [0] * len(counts)
        for run in field.get("material_runs", []):
            require(isinstance(run, list) and len(run) == 2 and type(run[0]) is int and type(run[1]) is int
                    and 0 <= run[0] < len(counts) and run[1] > 0, "Malformed native material run")
            computed[run[0]] += run[1]
        require(computed == counts and sum(counts) == 128 * 128, "Incomplete frozen native field contents")

    def state(value):
        require(isinstance(value, dict) and vector(value.get("pose"), 6) and vector(value.get("velocity"), 2)
                and all(number(value.get(key)) for key in ("omega", "mass", "inertia", "kinetic"))
                and value.get("sleeping") is False and value.get("position_work") == 0 and value.get("potential") == 0
                and value.get("potential_scope") == "zero gravity causal control", "Incomplete actual Rapier state")
        near(value["mass"], 520, "actual mass")
        near(value["inertia"], source["inertia"], "actual inertia", 1e-4)
        near(value["kinetic"], 0.5 * value["mass"] * sum(v * v for v in value["velocity"])
             + 0.5 * value["inertia"] * value["omega"] ** 2, "actual kinetic energy", 1e-5)

    def measurement(value, step, actual):
        require(isinstance(value, dict) and type(value.get("geometry_id")) is int
                and 0 <= value["geometry_id"] < len(geometries), "Missing per-step geometry reference")
        geo = geometries[value["geometry_id"]]
        require(value.get("geometry_sha256") == geo["sha256"]
                and all(value.get(key) == geo[key] for key in geometry_fields)
                and value.get("contact_count") == len(geo["contacts"]), "Per-step geometry reference or metrics differ")
        require(max(abs(a - b) for a, b in zip(geo["pose"], actual["pose"])) <= 2e-4,
                "Per-step native source pose differs from actual Rapier pose")
        for key in ("sample_serial", "snapshot_serial"):
            integer(value.get(key), step + 1, "measurement " + key)
        require(value.get("native_tick") == 1 and value.get("physics_epoch") == 17
                and all(isinstance(value.get(key), str) and value[key] for key in ("revision", "generation", "token"))
                and type(value.get("published_usec")) is int and value["published_usec"] > 0
                and number(value.get("rapier_source_corner_drift")) and 0 <= value["rapier_source_corner_drift"] <= 2e-4,
                "Incomplete per-step native ownership or source/current witness")
        require(type(value.get("geometry_probes")) is int and 0 <= value["geometry_probes"] <= 8192
                and type(value.get("support_probes")) is int and 0 <= value["support_probes"] <= 9 * value["geometry_probes"]
                and value["support_probes"] % 9 == 0,
                "Unbounded or incomplete geometry/support observation probes")
        for key in ("owner_ms", "prepare_ms", "observation_ms", "envelope_freeze_ms", "native_geometry_ms", "native_payload_freeze_ms"):
            require(number(value.get(key)) and value[key] >= 0, "Missing per-stage owner work: " + key)
        near(value["owner_ms"], value["prepare_ms"] + value["observation_ms"] + value["envelope_freeze_ms"],
             "nonoverlapping owner stages")

    def plan(value):
        require(isinstance(value, dict) and type(value.get("accepted")) is bool
                and isinstance(value.get("outcome"), str) and value["outcome"]
                and isinstance(value.get("impulses", [] if value.get("accepted") is False else None), list),
                "Missing evaluated contact outcome")
        for action in value.get("impulses", []):
            require(isinstance(action, dict) and vector(action.get("impulse"), 2) and vector(action.get("offset"), 2),
                    "Malformed impulse or torque witness")
        require(value["accepted"] or value.get("impulses", []) == [], "Refused contact applied an impulse")
        stages = ("rid_state_ms", "planner_ms", "impulse_apply_ms", "readback_ms")
        if any(key in value for key in stages):
            require(all(number(value.get(key)) and value[key] >= 0 for key in stages),
                    "Incomplete synchronized response stage work")

    controls = result.get("controls", [])
    require([control.get("id") for control in controls] ==
            ["transported_midpoint", "stationary_velocity_limit", "interior_without_face"], "Incomplete causal controls")
    transport, stationary, interior = controls
    require(transport.get("source_accepts") is True and transport.get("source_span_length") == 0.25
            and transport.get("current_surviving_span_length") == 0.0625 and transport.get("current_area") == 0.015625
            and transport.get("current_depth") == 0.0625 and transport.get("vertex_drift") == 0.1875
            and transport.get("frozen_result", {}).get("outcome") == "ClearedContact"
            and transport["frozen_result"].get("accepted") is False
            and transport.get("candidate_result", {}).get("accepted") is True
            and bool(transport["candidate_result"].get("impulses")), "Missing executable geometric-witness counterexample")
    require(stationary.get("positive_area") == 0.0625 and stationary.get("position_work") == 0
            and stationary.get("result", {}).get("accepted") is True and stationary["result"].get("impulses") == [],
            "Missing stationary velocity-limit counterexample")
    geometry(interior.get("geometry"), hashed=False)
    require(interior["geometry"]["sand_overlap_area"] == 9 and interior["geometry"]["contacts"] == []
            and interior.get("native_field") in fields and interior.get("native_state_hash_before") == interior["native_field"]
            and isinstance(interior.get("native_state_hash_after"), str)
            and re.fullmatch(r"[0-9a-f]{1,16}", interior["native_state_hash_after"]) is not None
            and isinstance(interior.get("native_content_hash_before"), str)
            and re.fullmatch(r"[0-9a-f]{1,16}", interior["native_content_hash_before"]) is not None
            and interior.get("native_content_hash_after") == interior["native_content_hash_before"]
            and interior.get("native_material_cells_preserved") is True and interior.get("payload_preserved") is True
            and interior.get("aggregate_owned") == 520 and interior.get("native_source_members") == 0
            and interior.get("source_sha256") == result["source_sha256"] and interior.get("position_work") == 0
            and all(interior.get(arm, {}).get("accepted") is True and interior[arm].get("impulses") == []
                    for arm in ("velocity_control", "candidate")), "Missing initial-burial counterexample or native conservation")
    # The same frozen Sand must supply exterior witnesses in the independent
    # boundary pose: otherwise empty contacts could merely reflect unsupported Sand.
    geometry(interior.get("boundary_control"), hashed=False)
    require(bool(interior["boundary_control"]["contacts"]), "Initial-burial support control was not exercised")

    cases = result.get("cases", [])
    expected = [(fixture_id, arm) for fixture_id in SYNCHRONIZED_FIXTURES for arm in SYNCHRONIZED_ARMS]
    require([(case.get("fixture"), case.get("arm")) for case in cases] == expected,
            "Missing, duplicated or reordered synchronized cases")
    summaries, matched_initial = [], {}
    for case, (fixture_id, arm) in zip(cases, expected):
        label = fixture_id + "/" + arm
        declared = next(item for item in fixture["fixtures"] if item["id"] == fixture_id)
        require(case.get("id") == label and case.get("steps") == SYNCHRONIZED_STEPS and type(case.get("workers")) is int and case["workers"] == spec.workers
                and case.get("source_sha256") == result["source_sha256"] and case.get("native_field") in fields
                and case.get("native_state_hash_after") == case["native_field"]
                and case.get("native_ticks_before") == case.get("native_ticks_after") == 1
                and case.get("native_source_members") == 0 and case.get("aggregate_owned") == 520
                and case.get("payload_preserved") is True and case.get("ordinary_native_integration") is False
                and case.get("schedule") == declared["schedule"]
                and case.get("shape_partition") == {"valid": True, "holes_empty": True, "member_count": 520,
                                                     "covered_count": 520, "shape_count": 6},
                "Changed source, policy or ownership in synchronized case: " + label)
        initial = case.get("initial", {})
        require(initial.get("step") == 0, "Missing separate initial geometry observation")
        state(initial.get("state"))
        measurement(initial.get("measurement"), 0, initial["state"])
        expected_origin = declared.get("pose_origin", [center[axis] + declared["offset"][axis] for axis in (0, 1)])
        expected_pose = [math.cos(declared["angle"]), math.sin(declared["angle"]),
                         -math.sin(declared["angle"]), math.cos(declared["angle"]), *expected_origin]
        require(all(abs(a - b) <= 2e-4 for a, b in zip(initial["state"]["pose"], expected_pose))
                and initial["state"]["velocity"] == declared["velocity"] and initial["state"]["omega"] == declared["omega"],
                "Actual initial motion differs from registered fixture")
        starting = (initial["state"], initial["measurement"]["geometry_sha256"], case["native_field"])
        require(fixture_id not in matched_initial or matched_initial[fixture_id] == starting,
                "Comparison arms have different initial state, geometry or native field")
        matched_initial[fixture_id] = starting
        trace = case.get("trace", [])
        require(len(trace) == SYNCHRONIZED_STEPS and [row.get("step") for row in trace] == list(range(1, SYNCHRONIZED_STEPS + 1)),
                "Unobserved, duplicated or reordered simulation step")
        observations = [initial["measurement"]]
        delivered, refusals, accepts, first_impact = set(), {}, 0, -1
        impulse_sum = torque_sum = 0.0
        prior = initial["state"]
        for step, row in enumerate(trace, 1):
            for key in ("before", "after_response", "after"):
                state(row.get(key))
            require(row["before"] == prior and row["before"]["pose"] == row["after_response"]["pose"],
                    "Missing actual state transition or undeclared position correction")
            prior = row["after"]
            measurement(row.get("measurement"), step, row["after"])
            observations.append(row["measurement"])
            require(all(row["measurement"][key] == initial["measurement"][key]
                        for key in ("revision", "token", "generation", "physics_epoch", "native_tick")),
                    "Frozen synchronized ownership changed")
            plan(row.get("response"))
            response, receipt = row["response"], row.get("receipt", {})
            delay = {"delay_one": 1, "delay_two": 2}.get(case["schedule"], 0)
            missing = step <= delay or (case["schedule"] == "drop_every_fourth" and step % 4 == 0)
            require(receipt.get("delivered") is (not missing), "Publication schedule differs from registered fixture")
            if missing:
                require(receipt.get("outcome") == response["outcome"] == "MissingPublication"
                        and row.get("matched") == {} and not response["accepted"], "Missing publication created a response")
            else:
                serial = step - delay
                source_measurement = observations[serial - 1]
                require(serial not in delivered and receipt.get("source_step") == serial - 1
                        and receipt.get("sample_age") == delay, "Duplicate, out-of-order or mis-aged contact application")
                delivered.add(serial)
                for key, source_key in (("sample_serial", "sample_serial"), ("snapshot_serial", "snapshot_serial"),
                    ("tick", "native_tick"), ("revision", "revision"), ("token", "token"), ("generation", "generation"),
                    ("physics_epoch", "physics_epoch"), ("published_usec", "published_usec")):
                    require(receipt.get(key) == source_measurement[source_key], "Receipt lost source custody: " + key)
                require(type(receipt.get("received_usec")) is int and receipt["received_usec"] >= receipt["published_usec"]
                        and number(receipt.get("queue_latency_ms")) and receipt["queue_latency_ms"] >= 0,
                        "Incomplete publication latency")
                pair = row.get("matched", {})
                require(pair.get("same_input") is True, "Missing identical-input planner comparison")
                for control_arm in ("velocity_control", "candidate"):
                    plan(pair.get(control_arm))
                if first_impact < 0 and delay <= 1 and pair["candidate"]["accepted"] and pair["candidate"].get("approaching_count", 0) > 0:
                    first_impact = step - 1
                if arm == "conservative_baseline":
                    require(response["outcome"] == "DisabledControl" and not response["accepted"], "Baseline policy changed")
                else:
                    require(response.get("failed", False) is False, "Actual Rapier response failed")
                    if delay > 1:
                        require(response["outcome"] == "StaleContactSample" and not response["accepted"], "Stale publication accepted")
                    if response["accepted"]:
                        accepts += 1
                        require(response.get("readback_valid") is True, "Accepted response omitted actual post-application readback")
                        if first_impact < 0 and response["impulses"]:
                            first_impact = step - 1
                    else:
                        refusals[response["outcome"]] = refusals.get(response["outcome"], 0) + 1
            energy_delta = row["after_response"]["kinetic"] - row["before"]["kinetic"]
            near(row.get("response_energy_change"), energy_delta, "actual response work")
            require(energy_delta <= 0.0001 * max(1, row["before"]["kinetic"]), "Response energy limit failed")
            if not response["accepted"]:
                require(row["before"] == row["after_response"], "Refused or disabled response changed actual state")
            for action in response.get("impulses", []):
                impulse_sum += math.hypot(*action["impulse"])
                torque_sum += action["offset"][0] * action["impulse"][1] - action["offset"][1] * action["impulse"][0]
            rapier_delta = row["after"]["kinetic"] - row["after_response"]["kinetic"]
            near(row.get("rapier_energy_change"), rapier_delta, "actual free Rapier step energy")
            require(abs(rapier_delta) <= 0.0001 * max(1, row["after_response"]["kinetic"]),
                    "Unaccounted free-step energy change or sleep confound")
            for key in ("response_ms", "rapier_ms", "matched_planner_ms"):
                require(number(row.get(key)) and row[key] >= 0, "Missing per-step application work")
            stage_sum = sum(response.get(key, 0) for key in ("rid_state_ms", "planner_ms", "impulse_apply_ms", "readback_ms"))
            require(stage_sum <= row["response_ms"] + 1e-6, "Synchronized response stages exceed inclusive attempt work")
        stats = case.get("stats", {})
        integer_values = {"owner_attempts": 181, "complete_measurements": 181, "published": 181,
            "received": len(delivered), "missing": 180 - len(delivered), "queue_capacity": 3, "queue_peak": 3,
            "queue_evictions": 178, "overwritten": len(set(range(1, 179)) - delivered), "remaining_at_end": 3,
            "remaining_undelivered": len(set(range(179, 182)) - delivered),
            "response_attempts": 0 if arm == "conservative_baseline" else len(delivered), "response_accepts": accepts,
            "response_failures": 0, "energy_violations": 0, "nonfinite_states": 0, "sleep_steps": 0, "rapier_step_energy_violations": 0,
            "overlap_cell_ticks": sum(row["measurement"]["overlap_cells"] for row in trace),
            "geometry_probes": sum(value["geometry_probes"] for value in observations),
            "support_probes": sum(value["support_probes"] for value in observations)}
        positive_run = longest = positives = clear_run = 0
        sustained_start = -1
        for row in trace:
            observed = row["measurement"]
            positive = observed["sand_overlap_area"] > 1e-6 or observed["max_sand_penetration"] > 2e-5
            positive_run = positive_run + 1 if positive else 0
            clear_run = 0 if positive else clear_run + 1
            positives += positive
            longest = max(longest, positive_run)
            if clear_run >= 60 and sustained_start < 0:
                sustained_start = row["step"] - 59
        integer_values.update(positive_steps=positives, longest_positive_run=longest)
        for key, expected_value in integer_values.items():
            integer(stats.get(key), expected_value, key)
        require(stats.get("response_refusals") == refusals, "Refused contact attempts omitted or misclassified")
        float_values = {"area_cell_ticks": sum(row["measurement"]["overlap_area"] for row in trace),
            "sand_area_cell_ticks": sum(row["measurement"]["sand_overlap_area"] for row in trace),
            "max_penetration": max(value["max_penetration"] for value in observations),
            "max_sand_penetration": max(value["max_sand_penetration"] for value in observations),
            "owner_ms_total": sum(value["owner_ms"] for value in observations),
            "response_ms_total": sum(row["response_ms"] for row in trace), "rapier_ms_total": sum(row["rapier_ms"] for row in trace),
            "response_energy_change_sum": sum(row["response_energy_change"] for row in trace),
            "rapier_step_energy_change_sum": sum(row["rapier_energy_change"] for row in trace),
            "matched_planner_ms_total": sum(row["matched_planner_ms"] for row in trace),
            "queue_latency_ms_max": max((row["receipt"].get("queue_latency_ms", 0) for row in trace), default=0),
            "impulse_magnitude_sum": impulse_sum, "torque_impulse_sum": torque_sum}
        states = [initial["state"]] + [row["after"] for row in trace]
        float_values.update(max_speed=max(math.hypot(*value["velocity"]) for value in states),
            max_abs_omega=max(abs(value["omega"]) for value in states),
            max_translation=max(math.dist(value["pose"][4:], states[0]["pose"][4:]) for value in states),
            max_rotation_change=max(abs(math.atan2(value["pose"][1], value["pose"][0])
                - math.atan2(states[0]["pose"][1], states[0]["pose"][0])) for value in states))
        float_values["all_attempt_ms_per_complete_measurement"] = (float_values["owner_ms_total"] + float_values["response_ms_total"]) / 181
        for key, expected_value in float_values.items():
            near(stats.get(key), expected_value, key, 1e-5)
        require(number(stats.get("matched_planner_ms_total")) and stats["matched_planner_ms_total"] >= 0,
                "Diagnostic planner work omitted")
        recurrence = any(row["step"] > sustained_start + 59 and
            (row["measurement"]["sand_overlap_area"] > 1e-6 or row["measurement"]["max_sand_penetration"] > 2e-5)
            for row in trace) if sustained_start >= 0 else False
        initial_depth = observations[0]["max_sand_penetration"]
        embedded = initial_depth > 2e-5
        allowed_depth = initial_depth + 0.25 if embedded else 1.0
        expected_gates = {"newly_proposed": True, "initially_embedded": embedded, "initial_depth": initial_depth,
            "allowed_depth": allowed_depth, "depth_pass": float_values["max_sand_penetration"] <= allowed_depth,
            "sustained_clearance_pass": first_impact >= 0 and first_impact <= sustained_start <= first_impact + 120,
            "clearance_start_step": sustained_start, "first_valid_impact_step": first_impact,
            "recurrence_pass": sustained_start >= 0 and not recurrence, "observed_clearance_window_steps": 60,
            "recurrence_evaluable": sustained_start >= 0, "recurrence_detected": recurrence if sustained_start >= 0 else None,
            "response_energy_pass": True, "finite_state_pass": True, "position_work": 0.0, "physical_accepted": False}
        gates = case.get("physical_gates", {})
        for key, expected_value in expected_gates.items():
            require(key in gates and gates[key] == expected_value
                    and (type(gates[key]) is bool if type(expected_value) is bool else True)
                    and (type(gates[key]) is int if type(expected_value) is int else True),
                    "Physical gate redefined or differs from complete steps: " + key)
        summaries.append({"id": label, "max_sand_penetration": float_values["max_sand_penetration"],
            "overlap_cell_ticks": integer_values["overlap_cell_ticks"], "positive_steps": positives,
            "longest_positive_run": longest, "physical_gates": gates})
    return {"scope": "newly proposed frozen-field physical outcomes, separate from execution and original24 CPU gate",
            "cases": summaries, "physical_accepted": False,
            "sustained_clearance_failures": [item["id"] for item in summaries if not item["physical_gates"]["sustained_clearance_pass"]]}


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
    if spec.script == "test_solid_detachment_contact_recovery":
        verify_contact_recovery_result(result)
    identity = {"path": path.name, "sha256": digest(path)}
    if spec.script == "test_solid_contact_synchronized":
        identity["physical_outcomes"] = verify_synchronized_result(result, spec)
    return identity


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
              "status": "failed", "cohorts": [], "errors": [], "synchronized_physical_outcomes": [],
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
                original = verify_result_file(spec, path.parent, footer)
                require(original == record.get("result"), "Original result hash changed")
                if spec.script == "test_solid_contact_synchronized":
                    result["synchronized_physical_outcomes"].append({"platform": key[0], "workers": spec.workers,
                        "result_sha256": original["sha256"], **original["physical_outcomes"]})
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
