extends Control

# Presentation of the last copied decision only. Never issue an observation,
# sample terrain, advance a module, change its seed or renew command authority.
var _diagnostics: Dictionary = {}
var _origin := Vector2.ZERO
var _view := Vector2.ONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	hide()


func present(diagnostics: Dictionary, origin: Vector2, view_size: Vector2i, content: Rect2) -> void:
	_diagnostics = diagnostics.duplicate(true)
	_origin = origin
	_view = Vector2(view_size)
	position = content.position
	size = content.size
	visible = _diagnostics.has("ambient") and _diagnostics.get("environment", {}).get("position") is Vector2
	if visible: queue_redraw()


func _point(world: Vector2) -> Vector2:
	return (world - _origin) * size / _view


func _draw() -> void:
	var environment: Dictionary = _diagnostics.get("environment", {})
	if not environment.get("position") is Vector2: return
	var centre: Vector2 = environment.position
	var intent: Dictionary = _diagnostics.get("ambient", {}).get("intent", {})
	for target: Dictionary in environment.get("materials", {}).get("targets", {}).values():
		var radius := float(target.get("radius_cells", 0.0))
		var ring := PackedVector2Array()
		for index: int in range(49): ring.append(_point(centre + Vector2.from_angle(TAU * index / 48.0) * radius))
		draw_polyline(ring, Color(0.35, 0.85, 1.0, 0.45), 1.0, true)
		if bool(target.get("available", false)) and bool(target.get("present", false)) and target.get("nearest") is Vector2:
			var nearest: Vector2 = target.nearest
			draw_line(_point(centre), _point(nearest), Color("f8c766"), 1.5, true)
			draw_circle(_point(nearest), 4.0, Color("f8c766"), false, 1.5, true)
	var direction: Vector2 = intent.get("direction", Vector2.ZERO)
	var tip := centre + direction * 24.0
	draw_line(_point(centre), _point(tip), Color("98fca6"), 3.0, true)
	if direction.length_squared() > 0.001:
		draw_line(_point(tip), _point(tip - direction.rotated(0.55) * 7.0), Color("98fca6"), 2.0, true)
		draw_line(_point(tip), _point(tip - direction.rotated(-0.55) * 7.0), Color("98fca6"), 2.0, true)
	var drawn_probes: Dictionary = {}
	var ledges: Dictionary = environment.get("ledges", {})
	var module_probes: Array = ledges.get("modules", {}).values()
	if module_probes.is_empty(): module_probes = [ledges]
	for probes: Dictionary in module_probes:
		for side: String in ["left", "right"]:
			var ledge: Dictionary = probes.get(side, {})
			if not ledge.get("origin") is Vector2 or not ledge.get("target") is Vector2: continue
			var key := "%s:%s" % [ledge.origin, ledge.target]
			if drawn_probes.has(key): continue
			drawn_probes[key] = true
			var color := Color("87e4b3") if bool(ledge.get("support_found", false)) else Color("f28074")
			if not bool(ledge.get("available", false)): color = Color("a0a7b5")
			draw_line(_point(ledge.origin), _point(ledge.get("position", ledge.target)), color, 1.5, true)
	var label := str(intent.get("active_override", ""))
	if label.is_empty(): label = str(intent.get("reason", "waiting"))
	label = label.left(72)
	var remaining := float(intent.get("remaining_seconds", 0.0))
	if remaining > 0.0: label += " · %.1f s" % remaining
	draw_string(ThemeDB.fallback_font, _point(centre) + Vector2(10, -18), label, HORIZONTAL_ALIGNMENT_LEFT, 460, 14, Color("e7f0ff"))
