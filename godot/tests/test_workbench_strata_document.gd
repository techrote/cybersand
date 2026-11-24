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
	changed = scene.duplicate(true); changed.version = 2; variants.append(changed)
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
	var bytes := original.duplicate(); bytes.encode_u32(8,2); bad_bytes.append(bytes)
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
	owner.retire()
	check(owner.stats().native_world_count == 0 and owner.stats().pending_native_world_count == 0,"all native owner references retire")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("STRATA_DOCUMENT ",JSON.stringify({"checks":checks,"failures":failures,"completed":true,
		"invalid_candidates":variants.size(),"corrupt_envelopes":bad_bytes.size(),"original_saved_sha256":original_hash}))
	quit(0 if failures.is_empty() else 1)
