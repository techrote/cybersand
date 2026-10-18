extends SceneTree

const Worker = preload("res://scripts/simulation_worker.gd")
const Recorder = preload("res://scripts/gameplay_recorder.gd")
const WaterProfiles = preload("res://scripts/water_experiment_profiles.gd")
const MODELS: Array[StringName] = [&"runner", &"skimmer", &"crawler"]
const SPAWN: Vector2 = Vector2(800.0, 20.0)
const INPUT_KEYS: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT]

# Exercise the real desktop keyboard adapter with a deterministic focus gate.
# A headless Window cannot demonstrate interactive OS focus or visual quality.
class InputSink:
	extends CyberSimulationWorker
	var packets: Array[Dictionary] = []
	var cancellations: int = 0

	func submit_actor_action(actor_id: int, epoch: int, sequence: int, observed_tick: int,
		movement: Vector2, primary: bool, secondary: bool, lease_ticks: int = 12,
		producer: StringName = &"policy") -> bool:
		packets.append({"id": actor_id, "epoch": epoch, "sequence": sequence,
			"tick": observed_tick, "movement": movement, "primary": primary,
			"secondary": secondary, "lease": lease_ticks, "producer": producer})
		return true

	func cancel_actor_input(_actor_id: int, _epoch: int, _producer: StringName) -> bool:
		cancellations += 1
		return true

	func has_failed() -> bool:
		return false

class KeyboardHarness:
	extends "res://scripts/main.gd"
	var input_allowed: bool = true

	func actor_keyboard_allowed() -> bool:
		return input_allowed

var assertions: int = 0
var failures: int = 0
var native_actor_snapshots: Array[CyberSimulationSnapshot] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error("ACTOR_INTEGRATION: " + message)


func _wait_for(predicate: Callable, timeout_ms: int = 15000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call():
			return true
	return false


func _definition() -> Array:
	return [{"model": &"runner", "producer": &"policy", "position": SPAWN}]


func _frame(worker: CyberSimulationWorker, paused: bool, legacy_input: float = 0.0,
	legacy_jetpack: bool = false) -> void:
	worker.set_frame_state(legacy_input, legacy_jetpack, paused, Vector2i(800, 40),
		Vector2i(720, 0), Vector2i(160, 100), 0, 0, true, true, true)


func _worker_owner_and_publication() -> void:
	var worker := Worker.new()
	_frame(worker, true)
	_expect(worker.start_worker(SPAWN) == OK, "native owner thread failed to start")
	var receipt: int = worker.queue_actor_prototype_reset(_definition(), SPAWN)
	_expect(receipt > 0, "ordinary sandbox reset was not admitted")
	var applied: bool = await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.actor_prototype_reset_serial == receipt
	)
	_expect(applied, "owner did not acknowledge prototype reset")
	if not applied:
		worker.stop_worker()
		return
	var retained: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	_expect(retained.actor_prototype_reset_applied and retained.actor_prototypes.size() > 0,
		"admitted prototype reset did not install a motor")
	if retained.actor_prototypes.is_empty():
		worker.stop_worker()
		return
	var retained_context: Dictionary = retained.actor_prototypes.duplicate(true)
	native_actor_snapshots.append(retained)
	_expect(retained.player_representation == "actor-prototype/runner", "worker prototype identity is wrong")
	_expect(not retained.character_runtime_recovery_enabled, "prototype enabled legacy burial relocation")

	# Holding old sampled-player inputs must not actuate the installed prototype.
	_frame(worker, false, 1.0, true)
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and int(snapshot.actor_prototypes.get("tick", 0)) >= 8
	), "prototype did not advance through fixed owner ticks")
	var neutral: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	_expect(is_equal_approx(neutral.character_position.x, SPAWN.x), "legacy horizontal input also moved prototype")
	_expect(neutral.character_position.y > SPAWN.y, "legacy jetpack suppressed prototype gravity")
	_expect(neutral.tick_index == int(neutral.actor_prototypes.tick), "actor and cellular owner tick counts diverged")
	_expect(neutral.actor_prototypes == neutral.lab_context.actor_prototypes, "publication contexts disagree about current actors")
	var context: Dictionary = neutral.actor_prototypes
	_expect(worker.submit_actor_action(0, int(context.epoch), 1, int(context.tick),
		Vector2.LEFT, false, true, 18, &"policy"), "current policy action was refused by live owner")
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.character_position.x < SPAWN.x - 3.0
	), "policy action did not reach actor motor")
	var moved: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	native_actor_snapshots.append(moved)
	_expect(moved.actor_prototypes.query_count_last <= 32, "worker exceeded one-actor query budget")
	_expect(moved.character_position.is_equal_approx(Vector2(moved.actor_prototypes.states[0],
		moved.actor_prototypes.states[1])), "character presentation does not alias actor zero")
	_expect(retained.actor_prototypes == retained_context, "later worker ticks mutated a retained publication")
	_frame(worker, true)
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.paused and snapshot.actor_prototypes.suspended
	), "pause did not invalidate and suspend the actor session")
	var paused_snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	_expect(int(paused_snapshot.actor_prototypes.epoch) != int(context.epoch), "pause retained policy epoch")
	_expect(not worker.submit_actor_action(0, int(context.epoch), 2, int(context.tick),
		Vector2.RIGHT, false, false, 18, &"policy"), "late pre-pause inference reached suspended owner")
	worker.stop_worker()
	# Only inspect mutable owner objects after the worker has joined.
	_expect(worker._character is CyberActorPrototype, "prototype reset retained a second sampled player owner")
	_expect(worker._character == worker._actor_session.player(), "worker player does not reference session actor zero")


