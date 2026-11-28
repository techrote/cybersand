#!/usr/bin/env python3
"""Render exact native material arrays and separate provenance/transition overlays.

No image generation, invented geometry, smoothing, or application screenshots.
The 132 swatches are read from the unchanged native material catalogue.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import html
import json
from pathlib import Path
import re
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BG = (13, 18, 25)
FG = (223, 230, 239)
MUTED = (145, 161, 179)
ACCENT = (81, 221, 191)
KIND = {"FRAMEWEAVER": (113, 176, 220), "MOSAIC": (220, 175, 111), "RECEPTOR": (135, 195, 151)}
FONTPATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(size):
    try:
        return ImageFont.truetype(FONTPATH, size)
    except OSError:
        return ImageFont.load_default(size=size)


def catalogue():
    text = (ROOT / "native/include/cybersand/material.hpp").read_text()
    entries = re.findall(r'\{"([^\"]+)", MaterialState::\w+, [^,]+, \{(\d+), (\d+), (\d+), (\d+)\}', text)
    if len(entries) != 132:
        raise RuntimeError("Expected the unchanged 132-slot native palette")
    return {i: (name, tuple(map(int, (r, g, b)))) for i, (name, r, g, b, _) in enumerate(entries)}


PALETTE = catalogue()


def raster(cells, request, result=None, mode="material", owner_cells=None):
    w, h = request["width"], request["height"]
    context = request.get("context", [])
    data = []
    roles = result.get("roles", []) if result else []
    provenance = result.get("provenance", []) if result else []
    for i in range(w * h):
        m = cells[i] if i < len(cells) else 0
        fixed = context[i] if i < len(context) else 0
        colour = PALETTE.get(m or fixed, ("", BG))[1] if (m or fixed) else BG
        if mode == "semantic" and m:
            if roles and roles[i] == 4:
                colour = (222, 111, 190)  # non-structural cohesion
            elif roles and roles[i] == 5:
                colour = ACCENT
            else:
                base = KIND[result["gentek"]]
                shift = (provenance[i] * 17 % 37 - 18) if provenance else 0
                colour = tuple(max(0, min(255, c + shift)) for c in base)
        if mode == "transition":
            if request.get("transition") and request["transition"][i] and not (m or fixed):
                colour = (29, 43, 50)
            if request.get("protected") and request["protected"][i]:
                colour = (27, 79, 91) if (i % w + i // w) % 4 < 2 else (18, 49, 61)
        data.append(colour)
    image = Image.new("RGB", (w, h), BG)
    image.putdata(data)
    return image


def overlays(image, requests, results, seams=(), scale=3):
    image = image.copy()
    # Show generator-owned aperture reservations as well as fixture corridors.
    for result in results:
        for i, protected in enumerate(result.get("boundary", {}).get("protected", [])):
            if protected:
                x, y = i % image.width, i // image.width
                image.putpixel((x, y), (27, 79, 91) if (x + y) % 4 < 2 else (18, 49, 61))
    image = image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(image)
    xy = lambda p: (p[0] * scale + scale // 2, p[1] * scale + scale // 2)
    for request, result in zip(requests, results):
        for a in result.get("boundary", {}).get("hard", []):
            if a["family"] == "passage":
                colour = (77, 171, 208)
            elif a["required"]:
                colour = (255, 111, 106)
            else:
                colour = (228, 193, 99)
            start, end = xy(a["a"]), xy(a["b"])
            draw.line((start, end), fill=colour, width=1)
            x, y = start
            draw.rectangle((x - 2, y - 2, x + 2, y + 2), outline=colour)
            direction = a.get("facing", [0, 0])
            draw.line((start, (x + direction[0] * 6, y + direction[1] * 6)), fill=colour)
    for seam in seams:
        if seam["joined"]:
            draw.line([xy(p) for p in seam["cells"]], fill=ACCENT, width=2)
            for p in (seam["a"], seam["b"]):
                x, y = xy(p)
                draw.ellipse((x - 3, y - 3, x + 3, y + 3), outline=ACCENT, width=1)
    return image


def panel(image, title, subtitle, scale=3):
    if image.size == (192, 112):
        image = image.resize((576, 336), Image.Resampling.NEAREST)
    canvas = Image.new("RGB", (image.width + 24, image.height + 72), (20, 27, 36))
    canvas.paste(image, (12, 59))
    draw = ImageDraw.Draw(canvas)
    draw.text((13, 9), title, fill=FG, font=font(17))
    draw.text((13, 33), subtitle, fill=MUTED, font=font(12))
    return canvas


def row(panels, title, subtitle):
    width = sum(x.width for x in panels) + 16 * (len(panels) + 1)
    height = max(x.height for x in panels) + 104
    canvas = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 15), title, fill=FG, font=font(23))
    draw.text((18, 49), subtitle, fill=MUTED, font=font(14))
    x = 16
    for p in panels:
        canvas.paste(p, (x, 82))
        x += p.width + 16
    return canvas


def single_image(case):
    q, r = case["request"], case["result"]
    m = r.get("metrics", {})
    p1 = panel(raster(r["cells"], q), "Native material cells", f"{m.get('occupied_cells', 0)} occupied · {m.get('connected_material_components', 0)} components")
    p2 = panel(raster(r["cells"], q, r, "semantic"), "Instance / role provenance", f"{len(r['instances'])} instances · {m.get('cohesion_cells', 0)} magenta cohesion cells")
    p3 = panel(overlays(raster(r["cells"], q, mode="transition"), [q], [r]), "Affordances and protected space", f"{r['unresolved_joints']} unresolved mandatory · {r['status']}")
    return row([p1, p2, p3], f"{r['gentek']} · {q['fixture']} · {q['profile']['name']}", f"Seed {q['seed']} · source {q['source']} · native palette / no simulation")


def pair_images(case):
    q = case["left_request"]
    a, b = case["left"], case["right"]
    title = f"{a['gentek']} × {b['gentek']} · {case['fixture']} · {q['profile']['name']}"
    sub = f"Seed {q['seed']} · source {q['source']} · fixed 192 × 112 cells"
    panels = [
        panel(raster(case["clipped_cells"], q), "1  Independently generated, clipped", f"{case['clipped_left']['status']} / {case['clipped_right']['status']} · raw control"),
        panel(raster(case["initial_cells"], q), "2  Aware of own territory", f"{case['initial_left']['status']} / {case['initial_right']['status']} · no foreign offers"),
        panel(raster(case["cells"], q), "3  Negotiated transition", f"{case['bridges']} new bridges · {case.get('typed_contacts', 0)} adjacent contacts"),
    ]
    actual = row(panels, title, sub)
    semantic = raster(a["cells"], q, a, "semantic")
    second = raster(b["cells"], case["right_request"], b, "semantic")
    for i, m in enumerate(b["cells"]):
        if m:
            semantic.putpixel((i % q["width"], i // q["width"]), second.getpixel((i % q["width"], i // q["width"])))
    transition = overlays(raster(case["cells"], q, mode="transition"), [q, case["right_request"]], [a, b], case["seams"])
    detail = row([
        panel(raster(case["cells"], q), "Final native material output", f"Hard conflicts {case['conflicts']} · protected violations {case['protected_violations']}"),
        panel(semantic, "Distinct methods / actual provenance", "Blue frame · ochre motifs · green field · magenta cohesion"),
        panel(transition, "Boundary decisions", "Cyan = typed joint · yellow/red = offers · hatch = protected"),
    ], title, sub)
    return actual, detail


def metric_row(path, case):
    if case["type"] == "single":
        q, r = case["request"], case["result"]
        return dict(file=path.name, type="single", gentek=r["gentek"], fixture=q["fixture"], profile=q["profile"]["name"], seed=q["seed"], status=r["status"], occupied=r.get("metrics", {}).get("occupied_cells", 0), instances=len(r["instances"]), work=r["work"], solver_work=r["solver_work"], violations=r["protected_violations"] + r["illegal_overlaps"], bridges=0, contacts=0, bridge_cells=0, unresolved=r["unresolved_joints"], digest=r["material_digest"])
    q, a, b = case["left_request"], case["left"], case["right"]
    return dict(file=path.name, type="pair", gentek=a["gentek"] + " × " + b["gentek"], fixture=case["fixture"], profile=q["profile"]["name"], seed=q["seed"], status=a["status"] + "/" + b["status"], occupied=sum(bool(m) for m in case["cells"]), instances=len(a["instances"]) + len(b["instances"]), work=a["work"] + b["work"] + case["work"], solver_work=(a["solver_work"] + b["solver_work"]) if a["solver_work"] is not None and b["solver_work"] is not None else None, violations=case["conflicts"] + case["protected_violations"] + a["illegal_overlaps"] + b["illegal_overlaps"], bridges=case["bridges"], contacts=case.get("typed_contacts", 0), bridge_cells=case.get("bridge_cells", 0), unresolved=case["unresolved_seams"], digest=case["digest"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    directory = args.directory.resolve()
    files = sorted(directory.glob("*.json"))
    images = directory / "images"
    images.mkdir(exist_ok=True)
    cases, rows, cards = {}, [], []
    for path in files:
        case = json.loads(path.read_text())
        if case.get("type") not in ("single", "pair"):
            continue
        # Keep only the twelve overview inputs; render the full corpus as a stream.
        if (case["type"] == "single" and "_free_" in path.name and "damaged" not in path.name) or (case["type"] == "pair" and "_concave_intrusion_branching_irregular_605" in path.name):
            cases[path.name] = case
        record = metric_row(path, case)
        rows.append(record)
        if case["type"] == "single":
            picture = single_image(case)
            picture.save(images / (path.stem + ".png"))
            more = ""
        else:
            picture, detail = pair_images(case)
            picture.save(images / (path.stem + ".png"))
            detail.save(images / (path.stem + "_overlay.png"))
            more = f'<details><summary>Inspect semantic and boundary overlay</summary><img loading="lazy" src="images/{path.stem}_overlay.png"></details>'
        label = f"{record['gentek']} · {record['fixture']} · {record['profile']} · seed {record['seed']}"
        metadata = f"{record['status']} · {record['occupied']} occupied · {record['instances']} instances · {record['bridges']} new bridges, {record['contacts']} adjacent contacts · {record['unresolved']} unresolved"
        cards.append(f'<section class="card" data-search="{html.escape(label.lower())}"><h2>{html.escape(label)}</h2><p>{html.escape(metadata)}</p><a href="{path.name}">Raw native request, material cells and receipts</a><img loading="lazy" src="images/{path.stem}.png">{more}</section>')

    if not rows:
        raise RuntimeError("No native evidence found")
    with (directory / "metrics.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    totals = defaultdict(lambda: dict(cases=0, with_bridges=0, bridges=0, contacts=0, bridge_cells=0, violations=0, status_counts=Counter()))
    for r in rows:
        t = totals[r["gentek"]]
        t["cases"] += 1
        t["with_bridges"] += r["bridges"] > 0
        t["bridges"] += r["bridges"]
        t["contacts"] += r["contacts"]
        t["bridge_cells"] += r["bridge_cells"]
        t["violations"] += r["violations"]
        t["status_counts"][r["status"]] += 1
    summary = {"scope": "GENTEK-SWARM-001 isolated native research; no product integration or physical support acceptance", "case_count": len(rows), "single_count": sum(r["type"] == "single" for r in rows), "pair_count": sum(r["type"] == "pair" for r in rows), "totals": dict(totals), "palette_source_sha256": hashlib.sha256((ROOT / "native/include/cybersand/material.hpp").read_bytes()).hexdigest(), "metrics": rows}
    (directory / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")

    # Matched-seed, matched-canvas overview: all three primary profiles retained.
    overview_rows = []
    for kind in KIND:
        panels = []
        for pn in ("sparse_regular", "branching_irregular", "dense_cohesive"):
            case = cases.get(f"single_{kind}_free_{pn}.json")
            if not case:
                continue
            q, r = case["request"], case["result"]
            panels.append(panel(raster(r["cells"], q), pn.replace("_", " ").title(), f"{r['metrics'].get('occupied_cells', 0)} cells · {r['metrics'].get('connected_material_components', 0)} components · {r['status']}"))
        if panels:
            overview_rows.append(row(panels, kind, "Same seed 605 and 192 × 112 territory · actual existing material IDs"))
    if overview_rows:
        overview = Image.new("RGB", (max(i.width for i in overview_rows), sum(i.height for i in overview_rows)), BG)
        y = 0
        for im in overview_rows:
            overview.paste(im, (0, y))
            y += im.height
        overview.save(directory / "gentek_comparison.png")

    pair_rows = []
    for a, b in (("FRAMEWEAVER", "MOSAIC"), ("FRAMEWEAVER", "RECEPTOR"), ("MOSAIC", "RECEPTOR")):
        filename = f"pair_{a}_{b}_concave_intrusion_branching_irregular_605.json"
        if filename in cases:
            pair_rows.append(pair_images(cases[filename])[0])
    if pair_rows:
        overview = Image.new("RGB", (max(i.width for i in pair_rows), sum(i.height for i in pair_rows)), BG)
        y = 0
        for im in pair_rows:
            overview.paste(im, (0, y))
            y += im.height
        overview.save(directory / "meshing_comparison.png")

    table = "".join(f"<tr><td>{html.escape(k)}</td><td>{v['cases']}</td><td>{v['with_bridges']}</td><td>{v['bridges']}</td><td>{v['violations']}</td></tr>" for k, v in totals.items())
    document = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>GENTEK-SWARM-001 native research gallery</title>
<style>body{background:#0d1219;color:#dfe6ef;font:16px/1.55 system-ui;margin:0 auto;padding:30px;max-width:1900px}h1{font-size:36px;margin-bottom:8px}h2{font-size:20px}p{color:#a5b5c8}a{color:#51ddbf}img{display:block;max-width:100%;height:auto;margin:14px 0}table{border-collapse:collapse;margin:24px 0}th,td{padding:10px 18px;border-bottom:1px solid #354252;text-align:left}.card{background:#141b24;padding:22px;margin:24px 0;border:1px solid #293849;border-radius:10px}input{position:sticky;top:12px;width:min(900px,90%);padding:15px;background:#203042;color:white;border:1px solid #597387;border-radius:6px;font-size:17px}summary{color:#51ddbf;cursor:pointer}.tag{color:#51ddbf;font-weight:bold}</style>
<header><div class="tag">DRAFT / HOLD · RESEARCH ONLY</div><h1>Three Genteks. Six hostile boundaries.</h1><p>Exact native material arrays, followed by separate semantic overlays. This gallery contains successes, blocked joints, UNSAT results and resource exhaustion. Geometry is not a simulation stability or product acceptance claim.</p><p>Each pair is shown as independent clipped generation → generation aware of its own territory → bounded negotiation. Cyan paths are inspected typed joints; residual boundary offers remain explicit. RECEPTOR declares no mandatory mechanical graph, so zero unresolved mandatory joints is not proof of support.</p><p><a href="metrics.csv">Metrics CSV</a> · <a href="summary.json">Summary and all case identities</a> · <a href="manifest.json">Source and execution manifest</a></p></header>
<table><thead><tr><th>Method / pairing</th><th>Cases</th><th>Cases with new bridges</th><th>New bridges</th><th>Hard violations</th></tr></thead><tbody>''' + table + '''</tbody></table><input id="filter" aria-label="Filter cases" placeholder="Filter by Gentek, fixture, profile or seed…"><main>''' + "\n".join(cards) + '''</main><script>document.querySelector('#filter').addEventListener('input',e=>{const terms=e.target.value.toLowerCase().split(/\\s+/).filter(Boolean);for(const c of document.querySelectorAll('.card'))c.hidden=!terms.every(t=>c.dataset.search.includes(t));});</script></html>'''
    (directory / "index.html").write_text(document)
    print(json.dumps({"cases": len(rows), "totals": totals}, indent=2))


if __name__ == "__main__":
    main()
