extends SceneTree

# Runs the real Main/Shared Workbench owner, native candidate-and-swap builder,
# threaded cellular World and retained Rapier session. Only keyboard input is
# supplied deterministically through the same leased actor-control interface.
# Each invocation handles one install OR a fresh-process authored-start reopen.
const Setup = preload("res://scripts/workbench_setup.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

class PilotHost extends "res://scripts/main.gd":
	var qualification_pilot := false
	func _publish_workbench_keyboard() -> void:
		if not qualification_pilot:
			super._publish_workbench_keyboard()
			return
		if paused or shared_workbench == null or physical_actor_session == null: return
		physical_actor_session.submit_workbench_action(shared_workbench.selected_id(),
			{"move":Vector2(0.65,-0.25),"aim":Vector2.RIGHT,"effort":0.7},
			{"q":false,"e":false,"s":false,"boost":false},false)

var host: Control
var panel: Control
var checks := 0
var failures: Array[String] = []
var record: Dictionary = {}
var source: Dictionary = {}
var source_path := ""
var save_name := ""
var phase := ""
var completed := false
var start_msec := 0

func _initialize() -> void:
	start_msec = Time.get_ticks_msec()
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, detail: String) -> bool:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("WORKBENCH_LANDSCAPE: " + detail)
	return ok

func until(predicate: Callable, detail: String) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return check(true,detail)
		if host != null and host.simulation_worker.has_failed(): break
		await process_frame
	return check(false,detail+" / "+(str(host.microscenario_error)+" / "+str(panel.message) if host != null else "no host"))

func idle() -> bool:
	return panel != null and not panel.applied.is_empty() and not panel.busy() \
		and host.pending_microscenario_apply.is_empty()

func generation() -> int:
	return int(host.latest_snapshot.render_world_generation) if host.latest_snapshot != null else -1

func digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func decode_claim(value: Variant) -> Variant:
	# Qualified observation v1 preserves signed integers as tagged decimals.
	# Decode only on the test side; never feed this observation to a constructor.
	if value is Dictionary:
		if value.size() == 1 and value.has("integer_decimal"):
			return int(value.integer_decimal)
		var result := {}
		for key: String in value: result[key] = decode_claim(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(decode_claim(item))
		return result
	return value

func reference_cells(recipe: Dictionary) -> PackedByteArray:
	# Independent ordered stamp replay; never use Setup.rectangles() to make
	# the expected pixels checked against that constructor's installed result.
	var size := Setup.extent_of(recipe)
	var cells := PackedByteArray()
	cells.resize(size.x*size.y)
	for stamp: Array in recipe.edits:
		if stamp.size() == 5:
			for y: int in range(int(stamp[1]),int(stamp[1])+int(stamp[3])):
				for x: int in range(int(stamp[0]),int(stamp[0])+int(stamp[2])):
					cells[y*size.x+x] = int(stamp[4])
		else:
			var radius := int(stamp[2])
			for y: int in range(maxi(0,int(stamp[1])-radius),mini(size.y,int(stamp[1])+radius+1)):
				for x: int in range(maxi(0,int(stamp[0])-radius),mini(size.x,int(stamp[0])+radius+1)):
					if (x-int(stamp[0]))**2+(y-int(stamp[1]))**2 <= radius*radius:
						cells[y*size.x+x] = int(stamp[3])
	return cells

func current_cells(size: Vector2i) -> PackedByteArray:
	var cells := PackedByteArray()
	if not check(host.image != null and host.image.get_size() == size,"actual native publication has exact installed extent"): return cells
	cells.resize(size.x*size.y)
	for y: int in size.y:
		for x: int in size.x: cells[y*size.x+x] = host.image.get_pixel(x,y).r8
	return cells

func verify_grid(recipe: Dictionary, label: String) -> Dictionary:
	var size := Setup.extent_of(recipe)
	var expected := reference_cells(recipe)
	var requested: Dictionary = host.simulation_worker.material_capture_request(generation(),size.x*size.y*2)
	if not check(requested.get("ok",false),label+" stored-material capture admitted: "+str(requested)): return {}
	var token := int(requested.token)
	if not await until(func() -> bool: return not host.simulation_worker.material_capture_poll(token).is_empty(),label+" exclusive native owner completed material readback"):
		host.simulation_worker.material_capture_cancel(token)
		return {}
	var capture: Dictionary = host.simulation_worker.material_capture_poll(token)
	# Release the read-only capture without committing a Flatten or changing the
	# authored document, editor epoch, World, physical state or history.
	host.simulation_worker.material_capture_finish(token,false)
	if not check(capture.get("ok",false) and capture.get("extent") == size \
		and capture.get("cells") is PackedByteArray and capture.cells.size() == expected.size()*2,
		label+" exact native stored-material extent and LE16 byte count"): return {}
	var stored: PackedByteArray = capture.cells
	check(digest(stored) == capture.sha256,label+" native complete readback SHA256 recomputes")
	var actual := PackedByteArray()
	actual.resize(expected.size())
	var mismatches := 0
	var first_mismatches: Array = []
	for index: int in expected.size():
		var material := stored.decode_u16(index*2)
		if material != expected[index]:
			mismatches += 1
			if first_mismatches.size() < 8:
				first_mismatches.append([index%size.x,int(index/size.x),expected[index],material])
		actual[index] = material if material <= 255 else 0
	check(mismatches == 0,label+" matches all %d stored native material cells (%d mismatches)" % [expected.size(),mismatches])
	check(current_cells(size) == expected,label+" actual material publication also matches the complete source grid")
	return {"expected_sha256":digest(expected),"actual_sha256":digest(actual),
		"native_stored_materials_le16_sha256":capture.sha256,
		"extent":[size.x,size.y],"cells":expected.size(),"mismatches":mismatches,
		"first_mismatches":first_mismatches,"native_tick":host.latest_snapshot.tick_index,
		"world_generation":generation(),"world_revision":host.latest_snapshot.world_revision,
		"simulation_world_revision":host.latest_snapshot.simulation_world_revision}

func source_and_install() -> bool:
	source_path = OS.get_environment("WB_LANDSCAPE_SETUP")
	save_name = OS.get_environment("WB_LANDSCAPE_NAME")
	phase = OS.get_environment("WB_LANDSCAPE_PHASE")
	if not check(phase in ["install","reopen"] and not Setup._path(save_name).is_empty(),"explicit valid phase and isolated save name"): return false
	if not check(FileAccess.file_exists(source_path),"exact authored Setup input exists"): return false
	var parser := JSON.new()
	if not check(parser.parse(FileAccess.get_file_as_string(source_path)) == OK,"authored source JSON parses"): return false
	if not check(Setup.validate(parser.data).is_empty(),"authored Setup validates: "+Setup.validate(parser.data)): return false
	source = parser.data
	# JSON numbers are floats in Godot. Match the ordinary Setup reader's
	# validated integer canonicalization before structural equality checks.
	for index: int in source.edits.size():
		source.edits[index] = Array(PackedInt32Array(source.edits[index]))
	var source_hash := FileAccess.get_sha256(source_path)
	record.merge({"map_name":save_name,"phase":phase,"source_setup_sha256":source_hash,
		"source_edits":source.edits.size(),"extent":source.extent,
		"source_grid_sha256":digest(reference_cells(source))})
	var wanted := OS.get_environment("WB_LANDSCAPE_EXPECTED_SHA256")
	if not wanted.is_empty() and not check(source_hash == wanted,"source bytes match pinned manifest SHA256"): return false
	wanted = OS.get_environment("WB_LANDSCAPE_EXPECTED_GRID_SHA256")
	if not wanted.is_empty() and not check(record.source_grid_sha256 == wanted,"independent source grid matches pinned manifest SHA256"): return false
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	record.native_rectangle_capacity = int(bridge.workbench_start_rectangle_capacity())
	if not check(record.native_rectangle_capacity == 32768 and Setup.native_rectangle_budget() == 32768,
		"installed native adapter advertises existing 32768 rectangle capacity"): return false
	var runs := Setup.rectangles(source)
	if not check(not runs.has("error"),"authored source compiles completely into rectangles"): return false
	record.construction_rectangles = runs.runs.size()/5
	root.size = Vector2i(1600,1000)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(PilotHost)
	root.add_child(host)
	current_scene = host
	panel = host.shared_workbench
	if not await until(idle,"ordinary Shared Workbench initial owner installed"): return false
	check(host.paused,"Workbench starts paused")
	panel._name.text = save_name
	if phase == "install":
		# Use the ordinary named Load start path; source bytes remain unchanged.
		if not check(not FileAccess.file_exists(Setup._path(save_name)),"install has a fresh isolated save location"): return false
		DirAccess.make_dir_recursive_absolute(Setup.DIRECTORY)
		if not check(DirAccess.copy_absolute(source_path,Setup._path(save_name)) == OK,"stage exact authored file for ordinary Load start"): return false
	else:
		if not check(FileAccess.file_exists(Setup._path(save_name)),"fresh process finds prior authored save"): return false
	var old_generation := generation()
	if not check(panel.load_setup(),"Load start admits original or saved landscape / "+str(panel.message)): return false
	if not await until(func() -> bool: return idle() and generation()>old_generation and host.physical_actor_session != null \
		and host._physical_terrain_ready,"native World and real retained actor adoption acknowledged"): return false
	var expected: Dictionary = Setup.read_named(save_name).setup
	if not await until(func() -> bool: return host.image != null and host.image.get_size() == Setup.extent_of(expected) \
		and host.latest_snapshot.world_revision == host.latest_snapshot.simulation_world_revision,"complete native material publication catches up"): return false
	record.grid_initial = await verify_grid(expected,"installed authored start")
	if phase == "install": check(panel.applied.edits == source.edits,"native adoption preserves every original authored rectangle")
	else:
		check(panel.applied.edits.size() == source.edits.size()+2,"reopened start preserves original rectangles and two controlled edits")
		check(panel.applied.edits.slice(0,source.edits.size()) == source.edits,"fresh-process reopen loses no original geometry")
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var actor: Dictionary = session.workbench_actor_state(panel.selected_id())
	check(not actor.is_empty() and not session.bodies().is_empty(),"selected retained actor has a real Rapier body")
	check(panel.applied.actors == expected.actors,"source actor definitions and spawn survive construction")
	record.actor = {"id":panel.selected_id(),"model":panel.applied.actors[0].model,
		"body_count":session.bodies().size(),"physics_engine":ProjectSettings.get_setting("physics/2d/physics_engine","")}
	return failures.is_empty()

func inspect_claim() -> bool:
	var old_capture := int(host.tower_context.get("micro_capture_serial",0))
	host.microscenario_capture()
	if not await until(func() -> bool: return int(host.tower_context.get("micro_capture_serial",0))>old_capture,"exclusive native owner publishes its observation record"): return false
	var capture: Dictionary = host.tower_context.micro_capture
	var checked := Contract.validate(capture.definition)
	if not check(checked.get("ok",false),"installed full definition independently validates"): return false
	var runs := Setup.rectangles(panel.applied)
	check(checked.definition.rectangles == runs.runs,"native host retains complete ordered construction geometry")
	check(capture.definition_hash == checked.hash,"full installed definition digest recomputes exactly")
	var observation: Dictionary = capture.liquid_host_observation_record
	var claims: Dictionary = decode_claim(observation.values.host_claims.values)
	check(observation.identity.definition_hash == checked.hash and claims.definition_hash == checked.hash,
		"native acknowledgement, host identity and full validated source agree")
	check(not observation.values.host_eligible_for_full_matched_evidence and observation.values.host_claims.status == "unverified",
		"observation retains explicit limited claim authority")
	if runs.runs.size() > 32768:
		check(not claims.definition.has("rectangles") and claims.has("definition_projection"),"only oversized redundant host rectangle payload is omitted")
		if claims.has("definition_projection"):
			check(claims.definition_projection.rectangle_count == runs.runs.size()/5 \
				and claims.definition_projection.integer_word_count == runs.runs.size() \
				and claims.definition_projection.validated_complete_definition_sha256 == checked.hash,
				"projection identifies exact full geometry count and canonical SHA256")
	else:
		check(not claims.has("definition_projection") and claims.definition.rectangles == runs.runs,"below-boundary host observation remains complete")
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt",{}).duplicate(true)
	check(receipt.get("workbench_extent") == Setup.extent_of(panel.applied)
		and int(receipt.get("initial_body_count",-1)) == host.physical_actor_session.bodies().size()
		and receipt.get("receipt_hash","") == observation.identity.native_receipt_hash,
		"native committed extent, initial body count and receipt match the adopted host observation")
	if receipt.has("canonical_bytes"):
		receipt["canonical_bytes_hex"] = receipt.canonical_bytes.hex_encode()
		receipt.erase("canonical_bytes")
	record.host_claim = {"definition_sha256":checked.hash,"rectangle_count":runs.runs.size()/5,
		"projection":claims.get("definition_projection",{}),"identity":observation.identity,
		"native_construction_receipt":receipt}
	return failures.is_empty()

func progress(ticks: int, label: String) -> bool:
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var before: Dictionary = session.workbench_actor_state(panel.selected_id())
	var native_before := int(host.latest_snapshot.tick_index)
	var rapier_before := int(session.tick)
	var peak_force := 0.0
	host.qualification_pilot = true
	if host.paused and not check(panel.toggle_pause(),"resume native and Rapier play"): return false
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline and (int(host.latest_snapshot.tick_index)<native_before+ticks or session.tick<rapier_before+ticks):
		if host.simulation_worker.has_failed(): break
		await process_frame
		var state: Dictionary = session.workbench_actor_state(panel.selected_id())
		peak_force = maxf(peak_force,Vector2(state.get("controller",{}).get("applied_force",Vector2.ZERO)).length())
	var after: Dictionary = session.workbench_actor_state(panel.selected_id())
	var distance: float = Vector2(before.position).distance_to(Vector2(after.position))
	var observation := {"native_ticks_before":native_before,"native_ticks_after":int(host.latest_snapshot.tick_index),
		"rapier_ticks_before":rapier_before,"rapier_ticks_after":int(session.tick),
		"actor_start":[before.position.x,before.position.y],"actor_end":[after.position.x,after.position.y],
		"distance":distance,"peak_applied_force":peak_force}
	record[label] = observation
	check(not host.simulation_worker.has_failed(),"native World remains healthy while playing")
	check(observation.native_ticks_after >= native_before+ticks and observation.rapier_ticks_after >= rapier_before+ticks,"both native and Rapier clocks advance through actual gameplay")
	check(distance > 0.25 and peak_force > 0.0,"leased pilot produces force and actual actor displacement")
	host.qualification_pilot = false
	if not host.paused: check(panel.toggle_pause(),"pause after measured gameplay")
	return await until(func() -> bool: return idle() and host.latest_snapshot.paused,"pause acknowledged by exclusive owner")

func refused_replacements() -> bool:
	var old_generation := generation()
	var old_epoch: int = host._physical_epoch
	var old_setup: Dictionary = panel.applied.duplicate(true)
	var old_session: CyberPhysicalActorSession = host.physical_actor_session
	if host.paused: check(panel.toggle_pause(),"old valid World running during invalid replacement")
	var malformed := old_setup.duplicate(true)
	malformed.edits.append([4,4,-1,2,58])
	check(not panel.apply(malformed),"malformed construction refuses without dropping running World")
	var geometry_error := str(panel.message)
	var invalid_policy := old_setup.duplicate(true)
	invalid_policy.liquid_policy[0] = 0
	var requested: bool = panel.apply(invalid_policy)
	check(requested,"invalid native policy reaches the queued construction path")
	if requested and not await until(idle,"refused replacement request retires"): return false
	var native_error := str(panel.message)+" / "+str(host.microscenario_error)
	check(native_error.contains("malformed_policy"),"actual native constructor reports the malformed-policy refusal")
	check(generation() == old_generation and host._physical_epoch == old_epoch \
		and host.physical_actor_session == old_session and panel.applied == old_setup,
		"refused native policy replacement preserves World generation, real actor owner and accepted start")
	record.refusals = {"malformed_geometry":geometry_error,"invalid_native_policy":native_error,
		"invalid_request_queued":requested,"generation_before":old_generation,"generation_after":generation(),
		"physical_epoch_before":old_epoch,"physical_epoch_after":host._physical_epoch}
	return await progress(20,"progression_after_refusal")

func paint_save() -> bool:
	# Reconstruct the authored start after live dynamics before comparing its
	# saved cells. A starting recipe is not a checkpoint of moving Water/body state.
	var previous := generation()
	if not check(panel.restore_start(),"ordinary Restore start accepts large source again"): return false
	if not await until(func() -> bool: return idle() and generation()>previous,"authored start restored for controlled edits"): return false
	var grid := reference_cells(panel.applied)
	var size := Setup.extent_of(panel.applied)
	var position := Vector2i(-1,-1)
	for y: int in range(32,size.y-32,16):
		for x: int in range(32,size.x-32,16):
			var clear := true
			for dy: int in range(-8,9):
				for dx: int in range(-8,9):
					if grid[(y+dy)*size.x+x+dx] != 0: clear = false
			if clear:
				position = Vector2i(x,y)
				break
		if position.x >= 0: break
	if not check(position.x >= 0,"controlled empty paint region exists"): return false
	panel._brush.value = 4
	if not check(panel.paint(position,Setup.WALL),"ordinary paint command admitted"): return false
	if not await until(func() -> bool: return idle() and host.image.get_pixelv(position).r8 == Setup.WALL,"paint applied to actual native material cell"): return false
	panel._brush.value = 2
	if not check(panel.paint(position,0),"ordinary erase command admitted"): return false
	if not await until(func() -> bool: return idle() and host.image.get_pixelv(position).r8 == 0 \
		and host.image.get_pixelv(position+Vector2i(3,0)).r8 == Setup.WALL,"controlled erasure preserves surrounding painted ring"): return false
	record.grid_saved = await verify_grid(panel.applied,"painted authored start")
	panel._name.text = save_name
	if not check(panel.save_setup(),"ordinary Save start writes authored large map / "+str(panel.message)): return false
	var loaded := Setup.read_named(save_name)
	if not check(not loaded.has("error") and loaded.setup == panel.applied,"saved Setup preserves all authored geometry and actor settings"): return false
	record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),
		"sha256":FileAccess.get_sha256(Setup._path(save_name)),"edits":loaded.setup.edits.size(),
		"grid_sha256":digest(reference_cells(loaded.setup)),"paint_center":[position.x,position.y]}
	return failures.is_empty()

