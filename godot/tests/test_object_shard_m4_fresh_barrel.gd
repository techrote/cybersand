extends "res://tests/test_object_shard_m4_remote_barrel.gd"

# Freshly attached and paused Tower: no long settling precondition. Compare
# ordinary gravity/contact with two distant structural cutting schedules.
var scenarios: Array[Dictionary] = []
var accumulated_checks: int = 0
var accumulated_failures: Array[String] = []
var minimum_y: float = INF
var maximum_y: float = -INF
var sample_count: int = 0
var structures_disabled: bool = false

func _run() -> void:
	for mode: String in ["structures_disabled", "pristine", "cut_before_resume", "cut_after_four_ticks"]:
		await _fresh_case(mode)
	if scenarios.size()==4:
		var baseline: Dictionary = scenarios[0]
		for index: int in [1,2,3]:
			var cut: Dictionary = scenarios[index]
			accumulated_checks += 2
			if float(cut.maximum_upward_speed_cells_s)>float(baseline.maximum_upward_speed_cells_s)+1.0:
				accumulated_failures.append(str(cut.mode)+" acquired upward speed absent from the no-cut control")
			if absf(float(cut.final_y)-float(baseline.final_y))>.25:
				accumulated_failures.append(str(cut.mode)+" did not reach the same ordinary floor contact as the no-cut control")
	await _finish()

func _native_tick() -> int:
	return int(f.host.latest_snapshot.tick_index) if structures_disabled else f.tick()

func _open_disabled() -> bool:
	# Same authored Tower and ordinary physical actor; the experimental owner
	# is never enabled, so its substeps cannot affect this reference fall.
	set_meta("cybersand_feature","shared_workbench")
	f.host = load("res://main.tscn").instantiate()
	root.add_child(f.host)
	if not await f.until(f.installed,"Structures-disabled ordinary Workbench installed"): return false
	f.bench = f.host.shared_workbench
	if not f.expect(f.bench.apply(Fixture.Scenes.create("tower",PackedInt32Array(f.bench.applied.liquid_policy))),
		"Structures-disabled reference uses exactly the same Tower recipe"): return false
	if not await f.until(f.installed,"Structures-disabled authored Tower installed"): return false
	f.bench.set_camera(2)
	await _pause_disabled()
	return f.expect(not f.runtime().enabled and f.host.paused,"ordinary reference is paused without ever enabling Structures")

func _pause_disabled() -> void:
	if not f.host.paused: f.bench.toggle_pause()
	var request: int = f.host.simulation_worker.workbench_pause_request_serial()
	await f.until(func(): return f.host.paused and f.host.latest_snapshot.paused \
		and int(f.host.latest_snapshot.lab_context.get("workbench_pause_ack_serial",-1))>=request,
		"ordinary reference acknowledges its exact Pause")

