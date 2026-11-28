extends SceneTree

# Real Main/native World/Rapier pacing regression. The observer delegates every
# installation, gate and step to production code. Timing is evidence, not a
# machine-speed pass threshold. The adversarial edit spans more than one
# installation budget, then real physics callbacks run faster than rendering.
const Setup = preload("res://scripts/workbench_setup.gd")
const Bridge = preload("res://scripts/workbench_physics_bridge.gd")
const SIDE: int = 1024
const WAIT_MS: int = 90000

class ObservingHost extends "res://scripts/main.gd":
	var observing: bool = false
	var phase: String = ""
	var callbacks: Array[Dictionary] = []
	var installations: Array[Dictionary] = []
	var completed: Array[Dictionary] = []
	var presentations: Array[Dictionary] = []
	var pilot_action: Dictionary = {}
	var last_gate: String = ""
	var emitter_seen: Dictionary = {}
	var contact_recovery: Dictionary = {}
	var brush_admissions: Array[Dictionary] = []

	func queue_brush_mutation(x: int, y: int, radius: int, material: int,
			flags: int = CyberCellWorld.EMISSION_FLAG_NONE) -> bool:
		var accepted: bool = super.queue_brush_mutation(x,y,radius,material,flags)
		if observing:
			brush_admissions.append({"phase":phase,"time_usec":Time.get_ticks_usec(),
				"cell":[x,y],"radius":radius,"material":material,"accepted":accepted,
				"step":physical_actor_session.tick,"paused":paused})
		return accepted

	func _publish_workbench_keyboard() -> void:
		if pilot_action.is_empty():
			super._publish_workbench_keyboard()
		elif not paused and shared_workbench != null and physical_actor_session != null:
			physical_actor_session.submit_workbench_action(shared_workbench.selected_id(),pilot_action,
				{"q":false,"e":false,"s":false,"boost":false},shared_workbench.fire_enabled)

	func _physics_process(delta: float) -> void:
		if not observing:
			super._physics_process(delta)
			return
		var started: int = Time.get_ticks_usec()
		var before: int = physical_actor_session.tick if physical_actor_session != null else -1
		var prior_holds: Dictionary = _cadence_physics_hold_counts.duplicate()
		last_gate = ""
		super._physics_process(delta)
		# Stop at an actual completed callback, including when several physics
		# callbacks occur before the next process frame. This keeps the recovery
		# bound in physical steps rather than renderer opportunities.
		if not contact_recovery.is_empty() and not bool(contact_recovery.complete) \
				and physical_actor_session.tick>before and not completed.is_empty():
			var last: Dictionary = completed.back()
			var slot: int = int(contact_recovery.slot)
			var contact: bool = slot>=0 and slot<last.contacts.size() and int(last.contacts[slot])>0
			var elapsed_steps: int = physical_actor_session.tick-int(contact_recovery.first_step)
			if contact or elapsed_steps>=int(contact_recovery.maximum_steps):
				contact_recovery.complete = true
				contact_recovery.contact = contact
				contact_recovery.completed_step = physical_actor_session.tick
				contact_recovery.reason = "contact" if contact else "physical_step_limit"
				paused = true
				update_worker_frame_state()
		for reason: String in _cadence_physics_hold_counts:
			if int(_cadence_physics_hold_counts[reason])>int(prior_holds.get(reason,0)):
				last_gate = reason
		callbacks.append({"phase":phase,"start_usec":started,"end_usec":Time.get_ticks_usec(),
			"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
			"before_step":before,"after_step":physical_actor_session.tick if physical_actor_session != null else -1,
			"gate":last_gate,"pending_chunks":rapier_bridge.pending_hard_surface_chunks(),
			"queued_revision":last_hard_surface_revision,"waiting_sample":_workbench_wait_sample})

	func _workbench_terrain_installed(snapshot: CyberSimulationSnapshot) -> bool:
		var before: int = rapier_bridge.pending_hard_surface_chunks()
		var started: int = Time.get_ticks_usec()
		var accepted: bool = super._workbench_terrain_installed(snapshot)
		if observing:
			installations.append({"phase":phase,"start_usec":started,"end_usec":Time.get_ticks_usec(),
				"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
				"before_pending":before,"after_pending":rapier_bridge.pending_hard_surface_chunks(),
				"required_revision":snapshot.lab_context.get("workbench_hard_surface_revision",-1),
				"packet_revision":snapshot.hard_surface_revision,"queued_revision":last_hard_surface_revision,
				"accepted":accepted,"snapshot_serial":snapshot.serial})
		return accepted

	func _cadence_rapier_completed(started_usec: int, completed_usec: int,
			snapshot: CyberSimulationSnapshot) -> void:
		super._cadence_rapier_completed(started_usec,completed_usec,snapshot)
		if not observing: return
		var contacts: Array[int] = []
		var positions: Array = []
		for slot: int in range(physical_actor_session.bridge._body_rids.size()):
			var direct = PhysicsServer2D.body_get_direct_state(physical_actor_session.bridge._body_rids[slot])
			contacts.append(direct.get_contact_count() if direct != null else 0)
			var at: Vector2 = physical_actor_session.bridge.body_transform(slot).origin
			positions.append([at.x,at.y])
		completed.append({"phase":phase,"time_usec":Time.get_ticks_usec(),
			"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
			"step":physical_actor_session.tick,"native_tick":snapshot.tick_index,
			"native_completed_usec":snapshot.last_native_tick_completed_usec,
			"native_step_usec":snapshot.last_native_tick_completed_usec-snapshot.last_native_tick_started_usec,
			"required_revision":snapshot.lab_context.get("workbench_hard_surface_revision",-1),
			"packet_revision":snapshot.hard_surface_revision,"installed_revision":last_hard_surface_revision,
			"pending_chunks":rapier_bridge.pending_hard_surface_chunks(),
			"response":_cadence_response_json(physical_actor_session.bridge.last_application),
			"contacts":contacts,"positions":positions})
		if phase=="live-erasing-flight":
			var packet: Dictionary = snapshot.lab_context.get("workbench_gcr",{})
			var owners: Array = []
			for row: Dictionary in packet.get("rows",[]):
				owners.append({"instance_id":row.get("instance_id",-1),"generation":row.get("generation",-1),
					"sample":row.get("sample",-1)})
			completed.back()["owner"] = {"session":physical_actor_session.bridge._session,
				"epoch":_physical_epoch,"world_generation":snapshot.physics_world_generation,
				"snapshot_epoch":snapshot.rigid_body_epoch,"response_session":packet.get("session",-1),
				"response_epoch":packet.get("epoch",-1),"valid":packet.get("valid",false),
				"completed_sample":snapshot.lab_context.get("workbench_completed_sample",-1),"bodies":owners,
				"accepted_samples":Array(physical_actor_session.bridge._accepted_samples)}
		for receipt: Dictionary in snapshot.lab_context.get("workbench_emitters",[]):
			if not receipt.has_all(["tick","sequence","nozzle"]): continue
			var key: String = str(receipt.tick)+":"+str(receipt.sequence)+":"+str(receipt.nozzle)
			emitter_seen[key] = {"phase":phase,"material":receipt.get("material",-1),
				"changed_cells":receipt.get("changed_cells",0),"reason":receipt.get("reason","")}

	func _process(delta: float) -> void:
		super._process(delta)
		if observing:
			presentations.append({"phase":phase,"time_usec":Time.get_ticks_usec(),
				"process_frame":Engine.get_process_frames(),"visual_sources":workbench_presentation_frame.get("sources",{}).duplicate(),
				"visual_reasons":workbench_presentation_frame.get("reasons",{}).duplicate()})

