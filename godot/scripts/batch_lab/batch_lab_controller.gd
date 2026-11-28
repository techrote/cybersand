extends Node
## Optional Batch Lab scheduler. Each active attempt owns its existing native
## Workbench worker; no mutation API or World reference reaches the live editor.
signal changed
signal tile_changed(index: int)
const TileHost = preload("res://scripts/batch_lab/batch_lab_tile_host.gd")
const Plan = preload("res://scripts/art_batch_plan.gd")
const Provider = preload("res://scripts/art_provider.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Experiments = preload("res://scripts/batch_lab/batch_lab_experiments.gd")
const FORMAT := "cybersand-native-batch-lab-v1"
const MAX_TILES := 16
const MAX_PARALLEL := 2
const MAX_ATTEMPTS := 128
const MAX_CELL_BUDGET := 262144
const MAX_FILE_BYTES := 192*1024*1024
const MAX_STORED_BYTES := 128*1024*1024
const MAX_CONFIG_BYTES := 1024*1024
const MAX_RESPONSE_BYTES := 1024*1024
const TERMINAL := ["completed","partial","refused","stopped"]
const SECRET_FIELDS := ["key","api_key","apikey","credential","credentials","authorization","token","access_token","password"]
const EXECUTION_ORIGINS := ["supplied-program","provider-request","provider-response","history-replay","captured-baseline"]
const SHAPE_SCHEMA_HINT := ". Use only these shapes. Line and polyline accept optional integer width (default 1) with rounded ends. Polyline and filled polygon use points:[[x,y],...]. Airbrush uses x,y,radius, optional density and hardness in [0,1], and an integer seed."
var tiles: Array[Dictionary] = []
var columns := 2
var rows := 2
var max_parallel := 2
var attempts: Array[Dictionary] = []
var provenance: Dictionary = {}
var _queue: Array[int] = []
var _active: Dictionary = {}
var _credentials: Dictionary = {}
var _stored_bytes := 0
var _sequence := 0
var _runtime_identity: Dictionary = {}

func _ready() -> void:
	var native_name := "cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so"
	_runtime_identity = {"runtime":Engine.get_version_info().string,"platform":OS.get_name(),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"native_binary_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/"+native_name),
		"controller_sha256":FileAccess.get_sha256("res://scripts/batch_lab/batch_lab_controller.gd"),
		"tile_host_sha256":FileAccess.get_sha256("res://scripts/batch_lab/batch_lab_tile_host.gd")}
	if tiles.is_empty(): configure_grid(2,2)

static func _ok() -> Dictionary:
	return {"ok":true}

static func _error(message: String) -> Dictionary:
	return {"ok":false,"reason":message}

static func _extent(value: Variant) -> Vector2i:
	if not value is Array or value.size()!=2: return Vector2i.ZERO
	for side: Variant in value:
		if not Plan.integer(side) or int(side)<64 or int(side)>512: return Vector2i.ZERO
	return Vector2i(int(value[0]),int(value[1]))

static func defaults() -> Dictionary:
	return {"prompt":"Construct a connected industrial room with purposeful negative space.",
		"variant":"P0","prompt_version":"batch-lab-v1","family":"architecture",
		"provider":"procedural","model":"deterministic-v1","seed":19301,
		"extent":[128,128],"source_region":[0,0,128,128],"materials":[0,58],"protection":[],
		"budget_cells":65536,"max_output_tokens":4096,"timeout_seconds":60,
		"endpoint":"http://localhost:1234/v1","source_rectangles":[],
		"operations":[{"shape":"rectangle","x0":12,"y0":108,"x1":115,"y1":112,"material":58},
			{"shape":"rectangle","x0":12,"y0":16,"x1":16,"y1":107,"material":58},
			{"shape":"rectangle","x0":111,"y0":16,"x1":115,"y1":107,"material":58}]}

func is_running() -> bool:
	return not _queue.is_empty() or not _active.is_empty()

func configure_grid(cols: int, count_rows: int) -> Dictionary:
	if is_running(): return _error("Stop and wait for native acknowledgements before changing the grid.")
	if cols<1 or count_rows<1 or cols>4 or count_rows>4 or cols*count_rows>MAX_TILES:
		return _error("Choose one to four columns and rows, at most sixteen tiles.")
	columns = cols
	rows = count_rows
	tiles.clear()
	for i: int in cols*count_rows:
		var config := defaults()
		config.seed = int(config.seed)+i
		tiles.append({"id":i,"config":config,"state":"idle","reason":"","attempt_id":"",
			"metrics":{},"receipts":[],"attempts":[],"material_cells":PackedByteArray(),
			"source_materials":PackedByteArray(),"image":null,"render_kind":"native-material-id",
			"result_extent":[],"provenance":{},"timings":{},"usage":{},"history_cursor":"result"})
	changed.emit()
	return _ok()

func _index(index: int) -> bool:
	return index>=0 and index<tiles.size()

static func _has_secret(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if str(key).to_lower() in SECRET_FIELDS: return true
			if _has_secret(value[key]): return true
	elif value is Array:
		for item: Variant in value:
			if _has_secret(item): return true
	return false

static func _canonical_numbers(value: Variant) -> Variant:
	# JSON reopens integer IDs as floats. Canonicalize validated integral values
	# before Array membership checks and stable native-program hashing.
	if value is float and Plan.integer(value): return int(value)
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_canonical_numbers(item))
		return result
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[key] = _canonical_numbers(value[key])
		return result
	return value

func configure_tile(index: int, value: Dictionary) -> Dictionary:
	if not _index(index): return _error("Unknown tile.")
	if tiles[index].state in ["queued","running"]: return _error("Stop this attempt before changing its configuration.")
	if _has_secret(value): return _error("Credentials belong in the volatile Key field, never experiment configuration.")
	var config: Dictionary = defaults()
	config.merge(value.duplicate(true),true)
	if config.get("source_cells") is PackedByteArray: config.source_cells = config.source_cells.duplicate()
	var reason := _validate(config)
	if not reason.is_empty(): return _error(reason)
	tiles[index].config = _canonical_numbers(config)
	tile_changed.emit(index)
	changed.emit()
	return _ok()

