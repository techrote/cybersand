extends SceneTree

# This executes the current real Workbench adapter's refusal boundaries. It
# intentionally does not add a second World to the Workbench or claim an
# ObjectShard integration. The separate worker rehearsal exercises moving
# mutable material and the future applied-message ordering with real Rapier.
const Profiles = preload("res://scripts/transport_profiles.gd")
var checks: int = 0
var failures: int = 0
var bridge
var world
var original: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(detail)


func _sample() -> Dictionary:
	return {"session": 401, "epoch": 401,
		"states": PackedFloat64Array([1, 50, 50, 0, 8, 8, 0, 0, 0, 1, 1, 20, 50, 50, 0.4, 1.0/60.0, 401]),
		"geometry": PackedFloat64Array([0, 0, 8, 8]),
		"bodies": [{"id": 1, "instance_id": 42, "generation": 401, "first_proxy": 1,
			"count": 1, "budget": 20.0, "gravity": 92.0, "external_drive": false}]}


func _admit(sample: Dictionary) -> bool:
	return world.prepare_workbench_coupling(sample.states, sample.geometry, sample.bodies, sample.session, sample.epoch, false)


func _refused(label: String, candidate: Dictionary) -> void:
	var revision: int = int(world.get_revision())
	_expect(not _admit(candidate), label)
	_expect(int(world.get_revision()) == revision, "Refused candidate keeps material revision: " + label)
	# A rejected candidate must not relax the retained roster for the next one.
	var control: Dictionary = original.duplicate(true)
	control.states[10] = checks + 10
	_expect(_admit(control), "Original complete roster remains usable after refusal: " + label)


func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge"), "Actual native Workbench APIs are loaded")
	if failures:
		_finish()
		return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	original = _sample()
	var resolved: Dictionary = Profiles.resolve(Profiles.preset(0))
	_expect(resolved.get("ok", false), "Production Baseline transport resolves")
	var options: Dictionary = {"workbench_extent": Vector2i(256, 256), "workbench_response": "LA-SELECTIVE",
		"workbench_sample": original, "region": PackedInt32Array([0, 0, 256, 256]), "intent": "exploratory",
		"definition_hash": "objectshard-m3-workbench-boundary-v1".sha256_text(),
		"initial_bodies": PackedFloat32Array([1, 50, 50, 0, 8, 8, 0, 0, 0, 1, 1]), "workbench_worker_threads": 1}
	var token: int = bridge.prepare_liquid_world(world, PackedInt32Array([0, 200, 256, 8, 1]), resolved.packed,
		PackedInt32Array([1, 8, 12, 0]), PackedInt32Array(), bridge.default_liquid_policy(), options)
	_expect(token > 0, "Real prepared-World construction accepts the immutable physical roster")
	if token <= 0:
		_finish()
		return
	_expect(bridge.commit_liquid_world(world, token), "The actual prepared World commits")
	var control: Dictionary = original.duplicate(true)
	control.states[10] = 2
	control.states[1] += 0.125
	control.states[12] += 0.125
	_expect(_admit(control), "A new coherent pose is admitted within the retained roster")
	_expect(not _admit(control), "Duplicate native pose serial does not acquire another application")
	var mass: Dictionary = original.duplicate(true)
	mass.states[9] = 2.0
	mass.states[10] = 100
	_refused("A mutable ObjectShard mass cannot silently enter the immutable Workbench adapter", mass)
	var inertia: Dictionary = original.duplicate(true)
	inertia.states[11] = 19.0
	inertia.states[10] = 101
	_refused("Changing inertia needs an explicit new material-body contract", inertia)
	var geometry: Dictionary = original.duplicate(true)
	geometry.states[4] = 7.0
	geometry.geometry[2] = 7.0
	geometry.states[10] = 102
	_refused("An eroded collider cannot replace the retained Workbench geometry", geometry)
	var roster: Dictionary = original.duplicate(true)
	roster.bodies[0].instance_id = 43
	roster.states[10] = 103
	_refused("A new application identity cannot reuse a retained body slot", roster)
	var stale: Dictionary = original.duplicate(true)
	stale.session = 402
	stale.states[16] = 402
	stale.states[10] = 104
	_refused("A new session cannot reinterpret the old World owner", stale)
	var epoch: Dictionary = original.duplicate(true)
	epoch.epoch = 402
	epoch.states[10] = 105
	_refused("A new epoch cannot bypass the prepared-World boundary", epoch)
	var omitted: Dictionary = original.duplicate(true)
	omitted.states.clear()
	omitted.geometry.clear()
	omitted.bodies.clear()
	_refused("Retired or omitted bodies require a real roster transition", omitted)
	var methods: Array[String] = []
	for method: Dictionary in ClassDB.class_get_method_list(&"CyberObjectShardLab", true):
		methods.append(str(method.name))
	_expect("configure" in methods and "accept_motion" in methods and "acknowledge" in methods, "Actual ObjectShard owner exposes the narrow value protocol")
	_expect("attach_world" not in methods and "set_world" not in methods,
		"Current ObjectShard facade does not pretend to attach its private World to an existing Workbench")
	_finish()


func _finish() -> void:
	print(JSON.stringify({"schema": "objectshard-workbench-boundary-test-v1", "checks": checks, "failures": failures,
		"scope": "Actual accepted native Workbench refusal contracts; no production ObjectShard attachment is claimed"}))
	world = null
	bridge = null
	quit(0 if failures == 0 else 1)
