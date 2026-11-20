extends SceneTree

# Workbench construction and host-observation limits are distinct contracts.
# This is a pure GDScript regression and does not claim native gameplay PASS.
# Use the real source validator and canonical digest: a made-up checked result
# would exercise serialization without proving that omitted geometry was valid.
const Host = preload("res://scripts/microscenario_host.gd")
const Evidence = preload("res://scripts/liquid_host_evidence.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")

var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("WORKBENCH_HOST_CLAIMS: " + message)

func _definition(rectangle_count: int, workbench: bool = true) -> Dictionary:
	var source := Contract.base(Contract.WORKBENCH_ID if workbench else "host-claims/control")
	source.schema_version = 2
	var side: int = 2048 if workbench else Contract.SIDE
	if workbench: source["extent"] = [side,1024]
	source["presentation"] = {"title":"Host claim capacity","instructions":"Source validation fixture",
		"duration_ticks":1,"baseline":"workbench","profile":"host-claims","regions":[]}
	source.tools = ["paint","erase"]
	source.interest = {"policy":"fixed","region":[0,0,side,1024]}
	source.execution.cadence_lod_enabled = false
	var words: Array = []
	for i: int in range(rectangle_count):
		# Distinct, separated cells keep the exact rectangle count meaningful.
		words.append_array([(i % (side / 2)) * 2, int(i / (side / 2)) * 2, 1, 1, 58])
	source.rectangles = words
	return source

func _claim_values(claim: Dictionary, digest: String) -> Dictionary:
	var values: Dictionary = {"definition":claim.definition,"definition_hash":digest}
	if claim.has("projection"): values["definition_projection"] = claim.projection
	return values

func _serialize_claim(values: Dictionary) -> Dictionary:
	return Evidence._claims(values,0,[Evidence.MAX_CLAIM_VALUES,Evidence.MAX_CLAIM_TEXT_BYTES])

func _case(rectangle_count: int) -> void:
	var source: Dictionary = _definition(rectangle_count)
	var original: Dictionary = source.duplicate(true)
	var checked: Dictionary = Contract.validate(source)
	expect(checked.get("ok",false), "%d rectangles pass complete source validation: %s" %
		[rectangle_count,checked.get("error","")])
	if not checked.get("ok",false): return
	var canonical: String = JSON.stringify(checked.definition,"",true)
	var word_count: int = rectangle_count * 5
	expect(checked.definition.rectangles.size() == word_count and checked.canonical_json == canonical
		and checked.hash == canonical.sha256_text(),
		"%d complete validated definition supplies its real canonical identity" % rectangle_count)
	var result: Dictionary = Host.host_definition_claim(checked)
	var raw: Dictionary = _serialize_claim({"definition":checked.definition,"definition_hash":checked.hash})
	var projected: Dictionary = _serialize_claim(_claim_values(result,checked.hash))
	expect(projected.ok, "%d Workbench rectangles fit host claim after bounded representation" % rectangle_count)
	if word_count <= Host.HOST_CLAIM_MAX_CONTAINER_WORDS:
		expect(raw.ok and not result.has("projection") and result.definition == checked.definition
			and projected.value == raw.value,
			"%d rectangles retain identical full host claim" % rectangle_count)
	else:
		expect(not raw.ok and result.has("projection") and not result.definition.has("rectangles"),
			"%d rectangles exceed raw array envelope and use an explicit projection" % rectangle_count)
		var summary: Dictionary = result.projection
		expect(summary.rectangle_count == rectangle_count and summary.integer_word_count == word_count
			and summary.integer_word_count == summary.rectangle_count * 5
			and summary.validated_complete_definition_sha256 == checked.hash
			and summary.schema_version == 1 and summary.status == "unverified_host_claim_projection"
			and summary.omitted_field == "rectangles" and summary.format == "flat_xywhm_integer_words"
			and summary.reason == "per_container_host_claim_capacity",
			"%d projection discloses exact count, complete-source hash and limited scope" % rectangle_count)
		var without_geometry: Dictionary = checked.definition.duplicate(true)
		without_geometry.erase("rectangles")
		expect(result.definition == without_geometry,
			"%d projection removes only the redundant rectangle payload" % rectangle_count)
		expect(not Contract.validate(result.definition).ok,
			"%d reduced observation cannot masquerade as a native construction definition" % rectangle_count)
	expect(source == original and checked.definition.rectangles == original.rectangles
		and JSON.stringify(checked.definition,"",true) == canonical,
		"%d projection neither mutates nor truncates the original or validated native input" % rectangle_count)
	var restored: Dictionary = Contract.parse(checked.canonical_json)
	expect(restored.ok and restored.hash == checked.hash and restored.definition.rectangles == original.rectangles,
		"%d complete source round trip retains all geometry and identity" % rectangle_count)

func _refused(source: Dictionary, label: String) -> void:
	var checked: Dictionary = Contract.validate(source)
	expect(not checked.get("ok",false), label + " is refused by complete source validation")
	# The actual host must report the same refusal before looking for a native
	# World, preparing a token, or calling the observation projection helper.
	var host := Host.new()
	expect(not host.install(null,source) and host.last_error == checked.get("error","") and not host.active(),
		label + " cannot cross the host's pre-native validation boundary")

