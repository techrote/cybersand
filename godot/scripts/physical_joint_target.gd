class_name CyberPhysicalJointTarget
extends RefCounted

# ACT-IK-001: the only supported joint-reference geometry. This is an
# opt-in, equipment-absent Runner assembly, never the ordinary Runner loadout.
# These immutable NCA identifiers are NOT rebuilt from the new host revision.
const PROFILE_ID: String = "runner-right-sole@1"
const PROFILE_SHA256: String = "6cb15832e240f82f4bcd582d2c26015ef986e44f335da683abaf9746e31503c4"
const DESCRIPTOR_SHA256: String = "76fd5e0a481e628f30fe2fb55d62eb5cc66014be07c13a5b7720d30e792d2c65"
const TOPOLOGY_SHA256: String = "41834423020c4dda28c425e695124dc743419b90b05426efc3f087238df71b32"
const HISTORICAL_SOURCE: String = "f2e34cf9b6fbaa5d9dedf9aa2cbc721a87472497"
const PROTOCOL: String = "nca-host/1"
const CAPABILITY: String = "physical_joint_target/v1"
const MODE: String = "exclusive_joint_targets"
const PART_IDS: Array[String] = ["chassis", "leg_-1", "foot_-1", "leg_1", "foot_1"]
const JOINT_IDS: Array[String] = ["hip_-1", "ankle_-1", "hip_1", "ankle_1"]
const ACTIVE_JOINT_IDS: Array[String] = ["hip_1", "ankle_1"]
const TARGET_LIMITS: Array[float] = [0.72, 0.27]
const DELTA_LIMIT: float = 0.25
const MAX_OBSERVATION_AGE: int = 12
const MAX_LEASE: int = 18
const REQUEST_KEYS: Array[String] = [
	"protocol", "operation", "version", "run_id", "actor_id", "epoch",
	"incarnation", "control_generation", "source_id", "policy_sha256",
	"grant_id", "grant_generation", "goal_id", "goal_deadline_tick",
	"sequence", "observed_tick", "observation_id", "observation_sha256",
	"profile_sha256", "topology_sha256", "effector_id", "joint_ids",
	"joint_values", "target_mode", "lease_ticks", "producer"
]


static func digest(value: Variant, length: int = 64) -> bool:
	if not value is String or value.length() != length:
		return false
	for i: int in range(value.length()):
		if value[i] not in "0123456789abcdef":
			return false
	return true


static func identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 128:
		return false
	for c: String in value:
		if c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.:@":
			return false
	return true


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= minimum and int(value) <= maximum


static func finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func compatible_assembly(data: Dictionary) -> bool:
	# Verify actual prepared geometry, not a disabled trigger on a sixth body.
	if str(data.get("id", "")) != "runner" or str(data.get("joint_target_profile", "")) != PROFILE_ID \
		or str(data.get("equipment_preparation", "")) != "none" \
		or not bool(data.get("equipment_managed", false)) \
		or not data.get("mounts", []).is_empty():
		return false
	var parts: Array = data.get("parts", [])
	var joints: Array = data.get("joints", [])
	if parts.size() != 5 or joints.size() != 4:
		return false
	var positions: Array[Vector2] = [
		Vector2.ZERO, Vector2(-3.6, 5.5), Vector2(-4.6, 8.0),
		Vector2(3.6, 5.5), Vector2(4.6, 8.0)]
	var sizes: Array[Vector2] = [
		Vector2(6, 8), Vector2(2, 5), Vector2(4, 2),
		Vector2(2, 5), Vector2(4, 2)]
	var angles: Array[float] = [0.0, -0.18, 0.0, 0.18, 0.0]
	var masses: Array[float] = [1.35, 0.28, 0.23, 0.28, 0.23]
	for i: int in range(5):
		var part: Dictionary = parts[i]
		if str(part.get("id", "")) != PART_IDS[i] or str(part.get("shape", "rectangle")) != "rectangle" \
			or Vector2(part.get("offset", Vector2.INF)).distance_to(positions[i]) > 0.0001 \
			or Vector2(part.get("size", Vector2.ZERO)).distance_to(sizes[i]) > 0.0001 \
			or absf(float(part.get("angle", INF)) - angles[i]) > 0.0001 \
			or absf(float(part.get("mass", INF)) - masses[i]) > 0.0001:
			return false
	var parents: Array[int] = [0, 1, 0, 3]
	var children: Array[int] = [1, 2, 3, 4]
	var pivots: Array[Vector2] = [
		Vector2(-3.6, 2.8), Vector2(-3.6, 7.75),
		Vector2(3.6, 2.8), Vector2(3.6, 7.75)]
	for i: int in range(4):
		var joint: Dictionary = joints[i]
		var bound: float = 0.75 if i % 2 == 0 else 0.30
		if str(joint.get("id", "")) != JOINT_IDS[i] or str(joint.get("type", "")) != "rotary" \
			or int(joint.get("a", -1)) != parents[i] or int(joint.get("b", -1)) != children[i] \
			or not joint.get("anchor") is Vector2 \
			or Vector2(joint.anchor).distance_to(pivots[i]) > 0.0001 \
			or not joint.get("limits") is Vector2 \
			or Vector2(joint.limits).distance_to(Vector2(-bound, bound)) > 0.0001 \
			or not bool(joint.get("limits_enabled", false)) \
			or absf(float(joint.get("motor_speed", INF)) - 7.0) > 0.0001 \
			or absf(float(joint.get("max_force", INF)) - 100.0) > 0.0001:
			return false
	return true


