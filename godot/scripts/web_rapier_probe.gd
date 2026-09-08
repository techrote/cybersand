class_name CyberWebRapierProbe
extends RefCounted

# Opt-in acceptance fixture, shared by native headless and actual Web runtime.
# Owns the demo only while testing; never enabled on a normal play URL.
static func run(host: Node) -> Dictionary:
	var failures: Array[String] = []
	if not host.rapier_available:
		return {"ok": false, "failures": [host.rapier_reason]}
	host.set_physics_process(false)
	host.set_process(false)
	host.select_demo("physics_pit")
	host.focused = true
	host.input_armed = false
	# Complete the bounded collider queue before advancing either solver.
	for i: int in range(256):
		host._sync_web_colliders()
		if host.rapier_bridge.pending_hard_surface_chunks() == 0:
			break
	if host.rapier_bridge.pending_hard_surface_chunks() != 0:
		failures.append("Collider queue did not drain")
	var contacts: int = 0
	var displaced: int = 0
	var maximum_floor_y: float = 0.0
	for tick: int in range(600):
		host._physics_process(1.0 / 60.0)
		maximum_floor_y = maxf(maximum_floor_y, host.rapier_bridge.body_transform(0).origin.y)
		contacts += int(host.native_world.get_rigid_body_contacts_last_tick())
		displaced += int(host.native_world.get_rigid_body_displaced_last_tick())
		if tick % 20 == 0:
			await host.get_tree().process_frame
	var bodies: Array = host._metadata().bodies
	if int(host.native_world.get_tick_index()) != 600 or host.rapier_bridge.manual_step_count() != 600:
		failures.append("Cellular/Rapier step ownership mismatch")
	# Centre rests at 159; permit up to 2px transient solver penetration,
	# but never passage through the floor at y=166.
	if absf(bodies[0][1] - 159.0) > 0.1 or maximum_floor_y > 161.0:
		failures.append("One-pixel floor did not hold body")
	if bodies[1][1] <= 100.0 or bodies[2][1] <= 100.0:
		failures.append("Water/Sand bodies did not fall")
	if contacts <= 0 or displaced <= 0:
		failures.append("No two-way cellular contact/displacement")
	host.paused = true
	var before: Dictionary = host._metadata()
	host._physics_process(1.0 / 60.0)
	if host._metadata() != before or int(host.native_world.get_tick_index()) != 600:
		failures.append("Pause advanced simulation")
	host.paused = false
	host.ui.show_page("home")
	host._physics_process(1.0 / 60.0)
	if host._metadata() != before or host.rapier_bridge.manual_step_count() != 600:
		failures.append("Menu advanced Rapier")
	var encoded: Dictionary = host._encode_current()
	if not encoded.ok:
		failures.append("Physics save encode failed")
	else:
		host.select_demo("neon_works", false)
		if host.rapier_bridge.is_initialized() or not host.rigid_bodies.is_empty():
			failures.append("Demo switch retained physics")
		host.import_save(encoded.text)
		var restored: Dictionary = host._encode_current()
		if not restored.ok:
			failures.append("Restored physics level cannot be encoded")
		else:
			var original_save: Dictionary = CyberDemoSaveCodec.decode_text(encoded.text)
			var restored_save: Dictionary = CyberDemoSaveCodec.decode_text(restored.text)
			if original_save.world != restored_save.world:
				failures.append("Cellular payload did not round-trip exactly")
			# Rapier reconstructs a rotation matrix from the saved angle;
			# float32 atan2/sin/cos round-off is not an exact replay state.
			for i: int in range(3):
				for component: int in range(6):
					if absf(original_save.metadata.bodies[i][component] - restored_save.metadata.bodies[i][component]) > 0.00001:
						failures.append("Body state restore exceeded float32 tolerance")
				if original_save.metadata.bodies[i][6] != restored_save.metadata.bodies[i][6]:
					failures.append("Body sleep state changed on restore")
	host.select_demo("physics_pit", false)
	for i: int in range(3):
		if host.rapier_bridge.body_transform(i).origin != Vector2([124, 244, 384][i], 90):
			failures.append("Reset did not restore spawn")
	if int(host.native_world.get_tick_index()) != 0:
		failures.append("Reset did not reset cellular tick")
	var result: Dictionary = {"ok": failures.is_empty(), "failures": failures, "ticks": 600,
		"workers": int(host.native_world.get_worker_threads()), "bodies": bodies,
		"maximum_floor_y": maximum_floor_y, "contacts": contacts, "displaced": displaced}
	host.select_demo("neon_works", false)
	host.ui.show_page("home")
	host.set_process(true)
	host.set_physics_process(true)
	return result
