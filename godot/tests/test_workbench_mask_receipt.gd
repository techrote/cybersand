extends SceneTree

# CAMERA-STACK-RECON-001. Receipt-only extraction of #593 production coverage
# (9628729a), with no live-pose selector, clearance oracle or camera repair.
# Receipts, material bytes and the Kestrel RID come from the real native World.
const Setup = preload("res://scripts/workbench_setup.gd")
const LIMIT_MS: int = 90000
var checks: int = 0
var failures: Array[String] = []
var host: Control


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WORKBENCH_MASK_RECEIPT: " + label)
	return ok


func until(ready: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + LIMIT_MS
	while Time.get_ticks_msec() < deadline:
		if ready.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false


func assert_hidden(frame: Dictionary, label: String) -> void:
	host._present_physical_actor_overlay(frame)
	check(host.physical_actor_overlay._parts.is_empty(), label)


func _run() -> void:
	set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	var ui: Control = host.shared_workbench
	if check(await until(func() -> bool: return ui != null and not ui.applied.is_empty()),
			"actual native Workbench installed"):
		var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy), Vector2i(512,512))
		setup.actors = [Setup.instance("kestrel", 1, Vector2(240,360))]
		setup.next_id = 2
		setup.selected = 1
		setup.edits.append([260,345,5,1,58])
		var old_epoch: int = host._physical_epoch
		var installed: bool = check(ui.apply(setup), "authored native World and physical actor requested")
		if installed:
			installed = check(await until(func() -> bool:
				return host.pending_microscenario_apply.is_empty() and host._physical_epoch > old_epoch \
					and host.physical_actor_session != null and host._physical_terrain_ready \
					and host.image != null and host.image.get_pixel(260,345).r8 == 58 \
					and host._valid_workbench_mask_frame(host.workbench_display_frame())),
				"native Wall material and source-matched actor receipt uploaded")
		if installed:
			host.set_process(false)
			host.set_physics_process(false)
			var bridge = host.physical_actor_session.bridge
			var source: Dictionary = host.workbench_display_frame().duplicate(true)
			var bound: Transform2D = source.instances[1].pose
			var pixels: PackedByteArray = host.image.get_data()
			var tick: int = host.physical_actor_session.tick
			var live: Transform2D = Transform2D(bound.get_rotation(), bound.origin + Vector2(0,1))
			bridge.reset_body(0, live.origin, live.get_rotation())
			check(bridge.body_transform(0).origin.distance_to(live.origin) < 0.001,
				"actual Rapier RID/cache differs from uploaded bound pose")
			host._present_physical_actor_overlay(source)
			var parts: Array = host.physical_actor_overlay._parts
			check(not parts.is_empty() and parts[0].transform.origin.distance_to(bound.origin) < 0.001,
				"valid receipt draws bound pose despite a newer live RID")
			check(host.physical_actor_session.render_parts().size() > 0,
				"receipt-free geometry inspection API remains available")
			var legacy: Array = host.physical_actor_session.render_parts({})
			check(not legacy.is_empty() and legacy[0].transform.origin.distance_to(live.origin) < 0.001,
				"negative control: non-strict historical API really falls back to live RID")
			assert_hidden({}, "missing receipt cannot leak unchecked live pose")
			for key: String in ["session", "epoch", "world_generation", "revision"]:
				var invalid: Dictionary = source.duplicate(true)
				invalid[key] = int(invalid[key]) + 1
				check(not host._valid_workbench_mask_frame(invalid), key + " mismatch is rejected")
				assert_hidden(invalid, key + " mismatch hides final overlay")
			var invalid: Dictionary = source.duplicate(true)
			invalid.erase("instances")
			assert_hidden(invalid, "missing actor receipts hide final overlay")
			invalid = source.duplicate(true)
			invalid.instances[1].generation = int(invalid.instances[1].generation) + 1
			assert_hidden(invalid, "stale actor generation hides final overlay")
			invalid = source.duplicate(true)
			invalid.instances[1].erase("pose")
			assert_hidden(invalid, "missing actor pose hides final overlay")
			invalid = source.duplicate(true)
			invalid.instances[1].pose = Transform2D(0.0, Vector2(INF,0))
			assert_hidden(invalid, "nonfinite actor pose hides final overlay")
			host._present_physical_actor_overlay(source)
			check(not host.physical_actor_overlay._parts.is_empty(), "valid receipt restores actor overlay")
			check(host.image.get_data() == pixels, "receipt checks preserve uploaded native material bytes")
			check(host.physical_actor_session.tick == tick, "receipt checks do not advance physical simulation")
			bridge.reset_body(0, bound.origin, bound.get_rotation())
			# Replace through the real World/actor owner. Old receipts must remain
			# invalid even when the new setup has identical authored coordinates.
			host.set_process(true)
			old_epoch = host._physical_epoch
			if check(ui.apply(setup), "real replacement requested for stale-session control"):
				if check(await until(func() -> bool:
					return host.pending_microscenario_apply.is_empty() and host._physical_epoch > old_epoch \
						and host.physical_actor_session != null and host._physical_terrain_ready \
						and host._valid_workbench_mask_frame(host.workbench_display_frame())),
						"replacement installs a new native/physical identity"):
					host.set_process(false)
					assert_hidden(source, "old receipt remains hidden after actual World replacement")
					host._present_physical_actor_overlay(host.workbench_display_frame())
					check(not host.physical_actor_overlay._parts.is_empty(), "new source-matched receipt draws actor")
	host.queue_free()
	await process_frame
	await process_frame
	print("WORKBENCH_MASK_RECEIPT_RESULT ", JSON.stringify({
		"schema":"workbench-mask-receipt-v1", "checks":checks, "failures":failures,
		"platform":OS.get_name(), "source":"actual native World and actual Rapier RID; receipt-only admission"}))
	quit(int(not failures.is_empty()))
