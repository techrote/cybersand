#!/usr/bin/env python3
"""Bounded NONQUALIFYING Windows compiler experiments from frozen shader bytes.

Exclusions deliberately change pixels. Control-flow candidates require separate
source review, same-backend pixel parity and actual Main qualification before
production adoption. This module never modifies the production shader file.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

FROZEN_HOIST_SHA256 = "426c2b8a829d6ca216659b73f7663ba6c7f6dddd300726b81ed1eec85bbd3e1d"


def replace_once(text: str, before: str, after: str) -> str:
    if text.count(before) != 1:
        raise RuntimeError("Frozen experimental source anchor does not occur exactly once")
    return text.replace(before, after, 1)


def unified_dispatch(source: str) -> str:
    start = source.index("\t// Each structured branch either replaces the ordinary finish")
    end = source.index("\n\tif (material_id == 68 || material_id == 69) { // pipes", start)
    source = source[:start] + source[end:]
    helper = """// NONQUALIFYING candidate: reproduce the original structured dispatch guard.
bool structured_ordinary_flair(int material_id, vec4 extent) {
	bool ordinary = material_id != 5 && material_id != 7
		&& material_id != 46 && material_id != 55 && material_id != 64
		&& material_id != 68 && material_id != 69 && material_id != 73
		&& material_id != 74 && material_id != 75 && material_id != 76
		&& material_id != 80;
	if (!ordinary || material_id != 50) return ordinary;
	// The original orientation rule, including the capped long-run probes.
	float span_x = extent.z + extent.w + 1.0;
	float span_y = extent.x + extent.y + 1.0;
	float long_x = (extent.z >= 8.0 || extent.w >= 8.0) ? 99.0 : span_x;
	float long_y = (extent.x >= 8.0 || extent.y >= 8.0) ? 99.0 : span_y;
	bool large = long_x > 50.0 && long_y > 50.0;
	bool horizontal = large ? material_id != 64 : long_x >= long_y;
	float across_span = horizontal ? span_y : span_x;
	return across_span > 3.5;
}

"""
    source = replace_once(source, "vec4 apply_structured_fill(\n", helper + "vec4 apply_structured_fill(\n")
    before = """	if (material_id >= 81 && material_id <= LAST_MATERIAL_ID) {
		// Keep the catalogue at a single dispatch site. Putting it inside the
		// shared flair helper duplicates this large branch at every ordinary
		// structured finish call when GPU drivers inline shader functions.
		BuildGeometry geometry = default_build_geometry(world_pixel);
		if (uses_structured_fill(material_id)) {
			geometry = probed_build_geometry(world_pixel, neighbours,
				region_extent(world_pixel, material_id, neighbours, previous_snapshot));
		}
		colour = apply_building_finish(colour, material_id, world_pixel, geometry, condition);
	} else if (uses_structured_fill(material_id)) {
		vec4 extent = region_extent(world_pixel, material_id, neighbours, previous_snapshot);
		colour = apply_structured_fill(
			colour, material_id, flair, world_pixel, neighbours, extent, condition);
	} else {
		colour = apply_material_flair(colour, material_id, flair, world_pixel, condition);
	}
"""
    after = """	// NONQUALIFYING candidate: one extent gather and one ordinary finish site.
	bool structured = uses_structured_fill(material_id);
	bool building = material_id >= 81 && material_id <= LAST_MATERIAL_ID;
	vec4 extent = vec4(0.0);
	if (structured) {
		extent = region_extent(world_pixel, material_id, neighbours, previous_snapshot);
	}
	if (!building && (!structured || structured_ordinary_flair(material_id, extent))) {
		colour = apply_material_flair(colour, material_id, flair, world_pixel, condition);
	}
	if (building) {
		BuildGeometry geometry = default_build_geometry(world_pixel);
		if (structured) {
			geometry = probed_build_geometry(world_pixel, neighbours, extent);
		}
		colour = apply_building_finish(colour, material_id, world_pixel, geometry, condition);
	} else if (structured) {
		colour = apply_structured_fill(
			colour, material_id, flair, world_pixel, neighbours, extent, condition);
	}