func _validate(config: Dictionary) -> String:
	if _has_secret(config): return "Credentials belong in the volatile Key field, never experiment configuration."
	var serializable := config.duplicate()
	serializable.erase("source_cells")
	if JSON.stringify(serializable).to_utf8_buffer().size()>MAX_CONFIG_BYTES: return "Configuration exceeds the 1 MiB bounded compilation input."
	if _sanitize(serializable)!=serializable: return "Remove credentials from the prompt, endpoint and configuration; use the volatile Key field."
	var size := _extent(config.get("extent"))
	if size == Vector2i.ZERO: return "Tile footprint must be 64–512 cells on each side."
	for key: String in ["prompt","model","endpoint","family","variant","prompt_version"]:
		if not config.get(key) is String: return "Configuration text is missing or malformed: "+key
	var region: Variant = config.get("source_region")
	if not region is Array or region.size()!=4: return "Source region uses x,y,width,height."
	for coordinate: Variant in region:
		if not Plan.integer(coordinate): return "Source region coordinates must be integers."
	if region[0]<0 or region[1]<0 or int(region[2])!=size.x or int(region[3])!=size.y:
		return "Source region must be nonnegative and match the tile footprint."
	if not Plan.integer(config.get("seed")) or int(config.seed)<0: return "Host seed must be a nonnegative 32-bit integer."
	if not Plan.integer(config.get("budget_cells")) or int(config.budget_cells)<1 or int(config.budget_cells)>MAX_CELL_BUDGET:
		return "Native checked-cell budget must be 1–262144 per attempt."
	if not config.get("materials") is Array or config.materials.is_empty(): return "Select supported destination materials."
	for id: Variant in config.materials:
		if not Plan.integer(id) or int(id) not in Setup.MATERIALS: return "Unsupported destination material."
	if not config.get("protection") is Array or config.protection.size()>64: return "At most 64 protection rectangles are supported."
	for rect: Variant in config.protection:
		if not rect is Array or rect.size()!=4: return "Protection rectangles use x,y,width,height."
		for n: Variant in rect:
			if not Plan.integer(n): return "Protection coordinates must be integers."
		if rect[0]<0 or rect[1]<0 or rect[2]<1 or rect[3]<1 or rect[0]+rect[2]>size.x or rect[1]+rect[3]>size.y:
			return "Protection must fit inside the tile."
	if not config.get("operations") is Array: return "Drawing operations must be a JSON array."
	if config.operations.size()>4096: return "At most 4096 drawing operations fit one attempt."
	if config.has("metrics_targets") and not config.metrics_targets is Dictionary: return "Diagnostic geometry targets must be an object."
	if str(config.get("prompt","")).to_utf8_buffer().size()>32768: return "Tile prompt exceeds 32 KiB."
	if str(config.get("provider","")) not in ["procedural","random","direct","LM Studio","OpenAI","NVIDIA"]:
		return "Select a supported provider or deterministic control."
	if not Plan.integer(config.get("max_output_tokens")) or int(config.max_output_tokens)<64 or int(config.max_output_tokens)>8192:
		return "Model output budget must be 64–8192 tokens."
	if not Plan.integer(config.get("timeout_seconds")) or int(config.timeout_seconds)<1 or int(config.timeout_seconds)>120:
		return "Model timeout must be 1–120 seconds."
	var endpoint := str(config.get("endpoint",""))
	if endpoint.contains("?") or endpoint.contains("#") or endpoint.contains("@") or endpoint.contains("\\") \
		or endpoint.contains("\n") or endpoint.contains("\r") or endpoint.contains("\t") or endpoint.contains(" "):
		return "Endpoint URLs cannot contain credentials, query strings, fragments or whitespace."
	return ""

func set_credential(provider: String, key: String) -> void:
	_credentials[provider] = key

func _sanitize(value: Variant, request_redactor: Node = null) -> Variant:
	# Reuse the existing Art provider's credential treatment. Keys remain volatile;
	# request-owned secrets survive rotation/clearing until its response retires.
	var redactor: Node = request_redactor if request_redactor!=null else Provider.new()
	for secret: Variant in _credentials.values():
		if not str(secret).is_empty() and str(secret) not in redactor.secrets: redactor.secrets.append(str(secret))
	var clean: Variant = _redacted_tree(value,redactor,{})
	if request_redactor==null: redactor.free()
	return clean

static func _redacted_string(value: String, redactor: Node, cache: Dictionary) -> String:
	if not cache.has(value): cache[value] = redactor.redact(value)
	return cache[value]

static func _redacted_tree(value: Variant, redactor: Node, cache: Dictionary) -> Variant:
	if value is String or value is StringName: return _redacted_string(str(value),redactor,cache)
	if value is Dictionary:
		var clean := {}
		for key: Variant in value:
			if str(key).to_lower() in SECRET_FIELDS: continue
			# Metadata keys are provider-controlled text too. A changed key is
			# omitted rather than merged with another '[redacted]' key.
			var safe_key := _redacted_string(str(key),redactor,cache)
			if safe_key!=str(key): continue
			clean[safe_key] = _redacted_tree(value[key],redactor,cache)
		return clean
	if value is Array or value is PackedStringArray:
		var clean: Array = []
		for item: Variant in value: clean.append(_redacted_tree(item,redactor,cache))
		return clean
	return value

static func local_endpoint(endpoint: String) -> bool:
	# This evaluator has authority for local inference only. Literal loopback or
	# private LAN addresses cannot be repointed through DNS to a paid public API.
	var clean := endpoint.strip_edges()
	if not clean.begins_with("http://") and not clean.begins_with("https://"): return false
	var authority := clean.get_slice("://",1).get_slice("/",0)
	if clean.contains("@") or clean.contains("?") or clean.contains("#") or clean.contains("\\") \
		or clean.contains(" ") or clean.contains("\n") or clean.contains("\r") or clean.contains("\t"): return false
	var host_name := authority.get_slice(":",0).to_lower()
	var port := ""
	if authority.begins_with("["):
		if not authority.begins_with("[::1]"): return false
		host_name = "[::1]"
		var suffix := authority.substr(5)
		if not suffix.is_empty():
			if not suffix.begins_with(":"): return false
			port = suffix.substr(1)
			if port.is_empty(): return false
	elif authority.contains(":"):
		if authority.count(":")!=1: return false
		port = authority.get_slice(":",1)
		if port.is_empty(): return false
	if not port.is_empty() and (not port.is_valid_int() or str(int(port))!=port or int(port)<1 or int(port)>65535): return false
	if host_name in ["localhost","[::1]"]: return true
	var parts := host_name.split(".")
	if parts.size()!=4: return false
	var numbers: Array[int] = []
	for part: String in parts:
		if not part.is_valid_int() or str(int(part))!=part or int(part)<0 or int(part)>255: return false
		numbers.append(int(part))
	return numbers[0]==127 or numbers[0]==10 or (numbers[0]==192 and numbers[1]==168) or (numbers[0]==172 and numbers[1]>=16 and numbers[1]<=31)

static func _source_context(cells: PackedByteArray, size: Vector2i) -> Dictionary:
	# Exact nonempty horizontal runs, not an inferred image-to-material label map.
	# Empty cells are implicit. Refuse dense context rather than truncate the source.
	var runs: Array = []
	for y: int in size.y:
		var x := 0
		while x<size.x:
			var material := cells.decode_u16((y*size.x+x)*2)
			if material==0: x+=1; continue
			var end := x+1
			while end<size.x and cells.decode_u16((y*size.x+end)*2)==material: end+=1
			runs.append([x,y,end-x,material])
			if runs.size()>2048: return _error("Exact source context exceeds 2048 material runs; crop the tile or use direct/procedural construction.")
			x = end
	var text := JSON.stringify({"encoding":"horizontal [x,y,width,material_id]; unlisted cells are Empty 0",
		"extent":[size.x,size.y],"material_sha256":TileHost.digest(cells),"runs":runs})
	if text.to_utf8_buffer().size()>65536: return _error("Exact source context exceeds 64 KiB; crop the tile before local inference.")
	return {"ok":true,"text":text,"sha256":text.sha256_text(),"runs":runs.size()}

static func _provider_instructions(config: Dictionary, source_context: String) -> String:
	# The same accepted seven-shape hint used by ArtBatchPanel is provided to
	# every prompt variant. P3 never silently gains additional tools/schema.
	return Provider.INSTRUCTIONS+"\nEnabled shapes: "+JSON.stringify(Plan.SHAPES)+SHAPE_SCHEMA_HINT \
		+"\nAllowed materials: "+JSON.stringify(config.materials) \
		+". Local footprint: "+JSON.stringify(config.extent)+". Host seed: "+str(config.seed) \
		+". Checked-cell budget: "+str(config.budget_cells)+". Protected rectangles [x,y,width,height]: "+JSON.stringify(config.protection) \
		+". Original source region: "+JSON.stringify(config.source_region) \
		+". Diagnostic geometry targets: "+JSON.stringify(config.get("metrics_targets",{})) \
		+". These targets describe intended feature regions, connectivity, negative space and geometric clearance. " \
		+"They are not aesthetic scores or proof of native actor traversability/playability. " \
		+"The following exact material baseline will be independently restored and read back before applying your commands. " \
		+"Only existing Empty 0 and HardWall 58 are eligible sources. Preserve other materials and protection. Source: "+source_context

