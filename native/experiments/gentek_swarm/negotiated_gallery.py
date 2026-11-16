#!/usr/bin/env python3
"""Exact material-cell SWARM-002 comparisons, counterfactuals and decision overlays."""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw
from gallery import BG, FG, MUTED, PALETTE, font, panel, raster

CATEGORIES = ["exterior", "vault", "gallery", "shaft", "crossing", "arch_left", "arch_right", "rib", "buttress", "termination_west", "termination_east", "termination_north", "termination_south", "portal_west", "portal_east", "solid"]
COLORS = {"frame": (116, 180, 225), "planned frame endings": (245, 194, 89), "mosaic": (210, 161, 110), "shared final joins": (71, 231, 203), "receptor residual": (232, 112, 195), "context": (103, 111, 125)}
def cats(mask):
    return ", ".join(f"{i}:{name}" for i, name in enumerate(CATEGORIES) if mask & (1 << i)) or "EMPTY"
def metric(n, key):
    return n["metrics"].get(key, 0)
def mode(n):
    return n.get("offer_policy", "pilot-policy-unrecorded")
def semantic(n):
    q=n["frame_request"]; image=Image.new("RGB", (q["width"],q["height"]), BG);data=[]
    for i,c in enumerate(n["finished_cells"]):
        color=BG
        if c:
            if n["residual"]["cells"][i]:color=COLORS["receptor residual"]
            elif not n["planned_cells"][i]:color=COLORS["shared final joins"]
            elif n["frame"]["result"]["cells"][i]:color=COLORS["frame"] if n["frame"]["core"]["cells"][i] else COLORS["planned frame endings"]
            elif n["mosaic"]["result"]["cells"][i]:color=COLORS["mosaic"]
            else:color=COLORS["context"]
        if q["protected"][i]:color=(27,79,91) if (i%q["width"]+i//q["width"])%4<2 else (18,49,61)
        data.append(color)
    image.putdata(data);return image
def decisions(n):
    q=n["frame_request"];scale=3;image=raster(n["cells"],q).resize((q["width"]*scale,q["height"]*scale),Image.Resampling.NEAREST)
    draw=ImageDraw.Draw(image);xy=lambda p:(p[0]*scale+1,p[1]*scale+1)
    slots={s["id"]:i+1 for i,s in enumerate(n["frame"]["slots"])}
    for d in n["mosaic"]["domains"]:
        if not d["influences"]:continue
        x,y=xy(d["origin"]);draw.rectangle((x,y,x+47,y+47),outline=(189,144,255),width=2)
        before=n["no_offers"]["categories"][d["tile"]] if d["tile"]<len(n["no_offers"]["categories"]) else -1
        label=f"{before}>{d['selected']}";draw.rectangle((x+1,y+1,x+46,y+15),fill=BG);draw.text((x+3,y+1),label,fill=(220,190,255),font=font(10))
    for s in n["frame"]["slots"]:
        a,b=xy(s["a"]),xy(s["b"]);color=COLORS["planned frame endings"]
        draw.line((a,b),fill=color,width=2);x,y=a;draw.ellipse((x-3,y-3,x+3,y+3),outline=color,width=2)
        draw.line((a,(x+s["facing"][0]*12,y+s["facing"][1]*12)),fill=color,width=2)
        draw.text((x+4,y+3),f"S{slots[s['id']]}",fill=color,font=font(11),stroke_width=1,stroke_fill=BG)
    for r in n["mosaic"]["responses"]:
        if not r["admitted"]:continue
        s=next(s for s in n["frame"]["slots"] if s["id"]==r["slot_id"])
        draw.line((xy(s["a"]),xy(r["contact"])),fill=(196,160,230),width=1)
    for seam in n["seams"]:
        if seam["joined"]:draw.line([xy(p) for p in seam["cells"]],fill=COLORS["shared final joins"],width=2)
    return image
def grid(panels, title, subtitle, columns=3):
    gap=16;pw=max(p.width for p in panels);ph=max(p.height for p in panels);rows=(len(panels)+columns-1)//columns
    image=Image.new("RGB",(gap+(pw+gap)*columns,100+(ph+gap)*rows),BG);draw=ImageDraw.Draw(image)
    draw.text((18,14),title,fill=FG,font=font(23));draw.text((18,50),subtitle,fill=MUTED,font=font(14))
    for i,p in enumerate(panels):image.paste(p,(gap+(i%columns)*(pw+gap),86+(i//columns)*(ph+gap)))
    return image
def images(n):
    q=n["frame_request"];b=n["control"];m=n["metrics"];title=f"{q['fixture']} / {q['profile']['name']} / seed {q['seed']} / {mode(n)}"
    subtitle=f"SWARM-002 | source {q['source']} | exact 192 x 112 native material cells, no simulation"
    panels=[
        panel(raster(b["clipped_cells"],q),"A  Independent generation + clipping",f"{b['clipped_left']['status']} / {b['clipped_right']['status']}"),
        panel(raster(b["cells"],q),"B  SWARM-001 post-hoc meshing",f"{m['control_joined_interfaces']} joints | {m['control_posthoc_cells']} added cells ({b['bridge_cells']} shared)"),
        panel(raster(n["cells"],q),"C  Preplanned negotiated boundary",f"{m.get('joined_slots',0)} joints | {m.get('candidate_posthoc_cells',0)} post-hoc cells | {n['mosaic']['result']['status']}"),
        panel(raster(n["finished_cells"],q),"D  C + optional residual RECEPTOR",f"{m.get('receptor_cells',0)} residual cells | {'enabled' if m.get('receptor_enabled') else 'withheld / disabled'}"),
        panel(semantic(n),"Separate authorship and stages","Blue frame / gold endings / tan masonry / cyan joins / pink residual"),
        panel(decisions(n),"Reservation and domain decisions",f"S# offer -> purple tile: no-offer category > selected | cyan joint"),
    ]
    comparison=grid(panels,title,subtitle)
    causal=grid([
        panel(raster(n["no_offer_cells"],q),"Same frame; MOSAIC receives no offers",f"MOSAIC {n['no_offers']['result']['status']} | same seed, masks, vocabulary"),
        panel(raster(n["planned_cells"],q),"Preplanned result before shared joins",f"{m.get('causally_changed_tiles',0)} affected tiles select a different category"),
        panel(raster(n["cells"],q),"After minimal shared join validation",f"{m.get('shared_bridge_cells',0)} new shared cells | {m.get('direct_contacts',0)} direct contacts")
    ],title+" / causal ablation",subtitle)
    return comparison,causal
def summary(cases):
    groups=defaultdict(list)
    for name,n in cases:groups[(mode(n),n["frame_request"]["fixture"])].append((name,n))
    rows=[]
    for (policy,fixture),items in sorted(groups.items()):
        row={"policy":policy,"fixture":fixture,"cases":len(items)}
        for key in ("offered_slots","admitted_slots","selected_compatible_slots","causally_changed_tiles","domain_changed_tiles","joined_slots","direct_contacts","control_posthoc_cells","candidate_posthoc_cells","control_bridge_cells","shared_bridge_cells","frame_preplanned_addition_cells","unresolved_mandatory_connectors","control_unresolved_mandatory","protected_violations","illegal_overlaps","receptor_cells"):
            row[key]=sum(metric(n,key) for _,n in items)
        row["unsat"]=sum(n["mosaic"]["result"]["status"]=="unsat" for _,n in items)
        row["exhausted"]=sum(n["mosaic"]["result"]["status"]=="exhausted" for _,n in items)
        row["control_unsat"]=sum(n["control"]["right"]["status"]=="unsat" for _,n in items)
        comparable=[n for _,n in items if n["control"]["right"]["status"]=="complete" and n["mosaic"]["result"]["status"]=="complete"]
        row["both_solved_cases"]=len(comparable)
        for key in ("control_posthoc_cells","candidate_posthoc_cells","control_joined_interfaces","joined_slots"):
            row["both_solved_"+key]=sum(metric(n,key) for n in comparable)
        rows.append(row)
    return rows
def decision_table(n):
    rows=[];counter=n["no_offers"]["categories"]
    for d in n["mosaic"]["domains"]:
        if not d["influences"]:continue
        other=counter[d["tile"]] if d["tile"]<len(counter) else -1
        parts=[str(d["tile"]),str(d["origin"]),", ".join(str(i["slot_id"]) for i in d["influences"]),cats(d["original_domain"]),cats(d["preferred_domain"]),cats(d["modified_domain"]),d["selected_name"],CATEGORIES[other] if other>=0 else "unselected",str(d["fallback"])]
        rows.append("<tr>"+"".join(f"<td>{html.escape(x)}</td>" for x in parts)+"</tr>")
    headers=["Tile","Origin","Offer IDs","Original","Preferred","Final admitted","Selected","No offers","Fallback"]
    return "<div class='scroll'><table><tr>"+"".join(f"<th>{h}</th>" for h in headers)+"</tr>"+"".join(rows)+"</table></div>"
def main():
    ap=argparse.ArgumentParser();ap.add_argument("directory",type=Path);args=ap.parse_args();out=args.directory
    cases=[(p.stem,json.loads(p.read_text())) for p in sorted(out.glob("negotiated_*.json")) if p.name!="negotiated_summary.json"]
    if not cases:raise SystemExit("No negotiated cases")
    img=out/"images";img.mkdir(exist_ok=True)
    cards=[];facts=[]
    for name,n in cases:
        comparison,causal=images(n);comparison.save(img/(name+".png"));causal.save(img/(name+"_causal.png"))
        q=n["frame_request"];m=n["metrics"];facts.append({"case":name,"policy":mode(n),"fixture":q["fixture"],"profile":q["profile"]["name"],"seed":q["seed"],"mosaic_status":n["mosaic"]["result"]["status"],"control_mosaic_status":n["control"]["right"]["status"],**m})
        failures=[s["reason"] for s in n["seams"] if not s["joined"]]
        caption=f"{q['fixture']} · {q['profile']['name']} · {q['seed']} · {mode(n)} · MOSAIC {n['mosaic']['result']['status']}"
        cards.append(f"<article data-search='{html.escape(caption)}'><h2>{html.escape(caption)}</h2><p>Offers {m.get('offered_slots',0)}; admitted {m.get('admitted_slots',0)}; selected compatible {m.get('selected_compatible_slots',0)}; joined {m.get('joined_slots',0)}. Unresolved mandatory {m.get('unresolved_mandatory_connectors',0)} (control {m.get('control_unresolved_mandatory',0)}).</p><a href='images/{name}.png'><img loading='lazy' src='images/{name}.png'></a><details><summary>Inspect causal ablation, domains, failures and raw evidence</summary><img loading='lazy' src='images/{name}_causal.png'>{decision_table(n)}<h3>Solver attempts</h3><pre>{html.escape(json.dumps(n['mosaic']['attempts'],indent=2))}</pre><h3>Unresolved interface decisions</h3><pre>{html.escape(chr(10).join(failures) or 'None')}</pre><a href='{name}.json'>Complete exact raw case</a></details></article>")
    fields=sorted(set().union(*(f.keys() for f in facts)))
    with (out/"negotiated_metrics.csv").open("w",newline="") as f:w=csv.DictWriter(f,fields);w.writeheader();w.writerows(facts)
    rows=summary(cases);(out/"negotiated_summary.json").write_text(json.dumps({"cases":len(cases),"rows":rows,"claims":"Facts, not quality scores. Compare successful connections and failures alongside bridge cell counts; human architecture judgment remains required."},indent=2)+"\n")
    columns=["policy","fixture","cases","causally_changed_tiles","joined_slots","unsat","control_posthoc_cells","candidate_posthoc_cells","unresolved_mandatory_connectors"]
    table="<div class='scroll'><table><tr>"+"".join(f"<th>{x.replace('_',' ')}</th>" for x in columns)+"</tr>"+"".join("<tr>"+"".join(f"<td>{r[c]}</td>" for c in columns)+"</tr>" for r in rows)+"</table></div>"
    source=cases[0][1]["frame_request"]["source"]
    page="""<!doctype html><meta charset='utf-8'><title>GENTEK-SWARM-002 research evidence</title><style>body{max-width:1540px;margin:32px auto;padding:0 24px;background:#0d1219;color:#dfe6ef;font:16px system-ui;line-height:1.5}h1{font-size:36px}h2{font-size:22px}a{color:#51ddbf}article{border-top:1px solid #334052;margin:36px 0;padding-top:20px}img{width:100%;height:auto}table{border-collapse:collapse;font-size:13px}td,th{padding:8px;border:1px solid #334052;vertical-align:top}th{background:#182435}.scroll{overflow:auto}details{background:#141b24;padding:16px}summary{cursor:pointer}input{padding:12px;font:inherit;background:#182435;color:white;border:1px solid #526379;min-width:360px}pre{white-space:pre-wrap;overflow-wrap:anywhere}.notice{border-left:4px solid #edc15b;padding:10px 20px;background:#1d2630}</style>"""
    page+=f"<h1>GENTEK-SWARM-002</h1><h2>Preplanned negotiated boundaries</h2><p>Research only · Draft/HOLD · source <code>{source}</code><br>Exact predecessor <code>{cases[0][1]['predecessor']}</code></p><div class='notice'>All {len(cases)} matched cases, including failures, are retained. Material images come directly from native IDs. Gold is FRAMEWEAVER's preplanned terminal geometry; cyan is the shared final join; pink is RECEPTOR residual. A changed category is causal only where the same-frame no-offers ablation selects something different. Lower bridge counts alone do not establish better architecture.</div><p><a href='negotiated_metrics.csv'>Per-case metrics</a> · <a href='negotiated_summary.json'>Aggregate facts with both-solved denominators</a> · <a href='manifest.json'>Source and command custody</a></p>{table}<h2>Matched comparisons and causal evidence</h2><p><input id='filter' placeholder='Filter fixture, profile, hard/soft or status'></p>"+"".join(cards)
    page+="<script>document.getElementById('filter').addEventListener('input',e=>{const s=e.target.value.toLowerCase().split(/\\s+/);document.querySelectorAll('article').forEach(a=>a.hidden=!s.every(x=>a.dataset.search.toLowerCase().includes(x)))})</script>"
    (out/"index.html").write_text(page)
    palette={str(i):{"name":name,"rgb":rgb} for i,(name,rgb) in PALETTE.items()};(out/"material_palette.json").write_text(json.dumps(palette,indent=2)+"\n")
    print(f"Rendered {len(cases)} six-panel comparisons and {len(cases)} causal ablations")
if __name__=="__main__":main()
