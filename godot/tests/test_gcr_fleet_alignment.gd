extends SceneTree

# Exercise the actual room's TextureRect, shader uniforms and polygon projection.
# The oracle asserts KEEP_ASPECT_CENTERED's aspect/centering/maximal-fit contract;
# it deliberately does not duplicate the production min(scale_x,scale_y) formula.
var checks: int = 0
var failures: Array[String] = []
var samples: Array = []
const EPS := 0.002

func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok:
		failures.append(why)
		push_error(why)
		quit(1)
func near(a: Vector2,b: Vector2) -> bool: return a.distance_to(b)<EPS

func check_texture_fit(scene) -> void:
	var fitted: Rect2=scene._content_rect()
	var bounds: Rect2=scene._terrain.get_rect()
	var texture_size: Vector2=scene._terrain.texture.get_size()
	check(scene._terrain.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"actual terrain uses centered aspect fit")
	check(absf(fitted.size.x/fitted.size.y-texture_size.x/texture_size.y)<0.00001,"overlay matches actual material texture aspect, including follow mode")
	check(near(fitted.get_center(),bounds.get_center()),"material/overlay footprint is centered")
	check(bounds.grow(EPS).encloses(fitted),"fitted footprint remains inside actual TextureRect")
	check((absf(fitted.position.x-bounds.position.x)<EPS and absf(fitted.end.x-bounds.end.x)<EPS)
		or (absf(fitted.position.y-bounds.position.y)<EPS and absf(fitted.end.y-bounds.end.y)<EPS),"aspect fit touches one full pair of bounds")
	check(near(scene._overlay.position,fitted.position) and near(scene._overlay.size,fitted.size),"production overlay uses material footprint")
	check(scene._surface._material.get_shader_parameter("camera_origin_px")==scene._overlay._origin,"shader and actor use same clamped camera origin")
	check(scene._surface._material.get_shader_parameter("view_size_px")==scene._overlay._view_size,"shader and actor use same sampled dimensions")
	check(scene._surface._material.get_shader_parameter("view_rect_uv")==Vector4(0,0,1,1),"texture contains the full shader view without another internal inset")
	var part: Dictionary=scene.runtime.render_parts()[0]
	var vertices: PackedVector2Array=scene._overlay.polygon(part)
	var centre:=Vector2.ZERO
	for v: Vector2 in vertices: centre+=v/float(vertices.size())
	centre+=scene._overlay.position
	var actual: Vector2=part.transform.origin
	var origin: Vector2=scene._surface._material.get_shader_parameter("camera_origin_px")
	var view: Vector2=scene._surface._material.get_shader_parameter("view_size_px")
	# The shader samples floor(origin + fittedUV * view). A physical point inside
	# a world cell must fall within that exact material-cell band on both axes.
	var cell: Vector2=actual.floor()
	var band_start: Vector2=fitted.position+(cell-origin)*fitted.size/view
	var band_end: Vector2=fitted.position+(cell+Vector2.ONE-origin)*fitted.size/view
	check(centre.x>=band_start.x-EPS and centre.x<=band_end.x+EPS and centre.y>=band_start.y-EPS and centre.y<=band_end.y+EPS,"actual polygon centre shares the native material cell band")
	check(near(centre,scene._overlay.position+scene._overlay._point(actual)),"decorative marks and physical hull use one projection")
	# Corner projections use the real rotated shape, rather than another pose.
	var half: Vector2=Vector2(part.size)*0.5
	var corners:=PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)])
	for i: int in range(4):
		check(near(vertices[i],scene._overlay._point(part.transform*corners[i])),"rotated hull corner shares material projection")
	samples.append({"follow":scene._follow,"position":actual,"angle":part.transform.get_rotation(),"canvas":scene._canvas.size,"texture":texture_size,"view":view,"origin":origin,"content":fitted,"polygon_centre":centre})

func _run() -> void:
	var scene=load("res://gcr_fleet_playground.tscn").instantiate()
	root.add_child(scene);scene.set_physics_process(false)
	await process_frame
	check(scene.select_preset(2),"actual Kestrel scene is active")
	scene.runtime.set_paused(true)
	var world: Object=scene.runtime._arena._world
	var native_before: String=world.get_physical_state_hash()
	for follow: bool in [false,true]:
		scene._follow=follow
		for size: Vector2 in [Vector2(1234,512),Vector2(913.25,677.5),Vector2(600,900)]:
			# Real Control size/anchor notifications drive the terrain child. Run
			# synchronously so the outer VBox cannot replace this resize fixture.
			scene._canvas.size=size
			for x: float in [40.25,512.25,984.75]:
				for angle: float in [0.0,0.47]:
					scene.runtime._arena.session.bridge.reset_body(0,Vector2(x,445.25),angle)
					scene.runtime._arena.session.bridge.refresh_all_states()
					scene.runtime._arena.session._rigs[0].refresh_observation()
					scene._present(scene.runtime.snapshot(),true)
					check_texture_fit(scene)
					if follow:
						check(scene._view.position.x==(16 if x<100 else 496 if x>900 else 256),"left/center/right camera clamp exercised")
					check(world.get_physical_state_hash()==native_before,"camera/layout changes never mutate native material or clocks")
	check(scene._surface.material_surface_size==Vector2i(992,480),"material surface resolution remains unchanged")
	check(scene._terrain.texture.get_size()==Vector2(992,480),"actual viewport texture retains its original aspect")
	scene.queue_free();await process_frame
	print("GCR_FLEET_ALIGNMENT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples.size(),"scope":"Actual TextureRect/overlay/shader coordinate contract; no GPU pixel or subjective visual acceptance claim"}))
	quit(0 if failures.is_empty() else 1)
