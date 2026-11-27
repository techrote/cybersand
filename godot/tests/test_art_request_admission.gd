extends SceneTree
## Actual native Workbench Send paths with asynchronous outbound preparation.
## Numeric loopback has no listener; no external service or paid inference.
const Setup = preload("res://scripts/workbench_setup.gd")
const Provider = preload("res://scripts/art_provider.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
var host: Control
var bench: Control
var panel: Window
var endpoint := ""
var checks := 0
var failures: Array[String] = []
var starts: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_REQUEST_ADMISSION_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)

func until(predicate: Callable, label: String, seconds: float = 15) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	var ok: bool = predicate.call()
	if not ok: check(false,label)
	return ok

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() and not bench.paint_editor.busy() \
		and host.pending_microscenario_apply.is_empty() and not host.simulation_worker.paint_state().busy

func settled() -> bool:
	return not panel.provider.active and not panel.provider.request_preparation_active() \
		and not panel.provider.response_preparation_active()

func event_count(kind: String) -> int:
	if panel.provider.log_path.is_empty(): return 0
	return FileAccess.get_file_as_string(panel.provider.log_path).count('"kind":"'+kind+'"')

func prompt_count(prompt: String) -> int:
	var count := 0
	for turn: Dictionary in panel.conversation:
		if turn.get("role") == "user" and turn.get("content") == prompt: count += 1
	return count

func configure(prompt: String, large: bool = true) -> void:
	panel.current_provider = "LM Studio"
	panel.source.select(0)
	panel.model.text = "request-admission-fixture"
	panel.endpoint.text = endpoint
	panel.input_mode.select(1)
	panel.input.text = prompt
	panel.image_input.button_pressed = false
	panel.turn_limit.value = 1
	panel.seconds.value = 1
	panel.context_mode.select(0)
	panel.minimum_interval.value = 0
	panel.run_seconds.value = 0
	panel.spend_limit.value = 0
	panel.conversation = [{"role":"user","content":"Synthetic retained context "+"x".repeat(600000)}] if large else []
	panel.conversation_revision += 1
	panel.next_request_ms = 0
	panel.provider_wait_ms = 0
	panel.show()

func finite_run_checks() -> void:
	configure("unbounded direct run must not prepare")
	panel.turn_limit.value = 0
	panel.run_seconds.value = 0
	var serial_before: int = panel.provider.serial
	var starts_before := starts.size()
	var requests_before := event_count("request")
	panel.send_prompt()
	check(panel.provider.serial == serial_before and starts.size() == starts_before
		and event_count("request") == requests_before and not panel.provider.active
		and not panel.provider.request_preparation_active(),
		"zero turn and duration limits refuse before provider identity, preparation or HTTP admission")
	check(panel._pending_provider_send.is_empty() and panel.remaining_turns == 0
		and panel.input_error.contains("finite") and prompt_count("unbounded direct run must not prepare") == 0,
		"unbounded refusal explains the finite limit without inventing an admitted user turn")
	var old_input_price: float = panel.input_price.value
	var old_output_price: float = panel.output_price.value
	panel.spend_limit.value = 1
	panel.input_price.value = 1
	panel.output_price.value = 1
	panel.send_prompt()
	check(panel.provider.serial == serial_before and starts.size() == starts_before
		and event_count("request") == requests_before and panel.input_error.contains("finite"),
		"a positive spending ceiling alone cannot admit an indefinite direct run")
	panel.input_price.value = old_input_price
	panel.output_price.value = old_output_price

	configure("finite direct request count",false)
	panel.turn_limit.value = 2
	starts_before = starts.size()
	panel.send_prompt()
	check(starts.size() == starts_before+1 and panel.remaining_turns == 1
		and panel.run_deadline_ms == 0 and prompt_count("finite direct request count") == 1,
		"positive Turns preserves direct admission when the duration limit is disabled")
	panel.stop_all("Fixture Stop after finite turn admission")
	await until(settled,"finite turn request cancellation drains")
	check(panel.remaining_turns == 0 and not panel.provider.active,
		"Stop retires a finite turn run without an automatic continuation")

	configure("finite direct duration",false)
	panel.turn_limit.value = 0
	panel.run_seconds.value = 2
	starts_before = starts.size()
	panel.send_prompt()
	check(starts.size() == starts_before+1 and panel.remaining_turns == -1
		and panel.run_deadline_ms > Time.get_ticks_msec() and prompt_count("finite direct duration") == 1,
		"positive Run s preserves direct admission with a finite deadline when Turns is zero")
	panel.stop_all("Fixture Stop after finite duration admission")
	await until(settled,"finite duration request cancellation drains")
	check(panel.remaining_turns == 0 and panel.run_deadline_ms == 0 and not panel.provider.active,
		"Stop clears the bounded duration run and its remaining requests")

