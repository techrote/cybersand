extends RefCounted
## WB-AGENT-001 (#526): strictly bounded main->worker command envelope.
##
## Validate BEFORE duplicate(true) crosses the mutex-backed command queue.
## This is a shape/size check, NOT native material/scope authorization, render
## proof, an apply receipt or permission for a model to invoke host-only calls.
## The simulation worker must still revalidate all physical preconditions at
## its exclusive consume boundary.
const MAX_PRIMITIVES: int = 8
const MAX_PROTECTED_REGIONS: int = 32
const MAX_IDENTIFIER_LENGTH: int = 128


static func _keys_only(value: Dictionary, accepted: Array) -> bool:
	if value.size() > accepted.size():
		return false
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING or key not in accepted:
			return false
	return true


static func _identifier(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() \
		and value.length() <= MAX_IDENTIFIER_LENGTH


static func _operation(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var op: Dictionary = value
	if not op.has("shape") or typeof(op.shape) != TYPE_STRING:
		return false
	var required: Array = ["material"]
	var accepted: Array = ["shape","material","replace_only_material"]
	match op.shape:
		"disc":
			required.append_array(["x","y","radius"])
			accepted.append_array(["x","y","radius"])
		"line", "rectangle":
			required.append_array(["x0","y0","x1","y1"])
			accepted.append_array(["x0","y0","x1","y1"])
		_:
			return false
	if not _keys_only(op,accepted):
		return false
	for field: String in required:
		if not op.has(field) or typeof(op[field]) != TYPE_INT:
			return false
	if op.has("replace_only_material") \
			and typeof(op.replace_only_material) != TYPE_INT:
		return false
	return true


static func _render_identity(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var identity: Dictionary = value
	if not _keys_only(identity,[
		"render_snapshot_serial","world_generation","world_revision","tick",
		"viewport_width","viewport_height"
	]):
		return false
	for key: String in ["render_snapshot_serial","world_generation","world_revision","tick"]:
		if not identity.has(key) or typeof(identity[key]) != TYPE_INT:
			return false
	for key: String in ["viewport_width","viewport_height"]:
		if identity.has(key) and typeof(identity[key]) != TYPE_INT:
			return false
	return true


## Returns true only for one small, known, versioned command envelope.
## Application-level failures should still return an authoritative worker
## refusal, not a boolean 'applied' claim. This is an admission decision only.
static func valid(command: Variant) -> bool:
	if not command is Dictionary:
		return false
	var value: Dictionary = command
	if value.size() < 2 or value.size() > 6:
		return false
	if typeof(value.get("schema_version",null)) != TYPE_INT \
			or int(value.schema_version) != 1:
		return false
	if typeof(value.get("action",null)) != TYPE_STRING:
		return false
	match value.action:
		"authorize_task":
			if not _keys_only(value,["action","schema_version","task_id",
					"scope","protected","allowed_materials"]):
				return false
			if not _identifier(value.get("task_id",null)) \
					or not value.get("scope",null) is Rect2i:
				return false
			var protected: Variant = value.get("protected",null)
			var allowed: Variant = value.get("allowed_materials",null)
			if not protected is Array or protected.size() > MAX_PROTECTED_REGIONS \
					or not allowed is Array or allowed.is_empty() \
					or allowed.size() > 2:
				return false
			for region: Variant in protected:
				if not region is Rect2i:
					return false
			for material: Variant in allowed:
				if typeof(material) != TYPE_INT:
					return false
			return true
		"observe":
			if not _keys_only(value,["action","schema_version","region","detail"]):
				return false
			if value.has("region") and not value.region is Rect2i:
				return false
			if value.has("detail") and (
					typeof(value.detail) != TYPE_STRING \
					or value.detail not in ["cells","counts"]):
				return false
			return true
		"confirm_observation_frame":
			return _keys_only(value,["action","schema_version",
					"observation_id","render_identity"]) \
				and _identifier(value.get("observation_id",null)) \
				and _render_identity(value.get("render_identity",null))
		"prepare_edit":
			if not _keys_only(value,["action","schema_version",
					"observation_id","operations"]) \
					or not _identifier(value.get("observation_id",null)):
				return false
			var operations: Variant = value.get("operations",null)
			if not operations is Array or operations.is_empty() \
					or operations.size() > MAX_PRIMITIVES:
				return false
			for operation: Variant in operations:
				if not _operation(operation):
					return false
			return true
		"apply_edit":
			return _keys_only(value,["action","schema_version","proposal_id"]) \
				and _identifier(value.get("proposal_id",null))
		"retire_task":
			return _keys_only(value,["action","schema_version"])
		_:
			return false
