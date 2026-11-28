extends SceneTree
## Independent regression of confirmed review defects. HTTP responses use only
## synthetic credentials on loopback; their programs execute on the real native
## World. PNG fixtures are categorical material-ID captures, not viewport art.
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const LabPanel = preload("res://scripts/batch_lab/batch_lab_panel.gd")
var controller: Node
var server := TCPServer.new()
var fixture_thread := Thread.new()
var fixture_mutex := Mutex.new()
var fixture_stopping := false
var fixture_reply: Dictionary = {}
var received := 0
var released := 0
var port := 0
var checks := 0
var failures: Array[String] = []
var evidence := ""
var secrets: Array[String] = []
var png_structural_refusals := 0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("BATCH_SECURITY_CHECK ",checks," ",label," ",ok)
	if not ok: failures.append(label); push_error(label)
	return ok

func path(name: String) -> String:
	return ("user://batch-security" if evidence.is_empty() else evidence).path_join(name)

func write_fixture(name: String, value: Dictionary) -> String:
	var target := path(name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target).get_base_dir())
	var file := FileAccess.open(target,FileAccess.WRITE)
	if file==null: check(false,"write bounded security fixture "+name); return ""
	file.store_string(JSON.stringify(value)); file.close()
	return target

func request_count() -> int:
	fixture_mutex.lock()
	var count := received
	fixture_mutex.unlock()
	return count

func serve() -> void:
	var peer: StreamPeerTCP
	var wire := PackedByteArray()
	var admitted := 0
	while true:
		fixture_mutex.lock()
		var stopping := fixture_stopping
		var release := released
		var reply: Dictionary = fixture_reply.duplicate(true)
		fixture_mutex.unlock()
		if stopping: break
		if peer==null and server.is_connection_available(): peer=server.take_connection()
		if peer!=null:
			peer.poll()
			if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
				peer=null; wire.clear(); admitted=0
				continue
			var count := peer.get_available_bytes()
			if count>0:
				var incoming := peer.get_data(count)
				if incoming[0]==OK: wire.append_array(incoming[1])
			if admitted==0 and not wire.is_empty():
				var text := wire.get_string_from_utf8()
				var boundary := text.find("\r\n\r\n")
				if boundary>=0:
					var expected := 0
					for line: String in text.left(boundary).split("\r\n"):
						if line.to_lower().begins_with("content-length:"): expected=int(line.get_slice(":",1).strip_edges())
					if wire.size()>=boundary+4+expected:
						fixture_mutex.lock()
						received+=1; admitted=received
						fixture_mutex.unlock()
			if admitted>0 and release>=admitted:
				var secret := str(reply.secret)
				var usage := {"echo":secret,"authorization":secret,"prompt_tokens":12,"completion_tokens":4}
				usage[secret] = {"nested_echo":secret}
				var content := JSON.stringify([{"shape":"pixels","points":[[10,10]],"material":58}])
				var response := {"model":secret,"usage":usage,
					"choices":[{"message":{"content":content},"finish_reason":"stop"}]}
				if int(reply.status)!=200: response["error"]={"message":"fixture "+secret}
				var body := JSON.stringify(response).to_utf8_buffer()
				var header := "HTTP/1.1 %d Fixture\r\nContent-Type: application/json\r\nX-Credential-Echo: %s\r\nConnection: close\r\nContent-Length: %d\r\n\r\n" % [int(reply.status),secret,body.size()]
				var packet := header.to_utf8_buffer(); packet.append_array(body)
				peer.put_data(packet); peer.disconnect_from_host()
				peer=null; wire.clear(); admitted=0
		OS.delay_msec(1)
	if peer!=null: peer.disconnect_from_host()
	server.stop()

func close_server() -> void:
	fixture_mutex.lock(); fixture_stopping=true; fixture_mutex.unlock()
	if fixture_thread.is_started(): fixture_thread.wait_to_finish()
	else: server.stop()

func settle(label: String) -> bool:
	var deadline := Time.get_ticks_msec()+20000
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	return check(not controller.is_running(),label)

