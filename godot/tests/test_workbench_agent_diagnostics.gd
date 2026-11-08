extends SceneTree
## Actual client, fake HTTP. Durable-helper tests use a disposable local folder.
const Client = preload("res://scripts/workbench_agent_client.gd")
const Diagnostics = preload("res://scripts/workbench_agent_diagnostics.gd")
const TEST_KEY := "dummy-diagnostic-secret-not-an-api-key"
var checks := 0
var failures := 0
var folder := ""

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WB_AGENT_DIAGNOSTICS: " + detail)

func latest(client: Node, kind: String) -> Dictionary:
	var records: Array = client.diagnostic_records()
	for i: int in range(records.size()-1,-1,-1):
		if records[i].kind == kind: return records[i]
	return {}

func new_client() -> Node:
	var client := Client.new()
	root.add_child(client)
	client.configure_fake_transport_for_tests(true)
	return client

func start(client: Node) -> bool:
	return client.begin_task("Build a box","fake-model",{"region":{"x":0,"y":0,"width":32,"height":32},"allowed_materials":["Hard Wall","Empty"],"protected_regions":[],"cell_limit":16384})

func _run() -> void:
	await process_frame
	var had_key := OS.has_environment("OPENAI_API_KEY")
	var prior_key := OS.get_environment("OPENAI_API_KEY")
	OS.set_environment("OPENAI_API_KEY",TEST_KEY)
	folder = "user://wb-agent-diagnostics-test-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	check(not DirAccess.dir_exists_absolute(folder),"test directory collision")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK,"test directory unavailable")
	test_protocol()
	test_errors()
	test_storage()
	cleanup()
	if had_key: OS.set_environment("OPENAI_API_KEY",prior_key)
	else: OS.unset_environment("OPENAI_API_KEY")
	await process_frame
	await process_frame
	print("WB_AGENT_DIAGNOSTICS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func test_protocol() -> void:
	var c := new_client()
	check(c.activity_snapshot().state == "idle","new client not idle")
	check(start(c),"fake task start failed")
	var state: Dictionary = c.activity_snapshot()
	check(state.state == "active" and str(state.stage).contains("model"),"model waiting state missing")
	check(state.requests == 1 and state.request_limit == 128,"request use/default incorrect")
	check(state.input_tokens == -1 and state.output_tokens == -1,"unknown tokens presented as zero")
	var event := latest(c,"http.request")
	check(event.payload.body.input.size() == 2,"full request input missing")
	check(event.identity.request == c._serial and not str(event.utc).is_empty(),"request correlation/timestamp missing")
	var copy: Array = c.diagnostic_records()
	copy[0].kind = "tampered"
	check(c.diagnostic_records()[0].kind != "tampered","accessor exposes mutable log")
	var call := {"type":"function_call","name":"observe","call_id":"diag-call","arguments":JSON.stringify({"region":null,"detail":"counts"})}
	c.receive_fake_response(c.current_epoch(),c._serial,200,{"id":"diag1","status":"completed","output":[call],"usage":{"input_tokens":13,"output_tokens":7}})
	state = c.activity_snapshot()
	check(c.is_waiting_for_tool() and str(state.stage).contains("native"),"native waiting state missing")
	check(state.tools == 1 and state.input_tokens == 13 and state.output_tokens == 7,"actual provider/tool use missing")
	check(latest(c,"tool.request").payload.arguments.has("region"),"raw tool arguments missing")
	check(c.submit_tool_result(c.current_epoch(),"diag-call",{"status":"observed","observation_id":"native-diag","native_counts":{"0":1024}}),"native continuation failed")
	event = latest(c,"native.receipt")
	check(event.payload.receipt.native_counts.get("0") == 1024 and event.payload.stale == false,"native receipt missing")
	check(str(latest(c,"http.request").payload.body.input[0].output).contains("native-diag"),"provider-bound tool output missing")
	c.receive_fake_response(c.current_epoch(),c._serial,200,{"id":"diag2","status":"completed","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Finished assessment"}]}],"usage":{"input_tokens":17,"output_tokens":11}})
	state = c.activity_snapshot()
	check(state.state == "idle" and not c.is_active(),"completed task not idle")
	check(state.requests == 2 and state.input_tokens == 30 and state.output_tokens == 18,"cumulative actual usage incorrect")
	check(str(latest(c,"http.response").payload.body).contains("Finished assessment"),"full response missing")
	c.queue_free()

func test_errors() -> void:
	var c := new_client()
	check(start(c),"error fixture failed")
	var epoch: int = c.current_epoch()
	var serial: int = c._serial
	c._handle_transport(epoch,serial,HTTPRequest.RESULT_SUCCESS,429,("{malformed slow_down " + TEST_KEY).to_utf8_buffer(),PackedStringArray(["x-request-id: diagnostic-request","Retry-After: 12","Authorization: Bearer " + TEST_KEY]))
	var event := latest(c,"http.response")
	check(event.payload.http_status == 429 and str(event.payload.body).contains("{malformed slow_down"),"raw malformed429 discarded")
	check(str(event).contains("[REDACTED API KEY]") and not JSON.stringify(c.diagnostic_records()).contains(TEST_KEY),"configured key leaked")
	check(event.payload.headers.get("x-request-id") == "diagnostic-request" and event.payload.headers.get("retry-after") == "12" and not event.payload.headers.has("authorization"),"safe headers missing/credentials retained")
	check(c.activity_snapshot().state == "idle","error remains active")
	c._handle_transport(epoch,serial,HTTPRequest.RESULT_SUCCESS,200,"stale raw payload".to_utf8_buffer())
	check(latest(c,"http.response").payload.stale == true and latest(c,"http.response").payload.body == "stale raw payload","stale callback not inspectable")
	check(not c.submit_tool_result(epoch,"late",{"status":"applied","readback":[]}),"stale receipt accepted")
	check(latest(c,"native.receipt").payload.stale == true,"stale native receipt not recorded")
	c.queue_free()
	var malformed := new_client()
	check(start(malformed),"malformed200 fixture failed")
	malformed._handle_transport(malformed.current_epoch(),malformed._serial,HTTPRequest.RESULT_SUCCESS,200,("{bad JSON " + TEST_KEY).to_utf8_buffer())
	check(not malformed.is_active() and str(latest(malformed,"http.response").payload.body).contains("[REDACTED API KEY]") and not JSON.stringify(malformed.diagnostic_records()).contains(TEST_KEY),"malformed200 response discarded or unredacted")
	malformed.queue_free()

