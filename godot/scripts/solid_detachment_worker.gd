extends CyberSimulationWorker

# Dry, single-aggregate diagnostic lane. Reuses the ordinary pacing thread,
# native World and immutable snapshot machinery; no second simulation loop.
# Main reads only the mutex-protected copied reply, never this owner's World.
var _solid_reply_mutex: Mutex = Mutex.new()
var _solid_publication: Dictionary = {}
var _solid_pending_reply: Dictionary = {}
var _solid_last_request: int = 0
var _solid_refused_replacements: int = 0
# Set before start_worker and immutable for this owner's lifetime.
var solid_contact_observations_enabled: bool = false
var _contact_attempts: int = 0
var _contact_usec: int = 0
var _contact_max_usec: int = 0
var _contact_geometry_probes: int = 0
var _contact_support_probes: int = 0

func _populate_specialized_snapshot(snapshot: CyberSimulationSnapshot) -> void:
	if solid_contact_observations_enabled and not _simulation_failed \
		and _world.has_method(&"solid_detachment_contact_observation"):
		var started: int = Time.get_ticks_usec()
		var observation: Dictionary = _world.solid_detachment_contact_observation()
		observation["snapshot_serial"] = snapshot.serial
		observation["physics_epoch"] = snapshot.rigid_body_epoch
		observation["published_usec"] = Time.get_ticks_usec()
		_freeze_capture(observation)
		snapshot.solid_contact_observation = observation
		var elapsed: int = Time.get_ticks_usec() - started
		_contact_attempts += 1
		_contact_usec += elapsed
		_contact_max_usec = maxi(_contact_max_usec, elapsed)
		_contact_geometry_probes += int(observation.get("geometry_probes", 0))
		_contact_support_probes += int(observation.get("support_probes", 0))
		# Cumulative owner work survives overwritten publications and refusals.
		# Includes native observation, copied metadata and freezing the contact value.
		var work := {"attempts":_contact_attempts, "elapsed_usec":_contact_usec,
			"max_usec":_contact_max_usec, "geometry_probes":_contact_geometry_probes,
			"support_probes":_contact_support_probes}
		work.make_read_only()
		snapshot.solid_contact_work = work

func _refuse_replacement() -> void:
	_solid_reply_mutex.lock()
	_solid_refused_replacements += 1
	_solid_reply_mutex.unlock()

func queue_reset(_spawn_position: Vector2, _sampled_character_enabled: bool = true,
		_runtime_enclosure_recovery_enabled: bool = true) -> void:
	# This dedicated owner lives for exactly one detachment session. Resetting its
	# native World alone would leave the old main-thread Rapier aggregate alive.
	# Session.close/open joins this owner and retires its actual body together.
	_refuse_replacement()

func queue_actor_prototype_reset(_definitions: Array, _spawn_position: Vector2,
		_sampled_enabled: bool = true) -> int:
	_refuse_replacement()
	return 0

func queue_lab(command: Dictionary) -> void:
	# Reject mixed commands too: unrelated owner preparation runs before _apply_lab.
	if command.size() != 1 or not command.get("solid_detachment") is Dictionary:
		_refuse_replacement()
		return
	super.queue_lab(command)

func take_solid_reply(request_id: int) -> Dictionary:
	_solid_reply_mutex.lock()
	var result: Dictionary = {}
	if int(_solid_publication.get("request_id", -1)) == request_id:
		result = _solid_publication.duplicate(true)
	_solid_reply_mutex.unlock()
	return result

func _apply_lab(command: Dictionary) -> bool:
	if not command.has("solid_detachment"):
		if not command.is_empty():
			_refuse_replacement()
			_lab_status = "Lab replacement refused: reset the complete detachment session"
		return false
	for key: String in command:
		if key not in ["solid_detachment", "_owner_request_revision"]:
			_refuse_replacement()
			_lab_status = "Mixed detachment/scenario command refused"
			return false
	var input: Variant = command.get("solid_detachment")
	if not input is Dictionary:
		_lab_status = "Malformed solid-detachment command"
		return false
	var id_value: Variant = input.get("request_id", 0)
	if not id_value is int or int(id_value) <= _solid_last_request:
		_lab_status = "Stale solid-detachment request"
		return false
	_solid_last_request = int(id_value)
	if not _world.has_method(&"solid_detachment_command"):
		_solid_pending_reply = {"ok":false,"outcome":"NativeAPIUnavailable"}
	else:
		_solid_pending_reply = _world.solid_detachment_command(input)
		# Optional diagnostic values are copied only by the exclusive worker.
		# They expose neither the native World nor a mutable aggregate payload.
		var points: Variant = input.get("probe_points", PackedInt32Array())
		if points is PackedInt32Array and (points.size() & 1) == 0 and points.size() <= 256:
			var probe_materials := PackedInt32Array()
			var probe_body_ids := PackedInt32Array()
			for point: int in range(0, points.size(), 2):
				probe_materials.append(int(_world.material_at(points[point], points[point + 1])))
				probe_body_ids.append(int(_world.rigid_body_id_at(points[point], points[point + 1])))
			_solid_pending_reply["probe_materials"] = probe_materials
			_solid_pending_reply["probe_body_ids"] = probe_body_ids
		var snapshot_origin: Variant = input.get("snapshot_origin", Vector2i(-1, -1))
		var snapshot_size: Variant = input.get("snapshot_size", Vector2i.ZERO)
		if snapshot_origin is Vector2i and snapshot_size is Vector2i and snapshot_size.x > 0 and snapshot_size.y > 0:
			_solid_pending_reply["diagnostic_snapshot"] = _world.diagnostic_snapshot(
				snapshot_origin, snapshot_size, false)
		if bool(input.get("include_body_metrics", false)):
			_solid_pending_reply["body_metrics"] = _world.diagnostic_body_metrics()
	_solid_pending_reply["request_id"] = _solid_last_request
	_lab_status = "Solid detachment: " + str(_solid_pending_reply.get("outcome", "Invalid"))
	# Prevent the sampled character from adding unrelated material mutations in
	# the explicitly actor-free diagnostic lane. This does not change defaults.
	_sampled_character_enabled = false
	return true

func _publish_snapshot(step_ms: float, paused: bool, interval: int,
		force_full: bool = false, body_states: PackedFloat32Array = PackedFloat32Array(),
		body_epoch: int = 0) -> void:
	super._publish_snapshot(step_ms, paused, interval, force_full, body_states, body_epoch)
	if _solid_pending_reply.is_empty():
		return
	var output: Dictionary = _solid_pending_reply.duplicate(true)
	output["terrain_snapshot_revision"] = str(_snapshot_hard_surface_revision)
	output["terrain_chunks"] = _snapshot_hard_surface_chunk_rectangles.duplicate()
	output["terrain_chunks_valid"] = _snapshot_hard_surface_chunk_rectangles_valid
	output["source_probe"] = int(_world.material_at(51, 34))
	output["stump_probe"] = int(_world.material_at(51, 70))
	output["ground_probe"] = int(_world.material_at(80, 73))
	output["nearby_tree_probe"] = int(_world.material_at(9, 50))
	output["worker_failed"] = _simulation_failed
	output["actual_native_tick"] = int(_world.get_tick_index())
	output["configured_workers"] = int(_world.get_worker_threads())
	_solid_reply_mutex.lock()
	output["refused_replacements"] = _solid_refused_replacements
	_solid_publication = output
	_solid_reply_mutex.unlock()
	_solid_pending_reply = {}
