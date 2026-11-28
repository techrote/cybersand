extends SceneTree

# Ordinary native Workbench plus retained material publications. The injected
# Held state tests inspectability only; it does not claim the owner's cut order.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Overlay = preload("res://scripts/object_shard_workbench_overlay.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var f: RefCounted
var observations: Array[Dictionary] = []
var output: String = ""
var preparation_frames: int = 0
var preparing_status_seen: bool = false
var preparation_advanced_physics: bool = false
var preparation_changed_pause: bool = false
var initial_preparation: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _observe_material_preparation() -> void:
	if f==null or f.host==null or f.host.shared_workbench==null: return
	if Overlay.material_preparation_observation().state != "preparing": return
	preparation_frames += 1
	preparing_status_seen = preparing_status_seen or f.host.shared_workbench._status.text.begins_with("Preparing structure materials")
	preparation_advanced_physics = preparation_advanced_physics or f.runtime().physical_steps!=0
	preparation_changed_pause = preparation_changed_pause or not f.host.paused

func _view(label: String,origin: Vector2,extent: Vector2i) -> void:
	f.bench._camera.select(0)
	f.bench._set_view(origin,extent)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var overlay: Control = f.runtime().overlay
	var view: Array = overlay.presentation_observation().view
	var shader: ShaderMaterial = f.host.world_shader
	var shader_origin: Vector2 = shader.get_shader_parameter("camera_origin_px")
	var shader_extent: Vector2 = shader.get_shader_parameter("view_size_px")
	var shader_rect: Vector4 = shader.get_shader_parameter("view_rect_uv")
	var expected_extent: Vector2 = Vector2(extent.min(f.host.world_extent))
	var expected_origin: Vector2 = origin.clamp(Vector2.ZERO,Vector2(f.host.world_extent)-expected_extent).floor()
	f.expect(shader_origin.is_equal_approx(expected_origin) and shader_extent.is_equal_approx(expected_extent),
		label+": actual terrain adopts the requested camera rather than retaining a stale crop")
	var rect := Rect2(Vector2(shader_rect.x,shader_rect.y)*f.host.world_view.size,
		Vector2(shader_rect.z,shader_rect.w)*f.host.world_view.size)
	f.expect(view.size()==3 and Vector2(view[0]).is_equal_approx(shader_origin)
		and Vector2(view[1]).is_equal_approx(shader_extent) and Rect2(view[2]).is_equal_approx(rect),
		label+": structure view equals actual terrain camera/zoom/content uniforms")
	f.expect(overlay._content.clip_contents and overlay._content.position.is_equal_approx(rect.position)
		and overlay._content.size.is_equal_approx(rect.size),label+": aspect-fit letterbox clips material bodies")
	for shard: Dictionary in overlay.frame.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		var entry: Dictionary = overlay.textures.get(int(shard.id),{})
		if not f.expect(not entry.is_empty(),label+": native material has a visible texture"): continue
		var actual: Transform2D = overlay._canvas.transform * entry.sprite.transform
		var scale: Vector2 = rect.size/shader_extent
		var expected: Transform2D = Transform2D(0.0,scale,0.0,-shader_origin*scale) \
			* Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y)))
		f.expect(actual.is_equal_approx(expected),label+": retained native pose shares terrain transform")
	observations.append({"label":label,"phase":f.runtime().phase,"user_status":f.bench.object_shard_user_status(),
		"tick":f.tick(),"publication":f.runtime().visible_observation(),"view":overlay.presentation_observation(),
		"requested_origin":[expected_origin.x,expected_origin.y],"window_size":[root.size.x,root.size.y],
		"terrain_image_extent":[f.host.image.get_width(),f.host.image.get_height()]})
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		f.expect(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,label+": actual framebuffer retained")

