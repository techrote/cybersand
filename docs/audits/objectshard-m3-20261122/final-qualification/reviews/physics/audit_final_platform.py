#!/usr/bin/env python3
"""Independent final-source platform artifact audit, driven by bound input paths.

The configuration is a reviewer-owned JSON file naming completed/authenticated
artifacts. Reuses the retained raw physics trace verifier without executing the
qualification implementation being audited.
"""
import importlib.util
import json
from pathlib import Path
import sys
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("raw_physics_audit", ROOT / "build/review-physics/audit_platform_physics.py")
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)
CONFIG_PATH = Path(sys.argv[1]).resolve()
C = json.loads(CONFIG_PATH.read_text())
A.SHA, A.TREE = C["source_commit"], C["source_tree"]
A.EVIDENCE = ROOT / C["evidence_directory"]
OUT = ROOT / C["output_report"]
A.bind(CONFIG_PATH)
A.bind(Path(__file__).resolve())
A.bind(ROOT / "build/review-physics/audit_platform_physics.py")
platform = C["platform"]
source_lab = C["source_lab"]
lab_names = [source_lab] + ([C["package_lab"]] if C.get("package_lab") else [])
qmap = {}
navigation = {}
renderers = set()

for lab in lab_names:
    q = A.read(A.EVIDENCE / lab / "qualification.json")
    qmap[lab] = q
    A.check(q["source_commit"] == A.SHA and q["source_tree"] == A.TREE and q["status"] == "passed" and not q["failures"], lab + " source/status identity differs")
    A.check(len(q["cases"]) == (41 if lab == source_lab else 32), lab + " required case inventory differs")
    for key in ("native_source_inputs", "lab_source_inputs", "qualification_tool_inputs"):
        A.verify_source_map(lab + ":" + key, q[key])
    for case in q["cases"]:
        A.check(case["status"] == "passed" and case["returncode"] == 0 and case["natural_completion"], lab + " incomplete case: " + case["name"])
        log = A.EVIDENCE / lab / case["log"]
        A.check(A.bind(log) == case["log_sha256"], lab + " per-case log hash differs: " + case["name"])
        for line in log.read_text().splitlines():
            if line.startswith("OpenGL API "):
                renderers.add(line)
    n = A.read(A.EVIDENCE / lab / "worker-navigation.json")
    child = A.read(A.EVIDENCE / lab / "worker-navigation-quit-child.json")
    expected_cases = ["active_pending_repeated", "naturally_sleeping", "opening", "reset_superseded", "held_interval", "stop_delivery_faults", "already_closed_prior_policy", "window_close_upgrade"]
    A.check(n["schema"] == "objectshard-worker-navigation-test-v1" and n["source_revision"] == A.SHA and n["checks"] == 135 and n["failures"] == 0 and n["cases"] == expected_cases, lab + " maintained actual navigation receipt incomplete")
    child_rows = [r for r in n["observations"] if r.get("case") == "window_close_upgrade"]
    A.check(len(child_rows) == 1 and child_rows[0]["child_exit_code"] == 0 and child_rows[0]["child_report"] == child, lab + " actual child receipt differs from separately retained child output")
    A.check(child["schema"] == "objectshard-worker-navigation-quit-child-v1" and child["source_revision"] == A.SHA and child["checks"] == 18 and child["failures"] == 0, lab + " actual process-quit child incomplete")
    for observation in n["observations"]:
        if "passed" in observation:
            A.check(observation["passed"], lab + " negative navigation assertion: " + observation["check"])
        after = observation.get("after", {})
        if after:
            A.check(after.get("state") == "Closed" and after.get("body_count") == 0 and after.get("terrain_count") == 0 and after["worker"]["stopped"] and after["worker"]["terminal"].get("outcome") == "Stopped", lab + " native/RID lifecycle after-state incomplete")
    nav_case = next(row for row in q["cases"] if row["name"] == "objectshard_worker_navigation")
    A.check(nav_case["navigation_lifecycle"]["checks"] == 135 and nav_case["navigation_lifecycle"]["child_checks"] == 18, lab + " navigation case summary differs")
    child_log = A.EVIDENCE / lab / "worker-navigation-quit-child.json.log"
    A.check(A.bind(child_log) == child_rows[0]["child_output_sha256"], lab + " child process actual output hash differs")
    navigation[lab] = {"checks": n["checks"], "failures": n["failures"], "child_checks": child["checks"], "child_exit_code": child_rows[0]["child_exit_code"], "cases": n["cases"], "after_states_checked": sum(bool(row.get("after")) for row in n["observations"])}

