extends SceneTree

# This apparatus deliberately holds the native field after source extraction.
# Actual Rapier moves only through the existing manual-step bridge. It isolates
# witness geometry, initial embedding and deliberate publication schedules;
# the separate asynchronous cohorts own ordinary native/displacement evidence.
const Frozen = preload("res://tests/support/solid_contact_response_749fb8b.gd")
const Current = preload("res://scripts/solid_contact_response.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const Fixture = preload("res://tests/support/solid_contact_synchronized_fixture.gd")
const FIXTURE_PATH: String = "res://tests/fixtures/sol364/synchronized_contacts.json"
const SCHEMA: String = "cybersand.sol364.synchronized-contact.v1"
const STEPS: int = 180
const CLEAR_AREA: float = 0.000001
const CLEAR_DEPTH: float = 0.00002

class RetainedBridge:
	extends Bridge
	func _plan_solid_contact(observation: Dictionary, transform: Transform2D,
			velocity: Vector2, omega: float, mass: float, inertia: float,
			local_centers: PackedVector2Array, sizes: PackedVector2Array) -> Dictionary:
		return Frozen.plan(observation,transform,velocity,omega,mass,inertia,local_centers,sizes)

var checks: int = 0
var failures: Array[String] = []
var workers: int = 1
var report_path: String = ""
var definition: Dictionary = {}
var controls: Array[Dictionary] = []
var case_reports: Array[Dictionary] = []
var geometries: Array[Dictionary] = []
var geometry_index: Dictionary = {}
var native_fields: Dictionary = {}
var source_record: Dictionary = {}
var source_sha256: String = ""

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL SOL364 SYNC ",message)
	return ok

func _geometry_controls() -> void:
	var source := Transform2D(0.0,Vector2(22.75,20.25))
	var current := Transform2D(0.0,Vector2(22.9375,20.25))
	var record := {"proxy":1,"face":2,"cell":Vector2i(20,21),
		"point":Vector2(20.875,21.25),"normal":Vector2.DOWN,
		"a":Vector2(21,21.25),"b":Vector2(20.75,21.25),
		"depth":0.25,"area":0.0625,"weight":0.25}
	var observation := {"schema":"cybersand.sol281.sand-contact.v1","ok":true,"complete":true,
		"sample_serial":1,"token":"23:1","body_generation":"7","tick":19,
		"revision":"31","source_transform":source,"contacts":[record]}
	var centers := PackedVector2Array([Vector2.ZERO])
	var sizes := PackedVector2Array([Vector2(4,2)])
	var fresh: Dictionary = Frozen.plan(observation,source,Vector2(0,12),0.0,520.0,866.6666666666667,centers,sizes)
	var before: Dictionary = Frozen.plan(observation,current,Vector2(0,12),0.0,520.0,866.6666666666667,centers,sizes)
	var after: Dictionary = Current.plan(observation,current,Vector2(0,12),0.0,520.0,866.6666666666667,centers,sizes)
	check(fresh.get("accepted",false),"authenticated source contact accepts before transport")
	check(not before.get("accepted",true) and before.get("outcome")=="ClearedContact",
		"retained planner reproduces midpoint refusal inside quarter-cell drift")
	var actual: Dictionary = Frozen._intersection(current,Vector2.ZERO,Vector2(4,2),Vector2i(20,21))
	check(float(actual.area)>0.0 and absf(float(actual.area)-0.015625)<1e-8,
		"positive exact current intersection survives midpoint leaving cell")
	check(after.get("accepted",false) and not after.get("impulses",[]).is_empty(),
		"candidate uses surviving authenticated current subsegment")
	controls.append(Fixture.json_value({"id":"transported_midpoint","source_pose":source,"current_pose":current,
		"source_observation":observation,"current_area":actual.area,"current_depth":actual.depth,
		"source_accepts":fresh.get("accepted",false),"frozen_result":before,"candidate_result":after,
		"source_span_length":0.25,"current_surviving_span_length":0.0625,
		"old_midpoint_current":Vector2(21.0625,21.25),"vertex_drift":0.1875}))
	var stationary: Dictionary = Frozen.plan(observation,source,Vector2.ZERO,0.0,520.0,866.6666666666667,centers,sizes)
	check(stationary.get("accepted",false) and stationary.get("impulses",[1]).is_empty(),
		"fresh accepted stationary burial has zero corrective impulse")
	controls.append(Fixture.json_value({"id":"stationary_velocity_limit","source_observation":observation,
		"result":stationary,"positive_area":0.0625,"position_work":0.0}))

func _read(body: RigidBody2D) -> Dictionary:
	var rid: RID = body.get_rid()
	var pose: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var omega: float = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	var mass: float = PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_MASS)
	var inertia: float = PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_INERTIA)
	return {"pose":pose,"velocity":velocity,"omega":omega,"mass":mass,"inertia":inertia,
		"kinetic":0.5*mass*velocity.length_squared()+0.5*inertia*omega*omega}

