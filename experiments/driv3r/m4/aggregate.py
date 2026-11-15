"""Cross-arm audit of *original* native M4 summaries, never synthetic outcomes.

Comparison is meaningful only at matched native source World states and
identical host-legal candidate catalog IDs/effects. After first divergent
choice, legality is independently recomputed for each arm's resulting World.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ARMS=("A1","A2","A3")


def compare(summaries:dict)->dict:
    if set(summaries)!=set(ARMS):
        return {"status":"INCOMPLETE","missing_arms":sorted(set(ARMS)-set(summaries)),
                "independent_outcomes":summaries,
                "claims":"No matched A1/A2/A3 conclusions without all three original native arms"}
    arms=[summaries[a] for a in ARMS]
    if len({x["source_sha"] for x in arms})!=1:
        raise ValueError("M4 arms use different exact source commits")
    if len({x["initial_world_sha256"] for x in arms})!=1:
        raise ValueError("M4 arms do not share the identical native starting material bytes")
    if len({x["first_legal_catalog_sha256"] for x in arms})!=1:
        raise ValueError("M4 arms had unequal first legal recovery candidate sets")
    traces={a:summaries[a]["decision_effects"] for a in ARMS}
    if any(not v for v in traces.values()):
        raise ValueError("M4 arm has no actual retained decision/World trace")
    count=min(len(v) for v in traces.values())
    first_choice=None
    first_effect=None
    first_unmatched=None
    for i in range(count):
        t=[traces[a][i] for a in ARMS]
        matched=(len({(x["source_world_sha256"],tuple(x["cursor_before"]),
                       x["legal_sha256"],tuple(x["candidate_ids"])) for x in t})==1)
        if not matched and first_unmatched is None:
            first_unmatched=i
        if matched and len({x["choice"] for x in t})>1 and first_choice is None:
            first_choice=i
        if len({(tuple(x["cursor_after"]),x["world_after_sha256"]) for x in t})>1 and first_effect is None:
            first_effect=i
    if first_effect is None and len({len(v) for v in traces.values()})>1:
        first_effect=count
    data={
      "schema":"driv3r-m4-matched-comparison-summary-v1",
      "status":"COMPLETE_COMPARISON",
      "source_sha":arms[0]["source_sha"],
      "arms":ARMS,
      "same_initial_native_world":True,
      "identical_first_host_legal_candidate_catalog":True,
      "first_choice_divergence_on_matched_world":first_choice,
      "first_consequential_native_cursor_or_material_divergence":first_effect,
      "first_unmatched_native_input_state":first_unmatched,
      "candidate_equality_after_divergence":"NOT_ASSERTED",
      "scores":{a:{
         "model_requests":summaries[a]["model_requests"],
         "actual_native_edits":summaries[a]["actual_native_edits"],
         "model_selected_edits":summaries[a]["model_selected_native_edits"],
         "recovery_interventions":summaries[a]["neural_recovery_interventions"],
         "productive_steps_after_recovery":summaries[a]["productive_procedural_steps_after_recovery"],
         "recovery_leverage":summaries[a]["recovery_leverage"],
         "final_world_sha256":summaries[a]["final_world_sha256"],
         "actual_native_replay":summaries[a]["independent_native_replay"],
         } for a in ARMS},
      "limits":["One DEVELOPMENT fixture and seed; no held-out generalisation",
                "A2/A3 contain additional information, not only alternative encoding",
                "First choice divergence is not always consequential material divergence",
                "Any graphical images are native material visualisations, NOT framebuffer",
                "No neural model weights updated or production merge"],
    }
    return data


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--root",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    args=p.parse_args()
    source={}
    for arm in ARMS:
        path=args.root/arm/"execution/summary.json"
        if path.is_file():
            result=json.loads(path.read_text())
            if result.get("arm") != arm or result.get("status")!="PASS":
                continue
            source[arm]=result
    output=compare(source)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(output,indent=2,sort_keys=True)+"\n")
    print(json.dumps({key:value for key,value in output.items()
                      if key in ("status","source_sha","missing_arms",
                                 "first_choice_divergence_on_matched_world",
                                 "first_consequential_native_cursor_or_material_divergence")},
                     sort_keys=True))
    if output["status"]!="COMPLETE_COMPARISON":
        raise SystemExit(2)

if __name__=="__main__":
    main()
