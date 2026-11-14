extends ConfirmationDialog

# EXPLORE-001: finite, copied GEN-007 preview in the ordinary workbench.
# Only the accepted play plane is installed. Neither this dialog nor its
# generator ever calls or stores the live native simulation World.
const Store = preload("res://scripts/workbench_generated_map.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Palette = preload("res://scripts/material_appearance_lut.gd")
const ArchitecturalProject = preload("res://scripts/architectural_generator_project.gd")
const ArchitecturalDialog = preload("res://scripts/architectural_generator_dialog.gd")
const PREVIEW_CELLS_PER_FRAME := 8192
const PLANE_CELLS_PER_TURN := 2048
const PROFILE_MAX_BYTES := 1024 * 1024
const PACKAGED_PROFILES := "res://authoring/worldgen"
const CHECKOUT_PROFILES := "res://../examples/worldgen"
const ARCHITECTURAL_PROFILE := "architectural-project://active"
const ZONE_COLOURS := [Color(0.95,0.61,0.25,0.25), Color(0.25,0.68,0.98,0.25), Color(0.45,0.88,0.43,0.25)]
const ZONE_COLOUR_NAMES := ["Orange", "Blue", "Green"]

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
var _profile_error := ""
var _architecture_button := Button.new()
var _architecture := ArchitecturalDialog.new()
var _architecture_project: Dictionary = {}
var _architecture_result: Dictionary = {}
var _architecture_active := false
var _zone_diagnostics := Label.new()
var _zone_toggle := CheckButton.new()
var _zone_overlay := TextureRect.new()
var _restore_button := Button.new()
# One immutable accepted proposal can be recovered explicitly after a refused
# or cancelled replacement. A dirty form cannot silently install old bytes.
var _accepted_proposal: Dictionary = {}
var _attempt_serial := 0

func _reload_profiles() -> void:
	_profile.clear()
	var seen := {}
	# Packages carry canonical recipes inside the project. Source checkouts
	# use examples/worldgen. Neither path depends on the launch cwd.
	for directory: String in [PACKAGED_PROFILES, ProjectSettings.globalize_path(CHECKOUT_PROFILES)]:
		if not DirAccess.dir_exists_absolute(directory): continue
		var names := DirAccess.get_files_at(directory)
		names.sort()
		for filename: String in names:
			if not filename.ends_with(".json") or seen.has(filename): continue
			var path := directory.path_join(filename)
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null: continue
			seen[filename] = true
			_profile.add_item(filename.trim_suffix(".json"))
			_profile.set_item_metadata(_profile.item_count - 1, path)
	_profile_error = ""
	if _profile.item_count == 0:
		_profile_error = "No readable GEN-007 profiles found. Reinstall the complete Workbench package with godot/authoring/worldgen, or use Choose profile file… Searched: %s; %s" % [ProjectSettings.globalize_path(PACKAGED_PROFILES), ProjectSettings.globalize_path(CHECKOUT_PROFILES)]
	else:
		for i: int in _profile.item_count:
			if _profile.get_item_text(i) == "gen007-deepworks":
				_profile.select(i)
				break
	_preview_button.disabled = _profile.item_count == 0

func _select_profile_file(path: String) -> void:
	_architecture_active = false
	_saved_recipe.clear()
	_saved_generation.clear()
	_saved_setup.clear()
	_profile.add_item(path.get_file())
	_profile.set_item_metadata(_profile.item_count - 1, path)
	_profile.select(_profile.item_count - 1)
	_profile_error = ""
	_preview_button.disabled = false
	_invalidate()

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
	# Bound content independently of AcceptDialog's action buttons. In Godot
	# 4.7, unlaid-out autowrapped labels can inflate the first popup minimum.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "GeneratedMapControls"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)
	var warning := Label.new()
	warning.text = "Preview uses the native generator. Install replaces the current map; save existing edits first."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(warning)
	var row := _row(root)
	_field(row, "Profile", _profile)
	_profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile.item_selected.connect(func(_i: int) -> void:
		_architecture_active = str(_profile.get_item_metadata(_profile.selected)) == ARCHITECTURAL_PROFILE
		_saved_recipe.clear()
		_saved_generation.clear()
		_saved_setup.clear()
		_invalidate())
	_preview_button.text = "Generate preview"
	row.add_child(_preview_button)
	_preview_button.pressed.connect(_start)
	_reload_profiles()
	row = _row(root)
	for setting: Array in [["Seed", _seed, 0, 9007199254740991, 19301],
			["World X", _x, -1000000, 1000000, 0],
			["World Y", _y, -1000000, 1000000, 0]]:
		var knob: SpinBox = setting[1]
		knob.min_value = setting[2]
		knob.max_value = setting[3]
		knob.rounded = true
		if knob == _seed:
			knob.step = 0
			knob.rounded = false
			knob.custom_arrow_step = 1.0
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
	_architecture_button.text = "Architectural Generator…"
	row.add_child(_architecture_button)
	_architecture_button.pressed.connect(_open_architecture)
	add_child(_architecture)
	_architecture.mount()
	_architecture.project_compiled.connect(func(result: Dictionary) -> void: start_architectural(result.project))
	var choose := Button.new()
	choose.text = "Choose profile file…"
	row.add_child(choose)
	choose.pressed.connect(func() -> void: _browse.popup_centered(Vector2i(840,600)))
	_browse.access = FileDialog.ACCESS_FILESYSTEM
	_browse.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_browse.add_filter("*.json", "GEN-007 recipe JSON")
	_browse.file_selected.connect(_select_profile_file)
	add_child(_browse)
	row = _row(root)
	var stop_button := Button.new()
	stop_button.text = "Stop preview"
	stop_button.pressed.connect(_cancel_preview)
	row.add_child(stop_button)
	_restore_button.text = "Restore previous preview"
	_restore_button.disabled = true
	_restore_button.pressed.connect(restore_previous_preview)
	row.add_child(_restore_button)
	_zone_toggle.text = "Show style-zone overlay"
	_zone_toggle.visible = false
	_zone_toggle.toggled.connect(func(value: bool) -> void: _zone_overlay.visible = value and _zone_overlay.texture != null)
	row.add_child(_zone_toggle)
	_status.text = _profile_error if not _profile_error.is_empty() else "Select a recipe, seed and finite region. No installed World is changed until confirmation."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	_composition.text = "Native material composition will appear after complete generation."
	_composition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_composition)
	_zone_diagnostics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zone_diagnostics.visible = false
	root.add_child(_zone_diagnostics)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(540,290)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(_preview)
	_zone_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zone_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_zone_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_zone_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(_zone_overlay)
	_zone_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zone_overlay.visible = false
	confirmed.connect(_install)
	canceled.connect(_cancel_preview)
	# AcceptDialog may hide before emitting confirmed. Keep the verified
	# proposal alive across that transition; cancel only unfinished generation.
	visibility_changed.connect(func() -> void:
		if not visible and _phase in ["plane","chunks","render"]: _cancel_preview())
	get_tree().root.size_changed.connect(func() -> void:
		if visible: _fit_available_bounds())

