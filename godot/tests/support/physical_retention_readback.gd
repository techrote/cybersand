extends RefCounted

# Test-local readiness over copied values only. This neither delivers feedback
# nor queries a World, issues an observation, changes a lease, or advances time.
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const ENVELOPE_FIELDS: Array[String] = ["actor_id", "instance_id", "equipment_epoch", "usable_index", "body_id"]
const CONTEXT_INTEGERS: Array[String] = ["world_instance_id", "native_generation", "mass_bits", "maximum",
	"coherence_ticks", "completed_tick", "water_units_initial", "water_units_remaining", "water_units_removed",
	"brine_cells_initial", "brine_cells_remaining", "brine_cells_removed"]


static func _failure(reason: String, expected: Variant = null, actual: Variant = null) -> Dictionary:
	var copied_expected: Variant = expected.duplicate(true) if expected is Dictionary or expected is Array else expected
	var copied_actual: Variant = actual.duplicate(true) if actual is Dictionary or actual is Array else actual
	return {"ready": false, "reason": reason, "details": {"expected": copied_expected, "actual": copied_actual},
		"context": {}, "world_instance_id": 0}


static func _equal(left: Variant, right: Variant) -> bool:
	return typeof(left) == typeof(right) and left == right


static func equipment_unchanged(before: Variant, after: Dictionary) -> bool:
	# Supports the original already-serialized baseline without decoding it.
	if before is PackedByteArray:
		return before == var_to_bytes(after)
	return before is Dictionary and var_to_bytes(before) == var_to_bytes(after)


static func equipment_differences(before: Variant, after: Dictionary) -> Array:
	var original: Variant = bytes_to_var(before) if before is PackedByteArray else before
	var changes: Array = []
	_differences(original, after, "equipment", changes)
	return changes


static func _differences(before: Variant, after: Variant, path: String, changes: Array) -> void:
	if typeof(before) != typeof(after):
		changes.append({"path": path, "kind": "type", "before": type_string(typeof(before)), "after": type_string(typeof(after))})
	elif before is Dictionary:
		if var_to_bytes(before.keys()) != var_to_bytes(after.keys()):
			changes.append({"path": path, "kind": "key_sequence", "before": before.keys(), "after": after.keys()})
		for key: Variant in before:
			if not after.has(key):
				changes.append({"path": path + "." + str(key), "kind": "removed", "before": var_to_str(before[key])})
			else:
				_differences(before[key], after[key], path + "." + str(key), changes)
		for key: Variant in after:
			if not before.has(key):
				changes.append({"path": path + "." + str(key), "kind": "added", "after": var_to_str(after[key])})
	elif var_to_bytes(before) != var_to_bytes(after):
		changes.append({"path": path, "kind": "value", "before": var_to_str(before), "after": var_to_str(after)})


static func _hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _actor(rows: Array, actor_id: int) -> Dictionary:
	var found: Dictionary = {}
	for value: Variant in rows:
		if not value is Dictionary or not value.get("actor_id") is int:
			return {}
		if value.actor_id == actor_id:
			if not found.is_empty():
				return {}
			found = value
	return found


