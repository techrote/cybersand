extends RefCounted

## Independent contracts for the additional ordinary gameplay adapters.
## Expected values come from action inputs, preceding observations and documented
## editor/lifecycle contracts, never from adapter-supplied expected-result fields.
const REPLACEMENTS := ["actor_remove", "actor_move", "actor_replace", "actor_equipment",
	"response_mode", "actor_settings", "restore_start"]
const NO_NATIVE_MUTATION := ["select_tool", "brush_radius", "preview_begin", "preview_cancel",
	"camera_pan", "camera_zoom", "camera_focus", "camera_mode", "actor_save_spawn",
	"actor_capture_spawn", "actor_release", "actor_hand_back", "actor_control"]
const FINITE_CANVAS_REFUSAL := "A body reached the finite canvas edge. Move, reset or remove it while paused."
## Independent finite contract, not a call back into the rig constructor.
## physical_actor_catalog: _biped/_crawl root zero; monowheel weighted_cab
## (0,1.5), tumbling_rim zero. player_actor_catalog._vehicle, retained Kestrel
## and reference_barrel also place their first body at zero offset.
## physical_actor_rig.configure adds each part offset to the authored origin;
## physical_actor_session.workbench_actor_state reports bodies()[0], not origin.
const ACTOR_ROOT_OFFSETS := {"kestrel": Vector2.ZERO, "reference_barrel": Vector2.ZERO,
	"runner": Vector2.ZERO, "crawler": Vector2.ZERO, "monowheel": Vector2(0, 1.5),
	"stuntbuggy": Vector2.ZERO}


static func actor_origin_root(model: String, spawn: Variant) -> Array:
	if model not in ACTOR_ROOT_OFFSETS or not spawn is Array or spawn.size() != 2: return []
	for value: Variant in spawn:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)): return []
	# The authored position enters Vector2 before part offsets are added.
	# Preserve that exact float boundary; do not add a blanket position tolerance.
	var root := Vector2(float(spawn[0]), float(spawn[1])) + Vector2(ACTOR_ROOT_OFFSETS[model])
	if not root.is_finite(): return []
	return [root.x, root.y]


static func actor_origin_parts(actor: Dictionary, model: String, spawn: Variant) -> bool:
	var expected := actor_origin_root(model, spawn)
	if expected.is_empty() or actor.get("model") != model or actor.get("observed") != true: return false
	var body: Variant = actor.get("state")
	if not body is Dictionary or not _same(body.get("position"), expected): return false
	var parts: Variant = body.get("retained_parts")
	if not parts is Array or parts.is_empty() or not parts[0] is Dictionary \
		or not _same(parts[0].get("position"), expected): return false
	if model == "monowheel":
		var origin := Vector2(float(spawn[0]), float(spawn[1]))
		if parts.size() < 2 or not parts[1] is Dictionary \
			or not _same(parts[1].get("position"), [origin.x, origin.y]): return false
	return true


static func _check(rows: Array[Dictionary], id: String, ok: bool, expected: Variant, actual: Variant, kind: String = "gameplay") -> void:
	rows.append({"id": id, "status": "pass" if ok else "fail", "kind": kind,
		"expected": expected, "actual": actual, "reason": ""})


static func _same(first: Variant, second: Variant) -> bool:
	if first is Array and second is Array:
		if first.size() != second.size(): return false
		for index: int in first.size():
			if not _same(first[index], second[index]): return false
		return true
	if first is Dictionary and second is Dictionary:
		if first.size() != second.size(): return false
		for key: Variant in first:
			if not second.has(key) or not _same(first[key], second[key]): return false
		return true
	return first == second


static func _actor(observation: Dictionary, id: int) -> Dictionary:
	for actor: Dictionary in observation.get("actors", []):
		if int(actor.get("id", -1)) == id: return actor
	return {}


static func _same_native(first: Dictionary, last: Dictionary) -> bool:
	for key: String in ["generation", "revision", "tick"]:
		if not first.has(key) or not last.has(key) or first[key] != last[key]: return false
	return true