func contains_secret(value: String) -> bool:
	for secret: String in secrets:
		if not secret.is_empty() and value.contains(secret): return true
	return false

func tree_contains_secret(value: Variant) -> bool:
	if value is String: return contains_secret(value)
	if value is Dictionary:
		for key: Variant in value:
			if contains_secret(str(key)) or tree_contains_secret(value[key]): return true
	if value is Array:
		for item: Variant in value:
			if tree_contains_secret(item): return true
	return false

func decoded_traffic_safe(path_name: String) -> bool:
	var found_response := false
	var found_echo_header := false
	for line: String in FileAccess.get_file_as_string(path_name).split("\n",false):
		var event: Variant = JSON.parse_string(line)
		if not event is Dictionary or tree_contains_secret(event): return false
		if event.get("kind")=="response":
			# A raw provider response is JSON inside the outer JSONL string.
			# Plain substring checks miss JSON-escaped opaque credentials.
			var body: Variant = JSON.parse_string(str(event.data.body))
			if not body is Dictionary or tree_contains_secret(body): return false
			if not event.data.get("headers") is Array: return false
			for header: Variant in event.data.headers:
				if str(header).to_lower().begins_with("x-credential-echo:"): found_echo_header=true
			found_response=true
	return found_response and found_echo_header

func credential_case(label: String, clear_key: bool, failed: bool, secret_override := "") -> void:
	var old_secret := "security-fixture-previous-opaque-"+label if secret_override.is_empty() else secret_override
	var new_secret := "" if clear_key else "security-fixture-current-opaque-"+label
	secrets.append(old_secret)
	if not new_secret.is_empty(): secrets.append(new_secret)
	fixture_mutex.lock()
	fixture_reply={"secret":old_secret,"status":500 if failed else 200}
	fixture_mutex.unlock()
	controller.set_credential("LM Studio",old_secret)
	var config := Controller.defaults()
	config.provider="LM Studio"; config.model="security-protocol-"+label
	config.endpoint="http://127.0.0.1:%d/v1" % port
	config.extent=[64,64]; config.source_region=[0,0,64,64]
	config.operations=[]; config.max_output_tokens=64; config.timeout_seconds=10
	var before := request_count()
	if not check(controller.configure_tile(0,config).ok and controller.start([0]).ok,label+" admitted locally"): return
	var deadline := Time.get_ticks_msec()+5000
	while request_count()==before and Time.get_ticks_msec()<deadline: await process_frame
	check(request_count()==before+1,label+" reached actual loopback transport before credential change")
	var traffic_path := ""
	if controller._active.has(0) and controller._active[0].has("provider"):
		traffic_path=str(controller._active[0].provider.log_path)
	controller.set_credential("LM Studio",new_secret)
	fixture_mutex.lock(); released=received; fixture_mutex.unlock()
	if not await settle(label+" reaches terminal result"): return
	var record: Dictionary = controller.attempts.back()
	if failed:
		check(record.state=="refused" and record.material_cells.is_empty(),label+" failure cannot become native edits")
	else:
		check(record.state=="completed" and int(record.metrics.get("changed",0))==1 and not record.receipts.is_empty(),label+" performs one acknowledged native cell change")
	check(not tree_contains_secret(record),label+" retained metadata keys, values and failure text contain no credentials")
	check(not traffic_path.is_empty() and not contains_secret(FileAccess.get_file_as_string(traffic_path)),label+" shared provider durable traffic contains no credential-bearing metadata keys")
	check(not traffic_path.is_empty() and decoded_traffic_safe(traffic_path),label+" decoded raw HTTP body and actual echoed response header contain no credentials")
	check(record.usage.get("cost_usd")==null and not record.usage.get("cost_known",true),label+" unknown cost remains explicit")
	var exported := path(label+"-session.json")
	check(controller.save_session(exported).ok,label+" session exports")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(exported))
	check(saved is Dictionary and not tree_contains_secret(saved),label+" export contains no old or current credential")