func _available_bounds() -> Rect2i:
	if is_embedded():
		return Rect2i(Vector2i.ZERO,Vector2i(get_tree().root.get_visible_rect().size))
	return DisplayServer.screen_get_usable_rect(get_tree().root.current_screen)

func _fit_available_bounds() -> void:
	var bounds := _available_bounds()
	# Leave room for native window decorations and desktop chrome. Content
	# scrolls; OK/Cancel remain outside the scroll container.
	max_size = Vector2i(maxi(1,bounds.size.x-32),maxi(1,bounds.size.y-64))
	if visible:
		size = size.min(max_size)
		position = position.clamp(bounds.position,bounds.end-size)

func _popup_bounded() -> void:
	_fit_available_bounds()
	popup_centered_clamped(Vector2i(720,610),0.9)

func open_new() -> void:
	if _workbench == null: return
	_saved_generation.clear()
	_saved_setup.clear()
	_saved_recipe.clear()
	_invalidate()
	title = "GEN-007 · New playable starting map"
	_popup_bounded()

func open_saved(starting_setup: Dictionary, generation: Dictionary) -> void:
	var reason := Store.valid_provenance(generation, Setup.extent_of(starting_setup))
	if not reason.is_empty():
		_workbench.refuse(reason)
		return
	_saved_generation = generation.duplicate(true)
	_saved_setup = starting_setup.duplicate(true)
	_saved_recipe = generation.recipe.duplicate(true)
	_architecture_active = false
	_seed.set_value_no_signal(int(_saved_recipe.get("seed",0)))
	_x.set_value_no_signal(int(generation.origin[0]))
	_y.set_value_no_signal(int(generation.origin[1]))
	var side := int(generation.extent[0])
	for i: int in _extent.item_count:
		if _extent.get_item_id(i) == side: _extent.select(i)
	_invalidate()
	title = "GEN-007 · Verify and reopen saved starting map"
	_popup_bounded()
	_start()

