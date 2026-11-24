extends "res://tools/qualify_workbench_strata.gd"

# A separate process owns the cap probe. It uses the unchanged ordinary default
# 2048x2048 canvas and ordinary actor placement, then enables three full-size
# static material planes. Reference scenes remain separate 1024x768 processes.
func run() -> void:
	phase = "maximum"
	scene_id = "default-canvas"
	output = OS.get_environment("STRATA_EVIDENCE")
	record = {"schema":"strata-maximum-execution-v1","completed":false,"phase":phase,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
		"rendering_adapter":RenderingServer.get_video_adapter_name(),"process_id":OS.get_process_id()}
	if not check(DisplayServer.get_name() != "headless" and not output.is_empty(),"maximum probe requires actual graphical execution"):
		finish(); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,1000)
	set_meta("cybersand_feature","shared_workbench")
	var bootstrap_start := Time.get_ticks_msec()
	host = load("res://main.tscn").instantiate()
	print("STRATA_PROGRESS maximum ordinary Main")
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	if not await until(idle,"ordinary default2048startup",180000): finish(); return
	record.bootstrap_elapsed_ms = Time.get_ticks_msec()-bootstrap_start
	check(Setup.extent_of(wb.applied) == Vector2i(2048,2048),"unchanged ordinary default extent is2048square")
	record.extent = [2048,2048]
	record.ordinary_workbench = wb.get_script().resource_path == "res://scripts/shared_workbench.gd"
	await ordinary_disabled_baseline()
	check(wb.place(Setup.Fleet.stable_id(0),Vector2(1024,1100)),"ordinary actor placed in maximum canvas")
	if not await until(func() -> bool: return idle() and host.physical_actor_session != null,"maximum actual actor adopted"):
		finish(); return
	wb.set_camera(2)
	var before := play_identity()
	var play_before := await play_bytes()
	strata = wb.ensure_strata()
	print("STRATA_PROGRESS maximum three native planes")
	if not check(strata.set_enabled(true),"three2048nativeplanes enabled"): finish(); return
	await settle()
	stable_identity(before,play_identity(),"maximum enable")
	var owners: Dictionary = strata.layer_owner.stats()
	check(owners.native_world_count == 3 and not owners.owns_play_world,"maximum cardinality one borrowed and three owned")
	record.world_count = {"play_borrowed":1,"decorative_owned":owners.native_world_count}
	var planes := {}
	for id: String in ["scripted","effects","background"]:
		var surface: SubViewport = strata.presenter._surfaces[id]
		check(surface.cell_image.get_size() == Vector2i(2048,2048) and surface.size == Vector2i(2048,2048),"maximum actual native/image/viewport dimensions "+id)
		check(strata.set_presentation({"mode":"flat","active":id,"solo":"","parallax_strength":0.0,"fog_strength":0.0}),"maximum flat target "+id)
		check(strata.set_layer_option(id,"opacity",1.0),"maximum opaque target "+id)
		var point := Vector2i(1024,700)
		var dark: Image = await capture("maximum-before-"+id)
		await gesture(id,"Brush",point,point,131,6)
		check(strata.layer_owner.material_at(id,point) == 131,"maximum actual native brush target "+id)
		var painted: Image = await capture("maximum-brush-"+id)
		var delta := colour_distance(framebuffer_colour(dark,point,id),framebuffer_colour(painted,point,id))
		check(delta > 0.025,"maximum actual rendered material pixel "+id)
		planes[id] = {"extent":[surface.cell_image.get_width(),surface.cell_image.get_height()],
			"native_material":strata.layer_owner.material_at(id,point),"pixel_delta":delta,
			"owner":str(strata.layer_owner.stats().layers[id].native_instance_id)}
	check(strata.set_presentation({"mode":"stack","active":"play","solo":""}),"maximum stack")
	for enabled: bool in [false,true,false,true]:
		check(strata.set_enabled(enabled),"maximum display toggle")
		await settle()
		stable_identity(before,play_identity(),"maximum mode toggle")
	var play_after := await play_bytes()
	check(play_after == play_before,"maximum decorative edits leave all Play native cells unchanged")
	record.identity = {"before":before,"after":play_identity()}
	record.play_hash_before = digest(play_before)
	record.play_hash_after = digest(play_after)
	record.planes = planes
	record.cost = await cost("stack")
	record.final_diagnostics = strata.diagnostics()
	print("STRATA_MAXIMUM ",JSON.stringify({"checks":checks,"failures":failures,"extent":[2048,2048]}))
	finish()
