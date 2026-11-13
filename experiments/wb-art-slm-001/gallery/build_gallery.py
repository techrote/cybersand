"""Curate real native readback PNGs; never rasterize model geometry here."""
from __future__ import annotations

import argparse
import base64
import hashlib
import html
import json
from pathlib import Path
import shutil


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


PAGE = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CyberSand · native pattern atlas</title>
<style>
:root{color-scheme:dark;font:16px/1.5 system-ui,sans-serif;background:#0c1218;color:#e8e5d2}
body{margin:0}header,main,footer{max-width:1440px;margin:auto;padding:26px 30px}header{border-bottom:1px solid #374048}
.eyebrow{font:12px ui-monospace,monospace;letter-spacing:.14em;color:#65d3b0;text-transform:uppercase}
h1{font-size:clamp(28px,4vw,50px);line-height:1.08;margin:16px 0}p{max-width:900px;color:#b6c0c8}
.controls{display:flex;gap:12px;flex-wrap:wrap;margin:18px 0}.controls label{display:flex;gap:8px;align-items:center}
select,button{background:#18232d;color:#ece7d3;border:1px solid #52616c;border-radius:4px;padding:8px;font:inherit}
#count{font:13px ui-monospace,monospace;color:#88b9ab}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:18px}
figure{margin:0;border:1px solid #32404a;background:#111c25;overflow:hidden}figure a{display:block;background:#0d161c}
img{display:block;width:100%;height:auto;aspect-ratio:1;image-rendering:pixelated}figcaption{padding:13px}
.name{display:flex;justify-content:space-between;gap:10px;font-weight:650}.badge{font:10px ui-monospace,monospace;color:#79d6b8;text-transform:uppercase;align-self:center}
.detail{font:12px/1.6 ui-monospace,monospace;color:#9db1be;margin:8px 0}.prompt{font-size:13px;color:#d6d5c9;min-height:38px}
details{font-size:12px;color:#aebdc7}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:11px/1.4 ui-monospace,monospace}
a{color:#84d4bc}footer{font-size:13px;border-top:1px solid #374048;margin-top:30px;color:#9fb2bf}
:focus-visible{outline:3px solid #8aebc3;outline-offset:3px}
</style></head><body>
<header><div class="eyebrow">WB-ART-SLM-001 / native evidence</div>
<h1>Twelve words.<br>Seeded structures.</h1>
<p>Actual CyberSand native cell readback, drawn through its Art planner and executor. Every tile links to its original PNG. Reference recipes and model predictions are identified separately; a rendered reference does not prove model competence.</p>
<div class="controls"><label>Requested theme <select id="theme"><option value="">All twelve</option></select></label>
<label>Source <select id="kind"><option value="">All sources</option></select></label>
<label>Layout <select id="layout"><option value="">All layouts</option></select></label>
<label>Seed <select id="seed"><option value="">All seeds</option></select></label><button id="reset">Reset filters</button></div>
<div id="count" aria-live="polite"></div></header>
<main><div id="grid" class="grid"></div></main>
<footer><strong>Qualification scope.</strong> Pinned Linux headless native-material pilot. These are readback visualizations, not screenshots of a qualified Windows UI. Runtime source, binary hashes, native receipts, seeded programs and review notes accompany the atlas. No current-main, Windows, blind aesthetic or production acceptance is implied. Read <a href="manifest.json">the exact manifest</a> and <a href="README.md">qualification notes</a>.</footer>
<script id="data" type="application/json">__DATA__</script>
<script>
const atlas=JSON.parse(document.getElementById('data').textContent), fields=['theme','kind','layout','seed'];
for(const field of fields){const el=document.getElementById(field);const values=[...new Set(atlas.items.map(r=>String(r[field])))].sort();for(const v of values){const o=document.createElement('option');o.value=v;o.textContent=v;el.appendChild(o);}el.addEventListener('change',render);}
document.getElementById('reset').onclick=()=>{for(const f of fields)document.getElementById(f).value='';render();};
function add(parent,tag,text,cls){const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;parent.appendChild(e);return e;}
function render(){const rows=atlas.items.filter(r=>fields.every(f=>!document.getElementById(f).value||String(r[f])===document.getElementById(f).value));const grid=document.getElementById('grid');grid.replaceChildren();document.getElementById('count').textContent=`${rows.length} of ${atlas.items.length} native images · ${atlas.runtime.source_commit.slice(0,12)} · Godot ${atlas.runtime.godot_version}`;
for(const r of rows){const f=add(grid,'figure');const a=add(f,'a');a.href=r.png;const img=add(a,'img');img.src=r.png;img.width=r.width;img.height=r.height;img.loading='lazy';img.alt=`${r.kind}: requested ${r.theme}, ${r.layout}, seed ${r.seed}`;const cap=add(f,'figcaption');const name=add(cap,'div',undefined,'name');add(name,'span',(r.model?'Requested ':'')+r.theme);add(name,'span',r.kind,'badge');add(cap,'div',`${r.layout} · seed ${r.seed}\n${r.operation_count} shapes · ${r.filled_cells} cells`,'detail');if(r.predicted_theme!==r.theme)add(cap,'div',`Model theme field: ${r.predicted_theme}`,'detail');add(cap,'div',r.prompt||r.id,'prompt');const details=add(cap,'details');add(details,'summary','Program and provenance');add(details,'pre',JSON.stringify({id:r.id,program:r.program,image_sha256:r.image_sha256,readback_sha256:r.readback_sha256,receipt:r.receipt},null,2));}}
render();
</script></body></html>'''


def build(config_path: Path, output: Path) -> dict:
    config = json.loads(config_path.read_text())
    output.mkdir(parents=True, exist_ok=True)
    images = output / "images"
    images.mkdir(exist_ok=True)
    items, seen = [], set()
    runtime = None
    for batch in config["batches"]:
        source = Path(batch["artifacts"])
        document = json.loads(Path(batch["cases"]).read_text())
        cases = {c["id"]: c for c in document["cases"]}
        receipt_document = json.loads(Path(batch["receipts"]).read_text())
        if receipt_document.get("passed") is not True:
            raise ValueError("failed native batch cannot become a qualified gallery")
        if runtime and runtime != receipt_document["runtime"]:
            raise ValueError("gallery mixes runtime identities")
        runtime = receipt_document["runtime"]
        select = set(batch.get("select", cases))
        for receipt in receipt_document["cases"]:
            if receipt["id"] not in select:
                continue
            case = cases[receipt["id"]]
            if not receipt["success"] or receipt["outside_focus_violations"] or receipt["unexpected_material_cells"]:
                raise ValueError("invalid native case selected")
            if receipt["operations_sha256"] != case["operations_sha256"]:
                raise ValueError("native case geometry digest mismatch")
            path = (source / receipt["png"]).resolve()
            if not path.is_relative_to(source.resolve()) or digest(path) != receipt["image_sha256"]:
                raise ValueError("native PNG path or digest mismatch")
            key = batch["kind"] + "-" + case["id"]
            if key in seen:
                continue
            seen.add(key)
            if Path(key).name != key:
                raise ValueError("unsafe gallery ID")
            filename = key + ".png"
            shutil.copyfile(path, images / filename)
            items.append({"id": case["id"], "theme": case["theme"],
                          "predicted_theme": case["program"]["theme"],
                          "kind": batch["kind"], "model": batch.get("model"),
                          "layout": case["program"]["layers"][0]["layout"],
                          "seed": case["seed"], "width": case["width"],
                          "height": case["height"], "program": case["program"],
                          "operation_count": case["operation_count"],
                          "filled_cells": receipt["filled_cells"],
                          "prompt": case.get("prompt", case["theme"]),
                          "png": "images/" + filename,
                          "image_sha256": receipt["image_sha256"],
                          "readback_sha256": receipt["readback_sha256"],
                          "receipt": receipt})
    manifest = {"version": 1, "qualification": "Pinned Linux native-material pilot",
                "runtime": runtime, "count": len(items), "items": items}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    data = json.dumps(manifest, ensure_ascii=False).replace("</", "<\\/")
    (output / "index.html").write_text(PAGE.replace("__DATA__", data))
    standalone = {**manifest, "items": []}
    for row in items:
        embedded = "data:image/png;base64," + base64.b64encode((output / row["png"]).read_bytes()).decode()
        standalone["items"].append({**row, "png": embedded, "original_filename": row["png"]})
    standalone_data = json.dumps(standalone, ensure_ascii=False).replace("</", "<\\/")
    standalone_page = PAGE.replace("__DATA__", standalone_data)
    standalone_page = standalone_page.replace('Read <a href="manifest.json">the exact manifest</a> and <a href="README.md">qualification notes</a>.',
        'Each tile contains its exact program, image/readback hashes and native receipt. The accompanying repository report gives full qualification notes. All image bytes are embedded in this file.')
    standalone_page = standalone_page.replace('a.href=r.png;', 'a.href=r.png;a.download=(r.original_filename||r.id+".png").split("/").pop();')
    (output / "native_atlas.html").write_text(standalone_page)
    return manifest


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()
    result = build(args.config, args.out)
    print(json.dumps({"count": result["count"], "runtime": result["runtime"]}, indent=2))


if __name__ == "__main__":
    main()
