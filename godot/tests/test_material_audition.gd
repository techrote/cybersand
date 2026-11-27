extends SceneTree

# Source-built native transactions, effective consumers, and the real ordinary
# Workbench/Lab owner. The synchronous worker fixture below has no worker thread;
# all mounted Workbench checks use only immutable published owner readback.
const Worker = preload("res://scripts/simulation_worker.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Profiles = preload("res://scripts/material_audition_profile.gd")
const Scenes = preload("res://scripts/workbench_material_audition_scenes.gd")
var checks := 0
var failures := 0
var witnesses: Array = []
var frames: Array = []
var evidence := ""
var main: Variant
var wb: Variant
var panel: Variant

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	evidence = OS.get_environment("MAT_AUDITION_EVIDENCE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MATERIAL_AUDITION: " + message)

func until(predicate: Callable, message: String, timeout_ms: int = 90000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	expect(false,"Timed out: " + message)
	return false

func profile(id: String, materials: Array = [], reactions: Array = []) -> Dictionary:
	return {"schema_version":1,"profile_id":id,"materials":materials,"reactions":reactions}

func request(state: Dictionary, proposed: Dictionary, host: bool = false) -> Dictionary:
	var result := {"world_id":state.world_id,"expected_revision":state.revision,"profile":proposed}
	if host: result.session_id = state.session_id
	return result

func capability(state: Dictionary, property: String, index: int, kind: String = "material") -> Dictionary:
	for row: Dictionary in state.get("capabilities",[]):
		if row.kind == kind and row.property == property and int(row.get("material_id" if kind == "material" else "slot",-1)) == index:
			return row
	return {}

func native_world(workers: int = 1, options: Dictionary = {}) -> Variant:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world != null and world.has_method("apply_material_audition"),"new native material profile API is loaded")
	if world == null or not world.has_method("apply_material_audition"): return null
	var configuration := {"workers":workers,"extent":Vector2i(128,128)}
	configuration.merge(options,true)
	expect(world.diagnostic_reset(configuration),"native diagnostic World accepts its explicit construction")
	expect(world.get_worker_threads() == workers,"requested native worker configuration is observed")
	return world

func fill(world: Variant, x: int, y: int, width: int, height: int, material: int) -> void:
	expect(world.diagnostic_fill_rect(Vector2i(x,y),Vector2i(width,height),material),"actual native fixture fill")

func bay(world: Variant) -> void:
	fill(world,10,10,3,4,1)
	fill(world,11,11,1,1,2)
	fill(world,11,12,1,1,16)

func activate(world: Variant, proposed: Dictionary) -> Dictionary:
	var before: Dictionary = world.get_material_audition_state()
	var cells: PackedByteArray = world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128)).cells
	var receipt: Dictionary = world.apply_material_audition(request(before,proposed))
	expect(receipt.get("ok",false) and receipt.get("status") == "active","native activation succeeds: " + str(receipt))
	var after: Dictionary = world.get_material_audition_state()
	expect(after.world_id == before.world_id and after.observed_tick == before.observed_tick,"activation retains the native World and completed tick")
	expect(after.revision == before.revision + 1 and after.profile == proposed,"actual activated profile has the next revision")
	expect(world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128)).cells == cells,"configuration transition preserves existing stored cells")
	return receipt

