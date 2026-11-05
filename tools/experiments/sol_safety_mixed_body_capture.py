#!/usr/bin/env python3
"""Reduce exact shared mixed-body Original/Active World+Rapier captures.

This is evidence reduction only. It does not choose a response policy or alter
the physical fixture. CYPS2 material accounting delegates to la_physical_reduce.
"""
import argparse
import json
import math
import os
import statistics
from pathlib import Path
import la_physical_reduce as physical

EXPECTED_FIRST = {"reference_barrel": 30, "kestrel": 32, "scooper": 2}

def load_report(root: Path):
    found=[]
    for path in sorted(root.rglob("*.json")):
        try:
            data=json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        if data.get("case",{}).get("id")=="shared-granular-bodies" and data.get("initial_payload"):
            found.append((path,data))
    if len(found)!=1:
        raise AssertionError(f"expected one shared-granular-bodies report under {root}, got {len(found)}")
    return found[0]

def rows(step):
    return {int(row["id"]): row for row in step["native_response"]["rows"]}

def finite_tree(value):
    if isinstance(value,float): return math.isfinite(value)
    if isinstance(value,list): return all(finite_tree(x) for x in value)
    if isinstance(value,dict): return all(finite_tree(x) for x in value.values())
    return True

def timing(data):
    keys=("native_tick_us","application_us","rapier_us","simulation_us")
    return {key:{
        "mean":statistics.fmean(float(s[key]) for s in data["steps"]),
        "median":statistics.median(float(s[key]) for s in data["steps"]),
        "maximum":max(float(s[key]) for s in data["steps"])
    } for key in keys}

def ownership(data):
    lifecycle=data.get("lifecycle",[])
    duplicate=any(x.get("duplicate_owner_refused") is True and x.get("native_unchanged") is True
                  and x.get("reset_coupling_retired") is True for x in lifecycle if isinstance(x,dict))
    retired=any(x.get("accepted") is False and "retired_session" in x for x in lifecycle if isinstance(x,dict))
    packets=all(s["native_response"].get("valid") is True and len(s["native_response"].get("rows",[]))==3
                for s in data["steps"])
    accepted=all(s["application"].get("accepted") is True for s in data["steps"])
    return {"duplicate_owner_refusal_preserved_native":duplicate,
            "retired_owner_refused":retired,
            "all_native_packets_valid":packets,
            "all_applications_accepted":accepted}

