#!/usr/bin/env python3
"""Reduce exact-runtime Windows GL/ANGLE flyer presentation A/B trials.

The A/B only changes the GDScript overlay source. Physics, Rapier and World
retain the byte-qualified PR566 native DLL and the same authored flight input.
Reports actual native/actor/pixel evidence; distinguishes safety from visual
preference. Does not call hosted ANGLE a physical GPU acceptance.
"""
import hashlib
import json
import math
import pathlib
import statistics
import struct
import sys

MODES = ["mask", "live"]
CAMERAS = ["free", "follow"]
FIRE = ["nofire", "fire"]
EXPECTED = [(fire,mode,camera) for fire in FIRE for camera in CAMERAS for mode in MODES]
CAPTURE_MAGIC = b"\x89PNG\r\n\x1a\n"


def distance(a,b):
    return math.dist([float(x) for x in a],[float(x) for x in b])


def percentile(values,q):
    if not values: return None
    xs=sorted(values)
    pos=(len(xs)-1)*q
    low=int(pos)
    high=min(low+1,len(xs)-1)
    return xs[low]*(1.0-(pos-low))+xs[high]*(pos-low)


def parse_one(output,fire,mode,camera):
    arm=f"{fire}-{mode}-{camera}"
    source=output / "reports" / f"{arm}.json"
    doc=json.loads(source.read_text("utf-8"))
    if doc.get("failures"): raise AssertionError(f"{arm} fixture failures: {doc['failures']}")
    if (doc.get("trial"),doc.get("pose_mode"),doc.get("camera_mode")) != (fire,mode,camera):
        raise AssertionError(f"{arm} arm label mismatch")
    if doc.get("source_parent") != "214de85adef2aaabc8e26de8612a3bf27cc1a081":
        raise AssertionError(f"{arm} PR566 parent mismatch")
    if doc.get("os") != "Windows" or doc.get("display_server") in (None,"headless"):
        raise AssertionError(f"{arm} did not use Windows graphical display")
    if ("gl_compatibility" not in str(doc.get("render_driver","")) and
            "gl_compatibility" not in str(doc.get("render_driver","")).lower()):
        raise AssertionError(f"{arm} not a GL Compatibility rendering process")
    samples=doc.get("samples",[])
    if len(samples)<90 or int(doc.get("native_frames",0))<90 or max(int(r["tick"]) for r in samples)<215:
        raise AssertionError(f"{arm} incomplete Rapier/native telemetry")
    if fire=="fire" and int(doc.get("actual_fire_inserts",0))<=0:
        raise AssertionError(f"{arm} no actual Fire inserted")
    if fire=="nofire" and int(doc.get("actual_fire_inserts",0))!=0:
        raise AssertionError(f"{arm} control emitted Fire")
    frames=[]
    for row in doc.get("frame_captures",[]):
        image=output/"frames"/arm/row["png"]
        data=image.read_bytes()
        if data[:8] != CAPTURE_MAGIC or data[12:16]!=b"IHDR":
            raise AssertionError(f"{arm} missing PNG pixels: {image}")
        width,height=struct.unpack(">II",data[16:24])
        if [width,height]!=row["framebuffer"] or width<600 or height<360:
            raise AssertionError(f"{arm} framebuffer size invalid")
        if (row["mode"],row["camera"])!=(mode,camera):
            raise AssertionError(f"{arm} captured wrong mode/camera")
        if row["captured_tick"]-row["requested_tick"]>5:
            raise AssertionError(f"{arm} capture straddled excessive physics steps")
        if float(row["drawn_vs_selected"]) > 0.01:
            raise AssertionError(f"{arm} captured overlay did not select its requested pose")
        frames.append({"filename":image.relative_to(output).as_posix(),
                       "sha256":hashlib.sha256(data).hexdigest(),
                       "bytes":len(data),"tick":row["captured_tick"],
                       "pose_gap":row["pose_gap"],
                       "geometry":row["geometry"],
                       "drawn_vs_selected":row["drawn_vs_selected"],
                       "mask_revision":row["mask_revision"],
                       "uploaded_revision":row["uploaded_revision"]})
    if len(frames)<8: raise AssertionError(f"{arm} missing planned real graphical captures")
    # ABL runs may skip a tick at screenshot handoff, so compare keyed physics.
    indexed={int(row["tick"]):row for row in samples}
    return {"arm":arm,"godot":doc["godot"],"display":doc["display_server"],
            "renderer":doc["render_driver"],"native_frames":doc["native_frames"],
            "real_fire_inserts":doc["actual_fire_inserts"],
            "sample_count":len(samples),"mode":mode,"camera":camera,
            "mask_rev_matched":doc["matched_mask_samples"],
            "nonzero_pose_gap_samples":doc["nonzero_pose_gap_samples"],
            "max_mask_live_gap":doc["max_pose_gap"],
            "max_mask_live_geometry_xor":doc["max_live_mask_xor"],
            "hold_count":sum(a["display_position"]==b["display_position"]
                             for a,b in zip(samples,samples[1:])),
            "drawn_stutter_count":sum(a["drawn_position"]==b["drawn_position"]
                                     for a,b in zip(samples,samples[1:])),
            "display_vs_live_p95":percentile(
                [distance(row["display_position"],row["live_position"])
                 for row in samples],.95),
            "drawn_vs_live_p95":percentile(
                [distance(row["drawn_position"],row["live_position"])
                 for row in samples if all(math.isfinite(x) for x in row["drawn_position"])],.95),
            "frames":frames,
            "_physics":indexed}


