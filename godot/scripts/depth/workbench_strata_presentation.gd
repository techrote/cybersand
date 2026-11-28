extends Control

# A presentation adapter, never a simulation owner. The existing Workbench
# TextureRect, shader updates and actor overlays remain the play drawable.
# Three independently frozen material surfaces supply its rear scenery.
const Surface = preload("res://scripts/depth/depth_layer_surface.gd")
const Transform = preload("res://scripts/depth/depth_compositor.gd")
const Appearance = preload("res://scripts/material_appearance_lut.gd")
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Atmosphere = preload("res://scripts/depth/strata_atmosphere.gd")
const AtmosphereProfiles = preload("res://scripts/depth/strata_atmosphere_profiles.gd")
const OpticalRenderer = preload("res://scripts/depth/strata_optical_renderer.gd")
const OpticalConfiguration = preload("res://scripts/depth/strata_optics_configuration.gd")
const AuthoringProvenance = preload("res://scripts/depth/strata_authoring_provenance.gd")
const IDS: Array[String] = ["play", "scripted", "effects", "background"]
const REAR_IDS: Array[String] = ["background", "effects", "scripted"]
const HAZE_SHADER: String = "shader_type canvas_item; render_mode unshaded; uniform float haze = 0.0; varying vec4 vertex_colour; void vertex() { vertex_colour = COLOR; } void fragment() { vec4 c = texture(TEXTURE, UV); c.rgb = mix(c.rgb, vec3(0.055,0.105,0.15), haze); COLOR = c * vertex_colour; }"
const PLAY_SOURCE_META: StringName = &"strata_play_palette_source"
const GLOW_SOURCE_META: StringName = &"strata_play_glow_source"
const PLAY_OPACITY_UNIFORM: StringName = &"strata_play_opacity"
# One current private program per kind is shared across staged/replaced
# compositions. Existing adapters retain their reference until retirement.
static var _cached_play_source: Shader
static var _cached_play_variant: Shader
static var _cached_glow_source: Shader
static var _cached_glow_variant: Shader

var last_error: String = ""
var extent: Vector2i = Vector2i.ZERO
var host: Control
var _view: TextureRect
var _glow_view: TextureRect
var _clip: Control
var _surfaces: Dictionary = {}
var _drawables: Dictionary = {}
var _atmospheres: Dictionary = {}
var _document: Dictionary = {}
var _expected: Dictionary = {}
var _accepted: Dictionary = {}
var _original_shader: ShaderMaterial
var _private_shader: ShaderMaterial
var _original_glow_shader: ShaderMaterial
var _private_glow_shader: ShaderMaterial
var _prepared_host_id: int = 0
var _prepared_view_id: int = 0
var _prepared_shader: Shader
var _prepared_glow_view_id: int = 0
var _prepared_glow_shader: Shader
var _original_modulate: Color = Color.WHITE
var _overlay_modulates: Dictionary = {}
var _enabled: bool = false
var _prepared: bool = false
var _content := Rect2()
var _origin := Vector2.ZERO
var _view_size := Vector2.ONE
var _rejected_packets: int = 0
var _optics = OpticalRenderer.new()

