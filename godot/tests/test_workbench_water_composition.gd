extends SceneTree

const Coherence = preload("res://scripts/workbench_presentation_coherence.gd")
const Composition = preload("res://scripts/workbench_water_composition.gd")
const Overlay = preload("res://scripts/physical_actor_overlay.gd")
const Main = preload("res://scripts/main.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Bridge = preload("res://scripts/workbench_physics_bridge.gd")
var checks: int = 0
var failures: Array[String] = []
var coverage_checks_completed: bool = false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("WATER_COMPOSITION: "+message)

func _initialize() -> void:
	_run.call_deferred()

func picture(material: int) -> Image:
	var image := Image.create(8,8,false,Image.FORMAT_RG8)
	image.fill(Color(float(material)/255.0,0,0,1))
	return image

func proof(current: Image, previous: Image, allow: bool = true,
		old_active: bool = true, old_unknown: bool = false, limit: int = 12000) -> Dictionary:
	return Coherence.assess(Transform2D(0,Vector2(3.5,3)),Transform2D(0,Vector2(3.5,3)),
		[{"center":Vector2.ZERO,"size":Vector2(3,2.5)}],current,{},old_unknown,old_active,
		limit,0,previous,true,current.get_data(),previous.get_data() if previous != null else PackedByteArray(),
		0,false,allow)


func bounded_water_clearance_checks() -> void:
	var start := Transform2D(-0.15,Vector2(32.5,32.5))
	var finish := Transform2D(0.15,Vector2(32.5,32.5))
	var thin: Array = [{"center":Vector2(5,0),"size":Vector2(8,0.15)}]
	for format: Image.Format in [Image.FORMAT_R8,Image.FORMAT_RG8]:
		var current := Image.create(64,64,false,format)
		var previous := Image.create(64,64,false,format)
		# Green contains a Sand-like state byte, which is NOT a second ID.
		current.fill(Color(3.0/255.0,2.0/255.0,0,1))
		previous.fill(Color(0,3.0/255.0,0,1))
		var current_bytes := current.get_data()
		var previous_bytes := previous.get_data()
		var sweep: Dictionary = Coherence.assess(start,finish,thin,current,{},false,true,
			12000,0,previous,true,current_bytes,previous_bytes,24000,true,true)
		check(sweep.safe and sweep.get("proof")=="water_composable_bounds"
			and sweep.scanned > 0 and sweep.scanned <= 24000,
			"bounded full Water/Empty clearance uses exact material IDs in format "+str(format))
		check(current.get_data()==current_bytes and previous.get_data()==previous_bytes,
			"bounded conversion leaves both immutable uploaded images unchanged "+str(format))
		check(not Coherence.assess(start,finish,thin,current,{},false,true,
			12000,0,previous,true,current_bytes,previous_bytes,24000,true,false).safe,
			"ordinary non-composition still refuses genuine Water "+str(format))
		# Both endpoints miss this cell, but the true intermediate rotation
		# crosses its centre. Full bounds must not hide the thin Sand witness.
		current.set_pixel(37,32,Color(2.0/255.0,3.0/255.0,0,1))
		check(not Coherence.assess(start,finish,thin,current,{},false,true,
			12000,0,previous,true,current.get_data(),previous_bytes,24000,true,true).safe,
			"thin current Sand between sampled endpoints remains blocking "+str(format))
		current.set_pixel(37,32,Color(3.0/255.0,2.0/255.0,0,1))
		previous.set_pixel(37,32,Color(58.0/255.0,0,0,1))
		check(not Coherence.assess(start,finish,thin,current,{},false,true,
			12000,0,previous,true,current.get_data(),previous.get_data(),24000,true,true).safe,
			"old-only hard material remains blocking through active crossfade "+str(format))
		check(Coherence.assess(start,finish,thin,current,{},false,false,
			12000,0,previous,true,current.get_data(),previous.get_data(),24000,true,true).safe,
			"explicitly expired previous material contributes no clearance pixels "+str(format))
		check(not Coherence.assess(start,finish,thin,current,{},false,false,
			1,0,null,true,current.get_data(),PackedByteArray(),1,true,true).safe,
			"insufficient shared cell allowance still refuses complete coverage "+str(format))
		check(not Coherence.assess(start,finish,thin,current,{},false,false,
			12000,Time.get_ticks_usec()-1,null,true,current.get_data(),PackedByteArray(),24000,true,true).safe,
			"expired shared elapsed deadline cannot admit even clear Water bounds "+str(format))

func identity_checks() -> void:
	var pose := Transform2D(0,Vector2(3.5,3))
	var context := {"bridge":-9223372036854775000,"session":1,"epoch":7,"world":3,
		"revision":12,"step":44,"native_tick":43,"sample":45,"native_completed_usec":100}
	var member := {"instance_id":2,"generation":6}
	var entry := {"pose":pose,"sample":45,"generation":6}
	var observation := {"pose":pose,"step":44,"instance_id":2,"generation":6,"completed_usec":200}
	var sampled := {"serial":45,"step":44,"session":1,"epoch":7,"pose":pose}
	var joined: Dictionary = Composition.dependency(context,member,entry,observation,sampled,{})
	check(joined.get("kind") == "current_step_sampled_closure" and not joined.get("consumed_by_step",true),
		"later current-step closure is explicitly not a consumed dependency")
	var consumed: Dictionary = context.duplicate()
	consumed.merge({"instance_id":2,"generation":6,"input_pose":pose,"output_pose":pose,
		"completed_usec":200,"native_response_applied":true})
	joined = Composition.dependency(context,member,entry,observation,{},consumed)
	check(joined.get("kind") == "consumed_native_dependency" and joined.get("consumed_by_step",false),
		"exact original consumed dependency joins actual current completion")
	for key: String in ["bridge","session","epoch","world","step","native_tick","sample","generation","instance_id","completed_usec","native_completed_usec"]:
		var bad: Dictionary = consumed.duplicate()
		bad[key] = int(bad[key])+1
		check(Composition.dependency(context,member,entry,observation,{},bad).is_empty(),"reject changed consumed "+key)
	for key: String in ["step","generation","instance_id","completed_usec"]:
		var bad: Dictionary = observation.duplicate()
		bad[key] = int(bad[key])+1 if key != "completed_usec" else 0
		check(Composition.dependency(context,member,entry,bad,{},consumed).is_empty(),"reject changed actual observation "+key)
	for key: String in ["serial","step","session","epoch"]:
		var bad: Dictionary = sampled.duplicate()
		bad[key] = int(bad[key])+1
		check(Composition.dependency(context,member,entry,observation,bad,{}).is_empty(),"reject stale closure "+key)
	var bad_consumed: Dictionary = consumed.duplicate()
	bad_consumed.native_response_applied = false
	check(Composition.dependency(context,member,entry,observation,{},bad_consumed).is_empty(),"refused response is not consumed authority")
	var bad_sample: Dictionary = sampled.duplicate()
	bad_sample.pose = Transform2D(0,Vector2(3.6,3))
	check(Composition.dependency(context,member,entry,observation,bad_sample,{}).is_empty(),"closure pose must be exact sampled geometry")

func independent_authority_checks() -> void:
	var pose := Transform2D(0,Vector2(3.5,3))
	var member := {"instance_id":2,"generation":6}
	var context := {"bridge":-999,"session":1,"epoch":7,"world":3,"revision":12,
		"step":44,"native_tick":43,"sample":45,"native_completed_usec":100,
		"completed_usec":200,"rid":99,"rectangles":[{"center":Vector2.ZERO,"size":Vector2(7,3)}]}
	var observation := {"pose":pose,"step":44,"instance_id":2,"generation":6,"completed_usec":200}
	var consumed: Dictionary = context.duplicate(true)
	consumed.merge({"instance_id":2,"generation":6,"input_pose":Transform2D(0,Vector2(3.0,3)),
		"output_pose":pose,"native_response_applied":true})
	var joined: Dictionary = Composition.completed_dependency(context,member,observation,consumed)
	check(joined.get("kind")=="current_completed_native_dependency" and joined.get("physical_completion_claim",false),
		"current consumed physical authority is independent of an image's older native identity")
	for key: String in ["bridge","session","epoch","world","step","native_tick","sample","revision","rid","native_completed_usec","completed_usec"]:
		var changed: Dictionary = consumed.duplicate(true)
		changed[key] = int(changed[key])+1
		check(Composition.completed_dependency(context,member,observation,changed).is_empty(),"current dependency refuses changed "+key)
	for key: String in ["session","epoch"]:
		var changed: Dictionary = context.duplicate(true)
		var bad: Dictionary = consumed.duplicate(true)
		changed[key] = -1
		bad[key] = -1
		check(Composition.completed_dependency(changed,member,observation,bad).is_empty(),"negative current native owner domain refuses "+key)
	var changed: Dictionary = consumed.duplicate(true)
	changed.output_pose = Transform2D(0,Vector2(3.6,3))
	check(Composition.completed_dependency(context,member,observation,changed).is_empty(),"stale actual output pose refuses")
	changed = consumed.duplicate(true)
	changed.rectangles[0].size = Vector2(8,3)
	check(Composition.completed_dependency(context,member,observation,changed).is_empty(),"changed current member geometry refuses")
	changed = consumed.duplicate(true)
	changed.native_response_applied = false
	check(Composition.completed_dependency(context,member,observation,changed).is_empty(),"unapplied native response cannot prove a current pose")
	var birth: Dictionary = context.duplicate(true)
	birth.merge({"step":0,"manual_steps":0,"initialized":true,"completed_usec":0,"native_completed_usec":-1,
		"initialized_pose":pose},true)
	var entry := {"pose":pose,"sample":45,"generation":6}
	var initial := {"pose":pose,"step":0,"instance_id":2,"generation":6,"completed_usec":0}
	var sampled := {"serial":45,"step":0,"session":1,"epoch":7,"pose":pose,"completed_usec":0}
	joined = Composition.initialized_closure(birth,member,entry,initial,sampled)
	check(joined.get("kind")=="initialized_authoring_closure" and not joined.get("physical_completion_claim",true) \
		and not joined.get("consumed_by_step",true) and joined.get("completed_usec",-1)==0,
		"initialized Water pose grants no physical completion or consumed-step credit")
	for key: String in ["step","manual_steps","completed_usec"]:
		changed = birth.duplicate(true)
		changed[key] = 1
		check(Composition.initialized_closure(changed,member,entry,initial,sampled).is_empty(),"birth authority refuses nonzero "+key)
		changed[key] = 0.0
		check(Composition.initialized_closure(changed,member,entry,initial,sampled).is_empty(),"birth authority refuses coerced "+key)
	for key: String in ["serial","step","session","epoch","completed_usec"]:
		changed = sampled.duplicate(true)
		changed[key] = float(changed[key])
		check(Composition.initialized_closure(birth,member,entry,initial,changed).is_empty(),"birth closure refuses coerced "+key)
	changed = birth.duplicate(true)
	changed.initialized = false
	check(Composition.initialized_closure(changed,member,entry,initial,sampled).is_empty(),"uninitialized owner cannot claim an authored pose")
	for key: String in ["instance_id","generation"]:
		var bad_member: Dictionary = member.duplicate()
		bad_member.erase(key)
		check(Composition.completed_dependency(context,bad_member,observation,consumed).is_empty(),"current authority rejects missing member "+key)
		check(Composition.initialized_closure(birth,bad_member,entry,initial,sampled).is_empty(),"birth authority rejects missing member "+key)

func color_error(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))


