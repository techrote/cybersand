extends SceneTree

# External observer of the frozen ordinary application. Mounted buttons supply
# creation, scene selection, enabling and Save/Load; ordinary brush and owner
# controls supply edits and Play/Pause. No World or physical state is injected.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Scenes = preload("res://scripts/object_shard_workbench_scenes.gd")
const INTACT_LABEL := "m4-recovery-intact"
const CUT_LABEL := "m4-recovery-cut"
var f: RefCounted
var evidence: Dictionary = {}
var prior: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _buttons(node: Node, caption: String, result: Array[Button]) -> void:
	if node is Button and node.text==caption: result.append(node)
	for child: Node in node.get_children(): _buttons(child,caption,result)

func _press(caption: String) -> bool:
	var found: Array[Button] = []
	_buttons(f.host,caption,found)
	if not f.expect(found.size()==1 and not found[0].disabled,"one enabled mounted button exists: "+caption): return false
	found[0].pressed.emit()
	evidence.mounted_actions.append({"caption":caption,"node_path":str(found[0].get_path()),
		"tick":int(f.host.latest_snapshot.tick_index),"world_generation":int(f.host.latest_snapshot.render_world_generation)})
	return true

func _snapshot() -> Dictionary:
	return {"extent":f.bench.applied.get("extent",[]).duplicate(),"paused":f.host.paused,
		"native_tick":int(f.host.latest_snapshot.tick_index),"world_generation":int(f.host.latest_snapshot.render_world_generation),
		"world_revision":int(f.host.latest_snapshot.world_revision),"worker_instance_id":f.host.simulation_worker.get_instance_id(),
		"runtime_enabled":f.runtime().enabled,"port_enabled":f.bench.object_shard_m4_port.enabled,
		"attached":f.diagnostics().get("attached",false),"body_count":f.body_count(),
		"native_instance_id":f.diagnostics().get("native_instance_id",0),"capabilities":f.runtime().capabilities.duplicate(true),
		"message":f.bench.message}

func _open() -> bool:
	process_frame.connect(f._observe_callback)
	set_meta("cybersand_feature","shared_workbench")
	f.host = load("res://main.tscn").instantiate()
	root.add_child(f.host)
	if not await f.until(f.installed,"fresh ordinary Workbench installed",60000): return false
	f.bench = f.host.shared_workbench
	return true

func _attach() -> bool:
	if not f.play(): return false
	if not await f.until(func():return f.runtime()!=null and f.diagnostics().get("attached",false),
		"ordinary Play attaches the native World and actual Rapier",60000): return false
	if not await f.pause(): return false
	return f.expect(int(f.diagnostics().get("native_instance_id",0))!=0 \
		and int(f.diagnostics().get("shared_main_space_id",0))==f.host.rapier_bridge.shared_space().get_id(),
		"attachment identifies one native owner and the ordinary shared Rapier space")

func _overview() -> bool:
	f.bench._camera.select(2)
	f.bench._camera.item_selected.emit(2)
	return await f.until(func():return f.coherent() and f.host.image!=null \
		and f.host.image.get_size()==Setup.extent_of(f.bench.applied),"overview uploads the complete actual canvas",60000)

func _supports() -> int:
	if not f.whole_canvas_coherent(): return -1
	var bytes: PackedByteArray = f.host.image.get_data()
	if bytes.size()!=512*512*2: return -1
	var total: int = 0
	for rect: Rect2i in Scenes.manifest("tower").support_rects:
		for y: int in range(rect.position.y,rect.end.y):
			for x: int in range(rect.position.x,rect.end.x):
				if int(bytes[(y*512+x)*2])==1: total+=1
	return total

func _save(label: String) -> Dictionary:
	f.bench._name.text = label
	if not _press("Save start [Ctrl+S]"): return {}
	var path: String = Setup._path(label)
	if not f.expect(FileAccess.file_exists(path),"ordinary Save writes the named authored file: "+label): return {}
	var parsed: Dictionary = Setup.read_named(label)
	if not f.expect(not parsed.has("error") and parsed.get("setup",{})==f.bench.applied,
		"saved named document exactly equals the acknowledged authored setup"): return {}
	var raw: String = FileAccess.get_file_as_string(path)
	var document: Variant = JSON.parse_string(raw)
	var keys: Array = document.keys() if document is Dictionary else []
	keys.sort()
	var expected: Array = Setup.ROOT_KEYS.duplicate()
	expected.sort()
	f.expect(document is Dictionary and keys==expected,"Save retains only the declared authored schema, with no evolved shard state")
	f.expect(f.bench.message.contains("Moving poses, burning progress and shard inventory are not a runtime save"),
		"ordinary Save explains its authored-start boundary to the owner")
	return {"label":label,"path":ProjectSettings.globalize_path(path),"sha256":FileAccess.get_sha256(path),
		"bytes":raw.to_utf8_buffer().size(),"root_keys":keys,"setup":parsed.get("setup",{}).duplicate(true),
		"native_tick":f.tick(),"body_count":f.body_count(),"support_material_cells":_supports()}

