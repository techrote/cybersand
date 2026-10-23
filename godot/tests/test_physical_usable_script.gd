extends SceneTree

const Actors = preload("res://scripts/physical_actor_catalog.gd")
const Usables = preload("res://scripts/usable_catalog.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
const Pilot = preload("res://scripts/physical_usable_script.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
var assertions: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_USABLE_SCRIPT: " + message)


func _view(id: StringName) -> Dictionary:
	var loadout: Dictionary = Loadouts.entry(id)
	return {"rig_id": id, "epoch": 1, "position": Vector2(100, 80), "centre": Vector2(100, 80),
		"velocity": Vector2(6, 0), "rotation": 0.0, "angular_velocity": 0.0,
		"grounded": str(loadout.strategy) != "drop", "ground_distance": 18.0,
		"blocked": true, "parts": [], "equipment": {"usable_index": int(loadout.usable_index),
			"instance_id": "test-device", "equipment_epoch": 1, "state": "held", "attached": true,
			"position": Vector2(108, 80), "muzzle": Vector2(112, 80), "ready": true,
			"pending": false, "charge": 100.0, "cooldown": 0.0, "projectiles": []}}


func _locomotion() -> Dictionary:
	return {"move": Vector2(0.6, -0.3), "aim": Vector2(-0.2, -1).normalized(),
		"effort": 0.8, "primary": false, "secondary": false, "auxiliary": false,
		"tool": false, "trim": 0.1, "reel": 0.0}


func _run() -> void:
	var used: Dictionary = {}
	_check(Loadouts.all().size() == 46, "all 41 retained and five player actors have explicit equipment policies")
	var legacy_count: int = 0
	for id: StringName in Actors.RIG_IDS:
		var loadout: Dictionary = Loadouts.entry(id)
		if Actors.set_for(id) == &"setP":
			_check_player_loadout(id, loadout)
			continue
		legacy_count += 1
		_check(not loadout.is_empty() and Usables.has_usable(StringName(loadout.usable_id)), str(id) + " keeps a real U01-U32 identity")
		_check(not str(loadout.reason).is_empty() and float(loadout.power) > 0 and float(loadout.power) <= 1,
			str(id) + " has authored rationale and bounded equipment power")
		used[loadout.usable_id] = true
		var pilot := Pilot.new()
		_check(pilot.configure(id, Vector2(100, 80)), str(id) + " pilot configures")
		var view: Dictionary = _view(id)
		var frozen: Dictionary = view.duplicate(true)
		var attempts: int = 0
		for tick: int in range(45):
			var action: Dictionary = pilot.apply(view, _locomotion(), 0.1)
			_check(not Session.normalized_action(action).is_empty(), str(id) + " output uses admitted equipment action schema")
			_check(action.aim == _locomotion().aim, str(id) + " equipment does not retarget locomotion aim")
			attempts += int(action.get("equipment", {}).get("trigger", false))
		_check(attempts >= 1 and attempts < 20, str(id) + " performs intentional bounded use windows")
		_check(view == frozen, str(id) + " never mutates copied input observations")
		var snapshot: Dictionary = Loadouts.entry(id)
		snapshot.reason = "mutated"
		_check(Loadouts.entry(id).reason != "mutated", str(id) + " loadout readback is copied")
	_check(legacy_count == 41 and used.size() == 32, "the 41 retained default loadouts demonstrate all32 usables")
	_negative_control()
	_deployment_control()
	_existing_payload_control()
	_target_control()
	print("PHYSICAL_USABLE_SCRIPT assertions=", assertions, " failures=", failures)
	quit(1 if failures else 0)


func _check_player_loadout(id: StringName, loadout: Dictionary) -> void:
	_check(int(loadout.get("usable_index", -2)) == -1 and str(loadout.get("usable_id", "")) == "none",
		str(id) + " starts explicitly unequipped")
	_check(not str(loadout.get("none_reason", "")).is_empty(), str(id) + " records why its mount is empty")
	var pilot := Pilot.new()
	_check(pilot.configure(id, Vector2(100, 80)), str(id) + " neutral equipment policy configures")
	var view: Dictionary = _view(id)
	for installed: int in [-1, 0]:
		view.equipment.usable_index = installed
		for tick: int in range(45):
			var action: Dictionary = pilot.apply(view, _locomotion(), 0.1)
			_check(action == _locomotion() and not action.has("equipment"), str(id) + " never adds autonomous tool use")


func _negative_control() -> void:
	var pilot := Pilot.new()
	pilot.configure(&"astra", Vector2(100, 80))
	var view: Dictionary = _view(&"astra")
	for _tick: int in range(10):
		pilot.apply(view, _locomotion(), 0.1)
	for key: String in ["ready", "pending", "charge"]:
		var blocked: Dictionary = view.duplicate(true)
		blocked.equipment[key] = false if key == "ready" else (true if key == "pending" else 0.0)
		var triggered: bool = false
		for _tick: int in range(20):
			triggered = triggered or bool(pilot.apply(blocked, _locomotion(), 0.1).equipment.trigger)
		_check(not triggered, key + " refusal prevents scripted firing")
	view.equipment.equipment_epoch += 1
	_check(not pilot.apply(view, _locomotion(), 0.1).equipment.trigger, "new equipment incarnation first emits neutral rearm")
	view.suspended = true
	_check(not pilot.apply(view, _locomotion(), 0.1).has("equipment"), "suspended producer creates no equipment request")
	view.erase("suspended")
	for dt: float in [0.0, -0.1, NAN, INF, 0.26]:
		_check(not pilot.apply(view, _locomotion(), dt).has("equipment"), "invalid timestep creates no equipment request")


func _deployment_control() -> void:
	var pilot := Pilot.new()
	pilot.configure(&"heavylift", Vector2(100, 80))
	var view: Dictionary = _view(&"heavylift")
	pilot.apply(view, _locomotion(), 0.1)
	view.equipment.state = "released"
	view.equipment.attached = false
	view.equipment.equipment_epoch += 1
	view.equipment.deploy_intent = true
	view.equipment.reattach_ready = true
	for _tick: int in range(40):
		var action: Dictionary = pilot.apply(view, _locomotion(), 0.1)
		_check(not action.equipment.attach, "carrier waits for a released deployment to settle")
	view.equipment.state = "fixed"
	view.equipment.equipment_epoch += 1
	view.equipment.deploy_intent = false
	view.equipment.processor_state = {"state": "blocked-output"}
	var recovered: bool = false
	for _tick: int in range(35):
		recovered = recovered or bool(pilot.apply(view, _locomotion(), 0.1).equipment.attach)
	_check(recovered, "jammed deployed processor has an explicit nearby recovery action")
	view.equipment.reattach_ready = false
	_check(not pilot.apply(view, _locomotion(), 0.1).equipment.attach, "distant device is approached without forging pickup admission")
	view.equipment.state = "held"
	view.equipment.attached = true
	view.equipment.equipment_epoch += 1
	pilot.apply(view, _locomotion(), 0.1)
	_check(int(pilot.diagnostics().pickups_observed) == 1, "recovery is acknowledged only from new physical state")
	# The suspended grip must approach inside the real pickup radius. A policy
	# that merely hovers fourteen cells away can never recover the payload.
	view.equipment.state = "deployed"
	view.equipment.attached = false
	view.equipment.equipment_epoch += 1
	view.equipment.position = Vector2(108, 110)
	view.equipment.grip_position = Vector2(108, 92)
	view.equipment.reattach_ready = false
	view.velocity = Vector2.ZERO
	var descending: Dictionary = {}
	for tick: int in range(40):
		descending = pilot.apply(view, _locomotion(), 0.1)
	_check(descending.move.y > 0.3, "heavy recovery lowers the actual grip into pickup range")


func _existing_payload_control() -> void:
	var pilot := Pilot.new()
	pilot.configure(&"astra", Vector2(100, 80))
	var view: Dictionary = _view(&"astra")
	view.equipment.charge = 0.0
	view.equipment.cooldown = 2.0
	view.equipment.ready = false
	view.equipment.projectiles = [{"usable_index": Usables.index_for(&"timer_airburst"),
		"state": "flight", "age": 0.4}]
	pilot.apply(view, _locomotion(), 0.1)
	var action: Dictionary = pilot.apply(view, _locomotion(), 0.1)
	_check(action.equipment.alternate and not action.equipment.trigger,
		"committed timer payload can be activated without new-launch resources")


func _target_control() -> void:
	var pilot := Pilot.new()
	pilot.configure(&"crawler", Vector2(100, 80))
	var view: Dictionary = _view(&"crawler")
	var materials := PackedByteArray()
	materials.resize(81)
	materials.fill(0)
	materials[4 * 9 + 4] = 2
	view.cell_patch = {"origin": Vector2i(112, 76), "size": Vector2i(9, 9), "materials": materials}
	var saved: Dictionary = view.duplicate(true)
	pilot.apply(view, _locomotion(), 0.1)
	var action: Dictionary = pilot.apply(view, _locomotion(), 0.1)
	_check(Vector2(action.equipment.aim).dot(Vector2.RIGHT) > 0.98, "powder vacuum aims at actual copied loose material")
	_check(view == saved, "material patch remains immutable")