func compile_preview(index: int) -> Dictionary:
	if not _index(index): return _error("Unknown tile.")
	var config: Dictionary = tiles[index].config
	var reason := _validate(config)
	if not reason.is_empty(): return _error(reason)
	var plan := Plan.new()
	if not plan.configure(config.operations,Rect2i(Vector2i.ZERO,_extent(config.extent))): return _error(plan.error)
	for operation: Dictionary in plan.operations:
		if int(operation.material) not in config.materials: return _error("An operation requests a disabled destination material.")
	return {"ok":true,"zero_writes":true,"operations":config.operations.duplicate(true),
		"extent":config.extent.duplicate(),"budget_cells":config.budget_cells,
		"reason":"Compilation preview only; applied counts require native execution and readback."}

func _source(config: Dictionary) -> Dictionary:
	var size := _extent(config.extent)
	var cells := PackedByteArray()
	cells.resize(size.x*size.y*2)
	if config.has("source_cells"):
		var raw: Variant = config.source_cells
		var source_extent: Variant = config.get("source_extent",config.extent)
		var region: Variant = config.get("source_region",[0,0,size.x,size.y])
		if not raw is PackedByteArray or not source_extent is Array or source_extent.size()!=2 \
			or not region is Array or region.size()!=4: return _error("Source capture is malformed.")
		for n: Variant in source_extent+region:
			if not Plan.integer(n): return _error("Source capture coordinates must be integers.")
		var source_size := Vector2i(int(source_extent[0]),int(source_extent[1]))
		if source_size.x<1 or source_size.y<1 or source_size.x>2048 or source_size.y>2048 or raw.size()!=source_size.x*source_size.y*2:
			return _error("Source capture size is invalid.")
		if int(region[2])!=size.x or int(region[3])!=size.y or region[0]<0 or region[1]<0 \
			or region[0]+size.x>source_size.x or region[1]+size.y>source_size.y: return _error("Source crop must match the tile footprint and fit its captured source.")
		cells.clear()
		for y: int in size.y:
			var offset := ((y+int(region[1]))*source_size.x+int(region[0]))*2
			cells.append_array(raw.slice(offset,offset+size.x*2))
	var rectangles: Variant = config.get("source_rectangles",[])
	if not rectangles is Array or rectangles.size()>4096: return _error("Source rectangles exceed the bounded source recipe.")
	var source_work := 0
	for rect: Variant in rectangles:
		if not rect is Array or rect.size()!=5: return _error("Source rectangles use x,y,width,height,material.")
		for n: Variant in rect:
			if not Plan.integer(n): return _error("Source rectangle values must be integers.")
		if rect[0]<0 or rect[1]<0 or rect[2]<1 or rect[3]<1 or rect[0]+rect[2]>size.x or rect[1]+rect[3]>size.y \
			or rect[4]<0 or rect[4]>255: return _error("Source rectangle lies outside the tile or material catalogue.")
		source_work += int(rect[2])*int(rect[3])
		if source_work>MAX_CELL_BUDGET: return _error("Initial source recipe exceeds 262144 cells of construction work.")
		for y: int in range(int(rect[1]),int(rect[1]+rect[3])):
			for x: int in range(int(rect[0]),int(rect[0]+rect[2])): cells.encode_u16((y*size.x+x)*2,int(rect[4]))
	return {"ok":true,"cells":cells}

func start(indices: Array = []) -> Dictionary:
	var selected: Array = indices.duplicate()
	if selected.is_empty(): selected = range(tiles.size())
	if attempts.size()+_queue.size()+_active.size()+selected.size()>MAX_ATTEMPTS:
		return _error("This session has reached its 128-attempt evidence capacity. Save it and begin another session.")
	var seen := {}
	for value: Variant in selected:
		if not Plan.integer(value) or not _index(int(value)) or seen.has(int(value)): return _error("Select unique existing tile indices.")
		seen[int(value)] = true
		if tiles[int(value)].state in ["queued","running"]: return _error("A selected tile is already queued or running.")
	for value: Variant in selected:
		var index := int(value)
		_sequence += 1
		var tile: Dictionary = tiles[index]
		var config: Dictionary = tile.config.duplicate(true)
		if config.get("source_cells") is PackedByteArray: config.source_cells = config.source_cells.duplicate()
		var attempt_id := "%d-%s" % [_sequence,Crypto.new().generate_random_bytes(6).hex_encode()]
		tile.state = "queued"
		tile.reason = ""
		tile.attempt_id = attempt_id
		tile["_frozen_config"] = config
		tile["_queued_usec"] = Time.get_ticks_usec()
		tile["_restore_only"] = false
		tile["_native_readback_current_process"] = false
		tile["execution_origin"] = "supplied-program" if str(config.provider) in ["procedural","random","direct"] else "provider-request"
		tile.metrics = {}
		tile.receipts = []
		tile.image = null
		tile["render_image"] = null
		tile.material_cells = PackedByteArray()
		tile.source_materials = PackedByteArray()
		tile["material_sha256"] = ""
		tile["model_response"] = ""
		tile["accepted_edits"] = []
		tile.erase("history_attempt")
		tile.history_cursor = "result"
		tile.result_extent = config.extent.duplicate()
		tile.render_kind = "native-material-id"
		tile.provenance = provenance.duplicate(true)
		tile.provenance.merge(_runtime_identity,true)
		tile.provenance["native_world_isolation"] = "one exclusive CyberSimulationWorker/CyberNativeCellWorld per active attempt"
		tile.provenance["state_scope"] = "paused material identities; not an evolved physics checkpoint"
		tile.provenance["actual_prompt_sha256"] = str(config.prompt).sha256_text()
		tile.provenance["request_configuration_sha256"] = JSON.stringify(_config_identity(config)).sha256_text()
		tile.provenance["request_configuration_scope"] = "canonical configuration when queued, before any provider program replacement"
		tile.provenance["compiled_program_admitted"] = false
		tile.timings = {"model_ms":0.0,"compile_ms":0.0,"native_ms":0.0,"capture_ms":0.0,"total_ms":0.0}
		tile.usage = {}
		_queue.append(index)
		tile_changed.emit(index)
	changed.emit()
	return _ok()

func stop(indices: Array = []) -> void:
	var selected: Array = range(tiles.size()) if indices.is_empty() else indices
	for value: Variant in selected:
		if not Plan.integer(value) or not _index(int(value)): continue
		var index := int(value)
		if _queue.has(index):
			_queue.erase(index)
			_finish(index,"stopped","Stopped before inference or native execution.")
		elif _active.has(index):
			var work: Dictionary = _active[index]
			if work.has("initializing"):
				work["stop_requested"] = true
			elif work.has("provider"):
				work.provider.cancel()
				_record_provider_trace(tiles[index],work.provider)
				work.provider.queue_free()
				_active.erase(index)
				_finish(index,"stopped","Inference stopped; no native commands were applied.")
			elif work.has("host"): work.host.stop()
	changed.emit()

func reset() -> Dictionary:
	if is_running(): return _error("Stop and wait before resetting the presentation grid.")
	# Original attempts stay in the session ledger. Reset never silently erases
	# failed, partial or valuable completed evidence.
	return configure_grid(columns,rows)

func repeat(index: int) -> Dictionary:
	return start([index])