func _held_lease_1024() -> bool:
	var authored: Dictionary = Fixture.Scenes.create("tower",PackedInt32Array(f.bench.applied.liquid_policy))
	authored.extent = [1024,1024]
	# Boundary-anchored marker outside the initial cropped view. Inspecting it
	# after Held proves that a full retained image supports navigation without
	# another worker tick or a camera-triggered replacement publication.
	authored.edits.append([760,760,40,264,1])
	if not f.expect(f.bench.apply(authored),"1024 canvas with remote fixed marker accepted"): return false
	if not await f.until(f.installed,"1024 authored owner replacement installed"): return false
	await _view("lease-cropped-before-play",Vector2(112,220),Vector2i(160,128))
	f.play()
	if not await f.until(func(): return f.runtime().owns_terrain(),"1024 structural owner attaches") or not await f.pause(): return false
	if not await f.cut_supports("tower"): return false
	f.play()
	if not await f.until(func(): return f.body_count()>0,"1024 cropped scene admits actual falling structure"): return false
	if not await f.until(func(): return not f.runtime().overlay.textures.is_empty(),
		"1024 cropped view has a completed visible owned-material publication"): return false
	await _view("lease-cropped-active",Vector2(112,220),Vector2i(160,128))
	if not await f.until(func(): return f.runtime()._motion_lease!=0 and f.runtime()._interval_active \
		and f.runtime()._pending_serial!=0 and f.runtime()._pending_kind=="motion",
		"actual admitted motion lease and pending pose receipt precede injected protective Held"): return false
	var lease: int = f.runtime()._motion_lease
	var tick: int = f.tick()
	var retained: Dictionary = f.runtime().visible_observation().duplicate(true)
	var image_bytes: PackedByteArray = f.host.image.get_data()
	f.runtime()._hold("LeasedPresentationFixtureHold")
	await _view("held-lease-far-pan",Vector2(720,720),Vector2i(256,192))
	root.size = Vector2i(1080,820)
	await _view("held-lease-resize",Vector2(736,736),Vector2i(192,192))
	f.expect(f.host.image.get_size()==Vector2i(1024,1024) and f.host.texture.get_size()==Vector2(1024,1024)
		and Vector2(f.host.world_shader.get_shader_parameter("world_size_px"))==Vector2(1024,1024),
		"retained terrain texture covers the complete 1024 World despite initially cropped camera")
	f.expect(roundi(f.host.image.get_pixel(780,780).r*255.0)==1
		and roundi(f.host.image.get_pixel(740,740).r*255.0)==0,
		"retained image contains the actual remote marker and empty neighbour outside the former view")
	f.expect(f.host.image.get_data()==image_bytes and f.tick()==tick
		and f.runtime().visible_observation()==retained and f.runtime()._motion_lease==lease,
		"Held leased inspection preserves exact terrain bytes, material publication, native tick and lease")
	f.expect(f.bench.restore_start(),"Restore start escapes the retained active-lease Held state")
	var deadline: int = Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec()<deadline:
		if f.installed() and f.runtime().held_reason.is_empty(): break
		await process_frame
	return f.expect(f.installed() and f.runtime().held_reason.is_empty()
		and f.runtime()._motion_lease==0 and f.runtime().overlay.textures.is_empty(),
		"actual owner replacement retires the held lease and every old body visual")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	f = Fixture.new(self)
	if DisplayServer.get_name() != "headless": RenderingServer.frame_post_draw.connect(_observe_material_preparation)
	if not await f.open("tower"): await _finish(); return
	initial_preparation = Overlay.material_preparation_observation()
	if DisplayServer.get_name() == "headless":
		f.expect(initial_preparation.state=="headless" and not initial_preparation.rendered and initial_preparation.runs==0,
			"headless admission explicitly records that no graphical preparation was performed")
	else:
		f.expect(initial_preparation.state=="ready" and initial_preparation.rendered and initial_preparation.runs==1,
			"ordinary Structures admission waits for its one real shader preparation draw")
		f.expect(preparation_frames>0 and preparing_status_seen and not preparation_advanced_physics and not preparation_changed_pause,
			"Preparing structure materials is visible before readiness without changing Pause or structural physical time")
	if not await f.cut_supports("tower"): await _finish(); return
	f.play()
	if not await f.until(func(): return f.body_count()>0,"ordinary cut creates owned material body"):
		await _finish(); return
	if not await f.advance(20,"native collapse progresses before camera checks"):
		await _finish(); return
	await _view("active-overview",Vector2.ZERO,Vector2i(512,512))
	await _view("active-pan-zoom",Vector2(120,180),Vector2i(256,144))
	if not await f.pause(): await _finish(); return
	for shard: Dictionary in f.runtime().publication.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		var bytes: PackedByteArray = shard.get("render_cells",PackedByteArray())
		f.expect(bytes.size()==int(shard.width)*int(shard.height)*2,"actual native shard publishes ordinary RG8 visual projection")
		if bytes.size()!=int(shard.width)*int(shard.height)*2: continue
		var materials_match: bool = true
		for cell: int in range(int(shard.width)*int(shard.height)):
			materials_match = materials_match and int(bytes[cell*2])==int(shard.materials[cell])
		f.expect(materials_match,"every RG8 material byte preserves authoritative carrier identity")
		f.expect(f.runtime().overlay.textures[int(shard.id)].projected,"actual detached body selects shared material finish")
		if DisplayServer.get_name() != "headless":
			f.expect(f.runtime().overlay.textures[int(shard.id)].sprite.material.shader.get_instance_id()==int(initial_preparation.shader_instance_id),
				"first native detached body reuses the exact admitted shared shader")
	await _view("paused-pan-zoom",Vector2(160,240),Vector2i(320,180))
	root.size = Vector2i(1024,768)
	await _view("paused-resize",Vector2(110,160),Vector2i(256,144))
	var retained: Dictionary = f.runtime().visible_observation().duplicate(true)
	var held_tick: int = f.tick()
	var before_views: int = f.runtime().overlay.view_updates
	f.runtime()._hold("PresentationFixtureHold")
	await _view("held-pan-zoom",Vector2(120,220),Vector2i(320,180))
	root.size = Vector2i(1280,720)
	await _view("held-resize",Vector2.ZERO,Vector2i(512,512))
	f.expect(f.runtime().overlay.view_updates>before_views,"Held camera remains responsive without receipt pumping")
	f.expect(f.tick()==held_tick and f.runtime().visible_observation()==retained,
		"Held inspection neither advances native time nor changes the retained coherent material publication")
	f.expect(f.bench.object_shard_user_status().begins_with("Held: PresentationFixtureHold") \
		and f.bench.object_shard_user_status().contains("Save diagnostics") \
		and f.bench.object_shard_user_status().contains("Restore start"),"protective refusal remains visible and actionable")
	f.bench._last_status_ms = -1000
	f.bench._process(0.0)
	f.expect(f.bench._status.text.begins_with("Structures Held:"),"protective refusal precedes clipped routine status counters")
	var old_generation: int = int(f.runtime().capabilities.world_generation)
	f.expect(f.bench.restore_start(),"ordinary Restore start accepted from Held")
	var deadline: int = Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec()<deadline:
		if f.installed() and f.runtime().held_reason.is_empty(): break
		await process_frame
	f.expect(f.installed() and f.runtime().held_reason.is_empty(),"owner replacement clears Held and stale body visuals")
	# Restore intentionally leaves the authored World paused before its first
	# native tick. It must be inspectable without claiming an attached/Ready
	# structural transaction or resuming merely to refresh the old overlay.
	f.expect(f.host.paused and f.host.image != null,"Restore presents the paused authored canvas before Play")
	f.expect(f.runtime().overlay.textures.is_empty() and f.runtime().overlay.frame.is_empty(),
		"paused Restore retires every former owned-material visual before Play")
	await _view("restored-paused-before-play",Vector2(120,180),Vector2i(320,180))
	f.expect(f.host.paused and f.runtime().overlay.textures.is_empty(),
		"paused restored canvas remains navigable with no retired owner visuals")
	f.expect(f.bench.object_shard_user_status()=="Paused · Play to start structures",
		"paused first-tick boundary explains the Play action instead of an indefinite Starting status")
	f.play()
	if not await f.until(func(): return int(f.runtime().capabilities.get("world_generation",-1))>old_generation and f.tick()>0,
		"Restore adopts a new native World generation"):
		await _finish(); return
	await f.pause()
	f.expect(f.runtime().publication.get("world_generation",-1)!=retained.get("world_generation",-1),
		"restored material publication cannot reuse the retired World identity")
	await _view("restored-start",Vector2.ZERO,Vector2i(512,512))
	if not await _held_lease_1024(): await _finish(); return
	f.expect(f.bench.load_object_shard_scene("stress"),"new eight-body authored scene accepted")
	if not await f.until(f.installed,"replacement stress scene installed"):
		await _finish(); return
	f.play()
	await f.until(func(): return f.tick()>0,"replacement scene completes its first native tick")
	await f.pause()
	await _view("scene-replacement",Vector2.ZERO,Vector2i(512,512))
	f.expect(Overlay.material_preparation_observation()==initial_preparation,
		"Restore and scene replacement retain the process-shared material preparation without another cold admission")
	await _finish()

func _finish() -> void:
	f.validate_display()
	var display: Dictionary = f.display_witness()
	if RenderingServer.frame_post_draw.is_connected(_observe_material_preparation): RenderingServer.frame_post_draw.disconnect(_observe_material_preparation)
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-camera-lifecycle-v1","checks":f.checks,"failures":f.failures,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"display_driver":DisplayServer.get_name(),
		"observations":observations,"display":display,"material_preparation":Overlay.material_preparation_observation(),
		"preparation_status_frames":preparation_frames,"preparing_status_seen":preparing_status_seen,
		"scope":"actual ordinary native/Rapier Workbench; camera/zoom/resize in active, paused and deliberately injected Held state; Restore and scene replacement; no claim to reproduce original owner cut order"}))
	quit(0 if f.failures.is_empty() else 1)
