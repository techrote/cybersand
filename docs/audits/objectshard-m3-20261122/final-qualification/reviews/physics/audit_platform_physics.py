#!/usr/bin/env python3
"""Independent read-only audit of the fresh M3 Windows qualification artifacts.

All writes are under build/review-physics. This does not execute Windows code;
it checks exact-source identities, raw hosted trace continuity and retained data.
"""
from __future__ import annotations

import collections
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/review-physics"
PLATFORM = ROOT / "build/m3-platform/windows"
EVIDENCE = PLATFORM / "14744390583"
SHA = "68235b12d7f41f7b590456971f21dfc3f5c6d701"
TREE = "f533105e41b33e75c07c93aa0c8c40438e7bc112"
NATIVE = "6858f326f31c8c26adaf08a83f4c99d127cdc9d33d5bc71afcd2c324afca5d1f"
errors: list[str] = []
checks = 0
source_hashes: dict[str, str] = {}
inputs: dict[str, str] = {}


def check(ok: bool, detail: str) -> None:
    global checks
    checks += 1
    if not ok:
        errors.append(detail)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def bind(path: Path) -> str:
    value = digest(path.read_bytes())
    inputs[str(path.relative_to(ROOT))] = value
    return value


def read(path: Path):
    bind(path)
    return json.loads(path.read_text())


def git_digest(path: str) -> str:
    if path not in source_hashes:
        source_hashes[path] = digest(subprocess.check_output(["git", "show", f"{SHA}:{path}"], cwd=ROOT))
    return source_hashes[path]


def verify_source_map(name: str, values: dict[str, str]) -> None:
    for path, value in values.items():
        check(git_digest(path) == value, f"{name} differs from exact Git blob: {path}")


def distribution(values: list[int]) -> dict[str, int]:
    values = sorted(values)
    return {"count": len(values), "maximum": max(values), **{
        f"p{percent}": values[math.ceil(len(values) * percent / 100) - 1]
        for percent in (50, 95, 99)
    }}


def clean_physics(value):
    if isinstance(value, dict):
        return {k: clean_physics(v) for k, v in value.items() if not k.endswith("_usec")}
    if isinstance(value, list):
        return [clean_physics(v) for v in value]
    return value


