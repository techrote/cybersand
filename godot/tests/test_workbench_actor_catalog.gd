extends SceneTree

const Actors = preload("res://scripts/workbench_actor_catalog.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Preferences = preload("res://scripts/flyer_preferences.gd")
var checks := 0
var failures: Array[String] = []

func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures.append(description)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	check(Actors.ids().size() == 16 and Actors.pilot_ids().size() == 15,"complete actor roster")
	check(Actors.ids().slice(0,8) == ["midge","needle","kestrel","afterglow","surveyor","cartographer","observatory","scooper"],"original flyer order preserved")
	check(Actors.kind("missing") == "" and Actors.definition_hash("missing").is_empty(),"unavailable model has no admission")
	var hashes := {}
	for id: String in Actors.ids():
		check(not Actors.definition_hash(id).is_empty(),id+" has definition identity")
		check(not hashes.has(Actors.definition_hash(id)),id+" distinct definition identity")
		hashes[Actors.definition_hash(id)] = true
		check(Actors.bounds(id).has_area(),id+" has bounded placement footprint")
		var a := Setup.instance(id,1,Vector2(1500,1400))
		var s := Setup.fresh(PackedInt32Array([1]))
		s.actors = [a]; s.selected = 1; s.next_id = 2
		check(Setup.validate(s).is_empty(),id+" admitted in distant canvas")
		check(Setup.validate(JSON.parse_string(JSON.stringify(s))).is_empty(),id+" survives JSON number representation")
		check(a.usable_index == -1 and a.usable_power == 1.0,id+" starts without usable")
		var physical := Setup.physical_definitions(s)
		var material := Setup.material_definitions(s)
		check((physical.size() == 0 and material.size() == 1) if Actors.kind(id) == "material" else (physical.size() == 1 and material.is_empty()),id+" has truthful owner route")
		if Actors.kind(id) == "mechanical":
			check(Actors.definition(id).parts.size() > 1,id+" retains multipart equipment chassis")
			for usable: int in range(-1,32):
				a.usable_index = usable
				check(Setup.validate(s).is_empty(),id+" admits usable "+str(usable))
		else:
			a.usable_index = 0
			check(not Setup.validate(s).is_empty(),id+" cannot invent equipment mount")
		if id != Setup.BARREL:
			check(Preferences.validate_profile(Preferences.default_profile(Actors.capabilities(id)),Actors.capabilities(id)).is_empty(),id+" default profile valid")
	legacy_and_input()
	palette()
	print("WORKBENCH_ACTOR_CATALOG "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func palette() -> void:
	var materials := Setup.paint_materials()
	check(materials.size() == CyberCellWorld.LAST_MATERIAL and materials.slice(0,12) == Setup.MATERIALS,"registered palette preserves original twelve order")
	var start := Setup.fresh(PackedInt32Array([1]),Vector2i(512,512))
	for material: int in [0,1,4,24,122,131]:
		start.material = material; start.edits = [[250,250,3,material]]
		check(Setup.validate(start).is_empty(),"registered paint material "+str(material))
	for material: int in [10,255]:
		start.material = material; start.edits = []
		check(not Setup.validate(start).is_empty(),"reserved/unregistered palette material refused")
		start.material = 2; start.edits = [[250,250,3,material]]
		check(not Setup.validate(start).is_empty(),"reserved/unregistered saved paint refused")
	start.material = 24; start.edits = [[250,250,3,24]]; start.source = [50,50,24]
	check(not Setup.validate(start).is_empty(),"painting Brine does not grant a liquid powder source")
	start.source = [50,50,14]
	check(Setup.validate(start).is_empty(),"original powder source independent of paint material")
	var name := "test-roster-palette-%d" % OS.get_process_id()
	check(Setup.write_named(name,start).is_empty(),"new palette saves to bounded named recipe")
	var loaded := Setup.read_named(name)
	check(loaded.has("setup") and loaded.setup.material == 24 and loaded.setup.edits[0][3] == 24 and loaded.setup.source[2] == 14,"registered paint/source choices reload exactly")
	var path: String = Setup._path(name)
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func legacy_and_input() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/player_actor_catalog.gd").replace("\r\n","\n")
	check(Actors.normalized_source_hash(source) == Actors.normalized_source_hash(source.replace("\n","\r\n")),"definition identity survives LF/CRLF checkout")
	check(Actors.normalized_source_hash(source) != Actors.normalized_source_hash(source+"#delta\n"),"source changes still alter identity")
	var legacy := Setup.fresh(PackedInt32Array([1]))
	legacy.actors = [Setup.instance("midge",1,Vector2(200,200))]
	legacy.next_id = 2; legacy.selected = 1
	for version: int in [2,3]:
		var s := legacy.duplicate(true)
		s.version = version
		s.actors[0].erase("usable_index"); s.actors[0].erase("usable_power")
		if version == 2: s.actors[0].erase("customization")
		check(Setup.validate(s).is_empty(),"historical version"+str(version)+" remains readable")
		var normalized := Setup.normalized(s)
		check(normalized.version == 4 and normalized.actors[0].usable_index == -1 and normalized.actors[0].customization.acceleration == 1.0,"neutral legacy migration")
		check(Setup.validate(normalized).is_empty(),"normalized start valid")
	var fields := Setup.fresh(PackedInt32Array([1]))
	fields.actors = [Setup.instance("dryswarm",1,Vector2(100,100)),Setup.instance("liquidswarm",2,Vector2(400,400))]
	fields.next_id = 3; fields.selected = 2
	check(Setup.validate(fields).is_empty() and Setup.physical_definitions(fields).is_empty(),"all-native roster has no fabricated rigid body")
	check(Setup.material_definitions(fields)[1].material_id == 3,"Water field keeps native material")
	fields.actors[0].options.mass_multiplier = 2.0
	check(not Setup.validate(fields).is_empty(),"native field rejects mass tuning")
	var bindings := Preferences.default_bindings()
	for id: String in ["stuntbuggy","trialsbike","acrobat","arcadelander","jetbarrel","dryswarm","liquidswarm"]:
		var result := Preferences.from_state(bindings,{KEY_SHIFT:true},Vector2.ZERO,Vector3i.ZERO,0,{},true,true)
		check(result.action.secondary and not result.ports.boost,id+" keeps Shift secondary")
		result = Preferences.from_state(bindings,{KEY_CTRL:true},Vector2.ZERO,Vector3i.ZERO,0,{},true,true)
		check(not result.action.secondary,id+" does not move secondary to Ctrl")
	var flyer := Preferences.from_state(bindings,{KEY_SHIFT:true})
	check(not flyer.action.secondary and flyer.ports.boost,"flyer Shift stays boost")
	flyer = Preferences.from_state(bindings,{KEY_CTRL:true})
	check(flyer.action.secondary and not flyer.ports.boost,"flyer Ctrl stays airbrake")
	for id: String in Actors.pilot_ids():
		var caps := Actors.capabilities(id)
		for code: Key in [KEY_M,KEY_N,KEY_U]:
			var value := Preferences.default_profile(caps)
			value.bindings.primary = [code]
			check(Preferences.validate_profile(value,caps).is_empty() == (Actors.kind(id) != "mechanical"),id+" conditional equipment key "+str(code))
