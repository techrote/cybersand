extends SceneTree
## Unattended, display-backed world-art capture (MAP-AUTO-01 / #498).
##
## Driven only by a request JSON written by tools/world_art_preview_launcher.py
## --capture; no interactive scene, mouse, keyboard or UI control is used. Pixels
## are genuine Godot framebuffer readbacks through the production RG8 palette,
## emission and glow shaders (world_art_render_rig.gd), never SVG, Python
## rasterisation or an approximation. Every job writes PNGs plus manifest.json
## into the caller-supplied output directory; source packs are only read.
##
## Exit codes: 0 all jobs complete, 1 at least one job failed, 2 bad request,
## 77 no graphical display (headless display server).
const Adapter = preload("res://tools/world_design_pack_adapter.gd")
const RenderRig = preload("res://tools/world_art_render_rig.gd")
const FullExport = preload("res://tools/world_art_full_export.gd")
const REQUEST_SCHEMA: String = "cybersand.world_art_capture.request/1"
const JOB_SCHEMA: String = "cybersand.world_art_capture.job-manifest/1"
const MAX_SIDE: int = 16384
const MAX_PIXELS: int = 50000000
const ZOOM_MIN: float = 0.03
const ZOOM_MAX: float = 32.0
const SETTLE_FRAMES: int = 4
const SAMPLE_GRID: int = 256
const EDGE_NATIVE_CELLS: int = 8
const SYNTHETIC_NOTICE: String = (
	"Material condition bytes are SYNTHETIC native creation-state fixtures. "
	+ "The image is a presentation of authored geometry, not a physics, pressure, "
	+ "Water, reaction, Rapier, traversal, worldgen or gameplay simulation result.")
const LIMITATIONS: Array[String] = [
	"Synthetic material conditions; no native simulation state is run or measured.",
	"Pixels differ legitimately between operating systems, drivers and GPUs; compare "
		+ "source identity, geometry, completeness and renderer-specific invariants across platforms.",
	"The provisional pack format is a presentation input, not a production import/save contract.",
	"Presentation-only layering; this is not a four-native-plane (#501) render.",
]

var _request: Dictionary = {}
var _output_dir: String = ""
var _background_bytes: Vector3i = Vector3i(
	roundi(RenderRig.BACKGROUND.r * 255.0), roundi(RenderRig.BACKGROUND.g * 255.0),
	roundi(RenderRig.BACKGROUND.b * 255.0))


func _init() -> void:
	call_deferred("_run")


func _fatal(code: int, message: String) -> void:
	printerr("WORLD_ART_CAPTURE_ERROR " + message)
	quit(code)


func _frames() -> void:
	for i: int in range(SETTLE_FRAMES):
		await RenderingServer.frame_post_draw


func _write_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	var success: bool = file.get_error() == OK
	file.close()
	return success


