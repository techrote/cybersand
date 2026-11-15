"""Compare two actual native, resident-d1 worm episodes; never invent missing arms."""
from __future__ import annotations
import argparse
import json
from pathlib import Path

MODES = ("free", "soft")


def compare(reports, traces):
    if set(reports) != set(MODES) or set(traces) != set(MODES):
        return {
            "status": "INCOMPLETE",
            "missing_modes": sorted(set(MODES) - (set(reports) & set(traces))),
            "conclusion": "No paired native worm result without both original arms",
        }
    if len({r["source_sha"] for r in reports.values()}) != 1:
        raise ValueError("Different source commit across actual worm arms")
    if len({r["initial_world_sha256"] for r in reports.values()}) != 1:
        raise ValueError("Different original native World across worm arms")
    if len({r["initial_host_legal_catalog_sha256"] for r in reports.values()}) != 1:
        raise ValueError("Different original host legal movement catalog")
    if not all(r["independent_native_replay"] and
               r["source_fenced_m1_valid"] and
               r["original_model_process_reaped"] for r in reports.values()):
        raise ValueError("Missing native material custody, M1 validity or Q8 cleanup")
    if not all(r["status"] in ("PASS","VALID_NO_INK") for r in reports.values()):
        raise ValueError("Original native worm arm not source-admitted")
    if any(not traces[m] for m in MODES):
        raise ValueError("No original resident model decision for worm")
    a, b = (traces[m] for m in MODES)
    shared = min(len(a),len(b))
    first_choice = first_effect = first_unmatched = None
    for i in range(shared):
        x,y = a[i],b[i]
        matched = (
            x["source_world_sha256"] == y["source_world_sha256"]
            and x["cursor_before"] == y["cursor_before"]
            and x["host_legal_sha256"] == y["host_legal_sha256"]
            and x["candidate_ids"] == y["candidate_ids"]
        )
        if not matched and first_unmatched is None:
            first_unmatched = i
        if matched and x["choice"] != y["choice"] and first_choice is None:
            first_choice = i
        if (x["cursor_after"],x["world_after_sha256"]) != (
                y["cursor_after"],y["world_after_sha256"]):
            if first_effect is None:
                first_effect = i
    if first_effect is None and len(a) != len(b):
        first_effect = shared
    return {
        "schema": "driv3r-wormbrain-native-pilot-pair/1",
        "status": "NATIVE_WORM_PAIR_SOURCE_VERIFIED",
        "source_sha": reports["free"]["source_sha"],
        "same_initial_native_world": True,
        "same_initial_host_legal_catalog": True,
        "first_choice_divergence_on_matched_world": first_choice,
        "first_consequential_native_divergence": first_effect,
        "first_unmatched_input_state": first_unmatched,
        "after_divergence_legal_candidate_equality": "NOT_ASSERTED",
        "original_episodes": {mode: {
            "status":r["status"],"model_decisions":r["model_decisions"],
            "actual_native_ink_cells":r["native_painted_cells"],
            "material_preserving_backtracks":r["brush_up_recoveries"],
            "termination":r["termination"],
            "original_material_sha256":r["final_world_sha256"],
            "real_native_replay":r["independent_native_replay"],
            "material_derived_gallery":r["material_derived_gallery"],
            "elapsed_seconds":r["elapsed_seconds"],
        } for mode,r in reports.items()},
        "assessment": (
            "Real model-selected native steering, not a pathfinding challenge. "
            "Observe gallery material traces before assessing character or quality."
        ),
        "limitations": [
            "One seed, two guidance arms: no population or artistic superiority claim.",
            "STOP and no-ink results remain genuine data, not retried automatically.",
            "Gallery PNG/GIF are derived native material, not framebuffer screenshots.",
            "Free versus soft differences are exploratory, not calibrated neural steering.",
        ],
    }


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--root",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args()
    reports={}
    traces={}
    for mode in MODES:
        root=a.root/mode/"execution"
        s=root/"execution/summary.json"
        t=root/"original-decisions.json"
        if not s.is_file() or not t.is_file():
            continue
        r=json.loads(s.read_text())
        if r.get("mode") != mode:
            continue
        reports[mode]=r
        traces[mode]=json.loads(t.read_text())
    result=compare(reports,traces)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,sort_keys=True,indent=2)+"\n")
    print(json.dumps({k:v for k,v in result.items() if k in (
        "status","source_sha","missing_modes","first_choice_divergence_on_matched_world",
        "first_consequential_native_divergence")},sort_keys=True))
    if result["status"]!="NATIVE_WORM_PAIR_SOURCE_VERIFIED":
        raise SystemExit(2)


if __name__=="__main__":
    main()
