class_name CyberObjectShardLabSession
extends RefCounted

const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
const Capture = preload("res://scripts/object_shard_capture.gd")
const MAX_EVENTS: int = 256
const MAX_SAMPLES: int = 7200
const MAX_PENDING_EDITS: int = 256
const MAX_EDITS_PER_FRAME: int = 16

var native: RefCounted
var bridge: CyberObjectShardPhysicsBridge
var frame: Dictionary = {}
var paused: bool = true
var failed: bool = false
var scenario: int = 1
var seed: int = 12
var status: String = "Not started"
var last_refusal: Dictionary = {}
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var promotion_max_usec: int = 0
var frame_max_usec: int = 0
var last_frame_usec: int = 0
var last_copy_usec: int = 0
var last_native_usec: int = 0
var last_snapshot_copies: int = 0
var capture := Capture.new()
var capture_enabled: bool = false
var capture_directory: String = "user://objectshard-results"
var session_metrics_start: Dictionary = {}
var total_events: int = 0
var total_samples: int = 0
var authored_fixture_fire: int = 0
var burner_enabled: bool = false
var burner_cells: Array[Vector2i] = []
var pending_edits: Array[Dictionary] = []
var pending_edit_keys: Dictionary = {}
var edit_queue_refusals: int = 0
var last_edit_result: Dictionary = {}
var configured_size := Vector2i(192, 128)


func open(next_scenario: int = 1, next_seed: int = 12, options: Dictionary = {}) -> Dictionary:
	if not ClassDB.class_exists(&"CyberObjectShardLab"):
		return _failure("Source-matched ObjectShard native extension is unavailable")
	if not frame.is_empty():
		capture.checkpoint(int(frame.get("tick", 0)), {"reason": "Explicit session reset", "pending_edits_cancelled": pending_edits.size(),
			"inventory_disposal": "Whole native Lab reset; old ownership handles and transactions retire"})
	scenario = next_scenario
	seed = next_seed
	if bridge != null:
		bridge.shutdown()
	bridge = Bridge.new()
	var result: Dictionary
	var desired_size := Vector2i(int(options.get("width", 192)), int(options.get("height", 128)))
	if native != null and desired_size != configured_size:
		# Explicit session disposal precedes replacing the differently sized Lab
		# owner. No inventory or obsolete receipt can survive into the new owner.
		result = native.reset(0, seed)
		if not result.get("ok", false):
			return _failure("Canvas replacement reset refused: " + str(result))
		native = null
	if native == null:
		native = ClassDB.instantiate(&"CyberObjectShardLab")
		result = native.configure({"scenario": scenario, "seed": seed, "width": desired_size.x, "height": desired_size.y})
		configured_size = desired_size
	else:
		result = native.reset(scenario, seed)
	if not result.get("ok", false):
		return _failure("Native reset refused: " + str(result))
	failed = false
	paused = true
	events.clear()
	samples.clear()
	last_refusal.clear()
	promotion_max_usec = 0
	frame_max_usec = 0
	total_events = 0
	total_samples = 0
	authored_fixture_fire = 0
	burner_enabled = false
	burner_cells.clear()
	pending_edits.clear()
	pending_edit_keys.clear()
	edit_queue_refusals = 0
	last_edit_result.clear()
	frame = native.snapshot()
	session_metrics_start = frame.get("metrics", {}).duplicate(true)
	var trace_path: String = ""
	if capture_enabled:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
		trace_path = capture_directory.path_join("objectshard-%d-%d.trace.jsonl" % [int(frame.session), Time.get_unix_time_from_system()])
	var manifest_path: String = OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")
	var manifest_sha: String = FileAccess.get_sha256(manifest_path) if not manifest_path.is_empty() and FileAccess.file_exists(manifest_path) else ""
	capture.begin({"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"package_manifest_sha256": manifest_sha, "scenario": scenario, "seed": seed, "session": frame.session,
		"engine": Engine.get_version_info(), "platform": OS.get_name(), "width": frame.width, "height": frame.height}, trace_path)
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
	var capture_io_started: int = capture.io_usec
	_feed_burner()
	capture.write("step_requested", int(frame.get("tick", 0)), {"force": force, "paused": paused})
	bridge.begin_frame()
	last_copy_usec = 0
	last_snapshot_copies = 0
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
			last_refusal.clear()
			_refresh()
		elif str(preparation.get("outcome", "")) not in ["Busy", "Anchored"]:
			# Keep refusal pressure visible without evicting every useful edit from
			# the event ring when an unchanged capacity boundary persists.
			if str(preparation.get("outcome", "")) != str(last_refusal.get("outcome", "")) or str(preparation.get("detail", "")) != str(last_refusal.get("detail", "")):
				_event("DiscoveryRefused", preparation)
			last_refusal = preparation.duplicate(true)
		var admission: Dictionary = frame.get("admission", {})
		if admission.get("census_complete", false) and int(admission.get("eligible", 0)) == 0 and int(admission.get("refused_geometry", 0)) == 0 and int(admission.get("unknown_boundary", 0)) == 0:
			last_refusal.clear()
	if bool(frame.promotion.get("present", false)):
		if not _promote():
			return {"ok": false, "outcome": "PromotionHeld"}
	if not _synchronize():
		return {"ok": false, "outcome": "SynchronizationFailed"}
	if not bool(frame.get("paused", true)):
		var moved: Dictionary = bridge.step_motion(Callable(native, "accept_motion"), int(frame.tick))
		if not moved.get("ok", false):
			return _failure("Physics motion outside admitted envelope: " + str(moved))
		# Accepted motion has reconciled native occupancy and contact history.
		# Publish the matching accepted pose serial before any further edit can
		# use it; presentation never pairs a new RID pose with an old receipt.
		_refresh()
	var diagnostics_started: int = Time.get_ticks_usec()
	var physics_observation: Dictionary = _physics_diagnostics(false)
	var diagnostics_usec: int = Time.get_ticks_usec() - diagnostics_started
	_record_sample(physics_observation)
	capture.write("step_completed", int(frame.tick), {"native_tick": frame.tick, "physics": physics_observation})
	last_frame_usec = Time.get_ticks_usec() - started
	frame_max_usec = maxi(frame_max_usec, last_frame_usec)
	samples[-1]["frame_usec"] = last_frame_usec
	samples[-1]["diagnostics_usec"] = diagnostics_usec
	samples[-1]["trace_io_usec"] = capture.io_usec - capture_io_started
	status = "Tick %d · %d moving owners · %s" % [int(frame.tick), bridge.bodies.size(), "paused" if paused else "running"]
	if not last_refusal.is_empty():
		status += " · discovery " + str(last_refusal.get("outcome", "refused")) + ": inventory stays with its current owner"
	return {"ok": true, "tick": frame.tick}


