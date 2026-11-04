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

class ClockedLab extends "res://scripts/paired_material_runtime.gd":
	var clock_usec: int = 0
	var measured_native_readbacks: int = 0
	func _observation_clock_usec() -> int:
		return clock_usec
	func _read_tray_snapshot() -> Dictionary:
		measured_native_readbacks+=1
		return super._read_tray_snapshot()

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
	# Shape submission is followed by the real owner's Rapier step/flush.
	# Query the positive fixture after its existing settling window, when
	# Rapier's spatial-query index has consumed the newly authored statics.
	for _tick: int in range(120): arena.step()
	check(not ray(arena,x+.5).is_empty(),"actual Rapier roof ray hits intact patch")
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
	# As for the roof control, use the normal owner step to publish the new
	# static shape to Rapier queries before the positive collision readback.
	arena.step()
	check(not ray(arena,320.5).is_empty(),"Salt wall initially hard")
	check(world.diagnostic_fill_rect(Vector2i(320,255),Vector2i.ONE,3),"one finite Water chemical dose")
	for _tick: int in range(60):
		arena.step()
		if int(world.material_at(320,256))!=133: break
	check(int(world.material_at(320,256))!=133,"native Salt-wall dissolution occurs")
	check(ray(arena,320.5).is_empty(),"chemical conversion retires hard collider")
	check(arena.snapshot().terrain_revision==world.get_hard_surface_revision() and arena.session.bridge.pending_hard_surface_chunks()==0,"chemical hard revision delivered exactly")
	arena.free()

func crust_ray(arena, x: float) -> Dictionary:
	# Ends above the supporting floor: a floor hit cannot impersonate Crust.
	var query := PhysicsRayQueryParameters2D.create(Vector2(x,259.1),Vector2(x,260.9),1)
	var exclusions: Array[RID] = []
	for body: RigidBody2D in arena.session.bodies(): exclusions.append(body.get_rid())
	query.exclude=exclusions
	return arena.session.get_world_2d().direct_space_state.intersect_ray(query)

func newly_cured_collider() -> void:
	var arena = Arena.new()
	root.add_child(arena)
	check(arena.configure(configuration(Vector2(176,200))),"new Crust collider owner")
	if arena.session==null:
		arena.free()
		return
	var world: Object = arena._world
	check(world.diagnostic_fill_rect(Vector2i.ZERO,Vector2i(1024,512),0),"clear cure-collider apparatus")
	check(world.diagnostic_fill_rect(Vector2i(315,261),Vector2i(30,1),1),"floor holds powder outside the query segment")
	check(world.diagnostic_fill_rect(Vector2i(320,260),Vector2i.ONE,135),"real dry target at a chunk seam")
	check(world.diagnostic_fill_rect(Vector2i(330,260),Vector2i.ONE,132),"unchanged neighboring Stone Wall control")
	arena._sync_terrain()
	arena.step()
	check(int(world.material_at(320,260))==135 and crust_ray(arena,320.5).is_empty(),"dry powder does not collide as hard Crust")
	var neighbor_before: Dictionary = crust_ray(arena,330.5)
	check(not neighbor_before.is_empty(),"neighbor is genuinely collidable before cure")
	var before_revision: int = int(world.get_hard_surface_revision())
	check(world.diagnostic_fill_rect(Vector2i(320,259),Vector2i.ONE,3),"one full finite Water cell supplies activation")
	var saw_active: bool = false
	var cure_ticks: int = 0
	for _tick: int in range(240):
		arena.step()
		cure_ticks+=1
		saw_active=saw_active or int(world.material_at(320,260))==136
		if int(world.material_at(320,260))==137: break
	check(saw_active and int(world.material_at(320,260))==137,"native activation/countdown produced new Crust")
	var cured: Dictionary = world.diagnostic_snapshot(Vector2i(315,256),Vector2i(30,8),false)
	check(int(cured.bound_water)==255 and int(cured.total_free_and_bound_water)==255,"real cure retains exactly its255-unit dose")
	check(not arena.snapshot().failed and int(world.get_hard_surface_revision())>before_revision,"cure adds hard terrain without a host failure")
	check(arena.snapshot().terrain_revision==world.get_hard_surface_revision() and arena.session.bridge.pending_hard_surface_chunks()==0,"new Crust revision reaches Rapier before the next step")
	check(not crust_ray(arena,320.5).is_empty(),"newly cured Crust actually collides")
	var neighbor_cured: Dictionary = crust_ray(arena,330.5)
	check(not neighbor_cured.is_empty() and neighbor_cured.get("position")==neighbor_before.get("position") and neighbor_cured.get("normal")==neighbor_before.get("normal"),"neighbor collision geometry unchanged by cure")
	var cured_revision: int = int(world.get_hard_surface_revision())
	check(world.diagnostic_fill_rect(Vector2i(320,260),Vector2i.ONE,0),"explicitly erase newly cured Crust")
	arena.step()
	check(int(world.get_hard_surface_revision())>cured_revision and arena.snapshot().terrain_revision==world.get_hard_surface_revision() and arena.session.bridge.pending_hard_surface_chunks()==0,"erased Crust revision fully admitted")
	check(crust_ray(arena,320.5).is_empty(),"erased Crust no longer collides")
	var neighbor_erased: Dictionary = crust_ray(arena,330.5)
	check(not neighbor_erased.is_empty() and neighbor_erased.get("position")==neighbor_before.get("position") and neighbor_erased.get("normal")==neighbor_before.get("normal"),"neighbor collision geometry unchanged by erase")
	reports.append({"arm":"new-crust-collider","transition":["miss","hit","miss"],"cure_ticks":cure_ticks,"bound_before_erasure":cured.bound_water,"free_and_bound_before_erasure":cured.total_free_and_bound_water,"neighbor_retained":not neighbor_erased.is_empty(),"scope":"closed cure before explicit destruction; erasure is an external bound-Water sink"})
	arena.free()