func _state_values(state: Dictionary) -> Dictionary:
	return {"pose":Fixture.pose_values(state.pose),"velocity":[state.velocity.x,state.velocity.y],
		"omega":state.omega,"kinetic":state.kinetic,"mass":state.mass,"inertia":state.inertia,
		"potential":0.0,"potential_scope":"zero gravity causal control","position_work":0.0}

func _finite(state: Dictionary) -> bool:
	return (state.pose as Transform2D).is_finite() and (state.velocity as Vector2).is_finite() \
		and is_finite(float(state.omega)) and is_finite(float(state.kinetic)) \
		and is_finite(float(state.mass)) and is_finite(float(state.inertia))

func _body(parent: Node, source: Dictionary, shapes: Dictionary, spec: Dictionary) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.freeze = true
	body.mass = float(source.mass)
	body.inertia = float(source.inertia)
	body.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector2.ZERO
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.position = (source.center as Vector2)+Vector2(spec.offset[0],spec.offset[1])
	if spec.has("pose_origin"):
		body.position=Vector2(spec.pose_origin[0],spec.pose_origin[1])
	body.rotation = float(spec.angle)
	for index: int in range(shapes.centers.size()):
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = shapes.sizes[index]
		collider.position = shapes.centers[index]
		collider.shape = rectangle
		body.add_child(collider)
	parent.add_child(body)
	return body

func _source(source: Dictionary) -> String:
	var values: Dictionary = {}
	for key: String in ["members","rectangles","center","mass","inertia","payload_digest","shape_digest","member_count","shape_count"]:
		values[key] = Fixture.json_value(source[key])
	var digest: String = JSON.stringify(values).sha256_text()
	if source_record.is_empty():
		source_record = values
		source_sha256 = digest
	check(digest == source_sha256,"every replay arm retains identical native520-cell source payload and six proxies")
	return digest

func _native_field(snapshot: Dictionary) -> String:
	var digest: String = str(snapshot.hash)
	if not native_fields.has(digest):
		var runs: Array = []
		var previous: int = -1
		var count: int = 0
		for material: int in snapshot.cells:
			if material != previous and count>0:
				runs.append([previous,count])
				count=0
			previous=material
			count+=1
		if count>0: runs.append([previous,count])
		native_fields[digest] = {"origin":[0,0],"size":[128,128],"material_runs":runs,
			"counts":snapshot.counts,"water_mass":snapshot.water_mass,"world_state_hash":digest,
			"state_hash_scope":"complete stored material/state_a/state_b/temperature, epochs, tick and world configuration",
			"native_ticks":snapshot.completed_ticks}
	return digest