q = qmap[source_lab]
runtime = q["runtime"]
provenance = A.read(ROOT / C["provenance"])
native_path = ROOT / C["native_runtime"]
native_hash = A.bind(native_path)
A.check(native_hash == runtime["native_sha256"], "Selected qualified runtime differs from fresh native artifact")
if platform == "windows":
    A.check(provenance["kind"] == "source-built-windows-candidate" and provenance["source_commit"] == provenance["build_commit"] == A.SHA and provenance["source_tree"] == A.TREE and provenance["sha256"] == native_hash, "Fresh Windows compile candidate provenance differs")
    A.verify_source_map("fresh Windows compilation inputs", provenance["source_inputs"])
    A.check(provenance["source_inputs"] == q["native_source_inputs"], "Fresh Windows compilation inputs differ from qualified inputs")
else:
    A.check(provenance["phase"] == "sealed" and provenance["source"]["source_commit"] == A.SHA and provenance["source"]["source_tree"] == A.TREE and provenance["runtime"]["sha256"] == native_hash, "Fresh Linux compile candidate provenance differs")
    for key in ("source_inputs", "build_contract_inputs"):
        A.verify_source_map("fresh Linux " + key, provenance["source"][key])
    A.check(provenance["source"]["source_inputs"] == q["native_source_inputs"], "Fresh Linux compilation inputs differ from qualified inputs")
    compiled = A.read(A.EVIDENCE / "extension/receipt.json")
    A.check(compiled["complete"] and compiled["natural_completion"] and compiled["status"] == "passed" and compiled["returncode"] == 0 and compiled["source"]["commit"] == A.SHA and compiled["source"]["tree"] == A.TREE, "Fresh Linux native compile did not naturally complete from final source")
    A.check(A.bind(A.EVIDENCE / "extension" / compiled["log"]) == compiled["log_sha256"], "Fresh Linux native compile actual log differs")
archives = []
for archive in C.get("archives", []):
    path = ROOT / archive["path"]
    actual = A.bind(path)
    A.check(actual == archive["sha256"], "Authenticated archive SHA mismatch: " + str(path))
    archives.append({"path": archive["path"], "sha256": actual, "bytes": path.stat().st_size})
for custody in C.get("custody_files", []):
    A.bind(ROOT / custody)

zip_members = {}
if C.get("owner_zip"):
    with zipfile.ZipFile(ROOT / C["owner_zip"]) as archive:
        for path in ("Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe", "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll", "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll", "objectshard-lab-manifest.json"):
            data = archive.read(path)
            zip_members[path] = {"sha256": A.digest(data), "bytes": len(data)}
        A.check(zip_members["Godot_v4.7-stable_win64_console.exe"]["sha256"] == runtime["godot_sha256"], "Delivered console launcher differs from qualified launcher")
        A.check(zip_members["godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"]["sha256"] == native_hash, "Delivered owner ZIP native DLL differs")
        A.check(zip_members["godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"]["sha256"] == runtime["rapier_sha256"], "Delivered owner ZIP Rapier differs")
        A.check(zip_members["objectshard-lab-manifest.json"]["sha256"] == qmap[C["package_lab"]]["package_manifest_sha256"], "Actual delivered ZIP manifest differs from extracted rerun binding")
        for path, value in q["lab_source_inputs"].items():
            A.check(path in archive.namelist() and A.digest(archive.read(path)) == value, "Delivered ZIP final lab input differs: " + path)

sustained, trajectories, summaries = {}, {}, {}
for lab in lab_names:
    sustained[lab], trajectories[lab], summaries[lab] = A.audit_trace(lab)
    A.check(qmap[lab]["runtime"] == runtime, lab + " qualified source/package runtime differs")
if C.get("package_lab"):
    package_lab = C["package_lab"]
    A.check(sustained[package_lab]["package_manifest_sha256"] == qmap[package_lab]["package_manifest_sha256"], "Delivered sustained trace is not bound to actual ZIP manifest")

profiles = {str(b): A.read(A.EVIDENCE / source_lab / f"objectshard_worker_profile_{b}.json") for b in (0, 4000)}
for field in ("identity", "engine", "platform", "publication_digests", "native_accounting", "completed_intervals", "actual_live_inputs", "actual_physics_steps"):
    A.check(profiles["0"][field] == profiles["4000"][field], "Same-platform paired pump comparison differs: " + field)