func current_identity() -> String:
	var records: Array = []
	for record: Dictionary in controller.attempts: records.append(Controller._encode(record))
	return JSON.stringify({"records":records,"tiles":controller.tiles,"provenance":controller.provenance}).sha256_text()

func escaped_credential_case() -> void:
	# Local bearer strings need not match a cloud vendor's key alphabet. JSON
	# escaping must not turn a known volatile credential into durable metadata.
	var secret := "security-fixture-opaque-\"quote\"-and-\\slash"
	controller.set_credential("LM Studio",secret)
	check(not controller.configure_tile(0,{"prompt":"Accidental credential echo "+secret}).ok,"JSON-escaped volatile credential cannot enter prompt configuration")
	controller.provenance["untrusted_echo"]=secret
	controller.provenance[secret]="credential-bearing metadata key"
	var exported := path("escaped-credential-sanitized.json")
	check(controller.save_session(exported).ok,"structured credential sanitization exports bounded metadata")
	var decoded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(exported))
	check(not str(decoded.provenance.get("untrusted_echo","")).contains(secret) and not decoded.provenance.has(secret),"JSON decoding cannot recover credential values or keys from sanitized export")
	controller.provenance.erase("untrusted_echo"); controller.provenance.erase(secret)
	controller.set_credential("LM Studio","")

func refused_unchanged(value: Dictionary, label: String) -> void:
	var file := write_fixture(label+".json",value)
	var before := current_identity()
	var outcome: Dictionary = controller.load_session(file)
	check(not outcome.ok,label+" refuses as a value result")
	check(current_identity()==before,label+" preserves current grid, selected result and evidence atomically")

func refused_png(value: Dictionary, bytes: PackedByteArray, label: String) -> void:
	var bad := value.duplicate(true)
	bad.attempts[0].render_png_base64=Marshalls.raw_to_base64(bytes)
	# Recompute the stored checksum so these exercise PNG admission, rather than
	# succeeding solely because the existing source/byte identity guard fires.
	bad.attempts[0].render_png_sha256=Controller.TileHost.digest(bytes)
	refused_unchanged(bad,label)
	png_structural_refusals+=1

