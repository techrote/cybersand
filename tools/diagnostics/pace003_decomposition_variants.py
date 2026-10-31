#!/usr/bin/env python3
"""Source-pinned, NONQUALIFYING material/compositor decomposition inputs.

These are compiler experiments, not Godot shader assets. A material program has
one uniform snapshot selector (current, previous, or Empty) and one disjoint ID
domain. Its assigned-domain formula bytes are retained. A compositor consumes
three proposed float32 surfaces and retains the original temporal/ambient/actor
ordering. No render-target, texture-LOD, derivative or pixel parity is asserted.
"""
from __future__ import annotations

import base64
import hashlib
import re

SOURCE_BYTES = 175942
SOURCE_SHA256 = "192c1a086d5124ce4b22cb172bd90876212779e4d6c67447f9278493ba3ff03c"
CASES = (
    "original-control", "compositor", "ordinary", "building",
    "building-81-93", "building-94-106", "building-107-119", "building-120-131",
)
BUILDING_RANGES = {
    "building": (81, 131),
    "building-81-93": (81, 93),
    "building-94-106": (94, 106),
    "building-107-119": (107, 119),
    "building-120-131": (120, 131),
}
FAMILIES = {
    "coarse": ("ordinary", "building", "compositor"),
    "fine-building": (
        "ordinary", "building-81-93", "building-94-106",
        "building-107-119", "building-120-131", "compositor",
    ),
}
MATERIAL_FUNCTION = b"f_m_material_colour_int"
BUILDING_FUNCTION = b"f_m_apply_building_finish_float4_int__m_BuildGeometry"
FUNCTION_PATTERN = re.compile(
    rb"(?m)^(?:float[234]?|int|bool|_m_BuildGeometry) (f_m_[A-Za-z0-9_]+)\([^\n]*\)\n\{"
)
CALL_PATTERN = re.compile(rb"\b(f_m_[A-Za-z0-9_]+)\s*\(")
DISPATCH = b"if (((_m_material_id >= 81) && (_m_material_id <= 131)))\n"
MAIN_MATERIAL = (
    b"float4 _m_colour4088 = f_m_material_colour_int(_m_material_id4086, "
    b"_m_condition4084, _m_world_pixel4077, false);"
)
SNAPSHOT_ABI = b"""
// NONQUALIFYING stage ABI: 0=current, 1=previous, 2=Empty outside-view.
cbuffer PaceDecomposition : register(b4)
{
    uint pace_snapshot_mode;
};
"""
COMPOSITOR_ABI = b"""
// NONQUALIFYING stage ABI: unblended linear RGBA32F at framebuffer resolution.
// Stages must share the original viewport origin, extent and raster sample grid.
// SV_Position addresses the output pixel; logical view cells can contain subcells.
Texture2D<float4> pace_current_colour : register(t8);
Texture2D<float4> pace_previous_colour : register(t9);
Texture2D<float4> pace_air_colour : register(t10);
"""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_source(source: bytes) -> None:
    require(type(source) is bytes and len(source) == SOURCE_BYTES
            and sha256(source) == SOURCE_SHA256, "Captured HLSL identity mismatch")


def closing_brace(source: bytes, start: int) -> int:
    """Find a pinned generated-HLSL brace; no general shader parser is claimed."""
    require(source[start:start + 1] == b"{", "Expected opening brace")
    depth = 0
    for index in range(start, len(source)):
        if source[index:index + 1] == b"{":
            depth += 1
        elif source[index:index + 1] == b"}":
            depth -= 1
            if depth == 0:
                return index + 1
    raise ValueError("Unclosed pinned HLSL block")


def functions(source: bytes) -> dict[bytes, tuple[int, int, int]]:
    found = {}
    for match in FUNCTION_PATTERN.finditer(source):
        name = match.group(1)
        require(name not in found, "Duplicate generated helper definition")
        brace = match.end() - 1
        end = closing_brace(source, brace)
        found[name] = (match.start(), brace, end)
    return found


def patch(source: bytes, start: int, end: int, replacement: bytes, reason: str) -> dict:
    require(0 <= start <= end <= len(source), "Patch range outside original input")
    before = source[start:end]
    return {"start": start, "end": end, "reason": reason,
            "before_sha256": sha256(before), "after_sha256": sha256(replacement),
            "before_b64": base64.b64encode(before).decode("ascii"),
            "after_b64": base64.b64encode(replacement).decode("ascii")}


def apply_patches(source: bytes, patches: list[dict]) -> bytes:
    """Apply an ordered, nonoverlapping ledger, checking every original byte."""
    result, cursor = [], 0
    for item in patches:
        start, end = item["start"], item["end"]
        require(type(start) is int and type(end) is int
                and cursor <= start <= end <= len(source), "Overlapping or unordered patch")
        before = base64.b64decode(item["before_b64"], validate=True)
        after = base64.b64decode(item["after_b64"], validate=True)
        require(before == source[start:end] and sha256(before) == item["before_sha256"]
                and sha256(after) == item["after_sha256"], "Patch bytes or digest mismatch")
        result.extend((source[cursor:start], after))
        cursor = end
    result.append(source[cursor:])
    return b"".join(result)


