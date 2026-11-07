extends "res://tests/test_workbench_freed.gd"

const Baseline: String="2253eb2dd2e22f5dacb30cedd37084600e776656"
var baseline: bool=OS.get_environment("CYBERSAND_CUT_BASELINE")=="1"
var maximum_frame_usec: int=0
var last_frame_usec: int=0
var measuring: bool=false

func watch_frame() -> void:
	var now: int=Time.get_ticks_usec()
	if measuring and last_frame_usec>0: maximum_frame_usec=maxi(maximum_frame_usec,now-last_frame_usec)
	last_frame_usec=now

func packet(count: int, values: Dictionary) -> PackedInt32Array:
	var result:=PackedInt32Array([count]);var offset: int=count+2
	for i: int in range(count):
		result.append(offset);offset+=values.get(i,PackedInt32Array()).size()
	result.append(offset)
	for i: int in range(count): result.append_array(values.get(i,PackedInt32Array()))
	return result

func sparse_contract() -> void:
	var plain: Dictionary={"name":"legacy","rectangles":[[0,0,4,4]]}
	var expected: String=JSON.stringify(plain,"",true,true).sha256_text()
	check(Setup.CanvasBody.digest(plain)==expected,"legacy two-field digest unchanged")
	for appearance: Variant in [{"material":[],"origin":[0,0]},{"material":2,"origin":[0,0]},{"material":43,"origin":[-1,0]},{"material":43,"origin":[0.5,0]},{"material":43,"origin":[0,0],"extra":0}]:
		var malformed: Dictionary=plain.duplicate(true);malformed["appearance"]=appearance
		check(not Setup.CanvasBody.error(malformed).is_empty(),"malformed appearance refuses")
	var bridge:=CyberRapierPhysicsBridge.new()
	var body:=RigidBody2D.new();body.freeze=true;root.add_child(body)
	var bodies: Array[RigidBody2D]=[body]
	check(bridge.initialize(root.world_2d.space,bodies,PackedVector2Array([Vector2.ONE]))==OK,"isolated actual Rapier bridge")
	var a:=PackedInt32Array([70,110,40,4]);var b:=PackedInt32Array([90,90,2,2])
	check(bridge.queue_hard_surface_chunk_snapshot(packet(1024,{1:a})),"complete sparse1024 packet")
	check(bridge.pending_hard_surface_chunks()==1,"only occupied delta consumes a budget slot")
	check(bridge.process_hard_surface_collider_budget(8,2000)==1 and bridge.hard_surface_shape_count()==1,"one changed chunk installs actual collider")
	check(bridge.queue_hard_surface_chunk_snapshot(packet(1024,{1:a})) and bridge.pending_hard_surface_chunks()==0,"unchanged resubmission completes immediately")
	check(bridge.queue_hard_surface_chunk_snapshot(packet(1024,{1:b,999:a})) and bridge.pending_hard_surface_chunks()==2,"two deltas pending")
	check(bridge.process_hard_surface_collider_budget(1,0)==1,"partial packet installation")
	check(bridge.queue_hard_surface_chunk_snapshot(packet(1024,{1:a})) and bridge.pending_hard_surface_chunks()==1,"supersession diffs installed state, not discarded target")
	var invalid:=packet(1024,{1:a});invalid[2]=-1
	check(not bridge.queue_hard_surface_chunk_snapshot(invalid) and bridge.pending_hard_surface_chunks()==1,"invalid packet preserves pending work")
	bridge.process_hard_surface_collider_budget(8,0)
	check(bridge._hard_surface_chunk_rectangles[1]==a and bridge.hard_surface_shape_count()==1,"exact reversion geometry")
	bridge.queue_hard_surface_chunk_snapshot(packet(1024,{999:b}));bridge.process_hard_surface_collider_budget(8,0)
	check(bridge.hard_surface_shape_count()==1,"move to late occupied chunk")
	check(bridge._hard_surface_chunk_bodies.filter(func(rid: RID):return rid.is_valid()).size()==2,"late occupied chunk creates no preceding empty RIDs")
	bridge.queue_hard_surface_chunk_snapshot(packet(1,{}));bridge.process_hard_surface_collider_budget(8,0)
	check(bridge.hard_surface_shape_count()==0,"shrinking packet removes installed trailing shapes")
	bridge._replace_hard_surface_colliders([Rect2i(1,1,2,2)],Time.get_ticks_usec())
	check(bridge.hard_surface_shape_count()==1,"global-list control")
	check(bridge.queue_hard_surface_chunk_snapshot(packet(1024,{})) and bridge.pending_hard_surface_chunks()==0 and bridge.hard_surface_shape_count()==0,"empty chunk packet retires global shapes")
	bridge.shutdown();body.free()