var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var native_receipts: Array[Dictionary] = []
var phases: Array[Dictionary] = []
var output: String = ""
var saved_environment: Dictionary = {}
var source_before: Dictionary = {}
var original_fps: int
var original_physics_hz: int
var stale_snapshot: CyberSimulationSnapshot
var live_erasing: Dictionary = {}

func _initialize() -> void:
	original_fps = Engine.max_fps
	original_physics_hz = Engine.physics_ticks_per_second
	output = OS.get_environment("CYBERSAND_PHYSICS_PACING_OUTPUT")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-pacing-evidence="):
			output = argument.trim_prefix("--physics-pacing-evidence=")
	for key: String in ["CYBERSAND_DIAG_PRESENTATION","CYBERSAND_DIAG_FLYER_POSE","CYBERSAND_DIAG_RENDER_CADENCE"]:
		saved_environment[key] = OS.get_environment(key)
		OS.set_environment(key,"")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","coherent")
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("PHYSICS_PACING: "+label)
	return ok

func until(predicate: Callable, timeout_ms: int = WAIT_MS) -> bool:
	var deadline: int = Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func identity() -> Dictionary:
	var result: Dictionary = {"source_sha":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"godot":Engine.get_version_info().string,"platform":OS.get_name(),"display":DisplayServer.get_name()}
	for path: String in ["res://scripts/main.gd","res://scripts/rapier_physics_bridge.gd",
			"res://scripts/workbench_physics_bridge.gd","res://scripts/simulation_worker.gd",
			"res://tests/test_workbench_physics_pacing.gd"]:
		result[path] = FileAccess.get_sha256(path)
	var native_path: String = "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" \
		if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
	result["native_sha256"] = FileAccess.get_sha256(native_path)
	return result

func snapshot() -> CyberSimulationSnapshot:
	return host.simulation_worker.take_latest_snapshot(0)

func recipe() -> Dictionary:
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(SIDE,SIDE))
	setup.actors = [Setup.instance("needle",1,Vector2(150,160)),Setup.instance(Setup.BARREL,2,Vector2(175,172))]
	setup.next_id = 3
	setup.selected = 1
	# Two isolated, stable rectangles per native 64-cell collider chunk.
	# Later PAINT adds one unrelated cell in every chunk; these exact existing
	# shape RIDs must survive, including in the changed chunks themselves.
	for y: int in range(0,SIDE,64):
		for x: int in range(0,SIDE,64):
			setup.edits.append([x+8,y+8,1,1,58])
			setup.edits.append([x+16,y+8,1,1,58])
	setup.edits.append([128,188,64,4,58])
	return setup

func install(setup: Dictionary = {}) -> bool:
	host.paused = true
	host.update_worker_frame_state()
	var epoch: int = host._physical_epoch
	if not check(ui.apply(recipe() if setup.is_empty() else setup,false),"authored hard World and actual Needle/barrel accepted"): return false
	if not check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch>epoch \
			and host.physical_actor_session != null and host._physical_terrain_ready \
			and host._valid_workbench_mask_frame(host.workbench_display_frame())),
		"real World, actor, material and terrain receipts installed"): return false
	ui._camera.select(1)
	ui._set_view(Vector2(112,128),Vector2i(128,96))
	check(host.engine_lab_wait_native_sample,"interactive default waits for the completed native body sample")
	check(bool(host.simulation_worker.engine_lab_pixel_pacing().sample_wake),"interactive default wakes native owner for new samples")
	check(Bridge.MAX_AGE==1,"native wrench age limit stays exactly one Rapier step")
	check(host.WORKBENCH_HARD_SURFACE_FRAME_BUDGET_USEC==4000,"terrain work retains the 4ms callback budget")
	check(snapshot().hard_surface_chunk_rectangles[0]>host.WORKBENCH_HARD_SURFACE_CHUNKS_PER_FRAME,
		"actual native terrain packet spans multiple changed-chunk budgets")
	return true

func pause_callbacks() -> bool:
	host.paused = true
	host.update_worker_frame_state()
	# A retained graphical frame can still say paused after early physical
	# publication has resumed. Fence after issuing pause, then require a new
	# owner turn and the same native source that PAINT will validate. An older
	# paused frame cannot acknowledge this transition or an in-flight tick.
	var prior: CyberSimulationSnapshot = snapshot()
	var pause_serial: int = prior.serial if prior != null else -1
	if not check(await until(func() -> bool:
		var current: CyberSimulationSnapshot = snapshot()
		var paint: Dictionary = host.simulation_worker.paint_state()
		return current!=null and current.serial>pause_serial and current.paused \
			and bool(paint.paused) and int(paint.tick)==current.tick_index \
			and int(paint.revision)==current.simulation_world_revision),
		"fresh native owner acknowledges pause and matching PAINT source"): return false
	host.set_physics_process(false)
	host.set_process(false)
	return true

func native_edit(cells: PackedInt32Array, label: String) -> CyberSimulationSnapshot:
	var before: Dictionary = host.simulation_worker.paint_state()
	var previous_revision: int = snapshot().hard_surface_revision
	var queued: Dictionary = host.simulation_worker.paint_queue({"kind":"edit","cells":cells,
		"expected_generation":before.generation,"expected_revision":before.revision,"expected_tick":before.tick,
		"expected_authoring_generation":before.authoring_generation})
	if not check(queued.get("status","")=="queued",label+" native PAINT queued"): return null
	if not check(await until(func() -> bool: return host.simulation_worker.paint_state().receipt_ready),label+" native PAINT completed"): return null
	var receipt: Dictionary = host.simulation_worker.paint_take_result()
	native_receipts.append({"label":label,"receipt":receipt})
	if not check(receipt.get("status","")=="completed",label+" authoritative edit accepted"): return null
	var expected := PackedInt32Array()
	for offset: int in range(2,cells.size(),3): expected.append(cells[offset])
	check(receipt.get("after",PackedInt32Array())==expected,label+" every native material readback matches")
	if not check(await until(func() -> bool:
		var value: CyberSimulationSnapshot = snapshot()
		return value!=null and value.hard_surface_revision>previous_revision \
			and value.hard_surface_chunk_rectangles_valid \
			and value.hard_surface_revision==int(value.lab_context.get("workbench_hard_surface_revision",-1))),
		label+" matching complete hard-geometry receipt published"): return null
	return snapshot()

