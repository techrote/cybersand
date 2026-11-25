extends SceneTree

# Authored values and real Setup codec only. Ordinary scene progression, peer
# movement and visual appeal are qualified separately and never inferred here.
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Authoring = preload("res://scripts/ambient/ambient_authoring.gd")
const Examples = preload("res://scripts/ambient/ambient_living_examples.gd")
const AllExamples = preload("res://scripts/ambient/ambient_examples.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const NativeCatalogue = preload("res://scripts/material_lab_catalogue.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("AMBIENT_LIVING_AUTHORING: " + label)


func run() -> void:
	var native := NativeCatalogue.new()
	check(native.reload(), "actual native material catalogue loads")
	var admitted: Array = []
	for material: Dictionary in native.materials:
		if bool(material.valid) and int(material.id) > 0: admitted.append(int(material.id))
	check(Profile.module_types().size() >= 24, "at least twenty-four distinct module schemas")
	var profiles := Profile.presets()
	check(profiles.size() >= 16, "six preserved and ten living profiles")
	var legacy := 0
	var living := 0
	for profile: Dictionary in profiles:
		check(Profile.validate(profile, admitted).is_empty(), "profile schema and native materials: " + str(profile.id))
		if int(profile.version) == 1: legacy += 1
		else: living += 1
		var before := JSON.stringify(profile)
		var upgraded := Profile.upgrade(profile)
		check(not upgraded.is_empty() and int(upgraded.version) == 2, "explicit copied v2 upgrade: " + str(profile.id))
		check(JSON.stringify(profile) == before, "upgrade never mutates source profile")
		check(Profile.upgrade(upgraded) == upgraded, "v2 upgrade is idempotent")
	check(legacy == 6 and living >= 10, "all six v1 profiles preserved with ten additive living profiles")
	check(AllExamples.legacy_entries().size() == 5 and Examples.entries().size() == 6 and AllExamples.entries().size() == 11, "five preserved plus six new ordinary scenes")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var policy: PackedInt32Array = bridge.call(&"default_liquid_policy")
	var total_actors := 0
	var scene: Dictionary = {}
	for entry: Dictionary in Examples.entries():
		var data := Examples.make(str(entry.id), policy)
		check(not data.is_empty(), "ordinary source-backed scene loads: " + str(entry.id))
		if data.is_empty(): continue
		check(Setup.validate(data).is_empty(), "normal Setup-v2 admission: " + str(entry.id))
		check(data.actors.size() >= 6 and data.actors.size() <= 8, "substantial physically admissible cast")
		check(data.edits.size() >= 45, "native architectural construction has substantial editable detail")
		check(Authoring.validate(data.get("ambient_authoring", {})).is_empty(), "scene carries reusable authored library")
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://examples/workbench/" + str(entry.id) + ".json"))
		saved.liquid_policy = Array(policy)
		check(data == saved, "source constructor preserves exact ordinary saved data")
		var original := JSON.stringify(data)
		for actor: Dictionary in data.actors:
			check(int(actor.control.ambient.version) == 2, "new inhabitant uses ordinary v2 profile")
			check(Catalog.control_error(str(actor.model), actor.control).is_empty(), "profile respects actual actor capabilities")
			check(not actor.control.ambient.has("runtime") and not actor.control.ambient.has("rng_state"), "private runtime memory is absent from saved profile")
			total_actors += 1
		var copied := data.duplicate(true)
		copied.actors[0].control.ambient.name = "Independent override"
		check(JSON.stringify(data) == original, "individual override does not alias shared library or constructor")
		if scene.is_empty(): scene = data
	_library_refusals(profiles)
	var args := OS.get_cmdline_user_args()
	if args.has("--save") and not scene.is_empty():
		var label: String = args[args.find("--save") + 1]
		check(not FileAccess.file_exists(Setup._path(label)), "fresh save cannot overwrite user work")
		if not FileAccess.file_exists(Setup._path(label)):
			check(Setup.write_named(label, scene).is_empty(), "normal Save retains library, regions, relationships and assignments")
			var digest := FileAccess.get_sha256(Setup._path(label))
			var bad := scene.duplicate(true)
			bad.ambient_authoring.profiles[0].memory.runtime_state = {"visits":[]}
			check(not Setup.write_named(label, bad).is_empty(), "ephemeral state cannot enter authored library")
			check(FileAccess.get_sha256(Setup._path(label)) == digest, "invalid Save preserves previous bytes")
	if args.has("--reopen") and not scene.is_empty():
		var label: String = args[args.find("--reopen") + 1]
		var result := Setup.read_named(label)
		check(result.has("setup"), "fresh process ordinary Reopen")
		if result.has("setup"):
			check(JSON.parse_string(JSON.stringify(result.setup)) == JSON.parse_string(JSON.stringify(scene)), "fresh Reopen retains all authored living values")
			check(result.setup.ambient_authoring.version is int, "library version canonicalized")
			for actor: Dictionary in result.setup.actors:
				check(actor.control.ambient.seed is int, "inhabitant seed canonicalized")
			DirAccess.remove_absolute(Setup._path(label))
	print("AMBIENT_LIVING_AUTHORING ", JSON.stringify({"checks":checks, "failures":failures, "profiles":profiles.size(), "scenes":Examples.entries().size(), "actors":total_actors}))
	quit(0 if failures.is_empty() else 1)


func _library_refusals(profiles: Array) -> void:
	var good := Authoring.blank()
	good.profiles = [profiles.back().duplicate(true)]
	check(Authoring.validate(good).is_empty(), "bounded library accepts full valid profile")
	var canonical := Authoring.canonicalize(good)
	canonical.profiles[0].name = "Changed copy"
	check(good.profiles[0].name != canonical.profiles[0].name, "library canonicalization owns its copied values")
	for mutation: String in ["unknown", "version", "duplicate", "invalid_profile", "capacity"]:
		var bad := good.duplicate(true)
		match mutation:
			"unknown": bad.runtime = {}
			"version": bad.version = 2
			"duplicate": bad.profiles.append(bad.profiles[0].duplicate(true))
			"invalid_profile": bad.profiles[0].seed = NAN
			"capacity":
				bad.profiles.clear()
				for index: int in 33:
					var item: Dictionary = profiles.back().duplicate(true)
					item.id = "library_" + str(index)
					bad.profiles.append(item)
		check(not Authoring.validate(bad).is_empty() and Authoring.canonicalize(bad).is_empty(), "library refuses " + mutation)
