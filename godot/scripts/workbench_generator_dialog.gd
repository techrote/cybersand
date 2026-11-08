extends ConfirmationDialog

# EXPLORE-001: finite, copied GEN-007 preview in the ordinary workbench.
# Only the accepted play plane is installed. Neither this dialog nor its
# generator ever calls or stores the live native simulation World.
const Store = preload("res://scripts/workbench_generated_map.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Palette = preload("res://scripts/material_appearance_lut.gd")
const PREVIEW_CELLS_PER_FRAME := 8192
const PLANE_CELLS_PER_TURN := 2048
const PROFILE_MAX_BYTES := 1024 * 1024

var _workbench: Control
var _profile := OptionButton.new()
var _seed := SpinBox.new()
var _x := SpinBox.new()
var _y := SpinBox.new()
var _extent := OptionButton.new()
var _preview_button := Button.new()
var _browse := FileDialog.new()
var _status := Label.new()
var _composition := Label.new()
var _preview := TextureRect.new()
var _generator: Variant = null
var _phase := "idle"
var _recipe: Dictionary = {}
var _configuration: Dictionary = {}
var _origin := Vector2i.ZERO
var _size := Vector2i(1024, 1024)
var _region := Rect2i()
var _cells := PackedByteArray()
var _pixels := PackedByteArray()
var _render_at := 0
var _chunks: Array[Vector2i] = []
var _next_chunk := 0
var _receipts: Array = []
var _material_counts: Dictionary = {}
var _start_usec := 0
var _ready_packet: Dictionary = {}
var _saved_generation: Dictionary = {}
var _saved_setup: Dictionary = {}
var _saved_recipe: Dictionary = {}

func _field(row: HBoxContainer, text: String, field: Control) -> void:
	var label := Label.new()
	label.text = text
	row.add_child(label)
	row.add_child(field)

func _row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row

func mount(workbench: Control) -> void:
	_workbench = workbench
	title = "GEN-007 · New playable starting map"
	ok_button_text = "Install into workbench"
	cancel_button_text = "Keep current map"
	get_ok_button().disabled = true
	exclusive = true
	# Godot 4.7 ConfirmationDialog has no get_vbox() API. Direct Control
	# children are arranged by AcceptDialog's wrap-controls layout.
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "GeneratedMapControls"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)
	var warning := Label.new()
	warning.text = "Preview uses the native generator. Install replaces the current map; save existing edits first."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(warning)
	var row := _row(root)
	_field(row, "Profile", _profile)
	_profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile.item_selected.connect(func(_i: int) -> void:
		_saved_recipe.clear()
		_saved_generation.clear()
		_saved_setup.clear()
		_invalidate())
	_preview_button.text = "Generate preview"
	row.add_child(_preview_button)
	_preview_button.pressed.connect(_start)
	var directory: String = ProjectSettings.globalize_path("res://../examples/worldgen")
	var names := DirAccess.get_files_at(directory)
	names.sort()
	for filename: String in names:
		if not filename.ends_with(".json"): continue
		_profile.add_item(filename.trim_suffix(".json"))
		_profile.set_item_metadata(_profile.item_count - 1, directory.path_join(filename))
	if _profile.item_count > 0:
		for i: int in _profile.item_count:
			if _profile.get_item_text(i) == "gen007-deepworks":
				_profile.select(i)
				break
	row = _row(root)
	for setting: Array in [["Seed", _seed, 0, 2147483647, 19301],
			["World X", _x, -1000000, 1000000, 0],
			["World Y", _y, -1000000, 1000000, 0]]:
		var knob: SpinBox = setting[1]
		knob.min_value = setting[2]
		knob.max_value = setting[3]
		knob.rounded = true
		knob.value = setting[4]
		knob.custom_minimum_size.x = 100
		knob.value_changed.connect(func(_value: float) -> void: _invalidate())
		_field(row, setting[0], knob)
	_field(row, "Size", _extent)
	for side: int in [512, 1024, 2048]:
		_extent.add_item("%d × %d" % [side, side], side)
	_extent.select(1)
	_extent.item_selected.connect(func(_i: int) -> void: _invalidate())
	row = _row(root)
	var choose := Button.new()
	choose.text = "Choose profile file…"
	row.add_child(choose)
	choose.pressed.connect(func() -> void: _browse.popup_centered(Vector2i(840,600)))
	_browse.access = FileDialog.ACCESS_FILESYSTEM
	_browse.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_browse.add_filter("*.json", "GEN-007 recipe JSON")
	_browse.file_selected.connect(func(path: String) -> void:
		_saved_recipe.clear()
		_saved_generation.clear()
		_saved_setup.clear()
		_profile.add_item(path.get_file())
		_profile.set_item_metadata(_profile.item_count - 1, path)
		_profile.select(_profile.item_count - 1)
		_invalidate())
	add_child(_browse)
	_status.text = "Select a recipe, seed and finite region. No installed World is changed until confirmation."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	_composition.text = "Native material composition will appear after complete generation."
	_composition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_composition)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(540,290)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(_preview)
	confirmed.connect(_install)
	canceled.connect(_stop)
	# AcceptDialog may hide before emitting confirmed. Keep the verified
	# proposal alive across that transition; cancel only unfinished generation.
	visibility_changed.connect(func() -> void:
		if not visible and _phase in ["plane","chunks","render"]: _stop())

