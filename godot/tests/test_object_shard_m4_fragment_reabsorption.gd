extends SceneTree

# Genuine ordinary Workbench handoffs: a witnessed cut makes two physical
# islands, and a separate settled body returns its exact inventory to World.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var f: RefCounted
var evidence: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _install(shape: String) -> bool:
	await f.pause()
	var authored: Dictionary = Setup.fresh(PackedInt32Array(f.bench.applied.liquid_policy),Vector2i(512,512))
	authored.edits = [[0,464,512,48,1],[0,0,3,512,1],[509,0,3,512,1]]
	if shape=="fragment":
		authored.edits.append_array([[140,420,12,12,7],[158,420,12,12,7],[152,425,6,2,7],
			[145,432,2,32,1],[163,432,2,32,1]])
	else:
		authored.edits.append_array([[140,440,20,8,7],[149,448,2,16,1]])
	if not f.expect(f.bench.apply(authored),"fresh native "+shape+" construction admitted"): return false
	if not await f.until(f.installed,"fresh "+shape+" World installed"): return false
	f.bench.set_camera(2)
	f.play()
	if not await f.until(func(): return f.runtime().owns_terrain(),"ordinary material owner rebound"): return false
	await f.pause()
	f.bench._brush.value = 3
	var points: Array[Vector2i] = [Vector2i(146,437),Vector2i(164,437)]
	if shape=="return":
		# Remove the complete stem with bounded ordinary disc painting. The flat
		# plank must actually fall to the floor and sleep before being returned;
		# zero velocity immediately after body activation is not settlement.
		f.bench._brush.value = 2
		points.clear()
		for y: int in [450,454,458,461]:
			for x: int in [149,150]: points.append(Vector2i(x,y))
	for point: Vector2i in points:
		if not f.expect(f.bench.paint(point,0),"ordinary support cut "+str(point)): return false
		await process_frame
	f.play()
	if not await f.until(func(): return f.body_count()==1,"one actual material body detached"): return false
	# Ready can be shorter than a callback while playing. The explicit Pause
	# still requires exactly the same installed geometry/coherence barrier.
	return await f.pause()

func _target_for_source(position: Vector2i) -> Dictionary:
	for shard: Dictionary in f.runtime().publication.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		var local: Vector2i = position-Vector2i(int(shard.origin_x),int(shard.origin_y))
		if local.x<0 or local.y<0 or local.x>=int(shard.width) or local.y>=int(shard.height): continue
		var index: int = local.y*int(shard.width)+local.x
		if int(shard.roles[index])!=1: continue
		var pose := Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y)))
		var pixel := Vector2i((pose*(Vector2(local)+Vector2(0.5,0.5))).floor())
		for y: int in range(-1,2):
			for x: int in range(-1,2):
				var target: Dictionary = f.runtime().visible_target(pixel+Vector2i(x,y))
				if target.get("owner")==int(shard.id) and target.get("cell")==index: return target
	return {}

func _pointer_local(position: Vector2i) -> Vector2:
	var area: Rect2 = f.host.view_content_rect()
	return area.position+(Vector2(position)-Vector2(f.host.camera_origin.floor())+Vector2(0.5,0.5)) \
		*area.size/Vector2(f.host.current_view_size)