func direct_adversaries() -> void:
	var world: Variant = native_world()
	if world == null: return
	bay(world)
	var initial: Dictionary = world.get_material_audition_state()
	var initial_hash: String = world.get_physical_state_hash()
	var invalid: Array = [
		profile("invalid",[{"material_id":2,"density":0}]),
		profile("invalid",[{"material_id":2,"density":65536}]),
		profile("invalid",[{"material_id":2,"density":true}]),
		profile("invalid",[{"material_id":2,"density":2.5}]),
		profile("invalid",[{"material_id":2,"density":NAN}]),
		profile("invalid",[{"material_id":2,"density":INF}]),
		profile("invalid",[{"material_id":2,"density":500},{"material_id":2,"density":700}]),
		profile("invalid",[{"material_id":2,"density":500},{"material_id":3,"viscosity":64}]),
		profile("invalid",[{"material_id":10,"density":500}]),
		profile("invalid",[{"material_id":2,"name":"fake"}]),
		profile("invalid",[],[{"slot":2,"probability_threshold":256}]),
		profile("invalid",[],[{"slot":2,"probability_threshold":0},{"slot":2,"probability_threshold":255}]),
		profile("invalid",[],[{"slot":56,"probability_threshold":255}]),
		profile("unsupported identity /"),
		{"schema_version":2,"profile_id":"invalid","materials":[],"reactions":[]},
		{"schema_version":1,"profile_id":"invalid","materials":[],"reactions":[],"extra":true}
	]
	for proposed: Dictionary in invalid:
		var refused: Dictionary = world.apply_material_audition(request(initial,proposed))
		expect(not refused.get("ok",true) and refused.status == "refused","invalid/unsupported profile receives a refusal")
		expect(world.get_material_audition_state() == initial and world.get_physical_state_hash() == initial_hash,"refusal is atomic for config, cells, time and physical identity")
	for identity: Variant in [0,"0","-1","18446744073709551616","unknown",str(int(initial.world_id) + 100000)]:
		var bad := request(initial,profile("wrong-world"))
		bad.world_id = identity
		expect(not world.apply_material_audition(bad).get("ok",true),"malformed or different native World is refused")
	for revision: Variant in [-1,0.0,true,1]:
		var bad := request(initial,profile("wrong-revision"))
		bad.expected_revision = revision
		expect(not world.apply_material_audition(bad).get("ok",true),"malformed or stale expected revision is refused")
	var proposed := profile("low-density",[{"material_id":2,"density":500}])
	activate(world,proposed)
	var active: Dictionary = world.get_material_audition_state()
	expect(capability(active,"density",2).effective == 500 and capability(active,"density",2).declared == 1600,"declared and effective density remain distinct")
	expect(active.changes_behavior and active.physical_state_hash_version == 7,"behaviorally modified physical identity is explicitly versioned")
	var stale: Dictionary = world.apply_material_audition(request(initial,profile("stale")))
	expect(not stale.ok and world.get_material_audition_state() == active,"stale native intent cannot overwrite the active profile")
	var detached := active.duplicate(true)
	detached.profile.materials[0].density = 900
	detached.capabilities.clear()
	expect(world.get_material_audition_state() == active,"caller-owned readback edits cannot mutate the native profile")
	var repeat := activate(world,proposed)
	expect(int(repeat.get("woken_blocks",-1)) == 0,"repeated equivalent effective settings do not wake unrelated cells")
	var old_id: String = active.world_id
	expect(world.diagnostic_reset({"workers":1,"extent":Vector2i(128,128)}),"explicit World reconstruction succeeds")
	var replacement: Dictionary = world.get_material_audition_state()
	expect(replacement.world_id != old_id and replacement.revision == 0 and not replacement.changes_behavior,"new World retires profile authority and begins at accepted defaults")
	expect(not world.apply_material_audition(request(active,proposed)).ok,"retired native World identity cannot activate in its replacement")
	var wave: Variant = native_world(1,{"wave_flow":true})
	var state: Dictionary = wave.get_material_audition_state()
	var clay_slot := -1
	for row: Dictionary in state.capabilities:
		if row.get("rule_id") == "int.pair.water-raw-clay.slake.v1": clay_slot = int(row.slot)
	expect(clay_slot >= 0 and capability(state,"probability_threshold",clay_slot,"reaction").change_class != "live","Wave Water plus inert clay exposes its unavailable initiating consumer")
	expect(not wave.apply_material_audition(request(state,profile("wave-clay",[],[{"slot":clay_slot,"probability_threshold":255}]))).ok,"ineffective Wave pair cannot masquerade as a live edit")
	expect(capability(state,"probability_threshold",2,"reaction").change_class == "live","active Salt retains its valid initiating contact against Wave Water")
	# Decode a full-length owned string without truncation or overlapping-string
	# replacement; this also guards the portable libstdc++ wire-copy seam.
	var names: Variant = native_world()
	var exact_name: String = "Az09._-".repeat(9) + "Q"
	activate(names,profile(exact_name))
	var named: Dictionary = names.get_material_audition_state()
	expect(named.profile.profile_id == exact_name and str(named.profile.profile_id).to_utf8_buffer().size() == 64,
		"native wire preserves all 64 admitted ASCII profile identity bytes")
	for invalid_name: String in ["",exact_name + "x","é","prefix" + String.chr(0) + "tail"]:
		var refused: Dictionary = names.apply_material_audition(request(named,profile(invalid_name)))
		expect(not refused.get("ok",true) and refused.get("status") == "refused",
			"native wire refuses empty, overlong, non-ASCII and embedded-NUL identities")
		expect(names.get_material_audition_state() == named,
			"refused wire identity cannot truncate into an accepted name or change active configuration")