func _stop() -> void:
	_attempt_serial += 1
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
	_restore_button.disabled = _accepted_proposal.is_empty()

func _invalidate() -> void:
	_stop()
	_preview.texture = null
	_composition.text = "No accepted material proposal."
	_zone_overlay.texture = null
	_zone_overlay.visible = false
	_zone_toggle.visible = false
	_zone_diagnostics.visible = false
	_status.text = _profile_error if not _profile_error.is_empty() and _saved_recipe.is_empty() else "Generate a complete native preview before replacing the current map."
	_preview_button.disabled = _profile.selected < 0 and _saved_recipe.is_empty()

func _fail(reason: String) -> void:
	_stop()
	_preview.texture = null
	_zone_overlay.texture = null
	_zone_overlay.visible = false
	_zone_toggle.visible = false
	_zone_diagnostics.visible = false
	_status.text = "Refused · " + reason
	_composition.text = "No installable material proposal."
	if not _accepted_proposal.is_empty():
		_status.text += " Previous verified preview is retained; Restore previous preview restores its settings."

func _cancel_preview() -> void:
	if _phase == "ready": return
	_stop()
	_status.text = "Preview cancelled. The installed World is unchanged."
	if not _accepted_proposal.is_empty():
		_status.text += " Restore previous preview recovers its verified bytes and settings."

func _open_architecture() -> void:
	var value: Dictionary = _architecture_project.duplicate(true) if not _architecture_project.is_empty() else ArchitecturalProject.default_project()
	if _architecture_active:
		value.seed = _seed.value
		if _seed.value == floor(_seed.value): value.seed = int(_seed.value)
		value.origin = [int(_x.value), int(_y.value)]
		value.extent = [_extent.get_selected_id(), _extent.get_selected_id()]
	_architecture.open_project(value)

func start_architectural(project: Dictionary) -> bool:
	var result: Dictionary = ArchitecturalProject.compile(project)
	if not result.get("ok", false):
		_fail(str(result.get("error", "Invalid architectural project.")))
		return false
	if int(result.project.extent[0]) not in [512, 1024]:
		_fail("Shared Workbench architectural previews support 512 or 1024 cells per side.")
		return false
	_architecture_project = result.project.duplicate(true)
	_architecture_result = result
	_architecture_active = true
	_saved_generation.clear()
	_saved_setup.clear()
	_saved_recipe.clear()
	var index := -1
	for i: int in _profile.item_count:
		if str(_profile.get_item_metadata(i)) == ARCHITECTURAL_PROFILE: index = i
	if index < 0:
		_profile.add_item("Architectural project")
		index = _profile.item_count - 1
		_profile.set_item_metadata(index, ARCHITECTURAL_PROFILE)
	_profile.select(index)
	_seed.set_value_no_signal(int(project.seed))
	_x.set_value_no_signal(int(project.origin[0]))
	_y.set_value_no_signal(int(project.origin[1]))
	for i: int in _extent.item_count:
		if _extent.get_item_id(i) == int(project.extent[0]): _extent.select(i)
	_preview_button.disabled = false
	title = "GEN-007 · Architectural starting map"
	if not visible: _popup_bounded()
	_start()
	return _phase in ["chunks", "plane", "render", "ready"]

func _capture_accepted() -> void:
	_accepted_proposal = {"packet": _ready_packet.duplicate(true), "configuration": _configuration.duplicate(true),
		"generator": _generator, "recipe": _recipe.duplicate(true), "origin": _origin, "size": _size,
		"region": _region, "pixels": _pixels, "counts": _material_counts.duplicate(true),
		"texture": _preview.texture, "composition": _composition.text, "status": _status.text,
		"profile": _profile.selected, "seed": _seed.value, "x": _x.value, "y": _y.value,
		"extent_index": _extent.selected, "saved_generation": _saved_generation.duplicate(true),
		"saved_setup": _saved_setup.duplicate(true), "saved_recipe": _saved_recipe.duplicate(true),
		"architecture_project": _architecture_project.duplicate(true), "architecture_result": _architecture_result.duplicate(true),
		"architecture_active": _architecture_active}
	_restore_button.disabled = false