func _pointer_button(position: Vector2i, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = _pointer_local(position)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	f.host.world_view.gui_input.emit(event)

func _pointer_move(position: Vector2i) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _pointer_local(position)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	f.host.world_view.gui_input.emit(event)

func _status_keeps_pointer_geometry() -> bool:
	# Exercise the actual mounted Label and container. Rapid receipts can
	# alternate between one line and the two visible lines during a stroke.
	var status: Label = f.bench._status
	var previous_text := status.text
	var was_processing: bool = f.bench.is_processing()
	f.bench.set_process(false)
	status.text = "Paused"
	await process_frame
	await process_frame
	var short_area: Rect2 = f.host.view_content_rect()
	var one_line := status.get_line_count() == 1
	status.text = "Moving material edit: waiting for the current native and physics receipt. ".repeat(12)
	await process_frame
	await process_frame
	var wrapped := status.get_line_count() > 1
	var stable: bool = short_area.has_area() and f.host.view_content_rect() == short_area
	status.text = previous_text
	f.bench.set_process(was_processing)
	return f.expect(one_line and wrapped and stable,"short and wrapped structural status receipts preserve the actual viewport transform")

func _cut_neck_with_pointer() -> bool:
	if not await _status_keeps_pointer_geometry(): return false
	if not await f.until(func(): return f.runtime().physics_ready() and f.coherent() \
		and f.runtime().publication.get("publication_sequence")==f.runtime().frame.get("publication_sequence"),
		"pointer starts on the latest completely displayed native publication"): return false
	var first: Dictionary = _target_for_source(Vector2i(154,425))
	var second: Dictionary = _target_for_source(Vector2i(154,426))
	if not f.expect(not first.is_empty() and not second.is_empty(),"both neck cells have actual displayed native witnesses"): return false
	f.bench._tool.select(f.bench.CUT_MOVING_TOOL)
	var before: int = f.bench.object_shard_m4_port.results.size()
	_pointer_button(first.position,true)
	f.expect(not f.bench._brush.editable,"moving Cut disables the unrelated ordinary radius control")
	if not f.expect(f.bench.object_shard_m4_port.pending_count()==1,"real mounted pointer press queues exactly one witnessed cell"):
		print("M4_POINTER_REFUSAL ",JSON.stringify({"message":f.bench.message,"target":first,
			"pointer_tool":f.bench._object_shard_pointer_tool,"display":f.runtime().visible_observation(),
			"native_sequence":f.runtime().frame.get("publication_sequence"),"drag_button":f.bench._drag_button,
			"area":f.host.view_content_rect(),"camera":f.host.camera_origin,"view":f.host.current_view_size,
			"local_pointer":_pointer_local(first.position),
			"roundtrip":f.host.view_pixel_from_local_point(_pointer_local(first.position)),
			"selected_tool":f.bench._tool.selected,"signal_connections":f.host.world_view.gui_input.get_connections().size()}))
		_pointer_button(first.position,false)
		return false
	# Delay Main's idle and physical receipt callbacks. The real child Workbench input
	# process and exclusive native worker continue. A native mutation receipt
	# can therefore arrive before Main sees or installs its new geometry.
	# This is an actual delivery interleaving, not a substituted owner/frame.
	var main_was_processing: bool = f.host.is_processing()
	var main_was_physics_processing: bool = f.host.is_physics_processing()
	f.host.set_process(false)
	f.host.set_physics_process(false)
	_pointer_move(second.position)
	f.expect(f.bench.object_shard_m4_port.pending_count()==1,"pointer motion cannot queue an unwitnessed stroke behind pending geometry")
	var first_received: bool = await f.until(func(): return f.bench.object_shard_m4_port.results.size()>before,
		"actual native Cut receipt arrives while Main publication is delayed")
	for callback: int in range(3): await process_frame
	var fenced: bool = f.bench.object_shard_m4_port.results.size()==before+1 \
		and f.bench.object_shard_m4_port.pending_count()==0 \
		and f.bench._object_shard_pointer_tool == f.bench.CUT_MOVING_TOOL and f.bench._drag_button==MOUSE_BUTTON_LEFT
	evidence.pointer_receipt_fence = {"main_callback_delayed":not f.host.is_processing(),
		"main_physics_callback_delayed":not f.host.is_physics_processing(),
		"results":f.bench.object_shard_m4_port.results.slice(before).duplicate(true),
		"pending_count":f.bench.object_shard_m4_port.pending_count(),
		"frame_next_transaction":f.runtime().frame.get("next_transaction",-1),
		"display_next_transaction":f.runtime().publication.get("next_transaction",-1),
		"frame_sequence":f.runtime().frame.get("publication_sequence",-1),
		"display_sequence":f.runtime().publication.get("publication_sequence",-1),
		"held_pointer_tool":f.bench._object_shard_pointer_tool}
	# Restore the real callback on every outcome before closing or continuing.
	f.host.set_process(main_was_processing)
	f.host.set_physics_process(main_was_physics_processing)
	if not first_received or not f.expect(fenced,
		"held Cut waits for the applied native transaction to reach its actual displayed geometry"):
		_pointer_button(second.position,false)
		return false
	if not await f.until(func(): return f.bench.object_shard_m4_port.results.size()==before+2 \
		and f.runtime().physics_ready() and f.coherent(),"held current pointer cuts its next visible cell only after the first receipt and geometry"):
		_pointer_button(second.position,false)
		return false
	_pointer_button(second.position,false)
	for index: int in range(2):
		var terminal: Dictionary = f.bench.object_shard_m4_port.results[before+index]
		var source: Dictionary = terminal.get("native_receipt",{}).get("source_target",{})
		var expected: Dictionary = first if index==0 else second
		f.expect(terminal.get("outcome")=="Applied" and source.get("owner")==expected.owner and source.get("cell")==expected.cell,
			"actual pointer cut has its exact native source cell receipt "+str(index))
	for frame: int in range(3): await process_frame
	f.expect(f.bench.object_shard_m4_port.results.size()==before+2 and f.bench.object_shard_m4_port.pending_count()==0,
		"pointer release does not replay held or prior stroke positions")
	# Use a real read-only native operation as the pending barrier. Releasing
	# a newly held Cut or changing its tool must cancel that held intent before
	# the genuine inspector receipt arrives; no fake worker state is installed.
	for cancel_by_tool: bool in [false,true]:
		var target: Dictionary = f.moving_target(7)
		var queued: Dictionary = f.bench.object_shard_m4_action(target.position,"inspect",f.runtime().visible_observation(),target)
		if not f.expect(queued.get("ok",false),"real native inspect supplies a pending pointer barrier"): return false
		var before_action: int = f.bench.object_shard_m4_port._next_action
		_pointer_button(target.position,true)
		if cancel_by_tool:
			f.bench._tool.select(0)
			f.bench._tool.item_selected.emit(0)
		else:
			_pointer_button(target.position,false)
		if not await f.until(func(): return f.bench.object_shard_m4_port.pending_count()==0 \
			and f.runtime().physics_ready() and f.coherent(),"pending native receipt drains after pointer cancellation"): return false
		f.expect(f.bench.object_shard_m4_port._next_action==before_action,
			"tool switch cancels current held intent" if cancel_by_tool else "release cancels current held intent before its barrier closes")
	f.expect(f.bench._brush.editable,"ordinary paint radius returns after leaving moving tools")
	return true

func _settled() -> bool:
	for shard: Dictionary in f.frame().get("shards",[]):
		if not shard.get("has_body",false): continue
		var angle: float = wrapf(float(shard.rotation),-PI,PI)
		return int(shard.get("pose_serial",0))>0 and bool(shard.get("sleeping",false)) \
			and Vector2(float(shard.vx),float(shard.vy)).length()<=0.25 \
			and absf(float(shard.angular_velocity))<=0.01 \
			and absf(angle-roundf(angle/(PI/2.0))*(PI/2.0))<=0.001
	return false

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower") or not await _install("fragment"):
		await _finish(); return
	await f.pause()
	await f.until(f.coherent,"pre-cut native World and material body display coherent")
	var inventory: int = f.material_count(7)
	var parent: int = int(f.frame().shards[0].id)
	if not await _cut_neck_with_pointer():
		await _finish(); return
	f.play()
	if not await f.until(func(): return f.body_count()==2,"two actual physical islands are reserved after native transfer"):
		await _finish(); return
	await f.pause()
	await f.until(f.coherent,"fragmented inventory shares one visual World revision")
	f.expect(f.material_count(7)==inventory-2,"fragment custody conserves every surviving Wood cell")
	var source_proved: bool = false
	for shard: Dictionary in f.frame().shards:
		if shard.get("fragment",false) and int(shard.get("source_parent_id",0))==parent: source_proved = true
	f.expect(source_proved,"native child names its actual parent ownership transfer")
	f.validate_physics()
	evidence.fragment = f.diagnostics()
	if not await _install("return"):
		await _finish(); return
	var before_fall_y: float = float(f.frame().shards[0].position_y)
	f.play()
	if not await f.advance(90,"returned body receives ninety real physical intervals before settlement"):
		await _finish(); return
	if not await f.until(_settled,"actual Rapier body settles nearly on the material grid"):
		await _finish(); return
	await f.pause()
	await f.until(f.coherent,"settled body is exactly the displayed source")
	f.expect(float(f.frame().shards[0].position_y)-before_fall_y>8.0,"returned plank actually fell toward the floor")
	var resting_body: Dictionary = f.diagnostics().physics.bodies[0]
	var resting_rid: RID = f.runtime().bridge.bodies[int(resting_body.id)].rid
	var query := PhysicsTestMotionParameters2D.new()
	query.from = PhysicsServer2D.body_get_state(resting_rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	query.motion = Vector2(0,0.1)
	query.margin = 0.001
	query.recovery_as_collision = true
	var collision := PhysicsTestMotionResult2D.new()
	var hit: bool = PhysicsServer2D.body_test_motion(resting_rid,query,collision)
	var installed_floor: bool = false
	if hit:
		for chunk: Dictionary in f.runtime().bridge.terrain.values():
			if chunk.rid == collision.get_collider_rid(): installed_floor = true
	f.expect(bool(resting_body.sleeping) and hit and installed_floor and collision.get_collision_normal().y < -0.9,
		"nonmutating actual Rapier query proves sleeping contact with installed terrain before return")
	evidence.settled_contact = {"hit":hit,"installed_terrain":installed_floor,
		"normal":[collision.get_collision_normal().x,collision.get_collision_normal().y]}
	evidence.settled_body = resting_body
	var before: int = f.material_count(7)
	var target: Dictionary = f.moving_target(7)
	if not f.expect(not target.is_empty(),"settled owned Wood has exact displayed witness"):
		await _finish(); return
	var before_action: int = f.runtime()._reabsorption_action_serial
	f.bench._tool.select(f.bench.SETTLE_MOVING_TOOL)
	f.bench._tool.item_selected.emit(f.bench.SETTLE_MOVING_TOOL)
	_pointer_button(target.position,true)
	_pointer_button(target.position,false)
	evidence.settle_pointer = {"tool":f.bench._tool.selected,
		"action_before":before_action,"action_after":f.runtime()._reabsorption_action_serial,
		"pending_kind":f.runtime()._pending_kind,"pending_serial":f.runtime()._pending_serial,
		"displayed_target":target.duplicate(true),"body_count":f.body_count()}
	if not f.expect(f.runtime()._reabsorption_action_serial==before_action+1 \
		and f.runtime()._pending_kind=="reabsorb_prepare" and f.runtime()._pending_serial>0 \
		and not f.runtime().last_reabsorption_receipt.get("applied",false) and f.body_count()==1,
		"mounted Settle click stages exactly one native request, never a fictitious applied edit"):
		await _finish(); return
	if not await f.until(func(): return f.runtime().last_reabsorption_receipt.get("applied",false),"actual freeze, World credit, RID removal and terrain ACK complete"):
		await _finish(); return
	await f.until(func(): return f.runtime().physics_ready() and f.coherent(),"returned World and absent moving overlay commit together")
	var receipt: Dictionary = f.runtime().last_reabsorption_receipt
	f.expect(receipt.get("source_target",{})==target,"terminal native receipt retains exact pre-return target")
	f.expect(receipt.get("world_committed",false) and int(receipt.get("retired_inventory_cells",-1))==0,
		"native return retires only empty inventory after World owns the cells")
	f.expect(f.body_count()==0 and not f.runtime().has_live_inventory(),"returned body owns no hidden RID or material copy")
	f.expect(f.material_count(7)==before,"independent ordinary World image conserves returned Wood")
	evidence.reabsorption = receipt
	evidence.final = f.diagnostics()
	var exported: Dictionary = f.bench.save_object_shard_diagnostics()
	if f.expect(exported.get("ok",false),"ordinary Structures action writes owner diagnostics"):
		var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(exported.path)))
		if f.expect(report is Dictionary,"saved owner report is readable JSON"):
			f.expect(report.get("schema")=="objectshard-m4-workbench-diagnostics-v1" \
				and report.get("source_commit")==OS.get_environment("CYBERSAND_SOURCE_REVISION"),
				"owner report binds the actual launched source")
			f.expect(int(report.get("runtime",{}).get("native_tick",-1))==f.tick() \
				and int(report.get("capabilities",{}).get("max_body_area",0))==16384,
				"owner report includes actual native progress and advertised body bounds")
			var cadence: Dictionary = report.get("probe",{}).get("cadence",{})
			f.expect(cadence.has("post_draw_intervals") and cadence.has("native_progress_delivery") \
				and cadence.get("hardware_present_verified")==false,
				"owner report separates renderer callbacks from native progression and physical display evidence")
		evidence.diagnostics_export = exported
	await _finish()

func _finish() -> void:
	if f.failures.is_empty(): await f.validate_quantity_ledger()
	f.validate_display()
	evidence.display_coherence = f.display_witness()
	evidence.inventory_witnesses = f.inventory_witnesses
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-fragment-reabsorption-v1","checks":f.checks,"failures":f.failures,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"evidence":evidence,
		"scope":"actual ordinary Workbench material inventory, shared Rapier fragmentation and same-World settled return"}))
	quit(0 if f.failures.is_empty() else 1)