func admission_checks() -> void:
	configure("small captured prompt",false)
	var starts_before := starts.size()
	panel.send_prompt()
	check(starts.size() == starts_before+1 and prompt_count("small captured prompt") == 1,
		"small synchronous request records its captured user turn exactly once")
	check(panel._pending_provider_send.is_empty() and panel.last_send_timing.request_started,
		"synchronous start consumes the pending admission before send returns")
	await until(settled,"small absent-server request finishes")

	configure("cancel before outbound admission")
	var requests_before := event_count("request")
	starts_before = starts.size()
	panel.send_prompt()
	check(panel.provider.request_preparation_active() and not panel._pending_provider_send.is_empty(),
		"large context enters observable preparation with a captured pending turn")
	check(prompt_count("cancel before outbound admission") == 0 and panel.provider.last_request_offset == -1,
		"pending outbound request has no premature conversation turn or stale image offset")
	panel.stop_all("Fixture Stop before request admission")
	check(not panel.provider.active and panel._pending_provider_send.is_empty(),
		"Stop immediately clears pending panel admission")
	await until(settled,"cancelled request value job drains")
	check(event_count("request") == requests_before and starts.size() == starts_before
		and prompt_count("cancel before outbound admission") == 0,
		"Stop before preparation completes dispatches no request and invents no user turn")

	configure("captured across hide and edit")
	panel.send_prompt()
	panel.close_requested.emit()
	check(not panel.visible and panel.provider.active and not panel._pending_provider_send.is_empty(),
		"Art close-request binding preserves outbound preparation and its pending captured turn")
	panel.input.text = "future prompt edited while waiting"
	panel.model.text = "future model edited while waiting"
	panel.show()
	await until(settled,"hidden and reopened request finishes")
	check(prompt_count("captured across hide and edit") == 1 and prompt_count("future prompt edited while waiting") == 0,
		"late request start records the captured prompt rather than current editor text")
	check(panel.input.text == "future prompt edited while waiting" and panel.model.text == "future model edited while waiting",
		"completion preserves live edits for the next Send")
	check(panel.provider.requested_model == "request-admission-fixture" and panel._pending_provider_send.is_empty(),
		"outstanding request retains its captured model and consumes pending admission")

	configure("invalid model does not become a sent turn",false)
	panel.model.text = ""
	starts_before = starts.size()
	panel.send_prompt()
	check(starts.size() == starts_before and panel._pending_provider_send.is_empty()
		and prompt_count("invalid model does not become a sent turn") == 0 and not panel.input_error.is_empty(),
		"synchronous validation failure clears pending turn and shows the error")

	configure("async invalid endpoint does not become a sent turn")
	panel.endpoint.text = "invalid-fixture://loopback/v1"
	starts_before = starts.size()
	panel.send_prompt()
	check(panel.provider.request_preparation_active(),"invalid endpoint reaches asynchronous start path with large context")
	await until(settled,"asynchronous HTTP start failure settles")
	check(starts.size() == starts_before and panel._pending_provider_send.is_empty()
		and prompt_count("async invalid endpoint does not become a sent turn") == 0 and not panel.input_error.is_empty(),
		"asynchronous start failure clears pending turn without claiming dispatch")

	configure("obsolete UI generation")
	requests_before = event_count("request")
	panel.send_prompt()
	panel.ui_epoch += 1
	await until(settled,"obsolete outbound generation settles")
	check(event_count("request") == requests_before and panel._pending_provider_send.is_empty()
		and prompt_count("obsolete UI generation") == 0,
		"dispatch guard fences a superseded UI generation before request audit or network")

	configure("obsolete captured World")
	panel.send_prompt()
	var stale_world: int = host.simulation_worker.art_state().epoch+1
	check(not panel._can_dispatch_provider_request(panel.ui_epoch,stale_world),
		"main-thread dispatch guard rejects a stale captured World identity")
	await until(settled,"stale captured World job drains")
	check(panel._pending_provider_send.is_empty() and prompt_count("obsolete captured World") == 0,
		"World identity refusal retires the pending user turn")

