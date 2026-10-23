class_name CyberPlayerActorCatalog
extends RefCounted

# PLAY-001 authored human-control rigs. Circles are real Rapier contact shapes;
# the existing cellular bridge deliberately keeps their conservative square mask.
const IDS: Array[StringName] = [&"stuntbuggy", &"trialsbike", &"acrobat", &"arcadelander", &"jetbarrel"]
const NAMES: Dictionary = {&"stuntbuggy": "Loose Cannon", &"trialsbike": "Trials Rat",
	&"acrobat": "Afterimage", &"arcadelander": "Vector Rush", &"jetbarrel": "Barrel Rocket"}


static func has_rig(id: StringName) -> bool:
	return id in IDS


static func name_for(id: StringName) -> String:
	return str(NAMES.get(id, id))


static func controls(id: StringName) -> String:
	match id:
		&"stuntbuggy":
			return "W/S throttle / reverse · A/D or Q/E rider lean and air rotation\nSpace hop · Shift brake · C hold recovery assist"
		&"trialsbike":
			return "W/S throttle / reverse · A/D or Q/E lean and air rotation\nHold Space to preload, release to bunny-hop · Shift brake · C hold recovery assist"
		&"acrobat":
			return "A/D run and steer · Space jump / double jump · hold Shift slide / tap Shift roll\nShift or S + Space bullet jump · C airglide / brake-cancel · mouse aims bullet jump"
		&"arcadelander":
			return "W or Space thrust · S reverse thrust · A/D or Q/E rotate\nShift airbrake · C toggle damped / drift flight"
		&"jetbarrel":
			return "W or Space body-axis jet · S reverse puff · A/D or Q/E strong rotation\nShift airbrake · C hold upright assist"
	return ""


static func build(data: Dictionary, id: StringName) -> void:
	data.id = id
	data.name = name_for(id)
	data.set = &"setP"
	data.theme = "Player movement playground"
	data["human_focused"] = true
	data.profile.merge({"player_controller": "acrobat" if id == &"acrobat" else "vehicle",
		"primary": "none", "secondary": "none", "auxiliary": "none", "slew": 24.0,
		"air_drag": 0.05, "angular_drag": 0.28, "recharge": 0.65,
		"gyro": 34.0, "gyro_kp": 16.0, "damping": 5.5, "play": 0.06}, true)
	data.script.character = "human movement preset; controls are described by the player guide"
	data.limitations = ["Human-focused prototype; motion is driven by bounded authored forces.",
		"Round wheel collision uses real Rapier circles and conservative square native material masks."]
	match id:
		&"stuntbuggy", &"trialsbike":
			_build_vehicle(data, id == &"trialsbike")
		&"acrobat":
			data.color = Color("56dfcb")
			data.description = "A momentum runner with folding legs, buffered jumps, slides, rolls, bullet jumps and airborne cancels."
			data.profile.merge({"movement": "walk", "gravity": 156.0, "speed": 100.0,
				"accel": 520.0, "jump": 80.0, "gyro": 60.0, "air_control": 0.75}, true)
			_part(data, "chassis", Vector2.ZERO, Vector2(7, 9), 1.2)
			for side: int in [-1, 1]:
				var leg: int = _part(data, "leg_%d" % side, Vector2(side * 3.0, 5.5), Vector2(2, 4), 0.20, "leg")
				_pin(data, "hip_%d" % side, 0, leg, Vector2(side * 3.0, 3.5), Vector2(-1.5, 1.5), "leg")
				var foot: int = _part(data, "foot_%d" % side, Vector2(side * 4.0, 8), Vector2(4, 2), 0.16, "foot")
				_pin(data, "ankle_%d" % side, leg, foot, Vector2(side * 3.0, 7.5), Vector2(-1.3, 1.3), "foot")
		&"arcadelander":
			data.color = Color("a3c8ff")
			data.description = "A fast body-axis lander: quick rotation, responsive main engine and a strong airbrake. Toggle drift for long inertial arcs."
			data.profile.merge({"movement": "flight", "gravity": 32.0, "thrust": 440.0,
				"speed": 175.0, "angular_drag": 0.08}, true)
			_part(data, "chassis", Vector2.ZERO, Vector2(7, 10), 1.0)
			for side: int in [-1, 1]:
				var skid: int = _part(data, "skid_%d" % side, Vector2(side * 5.0, 5), Vector2(5, 2), 0.2, "foot")
				_pin(data, "landing_leg_%d" % side, 0, skid, Vector2(side * 3.5, 4), Vector2(-0.35, 0.35), "foot")
		&"jetbarrel":
			data.color = Color("ffb44a")
			data.description = "A heavy barrel with an overpowered jet and deliberate high-authority rotational controls. Hold the stabilizer only when you want help staying upright."
			data.profile.merge({"movement": "flight", "gravity": 110.0, "thrust": 510.0,
				"speed": 155.0, "angular_drag": 0.12, "gyro": 75.0}, true)
			_part(data, "barrel", Vector2.ZERO, Vector2(9, 12), 2.4)
	# Keep ACT-005's ordinary physical mounting chassis and optional equipment
	# lifecycle. The player loadout starts empty, leaving movement controls free.
	data.mounts.append({"id": "player_mount", "part": 0, "offset": Vector2(0, -3),
		"angle": 0.0, "limits": Vector2(-2.5, 2.5), "type": "mounted", "usable": "depositor",
		"reach": 14.0, "radius": 2, "recoil": 2.0, "cooldown": 0.55})


