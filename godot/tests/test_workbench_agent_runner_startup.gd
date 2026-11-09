extends SceneTree
## Real Python/Git/Windows pipe preflight; synthetic owner ACK, NO World/inference.
const Client = preload("res://scripts/workbench_agent_runner_client.gd")
var checks := 0
var failures := 0
var client: Node

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WB_RUNNER_STARTUP: " + detail)

func wait_until(predicate: Callable, seconds: int = 50) -> bool:
	var end := Time.get_ticks_msec()+seconds*1000
	while not predicate.call() and Time.get_ticks_msec() < end:
		await process_frame
	return predicate.call()

func _acknowledge_stop(_reason: String) -> void:
	client.record_diagnostic("native_retirement_ack",{"status":"retired","ready_for_new_task":true,
		"owner_receipt":{"status":"stopped","no_further_agent_mutations":true}})

func _run() -> void:
	var previous_key := OS.get_environment("OPENAI_API_KEY")
	client = Client.new()
	root.add_child(client)
	var template_path := ProjectSettings.globalize_path("res://../tools/workbench_api_agent/profiles/openai-responses.example.json")
	var parsed := JSON.new()
	check(parsed.parse(FileAccess.get_file_as_string(template_path)) == OK,"example profile unavailable")
	var profile: Dictionary = parsed.data
	var forbids_inference := float(profile.spend.get("authorised_ceiling_usd",1)) == 0 and str(profile.spend.get("authorisation_ref","unexpected")) == ""
	check(forbids_inference,"startup regression requires an explicitly unauthorised profile")
	if not forbids_inference:
		quit(1)
		return
	# Keep the original integer JSON lexemes; Godot parses them as floats.
	client.profile_path = template_path
	client.provider_mode = "openai_responses"
	client.allow_live = true
	client.compute_consent = true
	client.task_finished.connect(_acknowledge_stop)
	var scope := {"region":{"x":0,"y":0,"width":8,"height":8},
		"allowed_materials":["Hard Wall","Empty"],"protected_regions":[],"cell_limit":4096}
	for attempt: int in range(2):
		# The example's zero authorization ceiling forces refusal before any
		# model probe/HTTP call, even with a valid-length dummy credential.
		OS.set_environment("OPENAI_API_KEY","" if attempt == 0 else "dummy-local-startup-only-not-a-real-key-012345")
		client.record_diagnostic("native_authorization_ack",{"status":"authorized","generation":3,
			"task_id":"startup-test-%d" % attempt,"cell_limit":4096})
		check(client.begin_task("Test preflight only; do not infer.","gpt-6-luna",scope),"child start refused")
		var complete: bool = await wait_until(func() -> bool: return not client._finished_receipt.is_empty())
		check(complete,"startup hung before explicit preflight refusal")
		if not complete:
			client.stop_task("test timeout")
			_acknowledge_stop("test timeout")
			await wait_until(func() -> bool: return client._runner_pid == 0,5)
			break
		var reason := str(client._finished_receipt.get("reason",""))
		check(reason.contains("credential missing") if attempt == 0 else reason.contains("charged provider needs"),"wrong preflight outcome: " + reason)
		check(client._finished_receipt.get("stop_acknowledged") == true,"preflight Stop ACK missing")
		check(await wait_until(func() -> bool: return client._runner_pid == 0,5),"child not cleaned after refusal")
	var raw := JSON.stringify(client.diagnostic_records())
	check(not raw.contains("Fatal Python error"),"fatal daemon-stdin shutdown error")
	check(not raw.contains('"kind":"http.request"'),"preflight unexpectedly dispatched inference")
	check(raw.contains("source_check") and raw.contains("funding_check"),"startup phases are not inspectable")
	OS.set_environment("OPENAI_API_KEY",previous_key)
	client.queue_free()
	# Control regression: phase display and watchdog must revoke dispatch once,
	# never present a timeout/process exit as an actual native Stop ACK.
	var probe := Client.new()
	root.add_child(probe)
	probe.configure_fake_transport_for_tests(true)
	probe._active = true
	probe._runner_epoch = probe._epoch
	probe._handle_frame({"type":"event","event":"runner.preflight",
		"payload":{"phase":"source_check","detail":"Checking local source"}})
	check(probe._stage == "Checking local source","preflight phase not visible")
	var retire_requests := [0]
	probe.task_finished.connect(func(_reason: String) -> void: retire_requests[0] += 1)
	probe._startup_deadline = Time.get_ticks_msec()-1
	probe._check_startup_deadline()
	probe._check_startup_deadline()
	check(not probe.is_active() and retire_requests[0] == 1,"startup watchdog does not revoke once")
	check(not probe._native_stop_acknowledged(),"watchdog fabricated native Stop ACK")
	probe.queue_free()
	await process_frame
	print("WB_RUNNER_STARTUP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