func edit(position: Vector2i, material: int, state_a: int = 0, state_b: int = 0, temperature: int = 200) -> Dictionary:
	if native == null or failed or bool(frame.get("paused", false)):
		return {"ok": false, "outcome": "Fenced"}
	var owned: Dictionary = _owned_cell(position)
	if not owned.is_empty():
		var refusal: Dictionary = {"ok": false, "outcome": "OwnedMaterial", "detail": "Moving material accepts structural erasure or ignition; World paint cannot replace its inventory."}
		if material == 0 and native.has_method("erase_shard"):
			var shard: Dictionary = owned.shard
			var cell: int = int(owned.cell)
			var request: Dictionary = {"session": shard.session, "id": shard.id, "generation": shard.generation,
				"sequence": frame.get("next_transaction", 0), "body_generation": shard.body_generation,
				"geometry_revision": shard.applied_physics_revision, "pose_serial": shard.get("pose_serial", 0),
				"material_revision": shard.material_revision, "cell": cell, "incarnation": shard.incarnations[cell],
				"expected": {"material": int(shard.materials[cell]), "state_a": int(shard.states_a[cell]),
					"state_b": int(shard.states_b[cell]), "temperature": int(shard.temperature[cell])}, "capability_version": 1}
			refusal = native.erase_shard(request)
			_event("ShardEdit", {"request": request, "position": position, "result": refusal})
			capture.action(int(frame.get("tick", 0)), "erase_shard", {"position": position, "receipt": request}, refusal)
			_refresh()
			if refusal.get("ok", false) and not _synchronize():
				return {"ok": false, "outcome": "GeometryHeld", "detail": status}
		else:
			capture.action(int(frame.get("tick", 0)), "edit", {"position": position, "material": material,
				"state_a": state_a, "state_b": state_b, "temperature": temperature}, refusal)
		return refusal
	var result: Dictionary = native.edit_cell(position, material, state_a, state_b, temperature)
	_event("OrdinaryEdit", {"position": position, "material": material, "result": result})
	capture.action(int(frame.get("tick", 0)), "edit", {"position": position, "material": material,
		"state_a": state_a, "state_b": state_b, "temperature": temperature}, result)
	_refresh()
	return result


