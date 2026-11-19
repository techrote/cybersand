extends SceneTree

# Workbench construction and host-observation limits are distinct contracts.
# This is a pure GDScript regression and does not claim native gameplay PASS.
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

func _case(rectangle_count: int) -> void:
	var words: Array = []
	for i: int in range(rectangle_count):
		words.append_array([i % 2048, int(i / 2048), 1, 1, 58])
	var source: Dictionary = {"id":Contract.WORKBENCH_ID,"schema_version":2,
		"extent":[2048,1024],"rectangles":words}
	var checked: Dictionary = {"definition":source,"hash":"a".repeat(64)}
	var result: Dictionary = Host.host_definition_claim(checked)
	var raw: Dictionary = Evidence._claims({"definition":source},0,
		[Evidence.MAX_CLAIM_VALUES,Evidence.MAX_CLAIM_TEXT_BYTES])
	var projected_claims: Dictionary = {"definition":result.definition,
		"definition_hash":checked.hash}
	if result.has("projection"):
		projected_claims["definition_projection"] = result.projection
	var projected: Dictionary = Evidence._claims(projected_claims,0,
		[Evidence.MAX_CLAIM_VALUES,Evidence.MAX_CLAIM_TEXT_BYTES])
	expect(projected.ok, "%d Workbench rectangles fit host claim after bounded representation" % rectangle_count)
	if words.size() <= Host.HOST_CLAIM_MAX_CONTAINER_WORDS:
		expect(raw.ok and not result.has("projection") and result.definition.rectangles == words,
			"%d rectangles retain identical full host claim" % rectangle_count)
	else:
		expect(not raw.ok and result.has("projection") and not result.definition.has("rectangles"),
			"%d rectangles exceed raw array envelope and use an explicit projection" % rectangle_count)
		var summary: Dictionary = result.projection
		expect(summary.rectangle_count == rectangle_count
			and summary.integer_word_count == words.size()
			and summary.validated_complete_definition_sha256 == checked.hash
			and summary.status == "unverified_host_claim_projection",
			"%d projection discloses exact count, complete-source hash and limited scope" % rectangle_count)
		expect(source.rectangles == words and not source.has("definition_projection"),
			"%d source construction rectangles are unchanged" % rectangle_count)

func run() -> void:
	# Edge immediately below and above the 32,768 flat-word envelope.
	_case(6553)
	_case(6554)
	# Real problematic originals and the full accepted 32,768-rectangle ceiling.
	_case(9167)
	_case(13839)
	_case(32768)
	# Host observation must not silently weaken the independent MicroScenario contract.
	var other: Dictionary = {"id":"unrelated","rectangles":[]}
	for i: int in range(6554):
		other.rectangles.append_array([0,0,1,1,58])
	var untouched: Dictionary = Host.host_definition_claim(
		{"definition":other,"hash":"b".repeat(64)})
	expect(not untouched.has("projection") and untouched.definition.rectangles == other.rectangles,
		"non-Workbench definition is not projected")
	expect(not Evidence._claims({"definition":untouched.definition},0,
		[Evidence.MAX_CLAIM_VALUES,Evidence.MAX_CLAIM_TEXT_BYTES]).ok,
		"other scenarios retain strict per-container refusal")
	# Invalid value types still refuse; the projection is not a blanket bypass.
	expect(not Evidence._claims({"object":RefCounted.new()},0,
		[Evidence.MAX_CLAIM_VALUES,Evidence.MAX_CLAIM_TEXT_BYTES]).ok,
		"unsupported host-claim objects still refuse")
	print("WORKBENCH_HOST_CLAIMS: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
