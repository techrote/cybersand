extends SceneTree

## Native ownership and real on-disk schema/preset regression. The harness must
## give this process isolated user data; never corrupt a real user's catalogue.
const Configuration = preload("res://scripts/depth/strata_optics_configuration.gd")
const Presets = preload("res://scripts/depth/strata_optics_presets.gd")
const Profiles = preload("res://scripts/depth/strata_optical_profiles.gd")
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Owner = preload("res://scripts/depth/workbench_layer_owner.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("STRATA3_CONFIG " + label)


func run() -> void:
	check(OS.get_environment("STRATA3_TEST_ISOLATED_USERDATA") == "1", "test explicitly requires isolated user data")
	check(not FileAccess.file_exists(Presets.PATH), "fresh process has no existing user preset catalogue")
	if not failures.is_empty(): quit(1); return
	var configuration := Configuration.defaults()
	check(Configuration.validate(configuration).is_empty(), "complete Classic defaults admitted")
	check(not configuration.enabled and not configuration.planes.play.participates, "Classic bypass and crisp Play are defaults")
	for key: String in Configuration.GLOBAL_RANGES:
		for bad: Variant in [NAN,INF,-INF,true,"0.5",null]:
			var invalid := configuration.duplicate(true)
			invalid[key] = bad
			check(not Configuration.validate(invalid).is_empty(), "invalid scalar refused " + key + " " + str(bad))
	for patch: Dictionary in [{"version":2},{"planes":{}},{"unexpected":1},{"focus_mode":"pointer"},{"focal_plane":"new-world"}]:
		check(Configuration.patched(configuration,patch).has("error"), "unknown schema or focus authority refused")
	var invalid := configuration.duplicate(true)
	invalid.planes.play.participates = true
	check(not Configuration.validate(invalid).is_empty(), "Play processing cannot be enabled")
	invalid = configuration.duplicate(true)
	invalid.planes.background.tint = [1.0,NAN,1.0]
	check(not Configuration.validate(invalid).is_empty(), "nonfinite colour refused")
	check(Configuration.patched(configuration,{"depth":0.7},"background").has("configuration"), "known plane patch admitted")
	check(configuration.planes.background.depth == 1.0, "patch does not alias caller state")
	for id: String in Profiles.ids():
		check(Configuration.validate(Profiles.configuration(id)).is_empty(), "catalogue config admitted " + id)
	var scene := Document.default_document(Vector2i(512,512))
	scene.presentation.enabled = true
	for id: String in ["scripted","effects","background"]:
		Document.plane(scene,id).rectangles = [[32,32,12,12,58]]
	check(scene.version == 2 and not scene.has("optics"), "old/default scenes retain exact v2 Classic fields")
	var legacy := scene.duplicate(true)
	legacy.version = 1
	legacy.erase("atmosphere")
	legacy.erase("authoring")
	check(Document.validate(legacy).is_empty(), "original v1 still admitted")
	check(not Document.canonical(legacy).has("optics"), "canonical v1 does not silently acquire optics")
	var migrated := Document.with_optics(legacy,Profiles.configuration("architectural"))
	check(migrated.version == 3 and Document.validate(migrated).is_empty(), "explicit optics upgrades v1 losslessly to v3")
	check(migrated.planes == legacy.planes and migrated.presentation == legacy.presentation, "migration preserves layouts and edit authority")
	var owner := Owner.new()
	var prepared: Dictionary = owner.prepare(scene)
	check(prepared.get("ok",false) and owner.commit(prepared.get("token",-1)), "real native decorative owner admitted")
	if not failures.is_empty(): owner.retire(); quit(1); return
	var before := owner.stats()
	var before_layouts: Array = owner.document().planes
	for index: int in 44:
		configuration = Profiles.configuration(Profiles.ids()[index % Profiles.ids().size()])
		configuration.focus_distance = 0.37123456789
		check(owner.set_optics(configuration), "repeated optical commit " + str(index))
	var after := owner.stats()
	check(after == before, "44 optical edits preserve every native owner, history, snapshot and publication counter")
	check(owner.document().planes == before_layouts, "optical edits preserve authored geometry/revisions")
	for id: String in ["scripted","effects","background"]:
		check(owner.material_at(id,Vector2i(35,35)) == 58, "actual native material unchanged " + id)
	var saved_scene := owner.document()
	check(saved_scene.version == 3 and Document.validate(saved_scene).is_empty(), "settings-only fast path remains a valid v3 scene")
	invalid = configuration.duplicate(true)
	invalid.strength = NAN
	check(not owner.set_optics(invalid) and owner.document() == saved_scene, "invalid optical commit retains previous complete scene")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var setup := Setup.fresh(bridge.default_liquid_policy(),Vector2i(512,512))
	var name := "strata003-optics-roundtrip"
	check(Document.write_named(name,setup,{},{},saved_scene).is_empty(), "real v3 authored scene saves")
	var read := Document.read_named(name)
	check(read.get("layered",false) and read.document == saved_scene, "real v3 authored settings/layout roundtrip exact")
	check(read.document.optics.focus_distance == configuration.focus_distance, "v3 retains float64 optical precision")
	var digest := FileAccess.get_sha256(Setup._path(name))
	invalid = saved_scene.duplicate(true)
	invalid.optics.version = 2
	check(not Document.write_named(name,setup,{},{},invalid).is_empty() and FileAccess.get_sha256(Setup._path(name)) == digest,
		"invalid v3 replacement preserves exact saved scene")
	var saved := Presets.save("Copper halls",configuration)
	check(not saved.has("error") and saved.catalogue.presets.size() == 1, "named preset writes through native atomic service")
	var preset_read := Presets.read_catalogue()
	check(preset_read.get("catalogue",{}) == saved.catalogue, "custom preset independently reopens exact values")
	var stored: PackedByteArray = FileAccess.get_file_as_bytes(Presets.PATH)
	invalid = configuration.duplicate(true)
	invalid.effects.defocus = 1
	check(Presets.save("Invalid",invalid).has("error") and FileAccess.get_file_as_bytes(Presets.PATH) == stored,
		"malformed preset cannot replace catalogue")
	var file := FileAccess.open(Presets.PATH,FileAccess.WRITE)
	file.store_string("{bad-json")
	file.close()
	check(Presets.read_catalogue().has("error"), "corrupt custom catalogue truthfully refused")
	check(Presets.save("Recovered?",configuration).has("error") and FileAccess.get_file_as_string(Presets.PATH) == "{bad-json",
		"saving cannot silently erase a malformed existing catalogue")
	file = FileAccess.open(Presets.PATH,FileAccess.WRITE)
	file.store_buffer(stored)
	file.close()
	check(Presets.write_quality("low").is_empty() and Presets.read_quality() == "low", "quality persists separately")
	check(FileAccess.get_file_as_bytes(Presets.PATH) == stored and owner.document() == saved_scene,
		"quality changes neither authored scene nor preset catalogue")
	check(not Presets.write_quality("unbounded").is_empty() and Presets.read_quality() == "low", "unsupported quality retains prior preference")
	check(not Presets.remove(saved.id).has("error") and Presets.read_catalogue().catalogue.presets.is_empty(), "custom preset can be removed")
	check(owner.document() == saved_scene, "removing preset cannot mutate embedded scene values")
	owner.retire()
	check(owner.stats().native_world_count == 0, "actual native worlds retire after optical use")
	print("STRATA3_CONFIGURATION_RESULT " + JSON.stringify({"schema":"strata3-configuration-regression-v1", "checks":checks,
		"failures":failures,"passed":failures.is_empty(),"native_isolation":true,"disk_roundtrip":true}))
	quit(0 if failures.is_empty() else 1)