func prepare(authored_extent: Vector2i) -> bool:
	if _prepared:
		return _accept() if extent == authored_extent else _reject("Prepared Strata surfaces cannot change extent")
	if authored_extent.x < 512 or authored_extent.y < 512 or authored_extent.x > 2048 or authored_extent.y > 2048:
		return _reject("Strata presentation supports 512..2048 cells per axis")
	if authored_extent.x % 64 != 0 or authored_extent.y % 64 != 0:
		return _reject("Strata presentation dimensions must be multiples of 64")
	extent = authored_extent
	name = "WorkbenchStrataPresentation"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	_clip = Control.new()
	_clip.name = "ClippedRearPlanes"
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.clip_contents = true
	add_child(_clip)
	var sky := ColorRect.new()
	sky.name = "Backdrop"
	sky.color = Color(0.018, 0.028, 0.047, 1.0)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip.add_child(sky)
	var haze_shader := Shader.new()
	haze_shader.code = HAZE_SHADER
	for id: String in REAR_IDS:
		var surface := Surface.new()
		if not surface.configure(id, true, extent, extent):
			surface.free()
			return _reject("Could not prepare native material presentation for " + id)
		surface.name = "StrataSurface_" + id
		surface.freeze_material_time(0.0)
		# No decorative surface renders continuously. An admitted dirty packet
		# schedules one bake once the layer is visible.
		surface.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(surface)
		_surfaces[id] = surface
		var drawable := TextureRect.new()
		drawable.name = "StrataPlane_" + id
		drawable.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drawable.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		drawable.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		drawable.stretch_mode = TextureRect.STRETCH_SCALE
		drawable.texture = surface.get_texture()
		drawable.visible = false
		var haze := ShaderMaterial.new()
		haze.shader = haze_shader
		drawable.material = haze
		_clip.add_child(drawable)
		_drawables[id] = drawable
		_optics.register_plane(id, drawable)
		var atmosphere := Atmosphere.new()
		atmosphere.name = "VisualAtmosphere_" + id
		drawable.add_child(atmosphere)
		_atmospheres[id] = atmosphere
	_prepared = true
	visible = false
	return _accept()

func prepare_host(controller_host: Control) -> bool:
	if not _prepared or controller_host == null:
		return _reject("Prepare Strata surfaces before binding the Workbench host")
	if host != null: return _reject("Cannot prepare a mounted presentation host")
	var candidate: Variant = controller_host.get("world_view")
	if not candidate is TextureRect or not candidate.material is ShaderMaterial:
		return _reject("Workbench play drawable is unavailable")
	if controller_host.get("world_shader") != candidate.material or candidate.material.shader == null:
		return _reject("Workbench play shader ownership does not match its drawable")
	var source: Shader = _play_source(candidate.material.shader)
	var variant: Shader = _play_variant(source)
	if source == null or variant == null:
		return _reject("The accepted play palette does not expose the validated Strata opacity seam")
	var glow: Variant = controller_host.get("glow_overlay")
	if not glow is TextureRect or not glow.material is ShaderMaterial \
			or controller_host.get("glow_composite_shader") != glow.material:
		return _reject("Workbench play glow ownership does not match its drawable")
	var glow_source: Shader = _glow_source(glow.material.shader)
	var glow_variant: Shader = _glow_variant(glow_source)
	if glow_source == null or glow_variant == null:
		return _reject("The accepted play glow does not expose the validated Strata opacity seam")
	# Stage the private material and LUT before requesting any play installation.
	# If another Strata adapter is active, resolve its original shader through
	# the validated source metadata; never wrap a private variant a second time.
	# mount() captures the original material object after the previous detach.
	var private: ShaderMaterial = candidate.material.duplicate()
	var private_glow: ShaderMaterial = glow.material.duplicate()
	var transparent: ImageTexture = _transparent_empty_lut()
	if private == null or private_glow == null or transparent == null or transparent.get_width() != Appearance.ATLAS_WIDTH:
		return _reject("Could not prepare the private Strata play palette")
	private.shader = variant
	private.set_shader_parameter("material_lut", transparent)
	private.set_shader_parameter(PLAY_OPACITY_UNIFORM, 1.0)
	private_glow.shader = glow_variant
	private_glow.set_shader_parameter(PLAY_OPACITY_UNIFORM, 1.0)
	_private_shader = private
	_private_glow_shader = private_glow
	_prepared_host_id = controller_host.get_instance_id()
	_prepared_view_id = candidate.get_instance_id()
	_prepared_shader = source
	_prepared_glow_view_id = glow.get_instance_id()
	_prepared_glow_shader = glow_source
	return _accept()