static func _same_poses(first: Dictionary, last: Dictionary) -> bool:
	if not _same(first.get("actor_ids"), last.get("actor_ids")): return false
	for actor: Dictionary in first.get("actors", []):
		var other := _actor(last, int(actor.id))
		if not _same(actor.get("position"), other.get("position")) or actor.get("rotation") != other.get("rotation"): return false
	return true


static func finite_canvas_refusal(native: Dictionary, publication: Dictionary) -> Dictionary:
	# simulation_worker.gd:_consume loop publishes this exact legal edge stop;
	# a generic healthy body-sample refusal has no equivalent accepted contract.
	if publication.get("reason") != FINITE_CANVAS_REFUSAL or publication.get("paused") != true \
		or publication.get("failed") != false or native.get("failed") != false or native.get("paused") != true:
		return {}
	for field: String in ["generation", "revision", "tick"]:
		var value: Variant = native.get(field)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) \
			or float(value) != floor(float(value)) or value < (1 if field == "generation" else 0): return {}
	for field: String in ["generation", "tick", "serial"]:
		var value: Variant = publication.get(field)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) \
			or float(value) != floor(float(value)) or value < (0 if field == "tick" else 1): return {}
	if publication.generation != native.generation or publication.tick != native.tick: return {}
	return {"kind": "finite_canvas_edge", "reason": FINITE_CANVAS_REFUSAL,
		"source": "immutable_workbench_publication", "generation": native.generation,
		"revision": native.revision, "tick": native.tick, "snapshot_serial": publication.serial,
		"publication": {"reason": publication.reason, "generation": publication.generation,
			"tick": publication.tick, "serial": publication.serial, "paused": true, "failed": false}}


static func expected_boundary_refusal(record: Dictionary) -> bool:
	if record.get("status") != "partial" or record.get("classification") != "game_observation" \
		or record.get("admission", {}).get("accepted") != true: return false
	var after: Dictionary = record.get("after", {})
	var proof: Variant = record.get("expected_refusal", {})
	if not proof is Dictionary or not proof.get("publication") is Dictionary or after.get("paused") != true: return false
	var observed := finite_canvas_refusal(after.get("native", {}), proof.publication)
	if observed.is_empty() or not _same(proof, observed) or not _same(after.get("progress_refusal"), observed): return false
	var interval: Variant = record.get("interval", {})
	if not interval is Dictionary or not interval.get("progress_refusal", {}) is Dictionary: return false
	if interval.get("progress_refusal", {}).is_empty():
		var delivery: Variant = record.get("actor_delivery", {})
		if not delivery is Dictionary: return false
		interval = delivery.get("release_interval", {})
		if not interval is Dictionary: return false
	if not _same(interval.get("progress_refusal"), observed): return false
	return interval.get("ok") == false and interval.get("end_tick") == observed.tick \
		and typeof(interval.get("start_tick")) in [TYPE_INT, TYPE_FLOAT] and interval.start_tick <= observed.tick \
		and interval.start_tick >= 0 and float(interval.start_tick) == floor(float(interval.start_tick)) \
		and record.get("before", {}).get("native", {}).get("generation") == observed.generation


static func expected_boundary_capture_refusal(captured: Dictionary) -> bool:
	# paint_queue refuses even readonly captures while the exact finite-edge
	# stop is retained. This is a prequeue refusal, not a successful capture.
	for key: String in ["admission", "native_receipt", "source_before", "source_after", "progress_refusal"]:
		if not captured.get(key) is Dictionary: return false
	if not captured.get("error") is String or captured.error.is_empty() \
		or not str(captured.get("wait_failure_classification", "")).is_empty() \
		or captured.get("source_matches", false) != false or captured.has("materials"): return false
	var admission: Dictionary = captured.admission
	if admission.get("status") != "refused" or admission.get("accepted", false) != false \
		or admission.get("reason") != FINITE_CANVAS_REFUSAL or not captured.native_receipt.is_empty(): return false
	var before: Dictionary = captured.source_before
	var after: Dictionary = captured.source_after
	var proof: Dictionary = captured.progress_refusal
	if not _same(before, after) or not proof.get("publication") is Dictionary: return false
	var observed := finite_canvas_refusal(after, proof.publication)
	return not observed.is_empty() and _same(proof, observed)


