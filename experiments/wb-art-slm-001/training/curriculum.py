#!/usr/bin/env python3
"""Deterministic, train-only sampling for WB-ART-SLM-001.

The default shuffled-v1 sequence is byte-for-byte equivalent to the bootstrap
400-step run. keyword-replay-v1 is a *new* training candidate; it must never
be resumed from an old shuffled-v1 optimizer checkpoint.
"""
from __future__ import annotations

import hashlib
import json
import random
from collections import Counter
from pathlib import Path

THEMES = (
    "roots", "coral", "veins", "mycelium", "strata", "dunes",
    "crystals", "honeycomb", "labyrinth", "ruins", "circuitry", "ribs",
)
POLICIES = ("shuffled-v1", "keyword-replay-v1", "failure-contrast-v5")
REPLAY_INTERVAL = 16


V5_INDEX_SHA256 = "dafbfcbdbb81ce23b3218e0e33d8ca6fb1f49c0f4fea5feba64cda3d638c11fa"
V5_IDS_SHA256 = "74e7cf0441b678e9e10e40f50ded01d52675e55f5be5ee9776a7985831fb610a"
V5_TRAIN_SHA256 = "972826e1af15a6babaff6e68e4c57d790c0c060a2befe050b4156c5f8ee05f66"


def _digest_lines(values) -> str:
    return hashlib.sha256(("\\n".join(map(str, values)) + "\\n").encode("utf-8")).hexdigest()


def _failure_contrast_v5(rows, seed: int, epoch: int, manifest_path: str | Path | None) -> list[int]:
    """Strict TRAIN-only original-index replay. Requires external Corpus-owned v5 manifest.

    Does not mutate admitted TRAIN rows or inspect DEV/FINAL. Index/ID fingerprints
    and role-owned manifest must match the exact frozen candidate before training.
    """
    if seed != 731 or epoch != 0 or len(rows) != 1152 or manifest_path is None:
        raise ValueError("v5 requires original 1152 TRAIN rows, seed 731, epoch zero and explicit manifest")
    manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    pins = {
        "schema_version": 1, "name": "failure-contrast-replay-v5",
        "draws": 400, "source_indices_space": "original admitted corpus/train.jsonl",
        "source_train_sha256": V5_TRAIN_SHA256,
        "source_indices_sha256": V5_INDEX_SHA256,
        "ordered_ids_sha256": V5_IDS_SHA256,
        "structural_groups": 72, "unique_native_traces": 376,
    }
    if any(manifest.get(k) != v for k, v in pins.items()):
        raise ValueError("v5 manifest has changed identity or original TRAIN source")
    if any(row.get("split") != "train" for row in rows):
        raise ValueError("v5 requires admitted TRAIN only")
    if len({row.get("id") for row in rows}) != len(rows):
        raise ValueError("v5 original TRAIN row IDs are not unique")
    idx = manifest.get("source_indices")
    if (not isinstance(idx, list) or len(idx) != 400
            or any(type(i) is not int or i < 0 or i >= len(rows) for i in idx)
            or _digest_lines(idx) != V5_INDEX_SHA256):
        raise ValueError("v5 index sequence or checksum differs")
    selected = [rows[i] for i in idx]
    if _digest_lines([r["id"] for r in selected]) != V5_IDS_SHA256:
        raise ValueError("v5 selected raw TRAIN IDs differ")
    if (len({r["native_case_id"] for r in selected}) != 376
            or len({r["group_id"] for r in selected}) != 72
            or Counter(r["theme"] for r in selected if r["prompt"] == r["theme"])
            != {theme: 3 for theme in THEMES}):
        raise ValueError("v5 native-trace/group/literal exposure contract differs")
    remaining = [i for i in range(len(rows)) if i not in set(idx)]
    full = idx + remaining[:len(rows) - len(idx)]
    if len(full) != len(rows):
        raise ValueError("v5 full epoch length changed")
    return full


def epoch_indices(rows, seed: int, epoch: int, policy: str = "shuffled-v1", v5_manifest: str | Path | None = None) -> list[int]:
    """Return an epoch of *sample indices*; never copy or change corpus rows.

    For keyword-replay-v1, all 12 admitted literal-word rows appear in the
    first 12 samples. Every 16th subsequent sample is a keyword replay,
    cycling fairly across themes. Non-replay slots use a fresh deterministic
    permutation of the remaining admitted train rows. The epoch has the same
    number of samples as the input corpus, though replay intentionally
    displaces some other rows; no dev/final rows are ever introduced.

    The seed+epoch permutation and sample cursor are sufficient to restore the
    schedule exactly on a full optimizer checkpoint resume.
    """
    if policy not in POLICIES:
        raise ValueError(f"Unknown curriculum policy: {policy}")
    if not isinstance(seed, int) or not isinstance(epoch, int) or epoch < 0:
        raise ValueError("Seed and nonnegative epoch must be integers")
    if not rows:
        raise ValueError("Training corpus is empty")
    if policy == "failure-contrast-v5":
        return _failure_contrast_v5(rows, seed, epoch, v5_manifest)
    order = list(range(len(rows)))
    rng = random.Random(seed + epoch)
    if policy == "shuffled-v1":
        rng.shuffle(order)
        return order

    # Fail closed: do not silently 'help' on the wrong corpus/split, or add
    # duplicated keyword rows to training without a new candidate identity.
    if len(rows) <= len(THEMES):
        raise ValueError("Keyword replay requires more than 12 train rows")
    if any(row.get("split") != "train" for row in rows):
        raise ValueError("Keyword replay accepts the admitted train split only")
    themes = {row.get("theme") for row in rows}
    if themes != set(THEMES):
        raise ValueError("Keyword replay requires the exact 12-theme vocabulary")
    if len({row.get("id") for row in rows}) != len(rows):
        raise ValueError("Keyword replay requires unique training IDs")
    exact = {}
    for index, row in enumerate(rows):
        if row.get("prompt", "").strip() == row.get("theme"):
            theme = row["theme"]
            if theme in exact:
                raise ValueError(f"Multiple literal training rows for {theme}")
            exact[theme] = index
    if set(exact) != set(THEMES):
        raise ValueError("Missing literal training row for " + ", ".join(sorted(set(THEMES) - set(exact))))
    keyword_indices = [exact[t] for t in THEMES]
    rng.shuffle(keyword_indices)
    keyword_set = set(keyword_indices)
    remaining = [i for i in order if i not in keyword_set]
    rng.shuffle(remaining)
    output = []
    keyword_cursor = 0
    regular_cursor = 0
    for position in range(len(rows)):
        # The first 12 are exposure, later positions add an explicit replay
        # at 12+15, 12+31, ... (one every 16 post-warmup samples).
        is_replay = position < len(THEMES) or (position - len(THEMES) + 1) % REPLAY_INTERVAL == 0
        if is_replay:
            output.append(keyword_indices[keyword_cursor % len(THEMES)])
            keyword_cursor += 1
        else:
            output.append(remaining[regular_cursor])
            regular_cursor += 1
    return output
