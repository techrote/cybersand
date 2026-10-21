extends SceneTree

# End-to-end owner regressions: actual native worlds, actual Rapier sessions,
# issued command authority, retirement and material conservation. --physical-only
# is an explicit partial pass for a checkout still building the native field API;
# the normal invocation requires and exercises all seven presets.
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const Controls = preload("res://scripts/player_playground_input.gd")
const Playground = preload("res://player_playground.tscn")

var assertions: int = 0
var failures: int = 0
var owner: Node2D
var runtime
var physical_only: bool = false
var metrics: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYER_PLAYGROUND: " + message)


func native_world() -> Object:
	return runtime._world if Course.is_swarm(runtime.selection) else runtime._arena._world


func native_snapshot() -> Dictionary:
	return native_world().diagnostic_snapshot(Course.VIEW.position, Course.VIEW.size)


func configure(id: StringName) -> bool:
	var result: bool = runtime.configure(id)
	expect(result, "preset configures: %s (%s)" % [id, runtime.last_error])
	return result


func test_input_mapping() -> void:
	var action: Dictionary = Controls.from_state({KEY_W: true, KEY_S: true, KEY_A: true, KEY_D: true})
	expect(Vector2(action.move) == Vector2.ZERO, "opposed keyboard directions cancel")
	action = Controls.from_state({KEY_RIGHT: true, KEY_SPACE: true}, Vector2(1, -1), Vector3i(0, 1, 0), 4.0)
	expect(Vector2(action.move).is_finite() and Vector2(action.move).length() <= 1.00001,
		"combined keyboard/gamepad movement remains normalized")
	expect(action.primary and action.secondary and action.trim == 1.0,
		"gamepad buttons and shoulder trim combine with keyboard controls")
	expect(Controls.deadzone(Vector2(0.1, -0.1)) == Vector2.ZERO,
		"small resting-stick noise produces no motion")
	expect(Controls.deadzone(Vector2(INF, 0)) == Vector2.ZERO, "nonfinite joystick input is neutral")
	action = Controls.from_state({KEY_D: true}, Vector2(NAN, 0), Vector3i.ZERO, INF)
	expect(Vector2(action.move) == Vector2.RIGHT and action.trim == 0.0,
		"invalid gamepad state does not poison valid keyboard input")
	for key: Key in Controls.KEYS:
		expect(Controls.active(Controls.from_state({key: true})), "release gate sees held key %d" % key)
	expect(not Controls.active(Controls.from_state({})), "released controls are neutral")


func test_mechanical_presets() -> void:
	for id: StringName in Course.PRESETS:
		if Course.is_swarm(id):
			continue
		if not configure(id):
			continue
		var first: Dictionary = runtime.observation()
		expect(first.representation == "articulated-rapier", "mechanical preset uses shared Rapier owner")
		expect(int(first.part_count) >= 1 and int(first.part_count) <= 8, "mechanical preset respects eight-part capacity")
		expect(runtime.render_parts().size() == int(first.part_count), "rendered player parts are actual collision bodies")
		var start: Vector2 = first.position
		var movement: Vector2 = Vector2.RIGHT if id == &"acrobat" else Vector2.UP
		for tick: int in range(45):
			expect(runtime.submit_action({"move": movement, "effort": 1.0}), "human movement admitted for " + str(id))
			runtime.step()
		var end: Dictionary = runtime.observation()
		expect(not runtime.failed and str(end.get("fault", "")).is_empty(), "mechanical integration remains healthy: " + str(id))
		expect(Vector2(end.position).is_finite() and Vector2(end.velocity).is_finite(), "mechanical pose remains finite")
		expect(start.distance_to(end.position) > 3.0, "human input moves actual assembly: " + str(id))
		expect(runtime.tick == 45 and int(native_world().get_tick_index()) == 45,
			"mechanical owner advances one native and physical step together")
		metrics[str(id)] = {"displacement": start.distance_to(end.position), "parts": int(end.part_count)}


