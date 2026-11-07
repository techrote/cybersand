extends SceneTree
## #528 actual mounted Godot UI -> #526 exclusive native owner -> rendered observation.
## Fake Responses transport only; this is NOT a paid live-model acceptance.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

var host: Control
var wb: Control
var mount: RefCounted
var panel: Control
var checks := 0
var failed := 0
var evidence_dir := ""

func _initialize() -> void:
	set_meta("cybersand_feature","shared_workbench")
	_run.call_deferred()

func check(ok: bool, reason: String) -> bool:
	checks += 1
	if not ok:
		failed += 1
		push_error("WB528_MOUNTED: " + reason)
	return ok

func until(predicate: Callable, reason: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return check(predicate.call(),reason)

func _ready_native() -> bool:
	return wb != null and not wb.applied.is_empty() and not wb.busy() 		and host.latest_snapshot != null and host.paused

func _ready_blank() -> bool:
	return _ready_native() and wb.applied.extent == [2048,2048] 		and host.pending_microscenario_apply.is_empty()

func _ready_panel_task() -> bool:
	return panel.client.is_active() and not panel._start_pending

func _next_request(serial: int) -> bool:
	return panel.client.is_active() and panel.client._serial > serial 		and not panel.client.pending_fake_payload().is_empty()

func _fake(name: String, id: String, arguments: Dictionary) -> void:
	var model_response := {
		"id":"wb528-"+id,"status":"completed","output":[{
			"type":"function_call","name":name,"call_id":id,
			"arguments":JSON.stringify(arguments)
		}]
	}
	var client: Node = panel.client
	client.receive_fake_response(client.current_epoch(),client._serial,
		200,model_response)

func _receipt() -> Dictionary:
	var input: Array = panel.client.pending_fake_payload().get("input",[])
	if input.is_empty():
		return {}
	var item: Variant = input[0]
	if not item is Dictionary or item.get("type") != "function_call_output":
		return {}
	var value: Variant = JSON.parse_string(str(item.get("output","")))
	return value if value is Dictionary else {}

func _capture_original() -> void:
	var payload: Dictionary = panel.client.pending_fake_payload()
	var input: Array = payload.get("input",[])
	check(input.size() == 2,"native observe did not attach an actual image item")
	if input.size() < 2:
		return
	var content: Array = input[1].get("content",[])
	if not check(content.size() == 2 and content[1].get("type") == "input_image",
			"native image was not forwarded as OpenAI input_image"):
		return
	var url: String = str(content[1].get("image_url",""))
	check(url.begins_with("data:image/png;base64,"),"native image must use PNG data URL")
	var image: PackedByteArray = Marshalls.base64_to_raw(url.trim_prefix("data:image/png;base64,"))
	check(image.size() > 8 and image[0] == 137 and image[1] == 80,
		"copied original PNG signature not present")
	if evidence_dir.is_empty() or image.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var file: FileAccess = FileAccess.open(evidence_dir.path_join("mounted-native-frame.png"),FileAccess.WRITE)
	if check(file != null,"cannot retain original mounted PNG"):
		file.store_buffer(image)
		file.close()
	var receipt: Dictionary = _receipt()
	var data: FileAccess = FileAccess.open(evidence_dir.path_join("mounted-native-receipt.json"),FileAccess.WRITE)
	if check(data != null,"cannot retain exact native/render identity"):
		data.store_string(JSON.stringify(receipt,"  ")+"\n")
		data.close()

func _run() -> void:
	evidence_dir = OS.get_environment("WB_AGENT_EVIDENCE_DIR")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	wb = host.shared_workbench
	if not await until(Callable(self,"_ready_native"),"shared workbench startup/worker pause"):
		_finish()
		return
	mount = wb._agent_mount
	panel = mount.panel() if mount != null else null
	if not check(panel != null and panel.proposal_overlay.get_parent() == host.world_view,
			"opt-in agent panel not mounted in existing client"):
		_finish()
		return
	check(not panel.visible,"opt-in panel unexpectedly visible by default")
	check(mount._toggle.text.contains("opt-in"),"toggle absent from shared workbench")
	mount._toggle.button_pressed = true
	check(panel.visible,"user opt-in toggle cannot reveal panel")
	var fresh: Dictionary = Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(2048,2048))
	if not check(wb.apply(fresh),"real 2048-square native owner declined blank workbench") 			or not await until(Callable(self,"_ready_blank"),"native blank extent never installed"):
		_finish()
		return
	panel._task.text = "Construct an exact native Wall and verify it."
	panel._model.text = "test-vision-model-not-called"
	panel._region[0].value = 1120
	panel._region[1].value = 220
	panel._region[2].value = 64
	panel._region[3].value = 64
	panel.client.configure_fake_transport_for_tests(true)
	panel._on_start()
	if not await until(Callable(self,"_ready_panel_task"),"native host authorization missing"):
		_finish()
		return
	check(mount._authorised,"model started without native task authorization")
	var s: int = panel.client._serial
	_fake("observe","obs1",{"region":{"x":1144,"y":260,"width":8,"height":8},"detail":"cells"})
	if not await until(func() -> bool: return _next_request(s),
			"native observe / real frame did not complete"):
		_finish()
		return
	var observed: Dictionary = _receipt()
	check(observed.get("status") == "observed" 		and observed.get("image_status") == "matched_post_draw" 		and observed.get("native_material_ids",[]).size() == 64,
		"matched native observation does not have 64 real cells")
	_capture_original()
	s = panel.client._serial
	_fake("prepare_edit","prep1",{"observation_id":observed.get("observation_id",""),
		"operations":[{"shape":"rectangle","x0":1144,"y0":260,
			"x1":1146,"y1":262,"material":58,"replace_only_material":null}]})
	if not await until(func() -> bool: return _next_request(s),
			"real native prepare did not complete"):
		_finish()
		return
	var prepared: Dictionary = _receipt()
	check(prepared.get("status") == "proposed" 		and prepared.get("changed_cells") == 9,
		"authoritative nine-cell rectangle preflight failed")
	check(panel.proposal_overlay.visible 		and panel.proposal_overlay._cells.size() == 9,
		"visible overlay not bound to actual prepared native cells")
	check(mount.project_cell(Vector2i(1144,260)) is Rect2,
		"cell-to-screen projection missing after opt-in")
	s = panel.client._serial
	_fake("apply_edit","apply1",{"proposal_id":prepared.get("proposal_id","")})
	if not await until(func() -> bool: return _next_request(s),
			"real native verified application did not complete"):
		_finish()
		return
	var applied: Dictionary = _receipt()
	check(applied.get("status") == "applied" 		and applied.get("readback",[]).size() == 9 		and applied.get("authored_start",{}).get("status") == "recorded",
		"native readback and authored-start commit missing")
	check(not panel.proposal_overlay.visible,"applied proposal overlay remained visible")
	# The fake API is deliberately held after the real application receipt.
	var stale_epoch: int = panel.client.current_epoch()
	var stale_serial: int = panel.client._serial
	var edits_before: int = wb.applied.edits.size()
	check(wb.paint(Vector2i(1155,270),58),"human brush rejected during held model response")
	check(wb.applied.edits.size() >= edits_before + 1,
		"human authored intent was not preserved")
	check(not panel.client.is_active(),"human edit did not revoke held API response")
	await until(func() -> bool: return not panel._retire_pending,
		"native task retirement after human intervention did not complete")
	var old_response: Dictionary = {
		"id":"late-model","status":"completed","output":[{
			"type":"function_call","name":"apply_edit","call_id":"late-call",
			"arguments":JSON.stringify({"proposal_id":prepared.get("proposal_id","")})
		}]
	}
	panel.client.receive_fake_response(stale_epoch,stale_serial,200,old_response)
	check(not panel.client.is_active() and not mount._authorised,
		"late API result revived a retired worker-authoring task")
	# No API keys or paid calls; actual native edit and Godot frame were used.
	_finish()

func _finish() -> void:
	print("WB_AGENT_528 mounted real-native checks %d, failures %d" % [checks,failed])
	if is_instance_valid(host):
		host.queue_free()
	await process_frame
	quit(1 if failed else 0)