func test_storage() -> void:
	var store := Diagnostics.new()
	store.directory = folder
	var identity := {"epoch":1,"request":1,"call_id":"test"}
	var safe := store.append("redaction",{"Authorization":"hidden","api_key":"hidden","text":TEST_KEY},identity,false)
	check(safe.payload.Authorization == "[REDACTED]" and safe.payload.api_key == "[REDACTED]" and not JSON.stringify(safe).contains(TEST_KEY),"structured redaction failed")
	for i: int in range(Diagnostics.MAX_RECORDS+4): store.append("bounded",{"index":i},identity,false)
	check(store.records.size() == Diagnostics.MAX_RECORDS and store.dropped == 5,"eviction not surfaced/bounded")
	var large_event := store.append("oversized",{"body":"x".repeat(Diagnostics.MAX_RECORD_BYTES+128)},identity,false)
	check(large_event.payload.has("omitted") and large_event.payload.original_bytes > Diagnostics.MAX_RECORD_BYTES and str(large_event.payload.sha256).length() == 64,"oversize omission silent")
	check(store._bytes <= Diagnostics.MAX_MEMORY_BYTES,"memory byte bound exceeded")
	var bytes_store := Diagnostics.new()
	for i: int in range(2): bytes_store.append("large_valid",{"body":"y".repeat(9*1024*1024)},identity,false)
	check(bytes_store.records.size() == 1 and bytes_store.dropped == 1 and bytes_store._bytes <= Diagnostics.MAX_MEMORY_BYTES,"byte retention bound not enforced independently of record count")
	check(store.export_jsonl(folder+"/export.jsonl") == OK,"export failed")
	var file := FileAccess.open(folder+"/export.jsonl",FileAccess.READ)
	var metadata: Variant = JSON.parse_string(file.get_line()) if file != null else null
	if file != null: file.close()
	check(metadata is Dictionary and metadata.get("diagnostic_export") == true and metadata.get("dropped_events") == store.dropped and metadata.get("retained_events") == store.records.size(),"export hides partial retention")
	var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.25,0.5,0.75,1))
	var png: PackedByteArray = image.save_png_to_buffer()
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(png)
	var hash_value := hash_context.finish().hex_encode()
	var image_event := store.append("image",{"image":"data:image/png;base64,"+Marshalls.raw_to_base64(png)},identity,true)
	check(image_event.payload.image is Dictionary and image_event.payload.image.sha256 == hash_value and image_event.payload.image.bytes == png.size(),"image metadata unverifiable")
	check(FileAccess.get_file_as_bytes(folder+"/"+hash_value+".png") == png,"original PNG bytes not retained")
	check(not JSON.stringify(image_event).contains("data:image/png;base64,"),"image base64 inline in log")
	var durable := FileAccess.get_file_as_string(folder+"/events.jsonl")
	check(durable.contains(hash_value) and durable.contains("\"kind\":\"image\""),"event not durable before exit")
	# Grow only this invocation's file to exercise the32MiB rotation boundary.
	var large_file := FileAccess.open(folder+"/events.jsonl",FileAccess.READ_WRITE)
	check(large_file != null,"rotation fixture unavailable")
	if large_file != null:
		large_file.seek(Diagnostics.MAX_FILE_BYTES-1)
		large_file.store_8(10)
		large_file.close()
	store.append("after_rotation",{"message":"new event"},identity,true)
	var previous := FileAccess.open(folder+"/events.previous.jsonl",FileAccess.READ)
	check(previous != null and previous.get_length() == Diagnostics.MAX_FILE_BYTES,"32MiB file not rotated")
	if previous != null: previous.close()
	check(FileAccess.get_file_as_string(folder+"/events.jsonl").contains("after_rotation") and store.disk_error.is_empty(),"postrotation event missing")
	var fake := Diagnostics.new()
	fake.directory = folder+"/must-not-exist"
	fake.append("fake_image",{"image":"data:image/png;base64,"+Marshalls.raw_to_base64(png)},identity,false)
	check(not DirAccess.dir_exists_absolute(fake.directory),"fake transport persisted image")

func cleanup() -> void:
	# Unique directory was empty at creation. Delete only files inside that target.
	var absolute := ProjectSettings.globalize_path(folder).replace("\\","/")
	check(absolute.get_file().begins_with("wb-agent-diagnostics-test-"),"cleanup path outside unique test target")
	for filename: String in DirAccess.get_files_at(folder):
		var target := ProjectSettings.globalize_path(folder.path_join(filename)).replace("\\","/")
		if target.begins_with(absolute+"/"): DirAccess.remove_absolute(target)
	DirAccess.remove_absolute(folder)