func test_command_identity(id: StringName) -> void:
	if not configure(id):
		return
	# Reading render/evaluation state must not mint a control capability.
	var evaluation: Dictionary = runtime.snapshot().actor
	var unissued: Dictionary = Runtime.make_command(evaluation, 0, {"move": Vector2.RIGHT})
	expect(not runtime.submit(unissued), "evaluation snapshot cannot issue action authority: " + str(id))
	var view: Dictionary = runtime.observation()
	var good: Dictionary = Runtime.make_command(view, 1, {"move": Vector2.RIGHT}, 3)
	var mutations: Array[Dictionary] = [
		{"run_id": "obsolete-run"}, {"epoch": int(view.epoch) + 1},
		{"actor_id": 1}, {"sequence": -1}, {"sequence": 1.5},
		{"observed_tick": int(view.tick) + 1}, {"lease_ticks": 0},
		{"lease_ticks": 19}, {"observation_id": "invented-capability"},
		{"action": {"move": Vector2(NAN, 0)}}, {"action": {"primary": 1}},
		{"action": {"teleport": Vector2(500, 500)}}]
	var before: Dictionary = native_snapshot()
	for mutation: Dictionary in mutations:
		var bad: Dictionary = good.duplicate(true)
		bad.merge(mutation, true)
		expect(not runtime.submit(bad), "%s rejects malformed/stale packet %s" % [id, mutation.keys()])
	var extra: Dictionary = good.duplicate(true)
	extra["hidden_override"] = true
	expect(not runtime.submit(extra), "unknown envelope fields are refused")
	expect(native_snapshot().hash == before.hash, "rejected packets do not mutate native state")
	expect(runtime.submit(good), "fresh issued command is admitted")
	expect(not runtime.submit(good), "same sequence cannot be replayed")
	var old_view: Dictionary = runtime.observation()
	runtime.cancel()
	expect(not runtime.submit(Runtime.make_command(old_view, 2, {"move": Vector2.RIGHT})),
		"control generation retires pre-cancel observations")
	view = runtime.observation()
	expect(runtime.submit(Runtime.make_command(view, 3, {"move": Vector2.RIGHT}, 1)),
		"fresh command after cancellation is admitted")
	runtime.step()
	runtime.step()
	var expired: Dictionary = runtime.observation()
	expect(int(expired.lease_remaining) == 0, "one-tick command authority expires")
	expect(not runtime.submit(Runtime.make_command(view, 4, {"move": Vector2.RIGHT}, 1)),
		"receiving an old result cannot extend its observation-relative lease")
	var stale: Dictionary = Runtime.make_command(runtime.observation(), 5, {"move": Vector2.RIGHT})
	var old_run: String = str(runtime.observation().run_id)
	var old_epoch: int = runtime.epoch
	expect(configure(id), "same preset can reset")
	expect(runtime.epoch > old_epoch and str(runtime.observation().run_id) != old_run,
		"reset creates a fresh wrapper epoch and run identity")
	expect(not runtime.submit(stale), "reset retires all old input authority")
	var live_run: String = str(runtime.observation().run_id)
	expect(not runtime.configure(&"missing-preset"), "unknown preset is refused")
	expect(runtime.active() and str(runtime.observation().run_id) == live_run,
		"failed replacement preserves the existing live owner")


func test_pause(id: StringName) -> void:
	if not configure(id):
		return
	var view: Dictionary = runtime.observation()
	expect(runtime.submit(Runtime.make_command(view, 0, {"move": Vector2.RIGHT})), "pause fixture command admitted")
	runtime.step()
	runtime.set_paused(true)
	var before: Dictionary = native_snapshot()
	var tick_before: int = runtime.tick
	var parts_before: Array = runtime.render_parts()
	for step_index: int in range(12):
		runtime.step()
	var after: Dictionary = native_snapshot()
	expect(before.hash == after.hash and before.cells == after.cells and runtime.tick == tick_before,
		"paused calls leave native state and tick unchanged: " + str(id))
	expect(parts_before == runtime.render_parts(), "paused calls do not integrate Rapier")
	expect(not runtime.submit_action({"primary": true}), "paused owner refuses new movement")
	runtime.set_paused(false)
	expect(not runtime.submit(Runtime.make_command(view, 2, {"move": Vector2.RIGHT})),
		"resume requires fresh authority")
	expect(runtime.submit_action({"move": Vector2.ZERO}), "fresh neutral resume input is admitted")
	runtime.step()
	expect(runtime.tick == tick_before + 1 and not runtime.failed, "unpaused owner resumes one step")


func test_fast_input_edges() -> void:
	if not configure(&"acrobat"):
		return
	for tick: int in range(45):
		runtime.submit_action({"move": Vector2.ZERO})
		runtime.step()
	var view: Dictionary = runtime.observation()
	expect(bool(view.grounded), "edge fixture has actual floor support")
	expect(runtime.submit(Runtime.make_command(view, int(view.last_sequence) + 1, {"primary": true})),
		"same-tick jump press admitted")
	expect(runtime.submit(Runtime.make_command(view, int(view.last_sequence) + 2, {"primary": false})),
		"same-tick jump release admitted")
	runtime.step()
	runtime.step()
	var jumped: Dictionary = runtime.observation()
	expect(Vector2(jumped.velocity).y < -30.0, "press and release before a tick still produce the intended jump")
	expect(jumped.player_movement.last_move == "jump", "edge queue does not turn one tap into two jumps")


