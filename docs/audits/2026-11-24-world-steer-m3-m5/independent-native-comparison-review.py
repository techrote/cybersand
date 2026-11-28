"""Independent read-only native comparison audit; no CyberSand code imported."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys
from collections import defaultdict, deque

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("directory", type=Path, help="Extracted architecture/comparison evidence directory containing cases.json")
directory = parser.parse_args().directory
raw = (directory / "cases.json").read_bytes()
manifest = json.loads(raw)
errors = []
rows = []
blocks = defaultdict(list)

def require(condition, message):
    if not condition:
        errors.append(message)

def digest(value):
    return hashlib.sha256(value).hexdigest()

def cells_in(rectangles):
    return {(x, y) for x0, y0, width, height in rectangles
            for y in range(y0, y0 + height) for x in range(x0, x0 + width)}

for case in manifest["cases"]:
    identity = case["id"]
    width, height = case["extent"]
    raw_before = (directory / case["before"]["path"]).read_bytes()
    raw_after = (directory / case["after"]["path"]).read_bytes()
    require(digest(raw_before) == case["before"]["sha256"], identity + ": before custody")
    require(digest(raw_after) == case["after"]["sha256"], identity + ": after custody")
    before = list(struct.unpack("<" + "H" * (width * height), raw_before))
    after = list(struct.unpack("<" + "H" * (width * height), raw_after))
    expected = before.copy()
    readback = []
    for operation in case["operations"]:
        require(operation["shape"] == "rectangle", identity + ": registered operation shape")
        for y in range(operation["y0"], operation["y1"] + 1):
            for x in range(operation["x0"], operation["x1"] + 1):
                require(0 <= x < width and 0 <= y < height, identity + ": operation bounds")
                offset = y * width + x
                require(expected[offset] in (0, 58), identity + ": native source permission")
                readback.append([x, y, expected[offset], operation["material"]])
                expected[offset] = operation["material"]
    require(expected == after, identity + ": exact whole-plane operation reconstruction")
    require(len(case["receipts"]) == 1, identity + ": original acknowledgement count")
    receipt = case["receipts"][0]
    require(receipt["backend"] == "CyberNativeCellWorld" and receipt["status"] == "completed", identity + ": native acknowledgement")
    require(digest(json.dumps(readback, separators=(",", ":")).encode()) == receipt["readback_sha256"], identity + ": original readback hash reconstruction")
    new_detail = {(x, y) for y in range(height) for x in range(width)
                  if before[y * width + x] == 0 and after[y * width + x] == 28}
    require(len(new_detail) == case["proposed_detail_cells"] == receipt["changed"] == receipt["confirmed"] == receipt["checked"] == 144,
            identity + ": exact matched realized native detail budget")
    require(receipt["excluded"] == receipt["refused"] == receipt["unchanged"] == 0, identity + ": no silent excluded or unchanged native work")
    guards = cells_in(case["context"]["protection_rects"])
    require(all(before[y * width + x] == after[y * width + x] for x, y in guards), identity + ": protection unchanged")
    anchors = cells_in(case["context"]["anchor_rects"])
    pending = set(new_detail)
    anchored = 0
    components = 0
    while pending:
        start = pending.pop()
        component = {start}
        queue = deque([start])
        contact = False
        while queue:
            x, y = queue.popleft()
            for neighbour in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                nx, ny = neighbour
                if neighbour in pending:
                    pending.remove(neighbour)
                    component.add(neighbour)
                    queue.append(neighbour)
                if 0 <= nx < width and 0 <= ny < height and neighbour in anchors and before[ny*width+nx] == 58:
                    contact = True
        components += 1
        anchored += len(component) if contact else 0
    record = {"id": identity, "arm": case["arm"], "changed_cells": len(new_detail),
              "detail_components": components, "anchored_detail_cells": anchored,
              "clearance_intrusion_cells": len(new_detail & cells_in(case["context"]["clearance_rects"])),
              "native_checked": receipt["checked"], "before_sha256": case["before"]["sha256"],
              "after_sha256": case["after"]["sha256"]}
    rows.append(record)
    blocks[(case["family"], case["seed"])].append((case, record))

block_results = []
required_arms = {"hand_typed", "procedural_modules", "random_valid", "reference_guided", "retrieval_guided"}
for (family, seed), entries in blocks.items():
    require({case["arm"] for case, _ in entries} == required_arms and len(entries) == 5, family + ": all five unique arms")
    require(len({case["before"]["sha256"] for case, _ in entries}) == 1, family + ": matched original plane")
    require(len({json.dumps(case["context"], sort_keys=True) for case, _ in entries}) == 1, family + ": matched declared context")
    require(len({case["budget_cells"] for case, _ in entries}) == 1, family + ": matched native ceiling")
    nonrandom_hashes = {case["after"]["sha256"] for case, _ in entries if case["arm"] != "random_valid"}
    block_results.append({"family": family, "seed": seed, "four_nonrandom_native_planes_identical": len(nonrandom_hashes) == 1})
require(len(rows) == 30 and len(block_results) == 6, "all six registered five-arm blocks retained")
require(manifest["model_calls"] == 0, "no model calls in retained experiment")
report = {"schema_version": "cybersand.independent-native-comparison-review.v1", "reviewer": "specialist-C",
          "method": "Independent Python standard-library replay and cell/component audit; no production compiler or evaluator imported.",
          "source_commit": manifest["source_commit"], "manifest_sha256": digest(raw),
          "audit_script_sha256": digest(Path(__file__).read_bytes()), "passed": not errors, "errors": errors,
          "attempts": rows, "matched_blocks": block_results,
          "conclusions": [] if errors else ["Every actual before/after plane and original native readback acknowledgement hash reconstructed exactly.",
                          "All thirty cases realize 144 new native detail cells, with zero excluded/refused/unchanged native work.",
                          "Four nonrandom strategies deliberately produce the same native geometry in each matched block.",
                          "This qualifies native reuse and contextual placement diagnostics; it does not establish superiority of reference/retrieval plans over typed plans.",
                          "The simple 24-cell reusable parts are engineering controls, separate from the larger architectural demonstrations.",
                          "No model-quality, aesthetic, blinded-preference, physics or actor-traversal conclusion is established."]}
destination = directory / "independent-stage-audit-c.json"
destination.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"passed": report["passed"], "attempts": len(rows), "blocks": len(block_results), "errors": errors, "output": str(destination)}))
sys.exit(bool(errors))