func open_new() -> void:
	if _workbench == null: return
	_saved_generation.clear()
	_saved_setup.clear()
	_saved_recipe.clear()
	_invalidate()
	title = "GEN-007 · New playable starting map"
	popup_centered(Vector2i(720,610))

func open_saved(starting_setup: Dictionary, generation: Dictionary) -> void:
	var reason := Store.valid_provenance(generation, Setup.extent_of(starting_setup))
	if not reason.is_empty():
		_workbench.refuse(reason)
		return
	_saved_generation = generation.duplicate(true)
	_saved_setup = starting_setup.duplicate(true)
	_saved_recipe = generation.recipe.duplicate(true)
	_seed.set_value_no_signal(int(_saved_recipe.get("seed",0)))
	_x.set_value_no_signal(int(generation.origin[0]))
	_y.set_value_no_signal(int(generation.origin[1]))
	var side := int(generation.extent[0])
	for i: int in _extent.item_count:
		if _extent.get_item_id(i) == side: _extent.select(i)
	_invalidate()
	title = "GEN-007 · Verify and reopen saved starting map"
	popup_centered(Vector2i(720,610))
	_start()

func _stop() -> void:
	if _generator != null:
		if _phase == "plane":
			_generator.cancel_plane_region()
	_generator = null
	_phase = "idle"
	_cells = PackedByteArray()
	_pixels = PackedByteArray()
	_chunks.clear()
	_next_chunk = 0
	_receipts.clear()
	_ready_packet.clear()
	get_ok_button().disabled = true

func _invalidate() -> void:
	_stop()
	_preview.texture = null
	_composition.text = "No accepted material proposal."
	_status.text = "Generate a complete native preview before replacing the current map."

func _fail(reason: String) -> void:
	_stop()
	_status.text = "Refused · " + reason
	_composition.text = "No installable material proposal."

func _start() -> void:
	_stop()
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		_fail("Source-matched native GEN-007 runtime is unavailable.")
		return
	if not _saved_recipe.is_empty():
		_recipe = _saved_recipe.duplicate(true)
	else:
		if _profile.selected < 0:
			_fail("Choose a JSON generation profile.")
			return
		var path := str(_profile.get_item_metadata(_profile.selected))
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_fail("Cannot open the selected generation profile.")
			return
		if file.get_length() > PROFILE_MAX_BYTES:
			_fail("Generator recipe exceeds the bounded 1 MiB profile limit.")
			return
		var parse := JSON.new()
		if parse.parse(file.get_as_text()) != OK or not parse.data is Dictionary:
			_fail("Invalid generation recipe JSON.")
			return
		_recipe = parse.data
		_recipe["seed"] = int(_seed.value)
	_size = Vector2i(_extent.get_selected_id(), _extent.get_selected_id())
	_origin = Vector2i(int(_x.value), int(_y.value))
	_region = Rect2i(_origin, _size)
	if _size.x not in [512,1024,2048] or _origin.x > 1000000-_size.x or _origin.y > 1000000-_size.y:
		_fail("Selected finite region exceeds source coordinate limits.")
		return
	_configuration.clear()
	_generator = ClassDB.instantiate(&"CyberWorldGenerator")
	_start_usec = Time.get_ticks_usec()
	_configuration = _generator.configure(_recipe)
	if not _configuration.get("ok",false):
		_fail(str(_configuration.get("error","Native generator refused the recipe.")))
		return
	if _cells.resize(_size.x * _size.y) != OK:
		_fail("Cannot allocate the bounded native preview buffer.")
		return
	if _configuration.has("plane_fingerprint"):
		var plan: Dictionary = _generator.get_plane_plan()
		if not plan.get("ok",false) or not plan.get("bounds",Rect2i()).encloses(_region):
			_fail("Semantic-plan bounds do not enclose the selected region; select a contained region.")
			return
		_phase = "plane"
		var begun: Dictionary = _generator.begin_plane_region(_region)
		_plane_result(begun)
	else:
		var step: int = int(_recipe.get("chunk_size",64))
		if step <= 0 or step > 256:
			_fail("Invalid source chunk size.")
			return
		for cy: int in range(floori(float(_origin.y)/step),floori(float(_region.end.y-1)/step)+1):
			for cx: int in range(floori(float(_origin.x)/step),floori(float(_region.end.x-1)/step)+1):
				_chunks.append(Vector2i(cx,cy))
		_phase = "chunks"
		_status.text = "Native generation: 0 / %d complete source chunks." % _chunks.size()
	get_ok_button().disabled = true

