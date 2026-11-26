#!/usr/bin/env python3
"""Explicit derivation of a new mixed workload; frozen V3 remains untouched.

The committed observer preserves the existing sole-worker and actual-callback
implementations. The only changes are the registered fixture, ordinary paint
admission, additive observations, source identity and receipt schema. The
committed reducer expands its real actor ownership checks to exactly eight,
while retaining the source/native/terrain/command/callback/Water/GPU predicates.
No generated code is executed or raw evidence rewritten at qualification time.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from renderer_contract import FROZEN_V3_SHA256

BASE_OBSERVER_SHA256 = "24e61a18db9748f3cdef11e62f28e2e3ee26c030ad83d9cb200a66aec3a7c37e"
OBSERVER = "tests/pubpres_final_mixed_gameplay.gd"
RESOURCE = "tests/pubpres_final_mixed_registration.json"


def replace_once(text: str, original: str, replacement: str) -> str:
    if text.count(original) != 1:
        raise ValueError("Mixed derivation requires one exact boundary: " + original[:90])
    return text.replace(original, replacement)


MIXED_METHODS = r'''
	var mixed_scale := 1
	var mixed_paint_events: Array[Dictionary] = []
	var mixed_material_observations: Array[Dictionary] = []
	var mixed_neutral_controls_before: Array[Dictionary] = []
	var mixed_paint_next := 0
	var mixed_material_probe_attempts := 0
	var mixed_material_probe_total_usec := 0
	var mixed_material_probe_max_usec := 0

	func _mixed_actor_controls() -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		if physical_actor_session == null: return rows
		for slot: int in physical_actor_session._definitions.size():
			rows.append({"slot":slot,"instance_id":physical_actor_session._definitions[slot].instance_id,
				"sequence":physical_actor_session._sequences[slot],"deadline":physical_actor_session._deadlines[slot],
				"generation":physical_actor_session._generations[slot],
				"command_empty":physical_actor_session._commands[slot].is_empty()})
		return rows

	func _mixed_issue_paint(relative: int) -> void:
		if mixed_paint_next >= MIXED_PAINT_TAPE.size(): return
		var action: Dictionary = MIXED_PAINT_TAPE[mixed_paint_next]
		if relative < int(action.tick): return
		if relative != int(action.tick):
			common_input_error = "mixed paint missed its exact real-step index"
			return
		if mixed_paint_next == 1:
			var prior_wall_seen := false
			for row: Dictionary in mixed_material_observations:
				if row.action_index == 0: prior_wall_seen = true
			if not prior_wall_seen:
				common_input_error = "mixed wall58 was not actually published before erase admission"
				return
		var point := Vector2i(int(action.point[0]),int(action.point[1]))*mixed_scale
		var before_revision: int = latest_snapshot.world_revision
		var before_hard: int = last_hard_surface_revision
		var started := Time.get_ticks_usec()
		# Real authoring API: this queues a brush on the authoritative worker.
		# The observer does not access World, step Rapier, or refresh a texture.
		var accepted: bool = shared_workbench.paint(point,int(action.material))
		mixed_paint_events.append({"action_index":mixed_paint_next,"physical_tick":relative,
			"absolute_tick":physical_actor_session.tick,"point":[point.x,point.y],"material":action.material,
			"radius":int(shared_workbench.applied.brush),"start_usec":started,"time_usec":Time.get_ticks_usec(),
			"accepted":accepted,"before_world_revision":before_revision,"before_hard_revision":before_hard,
			"before_native_tick":latest_snapshot.tick_index,
			"world_generation":common_generation,"epoch":common_epoch})
		mixed_paint_next += 1
		if not accepted: common_input_error = "ordinary mixed paint refused: "+str(shared_workbench.message)

	func _mixed_observe_material() -> void:
		if not common_active or image == null: return
		for action: Dictionary in mixed_paint_events:
			var seen := false
			for row: Dictionary in mixed_material_observations:
				if row.action_index == action.action_index: seen = true
			if seen or last_uploaded_revision <= int(action.before_world_revision): continue
			var started := Time.get_ticks_usec()
			var point := Vector2i(int(action.point[0]),int(action.point[1]))
			var found := Vector2i(-1,-1)
			var expected := int(action.material)
			if expected == 2:
				# Sand can move before its first published frame. Search only this
				# registered bounded source-image area, never the native World.
				for y: int in range(point.y-16,point.y+65):
					if found.x >= 0: break
					for x: int in range(point.x-16,point.x+17):
						if roundi(image.get_pixel(x,y).r*255.0) == expected:
							found = Vector2i(x,y)
							break
			elif roundi(image.get_pixelv(point).r*255.0) == expected:
				found = point
			var probe_usec := Time.get_ticks_usec()-started
			mixed_material_probe_attempts += 1
			mixed_material_probe_total_usec += probe_usec
			mixed_material_probe_max_usec = maxi(mixed_material_probe_max_usec,probe_usec)
			if found.x < 0: continue
			mixed_material_observations.append({"action_index":action.action_index,"material":expected,
				"point":[found.x,found.y],"time_usec":Time.get_ticks_usec(),"observer_usec":probe_usec,
				"world_generation":last_uploaded_world_generation,"world_revision":last_uploaded_revision,
				"render_serial":last_uploaded_render_snapshot_serial,"native_tick":common_uploaded_native_tick,
				"generated_usec":common_uploaded_generated_usec,
				"scope":"first matching owned CPU material after actual production texture upload; not GPU completion or scanout"})
'''


def expected_mixed_observer(base: bytes, registration: dict) -> bytes:
    if hashlib.sha256(base).hexdigest() != BASE_OBSERVER_SHA256:
        raise ValueError("Existing causal observer bytes changed")
    text = base.decode("utf-8")
    text = replace_once(text, "extends SceneTree\n", "extends SceneTree\n\n# Separately registered eight-actor mixed ordinary Workbench qualification.\n# Source-derived observer; see mixed_contract.py for every explicit change.\n")
    text = replace_once(text, "extends SceneTree\n", '''extends SceneTree

const PresentationProbe = preload("res://tests/pubpres_final_presentation_probe.gd")
var presentation_probe = PresentationProbe.new()
var presentation_enabled := OS.get_environment("CYBERSAND_DIAG_PRESENTATION_OBSERVER") == "1"
''')
    declarations = "const MIXED_ACTORS = " + json.dumps(registration["actors"], separators=(",", ":")) + "\n"
    declarations += "const MIXED_PAINT_TAPE = " + json.dumps(registration["paint_tape"], separators=(",", ":")) + "\n"
    text = replace_once(text, "const MAX_EVENTS := 30000", declarations + "const MAX_EVENTS := 30000")
    text = replace_once(text, "\tfunc _physics_process(delta: float) -> void:", MIXED_METHODS + "\n\tfunc _physics_process(delta: float) -> void:")
    anchor = '\t\t\t\t"accepted_physical_tick":relative,"time_usec":Time.get_ticks_usec(),"move":row.move})'
    text = replace_once(text, anchor, anchor + "\n\t\t_mixed_issue_paint(relative)")
    text = replace_once(text, '"control_generations":Array(physical_actor_session._generations),', '"mixed_actor_controls":_mixed_actor_controls(),\n\t\t\t"control_generations":Array(physical_actor_session._generations),')
    anchor = '\t\t\t\t"full_refresh":snapshot.render_full_refresh,"world_generation":last_uploaded_world_generation})'
    text = replace_once(text, anchor, anchor + "\n\t\t\t_mixed_observe_material()")
    text = replace_once(text, 'var fixture_identity: Dictionary = {}', 'var fixture_identity: Dictionary = {}\nvar mixed_setup_json := ""')
    anchor = '\tProjectSettings.set_setting("cybersand/native_worker_threads",workers)'
    restrict = '''\tminimum_capture_usec = 60000000
\tif fixture_name not in ["basin512","basin1024"] or camera != "follow" or workers != 4 \\
\t\t\tor water_law != "wave_flow_v1" or water_variant != "reference" or water_profile != "gameplay_main846f" \\
\t\t\tor input_mode != "tape" or command_mode != "repeated_callback" or observer_mode != "full":
\t\tpush_error("PUBPRES mixed qualification requires its separately registered controls")
\t\tquit(2)
\t\treturn
'''
    text = replace_once(text, anchor, restrict + anchor)
    anchor = '\tfor path: String in ["res://scripts/blit_material_publisher.gd",'
    new = '\tfor path: String in ["res://' + OBSERVER + '","res://' + RESOURCE + '",\n\t\t"res://tests/pubpres_final_presentation_probe.gd","res://scripts/physical_actor_overlay.gd",\n\t\t"res://scripts/material_publication_deadline.gd","res://scripts/material_publication_steps.gd",\n\t\t"res://scripts/workbench_setup.gd","res://scripts/workbench_actor_catalog.gd",\n\t\t"res://scripts/physical_actor_catalog.gd","res://scripts/gcr_flyer_authoring.gd",\n\t\t"res://authoring/flyers/manifest.json","res://authoring/flyers/needle.json",\n\t\t"res://scripts/gcr_review_fleet.gd","res://scripts/full_image_ring_publisher.gd",\n\t\t"res://scripts/blit_material_publisher.gd",'
    text = replace_once(text, anchor, new)
    text = replace_once(text, '"CYBERSAND_MATERIAL_PUBLICATION","CYBERSAND_DIAG_PHYSICS_PUBLICATION",', '"CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL","CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ","CYBERSAND_DIAG_PRESENTATION_OBSERVER","CYBERSAND_DIAG_FULL_IMAGE_SLOTS","CYBERSAND_MATERIAL_PUBLICATION","CYBERSAND_DIAG_PHYSICS_PUBLICATION",')
    text = replace_once(text, 'return {"requested":requested,',
                        'return {"requested":requested,\n\t\t"material_steps_api_present":host.has_method("material_step_status"),\n\t\t"material_steps":host.call("material_step_status") if host.has_method("material_step_status") else null,\n\t\t"material_deadline":host.call("material_deadline_status") if host.has_method("material_deadline_status") else null,')
    # The recovered actual-task candidate adds only a pre-owner selector and
    # immutable native readback. Keep these exact changes in the derivation;
    # accepting an arbitrary observer diff would erase the original callbacks.
    text = replace_once(text,
                        '\t\t["CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE","cybersand/pubpres_wave_column_probe"]]:',
                        '\t\t["CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE","cybersand/pubpres_wave_column_probe"],\n\t\t["CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER","cybersand/pubpres_task_completion_barrier"]]:')
    text = replace_once(text,
                        '\t\t"CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES","CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE"]:',
                        '\t\t"CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES","CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE",\n\t\t"CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER"]:')
    anchor = '\t\t"wave_column_probe":host.latest_snapshot.lab_context.get("wave_flow",{}).get("column_probe",null) if host.latest_snapshot != null else null,'
    text = replace_once(text, anchor, anchor + '\n\t\t"task_completion":host.latest_snapshot.lab_context.get("wave_flow",{}).get("task_completion",null) if host.latest_snapshot != null else null,')
    text = replace_once(text, '\t_run.call_deferred()', '''\t_run.call_deferred()
\tif presentation_enabled:
\t\tRenderingServer.frame_pre_draw.connect(_presentation_pre_draw)

func _presentation_pre_draw() -> void:
\tif host != null and host.common_active and host.common_detailed:
\t\tpresentation_probe.observe_submission(host)
''')
    text = replace_once(text, '\t\t"inline_main":RenderingServer.is_on_render_thread()})',
                        '\t\t"inline_main":RenderingServer.is_on_render_thread()})\n\tif presentation_enabled: presentation_probe.observe_draw(host,RenderingServer.is_on_render_thread())')
    text = replace_once(text, 'func finish() -> void:\n', '''func finish() -> void:
\tif RenderingServer.frame_pre_draw.is_connected(_presentation_pre_draw):
\t\tRenderingServer.frame_pre_draw.disconnect(_presentation_pre_draw)
\tif presentation_enabled:
\t\tvar proof: Dictionary = presentation_probe.write(output.trim_suffix(".json")+"-presentation.json",
\t\t\tsource_before,capture_start,capture_end)
\t\tcheck(proof.complete,"bounded submitted presentation sidecar retained")
''')
    text = replace_once(text, '\t\tsetup.actors = [Setup.instance("needle",1,Vector2(200,160)*scale)]\n\t\tsetup.next_id = 2', '''\t\tsetup.actors = []
\t\tfor entry: Array in MIXED_ACTORS:
\t\t\tsetup.actors.append(Setup.instance(str(entry[1]),int(entry[0]),Vector2(float(entry[2]),float(entry[3]))*scale))
\t\tsetup.next_id = 9
\t\thost.mixed_scale = scale''')
    anchor = '\tfixture_identity["setup_sha256"] = JSON.stringify(setup).sha256_text()'
    text = replace_once(text, anchor, '''\tmixed_setup_json = JSON.stringify(setup)
\tfixture_identity["source"] = "pubpres_final_mixed_eight_actor_v1"
\tfixture_identity["actors"] = 8
\tfixture_identity["registration_sha256"] = FileAccess.get_sha256("res://''' + RESOURCE + '''")
''' + anchor)
    anchor = '\tcheck(ui.toggle_pause(),"native and Rapier unpaused through ordinary control")'
    text = replace_once(text, anchor, anchor + '\n\thost.mixed_neutral_controls_before = host._mixed_actor_controls()')
    anchor = '\t\tcheck(not host.common_overflow and not worker.overflow,"bounded observational trace retained every event")'
    text = replace_once(text, anchor, '''\t\tcheck(host.mixed_paint_events.size() == 4 and host.mixed_material_observations.size() == 4,
\t\t\t"all four ordinary paints admitted and observed in a real uploaded source material plane")
''' + anchor)
    text = replace_once(text, '"schema":"pubpres-playability-gameplay-v3"', '"schema":"pubpres-final-mixed-gameplay-v1"')
    text = replace_once(text, '"base_contract":"unchanged v3 validation"', '"base_contract":"separately registered eight-actor workload; explicit ownership-cardinality expansion and additive ordinary paint observations"')
    anchor = '\t\t"physical_owner_before":physical_owner_before'
    text = replace_once(text, anchor, '''\t\t"mixed_workload":{"schema":"pubpres-final-mixed-workload-v1","setup_json":mixed_setup_json,
\t\t\t"paint_tape":MIXED_PAINT_TAPE,"actor_specification":MIXED_ACTORS,
\t\t\t"paint_events":host.mixed_paint_events if host != null else [],
\t\t\t"material_observations":host.mixed_material_observations if host != null else [],
\t\t\t"material_probe_cost":{"attempts":host.mixed_material_probe_attempts if host != null else 0,
\t\t\t\t"total_usec":host.mixed_material_probe_total_usec if host != null else 0,
\t\t\t\t"max_usec":host.mixed_material_probe_max_usec if host != null else 0},
\t\t\t"neutral_controls_before":host.mixed_neutral_controls_before if host != null else []},
''' + anchor)
    return text.encode("utf-8")


ROSTER_CHECK = '''    expected_actors=limits["required_actors"]
    roster=data.get("actor_roster_before")
    need(isinstance(roster,list) and len(roster)==len(expected_actors)==8 and roster==data.get("actor_roster_after"),"Eight real actor owners missing or changed")
    owned=[]
    for index,(actor,expected) in enumerate(zip(roster,expected_actors)):
        need(all(actor.get(k)==expected[k] for k in ("actor_slot","instance_id","model","producer")),"Registered mixed actor ownership differs")
        bodies=actor.get("bodies",[])
        need(len(bodies)==expected["body_count"]==1,"Mixed actor must have its one real body")
        body=bodies[0]
        need(body.get("body_slot")==index and body.get("node_class")=="RigidBody2D" and integer(body.get("node_instance_id"),1)
             and integer(body.get("body_rid"),1) and body["body_rid"]==body.get("bridge_rid"),"Mixed actor node and Rapier bridge ownership disagree")
        owned.append(body)
    need(len({b["body_rid"] for b in owned})==len({b["node_instance_id"] for b in owned})==8,"Mixed actor/body identity aliases")
'''
STEP_CHECK = '''        need(isinstance(row.get("bodies"),list) and len(row["bodies"])==8,"Completed step lacks eight real bodies")
        for slot,physical in enumerate(row["bodies"]):
            need(physical.get("slot")==slot and physical.get("instance_id")==slot+1 and vector(physical.get("xy")) and vector(physical.get("velocity"))
                 and number(physical.get("angle")) and integer(physical.get("contacts")),"Completed mixed actor pose/velocity/contacts missing or nonfinite")
        need(row.get("body_ownership")==[{"slot":slot,"body_rid":body["body_rid"]} for slot,body in enumerate(owned)],"Completed step belongs to another mixed body owner")
'''


def expected_mixed_reducer(frozen: bytes) -> bytes:
    if hashlib.sha256(frozen).hexdigest() != FROZEN_V3_SHA256:
        raise ValueError("Frozen V3 reducer changed")
    text = frozen.decode("utf-8")
    text = text[text.index("from __future__ import annotations"):text.index("\ndef main():")].rstrip() + "\n"
    first, last = text.index('    expected=limits["required_actor"]'), text.index('    main_kinds=')
    text = text[:first] + ROSTER_CHECK + text[last:]
    first, last = text.index('        need(isinstance(row.get("bodies"),list)'), text.index('        need(number(row.get("observer_usec"))')
    text = text[:first] + STEP_CHECK + text[last:]
    changes = {
        'row.get("accepted_samples")==[-1]': 'row.get("accepted_samples")==[-1]*8',
        'row.get("accepted_samples")==[row["completed_body_sample"]]': 'row.get("accepted_samples")==[row["completed_body_sample"]]*8',
        'len(identity[k]) == 1\n                 and integer(identity[k][0],-1)': 'len(identity[k]) == 8\n                 and all(integer(value,-1) for value in identity[k])',
        'len(step["control_generations"]) == 1\n             and integer(step["control_generations"][0])': 'len(step["control_generations"]) == 8\n             and all(integer(value) for value in step["control_generations"])',
        'campaign["schema"] == "pubpres-playability-campaign-v3"': 'campaign["schema"] == "pubpres-final-mixed-campaign-v1"',
        'data["schema"] == "pubpres-playability-gameplay-v3"': 'data["schema"] == "pubpres-final-mixed-gameplay-v1"',
        '"analysis_schema":"pubpres-playability-analysis-v3"': '"analysis_schema":"pubpres-final-mixed-analysis-v1"',
        'registered 10-to-90-second bounds': 'registered 60-to-90-second bounds',
    }
    for original, replacement in changes.items():
        text = replace_once(text, original, replacement)
    original = 'data["fixture"]["name"] in ("landscape2048x1024","basin512")'
    if text.count(original) != 2:
        raise ValueError("Mixed closed-water registration boundary changed")
    text = text.replace(original, 'data["fixture"]["name"] in ("basin512","basin1024")')
    header = '#!/usr/bin/env python3\n"""Separately registered eight-actor reducer; exact derivation in mixed_contract.py.\n\nAll frozen V3 native, terrain, real callback, input, Water and GPU predicates\nremain. Every former single-actor ownership predicate now covers all eight.\nThis does not accept or rewrite historical single-actor receipts.\n"""\n'
    return (header + text).encode("utf-8")


def verify_mixed_contract(root: Path) -> dict:
    folder = root / "tools/pubpres_final"
    registration = json.loads((folder / "mixed_registration.json").read_bytes())
    observer = folder / "pubpres_final_mixed_gameplay.gd"
    reducer = folder / "results_registered_mixed.py"
    if observer.read_bytes() != expected_mixed_observer((root / "tools/pubpres003/pubpres_causal_gameplay.gd").read_bytes(), registration):
        raise ValueError("Mixed observer changes an unregistered callback, owner, fixture or observation")
    if reducer.read_bytes() != expected_mixed_reducer((root / "tools/pubpres_playability/results_same_frame.py").read_bytes()):
        raise ValueError("Mixed reducer changes an unregistered frozen V3 predicate")
    return {"observer_base_sha256": BASE_OBSERVER_SHA256, "frozen_v3_sha256": FROZEN_V3_SHA256,
            "observer_sha256": hashlib.sha256(observer.read_bytes()).hexdigest(),
            "reducer_sha256": hashlib.sha256(reducer.read_bytes()).hexdigest(),
            "scope": "Explicit eight-actor fixture and ownership cardinality, ordinary paint tape, pre-owner native task selector and additive material/control/native-mode observations; original callback/native/terrain predicates retained."}
