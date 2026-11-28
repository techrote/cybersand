extends SceneTree

# Read-only probe against the existing module; this file is not application code.
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Modules = preload("res://scripts/ambient/ambient_modules.gd")

func _initialize() -> void:
	var module: Dictionary = Profile.make_module("steer_obstacles")
	var observation: Dictionary = {"position":Vector2(100,100),"navigation":{"available":true,"directions":[
		{"available":true,"direction":Vector2.RIGHT,"clearance_cells":1.0,"maximum_distance_cells":32.0,"hit":true,"boundary":false},
		{"available":true,"direction":Vector2.LEFT,"clearance_cells":32.0,"maximum_distance_cells":32.0,"hit":false,"boundary":false}]}}
	var context: Dictionary = {"capabilities":{"vertical":false},"personality":Profile.personality_defaults(),
		"memory":{"available":false},"last_direction":Vector2.RIGHT}
	var state: Dictionary = {"rng":1}
	var first: Dictionary = Modules.evaluate(module,observation,state,0.0,0.0,context)
	context.last_direction = Vector2.LEFT
	var second: Dictionary = Modules.evaluate(module,observation,state,0.1,0.1,context)
	var result: Dictionary = {"case":"AMBIENT-002 canonical obstacle latch negative probe",
		"scope":"Pure copied-value probe; zero physical episodes; no runtime source edit.",
		"source_revision":"83a3db6ffb207761df999abedac77eb1401604a8",
		"first_blocked_heading_selects_clear_left":bool(first.get("active",false)) and first.get("direction") == Vector2.LEFT,
		"next_clear_left_should_retain_before_deadline":bool(second.get("active",false)) and second.get("direction") == Vector2.LEFT,
		"stored_until":float(state.get("until",0.0)),"second_at":0.1,
		"first":first,"second":second,"module":module,"state":state}
	print("AMBIENT_LATCH_NEGATIVE_PROBE=" + JSON.stringify(result))
	quit(0)