func replay(index: int) -> Dictionary:
	if not _index(index) or str(tiles[index].attempt_id).is_empty(): return _error("No retained attempt to replay.")
	if tiles[index].state in ["queued","running"]: return _error("Stop this tile before replay.")
	var record := _find_attempt(str(tiles[index].attempt_id))
	if record.is_empty(): return _error("The attempt is not yet retained.")
	if record.material_cells.is_empty(): return _error("No captured native result is available to replay. Repeat retains a new proposal separately.")
	var config: Dictionary = record.config.duplicate(true)
	config.provider = "direct"
	config.model = "replay-native-program"
	config.operations = record.get("operations",config.get("operations",[])).duplicate(true)
	var no_confirmed_work := false
	var restore_result := false
	if record.state in ["partial","stopped"] and not record.material_cells.is_empty():
		# Native checked counts identify the consumed prefix of the same deterministic
		# raster stream. Expanding accepted edits can exceed the operation cap even
		# for one valid pixels command; retain the compact original program instead.
		var checked := 0
		for receipt: Dictionary in record.receipts:
			checked += int(receipt.get("checked",0))
			if int(receipt.get("refused",0))>0: restore_result = true
		config.budget_cells = maxi(1,checked)
		no_confirmed_work = checked==0
		config["replay_mode"] = "native-confirmed-candidate-prefix"
		config["replay_checked_prefix"] = checked
	config.source_cells = record.source_materials.duplicate()
	if restore_result:
		# A failed native write may be counted as checked without confirmation.
		# Reconstruct the captured result rather than retrying that failed candidate.
		config.source_cells = record.material_cells.duplicate()
		config.operations = []
		config["replay_mode"] = "native-result-baseline-after-write-refusal"
		no_confirmed_work = true
	config.source_extent = record.result_extent.duplicate()
	config.source_region = [0,0,int(record.result_extent[0]),int(record.result_extent[1])]
	config.source_rectangles = []
	config["replay_of"] = record.attempt_id
	var configured := configure_tile(index,config)
	if not configured.ok: return configured
	var answer := start([index])
	if answer.ok:
		tiles[index].execution_origin = "captured-baseline" if no_confirmed_work else "history-replay"
		if no_confirmed_work: tiles[index]._restore_only = true
	return answer

func undo(index: int) -> Dictionary:
	return _restore(index,false)

func redo(index: int) -> Dictionary:
	return _restore(index,true)

func _restore(index: int, redo_result: bool) -> Dictionary:
	if not _index(index) or tiles[index].state in ["queued","running"]: return _error("Wait for this tile's native acknowledgement.")
	var tile: Dictionary = tiles[index]
	var original_id := str(tile.get("history_attempt",tile.attempt_id))
	var original := _find_attempt(original_id)
	if original.is_empty() or original.material_cells.is_empty(): return _error("No captured material result is available for isolated history.")
	var config: Dictionary = original.config.duplicate(true)
	config.source_cells = original.material_cells.duplicate() if redo_result else original.source_materials.duplicate()
	config.source_extent = original.result_extent.duplicate()
	config.source_region = [0,0,int(original.result_extent[0]),int(original.result_extent[1])]
	config.source_rectangles = []
	config.provider = "direct"
	config.model = "native-baseline-history"
	config.operations = []
	config["history_of"] = original_id
	config["history_action"] = "redo" if redo_result else "undo"
	var configured := configure_tile(index,config)
	if not configured.ok: return configured
	var answer := start([index])
	if answer.ok:
		tile._restore_only = true
		tile.execution_origin = "captured-baseline"
		tile.history_attempt = original_id
		tile.history_cursor = "result" if redo_result else "source"
	return answer

func _process(_delta: float) -> void:
	# Native work is asynchronous; process a fixed number of active owners.
	for index: int in _active.keys():
		var work: Dictionary = _active[index]
		if work.has("initializing"):
			if work.initializing.is_alive(): continue
			var admitted: Dictionary = work.initializing.wait_to_finish()
			work.erase("initializing")
			if not admitted.ok:
				work.host.close()
				work.host.queue_free()
				_active.erase(index)
				_finish(index,"refused",admitted.reason)
				continue
			if work.get("stop_requested",false): work.host.stop()
		if work.has("analysis"):
			if work.analysis.is_alive(): continue
			var analysis: Dictionary = work.analysis.wait_to_finish()
			tiles[index].metrics["structure"] = analysis.metrics
			tiles[index].image = analysis.image
			tiles[index].timings["analysis_ms"] = analysis.elapsed_ms
			_active.erase(index)
			_finish(index,str(work.status),str(work.reason))
			continue
		if not work.has("host"): continue
		var owner: Node = work.host
		owner.poll()
		tiles[index].metrics = owner.result.duplicate(true)
		if owner.phase != "finished": continue
		var tile: Dictionary = tiles[index]
		tile.material_cells = owner.final_cells.duplicate()
		# Volatile host observation only. Serialized receipts cannot mint this
		# current-process fact; imports reset it even when they supply the field.
		tile["_native_readback_current_process"] = not owner.final_cells.is_empty()
		tile.source_materials = owner.initial_cells.duplicate()
		tile.receipts = owner.receipts.duplicate(true)
		tile["accepted_edits"] = owner.applied.get("edits",[]).duplicate(true)
		tile.timings.merge(owner.timings,true)
		tile.timings.model_ms = work.get("model_ms",0.0)
		tile.provenance["worker_instance"] = owner.simulation_worker.get_instance_id()
		tile.provenance["generation"] = owner.generation
		tile.provenance["source_material_sha256"] = TileHost.digest(tile.source_materials)
		tile.provenance["material_sha256"] = "" if tile.material_cells.is_empty() else TileHost.digest(tile.material_cells)
		var status := str(owner.result.get("status","refused"))
		var reason := str(owner.result.get("reason",""))
		owner.close()
		owner.queue_free()
		_active.erase(index)
		if not tile.material_cells.is_empty():
			var analysis := Thread.new()
			var error := analysis.start(_analyse.bind(tile._frozen_config.duplicate(true),tile.source_materials.duplicate(),tile.material_cells.duplicate(),_extent(tile.result_extent)))
			if error==OK: _active[index] = {"analysis":analysis,"status":status,"reason":reason}
			else: _finish(index,"partial","Native result retained; could not start bounded analysis worker.")
		else: _finish(index,status,reason)
	while _active.size()<clampi(max_parallel,1,MAX_PARALLEL) and not _queue.is_empty():
		_begin(_queue.pop_front())

