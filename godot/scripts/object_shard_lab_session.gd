class_name CyberObjectShardLabSession
extends RefCounted

const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
const MAX_EVENTS: int = 256
const MAX_SAMPLES: int = 7200

var native: RefCounted
var bridge: CyberObjectShardPhysicsBridge
var frame: Dictionary = {}
var paused: bool = true
var failed: bool = false
var scenario: int = 1
var seed: int = 12
var status: String = "Not started"
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var promotion_max_usec: int = 0
var frame_max_usec: int = 0
var last_frame_usec: int = 0
var last_copy_usec: int = 0
var last_native_usec: int = 0


func open(next_scenario: int = 1, next_seed: int = 12) -> Dictionary:
	if not ClassDB.class_exists(&"CyberObjectShardLab"):
		return _failure("Source-matched ObjectShard native extension is unavailable")
	scenario = next_scenario
	seed = next_seed
	if bridge != null:
		bridge.shutdown()
	bridge = Bridge.new()
	var result: Dictionary
	if native == null:
		native = ClassDB.instantiate(&"CyberObjectShardLab")
		result = native.configure({"scenario": scenario, "seed": seed})
	else:
		result = native.reset(scenario, seed)
	if not result.get("ok", false):
		return _failure("Native reset refused: " + str(result))
	failed = false
	paused = true
	events.clear()
	samples.clear()
	promotion_max_usec = 0
	frame_max_usec = 0
	frame = native.snapshot()
	result = bridge.initialize(int(frame.session))
	if not result.get("ok", false):
		return _failure("Rapier initialization failed: " + str(result))
	result = bridge.install_terrain(frame.terrain_chunks)
	if not result.get("ok", false):
		return _failure("Initial collision installation failed: " + str(result))
	status = "Paused · native World owns the starting structure"
	_event("SessionOpened", {"scenario": scenario, "seed": seed, "session": frame.session})
	return {"ok": true, "session": frame.session}


func advance(force: bool = false) -> Dictionary:
	if failed or native == null or bridge == null:
		return {"ok": false, "outcome": "Unavailable"}
	if paused and not force:
		return {"ok": true, "outcome": "Paused"}
	var started: int = Time.get_ticks_usec()
	bridge.begin_frame()
	last_copy_usec = 0
	# Every material/shape installation finishes between explicit Rapier steps.
	if not _synchronize():
		return {"ok": false, "outcome": "SynchronizationFailed"}
	var native_started: int = Time.get_ticks_usec()
	var result: Dictionary = native.step(bridge.sample_poses())
	last_native_usec = Time.get_ticks_usec() - native_started
	if not result.get("ok", false):
		return _failure("Native tick refused: " + str(result))
	_refresh()
	if frame.get("quarantined", false):
		return _failure("Native coordinator quarantined; inventory retained until reset")
	if not bool(frame.promotion.get("present", false)):
		var preparation: Dictionary = native.prepare_next()
		if preparation.get("ok", false):
			_refresh()
	if bool(frame.promotion.get("present", false)):
		if not _promote():
			return {"ok": false, "outcome": "PromotionHeld"}
	if not _synchronize():
		return {"ok": false, "outcome": "SynchronizationFailed"}
	if not bool(frame.get("paused", true)):
		var moved: Dictionary = bridge.step()
		if not moved.get("ok", false):
			return _failure("Physics motion outside admitted envelope: " + str(moved))
	last_frame_usec = Time.get_ticks_usec() - started
	frame_max_usec = maxi(frame_max_usec, last_frame_usec)
	_record_sample()
	status = "Tick %d · %d moving owners · %s" % [int(frame.tick), bridge.bodies.size(), "paused" if paused else "running"]
	return {"ok": true, "tick": frame.tick}


func edit(position: Vector2i, material: int, state_a: int = 0, state_b: int = 0, temperature: int = 200) -> Dictionary:
	if native == null or failed or bool(frame.get("paused", false)):
		return {"ok": false, "outcome": "Fenced"}
	var result: Dictionary = native.edit_cell(position, material, state_a, state_b, temperature)
	_event("OrdinaryEdit", {"position": position, "material": material, "result": result})
	_refresh()
	return result


