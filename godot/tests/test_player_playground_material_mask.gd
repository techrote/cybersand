extends SceneTree

# Read the actual native mask at each effect entry after a real Rapier impulse
# has moved a loose prop out of its previous native footprint. The proxy only
# observes/delegates native calls; it neither supplies a fake mask nor moves a
# body. This catches preparing the mask only later inside Arena.step.
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Usables = preload("res://scripts/usable_catalog.gd")

class EffectProbe extends RefCounted:
	var native: Object
	var point := Vector2i.ZERO
	var field_masks: Array[int] = []
	var tool_masks: Array[int] = []

	func prepare_rigid_body_coupling(states: PackedFloat32Array, feedback: bool) -> void:
		native.prepare_rigid_body_coupling(states, feedback)

	func apply_player_material_field(centre: Vector2i, move: Vector2, material: int, mode: int, phase: int) -> Dictionary:
		field_masks.append(int(native.rigid_body_id_at(point.x, point.y)))
		return native.apply_player_material_field(centre, move, material, mode, phase)

	func has_failed() -> bool:
		# UsableRuntime checks World failure before processing any tool writes.
		tool_masks.append(int(native.rigid_body_id_at(point.x, point.y)))
		return native.has_failed()

	func material_at(x: int, y: int) -> int:
		return native.material_at(x, y)

	func emit_disc(x: int, y: int, radius: int, material: int) -> void:
		native.emit_disc(x, y, radius, material)


var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYGROUND_MATERIAL_MASK: " + message)


func run() -> void:
	for player: StringName in [&"dryswarm", &"liquidswarm"]:
		await moving_prop_effect_boundary(player)
	print("PLAYGROUND_MATERIAL_MASK: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)


func moving_prop_effect_boundary(player: StringName) -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	expect(runtime.configure(player, &"mixed"), "real shared material/prop host configures: " + str(player))
	if not runtime.active():
		runtime.free()
		return
	var arena = runtime._arena
	var world: Object = arena.native_world()
	var bridge = arena.session.bridge
	var prop: RigidBody2D = arena._props[0]
	var body_index: int = arena._prop_body_offset
	var expected_id: int = body_index + 1
	var original: Vector2 = bridge.body_transform(body_index).origin
	expect(world.diagnostic_fill_rect(Vector2i(original) - Vector2i(64, 64), Vector2i(128, 128), 0),
		"bounded fixture clears a prop's impulse path")
	arena._sync_terrain()
	PhysicsServer2D.body_apply_central_impulse(prop.get_rid(), Vector2(300, -120) * prop.mass)
	runtime.submit_action({"move": Vector2.ZERO})
	runtime.step()
	var pose: Transform2D = bridge.body_transform(body_index)
	expect(pose.origin.distance_to(original) > 3.0, "actual Rapier impulse moved the prop")
	# Locate a real current OBB cell that the prior pre-step native mask misses.
	var half: Vector2 = bridge.body_size(body_index) * 0.5
	var witness := Vector2i(-1, -1)
	for y: int in range(floori(pose.origin.y-half.length()), ceili(pose.origin.y+half.length())):
		for x: int in range(floori(pose.origin.x-half.length()), ceili(pose.origin.x+half.length())):
			var local: Vector2 = pose.affine_inverse() * Vector2(x+0.5, y+0.5)
			if absf(local.x) < half.x-0.2 and absf(local.y) < half.y-0.2 \
				and int(world.rigid_body_id_at(x, y)) != expected_id:
				witness = Vector2i(x, y)
				break
		if witness.x >= 0: break
	expect(witness.x >= 0, "fixture observes a genuine old-mask/current-pose disagreement")
	if witness.x >= 0:
		var probe := EffectProbe.new()
		probe.native = world
		probe.point = witness
		runtime._world = probe
		expect(runtime.select_usable(Usables.index_for(&"water_lance")), "actual material Water Lance selected")
		expect(runtime.submit_action({"move": Vector2.ZERO, "tool": true, "aim": Vector2.RIGHT}),
			"real material field/tool command admitted")
		var before_tick: int = int(world.get_tick_index())
		var before_steps: int = bridge.manual_step_count()
		runtime.step()
		expect(probe.field_masks.size() == 5, "all five real native material-field entries observed")
		for observed_id: int in probe.field_masks:
			expect(observed_id == expected_id, "material field sees the actual moving prop mask before writing")
		expect(not probe.tool_masks.is_empty(), "real usable processing entry observed")
		for observed_id: int in probe.tool_masks:
			expect(observed_id == expected_id, "material tool sees the actual moving prop mask before writing")
		expect(runtime._material_usables.write_count_last > 0, "the selected real tool performed native material writes")
		expect(not runtime.failed and int(world.get_tick_index()) == before_tick + 1 \
			and bridge.manual_step_count() == before_steps + 1,
			"mask refresh adds no extra native tick or Rapier step")
		runtime._world = world
	runtime.close()
	runtime.free()
	await process_frame
