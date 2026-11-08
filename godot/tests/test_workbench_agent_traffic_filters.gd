extends SceneTree
## Original diagnostic envelopes, fake provider JSON, actual read-only viewer.
const TrafficProjection = preload("res://scripts/workbench_agent_traffic_projection.gd")
const TrafficWindow = preload("res://scripts/workbench_agent_traffic_window.gd")
const Diagnostics = preload("res://scripts/workbench_agent_diagnostics.gd")
var checks := 0
var failures := 0
var store := Diagnostics.new()

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WB_AGENT_TRAFFIC_FILTERS: " + detail)

func record(kind: String, payload: Dictionary, epoch: int = 1) -> Dictionary:
	return store.append(kind,payload,{"epoch":epoch,"request":store.records.size()+1},false)

func only(category: String) -> Dictionary:
	return {category:true}

func _run() -> void:
	await process_frame
	var first := record("http.request",{"body":{"input":[
		{"role":"developer","content":[{"type":"input_text","text":"Use the actual protected native World."}]},
		{"role":"system","content":"System setup text"},
		{"role":"user","content":[{"type":"input_text","text":"Build a wall beside the hopper."},{"type":"input_image","image_url":{"image_payload":"stored separately"}}]}
	]}})
	var response := record("http.response",{"http_status":200,"transport_result":0,"body":JSON.stringify({"id":"resp-1","status":"completed","usage":{"input_tokens":140,"output_tokens":20},"output":[
		{"type":"reasoning","summary":[{"type":"summary_text","text":"Provider-returned visible summary."}],"content":[{"type":"reasoning_text","text":"PRIVATE_RECONSTRUCTION_MUST_NOT_APPEAR"}]},
		{"type":"function_call","call_id":"call-1","name":"observe","arguments":"{\"region\":null,\"detail\":\"cells\"}"}
	]})})
	record("tool.request",{"call_id":"call-1","name":"observe","arguments":{"region":null,"detail":"cells"}})
	record("native.receipt",{"call_id":"call-1","receipt":{"status":"observed","observation_id":"obs-1","native_counts":{"0":4096}}})
	record("http.request",{"body":{"previous_response_id":"resp-1","input":[
		{"role":"developer","content":[{"type":"input_text","text":"Use the actual protected native World."}]},
		{"role":"user","content":[{"type":"input_text","text":"Build a wall beside the hopper."}]},
		{"type":"function_call_output","call_id":"call-1","output":"{\"status\":\"observed\",\"observation_id\":\"obs-1\"}"}
	]}})
	record("http.response",{"http_status":200,"body":JSON.stringify({"id":"resp-2","status":"completed","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"[b]I have inspected the area.[/b]"}]}]})})
	var overlap := record("http.response",{"http_status":429,"body":JSON.stringify({"error":{"code":"rate_limit_exceeded","message":"Wait before retrying"},"usage":{"input_tokens":30,"output_tokens":0}})})
	var malformed := record("http.response",{"http_status":200,"body":"{broken JSON"})
	var refused := record("native_retirement_ack",{"status":"unconfirmed","reason":"native_stop_missing"})
	var status := record("task.running",{"detail":"Dispatching"})
	check(TrafficProjection.categories(first).has("Messages"),"real request messages absent")
	check(TrafficProjection.categories(response).has("Tools") and TrafficProjection.categories(response).has("Metrics"),"response categories do not overlap")
	check(TrafficProjection.categories(overlap).has("Errors") and TrafficProjection.categories(overlap).has("Metrics"),"429 usage/error overlap lost")
	check(TrafficProjection.matches(overlap,only("Metrics")) and TrafficProjection.matches(overlap,only("Errors")),"independent toggles exclude overlapping record")
	check(TrafficProjection.categories(malformed).has("Errors"),"malformed response not retained as Error")
	var wrong_type := record("http.response",{"http_status":200,"body":JSON.stringify({"output":[{"type":[],"content":{}},false]})})
	check(TrafficProjection.categories(wrong_type).has("Errors") and TrafficProjection.conversation([wrong_type],only("Errors")).contains("malformed item types"),"valid JSON with wrong typed fields crashes or disappears")
	check(TrafficProjection.categories(refused).has("ACKs") and TrafficProjection.categories(refused).has("Errors"),"unconfirmed ACK not classified as Error")
	check(not TrafficProjection.matches(status,TrafficProjection.DEFAULT_FILTERS),"opaque status noise appears by default")
	check(TrafficProjection.matches(status,only("Raw")),"Raw does not include unprojected status")
	check(not TrafficProjection.matches(first,{}),"all-disabled filter still matches")
	var wait := {"kind":"rate.wait","payload":{"estimated_tokens":11000,"wait_seconds":8}}
	var retry := {"kind":"rate.retry","payload":{"http_status":429,"error":{"code":"rate_limit_exceeded"}}}
	check(TrafficProjection.matches(wait,only("Metrics")) and TrafficProjection.conversation([wait],only("Metrics")).contains("Local rate limiter (estimate)"),"local rate wait invisible or misrepresented as provider usage")
	check(TrafficProjection.matches(retry,only("Metrics")) and TrafficProjection.matches(retry,only("Errors")),"rate retry with error body loses category overlap")
	var before := JSON.stringify(store.records)
	var transcript := TrafficProjection.conversation(store.records,TrafficProjection.DEFAULT_FILTERS)
	check(transcript.count("Build a wall beside the hopper.") == 1,"continuation duplicates initial human message")
	check(transcript.count("Use the actual protected native World.") == 1,"continuation duplicates developer instructions")
	check(transcript.contains("System setup text"),"system text discarded")
	check(transcript.count("Model → tool · observe [call-1]") == 1,"response and dispatcher duplicate tool call")
	check(transcript.contains("Tool → model [call-1]") and transcript.contains("obs-1"),"tool-result back-and-forth discarded")
	check(transcript.contains("No assistant prose returned"),"function-only response not explained")
	check(transcript.contains("[b]I have inspected the area.[/b]"),"literal assistant text discarded or interpreted")
	check(transcript.contains("Provider-returned visible summary.") and not transcript.contains("PRIVATE_RECONSTRUCTION"),"hidden reasoning was inferred or provider summary omitted")
	var no_summary := {"kind":"http.response","payload":{"body":JSON.stringify({"output":[{"type":"reasoning","content":[{"type":"reasoning_text","text":"PRIVATE_RECONSTRUCTION_MUST_NOT_APPEAR"}]}]})}}
	check(not TrafficProjection.conversation([no_summary],only("Raw")).contains("PRIVATE_RECONSTRUCTION"),"Raw filter leaks non-summary reasoning into Conversation")
	check(not transcript.contains("input_tokens"),"Metrics disabled but raw usage injected")
	var metrics := TrafficProjection.conversation(store.records,only("Metrics"))
	check(metrics.contains("input_tokens") and not metrics.contains("Build a wall"),"Metrics toggle changes unrelated Messages")
	var tools := TrafficProjection.conversation(store.records,only("Tools"))
	check(tools.contains("call-1") and not tools.contains("I have inspected"),"Tools toggle changes unrelated prose")
	check(JSON.stringify(store.records) == before,"projection mutated original retained data")
	var path := "user://wb-agent-filter-test-%d-%d.jsonl" % [OS.get_process_id(),Time.get_ticks_usec()]
	check(store.export_jsonl(path) == OK,"actual diagnostic JSONL export failed")
	var saved: Array = []
	var file := FileAccess.open(path,FileAccess.READ)
	check(file != null,"saved diagnostic stream unreadable")
	if file != null:
		while not file.eof_reached():
			var line := file.get_line()
			if line.is_empty():
				continue
			var parsed := JSON.new()
			check(parsed.parse(line) == OK,"real saved envelope did not parse")
			if parsed.data is Dictionary and parsed.data.has("kind"):
				saved.append(parsed.data)
		file.close()
	check(saved.size() == store.records.size() and TrafficProjection.conversation(saved,TrafficProjection.DEFAULT_FILTERS) == transcript,"saved raw structure changes conversation")
	DirAccess.remove_absolute(path)
	var window := TrafficWindow.new()
	root.add_child(window)
	await process_frame
	window.set_records(saved,"local-test",{"dropped_events":12})
	check(window._tabs.get_tab_title(0) == "Conversation" and not window.visible,"viewer does not open in hidden Conversation tab")
	check(window._filters.size() == 6 and not window._filters.Metrics.button_pressed and not window._filters.Raw.button_pressed,"category defaults wrong")
	check(window._conversation.text == transcript,"actual plaintext viewer differs from projection")
	var raw_before := window._jsonl()
	window._filters.Messages.button_pressed = false
	check(not window._conversation.text.contains("Build a wall"),"Messages checkbox ineffective")
	check(window._jsonl() == raw_before,"filters alter full raw export")
	window._filters.Raw.button_pressed = true
	check(window._visible_indices.size() == saved.size(),"Raw checkbox does not reveal all records")
	# Select the original first response, then refresh with the same sequence from another session.
	window._events.select(1)
	window._select_record(1)
	var selected_id := window._selected_id()
	var other: Dictionary = saved[0].duplicate(true)
	other.session = "other-session"
	saved.append(other)
	window.set_records(saved)
	check(window._selected_id() == selected_id and window._details.text.contains("resp-1"),"selection not preserved by session/sequence across refresh")
	window._filters.Raw.button_pressed = false
	window._filters.ACKs.button_pressed = false
	window._filters.Tools.button_pressed = false
	window._filters.Errors.button_pressed = false
	check(window._visible_indices.is_empty() and window._body.text.is_empty() and window._details.text.is_empty(),"empty filters leave stale raw detail")
	window.queue_free()
	await process_frame
	print("WB_AGENT_TRAFFIC_FILTERS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