def audit_trace(name: str) -> tuple[dict, list, dict]:
    directory = EVIDENCE / name
    summary = read(directory / "continuous-physics.json")
    path = directory / "continuous-physics-session-1.jsonl"
    bind(path)
    rows = [json.loads(line) for line in path.open()]
    kinds = collections.Counter(row["kind"] for row in rows)
    events = collections.Counter()
    actions = []
    steps = []
    first_poses = {}
    maximum_displacements = collections.defaultdict(float)
    moving, sleeping, contacting = set(), set(), set()
    last_segment = 0
    last_worker_sequence = 0
    pending_segment = None
    tick_receipts = []
    previous_physics_steps = 0
    previous_pose_serial = 0
    worker_threads = set()
    preparation_busy = collections.Counter()
    for index, row in enumerate(rows):
        check(row["sequence"] == index, f"{name} raw trace sequence discontinuity {index}")
        if row["kind"] == "event":
            event = row["detail"]
            events[event["kind"]] += 1
            d = event["detail"]
            if event["kind"] == "PhysicsSegmentAwaitingNative":
                check(pending_segment is None, f"{name} solver advanced before previous native receipt at {index}")
                check(d["segment_sequence"] == last_segment + 1, f"{name} segment sequence gap at {index}")
                last_segment = d["segment_sequence"]
                pending_segment = row
            elif event["kind"] == "NativeReceipt":
                check(d["sequence"] == last_worker_sequence + 1, f"{name} worker receipt sequence gap at {index}")
                last_worker_sequence = d["sequence"]
                worker_threads.add(d["owner_thread"])
                check(d["requested_session"] == d["published_session"] == 1, f"{name} receipt session mismatch at {index}")
                # A preparation scan with no candidate is an expected bounded
                # census outcome; host purpose=prepare explicitly continues
                # motion for Busy. Every actual material/pose mutation must ACK.
                expected_busy = d["operation"] == d["purpose"] == "prepare" and d["result"].get("outcome") == "Busy"
                if expected_busy:
                    preparation_busy[d["result"]["detail"]] += 1
                check(d["result"].get("ok", False) or expected_busy, f"{name} unexpected native refusal at {index}: {d['result']}")
                if d["operation"] == "motion":
                    check(pending_segment is not None, f"{name} motion receipt without pending segment at {index}")
                    check(d["result"].get("applied", False), f"{name} unapplied motion at {index}")
                    check(d["result"]["semantic_tick"] == row["tick"] == pending_segment["tick"], f"{name} motion receipt tick mismatch at {index}")
                    poses = d["result"]["accepted_pose_serials"]
                    check(bool(poses) and len({p["id"] for p in poses}) == len(poses), f"{name} motion pose identities empty/duplicate at {index}")
                    check(all(p["pose_serial"] > previous_pose_serial for p in poses), f"{name} stale pose serial at {index}")
                    previous_pose_serial = max(p["pose_serial"] for p in poses)
                    tick_receipts.append((pending_segment["detail"]["detail"], d["result"]))
                    pending_segment = None
        elif row["kind"] == "action":
            actions.append(row)
            check(row["detail"]["result"].get("ok", False), f"{name} refused sustained action at {index}")
        elif row["kind"] == "step_completed":
            steps.append(row)
            d, tick = row["detail"], row["tick"]
            p = d["physics"]
            m = p["motion"]
            check(tick == len(steps) + 1 == d["native_tick"] == p["last_completed_semantic_tick"], f"{name} semantic clock mismatch at {index}")
            check(d["completed_ticks"] == p["operation_sequence"] == m["operation_sequence"] == len(steps), f"{name} interval count mismatch at {index}")
            check(not p["awaiting_native"] and not p["motion_refused"] and not p["last_error"] and p["motion_phase"] == "Completed", f"{name} incomplete/refused physics at {index}")
            check(pending_segment is None, f"{name} completed before native motion acknowledgement at {index}")
            check(len(tick_receipts) == m["applied_segments"], f"{name} applied segment receipt count mismatch at {index}")
            check(1 <= m["substeps"] <= m["maximum_substeps"] == 16, f"{name} invalid physical interval budget at {index}")
            check(p["physics_steps"] - previous_physics_steps == m["substeps"], f"{name} physical step accounting mismatch at {index}")
            previous_physics_steps = p["physics_steps"]
            for field in ("requested_delta", "completed_delta", "applied_delta"):
                check(abs(m[field] - 1 / 60) < 1e-14, f"{name} wrong {field} at {index}")
            if tick_receipts:
                check(abs(sum(x[0]["delta"] for x in tick_receipts) - 1 / 60) < 1e-14, f"{name} native-acknowledged segment time mismatch at {index}")
                accepted = {item["id"]: item for item in tick_receipts[-1][1]["accepted_pose_serials"]}
                check(set(accepted) == {b["id"] for b in p["bodies"]}, f"{name} final motion owner identity mismatch at {index}")
                for b in p["bodies"]:
                    a = accepted[b["id"]]
                    check(all(a[k] == b[k] for k in ("id", "generation", "body_generation", "geometry_revision")) and a["session"] == p["session"] and a["pose_serial"] == p["last_sampled_pose_serial"], f"{name} accepted pose/geometry identity mismatch at {index}")
            for b in p["bodies"]:
                bid = b["id"]
                check(b["active"] and b["mass"] > 0 and b["inertia"] > 0 and b["shape_count"] > 0, f"{name} invalid active mass/shape at {index}")
                check(all(math.isfinite(b[k]) for k in ("x", "y", "rotation", "backend_rotation", "vx", "vy", "angular_velocity", "com_x", "com_y", "mass", "inertia")), f"{name} nonfinite body at {index}")
                check(b["rotation"] == b["backend_rotation"], f"{name} material/backend rotation mismatch at {index}")
                first_poses.setdefault(bid, (b["x"], b["y"]))
                distance = math.dist((b["x"], b["y"]), first_poses[bid])
                maximum_displacements[bid] = max(maximum_displacements[bid], distance)
                if distance > .5:
                    moving.add(bid)
                if b["sleeping"]:
                    sleeping.add(bid)
                if b["reported_contacts"] > 0:
                    contacting.add(bid)
            tick_receipts = []
    check(rows[0]["kind"] == "header" and rows[0]["detail"]["source_revision"] == SHA and rows[0]["detail"]["initial_tick"] == 1, f"{name} trace header identity mismatch")
    check(rows[-1]["kind"] == "footer" and rows[-1]["detail"]["complete_prefix"], f"{name} no complete raw trace footer")
    check(kinds["step_requested"] == kinds["step_completed"] == 3599 and steps[-1]["tick"] == 3600, f"{name} sustained endpoint missing")
    check(kinds["action"] == summary["actions_queued"] == 540, f"{name} sustained action count differs")
    check(len(moving) == len(sleeping) == len(contacting) == 3 and all(b["sleeping"] for b in steps[-1]["detail"]["physics"]["bodies"]), f"{name} three substantial moving/contacting/sleeping owners absent")
    for bid, maximum in maximum_displacements.items():
        check(maximum > 10 and abs(maximum - summary["maximum_displacements"][str(bid)]) < 2e-6, f"{name} substantial displacement summary mismatch for {bid}")
    check(summary["source_revision"] == SHA and summary["failures"] == 0 and summary["checks"] == 22513, f"{name} sustained summary failure")
    check(summary["physics_steps"] == previous_physics_steps == 14390 and last_segment == 14388, f"{name} total physical interval accounting mismatch")
    post_edit = [r for r in actions if r["tick"] == 2400 and r["detail"]["parameters"]["material"] == 0]
    check(len(post_edit) == 1, f"{name} exactly one post-settle erase missing")
    erase = post_edit[0]
    target = erase["detail"]["parameters"]["target"]
    check(target["owner"] > 0 and target["expected"]["material"] == 7 and erase["detail"]["result"]["id"] == target["owner"], f"{name} settled erase did not target actual owned Wood")
    before = next(b for s in steps if s["tick"] == 2400 for b in s["detail"]["physics"]["bodies"] if b["id"] == target["owner"])
    after = [b for s in steps if s["tick"] > 2400 for b in s["detail"]["physics"]["bodies"] if b["id"] == target["owner"]]
    translation = max(math.dist((b["x"], b["y"]), (before["x"], before["y"])) for b in after)
    rotation = max(abs(b["rotation"] - before["rotation"]) for b in after)
    check(before["sleeping"] and after[0]["mass"] == before["mass"] - 1 and after[0]["geometry_revision"] > before["geometry_revision"], f"{name} settled erase did not update exact real mass/geometry")
    check(translation < .5 and rotation < .1 and abs(translation - summary["post_erosion_maximum_translation"]) < 1e-9 and abs(rotation - summary["post_erosion_maximum_rotation"]) < 1e-12, f"{name} erosion stability summary differs from raw poses")
    materials = collections.Counter(str(r["detail"]["parameters"]["material"]) for r in actions)
    ledger = summary["native_accounting"]
    check(materials == {"0": 241, "2": 99, "3": 100, "6": 100}, f"{name} sustained action material mix differs")
    check(summary["fire_seen"] and summary["smoke_seen"] and ledger["created"][4] > 0 and ledger["created"][6] > 0 and ledger["destroyed"][7] > 0 and ledger["external_ignitions"] > 0, f"{name} real chemistry evidence absent")
    result = {
        "trace_rows": len(rows), "trace_kinds": dict(kinds), "event_kinds": dict(events),
        "native_endpoint": steps[-1]["tick"], "completed_intervals": len(steps),
        "physical_steps": previous_physics_steps, "acknowledged_nonempty_segments": last_segment,
        "worker_owner_threads": sorted(worker_threads), "action_material_counts": dict(materials),
        "nonmutating_prepare_busy_outcomes": dict(preparation_busy),
        "moving_owners": sorted(moving), "sleeping_owners": sorted(sleeping), "contacting_owners": sorted(contacting),
        "recomputed_maximum_displacements": dict(maximum_displacements),
        "post_settle_edit": erase, "post_edit_rotation": rotation, "post_edit_translation": translation,
        "final_bodies": clean_physics(steps[-1]["detail"]["physics"]["bodies"]),
        "checks_reported": summary["checks"], "timing_usec": summary["timing"],
        "fire_smoke_and_quantity_ledger_scope": "Source-bound runtime assertions and positive native ledger; full material byte arrays are not retained in every trace row, so ledger recomputation from raw cells is not claimed.",
        "capture": summary["report"]["capture"], "package_manifest_sha256": rows[0]["detail"]["package_manifest_sha256"],
    }
    canonical_steps = [clean_physics(s["detail"]["physics"]) for s in steps]
    return result, canonical_steps, summary