func actual_consumers() -> void:
	for workers: int in [1,4]:
		var control: Variant = native_world(workers)
		var equivalent: Variant = native_world(workers)
		var low: Variant = native_world(workers)
		var high: Variant = native_world(workers)
		for world: Variant in [control,equivalent,low,high]: bay(world)
		activate(equivalent,profile("equivalent-default",[{"material_id":2,"density":1600}]))
		expect(not equivalent.get_material_audition_state().changes_behavior,"explicit equivalent default is behaviorally default")
		activate(low,profile("low",[{"material_id":2,"density":500}]))
		activate(high,profile("high",[{"material_id":2,"density":3000}]))
		var token: String = low.get_material_audition_state().world_id
		for tick: int in range(12):
			for world: Variant in [control,equivalent,low,high]: expect(world.simulation_tick(),"native density fixture completes a tick")
			expect(control.get_physical_state_hash() == equivalent.get_physical_state_hash(),"equivalent defaults preserve exact continuing native physical state")
		expect(control.stored_material_at(11,12) == 2 and high.stored_material_at(11,12) == 2 and low.stored_material_at(11,11) == 2,"matched native density alternatives change actual exchange")
		expect(capability(control.get_material_audition_state(),"density",2).effective == 1600,"independent native World retains its default density")
		var before: Dictionary = low.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128))
		activate(low,profile("default"))
		expect(low.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128)).cells == before.cells,"Revert config does not restore or rewind physical state")
		for tick: int in range(4): expect(low.simulation_tick(),"reverted native World continues")
		expect(low.stored_material_at(11,12) == 2 and low.get_material_audition_state().world_id == token,"reversion reaches the old consumer in the same existing World")
		witnesses.append({"kind":"density","workers":workers,"world_id":token,"density_500_sinks":false,"density_1600_sinks":true,"density_3000_sinks":true,"reverted_sinks":low.stored_material_at(11,12)==2,"ticks":16})
		var moves: Array = []
		var reactions: Array = []
		for viscosity: int in [0,128,255]:
			var world: Variant = native_world(workers)
			for index: int in range(96):
				var x := (index % 16)*6
				var y := (index / 16)*8
				fill(world,x,y,5,3,1)
				fill(world,x+1,y+1,3,1,0)
				fill(world,x+2,y+1,1,1,20)
			activate(world,profile("paste-trial",[{"material_id":20,"viscosity":viscosity}]))
			expect(world.simulation_tick(),"native viscosity fixture completes")
			var moved := 0
			for index: int in range(96): moved += int(world.stored_material_at((index%16)*6+2,(index/16)*8+1) != 20)
			moves.append(moved)
		expect(moves[0] > moves[1] and moves[1] > moves[2],"three admitted viscosities produce ordered actual lateral movement")
		witnesses.append({"kind":"viscosity","material_id":20,"workers":workers,"bays":96,"ticks":1,"values":[0,128,255],"moved_bays":moves})
		for threshold: int in [0,63,255]:
			var world: Variant = native_world(workers)
			for index: int in range(96):
				var x := (index%16)*6
				var y := (index/16)*8
				fill(world,x,y,4,3,1)
				fill(world,x+1,y+1,1,1,3)
				fill(world,x+2,y+1,1,1,23)
			activate(world,profile("salt-contact",[],[{"slot":2,"probability_threshold":threshold}]))
			for tick: int in range(4): expect(world.simulation_tick(),"native reaction fixture completes")
			var completed := 0
			for index: int in range(96):
				completed += int(world.stored_material_at((index%16)*6+1,(index/16)*8+1) == 24 and world.stored_material_at((index%16)*6+2,(index/16)*8+1) == 24)
			var products: PackedByteArray = world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128)).cells
			activate(world,profile("default"))
			expect(world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(128,128)).cells == products,"reaction configuration revert preserves consumed endpoints and witnessed products")
			reactions.append(completed)
		expect(reactions[0] < reactions[1] and reactions[1] < reactions[2] and reactions[2] == 96,"inclusive thresholds alter actual native Salt/Water products")
		witnesses.append({"kind":"reaction","slot":2,"workers":workers,"bays":96,"ticks":4,"thresholds":[0,63,255],"completed_brine_pairs":reactions,"witness":"actual stored products; native standalone test independently checks pair event ledger"})
		if workers == 4:
			expect(witnesses[1].moved_bays == moves and witnesses[2].completed_brine_pairs == reactions,"actual native outcomes match across 1 and 4 workers")

