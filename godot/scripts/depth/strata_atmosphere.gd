extends Node2D

## Bounded native-coordinate CanvasItem motifs. No World, native material,
## texture publication, actor, collider or physics tick is created here.
const Profiles = preload("res://scripts/depth/strata_atmosphere_profiles.gd")
const MAX_STEP_SECONDS := 0.1

var last_error := ""
var _configuration: Dictionary = {}
var _extent := Vector2i.ZERO
var _plane := ""
var _effects: Array[Dictionary] = []
var _motifs: Dictionary = {}
var _active := false
var _phase := 0.0
var _advance_calls := 0
var _draw_calls := 0
var _draw_primitives := 0
var _clamped_seconds := 0.0
var _configuration_digest := ""


func _init() -> void:
	set_process(false)
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure(configuration: Dictionary, extent: Vector2i, plane: String) -> bool:
	var reason: String = Profiles.validate(configuration, extent)
	if not reason.is_empty() or plane not in Profiles.PLANES:
		last_error = reason if not reason.is_empty() else "Atmosphere cannot target the physical Play plane."
		return false
	var canonical: Dictionary = Profiles.canonical(configuration)
	var digest: String = JSON.stringify(canonical, "", true, true).sha256_text()
	if digest == _configuration_digest and _extent == extent and _plane == plane:
		last_error = ""
		return true
	_configuration = canonical
	_configuration_digest = digest
	_extent = extent
	_plane = plane
	_effects.clear()
	_motifs.clear()
	for effect: Dictionary in _configuration.effects:
		if effect.plane != _plane: continue
		_effects.append(effect)
		var random := RandomNumberGenerator.new()
		random.seed = int(_configuration.seed) * 1000003 + int(effect.seed)
		var particles: Array[Vector4] = []
		for index: int in int(effect.count):
			particles.append(Vector4(random.randf(), random.randf(), random.randf(), random.randf()))
		_motifs[effect.id] = particles
	_update_processing()
	queue_redraw()
	last_error = ""
	return true


func set_plane_active(value: bool) -> void:
	if _active == value: return
	_active = value
	visible = value
	_update_processing()
	queue_redraw()


func reset_phase() -> void:
	_phase = 0.0
	_clamped_seconds = 0.0
	queue_redraw()


func advance(delta: float) -> void:
	if not _should_animate() or not is_finite(delta) or delta <= 0.0: return
	# The visual clock slows during a stalled frame. It never catches up by
	# issuing hidden work or bursts and is not native simulation time.
	var step := minf(delta, MAX_STEP_SECONDS)
	_clamped_seconds += maxf(delta - step, 0.0)
	_phase = fmod(_phase + step, 86400.0)
	_advance_calls += 1
	queue_redraw()


func diagnostics() -> Dictionary:
	var count := 0
	for effect: Dictionary in _effects: count += int(effect.count)
	return {"category":"presentation-only", "plane":_plane, "active":_active,
		"enabled":bool(_configuration.get("enabled", false)),
		"paused":bool(_configuration.get("paused", false)), "processing":is_processing(),
		"effect_count":_effects.size(), "motif_count":count, "phase_seconds":_phase,
		"advance_calls":_advance_calls, "draw_calls":_draw_calls,
		"last_draw_primitives":_draw_primitives, "clamped_seconds":_clamped_seconds,
		"configuration_sha256":_configuration_digest, "additional_native_worlds":0,
		"native_material_writes":0, "native_captures":0, "texture_uploads":0,
		"clock_semantics":"Visible unpaused presentation time; each callback contributes at most 0.1 seconds; no catch-up; phase not persisted."}


func _process(delta: float) -> void:
	advance(delta)


func _update_processing() -> void:
	set_process(_should_animate())


func _should_animate() -> bool:
	if not _active or not bool(_configuration.get("enabled", false)) or bool(_configuration.get("paused", false)):
		return false
	for effect: Dictionary in _effects:
		if bool(effect.enabled) and int(effect.count) > 0 and float(effect.speed) > 0.0 \
				and float(effect.strength) > 0.0 and float(effect.colour[3]) > 0.0:
			if effect.kind in ["beacon", "light_shaft", "light_pool"] or float(effect.direction[0]) != 0.0 or float(effect.direction[1]) != 0.0:
				return true
	return false