for budget, profile in profiles.items():
    A.check(profile["identity"]["revision"] == A.SHA and profile["failures"] == 0 and profile["completed_intervals"] == 240 and len(profile["publication_digests"]) == 240 and profile["actual_live_inputs"] == 60 and profile["actual_physics_steps"] == 954, "Profile exact source/workload mismatch: " + budget)
    actual_engine = zip_members["Godot_v4.7-stable_win64.exe"]["sha256"] if zip_members else runtime["godot_sha256"]
    A.check(profile["identity"]["engine_sha256"] == actual_engine, "Actual profiler engine differs: " + budget)
    selected_native = "res://addons/cybersand_native/bin/" + ("cybersand_native.windows.x86_64.dll" if platform == "windows" else "libcybersand_native.linux.x86_64.so")
    A.check(profile["identity"]["files"][selected_native] == native_hash, "Profile selected native artifact differs: " + budget)
    for path, value in profile["identity"]["files"].items():
        if path.endswith(".gd"):
            A.check(A.git_digest("godot/" + path.removeprefix("res://")) == value, "Profile exact script differs: " + path)
    A.check(abs(profile["semantic_ticks_per_wall_second"] - 240e6 / profile["play_elapsed_usec"]) < 1e-12, "Profile progression arithmetic differs")

rendered = A.read(A.EVIDENCE / source_lab / "continuous-play-rendered.json")
results = rendered["action_results"]
A.check(len(results) == 153 and rendered["pointer_input"]["queued"] == rendered["pointer_input"]["dispatched"] == 153 and not rendered["pointer_input"]["pending"] and not rendered["failed"], "Rendered input workload incomplete")
A.check([row["action_id"] for row in results] == list(range(1, 154)), "Rendered command receipt sequence incomplete")
A.check(all(0 < row["captured_usec"] <= row["admitted_usec"] <= row["completed_usec"] and row["input_observation"] == "scene_intent" for row in results), "Rendered original input timestamp not retained")
for field, origin in (("input_to_result_usec", "captured_usec"), ("host_admission_to_result_usec", "admitted_usec")):
    d = A.distribution([row["completed_usec"] - row[origin] for row in results])
    A.check(all(rendered["timings_usec"][field][k] == v for k, v in d.items()), "Rendered original input/result distribution differs: " + field)
for name, stage in rendered["presentation_timing"]["stages"].items():
    d = A.distribution(stage["retained_values_usec"])
    A.check(stage["count"] == d["count"] and all(stage[k + "_usec"] == d[k] for k in ("maximum", "p50", "p95", "p99")), "Rendered retained scene distribution differs: " + name)
ui_case = next(row for row in q["cases"] if row["name"] == "objectshard_continuous_play_rendered")
A.check(ui_case["requires_display"] and "--headless" not in ui_case["command"], "Rendered scene ran headless")
for name in ("input_to_presented_usec", "host_admission_to_presented_usec"):
    A.check(ui_case["rendered_ui_timing"][name] == rendered["timings_usec"][name] and rendered["timings_usec"][name]["count"] == 153, "Actual post-draw input count/summary differs: " + name)