func owner_transactions() -> void:
	var world: Variant = native_world()
	bay(world)
	var worker := Worker.new()
	worker._world = world
	worker._workbench_extent = Vector2i(128,128)
	worker._running = true
	worker.material_audition_state()
	worker._consume_material_audition()
	var state: Dictionary = worker.material_audition_state()
	expect(state.ok,"synchronous real native owner publishes material readback")
	var command := request(state,profile("queued",[{"material_id":2,"density":500}]),true)
	var pending: Dictionary = worker.material_audition_request(command)
	expect(pending.get("status") == "pending" and world.get_material_audition_state().revision == 0,"enqueue preserves active configuration until its native owner boundary")
	expect(worker.material_audition_request(command).get("code") == "busy","concurrent intent cannot overwrite the single pending transaction")
	command.profile.materials[0].density = 700
	worker._consume_material_audition()
	var receipt: Dictionary = worker.material_audition_poll(pending.request_id)
	expect(receipt.ok and receipt.state.profile.materials[0].density == 500,"native owner consumes an immutable submitted profile copy")
	expect(worker.material_audition_cancel(pending.request_id).get("cancelled",true) == false,"late cancellation does not claim to reverse active configuration")
	state = worker.material_audition_state()
	command = request(state,profile("cancel",[{"material_id":2,"density":900}]),true)
	pending = worker.material_audition_request(command)
	expect(worker.material_audition_cancel(pending.request_id).get("code") == "cancelled","pending cancellation has a terminal owner receipt")
	worker._consume_material_audition()
	expect(world.get_material_audition_state().revision == state.revision,"cancelled intent is never activated later")
	command.session_id = "retired-host"
	expect(worker.material_audition_request(command).get("code") == "session_mismatch","wrong host session is refused")
	command.session_id = state.session_id
	command.expected_revision = 0
	expect(worker.material_audition_request(command).get("code") == "stale_revision","stale owner revision is refused")
	command.expected_revision = state.revision
	pending = worker.material_audition_request(command)
	worker._world = native_world()
	worker._world_generation += 1
	worker._consume_material_audition()
	expect(worker.material_audition_poll(pending.request_id).get("code") == "world_mismatch","World replacement retires queued intent before activation")
	expect(worker._world.get_material_audition_state().revision == 0,"replacement World never inherits stale queued configuration")
	state = worker.material_audition_state()
	pending = worker.material_audition_request(request(state,profile("stop"),true))
	worker.stop_worker()
	worker._running = false # This fixture has deliberately never started a thread.
	expect(worker.material_audition_poll(pending.request_id).get("code") == "stopped","owner stop retains a terminal pending refusal")
	expect(not worker.material_audition_request(request(state,profile("stopped"),true)).ok,"stopped native owner refuses subsequent intent")
	witnesses.append({"kind":"owner-adversaries","backend":"actual native World, synchronous existing worker mailbox; no worker thread in this fixture","cancelled_before_commit":true,"stale_and_session_refused":true,"replacement_retired_pending":true})

