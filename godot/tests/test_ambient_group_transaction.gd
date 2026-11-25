extends SceneTree

# Independent real Rapier owner regression for transactional group controls.
# World-generation edge probes use deliberately copied synthetic envelopes and
# are labelled separately from the native-material physical episode campaign.
const Session = preload("res://scripts/physical_actor_session.gd")
const Registry = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Snapshot = preload("res://scripts/simulation_snapshot.gd")
var checks: int = 0
var failures: Array[String] = []
var owner: Node2D
var session
var observed_signals: int = 0
var observed_complete_group: bool = true
var expected_profile: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_GROUP: " + label)


func _control(id: int) -> Dictionary:
	var slot: int = session.slot_for_instance(id)
	return session._workbench_configuration(slot)


func _cancelled(_slot: int, _epoch: int) -> void:
	observed_signals += 1
	for id: int in [101, 102]:
		observed_complete_group = observed_complete_group and _control(id).ambient == expected_profile


func _rows(profile: Dictionary) -> Array:
	var rows: Array = []
	for id: int in [101, 102]:
		var control: Dictionary = _control(id)
		var replacement: Dictionary = control.duplicate(true)
		replacement.ambient = profile.duplicate(true)
		rows.append({"instance_id":id, "configuration":replacement, "expected_configuration":control})
	return rows