func mount(controller_host: Control) -> bool:
	if not _prepared or controller_host == null or _private_shader == null or _private_glow_shader == null:
		return _reject("Prepare Strata surfaces and host before mounting")
	if host != null:
		return _accept() if host == controller_host else _reject("Strata presentation already has a host")
	var candidate: Variant = controller_host.get("world_view")
	var glow: Variant = controller_host.get("glow_overlay")
	if controller_host.get_instance_id() != _prepared_host_id or not candidate is TextureRect \
			or candidate.get_instance_id() != _prepared_view_id or not candidate.material is ShaderMaterial \
			or candidate.material.shader != _prepared_shader or controller_host.get("world_shader") != candidate.material:
		return _reject("The prepared Workbench presentation owner changed before adoption")
	if not glow is TextureRect or glow.get_instance_id() != _prepared_glow_view_id \
			or not glow.material is ShaderMaterial or glow.material.shader != _prepared_glow_shader \
			or controller_host.get("glow_composite_shader") != glow.material:
		return _reject("The prepared Workbench glow owner changed before adoption")
	host = controller_host
	_view = candidate
	_glow_view = glow
	_original_shader = _view.material
	_original_glow_shader = _glow_view.material
	_original_modulate = _view.self_modulate
	_capture_overlays()
	_view.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.move_child(self, 0)
	sync_view()
	_apply_visibility()
	return _accept()

func apply_document(candidate: Dictionary) -> bool:
	var reason: String = Document.validate(candidate)
	if not reason.is_empty(): return _reject(reason)
	var incoming: Variant = candidate.get("extent", [])
	if not _prepared or not incoming is Array or incoming.size() != 2 \
			or incoming[0] != extent.x or incoming[1] != extent.y:
		return _reject("Strata presentation document extent mismatch")
	if not candidate.get("presentation") is Dictionary or not candidate.get("planes") is Array:
		return _reject("Strata presentation document is incomplete")
	var seen: Array[String] = []
	for plane: Variant in candidate.planes:
		if not plane is Dictionary or str(plane.get("id", "")) not in IDS or str(plane.id) in seen:
			return _reject("Strata presentation plane identity mismatch")
		seen.append(str(plane.id))
	if seen.size() != IDS.size(): return _reject("Strata presentation requires all four planes")
	_document = candidate.duplicate(true)
	for id: String in REAR_IDS:
		if not _atmospheres[id].configure(_document.get("atmosphere", AtmosphereProfiles.default_configuration()), extent, id):
			return _reject(_atmospheres[id].last_error)
	_apply_visibility()
	sync_view()
	return _accept()


func apply_optics(configuration: Dictionary) -> bool:
	# Scene/native admission already validated the geometry. A presentation-only
	# slider validates/copies only its bounded settings, never the plane layouts.
	var reason: String = OpticalConfiguration.validate(configuration)
	if not reason.is_empty(): return _reject(reason)
	if not _prepared or _document.is_empty(): return _reject("Prepare a Strata document before optical changes")
	_document["optics"] = OpticalConfiguration.canonical(configuration)
	_document["version"] = Document.OPTICAL_VERSION
	if not _document.has("atmosphere"): _document["atmosphere"] = AtmosphereProfiles.default_configuration()
	if not _document.has("authoring"): _document["authoring"] = AuthoringProvenance.default_configuration()
	_optics.configure(_document.optics, str(_document.presentation.active), _document.planes, _enabled)
	_apply_optical_atmosphere()
	sync_view()
	return _accept()

