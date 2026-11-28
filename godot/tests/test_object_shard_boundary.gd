extends SceneTree

# Exercise the real GDExtension value boundary. Invalid copied inputs must not
# acquire a pose, semantic opportunity or replacement World by coercion.
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberObjectShardLab"), "Actual native Lab class is available")
	if failures == 0:
		for invalid: Dictionary in [{"scenario": "1"}, {"seed": 12.5}, {"scenario": true},
			{"width": "192"}, {"height": 128.5}, {"width": 513}, {"height": 63}, {"transfer_budget": false}]:
			var fresh = ClassDB.instantiate(&"CyberObjectShardLab")
			_expect(fresh.configure(invalid).get("outcome") == "InvalidConfiguration", "Configuration is typed and bounded: " + str(invalid))
			_expect(fresh.configure({"scenario": 0, "seed": 12}).get("ok", false), "Refused configuration leaves construction available")
			fresh = null
		var native = ClassDB.instantiate(&"CyberObjectShardLab")
		_expect(native.configure({"scenario": 0, "seed": 12}).get("ok", false), "Empty bounded real World configures")
		var before: Dictionary = native.snapshot()
		_expect(native.edit_cell(Vector2i(20, 20), 3, 0, 0, 200).get("outcome") == "Unsupported",
			"Zero-quanta Water is refused before normalization can corrupt authoring accounting")
		var pose: Dictionary = {"session": before.session, "id": 999, "generation": 1, "body_generation": 1,
			"geometry_revision": 1, "pose_serial": 1, "x": 0.0, "y": 0.0, "rotation": 0.0,
			"vx": 0.0, "vy": 0.0, "angular_velocity": 0.0, "sleeping": false}
		for key: String in ["x", "y", "rotation", "vx", "vy", "angular_velocity", "sleeping"]:
			var missing: Dictionary = pose.duplicate(true)
			missing.erase(key)
			_expect(native.accept_motion([missing]).get("outcome") == "InvalidPose", "Missing pose field cannot be defaulted: " + key)
			var coerced: Dictionary = pose.duplicate(true)
			coerced[key] = "0"
			_expect(native.accept_motion([coerced]).get("outcome") == "InvalidPose", "String pose field cannot become numeric state: " + key)
		for nonfinite: float in [NAN, INF, -INF]:
			var invalid_pose: Dictionary = pose.duplicate(true)
			invalid_pose.x = nonfinite
			_expect(native.accept_motion([invalid_pose]).get("outcome") == "InvalidPose", "Nonfinite position is refused")
		_expect(native.accept_motion([pose]).get("outcome") == "Stale", "A well-typed nonexistent body remains stale")
		_expect(native.accept_motion([pose, pose, pose, pose]).get("outcome") == "PoseCapacity", "Copied pose inventory is bounded")
		var after: Dictionary = native.snapshot()
		_expect(after.tick == before.tick and after.session == before.session, "Refused poses do not advance semantic time or session")
		_expect(after.world_materials == before.world_materials and after.shards == before.shards, "Refused poses do not change authoritative inventory")
		var accepted: Dictionary = native.accept_motion([])
		_expect(accepted.get("applied", false) and accepted.semantic_tick == before.tick,
			"Empty actual motion barrier reports application without ticking chemistry")
		_expect(native.step([]).get("ok", false) and int(native.snapshot().tick) == int(before.tick) + 1,
			"A subsequent valid semantic step still progresses")
		native = null
	print(JSON.stringify({"schema": "objectshard-boundary-contract-test-v1", "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