func _measurement(capture: Dictionary, state: Dictionary, source: Dictionary, shapes: Dictionary, label: String) -> Dictionary:
	var observation: Dictionary = capture.observation
	if not check(observation.get("ok",false) and observation.get("complete",false),label+": complete geometry measurement"):
		return {}
	var geometry: Dictionary = Fixture.geometry(observation,source,shapes,definition.hole_cells)
	var digest: String = JSON.stringify(geometry).sha256_text()
	var index: int
	if geometry_index.has(digest):
		index=int(geometry_index[digest])
	else:
		index=geometries.size()
		geometry_index[digest]=index
		geometry["sha256"]=digest
		geometries.append(geometry)
	var drift: float = 0.0
	for proxy: int in range(shapes.centers.size()):
		for corner: Vector2 in Frozen._corners(shapes.centers[proxy],shapes.sizes[proxy]):
			drift=maxf(drift,((observation.source_transform as Transform2D)*corner).distance_to((state.pose as Transform2D)*corner))
	check(drift<=0.0002,label+": sampled source pose authenticates actual Rapier corners within packed-input roundtrip precision")
	return {"geometry_id":index,"geometry_sha256":digest,"sample_serial":observation.sample_serial,
		"snapshot_serial":observation.snapshot_serial,"native_tick":observation.tick,"revision":observation.revision,
		"token":observation.token,"generation":observation.body_generation,"physics_epoch":observation.physics_epoch,
		"published_usec":observation.published_usec,"rapier_source_corner_drift":drift,
		"overlap_cells":observation.overlap_cells,"overlap_area":observation.overlap_area,
		"sand_overlap_area":observation.sand_overlap_area,"max_penetration":observation.max_penetration,
		"max_sand_penetration":observation.max_sand_penetration,"contact_count":observation.contacts.size(),
		"geometry_probes":observation.geometry_probes,"support_probes":observation.support_probes,
		"owner_ms":capture.owner_ms,"prepare_ms":capture.prepare_ms,"observation_ms":capture.observation_ms,
		"envelope_freeze_ms":capture.envelope_freeze_ms,"native_geometry_ms":observation.get("native_geometry_ms",observation.observation_ms),
		"native_payload_freeze_ms":observation.get("native_payload_freeze_ms",0.0)}

func _plan_values(plan: Dictionary) -> Dictionary:
	var result: Dictionary = {"accepted":plan.get("accepted",false),"outcome":plan.get("outcome","missing")}
	for key: String in ["energy_before","energy_after","energy_tolerance","actual_energy_after","actual_velocity_after",
		"actual_omega_after","velocity","omega","total_impulse","torque_impulse","impulses","contact_count",
		"sample_age","publication_latency_ms","application_ms","readback_valid","failed","maximum_vertex_drift",
		"approaching_count","remaining_approaching_contacts","maximum_remaining_approach_speed","cleared_contact_count"]:
		if plan.has(key): result[key]=Fixture.json_value(plan[key])
	return result

func _matched(observation: Dictionary, state: Dictionary, shapes: Dictionary) -> Dictionary:
	var old: Dictionary = Frozen.plan(observation,state.pose,state.velocity,state.omega,state.mass,state.inertia,shapes.centers,shapes.sizes)
	var candidate: Dictionary = Current.plan(observation,state.pose,state.velocity,state.omega,state.mass,state.inertia,shapes.centers,shapes.sizes)
	return {"velocity_control":_plan_values(old),"candidate":_plan_values(candidate),
		"same_input":true,"scope":"pure planners on the same immutable native observation and actual preapplication state; bridge fences apply separately"}