func expect_sources(sources: Dictionary) -> bool:
	# Binding is separate from a copied publication: an arbitrary packet cannot
	# appoint itself the owner of a plane, even with a larger serial/generation.
	if sources.size() != REAR_IDS.size(): return _reject("Expected exactly three decorative owner identities")
	var generation: int = -1
	for id: String in REAR_IDS:
		if not sources.get(id) is Dictionary: return _reject("Missing decorative owner identity: " + id)
		var identity: Dictionary = sources[id]
		if identity.size() != 3 or not identity.has_all(["owner_id", "reset_generation", "revision"]):
			return _reject("Unsupported decorative owner identity fields")
		if not identity.owner_id is String or identity.owner_id.is_empty() or identity.owner_id.length() > 128:
			return _reject("Decorative owner ID must be a nonempty bounded string")
		for field: String in ["reset_generation", "revision"]:
			if typeof(identity.get(field)) != TYPE_INT or int(identity[field]) < 1:
				return _reject("Decorative identity must have positive integer " + field)
		if generation >= 0 and generation != int(identity.reset_generation):
			return _reject("Decorative owners belong to different composition generations")
		generation = int(identity.reset_generation)
		var previous: Dictionary = _accepted.get(id, {})
		if not previous.is_empty():
			if generation < int(previous.reset_generation): return _reject("Cannot bind a retired decorative generation")
			if generation == int(previous.reset_generation) and (identity.owner_id != previous.owner_id or int(identity.revision) < int(previous.revision)):
				return _reject("Cannot replace an owner or retreat its revision within one generation")
	_expected = sources.duplicate(true)
	return _accept()

func apply_layer_packet(id: String, packet: Dictionary) -> bool:
	if not _surfaces.has(id) or not _expected.has(id): return _packet_reject("Unbound decorative presentation owner")
	if not packet.get("layer_id") is String or packet.layer_id != id: return _packet_reject("Decorative packet plane mismatch")
	if not packet.get("owner_id") is String or typeof(packet.get("reset_generation")) != TYPE_INT \
			or typeof(packet.get("revision")) != TYPE_INT:
		return _packet_reject("Decorative packet identity types are invalid")
	if typeof(packet.get("channels")) != TYPE_INT or packet.channels != 2 \
			or typeof(packet.get("layer_tick")) != TYPE_INT or packet.layer_tick != 0:
		return _packet_reject("Static decorative publication requires RG8 and native tick zero")
	if packet.has("failed") and (typeof(packet.failed) != TYPE_BOOL or packet.failed):
		return _packet_reject("Decorative publication is failed or has an invalid failure state")
	if packet.has("generation") and (typeof(packet.generation) != TYPE_INT or packet.generation != packet.reset_generation):
		return _packet_reject("Decorative publication generation identities disagree")
	var expected: Dictionary = _expected[id]
	for field: String in ["owner_id", "reset_generation", "revision"]:
		if packet.get(field) != expected.get(field): return _packet_reject("Decorative packet " + field + " does not match admitted owner")
	var packet_extent: Variant = packet.get("extent")
	if packet_extent is Array:
		if packet_extent.size() != 2 or typeof(packet_extent[0]) != TYPE_INT or typeof(packet_extent[1]) != TYPE_INT \
				or packet_extent[0] != extent.x or packet_extent[1] != extent.y:
			return _packet_reject("Decorative packet extent mismatch")
	elif not packet_extent is Vector2i or packet_extent != extent:
		return _packet_reject("Decorative packet extent mismatch")
	# This static owner publishes complete bounded planes, including Empty. A
	# truncated or empty publication cannot advance the visible revision witness.
	if typeof(packet.get("full_refresh")) != TYPE_BOOL or not packet.full_refresh \
			or not packet.get("cells") is PackedByteArray or packet.cells.size() != extent.x * extent.y * 2:
		return _packet_reject("Static decorative publication requires a complete material plane")
	var previous: Dictionary = _accepted.get(id, {})
	if not previous.is_empty() and packet.get("reset_generation") == previous.get("reset_generation"):
		if typeof(packet.get("serial")) != TYPE_INT or int(packet.serial) <= int(previous.serial):
			return _packet_reject("Decorative packet serial did not advance")
	var surface: CyberDepthLayerSurface = _surfaces[id]
	if not surface.apply_packet(packet): return _packet_reject(surface.last_rejection)
	_accepted[id] = {"owner_id":packet.owner_id, "reset_generation":packet.reset_generation,
		"revision":packet.revision, "serial":packet.serial, "extent":[extent.x, extent.y]}
	surface.render_target_update_mode = SubViewport.UPDATE_ONCE if _enabled and effective_visible(id) else SubViewport.UPDATE_DISABLED
	return _accept()

