extends SceneTree

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

# F5 kinetic usables on the production desktop: the shared kinetic catalogue
# (kinetic_usables.gd) equipped on a real articulated actor and fired with M.
# Every shot must be a native ballistic cell or parcel, never painted cells.
const Catalog = preload("res://scripts/usable_catalog.gd")
var desktop: Control
var assertions: int = 0
var failures: int = 0
var evidence := {}


class DesktopHarness:
	extends "res://scripts/main.gd"
	func actor_keyboard_allowed() -> bool:
		return not paused and _physical_terrain_ready and _actor_reset_receipt == 0 and not actor_prototype_panel.visible
	func actor_pointer_aim() -> Vector2:
		return Vector2(1.0, -0.6).normalized()


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error("F5_KINETIC: " + message)
	return value


func wait_for(predicate: Callable, timeout_ms: int = -1) -> bool:
	if timeout_ms < 0:
		timeout_ms = Watchdogs.milliseconds("operation_seconds")
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call():
			return true
	return false


func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func equipment() -> Dictionary:
	return desktop.physical_actor_observation().get("equipment", {})


func fire(id: StringName) -> Dictionary:
	var index: int = Catalog.index_for(id)
	expect(desktop.apply_actor_equipment_configuration(index, 1.0), "F5 equips " + str(id))
	expect(await wait_for(func() -> bool:
		return not desktop._actor_usable_transition_pending and int(equipment().get("usable_index", -1)) == index),
		str(id) + " acknowledged")
	await create_timer(0.08).timeout
	var before: int = int(equipment().get("accepted_uses", 0))
	key(true)
	var fired: bool = await wait_for(func() -> bool: return int(equipment().get("accepted_uses", 0)) > before, 8000)
	key(false)
	await create_timer(0.1).timeout
	var row := {"fired": fired, "receipt": equipment().get("last_receipt", {})}
	evidence[str(id)] = row
	return row


func run() -> void:
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopHarness)
	root.add_child(desktop)
	await process_frame
	expect(Catalog.KINETIC_IDS.size() == 13, "13 kinetic usables in the F5 catalogue")
	for id: StringName in Catalog.KINETIC_IDS:
		var definition: Dictionary = Catalog.entry(Catalog.index_for(id))
		expect(str(definition.operation) == "kinetic" and str(definition.kinetic) == str(id), "catalogue entry " + str(id))
	# The F5 panel pick is what Apply spawns the actor holding (not the rig default).
	var picked: int = Catalog.index_for(&"stone_slug")
	desktop.toggle_actor_prototypes()
	desktop.actor_prototype_panel.usable_choice.select(picked + 1)
	desktop.actor_prototype_panel.usable_choice.item_selected.emit(picked + 1)
	expect(desktop.apply_actor_prototype_configuration(&"rapier/runner", &"human", false), "F5 human actor")
	desktop.paused = false
	var installed: bool = await wait_for(func() -> bool:
		if desktop.pending_microscenario_apply.is_empty() and desktop._actor_reset_receipt == 0: desktop.paused = false
		return desktop.physical_actor_session != null and desktop._actor_reset_receipt == 0 \
			and desktop._physical_terrain_ready and desktop.physical_actor_session.tick >= 3)
	if expect(installed, "physical actor installed"):
		expect(int(equipment().get("usable_index", -1)) == picked, "Apply spawned the actor holding the panel pick: " + str(equipment().get("usable_index")))
		for id: StringName in [&"gravel_shotgun", &"water_cannon"]:
			var row: Dictionary = await fire(id)
			expect(row.fired and int(row.receipt.get("changed_cells",0)) > 0, "%s fired: %s" % [id, str(row.receipt)])
	print("F5_KINETIC_EVIDENCE " + JSON.stringify(evidence))
	print("F5_KINETIC %d assertions, %d failures" % [assertions, failures])
	desktop.queue_free()
	await process_frame
	quit(int(failures != 0))