func snapshot_cell(x: int, y: int) -> int:
	return -1 if main == null or main.image == null else main.image.get_pixel(x,y).r8

func pause_workbench(value: bool) -> bool:
	if main.paused == value: return true
	return wb.toggle_pause() and main.paused == value

func wait_pause_ack() -> bool:
	var requested: int = main.simulation_worker.workbench_pause_request_serial()
	return await until(func() -> bool: return main.paused and main.latest_snapshot.paused and int(main.latest_snapshot.lab_context.get("workbench_pause_ack_serial",-1)) >= requested,"native owner acknowledges this ordinary Workbench pause")

func wait_idle() -> bool:
	return await until(func() -> bool: return not wb.busy() and not wb.applied.is_empty() and main.pending_microscenario_apply.is_empty(),"ordinary Workbench native acknowledgement")

func wait_panel() -> bool:
	if not await until(func() -> bool: return panel._pending.is_empty(),"Lab native transaction receipt"): return false
	expect(panel.last_receipt.get("ok",false),"mounted current-scene Lab receives native activation: " + str(panel.last_receipt))
	return bool(panel.last_receipt.get("ok",false))

func capture(label: String, viewport: Viewport) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	expect(image != null and not image.is_empty(),"graphical framebuffer exists for " + label)
	if image == null or image.is_empty(): return
	var path := evidence.path_join(label + ".png")
	expect(image.save_png(path) == OK,"graphical framebuffer saved for " + label)
	frames.append({"name":label,"file":path.get_file(),"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(path)})

func mounted_workbench() -> void:
	root.size = Vector2i(1600,1000)
	expect(change_scene_to_file("res://feature_launcher.tscn") == OK,"ordinary launcher loads")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	wb = main.shared_workbench
	if not await wait_idle(): return
	var policy := PackedInt32Array(wb.applied.liquid_policy)
	var start := Setup.fresh(policy,Vector2i(512,512))
	start.brush = 2
	start.edits = [[40,40,3,4,58],[41,41,1,1,2],[41,42,1,1,16],[20,480,472,8,58]]
	var admitted: bool = wb.apply(start)
	expect(admitted,"ordinary authored control fixture is admitted: " + str(wb.message))
	if not admitted: return
	if not await wait_idle(): return
	if not await until(func() -> bool: return snapshot_cell(41,41) == 2 and snapshot_cell(41,42) == 16,"native initial control cells published"): return
	wb.open_materials_lab()
	var lab: Variant = wb._materials_lab_panel
	panel = lab.audition_panel
	lab._tabs.current_tab = 5
	if not await until(func() -> bool: panel.refresh_scene(); return panel.active_state.get("ok",false),"current-scene native capability readback"): return
	expect(lab._tabs.get_tab_count() == 6 and lab._tabs.get_tab_title(5) == "Current scene","existing Lab extends Inspect and isolated comparison with a current-scene mode")
	lab.select_material(2)
	panel.use_active_as_draft()
	var token: String = panel.active_state.world_id
	var before_revision: int = panel.active_state.revision
	var density: SpinBox = panel._controls.get("material:2:density")
	expect(density != null,"current-scene native-supported Sand density control is mounted")
	if density == null: return
	density.value = 500
	for value: int in [600,700,500]: density.value = value
	expect(wb.material_audition.material_audition_state().revision == before_revision,"editing multiple draft control values sends no native transaction")
	panel._buttons.apply.pressed.emit()
	if not await wait_panel(): return
	expect(panel.active_state.world_id == token and panel.active_state.revision == before_revision + 1,"Lab Apply retains actual current native World and advances only configuration revision")
	expect(panel.last_receipt.tick_before == panel.last_receipt.tick_after,"actual native transaction never advances or rewinds a simulation tick")
	expect(capability(panel.active_state,"density",2).effective == 500,"mounted Lab shows actual activated effective density")
	var first_tick: int = main.latest_snapshot.tick_index
	expect(pause_workbench(false),"ordinary Workbench simulation resumes with Lab open")
	if not await until(func() -> bool: return main.latest_snapshot.tick_index >= first_tick + 12,"existing World continues with experimental density"): return
	expect(snapshot_cell(41,41) == 2 and snapshot_cell(41,42) == 16,"owner-published actual native cells witness low-density Sand remaining above Oil")
	panel._controls["material:2:density"].value = 3000
	panel._buttons.apply.pressed.emit()
	if not await wait_panel(): return
	if not await until(func() -> bool: return snapshot_cell(41,42) == 2,"native density exchange reacts to a live Apply while simulation continues"): return
	expect(panel.active_state.world_id == token,"running-scene material application never substitutes a candidate World")
	expect(pause_workbench(true),"ordinary Pause remains usable")
	if not await wait_pause_ack(): return
	panel._buttons.revert.pressed.emit()
	if not await wait_panel(): return
	expect(capability(panel.active_state,"density",2).effective == 500 and snapshot_cell(41,42) == 2,"Revert configuration restores density while consumed movement consequences remain")
	panel._name.text = "Audition native qualification"
	var path := ProjectSettings.globalize_path("user://audition-native-profile.json")
	expect(panel.save_profile(path).get("ok",false),"named profile saves with actual native source and compatibility identities")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(saved.payload.source_identity == panel.active_state.source_identity and saved.payload.native_compatibility == panel.active_state.native_compatibility,"profile provenance binds actual host runtime identity")
	var drift: Dictionary = panel.active_state.duplicate(true)
	drift.source_identity = "native-file-sha256:" + "0".repeat(64)
	expect(not Profiles.load_file(path,drift).get("ok",true),"source-mismatched saved profile is refused")
	panel._buttons.reset.pressed.emit()
	if not await wait_panel(): return
	expect(not panel.active_state.changes_behavior and panel.active_state.world_id == token,"Reset restores accepted defaults in the same World")
	var active_revision: int = panel.active_state.revision
	expect(panel.load_profile(path).get("ok",false),"supported saved profile reopens as a draft")
	expect(wb.material_audition.material_audition_state().revision == active_revision,"profile load does not silently activate")
	panel._buttons.apply.pressed.emit()
	if not await wait_panel(): return
	expect(capability(panel.active_state,"density",2).effective == 500,"loaded named profile activates through the same native owner contract")
	expect(wb.paint(Vector2i(100,100),28),"ordinary authored painting remains usable after live material changes")
	if not await until(func() -> bool: return snapshot_cell(100,100) == 28,"native ordinary painting acknowledgement"): return
	wb._name.text = "audition-qualification-start"
	expect(wb.save_setup(),"ordinary authored start remains saveable")
	expect(wb.message.contains("profile is separate"),"Save start explicitly warns that scene-local runtime configuration is saved separately")
	var saved_start := Setup.read_named(wb._name.text)
	expect(not saved_start.has("error") and not saved_start.setup.has("material_profile"),"saved authored setup does not pretend to serialize live configuration")
	await capture("current-scene-density",wb._materials_lab_window)
	var previous: Dictionary = panel.active_state.duplicate(true)
	expect(wb.load_setup(),"ordinary saved start reopens through explicit scene reconstruction")
	if not await wait_idle(): return
	if not await until(func() -> bool: panel.refresh_scene(); return panel.active_state.get("ok",false) and panel.active_state.world_id != token,"reopened start publishes a new World identity"): return
	expect(not panel.active_state.changes_behavior and panel.active_state.revision == 0,"saved start restores authored cells with accepted configuration defaults")
	expect(not wb.material_audition.request_material_audition(request(previous,profile("retired"),true)).get("ok",true),"old scene authority is refused after reopen")
	expect(snapshot_cell(100,100) == 28,"ordinary authored paint is present after save and reopen")
	panel.use_active_as_draft()
	expect(panel.load_profile(path).get("ok",false),"separately saved profile can be explicitly loaded for the new current World")
	for scene: Dictionary in Scenes.SCENES:
		var opened: Dictionary = wb.load_material_audition_demo(scene.id)
		expect(opened.get("ok",false),"ordinary authored demonstration opens: " + str(scene.id))
		if not await wait_idle(): return
		panel.refresh_scene()
		panel.use_active_as_draft()
		expect(PackedInt32Array(wb.applied.liquid_policy) == policy,"demo preserves its requested active solver policy without consuming a staged liquid draft")
		expect(wb.applied.edits.size() > 0,"demonstration contains actual ordinary authored material edits")
		var tick: int = main.latest_snapshot.tick_index
		expect(pause_workbench(false),"demonstration native simulation starts")
		if not await until(func() -> bool: return main.latest_snapshot.tick_index >= tick + 8,"demonstration native simulation continues"): return
		expect(pause_workbench(true),"demonstration simulation pauses")
		if not await wait_pause_ack(): return
		wb._materials_lab_window.hide()
		await capture(str(scene.id),root)
		witnesses.append({"kind":"ordinary-demo","scene_id":scene.id,"extent":wb.applied.extent,"authored_rectangles":wb.applied.edits.size(),"native_ticks_observed":main.latest_snapshot.tick_index})
	wb.open_materials_lab()
	lab._tabs.current_tab = 5
	lab.select_material(24)
	panel.refresh_scene()
	panel.use_active_as_draft()
	for size: Vector2i in [Vector2i(1000,650),Vector2i(1280,720)]:
		wb._materials_lab_window.size = size
		await process_frame
		await process_frame
		expect(lab.size.x <= size.x and lab.size.y <= size.y,"real mounted Lab is bounded by ordinary desktop client size")
		await capture("current-scene-%dx%d" % [size.x,size.y],wb._materials_lab_window)
	witnesses.append({"kind":"ordinary-workbench","original_world_id":token,"native_apply_while_running":true,"configuration_revert_preserves_cells":true,"ordinary_paint_save_reopen":true,"separate_profile_saved_and_reloaded":true,"graphical":DisplayServer.get_name() != "headless"})
	var controller: Variant = wb.material_audition
	main.simulation_worker.stop_worker()
	expect(not controller.material_audition_state().get("ok",true),"real threaded host stop makes current-scene application unavailable")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		expect(false,"native extension must be present")
	else:
		direct_adversaries()
		if failures == 0: actual_consumers()
		if failures == 0: owner_transactions()
		if failures == 0: await mounted_workbench()
	var result := {"checks":checks,"failures":failures,"status":"passed" if failures == 0 else "failed","godot":Engine.get_version_info().string,"display":DisplayServer.get_name(),"native_witnesses":witnesses,"frames":frames}
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("native-readback.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"\t") + "\n")
	print("MATERIAL_AUDITION_RESULT " + JSON.stringify(result))
	quit(1 if failures else 0)