func sync_view() -> void:
	if not is_instance_valid(host) or not is_instance_valid(_view): return
	# The ordinary renderer floors its camera. Use precisely the accepted view;
	# no smoothing, independent clock or alternative pan/zoom state is introduced.
	_origin = Vector2(host.get("camera_origin")).floor()
	_view_size = Vector2(host.get("current_view_size"))
	_content = host.call("view_content_rect")
	if not _content.has_area() or _view_size.x <= 0.0 or _view_size.y <= 0.0: return
	_clip.position = _content.position
	_clip.size = _content.size
	for id: String in REAR_IDS:
		var drawable: TextureRect = _drawables[id]
		drawable.position = _logical_for_layer(Vector2.ZERO, id) / _view_size * _content.size
		drawable.size = Vector2(extent) / _view_size * _content.size
		_atmospheres[id].scale = drawable.size / Vector2(extent)
	var actor_bounds: Array[Rect2] = []
	if _optics.actor_reveal_active(): actor_bounds = _presented_actor_bounds()
	_optics.sync_view(extent, _origin, _view_size,
		float(_document.get("presentation", {}).get("parallax_strength", 0.75)), _private_shader, actor_bounds)


func _presented_actor_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for property: String in ["physical_actor_overlay", "actor_prototype_overlay"]:
		var overlay: Variant = host.get(property)
		if not is_instance_valid(overlay) or not overlay.visible or not overlay.has_method("presentation_bounds"): continue
		bounds.append_array(overlay.presentation_bounds(8-bounds.size()))
		if bounds.size() >= 8: break
	return bounds

func screen_to_layer(local_position: Vector2, id: String) -> Vector2:
	# Input may follow a pan/zoom/resize in the same event batch, before our
	# process callback. Read the existing accepted host view at the edit boundary.
	sync_view()
	if id not in IDS or not local_position.is_finite() or not _content.has_area() or not _content.has_point(local_position): return Vector2(-1, -1)
	var logical: Vector2 = (local_position - _content.position) / _content.size * _view_size
	var depth: float = 0.0 if id == "play" else float(_plane(id).get("depth", 0.0))
	var strength: float = float(_document.get("presentation", {}).get("parallax_strength", 0.75)) * _optics.parallax_scale(id)
	return Transform.logical_to_layer(logical, Vector2(extent), _view_size, _origin, 1.0, 1.0 - depth, strength)

func layer_to_screen(point: Vector2, id: String) -> Vector2:
	sync_view()
	if id not in IDS or not point.is_finite() or not _content.has_area(): return Vector2(-1, -1)
	return _content.position + _logical_for_layer(point, id) / _view_size * _content.size

func effective_visible(id: String) -> bool:
	if id not in IDS: return false
	var presentation: Dictionary = _document.get("presentation", {})
	if not bool(presentation.get("enabled", false)): return id == "play"
	var plane: Dictionary = _plane(id)
	if not bool(plane.get("visible", true)) or float(plane.get("opacity", 1.0)) <= 0.0: return false
	var solo: String = str(presentation.get("solo", ""))
	if not solo.is_empty() and solo != id: return false
	return str(presentation.get("mode", "stack")) != "flat" or str(presentation.get("active", "play")) == id