func ignite(position: Vector2i) -> Dictionary:
	if native == null or failed:
		return {"ok": false, "outcome": "Fenced"}
	# Native material ownership selects the operation. A visual shard cannot be
	# edited through World paint or turned into a second authoritative copy.
	for shard: Dictionary in frame.get("shards", []):
		if not shard.get("owns_inventory", false):
			continue
		var local: Vector2 = _pose(shard).affine_inverse() * (Vector2(position) + Vector2.ONE * 0.5)
		var x: int = floori(local.x)
		var y: int = floori(local.y)
		if x >= 0 and y >= 0 and x < int(shard.width) and y < int(shard.height):
			var cell: int = y * int(shard.width) + x
			if int(shard.materials[cell]) == 7:
				var result: Dictionary = native.ignite_shard(int(shard.id), int(shard.generation), cell)
				_event("IgniteShard", {"id": shard.id, "cell": cell, "result": result})
				_refresh()
				return result
	var result: Dictionary = native.ignite(position)
	_event("IgniteWorld", {"position": position, "result": result})
	_refresh()
	return result


func inspect(position: Vector2i) -> Dictionary:
	for shard: Dictionary in frame.get("shards", []):
		if not shard.get("owns_inventory", false):
			continue
		var local: Vector2 = _pose(shard).affine_inverse() * (Vector2(position) + Vector2.ONE * 0.5)
		var x: int = floori(local.x)
		var y: int = floori(local.y)
		if x >= 0 and y >= 0 and x < int(shard.width) and y < int(shard.height):
			var cell: int = y * int(shard.width) + x
			if int(shard.materials[cell]) != 0:
				return {"ok": true, "owner": "ObjectShard", "id": shard.id, "generation": shard.generation,
					"cell": cell, "material": shard.materials[cell], "state_a": shard.states_a[cell],
					"state_b": shard.states_b[cell], "temperature": shard.temperature[cell],
					"role": shard.roles[cell], "incarnation": shard.incarnations[cell]}
	return native.inspect(position) if native != null else {"ok": false}


func export_result() -> Dictionary:
	return {"schema": "objectshard-lab-observation-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine": Engine.get_version_info(), "platform": OS.get_name(), "scenario": scenario, "seed": seed,
		"session": frame.get("session", 0), "tick": frame.get("tick", 0), "failed": failed, "status": status,
		"capabilities": native.capabilities() if native != null else {}, "accounting": frame.get("accounting", {}),
		"native_metrics": frame.get("metrics", {}), "physics_metrics": bridge.timings if bridge != null else {},
		"promotion_max_usec": promotion_max_usec, "frame_max_usec": frame_max_usec,
		"events": events.duplicate(true), "samples": samples.duplicate(true),
		"owner_acceptance": "unrecorded; automated execution is not physical acceptance"}


func close() -> void:
	paused = true
	if bridge != null:
		bridge.shutdown()
	bridge = null
	native = null
	frame = {}


