extends SceneTree

# Source-matched actual native/Rapier apparatus. Counts are not substitutes for
# physics collision retirement; ray queries exclude every actor body RID.
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Lab = preload("res://scripts/paired_material_runtime.gd")
const Fixture = preload("res://scripts/paired_material_fixture.gd")
var checks: int = 0
var failures: int = 0
var reports: Array = []

func _init() -> void: call_deferred("run")
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("Paired material lab: "+reason)

func configuration(spawn: Vector2=Vector2(328,230)) -> Dictionary:
	return {"version":Arena.VERSION,"seed":0,"max_ticks":2000,"local_patch_radius":0,
		"actors":[{"model":"arcadelander","producer":"human","position":spawn}]}

func ray(arena, x: float) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(Vector2(x,254.5),Vector2(x,261.5),1)
	var exclusions: Array[RID] = []
	for body: RigidBody2D in arena.session.bodies(): exclusions.append(body.get_rid())
	query.exclude=exclusions
	return arena.session.get_world_2d().direct_space_state.intersect_ray(query)

func body_y(arena) -> float:
	return Transform2D(PhysicsServer2D.body_get_state(arena.session.bodies()[0].get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)).origin.y

func roof_release(x: int) -> void:
	var arena = Arena.new()
	root.add_child(arena)
	check(arena.configure(configuration(Vector2(x,230))),"real roof owner config")
	if arena.session==null:
		arena.free()
		return
	var world: Object = arena._world
	check(world.diagnostic_fill_rect(Vector2i.ZERO,Vector2i(1024,512),0),"clear inherited authoring")
	check(world.diagnostic_fill_rect(Vector2i(x-40,256),Vector2i(80,4),132),"new Stone wall roof")
	check(world.diagnostic_fill_rect(Vector2i(x-40,272),Vector2i(80,24),13),"powder below12cell airgap")
	check(world.diagnostic_fill_rect(Vector2i(x-40,296),Vector2i(80,4),1),"deep measured floor")
	arena._sync_terrain()
	check(not ray(arena,x+.5).is_empty(),"actual Rapier roof ray hits intact patch")
	for _tick: int in range(120): arena.step()
	var before: float = body_y(arena)
	check(not arena.snapshot().failed and before<256,"intact hard roof supports actual body")
	var revision: int = int(world.get_hard_surface_revision())
	check(world.diagnostic_fill_rect(Vector2i(x-20,256),Vector2i(40,4),0),"bounded native roof destruction")
	var state: Dictionary = arena.step()
	check(int(world.get_hard_surface_revision())>revision and int(state.terrain_revision)==int(world.get_hard_surface_revision()),"committed roof revision admitted before Rapier")
	check(arena.session.bridge.pending_hard_surface_chunks()==0,"terrain queue drained at synchronous boundary")
	check(ray(arena,x+.5).is_empty(),"removed patch no longer collides in actual Rapier space")
	check(not ray(arena,x-30+.5).is_empty(),"neighboring uncut roof remains collidable")
	for _tick: int in range(120): arena.step()
	var after: float = body_y(arena)
	check(not arena.snapshot().failed and after>before+4.,"body falls into cleared airgap after support removal")
	reports.append({"arm":"roof-release","x":x,"before_y":before,"after_y":after,"gap":12,"window_ticks":120,"terrain_revision":arena.snapshot().terrain_revision})
	var view: Dictionary = arena.observation(0)
	var stale: Dictionary = Session.make_command(view,int(view.last_sequence)+1,{"move":Vector2.ZERO})
	check(arena.reset(),"fresh reset admitted")
	check(not arena.submit(stale,&"human"),"reset refuses retired command identity")
	arena.free()

func chemical_retirement() -> void:
	var arena = Arena.new()
	root.add_child(arena)
	check(arena.configure(configuration(Vector2(176,200))),"chemical retirement owner")
	var world: Object = arena._world
	check(world.diagnostic_fill_rect(Vector2i.ZERO,Vector2i(1024,512),0),"clear chemical control")
	check(world.diagnostic_fill_rect(Vector2i(320,256),Vector2i.ONE,133),"single Salt wall at chunk seam")
	arena._sync_terrain()
	check(not ray(arena,320.5).is_empty(),"Salt wall initially hard")
	check(world.diagnostic_fill_rect(Vector2i(320,255),Vector2i.ONE,3),"one finite Water chemical dose")
	for _tick: int in range(60):
		arena.step()
		if int(world.material_at(320,256))!=133: break
	check(int(world.material_at(320,256))!=133,"native Salt-wall dissolution occurs")
	check(ray(arena,320.5).is_empty(),"chemical conversion retires hard collider")
	check(arena.snapshot().terrain_revision==world.get_hard_surface_revision() and arena.session.bridge.pending_hard_surface_chunks()==0,"chemical hard revision delivered exactly")
	arena.free()