func shape_identities() -> Dictionary:
	var result: Dictionary = {}
	var bridge = host.rapier_bridge
	for chunk: int in range(bridge._hard_surface_chunk_rectangles.size()):
		var packed: PackedInt32Array = bridge._hard_surface_chunk_rectangles[chunk]
		var shapes: Array = bridge._hard_surface_chunk_shape_rids[chunk]
		for index: int in range(shapes.size()):
			var offset: int = index*4
			var key: String = str(chunk)+":"+str(Array(packed.slice(offset,offset+4)))
			result[key] = shapes[index].get_id()
	return result

func exact_geometry(packet: PackedInt32Array, label: String) -> void:
	var bridge = host.rapier_bridge
	var exact: bool = bridge._hard_surface_chunk_rectangles.size()==packet[0]
	var server_exact: bool = bridge._hard_surface_chunk_bodies.size()==packet[0]
	var attached_exact: bool = true
	var shape_count: int = 0
	if exact and server_exact:
		for chunk: int in range(packet[0]):
			var expected: PackedInt32Array = packet.slice(packet[chunk+1],packet[chunk+2])
			if bridge._hard_surface_chunk_rectangles[chunk]!=expected: exact = false
			var shapes: Array = bridge._hard_surface_chunk_shape_rids[chunk]
			if shapes.size()!=expected.size()/4: exact = false
			shape_count += shapes.size()
			var body: RID = bridge._hard_surface_chunk_bodies[chunk]
			var expected_rectangles: Dictionary = {}
			var actual_rectangles: Dictionary = {}
			var expected_rids: Dictionary = {}
			var actual_rids: Dictionary = {}
			for offset: int in range(0,expected.size(),4):
				var key: String = str(Array(expected.slice(offset,offset+4)))
				expected_rectangles[key] = int(expected_rectangles.get(key,0))+1
			for shape: RID in shapes:
				var key: int = shape.get_id()
				expected_rids[key] = int(expected_rids.get(key,0))+1
			var body_pose: Transform2D = PhysicsServer2D.body_get_state(body,PhysicsServer2D.BODY_STATE_TRANSFORM)
			for index: int in range(PhysicsServer2D.body_get_shape_count(body)):
				var shape: RID = PhysicsServer2D.body_get_shape(body,index)
				var rid_key: int = shape.get_id()
				actual_rids[rid_key] = int(actual_rids.get(rid_key,0))+1
				if PhysicsServer2D.shape_get_type(shape)!=PhysicsServer2D.SHAPE_RECTANGLE:
					server_exact = false
					continue
				var half: Vector2 = PhysicsServer2D.shape_get_data(shape)
				var pose: Transform2D = body_pose*PhysicsServer2D.body_get_shape_transform(body,index)
				var low: Vector2 = pose.origin-half
				var size: Vector2 = half*2.0
				if not pose.x.is_equal_approx(Vector2.RIGHT) or not pose.y.is_equal_approx(Vector2.DOWN) \
						or not low.is_equal_approx(low.round()) or not size.is_equal_approx(size.round()):
					server_exact = false
				var key: String = str([roundi(low.x),roundi(low.y),roundi(size.x),roundi(size.y)])
				actual_rectangles[key] = int(actual_rectangles.get(key,0))+1
			if expected_rectangles!=actual_rectangles: server_exact = false
			if expected_rids!=actual_rids: attached_exact = false
	check(exact and shape_count==bridge.hard_surface_shape_count(),label+" installed geometry equals every native packet rectangle")
	check(server_exact,label+" actual PhysicsServer world rectangle multiset equals complete native packet")
	check(attached_exact,label+" actual attached shape RID multiset matches bridge packet-order ownership")

func compare_reuse(before: Dictionary, after: Dictionary, label: String) -> void:
	var unchanged: int = 0
	var reused: int = 0
	for key: String in before:
		if after.has(key):
			unchanged += 1
			if before[key]==after[key]: reused += 1
	observations.append({"label":label,"unchanged_rectangles":unchanged,"reused_shape_rids":reused})
	check(unchanged>0 and reused==unchanged,label+" retains every unchanged rectangle RID")

func terrain_progress() -> void:
	print("PHYSICS_PACING_STAGE native terrain delta")
	if not await pause_callbacks(): return
	var before: Dictionary = shape_identities()
	var cells := PackedInt32Array()
	for y: int in range(0,SIDE,64):
		for x: int in range(0,SIDE,64): cells.append_array(PackedInt32Array([x+24,y+8,58]))
	var target: CyberSimulationSnapshot = await native_edit(cells,"256-chunk edit")
	if target==null: return
	Engine.max_fps = 30
	host.engine_lab_set_rapier_hz(120)
	host.phase = "terrain-30-render-120-physics"
	var start: int = host.installations.size()
	host.paused = false
	host.update_worker_frame_state()
	host.set_process(true)
	host.set_physics_process(true)
	if not check(await until(func() -> bool:
		return host.last_hard_surface_revision==target.hard_surface_revision \
			and host.rapier_bridge.pending_hard_surface_chunks()==0,10000),"real physics callbacks finish native terrain edit"): return
	var series: Array = host.installations.slice(start)
	var opportunities: int = 0
	var progressed: int = 0
	for index: int in range(series.size()):
		var current: Dictionary = series[index]
		if index>0:
			var previous: Dictionary = series[index-1]
			if current.process_frame==previous.process_frame and current.physics_frame>previous.physics_frame \
					and current.before_pending>0 and current.required_revision==previous.required_revision:
				opportunities += 1
				if current.after_pending<current.before_pending: progressed += 1
		if current.after_pending>0:
			check(not current.accepted,"partial installation cannot satisfy complete revision fence")
			for callback: Dictionary in host.callbacks:
				if callback.phase==host.phase and callback.physics_frame==current.physics_frame:
					check(callback.before_step==callback.after_step and callback.gate=="terrain_installation",
						"unpaused Main refuses Rapier while required native geometry remains pending")
	observations.append({"label":"physics-independent-install","callbacks":series,
		"same_render_opportunities":opportunities,"progressed":progressed})
	check(opportunities>0,"adversarial native edit exercises successive actual physics callbacks without a new render frame")
	check(progressed==opportunities,"every eligible physics callback progresses terrain without waiting for rendering")
	exact_geometry(target.hard_surface_chunk_rectangles,"multi-chunk edit")
	compare_reuse(before,shape_identities(),"multi-chunk edit")
	if not await pause_callbacks(): return
	before = shape_identities()
	target = await native_edit(PackedInt32Array([24,8,0]),"one-cell erase")
	if target==null: return
	host.phase = "one-cell-install"
	host.set_process(true)
	host.set_physics_process(true)
	if check(await until(func() -> bool:
		return host.last_hard_surface_revision==target.hard_surface_revision \
			and host.rapier_bridge.pending_hard_surface_chunks()==0,10000),"one-cell geometry replacement completes"):
		exact_geometry(target.hard_surface_chunk_rectangles,"one-cell erase")
		compare_reuse(before,shape_identities(),"one-cell erase")