def restore_original(generated: bytes, patches: list[dict]) -> bytes:
    """Restore deleted/replaced input bytes, refusing changed output or ledger."""
    result, cursor, shift, previous_end = [], 0, 0, 0
    for item in patches:
        start, end = item["start"], item["end"]
        require(type(start) is int and type(end) is int and previous_end <= start <= end,
                "Overlapping or unordered inverse patch")
        before = base64.b64decode(item["before_b64"], validate=True)
        after = base64.b64decode(item["after_b64"], validate=True)
        require(len(before) == end - start and sha256(before) == item["before_sha256"]
                and sha256(after) == item["after_sha256"], "Inverse patch bytes or digest mismatch")
        generated_start = start + shift
        require(cursor <= generated_start <= len(generated)
                and generated[generated_start:generated_start + len(after)] == after,
                "Generated bytes differ from inverse patch")
        result.extend((generated[cursor:generated_start], before))
        cursor = generated_start + len(after)
        shift += len(after) - len(before)
        previous_end = end
    result.append(generated[cursor:])
    restored = b"".join(result)
    validate_source(restored)
    return restored


def material_ids(case: str) -> tuple[int, ...]:
    require(case in CASES, "Unregistered decomposition case")
    if case == "ordinary":
        # Preserve the original nonbuilding fallback for encoded unknown IDs.
        return tuple(range(81)) + tuple(range(132, 256))
    if case in BUILDING_RANGES:
        low, high = BUILDING_RANGES[case]
        return tuple(range(low, high + 1))
    return ()


def validate_plans() -> None:
    for name, cases in FAMILIES.items():
        material_cases = [case for case in cases if case != "compositor"]
        ids = [value for case in material_cases for value in material_ids(case)]
        require(sorted(ids) == list(range(256)) and len(ids) == len(set(ids)),
                "Plan is not a disjoint complete byte-ID partition: " + name)
        require(cases.count("compositor") == 1, "Plan has no unique compositor")


def _prune_unreachable(source: bytes, patches: list[dict]) -> list[dict]:
    interim = apply_patches(source, sorted(patches, key=lambda item: item["start"]))
    original_functions = functions(source)
    remaining = functions(interim)
    main = interim[interim.index(b"PS_OUTPUT main("):]
    reachable = set(CALL_PATTERN.findall(main))
    pending = list(reachable)
    while pending:
        name = pending.pop()
        require(name in remaining, "Reachable material helper is missing")
        start, brace, end = remaining[name]
        for called in set(CALL_PATTERN.findall(interim[brace + 1:end - 1])) - reachable:
            require(called in remaining, "Referenced material helper is missing")
            reachable.add(called)
            pending.append(called)
    for name in sorted(set(original_functions) - reachable):
        start, _, end = original_functions[name]
        # Keep the newline to retain separation around neighbouring functions.
        patches.append(patch(source, start, end, b"", "Unreachable helper: " + name.decode()))
    return patches


def _material_patches(source: bytes, case: str) -> list[dict]:
    found = functions(source)
    _, _, function_end = found[MATERIAL_FUNCTION]
    dispatch_start = source.index(DISPATCH, found[MATERIAL_FUNCTION][0], function_end)
    building_open = dispatch_start + len(DISPATCH)
    building_end = closing_brace(source, building_open)
    require(source[building_end:building_end + 6] == b"\nelse\n", "Material dispatch shape changed")
    ordinary_open = building_end + 6
    ordinary_end = closing_brace(source, ordinary_open)
    selected = source[ordinary_open:ordinary_end] if case == "ordinary" else source[building_open:building_end]
    patches = [patch(source, dispatch_start, ordinary_end, selected,
                     "Select original ordinary/building dispatch body for assigned ID domain")]

    if case.startswith("building-"):
        low, high = BUILDING_RANGES[case]
        _, brace, end = found[BUILDING_FUNCTION]
        position, seen = brace + 1, set()
        while position < end - 1:
            candidate = source.find(b"if (", position, end - 1)
            if candidate < 0:
                break
            condition_end = source.index(b"\n{", candidate, end - 1)
            condition = source[candidate:condition_end]
            ids = {int(value) for value in re.findall(rb"_m_id == ([0-9]+)", condition)}
            require(bool(ids) and not re.sub(rb"(?:if|_m_id|[0-9]+|[()=|\s])", b"", condition),
                    "Unexpected building top-level condition")
            require(not (seen & ids), "Duplicate building case ID")
            seen.update(ids)
            block_end = closing_brace(source, condition_end + 1)
            if not any(low <= value <= high for value in ids):
                patches.append(patch(source, candidate, block_end, b"",
                                     "Remove building branch outside assigned domain: " + ",".join(map(str, sorted(ids)))))
            position = block_end
        require(seen == set(range(81, 132)), "Building source does not cover the registered catalogue")

    insertion = source.index(b"// Uniform Blocks\n")
    patches.append(patch(source, insertion, insertion, SNAPSHOT_ABI, "Add proposed stage selector at b4"))
    main_start = source.index(b"PS_OUTPUT main(")
    main_brace = source.index(b"{", main_start)
    main_end = closing_brace(source, main_brace)
    tail_start = source.index(MAIN_MATERIAL, main_start, main_end)
    prefix = source[main_brace:tail_start]
    depth = prefix.count(b"{") - prefix.count(b"}")
    require(depth == 3, "Original main material-stage boundary changed")
    if case == "ordinary":
        refusal = "(pace_material_id >= 81 && pace_material_id <= 131)"
    else:
        low, high = BUILDING_RANGES[case]
        refusal = f"(pace_material_id < {low} || pace_material_id > {high})"
    tail = f"""// NONQUALIFYING material stage: original assigned-domain formula, no compositing.
if (pace_snapshot_mode > 2) discard;
bool pace_previous = (pace_snapshot_mode == 1);
int pace_material_id = _m_material_id4086;
float pace_condition = _m_condition4084;
if (pace_previous)
{{
    pace_material_id = _m_previous_material_id4087;
    pace_condition = _m_previous_condition4085;
}}
if (pace_snapshot_mode == 2)
{{
    pace_material_id = 0;
    pace_condition = 0.0;
}}
if {refusal} discard;
out_frag_color = f_m_material_colour_int(pace_material_id, pace_condition, _m_world_pixel4077, pace_previous);
return generateOutput();
""".encode() + b"}\n" * depth
    patches.append(patch(source, tail_start, main_end, tail,
                         "Replace compositor tail with one selected-snapshot material evaluation"))
    return _prune_unreachable(source, patches)


