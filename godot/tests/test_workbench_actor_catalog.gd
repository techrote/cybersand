extends SceneTree

# Authoring/schema coverage. Coupled physics, controller handoff and native
# equipment execution are deliberately exercised by the integration campaign.
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Physical = preload("res://scripts/physical_actor_catalog.gd")
const Flight = preload("res://scripts/physical_flight_profile.gd")
const Generated = preload("res://scripts/workbench_generated_map.gd")
const Baseline = preload("res://scripts/workbench_material_baseline.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("WB_ACTOR_CATALOG: " + label)


func run() -> void:
	var policy := PackedInt32Array([0])
	if ClassDB.class_exists(&"CyberDemoBridge"):
		var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
		policy = bridge.call(&"default_liquid_policy")
	var models := Catalog.ids()
	check(models.size() == Fleet.count() + Physical.RIG_IDS.size() + Flight.IDS.size() + 1,
		"all accepted physical identities and unchanged fleet are discoverable")
	var seen := {}
	var maximum_parts := 0
	for model: String in models:
		check(not seen.has(model), "unique model: " + model)
		seen[model] = true
		var data := Catalog.definition(model)
		var entry := Catalog.entry(model)
		var control := Catalog.default_control(model)
		maximum_parts = maxi(maximum_parts, int(entry.parts))
		check(not data.is_empty() and not entry.is_empty(), "resolved prepared definition: " + model)
		check(int(entry.parts) >= 1 and int(entry.parts) <= 8, "includes bounded physical equipment chassis: " + model)
		check(Catalog.control_error(model, control).is_empty(), "admitted default controller/equipment: " + model)
		check(not Catalog.definition_hash(model).is_empty(), "stable definition identity: " + model)
		var actor := Setup.instance(model, 1, Vector2(256,240))
		var recipe := Setup.fresh(policy, Vector2i(512,512))
		recipe.actors = [actor]
		recipe.next_id = 2
		check(Setup.validate(recipe).is_empty(), "ordinary Setup-v2 actor admission: " + model + " / " + Setup.validate(recipe))
	check(maximum_parts == 8, "roster covers full eight-part capacity")
	check(Catalog.definition("missing-rig").is_empty() and not Catalog.has_model("missing-rig"), "unknown models refuse")
	check(not Catalog.supports(Setup.BARREL, "human") and Catalog.supports(Setup.BARREL, "passive"), "passive barrel cannot acquire drive")
	check(not Catalog.equipment_error("4ly_trainer", 0).is_empty(), "4LY cannot acquire equipment topology")
	check(not Catalog.equipment_error(Fleet.stable_id(0), 0).is_empty(), "legacy fleet cannot acquire ACT005 mount")
	check(not Catalog.equipment_error(Setup.BARREL, 0).is_empty(), "barrel cannot acquire equipment")
	check(Catalog.equipment_error("crawler", 8).is_empty(), "compatible physical vacuum admitted")
	check(not Catalog.equipment_error("crawler", 32).is_empty(), "unknown equipment refused")
	var legacy := Setup.fresh(policy, Vector2i(512,512))
	legacy.actors = [Setup.instance(Fleet.stable_id(0),1,Vector2(128,120)),Setup.instance(Setup.BARREL,2,Vector2(256,120))]
	legacy.next_id = 3
	check(not legacy.actors[0].has("control") and not legacy.actors[1].has("control"), "unchanged legacy actor field shape")
	var legacy_bytes := JSON.stringify(legacy)
	check(Setup.validate(JSON.parse_string(legacy_bytes)).is_empty(), "old Setup-v2 JSON survives parser number types")
	var defs := Setup.physical_definitions(legacy)
	check(defs[0].producer == "human" and defs[1].producer == "passive", "old sources are preserved")
	check(legacy_bytes == JSON.stringify(legacy), "validation and definition resolution never rewrite authored data")
	var mixed := Setup.mixed_actor_workshop(policy)
	check(Setup.validate(mixed).is_empty(), "Mixed Actor Workshop validates: " + Setup.validate(mixed))
	check(not Setup.rectangles(mixed).has("error"), "genuine material-cell terrain compiles")
	check(mixed.actors.size() == 6 and mixed.extent == [1024,512], "six-actor ordinary landscape start")
	var sources := {}
	var body_count := 0
	for actor: Dictionary in mixed.actors:
		sources[str(actor.control.source)] = true
		body_count += Catalog.part_count(str(actor.model))
	check(sources.has_all(["human","scripted","policy","passive"]), "mixed cast has all four controller sources")
	check(body_count > mixed.actors.size() and body_count <= 64, "multiple articulated actors share the bounded body allocation")
	check(Setup.validate(JSON.parse_string(JSON.stringify(mixed))).is_empty(), "mixed control survives JSON roundtrip")
	var wrong_tuning := mixed.duplicate(true)
	wrong_tuning.actors[1].options.thrust_multiplier = 2.0
	check(not Setup.validate(wrong_tuning).is_empty(), "mechanical models refuse unsupported fleet thrust tuning")
	var flight_recipe := Setup.fresh(policy,Vector2i(512,512))
	flight_recipe.actors = [Setup.instance("4ly_trainer",1,Vector2(200,180))]
	flight_recipe.next_id = 2
	flight_recipe.actors[0].options.mass_multiplier = 2.0
	check(not Setup.validate(flight_recipe).is_empty(), "4LY frozen plant refuses mass override")
	var before := JSON.stringify(mixed)
	for mutation: String in ["unknown_model","hash","control_version","control_key","source","equipment","decision_fraction",
			"decision_zero","decision_over","enabled_type","policy","option_nonfinite","spawn","actor_key","root_key","duplicate"]:
		var bad := mixed.duplicate(true)
		match mutation:
			"unknown_model": bad.actors[1].model = "deleted-catalogue-entry"
			"hash": bad.actors[1].hash = "stale-definition"
			"control_version": bad.actors[1].control.version = 2
			"control_key": bad.actors[1].control.hidden_world_query = true
			"source": bad.actors[1].control.source = "AI"
			"equipment": bad.actors[0].control.usable_index = 1
			"decision_fraction": bad.actors[1].control.decision_ticks = 1.5
			"decision_zero": bad.actors[1].control.decision_ticks = 0
			"decision_over": bad.actors[1].control.decision_ticks = 13
			"enabled_type": bad.actors[1].control.enabled = 1
			"policy": bad.actors[4].control.policy = "unconnected-LLM"
			"option_nonfinite": bad.actors[1].options.mass_multiplier = NAN
			"spawn": bad.actors[1].spawn = [1,1]
			"actor_key": bad.actors[1].live_momentum = [10,20]
			"root_key": bad.live_tick = 99
			"duplicate": bad.actors[1].id = bad.actors[0].id
		check(not Setup.validate(bad).is_empty(), "refuse malformed authored extension: " + mutation)
		check(JSON.stringify(mixed) == before, "refusal preserves valued authored recipe: " + mutation)
	var over := mixed.duplicate(true)
	for i: int in range(7,10): over.actors.append(Setup.instance(Setup.BARREL,i,Vector2(920,260)))
	over.next_id = 10
	check(not Catalog.capacity_error(over.actors).is_empty() and not Setup.validate(over).is_empty(), "actor exhaustion refuses before live preparation")
	var full := Setup.fresh(policy, Vector2i(512,512))
	for i: int in 8: full.actors.append(Setup.instance("stuntbuggy",i+1,Vector2(48+i*56,240)))
	full.next_id = 9
	check(Catalog.capacity_error(full.actors).is_empty() and Setup.validate(full).is_empty(), "64 prepared bodies remain admissible without truncation")
	var copied := Catalog.definition("crawler")
	var original_hash := Catalog.definition_hash("crawler")
	copied.parts.clear()
	check(Catalog.definition_hash("crawler") == original_hash and Catalog.part_count("crawler") > 1, "catalogue observations are owned copies")
	for label: String in Setup.BUILTIN_LABELS + Setup.EQUIPMENT_LABELS:
		var old := Setup.builtin(label,policy)
		check(Setup.validate(old).is_empty(), "existing built-in remains valid: " + label)
	var args := OS.get_cmdline_user_args()
	if args.has("--save"):
		var label: String = args[args.find("--save")+1]
		check(not FileAccess.file_exists(Setup._path(label)), "fresh-process test refuses existing user file")
		if not FileAccess.file_exists(Setup._path(label)):
			check(Setup.write_named(label,mixed).is_empty(), "atomic mixed authored save")
			var saved_hash := FileAccess.get_sha256(Setup._path(label))
			check(not Setup.write_named(label,wrong_tuning).is_empty(), "invalid actor cannot replace an existing valued file")
			check(FileAccess.get_sha256(Setup._path(label)) == saved_hash, "failed actor save preserves complete previous file")
			write_other_formats(label,mixed)
	if args.has("--reopen"):
		var label: String = args[args.find("--reopen")+1]
		var read := Setup.read_named(label)
		check(not read.has("error"), "fresh process opens saved mixed setup: " + str(read.get("error","")))
		if read.has("setup"):
			check(JSON.stringify(read.setup) == JSON.stringify(mixed), "fresh process retains identities, spawns, source, tuning and equipment")
			check(read.setup.actors[4].control.decision_ticks is int, "control integers are canonical after JSON load")
			DirAccess.remove_absolute(Setup._path(label))
		read_other_formats(label,mixed)
	if args.has("--export-example"):
		var file := FileAccess.open("res://examples/workbench/mixed-actor-workshop.json",FileAccess.WRITE)
		check(file != null, "export self-contained ordinary authored example")
		if file != null:
			file.store_string(JSON.stringify(mixed,"\t",true,true)+"\n")
			file.close()
	print("WB_ACTOR_CATALOG checks=%d failures=%d models=%d prepared_workshop_bodies=%d" % [checks,failures,models.size(),body_count])
	quit(0 if failures == 0 else 1)


func write_other_formats(label: String, setup: Dictionary) -> void:
	# A codec fixture with independently checksummed empty cells exercises the
	# generated manifest envelope; actual generator replay is a separate native
	# integration gate. Never claim this fixture is a native generation receipt.
	var size := Setup.extent_of(setup)
	var cells := PackedByteArray()
	cells.resize(size.x*size.y)
	var recipe := {"seed":589}
	var packet := {"recipe":recipe,"origin":Vector2i.ZERO,"extent":size,
		"cells":cells,"sha256":Generated.digest(cells),"recipe_sha256":Generated.recipe_hash(recipe),
		"generator_fingerprint":"0123456789abcdef","plane_revision":"","generator_revision":1,"receipt_hashes":[]}
	check(Generated.write_named(label+"-generated",setup,packet).is_empty(), "generated authored envelope retains mixed controls")
	var plane := PackedByteArray()
	plane.resize(size.x*size.y*2)
	var baseline := {"schema":1,"extent":size,"cells":plane,"sha256":Generated.digest(plane)}
	check(Baseline.write_named(label+"-baseline",setup,baseline).is_empty(), "native-validated material-baseline envelope retains mixed controls")


func read_other_formats(label: String, expected: Dictionary) -> void:
	for format: String in ["generated","baseline"]:
		var result: Dictionary = Generated.read_named(label+"-generated") if format == "generated" else Baseline.read_named(label+"-baseline")
		check(not result.has("error") and result.has("setup"), "fresh-process " + format + " actor composition load: " + str(result.get("error","")))
		if result.has("setup"):
			check(JSON.stringify(result.setup) == JSON.stringify(expected), format + " preserves all authored values")
			check(result.setup.actors[4].control.usable_index is int and result.setup.actors[4].control.decision_ticks is int,
				format + " canonicalizes control integers after strict validation")
			DirAccess.remove_absolute(Setup._path(label+"-"+format))
