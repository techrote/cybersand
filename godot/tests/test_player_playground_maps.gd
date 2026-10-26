extends SceneTree

const Course = preload("res://scripts/player_playground_course.gd")
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Setup = preload("res://scripts/player_playground_world.gd")
const Playground = preload("res://player_playground.tscn")
var assertions: int = 0
var failures: int = 0
var runtime


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYER_MAPS: " + message)


func world() -> Object:
	return runtime._world if runtime._world != null else runtime._arena._world


func water_assignment(policy: Dictionary) -> Dictionary:
	for row: Dictionary in policy.assignments:
		if int(row.material) == 3: return row
	return {}


func run() -> void:
	runtime = Runtime.new()
	root.add_child(runtime)
	var layouts: Dictionary = {}
	for map_id: StringName in Course.MAP_IDS:
		var extent: Rect2i=Course.map_view(map_id)
		expect(extent.get_area() >= 4*Course.VIEW.get_area(), "every playable map has at least quadruple area")
		var materials: Dictionary={}
		for item: Dictionary in Course.layout(map_id): materials[item.material]=true
		expect(materials.size()>=15 and Course.layout(map_id).size()>=100,"district has varied materials and complex authored structures")
		var signature: String = str(Course.layout(map_id)).sha256_text()
		expect(not layouts.has(signature), "map has independent native geometry: " + str(map_id))
		layouts[signature] = true
		for player: StringName in Course.PRESETS:
			for solver: int in range(Setup.WATER_NAMES.size()):
				var label: String = "%s/%s/%d" % [map_id, player, solver]
				var accepted: bool = runtime.configure(player, map_id, solver)
				expect(accepted, "map/player/solver configures " + label + ": " + runtime.last_error)
				if not accepted: continue
				var readback: Dictionary = runtime.liquid_readback()
				var water: Dictionary = water_assignment(readback.policy)
				expect(water.applied_family == Setup.FAMILIES[solver]
					and water.applied_variant == Setup.VARIANTS[solver], "actual native Water assignment " + label + str(water))
				expect(int(readback.policy.maximum_rule_radius) == (3 if solver == 5 else 2), "explicit geometry " + label)
				expect(not readback.receipt.is_empty() and readback.receipt.completed_tick == 0,
					"actual native construction receipt " + label)
				var body_count: int = runtime.render_parts().size()
				expect(int(readback.receipt.initial_body_count) == body_count, "receipt covers actual initial bodies " + label)
				for target: Vector2 in Course.checkpoints(player, map_id):
					expect(extent.has_point(Vector2i(target)) and world().material_at(int(target.x), int(target.y)) == 0,
						"gate centre is inside map and free of terrain " + label)
				# Activate Water in every setup, including maps authored without it.
				expect(runtime.paint(Vector2i(212, 250), 3, 3).changed > 0, "bounded whole-cell Water spawn " + label)
				for tick: int in range(3):
					expect(runtime.submit_action({"move": Vector2.RIGHT}), "fresh movement admitted " + label)
					runtime.step()
				expect(not runtime.failed and runtime.tick == 3 and Vector2(runtime.snapshot().actor.position).is_finite(),
					"actual native/player ticks stay healthy " + label)
		print("PLAYER_MAPS completed map: ", map_id)
	test_authoring()
	runtime.close()
	runtime.free()
	await test_ui()
	await process_frame
	print("PLAYER_MAPS: %d assertions, %d failures; 8 maps x 7 players x 6 Water choices" % [assertions, failures])
	quit(0 if failures == 0 else 1)


