extends RefCounted

## GPU-only treatment of the existing rear material surfaces. This object owns
## three lazy ShaderMaterials and no World, SubViewport, texture or clock.
const OPTICAL_SHADER = preload("res://shaders/strata_optical_plane.gdshader")
const REAR_IDS := ["background", "effects", "scripted"]
const IDS := ["play", "scripted", "effects", "background"]

var settings: Dictionary = {}
var quality := "balanced"
var inspection := {"bypass":false, "clarity":false, "wipe":1.0, "focus_override":""}
var _classic: Dictionary = {}
var _materials: Dictionary = {}
var _uniforms: Dictionary = {}
var _drawables: Dictionary = {}
var _planes: Dictionary = {}
var _active_plane := "play"
var _strata_enabled := false
var _focus := 0.0
var _target_focus := 0.0
var _focus_initialized := false
var _configuration_count := 0
var _uniform_writes := 0
var _focus_updates := 0


func register_plane(id: String, drawable: TextureRect) -> void:
	assert(id in REAR_IDS and drawable != null and drawable.material is ShaderMaterial)
	_drawables[id] = drawable
	_classic[id] = drawable.material


func set_classic_haze(id: String, value: float) -> void:
	if not _classic.has(id): return
	_classic[id].set_shader_parameter("haze", value)
	if _materials.has(id): _uniform(id, "classic_haze", value)


func configure(value: Dictionary, selected_plane: String, planes: Array, enabled: bool) -> void:
	settings = value.duplicate(true)
	_active_plane = selected_plane
	_strata_enabled = enabled
	_planes.clear()
	# Optical sliders must never duplicate or traverse authored rectangle arrays.
	# The renderer needs only the already validated geometric parallax depth.
	for plane: Dictionary in planes: _planes[str(plane.id)] = {"depth":float(plane.get("depth", 0.0))}
	_target_focus = _resolve_focus()
	if not _focus_initialized or float(settings.get("transition_speed", 0.0)) <= 0.0 or not active():
		_focus = _target_focus
		_focus_initialized = true
	_configuration_count += 1
	_apply()


func set_inspection(patch: Dictionary) -> bool:
	var candidate := inspection.duplicate(true)
	for key: Variant in patch:
		if key not in candidate: return false
		candidate[key] = patch[key]
	if not candidate.bypass is bool or not candidate.clarity is bool \
			or typeof(candidate.wipe) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(candidate.wipe)) \
			or float(candidate.wipe) < 0.0 or float(candidate.wipe) > 1.0 \
			or not candidate.focus_override is String or candidate.focus_override not in IDS + [""]:
		return false
	inspection = candidate
	_target_focus = _resolve_focus()
	if float(settings.get("transition_speed", 0.0)) <= 0.0: _focus = _target_focus
	_apply()
	return true


func set_quality(value: String) -> bool:
	if value not in ["low", "balanced", "high"]: return false
	quality = value
	_apply()
	return true


func advance(delta: float) -> void:
	if not active() or not is_finite(delta) or delta <= 0.0 or is_equal_approx(_focus, _target_focus): return
	var speed := float(settings.get("transition_speed", 0.0))
	if speed <= 0.0: _focus = _target_focus
	else: _focus = lerpf(_focus, _target_focus, 1.0 - exp(-speed * minf(delta, 0.1)))
	if absf(_focus - _target_focus) < 0.0001: _focus = _target_focus
	_focus_updates += 1
	_apply()


func sync_view(extent: Vector2i, origin: Vector2, view_size: Vector2,
		parallax_strength: float, play_material: ShaderMaterial) -> void:
	if not active() or not _needs_play_mask(): return
	var texture: Variant = play_material.get_shader_parameter("current_world_texture") if play_material != null else null
	var player_rect := Vector4(-4096.0, -4096.0, 0.0, 0.0)
	if play_material != null and (bool(inspection.clarity) or float(settings.get("clarity", 0.0)) > 0.0):
		var player_origin: Variant = play_material.get_shader_parameter("player_origin_px")
		var player_size: Variant = play_material.get_shader_parameter("player_size_px")
		if player_origin is Vector2 and player_size is Vector2:
			player_rect = Vector4(player_origin.x, player_origin.y, player_size.x, player_size.y)
	var camera_delta := origin + view_size * 0.5 - Vector2(extent) * 0.5
	for id: String in REAR_IDS:
		if not _using_optics(id): continue
		var depth := float(_planes.get(id, {}).get("depth", 0.0))
		_uniform(id, "play_offset", camera_delta * depth * parallax_strength * parallax_scale(id))
		_uniform(id, "play_mask_available", texture is Texture2D)
		if texture is Texture2D: _uniform(id, "play_cells", texture)
		_uniform(id, "player_rectangle", player_rect)