trace_path = A.EVIDENCE / source_lab / "continuous-play-rendered.json.jsonl"
A.bind(trace_path)
rows = [json.loads(line) for line in trace_path.open()]
action_count = sum(row["kind"] == "action" for row in rows)
step_count = sum(row["kind"] == "step_completed" for row in rows)
replay = A.read(A.EVIDENCE / source_lab / "continuous-rendered-replay.json")
A.check(replay["source_revision"] == A.SHA and replay["failures"] == 0 and not replay["differences"] and not replay["incomplete_barrier"] and replay["actions"] == action_count == 155 and replay["semantic_steps"] == step_count, "Rendered replay does not match its own platform's actual trace")
campaign = A.read(A.EVIDENCE / source_lab / "frames-worker/render-campaign.json")
image_case = next(row for row in q["cases"] if row["name"] == "objectshard_worker_render")
A.check(campaign["source_revision"] == A.SHA and campaign["captures"] == 7 and campaign["failures"] == 0, "Rendered worker capture campaign incomplete")
images = []
for observation in campaign["observations"]:
    path = A.EVIDENCE / source_lab / "frames-worker" / observation["image"]
    sha = A.bind(path)
    A.check(sha == image_case["rendered_images"][observation["image"]] and observation["premise_passed"], "Rendered PNG/source premise differs: " + observation["image"])
    with Image.open(path) as image:
        colors = len(image.convert("RGB").getcolors(maxcolors=2**24) or [])
        A.check(image.size == (1280, 840) and colors > 20, "Rendered PNG empty/dimension differs")
        captured = observation["report"]
        physical = captured["physics"]
        accounting = captured["accounting"]
        images.append({"image": observation["image"], "sha256": sha, "size": image.size, "colors": colors, "detail": observation["detail"],
                       "visible_png_telemetry": C.get("visual_telemetry", {}).get(observation["image"], {}),
                       "adjacent_post_draw_host_diagnostics": {"native_tick": captured["tick"], "published_tick": captured["published_tick"], "publication_sequence": captured["publication_sequence"], "host_state": captured["state"],
                                                  "bridge_bodies": A.clean_physics(physical["bodies"]), "bridge_motion_phase": physical["motion_phase"], "bridge_last_completed_semantic_tick": physical["last_completed_semantic_tick"],
                                                  "ingested_sand": accounting["ingested"][2], "ingested_water": accounting["ingested"][3], "extinguished": accounting["extinguished"], "native_created_fire": accounting["created"][6], "native_created_smoke": accounting["created"][4], "authored_fire": accounting["authored_created"][6],
                                                  "scope": "The capture script saves the rendered image after frame_post_draw, then samples host.diagnostics. The PNG can show an earlier publication/HUD state than these adjacent diagnostics. Backend bodies are not substituted as exact displayed render poses; manually read PNG telemetry is retained separately."},
                       "visual_review": C.get("visual_review", {}).get(observation["image"], "Manual view pending; hash/content dimension only so far.")})
material_fixtures = {}
for lab in lab_names:
    lab_result = A.read(A.EVIDENCE / lab / "lab-result.json")
    A.check(lab_result["failures"] == 0 and lab_result["checks"] > 0, lab + " maintained material fixture suite incomplete")
    fixtures = []
    for scenario in lab_result["scenarios"]:
        A.check(scenario["source_revision"] == A.SHA, lab + " material fixture source differs")
        fixture = scenario.get("evidence", {})
        if "cargo_after" in fixture:
            A.check(fixture["cargo_after"] > 0 and fixture["world_sand_after"] + fixture["cargo_after"] == fixture["initial_world_sand"], lab + " separate Sand fixture transfer fails inventory conservation")
            A.check(fixture["cargo_tuple"]["material"] == 2 and fixture["cargo_tuple"]["state_a"] == fixture["cargo_tuple"]["state_b"] == 0 and fixture["cargo_tuple"]["temperature"] == 200, lab + " carried Sand tuple differs")
            A.check(fixture["water_contact"]["ok"] and fixture["water_contact"]["whole_world_water_quanta"] == 255 and fixture["same_cell_extinguished"] and scenario["accounting"]["ingested"][3] == 0, lab + " separate Water fixture does not establish surviving-Wood extinction without liquid ownership transfer")
            fixtures.append({"kind": "separate_native_lab_sand_water_fixture", "scenario": scenario["scenario"], "tick": scenario["tick"], "evidence": fixture,
                             "scope": "Separate maintained Lab fixture, not an ingestion/extinction claim for the long three-body M3 run. Outcome assertions are source-bound; a complete per-cell historical stream is not stored here."})
        if "burn_after_sleep" in fixture:
            A.check(fixture["actual_sleep_observed"] and fixture["burn_after_sleep"] < fixture["burn_before_sleep"] and fixture["retained_fire_seen"] and fixture["retained_smoke_seen"] and fixture["world_fire_seen"] and fixture["world_smoke_seen"], lab + " separate sleep/chemistry fixture lacks actual reaction while sleeping")
            fixtures.append({"kind": "separate_native_lab_sleeping_chemistry", "scenario": scenario["scenario"], "tick": scenario["tick"], "evidence": fixture})
    A.check(any(row["kind"] == "separate_native_lab_sand_water_fixture" for row in fixtures), lab + " separate Sand/Water fixture absent")
    ledger = summaries[lab]["native_accounting"]
    material_fixtures[lab] = {"separate_lab_fixture_checks": lab_result["checks"], "separate_fixtures": fixtures,
                              "long_three_body_run": {"authored_sand": ledger["authored_created"][2], "authored_water": ledger["authored_created"][3], "ingested_sand": ledger["ingested"][2], "ingested_water": ledger["ingested"][3], "extinguished": ledger["extinguished"], "created_fire": ledger["created"][6], "created_smoke": ledger["created"][4], "destroyed_wood": ledger["destroyed"][7]}}
