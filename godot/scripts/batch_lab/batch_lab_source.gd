extends RefCounted

# Read-only reuse of the ordinary worker's material-baseline capture boundary.
# This never adopts a baseline, clears history, or writes to the source World.
const Setup = preload("res://scripts/workbench_setup.gd")
const Baseline = preload("res://scripts/workbench_material_baseline.gd")
const MAX_FOOTPRINT := 512

static func capture(wb: Control, region: Rect2i) -> Dictionary:
	if not is_instance_valid(wb) or not wb.is_inside_tree() or wb.host == null or wb.applied.is_empty():
		return {"ok":false,"reason":"Open an installed Workbench before capturing a source region."}
	var extent: Vector2i = Setup.extent_of(wb.applied)
	if region.size.x < 1 or region.size.y < 1 or region.size.x > MAX_FOOTPRINT or region.size.y > MAX_FOOTPRINT \
			or not Rect2i(Vector2i.ZERO,extent).encloses(region):
		return {"ok":false,"reason":"The source region must fit the Workbench and be at most 512 × 512 cells."}
	if wb.busy() or (wb.paint_editor != null and (wb.paint_editor.dragging or wb.paint_editor.recovery_required())):
		return {"ok":false,"reason":"Finish the current Workbench transaction or paint gesture before capturing."}
	if is_instance_valid(wb.art_batches):
		var executor: RefCounted = wb.art_batches.executor
		if executor.active or executor.waiting or not executor.manual.is_empty() or not executor.manual_inflight.is_empty():
			return {"ok":false,"reason":"Wait for the current Art batch and native receipts before capturing."}
	var worker: CyberSimulationWorker = wb.host.simulation_worker
	var state: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.material_capture_request(int(state.get("generation",-1)))
	if not admitted.get("ok",false): return {"ok":false,"reason":str(admitted.get("reason","Native source capture refused."))}
	var token := int(admitted.token)
	var deadline := Time.get_ticks_msec()+16000
	var tree: SceneTree = wb.get_tree()
	var captured: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		if not is_instance_valid(wb) or not wb.is_inside_tree():
			worker.material_capture_cancel(token)
			return {"ok":false,"reason":"Workbench closed during source capture."}
		captured = worker.material_capture_poll(token)
		if not captured.is_empty(): break
		await tree.process_frame
	if captured.is_empty() or not captured.get("ok",false):
		worker.material_capture_cancel(token)
		return {"ok":false,"reason":str(captured.get("error","Native source capture timed out."))}
	if int(captured.get("request_token",-1)) != token or int(captured.get("generation",-1)) != int(state.get("generation",-2)):
		worker.material_capture_cancel(token)
		return {"ok":false,"reason":"The source World changed during capture; retry."}
	var staged: Dictionary = Baseline.stage(captured,extent)
	# commit=false is essential: this is observation, not Flatten/history adoption.
	var retired: Dictionary = worker.material_capture_finish(token,false)
	if staged.has("error") or not retired.get("ok",false):
		return {"ok":false,"reason":str(staged.get("error",retired.get("reason","Source capture could not be retired.")))}
	var plane: PackedByteArray = staged.baseline.cells
	var crop := PackedByteArray()
	if crop.resize(region.size.x*region.size.y*2) != OK:
		return {"ok":false,"reason":"Insufficient memory for the source region."}
	for y: int in region.size.y:
		var offset := ((region.position.y+y)*extent.x+region.position.x)*2
		for x: int in region.size.x*2:
			crop[y*region.size.x*2+x] = plane[offset+x]
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(crop)
	return {"ok":true,"config":{
		"source_cells":crop,"source_extent":[region.size.x,region.size.y],
		"source_region":[0,0,region.size.x,region.size.y],"source_rectangles":[],
		"source_provenance":{"kind":"native-material-occupancy-crop-v1","encoding":"uint16-le-row-major",
			"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
			"source_world_generation":captured.generation,"capture_token":token,
			"original_extent":[extent.x,extent.y],
			"original_region":[region.position.x,region.position.y,region.size.x,region.size.y],
			"whole_plane_sha256":staged.baseline.sha256,"crop_sha256":hash.finish().hex_encode(),
			"native_boundary_usec":captured.get("native_boundary_usec",0),
			"scope":"Stored material identities only; actor masks, cell conditions and evolved physical state are not copied."}}}