func _owner_admission_race() -> void:
	var worker := Worker.new()
	_frame(worker, true)
	# Reproduce a stale published view deterministically while this test is the
	# sole owner: a prototype request precedes a newly installed Tower world.
	var receipt: int = worker.queue_actor_prototype_reset(_definition(), SPAWN)
	_expect(receipt > 0, "stale-view fixture did not admit initial request")
	_expect(worker._apply_lab({"reset": true}), "stale-view fixture did not install Tower")
	_expect(worker.start_worker(SPAWN) == OK, "stale-view fixture owner failed to start")
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.actor_prototype_reset_serial == receipt
	), "owner refusal did not acknowledge admitted receipt")
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	_expect(not snapshot.actor_prototype_reset_applied and snapshot.actor_prototypes.is_empty(),
		"stale prototype reset replaced a registered apparatus")
	_expect(snapshot.lab_context.get("active", false), "owner refusal erased Tower identity")
	_expect(snapshot.actor_prototype_status.contains("Refused"), "owner refusal has no reviewable disposition")
	_expect(worker.queue_actor_prototype_reset(_definition(), SPAWN) == 0,
		"direct actor reset bypassed published lab exclusion")
	worker.stop_worker()
	_expect(not worker._character is CyberActorPrototype and not worker._actor_session.active(),
		"registered apparatus retained a hidden prototype owner")


func _ordinary_reset_supersedes_receipt() -> void:
	var worker := Worker.new()
	_frame(worker, true)
	var earlier_receipt: int = worker.queue_actor_prototype_reset(_definition(), SPAWN)
	var latest_receipt: int = worker.queue_actor_prototype_reset(_definition(), SPAWN)
	_expect(latest_receipt > earlier_receipt and earlier_receipt > 0, "actor reset receipts did not increase")
	var ordinary_spawn: Vector2 = SPAWN + Vector2(10, 0)
	worker.queue_reset(ordinary_spawn)
	_expect(worker.start_worker(SPAWN) == OK, "supersession fixture owner failed to start")
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.actor_prototype_reset_serial >= latest_receipt
	), "ordinary reset orphaned an admitted actor reset receipt")
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	_expect(not snapshot.actor_prototype_reset_applied and snapshot.actor_prototypes.is_empty(),
		"superseded actor reset was reported as installed")
	_expect(snapshot.character_position.is_equal_approx(ordinary_spawn)
		and snapshot.player_representation == "sampled-baseline",
		"receipt cancellation prevented the ordinary reset")
	_expect(snapshot.actor_prototype_status.contains("ordinary reset"), "supersession published no specific disposition")
	worker.stop_worker()


func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return event