def reduce(root):
    groups={}
    for fire,mode,camera in EXPECTED:
        row=parse_one(root,fire,mode,camera)
        groups[row["arm"]]=row
    identities={(r["godot"],r["display"],r["renderer"]) for r in groups.values()}
    if len(identities)!=1: raise AssertionError("A/B runtime/display renderer identities differ")
    comparisons=[]
    for fire in FIRE:
        for camera in CAMERAS:
            a=groups[f"{fire}-mask-{camera}"]
            b=groups[f"{fire}-live-{camera}"]
            overlap=sorted(a["_physics"].keys()&b["_physics"].keys())
            if len(overlap)<70: raise AssertionError(f"fewer than 70 matched real Rapier ticks: {fire}/{camera}")
            delta_position=max(distance(a["_physics"][t]["position"],b["_physics"][t]["position"]) for t in overlap)
            delta_velocity=max(distance(a["_physics"][t]["velocity"],b["_physics"][t]["velocity"]) for t in overlap)
            if delta_position>1e-3 or delta_velocity>1e-3:
                raise AssertionError(f"Non-presentation-only physical trajectory difference: {fire}/{camera}: {delta_position} / {delta_velocity}")
            comparisons.append({"trial":fire,"camera":camera,"paired_ticks":len(overlap),
                "maximum_Rapier_position_difference":delta_position,
                "maximum_Rapier_velocity_difference":delta_velocity,
                "mask_drawn_vs_live_p95":a["drawn_vs_live_p95"],
                "live_drawn_vs_live_p95":b["drawn_vs_live_p95"],
                "mask_pose_gap_max":a["max_mask_live_gap"],
                "live_actor_geometry_departure_cells_max":b["max_mask_live_geometry_xor"],
                "mask_drawn_holds":a["drawn_stutter_count"],
                "live_drawn_holds":b["drawn_stutter_count"],
                "fire_insertions":[a["real_fire_inserts"],b["real_fire_inserts"]]})
    for row in groups.values():
        row.pop("_physics")
    out={"schema":"pr566-flyer-presentation-ab-v1","source_pr":566,
         "native_build_run":43537909868,
         "native_windows_binary_sha256":"6c7811b78c12e34a68931f83f2fd505c20078c089bce245a9be8be6e02e6d04d",
         "context":"Windows hosted GL Compatibility / ANGLE graphical + real native World and Rapier; no assertion of a dedicated hardware GPU",
         "cohort_count":len(groups),"comparisons":comparisons,"arms":groups,
         "interpretation_rules":[
           "A pixel-visible hold/jump reduction in live mode must be interpreted with same-physics controls.",
           "A live-mode geometric XOR relative to the material-revision-bound mask is an alignment risk, not proof of actual cell penetration.",
           "Pixel frames use time-varying shaders; RGB differences are not actor-pose-only by themselves.",
           "This is an investigative build, not a qualified production repair or approval to merge PR566."
         ]}
    return out


def main():
    if len(sys.argv)!=3:
        raise SystemExit("usage: reduce_pr566_flyer_pose_ab.py <evidence-directory> <summary-output.json>")
    result=reduce(pathlib.Path(sys.argv[1]))
    dest=pathlib.Path(sys.argv[2]); dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(json.dumps(result,indent=2,allow_nan=False)+"\n",encoding="utf-8")
    for x in result["comparisons"]:
        print("PR566_POSE_AB_PAIR",json.dumps(x,sort_keys=True))
    print("PR566_POSE_AB_SUMMARY",json.dumps({"groups":len(result["arms"]),
          "pairs":len(result["comparisons"]),"native_sha256":result["native_windows_binary_sha256"]}))
    return 0


if __name__=="__main__":
    sys.exit(main())