func test_material_motion(id: StringName) -> void:
	if not configure(id):
		return
	var first: Dictionary = native_snapshot()
	var first_position: Vector2 = runtime.observation().position
	var material: int = 2 if id == &"dryswarm" else 3
	var moved: int = 0
	for index: int in range(90):
		var action: Dictionary = {"move": Vector2.RIGHT, "secondary": index >= 30 and index < 45,
			"auxiliary": index >= 65, "primary": index < 8}
		expect(runtime.submit_action(action), "fresh material control admitted")
		runtime.step()
		var view: Dictionary = runtime.observation()
		expect(not runtime.failed and bool(view.field.accepted), "real native material field applies")
		expect(Vector2(view.field.centroid).is_finite(), "material receipt centroid is finite")
		expect(Vector2(view.position).distance_to(first_position) <= (index + 1) * 4.0 + 0.001,
			"field centre cannot move faster than the actual receipt-follow bound")
		moved += int(view.field.moved_cells)
	var last: Dictionary = native_snapshot()
	if material == 2:
		expect(int(last.counts[2]) == int(first.counts[2]), "native steering conserves all Sand cells across ticks")
	else:
		expect(int(last.water_mass) == int(first.water_mass), "native steering conserves exact Water quantity across ticks")
	expect(moved > 256, "material controls actually transport native parcels")
	expect(Vector2(runtime.observation().position).x > first_position.x + 10.0,
		"receipt-following controller makes useful directional progress")
	var changed_hard: int = 0
	for index: int in range(first.cells.size()):
		if int(first.cells[index]) not in [0, 2, 3] and first.cells[index] != last.cells[index]:
			changed_hard += 1
	expect(changed_hard == 0, "material steering cannot erase course walls or supports")
	expect(runtime.render_parts().is_empty(), "material swarm does not allocate per-cell Rapier bodies")
	metrics[str(id)] = {"position": runtime.observation().position, "moved_cells_sum": moved,
		"sand_cells": int(last.counts[2]), "water_quantity": int(last.water_mass)}


func test_material_barrier(id: StringName) -> void:
	if not configure(id):
		return
	var world: Object = native_world()
	expect(world.diagnostic_fill_rect(Vector2i(216, 132), Vector2i(3, 220), 62),
		"barrier fixture seals west and east compartments")
	var right_before: Dictionary = world.diagnostic_snapshot(Vector2i(219, 132), Vector2i(417, 220))
	for index: int in range(100):
		runtime.submit_action({"move": Vector2.RIGHT, "primary": true})
		runtime.step()
	var right_after: Dictionary = world.diagnostic_snapshot(Vector2i(219, 132), Vector2i(417, 220))
	if id == &"dryswarm":
		expect(int(right_after.counts[2]) == int(right_before.counts[2]), "Sand surge cannot tunnel through sealed hard wall")
	else:
		expect(int(right_after.water_mass) == int(right_before.water_mass), "Water surge cannot tunnel through sealed hard wall")
	expect(Vector2(runtime.observation().position).x < 216.0, "receipt centre follows blocked material instead of crossing wall")
	var barrier: Dictionary = world.diagnostic_snapshot(Vector2i(216, 132), Vector2i(3, 220))
	expect(int(barrier.counts[62]) == 660, "all original barrier cells remain authoritative")


func test_cancel_is_natural_material_step(id: StringName) -> void:
	if not configure(id):
		return
	var reference = Runtime.new()
	owner.add_child(reference)
	expect(reference.configure(id), "cancel comparison starts identical native world")
	for index: int in range(8):
		var action: Dictionary = {"move": Vector2.RIGHT}
		runtime.submit_action(action)
		reference.submit_action(action)
		runtime.step()
		reference.step()
	runtime.cancel()
	reference.cancel()
	for index: int in range(12):
		runtime.step()
		expect(reference._world.simulation_tick(), "uncontrolled reference native tick succeeds")
	var actual: Dictionary = native_snapshot()
	var expected: Dictionary = reference._world.diagnostic_snapshot(Course.VIEW.position, Course.VIEW.size)
	expect(actual.hash == expected.hash and actual.cells == expected.cells,
		"cancelled owner applies no hidden field: exact match with ordinary native ticks")
	expect(not bool(runtime.snapshot().field_active), "cancelled material field reports inactive")
	reference.close()
	reference.free()


