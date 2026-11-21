extends SceneTree

# Genuine Rapier assemblies and production Workbench producer API. Native terrain
# and host persistence are exercised separately by the coupled workshop campaign.
const Session = preload("res://scripts/physical_actor_session.gd")
const Registry = preload("res://scripts/workbench_actor_catalog.gd")
const EquipmentRuntime = preload("res://scripts/physical_usable_runtime.gd")
const Reactive = preload("res://scripts/workbench_reactive_policy.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures := 0
var owner: Node2D
var session


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("WB_COMPOSE: " + label)


func definition(model: String, instance: int, source: String, position: Vector2) -> Dictionary:
	var control := Registry.default_control(model)
	control.source = source
	return {"model":model, "instance_id":instance, "position":position,
		"producer":Registry.producer_for(source), "usable_index":control.usable_index,
		"canvas_extent":Vector2i(2048,1024), "workbench_control":control,
		"workbench_options":{"response":"LA-SELECTIVE", "budget":20.0,
			"mass_multiplier":1.0, "inertia_multiplier":1.0,
			"thrust_multiplier":1.0, "torque_multiplier":1.0, "boost_multiplier":2.0}}


func step(count: int = 1) -> void:
	for index: int in count:
		session.advance(DT)
		session.bridge.step()
		session.complete_step()


func create(definitions: Array, epoch: int) -> bool:
	if session != null:
		session.close()
		session.free()
	session = Session.new()
	owner.add_child(session)
	return session.configure(definitions, owner.get_world_2d().space, epoch)


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	check(Reactive.supports("runner") and not Reactive.supports("copter") \
		and not Reactive.supports("pouncer") and not Reactive.supports("stuntbuggy"),
		"Thunderbowl wire reuse admits only physical ground/jump capability matches")
	var reflex = Reactive.new()
	check(reflex.configure("runner",Vector2(50,50),0),"physical reflex adapter configures without any simulation owner")
	var reflex_view := {"representation":"articulated-rapier","model":"runner","producer":"policy",
		"suspended":false,"fault":"","position":Vector2(50,50),"velocity":Vector2.ZERO,
		"grounded":true,"tick":90,"wall_left":30.0,"wall_right":30.0}
	var reflex_action: Dictionary = reflex.next_action(reflex_view,0.1)
	check(reflex_action.move.x > 0.0 and reflex_action.primary and not reflex_action.has("tag") \
		and not reflex_action.has("equipment"),"pure Thunderbowl steering maps legitimate movement/jump only")
	reflex_view.wall_right = 5.0
	check(reflex.next_action(reflex_view,0.1).move.x < 0.0,"physical local wall observation reverses reflex patrol")
	reflex_view.representation = "sampled"
	check(reflex.next_action(reflex_view,0.1).is_empty(),"sampled observations cannot masquerade as physical policy inputs")
	reflex_view.representation = "articulated-rapier"
	reflex_view.producer = "demo"
	check(reflex.next_action(reflex_view,0.1).is_empty(),"research adapter does not replace authored scripted producers")
	check(ClassDB.class_exists("RapierPhysicsServer2D"), "real Rapier available")
	var definitions: Array = [definition("scooper",101,"human",Vector2(160,80)),
		definition("crawler",205,"scripted",Vector2(300,95)),
		definition("copter",307,"scripted",Vector2(460,80)),
		definition("4ly_trainer",409,"policy",Vector2(620,80)),
		definition("reference_barrel",503,"passive",Vector2(760,80))]
	check(Session.valid_definitions(definitions), "heterogeneous physical roster admitted")
	var invalid: Array = definitions.duplicate(true)
	invalid[1].model = "invented"
	check(not Session.valid_definitions(invalid), "unknown definition refused before allocation")
	invalid = definitions.duplicate(true)
	invalid[2].instance_id = invalid[1].instance_id
	check(not Session.valid_definitions(invalid), "duplicate authored identity refused")
	invalid = definitions.duplicate(true)
	invalid[3].workbench_options.mass_multiplier = 2.0
	check(not Session.valid_definitions(invalid), "4LY exact plant preserved")
	invalid = definitions.duplicate(true)
	invalid[1].position = Vector2(0,0)
	check(not Session.valid_definitions(invalid), "all articulated hulls must fit before preparation")
	check(create(definitions, 31), "mixed Workbench creates one real physical owner")
	if not session.active():
		push_error(session.last_error)
		quit(1)
		return
	var body_count: int = session.bodies().size()
	check(body_count > definitions.size(), "actual articulated parts plus equipment exist")
	var sample: Dictionary = session.pack_workbench_sample()
	check(sample.bodies.size() == body_count, "each actual body has one native response owner")
	check(sample.states.size() / 17 == body_count + 4, "Scooper reserves five masks without duplicating its body")
	var masks := {}
	var identities := {}
	for member: Dictionary in sample.bodies:
		check(not identities.has(member.instance_id), "physical owner identity unique")
		identities[member.instance_id] = true
		for proxy: int in range(member.first_proxy, member.first_proxy + member.count):
			check(not masks.has(proxy), "native mask ownership unique")
			masks[proxy] = member.id
	check(EquipmentRuntime.frame_error(sample.equipment_frame).is_empty(), "remapped physical equipment frame validates")
	for actor: Dictionary in sample.equipment_frame.actors:
		check(actor.body_id == session.bridge.proxy_for_body(session._body_offsets[actor.actor_id] + session._rigs[actor.actor_id].equipment_mount_state().held_part),
			"ACT005 source body matches actual native proxy after compound flyer")
	var first_ids: Array = session.bodies().map(func(body: RigidBody2D): return body.get_rid())
	check(session.submit_workbench_action(101,{"move":Vector2(0,-0.8),"auxiliary":true},
		{"q":false,"e":false,"s":false,"boost":false},false), "human flight path remains usable")
	check(not session.submit_workbench_action(205,{"move":Vector2.RIGHT},
		{"q":false,"e":false,"s":false,"boost":false},false), "human cannot steal NPC producer")
	step(18)
	check(session.workbench_control(205).accepted >= 3 and session.workbench_control(307).accepted >= 3,
		"independent mechanical and flight scripts consume issued observations")
	check(session.workbench_control(409).accepted >= 3 and session.workbench_control(409).diagnostics.decisions >= 3,
		"policy fixture traverses public issued-observation submission path")
	check(session.observation(3).flight.last_step.sequence >= 0, "4LY policy actually reaches an observed physical step")
	var inspected: Dictionary = session.workbench_control(205)
	inspected.observation.position = Vector2(-999,-999)
	check(session.observation(1).position != inspected.observation.position, "inspector state is copied")
	var before: Dictionary = session.workbench_actor_state(205)
	var equipment_instance: String = session.observation(1).equipment.instance_id
	var old_token: Dictionary = session.observation(1)
	var human: Dictionary = definitions[1].workbench_control.duplicate(true)
	human.source = "human"
	check(session.set_workbench_control(205,human), "scripted ground actor accepts human takeover")
	var after: Dictionary = session.workbench_actor_state(205)
	check(before.retained_parts == after.retained_parts, "handoff preserves every articulated body pose and momentum")
	check(first_ids == session.bodies().map(func(body: RigidBody2D): return body.get_rid()), "handoff never reconstructs RIDs")
	check(session.observation(1).equipment.instance_id == equipment_instance, "handoff retains live equipment identity")
	check(not session.submit(Session.make_command(old_token,int(old_token.last_sequence)+1,{"move":Vector2.RIGHT}),&"demo"),
		"previous producer and observation revoked")
	check(session.submit_workbench_action(205,{"move":Vector2.RIGHT,"primary":true},
		{"q":false,"e":false,"s":false,"boost":false},false), "non-flyer human actions admitted")
	var native_item_mask: int = session.observation(1).equipment.body_id
	check(session.submit_workbench_action(205,{"release_usable":true},
		{"q":false,"e":false,"s":false,"boost":false},false), "human can release a physical usable")
	step(2)
	check(session.observation(1).equipment.state == "released" and session.bodies().size() == body_count,
		"released equipment keeps its physical body capacity")
	check(session.observation(1).equipment.body_id == native_item_mask, "released equipment retains its native mask identity")
	check(session.set_workbench_control(205,definitions[1].workbench_control), "ground actor handed back to existing script")
	check(session.observation(1).equipment.state == "released", "source handoff does not recreate or reattach released equipment")
	var stopped: Dictionary = definitions[2].workbench_control.duplicate(true)
	stopped.enabled = false
	check(session.set_workbench_control(307,stopped), "one autonomous source stops without destroying actor")
	var count_copter: int = session.workbench_control(307).accepted
	var count_crawler: int = session.workbench_control(205).accepted
	step(18)
	check(session.workbench_control(307).accepted == count_copter and session.workbench_control(307).status == "stopped",
		"stopped NPC decisions and leases remain stopped")
	check(session.workbench_control(205).accepted > count_crawler and session.bodies().size() == body_count,
		"unrelated NPC and physical world continue")
	var external: Dictionary = definitions[3].workbench_control.duplicate(true)
	external.policy = "external"
	check(session.set_workbench_control(409,external), "fixture can hand off to real external caller")
	var view: Dictionary = session.workbench_policy_observation(409)
	var command: Dictionary = Session.make_command(view,int(view.last_sequence)+1,{"move":Vector2.LEFT},3)
	check(session.submit_workbench_policy(409,command), "external command consumed through same lease")
	check(not session.submit_workbench_policy(205,command), "wrong authored actor cannot borrow slot authority")
	check(not session.submit_workbench_policy(409,command), "duplicate external sequence refused")
	step(3)
	check(session.workbench_control(409).lease_remaining == 0, "external lease expires at exact physical tick")
	check(not session.submit_workbench_policy(409,Session.make_command(view,int(view.last_sequence)+2,{"move":Vector2.RIGHT},18)),
		"delayed long reply cannot revive an expired generation")
	var fresh: Dictionary = session.workbench_policy_observation(409)
	session.set_suspended(true)
	var tick_before: int = session.tick
	session.advance(DT)
	session.complete_step()
	check(session.tick == tick_before and session.workbench_policy_observation(409).is_empty(), "pause stops decisions and observation authority")
	session.set_suspended(false)
	check(not session.submit_workbench_policy(409,Session.make_command(fresh,int(fresh.last_sequence)+1,{"move":Vector2.RIGHT})),
		"pause revokes outstanding external reply")
	var ground_external: Dictionary = definitions[1].workbench_control.duplicate(true)
	ground_external.source = "policy"
	ground_external.policy = "external"
	check(session.set_workbench_control(205,ground_external) and session.workbench_control(205).status == "waiting",
		"new external producer waits for its own first command despite earlier script admissions")
	session.set_suspended(true)
	var paused_ground: Dictionary = session.observation(1)
	check(paused_ground.suspended and session.workbench_control(205).status == "paused", "ground policy reports paused lifecycle")
	session.set_suspended(false)
	var resumed_ground: Dictionary = session.workbench_policy_observation(205)
	check(resumed_ground.tick == paused_ground.tick and resumed_ground.control_generation != paused_ground.control_generation,
		"paused ground observation and fresh same-tick resume observation have distinct authority")
	check(not session.submit_workbench_policy(205,Session.make_command(paused_ground,int(paused_ground.last_sequence)+1,{"move":Vector2.RIGHT})),
		"a paused ground view stays revoked even after a fresh view is issued at the same tick")
	check(session.submit_workbench_policy(205,Session.make_command(resumed_ground,int(resumed_ground.last_sequence)+1,{"move":Vector2.RIGHT})),
		"fresh resumed ground policy command remains usable")
	var retired: Dictionary = session.workbench_policy_observation(409)
	var retired_command: Dictionary = Session.make_command(retired,int(retired.last_sequence)+1,{"move":Vector2.RIGHT})
	check(create(definitions,31), "slot reuse creates a different run even with same epoch and authored IDs")
	check(not session.submit_workbench_policy(409,retired_command), "retired-run output cannot control replacement")
	var retained: Array = definitions.duplicate(true)
	step(2)
	for index: int in range(retained.size()): retained[index]["retained_parts"] = session.workbench_actor_state(retained[index].instance_id).retained_parts
	check(Session.valid_definitions(retained), "full multipart kinematic retention validates")
	check(create(retained,32), "multipart preparer can reconstruct retained poses")
	session.adopt_retained_motion()
	var restored: Array = session.workbench_actor_state(205).retained_parts
	for part: int in range(restored.size()):
		check(Vector2(restored[part].position).is_equal_approx(retained[1].retained_parts[part].position)
			and is_equal_approx(float(restored[part].rotation), float(retained[1].retained_parts[part].rotation))
			and Vector2(restored[part].linear_velocity).is_equal_approx(retained[1].retained_parts[part].linear_velocity)
			and is_equal_approx(float(restored[part].angular_velocity), float(retained[1].retained_parts[part].angular_velocity)),
			"retained limb kinematics survive backend angle conversion")
	session.close()
	session.free()
	owner.free()
	print("Workbench actor composition session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
