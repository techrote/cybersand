extends SceneTree

# A deterministic test pilot supplies leased controls through the workbench's
# physical session. The actual Main host, preparer, worker, native World and
# manually stepped Rapier space perform all construction, simulation and reads.
const Setup = preload("res://scripts/workbench_setup.gd")
const Fleet = Setup.Fleet
const WATCHDOG_MS := 90000

class PilotHost extends "res://scripts/main.gd":
	var pilot_action: Dictionary = {}
	var pilot_ports := {"q":false,"e":false,"s":false,"boost":false}
	func _publish_workbench_keyboard() -> void:
		if pilot_action.is_empty() or paused or shared_workbench == null or physical_actor_session == null: return
		physical_actor_session.submit_workbench_action(shared_workbench.selected_id(),pilot_action,pilot_ports,false)

var host: Control
var ui: Control
var failures: Array[String] = []
var cases: Array = []
var assertions: int = 0

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, reason: String) -> bool:
	assertions += 1
	if not ok:
		failures.append(reason)
		push_error("WORKBENCH_PHYSICS: " + reason)
	return ok

func wait_for(predicate: Callable, timeout: int = WATCHDOG_MS) -> bool:
	var until := Time.get_ticks_msec() + timeout
	var report_at := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < until:
		if predicate.call(): return true
		if Time.get_ticks_msec() > report_at:
			print("AWAIT ",{"panel":host.shared_workbench.message if host.shared_workbench != null else "absent","micro":host.microscenario_error,"request":host.pending_microscenario_apply.keys(),"lab_status":host.tower_context.get("status","")})
			report_at = Time.get_ticks_msec() + 20000
		if host.simulation_worker.has_failed(): break
		await process_frame
	return false

func recipe(model: String, material: int) -> Dictionary:
	var data := Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	data.actors = [Setup.instance(model,1,Vector2(245,220)),Setup.instance(Setup.BARREL,2,Vector2(340,211))]
	data.selected = 1
	data.next_id = 3
	# Joined hard discs form the same load-bearing floor for powder and prop.
	for x: int in range(125,421,14): data.edits.append([x,282,22,58])
	if model=="scooper":
		data.edits.append([245,212,2,material])
	else:
		for x: int in range(189,295,12): data.edits.append([x,255,17,material])
		data.source=[241,176,material]
	return data

func install(data: Dictionary) -> bool:
	print("INSTALL ",data.actors[0].model," edits=",data.edits.size())
	if not host.paused: ui.toggle_pause()
	var epoch: int = host._physical_epoch
	if not require(ui.apply(data), "prepared scenario request: " + str(ui.message)): return false
	return require(await wait_for(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch>epoch and host.physical_actor_session != null and host._physical_terrain_ready), "native + Rapier adoption: " + str(host.microscenario_error))

func inspect(stats: Dictionary, session: CyberPhysicalActorSession) -> void:
	var actual: Dictionary = session.workbench_actor_state(1)
	var packet: Dictionary = host.tower_context.get("workbench_gcr",{})
	stats.max_rotation=maxf(stats.max_rotation,absf(actual.rotation))
	if not actual.controller.is_empty():
		stats.force=maxf(stats.force,Vector2(actual.controller.applied_force).length())
		stats.torque=maxf(stats.torque,absf(actual.controller.applied_torque))
	if session.bodies().size() > 1 and session.bodies()[1] in session.bodies()[0].get_colliding_bodies():
		stats.barrel_contact_samples = int(stats.get("barrel_contact_samples",0))+1
	if packet.get("response") == "LA-SELECTIVE" and packet.get("valid") and packet.rows.size()==session.bodies().size():
		stats.native_frame = true
		for row: Dictionary in packet.rows:
			if row.instance_id != 1: continue
			stats.normal = maxf(stats.normal,float(row.normal_accepted))
			stats.arrivals = maxi(stats.arrivals,int(row.arrival_count))
			stats.wrench = maxf(stats.wrench,Vector2(row.impulse).length())
			stats.granular_torque = maxf(stats.granular_torque,absf(float(row.torque)))
	var delivery: Dictionary = session.bridge.last_application
	for body: Dictionary in delivery.get("bodies",[]):
		if body.get("instance_id") == 1:
			stats.delivered = maxf(stats.delivered,Vector2(body.impulse).length())
			stats.delivered_torque = maxf(stats.delivered_torque,absf(float(body.torque)))
		elif body.get("refusal","") == "age": stats.age_drops += 1
	stats.max_y = maxf(stats.max_y,actual.position.y)
	stats.min_y = minf(stats.min_y,actual.position.y)
	stats.end = [actual.position.x,actual.position.y]

