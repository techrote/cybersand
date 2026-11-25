extends SceneTree

const Coherence = preload("res://scripts/workbench_presentation_coherence.gd")
const Composition = preload("res://scripts/workbench_water_composition.gd")
const Overlay = preload("res://scripts/physical_actor_overlay.gd")
var checks: int = 0
var failures: Array[String] = []

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