func queue_edit(position: Vector2i, material: int, state_a: int = 0, state_b: int = 0, temperature: int = 200) -> Dictionary:
	var key: String = "%d:%d:%d" % [position.x, position.y, material]
	if pending_edit_keys.has(key):
		return {"ok": true, "outcome": "Coalesced"}
	if pending_edits.size() >= MAX_PENDING_EDITS:
		edit_queue_refusals += 1
		last_edit_result = {"ok": false, "outcome": "EditQueueCapacity", "detail": "256 queued cells; continue after the visible pending count drains."}
		return last_edit_result
	var target: Dictionary = inspect(position)
	pending_edits.append({"position": position, "material": material, "state_a": state_a, "state_b": state_b,
		"temperature": temperature, "session": frame.get("session", 0), "requested_tick": frame.get("tick", 0),
		"owner": target.get("owner", "World"), "id": target.get("id", 0), "incarnation": target.get("incarnation", 0), "key": key})
	pending_edit_keys[key] = true
	return {"ok": true, "outcome": "Queued", "pending": pending_edits.size()}


func author_cells(operations: Array[Dictionary]) -> Dictionary:
	# Scene setup is a bounded series of ordinary native edits, with one copied
	# publication per batch. Physics is paused and no shard exists, so neither
	# owner selection nor an installed dynamic-geometry receipt can be skipped.
	if native == null or not paused or failed or bool(frame.get("paused", false)) or not frame.get("shards", []).is_empty() or operations.size() > 32:
		return {"ok": false, "outcome": "AuthoredBatchFenced", "accepted_edits": 0, "refused_edits": operations.size()}
	var accepted: int = 0
	var refused: int = 0
	for operation: Dictionary in operations:
		var position: Vector2i = operation.position
		var material: int = int(operation.material)
		var result: Dictionary = native.edit_cell(position, material, 0, 0, 200)
		capture.action(int(frame.get("tick", 0)), "edit", {"position": position, "material": material,
			"state_a": 0, "state_b": 0, "temperature": 200}, result)
		if result.get("ok", false):
			accepted += 1
		else:
			refused += 1
	_event("AuthoredMaterialBatch", {"accepted_edits": accepted, "refused_edits": refused})
	_refresh()
	return {"ok": refused == 0, "accepted_edits": accepted, "refused_edits": refused}


func drain_edits() -> int:
	var processed: int = 0
	while not pending_edits.is_empty() and processed < MAX_EDITS_PER_FRAME:
		var request: Dictionary = pending_edits.pop_front()
		pending_edit_keys.erase(request.key)
		var target: Dictionary = inspect(request.position)
		if int(request.session) != int(frame.get("session", 0)) or str(request.owner) != str(target.get("owner", "World")) or int(request.id) != int(target.get("id", 0)):
			last_edit_result = {"ok": false, "outcome": "EditTargetMoved", "detail": "Owner changed while this input waited; no replacement owner was edited."}
			_event("QueuedEditRefused", {"request": request, "result": last_edit_result})
		else:
			last_edit_result = ignite(request.position) if int(request.material) == -2 else edit(request.position,
				int(request.material), int(request.state_a), int(request.state_b), int(request.temperature))
		processed += 1
	return processed


func set_burner(cells: Array[Vector2i], enabled: bool) -> Dictionary:
	if cells.size() > 64:
		return {"ok": false, "outcome": "BurnerCapacity"}
	burner_cells = cells.duplicate()
	burner_enabled = enabled
	var result: Dictionary = {"ok": true, "outcome": "BurnerEnabled" if enabled else "BurnerDisabled"}
	capture.action(int(frame.get("tick", 0)), "burner", {"cells": cells, "enabled": enabled}, result)
	return result