static func capability(host_identity: Dictionary, data: Dictionary) -> Dictionary:
	# This identity is injected by the trusted build/host owner. Unknown or
	# unverifiable provenance means no capability, not a fabricated HEAD.
	if not compatible_assembly(data) or not digest(host_identity.get("source_commit"), 40) \
		or not digest(host_identity.get("runtime_sha256")):
		return {}
	return {
		"protocol": PROTOCOL, "operation": "ik_capabilities", "version": 1,
		"capability": CAPABILITY, "mode": MODE,
		"host_source_commit": host_identity.source_commit,
		"host_runtime_sha256": host_identity.runtime_sha256,
		"profile_id": PROFILE_ID, "profile_sha256": PROFILE_SHA256,
		"descriptor_file_sha256": DESCRIPTOR_SHA256,
		"descriptor_source_commit": HISTORICAL_SOURCE,
		"topology_sha256": TOPOLOGY_SHA256,
		"effector": {"id": "right_sole", "part_id": "foot_1", "point_local_cells": [0.0, 1.0]},
		"part_ids": PART_IDS.duplicate(), "joint_ids": JOINT_IDS.duplicate(),
		"active_joint_ids": ACTIVE_JOINT_IDS.duplicate(),
		"part_capacity": 8, "joint_capacity": 7, "angle_unit": "radians",
		"length_unit": "game_cells", "target_mode": ["joint_position", "joint_delta"],
		"target_limits_radians": [[-0.72, 0.72], [-0.27, 0.27]],
		"max_delta_radians": DELTA_LIMIT,
		"base_hz": 60, "decision_ticks": 6, "max_observation_age_ticks": 12,
		"max_lease_ticks": 18, "helper_lease_ceiling_ticks": 12,
		"deadline_exclusive": true, "source_grant_required": true,
		"non_commanded": "passive_constraints",
		"wire_buttons_mounts": "disabled_disarmed",
		"authored_gyro": {"neutral_target_radians": 0.0, "gain_grounded": 1.0,
			"gain_airborne": 0.65, "gyro": 26.0, "gyro_kp": 10.0,
			"damping": 3.0, "play_radians": 0.055,
			"grounded_slope_lean": true, "button_boost": false},
		"motor": {"effort": 1.0, "speed_cap_radians_per_second": 7.0,
			"request_slew_radians_per_second_squared": 20.0,
			"pin_joint_max_force_parameter": 100.0,
			"max_force_is_measured_torque": false},
		"force_telemetry": "unavailable", "passive_force_decomposition": "unavailable",
		"receipts": ["requested", "admitted", "limited", "motor", "motion", "integrity"],
		"packet_kind": "ik_submit", "observation_schema": "ik_host_observation/v1"
	}


