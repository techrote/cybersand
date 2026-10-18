extends RefCounted

# Shared runner/presentation adapter. The arena remains the exclusive owner;
# only its privilege-filtered observations enter example controllers.
const Arena = preload("res://scripts/thunderbowl_arena.gd")
const Contract = preload("res://scripts/thunderbowl_contract.gd")
const Factory = preload("res://examples/thunderbowl/controller_factory.gd")
var arena: CyberThunderbowlArena
var config: Dictionary = {}
var last_error: String = ""
var smart_directory: String = ""
var controller_rejections: int = 0
var controller_rejection_reasons: Array[String] = []
var _controllers: Array[RefCounted] = []
var _oracle: RefCounted
var _response_hashes: Dictionary = {}
var _last_snapshot: Dictionary = {}


func configure(value: Dictionary) -> bool:
	var candidate := Arena.new()
	if not candidate.configure(value):
		last_error = candidate.last_error
		return false
	if arena != null:
		arena.close()
	arena = candidate
	config = value.duplicate(true)
	_controllers.clear()
	_oracle = Factory.create("oracle")
	for definition: Dictionary in config.actors:
		_controllers.append(_oracle if definition.controller == "oracle" else Factory.create(definition.controller))
	_response_hashes.clear()
	controller_rejections = 0
	controller_rejection_reasons.clear()
	_last_snapshot = arena.snapshot()
	last_error = ""
	return true


func step(input_frames: Dictionary = {}) -> Dictionary:
	if arena == null or bool(_last_snapshot.get("finished", true)):
		return _last_snapshot.duplicate(true)
	var tick: int = int(_last_snapshot.tick)
	var views: Array[Dictionary] = []
	var actor_ids: Array[int] = []
	var oracle_views: Array = []
	# Gather every due view first. No controller can see a partially stepped rig.
	for actor_id: int in range(config.actors.size()):
		if _last_snapshot.alive[actor_id] == 0:
			continue
		var definition: Dictionary = config.actors[actor_id]
		var human: bool = str(definition.controller).begins_with("human_")
		if not human and tick % 6 != 0:
			continue
		var view: Dictionary = arena.observation(actor_id)
		if definition.controller == "oracle":
			oracle_views.append(view)
		else:
			views.append(view)
			actor_ids.append(actor_id)
	var commands: Array = []
	for index: int in range(views.size()):
		var actor_id: int = actor_ids[index]
		var controller: RefCounted = _controllers[actor_id]
		var id: String = config.actors[actor_id].controller
		if id.begins_with("human_"):
			var frame: Dictionary = input_frames.get(actor_id, Contract.neutral_input())
			_append_bound(controller.decide_input(views[index], frame), views[index], commands)
			continue
		elif id == "smart_link" and not smart_directory.is_empty():
			_smart_exchange(actor_id, controller, views[index])
		_append_bound(controller.decide(views[index]), views[index], commands)
	if not oracle_views.is_empty():
		var assigned: Dictionary = {}
		for view: Dictionary in oracle_views: assigned[int(view.actor_id)] = view
		var seen: Dictionary = {}
		var batch: Variant = _oracle.decide_batch(oracle_views)
		if not batch is Array or batch.size() > oracle_views.size():
			_reject_controller("oracle_batch_shape")
		else:
			for value: Variant in batch:
				if not Contract.valid_command(value):
					_reject_controller("oracle_command_shape")
					continue
				var actor_id: int = int(value.actor_id)
				if not assigned.has(actor_id) or seen.has(actor_id):
					_reject_controller("oracle_actor_assignment")
					continue
				seen[actor_id] = true
				_append_bound(value, assigned[actor_id], commands)
	_last_snapshot = arena.step(commands)
	return _last_snapshot.duplicate(true)


func _append_bound(value: Variant, view: Dictionary, commands: Array) -> void:
	if not Contract.valid_command(value):
		_reject_controller("command_shape")
		return
	# A policy receives one actor's observation; guessing another valid slot's
	# deterministic token must not grant authority over that slot in our batch.
	if int(value.actor_id) != int(view.actor_id) or value.run_id != view.run_id \
		or int(value.epoch) != int(view.epoch) or int(value.observed_tick) != int(view.tick) \
		or value.observation_id != view.observation_id:
		_reject_controller("observation_origin")
		return
	commands.append(value)


func _reject_controller(reason: String) -> void:
	controller_rejections += 1
	if controller_rejection_reasons.size() == 8:
		controller_rejection_reasons.pop_front()
	controller_rejection_reasons.append(reason)


func snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


func smart_statistics() -> Array:
	var result: Array = []
	for index: int in range(_controllers.size()):
		if config.actors[index].controller == "smart_link":
			result.append({"actor_id": index, "accepted": int(_controllers[index].accepted_results),
				"rejected": int(_controllers[index].rejected_results)})
	return result


func close() -> void:
	if arena != null:
		arena.close()
	arena = null
	_controllers.clear()
	_oracle = null


func _smart_exchange(actor_id: int, controller: RefCounted, view: Dictionary) -> void:
	# Optional bounded file adapter, outside arena.step and every 6 ticks only.
	# No waiting, networking or model execution occurs on the simulation owner.
	var request: Dictionary = controller.request(view)
	if not request.is_empty():
		var request_path: String = smart_directory.path_join("actor-%d-request.json" % actor_id)
		if not write_json(request_path, request):
			last_error = "Could not publish smart-link request: " + request_path
	var response_path: String = smart_directory.path_join("actor-%d-response.json" % actor_id)
	if not FileAccess.file_exists(response_path):
		return
	var file: FileAccess = FileAccess.open(response_path, FileAccess.READ)
	if file == null:
		return
	if file.get_length() > Contract.MAX_JSON_BYTES:
		file.close()
		last_error = "Smart-link response exceeds 64 KiB"
		return
	var text: String = file.get_as_text()
	file.close()
	var digest: String = text.sha256_text()
	if _response_hashes.get(actor_id, "") == digest:
		return
	_response_hashes[actor_id] = digest
	var response: Variant = JSON.parse_string(text)
	controller.submit_decision(response if response is Dictionary else {})


static func write_json(path: String, value: Dictionary) -> bool:
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.flush()
	var result: Error = file.get_error()
	file.close()
	return result == OK and DirAccess.rename_absolute(temporary, path) == OK
