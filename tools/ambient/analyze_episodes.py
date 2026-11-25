#!/usr/bin/env python3
"""Validate and independently reduce actual AMBIENT-002 physical reports."""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import statistics

DT = .1
CELL = 16.0
SCHEMA = "ambient2-physical-analysis/v1"
REQUIRED_SOURCES = {
    "scripts/ambient/ambient_engine.gd", "scripts/ambient/ambient_modules.gd",
    "scripts/ambient/ambient_stateful_modules.gd", "scripts/ambient/ambient_memory.gd",
    "scripts/ambient/ambient_profile.gd", "scripts/ambient/ambient_perception.gd",
    "scripts/ambient/ambient_actuator.gd", "scripts/physical_actor_session.gd",
    "scripts/physical_actor_rig.gd", "scripts/physical_actor_catalog.gd",
    "scripts/physical_actor_script.gd", "scripts/physical_usable_runtime.gd", "scripts/physical_actor_effects.gd",
    "scripts/workbench_actor_control.gd", "scripts/workbench_actor_catalog.gd",
    "scripts/workbench_physics_bridge.gd", "scripts/rapier_physics_bridge.gd",
    "scripts/physical_flight_controller.gd", "scripts/physical_flight_profile.gd", "data/ambient/profiles.json",
    "tests/test_ambient2_episodes.gd", "tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json",
}


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def hexadecimal(value, size):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{%d}" % size, value) is not None


def xy(value):
    require(isinstance(value, list) and len(value) == 2, "Missing copied vector")
    require(all(isinstance(v, (int, float)) and math.isfinite(v) for v in value), "Nonfinite vector")
    return value


def distance(a, b, flight=True):
    return math.hypot(a[0]-b[0], a[1]-b[1]) if flight else abs(a[0]-b[0])


def magnitude(value):
    return math.hypot(*xy(value))


