extends SceneTree

# Diagnostic-only replay of authenticated native RG8 packets. The phase grid
# and both compositor arms are fixed before execution. A zero process exit
# means complete evidence capture, never a passing visibility qualification.
const DepthHost = preload("res://scripts/depth/depth_compositor.gd")
const IDS: Array[String] = ["play", "scripted", "effects", "background"]
const SOURCE: String = "93a5e85dc9d5459a5f9cce00839b64090a1a0573"
const VARIANTS: Dictionary = {
	"authored_q": {
		"counterfactual": false,
		"recipe_hash": "828f5174b41aa5fa3ed693dae9bb463f24c49d8ce18b506af7573152afd83caa",
		"effects_sha256": "fce342d9416c3f01b7be762fc402238a6933a830763cd599c64d3f2176875d29",
		"source_x": 235,
		"smoke_cells": [[235,929,240],[236,929,240],[234,930,240],[237,930,240],[234,931,240],[237,931,239]],
	},
	"d1_x238_counterfactual": {
		"counterfactual": true,
		"recipe_hash": "ec7d8a8988883446028a3b08cb4d2f9e00b59eec656409fd6b38a0dad06e4648",
		"effects_sha256": "135f4e1119c7f7f46ac0a88f80fd3af90d9a15af9a17766331b8d1a50589d51e",
		"source_x": 238,
		"smoke_cells": [[238,929,239],[239,929,240],[237,930,240],[240,930,240],[237,931,240],[240,931,240]],
	},
}
const BASE_PACKET_HASHES: Dictionary = {
	"play": "eb6aeb8255fd298d8408869dc687480a5d59f96d38d7cefe3eb69d3746c67e86",
	"scripted": "7d2b2ac02bd9f47f952c81113dba0f1470c4a278345b3e970c830a09b93c7953",
	"background": "0649a8edcde12cfebade2af77eab30c8ceb2b8d6a22eb799737f98008ec95c79",
}
var scene_variant: String = ""
var witness := Rect2i(230,925,12,13)
var packet_hashes: Dictionary = {}
const CHANNEL_DELTA: int = 4
const REQUIRED_PIXELS: int = 4
const ARMS: Array[String] = ["hybrid", "stack_no_relief"]
var packet_root: String = ""
var output: String = ""
var packets: Dictionary = {}
var smoke: Array[Vector2i] = []
var view: SubViewport
var compositor
var evidence: Dictionary = {"schema":"deepworks-causal-visibility-diagnostic-v2", "status":"incomplete", "source_commit":SOURCE, "phases":[], "arms":ARMS, "pixel_channel_threshold":CHANNEL_DELTA, "minimum_native_air_pixels_per_source":REQUIRED_PIXELS, "captures":[], "errors":[], "scope":"Actual rendering of immutable source-bound native tick46 packets; diagnostic observations including all negative phases, not owner acceptance"}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--packet-root="): packet_root = argument.trim_prefix("--packet-root=")
		if argument.begins_with("--capture-output="): output = argument.trim_prefix("--capture-output=")
		if argument.begins_with("--scene-variant="): scene_variant = argument.trim_prefix("--scene-variant=")
	if output.is_empty() or packet_root.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Actual display, packet root and capture output are required")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	var started: int = Time.get_ticks_msec()
	if not VARIANTS.has(scene_variant):
		_abort("Exactly one registered --scene-variant is required")
		return
	evidence["scene_variant"] = scene_variant
	evidence["counterfactual"] = VARIANTS[scene_variant]["counterfactual"]
	evidence["recipe_hash"] = VARIANTS[scene_variant]["recipe_hash"]
	packet_hashes = BASE_PACKET_HASHES.duplicate()
	packet_hashes["effects"] = VARIANTS[scene_variant]["effects_sha256"]
	evidence["packet_sha256"] = packet_hashes
	witness.position.x = int(VARIANTS[scene_variant]["source_x"])-5
	evidence["witness_rect"] = [witness.position.x,witness.position.y,witness.size.x,witness.size.y]
	var receipt_path: String = packet_root.path_join("native-packet-diagnostic.json")
	var native_receipt = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	if not native_receipt is Dictionary or native_receipt.get("scene_variant","")!=scene_variant or native_receipt.get("recipe_hash","")!=evidence["recipe_hash"] or native_receipt.get("packet_sha256",{})!=packet_hashes or not native_receipt.get("errors",["missing"]).is_empty() or not bool(native_receipt.get("incremental_equals_full_at_46",false)):
		_abort("Native variant receipt authentication failed")
		return
	evidence["native_receipt_sha256"] = FileAccess.get_sha256(receipt_path)
	evidence["probe_sha256"] = FileAccess.get_sha256(get_script().resource_path)
	evidence["godot"] = Engine.get_version_info()
	evidence["display"] = DisplayServer.get_name()
	evidence["renderer"] = RenderingServer.get_video_adapter_name()
	evidence["packet_replay"] = "Exact authenticated RG8 bytes from the selected declared recipe variant with a full-refresh envelope for production material surfaces; the counterfactual variant is not production Q. Native Worlds are not stepped or replaced during the sweep."
	evidence["phase_control"] = {"swept_material_surface":"effects", "fixed_material_surface_phase_seconds":{"play":0.0,"scripted":0.0,"background":0.0}, "depth_compositor_presentation_time":0.0, "original_ci_phases":"Unknown and potentially staggered between surface bakes. This controlled single-variable experiment cannot reconstruct the unavailable original RGB frame."}
	for phase: int in range(61): evidence["phases"].append(float(phase))
	for id: String in IDS:
		var path: String = packet_root.path_join(id + "-tick46.rg8")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.size() != 1024*1024*2 or FileAccess.get_sha256(path) != packet_hashes[id]:
			_abort("Source packet bytes differ: " + id)
			return
		packets[id] = bytes
	for y: int in range(witness.position.y, witness.end.y):
		for x: int in range(witness.position.x, witness.end.x):
			if packets["effects"][(y*1024+x)*2] == 4:
				smoke.append(Vector2i(x,y))
	if smoke.size() != 6:
		_abort("Expected exactly six native Smoke cells in the fixed witness")
		return
	var actual_cells: Array = []
	for p: Vector2i in smoke:
		actual_cells.append([p.x,p.y,packets["effects"][(p.y*1024+p.x)*2+1]])
	if actual_cells != VARIANTS[scene_variant]["smoke_cells"]:
		_abort("Native Smoke coordinates/lifetimes differ from declared variant")
		return
	evidence["native_smoke"] = []
	for p: Vector2i in smoke:
		evidence["native_smoke"].append({"position":[p.x,p.y], "material":4, "lifetime_state_a":packets["effects"][(p.y*1024+p.x)*2+1]})
	view = SubViewport.new()
	view.name = "DeepworksCausalPacketReplay"
	view.size = Vector2i(1024,1024)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	compositor = DepthHost.new()
	compositor.layer_scale = Vector4.ONE
	compositor.layer_parallax = Vector4(1.0,0.98,0.965,0.94)
	if not compositor.configure(Vector2i(1024,1024)):
		_abort("Production compositor configure failed")
		return
	view.add_child(compositor)
	compositor.position = Vector2.ZERO
	compositor.size = Vector2(1024,1024)
	compositor.set_view(Vector2.ZERO,Vector2(1024,1024))
	compositor.set_time(0.0)
	compositor.set_options({"mode":"hybrid", "parallax_strength":0.8, "relief_depth":5.0, "relief_slices":4, "relief_quantization":1.0, "fog_strength":0.46, "reflection_strength":0.12, "occluder_strength":0.30, "cutaway":true, "cutaway_radius":100.0, "layer_visibility":Vector4.ONE, "freeze_material_animation":true})
	for surface in compositor._surfaces:
		surface._material.set_shader_parameter("presentation_time_override",0.0)
	for id: String in IDS:
		var packet: Dictionary = {"layer_id":id, "reset_generation":1, "layer_tick":46 if id=="effects" else 0, "serial":1, "channels":2, "full_refresh":true, "rectangles":PackedInt32Array([0,0,1024,1024,0,2048]), "cells":packets[id]}
		if not compositor.apply_layer_packet(id,packet):
			_abort("Production surface rejected replay packet: "+id)
			return
	evidence["production_compositor_options"] = {"mode":"hybrid or stack only", "parallax_strength":0.8, "relief_depth":5.0, "relief_slices":4, "relief_quantization":1.0, "fog_strength":0.46, "reflection_strength":0.12, "camera_origin":[0,0], "view_size":[1024,1024], "world_size":[1024,1024], "layer_scale":[1,1,1,1]}
	for phase: int in range(61):
		compositor._surfaces[2]._material.set_shader_parameter("presentation_time_override",float(phase))
		compositor._surfaces[2].render_target_update_mode = SubViewport.UPDATE_ONCE
		await _settle()
		var effects_image: Image = _pixels(compositor._surfaces[2])
		for arm: String in ARMS:
			compositor.set_options({"mode":"hybrid" if arm=="hybrid" else "stack", "layer_visibility":Vector4.ONE})
			await _settle()
			var air_on: Image = _pixels(view)
			compositor.set_options({"layer_visibility":Vector4(1,1,0,1)})
			await _settle()
			var air_off: Image = _pixels(view)
			var prefix: String = "phase-%02d-%s" % [phase,arm]
			var on_name: String = prefix+"-air-on.png"
			var off_name: String = prefix+"-air-off.png"
			if air_on.save_png(output.path_join(on_name)) != OK or air_off.save_png(output.path_join(off_name)) != OK:
				_abort("Could not retain original PNG pair: "+prefix)
				return
			var cells: Array[Dictionary] = []
			var changed: int = 0
			for p: Vector2i in smoke:
				var on: Array[int] = _rgba(air_on,p)
				var off: Array[int] = _rgba(air_off,p)
				var delta: int = maxi(absi(on[0]-off[0]),maxi(absi(on[1]-off[1]),absi(on[2]-off[2])))
				if delta >= CHANNEL_DELTA: changed += 1
				cells.append({"position":[p.x,p.y], "air_on_rgba8":on, "air_off_rgba8":off, "effects_surface_rgba8":_rgba(effects_image,p), "maximum_rgb_channel_delta":delta, "passes_original_channel_threshold":delta>=CHANNEL_DELTA})
			var record: Dictionary = {"scene_variant":scene_variant,"counterfactual":evidence["counterfactual"],"phase_seconds":float(phase), "arm":arm, "native_mask_cells":smoke.size(), "visible_native_air_pixels":changed, "meets_original_minimum":changed>=REQUIRED_PIXELS, "cells":cells, "air_on":on_name, "air_off":off_name, "air_on_sha256":FileAccess.get_sha256(output.path_join(on_name)), "air_off_sha256":FileAccess.get_sha256(output.path_join(off_name))}
			evidence["captures"].append(record)
			if not _write():
				quit(2)
				return
			print("DEEPWORKS_PHASE_RECORD ",JSON.stringify({"scene_variant":scene_variant,"counterfactual":evidence["counterfactual"],"phase_seconds":float(phase),"arm":arm,"visible_native_air_pixels":changed,"meets_original_minimum":changed>=REQUIRED_PIXELS}))
	for index: int in range(IDS.size()):
		if compositor._surfaces[index].cell_image.get_data() != packets[IDS[index]]:
			_abort("Native packet bytes changed during time-only sweep")
			return
	evidence["packet_bytes_unchanged"] = true
	evidence["elapsed_ms"] = Time.get_ticks_msec()-started
	evidence["status"] = "diagnostic_complete"
	evidence["visibility_failures_by_arm"] = {"hybrid":0,"stack_no_relief":0}
	for record: Dictionary in evidence["captures"]:
		if not record["meets_original_minimum"]: evidence["visibility_failures_by_arm"][record["arm"]] += 1
	if not _write():
		quit(2)
		return
	print("DEEPWORKS_CAUSAL_RENDER_DIAGNOSTIC ",JSON.stringify({"scene_variant":scene_variant,"counterfactual":evidence["counterfactual"],"recipe_hash":evidence["recipe_hash"],"status":evidence["status"],"phases":61,"arms":2,"captured_pairs":evidence["captures"].size(),"visibility_failures_by_arm":evidence["visibility_failures_by_arm"],"packet_bytes_unchanged":true}))
	compositor.queue_free()
	await process_frame
	view.queue_free()
	await process_frame
	quit(0)

func _rgba(image: Image,p: Vector2i) -> Array[int]:
	var c: Color = image.get_pixelv(p)
	return [roundi(c.r*255.0),roundi(c.g*255.0),roundi(c.b*255.0),roundi(c.a*255.0)]

func _pixels(viewport: SubViewport) -> Image:
	var image: Image = viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image

func _settle() -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw

func _abort(message: String) -> void:
	evidence["errors"].append(message)
	_write()
	push_error(message)
	quit(2)

func _write() -> bool:
	var file := FileAccess.open(output.path_join("renderer-time-diagnostic.json"),FileAccess.WRITE)
	if file == null:
		push_error("Could not open causal renderer evidence output")
		return false
	file.store_string(JSON.stringify(evidence,"  ")+"\n")
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		push_error("Could not flush complete causal renderer evidence")
		return false
	return true
