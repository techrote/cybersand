#!/usr/bin/env python3
"""Independent byte and custody checks for the successor GPU fixtures.

These are untimed material-history oracles, not physical-progression evidence.
Expected pixels are reconstructed in Python from the registered input tape;
neither a fixture's success flags nor its self-reported expected hashes suffice.
Callers must separately require a successful process, strict diagnostics, and
source-exact staged inputs. The executable hash is supplied by that caller and
matched against the hash observed inside the actual Godot process.
"""
from __future__ import annotations

from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re

from identity_domains import object_id, texture_rid


EXTENT = (2048, 2048)
WARMUP = 30
SAMPLES = 180
RING_FIXTURE = "res://tests/test_full_image_ring_publication.gd"
TRANSITION_FIXTURE = "res://tests/pubpres_full_image_ring_oracle.gd"
MAIN_FIXTURE = "res://tests/test_full_image_ring_main_recovery.gd"


def need(value, message):
    if not value:
        raise ValueError(message)


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def file_digest(path: Path) -> str:
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def terminal(text: str, marker: str) -> dict:
    rows = [line[len(marker):] for line in text.splitlines() if line.startswith(marker)]
    need(len(rows) == 1, "Missing or duplicated terminal oracle receipt: " + marker)
    data = json.loads(rows[0])
    need(isinstance(data, dict), "Oracle receipt is not an object")
    return data


def _success(data: dict, schema: str, checks: int | None = None):
    need(data["schema"] == schema and data["complete"] is True and data["failures"] == [],
         "Oracle did not complete the registered fixture")
    if checks is not None:
        need(type(data["checks"]) is int and data["checks"] == checks,
             "Oracle check coverage differs")


def _context(data: dict, source: str, project: Path, driver: str, engine_sha256: str,
             separate: bool, fixture: str, *, shader: bool = False):
    need(re.fullmatch(r"[0-9a-f]{40}", source) is not None
         and re.fullmatch(r"[0-9a-f]{64}", engine_sha256) is not None,
         "Caller source/executable identity is incomplete")
    need(type(separate) is bool and driver in ("opengl3", "opengl3_angle"),
         "Unregistered renderer identity")
    context = data["context"]
    need(context["schema"] == "palette-qualification-context-v1"
         and context["source_revision"] == source and context["fixture"] == fixture
         and context["fixture_sha256"] == file_digest(project / fixture.removeprefix("res://")),
         "Live fixture source identity differs")
    need(context["engine_sha256"] == engine_sha256
         and context["backend"] == driver and context["display_server"] not in ("headless", ""),
         "Live executable/graphical backend differs")
    need(context["platform"] == ("Windows" if driver == "opengl3_angle" else "Linux")
         and context["godot"]["major"] == 4 and context["godot"]["minor"] == 7,
         "Live engine version/platform differs")
    need(type(context["process_id"]) is int and context["process_id"] > 0
         and data["render_thread_inline"] is (not separate),
         "Actual process/render owner observation differs")
    policy = context["execution_policy"]
    need(policy["ok"] is True and policy["schema_version"] == 1
         and policy["path"] == "res://tests/support/ci_execution_policy.json"
         and policy["sha256"] == file_digest(project / "tests/support/ci_execution_policy.json"),
         "Live execution-policy source differs")
    if "source" in data:
        need(data["source"] == source and data["pid"] == context["process_id"]
             and data["driver"] == driver, "Top-level identity disagrees with live context")
    if "engine" in data:
        need(data["engine"] == context["godot"], "Engine version observations disagree")
    need(data["publisher_sha256"] == file_digest(project / "scripts/full_image_ring_publisher.gd"),
         "Live ring publisher source differs")
    if shader:
        observed = context["shader"]
        source_path = "res://shaders/material_palette.gdshader"
        shader_bytes = (project / source_path.removeprefix("res://")).read_bytes()
        bounded = driver == "opengl3_angle"
        variant = (b"#define CYBER_BOUNDED_CROSSFADE\n" if bounded else b"") + shader_bytes
        need(observed["source_path"] == source_path
             and observed["source_sha256"] == observed["source_file_sha256"] == digest(shader_bytes)
             and observed["variant_sha256"] == digest(variant)
             and observed["variant"] == ("angle_bounded_crossfade" if bounded else "full_crossfade")
             and observed["source_file_bound"] is True and observed["source_bound"] is True,
             "Live material shader source/variant differs")