def validate(report, allow_partial=False, source_root=None):
    require(report.get("case") == "AMBIENT-002 matched physical actor episodes", "Wrong report family")
    require(report.get("mode") in {"full", "smoke", "shard"}, "Unknown mode")
    require(report.get("actor_limit") == 8 and report.get("decision_period_ticks") == 6, "Unexpected physical scope")
    source = report["source_identity"]
    require(source.get("runtime_supported") is True and source.get("platform") in {"Linux", "Windows"}, "Unsupported runtime")
    require(hexadecimal(source.get("source_revision"), 40), "Full source commit required")
    require(hexadecimal(source.get("godot_executable_sha256"), 64), "Engine identity required")
    require(set(source.get("sha256", {})) == REQUIRED_SOURCES, "Exact required source inventory missing")
    for name, expected in source["sha256"].items():
        require(hexadecimal(expected, 64), "Missing source hash: "+name)
        if source_root:
            path = Path(source_root)/"godot"/name
            require(path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == expected, "Tested source differs: "+name)
    runtime_paths = {
        "addons/cybersand_native/bin/"+("cybersand_native.windows.x86_64.dll" if source["platform"] == "Windows" else "libcybersand_native.linux.x86_64.so"),
        "addons/godot-rapier2d/bin/"+("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if source["platform"] == "Windows" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")}
    require(set(source["runtime_sha256"]) == runtime_paths and all(hexadecimal(v,64) for v in source["runtime_sha256"].values()),
            "Both actual native/Rapier hashes required")
    registration = report.get("registration", [])
    require(isinstance(registration, list) and registration, "Missing experiment registry")
    declared = {item["id"]: item for item in registration}
    require(len(declared) == len(registration), "Duplicate registered case")
    require(report["expected_campaigns"] == len(registration), "Campaign count differs from registry")
    require(report["expected_actor_episodes"] == sum(i["actor_count"] for i in registration), "Actor count differs from registry")
    if not allow_partial:
        require(report.get("complete") is True and report.get("failures") == [], "Incomplete or failed campaign")
        require(report["completed_campaigns"] == report["expected_campaigns"], "Campaign registry incomplete")
        require(report["completed_actor_episodes"] == report["expected_actor_episodes"], "Actor registry incomplete")
        require(report["mode"] != "full" or report["completed_actor_episodes"] >= 100, "Full campaign needs100 actual episodes")
    campaigns, episodes, initial, rows = set(), set(), {}, []
    for campaign in report["campaigns"]:
        cid = campaign["id"]
        require(cid not in campaigns and cid in declared, "Duplicate or unregistered campaign")
        require(all(campaign.get(k) == v for k,v in declared[cid].items()), "Executed case differs from registration")
        campaigns.add(cid)
        require(campaign["seconds"] in {2,30,120,300}, "Unregistered physical horizon")
        ticks = round(campaign["seconds"]*60)
        require(campaign["native_ticks"] == ticks and campaign["physical_ticks"] == ticks, "Incomplete native/Rapier steps")
        require(abs(campaign["completed_seconds"]-campaign["seconds"]) < 1e-5, "Wrong completed physical time")
        require(campaign["run_id"] and campaign["epoch"] > 0, "Missing owner identity")
        require(1 <= campaign["actor_count"] <= 8 and len(campaign["episodes"]) == campaign["actor_count"], "Invalid roster")
        require({r["actor_instance"] for r in campaign["episodes"]} == set(range(100,100+campaign["actor_count"])),
                "Actual actor identity set differs")
        require(0 < campaign["physical_parts"] <= 64 and campaign["physical_parts"] == campaign["native_masks"], "Invalid physical/native coupling")
        require(hexadecimal(campaign["initial_materials"]["sha256"],64) and hexadecimal(campaign["initial_pose_sha256"],64),
                "Missing initial native/physical identity")
        group = campaign["matched_group"]
        signature = (campaign["initial_materials"], campaign["initial_pose_sha256"], campaign["geometry"])
        require(group not in initial or initial[group] == signature, "Mismatched initial state: "+group)
        initial[group] = signature
        for row in campaign["episodes"]:
            eid = row["episode_id"]
            require(eid not in episodes, "Duplicate actual actor episode")
            episodes.add(eid)
            require(row["model"] == campaign["model"], "Actor identity mismatch")
            count = ticks//6
            expected_commands = 0 if row["controller"] == "passive_companion" else count
            require(len(row["trace"]) == count and row["accepted_commands"] == expected_commands and row["rejected_commands"] == 0,
                    "Incomplete command/trajectory budget: "+eid)
            require(row["outcome_sensor_unavailable"] == 0, "Unequal outcome observation coverage")
            for index, sample in enumerate(row["trace"]):
                require(abs(sample["seconds"]-index*DT) < 1e-5, "Observation clock gap")
                for key in ("position","velocity","action_move","intent_direction"):
                    xy(sample[key])
                require(sample["oil"]["available"] and sample["water"]["available"], "Material coverage unavailable")
                if index:
                    require(sample["tick"]-row["trace"][index-1]["tick"] == 6, "Observation tick gap")
            rows.append((campaign,row))
    if not allow_partial:
        require(len(episodes) == report["expected_actor_episodes"] and campaigns == set(declared), "Reduced population incomplete")
    return rows