static func validation_error(value: Variant) -> String:
	if not value is Dictionary or value.size() != REQUEST_KEYS.size():
		return "ik_packet_schema"
	for key: Variant in value:
		if not key is String and not key is StringName:
			return "ik_packet_field_type"
		if str(key) not in REQUEST_KEYS:
			return "ik_packet_unknown_field"
	if value.get("protocol") != PROTOCOL or value.get("operation") != "ik_submit" \
		or not integer(value.get("version"), 1, 1):
		return "ik_packet_version"
	for key: String in ["run_id", "source_id", "grant_id", "goal_id", "observation_id", "producer"]:
		if not identifier(value.get(key)):
			return "ik_identity_" + key
	for key: String in ["policy_sha256", "observation_sha256", "profile_sha256", "topology_sha256"]:
		if not digest(value.get(key)):
			return "ik_digest_" + key
	for key: String in ["actor_id", "epoch", "incarnation", "control_generation",
			"grant_generation", "sequence", "observed_tick"]:
		if not integer(value.get(key), 0, 9007199254740991):
			return "ik_integer_" + key
	if not integer(value.get("goal_deadline_tick"), 1, 9007199254740991) \
		or int(value.goal_deadline_tick) <= int(value.observed_tick):
		return "ik_goal_deadline"
	if not integer(value.get("lease_ticks"), 1, MAX_LEASE):
		return "ik_lease"
	if value.get("profile_sha256") != PROFILE_SHA256 or value.get("topology_sha256") != TOPOLOGY_SHA256 \
		or value.get("effector_id") != "right_sole":
		return "ik_profile"
	if value.get("joint_ids") != ACTIVE_JOINT_IDS:
		return "ik_joint_order"
	if value.get("target_mode") not in ["joint_position", "joint_delta"]:
		return "ik_target_mode"
	if not value.get("joint_values") is Array or value.joint_values.size() != 2:
		return "ik_target_shape"
	for i: int in range(2):
		var raw: Variant = value.joint_values[i]
		if not finite_number(raw):
			return "ik_target_nonfinite"
		var limit: float = TARGET_LIMITS[i] if value.target_mode == "joint_position" else DELTA_LIMIT
		if absf(float(raw)) > limit:
			return "ik_target_bounds"
	return ""


static func resolve_targets(packet: Dictionary, original_angles: Array) -> Array:
	if validation_error(packet) != "" or original_angles.size() != 2:
		return []
	var values: Array = []
	for i: int in range(2):
		if not finite_number(original_angles[i]):
			return []
		var requested: float = float(packet.joint_values[i])
		if packet.target_mode == "joint_delta":
			requested += float(original_angles[i])
		if absf(requested) > TARGET_LIMITS[i]:
			return []
		values.append(requested)
	return values


static func expiration(observed_tick: int, lease_ticks: int, goal_deadline_tick: int) -> int:
	return mini(observed_tick + MAX_OBSERVATION_AGE, mini(observed_tick + lease_ticks, goal_deadline_tick))


static func can_consume(observed_tick: int, lease_ticks: int, goal_deadline_tick: int,
		current_tick: int) -> bool:
	return observed_tick <= current_tick and current_tick < expiration(observed_tick, lease_ticks, goal_deadline_tick)


static func observation_digest(view: Dictionary) -> String:
	# An owner-issued opaque binding to the immutable copied root and joints.
	# NCA's canonical IKObservation hash remains a distinct value; never
	# misrepresent this host packet digest as that semantic record hash.
	var joints: Array = []
	for joint: Dictionary in view.get("joints", []):
		joints.append([str(joint.id), float(joint.angle)])
	var body: Array = [
		str(view.get("observation_id", "")), str(view.get("run_id", "")),
		int(view.get("epoch", -1)), int(view.get("control_generation", -1)),
		int(view.get("tick", -1)), float(view.get("position", Vector2.ZERO).x),
		float(view.get("position", Vector2.ZERO).y), float(view.get("rotation", 0.0)),
		joints
	]
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(JSON.stringify(body).to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


static func observed_chain(view: Dictionary) -> Array:
	var joints: Array = view.get("joints", [])
	if joints.size() != 4:
		return []
	for i: int in range(4):
		if str(joints[i].get("id", "")) != JOINT_IDS[i] or not finite_number(joints[i].get("angle")) \
			or not bool(joints[i].get("enabled", false)):
			return []
	return [float(joints[2].angle), float(joints[3].angle)]