func _plane_result(packet: Dictionary) -> void:
	if _phase != "plane": return
	if not packet.get("ok",false):
		_fail(str(packet.get("error","Native semantic-plane generation failed.")))
		return
	if packet.get("state","") == "running":
		_status.text = "Native play-plane proposal · %s / %d cells" % [
			str(packet.get("completed_cells",0)), _size.x*_size.y]
		return
	if packet.get("state","") != "ready" or packet.get("bounds",Rect2i()) != _region or \
			int(packet.get("adapter_serial",-1)) != int(_configuration.revision) or \
			str(packet.get("revision","")) != str(_configuration.plane_fingerprint) or \
			int(packet.get("completed_cells",-1)) != _size.x*_size.y:
		_fail("Stale or incomplete native semantic-plane result.")
		return
	var materials: Variant = packet.get("materials",{})
	var hashes: Variant = packet.get("hashes",{})
	if not materials is Dictionary or not hashes is Dictionary or \
			not materials.get("play") is PackedByteArray or \
			materials["play"].size() != _cells.size() or \
			not Store._hex(hashes.get("play",""),16) or \
			not Store._hex(packet.get("receipt_hash",""),16):
		_fail("Incomplete play-plane output or missing source hash.")
		return
	_cells = materials["play"]
	_receipts = [str(packet.receipt_hash)]
	_begin_render()

func _chunk_result(coord: Vector2i, packet: Dictionary) -> bool:
	var step: int = int(_recipe.get("chunk_size",64))
	if not packet.get("ok",false) or packet.get("state","") != "ready" or \
			int(packet.get("chunk_x",999999)) != coord.x or \
			int(packet.get("chunk_y",999999)) != coord.y or \
			int(packet.get("chunk_size",-1)) != step or \
			int(packet.get("revision",-1)) != int(_configuration.revision) or \
			str(packet.get("fingerprint","")) != str(_configuration.fingerprint) or \
			int(packet.get("completed_cells",-1)) != step*step or \
			not packet.get("cells") is PackedByteArray or packet.cells.size() != step*step or \
			not Store._hex(packet.get("hash",""),16) or \
			not Store._hex(packet.get("receipt_hash",""),16):
		_fail("Stale, invalid or incomplete native chunk at " + str(coord))
		return false
	var source: PackedByteArray = packet.cells
	for ly: int in step:
		var gy := coord.y*step + ly
		if gy < _origin.y or gy >= _region.end.y: continue
		for lx: int in step:
			var gx := coord.x*step + lx
			if gx < _origin.x or gx >= _region.end.x: continue
			_cells[(gy-_origin.y)*_size.x + gx-_origin.x] = source[ly*step+lx]
	_receipts.append(str(packet.receipt_hash))
	return true

func _begin_render() -> void:
	_phase = "render"
	if _pixels.resize(_cells.size()*4) != OK:
		_fail("Cannot allocate the requested material-colour preview.")
		return
	_render_at = 0
	_material_counts.clear()
	_status.text = "Native terrain complete; preparing preview colours…"