"""
    return replace_once(source, before, after)


def folded_view(source: str) -> str:
    source = replace_once(source,
        "\tvec4 colour = material_colour(material_id, condition, world_pixel, false);",
        "\tvec4 colour = material_colour(inside_view ? material_id : 0,\n"
        "\t\tinside_view ? condition : 0.0, world_pixel, false);")
    source = replace_once(source, "\t\tprevious_material_id != material_id\n",
                          "\t\tinside_view && previous_material_id != material_id\n")
    source = replace_once(source, "\tif (inside_player) {\n", "\tif (inside_view && inside_player) {\n")
    source = replace_once(source, "\tif (inside_test_body) {\n", "\tif (inside_view && inside_test_body) {\n")
    return replace_once(source, "\tif (!inside_view) {\n\t\tcolour = material_colour(0, 0.0, world_pixel, false);\n\t}\n", "")


def bounded_temporal_loop(source: str) -> str:
    start = source.index("\tvec4 colour = material_colour(inside_view ? material_id : 0,")
    end = source.index("\tif (material_id == 0 && inside_view)", start)
    return source[:start] + """	// NONQUALIFYING candidate: the same current/previous evaluations and mix,
	// with a per-fragment bound of exactly one or two iterations.
	bool blend_previous = inside_view && previous_material_id != material_id
		&& (is_temporally_smoothed_material(material_id)
			|| is_temporally_smoothed_material(previous_material_id));
	int palette_passes = blend_previous ? 2 : 1;
	vec4 colour = vec4(0.0);
	for (int palette_pass = 0; palette_pass < palette_passes; palette_pass++) {
		bool previous_pass = palette_pass == 1;
		int shade_id = previous_pass ? previous_material_id : (inside_view ? material_id : 0);
		float shade_condition = previous_pass ? previous_condition : (inside_view ? condition : 0.0);
		vec4 shade = material_colour(shade_id, shade_condition, world_pixel, previous_pass);
		if (previous_pass) colour = mix(shade, colour, snapshot_blend);
		else colour = shade;
	}