func parallax_scale(id: String) -> float:
	# A wipe compares the optical treatment at one shared geometric transform.
	# Otherwise one half would not be the exact Classic source coordinates.
	if id == "play" or not _using_optics(id) or float(inspection.wipe) < 1.0: return 1.0
	return lerpf(1.0, float(_plane_optics(id).get("parallax", 1.0)), float(settings.get("strength", 1.0)))


func active() -> bool:
	return _strata_enabled and not bool(inspection.bypass) and float(inspection.wipe) > 0.0 \
		and ((bool(settings.get("enabled", false)) and float(settings.get("strength", 0.0)) > 0.0) or bool(inspection.clarity))


func transitioning() -> bool:
	return active() and not is_equal_approx(_focus, _target_focus)


func statistics() -> Dictionary:
	var active_planes := []
	var radii := {}
	for id: String in REAR_IDS:
		if _using_optics(id): active_planes.append(id)
		radii[id] = _defocus_radius(id)
	return {"active":active(), "quality":quality, "profile":str(settings.get("profile", "classic")),
		"focus_distance":_focus, "target_focus":_target_focus, "transitioning":transitioning(),
		"inspection":inspection.duplicate(true), "active_planes":active_planes,
		"defocus_cells":radii, "material_count":_materials.size(), "uniform_writes":_uniform_writes,
		"configuration_updates":_configuration_count, "focus_updates":_focus_updates,
		"additional_worlds":0, "additional_viewports":0, "additional_textures":0,
		"native_captures":0, "native_writes":0, "texture_uploads":0,
		"play_processed":false, "wipe_uses_classic_parallax":float(inspection.wipe) < 1.0,
		"shader_sha256":OPTICAL_SHADER.code.sha256_text(),
		"alpha_contract":"Frozen SubViewport premultiplied RGBA; bounded weighted premultiplied filtering; premultiplied output. Classic retains its original material."}


func restore() -> void:
	for id: String in _drawables:
		if is_instance_valid(_drawables[id]): _drawables[id].material = _classic[id]
	_strata_enabled = false


func _resolve_focus() -> float:
	var mode := str(settings.get("focus_mode", "play"))
	var selected := "play"
	if not str(inspection.focus_override).is_empty(): selected = str(inspection.focus_override)
	elif mode == "manual": return float(settings.get("focus_distance", 0.0))
	elif mode == "plane": selected = str(settings.get("focal_plane", "play"))
	elif mode == "authoring": selected = _active_plane
	return float(_plane_optics(selected).get("depth", 0.0))


func _plane_optics(id: String) -> Dictionary:
	return settings.get("planes", {}).get(id, {})


func _effect(name: String) -> bool:
	return bool(settings.get("effects", {}).get(name, true))


func _needs_play_mask() -> bool:
	return (_effect("shadows") and float(settings.get("shadow", 0.0)) > 0.0) \
		or bool(inspection.clarity) or float(settings.get("clarity", 0.0)) > 0.0


func _using_optics(id: String) -> bool:
	return id in REAR_IDS and active() and bool(_plane_optics(id).get("participates", true))


func _defocus_radius(id: String) -> float:
	if not _using_optics(id) or not _effect("defocus"): return 0.0
	var plane := _plane_optics(id)
	var distance := maxf(0.0, absf(float(plane.get("depth", 0.0)) - _focus) - float(settings.get("dof_width", 0.25)) * 0.5)
	return clampf(distance * float(settings.get("defocus", 0.0)) * float(plane.get("defocus", 1.0)) * 3.0, 0.0, 1.0 if quality == "low" else 6.0)