func diagnostics() -> Dictionary:
	var layers := {}
	var uploads: int = 0
	var bytes: int = 0
	for id: String in REAR_IDS:
		var info: Dictionary = _surfaces[id].diagnostics() if _surfaces.has(id) else {}
		info["identity"] = _accepted.get(id, {}).duplicate(true)
		info["expected"] = _expected.get(id, {}).duplicate(true)
		info["effective_visible"] = effective_visible(id)
		info["atmosphere"] = _atmospheres[id].diagnostics()
		layers[id] = info
		uploads += int(info.get("upload_count", 0))
		bytes += int(info.get("uploaded_bytes", 0))
	return {"prepared":_prepared, "enabled":_enabled, "extent":extent, "camera_origin":_origin,
		"view_size":_view_size, "content_rect":_content, "play_effective_visible":effective_visible("play"),
		"layers":layers, "full_rg8_uploads":uploads, "full_rg8_uploaded_bytes":bytes,
		"rejected_packets":_rejected_packets, "last_error":last_error,
		"additional_native_play_worlds":0, "additional_play_texture_uploads":0,
		"decorative_surface_count":_surfaces.size(), "decorative_rg8_capacity_bytes":extent.x * extent.y * 2 * _surfaces.size(),
		"decorative_rgba_capacity_bytes":extent.x * extent.y * 4 * _surfaces.size(),
		"play_texture_instance_id":_view.texture.get_instance_id() if is_instance_valid(_view) and _view.texture != null else 0,
		"original_shader_instance_id":_original_shader.get_instance_id() if _original_shader != null else 0,
		"active_shader_instance_id":_view.material.get_instance_id() if is_instance_valid(_view) and _view.material != null else 0,
		"play_shader_source_sha256":_prepared_shader.code.sha256_text() if _prepared_shader != null else "",
		"play_shader_variant_sha256":_private_shader.shader.code.sha256_text() if _private_shader != null else "",
		"play_shader_variant_bound":_private_shader != null and _private_shader.shader.code == _play_variant_code(_prepared_shader),
		"play_glow_source_sha256":_prepared_glow_shader.code.sha256_text() if _prepared_glow_shader != null else "",
		"play_glow_variant_sha256":_private_glow_shader.shader.code.sha256_text() if _private_glow_shader != null else "",
		"play_glow_variant_bound":_private_glow_shader != null and _private_glow_shader.shader.code == _glow_variant_code(_prepared_glow_shader),
		"optics":_optics.statistics(),
		"play_overlay_instance_ids":_overlay_modulates.keys()}

func detach() -> void:
	for atmosphere: Node2D in _atmospheres.values(): atmosphere.set_plane_active(false)
	_optics.restore()
	_set_enabled(false)
	if is_instance_valid(_view):
		_view.self_modulate = _original_modulate
	_restore_overlays()
	if get_parent() != null: get_parent().remove_child(self)
	host = null
	_view = null
	_glow_view = null

func _apply_visibility() -> void:
	_set_enabled(bool(_document.get("presentation", {}).get("enabled", false)))
	if not is_instance_valid(_view): return
	_capture_overlays()
	var play_opacity: float = float(_plane("play").get("opacity", 1.0)) if _enabled and effective_visible("play") else (0.0 if _enabled else 1.0)
	_private_shader.set_shader_parameter(PLAY_OPACITY_UNIFORM, play_opacity)
	_private_glow_shader.set_shader_parameter(PLAY_OPACITY_UNIFORM, play_opacity)
	_view.self_modulate = _original_modulate * Color(1.0, 1.0, 1.0, play_opacity)
	for key: Variant in _overlay_modulates:
		var entry: Dictionary = _overlay_modulates[key]
		if is_instance_valid(entry.node): entry.node.modulate = entry.colour * Color(1.0, 1.0, 1.0, play_opacity)
	for id: String in REAR_IDS:
		var drawable: TextureRect = _drawables[id]
		var was_visible: bool = drawable.visible
		drawable.visible = _enabled and effective_visible(id)
		_atmospheres[id].set_plane_active(drawable.visible)
		var plane: Dictionary = _plane(id)
		drawable.modulate = Color(1.0, 1.0, 1.0, float(plane.get("opacity", 1.0)))
		var fog: float = float(_document.get("presentation", {}).get("fog_strength", 0.2))
		_optics.set_classic_haze(id, clampf(fog * float(plane.get("depth", 0.0)), 0.0, 0.9))
		if not drawable.visible:
			_surfaces[id].render_target_update_mode = SubViewport.UPDATE_DISABLED
		elif not was_visible and _accepted.has(id):
			_surfaces[id].render_target_update_mode = SubViewport.UPDATE_ONCE
	_optics.configure(_document.get("optics", {}), str(_document.get("presentation", {}).get("active", "play")),
		_document.get("planes", []), _enabled)
	_apply_optical_atmosphere()