func _load(label: String, saved: Dictionary) -> bool:
	f.bench._name.text = label
	var before: Dictionary = _snapshot()
	var expected: Dictionary = Setup.read_named(label)
	if not f.expect(not expected.has("error"),"exact saved file passes ordinary schema validation and numeric canonicalization"): return false
	if not f.expect(FileAccess.get_sha256(Setup._path(label))==saved.get("sha256"),
		"fresh process reads the exact author-process named file: "+label): return false
	if not _press("Load start"): return false
	if not await f.until(f.installed,"ordinary Load commits a fresh authored native World: "+label,60000): return false
	f.expect(f.bench.applied==expected.get("setup",{}),"Load restores every canonical authored field and ordinary brush edit from the exact saved file: "+label)
	evidence.loaded_setups[label] = f.bench.applied.duplicate(true)
	f.expect(int(f.host.latest_snapshot.render_world_generation)>int(before.world_generation),
		"Load advances ordinary World generation instead of restoring a live runtime: "+label)
	if not await _attach() or not await _overview(): return false
	return true

func _author() -> void:
	var before: Dictionary = _snapshot()
	var authored_before: Dictionary = f.bench.applied.duplicate(true)
	evidence.default_before = before
	if not f.expect(before.extent==[2048,2048] and before.paused and not before.runtime_enabled \
		and not before.port_enabled,"ordinary default is a paused 2048 canvas with ObjectShard disabled"): return
	if not _press("Structures…") or not _press("Enable on current canvas"): return
	for _i: int in range(3): await process_frame
	var refused: Dictionary = _snapshot()
	evidence.default_refusal = refused
	f.expect(not refused.runtime_enabled and not refused.port_enabled and not refused.attached,
		"mounted Enable refuses ObjectShard attachment on the default 2048 canvas")
	f.expect(refused.world_generation==before.world_generation and refused.worker_instance_id==before.worker_instance_id \
		and refused.native_tick==before.native_tick and refused.world_revision==before.world_revision \
		and f.bench.applied==authored_before,"refused 2048 Enable leaves the ordinary World and authored start unchanged")
	f.expect(str(refused.message).contains("512 or 1024"),"2048 refusal tells the owner the supported authoring sizes")
	f.bench._extent[0].value = 1024
	f.bench._extent[1].value = 1024
	if not _press("New blank") or not await f.until(f.installed,"mounted New blank installs 1024 start",60000): return
	var pre_enable: Dictionary = _snapshot()
	if not f.expect(pre_enable.extent==[1024,1024] and pre_enable.paused,"ordinary size controls produce a paused 1024 canvas"): return
	if not _press("Enable on current canvas") or not await _attach() or not await _overview(): return
	var large: Dictionary = _snapshot()
	evidence.supported_1024 = large
	f.expect(large.extent==[1024,1024] and large.body_count==0 and large.attached \
		and large.world_generation==pre_enable.world_generation and large.worker_instance_id==pre_enable.worker_instance_id,
		"supported 1024 start attaches to its existing ordinary World without inventing bodies")
	if not _press("Multi-storey tower") or not await f.until(f.installed,"mounted Tower recipe installs supported 512 start",60000): return
	if not await _attach() or not await _overview(): return
	evidence.intact = _snapshot()
	f.expect(f.bench.applied.extent==[512,512] and f.body_count()==0 and _supports()==800,
		"ordinary Tower has all 800 supporting Wall cells and no detached body")
	f.expect(f.material_count(7)==2184 and f.material_count(43)==2232,"intact ordinary Tower contains the exact authored Wood and Brick populations")
	evidence.saved_intact = _save(INTACT_LABEL)
	if evidence.saved_intact.is_empty(): return
	if not await f.cut_supports("tower") or not f.play(): return
	if not await f.until(func():return f.body_count()==1,"ordinary support erasure naturally detaches one coherent body",60000): return
	if not await f.advance(12,"detached authored Tower progresses through native and real physical intervals") or not await f.pause(): return
	if not await _overview(): return
	f.expect(_supports()==6 and f.body_count()==1,"ordinary support brush retains six support cap cells and one real moving body")
	f.validate_physics()
	evidence.saved_cut = _save(CUT_LABEL)
	if evidence.saved_cut.is_empty(): return
	f.expect(evidence.saved_cut.setup.edits.size()>evidence.saved_intact.setup.edits.size(),
		"cut authored save retains ordinary support erasure history")
	evidence.cut_inventory = await f.validate_quantity_ledger()
	f.expect(evidence.cut_inventory.get("total_material_counts",[]).size()==256 \
		and evidence.cut_inventory.total_material_counts[7]==2184 and evidence.cut_inventory.total_material_counts[43]==2232,
		"raw native grid and owned inventory conserve the Tower Wood and Brick after support cuts")
	f.expect(FileAccess.get_sha256(Setup._path(INTACT_LABEL))==evidence.saved_intact.sha256 \
		and FileAccess.get_sha256(Setup._path(CUT_LABEL))==evidence.saved_cut.sha256,
		"actual detached runtime and inventory inspection do not rewrite either authored save")
	evidence.cut = _snapshot()

