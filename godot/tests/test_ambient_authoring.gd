extends SceneTree

# Strict authored data and normal Setup-v2 persistence. This does not certify
# physical motion, desktop focus or native sensing; the gameplay fixture does.
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Modules = preload("res://scripts/ambient/ambient_modules.gd")
const Examples = preload("res://scripts/ambient/ambient_examples.gd")
const Actuator = preload("res://scripts/ambient/ambient_actuator.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const NativeCatalogue = preload("res://scripts/material_lab_catalogue.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_AUTHORING: " + label)


func run() -> void:
	var native_catalogue := NativeCatalogue.new()
	check(native_catalogue.reload(), "native catalogue is available for material-ID admission")
	var material_ids: Array = []
	for material: Dictionary in native_catalogue.materials:
		if int(material.id) > 0 and bool(material.valid): material_ids.append(int(material.id))
	check(16 in material_ids and 3 in material_ids and 10 not in material_ids, "actual native Oil16 / Water3; unused10 excluded")
	var presets := Profile.presets()
	check(presets.size() >= 16, "six preserved and at least ten living personality profiles are readable")
	var expected_models := {"oil_moth":"runner", "shy_crawler":"crawler", "curious_surveyor":"monowheel",
		"idle_mechanic":"monowheel", "drifting_flyer":"4ly_trainer", "social_roamer":"runner"}
	for profile: Dictionary in presets:
		if int(profile.version) != 1: continue
		var before := JSON.stringify(profile)
		check(Profile.validate(profile, material_ids).is_empty(), "native-catalogue profile validation: " + str(profile.id))
		var caps := Actuator.capabilities(str(expected_models[profile.id]))
		check(Profile.validate(profile, material_ids, caps).is_empty(), "profile's actual locomotion capabilities: " + str(profile.id))
		check(not profile.shared_seed, "preset independent seed is explicit: " + str(profile.id))
		var decoded: Variant = JSON.parse_string(before)
		check(Profile.canonicalize(decoded) == profile, "JSON preserves exact admitted profile values: " + str(profile.id))
		check(JSON.stringify(profile) == before, "validation and canonicalization do not mutate source config: " + str(profile.id))
	var copy := Profile.preset("oil_moth")
	copy.modules[0].params.pace = 0.99
	check(Profile.preset("oil_moth").modules[0].params.pace != 0.99, "preset consumers receive independent authored copies")
	check(Profile.preset("unknown").is_empty(), "unknown preset does not silently borrow a personality")
	check(Profile.validate(Profile.blank()).is_empty(), "empty profile explicitly permits passive neutral intent")
	for type: String in Profile.module_types():
		var value := Profile.blank()
		value.modules = [Profile.make_module(type)]
		check(Profile.validate(value, material_ids).is_empty(), "every exposed module has actual validated defaults: " + type)
		var second := Profile.make_module(type)
		value.modules[0].params.clear()
		check(not second.params.is_empty(), "module defaults do not share mutable authored params: " + type)
	_schema_refusals()
	var policy := PackedInt32Array([0])
	if ClassDB.class_exists(&"CyberDemoBridge"):
		var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
		policy = bridge.call(&"default_liquid_policy")
	var total_actors := 0
	for entry: Dictionary in Examples.legacy_entries():
		var scene := Examples.make(str(entry.id), policy)
		var error := Setup.validate(scene)
		check(error.is_empty(), "ordinary authored example validates: " + str(entry.id) + " / " + error)
		check(scene.actors.size() <= 8, "accepted-main actor capacity: " + str(entry.id))
		check(Catalog.capacity_error(scene.actors).is_empty(), "actual parts/proxies capacity: " + str(entry.id))
		check(not Setup.rectangles(scene).has("error"), "real native terrain construction budget: " + str(entry.id))
		for actor: Dictionary in scene.actors:
			check(actor.control.source == "policy" and actor.control.policy == "ambient", "example uses existing policy producer")
			check(actor.control.ambient is Dictionary, "example embeds authored profile; not a transient preset reference")
			total_actors += 1
		if OS.get_cmdline_user_args().has("--export-examples"):
			var path := "res://examples/workbench/" + str(entry.id) + ".json"
			var file := FileAccess.open(path, FileAccess.WRITE)
			check(file != null, "export self-contained authored example: " + str(entry.id))
			if file != null: file.store_string(JSON.stringify(scene, "\t", true, true) + "\n"); file.close()
		else:
			var path := "res://examples/workbench/" + str(entry.id) + ".json"
			check(FileAccess.file_exists(path), "committed authored JSON example exists: " + str(entry.id))
			if FileAccess.file_exists(path):
				var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				check(Setup.validate(saved).is_empty(), "committed example is normal valid authored data")
				check(saved == JSON.parse_string(JSON.stringify(scene, "", true, true)), "committed example exactly matches constructor: " + str(entry.id))
	var mixed := Setup.mixed_actor_workshop(policy)
	check(Setup.validate(mixed).is_empty(), "existing four-source Mixed Actor Workshop stays valid")
	for actor: Dictionary in mixed.actors:
		check(not actor.control.has("ambient") and actor.control.policy != "ambient", "ambient remains opt-in outside explicit presets")
	var settlement := Examples.make("ambient-settlement", policy)
	var args := OS.get_cmdline_user_args()
	if args.has("--save"):
		var label: String = args[args.find("--save") + 1]
		check(not FileAccess.file_exists(Setup._path(label)), "fresh save test preserves any existing file")
		if not FileAccess.file_exists(Setup._path(label)):
			check(Setup.write_named(label, settlement).is_empty(), "normal Setup-v2 atomically saves profiles and eight assignments")
			var hash_before := FileAccess.get_sha256(Setup._path(label))
			var invalid := settlement.duplicate(true)
			invalid.actors[0].control.ambient.modules[0].params.pace = NAN
			check(not Setup.write_named(label, invalid).is_empty(), "invalid profile cannot replace admitted authored save")
			check(FileAccess.get_sha256(Setup._path(label)) == hash_before, "failed save retains exact valid bytes")
	if args.has("--reopen"):
		var label: String = args[args.find("--reopen") + 1]
		var result := Setup.read_named(label)
		check(result.has("setup"), "fresh process reads authored ambient composition: " + str(result.get("error", "")))
		if result.has("setup"):
			check(JSON.stringify(result.setup, "", true, true) == JSON.stringify(settlement, "", true, true), "fresh process retains exact scene, profiles, order and assignment")
			for actor: Dictionary in result.setup.actors:
				check(actor.control.ambient.seed is int and actor.control.ambient.version is int, "fresh-process authored profile integer canonicalization")
				check(not actor.control.ambient.has("runtime") and not actor.control.ambient.has("rng_state"), "save contains no ephemeral runtime continuation")
			DirAccess.remove_absolute(Setup._path(label))
	print("AMBIENT_AUTHORING ", JSON.stringify({"checks":checks, "failures":failures, "presets":presets.size(), "examples":Examples.legacy_entries().size(), "actors":total_actors}))
	quit(0 if failures.is_empty() else 1)


func _schema_refusals() -> void:
	var good := Profile.preset("oil_moth")
	var original := JSON.stringify(good)
	for mutation: String in ["version", "extra_key", "missing_key", "id", "name", "description", "seed_fraction", "seed_nan", "seed_negative", "seed_big", "shared_seed", "modules_type", "module_type", "module_id", "duplicate_id", "module_key", "enabled", "priority", "weight_nan", "weight_high", "params_key", "params_missing", "radius_fraction", "radius_over", "material_reserved", "material_unknown", "standoff", "avoid_hysteresis", "duration_nan", "boolean", "capacity"]:
		var bad := good.duplicate(true)
		match mutation:
			"version": bad.version = 2
			"extra_key": bad.live_elapsed_seconds = 10
			"missing_key": bad.erase("name")
			"id": bad.id = "../profile"
			"name": bad.name = "   "
			"description": bad.description = "control" + String.chr(1) + "character"
			"seed_fraction": bad.seed = 1.5
			"seed_nan": bad.seed = NAN
			"seed_negative": bad.seed = -1
			"seed_big": bad.seed = 2147483648
			"shared_seed": bad.shared_seed = 1
			"modules_type": bad.modules = {}
			"module_type": bad.modules[0].type = "arbitrary_eval"
			"module_id": bad.modules[0].id = ""
			"duplicate_id": bad.modules[1].id = bad.modules[0].id
			"module_key": bad.modules[0].state = {"remaining":10}
			"enabled": bad.modules[0].enabled = "yes"
			"priority": bad.modules[0].priority = 1.5
			"weight_nan": bad.modules[0].weight = INF
			"weight_high": bad.modules[0].weight = 11
			"params_key": bad.modules[0].params.teleport = true
			"params_missing": bad.modules[0].params.erase("pace")
			"radius_fraction": bad.modules[1].params.radius = 1.5
			"radius_over": bad.modules[1].params.radius = 97
			"material_reserved": bad.modules[1].params.material_id = 10
			"material_unknown": bad.modules[1].params.material_id = 132
			"standoff": bad.modules[1].params.standoff = 60
			"avoid_hysteresis": bad.modules[2].params.enter_distance = 49; bad.modules[2].params.exit_distance = 35
			"duration_nan": bad.modules[3].params.duration = NAN
			"boolean": bad.modules[5].params.jump = "false"
			"capacity":
				bad.modules.clear()
				for index: int in 17: bad.modules.append(Profile.make_module("wander", "wander_" + str(index)))
		check(not Profile.validate(bad).is_empty(), "refuses malformed profile: " + mutation)
		check(Profile.canonicalize(bad).is_empty(), "canonicalization never silently repairs invalid config: " + mutation)
		check(JSON.stringify(good) == original, "refusal preserves previous valid config: " + mutation)
	var unavailable := good.duplicate(true)
	check(not Profile.validate(unavailable, [3]).is_empty(), "catalogue-specific material admission refuses unavailable Oil ID")
	check(not Profile.validate(good, [], Actuator.capabilities("4ly_trainer")).is_empty(), "enabled ground ledge module refuses a flyer")
	var disabled := good.duplicate(true)
	disabled.modules[3].enabled = false
	check(Profile.validate(disabled, [], Actuator.capabilities("4ly_trainer")).is_empty(), "disabled inapplicable module remains authored without claiming its capability")
	var jump := Profile.blank()
	jump.modules = [Profile.make_module("escape_obstruction")]
	jump.modules[0].params.jump = true
	check(not Profile.validate(jump, [], Actuator.capabilities("monowheel")).is_empty(), "ordinary jump recovery refuses incompatible wheel action")
	check(Profile.validate(jump, [], Actuator.capabilities("runner")).is_empty(), "compatible ordinary primary jump is admitted")