func phase(ticks: int, action: Dictionary, stats: Dictionary) -> bool:
	host.pilot_action = action
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var first: int = session.tick
	var until := Time.get_ticks_msec()+WATCHDOG_MS
	var observed: int = -1
	while session.tick < first+ticks and Time.get_ticks_msec()<until and not host.simulation_worker.has_failed():
		await process_frame
		if session.tick != observed:
			inspect(stats,session)
			observed=session.tick
	print("PHASE ",stats.case," ",session.tick-first," ticks ",stats.end)
	return require(session.tick>=first+ticks,"Rapier/worker progressed "+str(ticks)+" steps ("+str(session.tick-first)+")")

func stats_for(kind: String) -> Dictionary:
	return {"case":kind,"native_frame":false,"force":0.0,"torque":0.0,"max_rotation":0.0,
		"normal":0.0,"wrench":0.0,"arrivals":0,"granular_torque":0.0,"delivered":0.0,"delivered_torque":0.0,
		"age_drops":0,"max_y":-INF,"min_y":INF,"end":[]}

func burial(material: int) -> void:
	var label := "Sand" if material==2 else "Dust"
	if not await install(recipe("kestrel",material)): return
	var s := stats_for(label+" burial")
	cases.append(s)
	if not require(ui.toggle_pause(),"begin ordinary powder play"): return
	# Unpowered landing on the authored bed, then a true material burst/stream.
	if not await phase(120,{},s): return
	s.landed_y = s.end[1]
	require(ui.burst() and ui.stream(true),"bounded Burst and Stream requested")
	if not await phase(80,{},s): return
	s.source = host.tower_context.get("workbench_source",{}).duplicate(true)
	require(int(s.source.get("inserted",0))>0,"source inserted native powder")
	ui.stream(false)
	ui.toggle_pause()
	var fresh := await wait_for(func() -> bool:
		return host.latest_snapshot.paused and host.latest_snapshot.world_revision == host.latest_snapshot.simulation_world_revision and host.last_uploaded_render_snapshot_serial >= host.latest_snapshot.render_snapshot_serial)
	var state: Dictionary = host.physical_actor_session.workbench_actor_state(1)
	var pose := Transform2D(state.rotation,state.position)
	var sides := {"overhead":0,"left":0,"right":0,"under":0}
	for y: int in range(-12,13):
		for x: int in range(-13,14):
			var sample := Vector2i((pose * (Vector2(x,y) + Vector2(0.5,0.5))).floor())
			if host.image.get_pixel(sample.x,sample.y).r8!=material: continue
			if absi(x)<=4 and y < -3: sides.overhead += 1
			if absi(x)<=4 and y >= 3: sides.under += 1
			if x<=-5 and absi(y)<=3: sides.left += 1
			if x>=5 and absi(y)<=3: sides.right += 1
	s.burial_grains = sides
	require(fresh and sides.overhead>0 and sides.left>0 and sides.right>0 and sides.under>0,label+" material actually surrounds the landed flyer")
	ui.toggle_pause()
	host.pilot_ports.boost = true
	if not await phase(75,{"move":Vector2(0.6,-1),"trim":0.6,"primary":true,"effort":1.0},s): return
	host.pilot_ports.boost = false
	require(s.native_frame and s.normal>0 and s.wrench>0 and s.delivered>0,label+" passive bearing and delivered granular response")
	require(s.force>0 and s.torque>0,label+" powered force and torque")
	require(s.end[1] < s.landed_y,label+" can lift out of contact")
	s.barrel_end = host.physical_actor_session.workbench_actor_state(2).position
	s.native_ticks=host.latest_snapshot.tick_index
	host.pilot_action.clear()
	ui.toggle_pause()

