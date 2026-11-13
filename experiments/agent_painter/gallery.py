"""Make a side-by-side owner gallery from verified original native PNG bytes.

No compiler rasterization or image synthesis. The standalone HTML embeds each
unchanged PNG; original files, receipts and source hashes accompany it.
FINAL examples are never included in this development/owner gallery.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import html
import json
import shutil
from pathlib import Path


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_file(root: Path, name: str) -> Path:
    path = (root / name).resolve()
    if Path(name).is_absolute() or not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError("Gallery source missing or unsafe")
    return path


def validate_custody(evidence: Path, candidates: list[dict], report: dict, custody: dict) -> None:
    """Prevent post-verification relabeling, including exposing reserved FINAL."""
    if sha(evidence / "candidates.json") != custody.get("candidates_sha256"):
        raise ValueError("Gallery candidate custody changed")
    if report.get("cases"):
        for name, key in (("runtime-custody.json", "runtime_custody_sha256"),
                          ("native-summary.json", "engine_summary_sha256"),
                          ("native-receipts.jsonl", "native_receipts_sha256"),
                          ("process-result.json", "process_result_sha256")):
            if sha(evidence / name) != report.get(key):
                raise ValueError("Gallery verification custody changed: " + name)
        if (report.get("source_sha") != custody["source_sha"]
                or report.get("runtime_sha256") != custody["native_sha256"]):
            raise ValueError("Gallery runtime identity differs from native verification")
        examples = {row["id"]: row for row in candidates}
        for result in report["cases"]:
            if not result.get("success"):
                continue
            row = examples[result["id"]]
            canonical = lambda value: json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
            if (any(result.get(key) != row.get(key) for key in ("family", "split", "seed"))
                    or result.get("program_sha256") != hashlib.sha256(canonical(row["program"])).hexdigest()
                    or result.get("operations_sha256") != hashlib.sha256(canonical(row["compiled"]["operations"])).hexdigest()):
                raise ValueError("Gallery candidate differs from verified native case")


def build(evidence: Path, output: Path) -> dict:
    candidates = json.loads((evidence / "candidates.json").read_text())["examples"]
    report = json.loads((evidence / "native-verification.json").read_text())
    custody = json.loads((evidence / "runtime-custody.json").read_text())
    validate_custody(evidence, candidates, report, custody)
    by_id = {row["id"]: row for row in report.get("cases", [])}
    output.mkdir(parents=True, exist_ok=True)
    (output / "images").mkdir(exist_ok=True)
    (output / "receipts").mkdir(exist_ok=True)
    groups = {}
    items = []
    for example in candidates:
        if example["split"] == "FINAL":
            continue
        identifier = example["id"]
        result = by_id.get(identifier, {"success": False, "failures": ["Native case not completed"]})
        row = {
            "id": identifier, "family": example["family"], "group_id": example["group_id"],
            "split": example["split"], "seed": example["seed"], "prompt": example["prompt"],
            "program": example["program"], "kind": "procedural teacher / native-applied",
            "success": result.get("success", False), "failures": result.get("failures", []),
            "source_sha": custody["source_sha"], "runtime_sha256": custody["native_sha256"],
        }
        if row["success"]:
            png = safe_file(evidence, result["png"])
            receipt = safe_file(evidence, result["receipt"])
            if sha(png) != result["image_sha256"] or sha(receipt) != result["receipt_sha256"]:
                raise ValueError("Gallery refuses tampered native PNG/receipt")
            shutil.copyfile(png, output / "images" / png.name)
            shutil.copyfile(receipt, output / "receipts" / receipt.name)
            row.update({
                "png": "images/" + png.name, "receipt": "receipts/" + receipt.name,
                "png_sha256": sha(png), "receipt_sha256": sha(receipt),
                "readback_sha256": result["readback_sha256"], "operations_sha256": result["operations_sha256"],
                "program_sha256": result["program_sha256"], "affected_cells": result["affected_cells"],
                "filled_cells": result["filled_cells"], "structure": result["structure"],
                "image_data": "data:image/png;base64," + base64.b64encode(png.read_bytes()).decode(),
            })
        groups.setdefault((row["family"], row["group_id"]), []).append(row)
        items.append(row)
    manifest = {
        "schema_version": 1, "kind": "native teacher gallery", "passed": report["passed"],
        "source_sha": custody["source_sha"], "runtime_sha256": custody["native_sha256"],
        "godot_version": custody["godot_version"], "development_only": custody.get("development_only", False),
        "included_splits": ["TRAIN", "DEVELOPMENT"], "sealed_final_count": sum(row["split"] == "FINAL" for row in candidates),
        "native_verification_sha256": sha(evidence / "native-verification.json"),
        "failures": report.get("failures", []),
        "items": [{key: value for key, value in row.items() if key != "image_data"} for row in items],
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    cards = []
    for (family, group_id), pair in groups.items():
        pair.sort(key=lambda row: row["seed"])
        figures = []
        for row in pair:
            if row["success"]:
                image = ('<a download="' + html.escape(row["id"]) + '.png" href="' + row["image_data"] + '">'
                         '<img width="96" height="96" alt="' + html.escape(row["prompt"]) + '" src="' + row["image_data"] + '"></a>')
                detail = str(row["filled_cells"]) + " stored cells · replay verified"
            else:
                image = '<div class="failed">Native evidence unavailable<br>' + html.escape("; ".join(row["failures"])) + "</div>"
                detail = "Failed / not admitted"
            compact = {key: value for key, value in row.items() if key not in ("image_data", "prompt")}
            figures.append('<figure>' + image + '<figcaption><strong>Host seed ' + str(row["seed"]) + '</strong><p>' +
                           html.escape(detail) + '</p><details><summary>Program, receipts and hashes</summary><pre>' +
                           html.escape(json.dumps(compact, indent=2)) + '</pre></details></figcaption></figure>')
        cards.append('<article data-family="' + html.escape(family) + '"><h2>' + html.escape(group_id.replace("_", " ")) +
                     '</h2><p class="prompt">' + html.escape(pair[0]["prompt"]) + '</p><div class="badge">' +
                     html.escape(family + " · " + pair[0]["split"] + " · procedural teacher") +
                     '</div><div class="pair">' + "".join(figures) + '</div></article>')
    status = "Qualified native pilot" if report["passed"] and not custody.get("development_only") else (
        "Local development evidence" if report["passed"] else "Incomplete / failed native campaign")
    failures = ("<details open><summary>Preserved campaign failures</summary><pre>" +
                html.escape("\n".join(report["failures"])) + "</pre></details>") if report.get("failures") else ""
    page = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CyberSand · Agent-painter foundation</title>
<style>
:root{color-scheme:dark;font:16px/1.5 system-ui,sans-serif;background:#0d151c;color:#e8e2cd}
body{margin:0}header,main,footer{max-width:1280px;margin:auto;padding:28px}header{border-bottom:1px solid #354957}
h1{font-size:clamp(30px,5vw,54px);line-height:1.05;max-width:900px;margin:16px 0}h2{font-size:21px;margin:0 0 8px}
p{color:#b5c5ce;max-width:1040px}.eyebrow,.badge{color:#7bd1bd;font:12px ui-monospace,monospace}
.eyebrow{letter-spacing:.12em;text-transform:uppercase}.identity{font:12px/1.7 ui-monospace,monospace;overflow-wrap:anywhere}
.toolbar{display:flex;align-items:center;gap:20px;margin-top:24px}select{font:inherit;padding:8px;background:#182732;color:#e8e2cd;border:1px solid #426074}
article{border:1px solid #354957;background:#101e28;margin-bottom:28px;padding:20px}
.prompt{font-size:14px;margin:0 0 8px}.badge{margin-bottom:18px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}
figure{margin:0;min-width:0;background:#0d151c}figure>a{display:block}img{display:block;width:100%;height:auto;image-rendering:pixelated;aspect-ratio:1}
figcaption{padding:14px}figcaption p{font-size:12px;margin:6px 0}.failed{min-height:300px;display:grid;place-content:center;padding:20px;color:#f4ad92}
details{font-size:12px}pre{white-space:pre-wrap;overflow-wrap:anywhere;max-height:400px;overflow:auto;font:11px/1.5 ui-monospace,monospace}
a{color:#7bd1bd}footer{border-top:1px solid #354957;font-size:13px}.hidden{display:none}
@media(max-width:620px){header,main,footer{padding:16px}.pair{gap:8px}article{padding:10px}figcaption{padding:8px}}
</style></head><body><header><div class="eyebrow">CyberSand · agent-painter shared foundation</div>
<h1>Greebles, Pipework<br>and Architecture</h1>
<p>Seed-matched procedural teacher designs applied through CyberSand's real native Art owner.
These original PNGs map independently captured stored material IDs to a fixed palette. They are
native drawing evidence, not model-generated paintings or screenshots of the graphical Workbench.</p>
<p><strong>__STATUS__</strong> · __COUNT__ originals in __GROUPS__ structural groups · __FINAL__ sealed FINAL examples are omitted from the owner gallery.</p>
<div class="identity">Source __SOURCE__<br>Native runtime __RUNTIME__<br>Engine __GODOT__</div>
<div class="toolbar"><label>Assignment <select id="filter"><option value="">All families</option>
<option value="greebles">Greebles</option><option value="pipework">Pipework</option><option value="architecture">Architecture</option></select></label>
<span id="count"></span></div>__FAILURES__</header><main>__CARDS__</main>
<footer>Each pair uses two fixed host seeds. Click an image to download its unchanged original PNG.
The compiler supplies proposals; the native Workbench retains material, focus, protection, Stop,
Undo/Redo and persistence authority. Structural tests measure pipe topology/diameter and architecture
free-space clearance. They do not establish human visual quality or gravity-based gameplay traversal.
The source/hash manifest and original receipt files accompany this self-contained HTML.</footer>
<script>const filter=document.getElementById('filter'),cards=[...document.querySelectorAll('article')];
function render(){let visible=0;for(const card of cards){const yes=!filter.value||card.dataset.family===filter.value;
card.classList.toggle('hidden',!yes);if(yes)visible++;}document.getElementById('count').textContent=visible+' designs · two seeds each';}
filter.addEventListener('change',render);render();</script></body></html>"""
    replacements = {
        "__STATUS__": html.escape(status), "__COUNT__": str(sum(row["success"] for row in items)),
        "__GROUPS__": str(len(groups)), "__SOURCE__": html.escape(custody["source_sha"]),
        "__FINAL__": str(manifest["sealed_final_count"]),
        "__RUNTIME__": html.escape(custody["native_sha256"]), "__GODOT__": html.escape(custody["godot_version"]),
        "__FAILURES__": failures, "__CARDS__": "".join(cards),
    }
    for key, value in replacements.items():
        page = page.replace(key, value)
    (output / "index.html").write_text(page, encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = build(args.evidence, args.output)
    print(json.dumps({"passed": result["passed"], "images": len(result["items"]), "output": str(args.output)}))