func live_room() -> void:
	var runtime = Lab.new()
	root.add_child(runtime)
	check(runtime.configure_lab(&"jetbarrel",0),"source-matched full room")
	if not runtime.active():
		check(false,runtime.last_error)
		runtime.free()
		return
	var previous = runtime._arena
	check(not runtime.configure_lab(&"arcadelander",3) and runtime._arena==previous,"bad family preserves existing owner")
	check(runtime._arena.session.bodies().size()>0,"ordinary authored actor exists")
	check(runtime._arena._world.material_at(320,390)==132 and runtime._arena._world.material_at(613,390)==0,"intact/open shell fixtures differ at registered patch")
	var before: Dictionary = runtime.tray_observation()
	check(before.counts[135]==144*24 and before.counts[136]==0 and before.counts[137]==0,"tray starts dry without manufactured activation")
	var dose: Dictionary = runtime.add_water_dose()
	check(dose.changed_cells==16 and dose.added_free_water==16*255,"finite dose native full quantities")
	var removed: Dictionary = runtime.remove_water_dose()
	check(removed.removed_cells==16 and removed.removed_free_water==16*255,"Water removal explicitly accounted before activation")
	for _tick: int in range(200): runtime.step()
	var no_dose: Dictionary = runtime.tray_observation()
	check(no_dose.counts[137]==0,"no dose remains: no autonomous curing")
	check(no_dose.total_free_and_bound_water==0,"removed dose leaves no hidden bound or free Water")
	runtime.add_water_dose()
	for _tick: int in range(360): runtime.step()
	var after: Dictionary = runtime.tray_observation()
	check(after.counts[137]>0 and after.counts[137]<=16,"finite native curing produces a bounded crust")
	check(after.counts[135]+after.counts[136]+after.counts[137]==144*24,"binder parcels retained in contained tray")
	check(after.total_free_and_bound_water==16*255 and after.bound_water>0,"actual host closes free-plus-bound Water exactly after curing")
	reports.append({"arm":"playable-tray","crust":after.counts[137],"activated":after.counts[136],"free_water":after.water_mass,"bound_water":after.bound_water,"free_and_bound":after.total_free_and_bound_water,"supplied_cells":16})
	var view: Dictionary = runtime.observation()
	var command: Dictionary = Session.make_command(view,int(view.last_sequence)+1,{"move":Vector2.UP,"primary":true})
	check(runtime.submit(command),"ordinary leased actor input")
	runtime.set_paused(true)
	var old_tick: int = runtime.tick
	runtime.step()
	check(runtime.tick==old_tick and runtime.observation().lease_remaining==0,"pause cancels input and does not advance")
	runtime.set_paused(false)
	check(runtime.configure_lab(&"arcadelander",2),"new material family and actor")
	check(not is_instance_valid(previous) and not runtime.submit(command),"fresh room frees owner and refuses retired command")
	check(runtime.breach_shell().accepted,"bounded roof button reaches native owner")
	check(runtime.paint_lab(Vector2i(250,200),135,4) and runtime.paint_lab(Vector2i(250,200),0,4),"ordinary paint/erase kept")
	check(not runtime.paint_lab(Vector2i(250,200),136,4),"internal activated state is not a painting shortcut")
	var old_web: Variant = ProjectSettings.get_setting("cybersand/web_demo",false)
	ProjectSettings.set_setting("cybersand/web_demo",true)
	check(not Lab.supported(),"Web policy refuses lab despite loaded native symbols")
	ProjectSettings.set_setting("cybersand/web_demo",old_web)
	runtime.free()

func scene_navigation() -> void:
	var menu: Control = load("res://feature_launcher.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await process_frame
	menu.launch("paired_materials")
	await process_frame
	await process_frame
	var scene: Node = current_scene
	check(scene!=null and scene.scene_file_path=="res://paired_material_playground.tscn" and scene.runtime.active(),"launcher opens the native-only live scene")
	if scene!=null and scene.has_method("_can_control"):
		scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		check(not scene._can_control() and scene._rearm,"focus loss cancels and requires neutral rearm")
		var old_owner=weakref(scene.runtime._arena)
		root.get_node("FeatureNavigation").return_to_launcher()
		await process_frame
		await process_frame
		check(current_scene.scene_file_path=="res://feature_launcher.tscn" and old_owner.get_ref()==null,"F2 return tears down the previous owner")
	if current_scene!=null:
		current_scene.queue_free()
		current_scene=null
	await process_frame

func run() -> void:
	check(Lab.supported(),"paired-material native runtime required")
	if failures:
		quit(1)
		return
	roof_release(328)
	roof_release(320)
	chemical_retirement()
	live_room()
	await scene_navigation()
	print("PAIRED_MATERIAL_PLAYGROUND ",JSON.stringify({"checks":checks,"failures":failures,"reports":reports,"scope":"actual synchronous host material/collider and input controls; owner gameplay acceptance remains separate"}))
	quit(0 if failures==0 else 1)
