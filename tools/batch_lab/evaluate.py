#!/usr/bin/env python3
"""Reduce native Batch Lab exports and prepare a small offline blinded review.

No inference, network access, geometry generation or source mutation occurs here.
Material-ID thumbnails are derived from retained native readback; they are not
Godot framebuffer captures. Metrics are diagnostic, not an aesthetic score.
"""
from __future__ import annotations

import argparse
import base64
from collections import Counter, deque
import hashlib
import html
import json
from pathlib import Path
import random
import struct
import zlib

MAX_CELLS = 512 * 512
FINAL_STATES = {"completed", "partial", "refused", "stopped", "failed"}


def _hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _plane(value: str, count: int) -> tuple[list[int], bytes]:
    if not isinstance(value, str) or len(value) > ((MAX_CELLS * 2 + 2) // 3) * 4:
        raise ValueError("Missing or oversized native material plane")
    raw = base64.b64decode(value, validate=True)
    if len(raw) != count * 2:
        raise ValueError("Native uint16 material plane length does not match extent")
    return list(struct.unpack(f"<{count}H", raw)), raw


def _inside(x: int, y: int, box: list[int]) -> bool:
    return len(box) == 4 and box[0] <= x < box[0] + box[2] and box[1] <= y < box[1] + box[3]


def _neighbors(i: int, width: int, count: int):
    if i % width:
        yield i - 1
    if i % width + 1 < width:
        yield i + 1
    if i >= width:
        yield i - width
    if i + width < count:
        yield i + width


def _components(indices: set[int], width: int, count: int) -> list[int]:
    remaining = set(indices)
    sizes = []
    while remaining:
        start = remaining.pop()
        queue = [start]
        for i in queue:
            for neighbor in _neighbors(i, width, count):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    queue.append(neighbor)
        sizes.append(len(queue))
    return sorted(sizes, reverse=True)


def _route(cells: list[int], width: int, height: int, route: list, radius: int) -> bool:
    if not 0 <= radius <= 16 or len(route) != 2:
        raise ValueError("Invalid geometric clearance specification")
    # Summed occupancy table permits exact square-clearance checks in O(1).
    stride = width + 1
    prefix = [0] * (stride * (height + 1))
    for y in range(height):
        row = 0
        for x in range(width):
            row += cells[y * width + x] != 0
            prefix[(y + 1) * stride + x + 1] = prefix[y * stride + x + 1] + row

    def clear(x: int, y: int) -> bool:
        if not radius <= x < width - radius or not radius <= y < height - radius:
            return False
        x0, y0, x1, y1 = x - radius, y - radius, x + radius + 1, y + radius + 1
        return prefix[y1 * stride + x1] - prefix[y0 * stride + x1] - prefix[y1 * stride + x0] + prefix[y0 * stride + x0] == 0

    (ax, ay), (bx, by) = route
    if not clear(ax, ay) or not clear(bx, by):
        return False
    start, goal = ay * width + ax, by * width + bx
    queue, seen = deque([start]), {start}
    while queue:
        i = queue.popleft()
        if i == goal:
            return True
        for neighbor in _neighbors(i, width, width * height):
            if neighbor not in seen and clear(neighbor % width, neighbor // width):
                seen.add(neighbor)
                queue.append(neighbor)
    return False


def material_metrics(config: dict, before: list[int], after: list[int]) -> dict:
    width, height = config["extent"]
    if len(before) != width * height or len(after) != len(before):
        raise ValueError("Material plane dimensions differ")
    targets = config.get("metrics_targets", {})
    structures = set(targets.get("structural_materials", [58]))
    changed = [i for i, (a, b) in enumerate(zip(before, after)) if a != b]
    # Source-world crop coordinates are not the local authoring domain. The
    # native owner separately checks its complete arena outside this footprint.
    scope = [0, 0, width, height]
    guards = config.get("protection", [])
    protected = sum(before[i] not in (0, 58) or any(_inside(i % width, i // width, g) for g in guards) for i in changed)
    outside = sum(not _inside(i % width, i // width, scope) for i in changed)
    structural = {i for i, value in enumerate(after) if value in structures}
    components = _components(structural, width, len(after))
    features = []
    for feature in targets.get("features", []):
        x, y, w, h = feature["rect"]
        indices = [yy * width + xx for yy in range(max(0, y), min(height, y + h)) for xx in range(max(0, x), min(width, x + w))]
        found = sum(i in structural for i in indices)
        fraction = found / max(1, len(indices))
        features.append({"name": feature["name"], "structural_cells": found, "fraction": fraction,
                         "present_proxy": bool(indices) and fraction >= feature.get("minimum_fraction", 0.1)})
    route = targets.get("route", [])
    clearance = {"applicable": len(route) == 2}
    if clearance["applicable"]:
        clearance["connected"] = _route(after, width, height, route, int(targets.get("clearance_radius", 2)))
    void_fraction = None
    if "void_rect" in targets:
        x, y, w, h = targets["void_rect"]
        indices = [yy * width + xx for yy in range(max(0, y), min(height, y + h)) for xx in range(max(0, x), min(width, x + w))]
        void_fraction = sum(after[i] == 0 for i in indices) / max(1, len(indices))
    empty_fraction = after.count(0) / len(after)
    feature_pass = all(f["present_proxy"] for f in features)
    connected_ok = not targets.get("require_connected", False) or len(components) == 1
    route_ok = not clearance["applicable"] or clearance["connected"]
    return {"changed_cells": len(changed), "protected_changed_cells": protected,
            "outside_scope_changed_cells": outside, "empty_fraction": empty_fraction,
            "declared_void_empty_fraction": void_fraction, "structural_cells": len(structural),
            "structural_components": len(components), "largest_component_cells": components[0] if components else 0,
            "largest_component_fraction": (components[0] if components else 0) / max(1, len(structural)),
            "features": features, "all_feature_proxies_present": feature_pass, "clearance": clearance,
            "structural_checks_pass": protected == 0 and outside == 0 and connected_ok and route_ok and feature_pass and empty_fraction >= targets.get("minimum_empty_fraction", 0)}


def tile_records(document: dict) -> list[dict]:
    if not isinstance(document, dict):
        raise ValueError("Expected a Batch Lab export object")
    # Session tiles name the current selection, while attempts retain retries,
    # partials and failures. Never substitute current tiles for that denominator.
    records = document.get("attempts", document.get("attempt", document.get("tiles", [document])))
    if isinstance(records, dict):
        records = [records]
    if not isinstance(records, list) or len(records) > 1024 or not all(isinstance(t, dict) for t in records):
        raise ValueError("Expected a bounded array of tile attempts")
    return records


def checked_readback(tile: dict) -> tuple[dict, list[int], list[int], bytes, bytes, int]:
    """Validate the retained native boundary before deriving metrics or images."""
    if tile.get("state") not in FINAL_STATES:
        raise ValueError("Attempt has no terminal native outcome")
    config = tile["config"]
    width, height = config["extent"]
    if type(width) is not int or type(height) is not int or not 1 <= width <= 512 or not 1 <= height <= 512:
        raise ValueError("Unsupported extent")
    before, before_raw = _plane(tile["source_materials_base64"], width * height)
    after, raw = _plane(tile["material_cells_base64"], width * height)
    if _hash(raw) != tile.get("material_sha256"):
        raise ValueError("Native result plane SHA-256 mismatch")
    provenance = tile.get("provenance", {})
    if not isinstance(provenance, dict):
        raise ValueError("Native provenance is malformed")
    source_hash = tile.get("source_material_sha256", provenance.get("source_material_sha256"))
    if source_hash != _hash(before_raw):
        raise ValueError("Native source plane SHA-256 missing or mismatched")
    if "source_material_sha256" in provenance and provenance["source_material_sha256"] != source_hash:
        raise ValueError("Native source digests disagree")
    receipts = tile.get("receipts")
    if not isinstance(receipts, list) or len(receipts) > MAX_CELLS:
        raise ValueError("Native acknowledgement array is missing or oversized")
    confirmed_changes = 0
    total_checked = 0
    for receipt in receipts:
        if not isinstance(receipt, dict) or receipt.get("backend") != "CyberNativeCellWorld" or receipt.get("status") != "completed":
            raise ValueError("Receipt is not a completed native acknowledgement")
        fields = ("requested", "checked", "changed", "unchanged", "confirmed", "excluded", "refused")
        if any(type(receipt.get(k)) is not int or not 0 <= receipt[k] <= 4096 for k in fields):
            raise ValueError("Native acknowledgement counters are missing or outside chunk bounds")
        if (receipt["checked"] > receipt["requested"]
                or receipt["checked"] != sum(receipt[k] for k in ("changed", "unchanged", "excluded", "refused"))
                or receipt["confirmed"] != receipt["changed"] + receipt["unchanged"]):
            raise ValueError("Native acknowledgement counters are inconsistent")
        confirmed_changes += receipt["changed"]
        total_checked += receipt["checked"]
    if total_checked > MAX_CELLS:
        raise ValueError("Native acknowledgements exceed the bounded attempt capacity")
    if sum(a != b for a, b in zip(before, after)) > confirmed_changes:
        raise ValueError("Net changed cells exceed preserved native acknowledgements")
    return config, before, after, before_raw, raw, confirmed_changes


def evaluate(document: dict) -> dict:
    records = tile_records(document)
    outcomes = []
    seen = set()
    for index, tile in enumerate(records):
        identifier = str(tile.get("attempt_id", f"missing-id-{index}"))
        state = str(tile.get("state", "unknown"))
        usage = tile.get("usage", {})
        item = {"attempt_id": identifier, "state": state, "evaluable": False,
                "timings": tile.get("timings", {}), "usage": usage,
                "cost": usage.get("cost", None) if isinstance(usage, dict) else None}
        try:
            if identifier in seen:
                raise ValueError("Duplicate attempt identity")
            seen.add(identifier)
            config, before, after, before_raw, raw, confirmed_changes = checked_readback(tile)
            metrics = material_metrics(config, before, after)
            provider = config.get("provider")
            origin = tile.get("provenance", {}).get("execution_origin")
            if not origin:
                origin = "supplied-program" if provider in {"procedural", "random", "direct"} else "provider-response-unverified"
            control = config.get("control") if provider in {"procedural", "random"} and origin == "supplied-program" else None
            item.update(evaluable=True, metrics=metrics, native_changed_acknowledgements=confirmed_changes,
                        source_sha256=_hash(before_raw), result_sha256=_hash(raw),
                        cohort=config.get("cohort", "unassigned"), group_id=config.get("group_id", "unassigned"),
                        family=config.get("family"), variant=config.get("variant"), control=control,
                        requested_control=config.get("control"), execution_origin=origin,
                        provider=provider, model=config.get("model"), seed=config.get("seed"))
        except (ValueError, KeyError, TypeError, IndexError, AttributeError, struct.error) as exc:
            item["reason"] = str(exc)
        outcomes.append(item)
    return {"schema": "cybersand-batch-analysis-v1", "total_attempts": len(records),
            "states": dict(sorted(Counter(t["state"] for t in outcomes).items())),
            "evaluable_attempts": sum(t["evaluable"] for t in outcomes), "attempts": outcomes,
            "scope": "All attempts retained, including refused, stopped, partial and unevaluable results. Net changed cells differ from cumulative acknowledged writes. Structural diagnostics do not establish native actor traversal, aesthetic quality or prompt improvement.",
            "inference": "No inference is executed by this tool. A native result does not establish that a genuine model produced it. Unknown usage/cost remains unknown; it is never replaced with zero."}


def _png(cells: list[int], width: int, height: int) -> bytes:
    # Deliberately diagnostic colours, not a claim of production shader parity.
    def colour(material: int) -> bytes:
        if material == 0:
            return bytes((18, 22, 31))
        if material == 58:
            return bytes((225, 229, 236))
        if material == 28:
            return bytes((118, 144, 174))
        return bytes(((material * 67) % 192 + 63, (material * 97) % 192 + 63, (material * 127) % 192 + 63))
    rows = b"".join(b"\0" + b"".join(colour(v) for v in cells[y * width:(y + 1) * width]) for y in range(height))
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")


def blinded_bundle(document: dict, destination: Path, seed: int) -> dict:
    destination.mkdir(parents=True, exist_ok=False)
    review = destination / "review"
    review.mkdir()
    indexed = list(enumerate(tile_records(document)))
    random.Random(seed).shuffle(indexed)
    batch_id = _hash(json.dumps(document, sort_keys=True, separators=(",", ":")).encode())
    key, cards = [], []
    for ordinal, (original_index, tile) in enumerate(indexed, 1):
        anonymous = f"Attempt {ordinal:02d}"
        config = tile.get("config", {})
        labels = {name: config.get(name) for name in ("family", "variant", "seed", "provider", "model",
                  "prompt_version", "prompt_sha256", "group_id", "cohort", "control", "extent")}
        key.append({"anonymous_id": anonymous, "original_index": original_index,
                    "attempt_id": tile.get("attempt_id"), "config": labels})
        visual = "<p>Native evidence is unevaluable. Retain this outcome in the review denominator.</p>"
        try:
            validated, _before, cells, _before_raw, _raw, _changed = checked_readback(tile)
            width, height = validated["extent"]
            png = base64.b64encode(_png(cells, width, height)).decode()
            visual = f'<img width="{width * 2}" height="{height * 2}" src="data:image/png;base64,{png}" alt="Native material-ID view"><p>{width} × {height} cells; 2 display pixels per cell.</p>'
        except (KeyError, ValueError, TypeError, IndexError, AttributeError, struct.error):
            pass
        state = html.escape(str(tile.get("state", "unknown")))
        cards.append(f'<article data-id="{anonymous}"><h2>{anonymous}</h2><p>Outcome: {state}</p>{visual}<label>Visual usefulness <select><option value="">Unrated</option><option>not assessable</option><option>reject</option><option>promising</option></select></label><label>Reason <textarea></textarea></label></article>')
    page = '<!doctype html><meta charset="utf-8"><title>Batch Lab blinded review</title><style>body{font:16px system-ui;background:#171b24;color:#eef1f8;margin:24px}main{display:flex;flex-wrap:wrap;gap:18px}article{background:#252d3b;padding:14px;max-width:1100px;overflow:auto}img{image-rendering:pixelated;max-width:none}label{display:block;margin:8px 0}textarea{display:block;width:95%}button{font:inherit;padding:12px}</style><h1>Native Batch Lab — blinded review</h1><p>Material-ID diagnostics from retained native cells, not Godot framebuffer captures. Equal framing: full tile, exactly two display pixels per cell. Every outcome remains visible. Judge purposeful detail, legible construction and useful space; paint counts are not quality.</p><p>Provider, model, prompt and seed are withheld. Submit every judgement before opening the separate unblinding key. This is voluntary blinding, not an access-control boundary.</p><button id="save">Download committed judgements</button><p id="status"></p><main>' + ''.join(cards) + '</main><script>const batch=' + json.dumps(batch_id) + ';document.getElementById("save").onclick=()=>{const votes=[...document.querySelectorAll("article")].map(a=>({anonymous_id:a.dataset.id,judgement:a.querySelector("select").value,reason:a.querySelector("textarea").value}));if(votes.some(v=>!v.judgement)){document.getElementById("status").textContent="Rate every attempt, including failures.";return;}const data={schema:"cybersand-blind-votes-v1",batch_id:batch,committed_at:new Date().toISOString(),votes};const a=document.createElement("a");a.href=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:"application/json"}));a.download="committed-judgements.json";a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);};</script>'
    (review / "index.html").write_text(page, encoding="utf-8")
    mapping = {"schema": "cybersand-blind-key-v1", "batch_id": batch_id, "shuffle_seed": seed, "attempts": key}
    (destination / "unblinding-key.json").write_text(json.dumps(mapping, indent=2) + "\n", encoding="utf-8")
    return {"batch_id": batch_id, "attempts": len(key), "review": str(review / "index.html"), "key": str(destination / "unblinding-key.json")}


def reveal_votes(votes: dict, key: dict) -> dict:
    if votes.get("schema") != "cybersand-blind-votes-v1" or key.get("schema") != "cybersand-blind-key-v1" or votes.get("batch_id") != key.get("batch_id"):
        raise ValueError("Votes and key do not identify the same blinded cohort")
    if not votes.get("committed_at"):
        raise ValueError("Commit the complete judgements before revealing identities")
    mapping = {x["anonymous_id"]: x for x in key["attempts"]}
    entries = votes.get("votes", [])
    if len(entries) != len(mapping) or {v.get("anonymous_id") for v in entries} != set(mapping):
        raise ValueError("Every retained attempt, including failures, needs exactly one judgement")
    result = []
    for vote in entries:
        if vote.get("judgement") not in ("not assessable", "reject", "promising"):
            raise ValueError("Unknown or missing blind judgement")
        result.append({**mapping[vote["anonymous_id"]], "judgement": vote["judgement"], "reason": vote.get("reason", "")})
    return {"schema": "cybersand-unblinded-judgements-v1", "batch_id": key["batch_id"],
            "committed_at": votes["committed_at"], "attempts": result,
            "scope": "Human ordinal preferences, not a statistical claim. Keep paired seeds and structural groups in later analysis."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--blind-dir", type=Path)
    parser.add_argument("--blind-seed", type=int, default=1907)
    args = parser.parse_args()
    if args.export.stat().st_size > 256 * 1024 * 1024:
        raise ValueError("Export exceeds the offline analysis input bound")
    document = json.loads(args.export.read_text(encoding="utf-8"))
    report = evaluate(document)
    report["input_sha256"] = _hash(args.export.read_bytes())
    if args.blind_dir:
        report["blinded_review"] = blinded_bundle(document, args.blind_dir, args.blind_seed)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("total_attempts", "states", "evaluable_attempts")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
