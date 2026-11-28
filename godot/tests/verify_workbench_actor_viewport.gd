extends SceneTree

const Overlay = preload("res://scripts/physical_actor_overlay.gd")

var errors: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		errors.append(description)
		push_error(description)


func part(id: String, centre: Vector2, extent: Vector2, angle: float = 0.0) -> Dictionary:
	return {"actor_id":7, "part_id":id, "size":extent, "transform":Transform2D(angle,centre),
		"color":Color.RED, "water_composed":true}


func check_pixel(viewport: SubViewport, expected_visible: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var pixel := viewport.get_texture().get_image().get_pixel(6,20)
	check((pixel.r > 0.45 and pixel.g < 0.15) if expected_visible else pixel.r < 0.15,
		"rotated edge pixel after accepted camera change, expected visible=%s" % expected_visible)


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var overlay := Overlay.new()
	overlay.outlines = false
	viewport.add_child(overlay)
	var material_image := Image.create(256,256,false,Image.FORMAT_R8)
	material_image.fill(Color(3.0/255.0,0,0,1))
	var texture := ImageTexture.create_from_image(material_image)
	var water := {"enabled":true, "world_size":Vector2i(256,256), "previous_active":false,
		"current_texture":texture, "previous_texture":texture}
	var origin := Vector2(100,100)
	var extent := Vector2i(32,32)
	var content := Rect2(Vector2.ZERO,Vector2(viewport.size))
	var remote := part("root",Vector2(180,2000),Vector2(12,12))
	var limb := part("limb",Vector2(98,110),Vector2(2,12),PI/2.0)
	overlay.present([remote],origin,extent,content,water)
	check(overlay._water_layer == null and overlay._parts.size() == 1,
		"remote accepted actor preserved without binding Water textures")
	overlay.present([remote,limb],origin,extent,content,water)
	var layer: CyberPhysicalActorOverlay = overlay._water_layer
	check(layer != null and layer.visible and layer._parts.size() == 1
		and layer._parts[0].part_id == "limb","partially visible rotating multipart limb reaches wet layer")
	check(overlay._parts == [remote,limb],"accepted root and limb survive raster filtering")
	var circle := part("wheel",Vector2(98,110),Vector2(8,8))
	circle.shape = "circle"
	check(overlay._may_draw_part(circle),"circular edge reaches clip from outside")
	var plume := part("pilot",Vector2(98,110),Vector2(0.2,0.2))
	check(not overlay._may_draw_part(plume),"remote narrow polygon is outside")
	plume.flight_live = true
	plume.flight_force = Vector2(-400,0)
	check(overlay._may_draw_part(plume),"screen-space flight cue can enter from outside")
	await check_pixel(viewport,true)
	overlay.present([remote,limb],Vector2(150,100),extent,content,water)
	check(not layer.visible and layer._parts.is_empty() and overlay._water_state.is_empty(),
		"moving camera releases obsolete wet polygons and bindings")
	check(layer.material.get_shader_parameter("current_material") == null
		and layer.material.get_shader_parameter("previous_material") == null,"inactive layer releases both textures")
	await check_pixel(viewport,false)
	overlay.present([remote,limb],origin,extent,content,water)
	check(layer == overlay._water_layer and layer.visible and layer._parts.size() == 1,
		"camera reentry reuses the same bounded layer and current drawable limb")
	await check_pixel(viewport,true)
	print("WORKBENCH_ACTOR_VIEWPORT ", JSON.stringify({"checks":checks,"errors":errors,"display":DisplayServer.get_name()}))
	quit(0 if errors.is_empty() else 1)
