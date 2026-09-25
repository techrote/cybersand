extends SceneTree

# PCHAR-001 / #137 is an experiment. These checks protect ownership,
# conservation and the switch mechanisms; they do not declare either
# representation to be the final player model.

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PCHAR-001: " + message)


func _fill(
	world: CyberCellWorld,
	x0: int,
	y0: int,
	width: int,
	height: int,
	material: int
) -> void:
	for y: int in range(y0, y0 + height):
		for x: int in range(x0, x0 + width):
			world.set_cell(x, y, material)


func _material_count(world: CyberCellWorld, material: int) -> int:
	var result: int = 0
	for value: int in world.cells:
		result += int(value == material)
	return result


func _fresh_sampled_world() -> CyberCellWorld:
	var world := CyberCellWorld.new()
	# The recovery fixture only needs serialized occupancy queries. Clearing the
	# demo payload yields a deterministic fresh setup without running a tick.
	world.cells.fill(CyberCellWorld.EMPTY)
	world.updated_at.fill(0)
	world.rigid_body_occupancy.fill(0)
	world.rigid_body_occupied_indices.clear()
	world.tick_index = 0
	return world


func _sampled_recovery_contract() -> Dictionary:
	const START: Vector2 = Vector2(100.0, 100.0)
	var world: CyberCellWorld = _fresh_sampled_world()
	_fill(world, 100, 100, 8, 14, CyberCellWorld.SAND)
	var initial_sand: int = _material_count(world, CyberCellWorld.SAND)

	var baseline := CyberSampledCharacter.new()
	baseline.configure_runtime_enclosure_recovery(true)
	baseline.reset(START)
	baseline.simulate(0.0, 0.0, false, world)
	_check(
		baseline.runtime_recovery_attempts == 1
		and baseline.runtime_recovery_successes == 1,
		"sampled baseline did not expose the runtime enclosure recovery"
	)
	_check(
		baseline.last_recovery_kind == "runtime"
		and baseline.last_recovery_offset.y < 0.0,
		"sampled baseline did not identify upward-first relocation"
	)
	_check(
		baseline.runtime_recovery_upward_cells > 0,
		"sampled baseline did not count upward surfacing distance"
	)
	_check(
		_material_count(world, CyberCellWorld.SAND) == initial_sand,
		"sampled runtime recovery changed authoritative Sand"
	)

	var burial_safe := CyberSampledCharacter.new()
	burial_safe.configure_runtime_enclosure_recovery(false)
	burial_safe.reset(START)
	burial_safe.simulate(0.0, 1.0, false, world)
	_check(
		burial_safe.position.is_equal_approx(START),
		"burial-safe sampled mode reordered the runtime actor"
	)
	_check(
		burial_safe.runtime_enclosed and burial_safe.recovery_blocked,
		"burial-safe sampled mode did not retain explicit enclosure state"
	)
	_check(
		burial_safe.runtime_recovery_attempts == 0,
		"burial-safe sampled mode entered the runtime search path"
	)

	var invalid_spawn := CyberSampledCharacter.new()
	invalid_spawn.configure_runtime_enclosure_recovery(false)
	invalid_spawn.reset(START)
	_check(
		invalid_spawn.recover_invalid_spawn(world),
		"explicit invalid-spawn recovery failed"
	)
	_check(
		invalid_spawn.invalid_spawn_recovery_attempts == 1
		and invalid_spawn.invalid_spawn_recovery_successes == 1
		and invalid_spawn.last_recovery_kind == "invalid-spawn",
		"invalid-spawn recovery was not distinguished from runtime recovery"
	)
	_check(
		invalid_spawn.last_recovery_offset.y < 0.0,
		"invalid-spawn fixture did not exercise the bounded repair search"
	)

	# Progressive burial: add stable granular layers into a fresh player's
	# volume. With runtime reordering disabled the actor remains where it was,
	# while material remains authoritative and conserved.
	var progressive_world: CyberCellWorld = _fresh_sampled_world()
	var progressive := CyberSampledCharacter.new()
	progressive.configure_runtime_enclosure_recovery(false)
	progressive.reset(Vector2(200.0, 100.0))
	var progressive_start: Vector2 = progressive.position
	for layer: int in range(4):
		_fill(
			progressive_world,
			200,
			111 - layer * 3,
			8,
			3,
			CyberCellWorld.SAND
		)
		var before: int = _material_count(
			progressive_world,
			CyberCellWorld.SAND
		)
		progressive.simulate(0.0, 0.0, false, progressive_world)
		_check(
			progressive.position.is_equal_approx(progressive_start),
			"progressive burial caused automatic player surfacing"
		)
		_check(
			_material_count(progressive_world, CyberCellWorld.SAND) == before,
			"progressive burial deleted or duplicated Sand"
		)

	return {
		"baseline_offset": [
			baseline.last_recovery_offset.x,
			baseline.last_recovery_offset.y,
		],
		"baseline_upward_cells": baseline.runtime_recovery_upward_cells,
		"burial_safe_position": [
			burial_safe.position.x,
			burial_safe.position.y,
		],
		"invalid_spawn_offset": [
			invalid_spawn.last_recovery_offset.x,
			invalid_spawn.last_recovery_offset.y,
		],
	}