func _begin(index: int) -> void:
	var tile: Dictionary = tiles[index]
	var config: Dictionary = tile._frozen_config
	var reason := _validate(config)
	if not reason.is_empty(): _finish(index,"refused",reason); return
	var source := _source(config)
	if not source.ok: _finish(index,"refused",source.reason); return
	tile.source_materials = source.cells
	tile.provenance["source_material_sha256"] = TileHost.digest(source.cells)
	if _stored_bytes+source.cells.size()*4>MAX_STORED_BYTES:
		_finish(index,"refused","Session result capacity reached. Save this evidence and begin another session.")
		return
	tile.state = "running"
	var provider := str(config.provider)
	if provider in ["OpenAI","NVIDIA"]:
		_finish(index,"refused","Paid cloud batch dispatch is not authorised for this evaluator. Requested model retained; genuine cloud comparison is pending explicit spending authority.")
		return
	if provider == "LM Studio":
		if not local_endpoint(str(config.endpoint)):
			_finish(index,"refused","Local inference requires localhost or a literal private LAN endpoint; public cloud dispatch is not authorised.")
			return
		var source_context := _source_context(source.cells,_extent(config.extent))
		if not source_context.ok:
			_finish(index,"refused",source_context.reason)
			return
		tile.provenance["model_source_context_sha256"] = source_context.sha256
		tile.provenance["model_source_context_runs"] = source_context.runs
		tile.provenance["model_source_context_scope"] = "complete immutable input material plane; native restoration must agree before editing"
		var connection := Provider.new()
		connection.traffic_directory = "user://batch-lab-traffic"
		if not connection.traffic_namespace_valid():
			connection.free()
			_finish(index,"refused","Batch Lab traffic namespace is invalid or aliases ordinary Art history; no provider request was sent.")
			return
		add_child(connection)
		var identity := str(tile.attempt_id)
		_active[index] = {"provider":connection,"attempt_id":identity,"model_started_usec":Time.get_ticks_usec()}
		connection.finished.connect(func(_id: int, text: String, response: Dictionary, error: String):
			_provider_done(index,identity,text,response,error))
		var instructions := _provider_instructions(config,str(source_context.text))
		tile.provenance["model_common_context_sha256"] = instructions.sha256_text()
		var message := connection.send("LM Studio",str(config.endpoint),str(config.model),str(_credentials.get("LM Studio","")),
			str(config.prompt),instructions,
			int(config.max_output_tokens),float(config.timeout_seconds))
		if not message.is_empty(): _provider_done(index,identity,"",{},message)
	else:
		_begin_native(index,0.0)
	tile_changed.emit(index)
	changed.emit()

func _record_provider_trace(tile: Dictionary, connection: Node) -> void:
	var path := str(connection.log_path)
	if connection.traffic_directory=="user://batch-lab-traffic" and connection._valid_writer_path(path) and FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file!=null:
			tile.provenance["provider_traffic"] = {"path":path,"sha256":FileAccess.get_sha256(path),
				"bytes":file.get_length(),"scope":"sanitized Batch Lab transport JSONL; separate from ordinary Art history"}
			file.close()
	else:
		tile.provenance["provider_traffic"] = {"available":false,"reason":str(connection.log_warning)}

func _provider_done(index: int, identity: String, text: String, response: Dictionary, error: String) -> void:
	if not _active.has(index) or str(_active[index].attempt_id)!=identity or str(tiles[index].attempt_id)!=identity: return
	var work: Dictionary = _active[index]
	var elapsed := float(Time.get_ticks_usec()-int(work.model_started_usec))/1000.0
	var tile: Dictionary = tiles[index]
	tile.timings.model_ms = elapsed
	var clean_text := str(_sanitize(text,work.provider))
	var clean_error := str(_sanitize(error,work.provider))
	var response_bytes := clean_text.to_utf8_buffer()
	var response_size := JSON.stringify(response).to_utf8_buffer().size()
	var over_capacity := response_bytes.size()>MAX_RESPONSE_BYTES or response_size>MAX_RESPONSE_BYTES
	if not response.is_empty() or not text.is_empty(): tile.execution_origin = "provider-response"
	tile.provenance["model_response_sha256"] = TileHost.digest(response_bytes)
	tile.provenance["model_response_bytes"] = response_bytes.size()
	tile.provenance["model_response_digest_scope"] = "assistant text after existing ArtProvider credential redaction"
	tile.provenance["provider_packet_bytes"] = response_size
	tile["model_response"] = clean_text if not over_capacity else "[Response exceeded the 1 MiB retention limit; no program admitted. Digest and byte count retained.]"
	tile.provenance["model_response_complete"] = not over_capacity
	tile.usage = {} if over_capacity else _sanitize({"reported":response.get("usage",{}),"cost_usd":null,"cost_known":false,
		"requested_model":tile._frozen_config.model,"returned_model":response.get("model","unknown")},work.provider)
	_record_provider_trace(tile,work.provider)
	work.provider.queue_free()
	_active.erase(index)
	if over_capacity: _finish(index,"refused","Local provider response exceeds the 1 MiB bounded response capacity; no native writes."); return
	if not clean_error.is_empty(): _finish(index,"refused",clean_error); return
	var operations: Variant = Provider.operations(clean_text)
	if not operations is Array: _finish(index,"refused","Provider output was not a complete drawing array; original text retained."); return
	var candidate: Dictionary = tile._frozen_config.duplicate(true)
	candidate.operations = operations.duplicate(true)
	var validation := _validate(candidate)
	if not validation.is_empty(): _finish(index,"refused",validation); return
	tile._frozen_config = _canonical_numbers(candidate)
	_begin_native(index,elapsed)

func _begin_native(index: int, model_ms: float) -> void:
	var tile: Dictionary = tiles[index]
	var config: Dictionary = tile._frozen_config
	if not bool(tile.get("_restore_only",false)):
		var plan := Plan.new()
		var begin := Time.get_ticks_usec()
		if not plan.configure(config.operations,Rect2i(Vector2i.ZERO,_extent(config.extent))):
			_finish(index,"refused",plan.error)
			return
		for operation: Dictionary in plan.operations:
			if int(operation.material) not in config.materials: _finish(index,"refused","An operation requests a disabled destination material."); return
		tile.timings.compile_ms = float(Time.get_ticks_usec()-begin)/1000.0
		tile.provenance["compiled_program_admitted"] = true
	var owner := TileHost.new()
	add_child(owner)
	# World construction and its first immutable publication can be expensive.
	# This private initializer touches copied values/RefCounted native adapters
	# only; no scene-tree APIs run in it. Main begins polling after its join.
	var initializing := Thread.new()
	var error := initializing.start(owner.begin.bind(config.duplicate(true),tile.source_materials.duplicate(),bool(tile.get("_restore_only",false))))
	if error!=OK:
		owner.close()
		owner.queue_free()
		_finish(index,"refused","Could not start bounded native initialization worker.")
		return
	_active[index] = {"initializing":initializing,"host":owner,"attempt_id":tile.attempt_id,"model_ms":model_ms}

func _finish(index: int, status: String, reason: String) -> void:
	var tile: Dictionary = tiles[index]
	tile.state = status if status in TERMINAL else "refused"
	tile.reason = reason
	tile.timings.total_ms = float(Time.get_ticks_usec()-int(tile.get("_queued_usec",Time.get_ticks_usec())))/1000.0
	if not tile.material_cells.is_empty():
		tile["material_sha256"] = TileHost.digest(tile.material_cells)
	tile.provenance["attempt_id"] = tile.attempt_id
	tile.provenance["outcome"] = tile.state
	tile.provenance["runtime"] = Engine.get_version_info().string
	tile.provenance["source_material_sha256"] = "" if tile.source_materials.is_empty() else TileHost.digest(tile.source_materials)
	tile.provenance["actual_program_sha256"] = JSON.stringify(_canonical_numbers(tile._frozen_config.operations)).sha256_text()
	var final_config := _config_identity(tile._frozen_config)
	tile.provenance["configuration_sha256"] = JSON.stringify(final_config).sha256_text()
	tile.provenance["configuration_scope"] = "canonical retained record.config; input capture bytes represented by source_cells_sha256"
	tile.provenance["actual_prompt_sha256"] = str(final_config.prompt).sha256_text()
	tile.provenance["execution_origin"] = tile.execution_origin
	tile.provenance["execution_origin_scope"] = "controller execution path; provider-response does not establish genuine inference or model identity"
	var record := _record(tile)
	attempts.append(record)
	tile.attempts.append(record.attempt_id)
	_stored_bytes += _record_bytes(record)
	tile_changed.emit(index)
	changed.emit()