func exercise() -> void:
	if not check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge"),"actual native extension loaded"): return
	if not await source_and_install(): return
	if not await inspect_claim(): return
	if not await progress(60,"progression"): return
	if not await refused_replacements(): return
	if phase == "install":
		if not await paint_save(): return
	else:
		var loaded := Setup.read_named(save_name)
		record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),
			"sha256":FileAccess.get_sha256(Setup._path(save_name)),"edits":loaded.setup.edits.size(),
			"grid_sha256":digest(reference_cells(loaded.setup))}
	check(FileAccess.get_sha256(source_path) == record.source_setup_sha256,"immutable external authored source bytes never changed")
	var screenshot := OS.get_environment("WB_LANDSCAPE_SCREENSHOT")
	if not screenshot.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(screenshot) == OK,"actual application framebuffer saved")
	completed = failures.is_empty()

func run() -> void:
	record = {"schema_version":1,"campaign":"WORKBENCH-HOST-CLAIMS-001",
		"os":OS.get_name(),"engine":Engine.get_version_info().string,"process_id":OS.get_process_id(),
		"display":DisplayServer.get_name(),"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION")}
	await exercise()
	check(completed,"complete native install/play/edit/save or fresh-process reopen qualification")
	if is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	record.merge({"checks":checks,"failures":failures,"completed":completed,
		"elapsed_msec":Time.get_ticks_msec()-start_msec})
	var target := OS.get_environment("WB_LANDSCAPE_REPORT")
	if not target.is_empty():
		var file := FileAccess.open(target,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(record,"\t")+"\n")
		else: check(false,"qualification report file could not be written")
	print("WORKBENCH_LANDSCAPE ",JSON.stringify({"map_name":save_name,"phase":phase,
		"completed":completed,"checks":checks,"failures":failures,
		"progression":record.get("progression",{}),"elapsed_msec":record.elapsed_msec}))
	quit(0 if completed and failures.is_empty() else 1)
