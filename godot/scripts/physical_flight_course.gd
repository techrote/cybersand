class_name CyberPhysicalFlightCourse
extends RefCounted

# 4LY-003 geometry is native material, not a duplicate collision-only training
# world. CyberPhysicalActorArena installs these rectangles in CyberNativeCellWorld
# and rebuilds the normal Rapier hard-surface coupling from that same world.
const VERSION: int = 1
const SPLIT_VERSION: int = 3
const Sealed = preload("res://scripts/physical_flight_sealed_suite.gd")
const ID: String = "4ly-flight-course/v1"
const ARENA = Rect2i(128, 128, 512, 224)
const START = Vector2(192.0, 238.0)
const IDS: Array[String] = [
	"unsupported_hover", "horizontal_reach", "vertical_reach", "diagonal_reach",
	"reverse", "arrival_braking", "wide_corridor", "offset_gates",
	"corner", "slalom", "wall_recovery", "neutral_control",
	"constant_control", "power_off"
]
const OBSTACLE_IDS: Array[String] = [
	"wide_corridor", "offset_gates", "corner", "slalom", "wall_recovery"
]
const NEGATIVE_IDS: Array[String] = ["neutral_control", "constant_control", "power_off"]


static func scenario(id: String, seed: int = 0, split: String = "development") -> Dictionary:
	if id not in IDS or seed < 0 or split not in ["development", "tuning", "final"]:
		return {}
	# The public v1 final geometry was disclosed during implementation and is
	# INVALID as a sealed score. The successor independent suite lives outside
	# the repository, loads only after a frozen-teacher/source admission, and
	# provides exact geometry without leaking it to any policy observation.
	if split == "final":
		return Sealed.resolve(id, seed, scenario(id, seed, "development"))
	# Neither scenario identity nor its evaluator geometry is policy input.
	var start: Vector2 = START
	var goals: Array[Vector2] = [Vector2(350.0, 238.0)]
	var obstacles: Array = []
	var family: String = "free_space"
	var deadline: int = 1080
	match id:
		"unsupported_hover":
			goals = [START]
			family = "hover"
			deadline = 300
		"horizontal_reach":
			goals = [Vector2(362.0, 238.0)]
		"vertical_reach":
			goals = [Vector2(192.0, 171.0)]
		"diagonal_reach":
			start = Vector2(194.0, 294.0)
			goals = [Vector2(362.0, 180.0)]
		"reverse":
			goals = [Vector2(362.0, 238.0), Vector2(218.0, 238.0)]
			family = "reversal"
			deadline = 1560
		"arrival_braking":
			goals = [Vector2(466.0, 238.0)]
			family = "arrival"
			deadline = 1500
		"wide_corridor":
			goals = [Vector2(518.0, 245.0)]
			obstacles = [
				_rect(252, 176, 272, 35), _rect(252, 288, 272, 35)]
			family = "obstacles"
			deadline = 1800
		"offset_gates":
			goals = [Vector2(518.0, 245.0)]
			obstacles = [
				# Alternating apertures: lower opening first, then upper.
				# The direct start -> goal segment is blocked by real cells.
				_rect(295, 132, 14, 119), _rect(295, 304, 14, 44),
				_rect(414, 132, 14, 73), _rect(414, 261, 14, 87)]
			family = "obstacles"
			deadline = 2100
		"corner":
			goals = [Vector2(494.0, 260.0)]
			obstacles = [_rect(315, 216, 75, 72)]
			family = "obstacles"
			deadline = 2100
		"slalom":
			goals = [Vector2(538.0, 238.0)]
			obstacles = [
				# Slalom requires down, then up, then down through wide
				# physically passable openings, not a straight dash.
				_rect(282, 132, 14, 127), _rect(366, 252, 14, 96),
				_rect(450, 132, 14, 127)]
			family = "obstacles"
			deadline = 2400
		"wall_recovery":
			# Start close to, but clear of, the wall. The bounded host disturbance
			# below then creates a real contact opportunity before the teacher can
			# simply route around the obstacle. Qualification still requires the
			# actor to recover and complete low-speed arrival afterwards.
			start = Vector2(281.0, 241.0)
			goals = [Vector2(440.0, 241.0)]
			obstacles = [_rect(292, 215, 18, 60)]
			family = "recovery"
			deadline = 2100
		"neutral_control", "constant_control", "power_off":
			goals = [Vector2(420.0, 238.0)]
			family = "negative"
			deadline = 540

	# Split separation alters start/goal and obstacle geometry, not merely a
	# pseudorandom seed. Final layouts are registered but never teacher-tuned.
	if split == "tuning":
		start += Vector2(0.0, -16.0)
		for index: int in range(goals.size()):
			goals[index] += Vector2(-18.0, 16.0)
		if id in OBSTACLE_IDS:
			obstacles.append(_rect(558, 148, 10, 28))
	# Geometry-split amendment v2: retain the semantics of HORIZONTAL,
	# VERTICAL and HOVER tests. Off-axis variants would not test the same
	# registered handling skill. This changes no physical plant or score gate.
	if id == "unsupported_hover":
		goals = [start]
	elif id in ["horizontal_reach", "arrival_braking", "reverse",
		"neutral_control", "constant_control", "power_off"]:
		for index: int in range(goals.size()):
			var goal_horizontal: Vector2 = goals[index]
			goal_horizontal.y = start.y
			goals[index] = goal_horizontal
	elif id == "vertical_reach":
		var vertical_target: Vector2 = goals[0]
		vertical_target.x = start.x
		if split == "tuning":
			vertical_target.y = 158.0
		goals = [vertical_target]
	# Only bounded, mechanically irrelevant repeat variation on development
	# and tuning. Final geometry is fully specified by its separate split.
	if split != "final":
		var shift: int = seed % 3 - 1
		if id in OBSTACLE_IDS and not obstacles.is_empty():
			var first: Dictionary = obstacles[0]
			first["origin"] = Vector2i(first.origin) + Vector2i(0, shift * 2)
			obstacles[0] = first

	var radius: float = 12.0 if family != "hover" else 9.0
	return {"version": VERSION, "split_version": SPLIT_VERSION, "id": id, "seed": seed, "split": split,
		"family": family, "start": start, "goals": goals,
		"arrival_radius": radius, "speed_tolerance": 2.5,
		"dwell_ticks": 36, "max_ticks": deadline,
		# The negative controls must actually fail low-speed arrival, not pass a
		# vacuous evaluator ban on navigation credit. Their targets are remote.
		"navigation_credit": family != "hover",
		"power_off": id == "power_off",
		"disturbance": {"tick": 6, "delta_velocity": Vector2(24.0, 0.0),
			"delta_angular_velocity": 0.4} if id == "wall_recovery" else {},
		"obstacles": obstacles,
		"bounds": ARENA}