profile_fields = ("play_elapsed_usec", "semantic_ticks_per_wall_second", "process_callback_interval_usec", "semantic_interval_and_input_usec", "host_stages_usec", "pump_call_usec", "pump_call_while_pending_usec", "publication_comparison_observation_usec", "maximum_displacements", "contact_owners", "sleeping_owners", "presentation")
report = {
    "schema": "independent-final-platform-physics-review-v1", "reviewer": "/root/review_physics", "platform": platform,
    "source_commit": A.SHA, "source_tree": A.TREE, "checks": A.checks, "failures": A.errors,
    "status": "passed" if not A.errors else "adverse-evidence-retained", "runtime": runtime,
    "fresh_native_hash": native_hash, "source_input_counts": {"native": len(q["native_source_inputs"]), "lab": len(q["lab_source_inputs"]), "qualification_tools": len(q["qualification_tool_inputs"]), "unique_git_blobs": len(A.source_hashes)},
    "qualification_cases": {k: len(v["cases"]) for k, v in qmap.items()}, "navigation_lifecycle": navigation,
    "sustained_physics": sustained, "same_platform_source_vs_package_nontiming_physics_identical": trajectories.get(C.get("package_lab")) == trajectories[source_lab] if C.get("package_lab") else None,
    "same_platform_source_vs_package_native_accounting_identical": summaries[C["package_lab"]]["native_accounting"] == summaries[source_lab]["native_accounting"] if C.get("package_lab") else None,
    "pump_profiles": {budget: {k: profile[k] for k in profile_fields} for budget, profile in profiles.items()},
    "paired_same_platform_publication_digest_and_ledger_equality": profiles["0"]["publication_digests"] == profiles["4000"]["publication_digests"] and profiles["0"]["native_accounting"] == profiles["4000"]["native_accounting"],
    "paired_semantic_progression_ratio": profiles["4000"]["semantic_ticks_per_wall_second"] / profiles["0"]["semantic_ticks_per_wall_second"],
    "rendered_ui": {"pointer_input": rendered["pointer_input"], "timings_usec": rendered["timings_usec"], "raw_original_input_result_distributions_recomputed": True, "scene_input_to_host_usec": {k: v for k, v in rendered["presentation_timing"]["stages"]["input_to_host_usec"].items() if k != "retained_values_usec"}, "post_draw_input_count": 153, "post_draw_publication_count": rendered["timings_usec"]["publication_to_presented_usec"]["count"]},
    "rendered_trace_replay": {k: replay[k] for k in ("checks", "failures", "actions", "semantic_steps")},
    "material_fixture_outcomes": material_fixtures,
    "rendered_images": images, "renderer_lines": sorted(renderers), "actual_owner_zip_runtime_members": zip_members, "authenticated_archives": archives,
    "limits": ["No cross-platform Rapier/float/replay bit-identity claim; within-platform paired workload equivalence is checked separately.", "Endpoint native tick3600 starts at1:3599 actually completed intervals,14390 physical steps and14388 acknowledged nonempty segments.", "Receipt pump4000us is a soft main-thread loop budget; a current handler can overrun. It grants no new native or physical time.", "Scheduling profiles do not call mark_presented and do not measure display FPS. Actual rendered scene uses source-bound frame_post_draw instrumentation, not monitor scanout.", "Stored presented evidence has counts/distributions, not a per-present raw timestamp ledger. Original result timestamps and scene queue samples are independently recomputed.", "Rendered UI timings include intentional backlog, stale targets and held-receipt diagnostics; not a normal steady-play or target-GPU latency claim.", "Navigation coverage is controlled F2/window-close paths. Unsupported direct externally forced scene replacement of a live owner is not universal destructor cleanup.", "No physical Windows11/NVIDIA owner acceptance, ordinary CyberSimulationWorker adoption, Ready/merge/default promotion is established."],
    "input_sha256": A.inputs, "exact_git_source_sha256": A.source_hashes,
}
OUT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
print(json.dumps({"checks": A.checks, "failure_count": len(A.errors), "failures": A.errors[:20], "report": str(OUT)}, indent=2))