def episode_metrics(campaign, row):
    flight = row["model"] == "4ly_trainer"
    trace, start = row["trace"], xy(row["start"])
    points = [xy(p["position"]) for p in trace]+[xy(row["last"])]
    occupied, intentions, phases = Counter(), Counter(), Counter()
    entered, previous_cell = set(), None
    reentries = transitions = idle = neutral = active = stalled = 0
    oil_seen = water_seen = water_close = peer_seen = peer_lost = 0
    oil_distances, water_distances, first_oil_distances, peers = [], [], [], []
    first_oil = recovery = None
    previous_blocked = away = False
    blocked_intervals = blocked_entries = recoveries = departures = home_returns = 0
    idle_drift = 0.0
    for index, sample in enumerate(trace):
        point = sample["position"]
        cell = (math.floor(point[0]/CELL), math.floor(point[1]/CELL) if flight else 0)
        occupied[cell] += DT
        if cell != previous_cell:
            reentries += cell in entered
            entered.add(cell)
        previous_cell = cell
        intentions[sample["selection"]] += DT
        phases[sample.get("phase","")] += DT
        transitions += index > 0 and sample["selection"] != trace[index-1]["selection"]
        is_idle = sample["has_procedural_intent"] and (magnitude(sample["intent_direction"]) <= .05 or sample["intent_pace"] <= 0)
        idle += bool(is_idle)
        neutral += magnitude(sample["action_move"]) <= .05
        home = distance(point,start,flight)
        if not away and home >= 40:
            away = True
            departures += 1
        elif away and home <= 16:
            home_returns += 1
            away = False
        if index:
            prior = trace[index-1]
            travel = distance(point,prior["position"])
            if prior["has_procedural_intent"] and (magnitude(prior["intent_direction"]) <= .05 or prior["intent_pace"] <= 0):
                idle_drift += travel
            if magnitude(prior["action_move"]) > .05:
                active += 1
                stalled += distance(point,prior["position"],flight) < .25
            move_x = prior["action_move"][0]
            wall = prior.get("wall_right" if move_x >= 0 else "wall_left")
            progress = (point[0]-prior["position"][0])*(1 if move_x >= 0 else -1)
            blocked = abs(move_x) > .05 and isinstance(wall,(int,float)) and 0 <= wall <= 10 and progress < .25
            blocked_intervals += bool(blocked)
            if blocked and not previous_blocked:
                blocked_entries += 1
                if recovery is None:
                    recovery = (sample["seconds"],point)
            previous_blocked = blocked
            if recovery is not None:
                elapsed = sample["seconds"]-recovery[0]
                if elapsed > 5:
                    recovery = None
                elif distance(point,recovery[1],flight) >= 8:
                    recoveries += 1
                    recovery = None
        for name, values in (("oil",oil_distances),("water",water_distances)):
            target = sample[name]
            if not target["present"]:
                continue
            values.append(target["distance"])
            if name == "oil":
                oil_seen += 1
                if first_oil is None:
                    first_oil = target["nearest"]
            else:
                water_seen += 1
                water_close += target["distance"] <= 20
        if first_oil is not None:
            first_oil_distances.append(distance(point,first_oil))
        if sample["nearest_peer"] is not None:
            peers.append(sample["nearest_peer"])
        peer_seen += sample["observed_peer_count"] > 0
        peer_lost += index > 0 and trace[index-1]["observed_peer_count"] > 0 and sample["observed_peer_count"] == 0
    stable = sum(value+1e-8 >= .5 for value in occupied.values())
    decision, sensor = row["total_decision_usec"], row["sensor_usec_total"]
    result = {key:campaign[key] for key in ("group","layout","arm","seed","seconds")}
    result.update({
        "episode_id":row["episode_id"],"campaign_id":campaign["id"],"cluster":campaign["id"]+":"+campaign["run_id"],
        "model":row["model"],"controller":row["controller"],"profile_id":row["profile"].get("id",""),
        "x_range_cells":max(p[0] for p in points)-min(p[0] for p in points),
        "y_range_cells":max(p[1] for p in points)-min(p[1] for p in points),
        "net_displacement_cells":distance(points[-1],start,flight),
        "physical_path_including_gait_cells":row["physical_path_cells"],
        "neutral_command_drift_cells":row["neutral_command_path_cells"],"sampled_intentional_idle_drift_cells":idle_drift,
        "territory_dimension":2 if flight else 1,"stable_territory_cells":stable,"observed_territory_cells":len(occupied),
        "stable_territory_extent":stable*(CELL**2 if flight else CELL),
        "stable_territory_units":"cell_squared" if flight else "horizontal_cells",
        "territory_reentries":reentries,"intention_transitions":transitions,
        "intentions_seconds":dict(intentions),"phases_seconds":dict(phases),
        "intentional_idle_seconds":idle*DT,"neutral_command_seconds":neutral*DT,
        "active_intervals":active,"stalled_active_intervals":stalled,"stalled_active_fraction":stalled/active if active else None,
        "horizontal_obstruction_intervals":blocked_intervals,"horizontal_obstruction_entries":blocked_entries,
        "eight_cell_recoveries_within_five_seconds":recoveries,
        "home_departures_40_cells":departures,"home_returns_16_cells":home_returns,
        "home_distance_final":distance(points[-1],start,flight),"home_distance_semantics":"Euclidean" if flight else "horizontal",
        "oil_observed_seconds":oil_seen*DT,"water_observed_seconds":water_seen*DT,
        "minimum_oil_sample_distance":min(oil_distances) if oil_distances else None,
        "minimum_water_sample_distance":min(water_distances) if water_distances else None,
        "minimum_distance_to_first_oil_sample":min(first_oil_distances) if first_oil_distances else None,
        "water_within20_seconds":water_close*DT,"peer_observed_seconds":peer_seen*DT,
        "peer_range_loss_events":peer_lost,"peer_distance_median":statistics.median(peers) if peers else None,
        "canvas_center_incidents":row["canvas_center_incidents"],
        "decision_core_adapter_usec":decision,"sensor_usec":sensor,"decision_plus_sensor_usec":decision+sensor,
        "decision_core_adapter_usec_per_decision":decision/len(trace),"sensor_usec_per_decision":sensor/len(trace),
        "sensor_usec_max":row["sensor_usec_max"],"decision_usec_max":row["decision_usec_max"],
        "independent_outcome_observer_usec":row["observer_usec"]})
    return result