static func _rect(x: int, y: int, width: int, height: int) -> Dictionary:
	return {"origin": Vector2i(x, y), "size": Vector2i(width, height), "material": 1}


static func layout(id: String, seed: int = 0, split: String = "development") -> Array:
	var definition: Dictionary = scenario(id, seed, split)
	if definition.is_empty():
		return []
	# Fully bounded world fixture, including collision wall/floor/ceiling.
	var result: Array = [
		_rect(128, 128, 512, 4), _rect(128, 132, 4, 216),
		_rect(636, 132, 4, 216), _rect(128, 348, 512, 4)
	]
	result.append_array(definition.obstacles.duplicate(true))
	return result


static func feasible_clearance(model: StringName, id: String, seed: int = 0,
		split: String = "development") -> Dictionary:
	var definition: Dictionary = scenario(id, seed, split)
	if definition.is_empty():
		return {}
	var profile: Dictionary = CyberPhysicalFlightProfile.entry(model)
	if profile.is_empty():
		return {}
	var collider := Vector2(float(profile.collider_size[0]), float(profile.collider_size[1]))
	# Exact authored minimum nominal gap; a separate actual-Rapier test must
	# establish contact/swing feasibility. Never certify a gap by actor name.
	var gap: float = 0.0
	match id:
		"wide_corridor":
			gap = 77.0
		"offset_gates":
			gap = 53.0
		"slalom":
			gap = 89.0
		_:
			gap = 0.0
	return {"nominal_gap_cells": gap, "collider": collider,
		"nominal_margin_cells": gap - collider.y if gap > 0.0 else -1.0,
		"clearance_measured": false,
		"feasible_nominal": gap == 0.0 or gap > collider.y + 6.0}