class SampledWorld extends RefCounted:
	var revision := 31
	var tick_index := 8
	var packet: Dictionary
	func workbench_coupling_results() -> Dictionary: return packet


func exact_body_basis_checks() -> void:
	var worker := CyberSimulationWorker.new()
	var world := SampledWorld.new()
	var pose := Transform2D(0.21875,Vector2(14.25,18.5))
	# A native rigid rotation need not bit-round-trip through atan2 and sin.
	pose.x.y += 0.0000000149
	var local := Vector2(2.5,-1.25)
	var centre := pose*local
	var com := pose*Vector2(0.5,0.25)
	var states := PackedFloat64Array([1,centre.x,centre.y,pose.get_rotation(),4,2,0,0,0,1,17,1,com.x,com.y,0.5,1.0/60.0,4])
	worker._world = world
	world.packet = {"valid":true,"session":4,"epoch":2,"sample_tick":8,
		"rows":[{"id":1,"instance_id":56,"generation":2,"com":com,"sample":17}]}
	worker._workbench_consumed_sample = {"session":4,"epoch":2,"states":states,
		"bodies":[{"first_proxy":1,"instance_id":56,"generation":2}],
		"geometry":PackedFloat64Array([local.x,local.y,4,2]),"display_poses":[pose]}
	worker._capture_workbench_result()
	check(worker._workbench_display.get("instances",{}).get(56,{}).get("pose") == pose,
		"consumed proxy coordinates and force COM retain the exact sampled body basis and origin")
	worker._workbench_consumed_sample.display_poses[0] = Transform2D(pose.x,pose.y,pose.origin+Vector2.RIGHT)
	worker._capture_workbench_result()
	check(worker._workbench_display.is_empty(),"a body transform disagreeing with the consumed proxy has no display authority")
	worker._workbench_consumed_sample.display_poses[0] = pose
	world.packet.rows[0].com += Vector2.RIGHT
	worker._capture_workbench_result()
	check(worker._workbench_display.is_empty(),"a different returned native force COM cannot bind a sampled display transform")


