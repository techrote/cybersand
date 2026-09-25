class_name CyberPlayerRepresentation
extends RefCounted

# PCHAR-001 keeps representation identity explicit and reset-scoped. These
# constants describe the experiment; they do not change generic body semantics.
const SAMPLED: StringName = &"sampled"
const BARREL_RAPIER: StringName = &"barrel-rapier"
const BARREL_BODY_INDEX: int = 0

# Horizontal-only barrel control. The bridge applies this as a bounded impulse
# after cellular reaction has been consumed; it never assigns linear velocity.
const BARREL_WALK_SPEED: float = 42.0
const BARREL_HORIZONTAL_ACCELERATION: float = 180.0
const BARREL_MAX_HORIZONTAL_IMPULSE: float = 3.0


static func is_valid(representation: StringName) -> bool:
	return representation == SAMPLED or representation == BARREL_RAPIER


static func identity(
	representation: StringName,
	sampled_runtime_recovery_enabled: bool
) -> String:
	if representation == BARREL_RAPIER:
		return "barrel-rapier"
	return (
		"sampled-baseline"
		if sampled_runtime_recovery_enabled
		else "sampled-burial-safe"
	)
