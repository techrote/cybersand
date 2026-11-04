#!/usr/bin/env python3
"""Authenticate and summarize retained asynchronous physical observations only."""
import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import statistics

SOURCES = {
    "historical": {"sha": "749fb8b597ad866f7535f26442e904207c4f7611", "tree": "77a7bc2ed4d1f7ab339dd4a16fd082fccf56f0ce"},
    "current": {"sha": "9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d", "tree": "b5baf8b23ff947c2d7b70e69745c10f18fbe9ebe"}}
RUNS = {"historical": 41746597077, "current": 41815817333}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def near(a, b):
    assert math.isclose(a, b, rel_tol=1e-9, abs_tol=1e-6), (a, b)


def span(rows, field):
    return (max(r[field] for r in rows)-min(r[field] for r in rows))/1e6 if rows else None


def summarize(values):
    present = [x for x in values if x is not None]
    assert all(isinstance(x, (int, float)) and math.isfinite(x) for x in present)
    return {"n": len(present), "missing_or_not_applicable": len(values)-len(present),
        "min": min(present) if present else None, "max": max(present) if present else None,
        "mean": statistics.mean(present) if present else None,
        "sample_sd": statistics.stdev(present) if len(present)>1 else None,
        "sample_variance": statistics.variance(present) if len(present)>1 else None}


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--current",type=Path,required=True)
    ap.add_argument("--historical",type=Path,required=True)
    ap.add_argument("--output",type=Path,required=True)
    args=ap.parse_args()
    trials, custody, groups = [], [], defaultdict(list)
    for era, base in (("historical",args.historical),("current",args.current)):
        for platform in ("linux","windows"):
            validation_path=base/(platform+"-validation.json") if era=="historical" else None
            if validation_path:
                v=load(validation_path)
                assert v["source"]==SOURCES[era] and str(v["run_id"])==str(RUNS[era]) and v["status"]=="passed"
            build_path=(base/"build"/platform/"build.json") if era=="historical" else (base/("build-"+platform)/"build.json")
            build=load(build_path)
            for workers in (1,4):
                host=base/"cohorts"/platform/f"contact-w{workers}"
                if platform=="linux": host/= "host"
                host_path=host/"report.json"; report=load(host_path)
                assert report["source"]==build["source"]==SOURCES[era]
                assert report["status"]=="passed" and not report["errors"]
                assert report["source_unchanged"] and report["checkout_inputs_unchanged"]
                inputs=load(host/"inputs-before.json")
                assert inputs==load(host/"inputs-after.json")==build["inputs"]
                assert load(host/"checkout-inputs-before.json")==load(host/"checkout-inputs-after.json")
                assert sha(build_path)==report["build_manifest_sha256"] and build["runtime"]==report["runtime"]
                name=f"contact-recovery-w{workers}"
                record=next(x for x in report["records"] if x["name"]==name)
                path=host/(name+".json"); log=host/record["log"]
                assert record["status"]=="passed" and record["returncode"]==0 and record["natural_completion"]
                assert sha(path)==record["result"]["sha256"] and sha(log)==record["log_sha256"]
                data=load(path)
                assert all(data.get(k)==v for k,v in record["readback"].items())
                assert data["checks"]==290 and not data["failures"] and data["platform"]==platform.title() and data["workers"]==workers
                assert len(data["cases"])==18
                assert {(c["surroundings"],c["candidate"],c["repeat"]) for c in data["cases"]}=={
                    (f,a,r) for f in ("packed_sand","embedded_sand","mixed") for a in (False,True) for r in range(3)}
                relative=path.relative_to(base).as_posix()
                custody.append({"era":era,"platform":platform,"workers":workers,"source":SOURCES[era],
                    "run_id":RUNS[era],"run_url":f"https://github.com/techrote/cybersand/actions/runs/{RUNS[era]}",
                    "local_path":str(path),"artifact_name":f"sol281-host-{platform}-contact-w{workers}-{RUNS[era]}-1",
                    "artifact_member":path.relative_to(base/"cohorts"/platform/f"contact-w{workers}").as_posix(),
                    "repository_path":"docs/audits/sol281-20261103/hosted/"+SOURCES[era]["sha"]+"/"+relative,
                    "result_sha256":sha(path),"host_report_sha256":sha(host_path),"input_manifest_sha256":sha(host/"inputs-before.json"),
                    "build_manifest_sha256":sha(build_path),"runtime":report["runtime"],"engine":report["engine"],"rapier":report["rapier"],
                    "publication_validation_sha256":sha(validation_path) if validation_path else None,
                    "input_count":len(inputs),"case_count":18,"assertions":data["checks"]})
                for case in data["cases"]:
                    trace=case["trace"]; p=case["metrics"]["physical_contact"]
                    assert case["steps"]==case["metrics"]["timed_rapier_steps"]==360
                    assert case["sand_before"]==case["sand_after"] and case["water_before"]==case["water_after"]
                    assert len(trace)==p["observations"] and len({r["snapshot"] for r in trace})==len(trace)
                    assert all(trace[i]["observed_usec"]<trace[i+1]["observed_usec"] and trace[i]["source_published_usec"]<trace[i+1]["source_published_usec"] for i in range(len(trace)-1))
                    assert sum(r["overlap_cells"] for r in trace)==p["overlap_cell_samples"]
                    near(sum(r["overlap_area"] for r in trace),p["area_samples"])
                    near(sum(r["sand_overlap_area"] for r in trace),p["sand_area_samples"])
                    near(max(r["max_sand_penetration"] for r in trace),p["max_sand_penetration"])
                    positive=[r for r in trace if r["sand_overlap_area"]>1e-6 or r["max_sand_penetration"]>2e-5]
                    kinetics=[r["kinetic_energy"] for r in trace if "kinetic_energy" in r]
                    energy_rows=[r["response"] for r in trace if r.get("response_matches_observation")
                        and "actual_energy_after" in r.get("response",{}) and "energy_before" in r["response"]]
                    deltas=[r["actual_energy_after"]-r["energy_before"] for r in energy_rows]
                    assert all(delta<=1e-4*max(1,r["energy_before"]) for delta,r in zip(deltas,energy_rows))
                    if len(energy_rows)==p["response_accepts"]:
                        near(sum(deltas),p["energy_change_sum"])
                    metric={"complete_consumed_observations":p["observations"],"captured_trace_observations":len(trace),
                        "positive_observations":len(positive),"positive_observation_fraction":len(positive)/len(trace),
                        "max_sand_penetration_cells":p["max_sand_penetration"],"max_any_material_penetration_cells":p["max_penetration"],
                        "positive_source_publication_span_seconds":span(positive,"source_published_usec"),
                        "positive_main_observation_span_seconds":span(positive,"observed_usec"),
                        "all_main_observation_span_seconds":span(trace,"observed_usec"),
                        "overlap_cell_samples":p["overlap_cell_samples"],"overlap_area_samples":p["area_samples"],
                        "sand_area_samples":p["sand_area_samples"],
                        "mean_overlap_cells_per_complete_observation":p["overlap_cell_samples"]/p["observations"],
                        "mean_sand_area_per_complete_observation":p["sand_area_samples"]/p["observations"],
                        "max_translation_cells":case["max_translation"],"max_absolute_rotation_radians":case["max_rotation"],
                        "max_absolute_angular_velocity_radians_per_second":case["max_angular_velocity"],
                        "impulse_magnitude_sum":p["impulse_magnitude_sum"],"max_single_impulse_magnitude":p["max_impulse_magnitude"],
                        "impulse_x_sum":p["impulse_x_sum"],"impulse_y_sum":p["impulse_y_sum"],
                        "torque_impulse_sum":p["torque_impulse_sum"],"actual_angular_momentum_change_sum":p["angular_momentum_change_sum"],
                        "actual_contact_response_energy_change_sum":p["energy_change_sum"],
                        "energy_guard_violations":p["energy_violations"],"post_application_failures":sum(p["response_failures"].values()),
                        "response_attempts":p["response_attempts"],"response_accepts":p["response_accepts"],
                        "response_refusals":sum(p["response_refusals"].values()),
                        "sampled_kinetic_energy_observations":len(kinetics),
                        "sampled_kinetic_energy_min":min(kinetics) if kinetics else None,
                        "sampled_kinetic_energy_max":max(kinetics) if kinetics else None,
                        "sampled_kinetic_energy_mean":statistics.mean(kinetics) if kinetics else None,
                        "matched_response_energy_observations":len(energy_rows),
                        "matched_response_energy_delta_min":min(deltas) if deltas else None,
                        "matched_response_energy_delta_max":max(deltas) if deltas else None,
                        "matched_response_energy_delta_max_positive":max(0,max(deltas)) if deltas else None}
                    trial={"era":era,"platform":platform,"workers":workers,"fixture":case["surroundings"],
                        "arm":"candidate" if case["candidate"] else "baseline","repeat":case["repeat"],"id":case["id"],
                        "metrics":metric,"response_refusal_reasons":p["response_refusals"],
                        "geometry_denominator":"complete consumed native publications; all captured as unique trace records",
                        "motion_denominator":360,"first_observed_rapier_step":trace[0]["rapier_step"],"last_observed_rapier_step":trace[-1]["rapier_step"],
                        "first_positive_observed_rapier_step":positive[0]["rapier_step"] if positive else None,
                        "last_positive_observed_rapier_step":positive[-1]["rapier_step"] if positive else None,
                        "first_positive_source_published_usec":positive[0]["source_published_usec"] if positive else None,
                        "last_positive_source_published_usec":positive[-1]["source_published_usec"] if positive else None,
                        "first_positive_observed_usec":positive[0]["observed_usec"] if positive else None,
                        "last_positive_observed_usec":positive[-1]["observed_usec"] if positive else None,
                        "last_sample_has_positive_overlap":trace[-1] in positive,
                        "kinetic_energy_availability":"recorded after sampled main-thread step" if kinetics else "not recorded in historical trace",
                        "response_energy_availability":("response disabled" if not case["candidate"] else
                            "immediate per-response actual readbacks and cumulative metric" if energy_rows else "cumulative metric only; historical per-response readbacks not recorded"),
                        "sand_before":case["sand_before"],"sand_after":case["sand_after"],"water_before":case["water_before"],"water_after":case["water_after"]}
                    trials.append(trial)
                    groups[(platform,workers,case["surroundings"],trial["arm"],era)].append(trial)
    comparisons=[]
    for platform in ("linux","windows"):
        for workers in (1,4):
            for fixture in ("packed_sand","embedded_sand","mixed"):
                for arm in ("baseline","candidate"):
                    entry={"platform":platform,"workers":workers,"fixture":fixture,"arm":arm}
                    for era in ("historical","current"):
                        rows=sorted(groups[(platform,workers,fixture,arm,era)],key=lambda x:x["repeat"])
                        assert [r["repeat"] for r in rows]==[0,1,2]
                        entry[era]={"repeat_count":3,"trial_ids":[r["id"] for r in rows],
                            "complete_observation_denominators":[r["metrics"]["complete_consumed_observations"] for r in rows],
                            "metrics":{key:summarize([r["metrics"][key] for r in rows]) for key in rows[0]["metrics"]}}
                    comparisons.append(entry)
    result={"schema":"cybersand.sol364.asynchronous-physical-comparison.v1","status":"authenticated-descriptive-evidence",
        "review_script_sha256":sha(Path(__file__)),"sources":SOURCES,"runs":RUNS,"custody":custody,
        "trial_count":len(trials),"current_trial_count":72,"historical_trial_count":72,"group_count_per_source":24,
        "positive_overlap_definition":"Sand area >1e-6 cells squared OR maximum Sand depth >2e-5 cells; applied uniformly for descriptive historical/current observation classification, not a retrospective acceptance-threshold change.",
        "span_definition":"Last minus first positive observation timestamp, separately for source publication and main observation. This is a sampled-overlap observation span, not continuous penetration duration, dwell time, time-to-clearance or interpolated simulation steps.",
        "comparison_scope":"Baseline/candidate and historical/current asynchronous histories are unmatched. Initial fixtures/policies and3-repeat inventories are retained; ranges, maxima, means and sample SD/variance describe observed distributions, not matched causal effect estimates.",
        "energy_scope":"Aggregate contact energy_change_sum is actual immediate Sand-response readback change and excludes gravity/ordinary coupling between responses. Current per-trace kinetic energy is sampled after main-thread physics steps. Historical traces lack velocity/inertia/kinetic and per-response energy records; those fields remain unavailable rather than reconstructed. Cumulative historical response-energy metrics and guard counters remain present.",
        "response_channel_scope":"Impulse, torque and contact-response energy metrics are from the additional SOL Sand-response channel. Baseline zeros do not mean ordinary compound coupling applies no physical forces. Motion maxima include the combined actual session behavior and are not attributed to one channel.",
        "sample_units":"Geometry counts are cell-samples and area-samples. Motion maxima are accumulated across360 admitted Rapier steps. No asynchronous geometry cell-ticks are inferred.",
        "statistical_definition":"Within each group, n=3 separately reset recorded sessions. mean is arithmetic mean; sample SD/variance use denominator n-1 and are descriptive, without an independence assumption or confidence interval. Missing/not-applicable energy records are counted explicitly; no missing observations are fabricated.",
        "current_and_historical_material_quantities_conserved":all(t["sand_before"]==t["sand_after"] and t["water_before"]==t["water_after"] for t in trials),
        "observed_response_energy_violations":sum(t["metrics"]["energy_guard_violations"] for t in trials),
        "observed_post_application_failures":sum(t["metrics"]["post_application_failures"] for t in trials),
        "groups":comparisons,"trials":trials,
        "limitations":["No unobserved native or Rapier overlap is reconstructed; these traces cannot prove sustained clearance between samples.",
            "All cumulative observation quantities retain their original denominators. Different observation counts across hosts/sources affect sums; per-observation means are separately labelled descriptive quantities.",
            "This file makes no CPU pass claim and does not replace the registered24-group cost analysis.",
            "Headless asynchronous observations do not demonstrate human graphical acceptance or representative GPU frame pacing."]}
    args.output.write_text(json.dumps(result,sort_keys=True,separators=(",",":"),allow_nan=False)+"\n")
    print(json.dumps({"output":str(args.output),"sha256":sha(args.output),"trials":len(trials),"groups":len(comparisons),
        "energy_guard_violations":result["observed_response_energy_violations"],"post_application_failures":result["observed_post_application_failures"]}))


if __name__=="__main__":main()
