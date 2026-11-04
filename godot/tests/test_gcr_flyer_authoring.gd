extends SceneTree

const Fleet=preload("res://scripts/gcr_review_fleet.gd")
const Authoring=preload("res://scripts/gcr_flyer_authoring.gd")
const Controller=preload("res://scripts/gcr_review_fleet_controller.gd")
const FrozenController=preload("res://tests/fixtures/gcr_review_fleet_controller_b759.gd")
const LEGACY_ROWS: Array=[
	[Vector2(4,3),.035,180.,115.,8.,38.,8.,.22,8.,3.],
	[Vector2(7,3),.065,160.,130.,6.,28.,6.,.16,12.,10.],
	[Vector2(9,6),.10,145.,115.,4.8,20.,5.,.35,18.,22.],
	[Vector2(18,3),.14,125.,95.,2.8,12.,4.,.55,23.,36.],
	[Vector2(16,9),.18,110.,90.,2.5,9.,2.5,.38,26.,48.],
	[Vector2(23,10),.24,85.,75.,1.7,5.,1.6,.26,26.,64.],
	[Vector2(30,12),.32,70.,60.,1.15,2.6,1.,.20,28.,82.]]
var checks: int=0
var failures: Array[String]=[]
var file_folder: String="user://gcr-authoring-test-"+str(OS.get_process_id())

class MockRig extends RefCounted:
	var _profile: Dictionary
	var _total_mass: float
	var _inertias: Array=[0.0]
	var _transforms: Array=[Transform2D()]
	var _velocities: Array=[Vector2.ZERO]
	var _angular_velocities: Array=[0.0]
	var boost: bool=false
	var linear:=Vector2.ZERO
	var angular: float=0.0
	func review_boost_held() -> bool: return boost
	func _apply_rig_impulse(value: Vector2) -> void: linear=value
	func _apply_angular_impulse(_index: int,value: float) -> void: angular=value

