extends SceneTree

const Presets = preload("res://scripts/object_shard_lab_presets.gd")
const Capture = preload("res://scripts/object_shard_capture.gd")
var checks: int = 0
var failures: int = 0
var scene
var retained: Dictionary = {}


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _idle(seconds: int = 30) -> bool:
	var deadline: int = Time.get_ticks_msec() + seconds * 1000
	await process_frame
	while Time.get_ticks_msec() < deadline:
		if scene.host.failed or scene.setup_failed:
			return false
		if not scene.loading and not scene.replacing_owner and scene.host.state == "Idle" and scene.host.actions.is_empty() and scene.queued_cuts.is_empty():
			return true
		await process_frame
	return false


func _step() -> bool:
	var tick: int = int(scene.host.completed_ticks)
	scene._single_step()
	var deadline: int = Time.get_ticks_msec() + 15000
	while scene.host.completed_ticks <= tick and not scene.host.failed and Time.get_ticks_msec() < deadline:
		await process_frame
	return await _idle()


func _pointer(position: Vector2i, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = scene.view.offset + (Vector2(position) + Vector2.ONE * 0.5) * scene.view.zoom
	event.button_index = button
	event.pressed = true
	scene.view._gui_input(event)
	event.pressed = false
	scene.view._gui_input(event)


func _world_material(position: Vector2i) -> int:
	return int(scene.host.publication.world_materials[position.y * int(scene.host.publication.width) + position.x])


func _owned_point(source: Dictionary = {}, same_owner_in: Dictionary = {}) -> Vector2i:
	if source.is_empty():
		source = scene.view.frame
	for shard: Dictionary in source.get("shards", []):
		var pose := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
		for at: int in range(shard.materials.size()):
			if int(shard.roles[at]) != 1:
				continue
			var point: Vector2 = pose * Vector2(float(at % int(shard.width)) + 0.5, float(at / int(shard.width)) + 0.5)
			var cell := Vector2i(floori(point.x), floori(point.y))
			var owned: Dictionary = scene.Host._owned_cell(source, cell)
			if int(owned.get("id", 0)) == int(shard.id) and int(owned.get("cell", -1)) == at:
				if same_owner_in.is_empty() or int(scene.Host._owned_cell(same_owner_in, cell).get("id", 0)) == int(shard.id):
					return cell
	return Vector2i(-1, -1)


func _run() -> void:
	scene = load("res://object_shard_worker_rehearsal.tscn").instantiate()
	root.add_child(scene)
	_expect(await _idle(), "Continuous play screen starts a real native worker")
	_expect(scene.selector.item_count == 11 and scene.brush_select.item_count == 7, "All eleven preserved presets and seven tools are present")
	var budgets := PackedInt32Array([0, 4000, 8000, 12000])
	_expect(scene.receipt_pump_usec == 8000 and scene.pump_selector.get_selected_id() == 8000
		and scene.pump_selector.item_count == budgets.size() and not scene.host.event_driven_receipts,
		"Experimental rehearsal starts with the eight-millisecond soft budget and notifications off")
	for index in budgets.size():
		scene.pump_selector.select(index)
		scene.pump_selector.item_selected.emit(index)
		_expect(scene.pump_selector.get_selected_id() == budgets[index] and scene.receipt_pump_usec == budgets[index]
			and not scene.host.event_driven_receipts, "Receipt work control applies the selected budget: %d us" % budgets[index])
	# Preserve the four-millisecond control used for the original live edit and progression checks.
	scene.pump_selector.select(1)
	scene.pump_selector.item_selected.emit(1)
	if scene.host.failed or scene.loading:
		await _finish()
		return
	# Route synthetic pointer events through the actual view input handler.
	scene.brush_select.select(1)
	_pointer(Vector2i(20, 109))
	_expect(await _idle() and _world_material(Vector2i(20, 109)) == 7, "Wood pointer input reaches the authoritative native World")
	_pointer(Vector2i(20, 109), MOUSE_BUTTON_RIGHT)
	_expect(await _idle() and int(scene.host.last_inspection.get("material", -1)) == 7, "Right pointer inspect receives actual worker-owned material state")
	_expect(str(scene.host.last_inspection.get("owner", "")) == "World", "Inspection explicitly identifies World ownership")
	scene.brush_select.select(0)
	_pointer(Vector2i(20, 109))
	_expect(await _idle() and _world_material(Vector2i(20, 109)) == 0, "Erase uses the same native input route")
	for item: Dictionary in [{"brush": 2, "material": 2, "position": Vector2i(16, 20)},
		{"brush": 3, "material": 3, "position": Vector2i(18, 20)}, {"brush": 4, "material": 6, "position": Vector2i(20, 20)}]:
		scene.brush_select.select(int(item.brush))
		_pointer(item.position)
		_expect(await _idle() and _world_material(item.position) == int(item.material), "Sand/Water/Fire brushes author genuine native material")
	# A sustained backlog must not prevent the advertised semantic clock.
	scene.brush_select.select(2)
	var points: Array[Vector2i] = []
	for x: int in range(12, 108):
		points.append(Vector2i(x, 18))
	scene._stroke(points, MOUSE_BUTTON_LEFT)
	var before: int = scene.host.completed_ticks
	scene._toggle_run()
	var deadline: int = Time.get_ticks_msec() + 20000
	var progressed_with_pending: bool = false
	while scene.host.completed_ticks < before + 3 and not scene.host.failed and Time.get_ticks_msec() < deadline:
		if scene.host.completed_ticks > before and (not scene.queued_cuts.is_empty() or not scene.host.actions.is_empty()):
			progressed_with_pending = true
		await process_frame
	_expect(progressed_with_pending, "World/physics ticks continue with queued pointer edits")
	_expect(scene.host.completed_ticks >= before + 3 and scene.running, "Continuous mode completes real intervals without an empty/frozen pass")
	scene._cut_support()
	deadline = Time.get_ticks_msec() + 30000
	while scene.host.bridge.bodies.is_empty() and not scene.host.failed and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not scene.host.failed and scene.host.bridge.bodies.size() >= 1, "Support cuts detach real material while continuous simulation runs")
	deadline = Time.get_ticks_msec() + 15000
	while scene.view.frame.get("shards", []).is_empty() and not scene.host.failed and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not scene.view.frame.get("shards", []).is_empty(), "The first active owner reaches a coherent material-and-pose publication")
	if scene.view.frame.get("shards", []).is_empty():
		await _finish()
		return
	# Keep the game running: the displayed completed tick must offer a real
	# owner-aware input window before another physical interval replaces it.
	var live_owner: int = int(scene.host.publication.shards[0].id)
	var live_inventory: int = int(scene.host.publication.shards[0].structural)
	var live_remaining: int = live_inventory
	var live_started: int = scene.host.completed_ticks
	var live_attempts: int = 0
	var live_awake: bool = false
	deadline = Time.get_ticks_msec() + 20000
	while live_remaining == live_inventory and not scene.host.failed and Time.get_ticks_msec() < deadline:
		if scene.queued_cuts.is_empty() and scene.host.actions.is_empty():
			var live_point: Vector2i = _owned_point()
			if live_point.x >= 0:
				for body: Dictionary in scene.host.bridge.diagnostics().bodies:
					if int(body.id) == live_owner:
						live_awake = live_awake or (not bool(body.sleeping) and absf(float(body.vy)) > 0.1)
				scene.brush_select.select(0)
				_pointer(live_point)
				live_attempts += 1
		await process_frame
		for shard: Dictionary in scene.host.publication.shards:
			if int(shard.id) == live_owner:
				live_remaining = int(shard.structural)
	_expect(scene.running and not scene.host.failed and live_remaining == live_inventory - 1,
		"A displayed moving shard accepts an exact one-cell pointer cut while continuous simulation remains running")
	_expect(live_attempts > 0 and live_awake and scene.host.completed_ticks > live_started,
		"Live cutting includes real awake falling motion and additional semantic/physics progression")
	retained["live_moving_cut"] = {"attempts": live_attempts, "before_inventory": live_inventory,
		"after_inventory": live_remaining, "completed_ticks": scene.host.completed_ticks - live_started,
		"awake_motion_observed": live_awake, "running_throughout": scene.running}
	scene._toggle_run()
	_expect(await _idle(), "Pause finishes an admitted interval and drains input without resetting")
	var point: Vector2i = _owned_point()
	_expect(point.x >= 0, "The moving object's accepted pose resolves a real structural cell")
	if point.x >= 0:
		var owned: Dictionary = scene.Host._owned_cell(scene.host.publication, point)
		var inventory: int = int(owned.shard.structural)
		scene.brush_select.select(0)
		_pointer(point)
		_expect(await _idle(), "Owner-aware moving erasure completes the geometry barrier")
		var remaining: int = -1
		for shard: Dictionary in scene.host.publication.shards:
			if int(shard.id) == int(owned.id):
				remaining = int(shard.structural)
		_expect(remaining == inventory - 1, "One moving native structural cell is removed exactly once")
		_expect(scene.view.poses.is_empty(), "Rendering uses accepted material poses without live-RID overrides")
		point = _owned_point()
		_pointer(point, MOUSE_BUTTON_RIGHT)
		_expect(await _idle() and str(scene.host.last_inspection.get("owner", "")) == "ObjectShard", "Moving inventory inspection preserves explicit owner identity")
	var observed: Dictionary = scene.view.frame.duplicate(true)
	_expect(await _step(), "Single step remains usable after live material edits and detachment")
	var observed_point: Vector2i = _owned_point(observed, scene.host.publication)
	var observed_owner: Dictionary = scene.Host._owned_cell(observed, observed_point)
	# Deferred receipts may advance the host before this view gets another draw.
	# A pointer on the old visible object must not re-hit the newer owner pose.
	var current_owner: Dictionary = scene.Host._owned_cell(scene.host.publication, observed_point)
	_expect(not observed_owner.is_empty() and not current_owner.is_empty()
		and int(observed_owner.id) == int(current_owner.id)
		and int(observed_owner.shard.pose_serial) != int(current_owner.shard.pose_serial),
		"Adversary retains the same owner at the pointer across a real newer accepted pose")
	if not observed_owner.is_empty() and not current_owner.is_empty():
		var before_inventory: int = int(current_owner.shard.structural)
		scene.view.frame = observed
		scene.brush_select.select(0)
		_pointer(observed_point)
		_expect(not scene.queued_cuts.is_empty()
			and int(scene.queued_cuts[-1].parameters.target.pose_serial) == int(observed_owner.shard.pose_serial),
			"Actual pointer handler captures the displayed snapshot, not an unseen host publication")
		scene.view.present(scene.host.publication, [])
		_expect(await _idle() and str(scene.host.action_results[-1].outcome) == "TargetChanged",
			"Pointer against an older displayed pose receives an explicit TargetChanged refusal")
		var after_inventory: int = -1
		for shard: Dictionary in scene.host.publication.shards:
			if int(shard.id) == int(observed_owner.id):
				after_inventory = int(shard.structural)
		_expect(after_inventory == before_inventory, "Stale displayed-pose edit debits no newly positioned material")
		# A fresh click at the same pixel must survive a still-pending old click.
		scene.view.frame = observed
		_pointer(observed_point)
		scene.view.present(scene.host.publication, [])
		_pointer(observed_point)
		_pointer(observed_point)
		_expect(scene.queued_cuts.size() == 2, "Only identical target witnesses coalesce; a fresh same-pixel intent remains queued")
		_expect(await _idle() and scene.host.action_results.size() >= 2
			and str(scene.host.action_results[-2].outcome) == "TargetChanged" and bool(scene.host.action_results[-1].ok),
			"Stale same-pixel intent refuses while the distinct fresh target is admitted")
		var refreshed_inventory: int = -1
		for shard: Dictionary in scene.host.publication.shards:
			if int(shard.id) == int(observed_owner.id):
				refreshed_inventory = int(shard.structural)
		_expect(refreshed_inventory == before_inventory - 1, "Fresh same-pixel intent removes exactly one native structural cell")
	# Delaying consumption keeps both rendering and Rapier at the applied barrier.
	scene.delay_box.button_pressed = true
	scene.host.request_tick()
	await process_frame
	var sequence: int = scene.host.publication_sequence
	var physical_steps: int = int(scene.host.bridge.diagnostics().physics_steps)
	for frame: int in range(4):
		await process_frame
	_expect(scene.host.publication_sequence == sequence and int(scene.host.bridge.diagnostics().physics_steps) == physical_steps,
		"Explicit delayed receipts neither fabricate a new frame nor independently advance Rapier")
	scene.delay_box.button_pressed = false
	_expect(await _idle(), "Delayed receipt consumption resumes without resetting the session")
	scene._export()
	_expect(FileAccess.file_exists(scene.last_export), "Convenient bug export writes an actual observation")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.last_export))
	_expect(report.has("presentation_timing") and report.has("pointer_input") and report.has("preset"), "Bug export binds timings, input accounting and selected fixture")
	var trace: Dictionary = Capture.read_trace(scene.host.capture.path, OS.get_environment("CYBERSAND_SOURCE_REVISION"))
	_expect(trace.get("ok", false), "Recorded inspection and exact target witnesses form a valid bounded action trace")
	_expect(int(report.presentation_timing.stages.input_to_host_usec.get("count", 0)) > 0, "Timing distributions contain actual input observations")
	if DisplayServer.get_name() != "headless":
		_expect(int(report.get("timings_usec", {}).get("input_to_presented_usec", {}).get("count", 0)) > 0,
			"Rendered execution retains actual original-input-to-frame_post_draw observations")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report-copy="):
			var path: String = argument.trim_prefix("--report-copy=")
			var copied_report: int = DirAccess.copy_absolute(ProjectSettings.globalize_path(scene.last_export), path)
			var copied_trace: int = DirAccess.copy_absolute(ProjectSettings.globalize_path(scene.host.capture.path), path + ".jsonl")
			_expect(copied_report == OK and copied_trace == OK, "Qualification retains the actual continuous incident and replayable action prefix")
	retained["live_loop"] = {"completed_ticks": scene.host.completed_ticks, "bodies": scene.host.bridge.bodies.size(),
		"report_path": scene.last_export, "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION")}
	# Reset/switch every preserved authored scene, including different World bounds.
	var observations: Array[Dictionary] = []
	for index: int in range(11):
		var old_generation: int = scene.host.generation
		scene.selector.select(index)
		scene._change_scenario(index)
		var ready: bool = await _idle()
		var definition: Dictionary = Presets.definition(index + 1)
		_expect(ready and scene.host.generation > old_generation, "Preset switch disposes the old owner before opening a fresh transport")
		if not ready:
			break
		_expect(int(scene.host.publication.width) == int(definition.width) and int(scene.host.publication.height) == int(definition.height), "Preset retains its specified native canvas")
		_expect(scene.setup_cursor == Presets.edits(definition).size(), "Preset's complete ordered native authoring operations were executed")
		observations.append({"preset": index + 1, "width": scene.host.publication.width, "height": scene.host.publication.height,
			"authored_edits": scene.setup_cursor, "transport_generation": scene.host.generation})
		if index == 9:
			scene._toggle_run()
			deadline = Time.get_ticks_msec() + 15000
			while scene.authored_fixture_fire < 5 and not scene.host.failed and Time.get_ticks_msec() < deadline:
				await process_frame
			scene._toggle_run()
			_expect(await _idle() and scene.authored_fixture_fire >= 5, "External fixture authors a visible band of genuine Fire intents")
			var world: PackedByteArray = scene.host.publication.world_materials
			_expect(world.count(6) > 1, "External burner has multiple actual native Fire cells, not decorative pixels")
	if observations.size() == 11:
		scene._export()
		var authored_trace: Dictionary = Capture.read_trace(scene.host.capture.path, OS.get_environment("CYBERSAND_SOURCE_REVISION"))
		_expect(authored_trace.get("ok", false), "Full authored fixture trace retains normalized exact material tuples")
	retained["presets"] = observations
	_expect(observations.size() == 11, "Every owner-facing preset was exercised through actual worker setup")
	await _finish()


func _finish() -> void:
	if scene != null:
		scene.running = false
		scene.host.close()
		var deadline: int = Time.get_ticks_msec() + 10000
		while scene.host.state != "Closed" and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect(scene.host.state == "Closed", "Screen shutdown disposes the native session and main-thread RIDs")
		scene.queue_free()
		await process_frame
	print(JSON.stringify({"schema": "objectshard-continuous-play-test-v1", "checks": checks, "failures": failures,
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "evidence": retained,
		"scope": "Actual native worker, Rapier and owner scene input handlers; headless execution does not qualify rendered GPU playfeel"}))
	quit(0 if failures == 0 else 1)