func _native_interior_control() -> void:
	var fixture: Dictionary = Fixture.create(definition,{"surroundings":"empty"},workers)
	if not check(not fixture.has("error"),"interior control initializes retained native tree"):
		return
	var active: Dictionary = Fixture.activate(fixture)
	if not check(not active.has("error"),"interior control preserves exclusive native aggregate ownership"):
		return
	var source: Dictionary = fixture.source
	_source(source)
	var shapes: Dictionary = Fixture.shape_data(source)
	var world: Object = fixture.world
	# Intentional frozen initial embedding, after extraction. The 3x3 Sand
	# block lies strictly inside one broad crown proxy and crosses no face.
	check(bool(world.diagnostic_fill_rect(Vector2i(47,28),Vector2i(3,3),2)),"strict interior ambient Sand block authored")
	var before: Dictionary = world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128),false)
	var pose := Transform2D(0.0,source.center)
	var capture: Dictionary = Fixture.observe(world,shapes,pose,Vector2.ZERO,0.0,1)
	var observation: Dictionary = capture.observation
	if check(observation.get("ok",false) and observation.get("complete",false),"strictly interior Sand has complete native measurement"):
		var old: Dictionary = Frozen.plan(observation,pose,Vector2.ZERO,0.0,source.mass,source.inertia,shapes.centers,shapes.sizes)
		var candidate: Dictionary = Current.plan(observation,pose,Vector2.ZERO,0.0,source.mass,source.inertia,shapes.centers,shapes.sizes)
		check(int(observation.overlap_cells)==9 and absf(float(observation.sand_overlap_area)-9.0)<1e-7,
			"nine whole native Sand squares are geometrically embedded")
		check(observation.contacts.is_empty(),"strict interior overlap supplies no exterior crossing witness")
		check(old.get("accepted",false) and candidate.get("accepted",false)
			and old.impulses.is_empty() and candidate.impulses.is_empty(),"both planners cannot recover stationary interior embedding")
		var after: Dictionary = world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128),false)
		check(before.hash==after.hash,"interior measurement preserves complete native state hash")
		controls.append(Fixture.json_value({"id":"interior_without_face","source_sha256":source_sha256,
			"geometry":Fixture.geometry(observation,source,shapes,definition.hole_cells),
			"native_field":_native_field(before),"native_state_hash_after":after.hash,
			"velocity_control":_plan_values(old),"candidate":_plan_values(candidate),"position_work":0.0,
			"scope":"intentionally authored stationary burial; proves an interior-witness limitation without claiming identical historical native state"}))
	fixture.clear()
	world=null

func _physical_gates(initial: Dictionary, trace: Array, stats: Dictionary, first_impact: int) -> Dictionary:
	var sustained_start: int = -1
	var clear_run: int = 0
	for row: Dictionary in trace:
		var measured: Dictionary = row.measurement
		var clear: bool = float(measured.sand_overlap_area)<=CLEAR_AREA and float(measured.max_sand_penetration)<=CLEAR_DEPTH
		clear_run=clear_run+1 if clear else 0
		if clear_run>=60 and sustained_start<0: sustained_start=int(row.step)-59
	var clearance: bool = first_impact>=0 and sustained_start>=first_impact and sustained_start<=first_impact+120
	var recurrence: bool = false
	if sustained_start>=0:
		for row: Dictionary in trace:
			if int(row.step)>sustained_start+59 and (float(row.measurement.sand_overlap_area)>CLEAR_AREA \
				or float(row.measurement.max_sand_penetration)>CLEAR_DEPTH): recurrence=true
	var initial_depth: float = float(initial.measurement.max_sand_penetration)
	var embedded: bool = initial_depth>CLEAR_DEPTH
	var allowed_depth: float = initial_depth+0.25 if embedded else 1.0
	return {"newly_proposed":true,"depth_pass":float(stats.max_sand_penetration)<=allowed_depth,
		"initially_embedded":embedded,"initial_depth":initial_depth,"allowed_depth":allowed_depth,
		"sustained_clearance_pass":clearance,"clearance_start_step":sustained_start,"first_valid_impact_step":first_impact,
		"recurrence_pass":not recurrence and sustained_start>=0,"observed_clearance_window_steps":60,
		"response_energy_pass":int(stats.energy_violations)==0,"finite_state_pass":int(stats.nonfinite_states)==0,
		"position_work":0.0,"plausible_motion_acceptance":"not granted by finite-state/energy checks alone",
		"physical_accepted":false,"acceptance_scope":"proposal gates reported separately from execution; no promotion by this apparatus"}

