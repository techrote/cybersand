extends SceneTree

# 4LY-001 actual-owner conformance. No training or four-profile handling
# qualification is implied. Every test uses the real Rapier-backed session.
const Session = preload("res://scripts/physical_actor_session.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
const Overlay = preload("res://scripts/physical_actor_overlay.gd")
const DT: float = 1.0 / 60.0
var assertions: int = 0
var failures: int = 0
var owner: Node2D
var session: CyberPhysicalActorSession


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("4LY_SESSION: " + message)


func create(model: StringName = &"4ly_trainer", producer: StringName = &"policy", incarnation: int = 1) -> bool:
	session = Session.new()
	owner.add_child(session)
	return session.configure([{"model": model, "producer": producer,
		"position": Vector2(400, 400)}], owner.get_world_2d().space, incarnation)


func close_fixture() -> void:
	if is_instance_valid(session):
		session.close()
		expect(not session.active() and session.bodies().is_empty(), "close retires the actual body")
		session.free()
		session = null
	await process_frame


func step() -> Dictionary:
	session.advance(DT)
	session.bridge.step()
	session.complete_step()
	return session.observation(0)


func velocity() -> Vector2:
	return PhysicsServer2D.body_get_state(session.bodies()[0].get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)


func test_topology() -> void:
	expect(Catalog.RIG_IDS.size() == 46 and Catalog.SET_IDS[-1] == &"set4LY"
		and Catalog.rigs_in_set(&"set4LY") == Profile.IDS,
		"4LY selection is appended without renumbering the retained 46 actor identities/sets")
	for model: StringName in Profile.IDS:
		var base: Dictionary = Catalog.entry(model)
		var loadout: Dictionary = Loadouts.entry(model)
		var prepared: Dictionary = Equipment.definition(base, loadout)
		expect(not base.is_empty() and not loadout.is_empty() and not prepared.is_empty(), str(model) + " resolves explicit chassis/loadout")
		expect(base.parts.size() == 1 and base.joints.is_empty() and base.mounts.is_empty(), str(model) + " is one real rigid chassis")
		expect(prepared.parts.size() == 1 and prepared.joints.is_empty() and prepared.mounts.is_empty(), str(model) + " equipment preparation cannot add training mass")
		expect(int(loadout.usable_index) == -1, str(model) + " has an explicitly empty default loadout")
		expect(create(model), str(model) + " session configuration")
		if not session.active():
			await close_fixture()
			continue
		var view: Dictionary = session.observation(0)
		expect(session.bodies().size() == 1 and int(view.part_count) == 1, str(model) + " actual one-body topology")
		expect(view.equipment.get("preparation") == "none" and not bool(view.equipment.get("available", true))
			and int(view.equipment.get("body_id", -1)) == 0 and not view.equipment.has("instance_id"),
			str(model) + " explicitly exposes unavailable equipment without a fictitious instance")
		expect(view.action_profile == Profile.ACTION_PROFILE and view.flight.mode == "passive_no_lease",
			str(model) + " publishes the declared action interpretation and passive starting mode")
		var identity: Dictionary = view.flight.capabilities
		expect(str(identity.profile_hash).length() == 64 and identity.profile_hash == Profile.profile_hash(Profile.entry(model))
			and str(identity.controller_hash).length() == 64, str(model) + " publishes resolved profile/controller hashes")
		identity.collider_size[0] = 64.0
		identity.profile_hash = "changed consumer copy"
		var untouched: Dictionary = session.observation(0).flight.capabilities
		expect(is_equal_approx(float(untouched.collider_size[0]), float(Profile.entry(model).collider_size[0]))
			and str(untouched.profile_hash).length() == 64,
			str(model) + " capabilities are deep copies")
		var body: RigidBody2D = session.bodies()[0]
		var shape: RectangleShape2D = body.get_child(0).shape
		var p: Dictionary = Profile.entry(model)
		expect(is_equal_approx(body.mass, float(p.mass)) and is_equal_approx(body.inertia, float(p.inertia)), str(model) + " actual mass/inertia match resolved profile")
		expect(shape.size.is_equal_approx(Vector2(float(p.collider_size[0]), float(p.collider_size[1]))), str(model) + " collider matches profile dimensions")
		var rendered: Array = session.render_parts()
		var overlay = Overlay.new()
		owner.add_child(overlay)
		overlay.present(rendered, Vector2.ZERO, Vector2i(1024, 1024), Rect2(0, 0, 1024, 1024))
		var polygon: PackedVector2Array = overlay.polygon(rendered[0])
		var pose: Transform2D = session.bridge.body_transform(0)
		expect(rendered.size() == 1 and rendered[0].size == shape.size and polygon.size() == 4,
			str(model) + " one rendered rectangle per physical collider")
		expect(polygon[0].distance_to(pose * (-shape.size * 0.5)) < 0.001, str(model) + " drawing uses published physical pose")
		overlay.free()
		await close_fixture()
	var bad: Array = [{"model": &"4ly_trainer", "producer": &"policy", "position": Vector2(400, 400), "usable_index": 0}]
	expect(not Session.valid_definitions(bad), "equipment override cannot silently alter the training topology")
	bad[0].usable_index = -1
	bad[0].position = Vector2(NAN, 1)
	expect(not Session.valid_definitions(bad), "nonfinite spawn refused before allocation")
	for mutation: String in ["nonfinite_profile", "profile_identity", "extra_equipment", "mass_mismatch", "inertia_mismatch", "gravity_mismatch", "drag_mismatch", "friction_mismatch"]:
		var definition: Dictionary = Catalog.entry(&"4ly_trainer")
		match mutation:
			"nonfinite_profile":
				definition.flight_profile.max_force = NAN
			"profile_identity":
				definition.flight_profile.id = "4ly_dart"
			"extra_equipment":
				definition.equipment_preparation = "mounted"
			"mass_mismatch":
				definition.parts[0].mass = 2.0
			"inertia_mismatch":
				definition.parts[0].inertia = 20.0
			"gravity_mismatch":
				definition.profile.gravity = 155.0
			"drag_mismatch":
				definition.profile.air_drag = 0.2
			"friction_mismatch":
				definition.parts[0].friction = 0.1
		expect(not Rig.validate_definition(definition).is_empty(), "unresolved profile/chassis mismatch refused: " + mutation)


func test_action_schema() -> void:
	for action: Variant in [null, {}, {"move": [NAN, 0]}, {"move": [INF, 0]}, {"move": [true, 0]},
		{"move": [0]}, {"move": [0, 0, 0]}, {"move": [1.01, 0]}, {"move": [-1.01, 0]},
		{"move": [1.0000000001, 0]},
		{"move": Vector2(0, -INF)}, {"move": [0, 0], "primary": false},
		{"move": [0, 0], "effort": 1.0}, {"move": [0, 0], "goal": [100, 100]},
		{"move": [0, 0], "equipment": {}}, {"aim": [0, 0]}]:
		expect(Session.normalized_flight_action(action).is_empty(), "invalid or extra flight action field refused: " + str(action))
	var action: Dictionary = Session.normalized_flight_action({"move": [1, 1]})
	expect(not action.is_empty() and action.move.is_equal_approx(Vector2.ONE.normalized()), "diagonal request maps to the declared unit disk")
	var neutral: Dictionary = Session.normalized_flight_action({"move": Vector2.ZERO})
	expect(not neutral.is_empty() and neutral.move == Vector2.ZERO, "explicit zero is authorized neutral, not an absent action")
	# The new strict profile must not silently change the retained v2 envelope's
	# normalization rules for pre-existing actors.
	var legacy: Dictionary = Session.normalized_action({"move": [3, 4], "effort": 2, "trim": -8})
	expect(legacy.move.is_equal_approx(Vector2(0.6, 0.8)) and legacy.effort == 1.0 and legacy.trim == -1.0,
		"legacy vector/scalar clamps retain their original interpretation")


func test_project_gravity_mapping() -> void:
	# A positive project gravity below one is valid. The flight scale must
	# resolve to the declared acceleration even in that host configuration.
	var setting: String = "physics/2d/default_gravity"
	var original: Variant = ProjectSettings.get_setting(setting)
	ProjectSettings.set_setting(setting, 0.5)
	expect(create(), "positive sub-unit project gravity configures")
	if session.active():
		var profile: Dictionary = Profile.entry(&"4ly_trainer")
		var body: RigidBody2D = session.bodies()[0]
		expect(is_equal_approx(body.gravity_scale * 0.5, float(profile.gravity)),
			"actual body gravity scale resolves the complete declared acceleration")
	await close_fixture()
	ProjectSettings.set_setting(setting, original)
	# These are finite GDScript doubles, but overflow or underflow the backend's
	# real_t. Refuse them before allocating a body; never step this environment.
	for unsupported: float in [1.0e40, 1.0e-50]:
		ProjectSettings.set_setting(setting, unsupported)
		var configured: bool = create()
		ProjectSettings.set_setting(setting, original)
		expect(not configured, "backend-unrepresentable project gravity is refused: " + str(unsupported))
		expect(not session.active() and session.bodies().is_empty(),
			"unrepresentable gravity allocates no live physical body")
		await close_fixture()


func test_fences() -> void:
	expect(create(), "Trainer policy owner starts")
	if not session.active():
		await close_fixture()
		return
	var evaluator: Dictionary = session.snapshot().actors[0]
	expect(not session.submit(Session.make_command(evaluator, 0, {"move": Vector2.RIGHT}, 3)), "evaluator view does not mint action authority")
	var view: Dictionary = session.observation(0)
	var retained: Dictionary = view.duplicate(true)
	var original: Dictionary = {"move": [1.0, 1.0]}
	var command: Dictionary = Session.make_command(view, 0, original, 3)
	original.move[0] = -1.0
	expect(not session.submit(command, &"human"), "wrong producer cannot take over an issued policy observation")
	expect(session.submit(command), "two-output policy request admitted")
	command.action.move[0] = -1.0
	expect(session._commands[0].move.is_equal_approx(Vector2.ONE.normalized()), "admitted command owns a normalized copy")
	var receipt: Dictionary = session.observation(0).flight.command
	expect(receipt.requested_action.move == [1.0, 1.0]
		and receipt.admitted_action.move.is_equal_approx(Vector2.ONE.normalized()),
		"requested diagonal and normalized admission remain distinguishable")
	expect(int(receipt.sequence) == 0 and int(receipt.observed_tick) == 0 and int(receipt.admitted_tick) == 0,
		"command receipt preserves source, sequence and admission time")
	receipt.requested_action.move[0] = -1.0
	expect(session.observation(0).flight.command.requested_action.move == [1.0, 1.0], "command receipt is a deep copy")
	expect(not session.submit(Session.make_command(view, 0, {"move": Vector2.ZERO}, 3)), "duplicate sequence refused")
	for change: Dictionary in [{"version": 1}, {"kind": "wire_action"}, {"run_id": "other"},
		{"actor_id": 1}, {"actor_id": 0.5}, {"epoch": 2}, {"epoch": INF}, {"sequence": 1.5},
		{"sequence": NAN}, {"sequence": -1}, {"observed_tick": 1}, {"observed_tick": -1},
		{"lease_ticks": 0}, {"lease_ticks": 19}, {"lease_ticks": 1.5}, {"observation_id": "invented"},
		{"action": {"move": [0, 0], "trim": 0.0}}, {"action": {"move": [0, INF]}}]:
		var bad: Dictionary = Session.make_command(view, 1, {"move": Vector2.ZERO}, 3)
		bad.merge(change, true)
		expect(not session.submit(bad), "invalid flight envelope refused: " + str(change.keys()))
	var extra: Dictionary = Session.make_command(view, 1, {"move": Vector2.ZERO}, 3)
	extra["goal"] = Vector2(500, 500)
	expect(not session.submit(extra), "goal cannot enter the action envelope")
	var cancellations: Array = []
	session.input_cancelled.connect(func(actor_id: int, epoch: int) -> void: cancellations.append([actor_id, epoch]))
	var before_expiry: Dictionary = {}
	for _tick: int in range(3):
		step()
		if _tick == 1:
			before_expiry = session.observation(0)
	var applied: Dictionary = session.observation(0).flight.last_step
	expect(int(applied.sequence) == 0 and int(applied.step_tick) == 2, "applied receipt identifies the consumed command and actuator tick")
	expect(session.observation(0).lease_remaining == 0, "lease duration is measured from the source observation")
	expect(session.observation(0).flight.applied.is_empty() and session.observation(0).flight.command.is_empty(),
		"completion revokes current authority exactly at the lease boundary")
	expect(not session.submit(Session.make_command(before_expiry, 2, {"move": Vector2.UP}, 18)),
		"deadline boundary has no gap in which an earlier observation can renew authority")
	var before_expiry_velocity: Vector2 = velocity()
	session.advance(DT)
	expect(session._commands[0].is_empty(), "expiry clears the admitted target before the next actuator step")
	expect(velocity().is_equal_approx(before_expiry_velocity), "expiry supplies no impulse and does not delete physical momentum")
	var expired: Dictionary = session.observation(0).flight
	expect(expired.mode == "passive_no_lease" and expired.command.is_empty() and expired.applied.is_empty()
		and expired.controller.applied_force == Vector2.ZERO and float(expired.controller.applied_torque) == 0.0,
		"expiry publishes passive fallback, zero assistance, and no fresh external command")
	expect(cancellations == [[0, session.epoch]], "expiry revokes copied host work exactly once")
	expect(not session.submit(Session.make_command(before_expiry, 2, {"move": Vector2.UP}, 18)),
		"longer lease cannot revive a capability minted before expiry")
	session.bridge.step()
	session.complete_step()
	expect(view == retained, "later admission and simulation cannot mutate a retained copied view")
	expect(not session.submit(Session.make_command(view, 2, {"move": Vector2.ZERO}, 3)), "expired source view refused")
	view = session.observation(0)
	expect(session.submit(Session.make_command(view, 2, {"move": Vector2.RIGHT}, 12)), "fresh post-expiry action admitted")
	step()
	var delayed: Dictionary = Session.make_command(session.observation(0), 3, {"move": Vector2.UP}, 18)
	var moving: Vector2 = velocity()
	expect(session.cancel_input(0, session.epoch, &"policy"), "producer cancellation admitted")
	expect(velocity().is_equal_approx(moving), "cancellation preserves actual momentum without stepping")
	expect(not session.submit(delayed), "same-tick cancellation fences a delayed reply")
	expect(session.observation(0).action.is_empty(), "same-tick cancellation exposes no current external command")
	expect(session.observation(0).flight.controller.applied_force == Vector2.ZERO,
		"cancel clears the thrust response state immediately")
	expect(not session.observation(0).flight.last_step.is_empty(),
		"cancellation preserves a labelled historical receipt without representing it as current assistance")
	var fresh: Dictionary = session.observation(0)
	expect(session.submit(Session.make_command(fresh, 3, {"move": Vector2.ZERO}, 12)), "fresh neutral command admitted after cancellation")
	step()
	var pre_pause: Dictionary = session.observation(0)
	var paused_tick: int = session.tick
	moving = velocity()
	session.set_suspended(true)
	session.advance(DT)
	session.complete_step()
	expect(session.tick == paused_tick and session._commands[0].is_empty(), "pause holds the clock and clears command history")
	var during_pause: Dictionary = session.observation(0)
	expect(during_pause.flight.mode == "suspended", "lifecycle suspension is distinguishable from neutral or power-off")
	expect(velocity().is_equal_approx(moving), "pause does not erase physical velocity")
	expect(not session.submit(Session.make_command(pre_pause, 4, {"move": Vector2.RIGHT})), "suspended owner refuses delayed input")
	session.set_suspended(false)
	expect(not session.submit(Session.make_command(pre_pause, 4, {"move": Vector2.RIGHT})), "resume cannot renew a pre-pause lease")
	expect(not session.submit(Session.make_command(during_pause, 4, {"move": Vector2.RIGHT})),
		"a view obtained during suspension cannot acquire authority after resume")
	var old: Dictionary = Session.make_command(session.observation(0), 5, {"move": Vector2.RIGHT}, 18)
	var old_run: String = session.run_id
	await close_fixture()
	expect(create(&"4ly_trainer", &"human", 2), "replacement human owner starts")
	if session.active():
		expect(session.run_id != old_run and session.epoch == 2, "replacement has a fresh run and actor epoch")
		expect(not session.submit(old) and not session.submit(old, &"human"), "late policy reply cannot affect a replacement or new producer")
		expect(session.observation(0).action.is_empty() and velocity() == Vector2.ZERO, "replacement starts with empty command history and new physical initial state")
		expect(session.observation(0).flight.controller.applied_force == Vector2.ZERO
			and session.observation(0).flight.controller.applied_torque == 0.0
			and session.observation(0).flight.controller.requested_move == Vector2.ZERO
			and session.observation(0).flight.last_step.is_empty(),
			"replacement clears response filters and controller command history")
		expect(session.submit_local(0, {"move": Vector2.ZERO}, &"human"), "new human owner reaches the same admitted neutral path")
		step()
		expect(Vector2(session.observation(0).flight.controller.applied_force).length() <= 40.001,
			"fresh reset replays bounded thrust spool-up from zero")
	await close_fixture()


func test_takeover_and_power() -> void:
	expect(create(), "takeover fixture configures")
	if not session.active():
		await close_fixture()
		return
	expect(session.submit_local(0, {"move": Vector2.RIGHT}, &"policy", 12), "policy movement accepted before takeover")
	step()
	var old: Dictionary = Session.make_command(session.observation(0), 1, {"move": Vector2.UP}, 18)
	var moving: Vector2 = velocity()
	expect(not session.takeover(0, session.epoch + 1, &"human"), "wrong-epoch takeover refused")
	expect(not session.takeover(0, session.epoch, &"unknown"), "unknown takeover producer refused")
	expect(session.takeover(0, session.epoch, &"human"), "host may transfer the live actor to a human")
	expect(velocity().is_equal_approx(moving), "source takeover preserves the live body's momentum")
	expect(not session.submit(old) and not session.submit(old, &"human"), "takeover invalidates pre-takeover observations even for the new source")
	expect(session.observation(0).producer == "human" and session.observation(0).flight.command.is_empty(),
		"takeover publishes new ownership without stale command attribution")
	expect(session.submit_local(0, {"move": Vector2.ZERO}, &"human", 12), "new source can command authorized neutral")
	step()
	var neutral: Dictionary = session.observation(0)
	expect(neutral.flight.mode == "neutral" and Vector2(neutral.flight.controller.applied_force).length() > 0.0,
		"authorized zero input supplies bounded assistance")
	old = Session.make_command(neutral, int(neutral.last_sequence) + 1, {"move": Vector2.UP}, 18)
	moving = velocity()
	expect(session.set_propulsion_enabled(0, false), "host explicitly disables propulsion")
	expect(velocity().is_equal_approx(moving), "power-off transition does not erase momentum")
	expect(not session.submit(old, &"human"), "power transition fences delayed pre-transition input")
	expect(session.submit_local(0, {"move": Vector2.UP}, &"human", 12), "request can be admitted while propulsion is explicitly disabled")
	step()
	var off: Dictionary = session.observation(0)
	expect(off.flight.mode == "power_off" and off.flight.controller.applied_force == Vector2.ZERO
		and off.flight.controller.applied_torque == 0.0, "power-off reports live request separately from zero applied assistance")
	expect(not off.flight.command.is_empty() and off.flight.controller.desired_velocity.y < 0.0,
		"power-off preserves truthful current request diagnostics")
	old = Session.make_command(off, int(off.last_sequence) + 1, {"move": Vector2.UP}, 18)
	expect(session.set_propulsion_enabled(0, true), "host can restore propulsion")
	expect(session.observation(0).flight.command.is_empty() and not session.submit(old, &"human"),
		"power restoration requires fresh source authority")
	var after_enable: Vector2 = velocity()
	session.advance(DT)
	expect(velocity().is_equal_approx(after_enable) and session.observation(0).flight.mode == "passive_no_lease",
		"restoring power does not manufacture a hover command")
	await close_fixture()


func test_producer_path_and_cadence() -> void:
	for producer: StringName in [&"human", &"policy", &"demo"]:
		expect(create(&"4ly_trainer", producer), str(producer) + " producer session configures")
		if not session.active():
			await close_fixture()
			continue
		expect(session.submit_local(0, {"move": Vector2.RIGHT}, producer, 12), str(producer) + " uses the same local-to-envelope admission")
		var view: Dictionary = step()
		var accepted: Dictionary = view.flight.command
		expect(not accepted.is_empty() and accepted.admitted_action.size() == 1 and accepted.admitted_action.has("move"),
			str(producer) + " publishes exactly the two-output action")
		expect(view.flight.controller.admitted_move.is_equal_approx(accepted.admitted_action.move)
			and int(view.flight.applied.sequence) == int(accepted.sequence), str(producer) + " reaches the same actuator and receipt path")
		if producer == &"demo":
			expect(session.accepted_commands >= 2, "scripted producer actually passes through admission at tick zero")
		var before: Vector2 = velocity()
		var stale: Dictionary = Session.make_command(view, int(view.last_sequence) + 1, {"move": Vector2.LEFT}, 18)
		session.advance(DT * 2.0)
		expect(velocity().is_equal_approx(before) and session._commands[0].is_empty(), "wrong control cadence refuses actuation and cancels old target")
		expect(not session.submit(stale, producer), "wrong cadence fences its previously issued observation")
		await close_fixture()


func test_fault_attribution() -> void:
	expect(create(), "fault-attribution fixture configures")
	if not session.active():
		await close_fixture()
		return
	expect(session.submit_local(0, {"move": Vector2.RIGHT}, &"policy", 12), "fault fixture has a live command")
	var before: Dictionary = step()
	expect(Vector2(before.flight.controller.applied_force).length() > 0.0, "fault fixture has nonzero assistance to revoke")
	var delayed: Dictionary = Session.make_command(before, int(before.last_sequence) + 1, {"move": Vector2.RIGHT}, 18)
	# Inject the quarantine outcome, never nonfinite state into the native solver.
	session._rigs[0].fault = "injected 4LY quarantine"
	session.bodies()[0].freeze = true
	session.advance(DT)
	var faulted: Dictionary = session.observation(0)
	expect(faulted.suspended and faulted.flight.mode == "suspended" and faulted.lease_remaining == 0,
		"fault publishes suspension rather than active neutral")
	expect(not faulted.flight.command_live and faulted.flight.command.is_empty() and faulted.flight.applied.is_empty(),
		"fault revokes command and current applied attribution")
	expect(faulted.action.is_empty() and faulted.flight.controller.applied_force == Vector2.ZERO
		and faulted.flight.controller.applied_torque == 0.0
		and faulted.flight.controller.desired_velocity == Vector2.ZERO,
		"fault diagnostics cannot masquerade as the previous fresh command or assistance")
	expect(not faulted.flight.last_step.is_empty() and int(faulted.flight.last_step.sequence) == int(before.last_sequence),
		"fault preserves the separately labelled last completed actuator receipt")
	expect(not session.submit(delayed) and session.last_error == "actor_fault", "faulted actor refuses a delayed policy reply")
	await close_fixture()


func test_physics_step_attribution() -> void:
	expect(create(), "duplicate-advance fixture configures")
	if not session.active():
		await close_fixture()
		return
	expect(session.submit_local(0, {"move": Vector2.ZERO}, &"policy", 12), "neutral command precedes preparation")
	session.advance(DT)
	var prepared: Dictionary = session.observation(0).flight.controller
	var first_force: Vector2 = PhysicsServer2D.body_get_constant_force(session.bodies()[0].get_rid())
	session.advance(DT)
	expect(session.tick == 0 and session.bridge.manual_step_count() == 0,
		"actuator preparation cannot itself advance physical or session time")
	expect(session.observation(0).flight.controller == prepared
		and PhysicsServer2D.body_get_constant_force(session.bodies()[0].get_rid()).is_equal_approx(first_force),
		"duplicate advance cannot spool a second actuator interval before one physical step")
	expect(session.observation(0).flight.last_step.is_empty(), "preparation is not a completed physical receipt")
	session.bridge.step()
	session.complete_step()
	var completed: Dictionary = session.observation(0).flight.last_step
	expect(session.tick == 1 and session.bridge.manual_step_count() == 1
		and int(completed.get("sequence", -1)) == 0 and int(completed.get("step_tick", -1)) == 0,
		"one actual Rapier step commits one matching actuator receipt")
	session.complete_step()
	expect(session.tick == 1 and session.observation(0).flight.last_step == completed,
		"duplicate completion cannot age a lease or manufacture a second step")
	await close_fixture()

	expect(create(), "completion-without-physics fixture configures")
	if not session.active():
		await close_fixture()
		return
	expect(session.submit_local(0, {"move": Vector2.ZERO}, &"policy", 12), "no-step fixture admits neutral")
	session.advance(DT)
	session.complete_step()
	expect(session.tick == 0 and session.bridge.manual_step_count() == 0
		and session.observation(0).flight.last_step.is_empty(),
		"completion without an actual bridge step cannot claim assistance was consumed")
	await close_fixture()

	expect(create(), "pre-step cancellation fixture configures")
	if not session.active():
		await close_fixture()
		return
	expect(session.submit_local(0, {"move": Vector2.RIGHT}, &"policy", 12), "pre-step fixture admits movement")
	session.advance(DT)
	expect(PhysicsServer2D.body_get_constant_force(session.bodies()[0].get_rid()).length() > 0.0,
		"real force channel contains a prepared force before cancellation")
	var before: Vector2 = velocity()
	expect(session.cancel_input(0, session.epoch, &"policy"), "pre-step cancellation accepted")
	expect(PhysicsServer2D.body_get_constant_force(session.bodies()[0].get_rid()) == Vector2.ZERO
		and velocity().is_equal_approx(before), "pre-step cancellation removes only future assistance")
	session.bridge.step()
	session.complete_step()
	expect(session.observation(0).flight.last_step.is_empty() and absf(velocity().x) < 0.0001,
		"cancelled preparation never becomes a consumed receipt or horizontal impulse")
	await close_fixture()

	expect(create(), "post-step cancellation fixture configures")
	if not session.active():
		await close_fixture()
		return
	expect(session.submit_local(0, {"move": Vector2.RIGHT}, &"policy", 12), "post-step fixture admits movement")
	var source: Dictionary = session.observation(0)
	session.advance(DT)
	prepared = session.observation(0).flight.controller
	session.bridge.step()
	before = velocity()
	expect(before.x > 0.0, "actual Rapier consumed the prepared horizontal force")
	expect(session.cancel_input(0, session.epoch, &"policy"), "post-step cancellation accepted")
	expect(velocity().is_equal_approx(before), "post-step cancellation preserves consumed physical momentum")
	expect(session.takeover(0, session.epoch, &"human"), "new producer can take over before prior step bookkeeping")
	session.complete_step()
	completed = session.observation(0).flight.last_step
	expect(int(completed.get("sequence", -1)) == 0 and int(completed.get("step_tick", -1)) == 0
		and completed.get("controller", {}) == prepared
		and completed.get("action", {}).get("move") == Vector2.RIGHT,
		"post-step cancellation retains the exact historical receipt already consumed")
	expect(completed.get("run_id") == source.run_id and int(completed.get("epoch", -1)) == int(source.epoch)
		and int(completed.get("actor_id", -1)) == 0 and completed.get("producer") == "policy"
		and int(completed.get("control_generation", -1)) == int(source.control_generation)
		and int(completed.get("observed_tick", -1)) == 0 and int(completed.get("physics_step", -1)) == 1
		and session.observation(0).producer == "human"
		and int(session.observation(0).control_generation) > int(source.control_generation),
		"consumed receipt retains the former producer and generation after ownership changes")
	expect(session.observation(0).flight.command.is_empty() and session.observation(0).flight.applied.is_empty()
		and session.observation(0).flight.controller.applied_force == Vector2.ZERO,
		"historical consumption cannot masquerade as ongoing authority after cancellation")
	await close_fixture()

	expect(create(), "new-admission-before-completion fixture configures")
	if not session.active():
		await close_fixture()
		return
	expect(session.submit_local(0, {"move": Vector2.RIGHT}, &"policy", 12), "first command admits right movement")
	session.advance(DT)
	prepared = session.observation(0).flight.controller
	expect(session.submit_local(0, {"move": Vector2.UP}, &"policy", 12), "new command admits before prior physical completion")
	var admitted: Dictionary = session.observation(0).flight.command
	expect(int(admitted.sequence) == 1 and admitted.admitted_action.move == Vector2.UP,
		"latest admission is explicitly distinct from already prepared assistance")
	session.bridge.step()
	session.complete_step()
	completed = session.observation(0).flight.last_step
	expect(int(completed.get("sequence", -1)) == 0 and completed.get("controller", {}) == prepared
		and completed.get("action", {}).get("move") == Vector2.RIGHT,
		"later admission cannot rewrite the prior consumed command or controller receipt")
	step()
	completed = session.observation(0).flight.last_step
	expect(int(completed.get("sequence", -1)) == 1 and completed.get("action", {}).get("move") == Vector2.UP,
		"next actual step consumes the later admitted command")
	await close_fixture()


func test_step_order_faults() -> void:
	for mutation: String in ["unprepared", "extra_step", "uncompleted", "suspended"]:
		expect(create(), mutation + " step-order fixture configures")
		if not session.active():
			await close_fixture()
			continue
		expect(session.submit_local(0, {"move": Vector2.RIGHT}, &"policy", 12), mutation + " admits an initial command")
		if mutation != "unprepared":
			session.advance(DT)
		if mutation == "suspended":
			session.set_suspended(true)
		session.bridge.step()
		if mutation == "extra_step":
			session.bridge.step()
		if mutation == "uncompleted":
			session.advance(DT)
		else:
			session.complete_step()
		var faulted: Dictionary = session.observation(0)
		expect(faulted.suspended and faulted.flight.mode == "suspended" and not str(faulted.flight.step_fault).is_empty(),
			mutation + " physical/order mismatch is explicitly quarantined")
		expect(not faulted.flight.command_live and faulted.flight.command.is_empty() and faulted.flight.applied.is_empty()
			and PhysicsServer2D.body_get_constant_force(session.bodies()[0].get_rid()) == Vector2.ZERO,
			mutation + " mismatch revokes future force and current attribution")
		session.set_suspended(false)
		expect(session.observation(0).suspended and not session.submit_local(0, {"move": Vector2.ZERO}, &"policy"),
			mutation + " step fault cannot be reset by ordinary resume or a new command")
		await close_fixture()


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "pinned actual Rapier backend is required")
	if failures == 0:
		test_action_schema()
		await test_topology()
		await test_project_gravity_mapping()
		await test_fences()
		await test_takeover_and_power()
		await test_producer_path_and_cadence()
		await test_fault_attribution()
		await test_physics_step_attribution()
		await test_step_order_faults()
	owner.free()
	await process_frame
	print("4LY physical flight session: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
