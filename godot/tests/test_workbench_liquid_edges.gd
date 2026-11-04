extends SceneTree

# Drive the app's actual brush, liquid picker and Apply button through the
# shared desktop host. The worker advances native material beyond the authored
# edge before either the solver change or a same-solver physical edit.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var panel: Control
var checks := 0
var failures: Array[String] = []
var cases: Array = []

func _initialize() -> void: run.call_deferred()

func require(ok: bool, why: String) -> bool:
	checks += 1
	if not ok:
		failures.append(why)
		push_error("WORKBENCH_EDGE "+why+" / "+panel.message+" / "+host.microscenario_error)
	return ok

func until(predicate: Callable, why: String) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("diagnostic_capture_seconds")
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): break
		if not host.microscenario_error.is_empty() and host.pending_microscenario_apply.is_empty(): break
		await process_frame
	return require(false,why)

func click_at(viewport: Viewport, position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.pressed = down
		viewport.push_input(event,true)
		await process_frame

func click(button: Button) -> void:
	await click_at(button.get_viewport(),button.get_global_rect().get_center())

func button_named(label: String) -> Button:
	for child: Node in panel.find_children("*","Button",true,false):
		if child.text == label: return child
	return null

func pick(picker: OptionButton, index: int) -> bool:
	await click(picker)
	var popup := picker.get_popup()
	if not require(popup.visible,"real toolbar popup open"): return false
	popup.set_item_accelerator(index,KEY_F19)
	var key := InputEventKey.new()
	key.keycode = KEY_F19
	key.pressed = true
	var ok := require(popup.activate_item_by_event(key),"menu item activated")
	popup.set_item_accelerator(index,KEY_NONE)
	popup.hide()
	await process_frame
	return ok

func paint(pos: Vector2i, material: int) -> bool:
	if not await pick(panel._material,panel.Setup.MATERIALS.find(material)): return false
	panel._set_view(Vector2(pos)-Vector2(host.current_view_size)*0.5,host.current_view_size)
	await process_frame
	var rect: Rect2 = host.view_content_rect()
	var local: Vector2 = rect.position+(Vector2(pos)+Vector2(.5,.5)-host.camera_origin.floor())*rect.size/Vector2(host.current_view_size)
	var count: int = panel.applied.edits.size()
	await click_at(host.world_view.get_viewport(),host.world_view.get_global_transform()*local)
	return require(panel.applied.edits.size()==count+1 and panel.applied.edits.back()==[pos.x,pos.y,int(panel.applied.brush),material],"real canvas brush at "+str(pos))

func active_water() -> String:
	for entry: Dictionary in host.tower_context.get("liquid_solver_policy",{}).get("assignments",[]):
		if entry.material==3: return entry.applied_family
	return ""

func receipt() -> Dictionary:
	return host.tower_context.get("liquid_construction_receipt",{}).get("workbench_conversion",{}).duplicate(true)

func uploaded_after(old_generation: int) -> bool:
	var snap: CyberSimulationSnapshot = host.latest_snapshot
	return host.last_uploaded_world_generation>old_generation and host.last_uploaded_world_generation==snap.render_world_generation \
		and host.last_uploaded_revision==snap.world_revision and snap.world_revision==snap.simulation_world_revision

func edge_case(side: int, negative: bool) -> void:
	panel._extent[0].value=side; panel._extent[1].value=side
	await click(button_named("New blank"))
	if not await until(func() -> bool: return host.pending_microscenario_apply.is_empty() and panel.applied.extent==[side,side],"fresh extent"): return
	if panel._details.visible: await click(button_named("Details"))
	panel._brush.value=12
	# Every complete brush disc fits in the authored extent. Positive halo
	# inventory therefore witnesses transport, never a direct out-of-bounds write.
	var rim := Vector2i(12,96) if negative else Vector2i(side-24,side-13)
	var rock := Vector2i(64,60)
	if not await paint(rock,58) or not await paint(rim,3): return
	# Left-edge Water spreads left from the top of a shelf, bottom-edge Water
	# falls through the last visible row. The production worker moves each.
	if negative:
		if not await paint(Vector2i(12,112),58): return
	else:
		if not await paint(Vector2i(side-64,side-13),14): return
	await click(button_named("Details"))
	await click(button_named("Play / Pause [P]"))
	if not await until(func() -> bool:
		return host.latest_snapshot.tick_index>=22 and not host.latest_snapshot.native_worker_participation.is_empty(),
		"22 real native ticks and optional worker sample"): return
	var participation: Dictionary = host.latest_snapshot.native_worker_participation.duplicate(true)
	require(participation.worker_capacity>=1 and participation.workers_observed>=1 and participation.phase_jobs.size()==4 and participation.native_tick_ms>=0,"sampled worker capacity, claimants, phase jobs and duration")
	require("logical CPUs" in panel._detail_label.text and "task claimants" in panel._detail_label.text,"Details displays scoped CPU metrics")
	await click(button_named("Details"))
	if not await until(func() -> bool: return host.latest_snapshot.native_worker_participation.is_empty(),"Details closed sampling off"): return
	await click(button_named("Play / Pause [P]"))
	if not await until(func() -> bool: return host.latest_snapshot.paused,"pause acknowledgement"): return
	await click(button_named("Details"))
	if not require(panel._liquids.preset_picker.selected==0 and active_water()=="freemass_v1","new canvas resets previous visual preset to native defaults"): return
	if not await pick(panel._liquids.preset_picker,2): return # Water: pressure reference
	if not require(panel._liquids._validation.receipt.assignments.any(func(a: Dictionary)->bool:
		return a.material==3 and a.applied_family=="pressure_flow_v1"),"native menu stages selected Water solver"): return
	var generation: int = host.last_uploaded_world_generation
	await click(button_named("Apply liquid selection"))
	if not await until(func() -> bool: return host.pending_microscenario_apply.is_empty() and active_water()=="pressure_flow_v1" and uploaded_after(generation),"Water switch after edge transport"): return
	var first := receipt()
	if not require(first.get("preserved_halo_visible_water",0)>0,"actually migrated native Water outside the canvas"): return
	require(first.water_before==first.water_after+first.get("clipped_visible_water",0),"visible Water transfer balance")
	if not negative:
		require(int(first.preserved_halo_materials.get(14,0))>0,"falling native Dust also retained beyond bottom edge")
	require(not host.microscenario_error and host.image.get_pixelv(rock).r8==58,"interior authored terrain retained")
	require(panel.message.contains("outside") or panel.message.contains("halo"),"reported out-of-canvas material")
	await click(button_named("Details"))
	generation = host.last_uploaded_world_generation
	if not await pick(panel._roster,panel.Fleet.index_for_id("midge")+1): return
	if not await until(func() -> bool: return host.pending_microscenario_apply.is_empty() and panel.pilot_slot>=0 and uploaded_after(generation),"same-solver actor edit after edge transport"): return
	var second := receipt()
	require(active_water()=="pressure_flow_v1" and second.get("preserved_halo_visible_water",0)==first.preserved_halo_visible_water,"healthy actor edit retains native policy and halo")
	require(panel.applied.edits.size()>0 and host.image.get_pixelv(rock).r8==58,"starting recipe and live painted terrain survived")
	if not await until(func()->bool:
		return "active Water pressure_flow/reference" in panel._status.text and panel.message in panel._status.text,
		"acknowledged edit, quantity and active family visible in toolbar"): return
	cases.append({"side":side,"edge":"left" if negative else "bottom","switch":first,"edit":second,"workers":participation,"status":panel.message})
	var capture_dir := OS.get_environment("CYBERSAND_WORKBENCH_EDGE_CAPTURE")
	if not capture_dir.is_empty() and DisplayServer.get_name()!="headless":
		panel._set_view(Vector2(rim)-Vector2(host.current_view_size)*0.5,host.current_view_size)
		await process_frame
		await RenderingServer.frame_post_draw
		require(root.get_texture().get_image().save_png(capture_dir.path_join("water-edge-%d.png"%side))==OK,"saved rendered edge edit")
	await switch_out_of_pressure(cases.back(),rock,capture_dir)


func switch_out_of_pressure(record: Dictionary, rock: Vector2i, capture_dir: String) -> void:
	# Exercise the installed pressure solver. Recapture the resulting
	# inventory with an unchanged-policy edit immediately before leaving PF.
	var tick: int = host.latest_snapshot.tick_index
	await click(button_named("Step [.]"))
	if not await until(func()->bool: return not panel.step_pending and host.latest_snapshot.tick_index==tick+1 and active_water()=="pressure_flow_v1","PressureFlow stepped before switching away"): return
	var generation: int = host.last_uploaded_world_generation
	await click(button_named("Apply settings"))
	if not await until(func()->bool: return host.pending_microscenario_apply.is_empty() and uploaded_after(generation),"capture post-step pressure inventory"): return
	var baseline := receipt()
	if not require(not baseline.requested and baseline.water_after==record.edit.water_after and baseline.preserved_halo_visible_water>0,"PressureFlow retained whole-domain Water during the measured tick"): return

	await click(button_named("Details"))
	var editor = panel._liquids
	if not await pick(editor.material_picker,editor.material_picker.get_item_index(3)): return
	var target := -1
	for i: int in range(editor._choices.size()):
		var choice: Dictionary = editor._choices[i]
		if choice.accepted and choice.family=="freemass_v1" and choice.variant=="reference":
			target = i
			break
	if not require(target>=0,"FreeMass/reference is admitted for Water"): return
	if not await pick(editor.family_picker,target): return
	if not require(active_water()=="pressure_flow_v1" and editor._validation.receipt.assignments.any(func(a: Dictionary)->bool:
		return a.material==3 and a.applied_family=="freemass_v1"),"FreeMass staged while PressureFlow still runs"): return
	generation = host.last_uploaded_world_generation
	await click(button_named("Apply liquid selection"))
	if not await until(func()->bool: return host.pending_microscenario_apply.is_empty() and active_water()=="freemass_v1" and uploaded_after(generation),"native FreeMass installed after PressureFlow"): return
	var outgoing := receipt()
	require(outgoing.requested and outgoing.source_policy_sha256==baseline.target_policy_sha256 and outgoing.source_policy_sha256!=outgoing.target_policy_sha256,"conversion receipt identifies the actual outgoing pressure owner")
	require(outgoing.water_before==baseline.water_after and outgoing.water_before+outgoing.normalization_produced==outgoing.water_after+outgoing.normalization_consumed+outgoing.discarded_water_overfill+outgoing.clipped_visible_water,"whole-domain PF to FreeMass Water balance")
	require(outgoing.preserved_halo_materials==baseline.preserved_halo_materials and outgoing.preserved_halo_visible_water==baseline.preserved_halo_visible_water and outgoing.clipped_material_cells==0,"FreeMass retains the complete pressure halo")
	require(host.image.get_pixelv(rock).r8==58 and panel.applied.edits.size()>0 and panel.pilot_slot>=0,"rendered terrain, authored edits and flyer remain usable")
	if not await until(func()->bool: return "active Water freemass/reference" in panel._status.text and panel.message in panel._status.text,"FreeMass receipt visible in toolbar"): return
	record["outgoing_source"] = baseline
	record["outgoing"] = outgoing
	record["outgoing_status"] = panel.message
	if not capture_dir.is_empty() and DisplayServer.get_name()!="headless":
		await click(button_named("Details"))
		await RenderingServer.frame_post_draw
		require(root.get_texture().get_image().save_png(capture_dir.path_join("water-edge-%d-freemass.png"%record.side))==OK,"saved rendered outgoing Water solver")

func run() -> void:
	root.size=Vector2i(1920,1080)
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	root.add_child(host)
	panel=host.shared_workbench
	if await until(func()->bool: return not panel.applied.is_empty(),"blank workbench"):
		var sidecars: String = panel._inventory_report({"water_before":0,"water_after":0,"clipped_thermal_cells":9,
			"clipped_gas_labels":3,"discarded_gas_amount":400,"clipped_gas_amount":400,
			"discarded_inertial_cells":5,"clipped_inertial_cells":3,"clipped_pressure_flow_cells":1},false)
		require("thermal state in 9 cells" in sidecars and "3 gas labels" in sidecars and "400 gas units (400 beyond storage)" in sidecars
			and "inertial state in 5 cells (3 beyond storage)" in sidecars and "pressure flow in 1 cells beyond storage" in sidecars,"formatter reports clipped state without any material cells")
		await edge_case(512,true)
		if failures.is_empty(): await edge_case(2048,false)
	host.queue_free()
	await process_frame
	await process_frame
	print("WORKBENCH_EDGE ",JSON.stringify({"checks":checks,"failures":failures,"cases":cases}))
	quit(int(not failures.is_empty()))
