#!/usr/bin/env python3
"""Source-bound post-blind audit of historical native model-output collisions.

This inspects already-frozen development material displays and AI review labels.
It neither changes programs nor qualifies native/current-main/Windows output.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path

KEY_SHA256 = "1bcac225ca5d5674a042a750e3d6dae680c1ae6f26c4019569176f20d5ee90bf"
RESPONSE_SHA256 = "f0f688049cf077c25905049917272b6f06ad6db3ea5f770f5c2a7fa8191a0ed5"
PIXEL_SHA256 = "b87f804b48975746d5fb7aa9dcd2b937aa23607ce14e677011d3a248220d7f60"
HTML_SHA256 = "5f554c67c928d6f940126d07c529df89694a42d6cdeb7a65c7b9c4413f354877"
THEMES = frozenset("roots coral veins mycelium strata dunes crystals honeycomb labyrinth ruins circuitry ribs".split())


def load_pinned(path: Path, expected_sha: str) -> dict:
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != expected_sha:
        raise ValueError(f"source-bound file SHA-256 differs: {path.name}")
    return json.loads(raw)


def _unique_ids(rows: list, kind: str) -> dict:
    if not isinstance(rows, list) or any(not isinstance(x, dict) or not isinstance(x.get("id"), str) for x in rows):
        raise ValueError(f"invalid {kind} rows")
    found = {x["id"]: x for x in rows}
    if len(found) != len(rows):
        raise ValueError(f"duplicate {kind} id")
    return found


def analyze(key: dict, response: dict, pixels: dict) -> dict:
    """Evaluate frozen, independent raw sources; never infer human acceptance."""
    if (key.get("schema_version") != 1 or key.get("candidate") != "LFM350-step400"
            or key.get("original_requests") != 36 or key.get("first_pass_rejected") != 2
            or key.get("native_admitted_requests") != 34 or key.get("model_adapted") is not True):
        raise ValueError("original model request denominator or candidate differs")
    if (response.get("review_token") != key.get("review_token")
            or not str(response.get("reviewer_type", "")).startswith("AI visual review")
            or response.get("stimulus_sha256") != HTML_SHA256
            or pixels.get("html_sha256") != HTML_SHA256 or pixels.get("labels_opened") is not False):
        raise ValueError("frozen AI-only blind evidence/source identity differs")
    if (pixels.get("cards") != 34 or pixels.get("displayed_native_images") != 68
            or pixels.get("host_seeds") != [17, 73]
            or pixels.get("admitted_display_cards") != 34):
        raise ValueError("stimulus, host seed or native replay denominator differs")
    source = _unique_ids(key.get("items"), "answer-key")
    choices = _unique_ids(response.get("rows"), "blind-review")
    metrics = _unique_ids(pixels.get("per_card_blind_metrics"), "pixel metrics")
    if len(source) != 34 or set(source) != set(choices) or set(source) != set(metrics):
        raise ValueError("missing, added or mismatched native/blind cards")
    if any(i["theme"] not in THEMES or i.get("seeds") != [17, 73] or
           len(i.get("png_sha256", [])) != 2 or len(i.get("readback_sha256", [])) != 2
           for i in source.values()):
        raise ValueError("unqualified native theme, seed or receipt inventory")
    if any(z.get("label") not in THEMES or z.get("quality") not in (None, "") or
           z.get("variety") not in (None, "") for z in choices.values()):
        raise ValueError("invalid AI label or fabricated human quality/variety rating")
    rejected = key.get("excluded")
    if (not isinstance(rejected, list) or len(rejected) != 2 or
            any(z.get("theme") != "coral" or z.get("failure") != "first-pass-invalid" for z in rejected)):
        raise ValueError("refused original predictions were discarded or altered")

    groups = defaultdict(list)
    theme_totals = defaultdict(lambda: {"correct": 0, "requests": 0, "groups": set()})
    confusions = []
    for cid, item in sorted(source.items()):
        label = choices[cid]["label"]
        theme = item["theme"]
        correct = label == theme
        groups[item["group_id"]].append((cid, correct, theme))
        theme_totals[theme]["requests"] += 1
        theme_totals[theme]["correct"] += int(correct)
        theme_totals[theme]["groups"].add(item["group_id"])
        if not correct:
            confusions.append({"id": cid, "expected": theme, "ai_classified": label,
                               "structural_group": item["group_id"],
                               "symbolic_theme_correct": item.get("symbolic_theme_correct"),
                               "symbolic_primary_motif_correct": item.get("symbolic_motif_correct")})
    if len(groups) != 23 or set(theme_totals) != THEMES:
        raise ValueError("frozen native structural grouping differs")
    near = pixels.get("cross_request_near_pairs")
    if not isinstance(near, list) or len(near) != 3:
        raise ValueError("frozen exploratory similarity inventory differs")
    near_pairs = []
    seen = set()
    for pair in near:
        ids = pair.get("cards")
        if not isinstance(ids, list) or len(ids) != 2 or ids[0] == ids[1] or any(i not in source for i in ids):
            raise ValueError("malformed cross-request collision")
        edge = frozenset(ids)
        if edge in seen:
            raise ValueError("duplicated collision witness")
        seen.add(edge)
        scores = [pair.get("seed_17_jaccard"), pair.get("seed_73_jaccard")]
        if any(type(s) not in (float, int) or not 0.85 <= s <= 1.0 for s in scores):
            raise ValueError("collision is below the declared exploratory threshold")
        if pair.get("exact_png_pair") is True and scores != [1, 1]:
            raise ValueError("exact-pair witness conflicts with pixel overlaps")
        a, b = (source[x] for x in ids)
        near_pairs.append({"cards": ids, "themes": [a["theme"], b["theme"]],
                           "same_structural_group": a["group_id"] == b["group_id"],
                           "cross_theme": a["theme"] != b["theme"],
                           "seed_jaccard": scores,
                           "ai_labels": [choices[x]["label"] for x in ids],
                           "symbolic_primary_motif_correct": [a.get("symbolic_motif_correct"), b.get("symbolic_motif_correct")],
                           "exact_png_pair": pair["exact_png_pair"]})
    # Group-average scoring weights independent structural groups, not seeds/paraphrases.
    group_scores = {gid: sum(int(x[1]) for x in items) / len(items) for gid, items in groups.items()}
    per_theme = {t: {"correct_requests": z["correct"], "admitted_requests": z["requests"],
                     "admitted_groups": len(z["groups"]),
                     "group_macro": round(sum(group_scores[g] for g in z["groups"]) / len(z["groups"]), 6)}
                 for t, z in sorted(theme_totals.items())}
    good = sum(x["correct"] for x in theme_totals.values())
    if good != 29 or len(confusions) != 5 or sum(group_scores.values()) != 20:
        raise ValueError("independently scored historical AI visual results differ")
    cross_theme = [p for p in near_pairs if p["cross_theme"]]
    if len(cross_theme) != 1:
        raise ValueError("expected source-specific cross-theme collision inventory differs")
    return {
        "scope": "historical-linux-headless-native-model-material-images, frozen-development-only",
        "reviewer": "one AI reviewer; NOT human/owner acceptance",
        "candidate": key["candidate"], "original_requests": 36,
        "first_pass_admitted": 34, "first_pass_rejected": 2,
        "historical_seed_replays_conditional_on_admission": 68,
        "ai_correct_admitted": good, "ai_total_admitted": 34,
        "ai_correct_all_original": good, "ai_total_original": 36,
        "group_macro_admitted": round(sum(group_scores.values()) / 23, 6),
        "per_theme": per_theme, "incorrect_ai_labels": confusions,
        "exploratory_near_pairs": near_pairs,
        "cross_theme_near_collisions": cross_theme,
        "same_theme_near_pairs": len(near_pairs) - len(cross_theme),
        "cross_theme_diagnosis": "veins keyword output visually collides with circuitry; veins primary motif already recorded incorrect",
        "limits": "Only 34 admitted development/keyword requests and one AI reviewer; near threshold exploratory; no retraining or human, current-native, Windows or final assessment result",
        "decision": "HOLD",
    }


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("key", "responses", "pixels", "output"):
        p.add_argument("--" + name, required=True, type=Path)
    args = p.parse_args()
    result = analyze(load_pinned(args.key, KEY_SHA256),
                     load_pinned(args.responses, RESPONSE_SHA256),
                     load_pinned(args.pixels, PIXEL_SHA256))
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("ai_correct_admitted", "cross_theme_near_collisions", "decision")}, indent=2))


if __name__ == "__main__":
    main()