func _apply() -> void:
	for id: String in REAR_IDS:
		if not _drawables.has(id): continue
		if not _using_optics(id):
			_drawables[id].material = _classic[id]
			continue
		if not _materials.has(id):
			var material := ShaderMaterial.new()
			material.shader = OPTICAL_SHADER
			_materials[id] = material
			_uniforms[id] = {}
		_drawables[id].material = _materials[id]
		_uniform(id, "surface_texture", _drawables[id].texture)
		_uniform(id, "surface_size", _drawables[id].texture.get_size())
		if not _needs_play_mask(): _uniform(id, "play_mask_available", false)
		var plane := _plane_optics(id)
		var depth := maxf(0.0, float(plane.get("depth", 0.0)) - float(_plane_optics("play").get("depth", 0.0)))
		var tonal := float(settings.get("tonal", 0.0)) if _effect("tonal") else 0.0
		var chromatic := float(settings.get("chromatic", 0.0)) if _effect("chromatic") else 0.0
		var density := float(settings.get("atmosphere", 0.0)) * float(plane.get("atmosphere", 1.0)) * depth if _effect("atmosphere") else 0.0
		var clarity := 1.0 if bool(inspection.clarity) else float(settings.get("clarity", 0.0))
		var colour: Array = settings.get("scattering_color", [0.055, 0.105, 0.15])
		var tint: Array = plane.get("tint", [1.0, 1.0, 1.0])
		var offset: Array = settings.get("shadow_offset", [5.0, 8.0])
		_uniform(id, "effect_strength", 1.0 if bool(inspection.clarity) else float(settings.get("strength", 1.0)))
		_uniform(id, "comparison_wipe", float(inspection.wipe))
		_uniform(id, "quality_tier", ["low", "balanced", "high"].find(quality))
		_uniform(id, "classic_haze", float(_classic[id].get_shader_parameter("haze")))
		_uniform(id, "lens_method", ["pixel", "diffusion", "detail"].find(str(settings.get("defocus_method", "pixel"))))
		_uniform(id, "defocus_radius", _defocus_radius(id))
		_uniform(id, "detail_suppression", clampf(float(settings.get("detail", 0.0)) * depth, 0.0, 0.85) if _effect("detail") else 0.0)
		_uniform(id, "plane_contrast", float(plane.get("contrast", 1.0)) * (1.0 - minf(depth * tonal * 0.38, 0.65)) if _effect("tonal") else 1.0)
		_uniform(id, "black_lift", minf(depth * tonal * 0.065, 0.18))
		_uniform(id, "highlight_compression", depth * tonal * 0.65)
		_uniform(id, "plane_brightness", float(plane.get("brightness", 1.0)) if _effect("tonal") else 1.0)
		_uniform(id, "plane_saturation", float(plane.get("saturation", 1.0)) * (1.0 - minf(depth * chromatic * 0.4, 0.8)) if _effect("chromatic") else 1.0)
		_uniform(id, "plane_tint", Vector3.ONE.lerp(Vector3(float(tint[0]), float(tint[1]), float(tint[2])), chromatic))
		_uniform(id, "atmospheric_density", density)
		_uniform(id, "scattering_colour", Vector3(float(colour[0]), float(colour[1]), float(colour[2])))
		_uniform(id, "illumination_strength", float(settings.get("illumination", 0.0)) * float(plane.get("glow", 1.0)) if _effect("illumination") else 0.0)
		_uniform(id, "shadow_strength", float(settings.get("shadow", 0.0)) * minf(depth * 1.8, 1.0) if _effect("shadows") else 0.0)
		_uniform(id, "shadow_offset", Vector2(float(offset[0]), float(offset[1])) * maxf(depth, 0.05))
		_uniform(id, "shadow_softness", float(settings.get("shadow_softness", 0.0)) * (0.5 + depth))
		_uniform(id, "clarity_strength", clarity)
		_uniform(id, "plane_opacity", float(plane.get("opacity", 1.0)))


func _uniform(id: String, name: String, value: Variant) -> void:
	if not _materials.has(id): return
	var previous: Dictionary = _uniforms[id]
	if previous.has(name) and previous[name] == value: return
	_materials[id].set_shader_parameter(name, value)
	previous[name] = value
	_uniform_writes += 1
