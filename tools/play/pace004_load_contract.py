#!/usr/bin/env python3
"""Source-bound ordinary-brush workload contract, supplemental to full PACE004.

The queue acknowledges admission, not individual native application. Activity
comes from complete actual native tick records and exclusive-owner cell queries.
"""
from __future__ import annotations
from collections import Counter
import hashlib
import re

from pace004_contract import OWNER, integer, numeric, require, same, state_valid, stats

RECIPE = "brush_rain_v1;square=8;period_usec=100000;pulses=150;sand=2@396,176;water=3@576,176;flags=0;priming=0"
RECIPE_SHA256 = hashlib.sha256(RECIPE.encode()).hexdigest()
ACTIVE = "brush_rain_v1"
IDLE = "idle_control_v1"
MODES = (ACTIVE, IDLE)
PERIOD_USEC = 100_000
PULSES = 150
WINDOW_USEC = 15_000_000
CENTRES = ((396,176),(576,176))
MATERIALS = (2,3)
HELPER = "godot/tests/play_pace004_brush_load.gd"
LOAD_OWNER = (*OWNER,"generation")
# Frozen brush_rain_v1 thresholds after source-pinned feasibility. These measure real
# cellular work, not FPS, latency, configured capacity, or per-worker utilization.
MIN_MEDIAN_VISITED = 64
MIN_MEDIAN_MOVED = 16
MIN_ACTIVE_FRACTION = 0.75


def plan() -> list[tuple[str,int,int,str]]:
    return [(rig,workers,policy,mode) for rig in ("acrobat","jetbarrel")
            for workers in (1,0) for policy in (0,2) for mode in MODES]


def footprint(centre: tuple[int,int]) -> list[int]:
    return [value for y in range(centre[1]-3,centre[1]+5)
            for x in range(centre[0]-3,centre[0]+5) for value in (x,y)]


def active_activity_errors(activity: dict) -> list[str]:
    """Used identically for active cases and the matched no-load negative."""
    errors=[]
    if activity["visited_cells"]["p50"] < MIN_MEDIAN_VISITED:
        errors.append("median_visited_below_64")
    if activity["moved_cells"]["p50"] < MIN_MEDIAN_MOVED:
        errors.append("median_moved_below_16")
    if activity["active_tick_fraction"] < MIN_ACTIVE_FRACTION:
        errors.append("active_tick_fraction_below_0.75")
    for bucket in activity["seconds"]:
        number=bucket["second"]
        if not bucket["ticks"] or bucket["visited_cells"]<64 or bucket["moved_cells"]<16:
            errors.append(f"second_{number:02d}_insufficient_cell_work")
        if bucket["active_tick_fraction"]<MIN_ACTIVE_FRACTION:
            errors.append(f"second_{number:02d}_insufficient_active_ticks")
        if any(count<1 for count in bucket["intended_material_observations"]):
            errors.append(f"second_{number:02d}_no_intended_material_observation")
    return errors


def activity_summary(native: list[dict],started: int) -> dict:
    def active(row):return row["visited_cells"]>0 and row["moved_cells"]>0
    buckets=[]
    for second in range(15):
        rows=[row for row in native if started+second*1_000_000<=row["completed_usec"]<started+(second+1)*1_000_000]
        buckets.append({"second":second,"ticks":len(rows),
            "visited_cells":sum(row["visited_cells"] for row in rows),
            "moved_cells":sum(row["moved_cells"] for row in rows),
            "active_tick_fraction":sum(active(row) for row in rows)/len(rows) if rows else 0,
            "intended_material_observations":[sum(row["brush_cells"][slot]["material"]==material for row in rows)
                for slot,material in enumerate(MATERIALS)]})
    return {"native_ticks":len(native),"visited_cells":stats([row["visited_cells"] for row in native]),
        "moved_cells":stats([row["moved_cells"] for row in native]),
        "active_tick_fraction":sum(active(row) for row in native)/len(native),"seconds":buckets,
        "material_histograms":[dict(sorted(Counter(str(row["brush_cells"][slot]["material"]) for row in native).items()))
            for slot in range(2)]}


