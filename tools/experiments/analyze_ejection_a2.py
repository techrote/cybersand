"""Qualification-gated A2 census using the UNCHANGED #336 B/C implementations."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import subprocess

import ejection_a2 as a2


def weighted_c(rows, weights):
    if len(rows) != len(weights) or any(type(w) is not int or w < 1 for w in weights):
        raise ValueError("one positive integer multiplicity per scientific class required")
    baseline = sum(w for row, w in zip(rows, weights) if row["production_success"])
    failed = sum(w for row, w in zip(rows, weights) if not row["production_success"])
    total = baseline+failed
    policies = {}
    for policy in a2.oracle.POLICIES:
        policies[policy] = {}
        for cap in a2.oracle.CAPS:
            recovered = sum(w for row, w in zip(rows, weights)
                            if not row["production_success"] and row["policies"][policy][str(cap)]["legal"])
            policies[policy][str(cap)] = {"additional_recovered":recovered,"failed_denominator":failed,
                "additional_fraction":recovered/failed if failed else 0,
                "baseline_plus_chain":baseline+recovered,"all_contacts":total,
                "baseline_plus_chain_fraction":(baseline+recovered)/total if total else 0}
    return {"baseline":baseline,"total":total,"failed":failed,"policies":policies}


def b_extra(rows):
    failed = [r for r in rows if not r["production_success"]]
    exact = Counter(str(r["minimum_cost"]) if r["minimum_cost"] is not None else "unreachable" for r in failed)
    return {"exact_costs":dict(sorted(exact.items())),
            "cost_1_through_4":sum(r["minimum_cost"] in (1,2,3,4) for r in failed),
            "no_interior_void":sum(r["void_count"] == 0 for r in failed),
            "negative_translation_dot":sum(r["normal"].get("translation",{}).get("dot",0) < 0 for r in failed),
            "negative_radial_dot":sum(r["normal"].get("radial",{}).get("dot",0) < 0 for r in failed)}


def subgroups(population, c_rows):
    groups = defaultdict(dict)
    for i, capsule in enumerate(population["capsules"]):
        if capsule["target"][0] >= 0:
            continue
        h = capsule["topology_hash"]
        for stratum, multiplicity in population["event_strata"][h].items():
            phase, depth, normal = stratum.split("/")
            for key in ("phase:"+phase,"penetration:"+depth,"normal:"+normal,"stratum:"+stratum):
                groups[key][i] = groups[key].get(i,0)+multiplicity
    result = {}
    for key, indices in sorted(groups.items()):
        rows = [c_rows[i] for i in indices]
        unique = weighted_c(rows,[1]*len(rows))
        events = weighted_c(rows,list(indices.values()))
        result[key] = {"unique":unique,"events":events,
                       "registered_structural_classes":len({population["capsules"][i]["structural_hash"] for i in indices})}
    return result


def decide(unique, events, groups):
    # Thresholds were fixed in protocol.json before acquisition. No confidence
    # interval or inference about an unobserved population is asserted.
    if unique["failed"] <= 0 or events["failed"] <= 0:
        return {"disposition":"inconclusive: no observed unresolved population",
                "high_value_predeclared_subgroups":[],"maximum_additional_fraction":None}
    rates = [report["policies"][p]["4"]["additional_fraction"]
             for report in (unique,events) for p in a2.oracle.POLICIES]
    signals = []
    for key, values in groups.items():
        # Marginals are the preregistered decision groups. Crossed acquisition
        # strata are also reported, but do not redefine the decision after data.
        if key.startswith("stratum:") or values["unique"]["failed"] < 20:
            continue
        if any(values[weight]["policies"][p]["4"]["additional_fraction"] >= .10
               for weight in ("unique","events") for p in a2.oracle.POLICIES):
            signals.append(key)
    if max(rates,default=0) >= .10:
        disposition = "unexpected experimental GO signal; no production admission"
    elif signals:
        disposition = "conditional subgroup; no global production policy"
    elif max(rates,default=0) <= .01:
        disposition = "strong NO-GO for bounded local push-chain as primary solution in this finite cohort"
    else:
        disposition = "intermediate/inconclusive; independent review, no speculative extension"
    return {"disposition":disposition,"high_value_predeclared_subgroups":signals,
            "maximum_additional_fraction":max(rates,default=0)}


def suppression_detail(population, original):
    """Post-hoc layout description; never changes identity/retention/decision."""
    def layout(c):
        g=a2.topology.Grid(c)
        return a2.digest({"bounds":[g.left-g.source[0],g.top-g.source[1],g.width,g.height],
            "cells":[[r[0],r[5],r[6],0 if r[4]==0 else 1 if r[4]==g.body_id else 2] for r in g.cells]})
    originals={c["replay_hash"]:c for c in original["capsules"] if c["target"][0]<0}
    failed=[c for c in population["capsules"] if c["target"][0]<0]
    groups=defaultdict(set)
    for c in failed:
        groups[c["replay_hash"]].add(layout(c))
    scientific={c["topology_hash"] for c in population["capsules"]}
    collapsed=[c for c in failed if c["replay_hash"] in originals
                and c["topology_hash"] != a2.topology_hash(originals[c["replay_hash"]])]
    return {"original_scientific_states_present":sum(a2.topology_hash(c) in scientific for c in original["capsules"]),
        "additional_states_with_original_failure_hash":len(collapsed),
        "those_with_changed_grid_mask_layout":sum(layout(c)!=layout(originals[c["replay_hash"]]) for c in collapsed),
        "original_failure_hash_groups_splitting_grid_layout":sum(len(groups[h])>1 for h in originals),
        "all_failure_hash_groups_splitting_grid_layout":sum(len(v)>1 for v in groups.values()),
        "distinct_failure_grid_layouts":len({layout(c) for c in failed}),
        "scope":"Post-hoc relative material/hard/movable/own-foreign mask grid description, excluding pose/state payload; not the registered structural identity or decision unit."}


def bearing_summary(frames, population):
    evidence = []
    for frame in frames:
        b = frame["body_input"]
        metrics = frame["post_tick_metrics"][0]
        result = frame["requested_results"]
        applied = frame["bridge_application"]
        angle = b[3]
        extent = abs(math.sin(angle))*b[4]/2 + abs(math.cos(angle))*b[5]/2
        evidence.append({"tick":frame["tick"],"center_y":b[2],"lower_extent_depth_from_initial_surface":b[2]+extent-160,
            "upper_extent_y":b[2]-extent,"input_vy":b[7],"support_samples":metrics[19],
            "nominal_bearing_y":metrics[18],"requested_y":result[2],"accepted_y":applied[2],
            "correction_y":result[4],"live_vy_after":frame["live_velocity_after_application"][1],
            "age":applied[0],"intermediate_caps":metrics[12],"final_generic_cap":metrics[13],
            "displaced":metrics[14],"unresolved":metrics[15]})
    first_bearing = next(r for r in evidence if r["nominal_bearing_y"] != 0)
    first_failure = next(r for r in evidence if r["unresolved"] > 0)
    first_correction = next(r for r in evidence if r["correction_y"] != 0)
    failed = [c for c in population["capsules"] if c["target"][0] < 0]
    by_tick = {r["tick"]:r for r in evidence}
    bearing = [r for r in evidence if r["nominal_bearing_y"] != 0]
    limits = Counter()
    formula_errors = []
    for r in bearing:
        velocity = r["input_vy"]
        terms = {"arrest":velocity,"yield":92/60+max(0,velocity-92/60)*.18,
                 "capacity":min(20,r["support_samples"]*2)}
        limits[min(terms,key=terms.get)] += 1
        formula_errors.append(abs(-min(terms.values())-r["nominal_bearing_y"]))
    return {"first_bearing":first_bearing,"first_no_target_frame":first_failure,"first_slow_correction":first_correction,
        "maximum_lower_extent_depth":max(evidence,key=lambda r:r["lower_extent_depth_from_initial_surface"]),
        "failed_event_frames":sorted({int(c["tick"]) for c in failed}),
        "failures_while_rising":sum(by_tick[int(c["tick"])]["input_vy"] < 0 for c in failed),
        "failures_while_descending":sum(by_tick[int(c["tick"])]["input_vy"] > 0 for c in failed),
        "bridge_age_histogram":dict(Counter(str(r["age"]) for r in evidence)),
        "requested_accepted_net_equal_frames":sum(frame["requested_results"][1:3] == frame["bridge_application"][1:3] for frame in frames),
        "nominal_bearing_frames":len(bearing),"nominal_equals_requested_y_frames":sum(r["nominal_bearing_y"] == r["requested_y"] for r in bearing),
        "maximum_bearing_magnitude":max(abs(r["nominal_bearing_y"]) for r in evidence),
        "bearing_formula_maximum_error":max(formula_errors),"bearing_limiter_frames":dict(limits),
        "global_bearing_cap20_reached_frames":sum(abs(r["nominal_bearing_y"]) >= 20 for r in evidence),
        "intermediate_generic_caps":sum(r["intermediate_caps"] for r in evidence),
        "final_generic_cap_frames":sum(bool(r["final_generic_cap"]) for r in evidence),
        "all_upper_extents_above_initial_surface":all(r["upper_extent_y"] < 160 for r in evidence),
        "frames200_599": {"frames":400,"attempts":sum(f["events"] for f in frames[200:]),
            "bearing_frames":sum(r["nominal_bearing_y"] != 0 for r in evidence[200:]),
            "correction_frames":sum(r["correction_y"] != 0 for r in evidence[200:])},
        "limitations":"Initial surface is not current grain contour. Nominal bearing and accepted NET impulse are distinct channels; no separate backend-applied bearing or Rapier contact impulse is recorded."}


def run(population, sample, qualification, acquisition, stream_trace, legacy_trace, root):
    if not qualification["ok"] or qualification["mutation_failures"] != 0 or qualification["native_fallback_target_trace_matches"] != len(population["capsules"]):
        raise ValueError("replay qualification blocks B/C")
    if not acquisition["complete"] or acquisition["native_counters"]["dropped"]:
        raise ValueError("incomplete census")
    frames, legacy = stream_trace["frames"], legacy_trace["frames"]
    if len(frames) != 600 or [{k:v for k,v in r.items() if k!="events"} for r in frames] != [{k:v for k,v in r.items() if k!="events"} for r in legacy]:
        raise ValueError("diagnostic neutrality failed")
    # Do not merely trust filenames: freeze all four inherited analysis/test
    # modules to the reviewed parent blobs before interpreting any outcome.
    frozen = ["tools/experiments/ejection_topology.py","tools/experiments/ejection_push_chain.py",
              "tools/experiments/test_ejection_topology.py","tools/experiments/test_ejection_push_chain.py"]
    for path in frozen:
        original = subprocess.check_output(["git","rev-parse",a2.BASE+":"+path],cwd=root,text=True).strip()
        current = subprocess.check_output(["git","hash-object",path],cwd=root,text=True).strip()
        if original != current:
            raise ValueError("frozen B/C module changed: "+path)
    before = a2.digest(population)
    b, c = a2.topology.analyze_corpus(population), a2.oracle.analyze_corpus(population)
    sb, sc = a2.topology.analyze_corpus(sample), a2.oracle.analyze_corpus(sample)
    for report in (b,c):
        for row, capsule in zip(report["capsules"],population["capsules"]):
            row["topology_hash"], row["structural_hash"] = capsule["topology_hash"], capsule["structural_hash"]
    weights = [population["event_multiplicities"][cap["topology_hash"]] for cap in population["capsules"]]
    unique_c, event_c = weighted_c(c["capsules"],[1]*len(weights)), weighted_c(c["capsules"],weights)
    event_b_rows = [row for row,w in zip(b["capsules"],weights) for _ in range(w)]
    structural_indices = {}
    for i, cap in enumerate(population["capsules"]):
        structural_indices.setdefault(cap["structural_hash"],i)
    structural_c = weighted_c([c["capsules"][i] for i in structural_indices.values()],[1]*len(structural_indices))
    groups = subgroups(population,c["capsules"])
    original_b = json.loads((root/"docs/audits/physical-detachment-2026-10-31/stage-b-topology.json").read_bytes())
    original_c = json.loads((root/"docs/audits/physical-detachment-2026-10-31/stage-c-oracle.json").read_bytes())
    original_capsules = json.loads((root/"docs/audits/physical-detachment-2026-10-31/stage-a-corpus.json").read_bytes())
    recovered = [{"topology_hash":row["topology_hash"],"source":row["source"],
                  "input_penetration":cap["penetration"],"first_distance":cap["first_distance"],
                  "solutions":{p:row["policies"][p]["4"] for p in a2.oracle.POLICIES}}
                 for row,cap in zip(c["capsules"],population["capsules"])
                 if not row["production_success"] and row["policies"]["forward_lateral"]["4"]["legal"]]
    comparison = {"suppression_detail":suppression_detail(population,original_capsules),
        "original_B":original_b["unresolved"],"original_B_extra":b_extra(original_b["capsules"]),
        "a2_state_B":b["unresolved"],"a2_state_B_extra":b_extra(b["capsules"]),
        "a2_event_B":a2.topology.distribution([r for r in event_b_rows if not r["production_success"]]),
        "a2_sample_B":sb["unresolved"],"original_C":original_c["policies"],
        "a2_state_C":unique_c,"a2_event_C":event_c,"a2_structural_C":structural_c,
        "a2_sample_C":weighted_c(sc["capsules"],[1]*len(sc["capsules"])),
        "new_recovered_failures":recovered,"decision":decide(unique_c,event_c,groups),
        "all_multiplicities_one":all(w == 1 for w in weights),
        "input_nonmutation":before == a2.digest(population),
        "scope":"Complete finite-run scientific-state/event census; retained sample is not unbiased. Structural weighting is a robustness description, not replacement identity."}
    if not comparison["input_nonmutation"]:
        raise AssertionError("analysis mutated population")
    return {"stage-b-population.json":b,"stage-c-population.json":c,
            "stage-b-sample.json":sb,"stage-c-sample.json":sc,"comparison.json":comparison,
            "subgroups.json":groups,"bearing-observations.json":bearing_summary(frames,population)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ("population","sample","replay","acquisition","trace","legacy_trace"):
        parser.add_argument("--"+field.replace("_","-"),type=Path,required=True)
    parser.add_argument("--output-directory",type=Path,required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    paths = [getattr(args,k) for k in ("population","sample","replay","acquisition","trace","legacy_trace")]
    originals = [p.read_bytes() for p in paths]
    qualification = json.loads(originals[2])
    if qualification.get("input_sha256") != hashlib.sha256(originals[0]).hexdigest():
        raise ValueError("replay receipt does not bind this exact population file")
    results = run(*(json.loads(raw) for raw in originals),root)
    outputs = [args.output_directory/name for name in results]
    for output in outputs:
        for source in paths:
            if output.resolve() == source.resolve() or (output.exists() and output.samefile(source)):
                raise ValueError("output aliases frozen input")
    for path, result in zip(outputs,results.values()):
        a2.write_json(path,result)
    if any(path.read_bytes() != raw for path,raw in zip(paths,originals)):
        raise AssertionError("input file changed")
    print(json.dumps({"B":results["comparison.json"]["a2_state_B"],
                      "C":results["comparison.json"]["a2_state_C"],
                      "decision":results["comparison.json"]["decision"]},sort_keys=True))


if __name__ == "__main__":
    main()