func _keyboard_edges_and_rearm() -> void:
	for keycode: Key in INPUT_KEYS:
		_key(keycode, false)
	var desktop := KeyboardHarness.new()
	var sink := InputSink.new()
	desktop.simulation_worker = sink
	desktop.latest_snapshot = CyberSimulationSnapshot.new()
	desktop.latest_snapshot.actor_prototypes = {"epoch": 1, "tick": 0,
		"producers": [&"human"], "suspended": false}
	desktop.publish_actor_keyboard_input()
	_expect(not desktop._actor_input_rearm and sink.packets.size() == 1, "released keys did not arm keyboard adapter")
	desktop._unhandled_key_input(_key(KEY_SPACE, true))
	desktop._unhandled_key_input(_key(KEY_SPACE, false))
	_expect(sink.packets.size() == 3 and sink.packets[1].primary and not sink.packets[2].primary,
		"desktop event adapter lost a press-release between physics samples")
	_expect(sink.packets[1].producer == &"human" and sink.packets[1].lease == 6,
		"keyboard adapter changed producer identity or bounded lease")
	desktop.input_allowed = false
	desktop.publish_actor_keyboard_input()
	_expect(sink.cancellations == 1 and desktop._actor_input_rearm, "focus/UI rejection did not cancel and require rearm")
	desktop.input_allowed = true
	_key(KEY_A, true)
	_key(KEY_D, true)
	_expect(Input.is_key_pressed(KEY_A) and Input.is_key_pressed(KEY_D), "synthetic opposing-key premise failed")
	desktop.publish_actor_keyboard_input()
	_expect(desktop._actor_input_rearm and sink.packets.size() == 3,
		"opposing held keys bypassed release-to-rearm with a zero movement vector")
	_key(KEY_A, false)
	desktop.publish_actor_keyboard_input()
	_expect(desktop._actor_input_rearm and sink.packets.size() == 3, "one remaining held key bypassed rearm")
	_key(KEY_D, false)
	desktop.publish_actor_keyboard_input()
	_expect(not desktop._actor_input_rearm and sink.packets.size() == 4, "fully released controls failed to rearm")
	_key(KEY_D, true)
	desktop.latest_snapshot.actor_prototypes.epoch = 2
	desktop.publish_actor_keyboard_input()
	_expect(desktop._actor_input_rearm and sink.packets.size() == 4, "new session epoch replayed held keyboard action")
	_key(KEY_D, false)
	desktop.publish_actor_keyboard_input()
	_expect(sink.packets.size() == 5 and sink.packets[4].sequence == 1 and sink.packets[4].epoch == 2,
		"new keyboard epoch did not restart its own sequence")
	desktop.latest_snapshot.actor_prototypes.producers = [&"policy"]
	desktop._unhandled_key_input(_key(KEY_SPACE, true))
	_expect(sink.packets.size() == 5, "keyboard events also actuated a policy-controlled player")
	desktop._actor_reset_receipt = 19
	desktop.actor_model_selection = &"runner"
	desktop.latest_snapshot.actor_prototypes = {}
	desktop.latest_snapshot.actor_prototype_reset_serial = 19
	desktop.latest_snapshot.actor_prototype_reset_applied = false
	desktop._reconcile_actor_prototype_reset()
	_expect(desktop._actor_reset_receipt == 0 and desktop.actor_model_selection == &""
		and desktop._actor_input_rearm, "owner refusal left optimistic UI selection or a pending receipt")
	for keycode: Key in INPUT_KEYS:
		_key(keycode, false)
	desktop.free()


func _wait_model(desktop: Control, model: StringName, count: int) -> bool:
	return await _wait_for(func() -> bool:
		if desktop.latest_snapshot == null or desktop._actor_reset_receipt != 0:
			return false
		var context: Dictionary = desktop.latest_snapshot.actor_prototypes
		if count == 0:
			return context.is_empty()
		return int(context.get("count", 0)) == count and context.models[0] == model
	)