func import_cases() -> void:
	var clean := path("clear-failure-session.json")
	check(controller.load_session(clean).ok,"fresh completed and refused native session reopens with exact identities")
	var value: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(clean))
	value.tiles[0].attempt_id=value.attempts[0].attempt_id
	value.tiles[0].history_attempt=value.attempts[0].attempt_id
	value.tiles[0].history_cursor="result"
	var native_record: Dictionary = controller.attempts[0]
	var png := Controller.material_image(native_record.material_cells,Vector2i(64,64)).save_png_to_buffer()
	value.attempts[0]["render_png_base64"]=Marshalls.raw_to_base64(png)
	value.attempts[0]["render_png_sha256"]=Controller.TileHost.digest(png)
	value.attempts[0]["renderer"]={"material_sha256":native_record.material_sha256,
		"scope":"categorical native material-ID PNG import fixture; not a Godot viewport capture"}
	check(controller.load_session(write_fixture("valid-material-id-png.json",value)).ok,"bounded valid material-ID PNG decodes and preserves native result")
	controller.provenance["security_import_sentinel"]=true
	refused_png(value,png.slice(0,33),"png-ihdr-only")
	refused_png(value,png.slice(0,mini(64,png.size()-1)),"png-truncated-body")
	refused_png(value,png.slice(0,png.size()-1),"png-truncated-final-crc")
	refused_png(value,png.slice(0,png.size()-12),"png-missing-iend")
	var malformed := png.slice(0,33)
	malformed.append_array(png.slice(png.size()-12))
	refused_png(value,malformed,"png-missing-idat")
	malformed=png.duplicate(); malformed[11]=12
	refused_png(value,malformed,"png-invalid-ihdr-length")
	malformed=png.duplicate()
	for index: int in range(8,12): malformed[index]=255
	refused_png(value,malformed,"png-overflowing-chunk-length")
	malformed=png.duplicate(); malformed.append(0)
	refused_png(value,malformed,"png-trailing-after-iend")
	malformed=png.slice(0,33); malformed.append_array(png.slice(8,33)); malformed.append_array(png.slice(33))
	refused_png(value,malformed,"png-duplicate-ihdr")
	var bad: Dictionary = value.duplicate(true)
	bad.attempts[0].config.prompt="Altered construction instruction never used to build this result."
	bad.attempts[0].provenance.configuration_sha256=JSON.stringify(Controller._canonical_numbers(Controller._config_identity(bad.attempts[0].config))).sha256_text()
	refused_unchanged(bad,"prompt-digest-mismatch")
	bad=value.duplicate(true); bad.attempts[0].config.seed=987654
	refused_unchanged(bad,"configuration-seed-mismatch")
	bad=value.duplicate(true); bad.attempts[0].provenance.erase("actual_prompt_sha256")
	refused_unchanged(bad,"missing-prompt-identity")
	bad=value.duplicate(true); bad.attempts[0].provenance.erase("configuration_sha256")
	refused_unchanged(bad,"missing-configuration-identity")
	bad=value.duplicate(true); bad.attempts.back().config.seed=987655
	refused_unchanged(bad,"failed-result-configuration-mismatch")
	var next: Dictionary = value.duplicate(true)
	next.tiles[0].config.prompt="NEXT attempt only; never used for the retained native result."
	next.tiles[0].config.model="next-configuration-only-model"
	var next_path := write_fixture("next-configuration-session.json",next)
	var panel := LabPanel.new(); root.add_child(panel)
	await process_frame
	panel._current_file_action="open"; panel._file_selected(next_path); panel.refresh()
	var tile: Dictionary = panel.controller.tiles[0]
	var display: Dictionary = panel._result_config(tile)
	check(tile.config.prompt==next.tiles[0].config.prompt and tile.config.model==next.tiles[0].config.model,"reopen preserves separately editable next-attempt configuration")
	check(tile.has("_frozen_config") and display.prompt==next.attempts[0].config.prompt and display.model==next.attempts[0].config.model,"inspection labels the saved native result with its executed prompt and model")
	check(tile.material_sha256==next.attempts[0].material_sha256,"next-attempt edit cannot replace the saved native material result")
	panel.queue_free(); await process_frame

func run() -> void:
	evidence=OS.get_environment("BATCH_LAB_EVIDENCE_DIR")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path("placeholder")).get_base_dir())
	controller=Controller.new(); root.add_child(controller)
	await process_frame
	controller.configure_grid(1,1)
	for candidate: int in range(49000+OS.get_process_id()%1000,51000):
		if server.listen(candidate,"127.0.0.1")==OK: port=candidate; break
	if not check(port!=0,"synthetic credential fixture binds loopback only"): finish(); return
	if not check(fixture_thread.start(serve)==OK,"fixture serves independently of cancellation callbacks"): finish(); return
	await credential_case("rotation",false,false)
	await credential_case("clear",true,false)
	await credential_case("escaped-transport",true,false,"security-fixture-transport-\"quote\"-and-\\slash")
	await credential_case("clear-failure",true,true)
	close_server()
	escaped_credential_case()
	if controller.attempts.size()==4 and not controller.is_running(): await import_cases()
	else: check(false,"all four credential outcomes retained before import probes")
	finish()

func finish() -> void:
	close_server()
	var summary := {"checks":checks,"failures":failures,"actual_model_calls":0,
		"scope":"synthetic credential loopback transport; genuine native writes; categorical PNG corruption fixtures; headless Workbench panel reopen",
		"requests":request_count(),"retained_attempts":controller.attempts.size(),"png_structural_refusals":png_structural_refusals}
	if not evidence.is_empty(): write_fixture("security-summary.json",summary)
	print("BATCH_SECURITY_RESULT ",JSON.stringify(summary))
	controller.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