func _apply_optical_atmosphere() -> void:
	# Three existing nodes only, on authored/inspection updates. No recurring
	# callback, redraw source capture, material change or atmosphere recompile.
	for id: String in REAR_IDS:
		var colour := Color(1.0,1.0,1.0,_optics.atmosphere_opacity(id))
		if _atmospheres[id].self_modulate != colour: _atmospheres[id].self_modulate = colour


func set_optics_inspection(patch: Dictionary) -> bool:
	if not _optics.set_inspection(patch): return _reject("Unsupported optical inspection settings")
	_apply_optical_atmosphere()
	sync_view()
	return _accept()


func set_optics_quality(value: String) -> bool:
	if not _optics.set_quality(value): return _reject("Optics quality must be low, balanced or high")
	sync_view()
	return _accept()


func optics_statistics() -> Dictionary:
	return _optics.statistics()


func advance_optics(delta: float) -> void:
	# Called by the existing enabled Strata callback; no independent clock.
	_optics.advance(delta)

func _set_enabled(value: bool) -> void:
	if not is_instance_valid(_view):
		visible = false
		return
	if value == _enabled:
		visible = value
		return
	if value:
		# The host continues updating the same alias it already owns. Only the
		# private LUT makes Empty reveal the rear planes; final fragment opacity
		# is applied after all material/actor finishes in the private program.
		for uniform: Dictionary in _original_shader.shader.get_shader_uniform_list():
			if str(uniform.name) != "material_lut":
				_private_shader.set_shader_parameter(uniform.name, _original_shader.get_shader_parameter(uniform.name))
		_view.material = _private_shader
		host.set("world_shader", _private_shader)
		for uniform: Dictionary in _original_glow_shader.shader.get_shader_uniform_list():
			_private_glow_shader.set_shader_parameter(uniform.name, _original_glow_shader.get_shader_parameter(uniform.name))
		_glow_view.material = _private_glow_shader
		host.set("glow_composite_shader", _private_glow_shader)
	else:
		# Keep the live frame's textures, interpolation, sampled actors and view
		# when returning to flat inspection. Restore the exact material object.
		if _view.material == _private_shader:
			for uniform: Dictionary in _original_shader.shader.get_shader_uniform_list():
				if str(uniform.name) != "material_lut":
					_original_shader.set_shader_parameter(uniform.name, _private_shader.get_shader_parameter(uniform.name))
			_view.material = _original_shader
			if host.get("world_shader") == _private_shader: host.set("world_shader", _original_shader)
		if is_instance_valid(_glow_view) and _glow_view.material == _private_glow_shader:
			for uniform: Dictionary in _original_glow_shader.shader.get_shader_uniform_list():
				_original_glow_shader.set_shader_parameter(uniform.name, _private_glow_shader.get_shader_parameter(uniform.name))
			_glow_view.material = _original_glow_shader
			if host.get("glow_composite_shader") == _private_glow_shader: host.set("glow_composite_shader", _original_glow_shader)
		_view.self_modulate = _original_modulate
		_restore_overlays()
		for surface: CyberDepthLayerSurface in _surfaces.values():
			surface.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_enabled = value
	visible = value
	if not value:
		for atmosphere: Node2D in _atmospheres.values(): atmosphere.set_plane_active(false)


func reset_atmosphere_phase() -> void:
	for atmosphere: Node2D in _atmospheres.values(): atmosphere.reset_phase()

func _capture_overlays() -> void:
	if not is_instance_valid(_view): return
	for child: Node in _view.get_children():
		if child == self or not child is CanvasItem or bool(child.get_meta("strata_independent_overlay", false)): continue
		var key: int = child.get_instance_id()
		if not _overlay_modulates.has(key): _overlay_modulates[key] = {"node":child, "colour":child.modulate}

func _restore_overlays() -> void:
	for key: Variant in _overlay_modulates:
		var entry: Dictionary = _overlay_modulates[key]
		if is_instance_valid(entry.node): entry.node.modulate = entry.colour