func restore_previous_preview() -> bool:
	if _accepted_proposal.is_empty(): return false
	_stop()
	var saved: Dictionary = _accepted_proposal
	_ready_packet = saved.packet.duplicate(true)
	_configuration = saved.configuration.duplicate(true)
	_generator = saved.generator
	_recipe = saved.recipe.duplicate(true)
	_origin = saved.origin
	_size = saved.size
	_region = saved.region
	_cells = _ready_packet.cells
	_pixels = saved.pixels
	_material_counts = saved.counts.duplicate(true)
	_preview.texture = saved.texture
	_composition.text = saved.composition
	_status.text = "Restored previous verified preview and its settings. " + str(saved.status)
	_profile.select(int(saved.profile))
	_seed.set_value_no_signal(saved.seed)
	_x.set_value_no_signal(saved.x)
	_y.set_value_no_signal(saved.y)
	_extent.select(int(saved.extent_index))
	_saved_generation = saved.saved_generation.duplicate(true)
	_saved_setup = saved.saved_setup.duplicate(true)
	_saved_recipe = saved.saved_recipe.duplicate(true)
	_architecture_project = saved.architecture_project.duplicate(true)
	_architecture_result = saved.architecture_result.duplicate(true)
	_architecture_active = saved.architecture_active
	_phase = "ready"
	_show_zone_diagnostics()
	get_ok_button().disabled = false
	return true

func _show_zone_diagnostics() -> void:
	_zone_toggle.visible = _architecture_active
	_zone_diagnostics.visible = _architecture_active
	_zone_overlay.texture = null
	_zone_overlay.visible = false
	if not _architecture_active or _architecture_result.is_empty(): return
	var lines: Array[String] = []
	for entry: Dictionary in _architecture_result.coverage:
		lines.append("%s · %s: target %.2f%% → assigned %.2f%% · %d blocks · %d component(s)" % [
			ZONE_COLOUR_NAMES[int(entry.slot)], str(entry.name), float(entry.requested_percent), float(entry.achieved_percent), int(entry.blocks), int(entry.components)])
	_zone_diagnostics.text = "Style-zone area (including empty space)\n" + "\n".join(lines)
	var zones: Dictionary = _architecture_result.zones
	var width := int(zones.width)
	var height := int(zones.height)
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			var slot := int(zones.cells[y*width+x])
			img.set_pixel(x, y, ZONE_COLOURS[slot % ZONE_COLOURS.size()])
	_zone_overlay.texture = ImageTexture.create_from_image(img)
	_zone_overlay.visible = _zone_toggle.button_pressed

func _semantic_conflict(configuration: Dictionary) -> String:
	var report: Dictionary = configuration.get("route_validation", {})
	if report.is_empty(): return ""
	if not report.get("passed", false):
		for route: Dictionary in report.get("routes", []):
			if route.get("passed", false): continue
			return "Required semantic route '%s' is blocked at (%d, %d): %s. Remove the conflicting override or adjust the explicit route/socket geometry." % [
				str(route.get("id", "unknown")), int(route.get("first_block_x", 0)), int(route.get("first_block_y", 0)), str(route.get("detail", "clearance validation failed"))]
		return "Required semantic routes failed native clearance validation; adjust their explicit openings or conflicting material overrides."
	if not report.get("supports_passed", true):
		for support: Dictionary in report.get("supports", []):
			if support.get("passed", false): continue
			return "Required semantic support for '%s' failed at (%d, %d): %s. Restore the specified support or adjust its constraint." % [
				str(support.get("feature_id", "unknown")), int(support.get("first_missing_x", 0)), int(support.get("first_missing_y", 0)), str(support.get("detail", "support validation failed"))]
		return "Required semantic supports failed native validation."
	return ""

