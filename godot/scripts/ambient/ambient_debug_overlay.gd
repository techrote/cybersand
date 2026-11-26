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
	var ambient: Dictionary = _diagnostics.get("ambient", {})
	var intent: Dictionary = ambient.get("intent", {})
	_draw_places(ambient.get("authored_regions", environment.get("regions", [])))
	_draw_memory(ambient.get("memory", {}))
	_draw_navigation(environment.get("navigation", {}))
	_draw_peers(environment.get("neighbors", {}), centre)
	if intent.get("goal_target") is Vector2 and not str(intent.get("selected_goal", "")).is_empty():
		var goal: Vector2 = intent.goal_target
		draw_line(_point(centre), _point(goal), Color(0.9, 0.65, 1.0, 0.7), 1.5, true)
		draw_circle(_point(goal), 6.0, Color("dbacff"), false, 1.5, true)
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


func _draw_places(value: Variant) -> void:
	if not value is Array: return
	for index: int in mini(value.size(), 12):
		var region: Dictionary = value[index]
		var top_left := Vector2(float(region.get("x", 0.0)), float(region.get("y", 0.0)))
		var bottom_right := top_left + Vector2(float(region.get("width", 1.0)), float(region.get("height", 1.0)))
		var kind := str(region.get("kind", "interest"))
		var color := Color("9bc8ff") if kind == "home" else (Color("f58c85") if kind == "avoid" else Color("f6d48c"))
		var box := Rect2(_point(top_left), _point(bottom_right) - _point(top_left))
		draw_rect(box, Color(color, 0.06), true)
		draw_rect(box, Color(color, 0.7), false, 1.0)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(4, 15),
			(kind + " · " + str(region.get("name", region.get("id", "")))).left(48),
			HORIZONTAL_ALIGNMENT_LEFT, 300, 12, color)


func _draw_memory(memory: Dictionary) -> void:
	if not bool(memory.get("enabled", false)) or not bool(memory.get("available", true)): return
	var tile_size := float(memory.get("cell_size", 24.0))
	var visited: Array = memory.get("visited", [])
	for index: int in mini(visited.size(), 128):
		var entry: Dictionary = visited[index]
		if not entry.get("position") is Vector2: continue
		var point: Vector2 = entry.position
		var box := Rect2(_point(point - Vector2.ONE * tile_size * 0.5),
			_point(point + Vector2.ONE * tile_size * 0.5) - _point(point - Vector2.ONE * tile_size * 0.5))
		draw_rect(box, Color(0.45, 0.75, 1.0, 0.09), true)
		draw_rect(box, Color(0.45, 0.75, 1.0, 0.3), false, 1.0)
	var interests: Array = memory.get("interests", [])
	for index: int in mini(interests.size(), 32):
		var entry: Dictionary = interests[index]
		if not entry.get("position") is Vector2: continue
		draw_circle(_point(entry.position), 3.0, Color("f6d48c"), true)
	var obstructions: Array = memory.get("obstructions", [])
	for index: int in mini(obstructions.size(), 32):
		var entry: Dictionary = obstructions[index]
		if not entry.get("position") is Vector2: continue
		var point := _point(entry.position)
		draw_line(point - Vector2(4, 4), point + Vector2(4, 4), Color("f58c85"), 1.5, true)
		draw_line(point - Vector2(4, -4), point + Vector2(4, -4), Color("f58c85"), 1.5, true)


func _draw_navigation(navigation: Dictionary) -> void:
	var directions: Array = navigation.get("directions", [])
	for index: int in mini(directions.size(), 8):
		var ray: Dictionary = directions[index]
		if not ray.get("origin") is Vector2 or not ray.get("position") is Vector2: continue
		var color := Color("a5e4d4") if not bool(ray.get("hit", false)) else Color("f58c85")
		if not bool(ray.get("available", false)): color = Color("a0a7b5")
		draw_line(_point(ray.origin), _point(ray.position), Color(color, 0.6), 1.0, true)
		if bool(ray.get("hit", false)): draw_circle(_point(ray.position), 2.5, color, true)


func _draw_peers(neighbors: Dictionary, centre: Vector2) -> void:
	if not bool(neighbors.get("available", false)): return
	var peers: Array = neighbors.get("actors", [])
	for index: int in mini(peers.size(), 16):
		var peer: Dictionary = peers[index]
		if not peer.get("position") is Vector2: continue
		var color := Color("a9e5c4") if bool(peer.get("compatible", false)) else Color("f58c85")
		if float(peer.get("affinity", 0.0)) < 0.0: color = Color("f58c85")
		var point := _point(peer.position)
		draw_line(_point(centre), point, Color(color, 0.22), 1.0, true)
		draw_circle(point, 8.0, Color(color, 0.7), false, 1.0, true)
		draw_string(ThemeDB.fallback_font, point + Vector2(10, 10),
			"peer #%d" % int(peer.get("id", -1)), HORIZONTAL_ALIGNMENT_LEFT, 130, 11, color)