func _body_result(
	sample_serial: int,
	impulse: Vector2
) -> PackedFloat32Array:
	return PackedFloat32Array([
		1.0,
		impulse.x,
		impulse.y,
		0.0,
		0.0,
		1.0,
		0.0,
		0.0,
		float(sample_serial),
	])


func _barrel_control_preserves_reaction() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(64, 64)
	root.add_child(viewport)

	var body := RigidBody2D.new()
	body.mass = 1.0
	body.gravity_scale = 0.0
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 14)
	collision.shape = shape
	body.add_child(collision)
	viewport.add_child(body)
	await process_frame

	var bridge := CyberRapierPhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [body]
	_check(
		bridge.initialize(
			viewport.world_2d.space,
			bodies,
			PackedVector2Array([Vector2(8, 14)])
		) == OK,
		"barrel control bridge initialization failed"
	)
	bridge.reset_body(0, Vector2(32, 32), 0.0)
	var state: PackedFloat32Array = bridge.pack_body_states()
	var serial: int = roundi(
		state[CyberRigidBodyCoupling.INPUT_SAMPLE_SERIAL]
	)
	_check(
		bridge.apply_cellular_results(
			1,
			_body_result(serial, Vector2(1.25, -0.5))
		) == 1,
		"synthetic cellular reaction was not accepted"
	)
	bridge.step()
	var after_reaction: Vector2 = bridge.body_linear_velocity(0)
	var control_impulse: float = bridge.apply_horizontal_control(
		0,
		1.0,
		CyberPlayerRepresentation.BARREL_WALK_SPEED,
		CyberPlayerRepresentation.BARREL_HORIZONTAL_ACCELERATION,
		CyberPlayerRepresentation.BARREL_MAX_HORIZONTAL_IMPULSE,
		1.0 / 60.0
	)
	bridge.step()
	var after_control: Vector2 = bridge.body_linear_velocity(0)
	_check(
		after_reaction.x > 0.0 and after_reaction.y < 0.0,
		"incoming cellular impulse was not observable before control"
	)
	_check(
		control_impulse > 0.0
		and control_impulse
			<= CyberPlayerRepresentation.BARREL_MAX_HORIZONTAL_IMPULSE + 0.0001,
		"horizontal locomotion impulse exceeded its registered bound"
	)
	_check(
		after_control.x > after_reaction.x,
		"horizontal control overwrote rather than added to incoming reaction"
	)
	_check(
		is_equal_approx(after_control.y, after_reaction.y),
		"horizontal control changed vertical velocity"
	)
	_check(
		after_control.x < CyberPlayerRepresentation.BARREL_WALK_SPEED,
		"barrel controller assigned the target velocity directly"
	)

	bridge.shutdown()
	viewport.queue_free()
	await process_frame
	return {
		"reaction_velocity": [after_reaction.x, after_reaction.y],
		"control_impulse": control_impulse,
		"post_control_velocity": [after_control.x, after_control.y],
	}


