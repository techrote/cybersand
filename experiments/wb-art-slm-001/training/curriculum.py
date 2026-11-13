#!/usr/bin/env python3
"""Deterministic, train-only sampling for WB-ART-SLM-001.

The default shuffled-v1 sequence is byte-for-byte equivalent to the bootstrap
400-step run. keyword-replay-v1 is a *new* training candidate; it must never
be resumed from an old shuffled-v1 optimizer checkpoint.
"""
from __future__ import annotations

import random

THEMES = (
    "roots", "coral", "veins", "mycelium", "strata", "dunes",
    "crystals", "honeycomb", "labyrinth", "ruins", "circuitry", "ribs",
)
POLICIES = ("shuffled-v1", "keyword-replay-v1")
REPLAY_INTERVAL = 16


def epoch_indices(rows, seed: int, epoch: int, policy: str = "shuffled-v1") -> list[int]:
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