func _start() -> void:
	_stop()
	_preview.texture = null
	_zone_overlay.texture = null
	_zone_overlay.visible = false
	_zone_toggle.visible = false
	_zone_diagnostics.visible = false
	_composition.text = "Preparing a new native material proposal."
	if _seed.value != floor(_seed.value):
		_fail("Seed must be an exact nonnegative integer.")
		return
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		_fail("Source-matched native GEN-007 runtime is unavailable.")
		return
	if not _saved_recipe.is_empty():
		_recipe = _saved_recipe.duplicate(true)
	elif _architecture_active:
		var project: Dictionary = _architecture_project.duplicate(true)
		project.seed = int(_seed.value)
		project.origin = [int(_x.value), int(_y.value)]
		project.extent = [_extent.get_selected_id(), _extent.get_selected_id()]
		var result: Dictionary = ArchitecturalProject.compile(project)
		if not result.get("ok", false):
			_fail(str(result.get("error", "Invalid architectural project.")))
			return
		_architecture_project = result.project.duplicate(true)
		_architecture_result = result
		_recipe = result.recipe.duplicate(true)
	else:
		if _profile.selected < 0:
			_fail(_profile_error if not _profile_error.is_empty() else "Choose a JSON generation profile with Choose profile file…")
			return
		var path := str(_profile.get_item_metadata(_profile.selected))
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_fail("Cannot read profile %s (error %d). Reinstall the complete package or use Choose profile file…" % [path, FileAccess.get_open_error()])
			return
		if file.get_length() > PROFILE_MAX_BYTES:
			_fail("Generator recipe exceeds the bounded 1 MiB profile limit.")
			return
		var parse := JSON.new()
		if parse.parse(file.get_as_text()) != OK or not parse.data is Dictionary:
			_fail("Invalid generation recipe JSON in %s. Choose a valid GEN-007 profile." % path)
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
	# Schema 4 explicitly opts into architectural aperture controls. Required
	# semantic passages and supports remain authoritative even with automatic
	# carving disabled. Legacy recipe admission semantics are unchanged.
	if int(_recipe.get("schema", 1)) >= 4:
		var conflict := _semantic_conflict(_configuration)
		if not conflict.is_empty():
			_fail(conflict)
			return
	# Compute the exact chunk-grid footprint (including unaligned origins)
	# before preview allocation and expensive native generation.
	var first_chunk := Vector2i.ZERO
	var last_chunk := Vector2i.ZERO
	if not _configuration.has("plane_fingerprint"):
		var step: int = int(_recipe.get("chunk_size",64))
		if step <= 0 or step > 256:
			_fail("Invalid source chunk size.")
			return
		first_chunk = Vector2i(floori(float(_origin.x)/step),floori(float(_origin.y)/step))
		last_chunk = Vector2i(floori(float(_region.end.x-1)/step),floori(float(_region.end.y-1)/step))
		var count: int = (last_chunk.x-first_chunk.x+1)*(last_chunk.y-first_chunk.y+1)
		if count > Store.MAX_GENERATION_RECEIPTS:
			_fail("Source region requires %d native chunk receipts; saved-map limit is %d. Increase chunk size or reduce the region." % [
				count,Store.MAX_GENERATION_RECEIPTS])
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
		_plane_result(begun, _attempt_serial)
	else:
		for cy: int in range(first_chunk.y,last_chunk.y+1):
			for cx: int in range(first_chunk.x,last_chunk.x+1):
				_chunks.append(Vector2i(cx,cy))
		_phase = "chunks"
		_status.text = "Native generation: 0 / %d complete source chunks." % _chunks.size()
	get_ok_button().disabled = true

func _plane_result(packet: Dictionary, attempt_serial: int = -1) -> void:
	if attempt_serial >= 0 and attempt_serial != _attempt_serial: return
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

func _chunk_result(coord: Vector2i, packet: Dictionary, attempt_serial: int = -1) -> bool:
	if attempt_serial >= 0 and attempt_serial != _attempt_serial: return false
	if _phase != "chunks": return false
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
			var attempt := _attempt_serial
			_plane_result(_generator.advance_plane_region(PLANE_CELLS_PER_TURN), attempt)
		"chunks":
			if _next_chunk < _chunks.size():
				var coord: Vector2i = _chunks[_next_chunk]
				var attempt := _attempt_serial
				if not _chunk_result(coord,_generator.generate_chunk(coord),attempt): return
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
	_show_zone_diagnostics()
	_capture_accepted()

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
		_popup_bounded()
	else:
		# The owner already made a source-qualified copy for its pending commit.
		_accepted_proposal.clear()
		_stop()
