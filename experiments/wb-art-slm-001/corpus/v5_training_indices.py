#!/usr/bin/env python3
"""Read-only v5 source-index adapter for Training's admitted original train.jsonl.

Training owns wiring this into its versioned sampler. This helper never
reorders or rewrites corpus files and does not launch model training.
"""
from __future__ import annotations

from collections import Counter
import hashlib
import json
from pathlib import Path

MANIFEST = Path(__file__).with_name("failure_contrast_replay_v5.json")
THEMES = ("roots", "coral", "veins", "mycelium", "strata", "dunes",
          "crystals", "honeycomb", "labyrinth", "ruins", "circuitry", "ribs")
SOURCE_TRAIN_SHA256 = "972826e1af15a6babaff6e68e4c57d790c0c060a2befe050b4156c5f8ee05f66"
INDEX_SHA256 = "dafbfcbdbb81ce23b3218e0e33d8ca6fb1f49c0f4fea5feba64cda3d638c11fa"
IDS_SHA256 = "74e7cf0441b678e9e10e40f50ded01d52675e55f5be5ee9776a7985831fb610a"


def digest_lines(values: list[object]) -> str:
    return hashlib.sha256(("\n".join(map(str, values)) + "\n").encode("utf-8")).hexdigest()


def v5_epoch_indices(rows: list[dict], seed: int, epoch: int,
                     manifest_path: Path = MANIFEST) -> list[int]:
    """Return an admitted 1152-position epoch beginning with the pinned v5 400 draws.

    Intended for Training's fresh, named 400-step candidate at seed 731.
    The original-source train.jsonl must first pass Training's ordinary
    byte-SHA/native admission gate. Never pass a reordered train file.
    """
    if seed != 731 or epoch != 0 or len(rows) != 1152:
        raise ValueError("v5 is pinned to 1152 admitted TRAIN rows, seed 731, epoch zero")
    if any(row.get("split") != "train" for row in rows):
        raise ValueError("v5 accepts TRAIN only")
    if len({row.get("id") for row in rows}) != len(rows):
        raise ValueError("v5 original TRAIN identifiers are not unique")
    manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    required = {
        "schema_version": 1,
        "name": "failure-contrast-replay-v5",
        "draws": 400,
        "source_indices_space": "original admitted corpus/train.jsonl",
        "source_train_sha256": SOURCE_TRAIN_SHA256,
        "source_indices_sha256": INDEX_SHA256,
        "ordered_ids_sha256": IDS_SHA256,
        "structural_groups": 72,
        "unique_native_traces": 376,
    }
    if any(manifest.get(k) != v for k, v in required.items()):
        raise ValueError("v5 manifest identity or TRAIN source changed")
    idx = manifest.get("source_indices")
    if (not isinstance(idx, list) or len(idx) != 400 or
            any(type(i) is not int or i < 0 or i >= len(rows) for i in idx)):
        raise ValueError("v5 source index list is invalid")
    if digest_lines(idx) != INDEX_SHA256:
        raise ValueError("v5 source index digest differs from pinned source")
    selected = [rows[i] for i in idx]
    if digest_lines([row["id"] for row in selected]) != IDS_SHA256:
        raise ValueError("v5 source indices no longer select admitted original rows")
    if (len({row["native_case_id"] for row in selected}) != 376 or
            len({row["group_id"] for row in selected}) != 72 or
            Counter(row["theme"] for row in selected if row["prompt"] == row["theme"])
            != {t: 3 for t in THEMES}):
        raise ValueError("v5 exposure or native source identities differ")
    seen = set(idx)
    remaining = [i for i in range(len(rows)) if i not in seen]
    full_epoch = idx + remaining[:len(rows) - len(idx)]
    if len(full_epoch) != len(rows):
        raise ValueError("v5 full epoch construction differs")
    return full_epoch
