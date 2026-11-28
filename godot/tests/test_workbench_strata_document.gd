extends SceneTree

# Independent admission and persistence negatives. Native witnesses and original
# byte hashes, rather than validator return strings, establish nonmutation.
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Owner = preload("res://scripts/depth/workbench_layer_owner.gd")
const Setup = preload("res://scripts/workbench_setup.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("STRATA_DOCUMENT " + label)

func digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hashing.update(bytes)
	return hashing.finish().hex_encode()

func run() -> void:
	var scene := Document.default_document(Vector2i(512,512))
	scene.presentation.enabled = true
	for id: String in ["scripted","effects","background"]:
		Document.plane(scene,id).rectangles = [[32,32,12,12,58]]
	var owner := Owner.new()
	var admitted: Dictionary = owner.prepare(scene)
	check(admitted.get("ok",false) and owner.commit(admitted.get("token",-1)),"actual native owner starts")
	if not failures.is_empty(): quit(1); return
	var previous: Dictionary = owner.stats()
	var variants: Array = []
	var changed := scene.duplicate(true)
	changed.unknown = 42
	variants.append(changed)
	changed = scene.duplicate(true); changed.version = Document.VERSION + 1; variants.append(changed)
	changed = scene.duplicate(true); changed.format = 7; variants.append(changed)
	changed = scene.duplicate(true); changed.content_domain = 7; variants.append(changed)
	changed = scene.duplicate(true); changed.extent = [512]; variants.append(changed)
	changed = scene.duplicate(true); changed.extent = [512.5,512]; variants.append(changed)
	changed = scene.duplicate(true); changed.extent = [true,512]; variants.append(changed)
	changed = scene.duplicate(true); changed.presentation.parallax_strength = NAN; variants.append(changed)
	changed = scene.duplicate(true); changed.presentation.fog_strength = INF; variants.append(changed)
	changed = scene.duplicate(true); changed.presentation.active = "unregistered"; variants.append(changed)
	changed = scene.duplicate(true); changed.presentation.solo = "unregistered"; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[1].id = "effects"; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[1].id = 7; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[2].bounds = [0,0,512,513]; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[3].opacity = -0.1; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[0].depth = 0.1; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[1].clock.mode = "simulated"; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[1].clock.mode = 7; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[1].clock.paused = 1; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[1].rectangles = [[32,32,1,1,10]]; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[1].rectangles = [[-1,32,1,1,58]]; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[1].rectangles = [[500,500,13,13,58]]; variants.append(changed)
	changed = scene.duplicate(true); changed.planes[1].rectangles = [[32,32,1,1,58,true]]; variants.append(changed)
	changed = scene.duplicate(true); changed.content_domain = "exact-physical-continuation"; variants.append(changed)
	changed = scene.duplicate(true); changed.atmosphere.unknown = true; variants.append(changed)
	changed = scene.duplicate(true); changed.authoring.records = [null]; variants.append(changed)
	changed = scene.duplicate(true); changed.version = 1; variants.append(changed) # V1 cannot silently discard extensions.
	for index: int in variants.size():
		var refused: Dictionary = owner.prepare(variants[index],owner.generation())
		check(not refused.get("ok",false),"invalid candidate refused %d" % index)
		if refused.get("ok",false): owner.cancel(refused.token)
		var after: Dictionary = owner.stats()
		check(after.generation == previous.generation and after.pending_native_world_count == 0,
			"refusal retains generation and no candidate owners %d" % index)
		for id: String in ["scripted","effects","background"]:
			check(after.layers[id].native_instance_id == previous.layers[id].native_instance_id \
				and owner.material_at(id,Vector2i(35,35)) == 58,"refusal retains actual native owner/cells " + id)
	# Repeated cancellation/retirement must not retain extra owner generations.
	for index: int in 3:
		var candidate: Dictionary = owner.prepare(scene,owner.generation())
		check(candidate.get("ok",false),"replacement prepares %d" % index)
		owner.cancel(candidate.get("token",-1))
		check(not owner.commit(candidate.get("token",-1)) and owner.stats().pending_native_world_count == 0,
			"cancelled token cannot commit or retain Worlds")
	check(owner.material_at("scripted",Vector2i(35,35)) == 58,"cancellation retains actual native materials")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var setup := Setup.fresh(bridge.default_liquid_policy(),Vector2i(512,512))
	var label := "strata-independent-document"
	var path := Setup._path(label)
	check(Document.write_named(label,setup,{},{},owner.document()).is_empty(),"valid complete envelope saves")
	var original := FileAccess.get_file_as_bytes(path)
	var original_hash := digest(original)
	changed = owner.document(); changed.planes[1].revision = 0
	check(not Document.write_named(label,setup,{},{},changed).is_empty(),"invalid replacement save refuses")
	check(FileAccess.get_sha256(path) == original_hash,"refused save preserves previous exact bytes")
	var bad_bytes: Array[PackedByteArray] = []
	bad_bytes.append(original.slice(0,8))
	bad_bytes.append(original.slice(0,51))
	bad_bytes.append(original.slice(0,original.size()-1))
	var bytes := original.duplicate(); bytes.encode_u32(8,Document.VERSION + 1); bad_bytes.append(bytes)
	bytes = original.duplicate(); bytes.encode_u32(12,0xffffffff); bad_bytes.append(bytes)
	bytes = original.duplicate(); bytes.encode_u32(16,0xffffffff); bad_bytes.append(bytes)
	bytes = original.duplicate(); bytes[20] ^= 1; bad_bytes.append(bytes)
	bytes = original.duplicate(); bytes.append(0); bad_bytes.append(bytes)
	for index: int in bad_bytes.size():
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_buffer(bad_bytes[index]); file.close()
		check(Document.read_named(label).has("error"),"corrupt/truncated envelope refused %d" % index)
		check(owner.material_at("scripted",Vector2i(35,35)) == 58 and owner.generation() == previous.generation,
			"invalid load leaves native authority intact %d" % index)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(original); file.close()
	check(Document.read_named(label).get("layered",false),"original scene remains recoverable after all failures")
	# Explicit V1 construction and its original envelope shape remain exact.
	var legacy := scene.duplicate(true)
	legacy.version = 1
	legacy.erase("atmosphere")
	legacy.erase("authoring")
	check(Document.validate(legacy).is_empty(), "original V1 fields remain supported")
	check(Document.write_named(label, setup, {}, {}, legacy).is_empty(), "V1 authored envelope still writes")
	var legacy_bytes := FileAccess.get_file_as_bytes(path)
	check(legacy_bytes.decode_u32(8) == 1, "V1 writer retains V1 header")
	var reopened := Document.read_named(label)
	check(reopened.get("document", {}) == legacy, "V1 reopen preserves exact authored meaning")
	var upgraded := Document.upgraded(legacy)
	check(upgraded.version == 2 and upgraded.planes == legacy.planes and upgraded.presentation == legacy.presentation,
		"explicit V1 upgrade retains all native layout and presentation values")
	check(not upgraded.atmosphere.enabled and upgraded.atmosphere.effects.is_empty() and upgraded.authoring.records.is_empty(),
		"migration adds only empty disabled extension defaults")
	check(Document.write_named(label, setup, {}, {}, upgraded).is_empty(), "upgraded V2 saves through existing atomic replacement")
	check(Document.read_named(label).get("document", {}) == upgraded, "V2 extensions round trip exactly")
	# Full float64 precision matters for arithmetic-derived UI values, and JSON
	# number types in direction/colour arrays need one canonical representation.
	var precise := upgraded.duplicate(true)
	var computed := 0.123456789012345 * 3.0
	precise.presentation.fog_strength = computed
	Document.plane(precise,"scripted").opacity = computed
	var effect: Dictionary = Document.Atmosphere.make_effect("vent_steam","effects",Rect2i(16,16,48,48),42,"precision")
	effect.strength = computed
	effect.direction = [0.1,-1]
	effect.colour[1] = computed
	precise.atmosphere.effects = [effect]
	var sha := "f".repeat(64)
	precise.authoring.records = [{"version":1,"id":"precision-record","kind":"harvest","plane":"effects",
		"scene_id":"precision-scene","owner_id":"precision-owner","generation":1,"before_revision":1,"after_revision":1,
		"status":"completed","requested_cells":0,"applied_cells":0,"changed_cells":0,"requested_chunks":0,"completed_chunks":0,
		"source_sha256":sha,"proposal_sha256":sha,"geometry_sha256":sha,"before_sha256":sha,"projected_sha256":sha,"actual_sha256":sha,
		"published":true,"metadata":{"arithmetic_value":computed,"scope":"synthetic persistence fixture"},"error":"",
		"historical":true,"scope":"authored-material-operation-history"}]
	precise = Document.canonical(precise)
	check(Document.validate(precise).is_empty(),"arithmetic float and mixed-number direction fixture admitted")
	check(Document.write_named(label,setup,{},{},precise).is_empty(),"V2 saves full-precision atmosphere and provenance")
	var precise_reopened: Dictionary = Document.read_named(label).get("document",{})
	check(precise_reopened==precise,"V2 exact authored numeric values and array types survive save/reopen")
	check(PackedFloat64Array([precise_reopened.get("presentation",{}).get("fog_strength",0.0)]).to_byte_array()==PackedFloat64Array([computed]).to_byte_array(),
		"V2 arithmetic float64 bytes survive exact persistence without one-ULP drift")
	owner.retire()
	check(owner.stats().native_world_count == 0 and owner.stats().pending_native_world_count == 0,"all native owner references retire")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("STRATA_DOCUMENT ",JSON.stringify({"checks":checks,"failures":failures,"completed":true,
		"invalid_candidates":variants.size(),"corrupt_envelopes":bad_bytes.size(),"original_saved_sha256":original_hash}))
	quit(0 if failures.is_empty() else 1)
