extends RefCounted

# Evaluation-only first-start preparation. Apply, Load, Save, pilot selection
# and Play use ordinary Workbench APIs; this helper never steps Rapier/native,
# alters a callback, substitutes a World, or admits a body sample itself.
const Reference = preload("res://scripts/engine_lab_reference_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Profile = preload("res://tests/pubpres_playability_profile.gd")
const SAVE_NAME := "pubpres003-wave2048"
const SCENARIO := "wave2048_gameplay_follow"
const WAIT_MSEC := 240000


static func _ready(app: Control, epoch: int) -> bool:
	return app.pending_microscenario_apply.is_empty() and app._physical_epoch > epoch \
		and app.physical_actor_session != null and app._physical_terrain_ready \
		and app.latest_snapshot != null and app.last_uploaded_world_generation == app.latest_snapshot.render_world_generation \
		and app.rapier_bridge.pending_hard_surface_chunks() == 0


static func _wait(tree: SceneTree, app: Control, predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + WAIT_MSEC
	while not predicate.call():
		if Time.get_ticks_msec() > deadline or app.simulation_worker.has_failed(): return false
		await tree.process_frame
	return true


static func prepare(tree: SceneTree, app: Control, reopen: bool) -> Dictionary:
	var ui: Control = app.shared_workbench
	if not app.paused and not ui.toggle_pause(): return {"error":"Could not pause the ordinary initial World"}
	if not ClassDB.class_has_method(&"CyberNativeCellWorld", &"gameplay_water_options"):
		return {"error":"Exact native current-gameplay Water profile is unavailable"}
	var options: Dictionary = ClassDB.class_call_static(&"CyberNativeCellWorld", &"gameplay_water_options")
	if options != Profile.GAMEPLAY_OPTIONS:
		return {"error":"Native gameplay defaults differ from the explicit matched Wave profile"}
	app.workbench_water_options.clear()
	app.workbench_water_options.merge(options, true)
	ui._name.text = SAVE_NAME
	var saved_path := Setup._path(SAVE_NAME)
	var epoch: int = app._physical_epoch
	var saved_before := FileAccess.get_sha256(saved_path) if FileAccess.file_exists(saved_path) else ""
	if reopen:
		if saved_before.is_empty(): return {"error":"Saved owner start is missing; refusing to replace it with the initial fixture"}
		if not ui.load_setup(): return {"error":"Ordinary Load start refused: " + ui.message}
		var dialog: Window = ui._generated_dialog
		if not await _wait(tree, app, func() -> bool: return _ready(app, epoch) or dialog._phase in ["ready", "failed"]):
			return {"error":"Saved-start reconstruction did not complete"}
		if dialog._phase == "failed": return {"error":"Saved native generation was refused"}
		if dialog._phase == "ready":
			dialog.confirmed.emit()
			dialog.hide()
	else:
		if not saved_before.is_empty(): return {"error":"Fresh owner preparation refuses to overwrite an existing saved start"}
		var reference := Reference.new()
		var generated: Dictionary = await reference.materialize(tree)
		if not generated.get("ok", false): return {"error":"Exact native Wave2048 fixture refused: " + str(generated.get("error", ""))}
		var setup: Dictionary = generated.setup.duplicate(true)
		var api: Variant = ui._liquids.bridge
		var carrier: PackedInt32Array = api.default_liquid_policy()
		var matched := false
		for row: Dictionary in api.liquid_policy_assignment_choices(carrier, 3):
			if row.get("family", "") == "freemass_v1" and row.get("variant", "") == "reference" and row.get("accepted", false):
				carrier = row.request
				matched = true
				break
		if not matched: return {"error":"Required native Water carrier is unavailable"}
		setup.liquid_policy = Array(carrier)
		setup.rule_radius = 2
		if not ui.apply(setup, false, 0, false, false, generated.packet):
			return {"error":"Ordinary Apply refused the exact native fixture: " + ui.message}
	if not await _wait(tree, app, func() -> bool: return _ready(app, epoch)):
		return {"error":"Source-matched native World, terrain and actor did not become ready"}
	if Setup.extent_of(ui.applied) != Vector2i(2048,2048) or ui.applied.actors.is_empty():
		return {"error":"Saved comparison start must retain a real 2048-square World and actors"}
	if ui.pilot_id() == 0:
		if not ui.pilot_instance(int(ui.applied.actors[0].id)):
			return {"error":"Ordinary human pilot selection was refused"}
		if not await _wait(tree, app, func() -> bool: return app.pending_microscenario_apply.is_empty() and app._physical_terrain_ready):
			return {"error":"Pilot change did not complete"}
	ui._camera.select(1)
	ui.set_camera(1)
	var state: Dictionary = ui.body_state(ui.pilot_id())
	if state.is_empty(): return {"error":"Actual selected native-backed actor state is unavailable"}
	ui._set_view(Vector2(state.position)-Vector2(240,135), Vector2i(480,270))
	await tree.process_frame
	await tree.process_frame
	var wave: Dictionary = app.tower_context.get("wave_flow", {})
	if not wave.get("enabled", false) or int(wave.get("substeps", -1)) != 2 \
		or not wave.get("spill", {}).get("enabled", false) or not wave.get("spill", {}).get("parcels", false) \
		or not wave.get("construction_options", {}).get("workbench_ballistic", false):
		return {"error":"Actual current-gameplay Wave rounds, spill or ballistic transport differ"}
	if not reopen and not ui.save_setup(): return {"error":"Ordinary initial Save start was refused: " + ui.message}
	if reopen and FileAccess.get_sha256(saved_path) != saved_before:
		return {"error":"Reopening unexpectedly changed the saved authored start"}
	var native_start: int = app.latest_snapshot.tick_index
	var physical_start: int = app.physical_actor_session.tick
	var started_usec := Time.get_ticks_usec()
	if app.paused and not ui.toggle_pause(): return {"error":"Ordinary Play was refused"}
	if not await _wait(tree, app, func() -> bool: return app.physical_actor_session.tick >= physical_start+4 \
		and app.latest_snapshot.tick_index >= native_start+4):
		return {"error":"The active World did not execute four real native and physical steps"}
	var spray: Dictionary = app.latest_snapshot.lab_context.get("water_spray", {})
	var water: Dictionary = spray.get("water", {})
	if not spray.get("healthy", false) or water.is_empty() or int(water.get("total", -1)) != int(water.get("expected", -2)) \
		or int(water.get("visible", -1))+int(water.get("overfill", -1))+int(water.get("ballistic", -1)) != int(water.get("total", -2)):
		return {"error":"Native grid/overfill/ballistic Water ledger is not healthy"}
	return {"name":SCENARIO, "phase":"reopen" if reopen else "initialize", "save_name":SAVE_NAME,
		"saved_setup_sha256":FileAccess.get_sha256(saved_path), "saved_before_sha256":saved_before,
		"fixture_json_sha256":Reference.FILE_SHA256, "initial_generated_sha256":Reference.OUTPUT_SHA256,
		"authored_setup_sha256":JSON.stringify(ui.applied).sha256_text(),
		"worker_request":4, "worker_capacity":app.latest_snapshot.scheduler_thread_capacity_hint,
		"water_profile":"gameplay_main846f", "native_gameplay_options":options,
		"actual_wave_substeps":int(wave.substeps), "actual_spill":wave.spill,
		"actual_ballistic":wave.construction_options.workbench_ballistic,
		"water_ledger":water, "water_ledger_healthy":true, "camera":"follow", "pilot_id":ui.pilot_id(),
		"native_tick_before":native_start, "native_tick_ready":app.latest_snapshot.tick_index,
		"physical_tick_before":physical_start, "physical_tick_ready":app.physical_actor_session.tick,
		"startup_progress_usec":Time.get_ticks_usec()-started_usec,
		"scope":"Real ordinary Apply/Load/Save/Play and four completed startup steps. No steady-state performance or physical NVIDIA acceptance."}
