"""Bounded Stage C: two original d1-selected, native/graphical pilots per Art family.

The six pilot cases were frozen before executing their model outputs. This
module reuses the Stage B host-owned fuzzy choice schema and the unchanged
#568 compiler; neither a model nor an evaluation result mutates a fixture.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time
import traceback

from PIL import Image
from experiments.agent_painter.compiler import compile_program
from experiments.driv3r.contracts import Refusal, digest
from experiments.driv3r.controller import EpisodeController, write_json
from experiments.driv3r.native import NativeSession
from experiments.driv3r.provenance import ROOT, runtime_custody
from experiments.driv3r.qualify import new_backend, controller_safety
from experiments.driv3r.replay import replay_episode
from experiments.driv3r.tests.test_native import run_native_regressions
from experiments.driv3r.stage_b import fuzzy
from experiments.driv3r.stage_b.representation import SemanticPolicy

CATALOG = Path(__file__).with_name("cases.json")
ORIGINAL_STAGE_B = "2ea0f09c8fbbead7386f47232b0a61cff59bdfdc"
BASELINE_RELEASE_SHA256 = "17b22a80463594575ea28cb688a5b5ab155366b1127d09c3198aef853cae3ce6"
FAMILIES = ("pipework", "architecture", "greebles")


def _compiled(option: dict) -> dict:
    return compile_program(option["program"], seed=570, focus=(0, 0, 96, 96),
                           material=58, allowed_materials=(58,),
                           max_operations=16, max_cell_work=1024)


def prepare_cases() -> list[tuple[dict, dict]]:
    """Independent Stage C IDs with underlying frozen, distinct real-native fixtures."""
    document = json.loads(CATALOG.read_text())
    if (type(document) is not dict or set(document) !=
            {"schema", "source_stage_b", "scope", "cases"} or
            document["schema"] != "driv3r-stage-c-pilot-v1" or
            document["source_stage_b"] != ORIGINAL_STAGE_B or
            type(document["cases"]) is not list or len(document["cases"]) != 6):
        raise Refusal("Invalid or redefined Stage C frozen catalog")
    frozen_fixtures = {c["id"]: c["fixture"] for c in fuzzy.load_cases()}
    ids, families, fixture_ids, prepared = set(), [], set(), []
    for item in document["cases"]:
        if type(item) is not dict or set(item) != {
                "id", "family", "fixture_source", "cursor", "target",
                "objective", "paraphrase", "subgoal", "target_candidate_id", "candidates"}:
            raise Refusal("Invalid Stage C case shape")
        family, case_id, fixture = item["family"], item["id"], item["fixture_source"]
        if (type(case_id) is not str or not case_id.startswith("c-"+family+"-") or
                family not in FAMILIES or case_id in ids or fixture not in frozen_fixtures or
                fixture in fixture_ids):
            raise Refusal("Stage C family/case/fixture identity invalid or duplicated")
        ids.add(case_id)
        families.append(family)
        fixture_ids.add(fixture)
        options = item["candidates"]
        if (type(options) is not list or len(options) != 3 or
                len({v["id"] for v in options}) != 3 or
                item["target_candidate_id"] not in {v["id"] for v in options}):
            raise Refusal("Stage C requires three distinct tools and one frozen target")
        if any(v["program"]["family"] != family for v in options):
            raise Refusal("Stage C tools must belong to their declared Art family")
        target = next(v for v in options if v["id"] == item["target_candidate_id"])
        expected = _compiled(target)
        required = [[op["x0"], op["y0"], op["x1"]-op["x0"]+1, op["y1"]-op["y0"]+1]
                    for op in expected["operations"]]
        pseudo_case = {
            "id": fixture, "split": "held_out", "fixture": deepcopy(frozen_fixtures[fixture]),
            "cursor": item["cursor"], "target": item["target"],
            "objective": item["objective"], "paraphrase": item["paraphrase"],
            "subgoal": item["subgoal"], "candidates": deepcopy(options),
            "evaluation": {"kind": "coverage", "required_rectangles": required,
                           "allowed_new_rectangles": deepcopy(required),
                           "connectivity": [], "support_columns": []},
        }
        fuzzy.validate_case(pseudo_case)
        candidate_masks = []
        for option in options:
            compiled = _compiled(option)
            mask = {(x, y) for op in compiled["operations"]
                    for y in range(op["y0"], op["y1"]+1)
                    for x in range(op["x0"], op["x1"]+1)}
            candidate_masks.append(mask)
        if len({digest(sorted(mask)) for mask in candidate_masks}) != 3:
            raise Refusal("Stage C alternatives must produce three distinct material masks")
        if sum(mask == candidate_masks[options.index(target)] for mask in candidate_masks) != 1:
            raise Refusal("Frozen target mask is not unique among candidates")
        prepared.append((deepcopy(item), pseudo_case))
    if sorted(families) != sorted([f for f in FAMILIES for _ in range(2)]):
        raise Refusal("Stage C must hold exactly two cases in each Art family")
    return prepared


def _frame_check(session: NativeSession, before: dict, output: Path) -> dict:
    capture = session.frame(timeout=35)
    if capture.get("status") != "completed":
        raise Refusal("Actual graphical framebuffer capture failed: " + str(capture))
    frame = capture["frame"]
    path = session.output / frame["path"]
    with Image.open(path) as pic:
        pic.verify()
    with Image.open(path) as pic:
        if pic.size != (frame["width"], frame["height"]):
            raise Refusal("Frame PNG dimensions differ from Godot report")
        colors = len(set(pic.convert("RGB").resize((80, 50)).getdata()))
    if colors < 4:
        raise Refusal("Graphical framebuffer appears blank or unrendered")
    after = session.observe(timeout=35)["observation"]
    keys = ("world_id", "generation", "revision", "tick", "world_material_sha256")
    if any(before.get(key) != after.get(key) for key in keys):
        raise Refusal("Framebuffer capture mutated native World identity or materials")
    return {"status": "passed", "capture_type": frame["capture_type"],
            "path": str(path.relative_to(output)), "sha256": frame["sha256"],
            "width": frame["width"], "height": frame["height"],
            "sample_unique_rgb_colors": colors, "native_unchanged": True}


def run(args):
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True).strip()
    if sha != args.source_sha:
        raise Refusal("Stage C requires exact committed source")
    case_hash = hashlib.sha256(CATALOG.read_bytes()).hexdigest()
    request_path = CATALOG.with_name("qualification-request.json")
    request = json.loads(request_path.read_text())
    if (request != {"schema": "driv3r-stage-c-request-v1", "sequence": 4,
                    "stage_b_source": ORIGINAL_STAGE_B, "stage_b_release_sha256": BASELINE_RELEASE_SHA256,
                    "frozen_case_sha256": case_hash, "draft_hold": True}):
        raise Refusal("Stage C qualification request not frozen or not matched")
    summary = {"schema":"driv3r-stage-c-summary-v1", "stage":"C", "source_sha":sha,
        "source_tree":tree, "frozen_cases_sha256":case_hash, "stage_b_source":ORIGINAL_STAGE_B,
        "stage_b_release_sha256":BASELINE_RELEASE_SHA256, "draft_hold":True,
        "campaign_complete":False, "infrastructure_passed":False, "result":"HOLD",
        "episodes":[], "frames":[], "replays":[], "safety":{},
        "limitations":["Six original small fixtures; no artistic-quality or population-generalization claim",
                       "Each model has one tool choice with at most three authorized actions",
                       "Graphical viewport captures are separate from native material PNGs",
                       "Q8 only; no demonstrated need to substitute reference or Q4"]}
    backend = None
    try:
        prepared = prepare_cases()
        write_json(output/"frozen-input.json",{"cases":len(prepared),"case_sha256":case_hash,
                   "request":request,"source_sha":sha,"source_tree":tree})
        custody = runtime_custody(sha,args.runtime_manifest,args.godot)
        write_json(output/"runtime-custody.json",custody)
        write_json(output/"host.json",{"platform":platform.platform(),"python":sys.version,
                  "cpu_count":os.cpu_count(),"affinity":sorted(os.sched_getaffinity(0))})
        runtime = json.loads((args.runtime_dir/"runtime-manifest.json").read_text())
        write_json(output/"model-runtime.json",runtime)
        backend = new_backend(runtime, output/"resident-inference", threads=2, ctx_size=4096, batch_size=4096)
        records = []
        with backend:
            # True graphical Godot process and six independent native fixture resets.
            with NativeSession(ROOT,args.godot,output/"graphical-native",sha,
                               runtime_manifest=args.runtime_manifest,graphical=True) as native:
                for case, pseudo in prepared:
                    identifier = case["id"]+"-model"
                    record = EpisodeController(max_decisions=3,max_changed_cells=1024,
                        max_wall_seconds=180,request_seconds=90).run(
                            native=native,provider=fuzzy.FuzzyCaseProvider(pseudo),
                            policy=SemanticPolicy(backend),episode_id=identifier,output=output/identifier)
                    score = fuzzy.score_episode(pseudo,record)
                    write_json(output/identifier/"score.json",score)
                    original = {"case_id":case["id"],"family":case["family"],
                       "fixture_source":case["fixture_source"],"episode_id":identifier,
                       "record_sha256":digest(record), "decision_choices":[step.get("decision",{}).get("candidate_id")
                             for step in record["steps"] if step.get("decision")],
                       "actual_changed_cells":record.get("actual_changed_cells"),
                       "score":score,"terminal":record["terminal_status"]}
                    # A bad decision is retained and not silently replaced with the frozen target.
                    if not record.get("final_native") or record["terminal_status"] in (
                            "model_failure","invalid_decision","native_refusal","cancelled"):
                        raise Refusal("Native/model implementation failed: "+identifier)
                    frame = _frame_check(native, record["final_native"],output)
                    summary["frames"].append({"episode_id":identifier, **frame})
                    summary["episodes"].append(original)
                    records.append((case,record))
                    print(json.dumps({"event":"stage-c-episode","case":case["id"],
                        "selected":original["decision_choices"],"native_cells":record.get("actual_changed_cells"),
                        "geometry_success":score.get("task_success"),"frame":frame["sha256"]}),flush=True)
        summary["model_process"]={"startup":backend.startup_record,"shutdown":backend.shutdown_record}
        # Exact native replay of original decisions; no model reinference or choice repair.
        with NativeSession(ROOT,args.godot,output/"replay-headless",sha,
                           runtime_manifest=args.runtime_manifest) as native:
            for case,record in records:
                replay=replay_episode(record,native,output/"graphical-native",
                          output/(record["episode_id"]+"-replay"))
                summary["replays"].append({"episode_id":record["episode_id"],
                    "passed":replay["passed"],"original_episode_sha256":replay["original_episode_sha256"]})
        controls=run_native_regressions(ROOT,args.godot,output/"native-controls",sha,args.runtime_manifest)
        summary["safety"]["native_controls"]={"passed":controls["passed"],"checks":len(controls["checks"])}
        cleanups=[json.loads(p.read_text()) for p in output.rglob("cleanup.json")]
        summary["cleanup"]={"passed":all(x.get("graceful") and x.get("exit_code")==0 for x in cleanups),
                            "native_process_count":len(cleanups)}
        summary["persistent_model"]={"passed":len({s["decision"]["raw"]["pid"]
            for _,rec in records for s in rec["steps"] if s.get("decision_requested")})==1}
        summary["campaign_complete"]=len(records)==6
        summary["infrastructure_passed"]=all((summary["campaign_complete"],
            summary["cleanup"]["passed"], summary["persistent_model"]["passed"],
            controls["passed"],len(summary["frames"])==6,
            len(summary["replays"])==6,all(x["passed"] for x in summary["replays"]),
            runtime_custody(sha,args.runtime_manifest,args.godot)==custody))
        summary["result"]="QUALIFIED_RESEARCH_HANDOFF" if summary["infrastructure_passed"] else "HOLD"
    except Exception as exc:
        summary["failure"]={"type":type(exc).__name__,"message":str(exc),
                            "traceback":traceback.format_exc()}
        write_json(output/"failure.json",summary["failure"])
    finally:
        if backend is not None:
            backend.close()
        summary["behavior"]={"successes":sum(bool(x["score"].get("task_success"))
            for x in summary["episodes"]),"episodes":len(summary["episodes"]),
            "success_by_family":{f:sum(x["family"]==f and x["score"].get("task_success")
            for x in summary["episodes"]) for f in FAMILIES}}
        write_json(output/"summary.json",summary)
        lines=["# DRIV3R Stage C — original graphical/native pilot",
            "",f"**Result: {summary['result']}** · source {sha} · Draft/HOLD",
            "",f"Stage B gate source {ORIGINAL_STAGE_B}; verified release {BASELINE_RELEASE_SHA256}.",
            "",f"Model choices with actual native material/score: {len(summary['episodes'])}/6.",
            f"Genuine graphical framebuffer captures: {len(summary['frames'])}/6.",
            f"Native replay: {sum(r['passed'] for r in summary['replays'])}/{len(summary['replays'])}.",
            f"Correct geometry selected: {summary['behavior']['successes']}/{len(summary['episodes'])}.",
            "","The drawing score derives from the original native material readback and",
            "the frozen target compiler footprint, never from model labels or graph termination.",
            "No model action may bypass the Workbench Art compiler/permission authority.",
            "","## Original decisions, material and framebuffer"]
        for x in summary["episodes"]:
            frame=next((v for v in summary["frames"] if v["episode_id"]==x["episode_id"]),None)
            lines.extend(["",f"### {x['case_id']} ({x['family']})",
                f"- Model choice: {x['decision_choices']} · changed native cells: {x['actual_changed_cells']}",
                f"- Target material geometry: {'PASS' if x['score'].get('task_success') else 'FAIL'}",
                f"- Framebuffer: {frame['path'] if frame else 'MISSING'}"])
        if "failure" in summary: lines.extend(["","## Failure",summary["failure"]["message"]])
        lines.extend(["","This is a small bounded engineering pilot, not a trained painter,",
                      "model-superiority proof or Windows/GPU owner acceptance."])
        (output/"report.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    return 0 if summary["infrastructure_passed"] else 1


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--godot",required=True,type=Path)
    p.add_argument("--runtime-manifest",required=True,type=Path)
    p.add_argument("--source-sha",required=True)
    p.add_argument("--runtime-dir",required=True,type=Path)
    p.add_argument("--output",required=True,type=Path)
    raise SystemExit(run(p.parse_args()))


if __name__=="__main__":
    main()