func synchronized_cavity(stats: Dictionary, field: String) -> void:
	# The displayed cells and the Rapier pose have independent clocks. Pause
	# through the public UI, then wait for Main to consume the terminal native
	# publication so a moving cup isn't compared with a previous render.
	if not require(ui.toggle_pause(),"pause to read "+field): return
	var latest_tick: int = host.latest_snapshot.tick_index
	var ready := await wait_for(func() -> bool:
		var snap: CyberSimulationSnapshot = host.latest_snapshot
		return snap.paused and snap.tick_index>=latest_tick and snap.world_revision==snap.simulation_world_revision and host.last_uploaded_render_snapshot_serial>=snap.render_snapshot_serial)
	if require(ready,"current material publication at "+field):
		var inventory := load_inventory()
		var snap: CyberSimulationSnapshot = host.latest_snapshot
		var packet: Dictionary = snap.lab_context.get("workbench_gcr",{})
		var row: Dictionary = packet.get("rows",[{}])[0]
		var sampled: Dictionary = host.physical_actor_session.bridge.sampled_pose(1,int(row.get("sample",-1)))
		var frame: Dictionary = host.workbench_display_frame()
		var shown: Dictionary = frame.get("instances",{}).get(1,{})
		var identity := {"frame_tick":frame.get("tick",-1),"sample_tick":packet.get("sample_tick",-1),"completed_tick":snap.tick_index,
			"render_tick":snap.render_tick_index,"revision":snap.world_revision,"uploaded_revision":host.last_uploaded_revision,
			"world_generation":snap.render_world_generation,"uploaded_generation":host.last_uploaded_world_generation,
			"render_serial":snap.render_snapshot_serial,"uploaded_serial":host.last_uploaded_render_snapshot_serial,
			"session":packet.get("session",-1),"epoch":packet.get("epoch",-1),"instance":row.get("instance_id",-1),
			"generation":row.get("generation",-1),"sample":row.get("sample",-1)}
		stats[field+"_identity"] = identity
		var bound: bool = packet.get("valid",false) and row.get("instance_id")==1 and row.get("generation")==host._physical_epoch \
			and row.get("sample")==shown.get("sample",-1) and row.get("generation")==shown.get("generation",-1) \
			and sampled.get("session")==packet.get("session") and sampled.get("epoch")==packet.get("epoch") \
			and frame.get("session")==packet.get("session") and frame.get("epoch")==host._physical_epoch \
			and frame.get("tick")==snap.tick_index and frame.get("sample_tick")==packet.sample_tick \
			and snap.tick_index-int(packet.sample_tick) in [0,1] and snap.render_tick_index <= snap.tick_index \
			and frame.get("world_generation")==host.last_uploaded_world_generation and frame.get("revision")==host.last_uploaded_revision \
			and snap.render_world_generation==host.last_uploaded_world_generation and snap.world_revision==host.last_uploaded_revision \
			and snap.render_snapshot_serial==host.last_uploaded_render_snapshot_serial \
			and sampled.has("pose") and shown.has("pose") and Transform2D(shown.pose).is_equal_approx(sampled.pose)
		if require(bound,"display/census owner, sample and uploaded material identity at "+field):
			stats[field+"_sampled_material"] = load_inventory(shown.pose)
			var displayed: Array = host.physical_actor_session.render_parts(frame)
			var collider: CollisionShape2D = host.physical_actor_session.bodies()[0].get_child(0)
			require(Transform2D(displayed[0].transform).is_equal_approx(Transform2D(shown.pose)*collider.transform),"overlay uses matched sample at "+field)
		stats[field] = inventory.cavity
		stats[field+"_material"] = inventory
		stats[field+"_native_tick"]=host.latest_snapshot.tick_index
	if field=="carried" and not OS.get_environment("CYBERSAND_WORKBENCH_FRAME_PNG").is_empty() and DisplayServer.get_name()!="headless":
		ui.focus_selected()
		host.update_worker_frame_state()
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		require(shot != null and shot.save_png(OS.get_environment("CYBERSAND_WORKBENCH_FRAME_PNG")) == OK,"save graphical carry frame")
	require(ui.toggle_pause(),"resume after "+field)


