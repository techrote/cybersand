extends "res://scripts/physical_actor_overlay.gd"

var targets := PackedVector2Array()
var target_index: int = 0
var accent := Color("7be5ff")
var actor_position := Vector2.ZERO
var material_field: bool = false
var field_radius: float = 32.0
var movement: Dictionary = {}
var preset: StringName = &""
var usables: Dictionary = {}


func _point(world: Vector2) -> Vector2:
	return (world - _origin) * size / _view_size


func _draw() -> void:
	if _view_size.x <= 0 or _view_size.y <= 0:
		return
	# Quiet world-space grid and labelled obstacles stay underneath live bodies.
	for x: int in range(0,1025,64):
		draw_line(_point(Vector2(x,0)),_point(Vector2(x,768)),Color(0.23,0.42,0.52,0.10),1.0)
	for y: int in range(0,769,64):
		draw_line(_point(Vector2(0,y)),_point(Vector2(1024,y)),Color(0.23,0.42,0.52,0.10),1.0)
	for projectile: Dictionary in usables.get("projectiles",[]):
		draw_circle(_point(projectile.position),3.0,projectile.get("color",Color.WHITE))
	for device: Dictionary in usables.get("objects",[]):
		var point: Vector2=_point(device.position)
		draw_rect(Rect2(point-Vector2(4,4),Vector2(8,8)),device.get("color",Color.CYAN),false,2.0)
	for effect: Dictionary in usables.get("effects",[]):
		draw_circle(_point(effect.position),maxf(2.0,float(effect.get("radius",2.0))*size.x/_view_size.x),effect.get("color",Color.WHITE))
	for index: int in range(targets.size()):
		var point: Vector2 = _point(targets[index])
		var radius: float = 13.0 * size.x / _view_size.x
		var color: Color = accent if index == target_index else Color(0.5, 0.65, 0.72, 0.24)
		if index < target_index:
			color = Color(0.5, 0.95, 0.7, 0.55)
		draw_arc(point, radius, 0.0, TAU, 40, color, 2.0, true)
		var label: String = str(index + 1) if index >= target_index else "✓"
		draw_string(ThemeDB.fallback_font, point + Vector2(-4, -radius - 7), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, color)
	if material_field:
		var point: Vector2 = _point(actor_position)
		draw_arc(point, field_radius * size.x / _view_size.x, 0.0, TAU, 64, Color(accent, 0.20), 1.0, true)
		draw_line(point + Vector2(-5, 0), point + Vector2(5, 0), Color(accent, 0.7), 1.0)
		draw_line(point + Vector2(0, -5), point + Vector2(0, 5), Color(accent, 0.7), 1.0)
		if not usables.get("actors",[]).is_empty() and int(usables.actors[0].get("usable_index",-1))>=0:
			var nozzle: Vector2=_point(usables.actors[0].position)
			draw_line(point,nozzle,Color(accent,0.3),1.0)
			draw_circle(nozzle,4.0,accent,false,1.5)
	# Exhaust is a presentation cue driven by accepted controller telemetry.
	# It never adds a collider or changes the authoritative physical hull.
	if preset in [&"arcadelander", &"jetbarrel"]:
		for part: Dictionary in _parts:
			if str(part.part_id) in ["chassis", "barrel"]:
				var thrust: float = float(movement.get("thrust", 0.0))
				if absf(thrust) > 0.01:
					var pose: Transform2D = part.transform
					var base: float = Vector2(part.size).y * 0.5 * signf(thrust)
					var tip: float = base + signf(thrust) * (5.0 + 7.0 * absf(thrust))
					draw_colored_polygon(PackedVector2Array([_point(pose * Vector2(-2.1, base)),
						_point(pose * Vector2(2.1, base)), _point(pose * Vector2(0, tip))]), Color("ff9855"))
					draw_colored_polygon(PackedVector2Array([_point(pose * Vector2(-1.0, base)),
						_point(pose * Vector2(1.0, base)), _point(pose * Vector2(0, lerpf(base, tip, 0.55)))]), Color("e9faff"))
	super._draw()
	# One small badge per autonomous actor distinguishes NPCs from loose props
	# and the human without adding any scene object to the physics owner.
	var labelled: Dictionary = {}
	for part: Dictionary in _parts:
		var actor_id: int = int(part.get("actor_id", -1))
		if actor_id < 0 or (not material_field and actor_id == 0) or labelled.has(actor_id): continue
		labelled[actor_id] = true
		var badge: Vector2 = _point(Transform2D(part.transform).origin - Vector2(0, Vector2(part.size).y * 0.5 + 8.0))
		draw_string(ThemeDB.fallback_font, badge + Vector2(-13, 0), "NPC %d" % (actor_id + 1 if material_field else actor_id),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a8e4bb"))
	# A spoke makes actual wheel rotation legible without hiding its collider.
	for part: Dictionary in _parts:
		if str(part.get("shape", "")) == "circle":
			var pose: Transform2D = part.transform
			var radius: float = Vector2(part.size).x * 0.42
			draw_line(_point(pose.origin), _point(pose * Vector2(radius, 0)), Color(1, 1, 1, 0.65), 1.5, true)
		elif preset == &"jetbarrel" and str(part.part_id) == "barrel":
			var pose: Transform2D = part.transform
			var half: Vector2 = Vector2(part.size) * 0.5
			for band: float in [-0.62, 0.62]:
				draw_line(_point(pose * Vector2(-half.x, half.y * band)),
					_point(pose * Vector2(half.x, half.y * band)), Color("405364"), 2.0, true)
			draw_line(_point(pose * Vector2(-half.x * 0.55, -half.y * 0.85)),
				_point(pose * Vector2(-half.x * 0.55, half.y * 0.85)), Color(1, 0.9, 0.65, 0.55), 1.0, true)