def _history(row: dict, current: str, previous: str, *, verified: bool = False,
             expected_fields: bool = False):
    current_flag = "current_verified" if verified else "current_matches"
    previous_flag = "previous_verified" if verified else "previous_matches"
    need(row[current_flag] is True and row[previous_flag] is True,
         "First-read current or previous GPU history failed")
    need(row["current_sha256"] == current and row["previous_sha256"] == previous,
         "GPU history differs from independently reconstructed pixels")
    if expected_fields:
        need(row["expected_current_sha256"] == current and row["expected_previous_sha256"] == previous,
             "Fixture expected hashes disagree with independent reconstruction")


def queued_plane(width: int, height: int, channels: int, value: int) -> bytes:
    """Caller-owned R8/RG8 input before its mutation to black in the fixture."""
    pixel = bytes((value,)) if channels == 1 else bytes((value, 197 - value))
    plane = bytearray(pixel * (width * height))
    plane[:channels] = bytes((value + 1,)) if channels == 1 else bytes((value + 1, 17))
    plane[-channels:] = bytes((127,)) if channels == 1 else bytes((127, value + 2))
    return bytes(plane)


def ring_result(text: str, source: str, project: Path, driver: str, separate: bool = False,
                *, engine_sha256: str) -> dict:
    data = terminal(text, "FULL_IMAGE_RING_RESULT ")
    _success(data, "pubpres-full-image-ring-correctness-v1", 481 if separate else 475)
    _context(data, source, project, driver, engine_sha256, separate, RING_FIXTURE)
    observations = data["observations"]
    expected = {(width, height, channels) for width, height in ((33, 19), (512, 512), (2048, 1024))
                for channels in (1, 2)}
    need(len(observations) == 6
         and {(row["extent"][0], row["extent"][1], row["channels"]) for row in observations} == expected,
         "Ring size/format coverage differs")
    for row in observations:
        width, height = row["extent"]
        channels = row["channels"]
        need(type(channels) is int and row["resource_count"] == 3 and row["queued_publications"] == 17
             and row["logical_gpu_bytes"] == 3 * width * height * channels
             and row["separate"] is separate and row["render_gate_completed"] is separate,
             "Ring ownership/queue/allocation coverage differs")
        _history(row["histories"], digest(queued_plane(width, height, channels, 56)),
                 digest(queued_plane(width, height, channels, 55)), verified=True, expected_fields=True)
    data["independent_validation"] = {"schema": "pubpres-final-oracle-reconstruction-v1",
                                      "queued_histories_checked": 12, "case_count": 6,
                                      "actual_engine_sha256": engine_sha256}
    return data


def transition_plane(sequence: int) -> bytes:
    """Exact final RG8 plane after sequence N, derived from the latest dense write."""
    need(type(sequence) is int and sequence >= 0, "Invalid transition sequence")
    width, height = EXTENT
    dense = sequence if sequence % 12 == 0 else sequence - sequence % 12 + 1
    pixel = bytes((3 if dense % 2 == 0 else 58, (dense * 37) % 256))
    plane = bytearray(pixel * (width * height))
    if sequence > dense:
        patch = bytes((3 if sequence % 2 == 0 else 58, (sequence * 37) % 256)) * 8
        for y in range(96, 104):
            offset = (y * width + 96) * 2
            plane[offset:offset + len(patch)] = patch
    return bytes(plane)


@lru_cache(maxsize=1)
def transition_expectations() -> dict:
    width, height = EXTENT
    initial = bytearray(width * height * 2)
    stripe = bytes((58, 0)) * (width * 16)
    for y in range(8, height, 64):
        start = y * width * 2
        initial[start:start + len(stripe)] = stripe
    indices = {28, 29, 208, 209}
    entries = list(range(38, 210, 12))
    for index in entries:
        indices.update((index - 1, index))
    hashes = {index: digest(transition_plane(index)) for index in indices}
    return {"initial": digest(initial), "warmup": (hashes[29], hashes[28]),
            "terminal": (hashes[209], hashes[208]),
            "entries": [{"sequence": index, "current_sha256": hashes[index],
                         "previous_sha256": hashes[index - 1]} for index in entries]}