func load_inventory(sample_pose: Variant = null) -> Dictionary:
	# Total all Sand material ids in this 512-cell case, including every cell
	# that slipped through the hull or was temporarily above the open rim.
	var state: Dictionary = host.physical_actor_session.workbench_actor_state(1)
	var pose: Transform2D = sample_pose if sample_pose is Transform2D else Transform2D(state.rotation,state.position)
	var index := Fleet.index_for_id("scooper")
	var com: Vector2 = Fleet.Authoring.resolve_record(Fleet.authoring_record(index)).resolved_com
	var inverse := pose.affine_inverse()
	var bytes: PackedByteArray = host.image.get_data()
	var side: int = host.image.get_width()
	var channels: int = bytes.size()/(side*host.image.get_height())
	var result := {"total":0, "cavity":0, "above_rim":0, "inside_solid":0, "below_floor":0,
		"mean_x":0.0,"mean_y":0.0,"pose":[pose.origin.x,pose.origin.y,pose.get_rotation()],"points":[]}
	for offset: int in range(0,bytes.size(),channels):
		if bytes[offset] != 2: continue
		var pixel: int = offset/channels
		var center := Vector2(pixel%side+0.5,pixel/side+0.5)
		var local: Vector2 = inverse*center
		var raw := local+com
		result.total += 1
		result.mean_x += center.x
		result.mean_y += center.y
		result.points.append([center.x,center.y])
		if raw.x >= -12 and raw.x < 15 and raw.y >= -8 and raw.y < 0: result.cavity += 1
		if raw.x >= -12 and raw.x < 15 and raw.y < -8: result.above_rim += 1
		if raw.y >= 4: result.below_floor += 1
		for rect: Dictionary in Fleet.collision_rects(index):
			if Rect2(rect.center-rect.size*0.5,rect.size).has_point(local):
				result.inside_solid += 1
				break
	if result.total > 0:
		result.mean_x /= result.total
		result.mean_y /= result.total
	return result

func scoop() -> void:
	if not await install(recipe("scooper",2)): return
	var s := stats_for("Scooper native load and tilt")
	cases.append(s)
	var session: CyberPhysicalActorSession = host.physical_actor_session
	s.shape_count = session.bodies()[0].get_child_count()
	s.drawn_pieces = session.render_parts().filter(func(part: Dictionary) -> bool: return part.actor_id == 0).size()
	require(s.shape_count==5 and s.drawn_pieces==5 and session.bodies().size()==2,"five visible U pieces on one body plus passive prop")
	require(ui.toggle_pause(),"begin ordinary Scooper play")
	if not await phase(75,{"move":Vector2.ZERO,"effort":1.0},s): return
	await synchronized_cavity(s,"loaded")
	var start: Vector2 = session.workbench_actor_state(1).position
	if not await phase(35,{"move":Vector2(0,-1),"primary":true,"effort":1.0},s): return
	await synchronized_cavity(s,"lifted")
	s.lift_distance = start.y - session.workbench_actor_state(1).position.y
	if not await phase(25,{"move":Vector2(0.55,0),"effort":1.0},s): return
	await synchronized_cavity(s,"lateral_start")
	# Continue carrying until the sidewall has crossed the initial load width.
	# Retain the intermediate hull-intersection count as well as final losses.
	if not await phase(65,{"move":Vector2(0.55,0),"effort":1.0},s): return
	await synchronized_cavity(s,"carried")
	s.carry_x = session.workbench_actor_state(1).position.x-start.x
	host.pilot_ports.e = true
	if not await phase(90,{"move":Vector2.ZERO,"trim":1.0,"effort":1.0},s): return
	host.pilot_ports.e = false
	await synchronized_cavity(s,"after_tip")
	s.tip_rotation = session.workbench_actor_state(1).rotation
	s.barrel_end = session.workbench_actor_state(2).position
	require(s.loaded_sampled_material.cavity>0 and s.lifted_sampled_material.cavity>0 and s.lift_distance>1.0 and s.carry_x>13.0 and s.carried_material.mean_x-s.loaded_material.mean_x>13.0 and s.carried_sampled_material.cavity>0,"real native load lifts and carries")
	require(absf(s.tip_rotation)>0.4,"deliberate Q/E tip")
	s.native_ticks=host.latest_snapshot.tick_index
	host.pilot_action.clear()
	ui.toggle_pause()

