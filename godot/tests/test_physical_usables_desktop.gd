extends SceneTree

# Production desktop, actual asynchronous native owner and actual Rapier body
# owner. The harness supplies window focus and a fixed human aiming direction;
# equipment commands, receipt admission, reset and physics remain production.
const Catalog = preload("res://scripts/usable_catalog.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
var desktop: Control
var assertions: int = 0
var failures: int = 0


class DesktopHarness:
	extends "res://scripts/main.gd"
	var controls_allowed: bool = true
	func actor_keyboard_allowed() -> bool:
		return controls_allowed and not paused and _physical_terrain_ready \
			and _actor_reset_receipt == 0 and not actor_prototype_panel.visible
	func actor_pointer_aim() -> Vector2:
		return Vector2.RIGHT


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_USABLE_DESKTOP: " + message)


func wait_for(predicate: Callable, timeout_ms: int = 15000) -> bool:
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


func run() -> void:
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopHarness)
	root.add_child(desktop)
	await process_frame
	expect(desktop.apply_actor_prototype_configuration(&"rapier/runner", &"human", false),
		"F5 creates a human articulated actor")
	desktop.paused = false
	var installed: bool = await wait_for(func() -> bool:
		return desktop.physical_actor_session != null and desktop._actor_reset_receipt == 0 \
			and desktop._physical_terrain_ready and desktop.physical_actor_session.tick >= 3)
	expect(installed, "native reset and current terrain allow physical advancement")
	if not installed:
		desktop.free()
		quit(1)
		return
	expect(desktop.latest_snapshot.actor_prototypes.is_empty(), "physical path has no sampled actor owner")
	expect(desktop.actor_prototype_panel.usable_choice.item_count == 33,
		"same F5 picker exposes all 32 choices and None")
	var old_view: Dictionary = desktop.physical_actor_observation()
	var old_item: Dictionary = old_view.equipment.duplicate(true)
	var old_body: RigidBody2D = desktop.rigid_bodies[int(old_item.body_id) - 1]
	var body_instance: int = old_body.get_instance_id()
	var timer: int = Catalog.index_for(&"timer_airburst")
	expect(desktop.apply_actor_equipment_configuration(timer, 0.75), "F5 retools the held physical body")
	expect(await wait_for(func() -> bool:
		return not desktop._actor_usable_transition_pending and int(equipment().get("usable_index", -1)) == timer),
		"F5 selection is acknowledged by the physical session")
	expect(old_body.get_instance_id() == body_instance and equipment().instance_id == old_item.instance_id,
		"equip-only preserves the real body and stable item identity")
	expect(int(equipment().equipment_epoch) > int(old_item.equipment_epoch),
		"retooling changes equipment incarnation")
	expect(not desktop.physical_actor_session.submit(Session.make_command(old_view,
		int(old_view.last_sequence) + 1000, {"equipment": {"trigger": true}}, 18), &"human"),
		"pre-retool observation cannot operate the new incarnation")
	expect(not desktop.apply_actor_equipment_configuration(timer, NAN), "F5 refuses non-finite power")
	await create_timer(0.08).timeout
	key(true)
	var fired: bool = await wait_for(func() -> bool:
		return int(equipment().get("accepted_uses", 0)) > 0)
	key(false)
	expect(fired, "human M input commits a real worker-owned payload: " + str(equipment().get("last_receipt", {})))
	var snapshot: Dictionary = desktop.latest_snapshot.physical_usables
	var retained: Dictionary = snapshot.duplicate(true)
	expect(snapshot.get("physical", false) and snapshot.get("run_id", "") == old_view.run_id,
		"asynchronous native snapshot identifies the physical run")
	expect(snapshot.actors.size() == 1 and int(snapshot.actors[0].body_id) == int(old_item.body_id),
		"native receipt state is attached to the real coupling body")
	desktop.paused = true
	expect(await wait_for(func() -> bool: return desktop.latest_snapshot.paused), "desktop pause reaches exclusive native owner")
	var paused: Dictionary = desktop.latest_snapshot.physical_usables
	var ages: Array = []
	for projectile: Dictionary in paused.get("projectiles", []):
		ages.append(float(projectile.age))
	expect(not ages.is_empty(), "pause retains committed autonomous payload")
	await create_timer(0.10).timeout
	var later: Dictionary = desktop.latest_snapshot.physical_usables
	var later_ages: Array = []
	for projectile: Dictionary in later.get("projectiles", []):
		later_ages.append(float(projectile.age))
	expect(ages == later_ages, "pause freezes committed projectile age")
	expect(snapshot == retained, "later owner publications do not mutate retained snapshot")
	var accepted_before: int = int(equipment().accepted_uses)
	key(true)
	desktop.paused = false
	await create_timer(0.15).timeout
	expect(int(equipment().accepted_uses) == accepted_before,
		"a key held across pause cannot replay an equipment edge")
	key(false)
	await create_timer(0.06).timeout
	desktop.controls_allowed = false
	key(true)
	await create_timer(0.06).timeout
	desktop.controls_allowed = true
	await create_timer(0.10).timeout
	expect(int(equipment().accepted_uses) == accepted_before,
		"focus return also requires a neutral rearm boundary")
	key(false)
	await create_timer(0.06).timeout
	expect(desktop.apply_actor_equipment_configuration(-1, 0.75), "F5 can select None")
	expect(await wait_for(func() -> bool:
		return not desktop._actor_usable_transition_pending and int(equipment().get("usable_index", 99)) == -1),
		"None transition completes without replacing the assembly")
	expect(not desktop.actor_equipment_active(), "None releases the pointer equipment mode")
	expect(desktop.apply_actor_equipment_configuration(timer, 0.75), "None can re-equip the held chassis")
	expect(await wait_for(func() -> bool: return not desktop._actor_usable_transition_pending), "re-equip finishes")
	var old_epoch: int = desktop._physical_epoch
	var old_run: String = str(desktop.physical_actor_observation().run_id)
	desktop.reset_world()
	expect(await wait_for(func() -> bool:
		return desktop._actor_reset_receipt == 0 and desktop.physical_actor_session != null \
			and desktop._physical_terrain_ready and desktop.latest_snapshot.physical_usables.get("run_id", "") != old_run),
		"R replaces physical and native equipment owners")
	expect(desktop._physical_epoch > old_epoch and equipment().instance_id != old_item.instance_id,
		"reset fences the old world and equipment identity")
	expect(desktop.latest_snapshot.physical_usables.get("projectiles", []).is_empty(),
		"reset retires committed projectiles")
	var before_feedback: Dictionary = equipment()
	desktop.physical_actor_session.accept_equipment_feedback(retained)
	expect(equipment() == before_feedback, "late pre-reset snapshot has no effect on new equipment")
	key(false)
	desktop.free()
	await process_frame
	print("PHYSICAL_USABLE_DESKTOP_RESULT assertions=", assertions, " failures=", failures)
	quit(1 if failures else 0)