func _sha256_bytes(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _run() -> void:
	var request_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--request="):
			request_path = arg.trim_prefix("--request=")
	if request_path.is_empty() or not FileAccess.file_exists(request_path):
		_fatal(2, "--request=/absolute/request.json is required and must exist")
		return
	if DisplayServer.get_name() == "headless":
		_fatal(77, "A graphical display is required; Godot is using the headless display server. "
			+ "On Linux run under X11/Xvfb (xvfb-run) with OpenGL/llvmpipe; on Windows use a desktop session.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(request_path))
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("schema", "") != REQUEST_SCHEMA:
		_fatal(2, "request is not a %s document" % REQUEST_SCHEMA)
		return
	_request = parsed
	_output_dir = String(_request.get("output_dir", ""))
	if _output_dir.is_empty() or not _output_dir.is_absolute_path():
		_fatal(2, "request output_dir must be an absolute path")
		return
	if DirAccess.make_dir_recursive_absolute(_output_dir) != OK:
		_fatal(2, "cannot create output directory " + _output_dir)
		return
	var viewer_error: String = _verify_viewer_files()
	if not viewer_error.is_empty():
		_fatal(2, viewer_error)
		return
	var results: Array[Dictionary] = []
	var failures: int = 0
	for job: Variant in _request.get("jobs", []):
		var result: Dictionary = await _run_job(job)
		results.append(result)
		if result.status != "complete":
			failures += 1
			printerr("WORLD_ART_CAPTURE_ERROR job %s failed: %s" % [result.id, result.error])
	var identity: Dictionary = _display_identity()
	var summary := {"status": "complete" if failures == 0 and not results.is_empty() else "failed",
		"jobs_total": results.size(), "jobs_failed": failures, "display": identity,
		"jobs": results}
	if not _write_json(_output_dir.path_join("godot-run.json"), summary):
		_fatal(1, "cannot write godot-run.json")
		return
	print("WORLD_ART_CAPTURE " + JSON.stringify({"status": summary.status,
		"jobs_total": results.size(), "jobs_failed": failures}))
	quit(0 if failures == 0 and not results.is_empty() else 1)


func _display_identity() -> Dictionary:
	return {
		"godot": Engine.get_version_info().string,
		"os": OS.get_name(),
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"graphics_adapter": RenderingServer.get_video_adapter_name(),
		"graphics_vendor": RenderingServer.get_video_adapter_vendor(),
	}


## The launcher copies the production shaders and tool scripts into a temporary
## project; verify the bytes Godot loads equal the hashes recorded from the checkout.
func _verify_viewer_files() -> String:
	var expected: Dictionary = _request.get("viewer", {}).get("files", {})
	if expected.is_empty():
		return "request.viewer.files is missing; viewer identity cannot be proven"
	for name: String in expected:
		var actual: String = FileAccess.get_sha256("res://" + name)
		if actual != String(expected[name]):
			return "temporary project file %s differs from the checked-out source" % name
	return ""


func _is_inside(child: String, parent: String) -> bool:
	var a: String = child.simplify_path().replace("\\", "/").trim_suffix("/")
	var b: String = parent.simplify_path().replace("\\", "/").trim_suffix("/")
	if OS.get_name() == "Windows":
		a = a.to_lower()
		b = b.to_lower()
	return a == b or a.begins_with(b + "/")


func _safe_name(raw: String) -> String:
	var out: String = ""
	for i: int in range(raw.length()):
		var c: String = raw[i]
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c in ["-", "_", "."]:
			out += c
		else:
			out += "_"
	if out != raw or out.is_empty() or out.begins_with("."):
		out = "x" + out.trim_prefix(".") + "-" + raw.sha256_text().substr(0, 8)
	return out


# ---------------------------------------------------------------- job handling

func _fail_job(job: Dictionary, manifest: Dictionary, message: String) -> Dictionary:
	manifest["status"] = "failed"
	manifest["error"] = message
	var job_dir: String = _output_dir.path_join(String(job.get("id", "job")))
	_write_json(job_dir.path_join("manifest.json"), manifest)
	return {"id": String(job.get("id", "")), "status": "failed", "error": message,
		"manifest": String(job.get("id", "")) + "/manifest.json"}


func _manifest_skeleton(job: Dictionary) -> Dictionary:
	return {
		"schema": JOB_SCHEMA,
		"status": "incomplete",
		"error": "",
		"job": {"id": job.get("id", ""), "collection": job.get("collection", ""),
			"pack_path": job.get("pack_path", ""), "pack_sha256_expected": job.get("pack_sha256", "")},
		"art_source": _request.get("art_source", {}),
		"viewer": _request.get("viewer", {}),
		"presentation": _request.get("presentation", {}),
		"synthetic_condition_notice": SYNTHETIC_NOTICE,
		"limitations": LIMITATIONS,
		"shots": [],
	}


func _run_job(job: Dictionary) -> Dictionary:
	var job_id: String = String(job.get("id", ""))
	var job_dir: String = _output_dir.path_join(job_id)
	var manifest: Dictionary = _manifest_skeleton(job)
	if job_id.is_empty() or DirAccess.make_dir_recursive_absolute(job_dir) != OK:
		return {"id": job_id, "status": "failed", "error": "cannot create job directory", "manifest": ""}
	_write_json(job_dir.path_join("manifest.json"), manifest)
	var pack_path: String = String(job.get("pack_path", ""))
	if _is_inside(_output_dir, pack_path.get_base_dir()):
		return _fail_job(job, manifest, "output directory is inside the source pack directory; refusing")
	if not FileAccess.file_exists(pack_path):
		return _fail_job(job, manifest, "missing pack: " + pack_path)
	var pack_bytes: PackedByteArray = FileAccess.get_file_as_bytes(pack_path)
	var pack_sha: String = _sha256_bytes(pack_bytes)
	if pack_bytes.is_empty():
		return _fail_job(job, manifest, "pack is empty: " + pack_path)
	if pack_sha != String(job.get("pack_sha256", "")):
		return _fail_job(job, manifest, "pack bytes changed between hashing (%s) and rendering (%s)" % [
			String(job.get("pack_sha256", "")).substr(0, 12), pack_sha.substr(0, 12)])
	manifest["input_pack"] = {"path": pack_path, "sha256": pack_sha, "bytes": pack_bytes.size()}
	var parser := JSON.new()
	if parser.parse(pack_bytes.get_string_from_utf8()) != OK:
		return _fail_job(job, manifest, "invalid pack JSON at line %d: %s" % [
			parser.get_error_line(), parser.get_error_message()])
	var pack: Variant = parser.data
	var info: Dictionary = Adapter.inspect(pack)
	if not info.ok:
		return _fail_job(job, manifest, "invalid world-design pack: " + String(info.error))
	var combined: Dictionary = Adapter.build_combined(pack)
	if not combined.ok:
		return _fail_job(job, manifest, "cannot build combined composition: " + String(combined.error))
	var native: Vector2i = combined["size"]
	manifest["native"] = {"width": native.x, "height": native.y,
		"rg8_sha256": combined.rg8_sha256, "family": info.family,
		"scene_id": String(info.scene.get("id", "")),
		"features": info.features.size(), "placements": info.placements.size()}
	var expanded: Dictionary = _expand_shots(job.get("shots", []), info)
	if not expanded.ok:
		return _fail_job(job, manifest, String(expanded.error))
	var presentation: Dictionary = _request.get("presentation", {})
	var combined_image: Image = _image_from_input(combined)
	if combined_image == null:
		return _fail_job(job, manifest, "cannot construct the RG8 source image")
	var rig = RenderRig.new()
	root.add_child(rig)
	rig.setup(combined_image, Vector2i(2, 2))
	rig.set_presentation(float(presentation.get("time", 1.37)), bool(presentation.get("glow", true)),
		bool(presentation.get("structured_detail", true)))
	rig.set_background_enabled(bool(presentation.get("background", true)))
	manifest["renderer"] = _renderer_identity(rig)
	var shot_records: Array[Dictionary] = []
	var error: String = ""
	for shot: Dictionary in expanded.shots:
		var record: Dictionary = await _render_shot(shot, job, pack, combined, combined_image, rig, job_dir)
		shot_records.append(record)
		manifest["shots"] = shot_records
		if record.status != "complete":
			error = "shot %s failed: %s" % [record.id, record.error]
			break
	rig.queue_free()
	await process_frame
	manifest["shots"] = shot_records
	if not error.is_empty():
		return _fail_job(job, manifest, error)
	if shot_records.is_empty():
		return _fail_job(job, manifest, "no shots were requested")
	manifest["status"] = "complete"
	manifest["error"] = ""
	if not _write_json(job_dir.path_join("manifest.json"), manifest):
		return {"id": job_id, "status": "failed", "error": "cannot write manifest.json", "manifest": ""}
	return {"id": job_id, "status": "complete", "error": "", "manifest": job_id + "/manifest.json",
		"shots": shot_records.size()}


func _image_from_input(input: Dictionary) -> Image:
	var size: Vector2i = input["size"]
	var image: Image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RG8, input.data)
	if image == null or image.is_empty() or image.get_data() != input.data:
		return null
	return image


func _renderer_identity(rig: Variant) -> Dictionary:
	var identity: Dictionary = rig.renderer_identity()
	identity["display_server"] = DisplayServer.get_name()
	identity["graphics_vendor"] = RenderingServer.get_video_adapter_vendor()
	var shader_files := {}
	for path: String in ["shaders/material_palette.gdshader", "shaders/material_emission.gdshader",
			"shaders/glow_composite.gdshader", "scripts/material_appearance_lut.gd",
			"scripts/palette_shader_selector.gd", "tools/world_art_render_rig.gd",
			"tools/world_design_pack_adapter.gd"]:
		shader_files[path] = FileAccess.get_sha256("res://" + path)
	identity["shader_file_sha256"] = shader_files
	# Palette identity: the exact appearance atlas and program texels fed to the shaders.
	identity["palette_lut"] = {
		"atlas_sha256": _sha256_bytes(CyberMaterialAppearanceLut.create_texture().get_image().get_data()),
		"program_sha256": _sha256_bytes(CyberMaterialAppearanceLut.create_program_texture().get_image().get_data()),
		"atlas_size": [CyberMaterialAppearanceLut.ATLAS_WIDTH, CyberMaterialAppearanceLut.ATLAS_HEIGHT],
		"material_count": CyberMaterialAppearanceLut.MATERIAL_COUNT,
	}
	return identity


# ------------------------------------------------------------------- shot plan

## Resolves pseudo-shots ("features") into concrete per-feature/variant shots and
## validates every named feature/variant against the pack inventory.
func _expand_shots(shots: Array, info: Dictionary) -> Dictionary:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw: Variant in shots:
		if typeof(raw) != TYPE_DICTIONARY:
			return {"ok": false, "error": "malformed shot request"}
		var shot: Dictionary = raw
		var kind: String = String(shot.get("kind", ""))
		var concrete: Array[Dictionary] = []
		if kind == "features":
			var include_variants: bool = bool(shot.get("all_variants", false))
			for feature_id: String in info.features:
				concrete.append({"kind": "feature", "feature": feature_id, "variant": "",
					"scale": shot.get("scale", 4)})
				if include_variants:
					for variant: Dictionary in info.features[feature_id].get("variants", []):
						concrete.append({"kind": "feature", "feature": feature_id,
							"variant": String(variant.id), "scale": shot.get("scale", 4)})
		elif kind == "feature":
			var feature_id: String = String(shot.get("feature", ""))
			if not info.features.has(feature_id):
				return {"ok": false, "error": "unknown feature '%s'; available: %s" % [
					feature_id, ", ".join(PackedStringArray(info.features.keys()))]}
			var variant_id: String = String(shot.get("variant", ""))
			if variant_id != "" and variant_id != "base":
				var found: bool = false
				for variant: Dictionary in info.features[feature_id].get("variants", []):
					found = found or String(variant.id) == variant_id
				if not found:
					return {"ok": false, "error": "feature '%s' has no variant '%s'" % [feature_id, variant_id]}
			else:
				variant_id = ""
			concrete.append({"kind": "feature", "feature": feature_id, "variant": variant_id,
				"scale": shot.get("scale", 4)})
		elif kind in ["full", "viewport", "detail"]:
			concrete.append(shot)
		else:
			return {"ok": false, "error": "unknown shot kind '%s'" % kind}
		for item: Dictionary in concrete:
			var id: String = String(item.get("id", ""))
			if id.is_empty():
				id = item.kind if item.kind != "feature" else "feature-" + _safe_name(String(item.feature))
				if item.kind == "feature" and String(item.variant) != "":
					id += "--" + _safe_name(String(item.variant))
			if seen.has(id):
				return {"ok": false, "error": "duplicate shot id '%s'" % id}
			seen[id] = true
			var finished: Dictionary = item.duplicate()
			finished["id"] = id
			out.append(finished)
	return {"ok": true, "shots": out}


# ------------------------------------------------------------------ rendering

func _render_shot(shot: Dictionary, job: Dictionary, pack: Variant, combined: Dictionary,
		combined_image: Image, rig: Variant, job_dir: String) -> Dictionary:
	var kind: String = String(shot.kind)
	var id: String = String(shot.id)
	var record: Dictionary = {"id": id, "kind": kind, "status": "failed", "error": "",
		"file": id + ".png"}
	var presentation: Dictionary = _request.get("presentation", {})
	var native: Vector2i = combined["size"]
	var source: Dictionary = combined
	var image: Image = null
	var camera: Dictionary = {}
	if kind == "feature":
		source = Adapter.build_feature(pack, String(shot.feature), String(shot.variant))
		if not source.ok:
			record["error"] = String(source.error)
			return record
		record["selection"] = {"feature": String(shot.feature), "variant": String(shot.variant)}
		native = source["size"]
	else:
		record["selection"] = {"feature": "", "variant": ""}
	record["source"] = {"native_width": native.x, "native_height": native.y,
		"rg8_sha256": String(source.rg8_sha256), "geometry": source.geometry}
	if kind == "full" or kind == "feature":
		var scale: int = int(shot.get("scale", 2))
		if scale < 1 or scale > FullExport.MAX_SCALE:
			record["error"] = "scale %d is outside 1..%d" % [scale, FullExport.MAX_SCALE]
			return record
		if FullExport.output_pixels(native, scale) > MAX_PIXELS:
			record["error"] = "export of %dx%d cells at %dx exceeds %d pixels" % [
				native.x, native.y, scale, MAX_PIXELS]
			return record
		var input_image: Image = combined_image if kind == "full" else _image_from_input(source)
		if input_image == null:
			record["error"] = "cannot construct RG8 source image"
			return record
		image = await FullExport.render(self, input_image, scale, float(presentation.get("time", 1.37)),
			bool(presentation.get("glow", true)), bool(presentation.get("structured_detail", true)),
			bool(presentation.get("background", true)))
		camera = {"mode": "tiled-full", "scale": scale, "tile_cells": FullExport.TILE_CELLS,
			"halo_cells": FullExport.HALO_CELLS, "native_rect": [0, 0, native.x, native.y],
			"map_fully_visible": true}
	else:
		var framed: Dictionary = _frame_shot(shot, native)
		if not framed.ok:
			record["error"] = String(framed.error)
			return record
		camera = framed.camera
		var resolution: Vector2i = framed.resolution
		rig.set_resolution(resolution)
		rig.set_view(framed.origin, Vector2(resolution) / float(camera.zoom))
		await _frames()
		image = rig.get_texture().get_image()
		if image != null and not image.is_empty() and image.get_size() != resolution:
			record["error"] = "framebuffer is %s, expected %s" % [str(image.get_size()), str(resolution)]
			return record
	if image == null or image.is_empty():
		record["error"] = "Godot returned no framebuffer image (shader/render failure or limit exceeded)"
		return record
	image.convert(Image.FORMAT_RGB8)
	record["camera"] = camera
	var stats: Dictionary = _stats(image)
	record["stats"] = stats
	if kind == "full":
		record["edge_stats"] = _edge_stats(image, int(camera.scale))
	if not bool(_request.get("allow_blank", false)) and not stats.nonblank:
		record["error"] = "rendered framebuffer is blank (%d distinct sampled colours); check the pack, framing and shader" % stats.distinct_colours
		return record
	var path: String = job_dir.path_join(record.file)
	if image.save_png(path) != OK:
		record["error"] = "PNG write failed: " + path
		return record
	var reread: Image = Image.load_from_file(path)
	if reread == null or reread.is_empty() or reread.get_size() != image.get_size():
		record["error"] = "written PNG cannot be decoded back at the expected size: " + path
		return record
	reread.convert(Image.FORMAT_RGB8)
	if reread.get_data() != image.get_data():
		record["error"] = "written PNG decodes to different pixels than the framebuffer: " + path
		return record
	var handle := FileAccess.open(path, FileAccess.READ)
	record["png_bytes"] = handle.get_length() if handle != null else 0
	record["png_sha256"] = FileAccess.get_sha256(path)
	record["width"] = image.get_width()
	record["height"] = image.get_height()
	record["status"] = "complete"
	return record


## Resolves a viewport/detail shot into a concrete resolution and camera.
func _frame_shot(shot: Dictionary, native: Vector2i) -> Dictionary:
	var kind: String = String(shot.kind)
	var resolution := Vector2i(1920, 1080)
	if shot.has("resolution"):
		resolution = Vector2i(int(shot.resolution[0]), int(shot.resolution[1]))
	var zoom: float = 1.0
	var origin: Vector2 = Vector2.ZERO
	var mode: String = ""
	var crop: Array = []
	if kind == "detail":
		var rect := Rect2i(native.x / 4, native.y / 4, maxi(1, native.x / 2), maxi(1, native.y / 2))
		if shot.get("crop") != null:
			var raw: Array = shot.crop
			rect = Rect2i(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]))
			mode = "crop"
		else:
			mode = "centre-half-crop"
		if rect.size.x < 1 or rect.size.y < 1 or rect.position.x < 0 or rect.position.y < 0 \
				or rect.end.x > native.x or rect.end.y > native.y:
			return {"ok": false, "error": "crop %d,%d,%d,%d (x,y,w,h) lies outside the %dx%d-cell composition" % [
				rect.position.x, rect.position.y, rect.size.x, rect.size.y, native.x, native.y]}
		if shot.get("zoom") != null:
			zoom = float(shot.zoom)
		else:
			zoom = maxf(1.0, floorf(minf(float(resolution.x) / rect.size.x, float(resolution.y) / rect.size.y)))
		resolution = Vector2i(roundi(rect.size.x * zoom), roundi(rect.size.y * zoom))
		origin = Vector2(rect.position)
		crop = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	else:
		var framing: Dictionary = shot.get("framing", {"mode": "fit"})
		mode = String(framing.get("mode", "fit"))
		match mode:
			"fit":
				zoom = clampf(minf(float(resolution.x) / native.x, float(resolution.y) / native.y) * 0.96,
					ZOOM_MIN, ZOOM_MAX)
				origin = Vector2(native) * 0.5 - Vector2(resolution) / zoom * 0.5
			"native":
				zoom = 1.0
				origin = Vector2(native) * 0.5 - Vector2(resolution) * 0.5
			"zoom":
				zoom = float(framing.zoom)
				var centre: Vector2 = Vector2(native) * 0.5
				if framing.get("center") != null:
					centre = Vector2(float(framing.center[0]), float(framing.center[1]))
				origin = centre - Vector2(resolution) / zoom * 0.5
			"view":
				var rect: Array = framing.view
				var view_size := Vector2(float(rect[2]), float(rect[3]))
				if view_size.x <= 0.0 or view_size.y <= 0.0:
					return {"ok": false, "error": "view rectangle must have positive size"}
				zoom = minf(float(resolution.x) / view_size.x, float(resolution.y) / view_size.y)
				origin = Vector2(float(rect[0]), float(rect[1])) + view_size * 0.5 - Vector2(resolution) / zoom * 0.5
			_:
				return {"ok": false, "error": "unknown framing mode '%s'" % mode}
	if zoom < ZOOM_MIN or zoom > ZOOM_MAX:
		return {"ok": false, "error": "zoom %.4f is outside %.2f..%.0f pixels per native cell" % [zoom, ZOOM_MIN, ZOOM_MAX]}
	if resolution.x < 1 or resolution.y < 1 or resolution.x > MAX_SIDE or resolution.y > MAX_SIDE \
			or resolution.x * resolution.y > MAX_PIXELS:
		return {"ok": false, "error": "output resolution %s is outside 1..%d per side / %d pixels" % [
			str(resolution), MAX_SIDE, MAX_PIXELS]}
	var view_size: Vector2 = Vector2(resolution) / zoom
	var visible := Rect2(origin, view_size)
	var epsilon: float = 0.0005
	var camera := {
		"mode": mode, "zoom": zoom, "resolution": [resolution.x, resolution.y],
		"origin": [origin.x, origin.y], "view_size": [view_size.x, view_size.y],
		"visible_native_rect": [visible.position.x, visible.position.y, visible.size.x, visible.size.y],
		"map_fully_visible": origin.x <= epsilon and origin.y <= epsilon
			and origin.x + view_size.x >= native.x - epsilon and origin.y + view_size.y >= native.y - epsilon,
		"clips": {"left": origin.x > epsilon, "top": origin.y > epsilon,
			"right": origin.x + view_size.x < native.x - epsilon,
			"bottom": origin.y + view_size.y < native.y - epsilon},
		"native_size": [native.x, native.y],
	}
	if not crop.is_empty():
		camera["crop"] = crop
	return {"ok": true, "camera": camera, "resolution": resolution, "origin": origin}


