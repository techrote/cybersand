class_name CyberPhysicalActorCatalog
extends RefCounted

# ACT-004 authoring data with additive player presets. Visible geometry matches
# Rapier collision; player circles declare their separate square native masks.
# All dictionaries are constructed afresh; no live scene object
# or shared mutable tuning escapes this catalogue. Values use cells and seconds.
const Sampled = preload("res://scripts/actor_rig_catalog.gd")
const Player = preload("res://scripts/player_actor_catalog.gd")
const Flight = preload("res://scripts/physical_flight_profile.gd")
const VERSION: int = 1
const MAX_PARTS: int = 8
const SET_IDS: Array[StringName] = [&"setA", &"setB", &"setF", &"setY", &"setU", &"setV", &"setX", &"setP", &"set4LY"]
const RIG_IDS: Array[StringName] = [
	&"runner", &"skimmer", &"crawler", &"scout", &"scrabbler", &"ripper",
	&"groundeffect", &"digger", &"copter", &"pouncer", &"dropbot", &"lineshank",
	&"walljumper", &"clamberer", &"swinger", &"rocketjumper", &"springjack",
	&"gyrocrate", &"bellows", &"winchbug", &"magpie", &"skatesail",
	&"astra", &"claude", &"luna", &"qwen", &"bonsai", &"jev", &"gemini",
	&"monowheel", &"inchworm", &"pendulum", &"rocker", &"hammerhead", &"rocketblade",
	&"tandem", &"tricopter", &"tiltrotor", &"heavylift", &"needlejet", &"gyrosled",
	&"stuntbuggy", &"trialsbike", &"acrobat", &"arcadelander", &"jetbarrel",
]
const EXTRA_NAMES: Dictionary = {
	&"monowheel": "Monowheel", &"inchworm": "Inchworm", &"pendulum": "Pendulum",
	&"rocker": "Rocker", &"hammerhead": "Hammerhead", &"rocketblade": "Rocketblade",
	&"tandem": "Tandem", &"tricopter": "Tricopter", &"tiltrotor": "Tiltrotor",
	&"heavylift": "Heavylift", &"needlejet": "Needlejet", &"gyrosled": "Gyrosled",
}


static func has_rig(rig_id: StringName) -> bool:
	return rig_id in RIG_IDS or rig_id in Flight.IDS


