extends SceneTree

const Contract = preload("res://scripts/microscenario_contract.gd")
const Pack = preload("res://scripts/microscenario_reference_pack.gd")
const Compare = preload("res://scripts/microscenario_comparison.gd")
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ms001-legacy-definition-hashes.json"))
	for key: String in legacy.cases:
		var fields: PackedStringArray = key.split("@")
		var checked: Dictionary = Contract.validate(CyberMicroScenarioCatalogue.definition(fields[0],int(fields[1])))
		expect(checked.get("ok",false) and checked.get("hash","") == legacy.cases[key],"Legacy canonical definition changed: " + key)
	for id: String in Pack.ids():
		for seed: int in [0,2,31,0x7FFFFFFF]:
			var value: Dictionary = Pack.definition(id,seed)
			var checked: Dictionary = Contract.validate(value)
			expect(checked.get("ok",false),"Invalid reference definition: %s / %s" % [id,checked])
			if not checked.get("ok",false): continue
			expect(checked.definition.schema_version == 2,"Reference definition is not schema 2")
			expect(Contract.parse(checked.canonical_json).hash == checked.hash,"Schema-2 JSON round-trip changed identity")
			expect(Contract.validate(Pack.definition(id,seed)).hash == checked.hash,"Generator is not deterministic")
			expect(value.events.size() <= 24 and value.observations.size() <= 24,"Reference exceeded unchanged capacities")
	var base: Dictionary = Pack.interaction_fixture()
	for version: Variant in [0,3,2.5,true,"2",null]:
		var bad: Dictionary = base.duplicate(true)
		bad.schema_version = version
		expect(not Contract.validate(bad).ok,"Invalid schema accepted")
	for field: String in ["title","instructions","baseline","profile","duration_ticks","regions"]:
		var bad: Dictionary = base.duplicate(true)
		bad.presentation.erase(field)
		expect(not Contract.validate(bad).ok,"Missing presentation field accepted: " + field)
	for key: String in ["title","instructions","baseline","profile"]:
		for text: Variant in [null,1,"","a".repeat(4097)]:
			var bad: Dictionary = base.duplicate(true)
			bad.presentation[key] = text
			expect(not Contract.validate(bad).ok,"Invalid presentation text accepted")
	for duration: Variant in [0,3601,1.5,true,"120"]:
		var bad: Dictionary = base.duplicate(true)
		bad.presentation.duration_ticks = duration
		expect(not Contract.validate(bad).ok,"Invalid duration accepted")
	var bad: Dictionary = base.duplicate(true)
	bad.presentation.regions.resize(13)
	expect(not Contract.validate(bad).ok,"Region-label capacity exceeded silently")
	bad = base.duplicate(true)
	bad.presentation.regions.append(bad.presentation.regions[0].duplicate(true))
	expect(not Contract.validate(bad).ok,"Duplicate region ID accepted")
	bad = base.duplicate(true)
	bad.observations[2].region = [0,0,2,1]
	expect(not Contract.validate(bad).ok,"Multi-cell raw-state query accepted")
	bad = base.duplicate(true)
	bad.conditions.append({"observation":"dose-state","comparison":"eq","value":0,"outcome":"complete"})
	expect(not Contract.validate(bad).ok,"Structured state used as scalar condition")
	bad = base.duplicate(true)
	bad.schema_version = 1
	bad.erase("presentation")
	expect(not Contract.validate(bad).ok,"Schema 1 silently admitted new probe type")
	bad = CyberMicroScenarioContract.base("bad/fill")
	bad.events = [Pack.fill(0,10,10,1,1)]
	bad.events[0].normalized_mass = 0
	expect(not Contract.validate(bad).ok,"Native-rejected zero-mass scheduled fill was admitted")
	var comparison := Compare.new()
	var stored: bool = comparison.store("A",base)
	expect(stored,"A definition rejected")
	if not stored:
		quit(1)
		return
	var original: Dictionary = comparison.definition("A")
	expect(not comparison.store("A",bad),"Invalid A replaced good baseline")
	expect(comparison.definition("A") == original,"Rejected A store lost the original")
	expect(not comparison.store("C",base),"Unbounded comparison slot accepted")
	var copy: Dictionary = comparison.definition("A")
	copy.rectangles.clear()
	expect(not comparison.definition("A").rectangles.is_empty(),"Comparison exposed mutable retained definition")
	expect(comparison.store("B",Pack.interaction_fixture("salt-water",0,16)),"Candidate B rejected")
	expect(comparison.summary().slots.size() == 2,"A/B not bounded to two definitions")
	expect(not comparison.summary().matched_runtime_tick_seed,"Absent results claimed a matched comparison")
	print("MICROSCENARIO_REFERENCE_CONTRACT: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