func fresh(kind: String) -> bool:
	var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy))
	recipe.version=4;recipe.edits=[[0,72,2048,4,58]]
	if kind=="tree": structure(recipe,0,false)
	else: recipe.edits.append([50,54,1,18,43]) # Cut at y70 leaves16 cells.
	if ui.cut.capture_count>0:
		check(host.workbench_restart(recipe,true),"fresh whole-owner reset");await scene_changed
		host=current_scene;ui=host.shared_workbench
	else: check(ui.apply(recipe),"fresh2048 ordinary canvas")
	if not check(await until(installed),"canvas installed"): return false
	host.simulation_worker.set_worker_participation_sampling(true)
	check(ui.step_once(),"apply native region")
	return check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index>0),"native region applied")

func run() -> void:
	Engine.max_fps=60
	process_frame.connect(watch_frame)
	if not baseline: sparse_contract()
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"ordinary workbench"): finish();return
	evidence["profile"]={"parent":Baseline,"extent":[2048,2048],"repeats":5,"physics":"unchanged","baseline":baseline}
	for kind: String in ["tree","debris"]:
		for repeat: int in range(5):
			print("CUT_RESPONSIVENESS ",kind," repeat ",repeat)
			if not await fresh(kind): finish();return
			var tick: int=host.latest_snapshot.tick_index
			ui.applied.brush=2
			maximum_frame_usec=0;measuring=true
			var started: int=Time.get_ticks_usec();var frame: int=Engine.get_process_frames()
			check(ui.paint(Vector2i(51,67) if kind=="tree" else Vector2i(50,72),0),"ordinary erase")
			if kind=="tree":
				for x: int in [50,52,53]: check(ui.paint(Vector2i(x,67),0),"complete trunk cut")
			check(ui.cut.finish_stroke(ui),"ordinary cut")
			if not check(await until(installed),"cut returns"): finish();return
			var total: int=Time.get_ticks_usec()-started
			measuring=false
			check(host.latest_snapshot.tick_index==tick,"no hidden native step")
			check(host.rigid_bodies.size()==(1 if kind=="tree" else 0),"correct rigid/debris route")
			var row: Dictionary={"kind":kind,"repeat":repeat,"total_usec":total,"process_frames":Engine.get_process_frames()-frame,"maximum_frame_usec":maximum_frame_usec,
				"receipts":ui.cut.receipts.duplicate(true)}
			if not baseline:
				row["timings"]=ui.cut.timings.duplicate(true)
				check(ui.cut.timings.terrain_changed_chunks<=32,"local cut does not queue whole2048 terrain")
				if kind=="tree":
					var actor: Dictionary=ui.applied.actors.back()
					check(actor.body.has("appearance") and actor.body.appearance.material==43,"saved original brick appearance")
					var rendered: Array=host.physical_actor_session.render_parts()
					check(rendered.size()==1 and rendered[0].shape=="material","one image instead of per-proxy stripes")
					var image: Image=rendered[0].visual.texture.get_image()
					var count: int=0
					for y: int in image.get_height():
						for x: int in image.get_width(): count+=int(roundi(image.get_pixel(x,y).r*255)==43)
					check(count==520,"exact520-cell material mask including enclosed hole")
					var from: Vector2=rendered[0].visual.source
					check(image.get_pixel(60-int(from.x),32-int(from.y)).r==0 and image.get_pixel(68-int(from.x),50-int(from.y)).r==0,"hole and open concavity remain empty")
					var original: Dictionary=actor.body.duplicate(true);original.erase("appearance")
					check(Setup.CanvasBody.definition(original)==Setup.CanvasBody.definition(actor.body),"appearance changes no physics definition")
					check(Setup.CanvasBody.digest(original)!=actor.hash,"appearance authenticated separately")
					check(Setup.CanvasBody.digest(JSON.parse_string(JSON.stringify(actor.body)))==actor.hash,"appearance survives JSON roundtrip")
					if repeat==0:
						var name: String="cut-feedback-qualification-"+OS.get_environment("CYBERSAND_FREED_WORKERS")
						check(Setup.write_named(name,ui.applied).is_empty(),"ordinary disk Save retains material appearance")
						var saved: Dictionary=Setup.read_named(name)
						check(saved.has("setup") and saved.setup.actors[0].body==actor.body,"ordinary disk readback appearance")
			evidence.cuts.append(row)
			if kind=="tree": check(await run_steps(2),"resume current-body fence")
			else:
				check(ui.step_once(),"native-only debris Step")
				check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index==tick+1),"native-only debris resumes")
	evidence["maximum_observed_workers"]=observed_workers
	finish()