func _reopen() -> void:
	var path: String = OS.get_environment("CYBERSAND_AUTHOR_RECEIPT")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not f.expect(parsed is Dictionary and parsed.get("phase")=="author" \
		and parsed.get("failures",["missing"]).is_empty(),"fresh process consumes a completed positive author receipt"): return
	prior = parsed
	f.expect(not evidence.launch_nonce.is_empty() and evidence.launch_nonce!=prior.get("launch_nonce",""),
		"fresh external launch identity differs; actual separate subprocess lifetimes are retained by the runner")
	f.expect(OS.get_cmdline_user_args().has("--objectshard-m4-workbench") and f.bench.object_shard_m4_port.enabled,
		"fresh reopening explicitly opts into the evaluator ObjectShard session")
	evidence.author_receipt_sha256 = FileAccess.get_sha256(path)
	evidence.author_process_id = prior.process_id
	if not await _load(INTACT_LABEL,prior.saved_intact): return
	f.expect(_supports()==800 and f.body_count()==0,"fresh intact authored reopen reconstructs all supports and no detached body")
	f.expect(f.material_count(7)==2184 and f.material_count(43)==2232,"fresh intact Tower restores the exact structural material populations")
	evidence.intact = _snapshot()
	evidence.reopened_intact = prior.saved_intact.duplicate(true)
	if not await _load(CUT_LABEL,prior.saved_cut): return
	if f.body_count()==0:
		if not f.play() or not await f.until(func():return f.body_count()==1,"fresh cut recipe naturally detaches its own native body",60000): return
	if not f.play() or not await f.advance(12,"fresh cut authored start makes new native and actual physical progress") or not await f.pause(): return
	if not await _overview(): return
	f.expect(_supports()==6 and f.body_count()==1,"fresh cut authored reopen repeats support erasure and one natural detachment")
	f.validate_physics()
	evidence.cut_inventory = await f.validate_quantity_ledger()
	f.expect(evidence.cut_inventory.get("total_material_counts",[]).size()==256 \
		and evidence.cut_inventory.total_material_counts[7]==2184 and evidence.cut_inventory.total_material_counts[43]==2232,
		"fresh cut reopen independently conserves every authored Wood and Brick cell")
	f.expect(FileAccess.get_sha256(Setup._path(INTACT_LABEL))==prior.saved_intact.sha256 \
		and FileAccess.get_sha256(Setup._path(CUT_LABEL))==prior.saved_cut.sha256,
		"ordinary fresh-process Load and physical progression preserve both original authored files")
	evidence.reopened_cut = prior.saved_cut.duplicate(true)
	evidence.cut = _snapshot()

func _run() -> void:
	f = Fixture.new(self)
	var phase: String = OS.get_environment("CYBERSAND_AUTHORED_PHASE")
	evidence = {"schema":"objectshard-m4-authored-extent-reopen-v1","phase":phase,"process_id":OS.get_process_id(),
		"launch_nonce":OS.get_environment("CYBERSAND_LAUNCH_NONCE"),"loaded_setups":{},
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"observer_sha256":OS.get_environment("CYBERSAND_EXTERNAL_OBSERVER_SHA256"),
		"display_driver":DisplayServer.get_name(),"operating_system":OS.get_name(),"mounted_actions":[],
		"scope":"Headless mounted creation/enable/recipe/Save/Load signals (actual OS is operating_system), ordinary brush and Play/Pause controls, actual native worker and Rapier; authored starts only, no evolved runtime checkpoint or physical GPU claim"}
	if await _open():
		if phase=="author": await _author()
		elif phase=="reopen": await _reopen()
		else: f.expect(false,"registered external observer phase selected")
	f.validate_display()
	evidence.display_coherence = f.display_witness()
	evidence.inventory_witnesses = f.inventory_witnesses
	evidence.checks = f.checks
	evidence.failures = f.failures.duplicate()
	await f.close()
	var output := FileAccess.open(OS.get_environment("CYBERSAND_EXTERNAL_RECEIPT"),FileAccess.WRITE)
	if output!=null:
		output.store_string(JSON.stringify(evidence,"\t")+"\n")
		output.close()
	print(JSON.stringify(evidence))
	quit(0 if f.failures.is_empty() and output!=null else 1)