def social_metrics(campaign):
    rows = campaign["episodes"]
    if len(rows) < 2:
        return None
    previous, timeline = set(), []
    initial_groups = []
    formations = dissolutions = grouped_samples = 0
    for index in range(min(len(row["trace"]) for row in rows)):
        positions = [row["trace"][index]["position"] for row in rows]
        remaining, groups = set(range(len(rows))), set()
        while remaining:
            component = {remaining.pop()}
            pending = list(component)
            while pending:
                current = pending.pop()
                adjacent = {other for other in remaining if distance(positions[current],positions[other]) <= 40}
                remaining -= adjacent
                component |= adjacent
                pending.extend(adjacent)
            if len(component) > 1:
                groups.add(tuple(sorted(rows[i]["actor_instance"] for i in component)))
        formations += len(groups-previous)
        dissolutions += len(previous-groups)
        if index == 0:
            initial_groups = [list(group) for group in sorted(groups)]
        previous = groups
        grouped = sum(map(len,groups))
        grouped_samples += grouped
        timeline.append({"seconds":rows[0]["trace"][index]["seconds"],"groups":[list(g) for g in sorted(groups)],"grouped_actors":grouped})
    return {"campaign_id":campaign["id"],"arm":campaign["arm"],"seed":campaign["seed"],"actual_actors":len(rows),
            "formation_events":formations,"dissolution_events":dissolutions,"grouped_actor_seconds":grouped_samples*DT,
            "initial_proximity_components":initial_groups,
            "formation_events_after_initial":formations-len(initial_groups),
            "mean_grouped_fraction":grouped_samples/(len(timeline)*len(rows)),"timeline":timeline}