func distribution(values: Array) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var sorted: Array = values.duplicate()
	sorted.sort()
	return {"count":sorted.size(),"median":sorted[int((sorted.size()-1)*0.5)],
		"p95":sorted[int(ceil((sorted.size()-1)*0.95))],"p99":sorted[int(ceil((sorted.size()-1)*0.99))],"maximum":sorted.back()}

func run_phase(label: String, fps: int, physics_hz: int, minimum_steps: int, minimum_msec: int,
		options: Dictionary = {}) -> void:
	print("PHYSICS_PACING_STAGE ",label)
	Engine.max_fps = fps
	host.engine_lab_set_rapier_hz(physics_hz)
	host.phase = label
	host.set_process(true)
	host.set_physics_process(true)
	var first: int = host.physical_actor_session.tick
	var contact_required: bool = bool(options.get("contact_required",true))
	var contact_slot: int = int(options.get("contact_slot",-1))
	var recovery_maximum_steps: int = int(options.get("recovery_maximum_steps",0))
	var watchdog_msec: int = int(options.get("watchdog_msec",10000))
	host.contact_recovery = {"first_step":first,"maximum_steps":recovery_maximum_steps,
		"slot":contact_slot,"complete":false,"contact":false,"completed_step":first,"reason":"running"} \
		if recovery_maximum_steps>0 else {}
	var first_native: int = snapshot().tick_index
	var started: int = Time.get_ticks_usec()
	host.paused = false
	host.update_worker_frame_state()
	check(await until(func() -> bool:
		if recovery_maximum_steps>0: return bool(host.contact_recovery.complete)
		var additional: Callable = options.get("completion_predicate",Callable())
		return host.physical_actor_session.tick-first>=minimum_steps \
			and Time.get_ticks_usec()-started>=minimum_msec*1000 \
			and (not additional.is_valid() or additional.call()),watchdog_msec),label+" real completed steps progress before watchdog")
	var stopped: int = Time.get_ticks_usec()
	var interval: Array = []
	var native_work: Array = []
	var last: int = -1
	var completed_count: int = 0
	var contact_count: int = 0
	var required_contact_count: int = 0
	for row: Dictionary in host.completed:
		if row.phase!=label: continue
		completed_count += 1
		if last>=0: interval.append(float(row.time_usec-last)/1000.0)
		last = row.time_usec
		native_work.append(float(row.native_step_usec)/1000.0)
		for slot: int in range(row.contacts.size()):
			var touching: int = int(int(row.contacts[slot])>0)
			contact_count += touching
			if contact_slot<0 or slot==contact_slot: required_contact_count += touching
		check(row.pending_chunks==0 and row.required_revision==row.packet_revision \
			and row.required_revision==row.installed_revision,label+" completed step uses fully installed required terrain")
		for response: Dictionary in row.response.bodies:
			if response.refusal.is_empty(): check(response.age>=0 and response.age<=Bridge.MAX_AGE,label+" accepted native wrench retains strict age fence")
	var gates: Dictionary = {}
	var callback_count: int = 0
	for row: Dictionary in host.callbacks:
		if row.phase!=label: continue
		callback_count += 1
		if not row.gate.is_empty(): gates[row.gate] = int(gates.get(row.gate,0))+1
	var main_count: int = 0
	var visual_holds: int = 0
	for row: Dictionary in host.presentations:
		if row.phase!=label: continue
		main_count += 1
		for source: String in row.visual_sources.values(): visual_holds += int(source=="held")
	phases.append({"label":label,"fps_target":fps,"physics_callback_hz":physics_hz,
		"wait_native_sample":host.engine_lab_wait_native_sample,
		"sample_wake":host.simulation_worker.engine_lab_pixel_pacing().sample_wake,
		"elapsed_msec":float(stopped-started)/1000.0,"completed_steps":completed_count,
		"native_ticks":snapshot().tick_index-first_native,"physics_callbacks":callback_count,"main_frames":main_count,
		"completed_step_interval_ms":distribution(interval),"used_native_tick_work_ms":distribution(native_work),
		"physics_gate_counts":gates,"visual_held_body_frames":visual_holds,"contact_observations":contact_count,
		"contact_required":contact_required,"required_contact_slot":contact_slot,
		"required_contact_observations":required_contact_count,"minimum_completed_steps":minimum_steps,
		"minimum_elapsed_msec":minimum_msec,"watchdog_msec":watchdog_msec,
		"fixed_delta":host.rapier_bridge.fixed_delta(),
		"completed_simulation_seconds":completed_count*host.rapier_bridge.fixed_delta(),
		"contact_recovery":host.contact_recovery.duplicate(true)})
	check(host.engine_lab_wait_native_sample and host.simulation_worker.engine_lab_pixel_pacing().sample_wake,
		label+" preserves default native-sample handshake")
	if contact_required:
		check(required_contact_count>0,label+" actual required actor hard-terrain contact is observed")
	if recovery_maximum_steps>0:
		check(completed_count<=recovery_maximum_steps,label+" recovery obeys the completed physical-step bound")
	host.contact_recovery.clear()
	if stale_snapshot==null and snapshot().lab_context.get("workbench_gcr",{}).get("valid",false): stale_snapshot = snapshot()
	host.paused = true
	host.update_worker_frame_state()