static func evaluate(expected: Dictionary, current: Dictionary) -> Dictionary:
	for key: String in ["epoch", "actor_id", "equipment_epoch", "usable_index", "body_id",
		"native_generation", "minimum_publication_serial", "minimum_control_generation", "completed_tick"]:
		if not expected.get(key) is int:
			return _failure("expected." + key + ".type", "int", expected.get(key))
	for key: String in ["run_id", "instance_id"]:
		if not expected.get(key) is String or str(expected[key]).is_empty():
			return _failure("expected." + key, "nonempty String", expected.get(key))
	if not _hash(expected.get("policy_hash")):
		return _failure("expected.policy_hash", "full lowercase SHA256", expected.get("policy_hash"))
	if expected.epoch < 1 or expected.actor_id < 0 or expected.actor_id >= 8 \
		or expected.equipment_epoch < 1 or expected.body_id < 1 or expected.usable_index < -1 \
		or expected.usable_index >= 32 or expected.native_generation < 0 \
		or expected.minimum_publication_serial < 0 or expected.minimum_control_generation < 0 or expected.completed_tick < 0:
		return _failure("expected.identity_bounds")
	for key: String in ["context", "ledgers"]:
		if expected.has(key) and not expected[key] is Dictionary:
			return _failure("expected." + key + ".type", "Dictionary", expected[key])
	if expected.has("world_instance_id") and (not expected.world_instance_id is int or expected.world_instance_id == 0):
		return _failure("expected.world_instance_id", "nonzero opaque int", expected.world_instance_id)
	if not current.get("publication_serial") is int or current.publication_serial < expected.minimum_publication_serial:
		return _failure("publication_serial", expected.minimum_publication_serial, current.get("publication_serial"))
	for key: String in ["frame", "publication", "view"]:
		if not current.get(key) is Dictionary:
			return _failure(key + ".type", "Dictionary", current.get(key))
	var frame: Dictionary = current.frame
	var publication: Dictionary = current.publication
	var view: Dictionary = current.view
	for name: String in ["frame", "publication", "view"]:
		var value: Dictionary = current[name]
		for key: String in ["run_id", "epoch"]:
			if not _equal(value.get(key), expected[key]):
				return _failure(name + "." + key, expected[key], value.get(key))
	if not frame.get("actors") is Array or not publication.get("actors") is Array:
		return _failure("actor_rows", "frame/publication Arrays")
	if not frame.get("tick") is int or frame.tick < 0 or not frame.get("suspended") is bool:
		return _failure("frame.clock_or_suspension")
	if not _equal(view.get("tick"), frame.tick) or not _equal(view.get("suspended"), frame.suspended):
		return _failure("view.clock_or_suspension", [frame.tick, frame.suspended], [view.get("tick"), view.get("suspended")])
	# publication.tick is the equipment runtime counter, not the physical clock.
	if not publication.get("tick") is int or publication.tick < 0 \
		or not _equal(publication.get("frame_tick"), frame.tick) \
		or not _equal(publication.get("suspended"), frame.suspended):
		return _failure("publication.clock_or_suspension", [frame.tick, frame.suspended],
			[publication.get("tick"), publication.get("frame_tick"), publication.get("suspended")])
	var frame_row: Dictionary = _actor(frame.actors, expected.actor_id)
	var row: Dictionary = _actor(publication.actors, expected.actor_id)
	if frame_row.is_empty() or row.is_empty():
		return _failure("actor_row_missing_or_duplicate", expected.actor_id)
	if not view.get("equipment") is Dictionary or not _equal(view.get("actor_id"), expected.actor_id):
		return _failure("view.actor_or_equipment", expected.actor_id, view.get("actor_id"))
	var equipment: Dictionary = view.equipment
	for key: String in ENVELOPE_FIELDS:
		if not _equal(frame_row.get(key), expected[key]):
			return _failure("frame.actor." + key, expected[key], frame_row.get(key))
		if not _equal(row.get(key), expected[key]):
			return _failure("publication.actor." + key, expected[key], row.get(key))
		if key != "actor_id" and not _equal(equipment.get(key), expected[key]):
			return _failure("view.equipment." + key, expected[key], equipment.get(key))
	for key: String in ["run_id", "epoch"]:
		if not _equal(row.get(key), expected[key]):
			return _failure("publication.actor." + key, expected[key], row.get(key))
	if not frame_row.get("generation") is int or frame_row.generation < expected.minimum_control_generation \
		or not _equal(view.get("control_generation"), frame_row.generation):
		return _failure("current_control_generation", frame_row.get("generation"), view.get("control_generation"))
	# Production checks exact control generation at feedback DELIVERY. A later
	# pause/focus cancellation advances input authority while preserving the valid
	# native-owner context cache. The asynchronous publication need not equal the
	# later live lease generation; it must belong to this accepted owner interval,
	# never a pre-adoption or future generation. Full delivered context equality
	# and native owner/ledger checks below remain exact.
	if not row.get("generation") is int or row.generation < expected.minimum_control_generation \
		or row.generation > frame_row.generation:
		return _failure("publication.actor.generation", [expected.minimum_control_generation,frame_row.generation], row.get("generation"))
	for key: String in ["state"]:
		if not frame_row.get(key) is String or not _equal(row.get(key), frame_row[key]) \
			or not _equal(equipment.get(key), frame_row[key]):
			return _failure("current_equipment." + key, frame_row.get(key), [row.get(key), equipment.get(key)])
	for key: String in ["charge", "cooldown"]:
		for value: Variant in [row.get(key), equipment.get(key)]:
			if (not value is int and not value is float) or not is_finite(float(value)) \
				or float(value) < 0.0 or float(value) > (100.0 if key == "charge" else 60.0):
				return _failure("resource." + key, "finite bounded number", value)
		if float(row[key]) != float(equipment[key]):
			return _failure("resource_readback_not_delivered." + key, row[key], equipment[key])
	var context: Variant = row.get("metered_drain")
	if not Equipment._valid_metered_readback(context):
		return _failure("context.shape", "valid native-owner context", context)
	for key: String in CONTEXT_INTEGERS:
		if not context.get(key) is int:
			return _failure("context." + key + ".type", "int", context.get(key))
	if not context.get("initial_construction_receipt_available") is bool \
		or context.coherence_ticks < 0 or context.coherence_ticks > 12:
		return _failure("context.construction_or_coherence")
	for key: String in ["native_generation", "policy_hash", "completed_tick"]:
		if not _equal(context.get(key), expected[key]):
			return _failure("context." + key, expected[key], context.get(key))
	if not context.available or context.terminal or context.reason != "" or context.world_instance_id == 0:
		return _failure("context.unavailable_or_terminal", "available nonterminal native owner", context)
	if expected.has("world_instance_id") and context.world_instance_id != expected.world_instance_id:
		return _failure("context.world_instance_id", expected.world_instance_id, context.world_instance_id)
	if context.allowed_materials != [3, 24] or context.water_units_initial != 32 * context.maximum \
		or context.brine_cells_initial != 32:
		return _failure("context.initial_capacity_or_materials", "32Q Water /32 Brine; materials[3,24]", context)
	for section: String in ["context", "ledgers"]:
		for key: Variant in expected.get(section, {}):
			if not key is String or not _equal(context.get(key), expected[section][key]):
				return _failure("context.expected." + str(key), expected[section][key], context.get(key))
	if not equipment.get("metered_drain") is Dictionary \
		or var_to_bytes(equipment.metered_drain) != var_to_bytes(context):
		return _failure("context.readback_not_delivered", context, equipment.get("metered_drain"))
	return {"ready": true, "reason": "", "details": {"publication_serial": current.publication_serial,
		"runtime_tick": publication.tick, "frame_tick": publication.frame_tick,
		"matching_publication_generation":row.generation,"current_control_generation":frame_row.generation,
		"minimum_control_generation":expected.minimum_control_generation},
		"context": context.duplicate(true), "world_instance_id": int(context.world_instance_id)}
