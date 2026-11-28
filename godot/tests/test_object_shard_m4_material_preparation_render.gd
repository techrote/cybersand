extends SceneTree

const Overlay = preload("res://scripts/object_shard_workbench_overlay.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
class ViewHost extends Control:
	var world_view: Control
	var world_shader: ShaderMaterial
	var camera_origin := Vector2.ZERO
	var current_view_size := Vector2i(8,8)
	func view_content_rect() -> Rect2: return Rect2(0,0,64,64)
var checks: int = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var output: String = ""

func _initialize() -> void: _run.call_deferred()

func _check(value: bool,label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("M4_MATERIAL_PREPARATION: "+label)
	return value

func _publication(sequence: int) -> Dictionary:
	var bytes := PackedByteArray()
	bytes.resize(8*8*2)
	for y: int in range(1,7):
		for x: int in range(1,7): bytes[(y*8+x)*2] = 43
	return {"world_generation":7,"world_incarnation":9,"session":11,"publication_sequence":sequence,
		"shards":[{"session":11,"id":1,"generation":1,"body_generation":1,"material_revision":sequence,
			"width":8,"height":8,"owns_inventory":true,"render_cells":bytes,
			"origin_x":0,"origin_y":0,"position_x":0.0,"position_y":0.0,"rotation":0.0}]}

func _capture(view: SubViewport,label: String) -> Image:
	var started: int = Time.get_ticks_usec()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	var centre: Color = image.get_pixel(32,32)
	var row: Dictionary = {"label":label,"elapsed_usec":Time.get_ticks_usec()-started,
		"size":image.get_size(),"centre_rgba":[centre.r,centre.g,centre.b,centre.a],
		"empty_alpha":image.get_pixel(0,0).a}
	if not output.is_empty():
		var path: String = output.path_join(label+".png")
		_check(image.save_png(path)==OK,"save rendered "+label)
		row.sha256 = FileAccess.get_sha256(path)
	captures.append(row)
	return image

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Material preparation qualification requires an actual renderer")
		quit(1); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	_check(Overlay.material_preparation_observation().state=="unrequested", "ordinary process starts without structural shader preparation")
	var source_shader: Shader = Overlay.PALETTE_SOURCE
	var source_code: String = source_shader.code
	Overlay.request_material_preparation(self)
	_check(not Overlay.material_preparation_ready() and Overlay.material_preparation_observation().state=="preparing",
		"rendered admission waits for an actual completed preparation draw")
	var deadline: int = Time.get_ticks_msec()+Watchdogs.milliseconds("graphical_case_seconds")
	while not Overlay.material_preparation_ready() and Time.get_ticks_msec()<deadline:
		if Overlay.material_preparation_observation().state=="failed": break
		await process_frame
	var prepared: Dictionary = Overlay.material_preparation_observation()
	if not _check(prepared.state=="ready" and prepared.rendered,"positive material and transparent Empty shader draw complete before readiness"):
		_finish(prepared); return
	_check(prepared.runs==1 and prepared.status_frame_completed and prepared.temporary_viewport_retired,
		"one prior UI frame and one temporary rendered viewport precede process-shared readiness")
	_check(source_shader.code==source_code,"warm-up leaves ordinary shader source unchanged")
	var view := SubViewport.new()
	view.size = Vector2i(64,64)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var host := ViewHost.new()
	host.world_view = Control.new()
	host.world_view.size = Vector2(64,64)
	view.add_child(host)
	host.add_child(host.world_view)
	var overlay: Control = Overlay.new()
	overlay.host = host
	overlay.size = host.world_view.size
	host.world_view.add_child(overlay)
	overlay.present(_publication(1))
	var first: Image = await _capture(view,"prepared-first-body")
	_check(overlay.textures[1].sprite.material.shader.get_instance_id()==int(prepared.shader_instance_id),
		"first detached body reuses the exact prepared shared shader resource")
	_check(first.get_pixel(32,32).a>.99 and first.get_pixel(0,0).a<.01,
		"first detached material draws opaque occupied cells and transparent empty ring")
	overlay.clear()
	overlay.free()
	Overlay.request_material_preparation(self)
	_check(Overlay.material_preparation_observation()==prepared,"scene retirement and repeated admission do not restart preparation")
	overlay = Overlay.new()
	overlay.host = host
	overlay.size = host.world_view.size
	host.world_view.add_child(overlay)
	overlay.present(_publication(2))
	var replacement: Image = await _capture(view,"prepared-replacement-body")
	_check(overlay.textures[1].sprite.material.shader.get_instance_id()==int(prepared.shader_instance_id),
		"replacement overlay retains the same prepared shader without another preparation run")
	_check(first.get_data()==replacement.get_data(),"replacement material framebuffer remains identical")
	_check(root.find_child("ObjectShardMaterialPreparation",true,false)==null,"temporary preparation viewport has been retired")
	view.queue_free()
	await process_frame
	_finish(prepared)

func _finish(prepared: Dictionary) -> void:
	print(JSON.stringify({"schema":"objectshard-m4-material-preparation-v1","checks":checks,"failures":failures,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"display_driver":DisplayServer.get_name(),
		"preparation":prepared,"body_captures":captures,
		"scope":"actual renderer; explicit opt-in preparation and same shared shader reuse after overlay replacement; synthetic material inputs; no native World/body/time or physical display performance claim"}))
	quit(0 if failures.is_empty() else 1)
