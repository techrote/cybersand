extends "res://tests/test_workbench_cut_transport.gd"

func bounded_case(centres: int) -> void:
	if not await fresh_host(): return
	var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	recipe.version=4;recipe.edits=[[0,72,512,4,58],[50,64,50,8,43]]
	check(ui.apply(recipe),"anchored frontier source")
	if not check(await until(installed),"source installed"): return
	check(ui.step_once(),"apply source region")
	if not check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index>0),"region admitted"): return
	var tick: int=host.latest_snapshot.tick_index;var generation: int=host.latest_snapshot.render_world_generation
	ui.applied.brush=2
	for i: int in range(centres): check(ui.paint(Vector2i(52+6*i,66),0),"separated real erases")
	check(ui.cut.finish_stroke(ui),"normal opt-in prefetch path")
	if not check(await until(installed),"bounded refusals finish"): return
	var receipts: Array=ui.cut.receipts.duplicate(true)
	var counts: Dictionary={};var attempts: int=0;var anchored: int=0;var limited: bool=false
	for row: Dictionary in receipts:
		check(int(row.get("phase",0)) not in [2,3,4,8],"refusal never prepares/commits source")
		if row.get("native_action")=="next":
			var id: int=int(row.request_id);counts[id]=int(counts.get(id,0))+1
			attempts=maxi(attempts,int(row.get("discovery_attempts",0)))
			if row.outcome=="Anchored": anchored+=1
			limited=limited or row.get("frontier_limited",false)
	for count: int in counts.values(): check(count<=8,"at most8 native discoveries per request")
	check(attempts==(40 if centres==4 else 64) and anchored==attempts,"all native refusals retained including over8 work")
	check(limited==(centres==8),"64-investigation capacity outcome explicit")
	check(host.rigid_bodies.is_empty() and ui.cut.capture_count==0,"safe refusal retires no source")
	check(host.latest_snapshot.tick_index==tick and host.latest_snapshot.render_world_generation==generation,"no hidden tick or World replacement")
	var begin: Dictionary=await ui.cut._rpc({"action":"begin","dabs":PackedInt32Array([350,350,2]),"sample":{}})
	check(begin.get("ok",false) and not begin.has("prefetched_payload"),"direct census begin keeps old non-prefetch semantics")
	var census: Dictionary=await ui.cut._rpc({"action":"census","area":Rect2i(48,62,56,16)})
	check(census.get("ok",false),"authoritative post-refusal census")
	var values: PackedInt32Array=census.get("pixels",PackedInt32Array());var brick: int=0
	for i: int in range(0,values.size(),3):
		var point:=Vector2i(values[i],values[i+1]);var expected: int=0
		if point.y>=72 and point.y<76: expected=58
		elif Rect2i(50,64,50,8).has_point(point):
			expected=43
			for cut: int in range(centres):
				if (point-Vector2i(52+6*cut,66)).length_squared()<=4: expected=0
		check(values[i+2]==expected,"exact erased/retained material map")
		brick+=int(values[i+2]==43)
	check(brick==(348 if centres==4 else 296),"no failed source became Sand/Rust")
	check((await ui.cut._end()).get("ok",false),"census closes held owner")
	evidence.cuts.append({"centres":centres,"native_attempts":attempts,"anchored":anchored,"limited":limited,"receipts":receipts})

func run() -> void:
	for centres: int in [4,8]: await bounded_case(centres)
	finish()