static func rigs_in_set(set_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	# Append a new selection family without renumbering the 46 original actor
	# indices or making dedicated scientific/sampled actors part of 4LY.
	if set_id == &"set4LY":
		result.append_array(Flight.IDS)
		return result
	for rig_id: StringName in RIG_IDS:
		if set_for(rig_id) == set_id:
			result.append(rig_id)
	return result


static func set_for(rig_id: StringName) -> StringName:
	if rig_id in Flight.IDS:
		return &"set4LY"
	if Player.has_rig(rig_id):
		return &"setP"
	if EXTRA_NAMES.has(rig_id):
		return &"setX"
	return Sampled.set_for(rig_id)


static func name_for(rig_id: StringName) -> String:
	if rig_id in Flight.IDS:
		return str(rig_id).trim_prefix("4ly_").capitalize()
	if Player.has_rig(rig_id):
		return Player.name_for(rig_id)
	return str(EXTRA_NAMES.get(rig_id, Sampled.name_for(rig_id)))


static func definition(rig_id: StringName) -> Dictionary:
	return entry(rig_id)


static func entry(rig_id: StringName) -> Dictionary:
	if not has_rig(rig_id):
		return {}
	if rig_id in Flight.IDS:
		return _flight_entry(rig_id)
	var data: Dictionary = Sampled.entry(rig_id)
	if data.is_empty():
		data = {"id": rig_id, "name": name_for(rig_id), "set": &"setX",
			"theme": "Experimental mechanisms", "color": Color(0.48, 0.86, 0.84),
			"channels": ["movement", "aim", "effort", "trim", "reel", "primary", "secondary", "auxiliary"]}
	data["representation"] = "articulated-rapier"
	data["version"] = VERSION
	data["experimental"] = true
	data["parts"] = []
	data["joints"] = []
	data["mounts"] = []
	data["profile"] = _profile()
	data["channels"] = ["movement", "aim", "effort", "trim", "reel", "primary", "secondary", "auxiliary", "tool"]
	data["script"] = {"radius": 34.0, "altitude": 18.0, "pace": 0.9,
		"period": 2.1, "recovery_seconds": 0.75, "character": "decisive traversal"}
	data["limitations"] = [
		"Authored assistance and compliant rectangular parts; no finite gyro momentum accounting.",
		"Scripted feedback is deterministic local control, not learned inference or global pathfinding.",
	]
	if Player.has_rig(rig_id):
		Player.build(data, rig_id)
	else:
		_build(data, rig_id)
	var bounds := Rect2()
	var first: bool = true
	for part: Dictionary in data.parts:
		var transform := Transform2D(float(part.angle), part.offset)
		var half: Vector2 = part.size * 0.5
		for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
				Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
			var point: Vector2 = transform * corner
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	data["bounds"] = bounds
	data["body_size"] = bounds.size
	data["spawn_floor_clearance"] = bounds.end.y + 2.0
	data["spawn_radius"] = maxf(bounds.position.length(), bounds.end.length()) + 2.0
	data["part_count"] = data.parts.size()
	data["controller_id"] = "local-feedback/" + str(rig_id) + "/v1"
	if Player.has_rig(rig_id):
		data["controller_id"] = "player-movement/" + str(rig_id) + "/v1"
	data["controls"] = controls_text(rig_id, data)
	return data


static func controls_text(rig_id: StringName, supplied: Dictionary = {}) -> String:
	if rig_id in Flight.IDS:
		return "WASD: world-frame desired velocity (up is W). Release: bounded brake and hover with a live lease. Escape/menu/focus cancellation: passive fall. F5: select or reset a fresh chassis at the map spawn. No equipment; power/assistance is host-owned."
	if Player.has_rig(rig_id):
		return Player.controls(rig_id)
	var data: Dictionary = supplied if not supplied.is_empty() else entry(rig_id)
	if data.is_empty():
		return ""
	var profile: Dictionary = data.profile
	return "WASD move; mouse aim; [ / ] effort; Q/E trim; Z/X reel.\nSpace: %s. Shift: %s. C: %s.\nM: use tool. N: release held item. U: reattach nearby item. Release controls after focus/menu changes." % [
		_ability_text(str(profile.primary)), _ability_text(str(profile.secondary)),
		_ability_text(str(profile.auxiliary))]


static func _flight_entry(rig_id: StringName) -> Dictionary:
	var flight: Dictionary = Flight.entry(rig_id)
	var size := Vector2(float(flight.collider_size[0]), float(flight.collider_size[1]))
	var half: Vector2 = size * 0.5
	# Appearance metadata only: there are no drone-specific controller paths.
	var palette: Dictionary = {
		&"4ly_trainer": Color(0.34, 0.85, 0.90),
		&"4ly_hauler": Color(0.83, 0.62, 0.28),
		&"4ly_drifter": Color(0.59, 0.67, 0.97),
		&"4ly_dart": Color(0.96, 0.45, 0.48)}
	var descriptions: Dictionary = {
		&"4ly_trainer": "Balanced assisted free-flight baseline: predictable acceleration and firm neutral braking.",
		&"4ly_hauler": "Heavy clearance planner: slower translation, force buildup and deliberate braking.",
		&"4ly_drifter": "Low-drag flyer: soft translation correction and persistent controlled drift, with upright stabilization.",
		&"4ly_dart": "Compact quick-correction flyer: high speed and aggressive acceleration and braking."}
	var hull_color: Color = palette[rig_id]
	return {"id": rig_id, "name": name_for(rig_id), "set": &"set4LY",
		"theme": "4LY — assisted free-flight drones",
		"version": VERSION, "representation": "articulated-rapier", "experimental": true,
		"description": descriptions[rig_id] + " Handling calibration is a measured 4LY-002 gate.",
		"color": hull_color, "channels": ["move"],
		"controller_id": Flight.CONTROLLER_ID, "action_profile": Flight.ACTION_PROFILE,
		"flight_profile": flight, "equipment_preparation": "none", "equipment_managed": true,
		"parts": [{"id": "chassis", "offset": Vector2.ZERO, "size": size,
			"mass": float(flight.mass), "inertia": float(flight.inertia), "angle": 0.0,
			"shape": "rectangle", "friction": float(flight.friction), "bounce": float(flight.bounce),
			"role": "hull", "color": hull_color}],
		"joints": [], "mounts": [], "part_count": 1,
		"profile": {"movement": "4ly_velocity", "gravity": float(flight.gravity),
			"air_drag": float(flight.linear_drag), "angular_drag": float(flight.angular_drag)},
		"script": {"kind": "neutral_conformance"},
		"bounds": Rect2(-half, size), "body_size": size,
		"spawn_floor_clearance": half.y + 2.0, "spawn_radius": half.length() + 2.0,
		"controls": controls_text(rig_id),
		"limitations": ["Continuous authored power; no simulated fuel timer or equipment.",
			"Flight lab, qualified teaching and owner-feel acceptance remain separate gates."]}

static func _ability_text(ability: String) -> String:
	var names: Dictionary = {"jump": "jump", "charge_jump": "hold to coil, release to leap",
		"boost": "hold boost", "pulse": "aimed pulse", "grip_lunge": "lunge from contact",
		"rope": "cast line", "drill": "hold aimed bore", "cut": "cut and traction burst",
		"blast": "surface blast", "pogo": "hold pogo", "spin": "spin up", "left_thrust": "left thrust",
		"brake": "hold brake", "glide": "hold glide", "grip": "hold grip", "rope_release": "release line",
		"stabilize": "hold stabilizer", "preload": "brace and preload", "hop": "spend spin on hop",
		"inhale": "inhale and brake", "sail": "deploy sail", "right_thrust": "right thrust",
		"rebound": "hold rebound", "self_right": "self-right", "toggle_power": "toggle power",
		"dive": "commit dive", "grip_release": "release grip", "tuck": "tuck",
		"mode": "switch ground/flight", "paired_burst": "paired burst", "vent": "vent", "none": "unused"}
	return str(names.get(ability, ability.replace("_", " ")))


static func _profile() -> Dictionary:
	return {"movement": "ground", "speed": 42.0, "accel": 230.0,
		"gravity": 156.0, "gyro": 26.0, "gyro_kp": 10.0, "damping": 3.0,
		"play": 0.055, "slew": 8.0, "jump": 64.0, "thrust": 205.0,
		"primary": "jump", "secondary": "brake", "auxiliary": "self_right",
		"cooldown": 0.55, "charge_seconds": 0.48, "recharge": 0.45,
		"grip": false, "rope": false, "tool": "", "ground_clearance": 10.0,
		"gait_rate": 2.9, "gait_amplitude": 0.50, "air_control": 0.12,
		"body_thrust": false, "rebound": 0.58, "rope_range": 68.0}


static func _tune(data: Dictionary, tuning: Dictionary) -> void:
	data.profile.merge(tuning, true)


static func _part(data: Dictionary, id: String, offset: Vector2, size: Vector2,
		mass: float = 0.7, angle: float = 0.0, role: String = "hull") -> int:
	var parts: Array = data.parts
	var color: Color = data.color
	if role != "hull":
		color = color.darkened(0.20) if parts.size() % 2 == 0 else color.lightened(0.16)
	parts.append({"id": id, "offset": offset, "size": size, "mass": mass,
		"angle": angle, "shape": "rectangle", "friction": 0.82,
		"bounce": 0.04, "role": role, "color": color})
	return parts.size() - 1


static func _pin(data: Dictionary, id: String, a: int, b: int, anchor: Vector2,
		limits: Vector2 = Vector2(-0.65, 0.65), role: String = "leg", phase: float = 0.0,
		aim_axis: Vector2 = Vector2.RIGHT) -> void:
	data.joints.append({"id": id, "type": "rotary", "a": a, "b": b,
		"anchor": anchor, "axis": Vector2.DOWN, "limits": limits,
		"limits_enabled": role != "wheel",
		"rest_length": 0.0, "stiffness": 22.0, "damping": 3.8,
		"motor_speed": 7.0, "max_force": 100.0, "phase": phase, "role": role, "aim_axis": aim_axis})


static func _slide(data: Dictionary, id: String, a: int, b: int, _anchor: Vector2,
		limits: Vector2 = Vector2(0.0, 4.0), spring: bool = false, role: String = "slider") -> void:
	var anchor: Vector2 = data.parts[b].offset
	var travel: float = (limits.y - limits.x) * 0.5
	var rest: float = anchor.distance_to(data.parts[a].offset)
	data.joints.append({"id": id, "type": "spring" if spring else "slide", "a": a, "b": b,
		"anchor": anchor, "axis": Vector2.DOWN, "limits": Vector2(-travel, travel),
		"rest_length": rest, "stiffness": 35.0, "damping": 0.85,
		"motor_speed": 5.0, "max_force": 360.0, "phase": 0.0, "role": role})


static func _mount(data: Dictionary, usable: String = "depositor", kind: String = "mounted",
		part: int = 0, offset: Vector2 = Vector2(4.0, 0.0), held_part: int = -1) -> void:
	var mount: Dictionary = {"id": "usable", "part": part, "offset": offset,
		"angle": 0.0, "limits": Vector2(-2.5, 2.5), "type": kind,
		"usable": usable, "reach": 14.0, "radius": 2,
		"recoil": 13.0 if usable == "launcher" else 2.5, "cooldown": 0.55}
	if held_part >= 0:
		mount["held_part"] = held_part
	data.mounts.append(mount)


static func _biped(data: Dictionary, hull: Vector2 = Vector2(6, 8), leg_length: float = 5.0) -> void:
	_part(data, "chassis", Vector2.ZERO, hull, 1.35)
	for side: int in [-1, 1]:
		var x: float = float(side) * (hull.x * 0.5 + 0.6)
		var y: float = hull.y * 0.5 + leg_length * 0.30
		var leg: int = _part(data, "leg_%d" % side, Vector2(x, y), Vector2(2, leg_length), 0.28,
			float(side) * 0.18, "leg")
		_pin(data, "hip_%d" % side, 0, leg, Vector2(x, hull.y * 0.35),
			Vector2(-0.75, 0.75), "leg", 0.0 if side == -1 else PI)
		var foot: int = _part(data, "foot_%d" % side,
			Vector2(x + float(side), y + leg_length * 0.5), Vector2(4, 2), 0.23, 0.0, "foot")
		_pin(data, "ankle_%d" % side, leg, foot, Vector2(x, y + leg_length * 0.45),
			Vector2(-0.3, 0.3), "foot")


static func _crawl(data: Dictionary, hull: Vector2 = Vector2(10, 6), reach: float = 5.0) -> void:
	_part(data, "chassis", Vector2.ZERO, hull, 1.45)
	for side: int in [-1, 1]:
		var x: float = float(side) * reach
		var foot: int = _part(data, "shoe_%d" % side,
			Vector2(x, hull.y * 0.5 + 2.5), Vector2(6, 2.5), 0.50, float(side) * 0.08, "foot")
		_pin(data, "shoe_hinge_%d" % side, 0, foot, Vector2(x * 0.65, hull.y * 0.45),
			Vector2(-0.48, 0.48), "leg", 0.0 if side == -1 else PI)


static func _rotors(data: Dictionary, offsets: Array, rotor_size: Vector2 = Vector2(7, 2),
		limits: Vector2 = Vector2(-0.18, 0.18)) -> void:
	for offset: Vector2 in offsets:
		var index: int = data.parts.size()
		var rotor: int = _part(data, "rotor_%d" % index, offset, rotor_size, 0.22, 0.0, "thruster")
		_pin(data, "rotor_mount_%d" % index, 0, rotor, offset, limits, "thruster")


static func _build(data: Dictionary, rig_id: StringName) -> void:
	match rig_id:
		&"runner":
			_biped(data)
			_tune(data, {"speed": 55.0, "accel": 310.0, "primary": "jump", "secondary": "pulse"})
			data.description = "A springy five-part runner: quick planted steps, a buffered jump and a decisive dash."
			data.script.character = "run, vault, commit, brake"
		&"skimmer":
			_part(data, "chassis", Vector2.ZERO, Vector2(5, 10), 1.1)
			_rotors(data, [Vector2(-4, 1), Vector2(4, 1)], Vector2(2.5, 5))
			_tune(data, {"movement": "flight", "speed": 58.0, "primary": "boost", "thrust": 225.0})
			data.script.altitude = 22.0
			data.description = "Twin pivoting thruster pods keep an agile skimmer aloft; braking trades momentum for control."
		&"crawler":
			_crawl(data)
			_tune(data, {"speed": 31.0, "accel": 260.0, "jump": 43.0, "gait_rate": 2.2})
			data.description = "A low crawler rocks two broad hinged shoes over ledges and braces against support."
		&"scout":
			_biped(data, Vector2(5, 7), 5.0)
			_tune(data, {"speed": 63.0, "accel": 320.0, "jump": 70.0, "secondary": "glide", "double_jump": true})
			data.script.radius = 44.0
			data.description = "Long light legs give this scout fast strides, a recovery air jump and a compact glide."
		&"scrabbler":
			_part(data, "chassis", Vector2.ZERO, Vector2(12, 6), 1.8)
			for leg_index: int in range(3):
				var x: float = float(leg_index - 1) * 6.0
				var side: float = float(leg_index - 1)
				var leg: int = _part(data, "upper_%d" % leg_index, Vector2(x, 4.7), Vector2(2.2, 7),
					0.38, -side * 0.40, "leg")
				_pin(data, "hip_%d" % leg_index, 0, leg, Vector2(x * 0.8, 2.3),
					Vector2(-0.85, 0.85), "leg", float(leg_index) * TAU / 3.0)
				var foot: int = _part(data, "claw_%d" % leg_index, Vector2(x + side * 2.0, 8.7),
					Vector2(4.6, 2), 0.28, 0.0, "foot")
				_pin(data, "knee_%d" % leg_index, leg, foot, Vector2(x + side, 7.5),
					Vector2(-0.55, 0.55), "foot", float(leg_index) * TAU / 3.0)
			_tune(data, {"movement": "walk", "speed": 33.0, "jump": 77.0, "grip": true,
				"primary": "grip_lunge", "secondary": "grip", "gyro": 18.0, "gait_rate": 2.5, "gait_amplitude": 0.72})
			data.script.period = 2.6
			data.description = "A seven-part tripod with uneven three-foot purchase, compliant knees and committed Leaper-like lunges."
		&"ripper":
			_part(data, "chassis", Vector2.ZERO, Vector2(14, 5), 1.6)
			for side: int in [-1, 1]:
				var x: float = float(side) * 5.0
				var bogie: int = _part(data, "bogie_%d" % side, Vector2(x, 4), Vector2(7, 2), 0.45, 0.0, "foot")
				_slide(data, "suspension_%d" % side, 0, bogie, Vector2(x, 2.5), Vector2(0.5, 3), true)
				var roller: int = _part(data, "track_roller_%d" % side, Vector2(x, 6.0), Vector2(4, 3), 0.32, 0.0, "wheel")
				_pin(data, "drive_%d" % side, bogie, roller, Vector2(x, 6), Vector2(-PI, PI), "wheel")
			_tune(data, {"speed": 74.0, "accel": 390.0, "primary": "cut", "tool": "cutter", "jump": 45.0,
				"damping": 2.0, "gyro": 18.0, "play": 0.08})
			data.script.radius = 47.0
			data.script.character = "fast low drift, traction burst, aggressive reversal"
			data.description = "A low RC drift crawler with two sprung bogies, driven track rollers and a bounded cutting front."
		&"groundeffect":
			_part(data, "chassis", Vector2.ZERO, Vector2(13, 5), 1.7)
			for side: int in [-1, 1]:
				var skid: int = _part(data, "cushion_skid_%d" % side, Vector2(float(side) * 5, 4), Vector2(5, 2), 0.25, 0.0, "foot")
				_slide(data, "skid_spring_%d" % side, 0, skid, Vector2(float(side) * 5, 2), Vector2(0.5, 3.5), true)
			_tune(data, {"movement": "hover", "speed": 36.0, "primary": "boost", "ground_clearance": 12.0, "thrust": 202.0})
			data.script.altitude = 10.0
			data.description = "Compliant belly skids ride beneath a slow ground-distance cushion; it yields and settles when braking."
		&"digger":
			_part(data, "drive_body", Vector2.ZERO, Vector2(5, 7), 1.4)
			var nose: int = _part(data, "boring_head", Vector2(0, 5.8), Vector2(5.5, 4), 0.48, 0.0, "drill")
			_pin(data, "bore_spindle", 0, nose, Vector2(0, 3.5), Vector2(-PI, PI), "wheel")
			var fin: int = _part(data, "tail_fin", Vector2(0, -5.0), Vector2(8, 1.8), 0.14, 0.0, "fin")
			_pin(data, "tail_flex", 0, fin, Vector2(0, -3.5), Vector2(-0.2, 0.2), "fin")
			_tune(data, {"movement": "drill", "speed": 32.0, "primary": "drill", "tool": "cutter",
				"body_thrust": true, "thrust": 270.0, "gyro": 28.0})
			data.script.radius = 22.0
			data.description = "A rocket mole with a driven boring head and flexing tail; aimed bounded excavation permits horizontal or vertical burrows."
		&"copter":
			_part(data, "underslung_body", Vector2.ZERO, Vector2(7, 7), 1.5)
			_rotors(data, [Vector2(0, -5.2)], Vector2(14, 1.6), Vector2(-0.32, 0.32))
			_tune(data, {"movement": "flight", "speed": 45.0, "primary": "boost", "secondary": "stabilize",
				"auxiliary": "toggle_power", "body_thrust": true, "gyro": 14.0, "damping": 2.4,
				"wobble": 0.035, "thrust": 216.0})
			data.script.altitude = 23.0
			data.description = "A wide teetering rotor above an underslung mass: demanding attitude control with a useful recovery stabilizer."
		&"pouncer":
			_crawl(data, Vector2(10, 5), 5.3)
			for side: int in [-1, 1]:
				var wing: int = _part(data, "glide_fin_%d" % side, Vector2(float(side) * 7, -1), Vector2(5.5, 1.5), 0.12, float(side) * 0.3, "sail")
				_pin(data, "fin_hinge_%d" % side, 0, wing, Vector2(float(side) * 4.5, -1), Vector2(-0.85, 0.85), "sail")
			_tune(data, {"movement": "walk", "speed": 27.0, "primary": "charge_jump", "secondary": "glide",
				"auxiliary": "dive", "jump": 96.0, "charge_seconds": 0.55, "gyro": 20.0})
			data.script.period = 2.8
			data.description = "A cybernetic headcrab coils on hinged paws, leaps hard and opens two gliding fins for its landing."
		&"dropbot":
			_biped(data, Vector2(5, 6), 5.2)
			_tune(data, {"movement": "walk", "speed": 38.0, "primary": "grip_lunge", "secondary": "grip",
				"auxiliary": "dive", "grip": true, "jump": 78.0, "gyro": 30.0})
			data.description = "A jointed wall acrobat alternates firm contact, aimed push-offs and an explicitly committed dive."
		&"lineshank":
			_blade(data, false)
		&"walljumper":
			_biped(data, Vector2(5, 8), 5.8)
			_tune(data, {"movement": "walk", "speed": 43.0, "primary": "grip_lunge", "secondary": "grip",
				"auxiliary": "grip_release", "grip": true, "jump": 84.0, "grip_seconds": 1.2})
			data.script.period = 1.6
			data.description = "Long articulated legs catch short wall holds and spring away before the small grip reserve is spent."
		&"clamberer", &"claude", &"bonsai":
			var compact: bool = rig_id == &"bonsai"
			_crawl(data, Vector2(5 if compact else 7, 5), 3.6 if compact else 4.8)
			_tune(data, {"movement": "walk", "speed": 24.0 if compact else 34.0,
				"primary": "charge_jump" if compact else "grip_lunge", "secondary": "grip",
				"auxiliary": "tuck", "grip": true, "jump": 62.0 if compact else 54.0,
				"grip_seconds": 5.0, "gait_rate": 2.2, "gyro": 25.0})
			data.script.period = 2.4 if compact else 1.9
			data.description = "Compact hinged contact shoes fold around gaps, hold purchase and commit to short deliberate vaults."
			if rig_id == &"claude":
				_tune(data, {"auxiliary": "stabilize", "speed": 39.0, "damping": 3.8})
				data.script.character = "follow a contour, vault cleanly, soften the landing"
		&"swinger", &"winchbug":
			_crawl(data, Vector2(6, 7), 3.8)
			var hook: int = _part(data, "hook_arm", Vector2(0, -5), Vector2(2, 5), 0.20, -0.3, "aim")
			_pin(data, "hook_pivot", 0, hook, Vector2(0, -3), Vector2(-1.4, 1.4), "aim", 0.0, Vector2.UP)
			_tune(data, {"movement": "rope", "speed": 32.0, "primary": "rope", "secondary": "rope_release",
				"auxiliary": "rope_release", "rope": true, "rope_range": 78.0})
			if rig_id == &"winchbug":
				_tune(data, {"secondary": "brake", "speed": 25.0, "winch_speed": 16.0})
			data.script.altitude = 17.0
			data.description = "A hinged hook arm casts one bounded terrain line; articulated shoes provide contact drive between swings."
		&"rocketjumper":
			_biped(data, Vector2(6, 7), 4.5)
			var launcher: int = _part(data, "blast_tube", Vector2(4.5, 0.0), Vector2(3, 6), 0.30, 0.4, "usable")
			_pin(data, "blast_gimbal", 0, launcher, Vector2(3, 0), Vector2(-1.4, 1.4), "aim", 0.0, Vector2.DOWN)
			_tune(data, {"speed": 45.0, "primary": "blast", "tool": "blast", "jump": 96.0, "cooldown": 0.78})
			_mount(data, "launcher", "articulated", 0, Vector2(3, 0), launcher)
			data.description = "A six-part blast walker with an articulated launcher, bounded surface recoil and native-owned explosive effects."
		&"springjack":
			_part(data, "chassis", Vector2.ZERO, Vector2(6, 7), 1.3)
			var piston: int = _part(data, "piston", Vector2(0, 5.8), Vector2(2.5, 5), 0.35, 0.0, "slider")
			_slide(data, "piston_guide", 0, piston, Vector2(0, 2.5), Vector2(0.5, 5), true)
			var shoe: int = _part(data, "pogo_shoe", Vector2(0, 9), Vector2(7, 2), 0.4, 0.0, "foot")
			_pin(data, "shoe_play", piston, shoe, Vector2(0, 8), Vector2(-0.28, 0.28), "foot")
			_tune(data, {"movement": "hop", "speed": 38.0, "primary": "pogo", "secondary": "preload",
				"jump": 78.0, "cooldown": 0.42, "gyro": 22.0})
			data.script.period = 1.6
			data.description = "A guided spring piston and rocking shoe make supported pogo strokes with a clear brace/preload phase."
		&"gyrocrate":
			_part(data, "crate", Vector2.ZERO, Vector2(8, 8), 1.8)
			var weight: int = _part(data, "flywheel_hub", Vector2(0, -1), Vector2(4, 3), 0.45, 0.0, "wheel")
			_pin(data, "flywheel", 0, weight, Vector2(0, -1), Vector2(-PI, PI), "wheel")
			_tune(data, {"movement": "roll", "speed": 43.0, "primary": "spin", "secondary": "hop",
				"gyro": 34.0, "jump": 70.0, "damping": 1.5})
			data.script.character = "roll with intent, spend spin on a hop, counterspin after impact"
			data.description = "A lively two-body flywheel crate rolls, winds up and hops with bounded authored gyro assistance."
		&"bellows":
			_part(data, "delivery_box", Vector2.ZERO, Vector2(8, 6), 1.35)
			var bag: int = _part(data, "bellows_plate", Vector2(0, 5), Vector2(9, 2), 0.35, 0.0, "slider")
			_slide(data, "bellows_travel", 0, bag, Vector2(0, 2), Vector2(1.0, 5.0), false)
			var nozzle: int = _part(data, "nozzle", Vector2(5, 0), Vector2(3, 2), 0.14, 0.0, "aim")
			_pin(data, "nozzle_gimbal", 0, nozzle, Vector2(4, 0), Vector2(-1.2, 1.2), "aim")
			_tune(data, {"movement": "pulse", "speed": 42.0, "primary": "pulse", "secondary": "inhale",
				"auxiliary": "vent", "jump": 81.0, "cooldown": 0.65, "recharge": 0.85})
			data.script.period = 1.45
			data.script.character = "inhale, indignant shove, settle, repeat"
			data.description = "An aggrieved delivery box squeezes a guided bellows plate and aims its nozzle for discrete pneumatic shoves."
		&"magpie":
			_crawl(data, Vector2(6, 6), 4.4)
			_tune(data, {"movement": "walk", "speed": 33.0, "primary": "grip_lunge", "secondary": "grip",
				"auxiliary": "grip_release", "grip": true, "jump": 82.0, "recharge": 0.75})
			data.script.period = 1.8
			data.description = "A capacitive clamp perches on two compliant jaws, sights the next support and lunges with commitment."
		&"skatesail":
			_part(data, "skate", Vector2.ZERO, Vector2(11, 3), 1.2)
			var mast: int = _part(data, "mast", Vector2(0, -4.8), Vector2(2, 7), 0.23, 0.1, "sail")
			_pin(data, "mast_hinge", 0, mast, Vector2(0, -1), Vector2(-0.7, 0.7), "sail")
			var sail: int = _part(data, "sail", Vector2(0.5, -8.2), Vector2(10, 1.8), 0.18, 0.1, "sail")
			_pin(data, "sail_trim", mast, sail, Vector2(0.4, -7.5), Vector2(-0.6, 0.6), "sail")
			_tune(data, {"movement": "sail", "speed": 67.0, "primary": "jump", "secondary": "sail",
				"auxiliary": "brake", "gyro": 18.0, "damping": 2.2, "jump": 60.0})
			data.script.radius = 45.0
			data.description = "A low skate carries a two-hinge folding sail: it builds speed, pops and converts existing airspeed into lift."
		&"astra", &"luna":
			_part(data, "chassis", Vector2.ZERO, Vector2(5, 8), 1.15)
			_rotors(data, [Vector2(-3.5, 2), Vector2(3.5, 2)], Vector2(2, 4))
			_tune(data, {"movement": "flight", "speed": 61.0 if rig_id == &"astra" else 48.0,
				"primary": "pulse", "secondary": "brake", "auxiliary": "mode" if rig_id == &"astra" else "none",
				"jump": 68.0 if rig_id == &"astra" else 46.0, "cooldown": 0.6 if rig_id == &"astra" else 0.3})
			data.script.period = 1.8 if rig_id == &"astra" else 0.9
			data.script.character = "independent burst and counterthrust" if rig_id == &"astra" else "short sharp correction pulses"
			data.description = "A compact vector machine with two compliant thrust pods and independently aimed, bounded bursts."
			if rig_id == &"astra":
				_mount(data, "launcher", "recoil", 0, Vector2(3.5, 1.0))
		&"qwen":
			_crawl(data, Vector2(8, 5), 4.5)
			_rotors(data, [Vector2(-6, -3), Vector2(6, -3)], Vector2(4, 2))
			_tune(data, {"movement": "ground", "speed": 49.0, "primary": "boost", "secondary": "brake",
				"auxiliary": "mode", "flight_mode": true, "thrust": 227.0})
			data.script.period = 3.6
			data.description = "Two articulated shoes and two fan pods share a switchable ground/flight chassis with an observable mode."
		&"jev":
			_part(data, "impact_core", Vector2.ZERO, Vector2(7, 7), 1.3)
			for side: int in [-1, 1]:
				var pad: int = _part(data, "rebound_pad_%d" % side, Vector2(float(side) * 5, 0), Vector2(2, 6), 0.26, 0.0, "foot")
				_pin(data, "pad_flex_%d" % side, 0, pad, Vector2(float(side) * 3.5, 0), Vector2(-0.3, 0.3), "foot")
			_tune(data, {"movement": "hop", "speed": 48.0, "primary": "pulse", "secondary": "rebound",
				"jump": 86.0, "cooldown": 0.62, "gyro": 32.0, "rebound": 0.65})
			data.script.period = 1.4
			data.script.character = "committed burst, contact rebound, fast counterspin"
			data.description = "Jolt commits to aimed bursts and uses two yielding impact pads to shape energy-losing contact rebounds."
		&"gemini":
			_part(data, "bridge", Vector2.ZERO, Vector2(9, 3), 1.3)
			_rotors(data, [Vector2(-6, -1), Vector2(6, -1)], Vector2(4, 4), Vector2(-0.25, 0.25))
			_tune(data, {"movement": "flight", "speed": 51.0, "primary": "left_thrust", "secondary": "right_thrust",
				"auxiliary": "paired_burst", "gyro": 20.0, "body_thrust": true})
			data.script.character = "balance independent pods, then synchronize a burst"
			data.description = "A three-part Duet with independent thruster pods, differential trim and synchronized bursts."
		&"monowheel":
			_part(data, "weighted_cab", Vector2(0, 1.5), Vector2(4, 5), 1.7)
			var wheel: int = _part(data, "tumbling_rim", Vector2.ZERO, Vector2(10, 10), 0.7, PI * 0.25, "wheel")
			_pin(data, "axle", 0, wheel, Vector2.ZERO, Vector2(-PI, PI), "wheel")
			_tune(data, {"movement": "roll", "speed": 57.0, "primary": "spin", "secondary": "hop",
				"gyro": 17.0, "damping": 1.8, "jump": 61.0})
			data.description = "An eccentric cab hangs inside a square tumbling rim; rolling and cab attitude respond on different time scales."
		&"inchworm":
			_part(data, "centre", Vector2.ZERO, Vector2(7, 4), 0.8)
			for side: int in [-1, 1]:
				var end: int = _part(data, "grip_segment_%d" % side, Vector2(float(side) * 7, 1.5), Vector2(6, 3), 0.65, 0.0, "foot")
				_pin(data, "spine_%d" % side, 0, end, Vector2(float(side) * 3.7, 0), Vector2(-1.0, 1.0), "leg", 0.0 if side == -1 else PI)
			_tune(data, {"movement": "walk", "speed": 26.0, "primary": "charge_jump", "secondary": "grip",
				"auxiliary": "tuck", "grip": true, "gait_rate": 1.8, "gait_amplitude": 0.86, "jump": 62.0})
			data.script.period = 2.5
			data.description = "Three articulated segments alternate purchase, concertina over lips and coil into an emergency leap."
		&"pendulum":
			_crawl(data, Vector2(9, 3), 4.0)
			var boom: int = _part(data, "swing_boom", Vector2(0, -4.5), Vector2(2, 7), 0.2, 0.4, "leg")
			_pin(data, "swing_axle", 0, boom, Vector2(0, -1), Vector2(-1.1, 1.1), "leg", PI * 0.5)
			var weight: int = _part(data, "counterweight", Vector2(-2.0, -7), Vector2(4, 3), 1.1, 0.0, "weight")
			_pin(data, "weight_play", boom, weight, Vector2(-1.5, -6.5), Vector2(-0.12, 0.12), "foot")
			_tune(data, {"speed": 35.0, "primary": "spin", "secondary": "hop", "gyro": 14.0,
				"gait_rate": 1.7, "gait_amplitude": 0.85, "jump": 67.0})
			data.description = "A heavy swinging counterweight rocks a two-shoe sled across obstacles and stores a brief hopping opportunity."
		&"rocker":
			_part(data, "chassis", Vector2.ZERO, Vector2(10, 4), 1.3)
			for side: int in [-1, 1]:
				var arm: int = _part(data, "rocker_%d" % side, Vector2(float(side) * 5, 3), Vector2(7, 2), 0.4, float(side) * 0.25, "leg")
				_pin(data, "rocker_pivot_%d" % side, 0, arm, Vector2(float(side) * 3.5, 1.5), Vector2(-0.8, 0.8), "leg", 0.0 if side == -1 else PI)
				var foot: int = _part(data, "rocker_foot_%d" % side, Vector2(float(side) * 7, 5.5), Vector2(3, 3), 0.32, 0.0, "wheel")
				_pin(data, "foot_axle_%d" % side, arm, foot, Vector2(float(side) * 7, 5.5), Vector2(-PI, PI), "wheel")
			_tune(data, {"speed": 46.0, "jump": 50.0, "gyro": 17.0, "gait_rate": 2.2})
			data.description = "Long rocker arms carry driven feet, letting the chassis pitch and transfer support over broken ground."
		&"hammerhead":
			_crawl(data, Vector2(8, 4), 4.0)
			var arm: int = _part(data, "hammer_arm", Vector2(2, -4), Vector2(2, 7), 0.22, 0.55, "leg")
			_pin(data, "hammer_pivot", 0, arm, Vector2(0, -1), Vector2(-1.2, 1.2), "leg", PI * 0.5)
			var hammer: int = _part(data, "hammer", Vector2(4, -7), Vector2(6, 3), 1.0, 0.0, "usable")
			_pin(data, "hammer_head_pin", arm, hammer, Vector2(3.5, -6.4), Vector2(-0.14, 0.14), "foot")
			_tune(data, {"movement": "walk", "speed": 31.0, "primary": "cut", "tool": "cutter",
				"secondary": "preload", "gyro": 19.0, "gait_rate": 1.6})
			_mount(data, "cutter", "articulated", 0, Vector2(0, -1), hammer)
			data.script.period = 2.0
			data.description = "A heavy articulated hammer pitches a braced salvage walker while its bounded cutter acts at the held head."
		&"rocketblade":
			_blade(data, true)
		&"tandem", &"tricopter", &"tiltrotor", &"heavylift":
			_multirotor(data, rig_id)
		&"needlejet":
			_part(data, "needle", Vector2.ZERO, Vector2(3, 12), 0.85)
			_rotors(data, [Vector2(-2.5, 5), Vector2(2.5, 5)], Vector2(2, 3), Vector2(-0.06, 0.06))
			_tune(data, {"movement": "flight", "speed": 86.0, "accel": 390.0, "primary": "boost", "secondary": "stabilize",
				"body_thrust": true, "thrust": 275.0, "gyro": 13.0, "damping": 1.7})
			data.script.radius = 46.0
			data.script.altitude = 27.0
			data.description = "A narrow high-thrust dart with small stiff tail pods, fast translation and deliberately weak recovery authority."
		&"gyrosled":
			_part(data, "sled", Vector2.ZERO, Vector2(13, 2.5), 1.4)
			var mast: int = _part(data, "gyro_mast", Vector2(0, -4.5), Vector2(2, 6), 0.25, 0.0, "leg")
			_pin(data, "mast_bearing", 0, mast, Vector2(0, -1), Vector2(-0.55, 0.55), "leg")
			var gyro: int = _part(data, "gyro_pack", Vector2(0, -8), Vector2(5, 4), 1.05, 0.0, "wheel")
			_pin(data, "gyro_axle", mast, gyro, Vector2(0, -8), Vector2(-PI, PI), "wheel")
			_tune(data, {"speed": 68.0, "primary": "spin", "secondary": "hop", "gyro": 33.0,
				"damping": 1.8, "jump": 58.0, "play": 0.085})
			data.script.radius = 43.0
			data.description = "A tall moving gyro load over a narrow sled trades stability for fast skids, body lean and short corrective hops."
	if data.mounts.is_empty():
		_mount(data, "cutter" if str(data.profile.tool) == "cutter" else "depositor")


static func _blade(data: Dictionary, rocket: bool) -> void:
	_part(data, "weighted_grip", Vector2.ZERO, Vector2(3, 5), 1.7)
	var blade: int = _part(data, "blade", Vector2(0, -10.5), Vector2(1.8, 17), 0.24, 0.0, "usable")
	_pin(data, "hilt_play", 0, blade, Vector2(0, -2.5), Vector2(-0.10, 0.10), "aim", 0.0, Vector2.UP)
	var guard: int = _part(data, "guard", Vector2(0, -2), Vector2(7, 1.5), 0.12, 0.0, "fin")
	_pin(data, "guard_pin", 0, guard, Vector2(0, -2), Vector2(-0.08, 0.08), "foot")
	_tune(data, {"movement": "flight" if rocket else "rope", "speed": 69.0 if rocket else 44.0,
		"primary": "boost" if rocket else "rope", "secondary": "sail",
		"auxiliary": "self_right" if rocket else "rope_release", "rope": not rocket,
		"body_thrust": rocket, "gyro": 20.0, "thrust": 264.0, "tool": "cutter"})
	_mount(data, "cutter", "articulated", 0, Vector2(0, -2.5), blade)
	data.script.period = 2.2
	data.description = "A katana-slim collider blade with mass concentrated at the grip, slight hilt play and %s." % (
		"rocket thrust along its body" if rocket else "a bungee harpoon and speed-dependent blade lift")


static func _multirotor(data: Dictionary, rig_id: StringName) -> void:
	_tune(data, {"movement": "flight", "primary": "boost", "secondary": "stabilize",
		"body_thrust": true, "speed": 47.0, "thrust": 220.0})
	match rig_id:
		&"tandem":
			_part(data, "long_fuselage", Vector2.ZERO, Vector2(15, 3), 1.8)
			_rotors(data, [Vector2(-8, -2.5), Vector2(8, -2.5)], Vector2(7, 1.6))
			_tune(data, {"gyro": 17.0, "speed": 57.0, "damping": 2.8})
			data.description = "A long fore/aft tandem rotor craft: strong pitch leverage and cruise speed at the cost of doorway clearance."
		&"tricopter":
			_part(data, "offset_cab", Vector2(1.5, 1), Vector2(6, 6), 1.7)
			_rotors(data, [Vector2(-6, -2), Vector2(6, -2), Vector2(0, -7)], Vector2(5, 1.8), Vector2(-0.28, 0.28))
			_tune(data, {"gyro": 22.0, "speed": 46.0, "damping": 3.4, "thrust": 234.0})
			data.description = "A triangular three-pod frame with an offset cab needs persistent trim while retaining a useful third thrust source."
		&"tiltrotor":
			_part(data, "cab", Vector2.ZERO, Vector2(8, 4), 1.4)
			_rotors(data, [Vector2(-6, 0), Vector2(6, 0)], Vector2(5, 2.5), Vector2(-0.8, 0.8))
			data.joints[0].role = "tilt_thruster"
			data.joints[1].role = "tilt_thruster"
			_tune(data, {"gyro": 24.0, "speed": 66.0, "thrust": 235.0, "damping": 3.0})
			data.description = "Wide-travel tilting pods rotate their thrust axes for translation, with the cab still reacting to gimbal motion."
		&"heavylift":
			_part(data, "load_frame", Vector2.ZERO, Vector2(12, 3), 1.7)
			_rotors(data, [Vector2(-8, -2), Vector2(8, -2), Vector2(-4, -6), Vector2(4, -6)], Vector2(5, 1.6))
			var sling: int = _part(data, "load_sling", Vector2(0, 4), Vector2(1.8, 5), 0.16, 0.0, "leg")
			_pin(data, "sling_pivot", 0, sling, Vector2(0, 1), Vector2(-0.6, 0.6), "passive")
			var load_part: int = _part(data, "payload", Vector2(0, 8), Vector2(7, 4), 2.1, 0.0, "usable")
			_pin(data, "payload_pin", sling, load_part, Vector2(0, 6), Vector2(-0.35, 0.35), "passive")
			_tune(data, {"gyro": 31.0, "speed": 32.0, "accel": 170.0, "thrust": 240.0, "damping": 4.0})
			_mount(data, "depositor", "articulated", 0, Vector2(0, 1), load_part)
			data.script.radius = 26.0
			data.script.pace = 0.76
			data.description = "Four rotors lift a seven-part suspended payload: slow deliberate starts and active settling tame the hanging load."
	data.script.altitude = 24.0 if rig_id != &"heavylift" else 28.0