static func _analyse(config: Dictionary, source: PackedByteArray, result: PackedByteArray, size: Vector2i) -> Dictionary:
	# Pure copied value data only: no live World, UI or shared resource access.
	var started := Time.get_ticks_usec()
	var before := PackedInt32Array()
	var after := PackedInt32Array()
	before.resize(source.size()/2)
	after.resize(result.size()/2)
	for i: int in before.size(): before[i] = source.decode_u16(i*2)
	for i: int in after.size(): after[i] = result.decode_u16(i*2)
	var metrics := Experiments.evaluate_materials(config,before,after)
	return {"metrics":metrics,"image":material_image(result,size),"elapsed_ms":float(Time.get_ticks_usec()-started)/1000.0}

static func _config_identity(config: Dictionary) -> Dictionary:
	var identity := config.duplicate(true)
	if identity.has("source_cells"):
		identity["source_cells_sha256"] = TileHost.digest(identity.source_cells)
		identity.erase("source_cells")
	return _canonical_numbers(identity)

static func _record_bytes(record: Dictionary) -> int:
	var metadata := record.duplicate()
	var count: int = record.source_materials.size()+record.material_cells.size()+record.get("render_png",PackedByteArray()).size()
	metadata.erase("source_materials"); metadata.erase("material_cells"); metadata.erase("render_png")
	return count+JSON.stringify(metadata).to_utf8_buffer().size()

static func material_image(cells: PackedByteArray, size: Vector2i) -> Image:
	if size==Vector2i.ZERO or cells.size()!=size.x*size.y*2: return null
	# A deliberately categorical diagnostic, not a claim of Godot rendering.
	var pixels := PackedByteArray()
	pixels.resize(size.x*size.y*3)
	for i: int in size.x*size.y:
		var id := cells.decode_u16(i*2)
		var color := Color(0.035,0.045,0.065) if id==0 else Color.from_hsv(fmod(float(id)*0.61803398875,1.0),0.4,0.9)
		if id==58: color = Color(0.68,0.74,0.8)
		pixels[i*3] = color.r8; pixels[i*3+1] = color.g8; pixels[i*3+2] = color.b8
	return Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGB8,pixels)

func _record(tile: Dictionary) -> Dictionary:
	var config := _config_identity(tile.get("_frozen_config",tile.config))
	var value := {"attempt_id":tile.attempt_id,"config":config,"state":tile.state,"reason":tile.reason,
		"_native_readback_current_process":bool(tile.get("_native_readback_current_process",false)),
		"execution_origin":tile.execution_origin,
		"result_extent":tile.result_extent.duplicate(),"source_materials":tile.source_materials.duplicate(),
		"material_cells":tile.material_cells.duplicate(),"material_sha256":tile.get("material_sha256",""),
		"receipts":tile.receipts.duplicate(true),"accepted_edits":tile.get("accepted_edits",[]).duplicate(true),
		"operations":config.get("operations",[]).duplicate(true),"metrics":tile.metrics.duplicate(true),
		"timings":tile.timings.duplicate(true),"usage":tile.usage.duplicate(true),"provenance":tile.provenance.duplicate(true),
		"model_response":tile.get("model_response",""),"render_kind":tile.render_kind}
	return value

func _find_attempt(identity: String) -> Dictionary:
	for record: Dictionary in attempts:
		if str(record.attempt_id)==identity: return record
	return {}

func select_attempt(index: int, identity: String) -> Dictionary:
	if not _index(index) or tiles[index].state in ["queued","running"]: return _error("Stop this tile before selecting retained evidence.")
	var record := _find_attempt(identity)
	if record.is_empty(): return _error("Unknown retained attempt.")
	var tile: Dictionary = tiles[index]
	tile["_native_readback_current_process"] = bool(record.get("_native_readback_current_process",false))
	for key: String in ["attempt_id","state","reason","execution_origin","result_extent","source_materials","material_cells","material_sha256","receipts","accepted_edits","metrics","timings","usage","provenance","render_kind"]:
		if record.has(key): tile[key] = record[key].duplicate(true) if record[key] is Dictionary or record[key] is Array else record[key]
	tile.image = material_image(tile.material_cells,_extent(tile.result_extent))
	tile["render_image"] = null
	if record.has("render_png"):
		var image := Image.new()
		if image.load_png_from_buffer(record.render_png)==OK: tile.render_image = image
	tile["_frozen_config"] = record.config.duplicate(true)
	tile["history_attempt"] = str(record.config.get("history_of",record.attempt_id))
	tile.history_cursor = "source" if record.config.get("history_action","")=="undo" else "result"
	if identity not in tile.attempts: tile.attempts.append(identity)
	tile_changed.emit(index)
	changed.emit()
	return _ok()

func record_render(index: int, identity: String, image: Image, renderer: Dictionary) -> Dictionary:
	if not _index(index) or str(tiles[index].attempt_id)!=identity or tiles[index].state not in TERMINAL:
		return _error("Render belongs to a retired or unfinished attempt.")
	if image==null or image.is_empty() or image.get_width()>2048 or image.get_height()>2048:
		return _error("Rendered image is missing or exceeds capture bounds.")
	var record := _find_attempt(identity)
	if record.is_empty(): return _error("Unknown retained attempt.")
	if record.material_cells.is_empty() or renderer.get("material_sha256")!=record.material_sha256 or _has_secret(renderer):
		return _error("Renderer must identify the same retained native material plane.")
	var png := image.save_png_to_buffer()
	if png.size()>8*1024*1024 or _stored_bytes+png.size()>MAX_STORED_BYTES: return _error("Rendered image exceeds session capacity.")
	_stored_bytes += png.size()-record.get("render_png",PackedByteArray()).size()
	record["render_png"] = png
	record["render_png_sha256"] = TileHost.digest(png)
	record["renderer"] = renderer.duplicate(true)
	record.render_kind = "godot-rendered-material-plane"
	tiles[index]["render_image"] = image.duplicate()
	tiles[index].render_kind = record.render_kind
	tiles[index].provenance["renderer"] = renderer.duplicate(true)
	tile_changed.emit(index)
	return _ok()

static func _encode(record: Dictionary) -> Dictionary:
	var value := record.duplicate(true)
	value.erase("_native_readback_current_process")
	value["source_materials_base64"] = "" if value.source_materials.is_empty() else Marshalls.raw_to_base64(value.source_materials)
	value["material_cells_base64"] = "" if value.material_cells.is_empty() else Marshalls.raw_to_base64(value.material_cells)
	value.erase("source_materials"); value.erase("material_cells")
	if value.has("render_png"):
		value["render_png_base64"] = Marshalls.raw_to_base64(value.render_png)
		value.erase("render_png")
	return value

func _write(path: String, value: Dictionary) -> Dictionary:
	var bytes := JSON.stringify(_sanitize(value)).to_utf8_buffer()
	if bytes.size()>MAX_FILE_BYTES: return _error("Export exceeds the bounded session file size.")
	var target := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir())!=OK: return _error("Cannot create export directory.")
	var temporary := target+"."+Crypto.new().generate_random_bytes(6).hex_encode()+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return _error("Cannot create export file.")
	file.store_buffer(bytes); file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK:
		DirAccess.remove_absolute(temporary)
		return _error("Could not write complete experiment evidence.")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge") if ClassDB.class_exists(&"CyberDemoBridge") else null
	if bridge==null or not bridge.has_method("replace_material_baseline_file"):
		DirAccess.remove_absolute(temporary)
		return _error("Atomic evidence export requires the source-matched native runtime.")
	var replaced: Dictionary = bridge.replace_material_baseline_file(temporary,target)
	if not replaced.get("ok",false):
		DirAccess.remove_absolute(temporary)
		return _error("Previous export retained: "+str(replaced.get("error","atomic replacement failed")))
	return {"ok":true,"path":target,"sha256":TileHost.digest(bytes),"bytes":bytes.size()}