func mixed_impact() -> void:
	var data := recipe("scooper",2)
	data.edits.pop_back()
	data.actors[0].spawn = [245,235]
	data.actors[1].spawn = [245,200]
	data.actors.append(Setup.instance("needle",3,Vector2(345,230)))
	data.actors[2].options.mass_multiplier = 4.0
	data.actors[2].options.inertia_multiplier = 0.5
	data.actors[2].options.budget = 5.0
	data.actors[0].options.budget = 40.0
	# The ordinary .18-mass/23-force flyer's ceiling cannot lift a mass-one
	# reference barrel (92.12 gravity). Use the same admitted instance controls
	# available in Details for this loaded interaction.
	data.actors[0].options.mass_multiplier = 8.0
	data.actors[0].options.thrust_multiplier = 8.0
	data.next_id = 4
	if not await install(data): return
	var s := stats_for("mixed body impact")
	cases.append(s)
	require(ui.toggle_pause(),"begin ordinary mixed-body impact")
	if not await phase(100,{"move":Vector2.ZERO,"effort":1.0},s): return
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var original_actor := session.workbench_actor_state(1)
	var barrel := session.workbench_actor_state(2)
	s.first_y = original_actor.position.y
	s.barrel_y = barrel.position.y
	s.needle = session.workbench_actor_state(3)
	var rows: Array = host.tower_context.get("workbench_gcr",{}).get("rows",[])
	require(rows.size()==3 and rows[0].budget==40.0 and rows[1].budget==20.0 and rows[2].budget==5.0,"same native World with independent budgets")
	require(s.get("barrel_contact_samples",0)>0 and s.barrel_y>200 and s.barrel_y<254,"passive barrel actually collides with U, above the distant hard floor")
	# Lift the contacted barrel using the Scooper's existing propulsion.
	if not await phase(65,{"move":Vector2(0,-1),"primary":true,"effort":1.0},s): return
	var lifted_barrel := session.workbench_actor_state(2)
	s.barrel_lift = s.barrel_y-lifted_barrel.position.y
	require(s.barrel_lift>1.0,"contacted passive barrel moves upward under flyer actuation")
	require(ui.select_instance(3),"pilot handover")
	if not await phase(25,{"move":Vector2(0,-1),"primary":true,"effort":1.0},s): return
	var needle: Dictionary = session.workbench_actor_state(3)
	var scoop_state: Dictionary = session.workbench_actor_state(1)
	require(needle.controller.applied_force.length()>0 and scoop_state.controller.applied_force==Vector2.ZERO,"selected Needle receives distinct thrust and Scooper lease retires")
	host.pilot_action.clear()
	ui.toggle_pause()


func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(PilotHost)
	root.add_child(host)
	ui=host.shared_workbench
	if require(await wait_for(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty()),"open default workbench: "+str(host.microscenario_error)):
		ui=host.shared_workbench
		if OS.get_cmdline_user_args().has("--capture-scooper"):
			await scoop()
		else:
			await burial(2)
			await burial(14)
			await scoop()
			await mixed_impact()
	host.queue_free()
	await process_frame
	await process_frame
	var record := {"case":"WORKBENCH_001 shared physics","assertions":assertions,"failures":failures,"results":cases}
	var output: String = OS.get_environment("CYBERSAND_WORKBENCH_PHYSICS_REPORT")
	if not output.is_empty():
		var handle := FileAccess.open(output,FileAccess.WRITE)
		if handle != null: handle.store_string(JSON.stringify(record,"\t"))
	print("WORKBENCH_PHYSICS ",JSON.stringify(record))
	quit(int(not failures.is_empty()))
