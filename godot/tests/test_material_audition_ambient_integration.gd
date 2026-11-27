extends "res://tests/test_ambient_default_off_integration.gd"

# Resulting-source integration proof using the ordinary Lab UI, native mailbox,
# authored scene persistence and existing manual/ambient Rapier actors. Shared
# fixture helpers retain their established operation watchdogs and never read
# the worker's live native World from the main thread.
const MaterialScenes = preload("res://scripts/workbench_material_audition_scenes.gd")
const IntegrationWatchdogs = preload("res://tests/support/ci_execution_policy.gd")
var panel: Control
var initial_owners := {}
var initial_bodies: Array = []
var admitted_controls: Array = []


func fixture(policy: PackedInt32Array) -> Dictionary:
	var start: Dictionary = super.fixture(policy)
	# An enclosed Sand/Oil pair gives an actual cell-exchange witness while all
	# four existing actor producer families retain their separate ordinary area.
	start.edits.append_array([[40,40,3,4,58],[41,41,1,1,2],[41,42,1,1,16]])
	return start


func cell(x: int, y: int) -> int:
	return -1 if host.image == null else host.image.get_pixel(x,y).r8


func active_density() -> int:
	for row: Dictionary in panel.active_state.get("capabilities",[]):
		if row.get("kind") == "material" and row.get("material_id") == 2 and row.get("property") == "density":
			return int(row.effective)
	return -1


func wait_panel(label: String) -> bool:
	if not await until(func() -> bool: return panel._pending.is_empty(), label): return false
	return check(panel.last_receipt.get("ok",false), label + ": actual owner receipt accepted")


func ordinary_installed() -> bool:
	# Material demonstrations intentionally contain no actors. Requiring the
	# actor-bearing fixture's non-null Rapier session would reject a successful
	# ordinary replacement after the old actor session was correctly retired.
	return bench != null and not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty()


func same_owners(label: String) -> void:
	check(host.simulation_worker.get_instance_id() == initial_owners.worker,
		label + ": existing simulation worker retained")
	check(int(host.simulation_worker.paint_state().generation) == initial_owners.generation,
		label + ": actual native World generation retained")
	check(host.physical_actor_session.get_instance_id() == initial_owners.session and body_ids() == initial_bodies,
		label + ": existing Rapier session and every actual body retained")
	check(panel.active_state.world_id == initial_owners.world,
		label + ": material configuration remains in the same observed native World")
	var controls: Array = bench.applied.actors.map(func(a: Dictionary): return Catalog.control_for(a))
	check(controls == admitted_controls, label + ": no material operation changes authored actor authority")
	check(Catalog.control_for(bench.actor(bench.applied,101)).source == "human",
		label + ": manually controlled actor remains human-owned")
	check(Catalog.control_for(bench.actor(bench.applied,303)).policy == "ambient",
		label + ": explicitly opted-in actor retains its ambient producer")

func inspect_authored_region(session: Node, region: Rect2i, result: Dictionary) -> void:
	var observed: Dictionary = await session.inspect_region(region)
	result.merge(observed)

func verify_demo_admission(demo_id: String) -> bool:
	var area := Rect2i(84,84,1,1)
	var original: Dictionary = await bench.capture_batch_source(area)
	if not check(original.get("ok",false),"read the native Art target before demo admission"): return false
	var material := 0 if original.config.source_cells.decode_u16(0) == 58 else 58
	var worker_generation: int = host.simulation_worker.paint_state().generation
	var art: RefCounted = bench.art_batches.executor
	var submitted: Dictionary = art.submit([{"shape":"pixels","material":material,"points":[[84,84]]}],area,[],[material])
	if not check(submitted.status == "queued" and art.active,"Art admitted a real write before its native receipt"): return false
	var refused: Dictionary = bench.load_material_audition_demo(demo_id)
	if not check(not refused.get("ok",true) and not str(refused.get("error","")).is_empty()
			and art.active and not art.stopping and host.pending_microscenario_apply.is_empty(),
			"the Material demo preserves the pending Art writer and queues no replacement"): return false
	if not check(not bench.load_actor_sandbox("barrels",16)
			and not bench.set_sandbox_capacity(Catalog.Capacity.defaults())
			and not bench.set_actor_tuning(303,bench.actor(bench.applied,303).options)
			and art.active and not art.stopping and host.pending_microscenario_apply.is_empty(),
			"Actor scene, capacity and tuning preserve the Art writer before acknowledgement"): return false
	if not check(not bench.load_object_shard_scene("tower") and art.active and not art.stopping
			and host.pending_microscenario_apply.is_empty(), "Structures preserves the active Art writer"): return false
	if not await until(func() -> bool: return not art.active,"Art owner settles after refused demo"): return false
	if not check(art.result.status == "completed" and int(art.result.changed) == 1,
			"the Art owner receives the original native write acknowledgement"): return false
	var inspection := {}
	inspect_authored_region(bench.architecture_lab.session,area,inspection)
	if not check(bench.architecture_lab.authoring_busy(),"Architecture is inspecting the actual native result"): return false
	refused = bench.load_material_audition_demo(demo_id)
	if not check(not refused.get("ok",true) and not str(refused.get("error","")).is_empty()
			and host.pending_microscenario_apply.is_empty(),"the Material demo preserves Architecture's active source read"): return false
	if not check(not bench.load_actor_sandbox("barrels",16) and host.pending_microscenario_apply.is_empty(),
			"Actor sandbox leaves the in-flight Architecture source read intact"): return false
	if not await until(func() -> bool: return not inspection.is_empty(),"Architecture source inspection settles"): return false
	return check(inspection.get("ok",false) and inspection.cells.decode_u16(0) == material
			and int(inspection.generation) == worker_generation and not bench.architecture_lab.authoring_busy(),
			"Architecture reads the acknowledged Art edit in the original native World")