func coverage_cache_checks() -> void:
	# Exercise the production scan/cache seam without claiming an initialized
	# native owner. Real authority, lifecycle and framebuffer tests are separate.
	var app = Main.new()
	var session = Session.new()
	var bridge = Bridge.new()
	var body: RID = PhysicsServer2D.body_create()
	bridge._session = 5
	bridge._epoch = 7
	bridge._members.append({"instance_id":11,"generation":7})
	bridge._body_rids.append(body)
	session.bridge = bridge
	app.physical_actor_session = session
	app.image = picture(3)
	app._presentation_previous_image = picture(3)
	app._presentation_current_bytes = app.image.get_data()
	app._presentation_previous_bytes = app._presentation_previous_image.get_data()
	app._presentation_previous_unknown = false
	app._presentation_current_content_id = 21
	app._presentation_previous_content_id = 20
	app._presentation_current_content_shape = Vector3i(8,8,Image.FORMAT_RG8)
	app._presentation_previous_content_shape = Vector3i(8,8,Image.FORMAT_RG8)
	app.last_uploaded_world_generation = 4
	app.last_uploaded_revision = 9
	app.last_uploaded_render_snapshot_serial = 30
	app.texture = ImageTexture.create_from_image(app.image)
	app.previous_texture = ImageTexture.create_from_image(app._presentation_previous_image)
	var pose := Transform2D(0,Vector2(3.5,3))
	var rectangles := [{"center":Vector2.ZERO,"size":Vector2(3,2.5)}]
	var context := {"previous_blend_active":true,"deadline_usec":Time.get_ticks_usec()+100000}
	var summary := {"cells_examined":0,"budget_vetoes":0}
	check(app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary,true).is_empty(),
		"unscanned coverage never appears from the reuse path")
	var scanned: Dictionary = app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary)
	check(scanned.safe and scanned.scanned > 0 and app._workbench_water_coverage_cache.size()==1,
		"a complete genuine coverage scan seeds one bounded member record")
	context.deadline_usec = 1
	var spent: int = int(summary.cells_examined)
	var reused: Dictionary = app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary,true)
	check(reused.safe and reused.scanned==0 and reused.original_scanned==scanned.scanned \
		and reused.coverage_reused and summary.cells_examined==spent,
		"exact immutable coverage reuses its result without inventing new scan work")
	for property: String in ["last_uploaded_world_generation","last_uploaded_revision",
		"last_uploaded_render_snapshot_serial","_presentation_current_content_id","_presentation_previous_content_id"]:
		var original: int = app.get(property)
		app.set(property,original+1)
		check(app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary,true).is_empty(),
			"coverage refuses changed uploaded identity "+property)
		app.set(property,original)
	bridge._epoch += 1
	check(app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary,true).is_empty(),"new owner epoch cannot inherit coverage")
	bridge._epoch -= 1
	bridge._members[0].generation += 1
	check(app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary,true).is_empty(),"new member generation cannot inherit coverage")
	bridge._members[0].generation -= 1
	var moved := Transform2D(0,Vector2(3.6,3))
	check(app._assess_workbench_water_sweep(0,moved,pose,rectangles,context,summary,true).is_empty(),"changed sweep anchor requires a real scan")
	check(app._assess_workbench_water_sweep(0,pose,moved,rectangles,context,summary,true).is_empty(),"changed actual endpoint requires a real scan")
	var changed: Array = rectangles.duplicate(true)
	changed[0].size.x += 1
	check(app._assess_workbench_water_sweep(0,pose,pose,changed,context,summary,true).is_empty(),"changed shape cannot reuse coverage")
	app._presentation_previous_unknown = true
	check(app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary,true).is_empty(),"unknown active image history refuses reuse")
	app._presentation_previous_unknown = false
	app._presentation_current_content_id += 1
	context.deadline_usec = Time.get_ticks_usec()+100000
	app.image = picture(2)
	app._presentation_current_bytes = app.image.get_data()
	var refused: Dictionary = app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary)
	check(not refused.safe,"new Sand content requires and fails the genuine full scan")
	check(app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary,true).is_empty(),"a refused new-content scan never becomes cached authority")
	app.image = picture(3)
	app._presentation_current_bytes = app.image.get_data()
	app._presentation_current_content_id += 1
	app._presentation_previous_content_id += 1
	app._presentation_previous_image = picture(2)
	app._presentation_previous_bytes = app._presentation_previous_image.get_data()
	refused = app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary)
	check(not refused.safe,"new active previous Sand image independently refuses coverage")
	context.previous_blend_active = false
	scanned = app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary)
	check(scanned.safe,"inactive previous history contributes no pixels and is excluded explicitly")
	context.previous_blend_active = true
	check(app._assess_workbench_water_sweep(0,pose,pose,rectangles,context,summary,true).is_empty(),"reactivated old image cannot borrow current-only coverage")
	check(app.workbench_presentation_frame.is_empty() and app._workbench_presentation_history.retained_observations()==0 \
		and bridge.manual_step_count()==0,"coverage work creates no visible history or physical credit")
	bridge._rects.append(rectangles)
	app.rapier_bridge = bridge
	app._physical_terrain_ready = true
	context.previous_blend_active = false
	var endpoint: Dictionary = app._workbench_water_coverage_cache[0].identity
	var old := {"step":7,"pose":pose,"water_composed":true,"water_coverage_identity":endpoint}
	var prior_proof := {"step":7,"visible_material":{"native_tick":40,"native_sample":9}}
	app.workbench_presentation_frame = {"water_proofs":{0:prior_proof},"poses":{0:pose}}
	context.merge({"mask_frame":{"instances":{11:{"sample":9}}},"mask_native_tick":40})
	check(app._submitted_water_hold(0,old,context)==prior_proof,"the held Water endpoint preserves its original selected physical step")
	context.mask_native_tick = 41
	check(app._submitted_water_hold(0,old,context).is_empty(),"a changed visible native receipt cannot reuse a Water hold")
	context.mask_native_tick = 40
	app.last_uploaded_revision += 1
	check(app._submitted_water_hold(0,old,context).is_empty(),"a new material revision invalidates the held Water endpoint")
	app.last_uploaded_revision -= 1
	context.previous_blend_active = true
	check(app._submitted_water_hold(0,old,context).is_empty(),"crossfade activation invalidates a current-only hold")
	context.previous_blend_active = false
	bridge._epoch += 1
	check(app._submitted_water_hold(0,old,context).is_empty(),"a replacement physical owner cannot retain old Water coverage")
	bridge._body_rids.clear()
	PhysicsServer2D.free_rid(body)
	app.physical_actor_session = null
	session.free()
	app.free()
	coverage_checks_completed = true