func _process(_delta: float) -> void:
	if not visible or _generator == null: return
	match _phase:
		"plane":
			_plane_result(_generator.advance_plane_region(PLANE_CELLS_PER_TURN))
		"chunks":
			if _next_chunk < _chunks.size():
				var coord: Vector2i = _chunks[_next_chunk]
				if not _chunk_result(coord,_generator.generate_chunk(coord)): return
				_next_chunk += 1
				_status.text = "Native terrain: %d / %d chunks" % [_next_chunk,_chunks.size()]
			if _next_chunk == _chunks.size(): _begin_render()
		"render":
			var last: int = mini(_render_at + PREVIEW_CELLS_PER_FRAME, _cells.size())
			for i: int in range(_render_at,last):
				var id: int = int(_cells[i])
				if id == 10 or id >= Palette.MATERIAL_COUNT:
					_fail("Generator supplied a reserved/invalid material ID.")
					return
				var rgba: int = int(Palette.BASE_RGBA8[id])
				_pixels[i*4] = (rgba >> 24) & 255
				_pixels[i*4+1] = (rgba >> 16) & 255
				_pixels[i*4+2] = (rgba >> 8) & 255
				_pixels[i*4+3] = 255
				_material_counts[id] = int(_material_counts.get(id,0)) + 1
			_render_at = last
			if _render_at == _cells.size(): _complete()
			else: _status.text = "Colour preview: %d / %d cells" % [_render_at,_cells.size()]

func _complete() -> void:
	var digest: String = Store.digest(_cells)
	if digest.is_empty():
		_fail("Cannot hash the native material buffer.")
		return
	var img: Image = Image.create_from_data(_size.x,_size.y,false,Image.FORMAT_RGBA8,_pixels)
	_preview.texture = ImageTexture.create_from_image(img)
	_ready_packet = {"recipe":_recipe.duplicate(true),"origin":_origin,"extent":_size,
		"cells":_cells,"sha256":digest,"recipe_sha256":Store.recipe_hash(_recipe),
		"generator_fingerprint":str(_configuration.fingerprint),
		"plane_revision":str(_configuration.get("plane_fingerprint","")),
		"generator_revision":int(_configuration.revision),"receipt_hashes":_receipts.duplicate(true)}
	if not _saved_generation.is_empty():
		var saved: Dictionary = _saved_generation
		var fresh: Dictionary = Store.provenance(_ready_packet)
		for key: String in saved:
			if saved[key] != fresh.get(key):
				_fail("Saved source identity mismatch at %s; existing map preserved." % key)
				return
	var ranked: Array = _material_counts.keys()
	ranked.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(_material_counts[a]) > int(_material_counts[b]))
	var top: Array[String] = []
	for i: int in mini(ranked.size(),7):
		top.append("ID %d: %d" % [int(ranked[i]),int(_material_counts[ranked[i]])])
	_composition.text = "%d distinct material IDs · %s · final PLAY plane only" % [
		ranked.size(),", ".join(top)]
	var nonempty: int = _cells.size() - int(_material_counts.get(0,0))
	_phase = "ready"
	_status.text = "Verified native proposal · %dx%d · %d nonempty cells · %d source receipts · %.2fs to preview. Install replaces unsaved work." % [
		_size.x,_size.y,nonempty,_receipts.size(),(Time.get_ticks_usec()-_start_usec)/1000000.0]
	get_ok_button().disabled = false

# Source-session fence: a caller cannot relabel the dialog's native proposal
# with a different fingerprint, revision, region or arbitrarily edited bytes.
func attests(packet: Dictionary) -> bool:
	if _phase != "ready" or _ready_packet.is_empty() or packet.size() != _ready_packet.size():
		return false
	for key: String in _ready_packet:
		if packet.get(key) != _ready_packet[key]: return false
	return Store.digest(packet.cells) == _ready_packet.sha256 and \
		int(_configuration.get("revision",-1)) == int(packet.generator_revision) and \
		str(_configuration.get("fingerprint","")) == str(packet.generator_fingerprint) and \
		str(_configuration.get("plane_fingerprint","")) == str(packet.plane_revision)

func _install() -> void:
	if _phase != "ready" or _ready_packet.is_empty() or _workbench == null:
		return
	var candidate: Dictionary
	if _saved_setup.is_empty():
		if _workbench._liquids == null or _workbench._liquids.bridge == null:
			_workbench.refuse("Native liquid policy interface unavailable.")
			return
		candidate = Setup.fresh(_workbench._liquids.bridge.default_liquid_policy(),_size)
	else:
		candidate = _saved_setup.duplicate(true)
	if not _workbench.install_generated_start(candidate,_ready_packet):
		_status.text = _workbench.message
		popup_centered(Vector2i(720,610))
	else:
		# The owner already made a source-qualified copy for its pending commit.
		_stop()
