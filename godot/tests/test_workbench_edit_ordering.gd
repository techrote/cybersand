extends SceneTree

## Deterministic owner-boundary regression using an actual native World. It
## observes queue and receipt boundaries directly; the extracted-legacy and
## in-flight lease fixtures are explicitly controlled states, not timing races.
const Worker = preload("res://scripts/simulation_worker.gd")
const Equipment = preload("res://scripts/workbench_liquid_equipment.gd")
const PaintEditor = preload("res://scripts/workbench_paint_editor_controller.gd")
const Workbench = preload("res://scripts/shared_workbench.gd")
const ArtExecutor = preload("res://scripts/art_batch_executor.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
class SaveHost extends Control:
	var simulation_worker: RefCounted
	var pending_microscenario_apply := {}
	func queue_brush_mutation(x: int,y: int,radius: int,material: int) -> bool:
		return simulation_worker.queue_emit_disc(x,y,radius,material)
class SaveArtPanel extends Window:
	var executor: RefCounted
var checks := 0
var failures := 0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	print("EDIT_ORDER_CHECK ",label," ",value)
	if not value:
		failures += 1
		push_error(label)

func paint_request(worker: RefCounted, x: int, y: int, material: int) -> Dictionary:
	var state: Dictionary = worker.paint_state()
	return {"kind":"edit","cells":PackedInt32Array([x,y,material]),
		"expected_generation":state.generation,"expected_revision":state.revision,"expected_tick":state.tick}

func art_queue(worker: RefCounted, x: int = 30, y: int = 30) -> Dictionary:
	return worker.art_queue(PackedInt32Array([x,y]),58,Rect2i(0,0,128,128),[],worker.art_state().epoch)

func legacy_blocked(worker: RefCounted, label: String) -> void:
	check(not worker.queue_emit_disc(90,90,0,2) and not worker.queue_emit_cells(PackedInt32Array([91,90]),3),label)

func drain_art(worker: RefCounted) -> Dictionary:
	worker._consume_art()
	return worker.art_take_result()

func save_file_case(worker: RefCounted,save_host: Control,save_editor: Control,workers: int) -> bool:
	# Exercise the public Save method and real atomic file writer. The worker's
	# controlled extraction boundary removes timing from the regression; every
	# material mutation and agent receipt still comes from the native World.
	var bench := Workbench.new()
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	bench.host = save_host
	bench.paint_editor = save_editor
	save_editor.bench = bench
	var panel := SaveArtPanel.new()
	var executor := ArtExecutor.new()
	executor.wb = bench
	panel.executor = executor
	bench.art_batches = panel
	bench.applied = Setup.fresh(bridge.default_liquid_policy(),Vector2i(512,512))
	bench.applied.brush = 2
	bench._name.text = "edit-order-save-%d" % workers
	var path: String = Setup._path(bench._name.text)
	worker._consume_paint(true)
	check(bench.save_setup(),"public Save seeds a valid named start at the idle boundary")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(path)
	check(bench.paint(Vector2i(102,100),13) and worker._world.stored_material_at(102,100)==0,
		"ordinary Workbench brush records admission before native execution")
	check(not bench.save_setup() and FileAccess.get_file_as_bytes(path)==saved,
		"public Save refuses queued brush edits and preserves the existing file")
	var discs: Array[Vector4i] = worker._pending_emissions.duplicate()
	var cells: Array[Dictionary] = []
	worker._pending_emissions.clear()
	worker._legacy_edit_inflight = true
	check(not bench.save_setup() and FileAccess.get_file_as_bytes(path)==saved,
		"public Save refuses extracted brush edits and preserves the existing file")
	worker._apply_emissions(discs,cells)
	worker._consume_paint(true)
	worker._legacy_edit_inflight = false
	check(worker._world.stored_material_at(102,100)==13 and bench.save_setup(),
		"public Save resumes after the same ordinary brush is natively applied")
	var reopened: Dictionary = Setup.read_named(bench._name.text)
	check(not reopened.has("error") and reopened.setup.edits.size()==1 and reopened.setup.edits[0]==[102,100,2,13],
		"saved ordinary brush record reopens without claiming a queued result")
	saved = FileAccess.get_file_as_bytes(path)
	check(art_queue(worker,110,110).status=="queued","orphan-receipt Save fixture admits actual native art")
	worker._consume_art()
	check(worker._world.stored_material_at(110,110)==58 and worker.art_state().receipt_ready,
		"orphan-receipt fixture holds an actual applied native result")
	check(not bench.save_setup() and worker.art_state().receipt_ready and FileAccess.get_file_as_bytes(path)==saved,
		"public Save preserves an unconsumed agent receipt and the prior saved bytes")
	executor.record = bench.applied
	executor.active = true
	executor.waiting = true
	executor.stopping = true
	executor.epoch = worker.art_state().epoch
	executor.poll()
	check(not executor.active and not worker.art_state().receipt_ready and int(executor.last_receipt.get("changed",0))==1,
		"real agent executor consumes the native result and records its confirmed prefix")
	check(bench.save_setup(),"public Save succeeds after native receipt ownership is settled")
	reopened = Setup.read_named(bench._name.text)
	check(not reopened.has("error") and reopened.setup.edits.size()==2 and reopened.setup.edits.back()==[110,110,1,1,58],
		"reopened start retains both the human brush and confirmed agent cell")
	save_editor._save_hold = true
	check(not bench.paint(Vector2i(120,120),13) and worker._pending_emissions.is_empty()
		and bench.applied.edits.size()==2 and worker._world.stored_material_at(120,120)==0,
		"ordinary brush cannot bypass the partial-edit recovery hold or invalidate recovery history")
	save_editor._save_hold = false
	DirAccess.remove_absolute(path)
	executor.wb = null
	save_editor.bench = null
	bench.art_batches = null
	panel.free()
	bench.paint_editor = null
	bench.host = null
	# These controls were deliberately never mounted in a SceneTree. Release
	# their constructor-owned UI fields, including the two RefCounted panels.
	for owner: Object in [bench._generated_dialog,bench.water_spray,bench.equipment,bench]:
		for property: Dictionary in owner.get_property_list():
			if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0: continue
			var value: Variant = owner.get(property.name)
			if typeof(value)==TYPE_OBJECT and is_instance_valid(value) and value is Node:
				if value.get_parent()==null: value.free()
	bench.free()
	return true

func run_case(workers: int) -> void:
	var worker := Worker.new()
	var world: Variant = worker._world
	check(world.get_class()=="CyberNativeCellWorld" and world.has_method("stored_material_at"),"combined native runtime is loaded")
	if not world.has_method("stored_material_at"): return
	check(world.diagnostic_reset({"workers":workers}) and world.get_worker_threads()==workers,"actual native worker count %d" % workers)
	worker._workbench_extent = Vector2i(128,128)
	worker._running = true
	worker._paused = true
	worker._consume_paint(true)
	# Run the actual mounted editor's Save admission method against the same
	# native owner, without a second thread racing these controlled boundaries.
	var save_host := SaveHost.new()
	save_host.simulation_worker = worker
	var save_editor := PaintEditor.new()
	save_editor.host = save_host
	check(save_editor.save_allowed(),"Save admits an idle native boundary")
	var stale_request := paint_request(worker,32,30,3)
	check(art_queue(worker).status=="queued","art admission owns the shared mutation boundary")
	check(not save_editor.save_allowed(),"Save refuses an admitted but unexecuted agent chunk")
	check(worker.paint_queue(paint_request(worker,32,30,3)).status=="refused","PAINT cannot enter a pending art chunk")
	legacy_blocked(worker,"legacy emissions cannot enter a pending art chunk")
	var pending: Dictionary = worker._art_pending
	worker._art_pending = {}
	worker._art_inflight = true
	check(not save_editor.save_allowed(),"Save refuses the executing agent lease")
	check(worker.paint_queue(paint_request(worker,32,30,3)).status=="refused","synthetic executing-art lease excludes PAINT")
	legacy_blocked(worker,"synthetic executing-art lease excludes legacy commands")
	worker._art_inflight = false
	worker._art_pending = pending
	worker._consume_art()
	check(world.stored_material_at(30,30)==58,"first art chunk actually changed stored native material")
	check(worker.paint_state().revision==world.revision and worker.paint_state().generation==worker._world_generation,
		"art receipt and PAINT source fence become visible atomically")
	check(not save_editor.save_allowed(),"Save refuses actual applied agent cells before receipt consumption")
	check(worker.paint_queue(paint_request(worker,32,30,3)).status=="refused","unconsumed art completion still excludes PAINT")
	legacy_blocked(worker,"unconsumed art completion still excludes legacy commands")
	var receipt: Dictionary = worker.art_take_result()
	check(receipt.changed==1 and receipt.readback==[[30,30,0,58]],"art completion retains exact applied native content")
	check(save_editor.save_allowed(),"Save admission resumes after agent completion consumption")
	check(worker.paint_queue(stale_request).status=="refused","pre-art human source fence is invalidated")
	check(worker.paint_queue(paint_request(worker,32,30,3)).status=="queued","human operation enters after art receipt consumption")
	check(not save_editor.save_allowed(),"Save refuses admitted human PAINT")
	var refused: Dictionary = art_queue(worker,34,30)
	check(refused.status=="refused" and refused.retryable,"agent is told to retry while human PAINT owns the boundary")
	legacy_blocked(worker,"pending human operation excludes legacy commands")
	worker._consume_paint(true)
	check(worker.paint_state().busy and not worker.paint_state().receipt_ready,"human preflight retains the boundary between finite slices")
	refused = art_queue(worker,34,30)
	check(refused.status=="refused" and refused.retryable,"active human operation excludes agent chunks")
	worker._consume_paint(true)
	check(worker.paint_state().receipt_ready and world.stored_material_at(32,30)==3,"human operation completes in the same native World")
	check(not save_editor.save_allowed(),"Save refuses unconsumed human PAINT completion")
	refused = art_queue(worker,34,30)
	check(refused.status=="refused" and refused.retryable,"unconsumed human completion still excludes agent chunks")
	legacy_blocked(worker,"unconsumed human completion still excludes legacy commands")
	receipt = worker.paint_take_result()
	check(receipt.status=="completed" and receipt.after==PackedInt32Array([3]),"human completion exposes confirmed Water material")
	check(art_queue(worker,34,30).status=="queued","agent resumes after human completion consumption")
	receipt = drain_art(worker)
	check(receipt.changed==1 and world.stored_material_at(34,30)==58,"agent resumes without losing its native edit")

	check(worker.queue_emit_disc(70,70,0,13) and worker.queue_emit_cells(PackedInt32Array([71,70]),3),"ordinary legacy drawing still admits when editors are idle")
	check(not save_editor.save_allowed(),"Save refuses queued ordinary human brush edits")
	refused = art_queue(worker,36,30)
	check(refused.status=="refused" and refused.retryable,"pending legacy mutations precede new art")
	check(worker.paint_queue(paint_request(worker,72,70,2)).status=="refused","pending legacy mutations precede new PAINT")
	# Deterministically reproduce the extraction window: both queue arrays empty
	# while the owner still holds their unexecuted local commands.
	worker._mutex.lock()
	var discs: Array = worker._pending_emissions
	var cells: Array = worker._pending_cell_emissions
	worker._pending_emissions = []
	worker._pending_cell_emissions = []
	worker._legacy_edit_inflight = true
	worker._mutex.unlock()
	check(not save_editor.save_allowed(),"Save refuses extracted ordinary brush edits until native execution")
	refused = art_queue(worker,36,30)
	check(refused.status=="refused" and refused.retryable and worker.art_state().legacy_busy,
		"extracted legacy commands remain visible to agent admission")
	check(worker.paint_queue(paint_request(worker,72,70,2)).status=="refused",
		"extracted legacy commands remain visible to human admission")
	worker._apply_emissions(discs,cells)
	worker._consume_paint(true)
	check(world.stored_material_at(70,70)==13 and world.stored_material_at(71,70)==3,"extracted legacy commands apply in native order")
	worker._legacy_edit_inflight = false
	check(save_editor.save_allowed(),"Save admission resumes after ordinary edits and source publication")
	check(art_queue(worker,36,30).status=="queued","agent may continue after legacy context publication")
	check(drain_art(worker).changed==1,"post-legacy agent operation is retained")

	# Controlled extracted-transition and reset states: an equipment command
	# must not be admitted into the interval where replacement would discard it.
	var equipment_request := {"command":"configure","serial":1,"config":Equipment.empty_config()}
	worker._world_change_inflight = true
	check(not save_editor.save_allowed(),"Save refuses an extracted World transition")
	check(art_queue(worker,40,30).status=="refused" and worker.paint_queue(paint_request(worker,40,30,3)).status=="refused",
		"extracted World transition excludes both editors")
	legacy_blocked(worker,"extracted World transition excludes legacy authoring")
	check(not worker.queue_workbench_equipment(equipment_request) and worker._workbench_equipment_commands.is_empty(),
		"controlled extracted transition refuses equipment without enqueue")
	worker._world_change_inflight = false
	worker._reset_requested = true
	check(not worker.queue_workbench_equipment(equipment_request) and worker._workbench_equipment_commands.is_empty(),
		"controlled pending reset refuses equipment without enqueue")
	worker._reset_requested = false
	check(worker.queue_workbench_equipment(equipment_request) and worker._workbench_equipment_commands.size()==1,
		"controlled acknowledged-install state admits equipment again")
	var equipment_revision: int = world.revision
	worker._consume_workbench_emissions(true,{})
	var equipment_receipt: Dictionary = worker._workbench_equipment.receipt()
	check(equipment_receipt.configured and equipment_receipt.serial==1 and world.revision==equipment_revision,
		"admitted equipment configuration reaches the same owner without paused cell mutation")
	var paint_epoch: int = worker.paint_state().epoch
	var art_epoch: int = worker.art_state().epoch
	check(art_queue(worker,40,30).status=="queued","replacement fixture admits pending art")
	worker.queue_lab({"step":true})
	receipt = worker.art_take_result()
	check(receipt.status=="cancelled" and receipt.changed==0 and world.stored_material_at(40,30)==0,
		"World command explicitly cancels admitted but unstarted art")
	check(worker.paint_state().epoch>paint_epoch and worker.art_state().epoch>art_epoch,"World commands retain both editor epoch fences")
	worker._lab_request = {}
	worker._consume_paint(true)
	check(worker.paint_queue(paint_request(worker,42,30,3)).status=="queued","reset fixture admits pending human paint")
	art_epoch = worker.art_state().epoch
	worker.queue_reset(Vector2.ZERO)
	worker._reset_requested = false
	worker._consume_paint(true)
	receipt = worker.paint_take_result()
	check(receipt.status=="cancelled" and receipt.applied==0 and worker.art_state().epoch>art_epoch,
		"reset cancels human paint and advances the art fence without changing stored cells")
	check(art_queue(worker,44,30).status=="queued","settings-fence fixture admits art")
	worker._construction_settings_revision += 1
	receipt = drain_art(worker)
	check(receipt.status=="refused" and receipt.refused==1 and receipt.checked==0 and world.stored_material_at(44,30)==0,
		"art execution rechecks construction settings before writing")
	check(art_queue(worker,46,30).status=="queued","generation-fence fixture admits art")
	worker._world_generation += 1
	receipt = drain_art(worker)
	check(receipt.status=="refused" and receipt.checked==0 and world.stored_material_at(46,30)==0,
		"art execution rechecks native World generation before writing")
	check(save_file_case(worker,save_host,save_editor,workers),"entire public Save workflow completed")
	worker._running = false
	for node: Node in [save_editor._tools,save_editor._status,save_editor._copy,save_editor._paste,
			save_editor._undo_button,save_editor._redo_button,save_editor._cancel_button]:
		if node.get_parent()==null: node.free()
	save_editor.free()
	save_host.free()

func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		check(false,"source-built native GDExtension required")
		quit(1)
		return
	run_case(1)
	run_case(4)
	print("EDIT_ORDER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"native_workers":[1,4],
		"native_backend":"CyberNativeCellWorld","controlled_lease_fixtures":true}))
	quit(1 if failures else 0)