func fire_contact() -> void:
	if not await pause_callbacks(): return
	var cells := PackedInt32Array()
	# Native Ice reacts to adjacent heat on its four-tick thermal lane. Wood
	# instead burns for hundreds of ticks and cannot supply a short removal
	# witness. Ice both sides keeps the initial Fire in actual material contact.
	for y: int in range(348,351):
		for x: int in range(340,360):
			cells.append_array(PackedInt32Array([x,y,6 if y==349 else 9]))
	var target: CyberSimulationSnapshot = await native_edit(cells,"native Ice and Fire contact")
	if target==null: return
	host.set_process(true)
	host.set_physics_process(true)
	if not check(await until(func() -> bool:
		return host.last_hard_surface_revision==target.hard_surface_revision \
			and host.rapier_bridge.pending_hard_surface_chunks()==0),"painted Ice contact colliders installed before unpause"): return
	ui._fire.button_pressed = true
	host.pilot_action = {"move":Vector2(0,-0.5),"primary":true,"effort":1.0}
	await run_phase("fire-on-contact",30,60,30,1200)
	var observed_fire: int = 0
	for receipt: Dictionary in host.emitter_seen.values():
		if receipt.phase=="fire-on-contact" and receipt.material==6: observed_fire += int(receipt.changed_cells)
	check(ui.fire_enabled and observed_fire>0,"Fire ON supplies actual native thruster-emission receipts")
	check(snapshot().hard_surface_revision>target.hard_surface_revision,"real native Fire/Ice interaction changes hard terrain")
	ui._fire.button_pressed = false
	host.pilot_action.clear()
	# This retained flight window begins while Needle is still ascending.
	# Thirty fixed steps cannot promise a new collision; preserve its timing
	# evidence, then require actual selected-Needle contact in bounded recovery.
	await run_phase("fire-off-flight",60,60,30,1200,{"contact_required":false})
	check(not ui.fire_enabled,"Fire OFF transition preserves ordinary Workbench control")
	host.pilot_action = {"move":Vector2.ZERO,"primary":false,"effort":1.0}
	await run_phase("fire-off-recovery-contact",60,60,0,0,
		{"contact_slot":0,"recovery_maximum_steps":360,"watchdog_msec":120000})
	host.pilot_action.clear()
	check(not ui.fire_enabled,"neutral contact recovery keeps Fire OFF")

func disc_material(image: Image, cell: Vector2i, radius: int, material: int) -> bool:
	if image==null: return false
	for y: int in range(-radius,radius+1):
		for x: int in range(-radius,radius+1):
			if x*x+y*y<=radius*radius and image.get_pixel(cell.x+x,cell.y+y).r8!=material: return false
	return true