func observation_throttle() -> void:
	for arm: String in ["idle","held-brush","no-op-brush","paused-held-brush"]:
		var runtime := ClockedLab.new()
		root.add_child(runtime)
		check(runtime.configure_lab(&"arcadelander",0),"throttle real native/Rapier owner: "+arm)
		if not runtime.active():
			runtime.free()
			continue
		runtime.set_paused(arm=="paused-held-brush")
		var accepted_brushes: int = 0
		var last: Dictionary = {}
		for callback: int in range(300):
			runtime.clock_usec=callback*1_000_000/60
			if arm in ["held-brush","paused-held-brush"]:
				accepted_brushes+=int(runtime.paint_lab(Vector2i(870,430),135 if callback%2==0 else 0,1))
			elif arm=="no-op-brush":
				# Empty, outside the tray, admitted paint call with no material change.
				accepted_brushes+=int(runtime.paint_lab(Vector2i(250,200),0,1))
			runtime.step()
			last=runtime.tray_observation()
			var count_before: int = runtime.measured_native_readbacks
			var repeated: Dictionary = runtime.tray_observation()
			check(runtime.measured_native_readbacks==count_before and repeated==last,"same-time presentation cannot spend another observation: "+arm)
		check(accepted_brushes==(0 if arm=="idle" else 300),"all intended brush callbacks exercised: "+arm)
		check(runtime.measured_native_readbacks==10 and int(last.diagnostic_readbacks)==10,"300 callbacks spend exactly10 actual expensive reads: "+arm)
		check(not runtime.failed and bool(last.sample_stale),"cached observation explicitly reports pending state/edits: "+arm)
		check(int(last.sample_tick)==(0 if runtime.paused else 271),"sample tick identifies the last native read, not current presentation: "+arm)
		runtime.clock_usec=5_000_000
		var fresh: Dictionary = runtime.tray_observation()
		check(runtime.measured_native_readbacks==11 and not bool(fresh.sample_stale) and int(fresh.sample_tick)==runtime.tick,"deadline refresh observes the current native state even while paused: "+arm)
		fresh.counts[135]=-1
		check(int(runtime.tray_observation().counts[135])>=0,"caller cannot mutate cached native counts: "+arm)
		reports.append({"arm":"observation-throttle/"+arm,"callbacks":300,"clock_hz":60,"brush_calls":accepted_brushes,"expensive_native_reads":10,"post_deadline_reads":runtime.measured_native_readbacks,"sample_tick":last.sample_tick,"completed_tick":runtime.tick,"clock":"deterministic presentation clock; actual native diagnostics"})
		runtime.free()

func live_room() -> void:
	var runtime := ClockedLab.new()
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
	runtime.clock_usec+=Lab.TRAY_OBSERVATION_INTERVAL_USEC
	var no_dose: Dictionary = runtime.tray_observation()
	check(no_dose.counts[137]==0,"no dose remains: no autonomous curing")
	check(no_dose.total_free_and_bound_water==0,"removed dose leaves no hidden bound or free Water")
	runtime.add_water_dose()
	for _tick: int in range(360): runtime.step()
	runtime.clock_usec+=Lab.TRAY_OBSERVATION_INTERVAL_USEC
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
	check(not bool(runtime.tray_observation().sample_stale),"new owner has a fresh native sample before host failure")
	var reads_before_fault: int = runtime.measured_native_readbacks
	# Inject the existing rig owner's quarantined outcome; do not integrate NaNs
	# or infer a transactional rollback of an interrupted native activation.
	runtime._arena.session._rigs[0].fault="paired lab injected actor quarantine"
	for body: RigidBody2D in runtime._arena.session.bodies(): body.freeze=true
	runtime.step()
	var fault_tick: int = runtime.tick
	check(runtime.failed and not runtime.paint_lab(Vector2i(250,200),135,4) and runtime.add_water_dose().is_empty() and runtime.remove_water_dose().is_empty() and runtime.breach_shell().is_empty(),"quarantined lab refuses authoring and dose operations")
	runtime.step()
	check(runtime.tick==fault_tick,"quarantined lab does not silently retry")
	var waiting: Dictionary = runtime.tray_observation()
	check(bool(waiting.sample_stale) and runtime.measured_native_readbacks==reads_before_fault,"host failure marks an old sample stale without forcing an expensive observation")
	runtime.clock_usec+=Lab.TRAY_OBSERVATION_INTERVAL_USEC
	var fault_sample: Dictionary = runtime.tray_observation()
	check(runtime.failed and not bool(fault_sample.failed) and not bool(fault_sample.sample_stale) and int(fault_sample.sample_age_usec)==0,"fresh sample preserves healthy native authority separately from host quarantine")
	check(runtime.measured_native_readbacks==reads_before_fault+1 and runtime.tray_observation()==fault_sample and runtime.measured_native_readbacks==reads_before_fault+1,"host quarantine retains the ordinary sampling deadline and same-time cache")
	check(runtime.configure_lab(&"jetbarrel",0) and not runtime.failed,"fresh owner is the explicit recovery path")
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
	newly_cured_collider()
	observation_throttle()
	live_room()
	await scene_navigation()
	print("PAIRED_MATERIAL_PLAYGROUND ",JSON.stringify({"checks":checks,"failures":failures,"reports":reports,"scope":"actual synchronous host material/collider and input controls; owner gameplay acceptance remains separate"}))
	quit(0 if failures==0 else 1)