func graphical_checks() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color(0.1,0.2,0.3,1)
	background.size = Vector2(128,128)
	viewport.add_child(background)
	var overlay := Overlay.new()
	overlay.outlines = false
	viewport.add_child(overlay)
	var current: Image = picture(3)
	var previous: Image = picture(0)
	var current_texture := ImageTexture.create_from_image(current)
	var previous_texture := ImageTexture.create_from_image(previous)
	var part: Dictionary = {"actor_id":0,"part_id":"body","transform":Transform2D(0,Vector2(3.5,3)),
		"size":Vector2(3,2.5),"color":Color(1.0,0.4,0.2,1),"water_composed":true}
	var body_color: Color = Color(part.color).darkened(0.18)
	for blend: float in [0.0,0.25,0.5,1.0]:
		overlay.set_water_composition({"enabled":true,"current_texture":current_texture,
			"previous_texture":previous_texture,"world_size":Vector2i(8,8),"previous_active":true,"snapshot_blend":blend})
		overlay.present([part],Vector2.ZERO,Vector2i(8,8),Rect2(0,0,128,128))
		await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		var expected: Color = background.color.lerp(body_color,1.0-0.35*blend)
		var actual: Color = pixels.get_pixel(56,48)
		check(absf(actual.r-expected.r)<0.015 and absf(actual.g-expected.g)<0.015 and absf(actual.b-expected.b)<0.015,
			"first-read current/previous Water opacity blend "+str(blend))
	# The native body ends at4.25. Row4's centre4.5 is outside it, but
	# visible polygon pixels at4.09375 overlap that cell and must be clipped.
	for y: int in range(4,8):
		for x: int in range(8): current.set_pixel(x,y,Color(2.0/255.0,0,0,1))
	current_texture.update(current)
	overlay.set_water_composition({"enabled":true,"current_texture":current_texture,
		"previous_texture":previous_texture,"world_size":Vector2i(8,8),"previous_active":true,"snapshot_blend":1.0})
	overlay.present([part],Vector2.ZERO,Vector2i(8,8),Rect2(0,0,128,128))
	await RenderingServer.frame_post_draw
	var clipped: Image = viewport.get_texture().get_image()
	check(clipped.get_pixel(56,65).is_equal_approx(background.color) \
		or color_error(clipped.get_pixel(56,65),background.color)<0.015,"fractional hard floor border is clipped")
	# Old occupied pixels must also clip during an active history blend.
	previous.set_pixel(3,3,Color(1.0/255.0,0,0,1))
	previous_texture.update(previous)
	overlay.present([part],Vector2.ZERO,Vector2i(8,8),Rect2(0,0,128,128))
	await RenderingServer.frame_post_draw
	check(color_error(viewport.get_texture().get_image().get_pixel(56,56),background.color)<0.015,
		"old visible non-Water material clips actor pixels")
	# Repeated real disable/re-enable must release immutable-history bindings,
	# preserve exactly one layer/material, and never leave stale actor pixels.
	var layer_id: int = overlay._water_layer.get_instance_id()
	var material_rid: RID = overlay._water_layer.material.get_rid()
	previous.set_pixel(3,3,Color(3.0/255.0,0,0,1))
	previous_texture.update(previous)
	var stable: bool = true
	var clean_disabled: bool = true
	var restored: bool = true
	for cycle: int in range(12):
		overlay.set_water_composition({})
		overlay.present([part],Vector2.ZERO,Vector2i(8,8),Rect2(0,0,128,128))
		await RenderingServer.frame_post_draw
		clean_disabled = clean_disabled and color_error(viewport.get_texture().get_image().get_pixel(56,48),background.color)<0.015
		stable = stable and overlay._water_layer.get_instance_id()==layer_id \
			and overlay._water_layer.material.get_rid()==material_rid and overlay.get_child_count()==1 \
			and overlay._water_layer.material.get_shader_parameter("current_material")==null \
			and overlay._water_layer.material.get_shader_parameter("previous_material")==null
		overlay.set_water_composition({"enabled":true,"current_texture":current_texture,
			"previous_texture":previous_texture,"world_size":Vector2i(8,8),"previous_active":true,"snapshot_blend":1.0})
		overlay.present([part],Vector2.ZERO,Vector2i(8,8),Rect2(0,0,128,128))
		await RenderingServer.frame_post_draw
		restored = restored and color_error(viewport.get_texture().get_image().get_pixel(56,48),background.color.lerp(body_color,0.65))<0.015
	check(stable,"Water layer and material remain singly owned; disabled histories are unbound")
	check(clean_disabled,"disabled Water layer leaves no retained framebuffer actor pixels")
	check(restored,"re-enabled Water layer has correct first-read opacity on every transition")
	viewport.queue_free()
	await process_frame

