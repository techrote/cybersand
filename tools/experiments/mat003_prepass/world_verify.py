#!/usr/bin/env python3
"""Independent, fail-closed readback of the registered S1 World evidence.

This reader does not import the collector, carrier implementation, overlay
generator or fixture. Hashes bind retained files; explicit byte comparisons and
an independently decoded trace establish the registered comparison. Neither is
a claim of trusted publication, production acceptance or performance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PureWindowsPath
import re
import struct
import sys

STAGE = "S1-World-correctness"
EXPERIMENT = "tools/experiments/mat003_prepass/"
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
GIT_SHA = re.compile(r"[0-9a-f]{40}\Z")
KINDS = {"source": 0, "word": 1, "padded": 2, "packed": 3, "aligned": 4, "split": 5}
EXPECTED_ARMS = {"C64-E8-source"}
EXPECTED_ARMS |= {f"C64-E{epoch}-{rep}" for epoch in (8, 16) for rep in ("word", "padded")}
EXPECTED_ARMS |= {f"C{width}-E{epoch}-{rep}" for width in (72, 80) for epoch in (8, 16)
                 for rep in ("packed", "aligned", "split")}
TRACE_SPECS = {
    "ordinary-serial": (2048, "serial", 1),
    "ordinary-phased-1": (2048, "phased", 1),
    "ordinary-phased-4": (2048, "phased", 4),
    "natural": (131080, "phased", 1),
}
COMMON_SOURCES = {"source/native/src/" + name + ".cpp" for name in
                  ("material_rules", "scheduler_geometry", "settled_world_discovery")}
BASE_PATCH_LABELS = {
    "include isolated adapter",
    "type every World epoch consumer together",
    "select isolated carrier",
    "preserve selected width at World increment",
    "observe actual pool dispatch",
    "observe background worker task execution",
}
SPLIT_PATCH_LABELS = {
    "prepare dense bounded tails at chunk admission",
    "own separate neutral-tail array",
    "reset neutral tail with write_cell replacement",
    "reset neutral tail with public set replacement",
    "stage tails before whole-cell move or swap",
    "transfer source tail with destination carrier",
    "swap destination tail or reset vacancy",
    "reset newly Water destination neutral tail",
    "reset exhausted Water source neutral tail",
}


def checked_path(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or not relative or "\\" in relative:
        raise ValueError("artifact path must be a nonempty portable relative path")
    path = Path(relative)
    if path.is_absolute() or PureWindowsPath(relative).drive or ".." in path.parts:
        raise ValueError(f"unsafe artifact path: {relative}")
    resolved = (root / path).resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise ValueError(f"artifact escapes evidence directory: {relative}")
    return resolved


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON field: {key}")
        result[key] = value
    return result


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_unique_object)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def exact_bytes_equal(left: Path, right: Path) -> bool:
    if left.stat().st_size != right.stat().st_size:
        return False
    with left.open("rb") as a, right.open("rb") as b:
        while True:
            av, bv = a.read(1024 * 1024), b.read(1024 * 1024)
            if av != bv:
                return False
            if not av:
                return True


def _integer(value, minimum=0):
    return type(value) is int and value >= minimum


def verify_overlay(root: Path, name: str, spec: dict, registration: dict,
                   files: dict) -> list[str]:
    """Reconstruct every generated native file from its retained exact input."""
    errors = []
    label = spec["id"] + " overlay"
    try:
        if name not in files:
            raise ValueError("manifest is absent from artifact ledger")
        manifest_path = checked_path(root, name)
        overlay = load_json(manifest_path)
        if overlay.get("schema_version") != 1 or overlay.get("arm") != spec:
            errors.append(label + ": schema/arm differs from registration")
        source = spec["representation"] == "source"
        if overlay.get("source_control_unchanged") is not source:
            errors.append(label + ": source-control declaration is incorrect")
        if overlay.get("dispatch_observed") is not (not source):
            errors.append(label + ": dispatch observation declaration is incorrect")
        if overlay.get("split_tail_allocation") != (
                "dense-at-chunk-admission" if spec["representation"] == "split" else "inapplicable"):
            errors.append(label + ": split allocation policy is incorrect")
        registration_name = "source/" + EXPERIMENT + "world_registration.json"
        if overlay.get("registration_sha256") != files.get(registration_name, {}).get("sha256"):
            errors.append(label + ": frozen registration identity differs")
        patches = overlay.get("patches")
        if not isinstance(patches, list):
            raise ValueError("patch list is missing")
        expected_labels = set() if source else BASE_PATCH_LABELS.copy()
        if spec["representation"] == "split":
            expected_labels |= SPLIT_PATCH_LABELS
        labels = [p.get("label") for p in patches if isinstance(p, dict)]
        if (len(labels) != len(patches) or len(labels) != len(expected_labels)
                or set(labels) != expected_labels):
            errors.append(label + ": exact registered patch inventory differs")
        items = overlay.get("files")
        if not isinstance(items, list):
            raise ValueError("native overlay file inventory is missing")
        paths = [item.get("path") for item in items if isinstance(item, dict)]
        baseline = registration["baseline_control_sha256"]
        if len(paths) != len(items) or len(paths) != len(set(paths)) or set(paths) != set(baseline):
            errors.append(label + ": incomplete or duplicate native file inventory")
        overlay_relative = Path(name).parent
        for item in items:
            relative = item["path"]
            original_name = "source/" + relative
            generated_name = (overlay_relative / relative).as_posix()
            if original_name not in files or generated_name not in files:
                errors.append(label + ": unhashed input/output " + relative)
                continue
            original = checked_path(root, original_name).read_bytes()
            expected = original.decode("utf-8")
            if item.get("input_sha256") != baseline.get(relative):
                errors.append(label + ": baseline mismatch " + relative)
            for patch in patches:
                if patch.get("path") != relative:
                    continue
                if relative not in ("native/src/world.cpp", "native/include/cybersand/world.hpp"):
                    raise ValueError("patch outside the two declared World files")
                before, after = patch["before"], patch["after"]
                if not isinstance(before, str) or not before or not isinstance(after, str):
                    raise ValueError("malformed source substitution")
                if expected.count(before) != 1:
                    raise ValueError("source substitution does not have exactly one match")
                expected = expected.replace(before, after, 1)
            actual = checked_path(root, generated_name).read_bytes()
            if actual != expected.encode("utf-8"):
                errors.append(label + ": literal reconstructed bytes differ " + relative)
            if hashlib.sha256(actual).hexdigest() != item.get("output_sha256"):
                errors.append(label + ": output hash differs " + relative)
            if source and actual != original:
                errors.append(label + ": original source control was changed " + relative)
        # Every apparatus copy used by the compiler is the frozen input too.
        for original_name in files:
            if (not original_name.startswith("source/" + EXPERIMENT)
                    or Path(original_name).suffix not in (".py", ".hpp", ".cpp", ".json")):
                continue
            generated_name = (overlay_relative / original_name.removeprefix("source/")).as_posix()
            if generated_name not in files or not exact_bytes_equal(
                    checked_path(root, original_name), checked_path(root, generated_name)):
                errors.append(label + ": copied apparatus differs " + original_name)
        expected_macros = {
            f'-DMAT003_ARM_ID="{spec["id"]}"',
            f'-DMAT003_STORAGE_KIND={KINDS[spec["representation"]]}',
            f'-DMAT003_EPOCH_BITS={spec["epoch_bits"]}',
            f'-DMAT003_EXTRA_BYTES={spec["neutral_extra_bits"] // 8}',
            f'-DMAT003_SPLIT={int(spec["representation"] == "split")}',
            f'-DMAT003_WORLD_SOURCE="{overlay.get("world_source")}"',
        }
        macros = overlay.get("compile_definitions", [])
        if len(macros) != len(expected_macros) or set(macros) != expected_macros:
            errors.append(label + ": compile definitions do not select the registered arm")
    except (OSError, UnicodeError, ValueError, KeyError, TypeError, AttributeError) as exc:
        errors.append(label + ": unreadable or malformed evidence: " + str(exc))
    return errors


def verify_receipt(root: Path, receipt: dict, files: dict, label: str,
                   timeout: int, flags: list[str] | None = None) -> list[str]:
    errors = []
    if not isinstance(receipt, dict):
        return [label + ": command receipt is missing"]
    if type(receipt.get("exit_code")) is not int or receipt["exit_code"] != 0:
        errors.append(label + ": command did not exit successfully")
    if receipt.get("timed_out") is not False:
        errors.append(label + ": command timed out or lacks completion status")
    if not _integer(receipt.get("timeout_seconds"), 1) or receipt["timeout_seconds"] > timeout:
        errors.append(label + ": command timeout exceeds or omits registration")
    command = receipt.get("command")
    if (not isinstance(command, list) or not command
            or not all(isinstance(part, str) and part for part in command)):
        errors.append(label + ": command identity is missing")
    elif flags is not None and command[1:1 + len(flags)] != flags:
        errors.append(label + ": compiler flags differ from registration")
    for stream in ("stdout", "stderr"):
        if receipt.get(stream) not in files:
            errors.append(label + ": raw " + stream + " is not retained and hashed")
        else:
            try:
                checked_path(root, receipt[stream])
            except ValueError as exc:
                errors.append(label + ": " + str(exc))
    return errors


class Reader:
    def __init__(self, data: bytes):
        self.data = data
        self.offset = 0

    def take(self, length: int) -> bytes:
        if length < 0 or self.offset + length > len(self.data):
            raise ValueError("truncated exact snapshot")
        result = self.data[self.offset:self.offset + length]
        self.offset += length
        return result

    def unpack(self, fmt: str):
        layout = struct.Struct("<" + fmt)
        if self.offset + layout.size > len(self.data):
            raise ValueError("truncated exact snapshot field")
        values = layout.unpack_from(self.data, self.offset)
        self.offset += layout.size
        return values[0] if len(values) == 1 else values

    def boolean(self):
        value = self.unpack("B")
        if value not in (0, 1):
            raise ValueError("non-boolean snapshot flag")
        return value

    def region(self):
        return self.unpack("qqqq") if self.boolean() else None


def decode_snapshot(raw: bytes, cell_cache: dict | None = None) -> dict:
    """Decode explicit fields and independently derive resident species/mass.

    A bounded per-chunk cache only reuses a reduction when the complete retained
    eight-byte-per-cell record is exactly equal, including its support predicate.
    It does not substitute a digest for comparison or omit Empty records.
    """
    reader = Reader(raw)
    tick, completed = reader.unpack("QQ")
    failed = reader.boolean()
    backend = reader.unpack("B")
    if backend not in (0, 1):
        raise ValueError("unsupported backend in exact trace")
    chunk_size, chunk_count = reader.unpack("II")
    if not 8 <= chunk_size <= 1024 or chunk_count > 4096:
        raise ValueError("invalid resident geometry in exact trace")
    if completed > tick or (not failed and completed != tick):
        raise ValueError("attempted/completed tick identity is inconsistent")
    species = [0] * 132
    water = cells_total = 0
    chunk_keys = []
    high_a = nonzero_empty = temperatures_nondefault = 0
    quiet_active = deadlines = 0
    if cell_cache is None:
        cell_cache = {}
    live_keys = set()
    for _ in range(chunk_count):
        x, y, count = reader.unpack("qqI")
        key = (y, x)
        if chunk_keys and key <= chunk_keys[-1]:
            raise ValueError("duplicate or unordered signed chunk coordinates")
        chunk_keys.append(key)
        live_keys.add(key)
        if count != chunk_size * chunk_size:
            raise ValueError("cell count does not match resident chunk geometry")
        cells_total += count
        cell_bytes = reader.take(count * 8)
        cached = cell_cache.get(key)
        if cached is not None and cached[0] == cell_bytes:
            reduction = cached[1]
        else:
            local_species = [0] * 132
            local_water = local_high = local_empty = local_temperature = 0
            for material, a, b, temperature, current_stamp in struct.iter_unpack("<HHBhB", cell_bytes):
                if material >= 132 or material == 10 or current_stamp not in (0, 1):
                    raise ValueError("invalid material or current-stamp predicate")
                local_species[material] += 1
                if material == 3:
                    if not 1 <= a <= 255 or b > 12:
                        raise ValueError("Water state outside the unchanged default policy")
                    local_water += a
                local_high += a > 255
                local_empty += material == 0 and (a != 0 or b != 0)
                local_temperature += temperature != 200
            reduction = (local_species, local_water, local_high, local_empty, local_temperature)
            cell_cache[key] = (cell_bytes, reduction)
        local_species, local_water, local_high, local_empty, local_temperature = reduction
        species = [a + b for a, b in zip(species, local_species)]
        water += local_water
        high_a += local_high
        nonzero_empty += local_empty
        temperatures_nondefault += local_temperature
        blocks = reader.unpack("I")
        if blocks == 0 or blocks > count:
            raise ValueError("invalid activity block count")
        for _ in range(blocks):
            deadline, quiet, active, changed = reader.unpack("QIBB")
            if active not in (0, 1) or changed not in (0, 1):
                raise ValueError("invalid activity block flags")
            deadlines += deadline != 0
            quiet_active += bool(quiet and active)
        nonempty = reader.unpack("Q")
        reader.unpack("I")  # Chunk quiet count.
        reader.boolean(); reader.boolean(); reader.boolean()
        reader.unpack("iiii")  # Dirty rectangle; inactive values remain observable.
        if nonempty != count - local_species[0]:
            raise ValueError("chunk nonempty bookkeeping disagrees with retained cells")
    for key in list(cell_cache):
        if key not in live_keys:
            del cell_cache[key]
    requested = reader.region()
    selected = reader.region()
    applied = reader.region()
    pending = reader.unpack("I")
    if pending > 1024:
        raise ValueError("pending event count exceeds registered default capacity")
    for _ in range(pending):
        _x, _y, radius, _strength = reader.unpack("qqiB")
        if not 0 <= radius <= 64:
            raise ValueError("pending event radius outside registered policy")
    hard_revision = reader.unpack("Q")
    stats = reader.unpack("Q" * 15)
    if stats[0] != completed:
        raise ValueError("tick statistics identify a different completed tick")
    recorded_water, recorded_sand = reader.unpack("QQ")
    species_count = reader.unpack("I")
    if species_count != 132:
        raise ValueError("species ledger does not cover the frozen catalogue")
    recorded_species = list(reader.unpack("Q" * species_count))
    if recorded_water != water or recorded_sand != species[2] or recorded_species != species:
        raise ValueError("independent Water/species reduction disagrees with trace ledger")
    support_count = reader.unpack("I")
    if support_count > cells_total + 1024:
        raise ValueError("unbounded support sample count")
    supports = []
    for _ in range(support_count):
        x, y, down, side = reader.unpack("qqBB")
        if down not in (0, 1) or side not in (0, 1):
            raise ValueError("invalid support predicate")
        supports.append((x, y, down, side))
    diagnostics = reader.unpack("I")
    if diagnostics > 1_000_000:
        raise ValueError("unbounded diagnostic record count")
    last_key = -1
    diagnostic_totals = {}
    for _ in range(diagnostics):
        key, count = reader.unpack("IQ")
        if key <= last_key or count == 0:
            raise ValueError("duplicate/unordered/empty diagnostic entry")
        last_key = key
        kind = key >> 24
        if not 1 <= kind <= 17:
            raise ValueError("unknown diagnostic kind")
        diagnostic_totals[kind] = diagnostic_totals.get(kind, 0) + count
    overflow = reader.unpack("Q")
    if overflow:
        raise ValueError("physics diagnostic overflow prevents complete ledger")
    if reader.offset != len(raw):
        raise ValueError("unparsed trailing exact-snapshot bytes")
    return {
        "tick": tick, "completed": completed, "failed": failed,
        "backend": backend, "chunk_size": chunk_size, "chunks": chunk_count,
        "cells": cells_total, "water": water, "sand": species[2],
        "species": species, "stats": list(stats), "supports": supports,
        "high_a_cells": high_a, "nonzero_empty_cells": nonzero_empty,
        "nonambient_cells": temperatures_nondefault, "pending_events": pending,
        "requested_region": requested, "selected_region": selected,
        "applied_region": applied, "hard_revision": hard_revision,
        "deadline_blocks": deadlines, "diagnostic_entries": diagnostics,
        "diagnostic_totals": diagnostic_totals,
    }


def decode_trace(path: Path, expected_ticks: int | None = None) -> dict:
    """Replay every lossless delta, reject holes/overlaps, reduce actual cells."""
    frames = total_ranges = changed_bytes = 0
    previous = bytearray()
    initial = final = None
    cache = {}
    maxima = {"cells": 0, "high_a_cells": 0, "nonzero_empty_cells": 0,
              "nonambient_cells": 0, "pending_events": 0, "deadline_blocks": 0,
              "diagnostic_entries": 0}
    total_stats = [0] * 15
    water_changed = sand_changed = False
    support_changes = 0
    last_supports = None
    with path.open("rb") as stream:
        if stream.read(8) != b"M3WDEL1\n":
            raise ValueError("not the registered lossless World trace format")
        while True:
            header = stream.read(8)
            if not header:
                break
            if len(header) != 8:
                raise ValueError("truncated delta frame header")
            raw_length, nranges = struct.unpack("<II", header)
            if not 1 <= raw_length <= 512 * 1024 * 1024 or nranges > raw_length:
                raise ValueError("unbounded or invalid delta frame")
            old_length = len(previous)
            if raw_length < old_length:
                del previous[raw_length:]
            else:
                previous.extend(b"\0" * (raw_length - old_length))
            end = 0
            for index in range(nranges):
                range_header = stream.read(8)
                if len(range_header) != 8:
                    raise ValueError("truncated delta range header")
                offset, length = struct.unpack("<II", range_header)
                if length == 0 or offset < end or offset + length > raw_length:
                    raise ValueError("overlapping, empty or out-of-bounds delta range")
                if frames == 0 and (nranges != 1 or index != 0 or offset != 0 or length != raw_length):
                    raise ValueError("initial delta frame is not a complete exact snapshot")
                data = stream.read(length)
                if len(data) != length:
                    raise ValueError("truncated delta payload")
                previous[offset:offset + length] = data
                end = offset + length
                changed_bytes += length
            if frames == 0 and nranges == 0:
                raise ValueError("initial exact snapshot is missing")
            observation = decode_snapshot(bytes(previous), cache)
            if observation["tick"] != frames or observation["completed"] != frames or observation["failed"]:
                raise ValueError("trace has a skipped, duplicated or unsuccessful completed tick")
            if initial is None:
                initial = observation
            else:
                water_changed |= observation["water"] != initial["water"]
                sand_changed |= observation["sand"] != initial["sand"]
            if last_supports is not None and observation["supports"] != last_supports:
                support_changes += 1
            last_supports = observation["supports"]
            for key in maxima:
                maxima[key] = max(maxima[key], observation[key])
            for index, value in enumerate(observation["stats"]):
                total_stats[index] += value
            final = observation
            frames += 1
            total_ranges += nranges
            if expected_ticks is not None and frames > expected_ticks + 1:
                raise ValueError("trace exceeds its registered uninterrupted tick horizon")
    if not frames or (expected_ticks is not None and frames != expected_ticks + 1):
        raise ValueError("trace lacks the complete registered tick horizon")
    return {
        "frames": frames, "ticks": frames - 1, "ranges": total_ranges,
        "changed_bytes": changed_bytes, "initial": initial, "final": final,
        "maxima": maxima, "total_stats": total_stats,
        "water_constant": not water_changed, "sand_constant": not sand_changed,
        "support_change_frames": support_changes,
    }


def _traces(result: dict) -> list[dict]:
    ordinary = result.get("ordinary")
    natural = result.get("natural")
    if not isinstance(ordinary, list) or not isinstance(natural, dict):
        raise ValueError("ordinary/natural trace inventories are missing")
    return ordinary + [natural]


def validate_memory(memory: dict, spec: dict, stride: int, expected_cells: int | None = None) -> list[str]:
    errors = []
    if not isinstance(memory, dict):
        return ["physical memory observation is missing"]
    names = ("resident_cells", "cell_array_used_bytes", "cell_array_capacity_bytes",
             "temperature_capacity_bytes", "activity_capacity_bytes", "tail_capacity_bytes",
             "chunk_descriptor_bytes", "scratch_capacity_bytes", "world_object_bytes",
             "legacy_aggregate_bytes")
    for name in names:
        if not _integer(memory.get(name)):
            errors.append("missing/invalid memory component: " + name)
    if errors:
        return errors
    cells = memory["resident_cells"]
    if expected_cells is not None and cells != expected_cells:
        errors.append("observed memory residency differs from the declared fixture")
    if (memory["cell_array_used_bytes"] != cells * stride
            or memory["cell_array_capacity_bytes"] < memory["cell_array_used_bytes"]):
        errors.append("physical cell array/stride accounting disagrees")
    expected_tail = cells * (spec["logical_bits"] - 64) // 8 if spec["representation"] == "split" else 0
    if memory["tail_capacity_bytes"] != expected_tail:
        errors.append("split tail capacity is omitted, inflated or assigned to an AoS arm")
    if memory["chunk_descriptor_bytes"] == 0 or memory["world_object_bytes"] == 0:
        errors.append("chunk/World descriptor accounting is absent")
    legacy = sum(memory[key] for key in ("cell_array_capacity_bytes", "temperature_capacity_bytes", "activity_capacity_bytes"))
    if memory["legacy_aggregate_bytes"] != legacy:
        errors.append("legacy resident aggregate does not equal its recorded components")
    if memory.get("legacy_aggregate_is_component_sum_not_additive") is not True:
        errors.append("legacy resident aggregate risks double counting")
    if "allocator_overhead_bytes" not in memory or memory["allocator_overhead_bytes"] is not None:
        errors.append("unobserved allocator overhead must remain explicit, not inferred")
    return errors


def validate_result(result: dict, registration: dict, spec: dict) -> list[str]:
    """Validate declared outcomes without relying on the native implementation."""
    errors = []
    if not isinstance(result, dict):
        return ["result is not an object"]
    try:
        if result.get("schema_version") != 1 or result.get("stage") != STAGE or result.get("status") != "passed":
            errors.append("result is not a successful registered S1 outcome")
        if result.get("arm_id") != spec["id"]:
            errors.append("result arm differs from compiled arm")
        for field in ("logical_bits", "epoch_bits", "representation"):
            if result.get(field) != spec[field]:
                errors.append("result differs from registered " + field)
        if not _integer(result.get("assertions"), 1):
            errors.append("no positive executed assertion count")
        scope = result.get("scope", {})
        if (not isinstance(scope, dict) or set(scope) != {"production_changed", "primary_timing", "natural_real_world"}
                or scope.get("production_changed") is not False or scope.get("primary_timing") is not False
                or scope.get("natural_real_world") is not True):
            errors.append("result scope must preserve production and exclude primary timing")
        for field in ("epoch_counter_bytes", "epoch_accessor_bytes"):
            if type(result.get(field)) is not int or result[field] * 8 != spec["epoch_bits"]:
                errors.append("actual typed " + field + " does not match the registered epoch")
        stride, align = result.get("cell_stride"), result.get("cell_alignment")
        rep = spec["representation"]
        expected_stride = spec["logical_bits"] // 8 if rep == "packed" else (16 if rep in ("aligned", "padded") else 8)
        if stride != expected_stride or align != (1 if rep == "packed" else 8):
            errors.append("observed Linux cell stride/alignment differs from registered representation")
        traces = _traces(result)
        names = [trace.get("name") for trace in traces if isinstance(trace, dict)]
        if len(names) != 4 or len(names) != len(set(names)) or set(names) != set(TRACE_SPECS):
            errors.append("missing, duplicate or unexpected ordinary/natural fixtures")
        for trace in traces:
            name = trace.get("name")
            if name not in TRACE_SPECS:
                continue
            ticks, backend, workers = TRACE_SPECS[name]
            if (trace.get("ticks") != ticks or trace.get("frames") != ticks + 1
                    or trace.get("backend") != backend or trace.get("workers") != workers):
                errors.append(name + ": registered clock/backend/worker schedule differs")
            if trace.get("file") != name + ".bin":
                errors.append(name + ": unexpected exact trace path")
            period = 1 << spec["epoch_bits"]
            expected_clears = list(range(period, ticks + 1, period - 1))
            if trace.get("clears") != expected_clears:
                errors.append(name + ": actual World clear chronology is incomplete or wrong")
            observations = trace.get("clear_observations")
            if (not isinstance(observations, list) or len(observations) != len(expected_clears)
                    or [item.get("tick") for item in observations] != expected_clears):
                errors.append(name + ": observed counter transitions are missing or incomplete")
            else:
                for item in observations:
                    if item.get("before") != period - 1 or item.get("after") != 1:
                        errors.append(name + ": clear was not the actual typed maximum-to-one transition")
                    witnessed = name == "natural" and item["tick"] in (65536, 131071)
                    if item.get("sentinel_observed") is not witnessed:
                        errors.append(name + ": natural excluded sentinel clear witness is missing or mislabelled")
                    if witnessed and (not _integer(item.get("sentinel_before"), 1)
                                      or item["sentinel_before"] >= period or item.get("sentinel_after") != 0):
                        errors.append(name + ": excluded sentinel was not observed clearing from a nonzero stamp")
            for field in ("water_initial", "water_final", "sand_initial", "sand_final"):
                if not _integer(trace.get(field), 1):
                    errors.append(name + ": missing/nonpositive closed ledger " + field)
            if (trace.get("water_initial") != trace.get("water_final")
                    or trace.get("sand_initial") != trace.get("sand_final")):
                errors.append(name + ": closed Water/Sand totals changed")
            if not _integer(trace.get("maximum_observed_cells"), 1):
                errors.append(name + ": actual observed residency is missing")
            if name == "natural" and trace.get("maximum_observed_cells", 0) > 256:
                errors.append("natural: fixture exceeds registered 256-cell scope")
            dispatch = trace.get("dispatch", {})
            observed = rep != "source"
            if dispatch.get("observed") is not observed:
                errors.append(name + ": source/candidate observer identity differs")
            if not all(_integer(dispatch.get(key)) for key in ("calls", "dispatched_tasks", "worker_tasks")):
                errors.append(name + ": actual dispatch receipt is missing")
            elif workers == 4 and observed:
                if (dispatch["calls"] < 1 or dispatch["dispatched_tasks"] < 1
                        or dispatch["worker_tasks"] != dispatch["dispatched_tasks"]):
                    errors.append(name + ": configured workers did not observably execute dispatched tasks")
            elif any(dispatch[key] != 0 for key in ("calls", "dispatched_tasks", "worker_tasks")):
                errors.append(name + ": serial/unobserved control has unexpected worker observations")
            errors.extend(name + ": " + error for error in validate_memory(trace.get("memory"), spec, expected_stride))
        forced = result.get("forced")
        if not isinstance(forced, list) or len(forced) != 3 or {f.get("resident_side") for f in forced} != {512, 1024, 2048}:
            errors.append("all three registered large resident forced-boundary fixtures are required")
        else:
            for row in forced:
                side = row["resident_side"]
                if row.get("resident_cells") != side * side or row.get("cleared_cells") != side * side:
                    errors.append(f"forced {side}: actual all-resident clear membership is incomplete")
                if row.get("global_tick_before") != 0 or row.get("global_tick_after") != 2:
                    errors.append(f"forced {side}: global-tick seeding declaration differs")
                if row.get("non_epoch_preserved") is not True or row.get("raw_storage_stress") is not True or row.get("natural_run") is not False:
                    errors.append(f"forced {side}: forced/raw/preservation scope is incorrect")
                errors.extend(f"forced {side}: " + error for error in validate_memory(row.get("memory"), spec, expected_stride, side * side))
        lifecycle = result.get("lifecycle", {})
        expected_checks = {
            "signed_move_swap_temperature_neutral_tail", "partial_full_water_and_replacement_reset",
            "new_water_destination_changed_write_and_noop_payload",
            "admission_clear_replacement_first_update", "general_scan_path_signed_seam",
            "failed_rollover_quarantine_clear_recovery",
            "configured_transport_current_stamp_rejection_and_stale_pickup",
        }
        checks = lifecycle.get("checks", [])
        if not isinstance(checks, list) or len(checks) != len(expected_checks) or set(checks) != expected_checks:
            errors.append("mandatory declared lifecycle fixtures are missing or duplicated")
        if type(lifecycle.get("configured_transport_grain_events")) is not int or lifecycle["configured_transport_grain_events"] != 1:
            errors.append("configured transport did not establish the declared nonvacuous single pickup")
        if (lifecycle.get("neutral_payload_is_synthetic") is not True
                or lifecycle.get("high_a16_is_inert_raw_storage_probe") is not True):
            errors.append("neutral/high-a probes must not masquerade as admitted material semantics")
        if not isinstance(lifecycle.get("coverage_gaps"), list) or not lifecycle["coverage_gaps"]:
            errors.append("known unexecuted adapter/transport scope is not disclosed")
    except (ValueError, KeyError, TypeError, AttributeError) as exc:
        errors.append("malformed World result: " + str(exc))
    return errors


def validate_trace_summary(trace: dict, summary: dict, spec: dict) -> list[str]:
    errors = []
    name = trace["name"]
    ticks, backend, workers = TRACE_SPECS[name]
    if summary["ticks"] != ticks or summary["frames"] != trace.get("frames"):
        errors.append(name + ": declared and decoded horizons disagree")
    if summary["initial"]["tick"] != 0 or summary["final"]["tick"] != ticks:
        errors.append(name + ": exact trace is not an uninterrupted fresh-World run")
    if summary["initial"]["backend"] != (0 if backend == "serial" else 1):
        errors.append(name + ": declared and decoded backend disagree")
    for kind in ("water", "sand"):
        if (summary["initial"][kind] != trace.get(kind + "_initial")
                or summary["final"][kind] != trace.get(kind + "_final")):
            errors.append(name + ": declared and independently reduced " + kind + " totals disagree")
        if not summary[kind + "_constant"]:
            errors.append(name + ": closed " + kind + " ledger changed during the run")
    if summary["maxima"]["cells"] != trace.get("maximum_observed_cells"):
        errors.append(name + ": declared maximum residency differs from replayed exact records")
    if trace.get("memory", {}).get("resident_cells") != summary["final"]["cells"]:
        errors.append(name + ": memory observation differs from final exact residency")
    for field in ("high_a_cells", "nonzero_empty_cells", "nonambient_cells"):
        if summary["maxima"][field] == 0:
            errors.append(name + ": full-state sentinel coverage is vacuous: " + field)
    if summary["total_stats"][1] == 0 or summary["total_stats"][2] == 0:
        errors.append(name + ": no observed material visits or movement")
    if summary["total_stats"][14] != (2 if name == "natural" else 3):
        errors.append(name + ": tick-boundary event ledger differs from the frozen schedule")
    if name == "natural":
        if summary["maxima"]["cells"] != 256:
            errors.append(name + ": natural real-World fixture exceeds or lacks its 256 cells")
        if summary["support_change_frames"] == 0:
            errors.append(name + ": support/re-entry comparison is vacuous")
    elif summary["final"]["diagnostic_totals"].get(3, 0) == 0:
        errors.append(name + ": reactive conversion ledger is vacuous")
    return errors


def verify_directory(root: Path) -> dict:
    """Verify a complete formal run; developer subsets never qualify S1."""
    root = Path(root).resolve()
    errors = []
    comparisons = decoded = 0
    trace_controls = {}
    decoded_cache = {}
    summaries = {}
    historical_root = None
    try:
        report = load_json(root / "run.json")
        if report.get("schema_version") != 1 or report.get("stage") != STAGE:
            errors.append("invalid collector schema or stage")
        if report.get("scope") != "isolated-native-World-correctness":
            errors.append("collector scope is not isolated native World correctness")
        if report.get("status") != "passed" or report.get("errors") != []:
            errors.append("collector did not complete successfully")
        if report.get("developer_attempt") is not False:
            errors.append("developer subset/attempt cannot qualify formal S1")
        if report.get("performance_qualification") is not False:
            errors.append("correctness evidence cannot claim performance qualification")
        if not isinstance(report.get("source_head"), str) or not GIT_SHA.fullmatch(report["source_head"]):
            errors.append("source commit identity is missing")
        if not isinstance(report.get("source_status"), list):
            errors.append("source delta identity is missing")
        files = report.get("files")
        if not isinstance(files, dict) or not files:
            raise ValueError("empty artifact ledger")
        for name, entry in files.items():
            path = checked_path(root, name)
            if (not isinstance(entry, dict) or not _integer(entry.get("bytes"))
                    or not isinstance(entry.get("sha256"), str) or not SHA256.fullmatch(entry["sha256"])):
                raise ValueError("malformed artifact ledger entry: " + name)
            if path.stat().st_size != entry["bytes"] or sha256_file(path) != entry["sha256"]:
                errors.append("artifact identity mismatch: " + name)
        registration_name = report.get("registration_file")
        if registration_name != "source/" + EXPERIMENT + "world_registration.json" or registration_name not in files:
            raise ValueError("frozen hashed registration is missing")
        registration = load_json(checked_path(root, registration_name))
        if (registration.get("schema_version") != 1 or registration.get("stage") != STAGE
                or registration.get("issue") != 204):
            errors.append("unexpected experiment registration")
        if report.get("baseline_commit") != registration.get("execution_baseline"):
            errors.append("baseline/registration disagreement")
        limits = registration["execution"]
        if limits.get("primary_timing_admitted") is not False:
            errors.append("this readback cannot admit primary timing")
        if report.get("sanitizer_environment") != limits.get("sanitizer_environment"):
            errors.append("sanitizer environment differs from registration")
        if (report.get("sanitizer_environment", {}).get("ASAN_OPTIONS") != "detect_leaks=1:halt_on_error=1"
                or report.get("sanitizer_environment", {}).get("UBSAN_OPTIONS") != "halt_on_error=1:print_stacktrace=1"):
            errors.append("required sanitizers or leak detection are not enabled")
        elapsed = report.get("elapsed_seconds_not_benchmark")
        if type(elapsed) not in (int, float) or not 0 <= elapsed <= limits["total_stage_budget_seconds"]:
            errors.append("registered collection wall budget is missing or exceeded")
        if report.get("process_counts") != {"compile": 40, "test": 34}:
            errors.append("complete formal S1 requires 40 compilation and 34 execution processes")
        source_hashes = report.get("source_sha256")
        if not isinstance(source_hashes, dict) or not source_hashes:
            raise ValueError("source snapshot identity map is missing")
        required_inputs = set(registration["baseline_control_sha256"])
        required_inputs |= {EXPERIMENT + name for name in (
            "world_registration.json", "world_adapter.hpp", "world_overlay.py", "test_world.cpp",
            "world_run.py", "world_verify.py", "carriers.hpp")}
        required_inputs.add("third_party/native-toolchain.lock.json")
        if not required_inputs.issubset(source_hashes):
            errors.append("required native or apparatus source snapshots are missing")
        for name, digest in source_hashes.items():
            snapshot_name = "source/" + name
            if snapshot_name not in files or files[snapshot_name].get("sha256") != digest:
                errors.append("source snapshot not retained exactly: " + name)
        for name, expected in registration["baseline_control_sha256"].items():
            if (report.get("baseline_control_sha256", {}).get(name) != expected
                    or source_hashes.get(name) != expected):
                errors.append("production control differs from frozen baseline: " + name)
        for name in ("compiler_version_receipt", "linker_version_receipt"):
            errors.extend(verify_receipt(root, report.get(name), files, name, 10))
        if (not isinstance(report.get("compiler_binary_sha256"), str)
                or not SHA256.fullmatch(report["compiler_binary_sha256"])):
            errors.append("compiler executable identity is missing")
        if "13.3.0" not in report.get("compiler_version", ""):
            errors.append("compiler does not match the registered GNU13.3 pin")
        compiler_out = report.get("compiler_version_receipt", {}).get("stdout")
        if compiler_out in files:
            actual_version = checked_path(root, compiler_out).read_text().splitlines()
            if not actual_version or actual_version[0] != report.get("compiler_version"):
                errors.append("compiler metadata disagrees with retained identity stdout")
        linker_out = report.get("linker_version_receipt", {}).get("stdout")
        if linker_out in files and "2.42" not in checked_path(root, linker_out).read_text():
            errors.append("linker does not match the registered binutils2.42 pin")
        specs = registration["arms"]
        if not isinstance(specs, list) or len(specs) != 17 or {s["id"] for s in specs} != EXPECTED_ARMS:
            raise ValueError("registration does not include every mandatory S1 arm")
        expected = {spec["id"]: spec for spec in specs}
        modes = report.get("configurations")
        if not isinstance(modes, list) or [m.get("name") for m in modes] != ["normal", "sanitized"]:
            raise ValueError("normal and sanitized configurations were not both executed exactly once")
        for mode in modes:
            mode_name = mode["name"]
            flags = limits["normal_flags" if mode_name == "normal" else "sanitizer_flags"]
            common = mode.get("common_compiles")
            if (not isinstance(common, list) or len(common) != 3
                    or {row.get("source") for row in common} != COMMON_SOURCES):
                raise ValueError(mode_name + ": common compilation inventory is incomplete")
            for row in common:
                errors.extend(verify_receipt(root, row.get("compile"), files,
                                             mode_name + " common " + row.get("source", "?"),
                                             limits["compile_timeout_seconds"], flags))
                if row.get("source") not in files or row.get("object") not in files:
                    errors.append(mode_name + ": common source/object identity missing")
                command = row.get("compile", {}).get("command", [])
                object_name = row.get("object")
                if (len(command) < 2 or command[-2] != "-o" or not isinstance(object_name, str)
                        or not command[-1].endswith("/" + object_name)):
                    errors.append(mode_name + ": common compilation output does not identify its retained object")
                    continue
                original_root = command[-1][:-len(object_name)].rstrip("/")
                if historical_root is None:
                    historical_root = original_root
                if historical_root != original_root:
                    errors.append(mode_name + ": compilation receipts identify different evidence roots")
                expected_command = [report["compiler"], *flags, "-I" + original_root + "/source/native/include",
                                    "-c", original_root + "/" + row["source"], "-o",
                                    original_root + "/" + object_name]
                if command != expected_command:
                    errors.append(mode_name + ": common compile command differs from frozen source/flags/output")
                if row["compile"].get("cwd") != original_root + "/source":
                    errors.append(mode_name + ": common compile used an unexpected working directory")
            arms = mode.get("arms")
            if not isinstance(arms, list):
                raise ValueError(mode_name + ": arm execution inventory is missing")
            ids = [row.get("id") for row in arms if isinstance(row, dict)]
            if len(ids) != 17 or len(ids) != len(set(ids)) or set(ids) != EXPECTED_ARMS:
                raise ValueError(mode_name + ": missing, duplicate or unexpected registered arms")
            for row in arms:
                identifier = row["id"]
                label = mode_name + "/" + identifier
                spec = expected[identifier]
                errors.extend(verify_overlay(root, row.get("overlay_manifest"), spec, registration, files))
                for phase in ("compile", "execute"):
                    errors.extend(verify_receipt(
                        root, row.get(phase), files, label + " " + phase,
                        limits["compile_timeout_seconds" if phase == "compile" else "test_timeout_seconds"],
                        flags if phase == "compile" else None))
                binary = row.get("binary")
                if binary not in files or files[binary]["bytes"] == 0:
                    errors.append(label + ": compiled binary identity missing")
                execute = row.get("execute", {})
                command = execute.get("command", [])
                if (len(command) != 3 or command[1] != "--output" or not binary
                        or not command[0].endswith("/" + binary)):
                    errors.append(label + ": execution command does not identify the retained binary")
                result_name = row.get("result_file")
                if result_name not in files:
                    errors.append(label + ": no hashed result JSON")
                    continue
                manifest = load_json(checked_path(root, row["overlay_manifest"]))
                overlay_prefix = historical_root + "/" + Path(row["overlay_manifest"]).parent.as_posix()
                if (manifest.get("world_source") != overlay_prefix + "/native/src/world.cpp"
                        or manifest.get("include_dir") != overlay_prefix + "/native/include"
                        or manifest.get("experiment_dir") != overlay_prefix + "/" + EXPERIMENT.rstrip("/")):
                    errors.append(label + ": compilation inputs are not the retained source overlay")
                expected_command = [
                    report["compiler"], *flags, *manifest["compile_definitions"],
                    "-I" + manifest["include_dir"], "-I" + manifest["experiment_dir"],
                    manifest["experiment_dir"] + "/test_world.cpp",
                    *(historical_root + "/" + common_row["object"] for common_row in common),
                    "-o", historical_root + "/" + binary,
                ]
                if row.get("compile", {}).get("command") != expected_command:
                    errors.append(label + ": binary compilation is not bound to its declared arm and captured inputs")
                expected_execute = [historical_root + "/" + binary, "--output",
                                    historical_root + "/" + Path(result_name).parent.as_posix()]
                if execute.get("command") != expected_execute:
                    errors.append(label + ": execution/result directory does not match retained binary identity")
                if any(row.get(phase, {}).get("cwd") != historical_root + "/source" for phase in ("compile", "execute")):
                    errors.append(label + ": compile/test working directory differs from captured inputs")
                result_path = checked_path(root, result_name)
                result = load_json(result_path)
                errors.extend(label + ": " + error for error in validate_result(result, registration, spec))
                if execute.get("stdout") in files:
                    stdout_path = checked_path(root, execute["stdout"])
                    if not exact_bytes_equal(stdout_path, result_path):
                        errors.append(label + ": result bytes differ from original process stdout")
                if execute.get("stderr") in files and checked_path(root, execute["stderr"]).read_bytes().strip():
                    errors.append(label + ": nonempty test/sanitizer diagnostics")
                traces = _traces(result)
                for trace in traces:
                    trace_name = trace.get("name")
                    if trace_name not in TRACE_SPECS:
                        continue
                    trace_relative = (Path(result_name).parent / trace["file"]).as_posix()
                    trace_path = checked_path(root, trace_relative)
                    if trace_relative not in files:
                        errors.append(label + ": unhashed trace " + trace_name)
                        continue
                    ticks, backend, workers = TRACE_SPECS[trace_name]
                    if trace_name in trace_controls:
                        if not exact_bytes_equal(trace_controls[trace_name], trace_path):
                            errors.append(label + ": exact semantic/work/ledger trace differs: " + trace_name)
                        else:
                            comparisons += 1
                    else:
                        trace_controls[trace_name] = trace_path
                    # Equal digests are only a decode cache key after file hashes
                    # and literal equality to the canonical trace were checked.
                    cache_key = (trace_name, files[trace_relative]["sha256"])
                    if cache_key not in decoded_cache:
                        decoded_cache[cache_key] = decode_trace(trace_path, ticks)
                        decoded += 1
                    summary = decoded_cache[cache_key]
                    errors.extend(label + ": " + error for error in validate_trace_summary(
                        trace, summary, spec))
                    summaries.setdefault(trace_name, summary)
    except (OSError, UnicodeError, ValueError, KeyError, TypeError, AttributeError, struct.error) as exc:
        errors.append("unreadable or malformed evidence: " + str(exc))
    return {
        "schema_version": 1, "stage": STAGE, "status": "failed" if errors else "passed",
        "scope": "isolated-native-World-evidence-readback", "performance_qualification": False,
        "literal_trace_comparisons": comparisons, "independently_decoded_traces": decoded,
        "trace_summaries": summaries, "errors": errors,
        "limitations": [
            "Hashes and command receipts establish retained identity, not trusted publication or authenticity.",
            "Only the registered native fixtures are qualified; no production migration, speed ranking or continuation follows.",
            "Windows, Wasm and Godot adapter execution remain unqualified by this Linux apparatus.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    result = verify_directory(parser.parse_args().directory)
    print(json.dumps(result, indent=2))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    sys.exit(main())