func png_offset_checks() -> void:
	configure("captured image prompt")
	var picture := Image.create(2,2,false,Image.FORMAT_RGBA8)
	picture.fill(Color.RED)
	var old_png := Marshalls.raw_to_base64(picture.save_png_to_buffer())
	panel.provider.log_event("request",{"body":Provider.payload("LM Studio","fixture","older image","rules",128,old_png)})
	var old_offset: int = panel.provider.last_request_offset
	picture.fill(Color.BLUE)
	var png := Marshalls.raw_to_base64(picture.save_png_to_buffer())
	panel.ui_epoch += 1
	panel.request_epoch = host.simulation_worker.art_state().epoch
	var captured_epoch: int = panel.ui_epoch
	var prompt := "captured image prompt"
	var timing := {"conversation_log_usec":0,"request_started":false}
	panel._pending_provider_send = {"id":panel.provider.serial+1,"ui_epoch":captured_epoch,
		"world_epoch":panel.request_epoch,"prompt":prompt,"has_image":true,"timing":timing,"began_usec":Time.get_ticks_usec()}
	var error: String = panel.provider.send("LM Studio",endpoint,"image-fixture","",prompt,"rules",128,1,png,
		[{"role":"user","content":"x".repeat(600000)}],panel._can_dispatch_provider_request.bind(captured_epoch,panel.request_epoch))
	check(error.is_empty() and panel.provider.request_preparation_active() and panel.provider.last_request_offset == -1,
		"pending image request cannot borrow the earlier request offset")
	panel._provider_request_started(panel.provider.serial-1,old_offset)
	check(not panel._pending_provider_send.is_empty() and prompt_count(prompt) == 0,
		"stale request_started callback cannot consume a newer pending image turn")
	await until(settled,"image request admission settles")
	var captured: Dictionary = {}
	for turn: Dictionary in panel.conversation:
		if turn.get("content") == prompt: captured = turn
	check(prompt_count(prompt) == 1 and int(captured.get("image_offset",-1)) > old_offset,
		"PNG conversation turn stores the newly admitted request offset exactly once")
	check(not captured.is_empty() and captured.get("image_log_path") == panel.provider.log_path
		and panel.provider.historical_image(int(captured.get("image_offset",-1)),str(captured.get("image_log_path",""))) == "data:image/png;base64,"+png,
		"stored image offset resolves to this request's PNG rather than an older image")

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	bench = host.shared_workbench
	panel = bench._ensure_art_batches()
	if not await until(ready,"native Workbench ready",120): quit(1); return
	var fresh: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	check(bench.apply(fresh),"fresh native Workbench map admitted")
	if not await until(ready,"fresh native World ready",120): quit(1); return
	var listener := TCPServer.new()
	check(listener.listen(0,"127.0.0.1") == OK,"temporary numeric loopback endpoint allocated")
	endpoint = "http://127.0.0.1:%d/v1" % listener.get_local_port()
	listener.stop()
	panel.provider.request_started.connect(func(id: int, offset: int) -> void: starts.append({"id":id,"offset":offset}))
	var native_before: Dictionary = host.simulation_worker.paint_state()
	var authored_before: Array = bench.applied.edits.duplicate(true)
	await finite_run_checks()
	await admission_checks()
	await png_offset_checks()
	check(host.simulation_worker.paint_state().revision == native_before.revision and bench.applied.edits == authored_before,
		"request admission and failure fixtures never mutate native cells or authored history")
	host.queue_free()
	await process_frame
	await process_frame
	print("ART_REQUEST_ADMISSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}))
	quit(0 if failures.is_empty() else 1)
