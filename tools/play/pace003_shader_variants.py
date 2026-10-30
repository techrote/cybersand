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
             "shader": shader.encode("utf-8"),
             "sha256": hashlib.sha256(shader.encode("utf-8")).hexdigest()}
            for name, scope, shader in cases]


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
