extends SceneTree
## Geometry/admission control only. Native/rendered qualification is separate.
const Geometry = preload("res://scripts/workbench_agent_footprint.gd")
const Envelope = preload("res://scripts/workbench_authoring_envelope.gd")
const Signed = preload("res://scripts/workbench_agent_signed_frame.gd")
var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	_run.call_deferred()

func _compile(ops: Array, limit: int, protection: Array = []) -> Dictionary:
	return Geometry.compile(ops,Vector2i(2048,2048),Rect2i(0,0,2048,2048),protection,[0,58],[0,2,58],limit)

func _run() -> void:
	var rectangle := [{"shape":"rectangle","x0":200,"y0":200,"x1":327,"y1":327,"material":58}]
	check(_compile(rectangle,4096).get("status") == "refused","legacy4096 grant expanded")
	var larger: Dictionary = _compile(rectangle,16384)
	check(larger.get("status") == "validated_geometry" and larger.get("distinct_cells") == 16384,"16384-cell grant did not enable the actual footprint")
	check(_compile(rectangle,16383).get("status") == "refused","selected limit not exact")
	check(_compile(rectangle,16384,[Rect2i(327,327,1,1)]).get("reason") == "protected_region","larger grant bypassed protection")
	var maximum := [{"shape":"rectangle","x0":400,"y0":400,"x1":655,"y1":655,"material":58}]
	check(_compile(maximum,65536).get("distinct_cells") == 65536,"maximum selected footprint rejected")
	maximum[0].x1 = 656
	check(_compile(maximum,65536).get("status") == "refused","larger than maximum footprint admitted")
	var disc := [{"shape":"disc","x":800,"y":800,"radius":72,"material":58}]
	check(_compile(disc,16384).get("distinct_cells",0) > 4096,"expanded disc remains tied to old radius36")
	disc[0].radius = 144
	check(_compile(disc,65536).get("status") == "validated_geometry","maximum allowed disc rejected")
	disc[0].radius = 145
	check(_compile(disc,65536).get("status") == "refused","oversized disc admitted")
	for invalid: int in [0,-1,65537]:
		check(_compile(rectangle,invalid).get("status") == "refused","invalid grant admitted")
	var auth := {"schema_version":1,"action":"authorize_task","task_id":"capacity-control","scope":Rect2i(0,0,2048,2048),"protected":[],"allowed_materials":[0,58],"cell_limit":16384}
	check(Envelope.valid(auth),"bounded cell-limit authorization envelope refused")
	for invalid: Variant in [0,65537,16384.0,"16384"]:
		auth.cell_limit = invalid
		check(not Envelope.valid(auth),"invalid envelope cell limit admitted")
	check(not Envelope.valid({"schema_version":1,"action":"observe","cell_limit":65536}),"model-side observe may enlarge grant")
	check(Signed.operations([{"shape":"disc","x":300,"y":300,"radius":72,"material":58}],16384).get("status") == "mapped","expanded signed spatial adapter rejects valid disc")
	print("WB_AGENT_CELL_LIMIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