def verify_workload(result: dict,mode: str,helper_sha256: str) -> dict:
    """Caller must first pass verify_result: complete source/owner/step custody."""
    require(mode in MODES,"Unregistered workload mode")
    value=result.get("workload",{})
    require(value.get("mode")==mode and value.get("started") is True,"Wrong/unstarted workload")
    require(value.get("recipe")==RECIPE and value.get("recipe_sha256")==RECIPE_SHA256,
            "Workload recipe identity changed")
    require(value.get("helper_sha256")==helper_sha256 and re.fullmatch(r"[0-9a-f]{64}",helper_sha256) is not None,
            "Workload helper differs from executed source")
    require(value.get("errors")==[],"Workload producer reported an error")
    scope=value.get("scope",{})
    require(scope=={"normal_brush_queue":True,"native_world_queries_from_main":0,
                    "priming_usec":0,"per_command_native_applied_receipts":False,
                    "individual_admission_then_measured_cell_activity":True,
                    "producer_cost_outside_main_callback":True},"Unsupported workload authority/receipt claim")
    measurement=result["measurement"];started=measurement["started_usec"];ended=measurement["ended_usec"]
    require(value.get("started_usec")==started and ended<=value.get("stopped_usec",-1)<=ended+15_000_000,
            "Workload interval differs from gameplay measurement")
    owner=measurement["initial"]
    require(value.get("owner")==owner,"Workload copied another starting owner")
    require(owner.get("native_tick",0)>0 and owner.get("native_paused") is False
            and owner.get("suspended") is False,"Workload began before native running acknowledgement")
    acknowledgements=[wait for wait in result.get("waits",[]) if wait.get("name")=="initial loaded owner native progress"]
    require(len(acknowledgements)==1 and acknowledgements[0].get("passed") is True
            and acknowledgements[0].get("limit_usec")==15_000_000
            and acknowledgements[0]["started_usec"]<=acknowledgements[0]["ended_usec"]<=started,
            "Missing bounded native-running acknowledgement")
    pulses=value.get("pulses")
    require(type(pulses) is list and len(pulses)==PULSES,"Incomplete workload pulse inventory")
    main=result["main_rows"]
    cursor=0;previous_end=started;commands=[];producer_times=[];lateness=[]
    for pulse_id,pulse in enumerate(pulses,1):
        due=started+(pulse_id-1)*PERIOD_USEC
        integer(pulse.get("id"),"pulse identity",1)
        integer(pulse.get("scheduled_usec"),"pulse schedule")
        require(pulse.get("id")==pulse_id and pulse.get("scheduled_usec")==due
                and pulse.get("recipe_sha256")==RECIPE_SHA256,"Workload pulse source/order mismatch")
        entered=integer(pulse.get("entered_usec"),"pulse entry")
        finished=integer(pulse.get("ended_usec"),"pulse exit")
        require(due<=entered<due+PERIOD_USEC and previous_end<=entered<=finished<=ended,
                "Late/reordered workload pulse")
        while cursor<len(main) and main[cursor]["ended_usec"]<=entered:
            cursor+=1
        require(cursor>0,"Workload has no preceding actual Main callback")
        callback=main[cursor-1]
        require(finished<=(main[cursor]["started_usec"] if cursor<len(main) else ended),
                "Workload pulse crosses the next Main callback")
        before,after=pulse.get("before"),pulse.get("after")
        state_valid(before);state_valid(after)
        require(same(before,owner,LOAD_OWNER) and same(after,owner,LOAD_OWNER),"Workload owner/generation changed")
        require(same(before,after,tuple(k for k in before if k!="time_usec")),"Brush request mutated playable owner state")
        for state in (before,after):
            require(not any(state[key] for key in ("paused","pending","rearm","suspended","native_paused"))
                    and state["focus"] and state["fault"]=="","Workload admitted without playable authority")
            require(state["serial"]==callback["serial"] and state["native_tick"]==callback["tick"]
                    and state["epoch"]==callback["epoch"] and state["world_generation"]==callback["generation"],
                    "Workload state has no matching actual Main publication")
        require(entered<=before["time_usec"]<=after["time_usec"]<=finished,"Workload state timestamps reordered")
        batch=pulse.get("commands")
        require(type(batch) is list and len(batch)==2,"Incomplete workload command inventory")
        previous=before["time_usec"]
        for slot,command in enumerate(batch):
            for field in ("id","pulse_id","slot","material","flags","size"):
                integer(command.get(field),"brush command "+field)
            require(command.get("id")==2*(pulse_id-1)+slot+1 and command.get("pulse_id")==pulse_id
                    and command.get("slot")==slot,"Duplicate/reordered workload command")
            require(command.get("centre")==list(CENTRES[slot]) and command.get("material")==MATERIALS[slot]
                    and command.get("flags")==0 and command.get("shape")=="square" and command.get("size")==8
                    and command.get("points")==footprint(CENTRES[slot])
                    and all(type(point) is int for point in command["points"]),"Workload footprint/material changed")
            begin=integer(command.get("started_usec"),"command start")
            end=integer(command.get("ended_usec"),"command end")
            require(previous<=begin<=end<=after["time_usec"],"Workload command timing reordered")
            active_mode=mode==ACTIVE
            require(command.get("attempted") is active_mode and command.get("accepted") is active_mode
                    and command.get("control_skipped") is (not active_mode),"Wrong brush admission/control disposition")
            previous=end;commands.append(command)
        previous_end=finished;producer_times.append(finished-entered);lateness.append(entered-due)
    native=result["native_rows"]
    require(type(native) is list and native,"Missing actual workload native completions")
    for row in native:
        integer(row.get("visited_cells"),"visited cells");integer(row.get("moved_cells"),"moved cells")
        numeric(row.get("brush_observer_usec"),"brush cell observer time")
        cells=row.get("brush_cells")
        require(type(cells) is list and len(cells)==2,"Missing native brush cell observations")
        for cell,centre in zip(cells,CENTRES):
            for field in ("completed_tick","x","y"):integer(cell.get(field),"native brush cell "+field)
            require(cell.get("ok") is True and cell.get("completed_tick")==row["tick"]
                    and (cell.get("x"),cell.get("y"))==centre,"Stale/mismatched native brush cell observation")
            integer(cell.get("material"),"observed native material")
    activity=activity_summary(native,started)
    errors=active_activity_errors(activity)
    if mode==ACTIVE:
        require(not errors,"Active workload failed actual cell activity: "+", ".join(errors))
    else:
        require(bool(errors),"Matched no-load negative unexpectedly passed active activity")
    return {"mode":mode,"recipe_sha256":RECIPE_SHA256,"pulse_count":len(pulses),
        "command_count":len(commands),"admitted_commands":sum(command["accepted"] for command in commands),
        "activity":activity,"active_activity_passed":not errors,"activity_rejections":errors,
        "pulse_lateness_usec":stats(lateness),"producer_usec":stats(producer_times),
        "enqueue_call_usec":stats([command["ended_usec"]-command["started_usec"] for command in commands]),
        "brush_cell_observer_usec":stats([row["brush_observer_usec"] for row in native]),
        "all_native_observer_usec":stats([row["observer_usec"]+row["brush_observer_usec"] for row in native]),
        "individual_native_application_receipts":False,
        "qualification":"ordinary brush admission and actual active native work" if mode==ACTIVE else
                        "matched no-load adverse control; not active workload qualification"}