func _case(spec: Dictionary, arm: String) -> void:
	var label: String = str(spec.id)+"/"+arm
	var fixture: Dictionary = Fixture.create(definition,spec,workers)
	if not check(not fixture.has("error"),label+": retained native tree prepares"):
		return
	var source: Dictionary = fixture.source
	_source(source)
	var partition: Dictionary = Fixture.partition(source,definition.hole_cells)
	check(partition.valid and partition.holes_empty and int(partition.shape_count)==6
		and int(source.native_source_members)==520 and bool(source.cut_applied),label+": exact520 payload six proxies and both empty geometry witnesses")
	var shapes: Dictionary = Fixture.shape_data(source)
	var viewport := SubViewport.new()
	viewport.world_2d=World2D.new()
	root.add_child(viewport)
	var body: RigidBody2D = _body(viewport,source,shapes,spec)
	await process_frame
	var bridge: CyberRapierPhysicsBridge = RetainedBridge.new() if arm=="velocity_control" else Bridge.new()
	var bodies: Array[RigidBody2D] = [body]
	if not check(bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(29,38)]))==OK,
		label+": actual main-thread Rapier bridge initializes"):
		viewport.queue_free()
		return
	check(PhysicsServer2D.body_get_shape_count(body.get_rid())==6,label+": actual Rapier owns exact six rectangles")
	var active: Dictionary = Fixture.activate(fixture)
	if not check(not active.has("error"),label+": native source retires after actual body creation"):
		bridge.shutdown()
		viewport.queue_free()
		return
	var world: Object = fixture.world
	var native_before: Dictionary = world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128),false)
	var field: String = _native_field(native_before)
	body.freeze=false
	body.sleeping=false
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(spec.velocity[0],spec.velocity[1]))
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,float(spec.omega))
	bridge.refresh_all_states()
	var initial_state: Dictionary = _read(body)
	var capture: Dictionary = Fixture.observe(world,shapes,initial_state.pose,initial_state.velocity,initial_state.omega,1)
	var initial_measurement: Dictionary = _measurement(capture,initial_state,source,shapes,label+" initial")
	if initial_measurement.is_empty():
		bridge.shutdown()
		viewport.queue_free()
		return
	var initial := {"step":0,"state":_state_values(initial_state),"measurement":initial_measurement}
	var queue: Array[Dictionary] = [capture]
	var delivered_samples: Dictionary = {}
	var trace: Array[Dictionary] = []
	var stats := {"owner_attempts":1,"complete_measurements":1,"published":1,"received":0,"missing":0,
		"overwritten":0,"queue_evictions":0,"response_attempts":0,"response_accepts":0,"response_refusals":{},"response_failures":0,
		"energy_violations":0,"nonfinite_states":0,"overlap_cell_ticks":0,"area_cell_ticks":0.0,
		"sand_area_cell_ticks":0.0,"max_penetration":float(initial_measurement.max_penetration),
		"max_sand_penetration":float(initial_measurement.max_sand_penetration),"positive_steps":0,"longest_positive_run":0,
		"max_speed":(initial_state.velocity as Vector2).length(),"max_abs_omega":absf(float(initial_state.omega)),
		"max_rotation_change":0.0,"max_translation":0.0,"impulse_magnitude_sum":0.0,"torque_impulse_sum":0.0,
		"response_energy_change_sum":0.0,"owner_ms_total":float(capture.owner_ms),"response_ms_total":0.0,
		"rapier_ms_total":0.0,"matched_planner_ms_total":0.0,"queue_latency_ms_max":0.0,"geometry_probes":int(initial_measurement.geometry_probes),
		"support_probes":int(initial_measurement.support_probes),"queue_capacity":3,"queue_peak":1}
	var first_impact: int = -1
	var positive_run: int = 0
	for step: int in range(1,STEPS+1):
		var before: Dictionary = _read(body)
		var delay: int = 1 if spec.schedule=="delay_one" else (2 if spec.schedule=="delay_two" else 0)
		var missing: bool = queue.size()<=delay or (spec.schedule=="drop_every_fourth" and step%4==0)
		var selected: Dictionary = {} if missing else queue[queue.size()-1-delay]
		var receipt: Dictionary = {"delivered":not missing,"outcome":"MissingPublication" if missing else "Delivered"}
		var response: Dictionary = {"accepted":false,"outcome":"MissingPublication" if missing else "DisabledControl","impulses":[]}
		var pair: Dictionary = {}
		var response_ms: float = 0.0
		if missing:
			stats.missing+=1
		else:
			stats.received+=1
			var observation: Dictionary = selected.observation
			delivered_samples[int(observation.sample_serial)]=true
			var age: int = step-int(observation.sample_serial)
			var latency: float = float(Time.get_ticks_usec()-int(observation.published_usec))/1000.0
			receipt={"delivered":true,"source_step":int(observation.sample_serial)-1,"sample_serial":observation.sample_serial,
				"snapshot_serial":observation.snapshot_serial,"tick":observation.tick,"revision":observation.revision,
				"token":observation.token,"generation":observation.body_generation,"physics_epoch":observation.physics_epoch,
				"sample_age":age,"published_usec":observation.published_usec,"received_usec":Time.get_ticks_usec(),"queue_latency_ms":latency}
			stats.queue_latency_ms_max=maxf(float(stats.queue_latency_ms_max),latency)
			var matched_started: int = Time.get_ticks_usec()
			pair=_matched(observation,before,shapes)
			stats.matched_planner_ms_total+=float(Time.get_ticks_usec()-matched_started)/1000.0
			if first_impact<0 and age<=1 and pair.candidate.get("accepted",false) \
					and int(pair.candidate.get("approaching_count",0))>0:
				first_impact=step-1
			if arm!="conservative_baseline":
				stats.response_attempts+=1
				var started: int = Time.get_ticks_usec()
				response=bridge.apply_solid_sand_contact(observation,0,int(observation.snapshot_serial),int(observation.tick),
					int(observation.revision),Fixture.PHYSICS_EPOCH,str(source.token),Fixture.GENERATION,
					int(observation.sample_serial),step,shapes.centers,shapes.sizes)
				response_ms=float(Time.get_ticks_usec()-started)/1000.0
				stats.response_ms_total+=response_ms
				if response.get("accepted",false):
					stats.response_accepts+=1
					if first_impact<0 and not response.get("impulses",[]).is_empty(): first_impact=step-1
				elif not response.get("failed",false):
					var reason: String = str(response.get("outcome","missing"))
					stats.response_refusals[reason]=int(stats.response_refusals.get(reason,0))+1
				if response.get("failed",false): stats.response_failures+=1
				if age>1:
					check(not response.get("accepted",true) and response.get("outcome")=="StaleContactSample",
						label+": deliberate two-step publication refuses before response")
		var after_response: Dictionary = _read(body)
		var energy_delta: float = float(after_response.kinetic)-float(before.kinetic)
		stats.response_energy_change_sum+=energy_delta
		if energy_delta>0.0001*maxf(1.0,float(before.kinetic)): stats.energy_violations+=1
		for action: Dictionary in response.get("impulses",[]):
			stats.impulse_magnitude_sum+=(action.impulse as Vector2).length()
			stats.torque_impulse_sum+=(action.offset as Vector2).cross(action.impulse)
		var rapier_start: int = Time.get_ticks_usec()
		bridge.step()
		var rapier_ms: float = float(Time.get_ticks_usec()-rapier_start)/1000.0
		stats.rapier_ms_total+=rapier_ms
		var after: Dictionary = _read(body)
		if not _finite(before) or not _finite(after_response) or not _finite(after): stats.nonfinite_states+=1
		capture=Fixture.observe(world,shapes,after.pose,after.velocity,after.omega,step+1)
		stats.owner_attempts+=1
		stats.owner_ms_total+=float(capture.owner_ms)
		var measurement: Dictionary = _measurement(capture,after,source,shapes,label+" step"+str(step))
		if measurement.is_empty(): break
		stats.complete_measurements+=1
		stats.published+=1
		stats.geometry_probes+=int(measurement.geometry_probes)
		stats.support_probes+=int(measurement.support_probes)
		stats.overlap_cell_ticks+=int(measurement.overlap_cells)
		stats.area_cell_ticks+=float(measurement.overlap_area)
		stats.sand_area_cell_ticks+=float(measurement.sand_overlap_area)
		stats.max_penetration=maxf(float(stats.max_penetration),float(measurement.max_penetration))
		stats.max_sand_penetration=maxf(float(stats.max_sand_penetration),float(measurement.max_sand_penetration))
		var positive: bool = float(measurement.sand_overlap_area)>CLEAR_AREA or float(measurement.max_sand_penetration)>CLEAR_DEPTH
		positive_run=positive_run+1 if positive else 0
		stats.positive_steps+=int(positive)
		stats.longest_positive_run=maxi(int(stats.longest_positive_run),positive_run)
		stats.max_speed=maxf(float(stats.max_speed),(after.velocity as Vector2).length())
		stats.max_abs_omega=maxf(float(stats.max_abs_omega),absf(float(after.omega)))
		stats.max_rotation_change=maxf(float(stats.max_rotation_change),absf((after.pose as Transform2D).get_rotation()-(initial_state.pose as Transform2D).get_rotation()))
		stats.max_translation=maxf(float(stats.max_translation),(after.pose as Transform2D).origin.distance_to((initial_state.pose as Transform2D).origin))
		trace.append({"step":step,"before":_state_values(before),"receipt":receipt,"matched":pair,
			"response":_plan_values(response),"after_response":_state_values(after_response),"after":_state_values(after),
			"response_energy_change":energy_delta,"response_ms":response_ms,"rapier_ms":rapier_ms,"measurement":measurement})
		queue.append(capture)
		if queue.size()>3:
			var evicted: Dictionary = queue.pop_front()
			stats.queue_evictions+=1
			if not delivered_samples.has(int(evicted.observation.sample_serial)): stats.overwritten+=1
		stats.queue_peak=maxi(int(stats.queue_peak),queue.size())
	check(trace.size()==STEPS and bridge.manual_step_count()==STEPS,label+": every declared Rapier step has a geometry measurement")
	check(stats.energy_violations==0 and stats.nonfinite_states==0 and stats.response_failures==0,
		label+": finite actual states and unchanged post-application energy/readback limits")
	check(stats.owner_attempts==STEPS+1 and stats.complete_measurements==STEPS+1,
		label+": all owner attempts including initial measurement accounted")
	check(stats.received+stats.missing==STEPS,label+": complete explicit publication receipt/missing accounting")
	var remaining_undelivered: int = 0
	for queued: Dictionary in queue:
		if not delivered_samples.has(int(queued.observation.sample_serial)): remaining_undelivered+=1
	stats["remaining_at_end"]=queue.size()
	stats["remaining_undelivered"]=remaining_undelivered
	check(stats.published==stats.received+stats.overwritten+remaining_undelivered,
		label+": every publication is delivered, overwritten before delivery, or retained at end")
	var native_after: Dictionary = world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128),false)
	var retained: Dictionary = world.solid_detachment_command({"action":"inspect"})
	check(native_after.hash==native_before.hash and native_after.cells==native_before.cells,
		label+": complete native state hash and exact material cells conserved across all steps")
	check(retained.members==source.members and int(retained.aggregate_owned)==520
		and int(retained.native_source_members)==0,label+": original exact tuples retain exclusive aggregate ownership")
	check(int(native_after.completed_ticks)==int(native_before.completed_ticks),label+": native integration stayed frozen by design")
	stats["all_attempt_ms_per_complete_measurement"]=(float(stats.owner_ms_total)+float(stats.response_ms_total))/float(stats.complete_measurements)
	case_reports.append({"id":label,"fixture":spec.id,"arm":arm,"steps":STEPS,"workers":workers,
		"source_sha256":source_sha256,"native_field":field,"native_state_hash_after":native_after.hash,
		"native_ticks_before":native_before.completed_ticks,"native_ticks_after":native_after.completed_ticks,
		"native_source_members":retained.native_source_members,"aggregate_owned":retained.aggregate_owned,
		"payload_preserved":retained.members==source.members,"shape_partition":partition,
		"initial":initial,"trace":trace,"stats":stats,"physical_gates":_physical_gates(initial,trace,stats,first_impact),
		"cost_scope":"descriptive synchronized wall intervals; diagnostic matched-planner comparisons excluded and not the registered24-group CPU gate",
		"schedule":spec.schedule,"native_worker_publication":"none: synchronous exclusive native owner and explicit immutable fixture receipt queue",
		"ordinary_native_integration":false})
	bridge.shutdown()
	viewport.queue_free()
	await process_frame
	fixture.clear()
	world=null
	print("SOL364_SYNC_CASE ",label," steps=",trace.size()," max_sand_depth=",stats.max_sand_penetration,
		" positive_steps=",stats.positive_steps," response_accepts=",stats.response_accepts)

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="):
			workers=int(argument.trim_prefix("--workers="))
		elif argument.begins_with("--report="):
			report_path=argument.trim_prefix("--report=")
		elif not argument.begins_with("--") and report_path.is_empty():
			report_path=argument
	check(workers in [1,4],"workers configuration is1or4")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	if not check(parsed is Dictionary,"source-controlled fixture JSON parses"):
		_finish()
		return
	definition=parsed
	check(definition.schema=="cybersand.sol364.synchronized-fixtures.v1" and int(definition.steps)==STEPS
		and definition.fixtures.size()==7 and definition.arms.size()==3,"fixed21-case180-step registered replay inventory")
	check(FileAccess.get_sha256("res://tests/support/solid_contact_response_749fb8b.gd")==definition.frozen_planner_sha256,
		"retained source-qualified planner is exact unchanged bytes")
	_geometry_controls()
	if not check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"RapierPhysicsServer2D"),
		"actual native and Rapier runtime required without fallback"):
		_finish()
		return
	_native_interior_control()
	for spec: Dictionary in definition.fixtures:
		for arm: String in definition.arms:
			await _case(spec,arm)
	check(case_reports.size()==21,"all21registered actual replay cases complete")
	_finish()

