extends SceneTree

# Prospective hosted diagnostic only. No CyberSand, publisher or native extension.
# A fresh process is required for every arm. Ordinary font uploads retain the
# mutable atlas Image; the pinned mipmap branch duplicates it before upload.
const TARGET_DRAWS := 64
var errors: Array[String] = []
var requested_mode := ""
var requested_thread := ""
var mipmaps := false
var canvas: ProbeCanvas
var finishing := false

class ProbeCanvas extends Node2D:
	var probe: SceneTree
	var probe_font: FontFile
	var text_enabled := false
	var draw_count := 0
	var glyph_calls := 0
	func _process(_delta: float) -> void:
		if draw_count < TARGET_DRAWS:
			queue_redraw()
	func _draw() -> void:
		if draw_count >= TARGET_DRAWS:
			return
		if text_enabled:
			var size: int = 18 + draw_count % 32
			for codepoint: int in range(33,127):
				var index: int = codepoint - 33
				var position := Vector2(16 + (index % 20) * 48, 64 + (index / 20) * 96)
				draw_char(probe_font,position,String.chr(codepoint),size,Color.WHITE)
				glyph_calls += 1
		draw_count += 1
		if draw_count == TARGET_DRAWS:
			probe.call_deferred("finish")

func _init() -> void:
	print("ISOLATED_FONT_PROBE_SCRIPT_STARTED ",JSON.stringify({"pid":OS.get_process_id(),"engine":Engine.get_version_info()}))
	run_probe.call_deferred()

func check(ok: bool, detail: String) -> void:
	if not ok:
		errors.append(detail)
		push_error("ISOLATED_FONT_PROBE: " + detail)

func run_probe() -> void:
	check(GDExtensionManager.get_loaded_extensions().is_empty(),"isolated probe must load no native extensions")
	requested_mode = OS.get_environment("PUBPRES_FONT_PROBE_MODE")
	requested_thread = OS.get_environment("CYBERSAND_MATERIAL_QUEUE_THREAD")
	mipmaps = OS.get_environment("PUBPRES_FONT_PROBE_MIPMAPS") == "1"
	check(requested_mode in ["text","empty"],"mode must be text or empty")
	check(requested_thread in ["safe","separate"],"explicit safe or separate mode is required")
	check(DisplayServer.get_name() != "headless","real hosted graphical display required")
	check(RenderingServer.get_current_rendering_driver_name() in ["opengl3","opengl3_angle"],"Compatibility GL driver required")
	check(RenderingServer.is_on_render_thread() == (requested_thread == "safe"),"requested and actual rendering owner agree")
	check(not OS.get_environment("PUBPRES_FONT_PROBE_OUTPUT").is_empty(),"explicit output path is required")
	if not errors.is_empty():
		finish()
		return
	Engine.max_fps = 60
	canvas = ProbeCanvas.new()
	canvas.probe = self
	canvas.text_enabled = requested_mode == "text"
	if canvas.text_enabled:
		var fallback: Font = ThemeDB.fallback_font
		check(fallback is FontFile,"pinned default font must be FontFile")
		if not fallback is FontFile:
			finish()
			return
		canvas.probe_font = fallback as FontFile
		canvas.probe_font.set_generate_mipmaps(mipmaps)
	root.add_child(canvas)

func finish() -> void:
	if finishing:
		return
	finishing = true
	if canvas != null and errors.is_empty():
		await RenderingServer.frame_post_draw
		check(canvas.draw_count == TARGET_DRAWS,"bounded draw count completed")
	var framebuffer: Image = null
	if errors.is_empty():
		framebuffer = root.get_texture().get_image()
		check(framebuffer != null and not framebuffer.is_empty(),"real viewport readback completed")
	var output: String = OS.get_environment("PUBPRES_FONT_PROBE_OUTPUT")
	var report := {"schema":"pubpres-isolated-font-probe-v1",
		"source_commit":OS.get_environment("PUBPRES_PROBE_SOURCE"),
		"nonce":OS.get_environment("PUBPRES_PROBE_NONCE"),
		"native_independent":true,"loaded_extensions":GDExtensionManager.get_loaded_extensions(),
		"pid":OS.get_process_id(),"engine":Engine.get_version_info(),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"project_sha256":FileAccess.get_sha256("res://project.godot"),
		"script_sha256":FileAccess.get_sha256("res://font_probe.gd"),
		"platform":OS.get_name(),"display":DisplayServer.get_name(),
		"driver":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),
		"render_thread_inline":RenderingServer.is_on_render_thread(),
		"requested_thread":requested_thread,"mode":requested_mode,
		"font_mipmaps":mipmaps,"draws":canvas.draw_count if canvas != null else 0,
		"glyph_calls":canvas.glyph_calls if canvas != null else 0,
		"errors":errors,
		"scope":"Isolated engine diagnosis only; no gameplay or performance acceptance."}
	if framebuffer != null:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(framebuffer.get_data())
		report["framebuffer_sha256"] = hashing.finish().hex_encode()
		report["framebuffer_size"] = [framebuffer.get_width(),framebuffer.get_height()]
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var writer := FileAccess.open(output,FileAccess.WRITE)
		if writer == null:
			check(false,"could not write isolated diagnostic report")
		else:
			writer.store_string(JSON.stringify(report,"  ")+"\n")
	print("ISOLATED_FONT_PROBE_RESULT ",JSON.stringify(report))
	quit(int(not errors.is_empty()))