def first_divergences(original,active):
    models=original["case"]["models"]
    assert models==active["case"]["models"]==["reference_barrel","kestrel","scooper"]
    assert len(original["steps"])==len(active["steps"])
    result=[]
    for body_id,model in enumerate(models,1):
        hit=None
        for so,sa in zip(original["steps"],active["steps"]):
            ro=rows(so)[body_id]; ra=rows(sa)[body_id]
            if ro["passive_accepted_wrench_f64"] != ra["passive_accepted_wrench_f64"]:
                hit=(so,sa,ro,ra)
                break
        if hit is None: raise AssertionError(f"no passive-wrench divergence for {model}")
        so,sa,ro,ra=hit
        step=int(so["step"])
        historical_step=EXPECTED_FIRST[model]
        idx=body_id-1
        bins_o=ro.get("contact_bins"); bins_a=ra.get("contact_bins")
        if not isinstance(bins_o,list) or not isinstance(bins_a,list) or not bins_o or not bins_a:
            raise AssertionError(f"{model} divergence missing diagnostic contact bins")
        state_equal=ro["passive_state_f64"]==ra["passive_state_f64"]
        item={
            "model":model,"body_id":body_id,"step":step,
            "historical_step":historical_step,
            "historical_step_match":step==historical_step,
            "passive_state_equal":state_equal,
            "contact_bins_equal":bins_o==bins_a,
            "original":{
                "contact_bins":bins_o,
                "passive_state_f64":ro["passive_state_f64"],
                "passive_raw_wrench_f64":ro["passive_raw_wrench_f64"],
                "passive_accepted_wrench_f64":ro["passive_accepted_wrench_f64"],
                "legacy_wrench_f64":ro["legacy_wrench_f64"],
                "total_wrench_f64":ro["total_wrench_f64"],
                "normal_raw":ro["normal_raw"],"normal_accepted":ro["normal_accepted"],
                "tangent_raw":ro["tangent_raw"],"tangent_accepted":ro["tangent_accepted"],
                "application":so["application"]["bodies"][idx],
                "live_before_application":so["live_before_application"][idx],
                "after_application":so["after_application"][idx],
                "after_step":so["after_step"][idx],
                "geometry":so["geometry"][idx] if so["geometry"] else None,
            },
            "active":{
                "contact_bins":bins_a,
                "passive_state_f64":ra["passive_state_f64"],
                "passive_raw_wrench_f64":ra["passive_raw_wrench_f64"],
                "passive_accepted_wrench_f64":ra["passive_accepted_wrench_f64"],
                "legacy_wrench_f64":ra["legacy_wrench_f64"],
                "total_wrench_f64":ra["total_wrench_f64"],
                "normal_raw":ra["normal_raw"],"normal_accepted":ra["normal_accepted"],
                "tangent_raw":ra["tangent_raw"],"tangent_accepted":ra["tangent_accepted"],
                "application":sa["application"]["bodies"][idx],
                "live_before_application":sa["live_before_application"][idx],
                "after_application":sa["after_application"][idx],
                "after_step":sa["after_step"][idx],
                "geometry":sa["geometry"][idx] if sa["geometry"] else None,
            },
        }
        item["post_application_kinetic_delta_active_minus_original"] = (
            float(item["active"]["after_application"]["kinetic"])-
            float(item["original"]["after_application"]["kinetic"]))
        item["post_rapier_kinetic_delta_active_minus_original"] = (
            float(item["active"]["after_step"]["kinetic"])-
            float(item["original"]["after_step"]["kinetic"]))
        if not finite_tree(item): raise AssertionError(f"nonfinite captured evidence for {model}")
        result.append(item)
    return result

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--original",type=Path,required=True)
    ap.add_argument("--active",type=Path,required=True)
    ap.add_argument("--output",type=Path,required=True)
    ap.add_argument("--source-sha",default=os.environ.get("GITHUB_SHA",""))
    args=ap.parse_args()
    opath,o=load_report(args.original); apath,a=load_report(args.active)
    if args.source_sha:
        assert o["source"]==a["source"]==args.source_sha
    assert o["steps"][0]["native_response"]["normal_policy"]=="original"
    assert a["steps"][0]["native_response"]["normal_policy"]=="active-normal-001"
    assert o["case"]==a["case"]
    physics_keys=("bodies","geometry","states")
    assert all(o["initial_sample"][k]==a["initial_sample"][k] for k in physics_keys), \
        "policy arms did not start from the same packed physical sample"
    assert o["initial_geometry"]==a["initial_geometry"],"policy arms did not start from same observed geometry"
    assert not o["failures"] and not a["failures"]

    ro=physical.report(opath); ra=physical.report(apath)
    for name,reduced in (("original",ro),("active",ra)):
        assert reduced["material_source_ledger_closes"] is True,(name,"material ledger")
        assert reduced["closed_tuple_multiset_equal"] is True,(name,"closed tuple multiset")
        assert reduced["initial"]["material_counts"]==reduced["final"]["material_counts"],(name,"material counts")
        assert reduced["max_RID_readback_error"]<=1e-5,(name,"RID application readback")
    assert ro["initial"]["material_counts"]==ra["initial"]["material_counts"]
    assert ro["initial"]["tuple_multiset"]==ra["initial"]["tuple_multiset"]

    owner_o=ownership(o);owner_a=ownership(a)
    assert all(owner_o.values()) and all(owner_a.values()),(owner_o,owner_a)
    divergences=first_divergences(o,a)
    result={
        "schema":"SOL-SAFETY-MIXED-BODY-CAPTURE-001",
        "source_sha":o["source"],
        "case":o["case"]["id"],
        "models":o["case"]["models"],
        "steps":len(o["steps"]),
        "material":{
            "initial_counts":ro["initial"]["material_counts"],
            "original_final_counts":ro["final"]["material_counts"],
            "active_final_counts":ra["final"]["material_counts"],
            "original_tuple_multiset_equal":ro["closed_tuple_multiset_equal"],
            "active_tuple_multiset_equal":ra["closed_tuple_multiset_equal"],
            "original_ledger_closes":ro["material_source_ledger_closes"],
            "active_ledger_closes":ra["material_source_ledger_closes"],
        },
        "ownership":{"original":owner_o,"active":owner_a},
        "timing":{"original":timing(o),"active":timing(a)},
        "first_divergences":divergences,
        "all_historical_steps_match":all(x["historical_step_match"] for x in divergences),
        "all_first_passive_states_equal":all(x["passive_state_equal"] for x in divergences),
        "all_first_contact_bins_equal":all(x["contact_bins_equal"] for x in divergences),
        "interpretation":"Captured actual World/Rapier first response divergences. Historical step, copied-state and contact-bin equality are reported rather than forced so platform-specific prior trajectory divergence remains evidence instead of being hidden by a gate. No two-solve selector or threshold relaxation is evaluated.",
        "reports":{"original":str(opath),"active":str(apath)},
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("SOL_SAFETY_MIXED_BODY_CAPTURE",
          " ".join(f"{x['model']}={x['step']}" for x in divergences),
          f"bins_equal={result['all_first_contact_bins_equal']}",
          f"materials={result['material']['initial_counts']}")
if __name__=="__main__": main()