func test_material_button_edges(id: StringName) -> void:
	var reference = Runtime.new()
	owner.add_child(reference)
	for button: String in ["primary", "secondary", "auxiliary"]:
		if not configure(id) or not reference.configure(id):
			expect(false, "quick-tap comparison worlds configure")
			break
		var pulse: Dictionary = {button: true}
		expect(runtime.submit_action(pulse) and runtime.submit_action({button: false}),
			"same-tick material button press and release admitted: " + button)
		expect(reference.submit_action(pulse), "one-tick held material reference admitted")
		expect(int(runtime.observation().pending_input_edges) == 2,
			"quick material tap remains queued until an actual simulation sample")
		runtime.step()
		reference.step()
		var expected: Dictionary = reference._world.diagnostic_snapshot(Course.VIEW.position, Course.VIEW.size)
		expect(native_snapshot().hash == expected.hash,
			"quick material tap has exactly the native effect of one held tick: " + str(id) + "/" + button)
		expect(int(runtime.observation().pending_input_edges) == 1, "release waits for its own material sample")
		reference.submit_action({button: false})
		runtime.step()
		reference.step()
		expected = reference._world.diagnostic_snapshot(Course.VIEW.position, Course.VIEW.size)
		expect(native_snapshot().hash == expected.hash and int(runtime.observation().pending_input_edges) == 0,
			"material tap releases after one tick and creates no extra pulse")
	# A button backlog cannot turn an expired one-tick command into a delayed
	# launch. The comparison owner advances only ordinary native simulation.
	if configure(id) and reference.configure(id):
		var view: Dictionary = runtime.observation()
		for index: int in range(8):
			expect(runtime.submit(Runtime.make_command(view, index, {"primary": index % 2 == 0}, 1)),
				"short-lease material backlog admitted within bounded capacity")
		reference.submit_action({"primary": true})
		runtime.step()
		reference.step()
		reference.cancel()
		for index: int in range(3):
			runtime.step()
			expect(reference._world.simulation_tick(), "expired material comparison advances naturally")
		var expected: Dictionary = reference._world.diagnostic_snapshot(Course.VIEW.position, Course.VIEW.size)
		expect(native_snapshot().hash == expected.hash and int(runtime.observation().pending_input_edges) == 0,
			"lease expiry discards a pending material backlog without applying another field")
	if configure(id) and reference.configure(id):
		runtime.submit_action({"primary": true})
		runtime.submit_action({"primary": false})
		runtime.cancel()
		runtime.step()
		expect(reference._world.simulation_tick(), "cancelled tap reference advances naturally")
		var expected: Dictionary = reference._world.diagnostic_snapshot(Course.VIEW.position, Course.VIEW.size)
		expect(native_snapshot().hash == expected.hash and int(runtime.observation().pending_input_edges) == 0,
			"cancellation discards an unsampled material tap without a burst")
	# Deliberately flood one observation. Refusal must leave the accepted sequence
	# and native world intact, then normal cancellation must recover the owner.
	if configure(id):
		var view: Dictionary = runtime.observation()
		var before: Dictionary = native_snapshot()
		var refused: bool = false
		var last_accepted: int = -1
		for index: int in range(80):
			if not runtime.submit(Runtime.make_command(view, index, {"primary": index % 2 == 0})):
				refused = true
				break
			last_accepted = index
		expect(refused and last_accepted >= 1, "material edge flood reaches a bounded admission refusal")
		expect(int(runtime.observation().last_sequence) == last_accepted and native_snapshot().hash == before.hash,
			"edge capacity refusal cannot consume sequence or mutate native cells")
		runtime.cancel()
		expect(runtime.submit_action({"move": Vector2.ZERO}) and int(runtime.observation().pending_input_edges) == 0,
			"fresh neutral material control recovers cleanly after capacity cancellation")
	reference.close()
	reference.free()


