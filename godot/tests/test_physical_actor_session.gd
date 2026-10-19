extends SceneTree

# Real Rapier command/lifetime checks. Policy observations are issued separately
# from evaluator snapshots; cancellation invalidates pre-cancel capabilities.
const Session = preload("res://scripts/physical_actor_session.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Overlay = preload("res://scripts/physical_actor_overlay.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const DT: float = 1.0 / 60.0
var assertions: int = 0
var failures: int = 0
var owner: Node2D
var session: CyberPhysicalActorSession


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_SESSION: " + message)


func create(models: Array, producer: StringName = &"policy", epoch: int = 1) -> bool:
	session = Session.new()
	owner.add_child(session)
	var definitions: Array = []
	for index: int in range(models.size()):
		definitions.append({"model": models[index], "producer": producer,
			"position": Vector2(90 + index * 60, 90)})
	return session.configure(definitions, owner.get_world_2d().space, epoch)


func close() -> void:
	session.close()
	expect(not session.active() and session.bodies().is_empty(), "close retires every body")
	session.free()
	session = null


func step() -> void:
	session.advance(DT)
	session.bridge.step()
	session.complete_step()


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "real Rapier must be present")
	if failures:
		quit(1)
		return
	expect(not Session.valid_definitions([]), "empty physical owner refused")
	var invalid: Array = [{"model": &"runner", "producer": &"policy", "position": Vector2(NAN, 90)}]
	expect(not Session.valid_definitions(invalid), "nonfinite spawn refused")
	invalid[0].position = Vector2(90, 90)
	invalid[0].producer = "unknown"
	expect(not Session.valid_definitions(invalid), "unknown producer refused")
	invalid[0].producer = "policy"
	invalid[0].model = "unknown"
	expect(not Session.valid_definitions(invalid), "unknown rig refused")
	for action: Dictionary in [{"move": [INF, 0]}, {"aim": [1]}, {"primary": 1},
		{"primary": "false"}, {"effort": NAN}, {"move": [true, 0]}, {"torques": [1, 2]}]:
		expect(Session.normalized_action(action).is_empty(), "malformed action refused: " + str(action))
	var normalized: Dictionary = Session.normalized_action({"move": [3, 4], "effort": 2, "trim": -8, "tool": true})
	expect(normalized.move.is_equal_approx(Vector2(0.6, 0.8)) and normalized.effort == 1.0 \
		and normalized.trim == -1.0 and normalized.tool, "finite actions normalize at boundary")
	expect(create([&"gyrocrate", &"runner"]), "two-rig owner starts")
	if not session.active():
		quit(1)
		return
	# Evaluator-only data never mints an observation capability.
	var evaluation: Dictionary = session.snapshot()
	var command: Dictionary = Session.make_command(evaluation.actors[0], 0, {"move": [1, 0]}, 3)
	expect(not session.submit(command), "unissued evaluator view refused")
	var view: Dictionary = session.observation(0)
	var retained: Dictionary = view.duplicate(true)
	command = Session.make_command(view, 0, {"move": [1, 0], "trim": 0.5}, 3)
	expect(not session.submit(command, &"human"), "configured producer is exclusive")
	expect(session.submit(command), "issued policy command accepted")
	expect(not session.submit(command), "duplicate sequence refused")
	var mutations: Array = [
		{"version": 1}, {"kind": "wire_action"}, {"run_id": "other"}, {"actor_id": 1.5},
		{"actor_id": 99}, {"epoch": 2}, {"sequence": -1}, {"sequence": INF},
		{"sequence": 1.5}, {"observed_tick": 1}, {"lease_ticks": 19}, {"lease_ticks": 0},
		{"observation_id": "invented"}, {"action": {"primary": "false"}},
	]
	for change: Dictionary in mutations:
		var bad: Dictionary = Session.make_command(view, 1, {"move": [1, 0]}, 3)
		bad.merge(change, true)
		expect(not session.submit(bad), "packet mutation refused: " + str(change.keys()))
	var unknown: Dictionary = Session.make_command(view, 1, {"primary": true})
	unknown["privileged_reward"] = 1
	expect(not session.submit(unknown), "extra envelope field refused")
	for index: int in range(3):
		step()
	expect(session.snapshot().actors[0].lease_remaining == 0, "lease ends at source observation tick + duration")
	var before_expiry: Dictionary = session.observation(0)
	var cancellations: Array = []
	session.input_cancelled.connect(func(actor: int, actor_epoch: int) -> void:
		cancellations.append([actor, actor_epoch]))
	step()
	expect(session._commands[0].is_empty(), "expired action is neutralized")
	expect(cancellations == [[0, session.epoch]], "expiry notifies the host to revoke copied cellular work")
	expect(not session.submit(Session.make_command(before_expiry, 2, {"tool": true}, 18)),
		"a long lease cannot revive a pre-expiry observation capability")
	expect(view == retained, "later ticks do not mutate retained observation")
	expect(not session.submit(Session.make_command(view, 2, {"move": [1, 0]}, 3)), "expired source view refused")
	view = session.observation(0)
	var before_cancel: Dictionary = Session.make_command(view, 3, {"primary": true})
	expect(session.cancel_input(0, session.epoch, &"policy"), "cancel admitted")
	expect(not session.submit(before_cancel), "cancel invalidates delayed pre-cancel command")
	var fresh: Dictionary = session.observation(0)
	expect(fresh.observation_id != view.observation_id and fresh.tick == view.tick,
		"same-tick cancellation creates a fresh control generation")
	expect(session.submit(Session.make_command(fresh, 3, {"move": [-1, 0]})), "fresh post-cancel command admitted")
	session.set_suspended(true)
	var stopped_tick: int = session.tick
	session.advance(DT)
	session.complete_step()
	expect(session.tick == stopped_tick and session._commands[0].is_empty(), "suspension clears input and holds controller clock")
	expect(not session.submit(Session.make_command(fresh, 4, {"primary": true})), "suspended owner refuses commands")
	session.set_suspended(false)
	expect(not session.submit(Session.make_command(fresh, 4, {"primary": true})), "resume cannot revive pre-pause command")
	# A short press/release between physics callbacks survives as two ordered
	# samples. Analog targets still use the latest accepted command.
	expect(session.submit_local(0, {"primary": true, "move": Vector2.RIGHT}, &"policy"), "press admitted")
	expect(session.submit_local(0, {"primary": false, "move": Vector2.LEFT}, &"policy"), "same-frame release admitted")
	step()
	expect(session._applied_buttons[0].primary and session._button_edges[0].size() == 1,
		"first physical sample preserves short press")
	step()
	expect(not session._applied_buttons[0].primary and session._button_edges[0].is_empty(),
		"second physical sample consumes release")
	for index: int in range(Session.MAX_BUTTON_EDGES):
		expect(session.submit_local(0, {"tool": index % 2 == 0}, &"policy"), "bounded edge burst admitted")
	expect(not session.submit_local(0, {"tool": true}, &"policy"), "edge overflow explicitly refused")
	session.cancel_input(0, session.epoch, &"policy")
	step()
	expect(session._button_edges[0].is_empty() and session.drain_effects().is_empty(),
		"cancel discards queued presses without running them")
	# Every drawn polygon is the actual rectangle shape at its Rapier transform.
	var overlay = Overlay.new()
	root.add_child(overlay)
	var rendered: Array = session.render_parts()
	overlay.present(rendered, Vector2.ZERO, Vector2i(256, 128), Rect2(0, 0, 512, 256))
	for index: int in range(rendered.size()):
		var body: RigidBody2D = session.bodies()[index]
		var shape: RectangleShape2D = body.get_child(0).shape
		var transform: Transform2D = session.bridge.body_transform(index)
		var vertices: PackedVector2Array = overlay.polygon(rendered[index])
		expect(rendered[index].size == shape.size and vertices.size() == 4, "one visible polygon per actual collider")
		expect(vertices[0].is_equal_approx((transform * (-shape.size * 0.5)) * 2.0), "screen geometry matches physical vertex")
	overlay.free()
	# A quarantined rig must not appear controllable through the session wrapper.
	# Inject the owner's fault outcome without asking Rapier to integrate NaNs.
	expect(session.submit_local(0, {"tool": true}, &"policy"), "pre-fault command admitted")
	var pre_fault: Dictionary = session.observation(0)
	var accepted_before_fault: int = session.accepted_commands
	session._rigs[0].fault = "injected actor quarantine"
	for body: RigidBody2D in session._rigs[0].bodies():
		body.freeze = true
	var faulted_view: Dictionary = session.observation(0)
	expect(faulted_view.suspended and faulted_view.fault == "injected actor quarantine"
		and faulted_view.lease_remaining == 0, "fault suspension survives the copied session view")
	expect(not session.submit(Session.make_command(pre_fault, int(pre_fault.last_sequence) + 1, {"primary": true}))
		and session.last_error == "actor_fault", "previously issued capability gets explicit actor_fault refusal")
	expect(not session.submit_local(0, {"tool": true}, &"policy") and session.last_error == "actor_fault",
		"fresh faulty view cannot mint command authority")
	expect(session.accepted_commands == accepted_before_fault, "fault refusals never count as accepted actions")
	session._effects.append({"actor_slot": 0})
	session._effects.append({"actor_slot": 1})
	var cancellation_count: int = cancellations.size()
	session.complete_step()
	expect(session._commands[0].is_empty() and session._button_edges[0].is_empty(),
		"quarantine retires previously accepted input")
	expect(cancellations.size() == cancellation_count + 1 and cancellations[-1] == [0, session.epoch],
		"quarantine notifies the host to revoke the faulted actor's copied effects")
	var surviving_effects: Array = session.drain_effects()
	expect(surviving_effects.size() == 1 and int(surviving_effects[0].actor_slot) == 1,
		"fault retirement preserves another actor's pending effect")
	expect(not session.observation(1).suspended and session.submit_local(1, {"move": Vector2.RIGHT}, &"policy"),
		"another actor retains command authority after peer quarantine")
	var old: Dictionary = Session.make_command(session.observation(0), 5, {"primary": true})
	close()
	await process_frame
	expect(create([&"gyrocrate"], &"policy", 2), "replacement owner starts")
	expect(not session.submit(old), "reset cannot accept earlier run/epoch command")
	close()
	await process_frame
	# Eight maximum-size catalogue actors use the complete 64-body budget.
	var largest: StringName = &"runner"
	for model: StringName in Catalog.RIG_IDS:
		if Equipment.definition(Catalog.entry(model)).parts.size() > Equipment.definition(Catalog.entry(largest)).parts.size():
			largest = model
	var roster: Array = []
	roster.resize(8)
	roster.fill(largest)
	expect(create(roster, &"demo", 3), "eight maximal actors admitted")
	expect(session.bodies().size() == Equipment.definition(Catalog.entry(largest)).parts.size() * 8 \
		and session.bodies().size() <= 64, "session flattens all bodies within 64 identities")
	close()
	await process_frame
	roster.append(largest)
	expect(not create(roster), "ninth actor refused before allocation")
	expect(session.bodies().is_empty(), "refusal leaves no partial assembly")
	close()
	owner.free()
	await process_frame
	print("Physical actor session: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