func _init() -> void: call_deferred("_run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason);push_error(reason)

func mock(index: int) -> MockRig:
	var result:=MockRig.new()
	var definition: Dictionary=Fleet.definition(index)
	result._profile=definition.profile.duplicate(true)
	result._total_mass=float(definition.parts[0].mass)
	result._inertias[0]=float(definition.parts[0].get("inertia",result._total_mass*Vector2(definition.body_size).length_squared()/12.0))
	return result

func action(move:=Vector2.ZERO,trim: float=0.0,brake: bool=false,assist: bool=false,primary: bool=false) -> Dictionary:
	return {"move":move,"aim":Vector2.UP,"effort":1.0,"trim":trim,"primary":primary,"secondary":brake,"auxiliary":assist}

func _catalog_checks() -> void:
	check(Fleet.count()==8 and Fleet.last_error().is_empty(),"eight bounded authoring files load")
	check(Fleet.stable_id(7)=="scooper" and Fleet.index_for_id("scooper")==7,"stable Scooper identity")
	check(not Fleet.valid_index(-1) and not Fleet.valid_index(Fleet.count()),"catalogue index bounds")
	for index: int in range(7):
		check(Fleet.ROWS[index]==LEGACY_ROWS[index],"legacy seven physical/controller scalars unchanged")
		var definition: Dictionary=Fleet.definition(index)
		check(definition.parts.size()==1 and definition.parts[0].shape=="rectangle" and not definition.parts[0].has("collision_rects"),"legacy rectangular construction remains independent")
		check(Fleet.stable_id(index)==Authoring.LEGACY_IDS[index] and Fleet.definition_hash(index).length()==64,"legacy stable identity and resolved hash")
		check(definition.profile.fleet_attitude_gain==10.0 and definition.profile.fleet_attitude_damping==4.0 and definition.profile.fleet_trim_angle==.4,"legacy stabilization defaults unchanged")
	var scoop: Dictionary=Fleet.definition(7)
	check(Fleet.uses_compound(7) and Fleet.collision_rects(7).size()==6 and scoop.parts.size()==1,"Scooper has six shapes on one physical chassis")
	check(scoop.parts[0].mass==.18 and scoop.parts[0].inertia>22.0 and scoop.parts[0].inertia<22.2,"actual lightweight mass and uniform union inertia")
	check(scoop.profile.fleet_torque==1200 and scoop.profile.fleet_attitude_gain==40 and scoop.profile.fleet_attitude_damping==12.5 and scoop.profile.fleet_turn_accel==48 and scoop.profile.fleet_trim_angle==1.2,"registered Scooper angular defaults")
	var moment:=Vector2.ZERO
	var area: float=0.0
	for rectangle: Dictionary in Fleet.collision_rects(7):
		var parcel: float=Vector2(rectangle.size).x*Vector2(rectangle.size).y
		moment+=Vector2(rectangle.center)*parcel
		area+=parcel
	check(area==85.0 and moment.length()<.0001,"compound rectangles are recentered on physical COM")
	check(Fleet.is_hoverboard(3) and Fleet.is_hoverboard(7) and not Fleet.is_hoverboard(4),"control mode is authored independently of roster index")
	var returned: Array=Fleet.collision_rects(7)
	returned[0].center=Vector2(999,999)
	check(Fleet.collision_rects(7)[0].center!=Vector2(999,999),"geometry accessor cannot mutate cached authoring")
	var record: Dictionary=Fleet.authoring_record(7)
	for mutation: Dictionary in [{"unknown":true},{"physics":{"mass":NAN}},{"flight":{"torque_limit":INF}},{"control_mode":"sleep"}]:
		var bad: Dictionary=record.duplicate(true)
		for key: String in mutation:
			if mutation[key] is Dictionary: bad[key].merge(mutation[key],true)
			else: bad[key]=mutation[key]
		check(not Authoring.validate_record(bad).is_empty(),"invalid authoring field refuses")
	var bad: Dictionary=record.duplicate(true)
	bad.hull.rects.append(bad.hull.rects[0].duplicate())
	check(not Authoring.validate_record(bad).is_empty(),"overlapping geometry refuses")
	bad=record.duplicate(true)
	bad.hull.rects=[]
	for index: int in range(9): bad.hull.rects.append([index*2,0,1,1])
	check(not Authoring.validate_record(bad).is_empty(),"shape capacity refuses")
	bad=record.duplicate(true)
	bad.hull.rects[0][2]=0
	check(not Authoring.validate_record(bad).is_empty(),"zero area refuses")
	bad=record.duplicate(true)
	bad.physics.mass=-1
	check(not Authoring.validate_record(bad).is_empty(),"negative actual mass refuses")
	var snapshot: Dictionary=Fleet.registry_snapshot()
	var reordered: Array=snapshot.records.duplicate(true)
	reordered.reverse()
	check(not str(Authoring.registry_from_records(reordered).get("error","")).is_empty(),"legacy stable ordering is explicit")

func _controller_checks() -> void:
	var frozen_text: String=FileAccess.get_file_as_string("res://tests/fixtures/gcr_review_fleet_controller_b759.gd").replace("\r\n","\n")
	check(frozen_text.sha256_text()=="6a9c64d38ab8f9457a139feef5cf9e3f5266d1ec3086098f062f60d367a89e4a","frozen parent controller byte identity")
	var actions: Array=[action(),action(Vector2(.4,-1),.6),action(Vector2(-.7,.6),-.8),action(Vector2(.1,-.2),.2,true),action(Vector2(.3,-.4),0,false,true),action(Vector2(0,.7),.3,false,false,true)]
	for index: int in range(7):
		var current=Controller.new()
		var frozen=FrozenController.new()
		var current_rig: MockRig=mock(index)
		var frozen_rig: MockRig=mock(index)
		for tick: int in range(36):
			for rig: MockRig in [current_rig,frozen_rig]:
				rig._transforms[0]=Transform2D(float(tick%7-3)*.21,Vector2.ZERO)
				rig._velocities[0]=Vector2(tick%5*35.0-50.0,tick%3*20.0-15.0)
				rig._angular_velocities[0]=float(tick%5-2)*.9
				rig.boost=tick%3==1
			var effort: float=.25 if tick%2==0 else 1.0
			current.advance(current_rig,actions[tick%actions.size()],1.0/60.0,effort)
			frozen.advance(frozen_rig,actions[tick%actions.size()],1.0/60.0,effort)
			check(current_rig.linear==frozen_rig.linear and current_rig.angular==frozen_rig.angular,"legacy seven command sequence has exact prior linear/angular requests")
			check(current.observation()==frozen.observation(),"legacy controller telemetry and stateful throttle remain exact")
	for angle: float in [.1,.4,.8]:
		var scoop: MockRig=mock(7)
		var board: MockRig=mock(3)
		scoop._transforms[0]=Transform2D(angle,Vector2.ZERO)
		board._transforms[0]=Transform2D(angle,Vector2.ZERO)
		Controller.new().advance(scoop,action(),1.0/60.0,1.0)
		Controller.new().advance(board,action(),1.0/60.0,1.0)
		check(absf(scoop.angular/float(scoop._inertias[0]))>absf(board.angular/float(board._inertias[0]))*3.5,"Scooper stabilization is stronger after actual inertia accounting")
		check(absf(scoop.angular)<=1200.0/60.0+.000001,"Scooper stabilization remains torque bounded")
	var scoop: MockRig=mock(7)
	Controller.new().advance(scoop,action(Vector2.ZERO,1.0),1.0/60.0,1.0)
	check(scoop.angular>0 and float(scoop._profile.fleet_trim_angle)>1.0,"same Q/E controls can command a spill angle")

func _write_records(records: Array) -> String:
	DirAccess.make_dir_recursive_absolute(file_folder)
	var names: Array=[]
	for index: int in range(records.size()):
		var basename: String="flyer_%d.json" % index
		var file:=FileAccess.open(file_folder.path_join(basename),FileAccess.WRITE)
		file.store_string(JSON.stringify(records[index]))
		names.append(basename)
	var manifest:=FileAccess.open(file_folder.path_join("manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"schema_version":1,"flyers":names}))
	return file_folder.path_join("manifest.json")

func _reload_checks() -> void:
	var snapshot: Dictionary=Fleet.registry_snapshot()
	var original_hash: String=Fleet.registry_hash()
	var changed: Array=snapshot.records.duplicate(true)
	changed[7].flight.force_limit=27.0
	var path: String=_write_records(changed)
	check(Fleet.reload_definitions(path) and Fleet.ROWS[7][8]==27.0 and Fleet.registry_hash()!=original_hash,"explicit file reload resolves changed authored values and hash")
	var changed_hash: String=Fleet.registry_hash()
	changed[7]["unknown_field"]=true
	_write_records(changed)
	check(not Fleet.reload_definitions(path) and Fleet.registry_hash()==changed_hash and Fleet.ROWS[7][8]==27.0,"invalid reload is atomic and retains admitted catalogue")
	check(Fleet.restore_registry(snapshot) and Fleet.registry_hash()==original_hash,"owner rollback restores exact resolved registry")
	check(Fleet.reload_definitions() and Fleet.registry_hash()==original_hash,"source authoring can be deliberately reloaded")

func _key(code: Key) -> void:
	var press:=InputEventKey.new()
	press.keycode=code;press.physical_keycode=code;press.pressed=true
	Input.parse_input_event(press);Input.flush_buffered_events()
	press=InputEventKey.new()
	press.keycode=code;press.physical_keycode=code;press.pressed=false
	Input.parse_input_event(press);Input.flush_buffered_events()

func _room_checks() -> void:
	var scene=load("res://gcr_fleet_playground.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	check(scene._buttons.size()==Fleet.count(),"room roster is derived from catalogue population")
	check(scene.set_spawn_position(Vector2(640.5,120.25)),"safe authoring comparison spawn")
	_key(KEY_8)
	check(scene.selected==7 and scene.runtime._arena.session.bodies().size()==1,"key8 constructs the single-body Scooper")
	check(scene.runtime._arena.session._rigs[0]._profile.fleet_definition_hash==Fleet.definition_hash(7),"actual constructed owner carries definition hash")
	_key(KEY_TAB)
	check(scene.selected==0,"Tab cycles across all eight definitions")
	check(scene.select_preset(7),"Scooper can be selected again")
	var old_owner: int=scene.runtime._arena.get_instance_id()
	var snapshot: Dictionary=Fleet.registry_snapshot()
	var bad: Array=snapshot.records.duplicate(true)
	bad[7]["unknown"]=true
	var path: String=_write_records(bad)
	check(not scene.reload_flyer_definitions(path) and scene.runtime._arena.get_instance_id()==old_owner,"invalid authoring reload preserves actual live owner")
	var changed: Array=snapshot.records.duplicate(true)
	changed[7].flight.force_limit=27.0
	path=_write_records(changed)
	check(scene.reload_flyer_definitions(path) and scene.runtime._arena.get_instance_id()!=old_owner,"valid authored reload rebuilds selected body")
	check(scene.selected==7 and scene.spawn_position==Vector2(640.5,120.25) and scene.applied_controls.response=="LA","reload retains stable craft, saved spawn and response")
	check(scene.runtime._arena.session._rigs[0]._profile.fleet_force==27.0,"reloaded default reaches actual motor profile")
	check(scene.reload_flyer_definitions(),"return to source definitions through explicit reset")
	check(Fleet.registry_hash()==Authoring.load_registry(Fleet.DEFAULT_MANIFEST).registry_hash,"restored authoring identity is source-matched")
	scene.queue_free();await process_frame

func _cleanup() -> void:
	for index: int in range(Fleet.count()): DirAccess.remove_absolute(file_folder.path_join("flyer_%d.json" % index))
	DirAccess.remove_absolute(file_folder.path_join("manifest.json"))
	DirAccess.remove_absolute(file_folder)

func _run() -> void:
	_catalog_checks()
	_controller_checks()
	_reload_checks()
	var catalog_only: bool="--catalog-only" in OS.get_cmdline_user_args()
	if not catalog_only: await _room_checks()
	_cleanup()
	print("GCR_FLYER_AUTHORING ",JSON.stringify({"checks":checks,"failures":failures,"catalog_only":catalog_only,"registry_hash":Fleet.registry_hash()}))
	quit(0 if failures.is_empty() else 1)
