#!/usr/bin/env python3
"""Observe untouched qualified Strata 002 and candidate Classic in the same job.

The only additional code loaded by the predecessor is a separately hashed,
external SceneTree diagnostic driver. Its original project is reconstructed
from the exact Git commit; native binaries are materialized only after their
original LFS identities and every native source input have been checked.
Six fresh processes alternate A/B, B/A, A/B. Raw observations survive failure.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import struct
import subprocess
import sys
import tarfile
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import qualify_strata2_workbench as previous
import strata_process_metrics as metrics

custody = previous.custody
require, sha, write_json = custody.require, custody.sha, custody.write_json
BASELINE = "934cc0c0eef70dad528155e9a92eebe25e2757eb"
OVERLAY = "godot/tools/qualify_workbench_strata3_predecessor.gd"
CALLBACKS = 90
ORDER = ("predecessor", "candidate", "candidate", "predecessor", "predecessor", "candidate")
HEX64 = re.compile(r"[0-9a-f]{64}")
TARGETS = {"admission_ms": 45000, "minimum_native_rate_ratio": 0.90,
           "minimum_rapier_rate_ratio": 0.90, "p95_ratio": 1.20, "p95_allowance_usec": 10000,
           "scope": "Paired hosted observations; no physical Windows/NVIDIA acceptance."
                    " Median rates and interval tails are distinct. All original admission misses remain failures."}


def number(value, lower=0):
    return type(value) in (int, float) and math.isfinite(value) and value >= lower


def integer(value, lower=0):
    return type(value) is int and value >= lower


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def digest(data: bytes):
    return hashlib.sha256(data).hexdigest()


def archive_environment() -> dict[str, str]:
    # Match the established portable packager: git archive applies checkout
    # conversions, including core.eol for text without a specific attribute.
    # The Linux receipt must reproduce byte-for-byte on the Windows packager.
    environment = dict(os.environ, GIT_LFS_SKIP_SMUDGE="1")
    count = environment.get("GIT_CONFIG_COUNT", "0")
    require(count.isdecimal(), "Invalid inherited Git environment configuration count")
    offset = int(count)
    for key, value in (("core.autocrlf", "false"), ("core.eol", "lf")):
        environment[f"GIT_CONFIG_KEY_{offset}"] = key
        environment[f"GIT_CONFIG_VALUE_{offset}"] = value
        offset += 1
    environment["GIT_CONFIG_COUNT"] = str(offset)
    return environment


def original_archive() -> bytes:
    # Git archive can run the repository's LFS export filter. Keep unrelated
    # platform artifacts as original pointers; materialize only the two exact
    # current-platform dependencies below, after checking their source identity.
    return subprocess.check_output(["git", "-C", str(ROOT), "archive", "--format=tar", BASELINE, "godot"],
                                   env=archive_environment(), timeout=60)


def png_rgba(data: bytes) -> tuple[int, int, bytes]:
    """Bounded standard-library decoder for Godot's exact8-bit RGB/RGBA pixels.

    The row-filter approach follows tools/play/pace004_contract.py; that existing
    decoder fixes960x540 and intentionally discards alpha. This custody reader
    retains alpha and the actual world crop extent without changing PACE004.
    """
    require(len(data) <= 32 * 1024 * 1024 and data.startswith(b"\x89PNG\r\n\x1a\n"), "Invalid bounded PNG")
    offset, header, ended = 8, None, False
    payload = bytearray()
    while offset < len(data):
        require(offset + 12 <= len(data), "Truncated PNG")
        size = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        require(offset + 12 + size <= len(data), "Truncated PNG chunk")
        body = data[offset + 8:offset + 8 + size]
        require(zlib.crc32(kind + body) & 0xffffffff == struct.unpack_from(">I", data, offset + 8 + size)[0], "PNG CRC failed")
        if kind == b"IHDR":
            require(offset == 8 and header is None and size == 13, "Duplicate or misplaced PNG header")
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            require(header is not None, "PNG pixels precede header")
            payload.extend(body)
        elif kind == b"IEND":
            require(size == 0 and header is not None and payload, "Empty or malformed PNG end")
            ended = True
            offset += 12
            break
        else:
            require(header is not None and kind[0] & 32 and kind != b"tRNS", "Unsupported PNG colour or critical chunk")
        offset += size + 12
    require(ended and offset == len(data), "Incomplete or trailing PNG data")
    width, height, depth, color, compression, filtering, interlace = header
    require(0 < width <= 4096 and 0 < height <= 4096 and depth == 8 and color in (2, 6)
            and compression == filtering == interlace == 0, "Unsupported PNG extent or pixel format")
    channels = 3 if color == 2 else 4
    stride = width * channels
    expected = (stride + 1) * height
    decoder = zlib.decompressobj()
    try:
        raw = decoder.decompress(bytes(payload), expected + 1)
    except zlib.error as error:
        raise RuntimeError("Invalid PNG deflate stream") from error
    require(len(raw) == expected and decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail,
            "PNG scanline size or bounded deflate stream mismatch")
    result = bytearray()
    prior = bytearray(stride)
    for y in range(height):
        mode = raw[y * (stride + 1)]
        scan = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        require(mode in range(5), "Invalid PNG scanline filter")
        for x in range(stride) if mode else ():
            a, b, c = (scan[x - channels] if x >= channels else 0), prior[x], (prior[x - channels] if x >= channels else 0)
            if mode == 1: predict = a
            elif mode == 2: predict = b
            elif mode == 3: predict = (a + b) // 2
            else:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                predict = a if pa <= pb and pa <= pc else b if pb <= pc else c
            scan[x] = (scan[x] + predict) & 255
        if channels == 4:
            result.extend(scan)
        else:
            for x in range(0, stride, 3):
                result.extend(scan[x:x + 3])
                result.append(255)
        prior = scan
    return width, height, bytes(result)


def percentile(values, fraction):
    require(bool(values), "Empty interval population")
    return sorted(values)[math.ceil(len(values) * fraction) - 1]


def distribution(values):
    return {"count": len(values), "p50": percentile(values, .50), "p95": percentile(values, .95),
            "p99": percentile(values, .99), "maximum": max(values),
            "stalls_at_least_usec": {str(n): sum(value >= n for value in values)
                                     for n in (100000, 250000, 500000, 1000000)}}


def validate_observation(result: dict, *, role: str, source: str, driver: str, scene: str) -> None:
    """Recompute physical witnesses; a successful assertion count is insufficient."""
    require(result.get("schema") == "strata3-predecessor-observation-v1"
            and result.get("phase") == "predecessor-comparison" and result.get("completed") is True
            and result.get("failures") == [] and integer(result.get("checks"), 1),
            "Incomplete or failed predecessor observation")
    require(result.get("role") == role and result.get("scene") == scene
            and result.get("source_revision") == source and result.get("driver_sha256") == driver,
            "Source, observer, or scene identity mismatch")
    require(result.get("display_server") in ("X11", "Wayland", "Windows")
            and result.get("rendering_method") == "gl_compatibility"
            and isinstance(result.get("rendering_adapter"), str) and result["rendering_adapter"]
            and result.get("ordinary_workbench") is True and result.get("diagnostic_headless") is False
            and integer(result.get("process_id"), 1), "Actual ordinary graphical Workbench was not established")
    require(result.get("admission_target_ms") == 45000 and integer(result.get("admission_elapsed_ms"))
            and result.get("admission_target_met") == (result["admission_elapsed_ms"] <= 45000),
            "Original 45-second scene-admission criterion was changed or misreported")
    require(result.get("world_count") == {"play_borrowed": 1, "decorative_owned": 3}
            and result.get("teardown", {}).get("native_world_count") == 0
            and result.get("teardown", {}).get("pending_native_world_count") == 0,
            "Actual four-plane ownership or retirement failed")
    hashes = result.get("initial_plane_native_hashes", {})
    require(set(hashes) == {"play", "scripted", "effects", "background"}
            and all(HEX64.fullmatch(str(value)) for value in hashes.values())
            and result.get("initial_native_hashes_canonical_json") == canonical(hashes),
            "Initial actual native material readbacks are incomplete")
    camera = result.get("camera", {})
    require(camera.get("window_size") == [1600, 1000] and number(camera.get("content_scale_factor"), .01),
            "Unmatched observation viewport")
    for key, length in (("origin", 2), ("view_size", 2), ("world_rect", 4)):
        require(isinstance(camera.get(key), list) and len(camera[key]) == length
                and all(number(value, -100000) for value in camera[key]), "Invalid camera " + key)
    pose = result.get("initial_actor", {})
    for key in ("position", "linear_velocity"):
        require(isinstance(pose.get(key), list) and len(pose[key]) == 2
                and all(number(value, -100000) for value in pose[key]), "Missing actual actor " + key)
    require(number(pose.get("rotation"), -10000) and number(pose.get("angular_velocity"), -10000),
            "Missing initial physical actor pose")
    sample = result.get("sample", {})
    before, after = sample.get("before", {}), sample.get("after", {})
    for key in ("world_generation", "physical_epoch", "worker_id", "actor_session_id", "actor_body_ids"):
        require(key in before and before[key] == after.get(key), "Physical owner changed during sample: " + key)
    require(all(previous.instance_id(before.get(key)) for key in ("worker_id", "actor_session_id"))
            and isinstance(before.get("actor_body_ids"), list) and before["actor_body_ids"]
            and all(previous.instance_id(value) for value in before["actor_body_ids"]), "Missing actual native/actor instance IDs")
    for key in ("native_tick", "rapier_tick"):
        require(integer(before.get(key)) and integer(after.get(key), before[key] + 1), "Missing actual progression: " + key)
    elapsed = sample.get("elapsed_usec")
    require(integer(elapsed, 1) and elapsed <= 95000000 and sample.get("callbacks") == CALLBACKS,
            "Incomplete or unbounded physical observation window")
    callbacks = sample.get("callback_intervals_usec", [])
    require(len(callbacks) == CALLBACKS and all(integer(value, 1) for value in callbacks)
            and sum(callbacks) <= elapsed and elapsed - sum(callbacks) < 1000000,
            "Display callback records do not cover the measured window")
    require(len(sample.get("main_process_ms", [])) == CALLBACKS
            and all(number(value) for value in sample["main_process_ms"]), "Missing actual main-thread observations")
    completions = sample.get("completed_physical_steps", [])
    require(isinstance(completions, list) and len(completions) >= 2
            and len(completions) == after["rapier_tick"] - before["rapier_tick"],
            "Missing actual completed Rapier steps; callback counts cannot substitute")
    for index, row in enumerate(completions):
        require(row.get("rapier_tick") == before["rapier_tick"] + index + 1
                and integer(row.get("completed_usec"), 1), "Gap or invalid value in actual completed physical sequence")
    intervals = [right["completed_usec"] - left["completed_usec"] for left, right in zip(completions, completions[1:])]
    require(all(value > 0 for value in intervals) and intervals == sample.get("physical_intervals_usec")
            and sum(intervals) <= elapsed, "Physical interval tails disagree with original completion timestamps")
    publications = sample.get("native_publications", [])
    require(isinstance(publications, list) and publications, "No native publications observed")
    last_tick, last_time = -1, -1
    for row in publications:
        require(integer(row.get("native_tick")) and last_tick < row["native_tick"] <= after["native_tick"]
                and integer(row.get("observed_usec"), 1) and row["observed_usec"] >= last_time
                and integer(row.get("published_usec"), 1) and integer(row.get("serial"))
                and number(row.get("worker_step_ms")), "Invalid already-published native observation")
        last_tick, last_time = row["native_tick"], row["observed_usec"]
    for label in ("native", "rapier"):
        rate = (after[label + "_tick"] - before[label + "_tick"]) * 1000000 / elapsed
        require(number(sample.get(label + "_ticks_per_second"), .00001)
                and math.isclose(rate, sample[label + "_ticks_per_second"], rel_tol=1e-6),
                "Physical progression rate does not follow actual ticks and elapsed time")
    require(sample.get("actor_before") == pose and number(sample.get("actor_distance_cells"), .01),
            "No matched actual actor movement")
    end = sample.get("actor_after", {}).get("position", [])
    require(len(end) == 2 and math.isclose(math.dist(pose["position"], end), sample["actor_distance_cells"],
                                        rel_tol=1e-5, abs_tol=1e-5), "Actor movement differs from actual native poses")
    require(sample.get("native_capture_delta") == 0 and sample.get("decorative_upload_delta") == 0,
            "Decorative material recapture/upload entered the timed observation")
    contract = result.get("observer_contract", {})
    require(all(contract.get(key) == 0 for key in ("image_readbacks_during_sample", "extra_native_ticks", "extra_worlds"))
            and contract.get("physical_gpu_acceptance") is False, "Observer scope exceeds the registered contract")
    if role == "candidate":
        require(result.get("optical_configuration", {}).get("profile") == "classic"
                and result["optical_configuration"].get("enabled") is False
                and result.get("optical_statistics", {}).get("active") is False,
                "Candidate did not use optically disabled exact Classic")
    else:
        require(result.get("optical_statistics") == {"original_presenter": True, "optical_api_present": False},
                "Predecessor production presentation was modified")


def compare(results: list[dict]) -> dict:
    require(len(results) == len(ORDER) and tuple(row.get("role") for row in results) == ORDER,
            "Required six-process interleaved comparison is incomplete")
    reference = results[0]
    require(HEX64.fullmatch(str(reference.get("classic_pixels", {}).get("rgba8_sha256", ""))),
            "No actual predecessor pixel witness")
    for row in results[1:]:
        for key in ("scene", "initial_plane_native_hashes", "initial_actor", "camera", "extent",
                    "display_server", "rendering_method", "rendering_adapter"):
            require(row.get(key) == reference.get(key), "Unmatched predecessor/candidate condition: " + key)
        require(row.get("classic_pixels", {}).get("rgba8_sha256") == reference.get("classic_pixels", {}).get("rgba8_sha256")
                and row.get("classic_pixels", {}).get("size") == reference.get("classic_pixels", {}).get("size"),
                "Candidate Classic differs from actual frozen predecessor world pixels")
    medians, populations = {}, {}
    for role in ("predecessor", "candidate"):
        selected = [row for row in results if row["role"] == role]
        populations[role] = [{"native_ticks_per_second": row["sample"]["native_ticks_per_second"],
                              "rapier_ticks_per_second": row["sample"]["rapier_ticks_per_second"],
                              "physical_intervals_usec": distribution(row["sample"]["physical_intervals_usec"]),
                              "admission_elapsed_ms": row["admission_elapsed_ms"],
                              "admission_target_met": row["admission_target_met"]} for row in selected]
        medians[role] = {key: statistics.median(row[key] for row in populations[role])
                         for key in ("native_ticks_per_second", "rapier_ticks_per_second", "admission_elapsed_ms")}
        medians[role]["physical_p95_usec"] = statistics.median(row["physical_intervals_usec"]["p95"] for row in populations[role])
    old, new = medians["predecessor"], medians["candidate"]
    criteria = {"native_progression": new["native_ticks_per_second"] >= old["native_ticks_per_second"] * .90,
                "rapier_progression": new["rapier_ticks_per_second"] >= old["rapier_ticks_per_second"] * .90,
                "physical_p95": new["physical_p95_usec"] <= max(old["physical_p95_usec"] * 1.2, old["physical_p95_usec"] + 10000)}
    return {"matched_actual_native_geometry_actor_camera": True, "classic_world_rgba8_identical": True,
            "populations": populations, "medians": medians, "criteria": criteria,
            "comparative_gate": "observed-targets-met" if all(criteria.values()) else "observed-regression-requires-review",
            "physical_owner_acceptance": "pending", "scope": TARGETS["scope"],
            "short_window_limit": "Three fresh processes per source and90display callbacks each; tails and host-load spread remain visible. This is not sustained hardware qualification."}


def safe_relative(folder: Path, name: str) -> Path:
    require(isinstance(name, str) and name and "\\" not in name and ":" not in name and not name.startswith("/")
            and not Path(name).is_absolute() and ".." not in Path(name).parts, "Unsafe evidence path")
    path = folder / name
    require(path.is_file() and not path.is_symlink(), "Missing original evidence: " + name)
    return path


def verify(folder: Path) -> dict:
    record = json.loads((folder / "comparison.json").read_text(encoding="utf-8"))
    require(record.get("schema") == "strata3-predecessor-comparison-v1" and record.get("completed") is True
            and record.get("failures") == [] and record.get("baseline_ref") == BASELINE,
            "Incomplete or non-principal predecessor comparison")
    require(record.get("registration") == TARGETS and record.get("order") == list(ORDER)
            and record.get("callbacks_per_sample") == CALLBACKS, "Comparison criteria or order changed")
    ledger = record.get("files_sha256", {})
    require(isinstance(ledger, dict) and ledger, "Missing original evidence hash ledger")
    for name, expected in ledger.items():
        require(HEX64.fullmatch(str(expected)) and sha(safe_relative(folder, name)) == expected,
                "Changed original comparison evidence: " + name)
    observer = record.get("observer", {})
    require(observer.get("path") in ledger and ledger[observer["path"]] == observer.get("sha256"),
            "External observer is not bound to retained bytes")
    candidate_source = record.get("candidate_source", {})
    require(re.fullmatch(r"[0-9a-f]{40}", str(candidate_source.get("source_commit", "")))
            and candidate_source.get("local_delta") == [], "Candidate source was not frozen")
    require(digest((folder / observer["path"]).read_bytes().replace(b"\r\n", b"\n"))
            == candidate_source.get("source_inputs_sha256", {}).get(OVERLAY),
            "External observer bytes differ from the frozen candidate source")
    require(record.get("original_project_unchanged") is True and record.get("candidate_project_unchanged") is True,
            "Original and candidate source preservation was not established")
    require(record.get("godot", {}).get("version") == custody.windows.GODOT_VERSION
            and record["godot"].get("sha256") == previous.GODOT_SHA256.get(record.get("host", {}).get("platform")),
            "Unqualified comparison engine")
    original = record.get("baseline_identity", {})
    require(original.get("source_commit") == BASELINE and original.get("overlay_location") == "external-to-original-project",
            "Original source or external-overlay contract changed")
    archive = original_archive()
    require(original.get("archive_sha256") == digest(archive)
            and original.get("source_tree") == custody.git("rev-parse", BASELINE + "^{tree}").decode().strip(),
            "Original project archive identity differs from qualified application")
    expected_original = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        for member in bundle.getmembers():
            name = member.name.removeprefix("godot/")
            if member.isfile() and ".godot" not in Path(name).parts:
                expected_original[name] = digest(bundle.extractfile(member).read())
    for kind in ("cybersand_runtime", "rapier_runtime"):
        entry = record.get("runtime", {}).get(kind, {})
        require(isinstance(entry.get("path"), str) and HEX64.fullmatch(str(entry.get("sha256", "")))
                and integer(entry.get("size"), 1), "Missing actual source-matched runtime identity")
        pointer = custody.git("show", BASELINE + ":" + entry["path"])
        require(pointer == f"version https://git-lfs.github.com/spec/v1\noid sha256:{entry['sha256']}\nsize {entry['size']}\n".encode(),
                "Runtime is not the qualified predecessor's exact LFS artifact")
        expected_original[entry["path"].removeprefix("godot/")] = entry["sha256"]
    require(original.get("source_inputs_raw_sha256") == expected_original, "Original production source manifest changed")
    results = []
    cases = record.get("cases", [])
    require(len(cases) == len(ORDER), "Missing original paired process")
    for index, (case, role) in enumerate(zip(cases, ORDER)):
        label = f"pair-{index // 2 + 1}-{role}"
        require(case.get("label") == label and case.get("role") == role, "Changed paired case identity")
        location = folder / label
        process_path = safe_relative(folder, label + "/process.json")
        require(label + "/process.json" in ledger, "Process receipt is not in ledger")
        process = json.loads(process_path.read_text(encoding="utf-8"))
        require(process == case["process"] and process.get("status") == "passed" and process.get("exit_code") == 0
                and process.get("log_sha256") == sha(location / "process.log")
                and not custody.ERRORS.search((location / "process.log").read_text(encoding="utf-8", errors="replace")),
                "Actual process failed, logged a script error, or changed")
        command = process.get("command", [])
        require("--headless" not in command and command[-2] == "--script"
                and Path(command[-1]).name == Path(observer["path"]).name,
                "Observation did not execute the external graphical driver")
        result_path = safe_relative(folder, label + "/report.json")
        require(label + "/report.json" in ledger, "Actual report is not in ledger")
        result = json.loads(result_path.read_text(encoding="utf-8"))
        validate_observation(result, role=role, source=BASELINE if role == "predecessor" else candidate_source["source_commit"],
                             driver=observer["sha256"], scene=record["scene"])
        previous.verify_resource_receipt(folder, dict(process, label=label), result["process_id"])
        pixels = result.get("classic_pixels", {})
        require(pixels.get("filename") == "classic-world.png" and HEX64.fullmatch(str(pixels.get("rgba8_sha256", ""))),
                "Missing actual original Classic pixels")
        image_path = safe_relative(folder, label + "/classic-world.png")
        require(label + "/classic-world.png" in ledger and sha(image_path) == pixels.get("sha256"), "Original Classic capture changed")
        width, height, rgba = png_rgba(image_path.read_bytes())
        require([width, height] == pixels.get("size") and digest(rgba) == pixels["rgba8_sha256"],
                "Decoded actual pixel bytes differ from native image witness")
        results.append(result)
    derived = compare(results)
    require(record.get("summary") == derived, "Stored comparison summary disagrees with original observations")
    return derived


def baseline_project(destination: Path, candidate: Path, runtime: dict) -> tuple[Path, dict]:
    """Archive original sources without overlaying any candidate application file."""
    archive = original_archive()
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        for member in bundle.getmembers():
            require(not member.issym() and not member.islnk() and not Path(member.name).is_absolute()
                    and ".." not in Path(member.name).parts, "Unsafe original archive member")
        bundle.extractall(destination, filter="data")
    project = destination / "godot"
    original_native = json.loads(custody.git("show", BASELINE + ":" + runtime["runtime_provenance"]["path"]))
    require(original_native["source_inputs"] == runtime["native_source_inputs"],
            "Original and candidate native runtime inputs differ")
    for name, expected in runtime["native_source_inputs"].items():
        require(digest(custody.git("show", BASELINE + ":" + name).replace(b"\r\n", b"\n")) == expected,
                "Original native source does not match retained runtime: " + name)
    materialized = {}
    for kind in ("cybersand_runtime", "rapier_runtime"):
        entry = runtime[kind]
        pointer = custody.git("show", BASELINE + ":" + entry["path"])
        expected = f"version https://git-lfs.github.com/spec/v1\noid sha256:{entry['sha256']}\nsize {entry['size']}\n".encode()
        require(pointer == expected, "Original native/Rapier binary identity differs: " + kind)
        relative = entry["path"].removeprefix("godot/")
        source = candidate / relative
        require(sha(source) == entry["sha256"] and source.stat().st_size == entry["size"], "Candidate retained runtime changed")
        shutil.copyfile(source, project / relative)
        materialized[relative] = entry["sha256"]
    original = {path.relative_to(project).as_posix(): sha(path) for path in project.rglob("*")
                if path.is_file() and ".godot" not in path.relative_to(project).parts}
    return project, {"source_commit": BASELINE, "source_tree": custody.git("rev-parse", BASELINE + "^{tree}").decode().strip(),
                     "archive_sha256": digest(archive), "source_inputs_raw_sha256": original,
                     "materialized_lfs_sha256": materialized, "overlay_location": "external-to-original-project"}


def assert_original(project: Path, identity: dict) -> None:
    for name, expected in identity["source_inputs_raw_sha256"].items():
        require(sha(project / name) == expected, "Original production source changed during observation: " + name)
    actual_scripts = {path.relative_to(project).as_posix() for path in project.rglob("*.gd") if ".godot" not in path.parts}
    require(actual_scripts == {name for name in identity["source_inputs_raw_sha256"] if name.endswith(".gd")},
            "A new production script entered the original project")


def run(args) -> dict:
    output, candidate, godot = args.output.resolve(), args.candidate_project.resolve(), args.godot.resolve()
    require(args.baseline_ref == BASELINE, "Principal comparison must use the qualified934cc0c application")
    require(not output.exists(), "Use a fresh output directory; retain previous failures")
    require(sha(godot) == previous.GODOT_SHA256.get(sys.platform), "Godot runtime differs from pinned4.7")
    version = subprocess.check_output([str(godot), "--version"], timeout=20).decode().strip()
    require(version == custody.windows.GODOT_VERSION, "Wrong exact Godot runtime")
    source, runtime = previous.identity(), custody.verify_runtime_identity()
    loaded = custody.project_identity(candidate, source, runtime)
    assets = previous.project_assets_identity(candidate, source)
    output.mkdir(parents=True)
    observer = output / "observer" / Path(OVERLAY).name
    observer.parent.mkdir()
    shutil.copyfile(ROOT / OVERLAY, observer)
    record = {"schema": "strata3-predecessor-comparison-v1", "baseline_ref": BASELINE,
              "candidate_source": source, "candidate_loaded_source_sha256": loaded, "candidate_assets_sha256": assets,
              "runtime": runtime, "godot": {"sha256": sha(godot), "version": version},
              "observer": {"path": observer.relative_to(output).as_posix(), "sha256": sha(observer)},
              "host": {"platform": sys.platform, "system": platform.platform(), "machine": platform.machine(),
                       "logical_cpu_count": os.cpu_count(), "job": os.environ.get("GITHUB_JOB", ""),
                       "run_id": os.environ.get("GITHUB_RUN_ID", ""), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "")},
              "scene": args.scene, "callbacks_per_sample": CALLBACKS, "order": list(ORDER),
              "registration": TARGETS, "cases": [], "completed": False, "failures": []}
    results = []
    try:
        with tempfile.TemporaryDirectory(prefix="strata003-qualified-predecessor-") as temporary:
            baseline, record["baseline_identity"] = baseline_project(Path(temporary), candidate, runtime)
            bootstrap_env = custody.case_environment(output / "bootstrap-userdata")
            record["baseline_import"] = metrics.execute([str(godot), "--headless", "--editor", "--path", str(baseline), "--quit"],
                                                        output / "baseline-import", bootstrap_env, 600)
            require(record["baseline_import"]["status"] == "passed", "Original project import failed")
            assert_original(baseline, record["baseline_identity"])
            for index, role in enumerate(ORDER):
                label = f"pair-{index // 2 + 1}-{role}"
                location = output / label
                environment = custody.case_environment(output / "userdata" / label)
                environment.update(STRATA_SCENE=args.scene, STRATA_EVIDENCE=str(location), STRATA_REPORT=str(location / "report.json"),
                                   STRATA3_COMPARISON_ROLE=role, STRATA3_DRIVER_SHA256=sha(observer),
                                   CYBERSAND_SOURCE_REVISION=BASELINE if role == "predecessor" else source["source_commit"])
                command = [str(godot), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                           "--rendering-driver", "opengl3", "--path", str(baseline if role == "predecessor" else candidate),
                           "--script", str(observer)]
                process = metrics.execute(command, location, environment, 600)
                record["cases"].append({"label": label, "role": role, "process": process})
                require(process["status"] == "passed", "Paired process failed: " + label)
                result = json.loads((location / "report.json").read_text(encoding="utf-8"))
                validate_observation(result, role=role, source=environment["CYBERSAND_SOURCE_REVISION"],
                                     driver=sha(observer), scene=args.scene)
                results.append(result)
                assert_original(baseline, record["baseline_identity"])
                require(custody.project_identity(candidate, source, runtime) == loaded
                        and previous.project_assets_identity(candidate, source) == assets,
                        "Candidate project changed during observation")
                write_json(output / "comparison.json", record)
            record["summary"] = compare(results)
            record["original_project_unchanged"] = True
            record["candidate_project_unchanged"] = True
            record["completed"] = True
    except Exception as error:
        record["failures"].append(str(error))
    finally:
        record["files_sha256"] = {path.relative_to(output).as_posix(): sha(path) for path in output.rglob("*")
                                   if path.is_file() and path.name != "comparison.json"
                                   and not any(part in ("userdata", "bootstrap-userdata") for part in path.relative_to(output).parts)}
        write_json(output / "comparison.json", record)
    require(record["completed"] and not record["failures"], "Predecessor comparison incomplete: " + "; ".join(record["failures"]))
    verify(output)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", type=Path, help="Independently re-read all retained observations and original bytes")
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--candidate-project", type=Path, default=ROOT / "godot")
    parser.add_argument("--baseline-ref", default=BASELINE)
    parser.add_argument("--scene", choices=previous.SCENES, default="industrial-underworks")
    args = parser.parse_args()
    try:
        if args.verify:
            summary = verify(args.verify.resolve())
        else:
            require(args.godot is not None and args.output is not None, "--godot and --output are required")
            summary = run(args)["summary"]
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0
    except (RuntimeError, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print("PREDECESSOR_COMPARISON_REJECTED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