func bytes_sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func live_erasing_input() -> void:
	if live_erasing.is_empty() or host.paused or host.phase!="live-erasing-flight": return
	var step: int = host.physical_actor_session.tick
	var elapsed_steps: int = step-int(live_erasing.first_step)
	if step>int(live_erasing.get("checked_step",live_erasing.first_step)):
		live_erasing.checked_step = step
		var airborne: bool = int(host.completed.back().contacts[0])==0
		live_erasing.airborne_streak = int(live_erasing.get("airborne_streak",0))+1 if airborne else 0
		if not live_erasing.has("flight_start_step") and int(live_erasing.airborne_streak)>=4:
			live_erasing.flight_start_step = step
	var flight_steps: int = step-int(live_erasing.get("flight_start_step",step+1))
	for edit: Dictionary in live_erasing.edits:
		if edit.has("requested_step") or flight_steps<int(edit.at_step): continue
		var cell := Vector2i(edit.cell[0],edit.cell[1])
		var prior: CyberSimulationSnapshot = host.simulation_worker.take_latest_physics_snapshot()
		edit.requested_step = step
		edit.time_usec = Time.get_ticks_usec()
		edit.native_tick_before = prior.tick_index
		edit.revision_before = prior.simulation_world_revision
		edit.hard_revision_before = prior.hard_surface_revision
		edit.world_generation = prior.physics_world_generation
		ui._brush.value = int(edit.radius)
		var screen_point: Vector2 = host.presentation_camera_screen_transform()*(Vector2(cell)+Vector2(0.5,0.5))
		var point: Vector2 = host._world_view_screen_transform().affine_inverse()*screen_point
		var mapped: Vector2i = host.world_cell_from_local_point(point)
		edit.mapped_cell = [mapped.x,mapped.y]
		edit.paint_mode_active = ui.paint_editor.paint_mode_active()
		edit.paused = host.paused
		var actor_position: Vector2 = host.physical_actor_session.bridge.body_transform(0).origin
		edit.actor_position = [actor_position.x,actor_position.y]
		edit.actor_contacts = int(host.completed.back().contacts[0])
		var before: int = host.brush_admissions.size()
		# The ordinary non-PAINT right-button path remains available while
		# playing. Positive PAINT remains paused-only; do not bypass its guard.
		for pressed: bool in [true,false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_RIGHT
			event.pressed = pressed
			event.position = point
			ui._world_input(event)
		edit.queue_receipts = host.brush_admissions.slice(before).duplicate(true)
	if elapsed_steps>=int(live_erasing.maximum_steps):
		live_erasing.limit_reached = true
		host.paused = true
		host.update_worker_frame_state()

func live_erasing_publication() -> void:
	if live_erasing.is_empty() or host.paused or host.phase!="live-erasing-flight": return
	var current: CyberSimulationSnapshot = host.latest_snapshot
	if current==null or host.last_uploaded_render_snapshot_serial!=current.render_snapshot_serial \
			or host.last_uploaded_revision!=current.world_revision \
			or host.last_uploaded_world_generation!=current.render_world_generation: return
	if int(live_erasing.get("checked_render_serial",-1))==host.last_uploaded_render_snapshot_serial: return
	live_erasing.checked_render_serial = host.last_uploaded_render_snapshot_serial
	for edit: Dictionary in live_erasing.edits:
		if not edit.has("requested_step") or edit.has("publication"): continue
		var cell := Vector2i(edit.cell[0],edit.cell[1])
		if current.world_revision<=int(edit.revision_before) \
				or not disc_material(host.image,cell,int(edit.radius),0): continue
		edit.publication = {"time_usec":Time.get_ticks_usec(),"step":host.physical_actor_session.tick,
			"native_tick":current.tick_index,"render_tick":current.render_tick_index,
			"snapshot_serial":current.serial,"render_serial":current.render_snapshot_serial,
			"revision":host.last_uploaded_revision,"world_generation":host.last_uploaded_world_generation,
			"hard_revision":current.hard_surface_revision,"paused":host.paused,
			"region_sha256":bytes_sha256(
				host.image.get_region(Rect2i(cell-Vector2i.ONE*int(edit.radius),
				Vector2i.ONE*(int(edit.radius)*2+1))).get_data())}

func prepare_live_flight() -> bool:
	# Prior phases deliberately combine completed-step and wall-duration minima.
	# Recovery can therefore end at the floor or a sparse ceiling. Author a new
	# clear-air setup through the ordinary owner path before this independent
	# live-edit phase; never move an already running body or alter its velocity.
	host.phase = "live-erasing-setup"
	host.pilot_action.clear()
	var prior: CyberSimulationSnapshot = snapshot()
	var previous_epoch: int = host._physical_epoch
	var previous_session: int = host.physical_actor_session.bridge._session
	var previous_world_generation: int = prior.physics_world_generation
	var spawn := Vector2(304,400)
	var setup: Dictionary = recipe()
	setup.actors[0] = Setup.instance("needle",1,spawn)
	# Keep the authored sparse terrain and passive barrel, with an explicit
	# vertical air corridor for ordinary forward thrust from the new spawn.
	setup.edits.append([272,64,64,416,0])
	# The negative packet controls stopped Main callbacks while paused. Restore
	# ordinary owner-transaction callbacks; install keeps play paused throughout.
	host.set_process(true)
	host.set_physics_process(true)
	if not await install(setup): return false
	var adopted: CyberSimulationSnapshot = snapshot()
	if not check(adopted!=null,"live-flight authored owner has a real native snapshot"): return false
	var bridge = host.physical_actor_session.bridge
	var members: Array = bridge._members.map(func(member: Dictionary) -> int: return int(member.instance_id))
	var positions: Array = []
	var velocities: Array = []
	for slot: int in range(members.size()):
		var at: Vector2 = bridge.body_transform(slot).origin
		var velocity: Vector2 = bridge.body_linear_velocity(slot)
		positions.append([at.x,at.y])
		velocities.append([velocity.x,velocity.y])
	var reset_ready: bool = check(host.paused and host.physical_actor_session.tick==0 \
		and host._physical_epoch>previous_epoch and bridge._session>previous_session \
		and adopted.physics_world_generation>previous_world_generation \
		and adopted.rigid_body_epoch==host._physical_epoch \
		and host.last_uploaded_world_generation==adopted.physics_world_generation \
		and adopted.hard_surface_revision==int(adopted.lab_context.get("workbench_hard_surface_revision",-1)) \
		and host.last_hard_surface_revision==adopted.hard_surface_revision \
		and host.rapier_bridge.pending_hard_surface_chunks()==0,
		"ordinary live-flight setup advances owner and World with complete installed terrain before play")
	var spawn_ready: bool = check(members==[1,2] and ui.applied.actors==setup.actors \
		and positions==[[304.0,400.0],[175.0,172.0]] and velocities==[[0.0,0.0],[0.0,0.0]] \
		and disc_material(host.image,Vector2i(304,400),24,0),
		"live-flight actual Needle/barrel identities and resting authored spawns match clear-air setup")
	observations.append({"label":"live-erasing-setup","receipt":{
		"path":"ordinary SharedWorkbench.apply(preserve=false) before play",
		"previous_session":previous_session,"session":bridge._session,
		"previous_epoch":previous_epoch,"epoch":host._physical_epoch,
		"previous_world_generation":previous_world_generation,"world_generation":adopted.physics_world_generation,
		"required_revision":adopted.lab_context.get("workbench_hard_surface_revision",-1),
		"packet_revision":adopted.hard_surface_revision,"installed_revision":host.last_hard_surface_revision,
		"pending_chunks":host.rapier_bridge.pending_hard_surface_chunks(),
		"paused":host.paused,"step":host.physical_actor_session.tick,"instances":members,
		"authored_actors":setup.actors.duplicate(true),"positions":positions,"velocities":velocities,
		"air_corridor":[272,64,64,416],"material":0,"ready":reset_ready and spawn_ready,
		"trace_identity":"Physical steps restart in the new session/epoch/World; compare full owner identity with step."}})
	return reset_ready and spawn_ready

func live_erasing_flight() -> void:
	if not await prepare_live_flight(): return
	if not await pause_callbacks(): return
	var edits: Array[Dictionary] = [
		{"label":"small-live-erase","at_step":6,"cell":[480,480],"radius":2},
		{"label":"large-live-erase","at_step":18,"cell":[768,768],"radius":24}]
	var cells := PackedInt32Array()
	for edit: Dictionary in edits:
		var count: int = 0
		for y: int in range(-int(edit.radius),int(edit.radius)+1):
			for x: int in range(-int(edit.radius),int(edit.radius)+1):
				if x*x+y*y>int(edit.radius)*int(edit.radius): continue
				cells.append_array(PackedInt32Array([int(edit.cell[0])+x,int(edit.cell[1])+y,58]))
				count += 1
		edit.footprint_cells = count
	var prepared: CyberSimulationSnapshot = await native_edit(cells,"paused hard discs for ordinary live erasing")
	if prepared==null: return
	host.set_process(true)
	host.set_physics_process(true)
	if not check(await until(func() -> bool:
		return host.last_hard_surface_revision==prepared.hard_surface_revision \
			and host.rapier_bridge.pending_hard_surface_chunks()==0 \
			and edits.all(func(edit: Dictionary) -> bool:
				return disc_material(host.image,Vector2i(edit.cell[0],edit.cell[1]),int(edit.radius),58))),
		"both live-erasure targets have actual published hard material and installed colliders"): return
	var brush_before: float = ui._brush.value
	var tool_before: int = ui._tool.selected
	ui._tool.select(2) # Ordinary actor-selection mode retains right-button erasing.
	ui._camera.select(0)
	ui.set_camera(0)
	# A supported closer Free view gives every target cell at least one pixel;
	# a 1024-cell overview can legitimately skip cells on a smaller display.
	ui._set_view(Vector2(320,320),Vector2i(512,512))
	await process_frame
	var bridge = host.physical_actor_session.bridge
	var initial_position: Vector2 = bridge.body_transform(0).origin
	live_erasing = {"first_step":host.physical_actor_session.tick,"maximum_steps":90,"limit_reached":false,
		"session":bridge._session,"epoch":host._physical_epoch,"world_generation":prepared.physics_world_generation,
		"native_tick_before":prepared.tick_index,"edits":edits,
		"initial_position":[initial_position.x,initial_position.y],"initial_accepted_samples":Array(bridge._accepted_samples),
		"instances":bridge._members.map(func(member: Dictionary) -> int: return int(member.instance_id)),
		"camera_scope":"Free view shows the edit targets; Needle flies offscreen. Earlier Follow phases cover visible actor/camera behavior.",
		"input_path":"ordinary non-PAINT _world_input right button -> paint(material 0) -> queue_brush_mutation",
		"receipt_scope":"Observed queue acceptance and exact publication footprint; no PAINT history transaction."}
	# Use ordinary forward body thrust and the existing level assist from the
	# authored clear-air spawn. Actual airborne completions start the edit tape.
	host.pilot_action = {"move":Vector2.UP,"primary":true,"auxiliary":true,"effort":1.0}
	live_erasing.pilot_action = {"move":[0,-1],"primary":true,"auxiliary":true,"effort":1.0}
	live_erasing.controller_scope = "ordinary forward body thrust with level assist from authored clear air; actual airborne completions start the edit tape"
	physics_frame.connect(live_erasing_input)
	process_frame.connect(live_erasing_publication)
	await run_phase("live-erasing-flight",60,60,48,0,{"contact_required":false,"watchdog_msec":60000,
		"completion_predicate":func() -> bool:
			return live_erasing.limit_reached or (live_erasing.has("flight_start_step") \
				and host.physical_actor_session.tick>=int(live_erasing.flight_start_step)+26 \
				and edits.all(func(edit: Dictionary) -> bool: return edit.has("publication")))})
	physics_frame.disconnect(live_erasing_input)
	process_frame.disconnect(live_erasing_publication)
	host.pilot_action.clear()
	check(not live_erasing.limit_reached,"live erasing publishes both targets before the 90-completion bound")
	var final_position: Vector2 = bridge.body_transform(0).origin
	live_erasing.final_position = [final_position.x,final_position.y]
	var actual: Array = host.completed.filter(func(row: Dictionary) -> bool: return row.phase=="live-erasing-flight")
	check(final_position.distance_to(initial_position)>0.25 and actual.any(func(row: Dictionary) -> bool:
		return int(row.contacts[0])==0),"authoritative Needle moves through real airborne steps during live erasing")
	var accepted_samples: Array = live_erasing.initial_accepted_samples.duplicate()
	for row: Dictionary in actual:
		var owner: Dictionary = row.owner
		# A fresh owner can step once before its first native completion. Its
		# prepared sample1 history was deliberately retired, so both provisional
		# responses must be refused without spending any sample authority. The
		# trace's age=-1 is an unavailable-age sentinel for refused responses.
		var bootstrap_refusal: bool = int(live_erasing.first_step)==0 and row.step==1 \
			and row.native_tick==0 and row.native_completed_usec==-1 and owner.completed_sample==-1 \
			and accepted_samples==[-1,-1] and owner.accepted_samples==[-1,-1] \
			and not row.response.accepted and row.response.bodies.size()==2 \
			and row.response.bodies.all(func(response: Dictionary) -> bool:
				return response.sample==1 and response.refusal=="age" and response.age==-1)
		if int(live_erasing.first_step)==0 and row.step==1 and owner.completed_sample==-1:
			check(bootstrap_refusal,"fresh-owner provisional responses are refused before native completion without consuming sample authority")
			live_erasing.bootstrap_refusal = {"valid":bootstrap_refusal,"step":row.step,
				"native_tick":row.native_tick,"native_completed_usec":row.native_completed_usec,
				"completed_sample":owner.completed_sample,"response":row.response.duplicate(true),
				"authority_before":accepted_samples.duplicate(),"authority_after":owner.accepted_samples.duplicate()}
		check(owner.session==live_erasing.session and owner.response_session==owner.session \
			and owner.epoch==live_erasing.epoch and owner.response_epoch==owner.epoch and owner.snapshot_epoch==owner.epoch \
			and owner.world_generation==live_erasing.world_generation and owner.valid \
			and owner.bodies.map(func(body: Dictionary) -> int: return int(body.instance_id))==live_erasing.instances \
			and row.response.refusal.is_empty() \
			and row.response.bodies.map(func(body: Dictionary) -> int: return int(body.id))==[1,2] \
			and owner.accepted_samples.size()==2 \
			and owner.bodies.all(func(body: Dictionary) -> bool:
				return body.generation==owner.epoch and (body.sample==owner.completed_sample \
					or (bootstrap_refusal and body.sample==1))),
			"live erasing retains native feedback session, epoch, generation and completed-sample association")
		for response: Dictionary in row.response.bodies:
			var slot: int = int(response.id)-1
			if response.refusal.is_empty():
				var forward: int = posmod(int(response.sample)-int(accepted_samples[slot]),bridge.SAMPLE_SERIAL_LIMIT)
				check(response.sample==owner.completed_sample and response.age>=0 and response.age<=Bridge.MAX_AGE \
					and forward>0 and forward<=bridge.SAMPLE_SERIAL_LIMIT/2 \
					and owner.accepted_samples[slot]==response.sample,"live erasing accepts only the associated advancing safe-age native sample")
			else:
				check(owner.accepted_samples[slot]==accepted_samples[slot],
					"live erasing refused response consumes no additional accepted sample authority")
				if response.refusal=="duplicate":
					check(response.sample==accepted_samples[slot],"duplicate refusal preserves the already applied sample identity")
		accepted_samples = owner.accepted_samples.duplicate()
	for edit: Dictionary in edits:
		check(live_erasing.has("flight_start_step") \
			and edit.get("requested_step",-1)==int(live_erasing.get("flight_start_step",-1))+int(edit.at_step),
			str(edit.label)+" uses its exact completed-step trigger")
		check(edit.get("mapped_cell",[])==edit.cell and not edit.get("paused",true) \
			and not edit.get("paint_mode_active",true) and edit.get("queue_receipts",[]).size()==1,
			str(edit.label)+" reaches the ordinary playing right-button pointer path exactly once")
		check(int(edit.get("actor_contacts",-1))==0,str(edit.label)+" is requested during actual airborne Needle flight")
		for receipt: Dictionary in edit.get("queue_receipts",[]):
			check(receipt.accepted and receipt.cell==edit.cell and receipt.radius==edit.radius \
				and receipt.material==0 and not receipt.paused and receipt.step==edit.requested_step,
				str(edit.label)+" production queue acknowledges the intended live erasure")
		if check(edit.has("publication"),str(edit.label)+" exact erased footprint is published while playing"):
			var publication: Dictionary = edit.publication
			check(not publication.paused and publication.world_generation==live_erasing.world_generation \
				and publication.hard_revision>int(edit.hard_revision_before),str(edit.label)+" material publication retains owner and new hard geometry")
			check(actual.any(func(row: Dictionary) -> bool:
				return row.step>=int(edit.requested_step)+8 and row.native_tick>int(edit.native_tick_before) \
					and row.required_revision>=int(publication.hard_revision)),
				str(edit.label)+" native and Rapier continue with the erased terrain fully installed")
	if await pause_callbacks():
		exact_geometry(snapshot().hard_surface_chunk_rectangles,"completed ordinary live erasing")
		check(host.image.get_data()==host._presentation_current_bytes,"live-erasure uploaded image and safety certificate agree")
		# Readback is deliberately after the live phase, never in its timing sample.
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var current: Image = host.texture.get_image()
			var previous: Image = host.previous_texture.get_image()
			check(current!=null and current.get_data()==host._presentation_current_bytes,
				"live-erasure current GPU material equals the acknowledged safety bytes")
			check(previous!=null and previous.get_data()==host._presentation_previous_bytes,
				"live-erasure previous GPU material equals the preserved history bytes")
			live_erasing.gpu_history_readback_after_phase = current!=null and previous!=null
	ui._brush.value = brush_before
	ui._tool.select(tool_before)
	observations.append({"label":"live-erasing-flight","receipt":live_erasing.duplicate(true)})
	live_erasing.clear()

func packet_fences() -> void:
	print("PHYSICS_PACING_STAGE native packet fences")
	if not await pause_callbacks(): return
	if not check(stale_snapshot!=null,"a genuine earlier native response was retained for negative controls"): return
	var bridge = host.physical_actor_session.bridge
	var packet: Dictionary = stale_snapshot.lab_context.workbench_gcr
	var transforms: Array = []
	var velocities: Array = []
	for slot: int in range(bridge._members.size()):
		transforms.append(bridge.body_transform(slot))
		velocities.append(bridge.body_linear_velocity(slot))
	var accepted: PackedInt64Array = bridge._accepted_samples.duplicate()
	for kind: String in ["invalid","wrong-session","wrong-epoch","wrong-generation","stale"]:
		var altered: Dictionary = packet.duplicate(true)
		match kind:
			"invalid": altered.valid = false
			"wrong-session": altered.session += 1
			"wrong-epoch": altered.epoch += 1
			"wrong-generation": altered.rows[0].generation += 1
		var serial: int = bridge._last_snapshot+1
		var applied: int = host.physical_actor_session.apply_workbench_results(serial,altered)
		var decision: Dictionary = bridge.last_application.duplicate(true)
		observations.append({"label":"packet-"+kind,"applied":applied,"decision":host._cadence_response_json(decision)})
		check(applied==0 and not decision.accepted,kind+" native response cannot mutate actual physics")
		if kind=="stale":
			check(not decision.bodies.is_empty() and decision.bodies.all(func(row: Dictionary) -> bool:
				return row.get("refusal","")=="age"),"actual older native response is refused by strict sample age")
		elif kind=="invalid": check(decision.refusal=="native_refusal","invalid native response retains refusal")
		elif kind=="wrong-generation": check(decision.refusal=="identity","wrong actor generation retains refusal")
		else: check(decision.refusal=="owner_or_response",kind+" ownership fence retained")
	check(bridge._accepted_samples==accepted,"rejected responses consume no accepted sample authority")
	for slot: int in range(bridge._members.size()):
		check(bridge.body_transform(slot)==transforms[slot] and bridge.body_linear_velocity(slot)==velocities[slot],
			"negative response controls preserve actual RID state slot "+str(slot))
	var wrong_owner := CyberSimulationSnapshot.new()
	wrong_owner.serial = bridge._last_snapshot+1
	wrong_owner.rigid_body_epoch = host._physical_epoch+1
	wrong_owner.lab_context = {"workbench_gcr":packet.duplicate(true)}
	var prior: Dictionary = bridge.last_application.duplicate(true)
	host.apply_latest_rigid_body_results(wrong_owner)
	check(bridge.last_application==prior,"Main rejects wrong-owner snapshot before packet application")
	var real: CyberSimulationSnapshot = snapshot()
	for kind: String in ["missing-required","missing-packet","newer-required"]:
		var altered := CyberSimulationSnapshot.new()
		altered.rigid_body_epoch = real.rigid_body_epoch
		altered.hard_surface_revision = real.hard_surface_revision
		altered.hard_surface_chunk_rectangles = real.hard_surface_chunk_rectangles.duplicate()
		altered.hard_surface_chunk_rectangles_valid = kind!="missing-packet"
		altered.lab_context = real.lab_context.duplicate(true)
		if kind=="missing-required": altered.lab_context.erase("workbench_hard_surface_revision")
		elif kind=="newer-required": altered.lab_context.workbench_hard_surface_revision += 1
		var queued: int = host.last_hard_surface_revision
		check(not host._workbench_terrain_installed(altered),kind+" terrain receipt cannot release the physics fence")
		check(host.last_hard_surface_revision==queued and bridge.pending_hard_surface_chunks()==0,
			kind+" terrain refusal leaves the installed native geometry intact")

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	source_before = identity()
	host = load("res://main.tscn").instantiate()
	host.set_script(ObservingHost)
	root.add_child(host)
	root.size = Vector2i(1280,800)
	ui = host.shared_workbench
	if check(await until(func() -> bool: return ui!=null and not ui.applied.is_empty()),"ordinary Workbench opens") \
			and await install():
		check(host.begin_workbench_pose_trace({"fixture":"physics-pacing","interactive_defaults":true}),
			"production trace records exact completed steps and physics gate reasons")
		host.observing = true
		await run_phase("interactive-default-60",60,60,45,1800)
		await terrain_progress()
		await run_phase("render-30-physics-120",30,120,45,1200)
		await fire_contact()
		# The retained stale packet belongs to this original owner. Exercise its
		# adversarial age/session/terrain fences before the explicit live-fixture reset.
		await packet_fences()
		await live_erasing_flight()
		check(host.completed.all(func(row: Dictionary) -> bool:
			return row.pending_chunks==0 and row.required_revision==row.packet_revision \
				and row.required_revision==row.installed_revision),
			"every actual completed step including adversarial installation retains the complete terrain fence")
	var trace: Dictionary = host.finish_workbench_pose_trace()
	if host.observing: check(trace.get("status","")=="saved","original production pose/physics trace saved")
	check(source_before==identity(),"tested source and native runtime remain unchanged")
	var file: FileAccess
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		if trace.get("status","")=="saved":
			check(DirAccess.copy_absolute(str(trace.path),output.path_join("physics-pacing-poses.jsonl"))==OK,
				"original production trace retained beside test observations")
		file = FileAccess.open(output.path_join("physics-pacing.json"),FileAccess.WRITE)
		check(file!=null,"physics pacing evidence file opens")
	var result: Dictionary = {"schema":"workbench-physics-pacing-v1","checks":checks,"failures":failures,
		"source_identity":source_before,"phases":phases,"observations":observations,"native_receipts":native_receipts,"trace":trace,
		"physics_callbacks":host.callbacks,"terrain_installations":host.installations,
		"completed_steps":host.completed,"presentation_frames":host.presentations,
		"scope":"Actual production Main callbacks, native edits/receipts and Rapier contacts with default wait/wake. Wall-clock distributions are observations; no physical GPU acceptance."}
	if file!=null:
		file.store_string(JSON.stringify(result,"  ")+"\n")
		file.close()
	for key: String in saved_environment: OS.set_environment(key,str(saved_environment[key]))
	Engine.max_fps = original_fps
	Engine.physics_ticks_per_second = original_physics_hz
	host.queue_free()
	await process_frame
	await process_frame
	print("PHYSICS_PACING_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"phases":phases.size()}))
	quit(int(not failures.is_empty()))
