#!/usr/bin/env python3
"""Read-only comparison of two independently audited native architecture bundles.

Run review_native_architecture.py on each bundle first. This command binds those
reports back to their original manifests and files, then compares native planes
and renderer outputs. Different native geometry fails the comparison; different
PNG bytes are reported separately and do not imply a geometry failure.

The default uses only the Python standard library. --rgba additionally requires
Pillow and measures decoded channel differences; it does not edit either image.
Only the explicitly selected --output file is written.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"Expected object: {path}")
    return value


def inside(root: Path, relative: str) -> Path:
    require(isinstance(relative, str) and bool(relative), "Missing artifact path")
    path = (root / relative).resolve()
    require(path.is_relative_to(root.resolve()), f"Artifact escapes bundle: {relative}")
    require(path.is_file(), f"Missing artifact: {relative}")
    return path


def load_bundle(root: Path, review_path: Path, expected_source: str) -> dict:
    report = read_json(review_path)
    require(report.get("passed") is True, "Independent review did not pass")
    require(report.get("development_source_mode") is False,
            "Comparison requires strict source-bound review")
    require(report.get("expected_source") == expected_source,
            "Independent review source does not match requested authority")
    examples: dict[str, dict] = {}
    for group in report["native"].values():
        require(group.get("passed") is True, "Native group did not pass")
        manifest = inside(root, group["manifest"])
        require(sha256(manifest) == group["manifest_sha256"],
                "Native manifest changed after independent review")
        document = read_json(manifest)
        require(document.get("source_revision") == expected_source,
                "Native manifest declares a different source")
        reviewed = {row["id"]: row for row in group["examples"]}
        require(len(reviewed) == len(group["examples"]), "Duplicate audited example")
        require(len(document["examples"]) == len(reviewed), "Native example count changed")
        for row in document["examples"]:
            identity = row["id"]
            require(identity not in examples and identity in reviewed,
                    "Duplicate or unaudited native example")
            prior = reviewed[identity]
            require(prior.get("evaluable") is True, "Native example was not evaluable")
            plane = inside(root, row["plane"])
            digest = sha256(plane)
            require(digest == row["sha256"] == prior["plane_sha256"],
                    "Native plane changed after independent review")
            require(row["extent"] == prior["extent"], "Native extent changed")
            width, height = row["extent"]
            require(plane.stat().st_size == width * height * 2,
                    "Native plane length does not match its extent")
            examples[identity] = {
                "extent": row["extent"], "plane_sha256": digest,
                "plane": row["plane"], "family": row["family"],
            }
    render_review = report["renders"]
    require(render_review.get("passed") is True, "Graphical review did not pass")
    render_manifest = inside(root, render_review["manifest"])
    require(sha256(render_manifest) == render_review["manifest_sha256"],
            "Render manifest changed after independent review")
    renders = read_json(render_manifest)
    require(renders.get("source_revision") == expected_source,
            "Render manifest declares a different source")
    require(len(renders["renders"]) == len(examples), "Render count differs from native count")
    rendered: set[str] = set()
    for row in renders["renders"]:
        name = row["image"]
        require(name.endswith("-godot.png"), "Unexpected native render naming")
        identity = name.removesuffix("-godot.png")
        require(identity in examples and identity not in rendered,
                "Missing or duplicate rendered native example")
        rendered.add(identity)
        image = inside(root, name)
        require(sha256(image) == row["image_sha256"], "Rendered image changed after review")
        require(row["native_material_sha256"] == examples[identity]["plane_sha256"],
                "Rendered image binding differs from native plane")
        examples[identity].update({
            "image": name, "image_sha256": row["image_sha256"],
            "renderer": {key: row[key] for key in (
                "os", "display", "godot", "rendering_driver", "graphics_adapter", "palette")},
        })
    require(rendered == set(examples), "Some native examples lack rendered evidence")
    return {
        "source_revision": expected_source, "review_sha256": sha256(review_path),
        "examples": examples, "completed_stages": report["native_completed_stage_records"],
        "native_receipt_chunks": report["native_receipt_chunks"],
    }


def rgba_difference(left_path: Path, right_path: Path) -> dict:
    from PIL import Image

    with Image.open(left_path) as left_image, Image.open(right_path) as right_image:
        require(left_image.size == right_image.size, "Rendered image dimensions differ")
        left, right = left_image.convert("RGBA").tobytes(), right_image.convert("RGBA").tobytes()
    changed = above_four = maximum = 0
    for offset in range(0, len(left), 4):
        delta = max(abs(left[offset + channel] - right[offset + channel]) for channel in range(4))
        changed += delta > 0
        above_four += delta > 4
        maximum = max(maximum, delta)
    return {"equal": left == right, "pixel_count": len(left) // 4,
            "changed_pixels": changed, "pixels_channel_delta_gt_4": above_four,
            "max_channel_delta": maximum}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for side in ("reference", "candidate"):
        parser.add_argument(f"--{side}-stages", required=True, type=Path)
        parser.add_argument(f"--{side}-review", required=True, type=Path)
        parser.add_argument(f"--{side}-source", required=True)
    parser.add_argument("--rgba", action="store_true", help="Compare decoded RGBA with Pillow")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    left = load_bundle(args.reference_stages, args.reference_review, args.reference_source)
    right = load_bundle(args.candidate_stages, args.candidate_review, args.candidate_source)
    require(set(left["examples"]) == set(right["examples"]), "Example identities differ")
    rows = []
    for identity in sorted(left["examples"]):
        a, b = left["examples"][identity], right["examples"][identity]
        equal = a["extent"] == b["extent"] and a["plane_sha256"] == b["plane_sha256"]
        row = {"id": identity, "native_geometry_equal": equal,
               "png_sha256_equal": a["image_sha256"] == b["image_sha256"],
               "reference": a, "candidate": b}
        if args.rgba:
            row["rgba"] = rgba_difference(args.reference_stages / a["image"],
                                          args.candidate_stages / b["image"])
        rows.append(row)
    result = {
        "schema_version": "cybersand.independent-architecture-comparison.v1",
        "audit_tool_sha256": sha256(Path(__file__)),
        "reference": {key: value for key, value in left.items() if key != "examples"},
        "candidate": {key: value for key, value in right.items() if key != "examples"},
        "passed": all(row["native_geometry_equal"] for row in rows),
        "native_geometry_equal_count": sum(row["native_geometry_equal"] for row in rows),
        "png_sha256_equal_count": sum(row["png_sha256_equal"] for row in rows),
        "examples": rows,
        "scope": "Exact native geometry and render-file comparison after strict independent receipt and source audits. No visual preference, actor traversal, physics, model quality, or whole-application equivalence is inferred. Renderer differences are retained, not treated as native geometry differences.",
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({key: result[key] for key in ("passed", "native_geometry_equal_count", "png_sha256_equal_count")}))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