func _invalid_sources() -> void:
	_refused(_definition(Contract.WORKBENCH_MAX_RECORDS+1),"one rectangle beyond the Workbench source ceiling")
	var source: Dictionary = _definition(6554)
	var bad: Dictionary = source.duplicate(true)
	bad.rectangles.pop_back()
	_refused(bad,"incomplete final five-word record / mismatched word count")
	bad = source.duplicate(true)
	bad["rectangle_count"] = 6553
	_refused(bad,"forged rectangle count metadata")
	bad = source.duplicate(true)
	bad["definition_projection"] = {"rectangle_count":6553,"integer_word_count":6554*5}
	_refused(bad,"caller-supplied projection with mismatched counts")
	# Put malformed values in the omitted tail, beyond the old host envelope.
	# Admission must validate them before any omission can hide their contents.
	for mutation: Array in [[0,-1],[0,2048],[1,1024],[2,0],[2,2049],[3,-1],
			[4,Contract.MATERIAL_COUNT],[4,10],[0,1.5],[4,"58"],[4,RefCounted.new()]]:
		bad = source.duplicate(true)
		bad.rectangles[bad.rectangles.size()-5+int(mutation[0])] = mutation[1]
		_refused(bad,"malformed omitted-tail geometry word %s=%s" % [mutation[0],str(mutation[1])])
	for digest: Variant in ["0".repeat(63),"g".repeat(64),true]:
		bad = source.duplicate(true)
		bad.source_recipe_hash = digest
		_refused(bad,"invalid source recipe digest")
	bad = source.duplicate(true)
	bad["hash"] = "0".repeat(64)
	_refused(bad,"caller-supplied replacement for the validated complete-source digest")
	bad = source.duplicate(true)
	bad.extent = [2048,2112]
	_refused(bad,"World dimensions beyond the unchanged Workbench limit")
	bad = source.duplicate(true)
	bad.partial_water_fills = []
	for i: int in range(Contract.MAX_RECORDS+1):
		bad.partial_water_fills.append_array([0,0,1,1,255,0])
	_refused(bad,"partial Water fill count beyond the unchanged non-rectangle limit")

func _full_geometry_identity() -> void:
	var source: Dictionary = _definition(9167)
	var checked: Dictionary = Contract.validate(source)
	var initial: Dictionary = Host.host_definition_claim(checked)
	var changed: Dictionary = source.duplicate(true)
	changed.rectangles[-1] = 13
	var changed_checked: Dictionary = Contract.validate(changed)
	var changed_claim: Dictionary = Host.host_definition_claim(changed_checked)
	expect(changed_checked.ok and changed_checked.hash != checked.hash
		and changed_claim.definition == initial.definition
		and changed_claim.projection.rectangle_count == initial.projection.rectangle_count
		and changed_claim.projection.validated_complete_definition_sha256 != initial.projection.validated_complete_definition_sha256,
		"a material change in the omitted final rectangle changes complete-source identity at the same count")
	changed = source.duplicate(true)
	var first: Array = changed.rectangles.slice(0,5)
	for i: int in range(5):
		changed.rectangles[i] = changed.rectangles[changed.rectangles.size()-5+i]
		changed.rectangles[changed.rectangles.size()-5+i] = first[i]
	changed_checked = Contract.validate(changed)
	expect(changed_checked.ok and changed_checked.hash != checked.hash,
		"complete-source digest retains rectangle order as well as count and material identities")
	source.rectangles[-1] = 28
	expect(checked.definition.rectangles[-1] == 58
		and JSON.stringify(checked.definition,"",true).sha256_text() == checked.hash,
		"validated native input is detached from subsequent mutation of caller-owned geometry")

func _non_workbench_controls() -> void:
	var control: Dictionary = Contract.validate(_definition(Contract.MAX_RECORDS,false))
	expect(control.ok and not Host.host_definition_claim(control).has("projection"),
		"ordinary scenarios retain the full original claim at their independent 4096-rectangle ceiling")
	_refused(_definition(Contract.MAX_RECORDS+1,false),"ordinary scenario above its independent rectangle ceiling")
	var other: Dictionary = _definition(6554,false)
	_refused(other,"large non-Workbench source")
	# Deliberately bypass validation only to test the projection selector itself:
	# even a forged checked wrapper cannot obtain the Workbench-only exception.
	var untouched: Dictionary = Host.host_definition_claim({"definition":other,"hash":"b".repeat(64)})
	expect(not untouched.has("projection") and untouched.definition == other,
		"non-Workbench definitions are never projected")
	expect(not _serialize_claim({"definition":untouched.definition}).ok,
		"other scenarios retain strict per-container refusal")
	var checked: Dictionary = Contract.validate(_definition(6554))
	var claims: Dictionary = _claim_values(Host.host_definition_claim(checked),checked.hash)
	claims["object"] = RefCounted.new()
	expect(not _serialize_claim(claims).ok,"projection does not bypass unsupported host-claim object refusal")

func run() -> void:
	# Edge immediately below and above the 32,768 flat-word envelope.
	_case(6553)
	_case(6554)
	# Real problematic originals and the full accepted 32,768-rectangle ceiling.
	_case(9167)
	_case(13839)
	_case(32768)
	_invalid_sources()
	_full_geometry_identity()
	_non_workbench_controls()
	print("WORKBENCH_HOST_CLAIMS: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