func _desktop_selector_and_labs() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var desktop: Control = scene.instantiate()
	root.add_child(desktop)
	await process_frame
	desktop.paused = true
	for model: StringName in MODELS:
		var event := InputEventKey.new()
		event.keycode = KEY_F5
		event.pressed = true
		desktop._unhandled_key_input(event)
		_expect(desktop.actor_prototype_panel.visible, "F5 did not open prototype selector")
		_expect(not desktop.actor_keyboard_allowed(), "open prototype selector accepted gameplay input")
		desktop.actor_prototype_panel.configure_selection(model, &"policy", true)
		desktop.actor_prototype_panel._apply()
		_expect(await _wait_model(desktop, model, 3), str(model) + " panel apply did not acknowledge three actors")
		if desktop.latest_snapshot.actor_prototypes.is_empty():
			continue
		var context: Dictionary = desktop.latest_snapshot.actor_prototypes
		_expect(context.producers == [&"policy", &"demo", &"demo"], "selector did not preserve pilot and demo identities")
		_expect(context.models.has(&"runner") and context.models.has(&"skimmer") and context.models.has(&"crawler"),
			"demo NPC option omitted a prototype model")
		_expect(not desktop.toggle_sampled_runtime_recovery(), "F7 changed provisional burial semantics")
		_expect(desktop.player_representation_identity() == "actor-prototype/" + str(model), "desktop labels the wrong actor model")

	# Verify the overlay uses the same letterbox and integer camera grid as the
	# terrain and pointer transform, even on a non-16:9 available surface.
	desktop.world_view.size = Vector2(800, 800)
	desktop.current_view_size = Vector2i(320, 180)
	var content: Rect2 = desktop.view_content_rect()
	var origin: Vector2 = Vector2(12.75, 7.25)
	desktop.actor_prototype_overlay.present(desktop.latest_snapshot.actor_prototypes,
		origin, desktop.current_view_size, content)
	_expect(content == Rect2(0, 175, 800, 450), "non-16:9 transform fixture did not letterbox as expected")
	_expect(desktop.actor_prototype_overlay.position == content.position
		and desktop.actor_prototype_overlay.size == content.size
		and desktop.actor_prototype_overlay._origin == origin.floor(),
		"actor overlay differs from aspect-fit terrain or integer camera origin")

	desktop.actor_prototype_panel.configure_selection(&"", &"human", false)
	desktop.actor_prototype_panel._apply()
	_expect(await _wait_model(desktop, &"", 0), "baseline option did not remove provisional session")
	_expect(desktop.player_representation_identity() == "sampled-baseline", "baseline option retained provisional identity")
	_expect(desktop.toggle_sampled_runtime_recovery(), "baseline did not restore F7 recovery comparison")
	_expect(desktop.apply_actor_prototype_configuration(&"runner", &"human", false), "prototype reinstall before F6 was refused")
	_expect(await _wait_model(desktop, &"runner", 1), "prototype reinstall did not acknowledge")
	_expect(desktop.cycle_player_representation(), "F6 did not leave provisional selection")
	_expect(await _wait_model(desktop, &"", 0), "F6 left a second actor session active")
	_expect(desktop.player_uses_barrel() and desktop.actor_model_selection == &"", "F6 did not activate barrel owner")
	_expect(desktop.cycle_player_representation(), "F6 did not restore sampled owner")
	var sampled_identity: String = "sampled-baseline" if desktop.sampled_runtime_recovery_enabled else "sampled-burial-safe"
	_expect(await _wait_for(func() -> bool:
		return desktop.latest_snapshot != null and desktop.latest_snapshot.player_representation == sampled_identity
	), "F6 sampled reset was not published")
	_expect(desktop.apply_actor_prototype_configuration(&"crawler", &"policy", true), "prototype reinstall before Tower was refused")
	_expect(await _wait_model(desktop, &"crawler", 3), "prototype reinstall before Tower did not acknowledge")
	desktop.tower_reset()
	_expect(await _wait_for(func() -> bool:
		return desktop.tower_context.get("active", false) and desktop.latest_snapshot.actor_prototypes.is_empty()
	), "Tower transition retained provisional session")
	_expect(not desktop.actor_prototypes_allowed() and not desktop.apply_actor_prototype_configuration(&"runner", &"human", false),
		"Tower accepted ordinary prototype selector mutation")
	desktop.queue_free()
	await process_frame

	# A separate fresh sandbox checks direct prototype -> Water ownership.
	desktop = scene.instantiate()
	root.add_child(desktop)
	await process_frame
	desktop.paused = true
	_expect(desktop.apply_actor_prototype_configuration(&"skimmer", &"policy", true), "prototype install before Water was refused")
	_expect(await _wait_model(desktop, &"skimmer", 3), "prototype install before Water did not acknowledge")
	var water: Dictionary = WaterProfiles.resolve({}, {}, {"scenario_id": "shallow-pool",
		"mass_bits": 5, "coherence_ticks": 7, "interface_mode": "oriented", "seed": 441})
	desktop.water_lab_apply_result(water)
	_expect(await _wait_for(func() -> bool:
		return desktop.pending_water_apply.is_empty() and desktop.tower_context.get("water_active", false)
	), "Water transition did not acknowledge")
	_expect(desktop.latest_snapshot.actor_prototypes.is_empty() and desktop.actor_model_selection == &"",
		"Water transition retained provisional session or UI identity")
	_expect(desktop.simulation_worker.queue_actor_prototype_reset(_definition(), SPAWN) == 0,
		"direct actor reset bypassed Water apparatus exclusion")
	desktop.queue_free()
	await process_frame


