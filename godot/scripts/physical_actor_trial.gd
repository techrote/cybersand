extends RefCounted

# Reset-scoped exploratory arms. Native cells and the ordinary Rapier bridge
# remain the only material/body authorities. No sampled Ripper motor is used.
const PREFIX = "experimental/blacksite/"
const ARMS = ["sampled-baseline", "sampled-burial-safe", "barrel", "ripper"]
const Blacksite = preload("res://scripts/blacksite_nine.gd")

var armed: bool = false
var jump_held: bool = false
var pulse_cooldown: float = 0.0
var action: Dictionary = {"drive":0.0, "trim":0.0, "pulse":false}

static func contains(id: String) -> bool:
	return id.begins_with(PREFIX) and id.trim_prefix(PREFIX) in ARMS

static func configuration(id: String) -> Dictionary:
	if not contains(id): return {}
	var arm: String = id.trim_prefix(PREFIX)
	return {"representation":"barrel-rapier" if arm in ["barrel", "ripper"] else "sampled",
		"runtime_recovery_enabled":arm != "sampled-burial-safe", "experimental":true,
		"physical_trial":arm if arm in ["barrel", "ripper"] else ""}

static func body_size(arm: String) -> Vector2:
	return Vector2(18, 8) if arm == "ripper" else Vector2(8, 14)

static func definition(id: String, seed: int = 0) -> Dictionary:
	if not contains(id): return {}
	var out: Dictionary = Blacksite.definition(seed)
	out.id = id
	out.body_enabled = configuration(id).representation == "barrel-rapier"
	out.player_enabled = not out.body_enabled
	out.presentation.title = "Blacksite physical comparison / " + id.trim_prefix(PREFIX)
	out.presentation.instructions = "Experimental fresh-reset comparison. A/D drive; Q/E torque; Space rising edge gives a short upward thruster pulse (0.6 s cooldown, also works airborne). Release controls after menus/focus changes. P pauses; R restores the complete map. Sampled arms keep their existing controls."
	return out

func sample(delta: float, allowed: bool, horizontal: float, trim: float, jump: bool) -> Dictionary:
	# Main-thread scratch only; never published or retained as a snapshot.
	action.drive = 0.0
	action.trim = 0.0
	action.pulse = false
	if not allowed:
		armed = false
		jump_held = jump
		return action
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	if not armed:
		armed = absf(horizontal) < 0.001 and absf(trim) < 0.001 and not jump
		jump_held = jump
		return action
	var pulse: bool = jump and not jump_held and pulse_cooldown <= 0.0
	jump_held = jump
	if pulse: pulse_cooldown = 0.6
	action.drive = clampf(horizontal,-1,1)
	action.trim = clampf(trim,-1,1)
	action.pulse = pulse
	return action
