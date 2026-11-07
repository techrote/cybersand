extends "res://tests/test_workbench_brush_cuts.gd"

func fresh(edits: Array) -> bool:
	if not await super.fresh(edits): return false
	ui.cut.small_debris_limit=16
	return true

func source(n: int, x: int=79) -> Array:
	var result: Array=[[x,44,1,5,43]]
	if n==1: result.append([x,43,1,1,43])
	elif n==15: result.append([x-1,39,3,5,43])
	else:
		result.append([x-1,40,4,4,43])
		if n==17: result.append([x+3,40,1,1,43])
	return result

func census(x: int=64) -> Dictionary:
	ui.cut.panel=ui
	var sample: Dictionary={} if host.physical_actor_session==null else host.rapier_bridge.pack_held_sample()
	var begun: Dictionary=await ui.cut._rpc({"action":"begin","dabs":PackedInt32Array([350,350,2]),"sample":sample})
	if not check(begun.get("ok",false),"read-only census owner hold"): return {}
	var result: Dictionary=await ui.cut._rpc({"action":"census","area":Rect2i(x,24,48,40)})
	check(result.get("ok",false),"actual native material census")
	var ended: Dictionary=await ui.cut._end()
	check(ended.get("ok",false),"census ends with a fresh sample")
	return result

func counts(row: Dictionary) -> Dictionary:
	var result: Dictionary={2:0,29:0,43:0}
	var pixels: PackedInt32Array=row.get("pixels",PackedInt32Array())
	for i: int in range(0,pixels.size(),3):
		var material: int=pixels[i+2]
		if result.has(material): result[material]+=1
	return result

func advance_native(count: int) -> bool:
	var start: int=host.latest_snapshot.tick_index
	check(ui.toggle_pause(),"ordinary Play")
	if not check(await until(func():return host.latest_snapshot.tick_index>=start+count),"native material motion advances"): return false
	check(ui.toggle_pause(),"ordinary Pause")
	evidence["last_tick_window"]=[start,host.latest_snapshot.tick_index]
	return true

