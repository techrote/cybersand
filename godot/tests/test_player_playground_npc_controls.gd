extends SceneTree

const Course = preload("res://scripts/player_playground_course.gd")
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Playground = preload("res://player_playground.tscn")
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYGROUND_NPC_CONTROLS: " + message)


func stored_water(world: Object) -> int:
	return int(world.diagnostic_snapshot(Vector2i.ZERO, Vector2i(512, 768)).water_mass) \
		+ int(world.diagnostic_snapshot(Vector2i(512, 0), Vector2i(512, 768)).water_mass)


func run() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	for player: StringName in Course.PRESETS:
		expect(runtime.configure(player, &"mixed", 0, true), "initial NPC and props with " + str(player) + ": " + runtime.last_error)
		if not runtime.active(): continue
		var world: Object = runtime._arena._world
		var roster: Dictionary = runtime.npc_readback()
		var count: int = 1 if Course.is_swarm(player) else 2
		expect(roster.actors.size() == count and roster.props.size() == 3, "one demo NPC and three real props")
		expect(runtime.authoring_revision > 0, "NPC cohort starts practice lap")
		expect(runtime.observation().representation == ("native-material-field" if Course.is_swarm(player) else "articulated-rapier"), "NPC never takes player input identity")
		var construction: Dictionary = runtime.liquid_readback().receipt
		expect(int(construction.initial_body_count) == runtime.render_parts().size(), "immutable initial receipt includes player, NPC and props")
		runtime.set_paused(true)
		expect(runtime.paint(Vector2i(212, 250), 2, 3).changed == 13, "paint before spawn")
		var cells_before: PackedByteArray = world.get_cells()
		var mass_before: int = stored_water(world)
		var position_before: Vector2 = runtime.observation().position
		var epoch_before: int = runtime.epoch
		var clocks: int = runtime._arena.session.bridge.manual_step_count()
		var added: Dictionary = runtime.spawn_npc(&"runner", Course.Districts.npc_spawns(&"mixed")[1])
		expect(added.accepted, "live append while paused: " + str(added))
		expect(runtime._arena._world == world and runtime.tick == 0 and runtime.epoch == epoch_before, "append preserves world, clock and player epoch")
		expect(runtime.observation().position == position_before and world.material_at(212, 250) == 3, "append preserves player and painted cells")
		expect(runtime.liquid_readback().receipt == construction and runtime._arena.session.bridge.manual_step_count() == clocks, "spawn neither rewrites construction receipt nor advances Rapier")
		# Full physical identity includes the deliberately changed body mask.
		expect(world.get_cells() == cells_before and stored_water(world) == mass_before,
			"body-mask publication preserves all material IDs and exact Water quantity")
		var refused: Dictionary = runtime.spawn_npc(&"runner", Vector2(NAN, 0))
		expect(not refused.accepted and runtime.npc_readback().actors.size() == count + 1, "invalid spawn preserves roster")
		runtime.set_paused(false)
		var anchor: Vector2 = runtime.observation().position
		for step: int in range(24):
			expect(runtime.submit_action({"move": Vector2.ZERO}), "neutral player input remains valid")
			runtime.step()
		expect(not runtime.failed and runtime.tick == 24 and int(world.get_tick_index()) == 24, "all participants share one native tick")
		expect(runtime._arena.session.bridge.manual_step_count() == clocks + 24, "all participants share one Rapier step")
		if Course.is_swarm(player): expect(runtime.observation().position == anchor, "neutral swarm anchor never follows idle centroid")
		runtime.close()
	await process_frame
	runtime.free()
	await test_ui()
	await process_frame
	print("PLAYGROUND_NPC_CONTROLS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)


func test_ui() -> void:
	root.size = Vector2i(1280, 720)
	var scene = Playground.instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	expect(scene._npc_picker.item_count == 3, "real NPC model selector")
	scene._include_npcs.button_pressed = true
	expect(scene.runtime.include_npcs and scene.runtime.npc_readback().actors.size() == 2, "actual include toggle reconstructs cohort")
	scene._toggle_pause()
	var world: Object = scene.runtime._arena._world
	var stages: PackedVector2Array = Course.Districts.npc_spawns(scene.runtime.map_id)
	scene._npc_paint.button_pressed = true
	expect(not scene._can_control() and not scene._paint_toggle.button_pressed, "placement mode cancels movement and excludes material brush")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = scene._content_rect().position + (stages[1] - Vector2(scene._view.position)) / Vector2(scene._view.size) * scene._content_rect().size
	scene._canvas_input(event)
	expect(scene.runtime.npc_readback().actors.size() == 3 and scene.runtime.tick == 0 and world == scene.runtime._arena._world, "actual canvas click spawns without reset or tick")
	expect(scene._npc_status.text.contains("NPC added") and scene._timing.text.contains("PRACTICE"), "visible admission feedback and practice timing")
	scene._paint_toggle.button_pressed = true
	expect(not scene._npc_paint.button_pressed, "material brush excludes NPC placement")
	scene._restart()
	expect(scene.runtime.include_npcs and scene.runtime.npc_readback().actors.size() == 2, "restart restores only the requested initial cohort")
	expect(scene.select_preset(2) and scene._controls.text.contains("CTRL") and not scene._controls.text.contains("\nC "), "real Afterimage help uses Ctrl")
	expect(scene.select_preset(5) and scene.runtime.observation().representation == "native-material-field" and scene.runtime.npc_readback().actors.size() == 1, "real material-player UI retains NPC host")
	scene.runtime.close()
	scene.free()