func exercise() -> void:
	check(Catalog.Capacity.defaults().logical_limit == 8 and Catalog.MAX_AMBIENT_CONTROLLERS == 8,
		"ordinary defaults retain eight logical actors and the AMBIENT policy budget")
	check_off("ordinary startup before opening material tools", true)
	if not await until(func() -> bool: return cell(41,41) == 2 and cell(41,42) == 16,
		"initial native Sand/Oil control pair"): return
	var ambient := Catalog.control_for(bench.actor(bench.applied,303))
	ambient.policy = "ambient"
	ambient.ambient = Profile.blank("material-audition-ambient-coexistence")
	ambient.ambient.modules = [Profile.make_module("seek_material")]
	check(bench.set_actor_control(303,ambient), "explicit ambient admission uses the existing external actor slot")
	admitted_controls = bench.applied.actors.map(func(a: Dictionary): return Catalog.control_for(a)).duplicate(true)
	check(bench.art_batches == null and bench.architecture_lab == null, "ordinary actor scene keeps both authoring panels lazy")
	bench.open_materials_lab()
	var lab: Control = bench._materials_lab_panel
	panel = lab.audition_panel
	lab._tabs.current_tab = 5
	if not await until(func() -> bool: panel.refresh_scene(); return panel.active_state.get("ok",false),
		"ordinary current-scene material readback"): return
	lab.select_material(2)
	panel.use_active_as_draft()
	if not check(panel._controls.has("material:2:density"), "native-supported Sand density is mounted"): return
	initial_owners = {"worker":host.simulation_worker.get_instance_id(),
		"generation":int(host.simulation_worker.paint_state().generation),
		"session":host.physical_actor_session.get_instance_id(),"world":panel.active_state.world_id}
	initial_bodies = body_ids()
	check(bench.art_batches == null and bench.architecture_lab == null, "opening Materials Lab does not open Art or Architecture")
	bench.open_architecture_lab()
	var stage_session: Node = bench.architecture_lab.session
	var art: Window = bench._ensure_art_batches()
	var provider: Object = art.provider
	var art_serial: int = provider.serial
	var history_actions: int = bench.paint_editor.completed_actions
	var region := Rect2i(39,39,5,6)
	var before: Dictionary = await bench.capture_batch_source(region)
	if not check(before.get("ok",false), "Architecture reads the actual paused Sand/Oil material region"): return
	var default_revision: int = int(panel.active_state.revision)
	panel._controls["material:2:density"].value = 500
	check(bench.material_audition.material_audition_state().revision == default_revision,
		"editing the Draft sends no native transaction or actor command")
	panel._buttons.apply.pressed.emit()
	if not await wait_panel("paused low-density Apply"): return
	check(active_density() == 500 and int(panel.active_state.revision) == default_revision + 1,
		"Apply activates only the requested native configuration revision")
	same_owners("paused Apply")
	var larger_budget: Dictionary = Catalog.Capacity.defaults()
	larger_budget.logical_limit = 16
	check(bench.set_sandbox_capacity(larger_budget), "retained actor prepare reaches native material admission")
	if not await until(func() -> bool: return not bench.busy() and host.pending_microscenario_apply.is_empty(),
		"retained preparation receives its terminal native receipt"): return
	check(host.microscenario_error.contains("Reset live material overrides") and not bench.applied.has("sandbox_capacity"),
		"native refusal identifies active configuration and leaves authored capacity untouched")
	panel.refresh_scene()
	check(active_density() == 500 and int(panel.active_state.revision) == default_revision + 1,
		"refused retained prepare preserves the live override and revision")
	same_owners("refused retained actor preparation")
	var after: Dictionary = await bench.capture_batch_source(region)
	check(after.get("ok",false) and after.get("config",{}).get("source_cells") == before.config.source_cells,
		"paused configuration Apply preserves the native material plane observed by Architecture")
	check(bench.architecture_lab.session == stage_session and bench.art_batches.provider == provider
		and not provider.active and provider.serial == art_serial, "Apply retains the stage session and idle provider without issuing a proposal")
	check(bench.paint_editor.completed_actions == history_actions, "configuration Apply adds no authoring history operation")
	bench.architecture_lab.hide()
	art.hide()
	check(bench.toggle_pause(), "ordinary Play starts with explicit ambient and manual actors")
	if not await progress(24,"native and Rapier progression with active material configuration"): return
	check(cell(41,41) == 2 and cell(41,42) == 16, "low-density Sand remains above Oil in the actual native pair")
	check(host.physical_actor_session._ambient_perception.diagnostics().queries > 0,
		"ambient decisions continue using ordinary published materials")
	check(host.physical_actor_session.submit_workbench_action(101,{"move":Vector2.RIGHT,"effort":0.25},
		{"q":false,"e":false,"s":false,"boost":false},false), "human action is still admitted beside the ambient actor")
	panel._controls["material:2:density"].value = 3000
	panel._buttons.apply.pressed.emit()
	if not await wait_panel("live high-density Apply"): return
	if not await until(func() -> bool: return cell(41,42) == 2,
		"live material exchange while both actor owners remain active"): return
	same_owners("live Apply")
	check(bench.toggle_pause(), "ordinary Pause remains available")
	var requested: int = host.simulation_worker.workbench_pause_request_serial()
	if not await until(func() -> bool:
		return host.paused and host.latest_snapshot.paused and int(host.latest_snapshot.lab_context.get("workbench_pause_ack_serial",-1)) >= requested,
		"native owner acknowledges this exact pause"): return
	panel._buttons.revert.pressed.emit()
	if not await wait_panel("configuration Revert"): return
	check(active_density() == 500 and cell(41,42) == 2,
		"Revert restores configuration while preserving material movement already caused")
	check(panel.last_receipt.tick_before == panel.last_receipt.tick_after,
		"Revert neither advances nor rewinds the native simulation tick")
	same_owners("Revert")
	bench._name.text = "mergedown-material-ambient-start"
	check(bench.save_setup(), "ordinary authored start saves with live material profile and opted-in actor")
	var saved := Setup.read_named(bench._name.text)
	check(not saved.has("error") and not saved.setup.has("material_profile"),
		"authored save does not silently persist the session-only material configuration")
	check(Catalog.control_for(bench.actor(saved.setup,303)).ambient == ambient.ambient,
		"authored save retains the explicit ambient profile")
	var old: Dictionary = panel.active_state.duplicate(true)
	check(bench.load_setup(), "authored reopen uses ordinary scene replacement")
	if not await until(installed,"reopened authored actor scene"): return
	if not await until(func() -> bool:
		panel.refresh_scene()
		return panel.active_state.get("ok",false) and panel.active_state.world_id != old.world_id,
		"replacement native World publishes a fresh configuration identity"): return
	check(not panel.active_state.changes_behavior and int(panel.active_state.revision) == 0,
		"reopen restores default material configuration")
	check(Catalog.control_for(bench.actor(bench.applied,303)).ambient == ambient.ambient,
		"reopen preserves the authored ambient profile")
	var stale := {"session_id":old.session_id,"world_id":old.world_id,"expected_revision":old.revision,
		"profile":{"schema_version":1,"profile_id":"retired","materials":[],"reactions":[]}}
	check(not bench.material_audition.request_material_audition(stale).get("ok",true),
		"old material authority cannot affect the newly owned actor scene")
	var demo_id: String = str(MaterialScenes.SCENES[0].id)
	if not await verify_demo_admission(demo_id): return
	check(bench.load_material_audition_demo(demo_id).get("ok",false), "material demo enters the shared authored replacement path")
	if not await until(ordinary_installed,"material demo acknowledgement"): return
	check(bench.applied.actors.is_empty() and host.physical_actor_session == null,
		"actor-free material demo retires the previous Rapier actor owner")
	check(bench._name.text == "materials-" + demo_id and bench._pending_material_demo.is_empty() and bench._pending_ambient_example.is_empty(),
		"material demo acknowledgement consumes only its own completion metadata")
	check(bench.load_ambient_example("ambient-oil-water"), "ambient example enters the same authored replacement path")
	if not await until(installed,"ambient example acknowledgement"): return
	check(bench._name.text == "ambient-oil-water" and bench._pending_material_demo.is_empty() and bench._pending_ambient_example.is_empty(),
		"ambient acknowledgement retains its name without a stale material-demo completion")
	check(bench.applied.actors.size() > 0 and bench.applied.actors.size() <= 8,
		"actual ambient demonstration uses the existing bounded actor host")


func finish() -> void:
	print("MATERIAL_AMBIENT_INTEGRATION ", JSON.stringify(Catalog._json_value({"checks":checks,"failures":failures,
		"phases":phases,"elapsed_msec":Time.get_ticks_msec()-begun,"godot":Engine.get_version_info(),
		"operation_watchdog_seconds":IntegrationWatchdogs.seconds("operation_seconds"),
		"platform":OS.get_name(),"display":DisplayServer.get_name(),
		"scope":"Native Workbench, authored actor and material configuration integration"})))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
