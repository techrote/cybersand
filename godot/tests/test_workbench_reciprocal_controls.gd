extends SceneTree

# Real native transport/control integration. This never applies a construction
# or claims reciprocal success: blocked compositions remain valid test outcomes.
const Setup=preload("res://scripts/workbench_setup.gd")
var host:Control
var bench:Control
var panel:Control
var checks:=0
var failures:Array[String]=[]
var completed:=false

func _initialize()->void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(value:bool,label:String)->bool:
	checks+=1
	if not value: failures.append(label);push_error("SWARM004_CONTROLS "+label)
	return value

func until(predicate:Callable,label:String)->bool:
	var deadline:=Time.get_ticks_msec()+35000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return check(false,label)

func settled()->bool:
	return not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty()

func capture()->Dictionary:
	var state:Dictionary=host.simulation_worker.paint_state()
	var admitted:Dictionary=host.simulation_worker.material_capture_request(int(state.generation),2048*2048*2)
	if not check(admitted.get("ok",false),"independent native capture admitted"): return {}
	var result:Dictionary={};var deadline:=Time.get_ticks_msec()+15000
	while result.is_empty() and Time.get_ticks_msec()<deadline:
		result=host.simulation_worker.material_capture_poll(int(admitted.token));await process_frame
	var released:Dictionary=host.simulation_worker.material_capture_finish(int(admitted.token),false)
	check(result.get("ok",false) and released.get("ok",false),"native capture completed and released")
	return result

func exercise()->void:
	if not check(bench.apply(Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))),"blank native source admitted"): return
	if not await until(settled,"blank native source installed"): return
	var before:=await capture()
	bench.open_reciprocal();panel=bench.reciprocal_panel
	check(not panel.controls.shared_ownership.button_pressed and panel.controls.rounds.value==2,
		"new experimental dock uses the selected two-round fixed-territory default")
	panel.controls.profile.select(1);panel._select_expression(1)
	panel.controls.width.value=128;panel.controls.height.value=96
	panel.controls.layout.select(2);panel.controls.border.value=4
	panel.controls.seed.value=605;panel.controls.shared_extent.value=13;panel.controls.shared_ownership.button_pressed=false
	panel.activation.assign([Vector2i(64,48)])
	panel.gentek_controls.frame.enabled.button_pressed=true
	panel.gentek_controls.frame.values.branching.value=0.1
	panel.gentek_controls.mosaic.enabled.button_pressed=true
	panel.gentek_controls.mosaic.values.cohesion.value=0.6
	check(panel.controls.destruction.value==0 and panel.gentek_controls.frame.values.destruction.value==0 \
		and panel.gentek_controls.mosaic.values.destruction.value==0,"independent structural changes never enable destruction")
	if not check(panel.generate(),"real native child admitted for independent controls"): return
	if not await until(func()->bool:return not panel.busy(),"native generation and decoder settle"): return
	if not check(panel.phase=="ready" and not panel.document.is_empty(),"native independent-profile evidence decoded: "+panel.status): return
	check(panel.prepared.text.begins_with("SWARM004 2\n"),"independent controls use the declared V2 transport")
	var input:Dictionary=panel.document.input
	check(input.frame.profile.branching==0.1 and input.mosaic.profile.branching==0.55 \
		and input.frame.profile.cohesion==0.35 and input.mosaic.profile.cohesion==0.6,
		"native source receipt retains distinct requested FRAME and MOSAIC controls")
	check(not input.options.shared_ownership and not input.shared_zone.any(func(value:Variant)->bool:return int(value)!=0) \
		and input.frame.transition.any(func(value:Variant)->bool:return int(value)!=0) \
		and input.frame.transition==input.mosaic.transition,"fixed ownership retains both transition masks but no shared cell authority")
	check(panel._pid<0 and panel._thread==null,"generation and decoding leave no native child or worker")
	for layer:int in panel._layer.item_count:
		panel._layer.select(layer);panel._render()
	for round_index:int in panel._round.item_count:
		panel._round.select(round_index);panel._layer.select(panel.LAYERS.find("Sockets / receptors"));panel._render()
	check(panel._preview.texture!=null,"native final and provisional socket views render")
	check((await capture()).cells==before.cells and bench.applied.edits.is_empty(),"all native previews preserve the entire World and authoring history")
	panel.gentek_controls.frame.values.branching.value=0.15
	check(panel.document.is_empty() and panel.phase=="idle" and panel._apply.disabled,"changing an independent knob retires the old native Apply authority")
	completed=true

func run()->void:
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate();root.add_child(host);bench=host.shared_workbench
	if await until(settled,"Main and native worker initialize"): await exercise()
	check(completed,"complete independent native control sequence")
	if host!=null: host.queue_free();await process_frame;await process_frame
	print("SWARM004_CONTROLS ",JSON.stringify({"checks":checks,"completed":completed,"failures":failures,
		"scope":"real native independent controls, inspection and source immutability; no Apply or reciprocal acceptance"}))
	quit(0 if failures.is_empty() else 1)