func _feed_burner() -> void:
	if not burner_enabled or native == null or failed or bool(frame.get("paused", false)):
		return
	# A visible fixed World apparatus authors only genuine Fire into genuinely
	# empty World cells. It neither overwrites shard inventory nor deletes Wood.
	# The selected native Fire contact law decides whether Wood ignites.
	var created: int = 0
	for position: Vector2i in burner_cells:
		var target: Dictionary = inspect(position)
		if str(target.get("owner", "World")) == "World" and int(target.get("material", -1)) == 0:
			var result: Dictionary = native.edit_cell(position, 6, 32, 0, 650)
			if result.get("ok", false):
				created += 1
	if created > 0:
		authored_fixture_fire += created
		_event("FixtureFireAuthored", {"cells_created": created, "total_authored": authored_fixture_fire})
		_refresh()


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
				capture.action(int(frame.get("tick", 0)), "ignite", {"position": position, "owner": shard.id, "cell": cell}, result)
				_refresh()
				return result
	var result: Dictionary = native.ignite(position)
	_event("IgniteWorld", {"position": position, "result": result})
	capture.action(int(frame.get("tick", 0)), "ignite", {"position": position, "owner": "World"}, result)
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


func _owned_cell(position: Vector2i) -> Dictionary:
	for shard: Dictionary in frame.get("shards", []):
		if not shard.get("owns_inventory", false):
			continue
		var local: Vector2 = _pose(shard).affine_inverse() * (Vector2(position) + Vector2.ONE * 0.5)
		var x: int = floori(local.x)
		var y: int = floori(local.y)
		if x >= 0 and y >= 0 and x < int(shard.width) and y < int(shard.height):
			var cell: int = y * int(shard.width) + x
			if int(shard.materials[cell]) != 0:
				return {"shard": shard, "cell": cell}
	return {}


func set_paused(value: bool) -> void:
	paused = value
	capture.action(int(frame.get("tick", 0)), "pause", {"paused": value}, {"ok": true})


func export_result() -> Dictionary:
	var owners: Array[Dictionary] = []
	for shard: Dictionary in frame.get("shards", []):
		var owner: Dictionary = {}
		for key: String in ["session", "id", "generation", "lifecycle", "owns_inventory", "structural", "cargo", "products",
			"width", "height", "origin_x", "origin_y", "body_generation", "material_revision", "topology_revision",
			"geometry_revision", "applied_physics_revision", "geometry_pending", "mask_digest", "shape_digest",
			"mass", "com_x", "com_y", "inertia", "split_pending", "islands"]:
			owner[key] = shard.get(key)
		var inventory: Dictionary = {}
		for material: int in shard.get("materials", PackedByteArray()):
			if material != 0:
				inventory[str(material)] = int(inventory.get(str(material), 0)) + 1
		owner["material_populations"] = inventory
		owner["actual_pose"] = Capture.json_value(_pose(shard))
		owners.append(owner)
	capture.checkpoint(int(frame.get("tick", 0)), {"failed": failed, "status": status, "owners": owners})
	return {"schema": "objectshard-lab-observation-v2", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine": Engine.get_version_info(), "platform": OS.get_name(), "scenario": scenario, "seed": seed,
		"session": frame.get("session", 0), "tick": frame.get("tick", 0), "failed": failed, "status": status,
		"last_refusal": last_refusal.duplicate(true),
		"capabilities": native.capabilities() if native != null else {}, "accounting": frame.get("accounting", {}),
		"accounting_scope": "Coordinator cumulative authored creation/destruction, transfers and explicit reset disposal; not newly zeroed per-session counts",
		"native_metrics": frame.get("metrics", {}), "physics_metrics": bridge.timings if bridge != null else {},
		"native_metric_scope": "native_metrics are current-session counters and maxima when lifetime_metrics is present; otherwise native_session_counters supplies additive deltas. Maxima are never subtracted.",
		"native_session_counters": _session_counters(), "native_process_totals_at_session_start": session_metrics_start,
		"native_lifetime_metrics": frame.get("lifetime_metrics", {}),
		"native_lifetime_metric_scope": frame.get("lifetime_metrics_scope", "Native owner instance; canvas replacement starts a new owner"),
		"physics_diagnostics": _physics_diagnostics(), "admission": frame.get("admission", {}),
		"capture": capture.metadata(), "named_actions": capture.actions.duplicate(true),
		"observation_window": {"events_retained": events.size(), "events_total": total_events,
			"samples_retained": samples.size(), "samples_total": total_samples, "complete_input_replay": false},
		"authored_fixture_fire_cells": authored_fixture_fire,
		"burner": {"enabled": burner_enabled, "cells": burner_cells, "scope": "Authored external World Fire; chemistry products counted independently"},
		"edit_queue": {"pending": pending_edits.duplicate(true), "capacity": MAX_PENDING_EDITS,
			"per_frame_limit": MAX_EDITS_PER_FRAME, "capacity_refusals": edit_queue_refusals, "last_result": last_edit_result},
		"promotion_max_usec": promotion_max_usec, "frame_max_usec": frame_max_usec,
		"owners": owners,
		"events": events.duplicate(true), "samples": samples.duplicate(true),
		"owner_acceptance": "unrecorded; automated execution is not physical acceptance"}


