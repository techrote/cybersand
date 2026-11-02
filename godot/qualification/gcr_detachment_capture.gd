extends SceneTree

# Explicit registered capture; deliberately outside automatic test discovery.
# Every live native access goes through the
# real session owner. This script does not choose the force law or move the body.
const Session = preload("res://scripts/solid_detachment_session.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL GCR DETACHMENT ", message)

func portable(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is Transform2D:
		return {"origin": portable(value.origin), "rotation": value.get_rotation()}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[str(key)] = portable(value[key])
		return result
	if value is Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedVector2Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(portable(entry))
		return result
	return value

func compact(value: Variant) -> Variant:
	# Full selected observations are retained separately. Per-step rows keep
	# scalar/vector ledgers, omitting large contact geometry arrays only.
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if str(key) not in ["contact_bins", "members", "cells", "terrain_chunks", "witness_offset_counts"]:
				result[str(key)] = compact(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(compact(entry))
		return result
	return portable(value)

func lowest_union_y(session: RefCounted, pose: Transform2D) -> float:
	var lowest: float = -INF
	var rectangles: PackedInt32Array = session.source_rectangles
	for offset: int in range(0,rectangles.size(),4):
		for corner: Vector2 in [Vector2.ZERO,Vector2(rectangles[offset+2],0),Vector2(0,rectangles[offset+3]),Vector2(rectangles[offset+2],rectangles[offset+3])]:
			var point: Vector2 = Vector2(rectangles[offset],rectangles[offset+1])+corner-session.source_center
			lowest = maxf(lowest,(pose*point).y)
	return lowest

func _run() -> void:
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--validate-only":
			arguments["validate-only"] = true
		elif argument.begins_with("--") and "=" in argument:
			var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
			arguments[pair[0]] = pair[1]
	var protocol_path: String = arguments.get("protocol", "")
	var output: String = arguments.get("output", "")
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	if not protocol is Dictionary:
		printerr("Registered protocol required"); quit(1); return
	var arm: String = arguments.get("candidate", "")
	var surroundings: String = arguments.get("surroundings", "")
	var workers: int = int(arguments.get("workers", "0"))
	var repeat: int = int(arguments.get("repeat", "0"))
	# JSON numbers are FLOAT Variants, while the command argument is an INT.
	# Array membership is type-sensitive; compare supported numeric values.
	var registered_worker: bool = false
	for value: Variant in protocol.workers:
		if (value is int or value is float) and is_finite(float(value)) and float(value) == float(workers):
			registered_worker = true
	check(arm in protocol.arms and surroundings in protocol.surroundings and registered_worker, "registered case")
	check(repeat == 0 or (repeat == 1 and arm == "R2" and workers == 1), "registered repeat")
	var identity: Dictionary = {}
	for key: String in ["source", "input_identity", "native_sha256", "protocol_sha256"]:
		identity[key] = OS.get_environment("CYBERSAND_" + key.to_upper())
		check(not str(identity[key]).is_empty(), "authenticated identity " + key)
	check(identity.protocol_sha256 == FileAccess.get_sha256(protocol_path), "protocol bytes match runner")
	var case_value: Dictionary = {"arm":arm,"surroundings":surroundings,"workers":workers,"repeat":repeat,"platform":OS.get_name()}
	if arguments.has("validate-only"):
		# This branch deliberately precedes Session.new/open and all edit calls.
		print("GCR_DETACHMENT_ARGUMENT_VALIDATION ",JSON.stringify({"ok":failures.is_empty(),"case":case_value,"identity":identity,
			"world_constructed":false,"body_constructed":false,"native_ticks":0,"rapier_steps":0,"external_edits":[],"failures":failures}))
		quit(0 if failures.is_empty() else 1)
		return
	var session = Session.new()
	var planned_cut: Dictionary = {"action":"cut_prepare","origin":[50,65],"size":[4,2],"removed_material":43,"removed_cells":8}
	var report: Dictionary = {"schema":"cybersand.gcr-detachment.capture.v1", "identity":identity,
		"case":case_value,"rows":[],"selected_observations":[],"external_edits":[],"planned_edits":[planned_cut],
		"cut_attempted":false,"cut_effect":null,"external_edits_complete":true,"failures":failures,
		"timing_scope":"functional asynchronous; observer and pause/inspect costs are recorded separately",
		"unsupported": ["pre_overlap", "post_overlap", "local_slip", "full_energy_calibration"],
		"cutoff_derivative":null}
	var started: int = Time.get_ticks_msec()
	if failures.is_empty() and await session.open(root, workers, surroundings, true, arm):
		var before: Dictionary = await session.inspect_coupling(PackedInt32Array(), Rect2i(0,0,160,128))
		report["before"] = portable(before)
		check(before.get("ok", false), "pre-cut native census")
		report["cut_attempted"] = true
		report["external_edits_complete"] = false
		if await session.cut_and_release():
			var confirmed_cut: bool = bool(session.source_receipt.get("cut_applied",false))
			check(confirmed_cut,"native receipt confirms ordinary cut")
			if confirmed_cut:
				var actual_cut: Dictionary = planned_cut.duplicate(true)
				actual_cut["receipt_token"] = session.source_receipt.get("token")
				actual_cut["evidence"] = "successful cut_and_release and native cut_applied receipt for unchanged authored8-cell trunk cut"
				report.external_edits.append(actual_cut)
				report["cut_effect"] = {"known":true,"removed_cells":8}
				report["external_edits_complete"] = true
			session.set_paused(true)
			var release: Dictionary = await session.inspect_coupling(PackedInt32Array(), Rect2i(0,0,160,128))
			report["release"] = portable(release)
			report["source_receipt"] = portable(session.source_receipt)
			check(int(session.source_receipt.get("member_count", -1)) == 520, "full source member count")
			check(is_equal_approx(session.body.mass,520.0), "native mass520")
			check(session.source_rectangles.size() == 24, "six original shapes")
			report["actual_body"] = {"mass":session.body.mass,"inertia":PhysicsServer2D.body_get_param(session.body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA),
				"gravity_scale":session.body.gravity_scale,"linear_damp":session.body.linear_damp,"angular_damp":session.body.angular_damp,
				"friction":PhysicsServer2D.body_get_param(session.body.get_rid(),PhysicsServer2D.BODY_PARAM_FRICTION)}
			var start_tick: int = int(release.get("actual_native_tick", -1))
			var target: int = start_tick + int(protocol.capture.native_tick_horizon)
			check(start_tick >= 0, "release tick observed")
			report["release_native_tick"] = start_tick
			report["target_native_tick"] = target
			var step: int = 0
			var last_tick: int = start_tick
			var previous_pose: Transform2D = session.body_transform()
			var release_bottom: float = lowest_union_y(session,previous_pose)
			report["release_lowest_union_y"] = release_bottom
			var previous_velocity := Vector2.ZERO
			var previous_omega: float = 0.0
			var previous_rapier_steps: int = session.bridge.manual_step_count()
			session.set_paused(false)
			while failures.is_empty() and last_tick < target:
				await physics_frame
				session.physics_step()
				var observer_started: int = Time.get_ticks_usec()
				var metrics: Dictionary = session.coupling_metrics()
				var pose: Transform2D = session.body_transform()
				var velocity: Vector2 = PhysicsServer2D.body_get_state(session.body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
				var omega: float = session.angular_velocity()
				var bottom: float = lowest_union_y(session,pose)
				var rapier_steps: int = session.bridge.manual_step_count()
				var dt: float = float(rapier_steps-previous_rapier_steps)*session.bridge.fixed_delta()
				last_tick = int(metrics.get("native_tick", last_tick))
				var row: Dictionary = {"step":step,"native_tick":last_tick,"rapier_step":rapier_steps,"physics_dt":dt,
					"position":portable(pose.origin),"rotation":pose.get_rotation(),"velocity":portable(velocity),"omega":omega,
					"lowest_union_y":bottom,"reference_union_bottom_entry":bottom-release_bottom,
					"lowest_union_at_or_below_floor_y":bottom>=72.0,
					"metrics":compact(metrics),"pose_derivative":null,"acceleration":null,"angular_acceleration":null,
					"pre_overlap":null,"post_overlap":null,"local_slip":null}
				if step > 0 and dt > 0.0:
					row.pose_derivative = portable((pose.origin-previous_pose.origin)/dt)
					row.acceleration = portable((velocity-previous_velocity)/dt)
					row.angular_acceleration = (omega-previous_omega)/dt
				row["observer_usec"] = Time.get_ticks_usec()-observer_started
				report.rows.append(row)
				if step % 60 == 0:
					report.selected_observations.append({"step":step,"native_tick":last_tick,"metrics":portable(metrics)})
				previous_pose = pose; previous_velocity = velocity; previous_omega = omega
				previous_rapier_steps = rapier_steps
				step += 1
				check(pose.origin.is_finite() and is_finite(pose.get_rotation()) and velocity.is_finite() and is_finite(omega), "finite actual body")
				check(not session.worker.has_failed(), "native owner healthy")
				check(not session.physics_paused, "active session remains unpaused")
				check(Time.get_ticks_msec()-started < int(protocol.capture.wall_timeout_seconds)*1000, "registered wall timeout")
			session.set_paused(true)
			report["stop_native_tick"] = last_tick
			report["observed_cutoff_overshoot"] = maxi(0,last_tick-target)
			report["after"] = portable(await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128)))
			report["final_coupling"] = portable(session.coupling_metrics())
			check(last_tick >= target, "native horizon reached")
		else:
			report["cut_effect"] = {"known":false,"removed_cells":null,"native_receipt":portable(session.source_receipt)}
			check(false, "actual handoff: " + session.last_error)
	else:
		check(false, "actual owner construction: " + session.last_error)
	report["elapsed_ms"] = Time.get_ticks_msec()-started
	report["failures"] = failures
	report["ok"] = failures.is_empty()
	session.close()
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report))
		else:
			check(false, "output writable")
	print("GCR_DETACHMENT_CAPTURE ", JSON.stringify({"case":report.case,"ok":failures.is_empty(),"rows":report.rows.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
