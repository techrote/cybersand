class_name CyberEngineLabReferenceFixture
extends RefCounted

# ENG-LAB Test It: replay the exact source-verified owner-supplied 2048-square
# generated starting map. Never substitutes the authored edits for generator
# cells; the production native preparer still validates all ownership/receipts.
const Store = preload("res://scripts/workbench_generated_map.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const PATH := "res://tests/fixtures/engine_lab/setup-gate-canvas.json"
const FILE_SHA256 := "b001849d0823b9a1c3fdff7a650d455945eb1ebb885004e9836ee7525ce1b954"
const OUTPUT_SHA256 := "71610b37531531e284f069cf1e07c151283a441c9b0ff32a4fcc1dbb6c997a7a"
const MAX_CHUNKS := 1024

var last_error: String = ""


func _refuse(why: String) -> Dictionary:
	last_error = why
	return {"ok":false,"error":why}


func materialize(tree: SceneTree) -> Dictionary:
	# This is a fixture authority assertion, not a second mutable World.
	if not FileAccess.file_exists(PATH) or FileAccess.get_sha256(PATH) != FILE_SHA256:
		return _refuse("owner reference JSON missing or exact original file SHA differs")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not raw is Dictionary or raw.size() != 4 or raw.get("format","") != Store.FORMAT 		or int(raw.get("version",-1)) != 1:
		return _refuse("reference generated-start manifest has wrong schema")
	if not raw.get("starting_setup") is Dictionary or not raw.get("generation") is Dictionary:
		return _refuse("reference missing native generation/start metadata")
	var setup: Dictionary = raw.starting_setup.duplicate(true)
	var meta: Dictionary = raw.generation.duplicate(true)
	var error: String = Setup.validate(setup)
	if not error.is_empty(): return _refuse("starting setup refused: " + error)
	error = Store.edit_work_error(setup)
	if not error.is_empty(): return _refuse("reference authored edit budget: " + error)
	error = Store.valid_provenance(meta,Setup.extent_of(setup))
	if not error.is_empty(): return _refuse("reference generation provenance: " + error)
	if meta.sha256 != OUTPUT_SHA256 or Setup.extent_of(setup) != Vector2i(2048,2048):
		return _refuse("wrong material digest or canvas extent")
	if setup.actors.size() != 1 or str(setup.actors[0].model) != "needle" 		or int(setup.actors[0].id) != 1 or setup.actors[0].spawn != [200.0,200.0]:
		return _refuse("reference actor differs from owner Needle spawn")
	# Mirror the admitted saved-generated-start loader's numeric type
	# canonicalization before submitting to the real native preparer.
	for key: String in ["version","next_id","selected","rule_radius","material","brush"]:
		setup[key] = int(setup[key])
	for key: String in ["extent","source","liquid_policy"]:
		setup[key] = Array(PackedInt32Array(setup[key]))
	for i: int in setup.edits.size():
		setup.edits[i] = Array(PackedInt32Array(setup.edits[i]))
	for actor: Dictionary in setup.actors:
		actor.id = int(actor.id)
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		return _refuse("pinned source-matched native generator unavailable")
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	if generator == null: return _refuse("could not instantiate native generator")
	var cfg: Dictionary = generator.configure(meta.recipe)
	if not cfg.get("ok",false) or str(cfg.get("fingerprint","")) != str(meta.generator_fingerprint) 		or int(cfg.get("revision",-1)) != int(meta.generator_revision):
		return _refuse("generator configure refused source fingerprint/revision")
	var size: Vector2i = Setup.extent_of(setup)
	var origin := Vector2i(int(meta.origin[0]),int(meta.origin[1]))
	var region := Rect2i(origin,size)
	var cells := PackedByteArray()
	if cells.resize(size.x*size.y) != OK: return _refuse("2048-square cells allocation refused")
	var receipts: Array[String] = []
	var start_usec: int = Time.get_ticks_usec()
	var step: int = int(meta.recipe.get("chunk_size",0))
	if step < 1 or step > 256: return _refuse("invalid saved source chunk dimensions")
	# The owner-provided file is the original 256-chunk generated-start; a
	# different native semantic-plane algorithm is a provenance mismatch.
	if cfg.has("plane_fingerprint") or str(meta.plane_revision) != "":
		return _refuse("fixture requires original chunk-based generation (not plane substitution)")
	var min_chunk := Vector2i(floori(float(origin.x)/step),floori(float(origin.y)/step))
	var max_chunk := Vector2i(floori(float(region.end.x-1)/step),floori(float(region.end.y-1)/step))
	var chunks: int = (max_chunk.x-min_chunk.x+1)*(max_chunk.y-min_chunk.y+1)
	if chunks < 1 or chunks > MAX_CHUNKS or chunks != meta.receipt_hashes.size():
		return _refuse("source native chunk count differs from the 256 saved receipts")
	for cy: int in range(min_chunk.y,max_chunk.y+1):
		for cx: int in range(min_chunk.x,max_chunk.x+1):
			var coord := Vector2i(cx,cy)
			var p: Dictionary = generator.generate_chunk(coord)
			var index: int = receipts.size()
			if not p.get("ok",false) or p.get("state","") != "ready" 				or int(p.get("chunk_x",999999)) != cx or int(p.get("chunk_y",999999)) != cy 				or int(p.get("chunk_size",-1)) != step 				or str(p.get("fingerprint","")) != str(cfg.fingerprint) 				or int(p.get("revision",-1)) != int(cfg.revision) 				or not p.get("cells") is PackedByteArray or p.cells.size() != step*step 				or str(p.get("receipt_hash","")) != str(meta.receipt_hashes[index]):
				return _refuse("native chunk/receipt mismatch at %s index %d" % [str(coord),index])
			var src: PackedByteArray = p.cells
			for ly: int in step:
				var y: int = cy*step+ly
				if y < origin.y or y >= region.end.y: continue
				for lx: int in step:
					var x: int = cx*step+lx
					if x < origin.x or x >= region.end.x: continue
					cells[(y-origin.y)*size.x+(x-origin.x)] = src[ly*step+lx]
			receipts.append(str(p.receipt_hash))
			# Yield on every chunk to preserve GUI and cancellation opportunity.
			await tree.process_frame
	var digest: String = Store.digest(cells)
	if digest != OUTPUT_SHA256: return _refuse("generated native material digest differs: " + digest)
	var packet: Dictionary = {
		"recipe":meta.recipe.duplicate(true),"origin":origin,"extent":size,
		"cells":cells,"sha256":digest,"recipe_sha256":meta.recipe_sha256,
		"generator_fingerprint":meta.generator_fingerprint,
		"plane_revision":meta.plane_revision,
		"generator_revision":int(meta.generator_revision),
		"receipt_hashes":receipts.duplicate()
	}
	error = Store.valid_provenance(Store.provenance(packet),size)
	if not error.is_empty(): return _refuse("reconstructed exact generated packet refused: "+error)
	# Normal generation tools already verify this SHA and every saved receipt.
	return {"ok":true,"setup":setup,"packet":packet,"fixture_json_sha256":FILE_SHA256,
		"material_sha256":digest,"generation_receipt_count":receipts.size(),
		"material_bytes":cells.size(),"generation_seconds":float(Time.get_ticks_usec()-start_usec)/1000000.0}