""" + source[end:]


def _block_end(text: str, start: int) -> int:
    depth = 0
    index = start
    while index < len(text):
        if text.startswith("//", index):
            index = text.index("\n", index)
        elif text.startswith("/*", index):
            index = text.index("*/", index) + 2
            continue
        elif text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    raise RuntimeError("Unclosed frozen block")


def grouped_dispatch(text: str, function: str, selector: str, expected_values: set[int]) -> tuple[str, dict]:
    marker = "vec4 " + function + "("
    if text.count(marker) != 1:
        raise RuntimeError("Function anchor mismatch")
    start = text.index(marker)
    end = text.index("\n}", start) + 2
    body = text[start:end]
    pattern = re.compile(r"^\tif \((" + selector + r" == \d+(?: \|\| " + selector + r" == \d+)*)\) \{", re.M)
    matches = list(pattern.finditer(body))
    values = [int(value) for match in matches for value in re.findall(r"== (\d+)", match.group(1))]
    if len(values) != len(set(values)) or set(values) != expected_values:
        raise RuntimeError("Case coverage mismatch")
    groups: dict[int, list[str]] = {}
    receipts = []
    previous_end = matches[0].start()
    for match in matches:
        ids = [int(value) for value in re.findall(r"== (\d+)", match.group(1))]
        buckets = {value // 16 for value in ids}
        if len(buckets) != 1:
            raise RuntimeError("Original combined branch crosses a dispatch boundary")
        finish = _block_end(body, match.end() - 1)
        gap = body[previous_end:match.start()]
        # Between the exclusive branches only whitespace and comments may move.
        if re.sub(r"//[^\n]*|/\*.*?\*/|\s+", "", gap, flags=re.S):
            raise RuntimeError("Unexpected statement between dispatch branches")
        original = body[match.start():finish]
        bucket = next(iter(buckets))
        groups.setdefault(bucket, []).append(gap + original)
        receipts.append({"values": ids, "group": bucket, "original_branch_sha256": hashlib.sha256(original.encode()).hexdigest()})
        previous_end = finish
    tail = body[previous_end:]
    if tail.strip() != "return colour;\n}":
        raise RuntimeError("Fallback differs")
    result = body[:matches[0].start()]
    result += "\t// NONQUALIFYING: bounded exclusive ranges; every branch body is unchanged.\n"
    ordered = sorted(groups)
    for index, bucket in enumerate(ordered):
        if index == 0:
            guard = f"\tif ({selector} < {(bucket + 1) * 16}) {{\n"
        elif index == len(ordered) - 1:
            guard = "\telse {\n"
        else:
            guard = f"\telse if ({selector} < {(bucket + 1) * 16}) {{\n"
        result += guard + "\n".join(groups[bucket]) + "\n\t}\n"
    result += tail
    for match in matches:
        original = body[match.start():_block_end(body, match.end() - 1)]
        if result.count(original) != 1:
            raise RuntimeError("Original branch bytes lost or duplicated")
    return text[:start] + result + text[end:], {"function": function, "selector": selector, "groups": ordered, "branches": receipts}



def variants(data: bytes) -> list[dict]:
    if hashlib.sha256(data).hexdigest() != FROZEN_HOIST_SHA256:
        raise RuntimeError("Windows experiment requires the exact retained hoist shader")
    original = data.decode("utf-8")
    no_building = replace_once(original,
        "\t\tcolour = apply_building_finish(colour, material_id, world_pixel, geometry, condition);",
        "\t\t// NONQUALIFYING EXCLUSION: building finish deliberately omitted.")
    no_flair = original
    for site in ("pixel", "world_pixel"):
        no_flair = replace_once(no_flair,
            f"\t\tcolour = apply_material_flair(colour, material_id, flair, {site}, condition);",
            "\t\t// NONQUALIFYING EXCLUSION: ordinary flair deliberately omitted.")
    unified = folded_view(unified_dispatch(original))
    cases = [
        ("hoist-control-cold", "unchanged retained control", original),
        ("exclude-building-cold", "NONQUALIFYING visual exclusion", no_building),
        ("exclude-ordinary-flair-cold", "NONQUALIFYING visual exclusion", no_flair),
        ("unified-flair-view-cold", "unqualified control-flow candidate", unified),
        ("bounded-temporal-loop-cold", "unqualified control-flow candidate", bounded_temporal_loop(unified)),
    ]
    return [{"name": name, "scope": scope, "qualification_passed": False,
             "full_visual_candidate": name in ("unified-flair-view-cold", "bounded-temporal-loop-cold"),
             "shader": shader.encode("utf-8"),
             "sha256": hashlib.sha256(shader.encode("utf-8")).hexdigest()}
            for name, scope, shader in cases]



def bucket_variants(data: bytes) -> list[dict]:
    """Second bounded phase: smaller range guards on the production hoist first."""
    if hashlib.sha256(data).hexdigest() != FROZEN_HOIST_SHA256:
        raise RuntimeError("Windows grouping experiment requires the exact retained hoist shader")
    original = data.decode("utf-8")
    flair, flair_receipt = grouped_dispatch(original, "apply_material_flair", "flair", set(range(1, 51)) - {46})
    building, building_receipt = grouped_dispatch(original, "apply_building_finish", "id", set(range(81, 132)))
    both, _ = grouped_dispatch(flair, "apply_building_finish", "id", set(range(81, 132)))
    unified = folded_view(unified_dispatch(original))
    combined, _ = grouped_dispatch(unified, "apply_material_flair", "flair", set(range(1, 51)) - {46})
    combined, _ = grouped_dispatch(combined, "apply_building_finish", "id", set(range(81, 132)))
    cases = [
        ("hoist-control-cold", original, []),
        ("bucket-flair-cold", flair, [flair_receipt]),
        ("bucket-building-cold", building, [building_receipt]),
        ("bucket-both-cold", both, [flair_receipt, building_receipt]),
        ("unified-bucket-both-cold", combined, [flair_receipt, building_receipt]),
    ]
    return [{"name": name, "scope": "unchanged retained control" if not checks else "unqualified full-visual range-dispatch candidate",
             "qualification_passed": False, "full_visual_candidate": bool(checks), "source_checks": checks,
             "shader": shader.encode("utf-8"), "sha256": hashlib.sha256(shader.encode("utf-8")).hexdigest()}
            for name, shader, checks in cases]


def single_exit_variants(data: bytes) -> list[dict]:
    """Third bounded phase: exclusive dispatch with one initialized result."""
    import pace003_single_exit_variants as single_exit
    if hashlib.sha256(data).hexdigest() != FROZEN_HOIST_SHA256:
        raise RuntimeError("Windows single-exit experiment requires the exact retained hoist shader")
    unified = folded_view(unified_dispatch(data.decode("utf-8"))).encode("utf-8")
    return single_exit.single_exit_variants(data, unified)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    rows = variants(args.source.read_bytes())
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = []
    for row in rows:
        (args.output / (row["name"] + ".gdshader")).write_bytes(row["shader"])
        manifest.append({key: value for key, value in row.items() if key != "shader"})
    (args.output / "variants.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