func export_result(index: int, path: String) -> Dictionary:
	if not _index(index) or tiles[index].state not in TERMINAL: return _error("Wait for a terminal native result before exporting.")
	var record := _find_attempt(str(tiles[index].attempt_id))
	if record.is_empty(): return _error("No retained result.")
	return _write(path,{"format":FORMAT,"kind":"attempt","attempt":_encode(record)})

func save_session(path: String) -> Dictionary:
	if is_running(): return _error("Stop and wait for native acknowledgements before saving the session.")
	var records: Array = []
	for record: Dictionary in attempts: records.append(_encode(record))
	var views: Array = []
	for tile: Dictionary in tiles:
		var config: Dictionary = tile.config.duplicate(true)
		if config.has("source_cells"):
			config["source_cells_base64"] = "" if config.source_cells.is_empty() else Marshalls.raw_to_base64(config.source_cells)
			config["source_cells_sha256"] = TileHost.digest(config.source_cells)
			config.erase("source_cells")
		views.append({"config":config,"attempt_id":tile.attempt_id,"history_attempt":tile.get("history_attempt",""),"history_cursor":tile.history_cursor})
	return _write(path,{"format":FORMAT,"kind":"session","columns":columns,"rows":rows,
		"attempts":records,"tiles":views,"provenance":provenance,"sequence":_sequence})

static func _base64(value: Variant, maximum: int, allow_empty := true) -> Dictionary:
	if not value is String or value.length()>((maximum+2)/3)*4: return _error("Stored payload exceeds its capacity.")
	if value.is_empty(): return {"ok":true,"bytes":PackedByteArray()} if allow_empty else _error("Stored payload is missing.")
	if value.length()%4!=0 or RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}$").search(value)==null:
		return _error("Stored payload is not canonical base64.")
	var bytes := Marshalls.base64_to_raw(value)
	if bytes.is_empty() or bytes.size()>maximum or Marshalls.raw_to_base64(bytes)!=value: return _error("Stored payload is truncated or noncanonical.")
	return {"ok":true,"bytes":bytes}

static func _png_dimensions(bytes: PackedByteArray) -> Vector2i:
	if bytes.size()<45 or bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) \
		or bytes.slice(12,16).get_string_from_ascii()!="IHDR": return Vector2i.ZERO
	var width := (int(bytes[16])<<24)|(int(bytes[17])<<16)|(int(bytes[18])<<8)|int(bytes[19])
	var height := (int(bytes[20])<<24)|(int(bytes[21])<<16)|(int(bytes[22])<<8)|int(bytes[23])
	return Vector2i(width,height) if width>0 and height>0 and width<=2048 and height<=2048 else Vector2i.ZERO

static func _png_chunks_complete(bytes: PackedByteArray) -> bool:
	# The caller already checked the signature and bounded dimensions. Reject
	# incomplete framing before libpng emits engine errors for truncated input.
	# This walks only chunk headers inside the existing eight-MiB payload limit;
	# the native decoder still validates CRCs, compressed data and pixel format.
	var offset := 8
	var has_data := false
	while offset<bytes.size():
		var remaining := bytes.size()-offset
		if remaining<12: return false # length, type and CRC must all be present
		var length := (int(bytes[offset])<<24)|(int(bytes[offset+1])<<16) \
			|(int(bytes[offset+2])<<8)|int(bytes[offset+3])
		if length>0x7fffffff or length>remaining-12: return false
		var kind := bytes.slice(offset+4,offset+8).get_string_from_ascii()
		if offset==8:
			if kind!="IHDR" or length!=13: return false
		elif kind=="IHDR": return false
		if kind=="IDAT": has_data=true
		elif kind=="IEND": return has_data and length==0 and offset+12==bytes.size()
		offset+=12+length
	return false

func _decode_record(raw: Variant) -> Dictionary:
	if not raw is Dictionary or _has_secret(raw): return _error("Invalid or credential-bearing attempt record.")
	for key: String in ["config","provenance","metrics","timings","usage"]:
		if not raw.get(key) is Dictionary: return _error("Attempt metadata is missing or malformed: "+key)
	for key: String in ["receipts","accepted_edits","operations"]:
		if not raw.get(key) is Array: return _error("Attempt execution record is malformed: "+key)
	for key: String in ["attempt_id","reason","material_sha256","model_response","render_kind","source_materials_base64","material_cells_base64"]:
		if not raw.get(key) is String: return _error("Attempt text or payload is malformed: "+key)
	var size := _extent(raw.get("result_extent"))
	if size==Vector2i.ZERO or raw.get("state") not in TERMINAL or raw.attempt_id.is_empty() or raw.attempt_id.length()>128:
		return _error("Invalid attempt identity, extent or outcome.")
	var validation := _validate(raw.config)
	if not validation.is_empty() or _extent(raw.config.extent)!=size: return _error("Stored attempt configuration is invalid: "+validation)
	if raw.config.has("source_cells") or raw.config.has("source_cells_base64"): return _error("Attempt source must use its checksummed material plane.")
	if raw.receipts.size()>MAX_CELL_BUDGET or raw.accepted_edits.size()>MAX_CELL_BUDGET or raw.operations.size()>4096:
		return _error("Stored execution history exceeds its bounded work.")
	for receipt: Variant in raw.receipts:
		if not receipt is Dictionary or receipt.get("backend")!="CyberNativeCellWorld" or not receipt.get("before_source") is Dictionary:
			return _error("Stored receipt is not a native acknowledgement.")
		for counter: String in ["checked","changed","confirmed","excluded","refused"]:
			if not Plan.integer(receipt.get(counter)) or int(receipt[counter])<0 or int(receipt[counter])>4096:
				return _error("Stored native receipt has an invalid bounded counter.")
	for edit: Variant in raw.accepted_edits:
		if not edit is Array or edit.size()!=5: return _error("Stored accepted edit is malformed.")
		for number: Variant in edit:
			if not Plan.integer(number): return _error("Stored accepted edit must use integer values.")
		if edit[0]<0 or edit[1]<0 or edit[2]<1 or edit[3]<1 or edit[0]+edit[2]>size.x or edit[1]+edit[3]>size.y or int(edit[4]) not in Setup.MATERIALS:
			return _error("Stored accepted edit is outside the native result or material palette.")
	var value: Dictionary = raw.duplicate(true)
	value["_native_readback_current_process"] = false
	value.config = _canonical_numbers(value.config)
	value.operations = _canonical_numbers(value.operations)
	if JSON.stringify(value.config).sha256_text()!=value.provenance.get("configuration_sha256","") \
		or str(value.config.prompt).sha256_text()!=value.provenance.get("actual_prompt_sha256",""):
		return _error("Stored prompt or configuration differs from its final identity.")
	if value.get("execution_origin") not in EXECUTION_ORIGINS or value.provenance.get("execution_origin")!=value.execution_origin:
		return _error("Stored execution origin is missing or inconsistent.")
	if value.operations!=value.config.operations or JSON.stringify(value.operations).sha256_text()!=value.provenance.get("actual_program_sha256",""):
		return _error("Stored native program differs from its configuration or checksum.")
	for pair: Array in [["source_materials_base64","source_materials"],["material_cells_base64","material_cells"]]:
		var decoded := _base64(value[pair[0]],size.x*size.y*2)
		if not decoded.ok: return decoded
		value[pair[1]] = decoded.bytes
		value.erase(pair[0])
		if not value[pair[1]].is_empty() and value[pair[1]].size()!=size.x*size.y*2: return _error("Stored material plane is truncated.")
	if not value.source_materials.is_empty() and TileHost.digest(value.source_materials)!=str(value.provenance.get("source_material_sha256","")):
		return _error("Stored native source checksum differs.")
	if value.state=="completed" and value.material_cells.is_empty(): return _error("A completed attempt must retain its native readback.")
	if not value.material_cells.is_empty() and value.source_materials.is_empty(): return _error("Native result is missing its original source.")
	if not value.material_cells.is_empty() and TileHost.digest(value.material_cells)!=str(value.get("material_sha256","")):
		return _error("Stored native result checksum differs.")
	if value.material_cells.is_empty() and not value.material_sha256.is_empty(): return _error("An uncaptured result cannot carry a material checksum.")
	if value.has("render_png_base64"):
		var decoded := _base64(value.render_png_base64,8*1024*1024,false)
		if not decoded.ok: return decoded
		var dimensions := _png_dimensions(decoded.bytes)
		if dimensions==Vector2i.ZERO: return _error("Stored render has invalid or oversized PNG dimensions.")
		if TileHost.digest(decoded.bytes)!=value.get("render_png_sha256","") or not value.get("renderer") is Dictionary \
			or value.renderer.get("material_sha256")!=value.material_sha256: return _error("Stored render checksum or source identity differs.")
		if not _png_chunks_complete(decoded.bytes): return _error("Stored render has incomplete or malformed PNG chunks.")
		# Header and chunk framing are allocation/truncation guards. The actual
		# decoder must still accept the image before any session state is replaced.
		var image := Image.new()
		if image.load_png_from_buffer(decoded.bytes)!=OK or image.is_empty() or image.get_size()!=dimensions:
			return _error("Stored render is not a complete valid PNG.")
		value["render_png"] = decoded.bytes
		value.erase("render_png_base64")
	value.provenance["reopened_record"] = true
	value.provenance["reopen_scope"] = "retained evidence; Replay/Undo/Redo performs fresh native reconstruction"
	return {"ok":true,"record":value}

