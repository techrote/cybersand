extends CyberSimulationWorker

# Dry, single-aggregate diagnostic lane. Reuses the ordinary pacing thread,
# native World and immutable snapshot machinery; no second simulation loop.
# Main reads only the mutex-protected copied reply, never this owner's World.
var _solid_reply_mutex: Mutex = Mutex.new()
var _solid_publication: Dictionary = {}
var _solid_pending_reply: Dictionary = {}
var _solid_last_request: int = 0

func take_solid_reply(request_id: int) -> Dictionary:
	_solid_reply_mutex.lock()
	var result: Dictionary = {}
	if int(_solid_publication.get("request_id", -1)) == request_id:
		result = _solid_publication.duplicate(true)
	_solid_reply_mutex.unlock()
	return result

func _apply_lab(command: Dictionary) -> bool:
	if not command.has("solid_detachment"):
		if _native_representation_fenced() and not command.is_empty():
			_lab_status = "Lab change refused during native representation transaction"
			return false
		return super._apply_lab(command)
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
	_solid_publication = output
	_solid_reply_mutex.unlock()
	_solid_pending_reply = {}
