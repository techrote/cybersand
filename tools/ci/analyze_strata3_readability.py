#!/usr/bin/env python3
"""Measure original challenge pixels at native-witnessed material positions.

This is supporting evidence, not a perceptual acceptance gate. Run the campaign's
strict verifier first. No image is changed, resampled, cropped or re-encoded.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path


APPLICATION = "fd0830abcfadd9ae19162e5677943bb131223e59"
PROFILES = {
    "classic", "architectural", "gameplay_clarity", "cinematic_deep_focus",
    "optical_lens", "diorama", "atmospheric_industrial", "noir",
    "cold_orbital", "alien_bioluminescence", "sunlit_megastructure",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def measure(case: Path, application_root: Path, expected_report_sha256: str) -> dict:
    source = case / "result.json"
    require(sha256(source) == expected_report_sha256, "Case report custody mismatch")
    report = json.loads(source.read_text(encoding="utf-8"))
    require(report["source_revision"] == APPLICATION, "Unexpected application source")
    require(report["scene"] == "optics-readability-challenge", "Unexpected scene")
    require(report["phase"] == "install" and report["completed"] is True,
            "Incomplete install case")
    require(not report["failures"] and report["diagnostic_headless"] is False,
            "Rejected or nongraphical source report")
    require(report["plane_native_hashes_before"] == report["plane_native_hashes_after"],
            "Native geometry changed across the matched captures")
    require(len(report["profile_captures"]) == 11 and
            {row["profile"] for row in report["profile_captures"]} == PROFILES,
            "The eleven-profile population is incomplete")
    decoder_path = application_root / "tools/ci/strata3_predecessor_compare.py"
    spec = importlib.util.spec_from_file_location("strata3_png_reader", decoder_path)
    require(spec is not None and spec.loader is not None, "Missing bounded PNG reader")
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)

    probes = {row["id"]: row for row in report["readability_native_probes"]}
    for name, point, truth in [
        ("real-platform", [160, 214], {"play": 58, "scripted": 0}),
        ("real-ground", [420, 694], {"play": 58}),
        ("false-platform-extension", [350, 214], {"play": 0, "scripted": 58}),
    ]:
        require(probes[name]["point"] == point and probes[name]["observed"] == truth,
                f"Missing actual native material witness: {name}")

    rows = []
    baseline_camera = report["profile_captures"][0]["camera"]
    baseline_geometry = report["profile_captures"][0]["geometry_group_sha256"]
    baseline_actor = report["profile_captures"][0]["actor_state"]
    for capture in report["profile_captures"]:
        filename = capture["filename"]
        require(isinstance(filename, str) and Path(filename).name == filename and
                "\\" not in filename and "/" not in filename,
                "Unexpected capture path")
        path = case / filename
        require(not path.is_symlink() and sha256(path) == capture["sha256"],
                "Original image custody mismatch")
        require(capture["camera"] == baseline_camera and
                capture["geometry_group_sha256"] == baseline_geometry and
                capture["actor_state"] == baseline_actor,
                "Unmatched capture state")
        configuration_json = capture["configuration_canonical_json"]
        require(hashlib.sha256(configuration_json.encode("utf-8")).hexdigest() ==
                capture["configuration_sha256"] and
                json.loads(configuration_json) == capture["configuration"],
                "Configuration custody mismatch")
        width, height, rgba = decoder.png_rgba(path.read_bytes())
        camera = capture["camera"]
        origin, view, rect = camera["origin"], camera["view_size"], camera["world_rect"]
        require(rect[2] / view[0] >= 0.5 and rect[3] / view[1] >= 0.5,
                "Overview undersamples declared probe patch")

        def project(x: float, y: float) -> tuple[float, float]:
            return (rect[0] + (x - origin[0]) * rect[2] / view[0],
                    rect[1] + (y - origin[1]) * rect[3] / view[1])

        def pixel(x: int, y: int) -> tuple[int, ...]:
            require(0 <= x < width and 0 <= y < height, "Probe escaped framebuffer")
            start = (y * width + x) * 4
            return tuple(rgba[start:start + 4])

        def luma(x: int, y: int) -> float:
            value = pixel(x, y)
            return (value[0] * 0.2126 + value[1] * 0.7152 + value[2] * 0.0722) / 255

        def patch(point: list[int]) -> dict:
            cx, cy = map(math.floor, project(point[0] + 0.5, point[1] + 0.5))
            return {
                "centre_pixel": [cx, cy],
                "rgbau8": [list(pixel(x, y)) for y in range(cy - 1, cy + 2)
                           for x in range(cx - 1, cx + 2)],
                "mean_encoded_luma": sum(luma(x, y) for y in range(cy - 1, cy + 2)
                                         for x in range(cx - 1, cx + 2)) / 9,
            }

        real = patch(probes["real-platform"]["point"])
        ground = patch(probes["real-ground"]["point"])
        false = patch(probes["false-platform-extension"]["point"])
        adjacent = [patch([350, 207]), patch([350, 221])]
        false_edge = abs(false["mean_encoded_luma"] -
                         sum(row["mean_encoded_luma"] for row in adjacent) / 2)
        x0, y0 = map(math.ceil, project(70, 90))
        x1, y1 = map(math.floor, project(680, 178))
        differences = [abs(luma(x + 1, y) - luma(x, y))
                       for y in range(y0, y1) for x in range(x0, x1 - 1)]
        rows.append({
            "profile": capture["profile"],
            "configuration_sha256": capture["configuration_sha256"],
            "image_sha256": capture["sha256"],
            "actual_image_size": [width, height],
            "camera": camera,
            "native_geometry_group_sha256": capture["geometry_group_sha256"],
            "physical_core": real,
            "physical_ground_core": ground,
            "false_platform_core": false,
            "false_platform_adjacent_patches": adjacent,
            "false_platform_local_edge_encoded_luma": false_edge,
            "physical_minus_false_encoded_luma": real["mean_encoded_luma"] -
                                                   false["mean_encoded_luma"],
            "rear_detail_region_native": [70, 90, 610, 88],
            "rear_detail_region_pixels": [x0, y0, x1 - x0, y1 - y0],
            "rear_detail_mean_horizontal_pixel_luma_difference":
                sum(differences) / len(differences),
            "rear_detail_edge_sample_count": len(differences),
        })
    classic = next(row for row in rows if row["profile"] == "classic")
    for row in rows:
        for name, output in [("physical_core", "physical_core_vs_classic_max_difference_u8"),
                             ("physical_ground_core", "physical_ground_vs_classic_max_difference_u8")]:
            row[output] = max(abs(a - b)
                              for aa, bb in zip(row[name]["rgbau8"], classic[name]["rgbau8"])
                              for a, b in zip(aa, bb))
    return {
        "schema": "strata003-native-bound-readability-measurement-v1",
        "source_revision": report["source_revision"],
        "case_report_sha256": sha256(source),
        "native_readbacks": {name: probes[name] for name in
                             ["real-platform", "real-ground", "false-platform-extension"]},
        "procedure_sha256": sha256(Path(__file__)),
        "png_decoder_sha256": sha256(decoder_path),
        "method": "Exact original PNG decode; projected source-cell centres; mean nine-pixel "
                  "patches at actual native-verified material58 positions in Play platform, "
                  "Play ground and rear false platform. Local rear edge uses native y207/y221. "
                  "Encoded-sRGB coefficients(.2126,.7152,.0722); mean adjacent horizontal "
                  "pixel contrast in the declared rear-only high-frequency region. "
                  "No image resampling, generation or edits.",
        "limitations": "Supporting geometric contrast observations, not human perception or "
                       "linear-light photometry. A patch assumes the declared solid eight-cell "
                       "bar around the native-witnessed centre. Whole native hashes are bound "
                       "by the verified report. Overview sampling can underresolve individual "
                       "cells. Water, Sand and transparent Play content are excluded from "
                       "opaque material-colour preservation claims. Two exact patches do not "
                       "prove every physical material pixel is unchanged.",
        "profiles": rows,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--application-root", type=Path, required=True)
    parser.add_argument("--expected-report-sha256", required=True)
    args = parser.parse_args()
    result = measure(args.case, args.application_root, args.expected_report_sha256)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