# ----------------------------------------------------------------- image stats

func _stats(image: Image) -> Dictionary:
	return _region_stats(image, Rect2i(Vector2i.ZERO, image.get_size()))


func _region_stats(image: Image, region: Rect2i) -> Dictionary:
	var colours: Dictionary = {}
	var non_background: int = 0
	var samples: int = 0
	var luma_min: float = 1.0
	var luma_max: float = 0.0
	var nx: int = mini(SAMPLE_GRID, region.size.x)
	var ny: int = mini(SAMPLE_GRID, region.size.y)
	for gy: int in range(ny):
		var y: int = region.position.y + (gy * (region.size.y - 1)) / maxi(1, ny - 1)
		for gx: int in range(nx):
			var x: int = region.position.x + (gx * (region.size.x - 1)) / maxi(1, nx - 1)
			var pixel: Color = image.get_pixel(x, y)
			colours[(pixel.r8 << 16) | (pixel.g8 << 8) | pixel.b8] = true
			if Vector3i(pixel.r8, pixel.g8, pixel.b8) != _background_bytes:
				non_background += 1
			var luma: float = 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b
			luma_min = minf(luma_min, luma)
			luma_max = maxf(luma_max, luma)
			samples += 1
	return {"samples": samples, "distinct_colours": colours.size(),
		"non_background_fraction": float(non_background) / maxf(1.0, float(samples)),
		"luma_min": luma_min, "luma_max": luma_max,
		"nonblank": colours.size() >= 4 and non_background > maxi(0, samples / 2000)}


## Edge strips of a tiled full export (EDGE_NATIVE_CELLS native cells wide) so a
## consumer can prove left/right/top/bottom cells were rendered, not clipped.
func _edge_stats(image: Image, output_scale: int) -> Dictionary:
	var strip: int = EDGE_NATIVE_CELLS * output_scale
	var width: int = image.get_width()
	var height: int = image.get_height()
	var sw: int = mini(strip, width)
	var sh: int = mini(strip, height)
	var out: Dictionary = {"strip_native_cells": EDGE_NATIVE_CELLS}
	out["left"] = _region_stats(image, Rect2i(0, 0, sw, height))
	out["right"] = _region_stats(image, Rect2i(width - sw, 0, sw, height))
	out["top"] = _region_stats(image, Rect2i(0, 0, width, sh))
	out["bottom"] = _region_stats(image, Rect2i(0, height - sh, width, sh))
	return out