static func _build_vehicle(data: Dictionary, bike: bool) -> void:
	data.color = Color("ff8d66") if bike else Color("e3d76b")
	data.description = "A spring-suspended trials bike: rear-wheel drive, body lean and a charge-release bunny hop." if bike else "A loose seven-part stunt buggy: sprung wheels, a floppy hinged rider, sharp braking and a punchy hop."
	data.profile.merge({"movement": "ground", "gravity": 150.0, "speed": 95.0 if bike else 78.0,
		"accel": 160.0 if bike else 190.0, "gyro": 28.0, "angular_drag": 0.12,
		"gait_rate": 0.0, "gait_amplitude": 0.0}, true)
	var axle: float = 7.0 if bike else 8.5
	var radius: float = 3.5 if bike else 4.0
	_part(data, "chassis", Vector2.ZERO, Vector2(13, 3) if bike else Vector2(17, 4), 1.6 if bike else 2.0)
	for side: int in [-1, 1]:
		var carrier: int = _part(data, "carrier_%d" % side, Vector2(side * axle, 3.0), Vector2(2, 5), 0.28, "suspension")
		data.joints.append({"id": "suspension_%d" % side, "type": "spring", "a": 0, "b": carrier,
			"anchor": Vector2(side * axle, 3.0), "axis": Vector2.DOWN, "limits": Vector2(-1.8, 1.8),
			"rest_length": Vector2(side * axle, 3.0).length(), "stiffness": 75.0, "damping": 1.5,
			"motor_speed": 8.0, "max_force": 420.0, "role": "suspension"})
		var wheel: int = _part(data, "wheel_%d" % side, Vector2(side * axle, 4.5), Vector2.ONE * radius * 2.0, 0.48, "wheel")
		data.parts[wheel].shape = "circle"
		data.parts[wheel]["native_mask"] = "circumscribed_rectangle"
		data.parts[wheel].color = Color("465166")
		data.parts[wheel].friction = 1.0
		_pin(data, "axle_%d" % side, carrier, wheel, Vector2(side * axle, 4.5), Vector2(-PI, PI), "wheel")
		data.joints[-1].limits_enabled = false
		data.joints[-1].motor_speed = 32.0
		data.joints[-1].max_force = 190.0 if bike else 150.0
	var rider: int = _part(data, "rider", Vector2(-0.5, -5), Vector2(3.5, 7), 0.54, "rider")
	_pin(data, "rider_lean", 0, rider, Vector2(-0.5, -1.8), Vector2(-0.9, 0.9), "player_lean")
	var head: int = _part(data, "helmet", Vector2(-0.5, -10), Vector2(3.5, 3.5), 0.18, "rider")
	_pin(data, "neck", rider, head, Vector2(-0.5, -8.6), Vector2(-0.5, 0.5), "passive")


static func _part(data: Dictionary, id: String, offset: Vector2, size: Vector2,
		mass: float, role: String = "hull") -> int:
	data.parts.append({"id": id, "offset": offset, "size": size, "mass": mass,
		"angle": 0.0, "shape": "rectangle", "friction": 0.8, "bounce": 0.04,
		"role": role, "color": data.color if role == "hull" else Color(data.color).lightened(0.12)})
	return data.parts.size() - 1


static func _pin(data: Dictionary, id: String, a: int, b: int, anchor: Vector2,
		limits: Vector2, role: String) -> void:
	data.joints.append({"id": id, "type": "rotary", "a": a, "b": b, "anchor": anchor,
		"axis": Vector2.DOWN, "limits": limits, "limits_enabled": true, "rest_length": 0.0,
		"stiffness": 22.0, "damping": 3.8, "motor_speed": 9.0, "max_force": 130.0,
		"phase": 0.0, "role": role})
