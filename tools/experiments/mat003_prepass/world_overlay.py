#!/usr/bin/env python3
"""Create append-only, hash-guarded S1 copies; never edit production sources.

The exact source arm has no source replacements. Candidate edits are enumerated
below, applied only when each frozen source fragment occurs exactly once, and
retained in overlay.json with original and resulting SHA-256 identities.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

EXPERIMENT = Path("tools/experiments/mat003_prepass")
KINDS = {"source": 0, "word": 1, "padded": 2, "packed": 3, "aligned": 4, "split": 5}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _replace(text: str, old: str, new: str, label: str,
             patches: list[dict[str, str]], path: str) -> str:
    if text.count(old) != 1:
        raise ValueError(f"{label}: expected one frozen fragment in {path}, found {text.count(old)}")
    patches.append({"path": path, "label": label, "before": old, "after": new})
    return text.replace(old, new, 1)


def prepare_overlay(source_root: Path, output: Path, arm: dict) -> dict:
    """Return compiler macros/paths and exact patch receipts for one registered arm.

    source_root is an immutable full input snapshot, including native/include,
    native/src and the experimental files. output must not already exist.
    """
    source_root = Path(source_root).resolve()
    output = Path(output).resolve()
    if output.exists():
        raise ValueError(f"refusing existing overlay: {output}")
    if output == source_root or source_root in output.parents:
        raise ValueError("overlay must be outside the immutable input snapshot")
    registration_path = source_root / EXPERIMENT / "world_registration.json"
    registration = json.loads(registration_path.read_text())
    registered = next((a for a in registration["arms"] if a["id"] == arm.get("id")), None)
    if registered is None or registered != arm:
        raise ValueError("arm does not exactly match the registered record")
    native_hashes = registration["baseline_control_sha256"]
    for relative, digest in native_hashes.items():
        actual = sha256(source_root / relative)
        if actual != digest:
            raise ValueError(f"frozen production source drift: {relative}")
    # This internal header is directly included by world.cpp and is a required
    # compiled input even though it lives outside native/include.
    if "native/src/render_snapshot_internal.hpp" not in native_hashes:
        raise ValueError("registration omits compiled render_snapshot_internal.hpp")

    output.mkdir(parents=True)
    for relative in (Path("native/include"), Path("native/src"), EXPERIMENT):
        shutil.copytree(source_root / relative, output / relative,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    patches: list[dict[str, str]] = []
    representation = arm["representation"]
    kind = KINDS[representation]
    split = representation == "split"
    extra = arm["neutral_extra_bits"] // 8

    if representation != "source":
        header_rel = "native/include/cybersand/world.hpp"
        source_rel = "native/src/world.cpp"
        header = (output / header_rel).read_text()
        source = (output / source_rel).read_text()
        header = _replace(header, '#include "cybersand/material.hpp"',
                          '#include "cybersand/material.hpp"\n#include "world_adapter.hpp"',
                          "include isolated adapter", patches, header_rel)
        header = _replace(header, "    std::uint8_t update_epoch_ = 0;",
                          "    mat003_world::Epoch update_epoch_ = 0;",
                          "type every World epoch consumer together", patches, header_rel)
        source = _replace(source, "    using Cell = detail::PrecisionStorage;",
                          "    using Cell = mat003_world::Cell;",
                          "select isolated carrier", patches, source_rel)
        source = _replace(source,
                          "    update_epoch_ = static_cast<std::uint8_t>(update_epoch_ + 1U);",
                          "    update_epoch_ = static_cast<mat003_world::Epoch>(update_epoch_ + 1U);",
                          "preserve selected width at World increment", patches, source_rel)
        source = _replace(source,
                          "            parallel_->pool->dispatch(parallel_->phase_job_indices.size(), &context, execute_task);",
                          "            mat003_world::observe_dispatch(parallel_->phase_job_indices.size());\n"
                          "            parallel_->pool->dispatch(parallel_->phase_job_indices.size(), &context, execute_task);",
                          "observe actual pool dispatch", patches, source_rel)
        source = _replace(source, "                function(context, task);",
                          "                mat003_world::observe_worker_task();\n"
                          "                function(context, task);",
                          "observe background worker task execution", patches, source_rel)
        if split:
            source = _replace(source,
                              "                Cell::for_material(Material::Empty)),\n          activity_blocks_per_axis",
                              "                Cell::for_material(Material::Empty)),\n"
                              "          mat003_tails(cells.size()),\n          activity_blocks_per_axis",
                              "prepare dense bounded tails at chunk admission", patches, source_rel)
            source = _replace(source, "    std::vector<Cell> cells;",
                              "    std::vector<Cell> cells;\n"
                              "    std::vector<mat003_world::Tail> mat003_tails;",
                              "own separate neutral-tail array", patches, source_rel)
            source = _replace(source, "    cell = Chunk::Cell::for_material(material);",
                              "    cell = Chunk::Cell::for_material(material);\n"
                              "    chunk->mat003_tails[target.index] = 0;",
                              "reset neutral tail with write_cell replacement", patches, source_rel)
            source = _replace(source,
                              "    chunk.cells[target.index] = Chunk::Cell::for_material(material);",
                              "    chunk.cells[target.index] = Chunk::Cell::for_material(material);\n"
                              "    chunk.mat003_tails[target.index] = 0;",
                              "reset neutral tail with public set replacement", patches, source_rel)
            source = _replace(source,
                              "    const auto destination_cell = destination.cells[destination_address.index];",
                              "    const auto destination_cell = destination.cells[destination_address.index];\n"
                              "    const auto mat003_source_tail = source.mat003_tails[source_address.index];\n"
                              "    const auto mat003_destination_tail = destination.mat003_tails[destination_address.index];",
                              "stage tails before whole-cell move or swap", patches, source_rel)
            source = _replace(source,
                              "    destination.cells[destination_address.index] = source_cell;",
                              "    destination.cells[destination_address.index] = source_cell;\n"
                              "    destination.mat003_tails[destination_address.index] = mat003_source_tail;",
                              "transfer source tail with destination carrier", patches, source_rel)
            source = _replace(source,
                              "        swap ? destination_cell : Chunk::Cell::for_material(Material::Empty);",
                              "        swap ? destination_cell : Chunk::Cell::for_material(Material::Empty);\n"
                              "    source.mat003_tails[source_address.index] =\n"
                              "        swap ? mat003_destination_tail : mat003_world::Tail{0};",
                              "swap destination tail or reset vacancy", patches, source_rel)
            source = _replace(source,
                              "    if (destination_was_empty) destination_cell = Chunk::Cell::for_material(Material::Water);",
                              "    if (destination_was_empty) {\n"
                              "        destination_cell = Chunk::Cell::for_material(Material::Water);\n"
                              "        destination->mat003_tails[destination_address.index] = 0;\n    }",
                              "reset newly Water destination neutral tail", patches, source_rel)
            source = _replace(source,
                              "        source_cell = Chunk::Cell::for_material(Material::Empty);",
                              "        source_cell = Chunk::Cell::for_material(Material::Empty);\n"
                              "        source->mat003_tails[source_address.index] = 0;",
                              "reset exhausted Water source neutral tail", patches, source_rel)
        (output / header_rel).write_text(header)
        (output / source_rel).write_text(source)

    macros = [f'-DMAT003_ARM_ID="{arm["id"]}"',
              f"-DMAT003_STORAGE_KIND={kind}",
              f'-DMAT003_EPOCH_BITS={arm["epoch_bits"]}',
              f"-DMAT003_EXTRA_BYTES={extra}",
              f"-DMAT003_SPLIT={int(split)}",
              f'-DMAT003_WORLD_SOURCE="{output / "native/src/world.cpp"}"']
    files = []
    for relative in sorted(native_hashes):
        files.append({"path": relative, "input_sha256": sha256(source_root / relative),
                      "output_sha256": sha256(output / relative)})
    if representation == "source" and any(f["input_sha256"] != f["output_sha256"] for f in files):
        raise AssertionError("unmodified source arm changed")
    receipt = {"schema_version": 1, "arm": arm, "compile_definitions": macros,
               "world_source": str(output / "native/src/world.cpp"),
               "include_dir": str(output / "native/include"),
               "experiment_dir": str(output / EXPERIMENT),
               "registration_sha256": sha256(registration_path),
               "source_control_unchanged": representation == "source",
               "dispatch_observed": representation != "source",
               "split_tail_allocation": "dense-at-chunk-admission" if split else "inapplicable",
               "patches": patches, "files": files}
    (output / "overlay.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--arm", required=True)
    args = parser.parse_args()
    registration = json.loads((args.source / EXPERIMENT / "world_registration.json").read_text())
    arm = next((a for a in registration["arms"] if a["id"] == args.arm), None)
    if arm is None:
        raise ValueError("unknown registered arm")
    print(json.dumps(prepare_overlay(args.source, args.output, arm), indent=2))


if __name__ == "__main__":
    main()