func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func test_playground_ui() -> void:
	# Drive the real scene's event handler and its fixed-tick sampler separately,
	# so a press+release genuinely happens before the next physics update.
	for code: Key in Controls.KEYS:
		key_event(code, false)
	var scene: Control = Playground.instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	expect(scene._buttons.size() == 7 and scene.runtime.active(), "real player scene builds all seven choices")
	var ids: Array = [&"stuntbuggy", &"trialsbike", &"acrobat", &"arcadelander", &"jetbarrel"] if physical_only else Course.PRESETS
	for id: StringName in ids:
		var index: int = Course.PRESETS.find(id)
		expect(scene.select_preset(index), "real UI selects " + str(id))
		expect(scene._title.text == Course.NAMES[index] and scene._controls.text == Course.controls(id),
			"selection presents matching actor name and actual control mapping")
		expect(scene._surface.reset_generation == scene.runtime.epoch and scene._surface.last_rejection.is_empty(),
			"new native owner publishes an admitted immutable packet through the real surface")
	scene.select_preset(Course.PRESETS.find(&"acrobat"))
	var held: Dictionary = Controls.from_state({KEY_D: true})
	var neutral: Dictionary = Controls.from_state({})
	scene.advance_frame(held, scene._can_control())
	expect(scene._rearm and int(scene.runtime.observation().last_sequence) == -1,
		"changing presets cannot inherit held movement")
	for index: int in range(45):
		scene.advance_frame(neutral, scene._can_control())
	expect(not scene._rearm and bool(scene.runtime.observation().grounded),
		"released controls arm the real scene on actual floor support")
	expect(not scene._lap_started and scene._lap_ticks == 0,
		"neutral settling does not start the course clock")
	var before_tick: int = scene.runtime.tick
	key_event(KEY_SPACE, true)
	key_event(KEY_SPACE, false)
	expect(scene.runtime.tick == before_tick and int(scene.runtime.observation().pending_input_edges) == 2,
		"actual keyboard press+release are captured before the fixed tick")
	expect(scene._lap_started and scene._lap_ticks == 0,
		"admitted fast tap starts the course clock without advancing simulation")
	scene.advance_frame(neutral, scene._can_control())
	expect(Vector2(scene.runtime.observation().velocity).y < -30.0,
		"real scene fast-tap path produces a physical jump")
	expect(scene._lap_ticks == 1,
		"the first movement tick counts even when the input sample is already neutral")
	scene.advance_frame(neutral, scene._can_control())
	expect(scene._lap_ticks == 2,
		"coasting after a fast tap keeps the course clock running")
	# Cancellation between event and physics tick must not create a jump when
	# focus returns, even if the same physical key remains held.
	scene.select_preset(Course.PRESETS.find(&"acrobat"))
	for index: int in range(45):
		scene.advance_frame(neutral, scene._can_control())
	key_event(KEY_SPACE, true)
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	scene.advance_frame(scene._sample_action(), scene._can_control())
	expect(int(scene.runtime.observation().pending_input_edges) == 0 and Vector2(scene.runtime.observation().velocity).y > -5.0,
		"focus loss clears a queued jump without a delayed launch")
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	scene.advance_frame(scene._sample_action(), scene._can_control())
	expect(scene._rearm and int(scene.runtime.observation().lease_remaining) == 0,
		"regaining focus cannot consume a still-held movement button")
	key_event(KEY_SPACE, false)
	scene.advance_frame(scene._sample_action(), scene._can_control())
	expect(not scene._rearm, "fully released keyboard rearms after focus recovery")
	scene.advance_frame(held, scene._can_control())
	key_event(KEY_P, true)
	key_event(KEY_P, false)
	expect(scene.runtime.paused and not scene._surface.render_enabled, "actual pause key suspends simulation and continuous material rendering")
	var world: Object = scene.runtime._arena._world
	var paused_native: Dictionary = world.diagnostic_snapshot(Course.VIEW.position, Course.VIEW.size)
	var paused_tick: int = scene.runtime.tick
	var paused_lap: int = scene._lap_ticks
	for index: int in range(5):
		scene.advance_frame(held, scene._can_control())
	expect(scene.runtime.tick == paused_tick and scene._lap_ticks == paused_lap,
		"the real paused frame loop freezes both simulation and lap timing")
	expect(world.diagnostic_snapshot(Course.VIEW.position, Course.VIEW.size).hash == paused_native.hash,
		"the real paused frame loop cannot mutate native materials")
	# Model the already-consumed paused bake. A camera change needs another
	# one-shot render even though there is no simulation packet or native tick.
	scene._surface.render_target_update_mode = SubViewport.UPDATE_DISABLED
	key_event(KEY_F, true)
	key_event(KEY_F, false)
	expect(scene._view.size == Vector2i(256, 128) and scene._surface.render_target_update_mode == SubViewport.UPDATE_ONCE,
		"paused camera zoom requests a fresh terrain bake matching the overlay")
	expect(scene.runtime.tick == paused_tick and world.diagnostic_snapshot(Course.VIEW.position, Course.VIEW.size).hash == paused_native.hash,
		"paused camera changes affect presentation without advancing the native owner")
	key_event(KEY_P, true)
	key_event(KEY_P, false)
	scene.advance_frame(held, scene._can_control())
	expect(not scene.runtime.paused and scene._rearm and int(scene.runtime.observation().lease_remaining) == 0,
		"resume still requires release before held controls can act")
	scene.advance_frame(neutral, scene._can_control())
	scene.advance_frame(held, scene._can_control())
	expect(not scene._rearm and scene.runtime.tick == paused_tick + 3,
		"neutral release and fresh movement resume exactly one owner tick per frame")
	key_event(KEY_P, true)
	key_event(KEY_P, false)
	var old_run: String = str(scene.runtime.observation().run_id)
	key_event(KEY_R, true)
	key_event(KEY_R, false)
	expect(not scene.runtime.paused and scene._surface.render_enabled and scene.runtime.tick == 0,
		"reset from pause restores a running owner and continuous surface rendering")
	expect(scene._rearm and scene._target == 0 and scene._lap_ticks == 0 and str(scene.runtime.observation().run_id) != old_run,
		"reset retires old input identity and starts a clean course timer")
	# Reach the configured arena bound directly, rather than spending ten
	# minutes of this regression checking identical intermediate ticks.
	scene.runtime._arena.config.max_ticks = scene.runtime.tick + 1
	scene.advance_frame(neutral, scene._can_control())
	expect(scene.runtime.paused and scene.runtime.last_error == "tick_limit" and scene._status.text.contains("press R or P"),
		"completed arena exposes an actionable fresh-run path instead of an unresumable pause")
	old_run = str(scene.runtime.observation().run_id)
	key_event(KEY_P, true)
	key_event(KEY_P, false)
	expect(scene.runtime.tick == 0 and not scene.runtime.paused and str(scene.runtime.observation().run_id) != old_run,
		"pause key after the arena bound actually creates a fresh run")
	expect(scene._surface.render_enabled and scene._surface.rejected_packets == 0,
		"UI lifecycle leaves a live surface with no rejected native packets")
	scene.free()
	await process_frame