func _sample() -> void:
	if not monitor or not barrel.is_valid(): return
	var pose: Transform2D = PhysicsServer2D.body_get_state(barrel,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(barrel,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	minimum_y = minf(minimum_y,pose.origin.y)
	maximum_y = maxf(maximum_y,pose.origin.y)
	maximum_displacement = maxf(maximum_displacement,pose.origin.distance_to(reference))
	maximum_upward_speed = maxf(maximum_upward_speed,-velocity.y)
	sample_count += 1
	if observations.size()<16 and velocity.y < -1.0:
		observations.append({"tick":_native_tick(),"x":pose.origin.x,"y":pose.origin.y,"vx":velocity.x,"vy":velocity.y,
			"phase":f.runtime().phase,"bodies":f.body_count()})

func _fresh_case(mode: String) -> void:
	f = Fixture.new(self)
	structures_disabled = mode=="structures_disabled"
	var opened: bool = false
	if structures_disabled: opened = await _open_disabled()
	else: opened = await f.open("tower")
	if not opened:
		accumulated_checks += f.checks
		accumulated_failures.append_array(f.failures)
		await f.close()
		return
	var actor_bodies: Array = f.host.physical_actor_session.bodies()
	if not f.expect(actor_bodies.size()==1,"fresh Tower retains exactly its ordinary reference barrel"):
		accumulated_checks += f.checks
		accumulated_failures.append_array(f.failures)
		await f.close()
		return
	barrel = actor_bodies[0].get_rid()
	var pose: Transform2D = PhysicsServer2D.body_get_state(barrel,PhysicsServer2D.BODY_STATE_TRANSFORM)
	reference = pose.origin
	var start_tick: int = _native_tick()
	minimum_y = reference.y
	maximum_y = reference.y
	maximum_displacement = 0.0
	maximum_upward_speed = 0.0
	sample_count = 0
	observations = []
	monitor = true
	process_frame.connect(_sample)
	f.expect(reference.x>400.0 and reference.y<440.0,"fresh barrel starts above its floor before settling")
	if mode=="cut_after_four_ticks":
		f.play()
		await f.advance(4,"only four native ticks precede the early live support cut")
		await f.pause()
	if mode in ["cut_before_resume", "cut_after_four_ticks"]:
		f.bench._brush.value = 3
		f.expect(f.bench.paint(Vector2i(140,410),0),"ordinary Erase cuts a distant support before barrel settling")
		await f.until(func(): return f.runtime().physics_ready() and f.coherent() \
			and not f.host.simulation_worker.paint_state().get("legacy_busy",true),"fresh remote notch and collider installation finish")
		# Both actual supports are removed through normal authored painting;
		# every replacement happens while the independent barrel remains live.
		await f.cut_supports("tower",2)
	f.play()
	var target_tick: int = _native_tick()+120
	await f.until(func(): return _native_tick()>=target_tick,"fresh barrel falls and contacts ordinary floor through active native progression")
	if structures_disabled: await _pause_disabled()
	else: await f.pause()
	_sample()
	pose = PhysicsServer2D.body_get_state(barrel,PhysicsServer2D.BODY_STATE_TRANSFORM)
	f.expect(actor_bodies[0].get_rid()==barrel,"initial cuts preserve the actual independent barrel RID")
	f.expect(sample_count>0 and maximum_y>reference.y+10.0,"fresh barrel was observed falling freely, never frozen")
	f.expect(minimum_y>=reference.y-.25,"fresh barrel does not jump above its authored initial height")
	f.expect(f.diagnostics().get("held_reason","").is_empty(),"fresh support-cut schedule remains operational")
	if mode in ["cut_before_resume", "cut_after_four_ticks"]: f.expect(f.body_count()>=1,"early support removal produces a real detached structure")
	if structures_disabled:
		f.expect(not f.runtime().enabled and f.runtime().physical_steps==0,"ordinary reference completes without structural stepping")
	else:
		f.validate_physics()
		f.validate_display()
	scenarios.append({"mode":mode,"start_tick":start_tick,"end_tick":_native_tick(),"initial_x":reference.x,"initial_y":reference.y,
		"minimum_y":minimum_y,"maximum_y":maximum_y,"final_y":pose.origin.y,
		"maximum_upward_speed_cells_s":maximum_upward_speed,"observed_callbacks":sample_count,
		"anomalies":observations,"structural_bodies":f.body_count()})
	monitor = false
	process_frame.disconnect(_sample)
	barrel = RID()
	accumulated_checks += f.checks
	accumulated_failures.append_array(f.failures)
	await f.close()

func _finish() -> void:
	monitor = false
	if process_frame.is_connected(_sample): process_frame.disconnect(_sample)
	if f!=null: await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-fresh-barrel-v1","checks":accumulated_checks,"failures":accumulated_failures,
		"cases":scenarios,"platform":OS.get_name(),"engine":Engine.get_version_info(),
		"scope":"actual fresh Tower and independent barrel: Structures-disabled reference, pristine enabled owner and two early distant cutting schedules; initial attachment may consume a few native ticks; not owner pointer-sequence reconstruction"}))
	quit(0 if accumulated_failures.is_empty() else 1)