func _logical_for_layer(point: Vector2, id: String) -> Vector2:
	var depth: float = 0.0 if id == "play" else float(_plane(id).get("depth", 0.0))
	var strength: float = float(_document.get("presentation", {}).get("parallax_strength", 0.75)) * _optics.parallax_scale(id)
	return Transform.layer_to_logical(point, Vector2(extent), _view_size, _origin, 1.0, 1.0 - depth, strength)

func _plane(id: String) -> Dictionary:
	for plane: Dictionary in _document.get("planes", []):
		if str(plane.get("id", "")) == id: return plane
	return {}

func _transparent_empty_lut() -> ImageTexture:
	var image: Image = Appearance.create_texture().get_image()
	for x: int in range(Appearance.ATLAS_WIDTH):
		var colour: Color = image.get_pixel(x, 0)
		colour.a = 0.0
		image.set_pixel(x, 0, colour)
	return ImageTexture.create_from_image(image)

static func _play_variant_code(source: Shader) -> String:
	return _opacity_variant_code(source, "COLOR = colour;", "COLOR = vec4(colour.rgb, colour.a * strata_play_opacity);")

static func _glow_variant_code(source: Shader) -> String:
	# Additive glow contributes RGB independently of material alpha. Scale its
	# final contribution, retaining the ordinary glow strength and enable owner.
	return _opacity_variant_code(source, "COLOR = vec4((glow + centre * 0.18) * glow_strength, 1.0);",
		"COLOR = vec4((glow + centre * 0.18) * glow_strength * strata_play_opacity, 1.0);")

static func _opacity_variant_code(source: Shader, output: String, replacement: String) -> String:
	if source == null: return ""
	var code: String = source.code
	# This adapter deliberately refuses an unknown future palette seam instead
	# of editing a global shader or guessing where its final colour is produced.
	if code.count("shader_type canvas_item;") != 1 or code.count(output) != 1 \
			or code.contains(String(PLAY_OPACITY_UNIFORM)):
		return ""
	return code.replace("shader_type canvas_item;", "shader_type canvas_item;\nuniform float strata_play_opacity : hint_range(0.0, 1.0) = 1.0;").replace(
		output, replacement)

static func _play_source(palette: Shader) -> Shader:
	if palette == null: return null
	if not palette.has_meta(PLAY_SOURCE_META): return palette
	var source: Variant = palette.get_meta(PLAY_SOURCE_META)
	if not source is Shader or source == palette or palette.code != _play_variant_code(source): return null
	return source

static func _play_variant(source: Shader) -> Shader:
	var code: String = _play_variant_code(source)
	if code.is_empty(): return null
	if _cached_play_source != source or _cached_play_variant == null or _cached_play_variant.code != code:
		_cached_play_source = source
		_cached_play_variant = Shader.new()
		_cached_play_variant.code = code
		_cached_play_variant.set_meta(PLAY_SOURCE_META, source)
	return _cached_play_variant

static func _glow_source(palette: Shader) -> Shader:
	if palette == null: return null
	if not palette.has_meta(GLOW_SOURCE_META): return palette
	var source: Variant = palette.get_meta(GLOW_SOURCE_META)
	if not source is Shader or source == palette or palette.code != _glow_variant_code(source): return null
	return source

static func _glow_variant(source: Shader) -> Shader:
	var code: String = _glow_variant_code(source)
	if code.is_empty(): return null
	if _cached_glow_source != source or _cached_glow_variant == null or _cached_glow_variant.code != code:
		_cached_glow_source = source
		_cached_glow_variant = Shader.new()
		_cached_glow_variant.code = code
		_cached_glow_variant.set_meta(GLOW_SOURCE_META, source)
	return _cached_glow_variant

func _accept() -> bool:
	last_error = ""
	return true

func _reject(error: String) -> bool:
	last_error = error
	return false

func _packet_reject(error: String) -> bool:
	_rejected_packets += 1
	return _reject(error)

func _exit_tree() -> void:
	_optics.restore()
	_set_enabled(false)