func run() -> void:
	check(ClassDB.class_exists("RapierPhysicsServer2D"), "actual retained Rapier runtime is loaded")
	owner = Node2D.new()
	root.add_child(owner)
	session = Session.new()
	owner.add_child(session)
	var profile: Dictionary = Profile.blank("group-original")
	profile.modules = [Profile.make_module("rest")]
	profile.modules[0].params.active_seconds = 100.0
	var definitions: Array = []
	for index: int in 2:
		var model: String = "runner" if index == 0 else "monowheel"
		var control: Dictionary = Registry.default_control(model)
		control.source = "policy"
		control.policy = "ambient"
		control.enabled = true
		control.decision_ticks = 1
		control.usable_index = -1
		control.ambient = profile.duplicate(true)
		definitions.append({"model":model,"instance_id":101+index,"position":Vector2(120+index*80,100),
			"producer":"policy","usable_index":-1,"canvas_extent":Vector2i(512,256),"workbench_control":control,
			"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,"mass_multiplier":1.0,
				"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}})
	check(session.configure(definitions, owner.get_world_2d().space, 73), "two real physical families configure")
	if not session.active():
		print("AMBIENT_GROUP ",JSON.stringify({"checks":checks,"failures":failures,"error":session.last_error}))
		session.close()
		owner.free()
		quit(1)
		return
	var bodies: Array = session.bodies()
	var rids: Array[RID] = []
	for body: Node2D in bodies: rids.append(body.get_rid())
	var generations: PackedInt64Array = session._generations.duplicate()
	var dt: float = session.bridge.fixed_delta()
	for index: int in 8:
		session.advance(dt)
		session.bridge.step()
		session.complete_step()
	expected_profile = profile.duplicate(true)
	expected_profile.id = "group-new"
	expected_profile.name = "New group profile"
	expected_profile.seed = 731
	var valid: Array = _rows(expected_profile)
	check(not session.set_workbench_controls([],session.run_id,session.epoch), "empty group is refused")
	check(not session.set_workbench_controls(valid,session.run_id,session.epoch+1), "stale epoch refuses whole group")
	var repeated: Array = [valid[0].duplicate(true),valid[0].duplicate(true)]
	check(not session.set_workbench_controls(repeated,session.run_id,session.epoch), "duplicate member is refused")
	var stale: Array = valid.duplicate(true)
	stale[1].expected_configuration.enabled = false
	check(not session.set_workbench_controls(stale,session.run_id,session.epoch), "changed second member refuses prepared first member")
	var invalid: Array = valid.duplicate(true)
	invalid[1].configuration.ambient.modules[0].params.rest_seconds = NAN
	check(not session.set_workbench_controls(invalid,session.run_id,session.epoch), "invalid second adapter refuses before cancellation")
	for index: int in 2:
		check(session._generations[index] == generations[index], "refused groups retain command generations")
		check(_control(101+index).ambient == profile, "refused groups retain original profile")
	session.input_cancelled.connect(_cancelled)
	check(session.set_workbench_controls(valid,session.run_id,session.epoch), "all compatible members apply in one transaction")
	check(observed_signals == 2 and observed_complete_group, "every cancellation observer sees the complete committed group")
	for index: int in 2:
		check(session._generations[index] == generations[index]+1, "successful group revokes each authority once")
		check(_control(101+index).ambient == expected_profile, "both physical families have the new configuration")
	for index: int in rids.size():
		check(session.bodies()[index].get_rid() == rids[index], "group assignment preserves each actual Rapier body")
	check(not session.set_workbench_controls(valid,session.run_id,session.epoch), "replayed stale group cannot overwrite fresh state")
	session.input_cancelled.disconnect(_cancelled)
	var snapshot = Snapshot.new()
	snapshot.rigid_body_epoch = session.epoch
	snapshot.render_world_generation = 42
	snapshot.serial = 10
	session.ingest_ambient_snapshot(snapshot)
	check(session._ambient_world_generation == 42 and not session._ambient_sensor_active,
		"no-material profile still receives valid copied World identity")
	snapshot.render_world_generation = 43
	snapshot.serial = 9
	session.ingest_ambient_snapshot(snapshot)
	check(session._ambient_world_generation == 42, "older envelope cannot change World identity")
	snapshot.render_world_generation = 41
	snapshot.serial = 11
	session.ingest_ambient_snapshot(snapshot)
	check(session._ambient_world_generation == 42, "regressed generation cannot replace current identity")
	snapshot.render_world_generation = 43
	snapshot.serial = 12
	session.ingest_ambient_snapshot(snapshot)
	check(session._ambient_world_generation == 43, "new valid generation advances memory fence")
	var environment: Dictionary = session._ambient_environment(0,session._view(0,false),expected_profile)
	check(int(environment.get("world_generation",-1)) == 43, "generation reaches pure decision envelope")
	check(session._ambient_peer_observations.size() == 2, "peer work copies only instantiated bounded physical owners")
	var peer_copy: Array = session._ambient_peer_observations.duplicate(true)
	session._ambient_environment(1,session._view(1,false),expected_profile)
	check(peer_copy == session._ambient_peer_observations, "same-tick decisions share immutable copied peers")
	var scoped_profile: Dictionary = expected_profile.duplicate(true)
	scoped_profile.modules.append(Profile.make_module("avoid_ledge"))
	scoped_profile.modules[-1].weight = 0.0
	scoped_profile.regions = [{"id":"home-pad", "name":"Home pad", "kind":"home",
		"x":100.0, "y":80.0, "width":48.0, "height":32.0}]
	var scoped: Dictionary = session._ambient_environment(0,session._view(0,false),scoped_profile)
	check(not bool(scoped.ledges.available) and scoped.ledges.get("modules",{}).is_empty(),
		"zero-weight ledge rules issue no optional terrain observations")
	check(scoped.regions == scoped_profile.regions, "authored places enter the copied local environment")
	scoped.regions[0].x = 7.0
	check(float(scoped_profile.regions[0].x) == 100.0, "copied region inspection cannot change authoring")
	var steps: int = session.bridge.manual_step_count()
	session.close()
	check(session._ambient_world_generation == -1 and session._ambient_peer_observations.is_empty(),
		"owner close invalidates World identity and peer cache")
	owner.free()
	print("AMBIENT_GROUP ",JSON.stringify({"checks":checks,"failures":failures,
		"actual_rapier_steps":steps,"logical_actors":2,"world_identity_probes":"synthetic copied envelopes",
		"scope":"actual physical group handoff and ownership; no native-material or playfeel claim"}))
	quit(0 if failures.is_empty() else 1)
