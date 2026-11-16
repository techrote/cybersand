#!/usr/bin/env python3
"""Matched native-material evidence for fixed optional-offer admission policies."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import html
import json
from pathlib import Path

from PIL import ImageDraw
from gallery import BG, PALETTE, font, panel, raster
from negotiated_gallery import cats, decisions, grid


def metric(n, key):
    return n["metrics"].get(key, 0)


def first_limit(n):
    return next((a["work_limit"] for a in n["mosaic"]["attempts"] if a["attempted"]), 0)


def case_key(n):
    q = n["frame_request"]
    return f"{q['fixture']}_{q['profile']['name']}_{q['seed']}"


def policy_name(a):
    return (f"cap{a['optional_cap']}" if a["mode"] == "optional-cap"
            else f"drop{a['omitted_optional_id']}" if a["mode"] == "leave-one-out" else "full")


def selected_causal_tiles(n):
    no = n["no_offers"]["categories"]
    return {d["tile"]: d["selected"] for d in n["mosaic"]["domains"]
            if d["influences"] and d["selected"] >= 0 and d["tile"] < len(no)
            and no[d["tile"]] >= 0 and no[d["tile"]] != d["selected"]}


def optional_causal_tiles(n, hard):
    if n["mosaic"]["result"]["status"] != "complete" or hard["mosaic"]["result"]["status"] != "complete":
        return None
    optional = {s["id"] for s in n["frame"]["slots"] if not s["required"] and not s["hard"]}
    categories = hard["mosaic"]["categories"]
    return {d["tile"]: d["selected"] for d in n["mosaic"]["domains"]
            if any(i["slot_id"] in optional and i["admitted"] for i in d["influences"])
            and d["selected"] >= 0 and d["tile"] < len(categories)
            and categories[d["tile"]] >= 0 and categories[d["tile"]] != d["selected"]}


def validate_and_row(path, doc, full, hard):
    n, a = doc["candidate"], doc["admission"]
    if n["frame"] != full["frame"] or n["frame_request"] != full["frame_request"]:
        raise ValueError(f"{path.name}: frozen frame changed")
    if n["control"] != full["control"]:
        raise ValueError(f"{path.name}: B control changed")
    mq, cq = dict(n["mosaic_request"]), dict(full["mosaic_request"])
    if a["diagnostic"]:
        mq["limits"] = dict(mq["limits"])
        mq["limits"]["solver_work"] = cq["limits"]["solver_work"]
    if mq != cq:
        raise ValueError(f"{path.name}: non-admission MOSAIC request change")
    if not a["diagnostic"] and n["no_offers"] != full["no_offers"]:
        raise ValueError(f"{path.name}: no-offer control changed")
    if a["work"] + metric(n, "shared_work") > 2_000_000 or a["work"] + a["join_work_limit"] != 2_000_000:
        raise ValueError(f"{path.name}: aggregate admission/join allowance changed")
    if n["mosaic_request"]["limits"]["solver_work"] != (2_000_000 if a["diagnostic"] else 4_000_000):
        raise ValueError(f"{path.name}: solver ceiling changed")
    if n["finished_cells"] != n["cells"] or metric(n, "receptor_enabled"):
        raise ValueError(f"{path.name}: residual finish entered the comparison")
    for key in ("protected_violations", "illegal_overlaps", "frozen_core_changes", "mosaic_frozen_changes"):
        if metric(n, key):
            raise ValueError(f"{path.name}: {key}")
    full_slots = {s["id"]: s for s in full["frame"]["slots"]}
    selected = set(a["selected_ids"])
    mandatory = {i for i, s in full_slots.items() if s["required"] or s["hard"]}
    if not mandatory <= selected or not selected <= full_slots.keys():
        raise ValueError(f"{path.name}: mandatory retention or selected identity")
    if any(r["slot_id"] not in selected for r in n["mosaic"]["responses"]):
        raise ValueError(f"{path.name}: withheld slot entered the solve")
    joins = {s["left_affordance"] for s in n["seams"] if s["joined"]}
    cjoins = {s["left_affordance"] for s in full["seams"] if s["joined"]}
    if not joins <= selected:
        raise ValueError(f"{path.name}: withheld slot joined")
    domains = {d["tile"]: d for d in n["mosaic"]["domains"]}
    cdomains = {d["tile"]: d for d in full["mosaic"]["domains"]}
    added = removed = changed = 0
    for tile in domains.keys() & cdomains.keys():
        x, y = domains[tile], cdomains[tile]
        if x["original_domain"] != y["original_domain"]:
            raise ValueError(f"{path.name}: original domain changed")
        added += (x["modified_domain"] & ~y["modified_domain"]).bit_count()
        removed += (y["modified_domain"] & ~x["modified_domain"]).bit_count()
        changed += x["selected"] >= 0 and y["selected"] >= 0 and x["selected"] != y["selected"]
    causal = selected_causal_tiles(full)
    retained = sum(t < len(n["mosaic"]["categories"]) and n["mosaic"]["categories"][t] == cat
                   for t, cat in causal.items())
    q = n["frame_request"]
    status, cstatus = n["mosaic"]["result"]["status"], full["mosaic"]["result"]["status"]
    optional_causal = optional_causal_tiles(n, hard)
    c_optional_causal = optional_causal_tiles(full, hard)
    newly_compatible = None
    if status == hard["mosaic"]["result"]["status"] == "complete":
        newly_compatible = 0
        for response in n["mosaic"]["responses"]:
            if response["slot_id"] in mandatory or not response["satisfied"]:
                continue
            tile = response["tile"]
            cat = hard["mosaic"]["categories"][tile] if tile < len(hard["mosaic"]["categories"]) else -1
            x, y = response["contact"]
            material = hard["mosaic"]["result"]["cells"][y * q["width"] + x]
            newly_compatible += cat < 0 or not (response["compatible_domain"] & (1 << cat)) or not material
    return {
        "file": path.name, "case": case_key(n), "fixture": q["fixture"],
        "profile": q["profile"]["name"], "seed": q["seed"], "policy": policy_name(a),
        "lane": "matched-first-budget diagnostic" if a["diagnostic"] else "single-removal diagnostic" if a["mode"] == "leave-one-out" else "hard-only diagnostic" if a["optional_cap"] == 0 else "capped optional policy",
        "budget_mode": a["budget_mode"], "admission_status": a["status"],
        "mosaic_status": status, "full_c_status": cstatus,
        "b_status": full["control"]["right"]["status"],
        "recovered_from_c": cstatus != "complete" and status == "complete",
        "regressed_from_c": cstatus == "complete" and status != "complete",
        "all_offers": len(full_slots), "mandatory_offers": len(mandatory),
        "optional_offers": len(full_slots) - len(mandatory),
        "selected_optional": len(selected - mandatory), "withheld_optional": len(full_slots) - len(selected),
        "selected_ids": ";".join(map(str, sorted(selected))),
        "admitted": metric(n, "admitted_slots"), "compatible": metric(n, "selected_compatible_slots"),
        "joints": len(joins), "full_c_joints": len(cjoins), "retained_c_joint_ids": len(joins & cjoins),
        "new_joint_ids_vs_c": len(joins - cjoins), "b_joints": metric(full, "control_joined_interfaces"),
        "posthoc_cells": metric(n, "candidate_posthoc_cells"),
        "full_c_posthoc_cells": metric(full, "candidate_posthoc_cells"),
        "b_posthoc_cells": metric(full, "control_posthoc_cells"),
        "mandatory_unresolved": metric(n, "unresolved_mandatory_connectors"),
        "full_c_mandatory_unresolved": metric(full, "unresolved_mandatory_connectors"),
        "all_unresolved_slots": metric(n, "unresolved_slots"),
        "full_c_causal_tiles": len(causal), "retained_c_causal_tiles": retained,
        "causal_tiles_vs_no_offers": metric(n, "causally_changed_tiles"),
        "hard_only_status": hard["mosaic"]["result"]["status"],
        "optional_causal_tiles_vs_hard_only": None if optional_causal is None else len(optional_causal),
        "optional_responses_newly_compatible_vs_hard_only": newly_compatible,
        "full_c_optional_causal_tiles_vs_hard_only": None if c_optional_causal is None else len(c_optional_causal),
        "retained_c_optional_causal_tiles": None if c_optional_causal is None else sum(
            t < len(n["mosaic"]["categories"]) and n["mosaic"]["categories"][t] == cat for t, cat in c_optional_causal.items()),
        "optional_joint_ids": len(joins - mandatory),
        "changed_selected_tiles_vs_c": changed,
        "added_domain_alternatives_vs_c": added, "removed_domain_alternatives_vs_c": removed,
        "configured_solver_ceiling": n["mosaic_request"]["limits"]["solver_work"],
        "first_attempt_limit": first_limit(n), "full_c_first_attempt_limit": first_limit(full),
        "first_allocation_changed": first_limit(n) != first_limit(full),
        "solver_attempt_limits": ";".join(str(x["work_limit"]) for x in n["mosaic"]["attempts"]),
        "solver_known_work": metric(n, "solver_known_work"),
        "solver_used_work_available": bool(metric(n, "solver_total_work_available")),
        "admission_charge": a["work"], "ranking_charge": a["ranking_work"],
        "join_allowance": a["join_work_limit"], "join_charge": metric(n, "shared_work"),
        "join_allowance_hit": bool(metric(n, "shared_exhausted")),
        "structural_work_upper_bound": a["structural_work_upper_bound"],
        "observed_generator_plus_admission_work": metric(n, "candidate_generator_work") + a["work"],
        "preplanned_frame_cells": metric(n, "frame_preplanned_addition_cells"),
    }


def aggregate(rows):
    both = [r for r in rows if r["mosaic_status"] == r["full_c_status"] == "complete"]
    hard_both = [r for r in rows if r["mosaic_status"] == r["hard_only_status"] == "complete"]
    return {
        "trials": len(rows), "distinct_cases": len({r["case"] for r in rows}),
        "statuses": dict(sorted(Counter(r["mosaic_status"] for r in rows).items())),
        "recoveries": sum(r["recovered_from_c"] for r in rows),
        "distinct_recovered_cases": len({r["case"] for r in rows if r["recovered_from_c"]}),
        "regressions": sum(r["regressed_from_c"] for r in rows),
        "recoveries_same_first_allocation": sum(r["recovered_from_c"] and not r["first_allocation_changed"] for r in rows),
        "recoveries_changed_first_allocation": sum(r["recovered_from_c"] and r["first_allocation_changed"] for r in rows),
        "all_case_joints": sum(r["joints"] for r in rows),
        "all_case_posthoc_cells": sum(r["posthoc_cells"] for r in rows),
        "all_case_mandatory_unresolved": sum(r["mandatory_unresolved"] for r in rows),
        "join_allowance_hits": sum(r["join_allowance_hit"] for r in rows),
        "both_solved_with_hard_only": {"cases": len(hard_both),
            "optional_causal_tiles": sum(r["optional_causal_tiles_vs_hard_only"] for r in hard_both),
            "newly_compatible_optional_responses": sum(r["optional_responses_newly_compatible_vs_hard_only"] for r in hard_both),
            "optional_joint_ids": sum(r["optional_joint_ids"] for r in hard_both)},
        "both_solved_with_c": {"cases": len(both), **{k: sum(r[k] for r in both) for k in
            ("joints", "full_c_joints", "retained_c_joint_ids", "posthoc_cells", "full_c_posthoc_cells",
             "mandatory_unresolved", "full_c_mandatory_unresolved", "full_c_causal_tiles", "retained_c_causal_tiles")}},
    }


def status_panel(n, title, optional=None):
    q = n["frame_request"]
    caption = f"MOSAIC {n['mosaic']['result']['status']} | {metric(n,'joined_slots')} joints | {metric(n,'candidate_posthoc_cells')} late cells | {metric(n,'unresolved_mandatory_connectors')} mandatory unresolved"
    if optional is not None:
        title += f" ({optional} selected)"
    return panel(raster(n["cells"], q), title, caption)


def selection_overlay(doc):
    n, a = doc["candidate"], doc["admission"]
    image = decisions(n)
    draw = ImageDraw.Draw(image)
    slots = {s["id"]: s for s in n["frame"]["slots"]}
    for decision in a["decisions"]:
        s = slots[decision["slot_id"]]
        p = tuple(v * 3 + 1 for v in s["a"])
        b = tuple(v * 3 + 1 for v in s["b"])
        color = (245, 194, 89) if decision["mandatory"] else (91, 233, 163) if decision["selected"] else (128, 135, 147)
        draw.line((p, b), fill=color, width=3)
        draw.ellipse((p[0]-3, p[1]-3, p[0]+3, p[1]+3), outline=color, width=2)
        label = "R" if decision["mandatory"] else f"o{decision['rank']+1}" + ("" if decision["selected"] else " x")
        draw.text((p[0]+3, p[1]-13), label, fill=color, font=font(11), stroke_width=1, stroke_fill=BG)
    return image


def table(headers, rows):
    return "<div class='scroll'><table><tr>" + "".join(f"<th>{html.escape(str(h))}</th>" for h in headers) + "</tr>" + "".join(
        "<tr>" + "".join(f"<td>{html.escape(str(v))}</td>" for v in row) + "</tr>" for row in rows) + "</table></div>"


def decision_tables(doc, full):
    n, a = doc["candidate"], doc["admission"]
    ranking = table(["Slot", "Mandatory", "Optional rank", "Selected", "Prospective witness", "Distance", "Reason"],
                    [[d["slot_id"], d["mandatory"], d["rank"], d["selected"], d["witness_peer"] if d["witness_found"] else "none",
                      d["nearest_forward_distance"], d["reason"]] for d in a["decisions"]])
    old = {d["tile"]: d for d in full["mosaic"]["domains"]}
    records = []
    for d in n["mosaic"]["domains"]:
        c = old.get(d["tile"])
        if not c or not (d["influences"] or c["influences"]):
            continue
        records.append([d["tile"], ",".join(str(i["slot_id"]) for i in d["influences"]),
                        cats(d["original_domain"]), cats(c["modified_domain"]), cats(d["modified_domain"]),
                        cats(d["modified_domain"] & ~c["modified_domain"]), cats(c["modified_domain"] & ~d["modified_domain"]),
                        c["selected_name"], d["selected_name"]])
    return ranking + table(["Tile", "Selected offer IDs", "Original", "Full C final", "Variant final",
                            "Added alternatives", "Removed alternatives", "C selection", "Variant selection"], records)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    out = args.directory
    controls = {case_key(n): n for p in sorted((out / "controls-c").glob("full_control_*.json"))
                for n in [json.loads(p.read_text())]}
    documents, rows = {}, []
    hard_key, hard = None, None
    for path in sorted(out.glob("admission_*.json")):
        if path.name == "admission_summary.json":
            continue
        doc = json.loads(path.read_text())
        if doc.get("schema") != 3 or doc.get("type") != "optional_offer_admission":
            raise ValueError(f"Unexpected admission record {path}")
        full = controls[case_key(doc["candidate"])]
        key = case_key(doc["candidate"])
        if key != hard_key:
            hard = json.loads((out / f"admission_{key}_cap0.json").read_text())["candidate"]
            hard_key = key
        rows.append(validate_and_row(path, doc, full, hard))
        # Keep paths rather than every large material record resident at once.
        documents[path.name] = path
    primary = [r for r in rows if r["budget_mode"] == "primary" and r["policy"].startswith("cap")]
    if len(controls) not in (6, 36) or len(primary) != len(controls) * 4:
        raise ValueError("Incomplete registered cap matrix")
    by_case = defaultdict(dict)
    for row in primary:
        if row["policy"] in by_case[row["case"]]:
            raise ValueError("Duplicate registered cap result")
        by_case[row["case"]][row["policy"]] = row
    for key, group in by_case.items():
        if set(group) != {"cap0", "cap1", "cap2", "cap4"}:
            raise ValueError(f"Incomplete caps in {key}")
    common = {key for key, group in by_case.items()
              if all(group[p]["mosaic_status"] == group[p]["full_c_status"] == group[p]["b_status"] == "complete"
                     for p in ("cap1", "cap2", "cap4"))}
    diagnostic_rows = [r for r in rows if r["budget_mode"] != "primary"]
    summary = {
        "source": next(iter(controls.values()))["frame_request"]["source"],
        "frozen_c_source": "21617b14253cc6dcf35a83ded558565c8db517f5",
        "matched_cases": len(controls), "registered_cap_cases": len(primary),
        "primary_policy_cases": sum(r["policy"] in ("cap1", "cap2", "cap4") for r in primary),
        "hard_only_diagnostic_cases": sum(r["policy"] == "cap0" for r in primary),
        "full_c_statuses": dict(Counter(n["mosaic"]["result"]["status"] for n in controls.values())),
        "b_statuses": dict(Counter(n["control"]["right"]["status"] for n in controls.values())),
        "policies": {p: aggregate([r for r in primary if r["policy"] == p]) for p in ("cap0", "cap1", "cap2", "cap4")},
        "fixtures": {f: {p: aggregate([r for r in primary if r["fixture"] == f and r["policy"] == p])
                          for p in ("cap0", "cap1", "cap2", "cap4")} for f in sorted({r["fixture"] for r in primary})},
        "leave_one_out": aggregate([r for r in rows if r["budget_mode"] == "primary" and r["policy"].startswith("drop")]),
        "budget_diagnostics": aggregate(diagnostic_rows),
        "budget_diagnostic_rows": diagnostic_rows,
        "common_primary_success_cases": sorted(common),
        "common_primary_success": {p: aggregate([r for r in primary if r["policy"] == p and r["case"] in common])
                                   for p in ("cap1", "cap2", "cap4")},
        "claims": "Matched interventions, not independent worlds. Withheld slots remain unresolved opportunities. Admission can add and remove category alternatives. No per-case best-cap policy is selected. Primary ceilings fixed; lower-only budget diagnostics excluded from primary counts.",
    }
    (out / "admission_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    with (out / "admission_metrics.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    images = out / "images"
    images.mkdir(exist_ok=True)
    cards = []
    for key in sorted(controls):
        full, group = controls[key], by_case[key]
        related = [r for r in rows if r["case"] == key]
        case_documents = {r["file"]: json.loads(documents[r["file"]].read_text()) for r in related}
        q = full["frame_request"]
        title = f"{q['fixture']} / {q['profile']['name']} / seed {q['seed']}"
        subtitle = f"Optional-offer admission | source {q['source']} | exact native cells; all mandatory offers retained"
        panels = [panel(raster(full["control"]["cells"], q), "B  SWARM-001", f"MOSAIC {full['control']['right']['status']} | {metric(full,'control_joined_interfaces')} joints | {metric(full,'control_posthoc_cells')} late cells"),
                  status_panel(full, "C  All original offers")]
        for cap in (0, 1, 2, 4):
            row = group[f"cap{cap}"]
            panels.append(status_panel(case_documents[row["file"]]["candidate"], f"Cap {cap} optional + all mandatory", row["selected_optional"]))
        comparison_name = f"comparison_{key}.png"
        grid(panels, title, subtitle).save(images / comparison_name)
        overlay_name = f"offers_{key}.png"
        grid([panel(selection_overlay(case_documents[group[f'cap{cap}']["file"]]), f"Cap {cap}: retained / withheld offers",
                    "Gold mandatory | green selected optional | grey withheld | purple affected tile") for cap in (1, 2, 4)],
             title + " / admission decisions", subtitle).save(images / overlay_name)
        details = []
        for row in related:
            doc = case_documents[row["file"]]
            extra = ""
            if row["policy"].startswith("drop") or row["budget_mode"] != "primary":
                trial_image = Path(row["file"]).stem + ".png"
                n = doc["candidate"]
                grid([status_panel(full, "C  All original offers"),
                      panel(raster(n["planned_cells"], q), "Variant before shared joins", f"{row['policy']} | {row['budget_mode']} | MOSAIC {row['mosaic_status']}"),
                      status_panel(n, "Variant after validated joining")],
                     title + " / " + row["policy"], subtitle).save(images / trial_image)
                extra = f"<a href='images/{trial_image}'><img loading='lazy' src='images/{trial_image}'></a>"
            details.append(f"<details><summary>{html.escape(row['policy'])} / {row['lane']} / MOSAIC {row['mosaic_status']} / {row['joints']} joints</summary>"
                           f"<p>First attempt {row['first_attempt_limit']:,}; full C {row['full_c_first_attempt_limit']:,}. Admission charge {row['admission_charge']:,}; join allowance {row['join_allowance']:,}; actual join charge {row['join_charge']:,}.</p>"
                           + extra + decision_tables(doc, full) + "<h4>Solver receipts</h4><pre>" + html.escape(json.dumps(doc["candidate"]["mosaic"]["attempts"], indent=2))
                           + f"</pre><a href='{row['file']}'>Exact raw variant</a></details>")
        cards.append(f"<article data-search='{html.escape(title)}'><h2>{html.escape(title)}</h2><a href='images/{comparison_name}'><img loading='lazy' src='images/{comparison_name}'></a>"
                     f"<details><summary>Inspect offer decisions and every retained variant</summary><img loading='lazy' src='images/{overlay_name}'>"
                     + "".join(details) + f"<a href='controls-c/full_control_{key}.json'>Full C control</a></details></article>")
    overview = table(["Policy", "Trials", "Complete", "UNSAT", "Exhausted", "Recoveries", "Regressions", "Joints (all cases)"],
                     [[p, s["trials"], s["statuses"].get("complete", 0), s["statuses"].get("unsat", 0), s["statuses"].get("exhausted", 0),
                       s["recoveries"], s["regressions"], s["all_case_joints"]] for p, s in summary["policies"].items()])
    page = """<!doctype html><meta charset='utf-8'><title>SWARM-002 optional-offer experiment</title><style>body{max-width:1540px;margin:32px auto;padding:0 24px;background:#0d1219;color:#dfe6ef;font:16px system-ui;line-height:1.5}h1{font-size:34px}h2{font-size:22px}a{color:#51ddbf}article{border-top:1px solid #334052;margin:36px 0;padding-top:20px}img{width:100%;height:auto}table{border-collapse:collapse;font-size:13px}td,th{padding:8px;border:1px solid #334052;vertical-align:top}th{background:#182435}.scroll{overflow:auto}details{background:#141b24;padding:16px;margin:8px 0}summary{cursor:pointer}input{padding:12px;font:inherit;background:#182435;color:white;border:1px solid #526379;min-width:360px}pre{white-space:pre-wrap;overflow-wrap:anywhere}.notice{border-left:4px solid #edc15b;padding:10px 20px;background:#1d2630}</style>"""
    page += f"<h1>SWARM-002: bounded optional-offer admission</h1><p>Draft/HOLD · {html.escape(summary['source'])}</p><div class='notice'>All mandatory sockets stay hard. Frame geometry, the full offer universe, protected masks, native vocabulary and primary request ceilings are unchanged. Cap 0 is a hard-only diagnostic. Single-offer removals are registered only on original full-C failures. No per-case best-cap selection. MOSAIC complete does not imply all frame connectors resolve. Domain changes can add and remove alternatives; fewer offers are not necessarily fewer constraints.</div><p><a href='admission_metrics.csv'>Every trial and budget receipt</a> · <a href='admission_summary.json'>Matched aggregates</a> · <a href='manifest.json'>Exact-source qualification</a> · <a href='control-qualification/index.html'>Original C/A/B/D regression gallery</a></p>{overview}<p>Lower-only 2M diagnostics are separate: {len(diagnostic_rows)} trials. Their outcomes and all single-removal cases are retained in the expandable tables. Fixed shared allowance includes admission charge; a lower join allowance is reported if it binds.</p><input id='filter' placeholder='Filter fixture, profile or seed'>" + "".join(cards)
    page += "<script>document.getElementById('filter').addEventListener('input',e=>{const s=e.target.value.toLowerCase().split(/\\s+/);document.querySelectorAll('article').forEach(a=>a.hidden=!s.every(x=>a.dataset.search.toLowerCase().includes(x)))})</script>"
    (out / "index.html").write_text(page)
    (out / "material_palette.json").write_text(json.dumps({str(i): {"name": n, "rgb": rgb} for i, (n, rgb) in PALETTE.items()}, indent=2) + "\n")
    print(f"Retained {len(rows)} trials, {len(controls)} full C controls, and {len(list(images.glob('*.png')))} matched comparison/decision/diagnostic PNGs")


if __name__ == "__main__":
    main()