func _barrel_fixture_matrix() -> Array:
	var cases: Array = [
		{
			"id": "falling-onto-player",
			"layout": "burial",
			"ticks": 180,
			"horizontal_input": 0.0,
		},
		{
			"id": "walking-into-loose-falling",
			"layout": "burial",
			"ticks": 180,
			"horizontal_input": 1.0,
		},
		{
			"id": "adjacent-pile-support-erased",
			"layout": "side_erase",
			"ticks": 210,
			"horizontal_input": 1.0,
			"explicit_fixture_erase": true,
		},
		{
			"id": "progressive-burial",
			"layout": "burial",
			"ticks": 300,
			"horizontal_input": 0.0,
		},
		{
			"id": "lateral-pressure",
			"layout": "side",
			"ticks": 180,
			"horizontal_input": 1.0,
		},
		{
			"id": "ordinary-packed-support",
			"layout": "flat",
			"ticks": 180,
			"horizontal_input": 0.0,
		},
		{
			"id": "hard-terrain-control",
			"layout": "hard",
			"ticks": 120,
			"horizontal_input": 1.0,
		},
	]
	var reports: Array = []
	for spec: Dictionary in cases:
		var run_spec: Dictionary = spec.duplicate(true)
		run_spec["mode"] = "barrel"
		run_spec["material"] = CyberCellWorld.SAND
		run_spec["seed"] = 0
		run_spec["depth"] = 192
		run_spec["telemetry"] = true
		var report: Dictionary = await CyberPhysicsCharacterisation.run_case(
			root,
			run_spec
		)
		reports.append(report)
		_check(
			bool(report.get("ok", false)),
			str(spec.id) + " failed to execute"
		)
		if not bool(report.get("ok", false)):
			continue

		var peak_control: float = float(
			report.get("horizontal_control_peak_impulse", 0.0)
		)
		_check(
			peak_control
				<= CyberPlayerRepresentation.BARREL_MAX_HORIZONTAL_IMPULSE
				+ 0.0001,
			str(spec.id) + " exceeded barrel control impulse bound"
		)
		if absf(float(spec.horizontal_input)) > 0.001:
			_check(
				float(report.get(
					"horizontal_control_abs_impulse",
					0.0
				)) > 0.0,
				str(spec.id) + " produced no horizontal locomotion impulse"
			)

		if not bool(spec.get("explicit_fixture_erase", false)):
			var initial: Dictionary = report.get("initial", {})
			var final: Dictionary = report.get("final", {})
			var initial_counts: Variant = initial.get("counts", [])
			var final_counts: Variant = final.get("counts", [])
			if (
				initial_counts.size() > CyberCellWorld.SAND
				and final_counts.size() > CyberCellWorld.SAND
			):
				_check(
					int(initial_counts[CyberCellWorld.SAND])
						== int(final_counts[CyberCellWorld.SAND]),
					str(spec.id) + " changed Sand count without an explicit source/sink"
				)

		if str(spec.id) == "ordinary-packed-support":
			_check(
				int(report.get("floor_contact_tick", -1)) < 0,
				"ordinary packed-support barrel reached the hard floor"
			)
			_check(
				int(report.get("support_samples", 0)) > 0,
				"ordinary packed-support barrel observed no granular bearing"
			)
		await process_frame
	return reports


func _run() -> void:
	_check(
		CyberPlayerRepresentation.identity(
			CyberPlayerRepresentation.SAMPLED,
			true
		) == "sampled-baseline",
		"sampled baseline identity changed"
	)
	_check(
		CyberPlayerRepresentation.identity(
			CyberPlayerRepresentation.SAMPLED,
			false
		) == "sampled-burial-safe",
		"burial-safe sampled identity changed"
	)
	_check(
		CyberPlayerRepresentation.identity(
			CyberPlayerRepresentation.BARREL_RAPIER,
			true
		) == "barrel-rapier",
		"barrel identity changed"
	)

	var sampled: Dictionary = _sampled_recovery_contract()
	var reaction: Dictionary = await _barrel_control_preserves_reaction()
	var fixtures: Array = await _barrel_fixture_matrix()
	var summary: Array = []
	for report: Dictionary in fixtures:
		summary.append({
			"id": report.get("spec", {}).get("id", "unknown"),
			"ok": report.get("ok", false),
			"peak_depth": report.get("peak_depth"),
			"final_depth": report.get("final_depth"),
			"applied_impulse": report.get("applied_impulse"),
			"control_abs_impulse": report.get(
				"horizontal_control_abs_impulse"
			),
			"control_peak_impulse": report.get(
				"horizontal_control_peak_impulse"
			),
			"displaced": report.get("displaced"),
			"unresolved": report.get("unresolved"),
		})

	print("PCHAR001 ", JSON.stringify({
		"schema": "pchar001-v1",
		"sampled": sampled,
		"reaction_control": reaction,
		"fixtures": summary,
	}))
	if not _failed:
		print("PCHAR-001 player representation experiment passed")
	quit(1 if _failed else 0)