DEFINITIONS = {
    "territory":"Ground: horizontal16-cell bins ignoring vertical gait; flight:16x16 grid. Stable requires0.5s cumulative dwell. Starting bin is included; grid-edge oscillation can populate adjacent bins. Pair bins with x-range/displacement; nominal bin extent is not exact traversed extent.",
    "path":"Actual center path includes gait and vertical bobbing; path length is not exploration.",
    "idle":"Procedural neutral intention, neutral command and physical stillness differ. Actual neutral drift is retained.",
    "obstruction":"Horizontal wall-ray proxy: priorabs(move.x)>0.05, wall<=10cells, forwardprogress<0.25cells in0.1s. Entries are changes into this sampled proxy, not unique failed approach attempts. Vertical flight obstruction is unclassified.",
    "recovery":"At least8cells from a measured blocked-approach point within5s; not proof the original goal became reachable.",
    "home":"Sampled geometric departure40cells and returnwithin16cells of authored start; ground usesxonly, flight Euclidean. A zero return count is not failure when no home intention was requested, and geometric return alone does not establish intention.",
    "social":"Connected components of actual centers at40cells. Formation/dissolution counts exact membership-set changes, not human sociability or persistent group identity. The legacy formation_events field includes components already present at the first sample; initial_proximity_components and formation_events_after_initial separate that initial condition from later arrivals. Threshold crossings can create these events.",
    "cost":"Measured elapsed invocation time, not OS CPU utilization. Environment builds before decision timing. Sensor and decision-core/adapter costs are disjoint; both lie within production advance. Independent observer is evaluation overhead.",
    "selection":"intention_transitions counts changes of the selected module/blend label. It does not count distinct goal instances or same-module target changes; phase changes are distinct observations.",
    "materials":"Distances describe actual observed sampled material sites. Finite coarse coverage cannot prove absence of thin patches between sites; all arms share the outcome observer's declared scope.",
    "causality":"Ablations retain starting profile and scope. Legacy/new comparison includes documented profile/sensor differences. Held random exposes steering smoothness effects.",
    "replicates":"Population actors share campaign Worlds. Campaign clusters are separate; no independent-actor significance claim. Catalogue passive companions are auxiliary."
}


def summarize(report, rows):
    episodes = [episode_metrics(c,row) for c,row in rows]
    cohorts = defaultdict(list)
    for value in episodes:
        if value["controller"] == "passive_companion":
            continue
        cohorts[tuple(value[k] for k in ("group","layout","model","arm","seconds"))].append(value)
    aggregates = []
    keys = ["stable_territory_cells","x_range_cells","physical_path_including_gait_cells","intention_transitions",
            "intentional_idle_seconds","stalled_active_fraction","horizontal_obstruction_entries",
            "eight_cell_recoveries_within_five_seconds","home_returns_16_cells","water_within20_seconds",
            "peer_distance_median","decision_core_adapter_usec_per_decision","sensor_usec_per_decision"]
    for key, values in sorted(cohorts.items()):
        aggregate = dict(zip(("group","layout","model","arm","seconds"),key))
        aggregate.update(actor_episodes=len(values),campaign_clusters=len({v["campaign_id"] for v in values}))
        aggregate["medians"] = {name:statistics.median([v[name] for v in values if v[name] is not None])
                               if any(v[name] is not None for v in values) else None for name in keys}
        aggregates.append(aggregate)
    costs = []
    for c in report["campaigns"]:
        costs.append({"campaign_id":c["id"],"group":c["group"],"arm":c["arm"],"actual_actors":c["actor_count"],
            "seconds":c["seconds"],"native_ticks":c["native_ticks"],"physical_ticks":c["physical_ticks"],
            "native_step_ms_per_step":c["native_step_usec"]/c["native_ticks"]/1000,
            "physics_step_ms_per_step":c["physics_step_usec"]/c["physical_ticks"]/1000,
            "production_advance_ms_per_simulated_second":c["production_advance_usec"]/c["seconds"]/1000,
            "sensor_ms_per_simulated_second":sum(r["sensor_usec_total"] for r in c["episodes"])/c["seconds"]/1000,
            "wall_seconds":c["elapsed_usec"]/1e6})
    social = [social_metrics(c) for c in report["campaigns"]]
    return {"schema":SCHEMA,"complete":report["complete"],"mode":report["mode"],"source_identity":report["source_identity"],
        "campaign_clusters":len(report["campaigns"]),"actor_episodes":len(episodes),
        "subject_actor_episodes":sum(v["controller"] != "passive_companion" for v in episodes),
        "auxiliary_actor_episodes":sum(v["controller"] == "passive_companion" for v in episodes),
        "episodes":episodes,"cohorts":aggregates,"social":[s for s in social if s is not None],
        "population_costs":costs,"definitions":DEFINITIONS}