def _compositor_patches(source: bytes) -> list[dict]:
    insertion = source.index(b"// Uniform Blocks\n")
    patches = [patch(source, insertion, insertion, COMPOSITOR_ABI,
                     "Add proposed current/previous/Empty RGBA32F surfaces at t8/t9/t10")]
    calls = (
        (b"f_m_material_colour_int(_m_material_id4086, _m_condition4084, _m_world_pixel4077, false)", b"pace_current_colour"),
        (b"f_m_material_colour_int(_m_previous_material_id4087, _m_previous_condition4085, _m_world_pixel4077, true)", b"pace_previous_colour"),
        (b"f_m_material_colour_int(0, 0.0, _m_world_pixel4077, false)", b"pace_air_colour"),
    )
    for original, texture in calls:
        require(source.count(original) == 1, "Material/compositor call site is not unique")
        start = source.index(original)
        replacement = texture + b".Load(int3(int2(input.dx_Position.xy), 0))"
        patches.append(patch(source, start, start + len(original), replacement,
                             "Replace one original material result by its framebuffer-pixel surface lookup"))
    return _prune_unreachable(source, patches)


def generate(source: bytes, case: str) -> tuple[bytes, dict]:
    validate_source(source)
    require(case in CASES, "Unregistered decomposition case")
    validate_plans()
    if case == "original-control":
        patches = []
    elif case == "compositor":
        patches = _compositor_patches(source)
    else:
        patches = _material_patches(source, case)
    patches.sort(key=lambda item: item["start"])
    generated = apply_patches(source, patches)
    require(restore_original(generated, patches) == source, "Original HLSL round trip failed")
    receipt = {
        "schema": "pace003-decomposition-input-v1", "case": case,
        "scope": "NONQUALIFYING compiler-only source decomposition",
        "original_bytes": len(source), "original_sha256": sha256(source),
        "generated_bytes": len(generated), "generated_sha256": sha256(generated),
        "patches": patches, "original_round_trip_verified": True,
        "material_ids": list(material_ids(case)),
        "partition_proof": {
            "encoded_byte_ids": 256,
            "family_cases": {name: list(cases) for name, cases in FAMILIES.items()},
            "each_id_owned_once_per_family": True,
            "each_snapshot_shaded_independently": True,
            "outside_view_uses_independent_Empty_surface": True,
            "source_only_not_rendered_proof": True,
        },
        "snapshot_modes": ["current", "previous", "Empty outside-view"] if material_ids(case) else [],
        "source_formula_preservation": "Assigned-domain formula bytes retained; unreachable helpers and out-of-domain building branches removed",
        "graphical_equivalence_proven": False,
        "limitations": ["No Godot/ANGLE regeneration or device execution",
                        "New b4 or t8/t9/t10 interfaces are proposed and unimplemented",
                        "RGBA32F framebuffer-resolution storage, identical viewport origin/extent/sample grid, blend state, implicit LOD and derivatives require graphical qualification",
                        "All current/previous/Empty surfaces must match immutable original inputs and presentation time"],
    }
    return generated, receipt


def verify_generated(source: bytes, generated: bytes, receipt: dict) -> None:
    expected, expected_receipt = generate(source, receipt.get("case", ""))
    require(generated == expected and receipt == expected_receipt,
            "Generated HLSL or transformation receipt differs from deterministic recipe")