static func evaluate(record: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var action: Dictionary = record.get("action", {})
	var id: String = str(action.get("id", ""))
	var args: Dictionary = action.get("args", {})
	var before: Dictionary = record.get("before", {})
	var after: Dictionary = record.get("after", {})
	var first: Dictionary = before.get("native", {})
	var last: Dictionary = after.get("native", {})
	if record.has("expected_refusal"):
		_check(rows, "finite_canvas_refusal_current_source", expected_boundary_refusal(record),
			"source-matched published finite edge stop after partial progress", record.get("expected_refusal"), "evidence")
	for capture_key: String in ["capture_before", "capture_after", "persistence_capture"]:
		var captured: Variant = record.get(capture_key, {})
		if captured is Dictionary and captured.has("progress_refusal"):
			var proof: Variant = captured.get("progress_refusal")
			var publication: Variant = proof.get("publication", {}) if proof is Dictionary else {}
			var current: Dictionary = finite_canvas_refusal(last, publication) if publication is Dictionary else {}
			_check(rows, "finite_edge_capture_source_" + capture_key, expected_boundary_capture_refusal(captured) \
				and not current.is_empty() and _same(current, proof) and _same(after.get("progress_refusal"), current),
				"exact prequeue edge refusal at the unchanged current paused owner", captured, "evidence")
	if record.get("status") == "refused" and record.get("admission", {}).is_empty() \
		and before.get("paused") == true and after.get("paused") == true and not first.is_empty() and not last.is_empty():
		_check(rows, "unadmitted_paused_action_keeps_native", _same_native(first, last), first, last)
	if record.get("status") != "completed": return rows
	if after.has("world_size"):
		_check(rows, "disposable_world_extent", _same(after.world_size, [512, 512]), [512, 512], after.world_size)
		_check(rows, "logical_actor_capacity", after.get("actor_ids", []).size() <= 8, "at most eight actual actors", after.get("actor_ids", []).size())
		var camera: Dictionary = after.get("camera", {})
		var origin: Array = camera.get("origin", [])
		var size: Array = camera.get("size", [])
		var inside: bool = origin.size() == 2 and size.size() == 2
		if inside: inside = origin[0] >= 0 and origin[1] >= 0 and size[0] > 0 and size[1] > 0 \
			and origin[0] + size[0] <= 512 and origin[1] + size[1] <= 512
		_check(rows, "camera_inside_actual_world", inside, "positive camera extent wholly inside World", camera)
	if id in ["source_place", "source_burst", "source_stream"]:
		var publication: Dictionary = after.get("source", {})
		_check(rows, "source_command_consumed_and_published", int(publication.get("pending_commands", -1)) == 0 \
			and int(publication.get("snapshot_serial", -1)) > int(before.get("snapshot_serial", -1)),
			"actual command queue drained and newer immutable publication observed",
			{"pending": publication.get("pending_commands"), "serial": publication.get("snapshot_serial")}, "evidence")
	if id in NO_NATIVE_MUTATION and before.get("paused") == true and after.get("paused") == true:
		_check(rows, "control_only_keeps_native", _same_native(first, last), first, last)
	if id in REPLACEMENTS:
		_check(rows, "replacement_publishes_new_native_owner", int(last.get("generation", -1)) > int(first.get("generation", -1)),
			"new actual native generation", last.get("generation"))
		if after.get("actor_ids", []).is_empty():
			_check(rows, "empty_replacement_retires_physical_owner", after.get("physical_session_active") == false \
				and int(after.get("physical_body_count", -1)) == 0 and int(after.get("physical_proxy_count", -1)) == 0,
				"no actor session, bodies or proxies", {"active": after.get("physical_session_active"),
				"bodies": after.get("physical_body_count"), "proxies": after.get("physical_proxy_count")})
		else:
			_check(rows, "replacement_publishes_new_physical_owner", int(after.get("physical_epoch", -1)) > int(before.get("physical_epoch", -1)) \
				and after.get("physical_session_active") == true and after.get("physical_ready") == true,
				"new ready actual physical epoch", after.get("physical_epoch"))
	match id:
		"select_tool":
			_check(rows, "ordinary_tool_readback", after.get("tool") == args.get("tool"), args.get("tool"), after.get("tool"))
		"brush_radius":
			_check(rows, "ordinary_radius_readback", after.get("brush_radius") == args.get("radius"), args.get("radius"), after.get("brush_radius"))
		"preview_begin":
			_check(rows, "ordinary_preview_active", after.get("paint_preview", {}).get("dragging") == true, true, after.get("paint_preview"))
		"preview_cancel":
			_check(rows, "ordinary_preview_cancelled", after.get("paint_preview", {}).get("dragging") == false \
				and int(after.get("paint_preview", {}).get("samples", -1)) == 0, "no pending gesture", after.get("paint_preview"))
		"interrupt_stroke":
			var interrupted: Dictionary = record.get("interruption", {})
			_check(rows, "interrupted_actual_operation", interrupted.get("observed_busy") == true and interrupted.get("editor_idle") == true,
				"actual pending planner reached idle after Cancel", interrupted, "evidence")
			if interrupted.get("terminal") == "cancelled_before_native":
				_check(rows, "pre_native_cancel_preserves_materials", _same(record.get("capture_before", {}).get("materials"), record.get("capture_after", {}).get("materials")) \
					and _same_native(first, last), "identical actual captures and native identity", {"before": first, "after": last})
			else:
				_check(rows, "partial_cancel_keeps_actual_receipt", int(record.get("native_receipt", {}).get("applied", 0)) > 0,
					"nonzero actual partial receipt", record.get("native_receipt"), "evidence")
		"live_stroke":
			var edit: Dictionary = record.get("live_edit", {})
			var stamps: Array = edit.get("stamps", [])
			var expected_points := [[int(args.x0), int(args.y0)], [int(args.x1), int(args.y1)]]
			var valid: bool = not stamps.is_empty() and stamps.size() <= 2
			for stamp: Variant in stamps:
				if not stamp is Array or stamp.size() != 4:
					valid = false
					continue
				var belongs := false
				for point: Array in expected_points:
					if _same(stamp.slice(0, 2), point): belongs = true
				valid = valid and belongs and stamp[3] == before.get("material")
			_check(rows, "live_brush_authored_acknowledgement", valid \
				and int(edit.get("authored_after", 0)) > int(edit.get("authored_before", 0)), "bounded actual endpoint stamps", stamps, "evidence")
			_check(rows, "live_brush_native_progress", int(last.get("tick", -1)) > int(first.get("tick", -1)) and after.get("paused") == false,
				"native progression during ordinary running edit", last)
			rows.append({"id": "live_brush_atomic_material_equality", "status": "not_applicable", "kind": "evidence",
				"expected": null, "actual": null, "reason": "Asynchronous simulation has no atomic cell-equality contract for running gestures."})
		"camera_pan":
			var start: Array = before.get("camera", {}).get("origin", [0, 0])
			var size: Array = before.get("camera", {}).get("size", [0, 0])
			var expected := [clampf(float(start[0]) + float(args.dx), 0.0, 512.0 - float(size[0])),
				clampf(float(start[1]) + float(args.dy), 0.0, 512.0 - float(size[1]))]
			_check(rows, "camera_pan_clamped", _same(after.get("camera", {}).get("origin"), expected), expected, after.get("camera"))
		"camera_zoom":
			var zoom: int = clampi(int(before.get("camera", {}).get("zoom_index", 1)) + int(args.direction), 0, 2)
			var sizes := [[240, 135], [480, 270], [512, 512]]
			_check(rows, "camera_zoom_preset", _same(after.get("camera", {}).get("size"), sizes[zoom]), sizes[zoom], after.get("camera"))
		"camera_mode":
			_check(rows, "camera_mode_readback", int(after.get("camera", {}).get("mode", -1)) == ["free", "follow", "overview"].find(str(args.mode)),
				args.mode, after.get("camera"))
			if args.mode == "overview":
				_check(rows, "overview_contains_world", _same(after.get("camera", {}).get("origin"), [0, 0]) \
					and _same(after.get("camera", {}).get("size"), [512, 512]), "whole disposable World", after.get("camera"))
		"actor_remove":
			var expected: Array = before.get("actor_ids", []).duplicate()
			expected.erase(before.get("selected_actor"))
			_check(rows, "actor_retirement_roster", _same(expected, after.get("actor_ids")), expected, after.get("actor_ids"))
			_check(rows, "retired_actor_not_piloted", int(after.get("pilot_actor", 0)) != int(before.get("selected_actor", -1)),
				"retired identity owns no pilot", after.get("pilot_actor"))
		"actor_move", "actor_save_spawn", "actor_capture_spawn":
			var target: int = int(before.get("selected_actor", 0))
			var old_actor := _actor(before, target)
			var new_actor := _actor(after, target)
			var expected: Array = old_actor.get("position", []).duplicate() if id == "actor_capture_spawn" else [args.x, args.y]
			if id == "actor_capture_spawn" and expected.size() == 2:
				# Ordinary X/Y fields are hundredth-cell SpinBoxes; entered_position
				# then crosses the Vector2 float boundary before authored serialization.
				var entered := Vector2(floorf(float(expected[0]) * 100.0 + 0.5) / 100.0,
					floorf(float(expected[1]) * 100.0 + 0.5) / 100.0)
				expected = [entered.x, entered.y]
			_check(rows, "authored_reset_spawn_readback", _same(new_actor.get("authored_spawn"), expected), expected, new_actor.get("authored_spawn"))
			if id == "actor_move":
				var root := actor_origin_root(str(old_actor.get("model", "")), expected)
				_check(rows, "actor_move_actual_position", not root.is_empty() and _same(new_actor.get("position"), root), root, new_actor.get("position"))
				_check(rows, "actor_move_part_origins", actor_origin_parts(new_actor, str(old_actor.get("model", "")), expected),
					"fresh physical parts at authored origin plus fixed model offsets", new_actor.get("state"))
			else:
				_check(rows, "spawn_edit_keeps_live_poses", _same_poses(before, after), "unchanged physical poses", new_actor.get("position"))
		"actor_replace":
			var removed: int = int(before.get("selected_actor", 0))
			var added: int = int(before.get("next_actor_id", 0))
			var expected: Array = before.get("actor_ids", []).duplicate()
			var slot: int = expected.find(removed)
			if slot >= 0: expected[slot] = added
			var replacement := _actor(after, added)
			_check(rows, "actor_replacement_roster", slot >= 0 and _same(expected, after.get("actor_ids")), expected, after.get("actor_ids"))
			_check(rows, "actor_replacement_model", replacement.get("model") == args.get("model"), args.get("model"), replacement.get("model"))
			var spawn: Variant = _actor(before, removed).get("authored_spawn")
			var root := actor_origin_root(str(args.get("model", "")), spawn)
			_check(rows, "actor_replacement_authored_spawn", not root.is_empty() and _same(replacement.get("authored_spawn"), spawn), spawn, replacement.get("authored_spawn"))
			_check(rows, "actor_replacement_position", not root.is_empty() and _same(replacement.get("position"), root), root, replacement.get("position"))
			_check(rows, "actor_replacement_part_origins", actor_origin_parts(replacement, str(args.get("model", "")), spawn),
				"fresh physical parts at retained authored origin plus fixed model offsets", replacement.get("state"))
		"actor_release":
			_check(rows, "pilot_released", after.get("pilot_actor") == 0, 0, after.get("pilot_actor"))
			_check(rows, "pilot_release_keeps_pose", _same_poses(before, after), "unchanged physical poses", after.get("actor_ids"))
		"actor_hand_back":
			var previous := _actor(after, int(before.get("pilot_actor", 0)))
			_check(rows, "pilot_handback_producer", previous.get("authored_control", {}).get("source") != "human" \
				and after.get("pilot_actor") != before.get("pilot_actor"), "nonhuman producer owns former pilot", previous.get("authored_control"))
			_check(rows, "pilot_handback_keeps_pose", _same_poses(before, after), "unchanged physical poses", after.get("actor_ids"))
		"actor_control":
			var actor := _actor(after, int(args.actor_id))
			var control: Dictionary = actor.get("authored_control", {})
			_check(rows, "actor_controller_readback", control.get("source") == args.producer and control.get("enabled") == args.enabled,
				{"source": args.producer, "enabled": args.enabled}, control)
			_check(rows, "controller_change_keeps_pose", _same_poses(before, after), "unchanged physical poses", after.get("actor_ids"))
			var actual: Dictionary = actor.get("control_observation", {})
			_check(rows, "actor_live_producer_readback", actual.get("producer") == ("demo" if args.producer == "scripted" else args.producer),
				"demo" if args.producer == "scripted" else args.producer, actual.get("producer"))
		"actor_equipment":
			var actor := _actor(after, int(args.actor_id))
			_check(rows, "actor_equipment_authoring", actor.get("authored_control", {}).get("usable_index") == args.usable_index,
				args.usable_index, actor.get("authored_control"))
			_check(rows, "actor_equipment_roster", _same(before.get("actor_ids"), after.get("actor_ids")), before.get("actor_ids"), after.get("actor_ids"))
		"actor_actuate", "actor_trigger":
			var delivery: Dictionary = record.get("actor_delivery", {})
			var accepted: Dictionary = delivery.get("during", {})
			var prior: Dictionary = delivery.get("before", {})
			var pilot: int = int(before.get("pilot_actor", 0))
			var owner_ok: bool = pilot > 0 and delivery.get("instance_id") == pilot \
				and accepted.get("instance_id") == pilot and accepted.get("producer") == "human" \
				and accepted.get("generation") == prior.get("generation") and accepted.get("epoch") == prior.get("epoch") \
				and int(accepted.get("lease_remaining", 0)) > 0
			_check(rows, "actuator_live_input_admission", owner_ok and int(accepted.get("accepted", 0)) > int(prior.get("accepted", 0)) \
				and int(accepted.get("last_sequence", 0)) > int(prior.get("last_sequence", 0)),
				"current human owner accepted a new bounded input sequence",
				{"instance_id": accepted.get("instance_id"), "producer": accepted.get("producer"), "generation": accepted.get("generation"),
				"epoch": accepted.get("epoch"), "accepted": accepted.get("accepted"), "last_sequence": accepted.get("last_sequence")}, "evidence")
			var interval: Dictionary = record.get("interval", {})
			_check(rows, "actuator_native_and_physical_progress", int(interval.get("end_tick", -1)) - int(interval.get("start_tick", -1)) >= int(args.ticks) \
				and int(interval.get("end_actor_tick", -1)) > int(interval.get("start_actor_tick", -1)),
				"requested native interval and actual physical input samples advanced", interval, "evidence")
			var command: Dictionary = delivery.get("sampled_command", {})
			var released: Dictionary = delivery.get("released_command", {})
			var sampled := false
			var neutral := false
			if id == "actor_trigger":
				sampled = command.get("equipment", {}).get(str(args.button), false) == true
				neutral = released.get("equipment", {}).get(str(args.button), false) == false
			else:
				var port: String = str(args.port)
				if port in ["q", "e", "boost"]:
					sampled = delivery.get("sampled_ports", {}).get("ports", {}).get(port, false) == true
					neutral = delivery.get("released_ports", {}).get("ports", {}).get(port, false) == false
				elif port in ["primary", "secondary"]:
					sampled = command.get(port, false) == true
					neutral = released.get(port, false) == false
				else:
					sampled = float(command.get("reel", 0.0)) < 0.0 if port == "reel_in" else float(command.get("reel", 0.0)) > 0.0
					neutral = float(released.get("reel", 1.0)) == 0.0
			_check(rows, "requested_actuator_sampled", sampled, args, command)
			_check(rows, "requested_actuator_released", neutral, "neutral released input", released)
			if id == "actor_trigger":
				var current_actor := _actor(after, pilot)
				var control: Dictionary = current_actor.get("control_observation", {})
				var equipment: Dictionary = control.get("equipment", {})
				var receipt: Dictionary = equipment.get("last_receipt", {})
				var previous_receipt: Dictionary = _actor(before, pilot).get("control_observation", {}).get("equipment", {}).get("last_receipt", {})
				if not receipt.is_empty() and receipt.get("request_id") != previous_receipt.get("request_id"):
					var receipt_owner: bool = receipt.get("instance_id") == equipment.get("instance_id") \
						and receipt.get("equipment_epoch") == equipment.get("equipment_epoch") \
						and receipt.get("usable_index") == equipment.get("usable_index") \
						and receipt.get("generation") == control.get("control_generation") \
						and receipt.get("epoch") == control.get("epoch") and receipt.get("run_id") == control.get("run_id") \
						and receipt.get("actor_id") == control.get("actor_id")
					_check(rows, "equipment_receipt_current_owner", receipt_owner, "actual current actor, equipment and controller identities", receipt, "evidence")
					var charge: float = float(receipt.get("charge", -1))
					var cooldown: float = float(receipt.get("cooldown", -1))
					_check(rows, "equipment_receipt_resource_bounds", is_finite(charge) and charge >= 0.0 and charge <= 100.0 \
						and is_finite(cooldown) and cooldown >= 0.0 and cooldown <= 60.0,
						{"charge": [0, 100], "cooldown": [0, 60]}, {"charge": charge, "cooldown": cooldown})
		"response_mode":
			_check(rows, "response_configuration_readback", after.get("configuration", {}).get("response") == args.mode,
				args.mode, after.get("configuration"))
		"actor_settings":
			var actor := _actor(after, int(before.get("selected_actor", 0)))
			# The ordinary budget field uses integer steps; mass/inertia use 0.01.
			var units: float = 1.0 if args.field == "budget" else 100.0
			var expected: float = floorf(float(args.value) * units + 0.5) / units
			_check(rows, "actor_tuning_readback", is_equal_approx(float(actor.get("options", {}).get(str(args.field), -999)), expected),
				{"requested": args.value, "ordinary_control_value": expected}, actor.get("options", {}).get(str(args.field)))
		"restore_start":
			_check(rows, "restore_current_authored_start", before.get("authored_digest") == after.get("authored_digest"),
				before.get("authored_digest"), after.get("authored_digest"))
			_check(rows, "restore_native_clock_origin", int(last.get("tick", -1)) == 0, 0, last.get("tick"))
		"source_place":
			var source: Dictionary = after.get("source", {}).get("receipt", {})
			_check(rows, "source_configuration_native_ack", _same(source.get("origin"), [args.x, args.y]) \
				and source.get("material") == before.get("material") and source.get("stream_enabled") == false \
				and source.get("burst_queued") == false and int(source.get("stream_ticks", -1)) == 0,
				{"origin": [args.x, args.y], "material": before.get("material"), "stream": false, "ticks": 0}, source)
		"source_burst", "source_stream":
			var source: Dictionary = after.get("source", {}).get("receipt", {})
			_check(rows, "source_accounting_partition", int(source.get("attempted", -1)) == int(source.get("inserted", -2)) + int(source.get("blocked", -2)),
				"attempted = inserted + blocked", source)
			if id == "source_burst":
				var prior: Dictionary = before.get("source", {}).get("receipt", {})
				_check(rows, "source_burst_bounded_work", int(source.get("attempted", 0)) - int(prior.get("attempted", 0)) == 96,
					"one ordinary 4x24 burst", int(source.get("attempted", 0)) - int(prior.get("attempted", 0)))
			else:
				_check(rows, "source_stream_native_ack", source.get("stream_enabled") == args.enabled, args.enabled, source.get("stream_enabled"))
		"replace_fixture":
			_check(rows, "replacement_fixture_identity", after.get("fixture_id") == args.fixture, args.fixture, after.get("fixture_id"))
			_check(rows, "replacement_authored_identity", after.get("authored_digest") == after.get("scene_identity"),
				after.get("scene_identity"), after.get("authored_digest"))
			_check(rows, "replacement_native_clock_origin", int(last.get("tick", -1)) == 0 and int(last.get("generation", -1)) > int(first.get("generation", -1)),
				"new native generation at tick zero", last)
	return rows