func test_cross_preset_retirement() -> void:
	var ids: Array = [&"acrobat", &"jetbarrel", &"stuntbuggy"] if physical_only else Course.PRESETS
	var previous_run: String = ""
	var previous_command: Dictionary = {}
	for id: StringName in ids:
		if not configure(id):
			continue
		var view: Dictionary = runtime.observation()
		expect(str(view.run_id) != previous_run, "every preset replacement starts fresh run identity")
		if not previous_command.is_empty():
			expect(not runtime.submit(previous_command), "foreign preset cannot retain movement authority")
		previous_run = str(view.run_id)
		previous_command = Runtime.make_command(view, 99, {"primary": true})
		expect(runtime.get_child_count() == (0 if Course.is_swarm(id) else 1),
			"replacement retires the old arena and keeps one exclusive owner")
	runtime.close()
	expect(not runtime.active() and runtime.observation().is_empty() and runtime.render_parts().is_empty(),
		"close retires native and Rapier ownership")
	expect(not runtime.submit(previous_command), "closed runtime cannot consume delayed input")


func run() -> void:
	physical_only = "--physical-only" in OS.get_cmdline_user_args()
	owner = Node2D.new()
	root.add_child(owner)
	runtime = Runtime.new()
	owner.add_child(runtime)
	test_input_mapping()
	test_mechanical_presets()
	test_command_identity(&"acrobat")
	test_pause(&"acrobat")
	test_fast_input_edges()
	if not physical_only:
		for id: StringName in [&"dryswarm", &"liquidswarm"]:
			test_command_identity(id)
			test_pause(id)
			test_material_motion(id)
			test_material_barrier(id)
			test_cancel_is_natural_material_step(id)
			test_material_button_edges(id)
	test_cross_preset_retirement()
	await test_playground_ui()
	owner.free()
	await process_frame
	print("PLAYER_PLAYGROUND_RUNTIME_METRICS ", JSON.stringify(metrics))
	print("PLAYER_PLAYGROUND_RUNTIME: %d assertions, %d failures; scope=%s" %
		[assertions, failures, "physical-and-input-only" if physical_only else "all-seven-native-and-Rapier"])
	quit(0 if failures == 0 else 1)