def csv_outputs(report, summary, output):
    fields = [k for k,v in summary["episodes"][0].items() if not isinstance(v,(dict,list))]
    with (output/"episodes.csv").open("w",newline="",encoding="utf-8") as stream:
        writer = csv.DictWriter(stream,fields,extrasaction="ignore"); writer.writeheader(); writer.writerows(summary["episodes"])
    fields = ["episode_id","campaign_id","model","arm","seed","seconds","x","y","move_x","move_y",
              "selection","phase","oil_distance","water_distance","nearest_peer","peer_count"]
    with (output/"trajectories.csv").open("w",newline="",encoding="utf-8") as stream:
        writer = csv.DictWriter(stream,fields); writer.writeheader()
        for c in report["campaigns"]:
            for row in c["episodes"]:
                for s in row["trace"]:
                    writer.writerow({"episode_id":row["episode_id"],"campaign_id":c["id"],"model":row["model"],
                        "arm":c["arm"],"seed":c["seed"],"seconds":s["seconds"],"x":s["position"][0],"y":s["position"][1],
                        "move_x":s["action_move"][0],"move_y":s["action_move"][1],"selection":s["selection"],"phase":s["phase"],
                        "oil_distance":s["oil"].get("distance"),"water_distance":s["water"].get("distance"),
                        "nearest_peer":s["nearest_peer"],"peer_count":s["observed_peer_count"]})


