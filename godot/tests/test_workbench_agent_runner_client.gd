extends SceneTree
## Decoder/fencing and profile UI controls. No model service or synthetic World.
const RunnerClient = preload("res://scripts/workbench_agent_runner_client.gd")
const AgentPanel = preload("res://scripts/workbench_agent_panel.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WB_PROVIDER_UI_CLIENT: " + detail)

func _run() -> void:
	var panel := AgentPanel.new()
	root.add_child(panel)
	await process_frame
	check(panel.client.get_script() == RunnerClient,"ordinary panel does not use Python Runner transport")
	check(panel._provider.item_count == 5 and not panel._live.button_pressed,"provider choice or explicit live gate missing")
	panel._provider.select(2)
	panel._provider_selected(2)
	check(panel._credential_environment() == "NVIDIA_API_KEY" and not panel._key_button.disabled,"NVIDIA has no usable local key control")
	check(panel._key_entry.secret,"provider key entry is not masked")
	panel._provider.select(3)
	panel._provider_selected(3)
	check(panel._key_button.disabled,"local model incorrectly requires an API key")
	panel._provider.select(4)
	panel._provider_selected(4)
	check(panel._profile_data.get("provider") == "fixture" and panel._model.text == "scripted-provider-not-model","explicit Fixture does not select actual fixture profile")
	check(not panel._live.button_pressed,"fixture selection enabled live API calls")
	var client := RunnerClient.new()
	root.add_child(client)
	client.configure_fake_transport_for_tests(true) # memory-only diagnostics for protocol controls
	client._active = true
	client._epoch = 7
	client._runner_epoch = 7
	client._scope = {"cell_limit":16384}
	var dispatched: Array = []
	client.tool_requested.connect(func(name: String,args: Dictionary,epoch: int,id: String) -> void:
		dispatched.append({"name":name,"args":args,"epoch":epoch,"id":id}))
	var parsed := JSON.new()
	check(parsed.parse('{"type":"native_request","id":"python-step","tool":"step","args":{"ticks":4}}') == OK,"JSON wire fixture failed")
	client._handle_frame(parsed.data)
	check(dispatched.size() == 1 and dispatched[0].args.ticks is int and dispatched[0].args.ticks == 4,"real JSON numeric fields not safely normalized before native dispatcher")
	client._pending_call_id = ""
	check(parsed.parse('{"type":"native_request","id":"fraction","tool":"step","args":{"ticks":4.5}}') == OK,"fraction fixture failed")
	client._handle_frame(parsed.data)
	check(dispatched.size() == 1 and not client.is_active(),"fractional native count dispatched")
	client._handle_frame({"type":"native_request","id":"late","tool":"step","args":{"ticks":1}})
	check(dispatched.size() == 1,"late native call escaped epoch/Stop fencing")
	client._retirement_ack = {"status":"retired"}
	check(not client._native_stop_acknowledged(),"retirement label masquerades as native Stop")
	client._retirement_ack = {"status":"retired","owner_receipt":{"status":"stopped","no_further_agent_mutations":true}}
	check(client._native_stop_acknowledged(),"real native Stop acknowledgement not recognized")
	client._rate_endpoint = "test-provider:https://example.invalid"
	var expiry: float = Time.get_unix_time_from_system()+30.2
	client._accept_rate_history([{"expires_utc":expiry,"tokens":10},{"expires_utc":expiry,"tokens":20}])
	client.stop_task("pacing continuity test")
	var retained: Array = client._rate_history_for_start()
	check(retained.size() == 1 and retained[0].tokens == 30 and float(retained[0].expires_utc) >= expiry,"Stop/restart resets or shortens owned provider reservations")
	client._rate_endpoint = "other-provider:https://other.invalid"
	check(client._rate_history_for_start().is_empty(),"unrelated provider inherits reservation history")
	client._rate_endpoint = "test-provider:https://example.invalid"
	check(not client._rate_history_for_start().is_empty(),"provider selection clears retained pacing grants")
	var raw := JSON.stringify(client.diagnostic_records())
	check(raw.contains("runner.ignored_stale") and raw.contains("runner.error"),"fence/failure evidence discarded")
	client.queue_free()
	panel.queue_free()
	await process_frame
	await process_frame
	print("WB_PROVIDER_UI_CLIENT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
