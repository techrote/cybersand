#!/usr/bin/env python3
"""Build the offline Strata gallery from an admitted Windows capture campaign.

No screenshot is generated, edited, resized or substituted here. The package
builder must also run its full campaign verifier; this intake independently
checks the exact source, original scene receipts and every displayed asset.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
from pathlib import Path, PurePosixPath
import re
import struct


ROOT = Path(__file__).resolve().parents[1]
SCENES = ("orbital-terminal", "neon-rain-arcology", "industrial-underworks", "abyss-foundry", "vertical-transfer-spine")
PLANES = ("play", "scripted", "effects", "background")
PLANE_LABELS = {"play": "Play", "scripted": "Rear architecture", "effects": "Native effects", "background": "Background"}
GENERATOR = "tools/build_strata2_gallery.py"
HASH = re.compile(r"[0-9a-f]{64}\Z")
COMMIT = re.compile(r"[0-9a-f]{40}\Z")
IDENTITY = re.compile(r"[a-z0-9][a-z0-9_-]{0,63}\Z")


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), "Expected an object: " + str(path))
    return value


def finite(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def png_extent(data: bytes) -> list[int]:
    require(len(data) >= 33 and data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR",
            "Displayed evidence is not a PNG with a native header")
    width, height = struct.unpack(">II", data[16:24])
    require(0 < width <= 8192 and 0 < height <= 8192, "Capture dimensions are outside the gallery budget")
    return [width, height]


def prepare(qualification_dir: Path, output: Path, source_sha: str) -> dict:
    """Validate original inputs and return deterministic JSON-safe render data."""
    qualification_dir = qualification_dir.resolve(strict=True)
    output = output.resolve()
    require(COMMIT.fullmatch(source_sha) is not None, "An exact qualified application commit is required")
    require(output.suffix.lower() == ".html" and output.parent.is_dir(), "Gallery output needs an existing package directory")
    require(qualification_dir.is_relative_to(output.parent), "Gallery images must remain inside the package")
    prefix = qualification_dir.relative_to(output.parent).as_posix()
    report_path = qualification_dir / "qualification.json"
    require(report_path.is_file() and not report_path.is_symlink(), "Original campaign report is missing or linked")
    report = read_json(report_path)
    require(report.get("schema") == "strata2-workbench-qualification-v1" and report.get("completed") is True
            and report.get("status") == "passed" and report.get("input_custody") == "passed"
            and report.get("local_delta") == [], "Gallery requires a completed passing clean-source campaign")
    require(report.get("platform") == "win32" and report.get("source_commit") == source_sha
            and COMMIT.fullmatch(str(report.get("source_tree", ""))), "Gallery requires the exact qualified Windows source")
    require(report.get("selected_scenes") == list(SCENES), "Gallery requires all five ordered native environments")
    entries = report.get("scenes")
    require(isinstance(entries, list) and len(entries) == len(SCENES)
            and {entry.get("name") for entry in entries} == set(SCENES), "Missing or duplicated native scene receipts")
    by_id = {entry["name"]: entry for entry in entries}
    source_inputs = report.get("source_inputs_sha256", {})
    require(isinstance(source_inputs, dict), "Missing qualified source input ledger")
    source_hashes = {}
    for name in (GENERATOR, *("godot/data/strata2/" + identity + ".json" for identity in SCENES)):
        path = ROOT / name
        require(path.is_file() and not path.is_symlink(), "Missing source-bound gallery input: " + name)
        value = sha(path.read_bytes().replace(b"\r\n", b"\n"))
        require(source_inputs.get(name) == value, "Gallery input differs from qualified source: " + name)
        source_hashes[name] = value
    ledger = report.get("evidence_sha256", {})
    require(isinstance(ledger, dict) and ledger, "Missing original evidence ledger")
    used = {}

    def evidence(name: str) -> tuple[bytes, str]:
        parts = PurePosixPath(name)
        require(not parts.is_absolute() and ".." not in parts.parts and "\\" not in name,
                "Unsafe evidence path")
        digest = ledger.get(name)
        require(isinstance(digest, str) and HASH.fullmatch(digest), "Evidence was not recorded: " + name)
        path = qualification_dir / name
        require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(qualification_dir),
                "Missing or linked original evidence: " + name)
        data = path.read_bytes()
        require(sha(data) == digest, "Original evidence bytes changed: " + name)
        used[name] = digest
        return data, (prefix + "/" + name if prefix != "." else name)

    def material_hashes(value) -> dict:
        require(isinstance(value, dict) and set(value) == set(PLANES)
                and all(isinstance(digest, str) and HASH.fullmatch(digest) for digest in value.values()),
                "A capture has no exact four-plane native identity")
        return value

    scenes = []
    for identity in SCENES:
        entry = by_id[identity]
        require(entry.get("status") == "passed" and set(entry.get("phases", {})) == {"install", "reopen"},
                "Scene did not complete both passing processes: " + identity)
        phases = {}
        for phase in ("install", "reopen"):
            receipt = entry["phases"][phase]
            data, url = evidence(identity + "/" + phase + ".json")
            result = json.loads(data)
            require(sha(data) == receipt.get("report_sha256") and result == receipt.get("result"),
                    "Original scene report differs from its campaign receipt")
            require(result.get("schema") == "strata2-workbench-execution-v1" and result.get("completed") is True
                    and result.get("failures") == [] and result.get("scene") == identity and result.get("phase") == phase
                    and result.get("source_revision") == source_sha and result.get("display_server") == "Windows"
                    and result.get("rendering_method") == "gl_compatibility" and result.get("ordinary_workbench") is True
                    and result.get("diagnostic_headless") is False and result.get("document_version") == 2,
                    "Scene is not a passing actual Windows ordinary Workbench execution")
            require(type(result.get("process_id")) is int and result["process_id"] > 0,
                    "Missing actual Godot process identity")
            material_hashes(result.get("plane_native_hashes"))
            phases[phase] = {"report": result, "url": url}
        installed, reopened = (phases[phase]["report"] for phase in ("install", "reopen"))
        require(reopened.get("fresh_process_reopen") is True and installed["process_id"] != reopened["process_id"]
                and installed["plane_native_hashes"] == reopened["plane_native_hashes"]
                and installed.get("authored_settings_sha256") == reopened.get("authored_settings_sha256")
                and HASH.fullmatch(str(installed.get("authored_settings_sha256", ""))),
                "Scene lacks exact fresh-process authored reopening")
        metadata = read_json(ROOT / "godot/data/strata2" / (identity + ".json"))
        require(metadata.get("id") == identity and metadata.get("extent") == installed.get("extent"),
                "Capture and source recipe extent differ")
        original_native = material_hashes(installed.get("showcase_native_hashes"))
        atmosphere = installed.get("atmosphere", {})
        atmosphere_native = material_hashes(atmosphere.get("native_hashes_before"))
        require(atmosphere_native == atmosphere.get("native_hashes_after")
                and atmosphere.get("solo_leakage", {}).get("changed_samples") == 0,
                "Atmosphere comparison changed native geometry or leaked through excluded planes")
        require(installed.get("gallery", {}).get("isolated_planes", "").find("atmosphere disabled") >= 0,
                "Native-plane gallery did not exclude presentation-only motifs")
        views = []

        def add_view(view_id: str, filename: str, label: str, category: str, caption: str, native: dict,
                     extra: dict | None = None) -> dict:
            raw, url = evidence(identity + "/" + filename)
            view = {"id": view_id, "url": url, "label": label, "category": category, "caption": caption,
                    "image_sha256": sha(raw), "pixels": png_extent(raw), "native_hashes": native}
            if extra:
                view.update(extra)
            views.append(view)
            return view

        add_view("stack", "reference-composite.png", "Full stack", "planes",
                 "Original native showcase with its authored presentation-only atmosphere. Play alone owns actors and collision.", original_native)
        for plane in PLANES:
            role = metadata["provenance"]["plane_roles"][plane]
            add_view(plane, "reference-plane-" + plane + ".png", PLANE_LABELS[plane], "planes",
                     role + ". Isolated native material surface; visual atmosphere is disabled.", original_native)
        for state in ("off", "on"):
            add_view("atmosphere-" + state, "atmosphere-" + state + ".png", "Atmosphere " + state.upper(), "atmosphere",
                     "Matched atmosphere trial: identical native geometry and camera, visual motifs " + state.upper()
                     + ". Qualification edits can differ from the original reference stack. Paired stills do not demonstrate playfeel.", atmosphere_native)
        require(views[-1]["pixels"] == views[-2]["pixels"], "Atmosphere comparison framebuffer dimensions differ")
        details = installed.get("detail_views", [])
        require(isinstance(details, list) and details, "No actual native detail viewpoints were recorded")
        for detail in details:
            detail_id = detail.get("id", "")
            require(isinstance(detail_id, str) and IDENTITY.fullmatch(detail_id), "Unsafe detail viewpoint identity")
            add_view("detail-" + detail_id, "detail-" + detail_id + ".png", detail_id.replace("-", " ").capitalize(), "details",
                     "Actual native Godot detail with nearest material pixels. Magnified capture; no one-cell/one-display-pixel claim.", original_native,
                     {"camera_origin": detail.get("camera_origin"), "view_size": detail.get("view_size")})
        grid_planes = set()
        for detail in installed.get("native_grid_details", []):
            plane = detail.get("plane")
            require(plane in ("play", "scripted") and plane not in grid_planes, "Invalid or duplicate native grid detail")
            grid_planes.add(plane)
            require(all(finite(detail.get(key)) and abs(detail[key] - 1.0) < 0.01 for key in ("pixels_per_cell_x", "pixels_per_cell_y")),
                    "Native detail did not map one cell to one captured framebuffer pixel")
            view = add_view("native-grid-" + plane, "native-grid-" + plane + ".png", PLANE_LABELS[plane] + " · 1:1 capture", "details",
                            "Actual framebuffer crop: one native cell per captured pixel, no resampling. This page fits images by default; browser/OS scaling remains separate.",
                            original_native, {"pixels_per_cell_x": detail["pixels_per_cell_x"], "pixels_per_cell_y": detail["pixels_per_cell_y"]})
            crop = detail.get("framebuffer_crop")
            require(isinstance(crop, list) and len(crop) == 4 and crop[2:] == view["pixels"], "Native crop dimensions differ from its receipt")
        require(len({view["id"] for view in views}) == len(views), "Duplicate gallery view identity")
        scenes.append({"id": identity, "title": metadata["title"], "description": metadata["description"],
                       "extent": metadata["extent"], "roles": metadata["provenance"]["plane_roles"], "views": views,
                       "rendering_adapter": str(installed.get("rendering_adapter", "unreported")),
                       "install_report": phases["install"]["url"], "reopen_report": phases["reopen"]["url"],
                       "recipe_url": "godot/data/strata2/" + identity + ".json"})
    engine = report.get("godot", {})
    require(isinstance(engine.get("version"), str) and engine["version"].startswith("4.7.")
            and HASH.fullmatch(str(engine.get("sha256", ""))), "Missing exact Godot 4.7 identity")
    runtime = report.get("runtime", {})
    runtime_bytes = {}
    for kind in ("cybersand_runtime", "rapier_runtime"):
        item = runtime.get(kind, {})
        require(isinstance(item.get("path"), str) and HASH.fullmatch(str(item.get("sha256", ""))), "Missing exact runtime identity")
        runtime_bytes[kind] = {"path": item["path"], "sha256": item["sha256"]}
    return {"schema": "strata2-offline-native-gallery-v1", "draft_hold": True, "source_commit": source_sha,
            "source_tree": report["source_tree"], "godot": {"version": engine["version"], "sha256": engine["sha256"]},
            "runtime": runtime_bytes, "runtime_source_commit": runtime.get("runtime_source_commit", ""),
            "qualification_report": prefix + "/qualification.json", "qualification_report_sha256": sha(report_path.read_bytes()),
            "source_inputs_sha256": source_hashes, "capture_inputs_sha256": dict(sorted(used.items())),
            "inputs_receipt": output.with_suffix(".inputs.json").name, "scenes": scenes,
            "scope": "Actual hosted Windows Godot ordinary Workbench captures. Physical Windows/NVIDIA appearance, interaction and performance acceptance remains pending."}


STYLE = r"""
:root{color-scheme:dark;--ink:#e9f0ed;--muted:#9eafad;--base:#080e13;--panel:#101b22;--line:#283a42;--accent:#7be4cf;--warm:#f5b96a}*{box-sizing:border-box}body{margin:0;background:var(--base);color:var(--ink);font:15px/1.55 system-ui,Segoe UI,sans-serif}a{color:var(--accent)}button{font:inherit;color:inherit;cursor:pointer}button:focus-visible,a:focus-visible,select:focus-visible{outline:3px solid var(--warm);outline-offset:3px}.shell{max-width:1480px;margin:auto;padding:30px clamp(18px,4vw,64px) 64px}.eyebrow{text-transform:uppercase;letter-spacing:.19em;font-size:12px;color:var(--accent);font-weight:700}.mast{display:flex;gap:24px;justify-content:space-between;align-items:start;padding-bottom:28px;border-bottom:1px solid var(--line)}h1{font-size:clamp(30px,4.4vw,60px);line-height:1.06;max-width:800px;margin:18px 0}h2{font-size:26px;line-height:1.2;margin:0}p{margin:.7em 0;color:var(--muted)}.intro{max-width:740px}.pill{display:inline-block;border:1px solid #79613c;color:var(--warm);border-radius:99px;padding:5px 11px;font-size:12px;white-space:nowrap}.launch{max-width:300px;padding-top:14px;font-size:13px}.launch strong{color:var(--ink)}.launch a{margin-right:14px}.viewer{margin-top:30px;border:1px solid var(--line);background:var(--panel);border-radius:16px;overflow:hidden}.viewer-head{display:flex;justify-content:space-between;gap:20px;padding:22px 24px 12px}.extent{color:var(--accent);font:12px/1.6 ui-monospace,Consolas,monospace;white-space:nowrap}.controls{display:flex;gap:7px;flex-wrap:wrap;padding:0 24px 14px}.controls button,.sizing{background:#182830;border:1px solid #32474e;border-radius:6px;padding:7px 12px;font-size:13px}.controls button[aria-pressed=true]{background:var(--accent);color:#0a2929;border-color:var(--accent)}.secondary{display:flex;gap:14px;justify-content:space-between;align-items:center;flex-wrap:wrap;padding:0 24px 16px}.compare{display:flex;gap:6px;align-items:center;flex-wrap:wrap}.compare label{color:var(--muted);font-size:12px;margin-right:4px}.compare button{background:transparent;border:1px solid var(--line);padding:6px 10px;border-radius:5px;font-size:12px}.compare button[aria-pressed=true]{border-color:var(--warm);color:var(--warm)}select{background:#111d24;color:var(--ink);font:inherit;border:1px solid #32474e;border-radius:6px;padding:6px;max-width:100%}.viewport{background:#04090d;border-top:1px solid var(--line);border-bottom:1px solid var(--line);overflow:auto;max-height:85vh;text-align:center}.viewport img{display:block;width:100%;height:auto;image-rendering:pixelated;margin:auto}.viewport.actual img{width:auto;max-width:none;margin:0}.caption{padding:17px 24px 20px;display:grid;grid-template-columns:1fr auto;gap:20px}.caption p{font-size:13px;margin:4px 0}.caption strong{font-size:15px}.caption a{font-size:12px;white-space:nowrap}.gallery-heading{margin:38px 0 18px;display:flex;justify-content:space-between;gap:24px}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(275px,1fr));gap:16px}.card{border:1px solid var(--line);border-radius:12px;overflow:hidden;background:var(--panel);text-align:left;padding:0;transition:border-color .15s,transform .15s}.card:hover{transform:translateY(-2px);border-color:var(--accent)}.card[aria-pressed=true]{border-color:var(--accent)}.card img{display:block;width:100%;aspect-ratio:16/9;object-fit:contain;background:#04090d;image-rendering:pixelated}.card-copy{display:block;padding:14px 16px 17px}.card-copy strong{display:block;font-size:16px}.card-copy small{display:block;color:var(--muted);font-size:12px;margin-top:5px}.legend{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:30px 0}.legend div{border-top:2px solid #36545b;padding-top:10px}.legend strong{font-size:13px}.legend p{font-size:12px}.custody{margin-top:30px;border-top:1px solid var(--line);padding-top:20px}.custody summary{cursor:pointer;color:var(--accent)}.custody pre{white-space:pre-wrap;overflow-wrap:anywhere;font:11px/1.6 ui-monospace,Consolas,monospace;color:var(--muted);max-height:400px;overflow:auto}.notice{margin-top:20px;padding:16px 20px;border-left:3px solid var(--warm);background:#1d1b16;font-size:13px;color:#d3c5ac}.quiet{font-size:12px;color:var(--muted)}@media(max-width:700px){.mast{display:block}.launch{max-width:none}.viewer-head{padding:18px 15px 12px}.controls,.secondary{padding-left:15px;padding-right:15px}.caption{padding:15px;grid-template-columns:1fr}.legend{grid-template-columns:1fr 1fr}.gallery-heading{display:block}.extent{white-space:normal}h2{font-size:22px}}
"""


SCRIPT = r"""
const data=JSON.parse(document.getElementById('gallery-data').textContent);
let sceneIndex=0,currentView='stack',actual=false;
const byId=id=>document.getElementById(id);
function selectView(id){const scene=data.scenes[sceneIndex];const view=scene.views.find(row=>row.id===id);if(!view)return;currentView=id;byId('main-image').src=view.url;byId('main-image').alt=scene.title+' — '+view.label;byId('caption-title').textContent=view.label;byId('caption-text').textContent=view.caption;byId('image-original').href=view.url;byId('image-original').textContent='Open original PNG · '+view.pixels.join(' × ');byId('image-digest').textContent='PNG SHA-256 '+view.image_sha256;document.querySelectorAll('[data-view]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.view===id)));byId('details').value=view.category==='details'?id:'';byId('native-identities').textContent=JSON.stringify(view.native_hashes,null,2);}
function selectScene(index){sceneIndex=index;const scene=data.scenes[index];byId('scene-title').textContent=scene.title;byId('scene-description').textContent=scene.description;byId('scene-extent').textContent=scene.extent.join(' × ')+' native cells';byId('install-receipt').href=scene.install_report;byId('reopen-receipt').href=scene.reopen_report;byId('recipe-link').href=scene.recipe_url;byId('adapter').textContent=scene.rendering_adapter;const picker=byId('details');picker.replaceChildren();const empty=document.createElement('option');empty.value='';empty.textContent='Choose an actual native detail…';picker.append(empty);for(const view of scene.views.filter(v=>v.category==='details')){const option=document.createElement('option');option.value=view.id;option.textContent=view.label;picker.append(option)}document.querySelectorAll('[data-scene]').forEach(button=>button.setAttribute('aria-pressed',String(Number(button.dataset.scene)===index)));selectView('stack');}
document.querySelectorAll('[data-view]').forEach(button=>button.addEventListener('click',()=>selectView(button.dataset.view)));
document.querySelectorAll('[data-scene]').forEach(button=>button.addEventListener('click',()=>{selectScene(Number(button.dataset.scene));byId('viewer').scrollIntoView({behavior:'smooth',block:'start'})}));
byId('details').addEventListener('change',event=>{if(event.target.value)selectView(event.target.value)});
byId('sizing').addEventListener('click',()=>{actual=!actual;byId('viewport').classList.toggle('actual',actual);byId('sizing').textContent=actual?'Image 100% · click to fit':'Fit image · click for 100%';byId('sizing').setAttribute('aria-pressed',String(actual))});
selectScene(0);
"""


def render(data: dict) -> str:
    """Render already validated data without filesystem access or mutation."""
    escape = html.escape
    first = data["scenes"][0]
    encoded = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":")).replace("<", "\\u003c").replace("&", "\\u0026")
    cards = []
    for index, scene in enumerate(data["scenes"]):
        view = scene["views"][0]
        cards.append(f'<button class="card" data-scene="{index}" aria-pressed="{str(index == 0).lower()}"><img loading="lazy" src="{escape(view["url"])}" alt="{escape(scene["title"])} full native stack"><span class="card-copy"><strong>{escape(scene["title"])}</strong><small>{scene["extent"][0]} × {scene["extent"][1]} cells · four separately editable planes</small></span></button>')
    plane_buttons = ''.join(f'<button data-view="{identity}" aria-pressed="{str(identity == "stack").lower()}">{label}</button>' for identity, label in (("stack", "Full stack"), *PLANE_LABELS.items()))
    proof = {key: data[key] for key in ("source_commit", "source_tree", "godot", "runtime", "runtime_source_commit", "qualification_report_sha256")}
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'; base-uri 'none'">
<title>Strata Theatre · Native environment gallery</title><style>{STYLE}</style></head>
<body><div class="shell"><header class="mast"><div><div class="eyebrow">CyberSand / Strata Theatre 002</div>
<h1>Architecture across<br>four planes.</h1><p class="intro">Five editable native environments, captured inside the ordinary Godot Workbench. Inspect the physical Play silhouette, the architecture behind it, and the visual atmosphere that gives the space character.</p>
<span class="pill">DRAFT / HOLD · owner acceptance pending</span></div>
<aside class="launch"><strong>Open the world, then make it yours.</strong><p>Run <strong>Open Workbench.cmd</strong>, open <strong>Strata Theatre → Scenes</strong>, and choose an environment. Layered presentation starts opt-in.</p><a href="READ-ME.md">Evaluation guide</a><a href="OWNER-EVALUATION.md">Record owner findings</a></aside></header>
<main><section id="viewer" class="viewer" aria-label="Actual native capture inspector"><div class="viewer-head"><div><h2 id="scene-title">{escape(first["title"])}</h2><p id="scene-description" class="quiet">{escape(first["description"])}</p></div><span id="scene-extent" class="extent"></span></div>
<div class="controls" aria-label="Inspect native planes">{plane_buttons}</div>
<div class="secondary"><div class="compare" aria-label="Matched visual atmosphere comparison"><label>Matched trial</label><button data-view="atmosphere-off" aria-pressed="false">Atmosphere OFF</button><button data-view="atmosphere-on" aria-pressed="false">Atmosphere ON</button></div><select id="details" aria-label="Choose a native detail"></select><button id="sizing" class="sizing" aria-pressed="false" title="100% means one image pixel per CSS pixel; browser and OS display scaling still apply.">Fit image · click for 100%</button></div>
<div id="viewport" class="viewport"><img id="main-image" src="{escape(first["views"][0]["url"])}" alt="{escape(first["title"])} full native stack"></div>
<div class="caption"><div><strong id="caption-title">Full stack</strong><p id="caption-text"></p><p id="image-digest" class="quiet" style="overflow-wrap:anywhere"></p></div><a id="image-original" href="{escape(first["views"][0]["url"])}">Open original PNG</a></div></section>
<div class="gallery-heading"><h2>Five designed places</h2><p class="quiet">Actual hosted Windows captures · select a scene to inspect</p></div><div class="cards">{''.join(cards)}</div>
<section class="legend" aria-label="Plane ownership"><div><strong>Play</strong><p>The ordinary World, actors and collision. Bright physical geometry remains readable.</p></div><div><strong>Rear architecture</strong><p>Static native structures with their own authored materials and history.</p></div><div><strong>Effects</strong><p>Sparse native accents plus separately authored presentation-only motion.</p></div><div><strong>Background</strong><p>Distant native silhouettes, deliberate openings and controlled parallax.</p></div></section>
<div class="notice"><strong>These are actual Godot captures, not concept art.</strong> The native-plane views exclude visual atmosphere. Atmosphere is shown as matched stills; launch the Workbench to observe motion and pilot the ordinary actor. Hosted rendering does not decide physical Windows/NVIDIA appearance, input response, pacing or subjective playfeel.</div>
<details class="custody"><summary>Executed source, runtime and original receipts</summary><p class="quiet">Source <code>{escape(data["source_commit"])}</code>. All displayed PNG bytes were checked against the original Windows campaign ledger. The portable package manifest covers the gallery and its input receipt.</p><p><a href="{escape(data["qualification_report"])}">Original campaign</a> · <a href="{escape(data["inputs_receipt"])}">Gallery inputs and hashes</a> · <a id="install-receipt" href="{escape(first["install_report"])}">Scene install</a> · <a id="reopen-receipt" href="{escape(first["reopen_report"])}">Fresh-process reopen</a> · <a id="recipe-link" href="{escape(first["recipe_url"])}">Native source recipe</a></p><p class="quiet">Observed hosted rendering adapter: <span id="adapter"></span></p><pre>{escape(json.dumps(proof, indent=2))}</pre><p class="quiet">Native material identities for the selected capture group:</p><pre id="native-identities"></pre></details>
<noscript><p class="notice">Enable local JavaScript for plane and atmosphere controls. The five scene cards and original PNG links remain available without it.</p></noscript></main></div>
<script id="gallery-data" type="application/json">{encoded}</script><script>{SCRIPT}</script></body></html>\n'''


def build(qualification_dir: Path, output: Path, source_sha: str) -> dict:
    data = prepare(qualification_dir, output, source_sha)
    document = render(data)
    inputs = json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    output.write_text(document, encoding="utf-8", newline="\n")
    receipt = output.with_suffix(".inputs.json")
    receipt.write_text(inputs, encoding="utf-8", newline="\n")
    return {"html_sha256": sha(document.encode()), "inputs_sha256": sha(inputs.encode()),
            "source_commit": source_sha, "scenes": len(data["scenes"]),
            "displayed_capture_count": sum(len(scene["views"]) for scene in data["scenes"])}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qualification-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.qualification_dir, args.output, args.source_sha), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
