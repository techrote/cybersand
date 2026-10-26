class_name CyberPlayerPlaygroundWorld
extends RefCounted

const Course = preload("res://scripts/player_playground_course.gd")
const Transport = preload("res://scripts/transport_profiles.gd")
const WATER_NAMES: Array[String] = ["FreeMass · Current", "CellularYield · whole cells",
	"Pressure · reference", "Pressure · cached", "Pressure · dormant", "Inertial · retained momentum"]
const FAMILIES: Array[String] = ["freemass_v1", "cellular_yield_v1", "pressure_flow_v1",
	"pressure_flow_v1", "pressure_flow_v1", "inertial_cellular_v1"]
const VARIANTS: Array[String] = ["reference", "reference", "reference", "cached", "cached_dormant", "reference"]


static func build(world: Object, map_id: StringName, water: int, seed_material: int = 0,
	bodies: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	if (map_id not in Course.MAP_IDS and map_id != &"legacy") or water < 0 or water >= WATER_NAMES.size():
		return {"accepted": false, "error": "Unknown map or Water solver."}
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var request: PackedInt32Array = bridge.default_liquid_policy()
	if water > 0:
		var found: bool = false
		for choice: Dictionary in bridge.liquid_policy_assignment_choices(request, 3):
			if choice.family == FAMILIES[water] and choice.variant == VARIANTS[water] and choice.accepted:
				request = choice.request
				found = true
				break
		if not found:
			return {"accepted": false, "error": "Selected Water solver unavailable in this runtime."}
	var rectangles := PackedInt32Array()
	for rectangle: Dictionary in Course.layout(map_id):
		rectangles.append_array(PackedInt32Array([rectangle.origin.x, rectangle.origin.y,
			rectangle.size.x, rectangle.size.y, rectangle.material]))
	if seed_material != 0:
		var seed := Vector2i(Course.spawn(map_id)) - Vector2i(8,8)
		rectangles.append_array(PackedInt32Array([seed.x, seed.y, 16, 16, seed_material]))
	var profile: Dictionary = Transport.resolve(Transport.preset(0))
	var token: int = bridge.prepare_liquid_world(world, rectangles, profile.packed,
		PackedInt32Array([1, 8, 12, 0]), PackedInt32Array(), request,
		{"definition_hash": (str(rectangles) + ":playground-v2").sha256_text(), "seed": 0,
		"intent": "exploratory", "pacing": "host_paced", "region": PackedInt32Array([0, 0, 1024, 1024]),
		"simulation_window_enabled": false, "cadence_lod_enabled": false,
		"maximum_rule_radius": 3 if water == 5 else 2, "initial_bodies": bodies})
	if token <= 0 or not bridge.commit_liquid_world(world, token):
		return {"accepted": false, "error": bridge.get_last_error()}
	return {"accepted": true, "policy": world.get_liquid_solver_policy(),
		"receipt": world.get_applied_liquid_construction_receipt()}
