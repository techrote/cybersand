class_name CyberTickFailureProbe
extends RefCounted

# Shared real-adapter regression: Windows runner and opt-in browser fixture.
# Uses an explicit construction capacity, never a fabricated error return.
static func run(tree: SceneTree, controller: Variant = null) -> Dictionary:
	var failures: Array[String] = []
	var was_processing: bool = false
	var was_physics_processing: bool = false
	if controller != null:
		was_processing = controller.is_processing()
		was_physics_processing = controller.is_physics_processing()
		controller.set_process(false)
		controller.set_physics_process(false)
	var prior_capacity: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity", null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	var workers: int = 0
	for with_event: bool in [false, true]:
		var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		await tree.process_frame
		var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
		workers = int(world.get_worker_threads())
		world.set_simulation_window(Vector2i.ZERO, Vector2i(320, 180), 0, 0)
		_check(bridge.build_world(world, PackedInt32Array([20, 20, 1, 1, 2])), "construct", failures)
		await tree.process_frame
		_check(world.simulation_tick(), "normal tick", failures)
		var saved: PackedByteArray = bridge.export_level(world)
		world.paint_disc(20, 20, 0, 1)
		world.paint_disc(21, 20, 0, 1)
		world.paint_disc(160, 20, 0, 2)
		var valid_packet: Dictionary = world.take_render_snapshot(true)
		var retained: PackedByteArray = valid_packet.cells.duplicate()
		if with_event:
			_check(bridge.queue_explosion(world, 20, 20, 1), "accepted explosion", failures)
		var original_world: Variant = null
		var original_image: PackedByteArray = PackedByteArray()
		var original_player: Vector2 = Vector2.ZERO
		if controller != null:
			original_world = controller.native_world
			controller.native_world = world
			controller.camera_origin = Vector2.ZERO
			controller.paused = false
			controller.focused = true
			controller.input_armed = false
			controller.ui.close_menu()
			original_image = controller.image.get_data()
			original_player = controller.player.position
			controller._physics_process(1.0 / 60.0)
			_check(controller.paused and controller.ui.open, "Web owner did not stop/report", failures)
			_check(controller.player.position == original_player, "Web advanced player after failure", failures)
			controller._publish_world()
			controller._sync_web_colliders()
			_check(controller.image.get_data() == original_image, "Web published partial pixels", failures)
		else:
			_check(not world.simulation_tick(), "failure returned true", failures)
		_check(world.has_failed() and world.get_tick_index() == 1 and world.get_attempted_tick_index() == 2,
			"completed/attempted identities", failures)
		_check(world.get_tick_failure_count() == 1 and not str(world.get_last_tick_error()).is_empty(), "failure diagnostic", failures)
		_check(world.material_at(20, 20) == (6 if with_event else 1), "partial event evidence", failures)
		_check(not world.simulation_tick() and world.get_tick_failure_count() == 1 and world.get_attempted_tick_index() == 2,
			"latched failure retried", failures)
		world.paint_disc(20, 20, 0, 2)
		world.prepare_rigid_body_coupling(PackedFloat32Array(), true)
		_check(world.material_at(20, 20) == (6 if with_event else 1), "failed gameplay mutation", failures)
		_check(not bridge.queue_explosion(world, 20, 20, 1), "failed event accepted", failures)
		_check(world.rigid_body_results().is_empty(), "partial body result", failures)
		_check(world.take_render_snapshot(true).get("failed", false), "partial publication allowed", failures)
		_check(valid_packet.cells == retained, "retained publication mutated", failures)
		_check(bridge.export_level(world).is_empty(), "partial level exported as valid", failures)
		_check(not bridge.import_level(world, PackedByteArray()) and world.has_failed(), "invalid recovery revived world", failures)
		world.set_simulation_window(Vector2i(384, 0), Vector2i(64, 64), 0, 0)
		_check(not world.simulation_tick(), "region change revived failed world", failures)
		_check(bridge.import_level(world, saved) and not world.has_failed(), "validated replacement recovery", failures)
		await tree.process_frame
		world.set_simulation_window(Vector2i.ZERO, Vector2i(320, 180), 0, 0)
		_check(world.simulation_tick() and world.get_tick_index() == 1 and world.material_at(20, 20) == 0,
			"replacement replayed event or did not step", failures)
		_check(world.reset_demo_world() and not world.has_failed() and world.get_tick_index() == 0,
			"explicit reset", failures)
		await tree.process_frame
		if controller != null:
			controller.native_world = original_world
		world = null
		bridge = null
		# Browser pthread workers need the event loop to recycle after teardown.
		await tree.process_frame
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", prior_capacity)
	if controller != null:
		controller.set_process(was_processing)
		controller.set_physics_process(was_physics_processing)
	return {"ok": failures.is_empty(), "failures": failures, "workers": workers, "events": [false, true], "controller": controller != null}

static func _check(value: bool, label: String, failures: Array[String]) -> void:
	if not value:
		failures.append(label)