def plots(report, summary, output):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Rectangle
    colors = {"legacy":"#777777","random":"#c28624","random_hold":"#a96b1c","scripted":"#5273b8",
              "stateful":"#129574","no_memory":"#d2536d","no_traits":"#8a5cc0","coarse_only":"#4aa5bf","no_social":"#d2536d"}
    def terrain(ax,c,rows=None):
        geometry = c["geometry"]
        for i in range(0,len(geometry),5):
            x,y,w,h,m = geometry[i:i+5]
            ax.add_patch(Rectangle((x,y),w,h,color="#71808c" if m==1 else "#448fba" if m==3 else "#b39850",alpha=.35))
        points = [p["position"] for row in rows or c["episodes"] for p in row["trace"]]
        xmin=min([0]+[p[0] for p in points]); xmax=max([512]+[p[0] for p in points])
        ymin=min([0]+[p[1] for p in points]); ymax=max([256]+[p[1] for p in points])
        ax.add_patch(Rectangle((0,0),512,256,fill=False,edgecolor="#202b35",linewidth=.8))
        ax.set(xlim=(xmin-5,xmax+5),ylim=(ymax+5,ymin-5),xlabel="Native x",ylabel="Native y (down)")
        ax.grid(alpha=.15)
    fig,axes=plt.subplots(3,1,figsize=(12,9),constrained_layout=True)
    for ax,model in zip(axes,("runner","monowheel","4ly_trainer")):
        cases=[c for c in report["campaigns"] if c["group"]=="main" and c["seed"]==1701 and c["model"]==model]
        if not cases:
            ax.set_visible(False); continue
        terrain(ax,cases[0],[row for c in cases for row in c["episodes"]])
        for c in cases:
            trace=c["episodes"][0]["trace"]
            ax.plot([p["position"][0] for p in trace],[p["position"][1] for p in trace],color=colors[c["arm"]],label=c["arm"],linewidth=1.4,alpha=.85)
        ax.set_title(model+" — matched seed1701, actual body-center trajectories")
        ax.legend(ncol=4,fontsize=8,loc="upper right")
    fig.savefig(output/"matched-trajectories.png",dpi=170); plt.close(fig)
    def timeline(cases,filename,catalogue=False):
        if not cases: return
        subjects=[next(r for r in c["episodes"] if r["controller"]=="catalogue_subject") if catalogue else c["episodes"][0] for c in cases]
        states=sorted({s["selection"] for row in subjects for s in row["trace"]})
        palette=[plt.get_cmap(name)(i) for name in ("tab20","tab20b","tab20c") for i in range(20)]
        require(len(states) <= len(palette), "Selected-label timeline exceeds the distinct color catalogue")
        state_colors={s:palette[i] for i,s in enumerate(states)}
        fig,ax=plt.subplots(figsize=(15,max(5,len(cases)*.38)),constrained_layout=True)
        for line,(c,row) in enumerate(zip(cases,subjects)):
            trace=row["trace"]; start,state=trace[0]["seconds"],trace[0]["selection"]
            for sample in trace[1:]+[{"seconds":c["seconds"],"selection":None}]:
                if sample["selection"]==state: continue
                ax.broken_barh([(start,sample["seconds"]-start)],(line-.35,.7),facecolors=state_colors[state])
                start,state=sample["seconds"],sample["selection"]
        labels=[c["arm"] if catalogue else c["model"]+" / "+c["arm"] for c in cases]
        ax.set_yticks(range(len(cases)),labels,fontsize=8)
        ax.set_xlabel("Completed simulation seconds")
        ax.set_title("Selected module/blend labels; changes are not distinct goal-instance counts")
        ax.legend([Rectangle((0,0),1,1,color=state_colors[s]) for s in states],states,ncol=4,fontsize=7,loc="upper center",bbox_to_anchor=(.5,-.12))
        fig.savefig(output/filename,dpi=170,bbox_inches="tight"); plt.close(fig)
    timeline([c for c in report["campaigns"] if c["group"]=="main" and c["seed"]==1701],"behaviour-timelines.png")
    socials=[c for c in report["campaigns"] if c["group"] in {"social","capacity","departure"} and c["seed"]==1701]
    if socials:
        fig,axes=plt.subplots(len(socials),2,figsize=(12,max(4,len(socials)*2.7)),squeeze=False,constrained_layout=True)
        lookup={r["campaign_id"]:r for r in summary["social"]}
        for (ax,times),c in zip(axes,socials):
            terrain(ax,c)
            for row in c["episodes"]:
                trace=row["trace"]
                ax.plot([p["position"][0] for p in trace],[p["position"][1] for p in trace],label=str(row["actor_instance"]),linewidth=1.1)
            ax.set_title(c["group"]+" / "+c["arm"]+" / "+str(c["actor_count"])+" actual actors")
            ax.legend(ncol=4,fontsize=7)
            data=lookup[c["id"]]["timeline"]
            times.plot([p["seconds"] for p in data],[p["grouped_actors"] for p in data],color="#129574")
            times.set(ylim=(-.1,c["actor_count"]+.2),ylabel="Actors in40-cell connected groups",xlabel="Completed simulation seconds")
            times.grid(alpha=.2)
        fig.savefig(output/"social-trajectories.png",dpi=170); plt.close(fig)
    catalogue=[c for c in report["campaigns"] if c["group"]=="catalogue"]
    if catalogue:
        fig,axes=plt.subplots(4,4,figsize=(18,13),squeeze=False,constrained_layout=True)
        metrics={r["episode_id"]:r for r in summary["episodes"]}
        for ax,c in zip(axes.flat,catalogue):
            terrain(ax,c)
            subject=next(r for r in c["episodes"] if r["controller"]=="catalogue_subject")
            for row in c["episodes"]:
                trace=row["trace"]; auxiliary=row["controller"]=="passive_companion"
                ax.plot([p["position"][0] for p in trace],[p["position"][1] for p in trace],
                        color="#a0a8b0" if auxiliary else "#129574",linewidth=1 if auxiliary else 1.6,linestyle="--" if auxiliary else "-")
            m=metrics[subject["episode_id"]]
            ax.set_title(c["arm"]+" / "+c["model"]+"\n"+str(m["stable_territory_cells"])+" bins; "+str(m["intention_transitions"])+" label changes",fontsize=9)
            ax.tick_params(labelsize=7); ax.set_xlabel("Native x",fontsize=8); ax.set_ylabel("Native y",fontsize=8)
        for ax in list(axes.flat)[len(catalogue):]: ax.set_visible(False)
        fig.suptitle("Editable catalogue: one descriptive subject per preset, matched within locomotion; 30 seconds")
        fig.savefig(output/"catalogue-trajectories.png",dpi=170); plt.close(fig)
        timeline(catalogue,"catalogue-timelines.png",True)


