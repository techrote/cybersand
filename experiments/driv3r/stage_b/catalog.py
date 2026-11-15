"""Finite source-owned native fixtures, never supplied by model output."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from ..contracts import Refusal, integer, identifier

CATALOGS = tuple(f"experiments/driv3r/stage_b/{family}_cases.json"
                 for family in ("direct", "fuzzy", "vector"))


def catalogs(root: Path) -> tuple[dict[str, list[list[int]]], dict[str, str]]:
    fixtures, hashes = {}, {}
    for relative in CATALOGS:
        path = root / relative
        raw = path.read_bytes()
        if len(raw) > 262144:
            raise Refusal("Native fixture catalog exceeds bound")
        data = json.loads(raw)
        family = path.name.split("_")[0]
        if data.get("schema") != f"driv3r-stage-b-{family}-cases-v1":
            raise Refusal("Unknown native fixture catalog schema")
        cases = data.get("cases")
        if type(cases) is not list or not 1 <= len(cases) <= 16:
            raise Refusal("Fixture catalog extent exceeds bound")
        for case in cases:
            fixture = case["fixture"]
            name = identifier(fixture["id"], "fixture ID")
            if name in fixtures or not name.startswith(f"b-{family}-"):
                raise Refusal("Duplicate or wrong-family native fixture ID")
            edits = fixture["edits"]
            if type(edits) is not list or len(edits) > 32:
                raise Refusal("Fixture edit count exceeds bound")
            visits = 0
            for edit in edits:
                if type(edit) is not list or len(edit) != 5:
                    raise Refusal("Malformed fixture edit")
                x, y, w, h, material = [integer(v, 0, 96, "fixture edit") for v in edit]
                if w < 1 or h < 1 or x+w > 96 or y+h > 96 or material not in (28, 58):
                    raise Refusal("Fixture edit exceeds fixed native authority")
                visits += w*h
            if visits > 4096:
                raise Refusal("Fixture installation exceeds cell bound")
            fixtures[name] = edits
        hashes[relative] = hashlib.sha256(raw).hexdigest()
    return fixtures, hashes