func _promote() -> bool:
	var started: int = Time.get_ticks_usec()
	var promotion: Dictionary = frame.promotion
	var shard: Dictionary = _find_shard(int(promotion.id))
	if shard.is_empty():
		_failure("Prepared inventory disappeared")
		return false
	var reserved: Dictionary = bridge.reserve_body(shard)
	if not reserved.get("ok", false):
		var cancelled: Dictionary = native.cancel(int(promotion.transaction))
		_event("ReservationRefused", {"physics": reserved, "cancel": cancelled})
		_refresh()
		paused = true
		status = "Body reservation refused; original native inventory retained"
		return false
	var receipt: Dictionary = _ack(shard, "PhysicsReserved")
	var committed: Dictionary = native.acknowledge(receipt)
	if not committed.get("ok", false):
		bridge.remove_body(int(shard.id))
		_event("CommitRefused", committed)
		_refresh()
		paused = true
		status = "Promotion refused before activation: " + str(committed.get("detail", "unknown"))
		return false
	_event("CommittedInactive", committed)
	_refresh()
	shard = _find_shard(int(shard.id))
	var installed: Dictionary = bridge.install_terrain(frame.terrain_chunks)
	if not installed.get("ok", false):
		_failure("Postcommit terrain installation failed; exact inventory remains inactive")
		return false
	receipt = _ack(shard, "TerrainInstalled")
	var selected: Array = []
	for required: Dictionary in frame.promotion.chunks:
		for actual: Dictionary in installed.chunks:
			if int(actual.id) == int(required.id):
				selected.append(actual)
	receipt["chunks"] = selected
	var mask_applied: Dictionary = native.acknowledge(receipt)
	if not mask_applied.get("ok", false) or str(mask_applied.get("phase", "")) != "ReadyToActivate":
		_failure("Native occupancy application failed; body stays frozen")
		return false
	_event("MaskApplied", mask_applied)
	_refresh()
	shard = _find_shard(int(shard.id))
	var activated: Dictionary = bridge.activate(shard)
	if not activated.get("ok", false):
		_failure("Rapier activation failed; material owner remains held")
		return false
	var active: Dictionary = native.acknowledge(_ack(shard, "BodyActivated"))
	if not active.get("ok", false):
		_failure("BodyActivated receipt rejected; both clocks held")
		return false
	_event("Active", active)
	promotion_max_usec = maxi(promotion_max_usec, Time.get_ticks_usec() - started)
	_refresh()
	return true


func _synchronize() -> bool:
	var installed: Dictionary = bridge.install_terrain(frame.get("terrain_chunks", []))
	if not installed.get("ok", false):
		_failure("Terrain synchronization failed: " + str(installed))
		return false
	for shard: Dictionary in frame.get("shards", []):
		if not bridge.bodies.has(int(shard.id)) or not shard.get("geometry_pending", false):
			continue
		var updated: Dictionary = bridge.install_geometry(shard)
		if not updated.get("ok", false):
			_failure("Geometry installation held: " + str(updated))
			return false
		var kind: String = "BodyRetired" if updated.get("retired_body", false) else "GeometryInstalled"
		var accepted: Dictionary = native.acknowledge(_ack(shard, kind))
		if not accepted.get("ok", false):
			_failure("Geometry receipt rejected; both clocks held: " + str(accepted))
			return false
	_refresh()
	return true


func _ack(shard: Dictionary, kind: String) -> Dictionary:
	var receipt: Dictionary = {"kind": kind}
	for key: String in ["session", "id", "generation", "transaction", "body_generation",
		"payload_digest", "geometry_revision", "mask_digest", "shape_digest"]:
		receipt[key] = shard[key]
	return receipt


func _refresh() -> void:
	var started: int = Time.get_ticks_usec()
	frame = native.snapshot()
	last_copy_usec += Time.get_ticks_usec() - started


func _find_shard(id: int) -> Dictionary:
	for shard: Dictionary in frame.get("shards", []):
		if int(shard.id) == id:
			return shard
	return {}


func _pose(shard: Dictionary) -> Transform2D:
	if bridge != null and bridge.bodies.has(int(shard.id)):
		return PhysicsServer2D.body_get_state(bridge.bodies[int(shard.id)].rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	return Transform2D(float(shard.get("rotation", 0.0)), Vector2(float(shard.position_x), float(shard.position_y)))


func _event(kind: String, detail: Dictionary) -> void:
	if events.size() == MAX_EVENTS:
		events.pop_front()
	events.append({"tick": frame.get("tick", 0), "kind": kind, "detail": detail.duplicate(true)})


func _record_sample() -> void:
	if samples.size() >= MAX_SAMPLES:
		# A fixed-size observation window, never an unbounded owner-facing log.
		samples.pop_front()
	samples.append({"tick": frame.tick, "frame_usec": last_frame_usec, "native_usec": last_native_usec,
		"copy_usec": last_copy_usec, "rapier_usec": bridge.timings.rapier_step_usec,
		"flush_usec": bridge.timings.rapier_flush_usec, "geometry_usec": bridge.timings.geometry_install_usec,
		"terrain_usec": bridge.timings.terrain_install_usec})


func _failure(message: String) -> Dictionary:
	failed = true
	paused = true
	status = message
	_event("Held", {"reason": message})
	return {"ok": false, "outcome": "Held", "detail": message}
