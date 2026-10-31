extends "res://scripts/simulation_worker.gd"

# Test-only delivery/scheduling seams around the existing live owner. This is
# NOT a second simulation loop or a naturally queued network transport. The
# production latest-slot handoff cannot itself return an old serial.
const MAX_PACKETS: int = 8
const MAX_GATES: int = 4
const GATE_TIMEOUT_USEC: int = 15000000
var packets: Array[Dictionary] = [] # Main-thread retained immutable publications.
var deliveries: Array[Dictionary] = []
var capture_name: String = ""
var delivery_slot: int = -1
var delivery_name: String = ""
var capture_overflow: bool = false
var normal_handoffs: int = 0
var _gate_mutex := Mutex.new()
var _gate: Dictionary = {}
var _gate_history: Array[Dictionary] = []


static func packet_values(packet: CyberSimulationSnapshot) -> Dictionary:
	var copied: Dictionary = {}
	for property: Dictionary in packet.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			copied[str(property.name)] = packet.get(property.name)
	return copied


static func packet_bytes(packet: CyberSimulationSnapshot) -> PackedByteArray:
	return var_to_bytes(packet_values(packet))


static func digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func request_capture(label: String) -> bool:
	if not capture_name.is_empty() or packets.size() >= MAX_PACKETS:
		capture_overflow = true
		return false
	capture_name = label
	return true


func deliver(slot: int, label: String) -> bool:
	if delivery_slot >= 0 or slot < 0 or slot >= packets.size() or deliveries.size() >= 16:
		return false
	delivery_slot = slot
	delivery_name = label
	return true


func take_latest_snapshot(after_serial: int) -> CyberSimulationSnapshot:
	# The sole running worker still owns publication and all native operations.
	var genuine: CyberSimulationSnapshot = super.take_latest_snapshot(after_serial)
	if genuine != null:
		normal_handoffs += 1
		if not capture_name.is_empty():
			var bytes: PackedByteArray = packet_bytes(genuine)
			packets.append({"name":capture_name, "packet":genuine, "sha256":digest(bytes),
				"json_sha256":digest(JSON.stringify(packet_values(genuine)).to_utf8_buffer()),
				"size":bytes.size(), "serial":genuine.serial, "native_tick":genuine.tick_index,
				"epoch":genuine.rigid_body_epoch, "world_generation":genuine.render_world_generation,
				"captured_usec":Time.get_ticks_usec(), "published_usec":genuine.published_usec,
				"owner":get_instance_id(), "owner_running":_thread.is_started() and _thread.is_alive()})
			capture_name = ""
	if delivery_slot < 0:
		return genuine
	var retained: Dictionary = packets[delivery_slot]
	var packet: CyberSimulationSnapshot = retained.packet
	deliveries.append({"name":delivery_name, "slot":delivery_slot,
		"serial":packet.serial, "after_serial":after_serial,
		"live_serial":genuine.serial if genuine != null else -1,
		"live_native_tick":genuine.tick_index if genuine != null else -1,
		"epoch":packet.rigid_body_epoch, "world_generation":packet.render_world_generation,
		"captured_sha256":retained.sha256, "delivery_sha256":digest(packet_bytes(packet)),
		"delivered_usec":Time.get_ticks_usec(), "owner":get_instance_id(),
		"owner_running":_thread.is_started() and _thread.is_alive()})
	delivery_slot = -1
	delivery_name = ""
	return packet


func arm_gate(label: String) -> bool:
	_gate_mutex.lock()
	var allowed: bool = (_gate.is_empty() or bool(_gate.get("returned", false))) \
		and _gate_history.size() < MAX_GATES
	if allowed:
		_gate = {"name":label, "armed":true, "extracted":false, "released":false,
			"returned":false, "timed_out":false, "release_from_stop":false}
	_gate_mutex.unlock()
	return allowed


func gate_state() -> Dictionary:
	_gate_mutex.lock()
	var result: Dictionary = _gate.duplicate(true)
	_gate_mutex.unlock()
	return result


func release_gate(from_stop: bool = false) -> void:
	_gate_mutex.lock()
	if not _gate.is_empty():
		_gate.released = true
		_gate.release_from_stop = from_stop
		_gate["released_usec"] = Time.get_ticks_usec()
	_gate_mutex.unlock()


func gate_history() -> Array[Dictionary]:
	_gate_mutex.lock()
	var result: Array[Dictionary] = _gate_history.duplicate(true)
	_gate_mutex.unlock()
	return result


func _consume_physical_usables(requests: Array, body_epoch: int, allowed: bool,
	captured_frame: Dictionary = {}) -> void:
	var held: bool = false
	_gate_mutex.lock()
	if not requests.is_empty() and bool(_gate.get("armed", false)):
		held = true
		_gate.armed = false
		_gate.extracted = true
		_gate["requests"] = requests.duplicate(true)
		_gate["frame"] = captured_frame.duplicate(true)
		_gate["body_epoch"] = body_epoch
		_gate["allowed"] = allowed
		_gate["extracted_usec"] = Time.get_ticks_usec()
	_gate_mutex.unlock()
	if held:
		# Outside the production mutex: Main and Rapier remain automatic and can
		# perform normal cancellation. This bounded preconsume scheduling gate
		# does not claim to be a slow native tick or a native-busy phase probe.
		var deadline: int = Time.get_ticks_usec() + GATE_TIMEOUT_USEC
		while true:
			_gate_mutex.lock()
			var released: bool = bool(_gate.released)
			if not released and Time.get_ticks_usec() >= deadline:
				_gate.timed_out = true
				_gate.released = true
				released = true
			_gate_mutex.unlock()
			if released:
				break
			OS.delay_usec(1000)
	super._consume_physical_usables(requests, body_epoch, allowed, captured_frame)
	if held:
		# The inherited owner alone reads its equipment runtime. Only copied
		# values cross back to Main; no World, node or body RID is exposed.
		var copied: Dictionary = _physical_usables.snapshot()
		_gate_mutex.lock()
		_gate.returned = true
		_gate["returned_usec"] = Time.get_ticks_usec()
		_gate["runtime_after"] = copied
		_gate_history.append(_gate.duplicate(true))
		_gate_mutex.unlock()


func stop_worker() -> void:
	# Failure cleanup cannot strand a worker at this test-only scheduling gate.
	if bool(gate_state().get("extracted", false)) and not bool(gate_state().get("returned", false)):
		release_gate(true)
	super.stop_worker()


func save_packets(directory: String, prefix: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(packets.size()):
		var record: Dictionary = packets[index]
		var bytes: PackedByteArray = packet_bytes(record.packet)
		var json_bytes: PackedByteArray = JSON.stringify(packet_values(record.packet)).to_utf8_buffer()
		var relative: String = "%s-packet-%02d.bin" % [prefix, index]
		var output := FileAccess.open(directory.path_join(relative), FileAccess.WRITE)
		if output != null:
			output.store_buffer(bytes)
			output.close()
		var json_relative: String = relative.trim_suffix(".bin") + ".json"
		var json_output := FileAccess.open(directory.path_join(json_relative), FileAccess.WRITE)
		if json_output != null:
			json_output.store_buffer(json_bytes)
			json_output.close()
		var copied: Dictionary = record.duplicate()
		copied.erase("packet")
		copied["retired_sha256"] = digest(bytes)
		copied["artifact"] = relative
		copied["json_artifact"] = json_relative
		copied["retired_json_sha256"] = digest(json_bytes)
		copied["artifact_written"] = output != null and json_output != null
		result.append(copied)
	return result