func _run() -> void:
	identity_checks()
	independent_authority_checks()
	bounded_water_clearance_checks()
	exact_body_basis_checks()
	coverage_cache_checks()
	check(coverage_checks_completed,"the complete production coverage fixture actually executed")
	var water: Image = picture(3)
	var empty: Image = picture(0)
	check(not proof(water,water,false).safe,"ordinary empty-footprint guard still refuses retained Water")
	check(proof(water,water).safe,"explicit composition admits current and previous Water")
	check(proof(water,empty).safe and proof(empty,water).safe,"dry/wet transitions preserve both histories")
	for material: int in [1,2,4,5,8,10,18,45,60,255]:
		check(not proof(picture(material),water).safe,"current other material refuses "+str(material))
		check(not proof(water,picture(material)).safe,"previous other material refuses "+str(material))
	check(not proof(water,null,true,true,true).safe,"unknown previous history refuses")
	check(not proof(water,water,true,true,false,1).safe,"shared geometry budget is not bypassed")
	if DisplayServer.get_name() != "headless": await graphical_checks()
	print("PUBPRES_WATER_COMPOSITION_RESULT "+JSON.stringify({"checks":checks,"failures":failures,
		"graphical":DisplayServer.get_name() != "headless"}))
	quit(0 if failures.is_empty() else 1)