func _finish() -> void:
	var hashes: Dictionary = {}
	for path: String in ["res://tests/test_solid_contact_synchronized.gd",
		"res://tests/support/solid_contact_synchronized_fixture.gd","res://tests/support/solid_contact_response_749fb8b.gd",
		FIXTURE_PATH,"res://scripts/solid_contact_response.gd","res://scripts/rapier_physics_bridge.gd"]:
		hashes[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
	var summary := {"schema":SCHEMA,"platform":OS.get_name(),"workers":workers,"checks":checks,"failures":failures,
		"case_count":case_reports.size(),"steps":STEPS,"complete_replay":case_reports.size()==21 and failures.is_empty()}
	var report: Dictionary = summary.duplicate(true)
	report.merge({"engine":Engine.get_version_info().string,"backend":str(ProjectSettings.get_setting("physics/2d/physics_engine","")),
		"input_hashes":hashes,"script_sha256":hashes["tests/test_solid_contact_synchronized.gd"],
		"fixture_sha256":hashes[FIXTURE_PATH.trim_prefix("res://")],
		"frozen_planner_source":"749fb8b597ad866f7535f26442e904207c4f7611",
		"frozen_planner_sha256":hashes["tests/support/solid_contact_response_749fb8b.gd"],
		"current_planner_sha256":hashes["scripts/solid_contact_response.gd"],
		"source":source_record,"source_sha256":source_sha256,"native_fields":native_fields,
		"geometries":geometries,"controls":controls,"cases":case_reports,"fixed_delta":1.0/60.0,
		"contact_columns":["proxy","face","cell_x","cell_y","point_x","point_y","normal_x","normal_y","a_x","a_y","b_x","b_y","depth","area","weight"],
		"proxy_metric_columns":["proxy","area","max_depth","overlap_cells"],
		"pose_columns":["x_axis_x","x_axis_y","y_axis_x","y_axis_y","origin_x","origin_y"],
		"scope":definition.get("scope","incomplete initialization"),
		"overlap_units":"cell-ticks and area-ticks from every post-step measurement; initial step0 reported separately",
		"geometry_scope":"native exact float64 SAT/clipped-square metrics; reported corners reconstruct its published float32 Transform2D; actual Rapier corner roundtrip drift is recorded",
		"timing_scope":"monotonic elapsed work intervals, not operating-system thread CPU; separate original24-group actual-host gate remains mandatory"})
	if not report_path.is_empty():
		var file := FileAccess.open(report_path,FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report))
			file.close()
		else:
			check(false,"requested evidence report opens for writing")
	print("SOL364_SYNCHRONIZED_CONTACT ",JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