func _recorded_snapshot(actor: CyberSimulationSnapshot, material_actor: CyberSimulationSnapshot,
	serial: int, published_usec: int) -> CyberSimulationSnapshot:
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.serial = serial
	snapshot.published_usec = published_usec
	snapshot.tick_index = actor.tick_index
	snapshot.character_position = actor.character_position
	snapshot.character_velocity = actor.character_velocity
	snapshot.character_grounded = actor.character_grounded
	snapshot.character_runtime_recovery_enabled = false
	snapshot.player_representation = actor.player_representation
	snapshot.actor_prototypes = actor.actor_prototypes.duplicate(true)
	snapshot.lab_context = actor.lab_context.duplicate(true)
	snapshot.render_context = material_actor.lab_context.duplicate(true)
	snapshot.render_snapshot_serial = 1
	snapshot.render_tick_index = material_actor.tick_index
	snapshot.render_generated_usec = published_usec - serial * 20000
	snapshot.render_channels = 2
	snapshot.render_full_refresh = true
	snapshot.render_patch_rectangles = PackedInt32Array([10, 20, 2, 2, 0, 4])
	snapshot.render_patch_cells = PackedByteArray([1, 0, 2, 0, 3, 0, 4, 0])
	return snapshot


func _recording_actor_and_material_times() -> void:
	_expect(native_actor_snapshots.size() == 2, "native actor samples unavailable for recording regression")
	if native_actor_snapshots.size() != 2:
		return
	var recorder := Recorder.new()
	_expect(recorder.start_recording({"roi": Rect2i(10, 20, 2, 2), "capture_hz": 60,
		"queue_capacity": 4}, {"source": "actor-integration"}, false) == OK,
		"prototype recorder failed to start")
	var base_usec: int = Time.get_ticks_usec() + 100
	var first: CyberSimulationSnapshot = _recorded_snapshot(native_actor_snapshots[0], native_actor_snapshots[0], 1, base_usec)
	var second: CyberSimulationSnapshot = _recorded_snapshot(native_actor_snapshots[1], native_actor_snapshots[0], 2, base_usec + 20000)
	recorder.ingest_snapshot(first)
	recorder.ingest_snapshot(second)
	_expect(recorder._queue.size() == 2, "actor-only publication with retained material was not recorded")
	if recorder._queue.size() == 2:
		var metadata: Dictionary = recorder._queue[1].metadata
		_expect(recorder._queue[0].material_ids == recorder._queue[1].material_ids,
			"actor-only update rewrote retained material bytes")
		_expect(metadata.actor_sample.actor_prototypes == second.actor_prototypes,
			"recorder used stale material-generation actors as current observation")
		_expect(metadata.material_generation.actor_prototypes == first.actor_prototypes,
			"recorder relabelled material generation with newer actor context")
		_expect(int(metadata.actor_sample.completed_simulation_tick) == second.tick_index
			and int(metadata.material_generation.completed_simulation_tick) == first.tick_index,
			"recorder merged actor and material simulation times")
		_expect(not metadata.player.environment_profile_applied, "recorder claims baseline environment tuning controls prototype")
		var decoded: Variant = JSON.parse_string(JSON.stringify(metadata))
		_expect(decoded is Dictionary, "prototype recording metadata did not survive JSON round trip")
		if decoded is Dictionary:
			for context: Dictionary in [decoded.player.actor_prototype, decoded.actor_sample.actor_prototypes,
				decoded.material_generation.actor_prototypes]:
				_expect(context.states is Array and context.states.size() == 16,
					"JSON prototype observation is not a numeric 16-element array")
				_expect(context.sequences is Array and context.sequences.size() == 1
					and context.lease_remaining is Array and context.lease_remaining.size() == 1,
					"JSON prototype admission vectors are not usable arrays")
				_expect(context.capabilities[0].body_size is Array
					and context.capabilities[0].body_size.size() == 2
					and float(context.capabilities[0].body_size[0]) == 8.0
					and float(context.capabilities[0].body_size[1]) == 14.0,
					"JSON capability body size is not a two-element numeric array")
				for value: Variant in context.states:
					_expect((value is float or value is int) and is_finite(float(value)),
						"JSON prototype state contains a nonnumeric or nonfinite value")
		second.actor_prototypes.states[0] = -999.0
		_expect(metadata.actor_sample.actor_prototypes.states[0] != -999.0,
			"recorder metadata retained a mutable source alias")
	recorder.stop_recording()


func _run() -> void:
	_keyboard_edges_and_rearm()
	await _worker_owner_and_publication()
	await _owner_admission_race()
	await _ordinary_reset_supersedes_receipt()
	_recording_actor_and_material_times()
	await _desktop_selector_and_labs()
	print("ACTOR_INTEGRATION: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