func test_authoring() -> void:
	for player: StringName in [&"acrobat", &"liquidswarm"]:
		expect(runtime.configure(player, &"undertow_lab", 5), "authoring fixture configures")
		runtime.set_paused(true)
		var before: String = world().get_physical_state_hash()
		for invalid: Array in [[Vector2i(2, 200), 4, 3], [Vector2i(212, 250), 13, 3], [Vector2i(212, 250), 4, 255]]:
			expect(not runtime.paint(invalid[0], invalid[1], invalid[2]).accepted, "invalid paint refuses")
		expect(world().get_physical_state_hash() == before and runtime.authoring_revision == 0, "refused paint preserves exact World")
		var count: int = runtime.paint(Vector2i(212, 250), 4, 3).changed
		expect(count == 49 and runtime.tick == 0, "paused disc paints exactly its 49 cells without advancing")
		expect(runtime.paint(Vector2i(212, 250), 4, 2).changed == 0, "default spawn preserves occupied material")
		expect(runtime.paint(Vector2i(212, 250), 4, 2, true).changed == 49, "explicit replace changes occupied cells")
		expect(runtime.paint(Vector2i(212, 250), 4, 0).changed == 49, "erase removes exactly authored disc")
		var position: Vector2 = runtime.snapshot().actor.position
		if player == &"acrobat":
			runtime.paint(Vector2i(position), 12, 1, true)
			for part: Dictionary in runtime.render_parts():
				var point := Vector2i(Transform2D(part.transform).origin.floor())
				expect(world().inspect_inertial_cell(point).material == 0 and world().rigid_body_id_at(point.x, point.y) > 0,
					"painting protects every actual body centre")
		runtime.paint(Vector2i(8,8),12,0)
		expect(world().material_at(2,8)==1 and world().material_at(8,2)==1,"brush clips before boundary")
		var old_epoch: int = runtime.epoch
		var old_hash: String = world().get_physical_state_hash()
		expect(not runtime.configure(player, &"missing", 5) and runtime.epoch == old_epoch
			and world().get_physical_state_hash() == old_hash, "invalid replacement retains live owner")
		expect(runtime.configure(player, &"undertow_lab", 5) and runtime.authoring_revision == 0
			and world().material_at(212, 250) == 0 and runtime.water_solver == 5, "reset restores authored map and selected solver")


func test_ui() -> void:
	root.size = Vector2i(1280, 720)
	var scene = Playground.instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	expect(scene._map_picker.item_count == 8 and scene._water_picker.item_count == 6, "real scene exposes every map and Water choice")
	expect(scene.select_map(6) and scene.select_water(5) and scene.select_preset(4), "independent selectors admit cross-preset map and solver")
	expect(scene.runtime.map_id == &"undertow_lab" and scene.runtime.water_solver == 5, "player switch keeps accepted map and Water")
	expect(scene._water_readback.text.contains("inertial_cellular_v1"), "UI reads applied native identity")
	scene._toggle_pause()
	scene._material_picker.select(1)
	scene._spawn_material()
	expect(scene.runtime.authoring_revision > 0 and scene.runtime.tick == 0 and scene._timing.text.contains("PRACTICE"), "actual paused spawn marks practice lap")
	scene._paint_toggle.button_pressed = true
	expect(not scene._can_control(), "paint mode gates player input")
	var pointer: Vector2 = scene._content_rect().position + Vector2(0.4, 0.4) * scene._content_rect().size
	var painted_cell := Vector2i(Vector2(scene._view.position) + Vector2(0.4, 0.4) * Vector2(scene._view.size))
	scene._paint_at_view_position(pointer, false)
	expect(scene.runtime._world.material_at(painted_cell.x, painted_cell.y) == 3, "actual canvas coordinates paint native Water while paused")
	scene._paint_at_view_position(pointer, true)
	expect(scene.runtime._world.material_at(painted_cell.x, painted_cell.y) == 0, "actual canvas erase reaches same native cell")
	var revision: int = scene.runtime.authoring_revision
	scene._paint_at_view_position(Vector2(-10, -10), false)
	expect(scene.runtime.authoring_revision == revision, "outside canvas / letterbox paint cannot mutate world")
	scene._follow = true
	scene._present(scene.runtime.snapshot())
	pointer = scene._content_rect().position + Vector2(0.65, 0.45) * scene._content_rect().size
	painted_cell = Vector2i(Vector2(scene._view.position) + Vector2(0.65, 0.45) * Vector2(scene._view.size))
	scene._paint_at_view_position(pointer, false)
	expect(scene.runtime._world.material_at(painted_cell.x, painted_cell.y) == 3, "follow camera painting uses actual zoom origin and extent")
	scene._paint_toggle.button_pressed = false
	scene._restart()
	expect(scene.runtime.map_id == &"undertow_lab" and scene.runtime.water_solver == 5 and scene.runtime.authoring_revision == 0,
		"real restart retains map/solver and clears edits")
	var initial: int = scene.selected_map
	expect(not scene.select_map(99) and scene.selected_map == initial, "invalid picker selection retains state")
	scene.runtime.close()
	scene.free()
	await process_frame