def transition_result(path: Path, project: Path, *, source: str, driver: str,
                      engine_sha256: str, separate: bool = False) -> dict:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    _success(data, "pubpres-full-image-ring-transition-history-v1")
    _context(data, source, project, driver, engine_sha256, separate, TRANSITION_FIXTURE, shader=True)
    need(data["application_main_sha256"] == file_digest(project / "scripts/main.gd"),
         "Transition Main source differs")
    need(data["frames_checked"] == data["current_matches"] == data["previous_matches"] == SAMPLES
         and data["resource_count"] == data["full_image_slots"] == 3
         and data["case"] == "transition_2048_w1" and data["tape"] == "transition"
         and data["sparse_entries"] == 15, "Transition frame/tape coverage differs")
    expected = transition_expectations()
    need(data["initial_plane_sha256"] == expected["initial"], "Initial transition substrate differs")
    _history(data["warmup_history"], *expected["warmup"])
    _history(data["history"], *expected["terminal"])
    need(data["entry_history"] == expected["entries"],
         "Dense-to-sparse entry sequence or exact GPU history differs")
    admissions = data["admissions"]
    need(len(admissions) == SAMPLES, "Incomplete transition admission sequence")
    fixed_ids = None
    for index, row in enumerate(admissions, WARMUP):
        need(row["sequence"] == index and row["revision"] == index + 1
             and row["current_matches"] is True and row["previous_matches"] is True,
             "Transition admission ordering/first-read GPU history differs")
        status = row["material"]
        need(status["requested_mode"] == status["mode"] == status["backend"] == "full"
             and status["fallback_reason"] == "" and status["driver"] == driver
             and status["full_image_slots_requested"] == "3"
             and status["full_image_slots"] == status["full_image_slot_count"] == 3
             and status["logical_source_format"] == status["gpu_storage_format"] == "RG8"
             and status["allocated_logical_gpu_bytes"] == 3 * EXTENT[0] * EXTENT[1] * 2
             and status["submitted_bytes"] == EXTENT[0] * EXTENT[1] * 2,
             "Transition publication treatment/allocation differs")
        ids, rids = status["texture_ids"], status["texture_rids"]
        need(len(ids) == len(set(ids)) == len(rids) == len(set(rids)) == 3
             and all(object_id(value) for value in ids) and all(texture_rid(value) for value in rids),
             "Transition texture ownership aliases or is missing")
        observed_ids = (tuple(ids), tuple(rids))
        if fixed_ids is None:
            fixed_ids = observed_ids
        need(observed_ids == fixed_ids, "Transition texture owners were replaced")
        current, previous, spare = ((2, 0, 1), (1, 2, 0), (0, 1, 2))[index % 3]
        need((status["current_slot"], status["previous_slot"], status["spare_slot"], status["upload_slot"])
             == (current, previous, spare, current), "Transition did not rotate only the preceding spare")
    data["independent_validation"] = {"schema": "pubpres-final-oracle-reconstruction-v1",
                                      "exact_hashes_checked": 35, "slot_admissions_checked": SAMPLES,
                                      "actual_engine_sha256": engine_sha256,
                                      "scope": "First GPU read histories; no physical-step or scanout claim."}
    return data


def main_recovery_result(text: str, source: str, project: Path, driver: str, separate: bool = False,
                         *, engine_sha256: str) -> dict:
    data = terminal(text, "FULL_IMAGE_RING_MAIN_RESULT ")
    _success(data, "pubpres-full-image-ring-main-recovery-v1", 32)
    _context(data, source, project, driver, engine_sha256, separate, MAIN_FIXTURE)
    need(data["main_sha256"] == file_digest(project / "scripts/main.gd"), "Recovery Main source differs")
    need(data["acks"] == [1, 2, 3, 4, 5, 6], "Recovery lost, reordered or invented an ACK")
    labels = ["admission1", "admission2", "admission3", "admission4", "refusal-recovery",
              "post-recovery", "mode-recreation"]
    rows = data["observations"]
    need([row["label"] for row in rows] == labels, "Recovery history sequence differs")
    hashes = {0: digest(bytes(33 * 19 * 2))}
    hashes.update({serial: digest(bytes((3 + serial, 137 - serial)) * (33 * 19)) for serial in range(1, 7)})
    for row, serial in zip(rows, (1, 2, 3, 4, 5, 6, 6)):
        _history(row, hashes[serial], hashes[serial - 1], verified=True, expected_fields=True)
    data["independent_validation"] = {"schema": "pubpres-final-oracle-reconstruction-v1",
                                      "recovery_histories_checked": 14, "exact_acks": [1, 2, 3, 4, 5, 6],
                                      "actual_engine_sha256": engine_sha256}
    return data