def decision_note(summary):
    lines=["# AMBIENT-002 physical episode results","",
        "Source: "+summary["source_identity"]["source_revision"]+". Actual "+summary["source_identity"]["platform"]+
        " execution: "+str(summary["actor_episodes"])+" actor episodes in "+str(summary["campaign_clusters"])+" fresh World clusters.",
        "Subject episodes: "+str(summary["subject_actor_episodes"])+"; auxiliary companions: "+str(summary["auxiliary_actor_episodes"])+".",
        "Mode: "+summary["mode"]+"; complete: "+str(summary["complete"])+".","",
        "Raw report SHA-256: "+summary["raw_report_sha256"]+".","",
        "## Matched main comparisons","",
        "Medians across declared seeds. More travel, selected-label changes or larger groups are measurements, not automatic judgments of entertainment or intelligence.","",
        "| Rig / control | Episodes | Stable bins | X range | Selected-label changes | Active stall fraction | Sensor elapsed ms / decision |",
        "|---|---:|---:|---:|---:|---:|---:|"]
    for row in summary["cohorts"]:
        if row["group"]!="main": continue
        m=row["medians"]; stall="—" if m["stalled_active_fraction"] is None else f"{m['stalled_active_fraction']:.3f}"
        lines.append(f"| {row['model']} / {row['arm']} | {row['actor_episodes']} | {m['stable_territory_cells']:.1f} | {m['x_range_cells']:.2f} | {m['intention_transitions']:.1f} | {stall} | {m['sensor_usec_per_decision']/1000:.3f} |")
    lines += ["","## Actual population cost","",
        "Profiles and layouts differ between cohorts; these are workload measurements, not controlled asymptotic scaling. Eight-actor legacy/stateful comparisons retain their matched case identities in the machine-readable output.","",
        "| Actors | Campaigns | Native ms / tick | Physics ms / tick | Production ms / sim second | Sensor ms / sim second |",
        "|---|---:|---:|---:|---:|---:|"]
    for population in sorted({r["actual_actors"] for r in summary["population_costs"]}):
        rows=[r for r in summary["population_costs"] if r["actual_actors"]==population]
        values=[statistics.median(r[k] for r in rows) for k in ("native_step_ms_per_step","physics_step_ms_per_step","production_advance_ms_per_simulated_second","sensor_ms_per_simulated_second")]
        lines.append(f"| {population} | {len(rows)} | "+" | ".join(f"{v:.3f}" for v in values)+" |")
    lines += ["","## Interpretation boundaries",""]+["- "+v for v in summary["definitions"].values()]
    lines += ["","Actual ordinary Workbench graphics and physical Windows/NVIDIA owner acceptance remain separate."]
    return "\n".join(lines)+"\n"


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report",type=Path,required=True); parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--source-root",type=Path); parser.add_argument("--allow-partial",action="store_true")
    parser.add_argument("--no-plots",action="store_true")
    args=parser.parse_args()
    raw=args.report.read_bytes(); report=json.loads(raw)
    rows=validate(report,args.allow_partial,args.source_root)
    require(rows,"No actual physical episodes")
    summary=summarize(report,rows)
    summary["raw_report_sha256"]=hashlib.sha256(raw).hexdigest()
    summary["analyzer_sha256"]=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/"summary.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    csv_outputs(report,summary,args.output)
    (args.output/"decision-note.md").write_text(decision_note(summary),encoding="utf-8")
    if not args.no_plots: plots(report,summary,args.output)
    print(json.dumps({"status":"PASS","mode":report["mode"],"complete":report["complete"],
        "actor_episodes":len(rows),"campaign_clusters":len(report["campaigns"]),
        "source_revision":report["source_identity"]["source_revision"],"output":str(args.output)}))


if __name__=="__main__":
    main()