func load_session(path: String) -> Dictionary:
	if is_running(): return _error("Stop and wait before opening another session.")
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>MAX_FILE_BYTES: return _error("Session file is missing or exceeds 192 MiB.")
	var parser := JSON.new()
	if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary: return _error("Session is not valid JSON.")
	var value: Dictionary = parser.data
	if _has_secret(value) or not value.get("provenance") is Dictionary or not Plan.integer(value.get("sequence")) or int(value.sequence)<0:
		return _error("Invalid session metadata or credentials.")
	if value.get("format")!=FORMAT or value.get("kind")!="session" or not value.get("attempts") is Array \
		or value.attempts.size()>MAX_ATTEMPTS or not value.get("tiles") is Array: return _error("Unsupported session format or capacity.")
	if not Plan.integer(value.get("columns")) or not Plan.integer(value.get("rows")) \
		or value.columns<1 or value.columns>4 or value.rows<1 or value.rows>4 or value.tiles.size()!=int(value.columns)*int(value.rows):
		return _error("Invalid session grid.")
	var imported: Array[Dictionary] = []
	var identities := {}
	var imported_bytes := 0
	for raw: Variant in value.attempts:
		var decoded := _decode_record(raw)
		if not decoded.ok: return decoded
		if identities.has(decoded.record.attempt_id): return _error("Duplicate attempt identity.")
		identities[decoded.record.attempt_id] = true
		imported.append(decoded.record)
		imported_bytes += _record_bytes(decoded.record)
	if imported_bytes>MAX_STORED_BYTES: return _error("Stored session exceeds the evidence memory limit.")
	var imported_views: Array[Dictionary] = []
	for view: Variant in value.tiles:
		if not view is Dictionary or not view.get("config") is Dictionary or _has_secret(view): return _error("Invalid tile configuration.")
		var config: Dictionary = view.config.duplicate(true)
		if config.has("source_cells"): return _error("Stored source capture must use its checksummed encoding.")
		if config.has("source_cells_base64"):
			var decoded := _base64(config.source_cells_base64,2048*2048*2,false)
			if not decoded.ok: return decoded
			if TileHost.digest(decoded.bytes)!=config.get("source_cells_sha256",""): return _error("Stored editable source checksum differs.")
			config.source_cells = decoded.bytes
			config.erase("source_cells_base64")
			imported_bytes += decoded.bytes.size()
			var base_error := _validate(config)
			if not base_error.is_empty(): return _error(base_error)
			var source := _source(config)
			if not source.ok: return source
		var error := _validate(config)
		if not error.is_empty(): return _error(error)
		if not view.get("attempt_id","") is String or not view.get("history_attempt","") is String or view.get("history_cursor","result") not in ["result","source"]:
			return _error("Invalid retained tile selection.")
		if not str(view.get("attempt_id","")).is_empty() and not identities.has(view.attempt_id): return _error("Tile refers to missing attempt evidence.")
		if not str(view.get("history_attempt","")).is_empty() and not identities.has(view.history_attempt): return _error("Tile history refers to missing attempt evidence.")
		imported_views.append({"config":_canonical_numbers(config),"attempt_id":str(view.get("attempt_id","")),
			"history_attempt":str(view.get("history_attempt","")),"history_cursor":str(view.get("history_cursor","result"))})
	if imported_bytes>MAX_STORED_BYTES: return _error("Stored source configurations exceed the evidence memory limit.")
	# Commit only after the whole file has validated; a failed import leaves the
	# current grid, native evidence and ordinary Workbench untouched.
	configure_grid(int(value.columns),int(value.rows))
	attempts = imported
	provenance = value.provenance.duplicate(true)
	_stored_bytes = imported_bytes
	_sequence = maxi(int(value.get("sequence",0)),attempts.size())
	for index: int in tiles.size():
		var view: Dictionary = imported_views[index]
		var tile: Dictionary = tiles[index]
		tile.config = view.config.duplicate(true)
		tile["_native_readback_current_process"] = false
		tile.attempt_id = str(view.get("attempt_id",""))
		var record := _find_attempt(tile.attempt_id)
		if not record.is_empty():
			for key: String in ["state","reason","execution_origin","result_extent","source_materials","material_cells","material_sha256","receipts","accepted_edits","metrics","timings","usage","provenance","render_kind"]:
				if record.has(key): tile[key] = record[key].duplicate(true) if record[key] is Dictionary or record[key] is Array else record[key]
			tile["_frozen_config"] = record.config.duplicate(true)
			tile.image = material_image(tile.material_cells,_extent(tile.result_extent))
			if record.has("render_png"):
				var image := Image.new()
				if image.load_png_from_buffer(record.render_png)==OK and image.get_width()<=2048 and image.get_height()<=2048: tile["render_image"] = image
			tile.attempts = [record.attempt_id]
			tile.history_attempt = str(view.get("history_attempt","")) if not str(view.get("history_attempt","")).is_empty() else record.attempt_id
			tile.history_cursor = str(view.get("history_cursor","result"))
	changed.emit()
	return _ok()

func _exit_tree() -> void:
	for work: Dictionary in _active.values():
		if work.has("provider"): work.provider.cancel("Batch Lab closed")
		if work.has("initializing"): work.initializing.wait_to_finish()
		if work.has("host"): work.host.close()
		if work.has("analysis"): work.analysis.wait_to_finish()
	_active.clear()
	_queue.clear()
	_credentials.clear()