func run() -> void:
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"ordinary workbench starts"): finish();return
	for sand_bed: bool in [false,true]:
		for n: int in [1,15,16,17]:
			var edits: Array=[[0,49,512,4,58]]
			if sand_bed: edits.append([72,46,18,3,2])
			edits.append_array(source(n))
			if not await fresh(edits): finish();return
			var generation: int=host.latest_snapshot.render_world_generation
			if not await erase(Vector2i(79,46),2): finish();return
			var cut: Dictionary=evidence.cuts.back()
			cut["n"]=n;cut["sand_bed"]=sand_bed
			check(host.latest_snapshot.render_world_generation==generation,"same native World through conversion")
			var first: Dictionary=await census()
			var before: Dictionary=counts(first)
			if n<=16:
				check(host.rigid_bodies.is_empty() and ui.cut.capture_count==0,"no per-cell or aggregate Rapier objects")
				var commit: Dictionary={}
				for row: Dictionary in cut.receipts:
					if row.get("phase")==8 and row.get("ok",false): commit=row
				check(not commit.is_empty() and commit.granular_converted_count==n and commit.aggregate_owned==0,"native ownership, never aggregate retirement/restoration")
				check(commit.brick_converted==n and commit.sand_produced==(n+1)/2 and commit.rust_produced==n/2,"exact material conversion ledger")
				check(before[29]==n/2 and before[43]==0,"independent actual native output census")
				if not sand_bed: check(before[2]==(n+1)/2,"all loose Sand retained")
			else:
				check(host.rigid_bodies.size()==1 and host.rigid_bodies[0].mass==17,"17-cell piece remains one original rigid aggregate")
			if not await advance_native(120): finish();return
			var after: Dictionary=await census()
			check(counts(after)==before,"actual native pixels survive falling/settling")
			if n<=16:
				var source_still_occupied: bool=false
				var pixels: PackedInt32Array=after.pixels
				for i: int in range(0,pixels.size(),3):
					if pixels[i]>=78 and pixels[i]<=82 and pixels[i+1]>=39 and pixels[i+1]<=43 and pixels[i+2] in [2,29]: source_still_occupied=true
				check(not source_still_occupied,"all converted pixels vacate the original piece, independent of pre-existing Sand")
			cut.merge({"before":first,"after":after,"tick_window":evidence.last_tick_window})
	# Disabled control proves the route changes representation, not the rigid law.
	var edits: Array=[[0,49,512,4,58]];edits.append_array(source(16))
	if not await fresh(edits): finish();return
	ui.cut.small_debris_limit=0
	if not await erase(Vector2i(79,46),2): finish();return
	check(host.rigid_bodies.size()==1 and host.rigid_bodies[0].mass==16,"threshold0 retains old rigid route")
	# Mixed native/Rapier: source conversion must not rebuild or disturb the body.
	edits=[[0,49,512,4,58]];edits.append_array(source(17));edits.append_array(source(16,159))
	if not await fresh(edits): finish();return
	if not await erase(Vector2i(79,46),2): finish();return
	if not await advance_native(20): finish();return
	var body: RigidBody2D=host.rigid_bodies[0];var rid: RID=body.get_rid()
	var pose: Transform2D=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	if not await erase(Vector2i(159,46),2): finish();return
	check(host.rigid_bodies.size()==1 and host.rigid_bodies[0].get_rid()==rid,"small debris preserves existing RID")
	check(PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)==pose and PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)==velocity,"conversion does not move or kick the existing body")
	if not await run_steps(120): finish();return
	var mixed: Dictionary=await census(144)
	check(counts(mixed)[29]==8 and counts(mixed)[2]==8,"mixed owner retains16 native granular cells")
	var name: String="small-debris-"+OS.get_environment("CYBERSAND_FREED_WORKERS")
	check(Setup.write_named(name,ui.applied).is_empty(),"save post-cut authored material recipe")
	var saved: Dictionary=Setup.read_named(name)
	check(saved.has("setup") and JSON.parse_string(JSON.stringify(saved.setup))==JSON.parse_string(JSON.stringify(ui.applied)),"disk recipe round trip preserves the blend and actor")
	check(ui.restore_start(),"normal Restore retires whole mixed owner")
	await scene_changed;host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"fresh replay installed"): finish();return
	check(ui.step_once(),"ordinary Step applies replay region")
	if not check(await until(func():return not ui.step_pending),"replay Step completes"): finish();return
	var restored: Dictionary=await census(144)
	check(host.rigid_bodies.size()==1 and ui.cut.capture_count==0 and counts(restored)[29]==8 and counts(restored)[2]==8,"replay has one fresh body and blend, no duplicate brick/body")
	evidence["maximum_observed_workers"]=observed_workers
	# Depart while the new native phase is visible and terrain is being installed.
	var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	recipe.version=4;recipe.edits=[[0,49,512,4,58]];recipe.edits.append_array(source(16))
	recipe.actors=[Setup.instance(Setup.BARREL,1,Vector2(400,24))];recipe.next_id=2
	check(ui.apply(recipe),"prepare interrupted conversion with an existing owner")
	if not check(await until(installed),"interruption canvas ready"): finish();return
	check(ui.step_once(),"apply interruption region")
	if not check(await until(func():return not ui.step_pending),"interruption Step completes"): finish();return
	var controller=ui.cut
	ui.applied.brush=2;check(ui.paint(Vector2i(79,46),0) and controller.finish_stroke(ui),"start interrupted small conversion")
	if not check(await until(func():return controller.receipts.any(func(row: Dictionary):return row.get("phase")==8)),"observe actual DebrisCommitted phase"): finish();return
	evidence["interrupted_receipts"]=controller.receipts.duplicate(true)
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	host=null;ui=null
	await create_timer(.1).timeout
	check(controller._retired and not controller.busy and controller.panel==null,"phase8 departure retires the complete owner and coroutine")
	finish()
