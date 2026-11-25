extends "res://tests/profile_object_shard_m4_render_control.gd"

# External frozen-application observer: no native/physical state setters.
const QUIET_LINEAR: float = 0.01
const QUIET_ANGULAR: float = 0.001
const QUIET_DRIFT: float = 0.05
const QUIET_ANGLE: float = 0.005
const QUIET_NATIVE_TICKS: int = 120
var body_rid: RID
var quiet_anchor: Transform2D
var running_observations: Dictionary = {}
var rest_history: Array[Dictionary] = []
var first_native: int = -1
var first_body: Dictionary = {}
var result: Dictionary = {}

func _actual() -> Dictionary:
	var pose: Transform2D = PhysicsServer2D.body_get_state(body_rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(body_rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var angular: float = PhysicsServer2D.body_get_state(body_rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	return {"x":pose.origin.x,"y":pose.origin.y,"rotation":pose.get_rotation(),
		"speed":velocity.length(),"vx":velocity.x,"vy":velocity.y,"angular_velocity":angular,
		"sleeping":bool(PhysicsServer2D.body_get_state(body_rid,PhysicsServer2D.BODY_STATE_SLEEPING)),
		"native_tick":f.tick(),"pose":pose}

func _public_state(state: Dictionary) -> Dictionary:
	var value: Dictionary = state.duplicate()
	value.erase("pose")
	return value

func _is_quiet(state: Dictionary) -> bool:
	return state.speed<=QUIET_LINEAR and absf(state.angular_velocity)<=QUIET_ANGULAR \
		and state.pose.origin.distance_to(quiet_anchor.origin)<=QUIET_DRIFT \
		and absf(wrapf(state.rotation-quiet_anchor.get_rotation(),-PI,PI))<=QUIET_ANGLE

func _observe_running_quiet() -> void:
	var state: Dictionary = _actual()
	running_observations.callbacks += 1
	running_observations.maximum_speed = maxf(running_observations.maximum_speed,state.speed)
	running_observations.maximum_abs_angular_velocity = maxf(running_observations.maximum_abs_angular_velocity,absf(state.angular_velocity))
	running_observations.maximum_position_drift = maxf(running_observations.maximum_position_drift,state.pose.origin.distance_to(quiet_anchor.origin))
	running_observations.maximum_angle_drift = maxf(running_observations.maximum_angle_drift,absf(wrapf(state.rotation-quiet_anchor.get_rotation(),-PI,PI)))
	if state.sleeping: running_observations.sleeping_callbacks += 1
	if not _is_quiet(state): running_observations.nonquiet_callbacks += 1

func _run() -> void:
	f = Fixture.new(self)
	result = {"schema":"objectshard-m4-natural-rest-observer-v1","source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"external_observer_sha256":OS.get_environment("CYBERSAND_EXTERNAL_OBSERVER_SHA256"),
		"display_driver":DisplayServer.get_name(),"scene":"tower","canvas_extent":[512,512],"camera":"overview",
		"scope":"frozen ordinary Workbench and actual Rapier; only observation, ordinary support erase/play/pause; no forced pose, velocity, sleep, physics or chemistry suppression",
		"observation_scope":"per-callback actual Rapier state readback plus existing publication coherence observer; headless timing cannot qualify rendered or physical monitor performance",
		"quiet_requirement":{"linear_speed_max":QUIET_LINEAR,"angular_speed_max":QUIET_ANGULAR,
			"position_drift_max":QUIET_DRIFT,"angle_drift_max":QUIET_ANGLE,"native_ticks":QUIET_NATIVE_TICKS}}
	if not await f.open("tower"):
		await _finish_external();return
	f.bench.set_object_shard_diagnostics_enabled(false)
	var initial_inventory: Dictionary = {"wood":f.material_count(7),"brick":f.material_count(43)}
	await f.cut_supports("tower")
	f.play()
	if not await f.until(func():return f.body_count()==1,"ordinary erased supports detach one real tower"):
		await _finish_external();return
	await f.pause()
	if not await f.until(func():return f.runtime().physics_ready() and f.coherent(),"natural-rest observer begins from acknowledged actual body"):
		await _finish_external();return
	var shard_id: int = f.runtime().bridge.bodies.keys()[0]
	first_body = f.runtime().bridge.bodies[shard_id].duplicate()
	body_rid = first_body.rid
	var first: Dictionary = _actual()
	quiet_anchor = first.pose
	result.initial_body = _public_state(first)
	first_native = f.tick()
	f.play()
	var started: int = Time.get_ticks_usec()
	var quiet_begin: int = -1
	var last_report_tick: int = -1
	var reached_quiet: bool = false
	while Time.get_ticks_usec()-started<180000000 and f.tick()-first_native<2400 \
		and str(f.runtime().held_reason).is_empty():
		await process_frame
		var state: Dictionary = _actual()
		if _is_quiet(state):
			if quiet_begin<0:quiet_begin=f.tick()
			if f.tick()-quiet_begin>=QUIET_NATIVE_TICKS:
				reached_quiet=true;break
		else:
			quiet_begin=-1
			quiet_anchor=state.pose
		if last_report_tick<0 or f.tick()-last_report_tick>=60:
			last_report_tick=f.tick()
			var observed:Dictionary=_public_state(state)
			observed.elapsed_usec=Time.get_ticks_usec()-started
			rest_history.append(observed)
			print("NATURAL_REST_PROGRESS ",JSON.stringify(observed))
	result.rest_wait_usec=Time.get_ticks_usec()-started
	result.rest_wait_native_ticks=f.tick()-first_native
	result.rest_history=rest_history
	result.quiet_start_native_tick=quiet_begin
	result.quiet_reached=reached_quiet
	if not f.expect(reached_quiet,"actual Rapier naturally reaches120native ticks of stable quiet motion"):
		await _finish_external();return
	quiet_anchor=_actual().pose
	result.measurement_before=_public_state(_actual())
	running_observations={"callbacks":0,"sleeping_callbacks":0,"nonquiet_callbacks":0,
		"maximum_speed":0.0,"maximum_abs_angular_velocity":0.0,"maximum_position_drift":0.0,"maximum_angle_drift":0.0}
	var before:Dictionary=f.diagnostics()
	process_frame.connect(_observe_running_quiet)
	await _measure("naturally_quiet_playing")
	process_frame.disconnect(_observe_running_quiet)
	var after:Dictionary=f.diagnostics()
	result.measurement_after=_public_state(_actual())
	result.running_quiet_observations=running_observations
	result.window=rows[0]
	result.window.main_stage_deltas={}
	for stage:String in after.main_costs:
		result.window.main_stage_deltas[stage]={"calls":int(after.main_costs[stage].calls)-int(before.main_costs.get(stage,{}).get("calls",0)),
			"usec":int(after.main_costs[stage].usec)-int(before.main_costs.get(stage,{}).get("usec",0))}
	f.expect(not f.host.paused and running_observations.nonquiet_callbacks==0 and running_observations.callbacks>0,"running measurement preserves genuine quiet motion at every observed callback")
	f.expect(f.body_count()==1 and f.runtime().bridge.bodies[shard_id].rid==body_rid \
		and f.runtime().bridge.bodies[shard_id].geometry_revision==first_body.geometry_revision,"same actual body collider and geometry remain owned throughout quiet running")
	await f.pause()
	f.validate_physics()
	await f.validate_quantity_ledger()
	f.expect(initial_inventory=={"wood":f.material_count(7),"brick":f.material_count(43)},"quiet running conserves independent Wood and Brick inventory")
	await _finish_external()

func _finish_external() -> void:
	if f.host != null:
		f.validate_display()
		result.display_coherence=f.display_witness()
		result.final_diagnostics=f.diagnostics()
		await f.close()
	result.checks=f.checks
	result.failures=f.failures
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		if file!=null:
			file.store_string(JSON.stringify(result,"\t")+"\n")
			file.close()
	print(JSON.stringify(result))
	quit(0 if f.failures.is_empty() else 1)