func _draw() -> void:
	_draw_primitives = 0
	if not _active or not bool(_configuration.get("enabled", false)): return
	_draw_calls += 1
	for effect: Dictionary in _effects:
		if not effect.enabled or int(effect.count) == 0 or float(effect.strength) <= 0.0: continue
		var raw: Array = effect.region
		var region := Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
		var colour := Color(float(effect.colour[0]), float(effect.colour[1]), float(effect.colour[2]),
			float(effect.colour[3]) * float(effect.strength))
		var direction := Vector2(float(effect.direction[0]), float(effect.direction[1]))
		var speed := float(effect.speed)
		var particles: Array = _motifs[effect.id]
		for index: int in particles.size():
			var particle: Vector4 = particles[index]
			var drift := direction * (_phase * speed)
			var point := region.position + Vector2(fposmod(particle.x * region.size.x + drift.x, region.size.x),
				fposmod(particle.y * region.size.y + drift.y, region.size.y))
			match str(effect.kind):
				"haze":
					var width := minf(region.size.x * 0.55, 24.0 + particle.z * 92.0)
					var height := 2.0 + floorf(particle.w * 5.0)
					_box(region, Rect2(point, Vector2(width, height)), _alpha(colour, 0.13))
					_box(region, Rect2(point + Vector2(4, height), Vector2(maxf(width - 8.0, 1.0), height)), _alpha(colour, 0.06))
				"steam":
					var progress := fposmod(particle.y + _phase * speed * absf(direction.y) / maxf(region.size.y, 1.0), 1.0)
					var height_fraction := (1.0 - progress) if direction.y <= 0.0 else progress
					point = region.position + Vector2(fposmod(region.size.x * (0.5 + (particle.x - 0.5) * progress) + sin(progress * 7.0 + particle.z * TAU) * direction.x * 18.0 + _phase * speed * direction.x, region.size.x), region.size.y * height_fraction)
					var width := 3.0 + progress * (10.0 + particle.z * 14.0)
					var height := 2.0 + progress * 5.0
					_box(region, Rect2(point - Vector2(width * 0.5, 0), Vector2(width, height)), _alpha(colour, (1.0 - progress) * 0.26))
					_box(region, Rect2(point + Vector2(-width * 0.32, height), Vector2(width * 0.64, height)), _alpha(colour, (1.0 - progress) * 0.12))
				"rain":
					var length := 3.0 + floorf(particle.z * 10.0)
					var slope := direction.x / maxf(absf(direction.y), 0.25)
					for step: int in int(length):
						_box(region, Rect2(point + Vector2(floor(step * slope), step), Vector2(1, 1)), _alpha(colour, 0.20))
				"dust":
					var width := 1.0 if particle.z < 0.85 else 2.0
					_box(region, Rect2(point, Vector2(width, width)), _alpha(colour, 0.22 + particle.w * 0.30))
				"beacon":
					var width := minf(10.0, region.size.x / maxf(particles.size(), 1.0) * 0.4)
					var centre := region.position + Vector2((index + 0.5) * region.size.x / maxf(particles.size(), 1.0), region.size.y * 0.5)
					var pulse := 0.12 + 0.88 * pow(maxf(0.0, sin(_phase * speed * TAU * 0.2 + particle.x * 1.1)), 3.0)
					_box(region, Rect2(centre - Vector2(width, 3), Vector2(width * 2, 6)), _alpha(colour, pulse * 0.08))
					_box(region, Rect2(centre - Vector2(width * 0.5, 1), Vector2(width, 2)), _alpha(colour, pulse))
				"light_shaft":
					# Fixed source positions and eight bands keep geometry bounded.
					# Direction chooses tilt/up/down; speed only adds gentle breathing.
					var source_x := region.position.x + (index + 0.5) * region.size.x / maxf(particles.size(), 1.0)
					var base_width := minf(region.size.x / maxf(particles.size(), 1.0) * 0.35, 48.0)
					var breathing := 1.0 if speed <= 0.0 else 0.90 + 0.10 * sin(_phase * speed * TAU * 0.04 + particle.z * TAU)
					for band: int in 8:
						var progress := (band + 0.5) / 8.0
						var height := maxf(region.size.y / 8.0, 1.0)
						var y := region.position.y + (band if direction.y >= 0.0 else 7 - band) * height
						var width := base_width * (0.4 + 1.6 * progress)
						var x := source_x + direction.x * region.size.y * progress * 0.5 - width * 0.5
						_box(region, Rect2(x, y, width, height), _alpha(colour, (1.0 - progress * 0.75) * breathing * 0.20))
				"light_pool":
					var centre := region.position + Vector2((index + 0.5) * region.size.x / maxf(particles.size(), 1.0), region.size.y * (0.35 + particle.y * 0.30))
					var radius := Vector2(minf(region.size.x / maxf(particles.size(), 1.0) * 0.70, 72.0), minf(region.size.y * 0.48, 72.0))
					var breathing := 1.0 if speed <= 0.0 else 0.90 + 0.10 * sin(_phase * speed * TAU * 0.04 + particle.z * TAU)
					for band: int in 4:
						var scale_factor := 1.0 - band * 0.22
						var size := radius * scale_factor * 2.0
						_box(region, Rect2(centre - size * 0.5, size), _alpha(colour, breathing * (0.025 + band * 0.012)))
				"machinery":
					var width := minf(9.0, region.size.x / maxf(particles.size(), 1.0) * 0.45)
					_box(region, Rect2(point, Vector2(width, 2.0)), _alpha(colour, 0.65))


func _box(region: Rect2, rectangle: Rect2, colour: Color) -> void:
	var clipped := rectangle.intersection(region)
	if not clipped.has_area() or colour.a <= 0.0: return
	clipped.position = clipped.position.floor()
	clipped.size = clipped.size.floor().max(Vector2.ONE)
	draw_rect(clipped, colour)
	_draw_primitives += 1


static func _alpha(colour: Color, multiplier: float) -> Color:
	return Color(colour.r, colour.g, colour.b, colour.a * multiplier)