func close() -> void:
	paused = true
	capture.close()
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
	var native_changed: bool = false
	var installed: Dictionary = bridge.install_terrain(frame.get("terrain_chunks", []))
	if not installed.get("ok", false):
		_failure("Terrain synchronization failed: " + str(installed))
		return false
	for shard: Dictionary in frame.get("shards", []):
		if not bridge.bodies.has(int(shard.id)):
			continue
		if not shard.get("geometry_pending",false):
			var refreshed: Dictionary = bridge.refresh_motion_domain(shard)
			if not refreshed.get("ok",false):
				_failure("Motion domain held: "+str(refreshed))
				return false
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
		_event(kind, {"id": shard.id, "geometry_revision": shard.geometry_revision,
			"material_revision": shard.material_revision, "mass": shard.mass, "com_x": shard.com_x, "com_y": shard.com_y,
			"installation": updated, "acknowledgement": accepted})
		native_changed = true
	# Installing unchanged terrain reads back the backend; it does not mutate the
	# native owner. Copy a new material publication only after an actual native ACK.
	# The caller already refreshes after step/edit/promotion. This avoids two whole
	# Lab copies per ordinary frame without skipping a geometry or ownership barrier.
	if native_changed:
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
	last_snapshot_copies += 1


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
	total_events += 1
	if events.size() == MAX_EVENTS:
		events.pop_front()
	events.append({"tick": frame.get("tick", 0), "kind": kind, "detail": detail.duplicate(true)})
	capture.write("event", int(frame.get("tick", 0)), {"kind": kind, "detail": detail})


func _record_sample(physics_observation: Dictionary) -> void:
	total_samples += 1
	if samples.size() >= MAX_SAMPLES:
		# A fixed-size observation window, never an unbounded owner-facing log.
		samples.pop_front()
	samples.append({"tick": frame.tick, "frame_usec": last_frame_usec, "native_usec": last_native_usec,
		"snapshot_copies": last_snapshot_copies,
		"copy_usec": last_copy_usec, "rapier_usec": bridge.timings.rapier_step_usec,
		"flush_usec": bridge.timings.rapier_flush_usec, "geometry_usec": bridge.timings.geometry_install_usec,
		"terrain_usec": bridge.timings.terrain_install_usec, "physics": physics_observation})


func _session_counters() -> Dictionary:
	var counters: Dictionary = {}
	var current: Dictionary = frame.get("metrics", {})
	if frame.has("lifetime_metrics"):
		return current.duplicate(true)
	for key: String in current:
		if key.ends_with("_max") or key.contains("peak") or key.contains("bytes") or key.contains("age"):
			continue
		if current[key] is int or current[key] is float:
			counters[key] = current[key] - session_metrics_start.get(key, 0)
	return counters


func _physics_diagnostics(include_events: bool = true) -> Dictionary:
	if bridge == null:
		return {}
	if bridge.has_method("diagnostics"):
		var result: Dictionary = bridge.call("diagnostics")
		if not include_events:
			result.erase("events")
		return result
	var poses: Array[Dictionary] = []
	for id: Variant in bridge.bodies:
		var body: Dictionary = bridge.bodies[id]
		poses.append({"id": id, "pose": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM),
			"velocity": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),
			"angular_velocity": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY),
			"sleeping": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING)})
	return {"scope": "direct backend observation; no pose serial advanced", "bodies": poses}


func _failure(message: String) -> Dictionary:
	failed = true
	paused = true
	status = message
	_event("Held", {"reason": message})
	capture.write("failure", int(frame.get("tick", 0)), {"status": message, "physics": _physics_diagnostics()})
	return {"ok": false, "outcome": "Held", "detail": message}