def main() -> None:
    check(subprocess.check_output(["git", "rev-parse", f"{SHA}^{{tree}}"], cwd=ROOT).decode().strip() == TREE, "Exact source tree mismatch")
    provenance = read(PLATFORM / "14743743167/candidate-provenance.json")
    check(provenance["source_commit"] == provenance["build_commit"] == SHA and provenance["source_tree"] == TREE and provenance["kind"] == "source-built-windows-candidate", "Fresh Windows candidate provenance mismatch")
    check(bind(PLATFORM / "14743743167/cybersand_native.windows.x86_64.dll") == provenance["sha256"] == NATIVE, "Fresh Windows DLL hash mismatch")
    verify_source_map("candidate native inputs", provenance["source_inputs"])
    qualification = {}
    for name, count in (("windows-lab", 40), ("package-replay", 31)):
        q = read(EVIDENCE / name / "qualification.json")
        check(q["source_commit"] == SHA and q["source_tree"] == TREE and q["status"] == "passed" and not q["failures"], f"{name} qualification source/status mismatch")
        check(len(q["cases"]) == count, f"{name} unexpected case count")
        for case in q["cases"]:
            check(case["status"] == "passed" and case["returncode"] == 0 and case["natural_completion"], f"{name} incomplete case {case['name']}")
            check(bind(EVIDENCE / name / case["log"]) == case["log_sha256"], f"{name} exact per-case log hash differs: {case['name']}")
        for field in ("native_source_inputs", "lab_source_inputs", "qualification_tool_inputs"):
            verify_source_map(name + ":" + field, q[field])
        check(q["native_source_inputs"] == provenance["source_inputs"], f"{name} native provenance map differs")
        check(q["runtime"]["native_sha256"] == NATIVE, f"{name} selected runtime differs")
        qualification[name] = q
    check(qualification["windows-lab"]["runtime"] == qualification["package-replay"]["runtime"], "Source/package runtime identity differs")
    archive_hashes = {}
    for path, expected in [
        (PLATFORM / "14743829036/objectshard-windows-evaluator.zip", "47c55fecfe27272c157c9c7bdbdb864bb78166415c61ea2d8ccc74f502df9015"),
        (PLATFORM / "objectshard-m3-artifact-14744390583.zip", "e2b10d5f114ebffd923f908972e2e4ccc4dd882bcc08f365f5d63d9e3375c9d7"),
    ]:
        archive_hashes[str(path.relative_to(ROOT))] = {"bytes": path.stat().st_size, "sha256": bind(path)}
        check(archive_hashes[str(path.relative_to(ROOT))]["sha256"] == expected, f"Archive hash mismatch {path.name}")
    runtime_members = {}
    with zipfile.ZipFile(PLATFORM / "14743829036/objectshard-windows-evaluator.zip") as z:
        for name in ("Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe", "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll", "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll", "objectshard-lab-manifest.json"):
            data = z.read(name)
            runtime_members[name] = {"bytes": len(data), "sha256": digest(data)}
        check(runtime_members["objectshard-lab-manifest.json"]["sha256"] == qualification["package-replay"]["package_manifest_sha256"], "Delivered manifest binding mismatch")
        for name, source_hash in qualification["windows-lab"]["lab_source_inputs"].items():
            check(name in z.namelist(), "Packaged lab source missing: " + name)
            check(digest(z.read(name)) == source_hash, "Packaged lab source differs: " + name)
    runtime = qualification["windows-lab"]["runtime"]
    check(runtime_members["Godot_v4.7-stable_win64_console.exe"]["sha256"] == runtime["godot_sha256"], "Console launcher hash mismatch")
    check(runtime_members["godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"]["sha256"] == NATIVE, "Delivered native DLL differs")
    check(runtime_members["godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"]["sha256"] == runtime["rapier_sha256"], "Delivered Rapier differs")
    source_trace, source_physics, source_summary = audit_trace("windows-lab")
    zip_trace, zip_physics, zip_summary = audit_trace("package-replay")
    check(source_physics == zip_physics, "Source/package full non-timing physics trajectory differs")
    check(source_summary["native_accounting"] == zip_summary["native_accounting"], "Source/package native ledger differs")
    check(zip_trace["package_manifest_sha256"] == qualification["package-replay"]["package_manifest_sha256"], "Delivered trace manifest does not bind actual ZIP")
    profiles = {str(budget): read(EVIDENCE / "windows-lab" / f"objectshard_worker_profile_{budget}.json") for budget in (0, 4000)}
    for field in ("identity", "engine", "platform", "publication_digests", "native_accounting", "completed_intervals", "actual_live_inputs", "actual_physics_steps"):
        check(profiles["0"][field] == profiles["4000"][field], "Matched pump profile differs: " + field)
    for budget, profile in profiles.items():
        check(profile["identity"]["revision"] == SHA and profile["completed_intervals"] == 240 and len(profile["publication_digests"]) == 240 and profile["actual_live_inputs"] == 60 and profile["actual_physics_steps"] == 954 and profile["failures"] == 0, "Pump profile workload/source mismatch " + budget)
        check(profile["identity"]["engine_sha256"] == runtime_members["Godot_v4.7-stable_win64.exe"]["sha256"], "Actual profile engine differs from packaged engine " + budget)
        for path, value in profile["identity"]["files"].items():
            if path.endswith(".gd"):
                check(git_digest("godot/" + path.removeprefix("res://")) == value, "Pump profile exact script differs " + path)
        check(profile["identity"]["files"]["res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"] == NATIVE, "Pump profile selected native DLL differs")
        check(abs(profile["semantic_ticks_per_wall_second"] - 240e6 / profile["play_elapsed_usec"]) < 1e-12, "Pump profile wall progression arithmetic differs")
        check(profile["initial_tick"] == 1 and profile["final_tick"] == 241 and profile["requested_process_hz"] == 60 and not profile["notifications"], "Pump profile scheduling configuration differs")
    profile_summary = {budget: {k: p[k] for k in ("play_elapsed_usec", "semantic_ticks_per_wall_second", "process_callback_interval_usec", "semantic_interval_and_input_usec", "host_stages_usec", "pump_call_usec", "pump_call_while_pending_usec", "publication_comparison_observation_usec", "maximum_displacements", "contact_owners", "sleeping_owners", "presentation", "scope")} for budget, p in profiles.items()}
    rendered = read(EVIDENCE / "windows-lab/continuous-play-rendered.json")
    results = rendered["action_results"]
    check(len(results) == 153 and rendered["pointer_input"]["queued"] == rendered["pointer_input"]["dispatched"] == 153 and not rendered["pointer_input"]["pending"] and not rendered["failed"], "Rendered pointer workload incomplete")
    check([r["action_id"] for r in results] == list(range(1, 154)), "Rendered action receipt identities incomplete")
    check(all(0 < r["captured_usec"] <= r["admitted_usec"] <= r["completed_usec"] and r["input_observation"] == "scene_intent" for r in results), "Rendered original pointer timestamps not preserved")
    for field, origin in (("input_to_result_usec", "captured_usec"), ("host_admission_to_result_usec", "admitted_usec")):
        expected = distribution([r["completed_usec"] - r[origin] for r in results])
        check(all(rendered["timings_usec"][field][k] == v for k, v in expected.items()), "Rendered retained timestamp distribution differs: " + field)
    for name, stage in rendered["presentation_timing"]["stages"].items():
        values = stage["retained_values_usec"]
        d = distribution(values)
        check(stage["count"] == d["count"] and all(stage[k + "_usec"] == d[k] for k in ("maximum", "p50", "p95", "p99")), "Rendered scene raw timing distribution differs: " + name)
    ui_case = next(c for c in qualification["windows-lab"]["cases"] if c["name"] == "objectshard_continuous_play_rendered")
    check(ui_case["requires_display"] and "--headless" not in ui_case["command"], "Rendered scene not launched with display")
    for name in ("input_to_presented_usec", "host_admission_to_presented_usec"):
        check(ui_case["rendered_ui_timing"][name] == rendered["timings_usec"][name] and rendered["timings_usec"][name]["count"] == 153, "Actual post-draw timing summary differs " + name)
    outcomes = collections.Counter((r["name"], r["outcome"], r["ok"]) for r in results)
    check(outcomes[("edit", "TargetChanged", False)] == 3 and outcomes[("edit", "Accepted", True)] == 148, "Rendered source-bound stale target workload differs")
    replay = read(EVIDENCE / "windows-lab/continuous-rendered-replay.json")
    check(replay["source_revision"] == SHA and replay["checks"] == 387 and replay["failures"] == 0 and replay["actions"] == 155 and replay["semantic_steps"] == 38, "Rendered trace replay mismatch")
    campaign = read(EVIDENCE / "windows-lab/frames-worker/render-campaign.json")
    render_case = next(c for c in qualification["windows-lab"]["cases"] if c["name"] == "objectshard_worker_render")
    check(campaign["source_revision"] == SHA and campaign["captures"] == 7 and campaign["failures"] == 0, "Rendered capture campaign failed")
    images = []
    notes = {
        "objectshard-m3-native-supported.png": "Visible native-supported wood crown and trunk; no active owner outline.",
        "objectshard-m3-falling.png": "Visible wood crown below its supported position, severed trunk gap, active awake owner and matching material display.",
        "objectshard-m3-settled-after-erosion.png": "Visible settled rotated owner at the floor, exact shape outlines, sleeping 525-cell owner after one-cell erosion.",
        "objectshard-m3-main-structure-priority.png": "Visible 817-cell main owner and two admitted small owners, remaining native offcuts still visible with deferred capacity telemetry.",
        "objectshard-m3-water-sand-pocket.png": "Visible pocket geometry and discrete orange material; telemetry shows one cargo cell. A still image alone does not prove water extinction.",
        "objectshard-m3-external-fire.png": "Actual orange flame pixels visibly touch the supported wood base; authored fixture count 84 is shown.",
        "objectshard-m3-extended-320.png": "Visible three large owners across the 320x192 canvas, one resting at a rotated pose, material and shape outlines aligned.",
    }
    for observation in campaign["observations"]:
        name = observation["image"]
        path = EVIDENCE / "windows-lab/frames-worker" / name
        actual_hash = bind(path)
        check(actual_hash == render_case["rendered_images"][name], "Rendered PNG SHA mismatch " + name)
        check(observation["premise_passed"], "Rendered fixture premise failed " + name)
        with Image.open(path) as im:
            colors = len(im.convert("RGB").getcolors(maxcolors=2**24) or [])
            check(im.size == (1280, 840) and colors > 20, "Rendered image empty/dimension mismatch " + name)
            images.append({"name": name, "sha256": actual_hash, "size": im.size, "colors": colors, "detail": observation["detail"], "visual_review": notes[name]})
    job_log = OUT / "platform-windows-job137126167188.log"
    bind(job_log)
    bind(OUT / "platform-windows-job137126167188-steps.json")
    bind(Path(__file__).resolve())
    bind(OUT / "platform-windows-audit-harness-negative.json")
    bind(OUT / "platform-windows-audit-harness-negative.py")
    footer_counts = collections.Counter()
    relevant_footers = []
    renderers = set()
    for line in job_log.open():
        content = re.sub(r"^\d{4}-\d\d-\d\dT\S+\s+", "", line).strip()
        if content.startswith("OpenGL API "):
            renderers.add(content)
        try:
            row = json.loads(content)
        except ValueError:
            continue
        if not isinstance(row, dict) or "schema" not in row:
            continue
        footer_counts[row["schema"]] += 1
        if row["schema"] in ("objectshard-continuous-play-test-v1", "objectshard-continuous-physics-test-v1", "objectshard-worker-scheduling-profile-v1"):
            relevant_footers.append({k: row[k] for k in ("schema", "checks", "failures", "source_revision", "tick", "completed_ticks", "actions_queued") if k in row})
    check([r["checks"] for r in relevant_footers if r["schema"] == "objectshard-continuous-play-test-v1"] == [76, 77, 76], "Source/rendered/delivered scene natural completion footer mismatch")
    check([r["checks"] for r in relevant_footers if r["schema"] == "objectshard-continuous-physics-test-v1"] == [22513, 22513], "Sustained source/delivered natural completion footer mismatch")
    check(all(r["failures"] == 0 for r in relevant_footers), "Relevant hosted natural completion footer reports failure")
    result = {
        "schema": "independent-objectshard-m3-windows-physics-review-v1",
        "source_commit": SHA, "source_tree": TREE, "reviewer": "/root/review_physics",
        "method": "Independent source/receipt/raw-trace/PNG audit of fresh hosted Windows runtime and delivered-ZIP rerun; no Windows execution performed locally by this reviewer.",
        "checks": checks, "failures": errors, "status": "passed" if not errors else "adverse-evidence-retained",
        "source_input_counts": {"native": len(provenance["source_inputs"]), "lab": len(qualification["windows-lab"]["lab_source_inputs"]), "qualification_tools": len(qualification["windows-lab"]["qualification_tool_inputs"]), "unique_git_blobs_independently_hashed": len(source_hashes)},
        "runtime": runtime, "actual_owner_zip_members": runtime_members, "archives": archive_hashes,
        "qualification_cases": {k: len(v["cases"]) for k, v in qualification.items()},
        "job_log": {"natural_completion_footer_counts": dict(footer_counts), "relevant_footers": relevant_footers, "observed_renderer_lines": sorted(renderers)},
        "source_sustained": source_trace, "delivered_zip_sustained": zip_trace,
        "source_and_zip_nontiming_physics_all_3599_intervals_identical": source_physics == zip_physics,
        "source_and_zip_native_accounting_identical": source_summary["native_accounting"] == zip_summary["native_accounting"],
        "matched_pump_profiles": profile_summary,
        "pump_240_publication_digests_identical": profiles["0"]["publication_digests"] == profiles["4000"]["publication_digests"],
        "pump_semantic_progression_ratio": profiles["4000"]["semantic_ticks_per_wall_second"] / profiles["0"]["semantic_ticks_per_wall_second"],
        "rendered_ui": {"pointer_input": rendered["pointer_input"], "timings_usec": rendered["timings_usec"], "recomputed_result_distributions": True, "post_draw_present_counts": 153, "publication_to_present_count": rendered["timings_usec"]["publication_to_presented_usec"]["count"], "scene_input_to_host_usec": {k: v for k, v in rendered["presentation_timing"]["stages"]["input_to_host_usec"].items() if k != "retained_values_usec"}, "action_outcomes": [{"action": k[0], "outcome": k[1], "ok": k[2], "count": v} for k, v in outcomes.items()], "replay": {k: replay[k] for k in ("checks", "failures", "actions", "semantic_steps")}},
        "rendered_images": images,
        "limits": [
            "Hosted Windows uses ANGLE/Microsoft Basic Render Driver software rendering; physical Windows11/NVIDIA owner acceptance remains unperformed.",
            "The endpoint is native tick3600 from initial tick1:3599 complete native/physics intervals, not3600 newly advanced intervals.",
            "The 4000us receipt pump is a soft main-thread loop budget; a current handler completes and the observed profile maximum is5783us. It does not manufacture semantic ticks.",
            "Paired profiles measure 8.256 and19.531 semantic ticks/s at a requested60Hz callback; neither is a60FPS display acceptance claim. Profiles do not call mark_presented.",
            "Rendered UI post-draw timing is source-bound actual frame_post_draw instrumentation. Retained output contains distributions/counts rather than a raw per-present sequence/timestamp ledger, and does not measure monitor scanout.",
            "Rendered UI workload includes intentional backlog and stale/held cases; p95 original-input-to-presented1.403s is not a steady-state normal-play latency claim.",
            "All40 source-lab and31 delivered-ZIP per-case logs are present and independently SHA256-matched to case receipts, alongside the full immutable hosted job log. The initial rg-based inventory hid ignored .log files; the prior report is retained as platform-windows-review-before-case-log-readback.json and this corrected audit directly opens every qualified log path.",
            "This remains a standalone one-real-World/exclusive-worker rehearsal, Draft/HOLD, with no ordinary worker adoption or promotion authorized.",
            "Subsequent independent real F2 navigation reproduction found a ClassB lifecycle defect in this68235b12 source; see navigation-68235b12/finding.json. Passing platform datasets do not waive that candidate blocker. Author repair is reviewed separately.",
        ],
        "review_harness_corrections": [{"retained_negative_report": "build/review-physics/platform-windows-audit-harness-negative.json", "retained_negative_script": "build/review-physics/platform-windows-audit-harness-negative.py", "finding": "Initial audit incorrectly required all NativeReceipt results to be ok. Both runs had exactly 3596 expected prepare/Busy census outcomes (2 Discovering, 3594 no eligible component). Source host lines512-522 explicitly continues physical motion for these nonmutating outcomes. Audit now accepts only operation=purpose=prepare with outcome=Busy, retains/counts those outcomes, and still requires all material/physics mutations to acknowledge. No product source changed."}],
        "input_sha256": inputs, "exact_git_source_sha256": source_hashes,
    }
    (OUT / "platform-windows-review.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"checks": checks, "failures": errors[:30], "failure_count": len(errors), "source_inputs": result["source_input_counts"], "same_all_intervals": result["source_and_zip_nontiming_physics_all_3599_intervals_identical"], "report": str(OUT / "platform-windows-review.json")}, indent=2))


if __name__ == "__main__":
    main()
